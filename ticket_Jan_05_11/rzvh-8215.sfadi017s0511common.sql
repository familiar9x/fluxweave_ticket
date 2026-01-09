




CREATE OR REPLACE FUNCTION sfadi017s0511common ( 
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, 
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, 
    l_inKkStat MGR_STS.KK_STAT%TYPE ) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄情報変更ファイル 送信処理（ステータス更新）
-- * 期中銘柄情報変更（銘柄）、期中銘柄情報変更（利払）、期中銘柄情報変更（償還）へ
-- * ステータス更新を行います。
-- * 機構連携テーブルからデータを取得し、取得したデータが次のとき、各テーブルへ更新します。
-- *
-- * 期中銘柄情報変更（銘柄）
-- * 海外カレンダチェックフラグ、機構関与チェックフラグ、個別承認チェックフラグの
-- * いずれかが'1'のとき。
-- *
-- * 期中銘柄情報変更（利払）
-- * 利払チェックフラグが'1'のとき。
-- *
-- * 期中銘柄情報変更（償還）
-- * 定時償還チェックフラグが'1'かつ定時償還（利払）期日に期日がセットされているとき。
-- *  　銘柄情報変更区分が'20'（定時定額償還）,'21'（定時不定額償還）のデータを更新。
-- *　　期中銘柄情報変更（償還）テーブルにある区分を更新（同期日には存在しないため）
-- *
-- * コールオプション（全額償還）チェックフラグが'1'のとき。
-- * 　銘柄情報変更区分が'40'（コールオプション（全額償還））のデータを更新。
-- *
-- * 定時償還チェックフラグが'1'かつコールオプション（一部償還）コールオプション行使フラグが'Y'のとき。
-- * 　銘柄情報変更区分が'41'（コールオプション（一部償還））のデータを更新。
-- *
-- * プットオプションチェックフラグが'1'のとき。
-- * 　銘柄情報変更区分が'50'（プットオプション）のデータを更新。
--
-- * 満期償還チェックフラグが'1'のとき。
-- * 　銘柄情報変更区分が'10'（満期償還）のデータを更新。
-- *
-- * @author  磯田
-- * @version $Revision: 1.9 $
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
	DEBUG	integer	:= 1;
--====================================================================*
--                  変数定義
-- *====================================================================
 	result		integer;				-- ＳＰのリターンコード
-- 銘柄コード 
	gMgrCd			MGR_KIHON.MGR_CD%TYPE;
-- 委託会社コード 
	gItakuKaishaCd 	MGR_KIHON.ITAKU_KAISHA_CD%TYPE;
-- 定時償還通知区分 
    gTeijiShokanTsutiKbn MGR_KIHON.TEIJI_SHOKAN_TSUTI_KBN%TYPE;
-- 機構連携テーブルROWTYPE 
    rRT02           RECORD;
-- ＳＱＬ用 
    gSql varchar(500);
-- ＳＱＬ用 
    cSql numeric;
-- テーブル名 
    gTable              varchar(30);
-- テーブル名（日本語） 
    gTableNm            varchar(30);
-- 支払期日 
    gShrKjt UPD_MGR_KHN.SHR_KJT%TYPE;
--====================================================================*
--					定数定義
-- *====================================================================
-- SPID 
	SP_ID				CONSTANT text := 'SFADI017S0511COMMON';
-- ユーザID 
	USER_ID				CONSTANT text := pkconstant.BATCH_USER();
-- 帳票ID 
	REPORT_ID			CONSTANT text := '';
-- 銘柄情報 
	MG21_MEIGARA CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '01';
-- 利払情報 
    MG22_RBR CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '02';
-- 満期償還 
    MG23_MANKI CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '10';
-- 定時定額償還 
    MG23_TEIJI_TEIGAKU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '20';
-- 定時不定額償還 
    MG23_TEIJI_FUTEIGAKU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '21';
-- コールオプション（全額） 
    MG23_CALL_ALL CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '40';
-- コールオプション（一部） 
    MG23_CALL_ITIBU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '41';
-- プットオプション 
    MG23_PUT CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '50';
-- 定時償還通知区分 
    TEIJI_SHOKAN_TSUTI_KBN_KICHU CONSTANT MGR_KIHON.TEIJI_SHOKAN_TSUTI_KBN%TYPE := 'V';
--====================================================================*
--					カーソル定義
-- *====================================================================
 -- 業務日付の直近の期中銘柄情報変更（銘柄）のデータを取得する。 
    cUpdMgrKhn CURSOR(
            l_inItakuKaishaCd  UPD_MGR_SHN.ITAKU_KAISHA_CD%TYPE,
            l_inMgrCd  UPD_MGR_SHN.MGR_CD%TYPE,
            l_inGyomuYmd  UPD_MGR_SHN.SHR_KJT%TYPE
        ) FOR
        SELECT
            trim(both MIN(MG21.SHR_KJT)) AS SHR_KJT
        FROM
            UPD_MGR_KHN MG21
        WHERE
            MG21.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MG21.SHR_KJT >= l_inGyomuYmd
        AND MG21.MGR_CD = l_inMgrCd;
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
    	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKkSakuseiDt)::text, '') = ''
	  OR coalesce(trim(both l_inDenbunMeisaiNo::text)::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
   	-- 機構連携テーブル、委託会社マスタより 委託会社コードを取得する 
	CALL pkKkNotice.getKK_Itaku(
		l_inKkSakuseiDt,
		l_inDenbunMeisaiNo,
		gItakuKaishaCd
	);
    -- 機構連携テーブルよりＩＳＩＮコード、期日、各チェックフラグを取得します。 
    SELECT
        RT02.ITEM005,                           -- ＩＳＩＮコード
        RT02.ITEM008,                           -- 海外カレンダチェックフラグ
        RT02.ITEM009,                           -- 海外カレンダ利払期日
        RT02.ITEM011,                           -- 機構関与チェックフラグ
        RT02.ITEM013,                           -- 個別承認チェックフラグ
        RT02.ITEM015,                           -- 利払チェックフラグ
        RT02.ITEM016,                           -- 利払　利払期日
        RT02.ITEM019,                           -- コールオプション（全額償還）チェックフラグ
        RT02.ITEM021,                           -- コールオプション（全額償還）繰上償還期日
        RT02.ITEM024,                           -- 定時償還チェックフラグ
        RT02.ITEM025,                           -- 定時償還定時償還（利払）期日
        RT02.ITEM028,                           -- コールオプション（一部償還）コールオプション行使フラグ
        RT02.ITEM029,                           -- コールオプション（一部償還）繰上償還期日
        RT02.ITEM034,                           -- プットオプションチェックフラグ
        RT02.ITEM038,                           -- プットオプション繰上償還期日
        RT02.ITEM059                            -- 満期償還チェックフラグ
    INTO STRICT
        rRT02
    FROM
        KK_RENKEI RT02
    WHERE
        RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
    AND RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;
    -- 銘柄基本ＶＩＥＷから委託会社、ＩＳＩＮコードをキーにして銘柄コード取得 
	BEGIN
	    SELECT
	        MG1.MGR_CD,
	        MG1.TEIJI_SHOKAN_TSUTI_KBN
	    INTO STRICT
	        gMgrCd,
	        gTeijiShokanTsutiKbn
	    FROM
	        MGR_KIHON_VIEW MG1
	    WHERE
	        MG1.ITAKU_KAISHA_CD = gItakuKaishaCd
	    AND MG1.ISIN_CD = rRT02.ITEM005;
	EXCEPTION
		WHEN no_data_found THEN
			CALL pkLog.error('ECM3A3', SP_ID, 'ISINコード：' || rRT02.ITEM005 || 'は銘柄基本に存在しません。');
			RETURN pkconstant.NO_DATA_FIND();
		WHEN OTHERS THEN
			RAISE;
	END;
    -- 各期中銘柄情報変更へ更新する条件を満たしていれば、更新する *
--
--    /* 海外カレンダチェックフラグ、機構関与チェックフラグ、個別承認チェックフラグの
--     * いずれかが、'1' なら期中銘柄情報変更（銘柄）の更新を行う。
--     
    IF '1' IN (rRT02.ITEM008,rRT02.ITEM011,rRT02.ITEM013) THEN
        -- 海外カレンダの更新を行わない場合は日付データが電文上にないため業務日付の直近の日付のデータを更新する。 
        IF coalesce(trim(both rRT02.ITEM009)::text, '') = '' THEN
            -- 業務日付の直近の日付を取得 
            FOR rUpdMgrShn IN cUpdMgrKhn(gItakuKaishaCd,gMgrCd,pkDate.getGyomuYmd) LOOP
                gShrKjt := rUpdMgrShn.SHR_KJT;
            END LOOP;
            result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,gShrKjt,MG21_MEIGARA,l_inKkStat,gTeijiShokanTsutiKbn);
        ELSE
        -- 海外カレンダ利払期日があれば、そのまま使う 
        result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,rRT02.ITEM009,MG21_MEIGARA,l_inKkStat,gTeijiShokanTsutiKbn);
        END IF;
        IF result <> pkconstant.success() THEN
            RETURN result;
        END IF;
    END IF;
    -- 利払チェックフラグが'1'なら期中銘柄情報変更（利払）の更新を行う。 
    IF rRT02.ITEM015 = '1' THEN
        result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,rRT02.ITEM016,MG22_RBR,l_inKkStat,gTeijiShokanTsutiKbn);
        IF result <> pkconstant.success() THEN
            RETURN result;
        END IF;
    END IF;
    -- 定時償還チェックフラグが'1'かつ定時償還定時償還（利払）期日がセットされていれば、
--     * 期中銘柄情報変更（償還）の銘柄情報変更区分='20'もしくは'21'のデータの更新を行う。
--     
    IF rRT02.ITEM024 = '1' AND (trim(both rRT02.ITEM025) IS NOT NULL AND (trim(both rRT02.ITEM025))::text <> '') THEN
        -- 定時定額償還、定時不定額償還は同じ期日に存在することはないので'20','21'をセット。 
        result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,rRT02.ITEM025,MG23_TEIJI_TEIGAKU,l_inKkStat,gTeijiShokanTsutiKbn);
        IF result <> pkconstant.success() THEN
            RETURN result;
        END IF;
    END IF;
    -- コールオプション（全額償還）チェックフラグが'1'なら、
--     * 期中銘柄情報変更（償還）の銘柄情報変更区分='40'（コールオプション（全額償還））のデータの更新を行う。
--     
    IF rRT02.ITEM019 = '1' THEN
        result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,rRT02.ITEM021,MG23_CALL_ALL,l_inKkStat,gTeijiShokanTsutiKbn);
        IF result <> pkconstant.success() THEN
            RETURN result;
        END IF;
    END IF;
    -- 定時償還チェックフラグが'1'かつコールオプション（一部償還）コールオプション行使フラグが'Y'なら、
--     * 期中銘柄情報変更（償還）の銘柄情報変更区分='41'（コールオプション（一部償還））のデータの更新を行う。
--     
    IF rRT02.ITEM024 = '1' AND rRT02.ITEM028 = 'Y' THEN
        result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,rRT02.ITEM029,MG23_CALL_ITIBU,l_inKkStat,gTeijiShokanTsutiKbn);
        IF result <> pkconstant.success() THEN
            RETURN result;
        END IF;
    END IF;
    -- プットオプションチェックフラグが'1'なら
--     * 期中銘柄情報変更（償還）の銘柄情報変更区分='50'（プットオプション）のデータの更新を行う。
--     
    IF rRT02.ITEM034 = '1' THEN
        result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,rRT02.ITEM038,MG23_PUT,l_inKkStat,gTeijiShokanTsutiKbn);
        IF result <> pkconstant.success() THEN
            RETURN result;
        END IF;
    END IF;
    -- 満期償還チェックフラグが'1'なら
--     * 期中銘柄情報変更（償還）の銘柄情報変更区分='10'（満期償還）のデータの更新を行う。
--     
    IF rRT02.ITEM059 = '1' THEN
        result := SFADI017S0511COMMON_sfUpdateUpdMgrXXX(gItakuKaishaCd,gMgrCd,rRT02.ITEM059,MG23_MANKI,l_inKkStat,gTeijiShokanTsutiKbn);
        IF result <> pkconstant.success() THEN
            RETURN result;
        END IF;
    END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, 'ステータス更新SP  result = ' || result);	END IF;
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || ' ' || SUBSTR(SQLERRM, 1, 100));
		RETURN result;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi017s0511common ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inKkStat MGR_STS.KK_STAT%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi017s0511common_checkdummydata ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, gTeijiShokanTsutiKbn MGR_KIHON.TEIJI_SHOKAN_TSUTI_KBN%TYPE ) RETURNS integer AS $body$
DECLARE

        cnt numeric;
        result integer;
        TEIJI_SHOKAN_TSUTI_KBN_KICHU CONSTANT MGR_KIHON.TEIJI_SHOKAN_TSUTI_KBN%TYPE := 'V';
        MG23_TEIJI_TEIGAKU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '20';
        MG23_TEIJI_FUTEIGAKU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '21';
        MG23_CALL_ITIBU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '41';

BEGIN
        result := pkconstant.error();
        -- 定時償還通知区分'V'（期中に通知)のとき 
        IF gTeijiShokanTsutiKbn = TEIJI_SHOKAN_TSUTI_KBN_KICHU THEN
            SELECT
                COUNT(*)
            INTO STRICT
                cnt
            FROM
                MGR_SHOKIJ MG3
            WHERE
                MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND MG3.MGR_CD          = l_inMgrCd
            AND MG3.SHOKAN_KJT      = l_inShrKjt
            AND MG3.SHOKAN_KBN  IN (MG23_TEIJI_TEIGAKU,MG23_TEIJI_FUTEIGAKU,MG23_CALL_ITIBU);
            -- 銘柄_償還回次にデータが存在しなければ、ダミーデータ 
            IF cnt = 0 THEN
                result := pkconstant.success();
            ELSE
                result := pkconstant.error();
            END IF;
        -- それ以外はダミーデータは作成されない。 
        ELSE
            result := pkconstant.error();
        END IF;
        RETURN result;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi017s0511common_checkdummydata ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi017s0511common_sfupdateupdmgrxxx ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE, l_inKkStat MGR_STS.KK_STAT%TYPE, gTeijiShokanTsutiKbn MGR_KIHON.TEIJI_SHOKAN_TSUTI_KBN%TYPE ) RETURNS integer AS $body$
DECLARE
        gSql text;
        gTable varchar(30);
        gTableNm varchar(30);
        result integer;
        row_count integer;
        SP_ID CONSTANT text := 'SFADI017S0511COMMON';
        MG21_MEIGARA CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '01';
        MG22_RBR CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '02';
        MG23_MANKI CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '10';
        MG23_TEIJI_TEIGAKU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '20';
        MG23_TEIJI_FUTEIGAKU CONSTANT UPD_MGR_KHN.MGR_HENKO_KBN%TYPE := '21';
BEGIN
        -- 文字列の初期化 
        gSql := '';
        gTable := NULL;
        -- 銘柄情報変更区分によって更新するテーブルを変える 
        CASE l_inMgrHenkoKbn
            WHEN MG21_MEIGARA THEN
                gTable := 'UPD_MGR_KHN';
                gTableNm := '期中銘柄情報変更（銘柄）';
            WHEN MG22_RBR THEN
                gTable := 'UPD_MGR_RBR';
                gTableNm := '期中銘柄情報変更（利払）';
            ELSE
                gTable := 'UPD_MGR_SHN';
                gTableNm := '期中銘柄情報変更（償還）';
        END CASE;
        gSql := 'UPDATE ' || gTable
            || ' SET '
            || ' KK_STAT = $1';
        -- 取消の場合は承認解除抑制フラグ='0'(解除可能)に設定する 
        IF l_inKkStat = '02' THEN
            gSql := gSql || ' ,SHONIN_KAIJO_YOKUSEI_FLG = ''0''';
        END IF;
        gSql := gSql || ' WHERE '
          	|| ' ITAKU_KAISHA_CD = $2'
          	|| ' AND (MGR_HENKO_KBN = $3';
        -- 定時定額の場合は定時不定額とどちらかしか同期日に存在しない。 
        IF l_inMgrHenkoKbn = MG23_TEIJI_TEIGAKU THEN
            gSql := gSql || ' OR MGR_HENKO_KBN = $4';
        END IF;
        gSql := gSql || ' )';
	-- 満期償還以外の時は支払期日を設定する。
--		 * 満期償還の時は電文に期日がない。
--		 * ただ、満期償還の時は期中銘柄は1件しかないので条件に指定しなくても問題はない。
--		 
	IF l_inMgrHenkoKbn != MG23_MANKI THEN
		gSql := gSql || ' AND SHR_KJT = $' || CASE WHEN l_inMgrHenkoKbn = MG23_TEIJI_TEIGAKU THEN '5' ELSE '4' END;
	END IF;
	gSql := gSql || ' AND MGR_CD = $' || CASE WHEN l_inMgrHenkoKbn = MG23_TEIJI_TEIGAKU THEN '6' WHEN l_inMgrHenkoKbn != MG23_MANKI THEN '5' ELSE '4' END;
        -- バインド変数割り当てと実行 - 満期償還以外の時は支払期日を設定する。
        -- 満期償還の時は電文に期日がない。
        -- ただ、満期償還の時は期中銘柄は1件しかないので条件に指定しなくても問題はない。
        IF l_inMgrHenkoKbn = MG23_TEIJI_TEIGAKU THEN
            EXECUTE gSql USING l_inKkStat, l_inItakuKaishaCd, l_inMgrHenkoKbn, MG23_TEIJI_FUTEIGAKU, l_inShrKjt, l_inMgrCd;
        ELSIF l_inMgrHenkoKbn != MG23_MANKI THEN
            EXECUTE gSql USING l_inKkStat, l_inItakuKaishaCd, l_inMgrHenkoKbn, l_inShrKjt, l_inMgrCd;
        ELSE
            EXECUTE gSql USING l_inKkStat, l_inItakuKaishaCd, l_inMgrHenkoKbn, l_inMgrCd;
        END IF;
        GET DIAGNOSTICS row_count = ROW_COUNT;
        -- 更新件数チェック 
    	IF row_count = 0 THEN
            --
--             * 利払間隔と償還間隔が異なる場合、（利払年２回、償還年１回など）は、
--             * 電文中に定時償還のダミーデータが存在するので、更新されていなくてもＯＫ
--             * （実際には銘柄_償還回次に該当の期日での回次が存在しない。）
--             
            IF SFADI017S0511COMMON_checkDummyData(l_inItakuKaishaCd,l_inMgrCd,l_inShrKjt,gTeijiShokanTsutiKbn) = pkconstant.success() THEN
        		result := pkconstant.success();
            ELSE
        		CALL pkLog.error('ECM3A3', SP_ID, gTableNm);
        		result := pkconstant.NO_DATA_FIND();
            END IF;
    	ELSE
    		result := pkconstant.success();
    	END IF;
        RETURN result;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi017s0511common_sfupdateupdmgrxxx ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE ) FROM PUBLIC;