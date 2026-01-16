CREATE OR REPLACE FUNCTION sfadi002r04120 (
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE
) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄情報変更結果通知（エラー）処理
-- * 期中銘柄情報変更（ＮＮ）より、承認し、機構へ送信したデータがあった場合に、
-- * 銘柄情報変更結果通知（エラー）を受信する。
-- * このＳＰは銘柄情報変更結果通知（エラー）を受信したときに起動されるＳＰです。
-- * 現状の仕様では、機構フェーズ、機構ステータスにかかわらず、取り込み処理は可能です。
-- *
-- * 機構連携の電文データより、
-- * 該当する銘柄情報変更のデータの承認解除抑制フラグのクリアと銘柄機構エラーコードにエラーありをセットします。
-- * また、電文より取得したエラーコードをメッセージ通知に出力します。
-- *
-- * @author  磯田
-- * @version $Id: SFADI002R04120.sql,v 1.7 2021/09/10 08:59:55 hoshino Exp $
-- * @param  	l_inKkSakuseiDt 	IN 	KK_RENKEI.KK_SAKUSEI_DT%TYPE	機構連携作成日時
-- * @param  	l_inDenbunMeisaiNo 	IN 	KK_RENKEI.DENBUN_MEISAI_NO%TYPE	電文明細Ｎｏ
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()				: 正常
-- *   		 pkconstant.NO_DATA_FIND()		: 突合相手なし
-- *           pkconstant.FATAL() 				: SQLエラー
-- 
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
--====================================================================*
--                  変数定義
-- *====================================================================
	result			integer;			-- 本ＳＰのリターンコード
    gWkRtn          integer;
	gGyomuYmd		SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;	-- 業務日付
    gShrKjt         UPD_MGR_KHN.SHR_KJT%TYPE;   -- 支払期日
	gItakuKaishaCd		MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;		-- 委託会社コード
	gItakuKaishaRnm		MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE;	-- 委託会社略称
	gJipDenbunCd 		KK_RENKEI.JIP_DENBUN_CD%TYPE;  		-- JIP電文コード
	gMgrCd				MGR_KIHON.MGR_CD%TYPE;				-- 銘柄コード
	gMgrRnm				MGR_KIHON.MGR_RNM%TYPE;				-- 銘柄略称
    -- 機構連携テーブルROWTYPE 
    rRT02           RECORD;
    msg varchar(500) := '';
    gUpdFlg         numeric :=0;                 -- 更新フラグ（0:更新なし   1:更新あり)
    gTotsugoFlg     numeric :=0;                 -- 突合フラグ（0:正常       1:更新不可ステータスあり)
    
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI002R04120';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
	-- メッセージ通知書き込み内容 
	COND_TSUCHI_CATEGORY CONSTANT char(8) := '機構連携';
	COND_TSUCHI_LEVEL    CONSTANT varchar(8) := '警告';
	COND_BEEP_FLG        CONSTANT char(1) := '0';
	COND_KIDOKU_FLG      CONSTANT char(1) := '0';

    tempResult record;
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	 IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKkSakuseiDt::text), '') = ''
	  OR coalesce(trim(both l_inDenbunMeisaiNo::text), '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
   	-- 機構連携テーブル、委託会社マスタより 委託会社コード等を取得 
	CALL pkKkNotice.getKK_ItakuR(
		l_inKkSakuseiDt,
		l_inDenbunMeisaiNo,
		gItakuKaishaCd,
		gJipDenbunCd,
		gItakuKaishaRnm
	);
	-- 電文コードのチェック
	IF gJipDenbunCd != 'R0412' THEN
		-- 電文コードエラー
		CALL pkLog.error('ECM3A4', SP_ID, gJipDenbunCd);
		RETURN result;
	END IF;
	-- 業務日付取得 
	gGyomuYmd := pkDate.getGyomuYmd();
    CALL SFADI002R04120_getKkData(l_inKkSakuseiDt, l_inDenbunMeisaiNo, rRT02);
    tempResult := SFADI002R04120_validateData(l_inKkSakuseiDt,
                                        l_inDenbunMeisaiNo,
                                        gItakuKaishaCd,
                                        USER_ID,
                                        SP_ID,
                                        rRT02,
                                        COND_TSUCHI_CATEGORY,
                                        COND_TSUCHI_LEVEL,
                                        COND_BEEP_FLG,
                                        COND_KIDOKU_FLG,
                                        msg);
    result := tempResult.extra_param;
    -- データチェックで正常でなければリターン 
    IF result != pkconstant.success() THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'データチェックエラー ISINコード、または支払代理人コードがエラー');
        RETURN result;
    END IF;
    -- 銘柄基本ＶＩＥＷから委託会社、ＩＳＩＮコードをキーにして銘柄コード、銘柄略称取得 
    SELECT
        MG1.MGR_CD,
        MG1.MGR_RNM
    INTO STRICT
        gMgrCd,
        gMGrRnm
    FROM
        MGR_KIHON_VIEW MG1
    WHERE
        MG1.ITAKU_KAISHA_CD = gItakuKaishaCd
    AND MG1.ISIN_CD = rRT02.tempitem005;
    -- 各期日がセットされていたら、それぞれの変更情報について突合を行う。 
    --
--     * 海外カレンダ　利払期日、機構関与方式採用フラグ、個別承認採用フラグの
--     * いずれかの値がセットされているときは、期中銘柄情報変更（銘柄）へ更新をする
--     
    IF (rRT02.tempitem009 IS NOT NULL AND rRT02.tempitem009::text <> '') OR (rRT02.tempitem012 IS NOT NULL AND rRT02.tempitem012::text <> '') OR (rRT02.tempitem014 IS NOT NULL AND rRT02.tempitem014::text <> '') THEN
        IF (rRT02.tempitem009 IS NOT NULL AND rRT02.tempitem009::text <> '') THEN CALL pkLog.DEBUG(USER_ID,SP_ID,'海外カレンダ　利払期日がセットされているため、期中銘柄情報変更（銘柄）を更新します。');END IF;
        IF (rRT02.tempitem012 IS NOT NULL AND rRT02.tempitem012::text <> '') THEN CALL pkLog.DEBUG(USER_ID,SP_ID,'機構関与方式採用フラグがセットされているため、期中銘柄情報変更（銘柄）を更新します。');END IF;
        IF (rRT02.tempitem014 IS NOT NULL AND rRT02.tempitem014::text <> '') THEN CALL pkLog.DEBUG(USER_ID,SP_ID,'個別承認採用フラグがセットされているため、期中銘柄情報変更（銘柄）を更新します。');END IF;
        -- 海外カレンダの更新を行わない場合は日付データが電文上にないため業務日付の直近の日付のデータを更新する。 
        IF coalesce(rRT02.tempitem009::text, '') = '' THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'業務日付の直近の期中銘柄情報変更（銘柄）の該当銘柄のデータより、支払日を取得します。');
            -- 業務日付の直近の日付を取得 
            SELECT
                trim(both MIN(MG21.SHR_KJT)) AS SHR_KJT
            INTO STRICT
                gShrKjt
            FROM
                UPD_MGR_KHN MG21
            WHERE
                MG21.ITAKU_KAISHA_CD = gItakuKaishaCd
            AND MG21.SHR_KJT >= gGyomuYmd
            AND MG21.MGR_CD = gMgrCd;
        ELSE
            -- 海外カレンダ利払期日があれば、そのまま使う 
            gShrKjt := rRT02.tempitem009;
        END IF;
        -- 引数に突合結果のリターンを加え、機構エラーコードを更新するかどうかを判断する 
        tempResult := SFADI002R04120_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,gShrKjt,pkKkNotice.MGR_HENKO_KHN(),result, rRT02, USER_ID, SP_ID, gUpdFlg);
        gUpdFlg := tempResult.gUpdFlg;
        result := tempResult.extra_param;
        -- 更新に失敗したときはエラーコードを返す 
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（銘柄）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || gShrKjt);
            RETURN result;
        END IF;
    END IF;
    -- 利払　利払期日がセットされているときは、銘柄_利払回次の情報と突合を行う。
    IF (rRT02.tempitem016 IS NOT NULL AND rRT02.tempitem016::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'利払　利払期日がセットされているため、期中銘柄情報変更（利払）を更新します。');
        tempResult := SFADI002R04120_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.tempitem016,pkKkNotice.MGR_HENKO_RBR(),result, rRT02, USER_ID, SP_ID, gUpdFlg);
        gUpdFlg := tempResult.gUpdFlg;
        result := tempResult.extra_param;
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（利払）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.tempitem016);
            RETURN result;
        END IF;
    END IF;
    -- コールオプション（全額償還）　繰上償還期日がセットされているとき 
    IF (rRT02.tempitem021 IS NOT NULL AND rRT02.tempitem021::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（全額償還）　繰上償還期日がセットされているため、期中銘柄情報変更（償還）を更新します。');
        tempResult := SFADI002R04120_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.tempitem021,pkKkNotice.MGR_HENKO_CALL_A(),result, rRT02, USER_ID, SP_ID, gUpdFlg);
        gUpdFlg := tempResult.gUpdFlg;
        result := tempResult.extra_param;
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（全額償還）処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.tempitem021);
            RETURN result;
        END IF;
    END IF;
    -- コールオプション（一部償還）　繰上償還期日がセットされているとき 
    IF (rRT02.tempitem029 IS NOT NULL AND rRT02.tempitem029::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（一部償還）　繰上償還期日がセットされているため、期中銘柄情報変更（償還）を更新します。');
        tempResult := SFADI002R04120_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.tempitem029,pkKkNotice.MGR_HENKO_CALL_P(),result, rRT02, USER_ID, SP_ID, gUpdFlg);
        gUpdFlg := tempResult.gUpdFlg;
        result := tempResult.extra_param;
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（一部償還）処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.tempitem029);
            RETURN result;
        END IF;
    END IF;
    -- 定時償還期日がセットされているとき 
    IF (rRT02.tempitem025 IS NOT NULL AND rRT02.tempitem025::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'定時償還期日がセットされているため、期中銘柄情報変更（償還）を更新します。');
        -- 定時償還は、定時定額償還または、定時不定額償還 
        tempResult := SFADI002R04120_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.tempitem025,pkKkNotice.MGR_HENKO_TEIJI_T(),result, rRT02, USER_ID, SP_ID, gUpdFlg);
        gUpdFlg := tempResult.gUpdFlg;
        result := tempResult.extra_param;
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'定時償還処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.tempitem025);
            RETURN result;
        END IF;
    END IF;
    -- プットオプション　繰上償還期日がセットされているとき 
    IF (rRT02.tempitem038 IS NOT NULL AND rRT02.tempitem038::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'プットオプション　繰上償還期日がセットされているため、期中銘柄情報変更（償還）を更新します。');
        tempResult := SFADI002R04120_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.tempitem038,pkKkNotice.MGR_HENKO_PUT(),result, rRT02, USER_ID, SP_ID, gUpdFlg);
        gUpdFlg := tempResult.gUpdFlg;
        result := tempResult.extra_param;
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'プットオプション処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.tempitem038);
            RETURN result;
        END IF;
    END IF;
	-- 満期償還　償還プレミアムがセットされているとき 
	IF (rRT02.tempitem054 IS NOT NULL AND rRT02.tempitem054::text <> '') THEN
		CALL pkLog.debug(USER_ID,SP_ID,'満期償還　償還プレミアムがセットされているため、期中銘柄情報変更（償還）を更新します。');
		-- 支払期日を電文上に持っていないので期中銘柄変更（償還）から支払期日を取得する。
		SELECT
			trim(both MAX(MG23.SHR_KJT))
			INTO STRICT
				gShrKjt
			FROM
				UPD_MGR_SHN MG23
			WHERE MG23.ITAKU_KAISHA_CD = gItakuKaishaCd
			AND   MG23.MGR_CD          = gMgrCd
			AND   MG23.MGR_HENKO_KBN   = pkKkNotice.MGR_HENKO_MANKI();
		tempResult := SFADI002R04120_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd, gShrKjt, pkKkNotice.MGR_HENKO_MANKI(), result, rRT02, USER_ID, SP_ID, gUpdFlg);
		gUpdFlg := tempResult.gUpdFlg;
        result := tempResult.extra_param;
		IF result <> pkconstant.success() THEN
			CALL pkLog.debug(USER_ID, SP_ID, '期中銘柄情報変更（償還）への更新に失敗しました。');
			CALL pkLog.debug(USER_ID, SP_ID, '満期償還日処理');
			CALL pkLog.debug(USER_ID, SP_ID, '委託会社コード: ' || gItakuKaishaCd);
			CALL pkLog.debug(USER_ID, SP_ID, '銘柄コード: ' || gMgrCd);
			CALL pkLog.debug(USER_ID, SP_ID, '償還プレミアム: ' || rRT02.tempitem054);
			RETURN result;
		END IF;
	END IF;
    -- 今まで何も更新処理がなければエラー 
    IF gUpdFlg = 0 THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'更新処理が行われませんでした。');
        CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
        CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
        CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.tempitem038);
        result := pkconstant.NO_DATA_FIND();
    END IF;
    msg := NULL;
    -- メッセージ編集
    -- 期中銘柄情報変更結果通知エラー (銘柄コード:XXXXXXXXXXXXX エラーコード:XXXX)
    msg := '期中銘柄情報変更結果通知エラー (銘柄コード:' || gMgrCd || ' エラーコード:' || rRT02.tempitem006 || ')';
    -- 処理が正常、異常に関わらずメッセージ通知に出力をする 
    gWkRtn := SFIPMSGTSUCHIUPDATE(
                        gItakuKaishaCd,
                        COND_TSUCHI_CATEGORY,
                        COND_TSUCHI_LEVEL,
                        COND_BEEP_FLG,
                        COND_KIDOKU_FLG,
                        msg,
                        USER_ID,
                        USER_ID
                        );
    -- FATALの場合のみ         
    IF gWkRtn = pkconstant.FATAL() THEN
        CALL pkLog.DEBUG('ECM701',SP_ID,'メッセージ通知出力処理でエラーが発生しました。');
    END IF;
        -- 常に取り込めるようにする。
--    /* 期中銘柄情報変更データのいずれかが、更新できるステータスでない場合は突合エラーにする */
--    IF gTotsugoFlg = 1 THEN
--        pkLog.DEBUG(USER_ID,SP_ID,'更新できるステータスではないものが存在します。');
--        pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
--        pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
--        pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.tempitem038);
--        result := pkconstant.RECONCILE_ERROR();
--    END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04120 ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04120_checkstatus (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    USER_ID varchar(10),
    SP_ID varchar(20)
) RETURNS integer AS $body$
DECLARE

        rtn integer;
        status varchar(4);

BEGIN
        rtn := pkconstant.FATAL();
        -- 銘柄情報変更区分によってチェックするテーブルを変える 
        CASE l_inMgrHenkoKbn
            WHEN pkKkNotice.MGR_HENKO_KHN() THEN
                status := SFADI002R04120_getUpdMgrKhnStatus(l_inItakuKaishaCd,l_inMgrCd,l_inShrKjt,l_inMgrHenkoKbn, USER_ID, SP_ID);
            WHEN pkKkNotice.MGR_HENKO_RBR() THEN
                status := SFADI002R04120_getUpdMgrRbrStatus(l_inItakuKaishaCd,l_inMgrCd,l_inShrKjt,l_inMgrHenkoKbn, USER_ID, SP_ID);
            ELSE
                status := SFADI002R04120_getUpdMgrShnStatus(l_inItakuKaishaCd,l_inMgrCd,l_inShrKjt,l_inMgrHenkoKbn, USER_ID, SP_ID);
        END CASE;
        -- 更新できるステータスかどうかチェックする 
        IF status = 'M203' THEN
            rtn := pkconstant.success();
        ELSE
            rtn := pkconstant.RECONCILE_ERROR();
        END IF;
        RETURN rtn;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04120_checkstatus ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04120_getkkdata (
    l_inKkSakuseiDt character,
    l_inDenbunMeisaiNo integer,
    rRT02 OUT record
) AS $body$
DECLARE
    tempITEM005 text;
    tempITEM006 text;
    tempITEM009 text;
    tempITEM012 text;
    tempITEM014 text;
    tempITEM016 text;
    tempITEM021 text;
    tempITEM025 text;
    tempITEM028 text;
    tempITEM029 text;
    tempITEM038 text;
    tempITEM054 text;
BEGIN
        -- 機構連携テーブルよりＩＳＩＮコード、期日を取得します。 
        SELECT
            trim(both RT02.ITEM005),                                     -- ＩＳＩＮコード
            trim(both RT02.ITEM006),                                     -- エラーコード
            trim(both RT02.ITEM009),                                     -- 海外カレンダ利払期日
            trim(both RT02.ITEM012),                                     -- 機構関与方式採用フラグ
            trim(both RT02.ITEM014),                                     -- 個別承認採用フラグ
            trim(both RT02.ITEM016),                                     -- 利払　利払期日
            trim(both RT02.ITEM021),                                     -- コールオプション（全額償還）　繰上償還期日
            trim(both RT02.ITEM025),                                     -- 定時償還　定時償還（利払）期日
            trim(both RT02.ITEM028),                                     -- コールオプション（一部償還）　コールオプション行使フラグ
            trim(both RT02.ITEM029),                                     -- コールオプション（一部償還）　繰上償還期日
            trim(both RT02.ITEM038),                                     -- プットオプション　繰上償還期日
            trim(both RT02.ITEM054)                                      -- 満期償還　償還プレミアム
        INTO STRICT
            tempITEM005,                           				-- ＩＳＩＮコード
            tempITEM006,                           				-- エラーコード
            tempITEM009,                           				-- 海外カレンダ利払期日
            tempITEM012,                           				-- 機構関与方式採用フラグ
            tempITEM014,                           				-- 個別承認採用フラグ
            tempITEM016,                           				-- 利払　利払期日
            tempITEM021,                           				-- コールオプション（全額償還）　繰上償還期日
            tempITEM025,                           				-- 定時償還　定時償還（利払）期日
            tempITEM028,                           				-- コールオプション（一部償還）　コールオプション行使フラグ
            tempITEM029,                           				-- コールオプション（一部償還）　繰上償還期日
            tempITEM038,                           				-- プットオプション　繰上償還期日
            tempITEM054                           				-- 満期償還　償還プレミアム
        FROM
            KK_RENKEI RT02
        WHERE
            RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
        AND RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;

        -- Build record using SELECT INTO (PostgreSQL will lowercase all unquoted identifiers in RECORD)
        SELECT 
            tempITEM005, 
            tempITEM006, 
            tempITEM009, 
            tempITEM012, 
            tempITEM014, 
            tempITEM016,
            tempITEM021, 
            tempITEM025, 
            tempITEM028, 
            tempITEM029, 
            tempITEM038, 
            tempITEM054
        INTO rRT02;
        
        RETURN;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04120_getkkdata () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04120_getupdmgrkhnstatus (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    USER_ID varchar(10),
    SP_ID varchar(20)
) RETURNS varchar AS $body$
DECLARE

        -- 機構フェーズ、ステータス 
        status varchar(4);

BEGIN
        BEGIN     
            SELECT
                trim(both KK_PHASE) || trim(both KK_STAT)
            INTO STRICT
                status
            FROM
                UPD_MGR_KHN
            WHERE
                ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND MGR_CD          = l_inMgrCd
            AND SHR_KJT         = l_inShrKjt
            AND MGR_HENKO_KBN   = l_inMgrHenkoKbn;
        EXCEPTION
            WHEN no_data_found THEN
                CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更データが見つかりません。');
                CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード： ' || l_inItakuKaishaCd);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード　　： ' || l_inMgrCd);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'支払期日　　　： ' || l_inShrKjt);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄変更区分　： ' || l_inMgrHenkoKbn);
                status := '';
        END;
        RETURN status;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04120_getupdmgrkhnstatus ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04120_getupdmgrrbrstatus (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    USER_ID varchar(10),
    SP_ID varchar(20)
) RETURNS varchar AS $body$
DECLARE

        -- 機構フェーズ、ステータス 
        status varchar(4);

BEGIN
        BEGIN     
            SELECT
                trim(both KK_PHASE) || trim(both KK_STAT)
            INTO STRICT
                status
            FROM
                UPD_MGR_KHN
            WHERE
                ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND MGR_CD          = l_inMgrCd
            AND SHR_KJT         = l_inShrKjt
            AND MGR_HENKO_KBN   = l_inMgrHenkoKbn;
        EXCEPTION
            WHEN no_data_found THEN
                CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更データが見つかりません。');
                CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード： ' || l_inItakuKaishaCd);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード　　： ' || l_inMgrCd);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'支払期日　　　： ' || l_inShrKjt);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄変更区分　： ' || l_inMgrHenkoKbn);
                status := '';
        END;
        RETURN status;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04120_getupdmgrrbrstatus ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04120_getupdmgrshnstatus (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    USER_ID varchar(10),
    SP_ID varchar(20)
) RETURNS varchar AS $body$
DECLARE

        -- 機構フェーズ、ステータス 
        status varchar(4);

BEGIN
        BEGIN     
            SELECT
                trim(both KK_PHASE) || trim(both KK_STAT)
            INTO STRICT
                status
            FROM
                UPD_MGR_KHN
            WHERE
                ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND MGR_CD          = l_inMgrCd
            AND SHR_KJT         = l_inShrKjt
            AND MGR_HENKO_KBN   = l_inMgrHenkoKbn;
        EXCEPTION
            WHEN no_data_found THEN
                CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更データが見つかりません。');
                CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード： ' || l_inItakuKaishaCd);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード　　： ' || l_inMgrCd);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'支払期日　　　： ' || l_inShrKjt);
                CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄変更区分　： ' || l_inMgrHenkoKbn);
                status := '';
        END;
        RETURN status;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04120_getupdmgrshnstatus ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04120_updateupdmgrxxx (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    l_inErrCd integer,
    rRT02 record,
    USER_ID varchar(10),
    SP_ID varchar(20),
    gUpdFlg IN OUT numeric,
    extra_param OUT integer
) RETURNS record AS $body$
DECLARE

        rtn integer;
        -- ＳＱＬ用 
        gSql varchar(500);
        -- ＳＱＬ用 
        cSql integer;
        -- テーブル名 
        gTable              varchar(30);
        -- テーブル名（日本語） 
        gTableNm            varchar(30);

BEGIN
        -- 文字列の初期化 
        gSql := '';
        gTable := NULL;
        rtn := pkconstant.FATAL();
        -- 銘柄情報変更区分によって更新するテーブルを変える 
        CASE l_inMgrHenkoKbn
            WHEN pkKkNotice.MGR_HENKO_KHN() THEN
                gTable := 'UPD_MGR_KHN';
                gTableNm := '期中銘柄情報変更（銘柄）';
            WHEN pkKkNotice.MGR_HENKO_RBR() THEN
                gTable := 'UPD_MGR_RBR';
                gTableNm := '期中銘柄情報変更（利払）';
            ELSE
                gTable := 'UPD_MGR_SHN';
                gTableNm := '期中銘柄情報変更（償還）';
        END CASE;
        -- 常に取り込めるようにする。
--        rtn := sfadi002r04120_checkstatus(l_inItakuKaishaCd,l_inMgrCd,l_inShrKjt,l_inMgrHenkoKbn, USER_ID, SP_ID);
        
--        -- 更新できる状態('M203')であれば更新処理をする。
--        IF rtn = pkconstant.success() THEN
            gSql := 'UPDATE ' || gTable
                || ' SET '
                || ' KK_STAT = :kkStat'
                || ' , MGR_KK_ERR_CD = ''' || pkKkNotice.MGR_KKERR_ERR() || ''''
                || ' ,SHONIN_KAIJO_YOKUSEI_FLG = ''0'''
                || ' WHERE '
              	|| ' ITAKU_KAISHA_CD = :itakuKaishaCd'
              	|| ' AND MGR_CD = :mgrCd'
                || ' AND SHR_KJT = :shrKjt ';
            -- 定時定額の場合は定時不定額とどちらかしか同期日に存在しない。 
            IF l_inMgrHenkoKbn = pkKkNotice.MGR_HENKO_TEIJI_T() THEN
                gSql := gSql || ' AND MGR_HENKO_KBN IN ( :mgrHenkoKbn , :mgrHenkoKbn2 ) ';
            ELSE
            -- その他は１つの銘柄変更区分でよい 
                gSql := gSql || ' AND MGR_HENKO_KBN = :mgrHenkoKbn ';
            END IF;
        	cSql := DBMS_SQL.OPEN_CURSOR();
            -- バインド変数割り当て 
        	CALL DBMS_SQL.PARSE(cSql,gSql);
        	CALL DBMS_SQL.BIND_VARIABLE(cSql,':kkStat',pkKkNotice.MGR_KKSTAT_FIN());
        	CALL DBMS_SQL.BIND_VARIABLE(cSql,':itakuKaishaCd',l_inItakuKaishaCd);
        	CALL DBMS_SQL.BIND_VARIABLE(cSql,':mgrCd',l_inMgrCd);
        	CALL DBMS_SQL.BIND_VARIABLE(cSql,':shrKjt',l_inShrKjt);
        	CALL DBMS_SQL.BIND_VARIABLE(cSql,':mgrHenkoKbn',l_inMgrHenkoKbn);
            IF l_inMgrHenkoKbn = pkKkNotice.MGR_HENKO_TEIJI_T() THEN
            	CALL DBMS_SQL.BIND_VARIABLE(cSql,':mgrHenkoKbn2',pkKkNotice.MGR_HENKO_TEIJI_F());
            END IF;
            -- 更新件数チェック 
        	IF DBMS_SQL.EXECUTE(cSql) = 0 THEN
                --
--                 * 定時定額償還、または定時不定額償還で更新件数0件のとき、
--                 * コールオプション（一部償還）行使フラグが立っているときは正常とみなす。
--                 * 機構の電文フォーマット上、コールオプション（一部償還）の変更時に
--                 * 定時償還期日に値が入る可能性があるため。
--                 
                IF l_inMgrHenkoKbn IN (pkKkNotice.MGR_HENKO_TEIJI_T(),pkKkNotice.MGR_HENKO_TEIJI_F())
                    AND (rRT02.tempitem028 IS NOT NULL AND rRT02.tempitem028::text <> '') AND rRT02.tempitem028 = 'Y' THEN
               		CALL pkLog.DEBUG(USER_ID, SP_ID, '定時償還の更新に失敗しましたが、コールオプション（一部）行使フラグがたっているので無視します。');
                    rtn := pkconstant.success();
                ELSE
               		CALL pkLog.error('ECM3A3', SP_ID, gTableNm);
               		rtn := pkconstant.NO_DATA_FIND();
                END IF;
        	ELSE
                gUpdFlg := 1;
        		rtn := pkconstant.success();
        	END IF;
           	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
        -- 常に取り込めるようにする。
--        -- 更新不可ステータス    
--        ELSE
--            pkLog.DEBUG(USER_ID,SP_ID,'更新できるステータス(M203)ではないので更新処理は行いません。突合エラーになります。');
--            gTotsugoFlg := 1;
--        END IF;
        extra_param := rtn;
        RETURN;
    EXCEPTION
        WHEN OTHERS THEN
            -- 例外発生時にカーソルがオープンしたままならクローズする。 
            IF cSql IS NOT NULL AND DBMS_SQL.IS_OPEN(cSql) THEN
            	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
            END IF;
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04120_updateupdmgrxxx ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE, l_inErrCd integer ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04120_validatedata (
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
    gItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE,
    USER_ID varchar(10),
    SP_ID varchar(20),
    rRT02 record,
    COND_TSUCHI_CATEGORY char(8),
    COND_TSUCHI_LEVEL varchar(8),
    COND_BEEP_FLG char(1),
    COND_KIDOKU_FLG char(1),
    msg IN OUT varchar(500),
    extra_param OUT integer
) RETURNS record AS $body$
DECLARE
    rtn integer;
BEGIN
        -- ＩＳＩＮコード、支払代理人コードのチェック（エラーの場合は確認リストには出さずメッセージ通知に出す。） 
        rtn := SFADICheckShrdairiCd( l_inKkSakuseiDt,    --  電文作成日
                                        l_inDenbunMeisaiNo, --  電文明細No
                                        5,                  --  ＩＳＩＮコードの入っている機構連携ItemNo
                                        7,                  --  支払い代理人コードの入っている機構連携ItemNo
                                        gItakuKaishaCd,     --  委託会社コード
                                        '1',                --  銘柄基本処理区分（任意）1を入れると承認済みのものだけ
                                        '0' );              --  副受託を抽出するかどうか（任意）1を入れると副受託も対象
        IF rtn = pkconstant.FATAL() THEN
            -- 予期しないエラー
            extra_param := pkconstant.FATAL();
            RETURN;
        END IF;
        IF rtn <> 1 THEN
            CALL pkLog.error(USER_ID, SP_ID, '支払代理人チェックエラー：該当銘柄(ISIN)か、支払代理人がIPAに存在しません');
            CALL pkLog.debug(USER_ID, SP_ID,  'メッセージ通知テーブルに書き込みます');
            -- Insert用のメッセージを作成
            msg := pkIpaMsgKanri.getMessage( 'MSG003', '銘柄情報変更', rRT02.tempitem005 );
            -- メッセージ通知テーブルへInsert
            rtn := SFIPMSGTSUCHIUPDATE(    gItakuKaishaCd,              -- 委託会社コード
                                           COND_TSUCHI_CATEGORY,        -- 通知カテゴリ
                                           COND_TSUCHI_LEVEL,           -- 通知レベル
                                           COND_BEEP_FLG,               -- 警告音フラグ
                                           COND_KIDOKU_FLG,             -- 既読フラグ
                                           msg,                         -- 通知内容
                                           USER_ID,                     -- 更新者
                                           USER_ID                       -- 作成者
                                         );
            -- Insertが成功したときにはISINみつからずエラー
            IF rtn = pkconstant.success() THEN
                CALL pkLog.debug(USER_ID, SP_ID,  'メッセージ通知テーブルに書き込み成功');
                -- ISINみつからずエラー
                extra_param := pkconstant.NO_DATA_FIND_ISIN();
                RETURN;
            ELSE
                CALL pkLog.debug(USER_ID, SP_ID,  'メッセージ通知テーブルに書き込み失敗');
                -- Insert失敗の時にはエラーで返す
                extra_param := pkconstant.FATAL();
                RETURN;
            END IF;
        END IF;
        extra_param := pkconstant.success();
        RETURN;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04120_validatedata () FROM PUBLIC;

