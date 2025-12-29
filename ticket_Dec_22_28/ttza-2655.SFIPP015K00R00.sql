


DROP TYPE IF EXISTS sfipp015k00r00_type_key CASCADE;
CREATE TYPE sfipp015k00r00_type_key AS (
		gItakuKaishaCd		char(4),	-- 委託会社コード
		gMgrCd				varchar(13),			-- 銘柄コード
    gKozaKbn     char(2),       -- 口座区分
		gTaxKbn			char(2)			-- 税区分
	);
DROP TYPE IF EXISTS sfipp015k00r00_type_calc_zei CASCADE;
CREATE TYPE sfipp015k00r00_type_calc_zei AS (
  	gZeihikiBefKngk numeric,
	  gKokuZeiKngk    numeric,
	  gZeihikiAftKngk numeric,
	  gChihoZeiKngk   numeric,
		gShokanSeikyuKngk	numeric,
    gGnrZndk  numeric,
	  gErrMessage     varchar(200)
  );
DROP TYPE IF EXISTS sfipp015k00r00_type_summry CASCADE;
CREATE TYPE sfipp015k00r00_type_summry AS (
		gGzeihikiBefChokyu_kngk		decimal(14,2),
		gGzeiKngk				      decimal(14,2),
	  gZeihikiAftKngk          decimal(14,2),
		gShokanSeikyuKngk			  decimal(16,2),
    gGnrZndk                 numeric(14)
	);
DROP TYPE IF EXISTS sfipp015k00r00_type_jiko CASCADE;
CREATE TYPE sfipp015k00r00_type_jiko AS (
    gOwnFinancialSecuritiesKbn        char(1),
    gOwnBankCd                       char(4),
    gSknKessaiCd                     char(7)
  );


CREATE OR REPLACE FUNCTION sfipp015k00r00 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2007
-- * 会社名: JIP
-- *
-- * 機構非関与銘柄元利金請求明細データ（実質記番号方式）作成処理
-- *
-- * 銘柄_基本、銘柄_利払回次、銘柄_償還回次、自行委託Viewをもとに
-- * 元利金請求明細データを作成する。
-- *
-- * 対象とする銘柄:
-- * 機構関与方式採用フラグ：機構非関与方式（実質記番号方式）
-- *
-- * また、機構非関与銘柄元利金請求データ登録画面にて作成済のものは、
-- * ここでは作成しない。
-- *
-- * @author
-- * @version $Id:
-- *
-- * @return INTEGER 0:正常、99:異常
-- 
--====================================================================*
--   		定数定義
-- *====================================================================
    -- リターンコード 
 	result			integer;
	-- ファンクション名 
	SP_ID CONSTANT text := 'SFIPP015K00R00';
	-- ユーザID 
	USER_ID				CONSTANT text := pkconstant.BATCH_USER();
    -- 個別証人採用フラグ 非関与 　コード定義:511 
    KOBETSU_SHONIN_HIKANYO CONSTANT text := 'A';
    -- 機構関与方式採用フラグ　非関与 コード定義:505 
    KK_KANYO_FLG_HIKANYO CONSTANT text := '2';
    -- DVP区分 非DVP 　コード定義:501  -- 0=非DVP区分/1=DVP区分
    DVP_KBN_NOT_DVP CONSTANT text := '0';
    -- デフォルト値 
    DEFAULT_SPACE CONSTANT text := ' ';
    -- 通貨（日本円） 
    DEFAULT_TSUKA_CD CONSTANT text := 'JPY';
    -- オプションコード 
    OP_OPTION_CD CONSTANT text := 'IPP1003302020';
    -- オプションフラグ 
    OP_OPTION_FLG CONSTANT text := '1';
--====================================================================*
--   		変数定義
-- *====================================================================
    -- 支払日（システム管理情報．業務日付＋２営業日）
    gShrYmd KIKIN_SEIKYU.SHR_YMD%TYPE;
    -- 支払日1日前(残高取得共通ＳＰ用) 
    gBefShrYmd KIKIN_SEIKYU.SHR_YMD%TYPE;
    -- タイムスタンプ 
    gTimeStamp TIMESTAMP := to_timestamp(pkDate.getCurrentTime(),'YYYY-MM-DD HH24:MI:SS.US6');
	-- 処理区分 
    gShrKbn KIKIN_SEIKYU.SHORI_KBN%TYPE;
	-- レコードカウント 
	gRecCnt integer := 0;
	-- キー
	key SFIPP015K00R00_TYPE_KEY := ROW(' ', ' ', ' ', ' ')::SFIPP015K00R00_TYPE_KEY;
  -- 取引先別税額取得
  calcZei SFIPP015K00R00_TYPE_CALC_ZEI := ROW(0, 0, 0, 0, 0, 0, '')::SFIPP015K00R00_TYPE_CALC_ZEI;
	-- 集計
	summry SFIPP015K00R00_TYPE_SUMMRY := ROW(0, 0, 0, 0, 0)::SFIPP015K00R00_TYPE_SUMMRY;
  -- 自行情報
  jiko SFIPP015K00R00_TYPE_JIKO := ROW(' ', ' ', ' ')::SFIPP015K00R00_TYPE_JIKO;
--====================================================================*
--   		カーソル定義
-- *====================================================================
--
-- * 銘柄_利払回次、銘柄_償還回次の結合テーブル、銘柄_基本View、自行委託Viewより情報を取得する。
-- * 銘柄_利払回次、銘柄_償還回次の結合テーブルでは、以下のようなデータが取得できる。
-- *
-- * 1.利払回次、償還回次の両方に指定された支払日が存在する場合
-- *      利金項目、元金項目ともに取得できる。
-- *
-- * 2.利払回次にのみ、指定された支払日が存在する場合。
-- *      利金項目は取得できるが、元金項目はNULLを返す。
-- *
-- * 3.償還回次にのみ、指定された支払日が存在する場合。
-- *      元金項目は取得できるが、利金項目はNULLを返す。
-- *
-- * 利金項目:１通貨あたりの利子金額
-- * 元金項目:償還金額
-- *
-- 
cSeikyu CURSOR FOR
	SELECT
		DISTINCT
		VMG1.ITAKU_KAISHA_CD 	--委託会社コード
		,VMG1.MGR_CD 			--銘柄コード
		,MG2.RBR_YMD 			--利払日
		,P05.TRHK_CD 			--取引先コード
		,P05.TAX_KBN 			--税区分
		,MG2.RBR_KJT 			--利払期日
		,(pkIpaZndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, gBefShrYmd, '7'))::numeric  AS OSAE_KNGK  --差押金額
		,SUBSTR(P05.TRHK_CD, 10, 2) AS TRHK_KOZA_KBN  -- 口座区分（ORDER BY用）
	FROM
		MGR_KIHON_VIEW VMG1,
		KBG_SHOKBG P02,
		KBG_MTORISAKI P05,
		MGR_RBRKIJ MG2
	WHERE
		P02.ITAKU_KAISHA_CD = P05.ITAKU_KAISHA_CD
		AND P02.TRHK_CD = P05.TRHK_CD
		AND P05.TRHK_ZOKUSEI <> '3'		--その他口座管理機関除く
		AND P02.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND P02.MGR_CD = MG2.MGR_CD
		AND (P02.SHOKAN_KJT >= MG2.RBR_KJT OR coalesce(trim(both P02.SHOKAN_KJT)::text, '') = '')
		AND MG2.RBR_YMD = gShrYmd 		--業務日付の2営業日後
    AND VMG1.KK_KANYO_FLG = KK_KANYO_FLG_HIKANYO
		AND P02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		AND P02.MGR_CD = VMG1.MGR_CD
		AND P02.ITAKU_KAISHA_CD IN (SELECT J1.KAIIN_ID FROM VJIKO_ITAKU J1, MOPTION_KANRI O1 
				WHERE J1.KAIIN_ID = O1.KEY_CD 
					AND O1.OPTION_CD = OP_OPTION_CD 
					AND O1.OPTION_FLG = OP_OPTION_FLG)
    AND NOT EXISTS (SELECT 1 FROM KIKIN_SEIKYU K01
                    WHERE K01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                      AND K01.MGR_CD = VMG1.MGR_CD
                      AND K01.SHR_YMD = gShrYmd)
		AND (0 <> (pkIpaZndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, gBefShrYmd, '2'))::numeric )
	ORDER BY 
		VMG1.ITAKU_KAISHA_CD
		,VMG1.MGR_CD
		,TRHK_KOZA_KBN
		,P05.TAX_KBN;
--====================================================================*
--   		メイン
-- *====================================================================
BEGIN
--	pkLog.debug(USER_ID,SP_ID,'機構非関与銘柄元利金請求データ（実質記番号方式）作成 START');
    result := pkconstant.FATAL();
	-- 共通関数より、業務日付+2営業日の取得（支払日取得） 
	gShrYmd := pkDate.getPlusDateBusiness(pkDate.getGyomuYmd(),2);
--	pkLog.debug(USER_ID,SP_ID,'利払日（支払日）: ' || gShrYmd);
    -- 支払日1日前取得 
	gBefShrYmd := pkDate.getMinusDate(gShrYmd, 1);
--	pkLog.debug(USER_ID,SP_ID,'利払日（支払日）前日: ' || gBefShrYmd);
    FOR rSeikyu IN cSeikyu LOOP
		--キーブレイク処理
		IF key.gItakuKaishaCd <> rSeikyu.ITAKU_KAISHA_CD
		OR key.gMgrCd <> rSeikyu.MGR_CD
		OR key.gKozaKbn <> SUBSTR(rSeikyu.TRHK_CD,10,2)
		OR key.gTaxKbn <> rSeikyu.TAX_KBN THEN
--	pkLog.debug(USER_ID,SP_ID,'【キーブレイク】');
--	pkLog.debug(USER_ID,SP_ID,'委託会社コード：' || key.gItakuKaishaCd || ' <> ' || rSeikyu.ITAKU_KAISHA_CD );
--	pkLog.debug(USER_ID,SP_ID,'銘柄コード：' || key.gMgrCd || ' <> ' || rSeikyu.MGR_CD );
--	pkLog.debug(USER_ID,SP_ID,'口座区分：' || key.gKozaKbn || ' <> ' || SUBSTR(rSeikyu.TRHK_CD,10,2) );
--	pkLog.debug(USER_ID,SP_ID,'税区分：' || key.gTaxKbn || ' <> ' || rSeikyu.TAX_KBN );
 			IF gRecCnt > 0 THEN
				--請求データ登録
				CALL SFIPP015K00R00_insertKikinSeikyu(key, summry, jiko, gShrYmd, gShrKbn, DEFAULT_TSUKA_CD, KOBETSU_SHONIN_HIKANYO, KK_KANYO_FLG_HIKANYO, DVP_KBN_NOT_DVP, USER_ID, gTimeStamp, SP_ID, DEFAULT_SPACE);
--	pkLog.debug(USER_ID,SP_ID,'レコード件数： ' || gRecCnt);
--	pkLog.debug(USER_ID,SP_ID,'請求データ登録');
  			--カウントクリア
  			gRecCNt := 0;
			END IF;
      IF key.gItakuKaishaCd <> rSeikyu.ITAKU_KAISHA_CD THEN
--	pkLog.debug(USER_ID,SP_ID,'【委託会社情報取得】');
--	pkLog.debug(USER_ID,SP_ID,'委託会社コード：' || key.gItakuKaishaCd || ' <> ' || rSeikyu.ITAKU_KAISHA_CD );
  			--委託会社情報取得
  			BEGIN
  				SELECT VSC18.OWN_FINANCIAL_SECURITIES_KBN, VSC18.OWN_BANK_CD, VSC18.SKN_KESSAI_CD
  				INTO STRICT jiko.gOwnFinancialSecuritiesKbn, jiko.gOwnBankCd, jiko.gSknKessaiCd
  				FROM VJIKO_ITAKU VSC18
  				WHERE VSC18.KAIIN_ID = rSeikyu.ITAKU_KAISHA_CD;
  				EXCEPTION
  				WHEN no_data_found THEN
  				     jiko.gOwnFinancialSecuritiesKbn := ' ';
  				     jiko.gOwnBankCd := ' ';
  				     jiko.gSknKessaiCd := ' ';
  				WHEN OTHERS THEN
  				     RAISE;
  			END;
--	pkLog.debug(USER_ID,SP_ID,'自行金融証券区分：' || jiko.gOwnFinancialSecuritiesKbn );
--	pkLog.debug(USER_ID,SP_ID,'自行金融機関コード：' || jiko.gOwnBankCd );
--	pkLog.debug(USER_ID,SP_ID,'資金決済会社コード：' || jiko.gSknKessaiCd );
      END IF;
			--キー情報セット
			key.gItakuKaishaCd := rSeikyu.ITAKU_KAISHA_CD;
			key.gMgrCd := rSeikyu.MGR_CD;
			key.gKozaKbn := SUBSTR(rSeikyu.TRHK_CD,10,2);
			key.gTaxKbn := rSeikyu.TAX_KBN;
			--集計エリアクリア
			summry.gGzeihikiBefChokyu_kngk := 0;
			summry.gGzeiKngk := 0;
			summry.gZeihikiAftKngk := 0;
			summry.gShokanSeikyuKngk := 0;
			summry.gGnrZndk := 0;
		END IF;
		--取引先別税額取得処理
--	pkLog.debug(USER_ID,SP_ID,'【取引先別税額取得処理】');
--	pkLog.debug(USER_ID,SP_ID,'Pkipakibango.calcZeigaku(' || rSeikyu.ITAKU_KAISHA_CD || ',' || rSeikyu.MGR_CD || ',' || rSeikyu.RBR_KJT || ',' || gBefShrYmd || ',' || rSeikyu.TRHK_CD || ')' );
		IF Pkipakibango.calcZeigaku(rSeikyu.ITAKU_KAISHA_CD, rSeikyu.MGR_CD, rSeikyu.RBR_KJT, gBefShrYmd, rSeikyu.TRHK_CD
		                        , calcZei.gZeihikiBefKngk
		                        , calcZei.gZeihikiAftKngk
		                        , calcZei.gKokuZeiKngk
		                        , calcZei.gChihoZeiKngk
		                        , calcZei.gErrMessage) <> pkconstant.success() THEN
		    calcZei.gZeihikiBefKngk := 0;
		    calcZei.gZeihikiAftKngk := 0;
		    calcZei.gKokuZeiKngk := 0;
		    calcZei.gChihoZeiKngk := 0;
		END IF;
--	pkLog.debug(USER_ID,SP_ID,'国税引前利金請求額=' || calcZei.gZeihikiBefKngk);
--	pkLog.debug(USER_ID,SP_ID,'国税引後利金請求額=' || calcZei.gZeihikiAftKngk);
--	pkLog.debug(USER_ID,SP_ID,'国税額=' || calcZei.gKokuZeiKngk);
		--取引先別元金額取得処理
--	pkLog.debug(USER_ID,SP_ID,'【取引先別元金額取得処理】');
--	pkLog.debug(USER_ID,SP_ID,'pkipakibango.getGankinTrhk(' || rSeikyu.ITAKU_KAISHA_CD || ',' || rSeikyu.MGR_CD || ',' || gShrYmd || ',' || rSeikyu.TRHK_CD || ')' );
		calcZei.gShokanSeikyuKngk := pkipakibango.getGankinTrhk(rSeikyu.ITAKU_KAISHA_CD, rSeikyu.MGR_CD, gShrYmd, rSeikyu.TRHK_CD);
--	pkLog.debug(USER_ID,SP_ID,'償還金請求額=' || calcZei.gShokanSeikyuKngk);
		--取引先別振替債基準残高取得処理
--	pkLog.debug(USER_ID,SP_ID,'【取引先別振替債基準残高取得処理】');
--	pkLog.debug(USER_ID,SP_ID,'pkipakibango.getKjnZndkTrhk(' || rSeikyu.ITAKU_KAISHA_CD || ',' || rSeikyu.MGR_CD || ',' || gBefShrYmd || ',' || rSeikyu.TRHK_CD || ')' );
		calcZei.gGnrZndk := pkipakibango.getKjnZndkTrhk(rSeikyu.ITAKU_KAISHA_CD, rSeikyu.MGR_CD, gBefShrYmd, rSeikyu.TRHK_CD);
--	pkLog.debug(USER_ID,SP_ID,'元利払対象残高=' || calcZei.gGnrZndk);
		--集計処理
		summry.gGzeihikiBefChokyu_kngk := summry.gGzeihikiBefChokyu_kngk + calcZei.gZeihikiBefKngk;
		summry.gGzeiKngk := summry.gGzeiKngk + calcZei.gKokuZeiKngk;
		summry.gZeihikiAftKngk := summry.gZeihikiAftKngk + (calcZei.gZeihikiBefKngk - calcZei.gKokuZeiKngk);
		summry.gShokanSeikyuKngk := summry.gShokanSeikyuKngk + calcZei.gShokanSeikyuKngk;
		summry.gGnrZndk := summry.gGnrZndk + calcZei.gGnrZndk;
		--処理区分設定            
		IF rSeikyu.OSAE_KNGK > 0 THEN
			gShrKbn := '0';
		ELSE
			gShrKbn := '1';
		END IF;
		--レコード件数カウント
		gRecCnt := gRecCnt + 1;
    END LOOP;
		IF gRecCnt > 0 THEN
			--請求データ登録
			CALL SFIPP015K00R00_insertKikinSeikyu(key, summry, jiko, gShrYmd, gShrKbn, DEFAULT_TSUKA_CD, KOBETSU_SHONIN_HIKANYO, KK_KANYO_FLG_HIKANYO, DVP_KBN_NOT_DVP, USER_ID, gTimeStamp, SP_ID, DEFAULT_SPACE);
--	pkLog.debug(USER_ID,SP_ID,'レコード件数： ' || gRecCnt);
--	pkLog.debug(USER_ID,SP_ID,'最終データ登録');
		END IF;
    result := pkconstant.success();
--	pkLog.debug(USER_ID,SP_ID,'機構非関与銘柄元利金請求データ作成（実質記番号方式） END result' || result);
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipp015k00r00 () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipp015k00r00_insertkikinseikyu (
	INOUT key SFIPP015K00R00_TYPE_KEY,
	INOUT summry SFIPP015K00R00_TYPE_SUMMRY,
	INOUT jiko SFIPP015K00R00_TYPE_JIKO,
	gShrYmd char,
	gShrKbn char,
	DEFAULT_TSUKA_CD text,
	KOBETSU_SHONIN_HIKANYO text,
	KK_KANYO_FLG_HIKANYO text,
	DVP_KBN_NOT_DVP text,
	USER_ID text,
	gTimeStamp TIMESTAMP,
	SP_ID text,
	DEFAULT_SPACE text
) AS $body$
DECLARE

	errMessage    typeMessage;

BEGIN
        INSERT INTO KIKIN_SEIKYU(
            ITAKU_KAISHA_CD,
            MGR_CD,
            SHR_YMD,
            TSUKA_CD,
            FINANCIAL_SECURITIES_KBN,
            BANK_CD,
            KOZA_KBN,
            TAX_KBN,
            GZEIHIKI_BEF_CHOKYU_KNGK,
            GZEI_KNGK,
            GZEIHIKI_AFT_CHOKYU_KNGK,
            SHOKAN_SEIKYU_KNGK,
            AITE_SKN_KESSAI_BCD,
            AITE_SKN_KESSAI_SCD,
            KESSAI_NO,
            KOBETSU_SHONIN_SAIYO_FLG,
            KK_KANYO_UMU_FLG,
            DVP_KBN,
            GNR_ZNDK,
            SHORI_KBN,
            KOUSIN_ID,
            SAKUSEI_DT,
            SAKUSEI_ID)
        VALUES (
            key.gItakuKaishaCd,
            key.gMgrCd,
            gShrYmd,
            DEFAULT_TSUKA_CD,
            jiko.gOwnFinancialSecuritiesKbn,
            jiko.gOwnBankCd,
            key.gKozaKbn,
            key.gTaxKbn,
            summry.gGzeihikiBefChokyu_kngk,
            summry.gGzeiKngk,
            summry.gZeihikiAftKngk,
            summry.gShokanSeikyuKngk,
            SUBSTR(jiko.gSknKessaiCd,1,4),
            SUBSTR(jiko.gSknKessaiCd,5,3),
            DEFAULT_SPACE,
            KOBETSU_SHONIN_HIKANYO,
            KK_KANYO_FLG_HIKANYO,
            DVP_KBN_NOT_DVP,
            summry.gGnrZndk,
            gShrKbn,
            USER_ID,
            gTimeStamp,
            USER_ID
            );
    EXCEPTION
        WHEN OTHERS THEN
		-- エラーの詳細情報をセット
		errMessage := '{}';
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('委託会社コード： ' || key.gItakuKaishaCd)::typeMessageRecord;
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('銘柄コード： ' || key.gMgrCd)::typeMessageRecord;
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('支払日： ' || gShrYmd)::typeMessageRecord;
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('通貨コード： ' || DEFAULT_TSUKA_CD)::typeMessageRecord;
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('金融証券区分： ' || jiko.gOwnFinancialSecuritiesKbn)::typeMessageRecord;
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('金融機関コード： ' || jiko.gOwnBankCd)::typeMessageRecord;
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('口座区分： ' || key.gKozaKbn)::typeMessageRecord;
		errMessage := array_append(errMessage, null);
		errMessage[coalesce(cardinality(errMessage), 0)] := ROW('税区分： ' || key.gTaxKbn)::typeMessageRecord;
            CALL pkLog.error('ECM321',SP_ID, errMessage);
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipp015k00r00_insertkikinseikyu () FROM PUBLIC;
