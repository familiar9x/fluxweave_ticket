CREATE OR REPLACE FUNCTION sfadi010s0711common (
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inKkStat MGR_STS.KK_STAT%TYPE
) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 資金振替済通知（新規記録）ファイル 送信処理（ステータス更新）
-- *
-- * @author  磯田
-- * @version $Revision: 1.10 $
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
	gMgrCd			    MGR_KIHON.MGR_CD%TYPE;		        	-- 銘柄コード
	gItakuKaishaCd 	    MGR_KIHON.ITAKU_KAISHA_CD%TYPE;	        -- 委託会社コード
	gJipDenbunCd 	    KK_RENKEI.JIP_DENBUN_CD%TYPE;           -- JIP電文コード
	gSknFurizumiRefno   NYUKIN_YOTEI.SKN_FURIZUMI_REFNO%TYPE;   -- 資金振替済通知REF.NO
	gKessaiNo    	    SHINKIKIROKU.KESSAI_NO%TYPE; 	        -- 決済番号
	gDairiMotionFlg     NYUKIN_YOTEI.DAIRI_MOTION_FLG%TYPE;     -- 代理人直接申請フラグ
	gChkKkPhase         MGR_KIHON_VIEW.KK_PHASE%TYPE := 'H6';   -- 機構フェーズ（チェック用）
	gTable              varchar(30);
	gTableNm            varchar(30);
	gSql                varchar(400);
	gSql1               varchar(400);
	gSql2               varchar(400);
	gSql3               varchar(400);
	gSql4               varchar(400);
	cSql                integer;
	gNyukinYoteiMgrCd	NYUKIN_YOTEI.MGR_CD%TYPE;					-- 入金予定TBLから取得した銘柄コード
	gCount				numeric := (0);							-- 入金予定TBLの対象データ件数
	sqlCount            numeric;
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI010S0711COMMON';
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
	IF coalesce(trim(both l_inKkSakuseiDt::text), '') = ''
	  OR coalesce(trim(both l_inDenbunMeisaiNo::text), '') = ''
      OR coalesce(trim(both l_inKkStat::text), '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
   	-- 機構連携テーブル、委託会社マスタより 委託会社コード、銘柄コードを取得する 
	CALL pkKkNotice.getKK_Itaku(
		l_inKkSakuseiDt,
		l_inDenbunMeisaiNo,
		gItakuKaishaCd,
		gJipDenbunCd,
		gMgrCd
	);
    -- 機構連携テーブルから決済番号（リンケージリファレンスNo）、送信者リファレンスＮｏ取得 
	gSql := 'SELECT TRIM(both ITEM008),TRIM(both ITEM009) FROM KK_RENKEI '
		|| ' WHERE '
      	|| ' KK_SAKUSEI_DT = ''' || coalesce(l_inKkSakuseiDt, '') || ''''
      	|| ' AND DENBUN_MEISAI_NO = '''|| l_inDenbunMeisaiNo || '''';
	EXECUTE gSql INTO STRICT gKessaiNo, gSknFurizumiRefno;
	-- 入金予定テーブルのデータ存在チェック 
	gSql1 := 'SELECT COUNT(CTID) FROM NYUKIN_YOTEI '
		|| ' WHERE '
    	|| ' ITAKU_KAISHA_CD = ''' || gItakuKaishaCd || ''''
    	|| ' AND KESSAI_NO = '''|| coalesce(gKessaiNo, '') || ''''
		|| ' AND SKN_FURIZUMI_REFNO	= '''|| coalesce(gSknFurizumiRefno, '') || '''';
	EXECUTE gSql1 INTO STRICT gCount;
	IF gCount < 1 THEN
		CALL pkLog.error('ECM3A3', SP_ID, '入金予定テーブル該当データなし');
		return pkconstant.NO_DATA_FIND();
	END IF;
    -- 入金予定テーブルから代理人直接申請フラグ取得 
	gSql2 := 'SELECT DAIRI_MOTION_FLG, MGR_CD FROM NYUKIN_YOTEI '
		|| ' WHERE '
      	|| ' ITAKU_KAISHA_CD = ''' || gItakuKaishaCd || ''''
      	|| ' AND KESSAI_NO = '''|| coalesce(gKessaiNo, '') || ''''
      	|| ' AND SKN_FURIZUMI_REFNO	= '''|| coalesce(gSknFurizumiRefno, '') || '''';
	EXECUTE gSql2 INTO STRICT gDairiMotionFlg, gNyukinYoteiMgrCd;
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
			AND VMG1.MGR_CD = gNyukinYoteiMgrCd;
	EXCEPTION
		WHEN no_data_found THEN
			CALL pkLog.error('ECM3A3', SP_ID, '銘柄コード：' || gNyukinYoteiMgrCd || 'は銘柄基本に存在しません。');
			RETURN pkconstant.NO_DATA_FIND();
		WHEN OTHERS THEN
			RAISE;
	END;
    --
--     * 機構フェーズ='H6'、機構ステータス='02'なら更新OK
--     
    -- 代理人直接申請フラグが'1'なら新規募集情報、それ以外なら新規記録情報にステータスを更新する。 
    IF trim(both gDairiMotionFlg) = '1' THEN
        gTable := 'SHINKIBOSHU';
        gTableNm := '新規募集情報';
    ELSE
        gTable := 'SHINKIKIROKU';
        gTableNm := '新規記録情報';
    END IF;
    -- 通常の送信処理のとき 
    IF l_inKkStat = pkKkNotice.MGR_KKSTAT_SEND() THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'送信処理を行います。');
        CALL pkLog.DEBUG(USER_ID,SP_ID, gTableNm || 'の機構フェーズ、機構ステータスを更新します。');
        gSql3 := 'UPDATE ' || gTable
            || ' SET '
            || ' KK_STAT = :kkStat'
            || ' WHERE '
          	|| ' SHORI_KBN = ''1'''
          	|| ' AND KK_PHASE = :chkKkPhase'
          	|| ' AND KK_STAT = :chkKkStat'
          	|| ' AND ITAKU_KAISHA_CD = :itakuKaishaCd'
          	|| ' AND KESSAI_NO = :kessaiNo'
          	|| ' AND MASSHO_FLG = ''0''';
        IF trim(both gDairiMotionFlg) = '1' THEN
            gSql3 := gSql3 || ' AND MGR_CD = :mgrCd';
        END IF;
    	cSql := DBMS_SQL.OPEN_CURSOR();
        -- バインド変数割り当て 
    	CALL DBMS_SQL.PARSE(cSql,gSql3);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':kkStat',l_inKkStat);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':itakuKaishaCd',gItakuKaishaCd);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':kessaiNo',gKessaiNo);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':chkKkPhase',gChkKkPhase);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':chkKkStat',pkKkNotice.MGR_KKSTAT_SHONIN());
        IF trim(both gDairiMotionFlg) = '1' THEN
        	CALL DBMS_SQL.BIND_VARIABLE(cSql,':mgrCd',gNyukinYoteiMgrCd);
        END IF;
        sqlCount := DBMS_SQL.EXECUTE(cSql);
    	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
    -- 送信取消処理のとき 
    ELSE
        CALL pkLog.DEBUG(USER_ID,SP_ID,'送信取消処理を行います。');
        CALL pkLog.DEBUG(USER_ID,SP_ID, gTableNm || 'の承認解除抑制フラグを更新します。');
        gSql3 := 'UPDATE ' || gTable
            || ' SET '
            || ' SHONIN_KAIJO_YOKUSEI_FLG = ''0'''
            || ' WHERE '
          	|| ' SHORI_KBN = ''1'''
          	|| ' AND KK_PHASE = :chkKkPhase'
          	|| ' AND KK_STAT IN ( :chkKkStat ,:chkKkStat2 )'
          	|| ' AND ITAKU_KAISHA_CD = :itakuKaishaCd'
          	|| ' AND KESSAI_NO = :kessaiNo'
          	|| ' AND MASSHO_FLG = ''0''';
        IF trim(both gDairiMotionFlg) = '1' THEN
            gSql3 := gSql3 || ' AND MGR_CD = :mgrCd';
        END IF;
    	cSql := DBMS_SQL.OPEN_CURSOR();
        -- バインド変数割り当て 
    	CALL DBMS_SQL.PARSE(cSql,gSql3);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':itakuKaishaCd',gItakuKaishaCd);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':kessaiNo',gKessaiNo);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':chkKkPhase',gChkKkPhase);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':chkKkStat',pkKkNotice.MGR_KKSTAT_SHONIN());
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':chkKkStat2',pkKkNotice.MGR_KKSTAT_SEND());
        IF trim(both gDairiMotionFlg) = '1' THEN
        	CALL DBMS_SQL.BIND_VARIABLE(cSql,':mgrCd',gNyukinYoteiMgrCd);
        END IF;
        sqlCount := DBMS_SQL.EXECUTE(cSql);
    	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
    END IF;
    -- 更新件数チェック 
    IF sqlCount = 0 THEN
		CALL pkLog.error('ECM3A3', SP_ID, gTableNm);
        -- 通常の送信処理なら突合相手なし'40'、取消の送信処理なら取消不可ステータス'60'を返す。 
        IF l_inKkStat = pkKkNotice.MGR_KKSTAT_SEND() THEN
        	result := pkconstant.NO_DATA_FIND();
        ELSE
            result := pkconstant.CAN_NOT_CANC_KKSTAT();
        END IF;
	ELSE
		result := pkconstant.success();
	END IF;
    -- 上記の更新処理が正常で取消の場合は入金予定テーブルの承認解除抑制フラグを更新 
    IF result = pkconstant.success() AND l_inKkStat = '02' THEN
        gSql4 := 'UPDATE NYUKIN_YOTEI'
            || ' SET '
            || ' SHONIN_KAIJO_YOKUSEI_FLG = ''0'''
            || ' WHERE '
          	|| ' ITAKU_KAISHA_CD = :itakuKaishaCd'
          	|| ' AND KESSAI_NO = :kessaiNo'
          	|| ' AND SKN_FURIZUMI_REFNO = :sknFurizumiRefno';
    	cSql := DBMS_SQL.OPEN_CURSOR();
        -- バインド変数割り当て 
    	CALL DBMS_SQL.PARSE(cSql,gSql4);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':itakuKaishaCd',gItakuKaishaCd);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':kessaiNo',gKessaiNo);
    	CALL DBMS_SQL.BIND_VARIABLE(cSql,':sknFurizumiRefno',gSknFurizumiRefno);
        -- 更新件数チェック 
    	IF DBMS_SQL.EXECUTE(cSql) = 0 THEN
    		CALL pkLog.error('ECM3A3', SP_ID, '入金予定');
    		result := pkconstant.NO_DATA_FIND();
    	ELSE
	    	result := pkconstant.success();
    	END IF;
       	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
    END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, 'ステータス更新SP  result = ' || result);	END IF;
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
        -- 例外発生時にカーソルがオープンしたままならクローズする。 
        IF cSql IS NOT NULL AND DBMS_SQL.IS_OPEN(cSql) THEN
        	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
        END IF;
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi010s0711common ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inKkStat MGR_STS.KK_STAT%TYPE ) FROM PUBLIC;
