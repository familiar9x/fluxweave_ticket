CREATE OR REPLACE FUNCTION sfadi002r04110 (
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE
) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄情報変更結果通知突合処理
-- *   機構連携テーブル−送信(銘柄情報変更)との突合処理
-- *
-- * @author  藤江
-- * @author  磯田
-- * @version $Id: SFADI002R04110.sql,v 1.15 2021/09/10 08:59:44 hoshino Exp $
-- * @param  	l_inKkSakuseiDt 	IN 	KK_RENKEI.KK_SAKUSEI_DT%TYPE	機構連携作成日時
-- * @param  	l_inDenbunMeisaiNo 	IN 	KK_RENKEI.DENBUN_MEISAI_NO%TYPE	電文明細Ｎｏ
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()				: 正常
-- *   		 pkconstant.error()				: 予期したエラー
-- *   		 pkconstant.NO_DATA_FIND()		: 突合相手なし
-- *   		 pkconstant.RECONCILE_ERROR()		: 突合エラー
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
	curComp 		integer;			-- カーソルＩＤ
	gCompFlg 		integer;			-- 突合結果フラグ(全体)　0:一致  1:不一致
	gCompAllCnt		integer;			-- 検索結果の突合関連の項目数
	gMsg			varchar(100);		-- 確認リストに出力するエラー内容
	gGyomuYmd		SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;	-- 業務日付
    gShrKjt         UPD_MGR_KHN.SHR_KJT%TYPE;   -- 支払期日
	tMoto KK_RENKEI.ITEM001%type[];						-- 比較元
	tSaki KK_RENKEI.ITEM001%type[];						-- 比較先
	gItakuKaishaCd		MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;		-- 委託会社コード
	gItakuKaishaRnm		MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE;	-- 委託会社略称
	gJipDenbunCd 		KK_RENKEI.JIP_DENBUN_CD%TYPE;  		-- JIP電文コード
	gMgrCd				MGR_KIHON.MGR_CD%TYPE;				-- 銘柄コード
	gMgrRnm				MGR_KIHON.MGR_RNM%TYPE;				-- 銘柄略称
	gErrCd				KK_RENKEI.ITEM001%TYPE;				-- 機構連携.エラーコード
	-- 突合情報取得ＳＰパラメータ 
	gInTotsugoNo 	varchar(12);				-- 突合識別番号
	gInCondition 	varchar(4000);				-- 検索条件（突合条件マスタに登録している条件以外）
	gOutSql 		varchar(20000);			-- ＳＱＬ文字列
	gOutItemCnt 	numeric(3);					-- 突合項目数
	gOutItemAtt 	PkCompare.t_ItemAtt_type;	-- 突合項目属性（条件番号、表示項目名）
    
    -- 機構連携テーブルROWTYPE 
    rRT02           RECORD;
    msg varchar(500) := '';
    gTotsugoFlg      varchar(1) := '0';
    gCompErrFlg      varchar(1) := '0';
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI002R04110';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
--	-- SELECT句 (突合条件マスタの登録値)の何番目の項目か
--	-- (突合項目以外の項目の中での番号)
--	POS_MGR_CD			CONSTANT NUMBER(2) := 1;	-- 銘柄_基本.銘柄コード
--	POS_MGR_RNM			CONSTANT NUMBER(2) := 2;	-- 銘柄_基本.銘柄略称
--	POS_ISIN_CD			CONSTANT NUMBER(2) := 3;	-- 機構連携−受信.ＩＳＩＮコード
--	POS_ERR_CD			CONSTANT NUMBER(2) := 4;	-- 機構連携−受信.エラーコード
--
--	POS_SHRKJT_KHN		CONSTANT NUMBER(2) := 5;	-- 機構連携−受信.(海外カレンダ)利払期日
--	POS_SHRKJT_RBR		CONSTANT NUMBER(2) := 6;	-- 機構連携−受信.(利払)利払期日
--	POS_SHRKJT_CALL_A	CONSTANT NUMBER(2) := 7;	-- 機構連携−受信.（償還）コールオプション（全額償還）繰上償還期日
--	POS_SHRKJT_TEIJI	CONSTANT NUMBER(2) := 8;	-- 機構連携−受信.（償還）定時償還（利払）期日
--	POS_SHRKJT_CALL_P	CONSTANT NUMBER(2) := 9;	-- 機構連携−受信.（償還）コールオプション（一部償還）繰上償還期日
--	POS_SHRKJT_PUT		CONSTANT NUMBER(2) := 10;	-- 機構連携−受信.（償還）プットオプション繰上償還期日
--	POS_SOUJU_METHOD_CD CONSTANT NUMBER(2) := 11;	-- 機構連携−受信.送受信方法コード
--	POS_DENBUN_MEISAI	CONSTANT NUMBER(2) := 12;	-- 機構連携−送信.電文明細Ｎｏ
--
--
--	ONLINE_REAL			CONSTANT KK_RENKEI.SOUJU_METHOD_CD%TYPE := 'R';	--送受信方法コード オンラインリアル
--        
    TOTSUGO_NO_KHN      CONSTANT varchar(12) := 'R0411_01';
    TOTSUGO_NO_RBR      CONSTANT varchar(12) := 'R0411_02';
    TOTSUGO_NO_MANKI    CONSTANT varchar(12) := 'R0411_10';
    TOTSUGO_NO_TEIJI    CONSTANT varchar(12) := 'R0411_20';
    TOTSUGO_NO_CALL_A   CONSTANT varchar(12) := 'R0411_40';
    TOTSUGO_NO_CALL_P   CONSTANT varchar(12) := 'R0411_41';
    TOTSUGO_NO_PUT      CONSTANT varchar(12) := 'R0411_50';
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
	IF gJipDenbunCd NOT IN (pkKkNotice.DCD_MGR_CHG_RSLT(),'R0412') THEN
		-- 電文コードエラー
		CALL pkLog.error('ECM3A4', SP_ID, gJipDenbunCd);
		RETURN result;
	END IF;
	-- 業務日付取得  
	gGyomuYmd := pkDate.getGyomuYmd();
    CALL SFADI002R04110_getKkData(l_inKkSakuseiDt, l_inDenbunMeisaiNo, rRT02);
    result := SFADI002R04110_validateData(l_inKkSakuseiDt,
                                        l_inDenbunMeisaiNo,
                                        gItakuKaishaCd,
                                        rRT02,
                                        COND_TSUCHI_CATEGORY,
                                        COND_TSUCHI_LEVEL,
                                        COND_BEEP_FLG,
                                        COND_KIDOKU_FLG,
                                        msg,
                                        USER_ID);
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
    AND MG1.ISIN_CD = rRT02.ITEM005;
    -- 各期日がセットされていたら、それぞれの変更情報について突合を行う。 
    
    -- 
--     * 海外カレンダ　利払期日、機構関与方式採用フラグ、個別承認採用フラグの
--     * いずれかの値がセットされているときは、銘柄_基本の情報と突合を行う
--     
    IF (rRT02.ITEM009 IS NOT NULL AND rRT02.ITEM009::text <> '') OR (rRT02.ITEM012 IS NOT NULL AND rRT02.ITEM012::text <> '') OR (rRT02.ITEM014 IS NOT NULL AND rRT02.ITEM014::text <> '') THEN
        IF (rRT02.ITEM009 IS NOT NULL AND rRT02.ITEM009::text <> '') THEN CALL pkLog.DEBUG(USER_ID,SP_ID,'海外カレンダ　利払期日がセットされているため、銘柄_基本の情報と突合します。');END IF;
        IF (rRT02.ITEM012 IS NOT NULL AND rRT02.ITEM012::text <> '') THEN CALL pkLog.DEBUG(USER_ID,SP_ID,'機構関与方式採用フラグがセットされているため、銘柄_基本の情報と突合します。');END IF;
        IF (rRT02.ITEM014 IS NOT NULL AND rRT02.ITEM014::text <> '') THEN CALL pkLog.DEBUG(USER_ID,SP_ID,'個別承認採用フラグがセットされているため、銘柄_基本の情報と突合します。');END IF;
        -- 海外カレンダの更新を行わない場合は日付データが電文上にないため業務日付の直近の日付のデータを更新する。 
        IF coalesce(rRT02.ITEM009::text, '') = '' THEN
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
            gShrKjt := rRT02.ITEM009;
        END IF;
        tempResult := SFADI002R04110_comp(gItakuKaishaCd, gMgrCd,gShrKjt,pkKkNotice.MGR_HENKO_KHN(),TOTSUGO_NO_KHN, l_inKkSakuseiDt,
                                    l_inDenbunMeisaiNo,
                                    rRT02,
                                    gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt,
                                    gTotsugoFlg,
                                    curComp);
        result := tempResult.extra_param;
        -- 引数に突合結果のリターンを加え、機構エラーコードを更新するかどうかを判断する 
        result := SFADI002R04110_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,gShrKjt,pkKkNotice.MGR_HENKO_KHN(),result);
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
    IF (rRT02.ITEM016 IS NOT NULL AND rRT02.ITEM016::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'利払　利払期日がセットされているため、銘柄_利払回次の情報と突合します。');
        tempResult := SFADI002R04110_comp(gItakuKaishaCd, gMgrCd,rRT02.ITEM016,pkKkNotice.MGR_HENKO_RBR(),TOTSUGO_NO_RBR, l_inKkSakuseiDt,
                                    l_inDenbunMeisaiNo,
                                    rRT02,
                                    gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt,
                                    gTotsugoFlg,
                                    curComp);
        result := tempResult.extra_param;
        result := SFADI002R04110_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.ITEM016,pkKkNotice.MGR_HENKO_RBR(),result);
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（利払）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.ITEM016);
            RETURN result;
        END IF;
    END IF;
    -- コールオプション（全額償還）　繰上償還期日がセットされているとき 
    IF (rRT02.ITEM021 IS NOT NULL AND rRT02.ITEM021::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（全額償還）　繰上償還期日がセットされているため、銘柄_償還回次の情報と突合します。');
        tempResult := SFADI002R04110_comp(gItakuKaishaCd, gMgrCd,rRT02.ITEM021,pkKkNotice.MGR_HENKO_CALL_A(),TOTSUGO_NO_CALL_A, l_inKkSakuseiDt,
                                    l_inDenbunMeisaiNo,
                                    rRT02,
                                    gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt,
                                    gTotsugoFlg,
                                    curComp);
        result := tempResult.extra_param;
        result := SFADI002R04110_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.ITEM021,pkKkNotice.MGR_HENKO_CALL_A(),result);
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（全額償還）処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.ITEM021);
            RETURN result;
        END IF;
    END IF;
    -- コールオプション（一部償還）　繰上償還期日がセットされているとき 
    IF (rRT02.ITEM029 IS NOT NULL AND rRT02.ITEM029::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（一部償還）　繰上償還期日がセットされているため、コールオプション（一部）の情報と突合します。');
        tempResult := SFADI002R04110_comp(gItakuKaishaCd, gMgrCd,rRT02.ITEM029,pkKkNotice.MGR_HENKO_CALL_P(),TOTSUGO_NO_CALL_P, l_inKkSakuseiDt,
                                    l_inDenbunMeisaiNo,
                                    rRT02,
                                    gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt,
                                    gTotsugoFlg,
                                    curComp);
        result := tempResult.extra_param;
        result := SFADI002R04110_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.ITEM029,pkKkNotice.MGR_HENKO_CALL_P(),result);
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'コールオプション（一部償還）処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.ITEM029);
            RETURN result;
        END IF;
    END IF;
    -- 定時償還期日がセットされているとき 
    IF (rRT02.ITEM025 IS NOT NULL AND rRT02.ITEM025::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'定時償還期日がセットされているため、定時償還の情報と突合します。');
        -- 定時償還は、定時定額償還または、定時不定額償還 
        tempResult := SFADI002R04110_comp(gItakuKaishaCd, gMgrCd,rRT02.ITEM025,pkKkNotice.MGR_HENKO_TEIJI_T(),TOTSUGO_NO_TEIJI, l_inKkSakuseiDt,
                                    l_inDenbunMeisaiNo,
                                    rRT02,
                                    gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt,
                                    gTotsugoFlg,
                                    curComp);
        result := tempResult.extra_param;
        result := SFADI002R04110_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.ITEM025,pkKkNotice.MGR_HENKO_TEIJI_T(),result);
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'定時償還処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.ITEM025);
            RETURN result;
        END IF;
    END IF;
    -- プットオプション　繰上償還期日がセットされているとき 
    IF (rRT02.ITEM038 IS NOT NULL AND rRT02.ITEM038::text <> '') THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'プットオプション　繰上償還期日がセットされているため、銘柄_償還回次の情報と突合します。');
        tempResult := SFADI002R04110_comp(gItakuKaishaCd, gMgrCd,rRT02.ITEM038,pkKkNotice.MGR_HENKO_PUT(),TOTSUGO_NO_PUT, l_inKkSakuseiDt,
                                    l_inDenbunMeisaiNo,
                                    rRT02,
                                    gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt,
                                    gTotsugoFlg,
                                    curComp);
        result := tempResult.extra_param;
        result := SFADI002R04110_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd,rRT02.ITEM038,pkKkNotice.MGR_HENKO_PUT(),result);
        IF result <> pkconstant.success() THEN
            CALL pkLog.DEBUG(USER_ID,SP_ID,'期中銘柄情報変更（償還）への更新に失敗しました。');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'プットオプション処理');
            CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
            CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.ITEM038);
            RETURN result;
        END IF;
    END IF;
	-- 満期償還　償還プレミアムがセットされているとき 
	IF (rRT02.ITEM054 IS NOT NULL AND rRT02.ITEM054::text <> '') THEN
		CALL pkLog.debug(USER_ID,SP_ID,'満期償還　償還プレミアムがセットされているため、銘柄_償還回次の情報と突合します。');
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
		tempResult := SFADI002R04110_comp(gItakuKaishaCd, gMgrCd, gShrKjt, pkKkNotice.MGR_HENKO_MANKI(), TOTSUGO_NO_MANKI, l_inKkSakuseiDt,
                                    l_inDenbunMeisaiNo,
                                    rRT02,
                                    gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt,
                                    gTotsugoFlg,
                                    curComp);
        result := tempResult.extra_param;
		result := SFADI002R04110_updateUpdMgrXXX(gItakuKaishaCd, gMgrCd, gShrKjt, pkKkNotice.MGR_HENKO_MANKI(), result);
		IF result <> pkconstant.success() THEN
			CALL pkLog.debug(USER_ID, SP_ID, '期中銘柄情報変更（償還）への更新に失敗しました。');
			CALL pkLog.debug(USER_ID, SP_ID, '満期償還日処理');
			CALL pkLog.debug(USER_ID, SP_ID, '委託会社コード: ' || gItakuKaishaCd);
			CALL pkLog.debug(USER_ID, SP_ID, '銘柄コード: ' || gMgrCd);
			CALL pkLog.debug(USER_ID, SP_ID, '償還プレミアム: ' || rRT02.ITEM054);
			RETURN result;
		END IF;
	END IF;
    -- 今まで何も突合処理がなければエラー 
    IF gTotsugoFlg = '0' THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'突合処理が行われませんでした。');
        CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
        CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
        CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.ITEM038);
        result := pkconstant.NO_DATA_FIND();
    END IF;
    -- 突合不一致が１つでもあれば突合エラーで返す 
    IF gCompErrFlg = '1' THEN
        CALL pkLog.DEBUG(USER_ID,SP_ID,'突合エラーあり');
        CALL pkLog.DEBUG(USER_ID,SP_ID,'委託会社コード: ' || gItakuKaishaCd);
        CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄コード: ' || gMgrCd);
        CALL pkLog.DEBUG(USER_ID,SP_ID,'支払日: ' || rRT02.ITEM038);
		-- 新コード対応
        result := pkconstant.NOMATCH_ERROR();
    END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		IF curComp IS NOT NULL AND DBMS_SQL.IS_OPEN(curComp) THEN
			CALL DBMS_SQL.CLOSE_CURSOR(curComp);
		END IF;
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04110 ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04110_comp (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    l_inTotsugoNo text,
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
    rRT02 record,
    gInTotsugoNo IN OUT varchar(12),
    gInCondition IN OUT varchar(4000),
    gOutSql IN OUT varchar(20000),
    gOutItemCnt IN OUT numeric(3),
    gOutItemAtt IN OUT PkCompare.t_ItemAtt_type,
    gCompAllCnt IN OUT integer,
    gTotsugoFlg IN OUT varchar(1),
    curComp IN OUT integer,
    extra_param OUT integer
) RETURNS record AS $body$
DECLARE

        rtn         integer;
        intCount    integer;
        tempResult  record;

BEGIN
	-- 変数の初期化
        CALL sfadi002r04110_initparam(gInTotsugoNo,
                                    gInCondition,
                                    gOutSql,
                                    gOutItemCnt,
                                    gOutItemAtt,
                                    gCompAllCnt);
	-- 入力パラメータ設定
	gInTotsugoNo := l_inTotsugoNo;
	gInCondition := SFADI002R04110_getCondition(l_inItakuKaishaCd, l_inMgrCd, l_inShrKjt, l_inMgrHenkoKbn, l_inKkSakuseiDt, l_inDenbunMeisaiNo);
	-- ＳＰ実行  ＳＱＬと突合項目数を取得する
	tempResult := pkCompare.getCompareInfo(gInTotsugoNo, gInCondition);
    rtn := tempResult.extra_param;
    gOutSql := tempResult.l_outSql;
    gOutItemCnt := tempResult.l_outItemCnt;
    gOutItemAtt := tempResult.l_outItemAtt;
	IF rtn != 0 THEN
	    extra_param := rtn;
        RETURN;
	END IF;
	gCompAllCnt := gOutItemCnt * 2;
	-- 問い合わせ用のカーソルをオープンする 
	curComp := DBMS_SQL.OPEN_CURSOR();
	-- SELECT SQLを解析 
	CALL DBMS_SQL.PARSE(curComp,gOutSql);
	-- 出力変数を定義 
	CALL sfadi002r04110_definecolumn(curComp, tMoto, tSaki);
	-- 検索実行 
	intCount := DBMS_SQL.EXECUTE(curComp);
	-- FETCH 
	IF DBMS_SQL.FETCH_ROWS(curComp) = 0 THEN
	    -- 該当データがない場合は終了
	    CALL DBMS_SQL.CLOSE_CURSOR(curComp);
	    CALL pkLog.error('ECM3A3', SP_ID, '銘柄_基本VIEW');
	    rtn := pkconstant.NO_DATA_FIND();
	    extra_param := rtn;
        RETURN;
	END IF;
	-- 値を取り出す 
	-- 突合項目以外
	CALL sfadi002r04110_getcolumnvalue();
    	-- 機構連携−受信のエラーコードがスペース、NULL以外なら、終了する　 
    	IF (trim(both rRT02.ITEM006) IS NOT NULL AND (trim(both rRT02.ITEM006::text)) <> '') THEN
    	    CALL pkLog.info(USER_ID, REPORT_ID, '機構連携−受信にエラーがセットされています。エラーコード = ' || rRT02.ITEM006);
            -- 突合済と同じ意味とする 
            gTotsugoFlg := '1';
            extra_param := pkconstant.error();
    	    RETURN;
    	END IF;
	rtn := SFADI002R04110_compareExecute(gOutItemCnt,
                                        curComp,
                                        tMoto,
                                        tSaki,
                                        gOutItemAtt,
                                        USER_ID,
                                        REPORT_ID,
                                        gItakuKaishaCd,
                                        gGyomuYmd,
                                        rRT02,
                                        gMgrCd,
                                        gMgrRnm,
                                        gJipDenbunCd,
                                        gItakuKaishaRnm,
                                        gTotsugoFlg,
                                        gCompFlg,
                                        gCompErrFlg,
                                        gMsg);
	-- カーソル　クローズ 
	CALL DBMS_SQL.CLOSE_CURSOR(curComp);
        extra_param := rtn;
        RETURN;
EXCEPTION
	WHEN	OTHERS	THEN
            -- 例外発生時にカーソルがオープンしたままならクローズする。 
            IF curComp IS NOT NULL AND DBMS_SQL.IS_OPEN(curComp) THEN
            	CALL DBMS_SQL.CLOSE_CURSOR(curComp);
            END IF;
		RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04110_comp ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE, l_inTotsugoNo text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04110_compareexecute (
    gOutItemCnt numeric(3),
    curComp integer,
    tMoto varchar(400)[],
    tSaki varchar(400)[],
    gOutItemAtt PkCompare.t_ItemAtt_type,
    USER_ID varchar(10),
    REPORT_ID varchar(10),
    gItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE,
    gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE,
    rRT02 record,
    gMgrCd MGR_KIHON.MGR_CD%TYPE,
    gMgrRnm MGR_KIHON.MGR_RNM%TYPE,
    gJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE,
    gItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE,
    gTotsugoFlg varchar(1),
    gCompFlg IN OUT integer,
    gCompErrFlg IN OUT varchar(1),
    gMsg IN OUT varchar(100),
    extra_param OUT integer
) RETURNS record AS $body$
BEGIN
    	-- 突合項目
	-- 　比較元、比較先、条件番号の組を１組ずつ取り出し、突合
	-- 　突合項目数繰り返す
	gCompFlg := 0;
	FOR i IN 1 .. gOutItemCnt LOOP
     	CALL DBMS_SQL.COLUMN_VALUE(curComp,i * 2 -1, tMoto[i]);
      	CALL DBMS_SQL.COLUMN_VALUE(curComp,i * 2 , tSaki[i]);
            -- 突合項目マスタの条件番号が９のものは数値項目で、機構からの電文がスペースとなるため、スペースの場合は''0''に置き換える
            IF gOutItemAtt[i].condNo = 9 AND trim(both tMoto[i]) IS NULL THEN
                tMoto[i] := '0';
            END IF;
	    -- 突合項目マスタの条件番号が７の項目は、オンラインリアルのときのみ突合
            -- ７の項目は廃止（突合不要）
--	        IF gOutItemAtt[i].condNo != 7 OR gSoujuMethodCd = ONLINE_REAL THEN
    		-- 突合処理
    		IF coalesce(trim(both tMoto[i]), ' ') != coalesce(trim(both tSaki[i]), ' ') THEN 		-- 不一致のとき
                    
                    -- 機構項目がNULLかつ、ＩＰＡ項目がNULLでなく、
                    -- 突合項目マスタの条件番号が８の項目は正常とする。（機構項目が電文に入らない組み合わせがあるため）
                    IF gOutItemAtt[i].condNo = 8 AND trim(both tMoto[i]) IS NULL AND trim(both tSaki[i]) IS NOT NULL THEN
                        NULL;
                    ELSE
    	    			IF DEBUG = 1 THEN
    	    				CALL pkLog.debug(USER_ID, REPORT_ID, 'NG');
    	                    CALL pkLog.debug(USER_ID, REPORT_ID, 'dispNm' || i || ' = ' || gOutItemAtt[i].dispNm);
    	                    CALL pkLog.debug(USER_ID, REPORT_ID, 'tMoto_' || i || ' = ' || tMoto[i]);
    	                    CALL pkLog.debug(USER_ID, REPORT_ID, 'tSaki_' || i || ' = ' || tSaki[i]);
    	    			END IF;
    					gCompFlg := 1;
                        gCompErrFlg := '1';
    	     			-- 確認リストのエラー内容
    	     			gMsg := gOutItemAtt[i].dispNm;		-- 表示項目名
    	     			IF (gMsg IS NOT NULL AND gMsg::text <> '') THEN
    	    				gMsg := gMsg || 'が';
    	    			END IF;
    	    			gMsg := gMsg || '突合エラーです。';
    	    			-- 確認リスト出力内容を帳票ワークテーブルに登録
    	    			CALL pkKakuninList.insertKakuninData(
    	    					gItakuKaishaCd,
    	    					USER_ID,
    	    					pkKakuninList.CHOHYO_KBN_BATCH(),
    	    					gGyomuYmd,
    	    					gMsg,
    	    					rRT02.ITEM005,
    	    					gMgrCd,
    	    					gMgrRnm,
    	    					tSaki[i],
    	    					tMoto[i],
    	    					gJipDenbunCd,
    	    					gItakuKaishaRnm
    					);
    	    		END IF;
    			END IF;
--            END IF;
	END LOOP;
        gTotsugoFlg := '1';
        -- 不一致がある場合はエラーで返す 
        IF gCompFlg = 1 THEN
            extra_param := pkconstant.error();
            RETURN;
        ELSE
            extra_param := pkconstant.success();
            RETURN;
        END IF;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04110_compareexecute () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04110_definecolumn (
    curComp integer,
    tMoto IN OUT varchar(400),
    tSaki IN OUT varchar(400)
) AS $body$
BEGIN
    	-- 配列初期化
    	FOR i IN 1 .. gOutItemCnt LOOP
    		tMoto[i] := '';
    		tSaki[i] := '';
    	END LOOP;
    	-- 突合項目
    	FOR i IN 1 .. gOutItemCnt LOOP
    	    CALL DBMS_SQL.DEFINE_COLUMN(curComp,i * 2 -1, tMoto[i], 400);
    	    CALL DBMS_SQL.DEFINE_COLUMN(curComp,i * 2 , tSaki[i], 400);
    	END LOOP;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04110_definecolumn () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04110_getcolumnvalue () AS $body$
BEGIN
        NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04110_getcolumnvalue () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04110_getcondition (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE
) RETURNS varchar AS $body$
DECLARE

        condition varchar(4000);

BEGIN
        -- 共通条件 
    	condition := 'VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''''
            || ' AND RT02R.KK_SAKUSEI_DT = ''' || l_inKkSakuseiDt || ''''
            || ' AND RT02R.DENBUN_MEISAI_NO = ' || l_inDenbunMeisaiNo;
        CASE l_inMgrHenkoKbn
            WHEN pkKkNotice.MGR_HENKO_KHN() THEN
                NULL;
            WHEN pkKkNotice.MGR_HENKO_RBR() THEN
                condition := condition || ' AND MG2.RBR_KJT = ''' || l_inShrKjt || '''';
            WHEN pkKkNotice.MGR_HENKO_TEIJI_T() THEN
                condition := condition || ' AND MG3.SHOKAN_KJT = ''' || l_inShrKjt || '''';
            WHEN pkKkNotice.MGR_HENKO_TEIJI_F() THEN
                condition := condition || ' AND MG3.SHOKAN_KJT = ''' || l_inShrKjt || '''';
            WHEN pkKkNotice.MGR_HENKO_CALL_A() THEN
                condition := condition || ' AND MG3.SHOKAN_KJT = ''' || l_inShrKjt || '''';
            WHEN pkKkNotice.MGR_HENKO_CALL_P() THEN
                condition := condition || ' AND MG3.SHOKAN_KJT = ''' || l_inShrKjt || '''';
            WHEN pkKkNotice.MGR_HENKO_PUT() THEN
                condition := condition || ' AND MG3.SHOKAN_KJT = ''' || l_inShrKjt || '''';
            WHEN pkKkNotice.MGR_HENKO_MANKI() THEN
                condition := condition || ' AND MG3.SHOKAN_KJT = ''' || l_inShrKjt || '''';
            ELSE
                -- コード設定ミス、通常はここにこない。
                NULL;
        END CASE;
        RETURN condition;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04110_getcondition ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04110_getkkdata (
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
    rRT02 IN OUT record
) AS $body$
BEGIN
        -- 機構連携テーブルよりＩＳＩＮコード、期日を取得します。 
        SELECT
            trim(both RT02.ITEM005) AS ITEM005,                                     -- ＩＳＩＮコード
            trim(both RT02.ITEM006) AS ITEM006,                                     -- エラーコード
            trim(both RT02.ITEM009) AS ITEM009,                                     -- 海外カレンダ利払期日
            trim(both RT02.ITEM012) AS ITEM012,                                     -- 機構関与方式採用フラグ
            trim(both RT02.ITEM014) AS ITEM014,                                     -- 個別承認採用フラグ
            trim(both RT02.ITEM016) AS ITEM016,                                     -- 利払　利払期日
    --        TRIM(RT02.ITEM020) AS ITEM020,                                     -- コールオプション（全額償還）　コールオプション行使フラグ
            trim(both RT02.ITEM021) AS ITEM021,                                     -- コールオプション（全額償還）　繰上償還期日
            trim(both RT02.ITEM025) AS ITEM025,                                     -- 定時償還　定時償還（利払）期日
            trim(both RT02.ITEM028) AS ITEM028,                                     -- コールオプション（一部償還）　コールオプション行使フラグ
            trim(both RT02.ITEM029) AS ITEM029,                                     -- コールオプション（一部償還）　繰上償還期日
    --        TRIM(RT02.ITEM035) AS ITEM035,                                     -- プットオプション　プットオプション行使フラグ
            trim(both RT02.ITEM038) AS ITEM038,                                       -- プットオプション　繰上償還期日
    --        TRIM(RT02.ITEM040) AS ITEM040,                                     -- 送信者リファレンスＮｏ
    --        TRIM(RT02.ITEM047) AS ITEM047                                      -- コールオプション(一部償還)変更区分
            trim(both RT02.ITEM054) AS ITEM054                                        -- 満期償還　償還プレミアム
        INTO STRICT
            rRT02
        FROM
            KK_RENKEI RT02
        WHERE
            RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
        AND RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04110_getkkdata () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04110_initparam (
    gInTotsugoNo IN OUT varchar(12),
    gInCondition IN OUT varchar(4000),
    gOutSql IN OUT varchar(20000),
    gOutItemCnt IN OUT numeric(3),
    gOutItemAtt IN OUT PkCompare.t_ItemAtt_type,
    gCompAllCnt IN OUT integer
) AS $body$
BEGIN
	gInTotsugoNo := NULL;
	gInCondition := NULL;
	gOutSql := '';
	gOutItemCnt := NULL;
	gOutItemAtt := '{}';
	gCompAllCnt := NULL;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04110_initparam () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04110_nodatakakuninlist (
    gItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE,
    USER_ID varchar(10),
    gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE,
    gMsg varchar(100),
    rRT02 record,
    gMgrCd MGR_KIHON.MGR_CD%TYPE,
    gMgrRnm MGR_KIHON.MGR_RNM%TYPE,
    gJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE,
    gItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE
) AS $body$
BEGIN
        -- 確認リスト出力内容を帳票ワークテーブルに登録
        CALL pkKakuninList.insertKakuninData(
            	gItakuKaishaCd,
            	USER_ID,
            	pkKakuninList.CHOHYO_KBN_BATCH(),
            	gGyomuYmd,
            	gMsg,
            	rRT02.ITEM005,
            	gMgrCd,
            	gMgrRnm,
                NULL,
                NULL,
            	gJipDenbunCd,
            	gItakuKaishaRnm
        );
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04110_nodatakakuninlist () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04110_updateupdmgrxxx (
    l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE,
    l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE,
    l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE,
    l_inErrCd integer
) RETURNS integer AS $body$
DECLARE

        rtn integer;
        -- ＳＱＬ用 
        gSql varchar(500);
        -- ＳＱＬ用 
        cSql numeric;
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
        gSql := 'UPDATE ' || gTable
            || ' SET '
            || ' KK_STAT = :kkStat'
            || ' ,SHONIN_KAIJO_YOKUSEI_FLG = ''0''';
        -- 突合が正常終了でなければ機構エラーコードをセットする 
        IF l_inErrCd != pkconstant.success() THEN
        gSql := gSql || ' , MGR_KK_ERR_CD = ''' || pkKkNotice.MGR_KKERR_UNMATCH() || '''';
        END IF;
        -- update対象テーブルがUPD_MGR_SHNの場合、機構通知済みフラグに1をセットする 
        IF gTable = 'UPD_MGR_SHN' THEN
            gSql := gSql || ' , KK_TSUCHI_ZUMI_FLG = ''1''';
        END IF;
        gSql := gSql || ' WHERE '
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
        	CALL BMS_SQL.BIND_VARIABLE(cSql,':mgrHenkoKbn2',pkKkNotice.MGR_HENKO_TEIJI_F());
        END IF;
        -- 更新件数チェック 
    	IF DBMS_SQL.EXECUTE(cSql) = 0 THEN
            -- 
--             * 定時定額償還、または定時不定額償還で更新件数0件のとき、
--             * コールオプション（一部償還）行使フラグが立っているときは正常とみなす。
--             * 機構の電文フォーマット上、コールオプション（一部償還）の変更時に
--             * 定時償還期日に値が入る可能性があるため。
--             
            IF l_inMgrHenkoKbn IN (pkKkNotice.MGR_HENKO_TEIJI_T(),pkKkNotice.MGR_HENKO_TEIJI_F())
                AND (rRT02.ITEM028 IS NOT NULL AND rRT02.ITEM028::text <> '') AND rRT02.ITEM028 = 'Y' THEN
           		CALL pkLog.DEBUG(USER_ID, SP_ID, '定時償還の更新に失敗しましたが、コールオプション（一部）行使フラグがたっているので無視します。');
                rtn := pkconstant.success();
            ELSE
           		CALL pkLog.error('ECM3A3', SP_ID, gTableNm);
           		rtn := pkconstant.NO_DATA_FIND();
            END IF;
    	ELSE
    		rtn := pkconstant.success();
    	END IF;
       	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
        RETURN rtn;
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
-- REVOKE ALL ON FUNCTION sfadi002r04110_updateupdmgrxxx ( l_inItakuKaishaCd UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_KHN.MGR_CD%TYPE, l_inShrKjt UPD_MGR_KHN.SHR_KJT%TYPE, l_inMgrHenkoKbn UPD_MGR_KHN.MGR_HENKO_KBN%TYPE, l_inErrCd integer ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r04110_validatedata (
    l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
    l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
    gItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE,
    rRT02 record,
    COND_TSUCHI_CATEGORY char(8),
    COND_TSUCHI_LEVEL varchar(8),
    COND_BEEP_FLG char(1),
    COND_KIDOKU_FLG char(1),
    msg varchar(500),
    USER_ID varchar(10)
) RETURNS integer AS $body$
DECLARE

        rtn integer;

BEGIN
        -- ＩＳＩＮコード、支払代理人コードのチェック（エラーの場合は確認リストには出さずメッセージ通知に出す。） 
        rtn := SFADICheckShrdairiCd( l_inKkSakuseiDt,    --  電文作成日
                                        l_inDenbunMeisaiNo, --  電文明細No
                                        5,                  --  ＩＳＩＮコードの入っている機構連携ItemNo
                                        7,                  --  支払い代理人コードの入っている機構連携ItemNo
                                        gItakuKaishaCd,     --  委託会社コード
                                        '1',                  --  銘柄基本処理区分（任意）1を入れると承認済みのものだけ
                                        '0' );                --  副受託を抽出するかどうか（任意）1を入れると副受託も対象
        IF rtn = pkconstant.FATAL() THEN
            -- 予期しないエラー
            RETURN pkconstant.FATAL();
        END IF;
        IF rtn <> 1 THEN
            CALL pkLog.error(USER_ID, SP_ID, '支払代理人チェックエラー：該当銘柄(ISIN)か、支払代理人がIPAに存在しません');
            CALL pkLog.debug(USER_ID, SP_ID,  'メッセージ通知テーブルに書き込みます');
            -- Insert用のメッセージを作成
            msg := pkIpaMsgKanri.getMessage( 'MSG003', '銘柄情報変更', rRT02.ITEM005 );
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
                RETURN pkconstant.NO_DATA_FIND_ISIN();
            ELSE
                CALL pkLog.debug(USER_ID, SP_ID,  'メッセージ通知テーブルに書き込み失敗');
                -- Insert失敗の時にはエラーで返す
                RETURN pkconstant.FATAL();
            END IF;
        END IF;
        RETURN pkconstant.success();
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04110_validatedata () FROM PUBLIC;
