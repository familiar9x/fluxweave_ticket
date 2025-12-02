




CREATE OR REPLACE PROCEDURE spip05801 ( l_inUserId character varying,		-- ユーザーID
 l_inItakuKaishaCd character varying,		-- 委託会社コード
 l_inKijunYm character varying,		-- 基準年月
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2005
-- * 会社名:JIP
-- * @author 山下　健太(NOA)
-- * @version $Revision: 1.9 $
-- * 概要　:顧客宛帳票出力指示画面の入力条件により、期中管理手数料請求一覧表(分配)を作成する
-- * @param	l_inUserId  		ユーザID
-- * @param 	l_inItakuKaishaCd 	委託会社コード
-- * @param 	l_inKijunYm			基準年月
-- * @param 	l_outSqlCode		リターン値
-- * @param 	l_outSqlErrM		エラーコメント
-- * 返り値:なし
-- *
-- 
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer		:= 0;					-- 正常
	RTN_NG				CONSTANT integer		:= 1;					-- 予期したエラー
	RTN_FATAL			CONSTANT integer		:= 99;					-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030005811';		-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
    gReturnCode         integer := 0;
	gKjtFrom             char(8);
	gKjtTo               char(8);
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
    l_GyomuYmd          char(8);
    l_tmpSqlCode        integer;
    l_tmpSqlErrM        character varying;
    l_tmpExtra          integer;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
    -- 業務日付取得
    l_GyomuYmd := pkDate.getGyomuYmd()::char(8);
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp05801 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYm)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
    -- 基準年月から、期日Ｆｒｏｍ−Ｔｏをセット
    gKjtFrom := (l_inKijunYm || '01')::char(8);
    gKjtTo   := TO_CHAR(oracle.LAST_DAY(to_date(l_inKijunYm || '01','YYYYMMDD')),'YYYYMMDD')::char(8);
	-- データ取得
	-- 期中手数料計算処理（分配請求書）※リアル・予定表出力・請求書一覧
	SELECT f.l_outsqlcode, f.l_outsqlerrm, f.extra_param 
	INTO l_tmpSqlCode, l_tmpSqlErrM, l_tmpExtra
	FROM pkipakichutesuryo.insKichuTesuryoSeikyuOut(l_inuserid,
                                           l_GyomuYmd,
                                           gKjtFrom,
                                           gKjtTo,
                                           l_initakukaishacd,
                                           NULL,
                                           NULL,
                                           NULL,
                                           NULL,
                                           NULL,
                                           NULL,
                                           REPORT_ID,
                                           PKIPACALCTESURYO.C_REAL(),
										   PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
										   PKIPACALCTESURYO.C_SI_KBN_ICHIRAN(),
										   '0') AS f; --フロント照会画面判別フラグ '0'(フロント照会画面以外)
	gReturnCode := l_tmpSqlCode;
	l_outSqlCode := l_tmpSqlCode;
	l_outSqlErrM := l_tmpSqlErrM;
	IF gReturnCode <> pkconstant.success() THEN
		RETURN;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp05801 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip05801 ( l_inUserId TEXT, l_inItakuKaishaCd TEXT, l_inKijunYm TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;
