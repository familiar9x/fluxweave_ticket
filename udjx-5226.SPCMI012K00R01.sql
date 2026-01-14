




CREATE OR REPLACE PROCEDURE spcmi012k00r01 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
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
-- * アップロード処理により、機構発行体マスタ取込確認リストを作成する。
-- *
-- * @author  磯田 浩靖
-- * @version $Id: SPCMI012K00R01.sql,v 1.2 2007/06/18 09:43:37 shimazoe Exp $
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
	SP_ID				CONSTANT varchar(20)   := 'SPCMI012K00R01';
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_DUP_VAL_ON_INDEX	CONSTANT integer	:= 90;				-- 一意制約エラー
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'CG030001211';	-- 帳票ID
	-- 帳票件数項目名称
	KBN_NAME_ERROR		CONSTANT varchar(14)		:= '取込エラー件数';
	KBN_NAME_NORMAL		CONSTANT varchar(12)		:= '正常取込件数';
	KBN_NAME_TOTAL		CONSTANT varchar(6)		:= '総件数';
    ERR_UMU_ERR         CONSTANT varchar(1)        := '1';
    -- 明細出力最大件数
    MEISAI_LIMIT_CNT    CONSTANT integer        := 100;
    -- 明細出力最大件数オーバーメッセージ
    WARN_MSG            CONSTANT varchar(200)  := '※エラー検出数が100件を超えました。明細行は最初に検出された100件分のみ表示します。';
    ERR_CD_E            CONSTANT varchar(6)    := 'ECM321';
    ERR_CD_F            CONSTANT varchar(6)    := 'ECM602';
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gRecCnt				integer := 0;							-- データレコード件数
    gMeisaiCntArray     integer[];                       -- 件数用（要素番号 1:正常,2:エラー）
    gKkHakkoCd          MKIKOHAKKO_LIST_WK.KK_HAKKO_CD%TYPE;
    gErrUmuFlg          MKIKOHAKKO_LIST_WK.ERR_UMU_FLG%TYPE := '1';
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
                M12LW.KIJUN_YMD,
                M12LW.SAKUSEI_YMD,
                M12LW.SHORI_TM,
                M12LW.ERR_UMU_FLG,
                M12LW.SEQ_NO,
                M12LW.KK_HAKKO_CD,
                M12LW.ERR_NM30            
        FROM
                MKIKOHAKKO_LIST_WK M12LW
        WHERE
                M12LW.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND     M12LW.USER_ID = l_inUserId
        AND     M12LW.CHOHYO_ID = REPORT_ID
		ORDER BY	
                M12LW.ERR_UMU_FLG DESC,
				M12LW.SEQ_NO,
                M12LW.KK_HAKKO_CD,
				M12LW.ERR_NM30
		;
	recPrevMeisai	RECORD;
	recWorkMeisai	RECORD;
	has_data		boolean := false;  -- Track if cursor returned any data
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
	gMeisaiCntArray := ARRAY[0, 0];  -- [1]=normal, [2]=error (1-based indexing)
	gMeisaiCntArray[1] := 0;		-- 正常件数
	gMeisaiCntArray[2] := 0;		-- エラー件数
	-- 委託会社略称の取得
	gItakuKaishaRnm := SPCMI012K00R01_getItakuKaishaRnm(l_inItakuKaishaCd);
	FOR recMeisai IN curMeisai LOOP
		has_data := true;  -- Mark that we have data
        -- エラー有無フラグがエラー有り／エラー無しが変わるタイミングで件数データをインサートする。（SQLでソート済み）
        IF gErrUmuFlg != recMeisai.ERR_UMU_FLG THEN
            -- Only process if recPrevMeisai has been assigned (gRecCnt > 0)
            IF gRecCnt > 0 THEN
                -- 明細出力最大件数を超えていたらメッセージを出力
                IF gMeisaiCntArray[2] > MEISAI_LIMIT_CNT AND recPrevMeisai.ERR_UMU_FLG = ERR_UMU_ERR THEN
                    CALL SPCMI012K00R01_insertWarnMsg(recPrevMeisai, gSeqNo, l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gItakuKaishaRnm);
                END IF;
                -- 件数データレコードを帳票ワークへ追加する
                gSeqNo := gSeqNo + 1;
                		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem005 := recPrevMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem008 := KBN_NAME_ERROR;	-- 件数項目名称
		v_item.l_inItem009 := trim(both TO_CHAR(gMeisaiCntArray[1+1], '999999'));	-- エラー有無毎の件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem014 := recPrevMeisai.KIJUN_YMD;	-- 今回取込データ基準日
		
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
            -- 
			gErrUmuFlg	:= recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		END IF;
		-- 件数カウントアップ
        IF ( (coalesce(wSeqNo::text, '') = '') OR (recMeisai.SEQ_NO != wSeqNo)) THEN
            -- エラー有無フラグにより、エラーまたは正常の配列に件数カウントセット
            -- 正常なら正常用の配列に入っている件数を +1、エラーならエラー用の配列に入っている件数を +1 する。
            IF recMeisai.ERR_UMU_FLG = '1' THEN
                gMeisaiCntArray[2] := gMeisaiCntArray[2] + 1;  -- Error count
            ELSE
                gMeisaiCntArray[1] := gMeisaiCntArray[1] + 1;  -- Normal count
            END IF;
            -- 全体の件数
			gRecCnt := gRecCnt + 1;
            -- 
			wRecCnt := gRecCnt::text;
        END IF;
        -- 明細をインサートするかどうか        
        IF SPCMI012K00R01_isExecuteInsertMeisaiData(recMeisai,recPrevMeisai) THEN
            -- キーが同じなら機構発行体コードは出力しない
            IF SPCMI012K00R01_isChangeKey(recMeisai,recPrevMeisai) = FALSE THEN
                gKkHakkoCd := NULL;
            ELSE
                gKkHakkoCd := recMeisai.KK_HAKKO_CD;
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
		v_item.l_inItem006 := gKkHakkoCd;	-- 機構発行体コード
		v_item.l_inItem007 := recMeisai.ERR_NM30;	-- エラー内容
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem014 := recMeisai.KIJUN_YMD;	-- 今回取込データ基準日
		
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
		recPrevMeisai := recMeisai;
	    -- シーケンスNo保存
		wSeqNo := recMeisai.SEQ_NO;
		wRecCnt := ' ';
	END LOOP;
    -- すべてエラーのときのエラー件数レコード (only if we have data)
	IF has_data AND gErrUmuFlg = '1' THEN
		recWorkMeisai := recPrevMeisai;
        -- エラー件数データが存在しない場合はNULLを設定する
		IF gMeisaiCntArray[1+1] = 0 THEN
			recWorkMeisai.SAKUSEI_YMD	:= NULL;
			recWorkMeisai.SHORI_TM		:= NULL;
			recWorkMeisai.ERR_UMU_FLG	:= NULL;
		END IF;
        -- 明細出力最大件数を超えていたらメッセージを出力
        IF gMeisaiCntArray[2] > MEISAI_LIMIT_CNT THEN
            CALL SPCMI012K00R01_insertWarnMsg(recPrevMeisai, gSeqNo, l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gItakuKaishaRnm);
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
		v_item.l_inItem009 := trim(both TO_CHAR(gMeisaiCntArray[1+1], '999999'));	-- エラー有無毎の件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem014 := recWorkMeisai.KIJUN_YMD;	-- 今回取込データ基準日
		
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
	IF has_data THEN
		recWorkMeisai := recPrevMeisai;
		-- 正常データが存在しない場合はNULLを設定する
		IF gMeisaiCntArray[0+1] = 0 THEN
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
		v_item.l_inItem009 := trim(both TO_CHAR(gMeisaiCntArray[0+1], '999999'));	-- エラー有無毎の件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem014 := recWorkMeisai.KIJUN_YMD;	-- 今回取込データ基準日
		
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
		v_item.l_inItem010 := trim(both TO_CHAR(gMeisaiCntArray[0+1] + gMeisaiCntArray[1+1], '999999'));	-- 総件数
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem014 := recPrevMeisai.KIJUN_YMD;	-- 今回取込データ基準日
		
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
	END IF;  -- End of has_data check
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
-- REVOKE ALL ON PROCEDURE spcmi012k00r01 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spcmi012k00r01_getitakukaisharnm (l_inItakuKaishaCd text) RETURNS varchar AS $body$
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
-- REVOKE ALL ON FUNCTION spcmi012k00r01_getitakukaisharnm (l_inItakuKaishaCd text) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spcmi012k00r01_insertwarnmsg ( 
    l_inRow RECORD,
    INOUT p_gSeqNo integer,
    l_inItakuKaishaCd TEXT,
    l_inUserId TEXT,
    l_inChohyoKbn TEXT,
    l_inGyomuYmd TEXT,
    gItakuKaishaRnm TEXT
) AS $body$
DECLARE
    v_item type_sreport_wk_item;
    REPORT_ID CONSTANT char(11) := 'CG030001211';
    WARN_MSG CONSTANT varchar(200) := '※エラー検出数が100件を超えました。明細行は最初に検出された100件分のみ表示します。';
BEGIN
	p_gSeqNo := p_gSeqNo + 1;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inRow.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := l_inRow.SHORI_TM;	-- 処理時刻
		v_item.l_inItem005 := l_inRow.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem007 := WARN_MSG;	-- エラー内容
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem013 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem014 := l_inRow.KIJUN_YMD;	-- 今回取込データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> p_gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spcmi012k00r01_insertwarnmsg ( l_inRow RECORD ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spcmi012k00r01_ischangekey ( l_inRow RECORD, l_inPreRow RECORD ) RETURNS boolean AS $body$
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
-- REVOKE ALL ON FUNCTION spcmi012k00r01_ischangekey ( l_inRow RECORD, l_inPreRow RECORD ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spcmi012k00r01_isexecuteinsertmeisaidata ( l_inRow RECORD, l_inPreRow RECORD ) RETURNS boolean AS $body$
BEGIN
        -- エラーの明細だったらTRUEを返す。
        IF l_inRow.ERR_UMU_FLG = ERR_UMU_ERR THEN
            -- 明細総件数が指定件数を超えたら明細は帳票に出さない
            IF gRecCnt > MEISAI_LIMIT_CNT THEN
                RETURN FALSE;
            ELSE
                RETURN TRUE;
            END IF;
        ELSE
            RETURN FALSE;
        END IF;
EXCEPTION
	WHEN OTHERS THEN
		RETURN TRUE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spcmi012k00r01_isexecuteinsertmeisaidata ( l_inRow RECORD, l_inPreRow RECORD ) FROM PUBLIC;