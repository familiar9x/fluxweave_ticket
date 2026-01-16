




CREATE OR REPLACE FUNCTION sfadi012s1011common ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inKkStat MGR_STS.KK_STAT%TYPE ) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 決済指図 送信処理（ステータス更新）
-- *
-- * @author  磯田
-- * @version $Revision: 1.12 $
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
    gKkPhase            SHINKIKIROKU.KK_PHASE%TYPE;                 -- 機構フェーズ
	gMgrCd			    text := '';	        						-- 銘柄コード
	gItakuKaishaCd 	    text := '';       							-- 委託会社コード
	gJipDenbunCd 	    text := '';         						-- JIP電文コード
	gKessaiNo    	    SHINKIKIROKU.KESSAI_NO%TYPE; 	            -- 決済番号
    gSendRefno          KESSAISASHIZU.SEND_REFNO%TYPE;              -- 送信者ＲＥＦ.ＮＯ
    gShoriCd            KK_RENKEI.ITEM001%TYPE;                     -- 処理コード
    gMasshoFlg          KESSAISASHIZU.MASSHO_FLG%TYPE := '0';  -- 抹消フラグ
	gIsinCd				MGR_KIHON.ISIN_CD%TYPE;						-- ISINコード
    gMgrCnt				integer;									-- 銘柄抹消チェック用
    gChkKkPhase     MGR_KIHON_VIEW.KK_PHASE%TYPE;                   -- 機構フェーズ（チェック用）
    gChkKkStat      MGR_KIHON_VIEW.KK_PHASE%TYPE := '02';           -- 機構ステータス（チェック用）
    gCnt                integer;                                    -- 入金予定件数
    gSql                varchar(400);
    gSql2               varchar(400);
    gSql3               varchar(400);
    gStatCd             varchar(4);                                -- 機構フェーズ || 機構ステータス（取消時用）
    sqlCount            integer := 0;                              -- UPDATE affected rows
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI012S1011COMMON';
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
   	-- 機構連携テーブル、委託会社マスタより 委託会社コード、銘柄コードを取得する 
	BEGIN
		CALL pkKkNotice.getKK_Itaku(
			l_inKkSakuseiDt,
			l_inDenbunMeisaiNo,
			gItakuKaishaCd,
			gJipDenbunCd,
			gMgrCd
		);
	EXCEPTION
		WHEN no_data_found THEN
			RETURN pkconstant.NO_DATA_FIND();
		WHEN OTHERS THEN
			RAISE;
	END;
    -- 機構連携テーブルから送信者リファレンスＮｏ、処理コード、ISINコード取得 
	gSql := 'SELECT TRIM(ITEM004),TRIM(ITEM005), TRIM(ITEM021) FROM KK_RENKEI '
		|| ' WHERE '
      	|| ' KK_SAKUSEI_DT = ''' ||l_inKkSakuseiDt || ''''
      	|| ' AND DENBUN_MEISAI_NO = '''|| l_inDenbunMeisaiNo || '''';
	EXECUTE gSql INTO STRICT gSendRefno, gShoriCd, gIsinCd;
	-- 銘柄_基本ビューを検索し、銘柄コードの存在チェックを行う。 
	BEGIN
		SELECT
			VMG1.MGR_CD
		INTO STRICT
			gMgrCd
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE
			VMG1.ITAKU_KAISHA_CD = gItakuKaishaCd
			AND VMG1.ISIN_CD = gIsinCd;
	EXCEPTION
		WHEN no_data_found THEN
			CALL pkLog.error('ECM3A3', SP_ID, 'ISINコード：' || gIsinCd || 'は銘柄基本に存在しません。');
			RETURN pkconstant.NO_DATA_FIND();
		WHEN OTHERS THEN
			RAISE;
	END;
    -- 処理コードが'NEWM'（新規、訂正）なら抹消区分='0'、'CANC'（取消）なら抹消区分='1'をセット 
    IF gShoriCd = 'NEWM' THEN
        gMasshoFlg := '0';
    ELSE
        gMasshoFlg := '1';
    END IF;
    -- 決済指図から決済番号を取得 
    gSql2 := 'SELECT DISTINCT KESSAI_NO FROM KESSAISASHIZU '
        || ' WHERE '
      	|| ' ITAKU_KAISHA_CD = ''' || gItakuKaishaCd || ''''
      	|| ' AND SEND_REFNO = '''|| gSendRefno || ''''
        || ' AND MASSHO_FLG = '''|| gMasshoFlg || '''';
	EXECUTE gSql2 INTO STRICT gKessaiNo;
    -- 処理コードが'NEWM'（新規、訂正）なら抹消区分='0'、'CANC'（取消）なら抹消区分='1'をセット 
    IF gShoriCd = 'NEWM' THEN
        -- 機構フェーズを'H2'に更新（そのまま） 
        gKkPhase := 'H2';
        --
--         * 機構フェーズ='H2'、機構ステータス='02'なら更新OK
--         
        gChkKkPhase := 'H2';
    ELSE
        -- 入金予定テーブルにデータがあるかチェックする。
        SELECT
            COUNT(*)
        INTO STRICT
            gCnt
        FROM
            NYUKIN_YOTEI B03
        WHERE
            B03.ITAKU_KAISHA_CD = gItakuKaishaCd
        AND B03.KESSAI_NO = gKessaiNo;
        -- 入金予定テーブルにデータがなければ、機構フェーズを'H3'に更新 
        IF gCnt = 0 THEN
            gKkPhase := 'H3';
        -- 入金予定テーブルにデータがあれば、機構フェーズを'H5'に更新 
        ELSE
            gKkPhase := 'H5';
        END IF;
        --
--         * 機構フェーズ='H3'、機構ステータス='02'なら更新OK
--         
        gChkKkPhase := 'H3';
    END IF;
    -- 通常の送信処理のとき 
    IF l_inKkStat = pkKkNotice.MGR_KKSTAT_SEND() THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'送信処理を行います。');
        CALL pkLog.DEBUG(USER_ID,SP_ID,'新規記録情報の機構フェーズ、機構ステータスを更新します。');
        -- 新規記録情報テーブルのステータスを更新 
        gSql3 := 'UPDATE SHINKIKIROKU'
            || ' SET '
            || ' KK_PHASE = $1,'
            || ' KK_STAT = $2'
            || ' WHERE '
          	|| ' ITAKU_KAISHA_CD = $3'
          	|| ' AND KESSAI_NO = $4'
          	|| ' AND KK_PHASE = $5'
          	|| ' AND KK_STAT = $6'
          	|| ' AND MASSHO_FLG = ''0''';
    	-- Execute dynamic SQL using EXECUTE with parameters
        EXECUTE gSql3 
        USING gKkPhase, l_inKkStat, gItakuKaishaCd, gKessaiNo, gChkKkPhase, gChkKkStat;
        GET DIAGNOSTICS sqlCount = ROW_COUNT;
    -- 送信取消処理のとき 
    ELSE
        -- 新規記録情報より、機構ステータス、機構フェーズを取得 
        SELECT
            B04.KK_PHASE || B04.KK_STAT
        INTO STRICT
            gStatCd
        FROM
            SHINKIKIROKU B04
        WHERE
            B04.ITAKU_KAISHA_CD = gItakuKaishaCd
        AND B04.KESSAI_NO = gKessaiNo;
        -- 
--         * 'H302'のときは、ステータスを更新する。
--         * 入金予定が存在する場合は'H503'へ
--         * 入金予定が存在しない場合は'H303'へ
--         
        IF gStatCd = 'H302' THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'送信取消処理を行います。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'新規記録情報の機構フェーズ、機構ステータス、機構警告・エラーコードを更新します。');
            UPDATE
                SHINKIKIROKU
            SET
                KK_PHASE = gKkPhase,
                KK_STAT = pkKkNotice.MGR_KKSTAT_SEND(),
                KK_KEIKOKU_ERR_CD = '2'
            WHERE
                ITAKU_KAISHA_CD = gItakuKaishaCd
            AND MASSHO_FLG = '0'
            AND KK_PHASE = 'H3'
            AND KK_STAT = '02';
        -- 'H303','H503'のときは、機構警告・エラーコードを更新する。 
        ELSIF gStatCd IN ('H303','H503') THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'送信取消処理を行います。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'新規記録情報の機構警告・エラーコードを更新します。');
            UPDATE
                SHINKIKIROKU
            SET
                KK_KEIKOKU_ERR_CD = '2'
            WHERE
                ITAKU_KAISHA_CD = gItakuKaishaCd
            AND MASSHO_FLG = '0'
            AND KK_PHASE || KK_STAT IN ('H303','H503');
        -- 'H202'または'H203'のとき、かつ処理コードが'NEWM'の場合は決済指図テーブルの承認解除抑制フラグを更新。  
        ELSIF gStatCd IN ('H202','H203') AND gShoriCd = 'NEWM' THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'送信取消処理を行います。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'決済指図の承認解除抑制フラグを更新します。');
            UPDATE
                KESSAISASHIZU
            SET
                SHONIN_KAIJO_YOKUSEI_FLG = '0'
            WHERE
                ITAKU_KAISHA_CD = gItakuKaishaCd
            AND SEND_REFNO = gSendRefno;
        END IF;
        GET DIAGNOSTICS sqlCount = ROW_COUNT;
    END IF;
    
    -- 更新件数チェック 
    IF sqlCount = 0 THEN
        CALL pkLog.error('ECM3A3', SP_ID, '新規記録情報');
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
	-- データ無し 
	WHEN no_data_found THEN
    	CALL pkLog.error('ECM3A3', SP_ID, '対象データ無し');
		RETURN pkconstant.NO_DATA_FIND();
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi012s1011common ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inKkStat MGR_STS.KK_STAT%TYPE ) FROM PUBLIC;