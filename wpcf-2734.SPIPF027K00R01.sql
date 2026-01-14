




CREATE OR REPLACE PROCEDURE spipf027k00r01 ( 
	l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2006
-- * 会社名: JIP
-- *
-- * アップロード処理により、発行体マスタ取込確認リストを作成する。
-- *
-- * @author  緒方 広道
-- * @version $Revision: 1.3 $
-- * @param  	l_inItakuKaishaCd 	IN 	委託会社コード
-- * @param  	l_inUserId        	IN 	ユーザID
-- * @param  	l_inChohyoKbn      	IN 	帳票区分
-- * @param  	l_inGyomuYmd       	IN 	業務日付
-- * @param  	l_outSqlCode       	IN 	リターン値
-- * @param  	l_outSqlErrM       	IN 	エラーコメント
-- *
-- 
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 1;
--==============================================================================
--					定数定義													
--==============================================================================
	SP_ID				CONSTANT varchar(20)   := 'SPIPF027K00R01';
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_DUP_VAL_ON_INDEX	CONSTANT integer	:= 90;				-- 一意制約エラー
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IPF30102711';	-- 帳票ID
	-- 帳票件数項目名称
	KBN_NAME_ERROR		CONSTANT varchar(14)		:= '取込エラー件数';
	KBN_NAME_NORMAL		CONSTANT varchar(12)		:= '正常取込件数';
	KBN_NAME_TOTAL		CONSTANT varchar(6)		:= '総件数';
    ERR_UMU_ERR         CONSTANT varchar(1)        := '1';
    -- 明細出力最大件数
    --MEISAI_LIMIT_CNT    CONSTANT INTEGER        := 100;
    -- 明細出力最大件数オーバーメッセージ
    --WARN_MSG            CONSTANT VARCHAR(200)  := '※エラー検出数が100件を超えました。明細行は最初に検出された100件分のみ表示します。';
    ERR_CD_E            CONSTANT varchar(6)    := 'ECM321';
    ERR_CD_F            CONSTANT varchar(6)    := 'ECM602';
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gRecCnt				integer := 0;							-- データレコード件数
    gMeisaiCntNormal    integer := 0;                               -- 正常件数
    gMeisaiCntError     integer := 0;                               -- エラー件数
	gTeiseiCnt			numeric := 0;								-- うち訂正取込件数
    gHktCd          	IMPORT_KAKUNIN_LIST_WK.HKT_CD%TYPE;
    gErrUmuFlg          IMPORT_KAKUNIN_LIST_WK.ERR_UMU_FLG%TYPE := '1';
    gKozaTenCd			IMPORT_KAKUNIN_LIST_WK.KOZA_TEN_CD%TYPE;
    gKozaTenCifcd		IMPORT_KAKUNIN_LIST_WK.KOZA_TEN_CIFCD%TYPE;
    gShoriMode			IMPORT_KAKUNIN_LIST_WK.SHORI_MODE%TYPE;
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;					-- 委託会社略称
	wSeqNo				numeric := null;
	wRecCnt				varchar(10);
--==============================================================================
--					カーソル定義												
--==============================================================================
    --
--     * 機構発行体マスタ取込リストワークより、確認リスト用のデータを取得します。
--     
	curMeisai CURSOR FOR
		SELECT
                KC16.SAKUSEI_YMD,
                KC16.SHORI_TM,
                KC16.ERR_UMU_FLG,
                KC16.SHORI_MODE,
                KC16.SEQ_NO,
                KC16.HKT_CD,
                KC16.KOZA_TEN_CD,
                KC16.KOZA_TEN_CIFCD,
                KC16.ERR_NM30            
        FROM
                IMPORT_KAKUNIN_LIST_WK KC16
        WHERE
                KC16.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND     KC16.USER_ID = l_inUserId
        AND     KC16.CHOHYO_ID = REPORT_ID
		ORDER BY	
                KC16.ERR_UMU_FLG DESC,
				KC16.SEQ_NO,
                KC16.ERR_CD6,
				KC16.ERR_NM30
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
		l_outSqlErrM := '';
		CALL pkLog.error(ERR_CD_E, l_inUserId, SP_ID);
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
	gItakuKaishaRnm := SPIPF027K00R01_getItakuKaishaRnm(l_inItakuKaishaCd);
	FOR recMeisai IN curMeisai LOOP
        -- エラー有無フラグがエラー有り／エラー無しが変わるタイミングで件数データをインサートする。（SQLでソート済み）
        IF gRecCnt > 0 AND gErrUmuFlg != recMeisai.ERR_UMU_FLG THEN
			-- 件数データレコードを帳票ワークへ追加する
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem005 := recPrevMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem008 := KBN_NAME_ERROR;	-- 件数項目名称
		v_item.l_inItem009 := trim(both TO_CHAR(gMeisaiCntError, '999999'));	-- エラー有無毎の件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		
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
            -- 
			gErrUmuFlg	:= recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		END IF;
		-- 件数カウントアップ
        IF ( (coalesce(wSeqNo::text, '') = '') OR (recMeisai.SEQ_NO != wSeqNo)) THEN
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
			-- うち訂正取込件数（エラーなしかつ訂正モード の件数） をカウントアップ
			IF (recMeisai.ERR_UMU_FLG = '0' AND recMeisai.SHORI_MODE = '2') THEN
				gTeiseiCnt := gTeiseiCnt + 1;
			END IF;
        END IF;
        -- 明細をインサートするかどうか        
        --IF isExecuteInsertMeisaiData(recMeisai,recPrevMeisai) THEN
        
            -- キーが同じなら発行体コード等は出力しない
            IF SPIPF027K00R01_isChangeKey(recMeisai,recPrevMeisai) = FALSE THEN
                gHktCd := NULL;
				gKozaTenCd		:= NULL;
				gKozaTenCifcd	:= NULL;
				gShoriMode		:= NULL;
            ELSE
                gHktCd := recMeisai.HKT_CD;
				gKozaTenCd		:= recMeisai.KOZA_TEN_CD;
				gKozaTenCifcd	:= recMeisai.KOZA_TEN_CIFCD;
				gShoriMode		:= recMeisai.SHORI_MODE;
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
		v_item.l_inItem006 := gHktCd;	-- 発行体コード
		v_item.l_inItem007 := recMeisai.ERR_NM30;	-- エラー内容
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem014 := gKozaTenCd;	-- 口座店コード
		v_item.l_inItem015 := gKozaTenCifcd;	-- 口座店CIFコード
		v_item.l_inItem016 := gShoriMode;	-- 処理モード
		
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
		--END IF;
		recPrevMeisai := recMeisai;
	    -- シーケンスNo保存
		wSeqNo := recMeisai.SEQ_NO;
		wRecCnt := ' ';
	END LOOP;
	
	-- Only process summary records if we had data
	IF gRecCnt > 0 THEN
		-- すべてエラーのときのエラー件数レコード
		IF gErrUmuFlg = '1' THEN
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
		v_item.l_inItem005 := recPrevMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem008 := KBN_NAME_ERROR;	-- 件数項目名称
		v_item.l_inItem009 := trim(both TO_CHAR(gMeisaiCntError, '999999'));	-- エラー有無毎の件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		
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
		v_item.l_inItem008 := KBN_NAME_NORMAL;	-- 件数項目名称
		v_item.l_inItem009 := trim(both TO_CHAR(gMeisaiCntNormal, '999999'));	-- エラー有無毎の件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem017 := TO_CHAR(gTeiseiCnt, '999999');	-- うち訂正取込件数
		
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
		v_item.l_inItem008 := KBN_NAME_TOTAL;	-- 件数項目名称
		v_item.l_inItem010 := trim(both TO_CHAR(gMeisaiCntNormal + gMeisaiCntError, '999999'));	-- 総件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		
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
	END IF;  -- End of gRecCnt > 0 check
	
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
		CALL pkLog.fatal(ERR_CD_F, SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SUBSTR(SQLERRM, 1, 100);
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf027k00r01 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipf027k00r01_getitakukaisharnm (l_inItakuKaishaCd text) RETURNS varchar AS $body$
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
-- REVOKE ALL ON FUNCTION spipf027k00r01_getitakukaisharnm (l_inItakuKaishaCd text) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipf027k00r01_ischangekey ( l_inRow RECORD, l_inPreRow RECORD ) RETURNS boolean AS $body$
BEGIN
        -- キーが同じならFALSE
        IF l_inRow.SEQ_NO = l_inPreRow.SEQ_NO THEN
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
-- REVOKE ALL ON FUNCTION spipf027k00r01_ischangekey ( l_inRow RECORD, l_inPreRow RECORD ) FROM PUBLIC;