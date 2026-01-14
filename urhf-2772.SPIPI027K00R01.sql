




CREATE OR REPLACE PROCEDURE spipi027k00r01 ( 
	l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 INOUT l_outSqlCode integer,		-- リターン値
 INOUT l_outSqlErrM text	-- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権	:Copyright(c)2012
-- * 会社名	:JIP
-- *
-- * 概要		:アップロード処理により、定時不定額償還情報取込確認リストを作成する。
-- *
-- * 引数		:l_inItakuKaishaCd 	:委託会社コード
-- * 			 l_inUserId        	:ユーザID
-- * 			 l_inChohyoKbn      :帳票区分
-- * 			 l_inGyomuYmd       :業務日付
-- * 			 l_outSqlCode       :リターン値
-- * 			 l_outSqlErrM       :エラーコメント
-- * 
-- * 返り値: なし
-- * 
-- * @author 中村（IPT）
-- * @version $Id: SPIPI027K00R01.sql,v 1.1 2014/07/23 01:41:23 nakamura Exp $
-- *
-- 
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 1;
--==============================================================================
--					定数定義													
--==============================================================================
	SP_ID					CONSTANT varchar(20)   := 'SPIPI027K00R01';
	RTN_OK					CONSTANT integer		:= 0;				-- 正常
	RTN_NG					CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA				CONSTANT integer		:= 2;				-- データなし
	RTN_DUP_VAL_ON_INDEX	CONSTANT integer		:= 90;				-- 一意制約エラー
	RTN_FATAL				CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID				CONSTANT char(11)		:= 'IPK30000151';	-- 帳票ID
    ERR_UMU_ERR         	CONSTANT varchar(1)    := '1';
    ERR_CD_E            	CONSTANT varchar(6)    := 'ECM501';
    ERR_CD_F            	CONSTANT varchar(6)    := 'ECM701';
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd					integer :=	RTN_OK;						-- リターンコード
	gSeqNo					integer := 0;							-- シーケンス
	gRecCnt					integer := 0;							-- データレコード件数
    gMeisaiCntNormal     	integer := 0;                       		-- 正常件数
    gMeisaiCntError     	integer := 0;                       		-- エラー件数
    gMgrCd          		IMPORT_KAKUNIN_LIST_WK.MGR_CD%TYPE;
    gMgrRnm          		IMPORT_KAKUNIN_LIST_WK.MGR_RNM%TYPE;
    gShokanYmd         		IMPORT_KAKUNIN_LIST_WK.SHOKAN_YMD%TYPE;
    gShokanKngk				IMPORT_KAKUNIN_LIST_WK.SHOKAN_KNGK%TYPE;
    gErrUmuFlg          	IMPORT_KAKUNIN_LIST_WK.ERR_UMU_FLG%TYPE := '1';
	gItakuKaishaRnm			VJIKO_ITAKU.BANK_RNM%TYPE;					-- 委託会社略称
	wSeqNo					numeric 					:= null;
	wRecCnt					varchar(10);
--==============================================================================
--					カーソル定義												
--==============================================================================
    --
--     * 取込確認リストワークより、確認リスト用のデータを取得します。
--     
	curMeisai CURSOR FOR
		SELECT
                KC16.SAKUSEI_YMD,
                KC16.SHORI_TM,
                KC16.ERR_UMU_FLG,
                KC16.SEQ_NO,
                KC16.MGR_CD,
                KC16.MGR_RNM,
                MG1.HAKKO_YMD,
				KC16.SHOKAN_YMD,
				KC16.SHOKAN_KNGK,
				KC16.ERR_CD6,
				KC16.ERR_NM30
        FROM import_kakunin_list_wk kc16
LEFT OUTER JOIN mgr_kihon mg1 ON (KC16.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND KC16.MGR_CD = MG1.MGR_CD)
WHERE KC16.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND KC16.USER_ID = l_inUserId AND KC16.CHOHYO_ID = REPORT_ID AND KC16.SAKUSEI_YMD = l_inGyomuYmd ORDER BY	
                KC16.ERR_UMU_FLG DESC,
				KC16.SEQ_NO
		;
	recPrevMeisai	RECORD;
	recWorkMeisai	RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(SP_ID, l_inUserId, 'START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '入力パラメータエラー';
		CALL pkLog.error(ERR_CD_E, SP_ID, 'エラー内容：' || l_outSqlErrM);
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE	FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 件数のクリア
	gMeisaiCntNormal := 0;		-- 正常件数
	gMeisaiCntError := 0;		-- エラー件数
	-- 委託会社略称の取得
	gItakuKaishaRnm := SPIPI027K00R01_getItakuKaishaRnm(l_inItakuKaishaCd);
	FOR recMeisai IN curMeisai LOOP
        -- エラー有無フラグがエラー有り／エラー無しが変わるタイミングで件数データをインサートする。（SQLでソート済み）
        IF gErrUmuFlg != recMeisai.ERR_UMU_FLG THEN
			-- Only process if recPrevMeisai has been assigned (gRecCnt > 0)
			IF gRecCnt > 0 THEN
				recWorkMeisai := recPrevMeisai;
				-- エラー件数データレコードを帳票ワークへ追加する
				gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recWorkMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recWorkMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem005 := recWorkMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem013 := 'エラーデータ件数';	-- エラーデータ件数
		v_item.l_inItem014 := trim(both TO_CHAR(gMeisaiCntError, '999999'));	-- エラー件数
		v_item.l_inItem015 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem017 := l_inGyomuYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			END IF;
			gErrUmuFlg	:= recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		END IF;
		-- 件数カウントアップ
        IF ((coalesce(wSeqNo::text, '') = '') OR (recMeisai.SEQ_NO != wSeqNo)) THEN
            -- エラー有無フラグにより、エラーまたは正常の配列に件数カウントセット
            -- 正常なら正常用の配列に入っている件数を +1、エラーならエラー用の配列に入っている件数を +1 する。
            IF recMeisai.ERR_UMU_FLG = '1' THEN
                gMeisaiCntError := gMeisaiCntError + 1;
            ELSE
                gMeisaiCntNormal := gMeisaiCntNormal + 1;
            END IF;
            -- 全体の件数
			gRecCnt := gRecCnt + 1;
	        -- 
			wRecCnt := gRecCnt::text;
        END IF;
        -- キーが同じなら銘柄コード・銘柄略称・利払期日は出力しない
        IF SPIPI027K00R01_isChangeKey(recMeisai,recPrevMeisai) = FALSE THEN
			gMgrCd := NULL;
			gMgrRnm := NULL;
			gShokanYmd := NULL;
			gShokanKngk := NULL;
        ELSE
			gMgrCd := recMeisai.MGR_CD;
			gMgrRnm := recMeisai.MGR_RNM;
			gShokanYmd := recMeisai.SHOKAN_YMD;
			gShokanKngk := recMeisai.SHOKAN_KNGK;
        END IF;
		-- データレコードを帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := wRecCnt;	-- 連番
		v_item.l_inItem005 := recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem006 := gMgrCd;	-- 銘柄コード
		v_item.l_inItem007 := gMgrRnm;	-- 銘柄略称
		v_item.l_inItem008 := recMeisai.HAKKO_YMD;	-- 発行日
		v_item.l_inItem009 := gShokanYmd;	-- 償還期日
		v_item.l_inItem010 := gShokanKngk;	-- 償還金額
		v_item.l_inItem011 := recMeisai.ERR_CD6;	-- エラーコード
		v_item.l_inItem012 := recMeisai.ERR_NM30;	-- エラー内容
		v_item.l_inItem015 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem017 := l_inGyomuYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		recPrevMeisai := recMeisai;
	    -- シーケンスNo保存
		wSeqNo := recMeisai.SEQ_NO;
		wRecCnt := ' ';
	END LOOP;
    -- すべてエラーのときのエラー件数レコード
	IF gErrUmuFlg = '1' THEN
		-- Only process if there's data
		IF gRecCnt > 0 THEN
			recWorkMeisai := recPrevMeisai;
	        -- エラー件数データが存在しない場合はNULLを設定する
			IF gMeisaiCntError = 0 THEN
				recWorkMeisai.SAKUSEI_YMD	:= NULL;
				recWorkMeisai.SHORI_TM		:= NULL;
				recWorkMeisai.ERR_UMU_FLG	:= NULL;
			END IF;
	    	-- エラー件数データを出力する
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recWorkMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recWorkMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem005 := recWorkMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem013 := 'エラーデータ件数';	-- エラーデータ件数
		v_item.l_inItem014 := trim(both TO_CHAR(gMeisaiCntError, '999999'));	-- エラー件数
		v_item.l_inItem015 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem017 := l_inGyomuYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		END IF;
	END IF;
	
	-- Only process normal count if there's data
	IF gRecCnt > 0 THEN
		recWorkMeisai := recPrevMeisai;
		-- 正常データが存在しない場合はNULLを設定する
		IF gMeisaiCntNormal = 0 THEN
			recWorkMeisai.SAKUSEI_YMD	:= NULL;
			recWorkMeisai.SHORI_TM		:= NULL;
			recWorkMeisai.ERR_UMU_FLG	:= NULL;
		END IF;
		-- 正常件数を出力する
		gSeqNo := gSeqNo + 1;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recWorkMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recWorkMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem005 := recWorkMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem013 := '正常取込データ件数';	-- 件数項目名称
		v_item.l_inItem014 := trim(both TO_CHAR(gMeisaiCntNormal, '999999'));	-- エラー有無毎の件数
		v_item.l_inItem015 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem017 := l_inGyomuYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		
		-- 総件数データレコードを出力する
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem013 := '総データ数';	-- 件数項目名称
		v_item.l_inItem014 := trim(both TO_CHAR(gMeisaiCntNormal + gMeisaiCntError, '999999'));	-- 総件数
		v_item.l_inItem015 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem017 := l_inGyomuYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
    -- 総件数が0件のとき
	IF gRecCnt = 0 THEN
    	-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
    -- 正常ならバッチ帳票出力指示画面より出力できるようにPRT_OKにINSERT
	IF gRtnCd = RTN_OK THEN
		CALL pkPrtOk.insertPrtOk(
			l_inUserId,
			l_inItakuKaishaCd,
			l_inGyomuYmd,
			pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(),
			REPORT_ID
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(SP_ID, l_inUserId, 'ROWCOUNT:'|| gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(SP_ID, l_inUserId, 'END ' || gRtnCd);	END IF;
-- エラー処理
EXCEPTION
	WHEN	unique_violation THEN
		l_outSqlCode := RTN_DUP_VAL_ON_INDEX;
		l_outSqlErrM := SQLERRM;
	WHEN OTHERS THEN
		CALL pkLog.fatal(ERR_CD_F, SP_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal(ERR_CD_F, SP_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi027k00r01 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipi027k00r01_getitakukaisharnm (l_inItakuKaishaCd text) RETURNS varchar AS $body$
DECLARE

	bankRnm		varchar(100) := NULL;

BEGIN
	-- 自行・委託会社情報から委託会社略称の取得
	SELECT	CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE NULL END
	INTO STRICT	bankRnm
	FROM	VJIKO_ITAKU
	WHERE	KAIIN_ID = l_inItakuKaishaCd;
	RETURN bankRnm;
EXCEPTION
	WHEN OTHERS THEN
		RETURN bankRnm;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipi027k00r01_getitakukaisharnm (l_inItakuKaishaCd text) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipi027k00r01_ischangekey ( l_inRow RECORD, l_inPreRow RECORD ) RETURNS boolean AS $body$
BEGIN
        -- キーが同じならFALSE
        IF (l_inRow.MGR_CD = l_inPreRow.MGR_CD) AND (l_inRow.SHOKAN_YMD = l_inPreRow.SHOKAN_YMD) THEN
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
EXCEPTION
	WHEN OTHERS THEN
		RETURN TRUE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipi027k00r01_ischangekey ( l_inRow RECORD, l_inPreRow RECORD ) FROM PUBLIC;