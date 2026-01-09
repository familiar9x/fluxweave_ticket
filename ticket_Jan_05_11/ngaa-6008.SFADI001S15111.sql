
CREATE OR REPLACE FUNCTION sfadi001s15111 ( l_inKkSakuseiDt varchar(20), l_inDenbunMeisaiNo numeric ) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄情報登録データ 送信処理（ステータス更新）
-- * 銘柄_ステータステーブルのステータス区分を「送信済」に更新します。
-- *
-- * @author  磯田
-- * @version $Revision: 1.3 $
-- * @param  	l_inKkSakuseiDt 	IN 	KK_RENKEI.KK_SAKUSEI_DT%TYPE	機構連携作成日時
-- * @param  	l_inDenbunMeisaiNo 	IN 	KK_RENKEI.DENBUN_MEISAI_NO%TYPE	電文明細Ｎｏ
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()				: 正常
-- *   		 pkconstant.NO_DATA_FIND()	 	: 突合相手なし
-- *   		 pkconstant.RECONCILE_ERROR()		: 突合エラー
-- *           pkconstant.FATAL() 			 	: 致命的エラー
-- 
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
--====================================================================*
--                  変数定義
-- *====================================================================
 	result		integer;				-- 本ＳＰのリターンコード
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI001S15111';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
    -- 機構ステータス
    UPDATE_KK_STAT      CONSTANT varchar(2)  := pkKkNotice.MGR_KKSTAT_SEND();
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
    -- 銘柄情報登録データ 送信処理（ステータス更新）共通ＳＰをＣＡＬＬ   
    result := SFADI001S1511COMMON(l_inKkSakuseiDt,l_inDenbunMeisaiNo,UPDATE_KK_STAT);
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, 'ステータス更新SP  result = ' || result);	END IF;
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTRING(SQLERRM FROM 1 FOR 100));
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi001s15111 ( l_inKkSakuseiDt varchar(20), l_inDenbunMeisaiNo numeric ) FROM PUBLIC;

