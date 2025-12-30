
CREATE OR REPLACE FUNCTION sfadi001s1511common ( l_inKkSakuseiDt varchar(20), l_inDenbunMeisaiNo numeric, l_inKkStat char(2) ) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄情報登録データ 送信処理（ステータス更新）
-- * 銘柄_ステータステーブルのステータス区分を「送信済」に更新します。
-- *
-- * @author  磯田
-- * @version $Revision: 1.7 $
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
	gMgrCd			char(6);      				-- 銘柄コード
	gItakuKaishaCd 	char(4);	            -- 委託会社コード
	gJipDenbunCd 	varchar(10);  	            -- JIP電文コード
    gChkKkPhase     char(2) := 'M1';       -- 機構フェーズ（チェック用）
    gSql            varchar(400);
    cSql            numeric;
    sqlCount        numeric;
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI001S1511COMMON';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
    	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKkSakuseiDt)::text, '') = ''
	  OR l_inDenbunMeisaiNo IS NULL
      OR coalesce(trim(both l_inKkStat)::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
   	-- 機構連携テーブル、委託会社マスタより 委託会社コード、銘柄コード(社内処理用項目２) を取得する 
	CALL pkKkNotice.getKK_Itaku(
		l_inKkSakuseiDt,
		l_inDenbunMeisaiNo,
		gItakuKaishaCd,
		gJipDenbunCd,
        gMgrCd
	);
    -- 銘柄コードにスペースが含まれている可能性があるので、TRIMしておく 
    gMgrCd := trim(both gMgrCd);
    -- 通常の送信処理のとき 
    IF l_inKkStat = pkKkNotice.MGR_KKSTAT_SEND() THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'送信処理を行います。');
        CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄_ステータスの機構フェーズ、機構ステータスを更新します。');
        --
--         * 機構フェーズ='M1'、機構ステータス='02'なら更新OK
--         
        -- 銘柄_ステータス更新 
        gSql := 'UPDATE MGR_STS MG0 '
            || ' SET '
            || ' MG0.KK_STAT = :kkStat'
            || ' WHERE '
          	|| ' MG0.SHORI_KBN = ''1'''
          	|| ' AND MG0.KK_PHASE = :chkKkPhase'
          	|| ' AND MG0.KK_STAT = :chkKkStat'
          	|| ' AND MG0.ITAKU_KAISHA_CD = :itakuKaishaCd'
          	|| ' AND MG0.MGR_CD = :mgrCd';
    	cSql := DBMS_SQL.OPEN_CURSOR;
        -- バインド変数割り当て 
    	CALL DBMS_SQL.PARSE(cSql,gSql,DBMS_SQL.V7);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':kkStat',l_inKkStat);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':itakuKaishaCd',gItakuKaishaCd);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':mgrCd',gMgrCd);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':chkKkPhase',gChkKkPhase);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':chkKkStat',pkKkNotice.MGR_KKSTAT_SHONIN());
        sqlCount := DBMS_SQL.EXECUTE(cSql);
    	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
    -- 送信取消処理のとき 
    ELSE
        CALL pkLog.DEBUG(USER_ID,SP_ID,'送信取消処理を行います。');
        CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄_ステータスの承認解除抑制フラグを更新します。');
        -- 承認解除抑制フラグを承認解除可能にする。 
        -- 送信待ち（未送信）か送信済み（通知待ち）なら更新可能 
        UPDATE
            MGR_STS MG0
        SET
			MG0.MGR_SEND_TAISHO_FLG = '1',
            MG0.SHONIN_KAIJO_YOKUSEI_FLG = '0'
        WHERE
            MG0.ITAKU_KAISHA_CD = gItakuKaishaCd
        AND MG0.MGR_CD = gMgrCd
        AND MG0.SHORI_KBN = '1'
        AND MG0.KK_PHASE = gChkKkPhase
        AND MG0.KK_STAT IN (pkKkNotice.MGR_KKSTAT_SHONIN(),pkKkNotice.MGR_KKSTAT_SEND());
        GET DIAGNOSTICS sqlCount = ROW_COUNT;
    END IF;
    -- 更新件数チェック 
    IF sqlCount = 0 THEN
    	CALL pkLog.error('ECM3A3', SP_ID, '銘柄ステータス管理');
        -- 通常の送信処理なら突合相手なし'40'、取消の送信処理なら取消不可ステータス'60'を返す。 
        IF l_inKkStat = pkKkNotice.MGR_KKSTAT_SEND() THEN
        	result := pkconstant.NO_DATA_FIND();
        ELSE
            result := pkconstant.CAN_NOT_CANC_KKSTAT();
        END IF;
    ELSE
    	result := pkconstant.success();
    END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, 'ステータス更新SP  result = ' || result);	END IF;
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTRING(SQLERRM FROM 1 FOR 100));
        -- 例外発生時にカーソルがオープンしたままならクローズする。 
        BEGIN
            IF cSql IS NOT NULL THEN
                CALL DBMS_SQL.CLOSE_CURSOR(cSql);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi001s1511common ( l_inKkSakuseiDt varchar(20), l_inDenbunMeisaiNo numeric, l_inKkStat char(2) ) FROM PUBLIC;

