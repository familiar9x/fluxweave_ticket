




CREATE OR REPLACE FUNCTION sfipx117k15r01_01 ( 
	l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inItakuKaishaRnm SOWN_INFO.BANK_RNM%TYPE,            -- 委託会社略称
 l_inJikodaikoKbn text                            -- 自行代行区分
 ) RETURNS integer AS $body$
DECLARE

/**
 * 著作権: Copyright (c) 2016
 * 会社名: JIP
 *
 * 警告連絡情報リスト、公社債関連管理リストを作成する。（バッチ用）
 * １．各警告・連絡の検索処理
 * ２．SFIPKEIKOKUINSERTの呼び出し処理
 * ３．SPIPX117K15R01の呼び出し処理
 * ４．バッチ帳票出力ＯＮ処理
 *
 * @author Y.Yamada
 * @version $Id: SFIPX117K15R01_01.sql,v 1.0 2017/02/10 10:19:30 Y.Yamada Exp $
 *
 * @param l_initakuKaishaCd 委託会社コード
 * @param l_inItakuKaishaRnm 委託会社略称
 * @param l_inItakuKaishaRnm 自行代行区分
 * @return INTEGER 0:正常
 *                99:異常、それ以外：エラー
 */
/*==============================================================================*/

/*                定数定義                                                      */

/*==============================================================================*/

	C_PROGRAM_ID         CONSTANT varchar(50) := 'SPIPX055K15R03';    --プログラムID
/*==============================================================================*/

/*                変数定義                                                      */

/*==============================================================================*/

	gGyomuYmd	     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 業務日付
	gGetsumatuYmd	     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 月末営業日
	gGessyoYmd	     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 月初営業日
	gFncResult           integer;                            -- 実行結果
	gYobi1               varchar(50) := NULL;           -- 予備１
	gYobi2               varchar(50) := NULL;           -- 予備２
	gHikakuKingaku       numeric;
	gIPW009ItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;
	gIPW009ShokanYmd     GENSAI_RIREKI.SHOKAN_YMD%TYPE;
	gIPW009IsinCd        MGR_KIHON_VIEW.ISIN_CD%TYPE;
	gIPW008ItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;
	gIPW008ShokanYmd     GENSAI_RIREKI.SHOKAN_YMD%TYPE;
	gIPW008MgrCd         GENSAI_RIREKI.MGR_CD%TYPE;
 	gIPW008IsinCd        Mgr_KIHON.ISIN_CD%TYPE;
	gShokanMethodCd      MGR_KIHON.SHOKAN_METHOD_CD%TYPE;    -- 償還方法コード
	gPreviousShokanYmd   SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 償還日の前日
	gFactor              MGR_SHOKIJ.FACTOR%TYPE;             -- ファクタ
	gDenbunGensaiKngk    numeric(16);                         -- 保振の減債金額
	C_REPORT_ID          varchar(50) := NULL;          --帳票ID
	gRtnCd               integer := pkconstant.success();
	gSqlErrM             varchar(200) := NULL;
	gOpFlg               varchar(20);
	gYokuEigyoYmd        SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 翌営業日
	gIPW006ItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;
	gIPW006MgrCd         GENSAI_RIREKI.MGR_CD%TYPE;
	gIPW007ItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;
	gIPW007MgrCd         GENSAI_RIREKI.MGR_CD%TYPE;
	gIPW002ItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;
	gIPW002MgrCd         GENSAI_RIREKI.MGR_CD%TYPE;
	gIPW010CNT           varchar(5) := '0';
	gIPW019CNT           numeric;
	gIPW019BIKO          varchar(100) := NULL;
	gIPW011CNT           varchar(5) := '0';
	gGyomuYmdAfter      SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付（Xか月後）
	gGetsumatuYmdAfter  SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 月末営業日（Xか月後）
	gGessyoYmdAfter     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 月初営業日（Xか月後）
	gHolidayCheck       varchar(5) := '0';                   -- 休日判定結果
	gMaeEigyoYmd        SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 前営業日
	gWarningYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 警告出力日
	gIPW012BIKO         varchar(100) := NULL;
	gIPI002BIKO_01      varchar(100) := NULL;
	gIPI002BIKO_02      varchar(100) := NULL;
	gIPI002BIKO_03      varchar(100) := NULL;
	gIPI002BIKO_04      varchar(100) := NULL;
	g8MaeEigyoYmdIPI002 SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 8営業日前
	gIPI004BIKO1        varchar(100) := NULL;
	gIPI004BIKO2        varchar(100) := NULL;
	gIPI004BIKO3        varchar(100) := NULL;
	g2MaeEigyoYmdIPI004 SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 2営業日前
	g8MaeEigyoYmdIPI004 SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 8営業日前
	gIPI104SELECTBIKO1  varchar(100) := NULL;
	gIPI104SELECTBIKO2  varchar(100) := NULL;
	gIPI104SELECTBIKO3  varchar(100) := NULL;
	gALLHenreiKingaku       numeric;
	gZeinukiHenreiKingaku       numeric;
	gSzeiHenreiKingaku       numeric;
    /* オプションフラグ */

    gOptionFlg   MOPTION_KANRI.OPTION_FLG%TYPE := '0';  -- オプションフラグ
	gBefGyomuYmd        SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付の1営業日前
	gGyomuYmd1After     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付の1営業日後
	gGyomuYmd2After     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付の2営業日後
	gGyomuYmd3After     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付の3営業日後
	gGyomuYmd4After     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付の4営業日後
	gGyomuYmd5After     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付の5営業日後
	gGyomuYmd6After     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付の6営業日後
	gGyomuYmd2MAfterYM  char(6);                             -- 業務日付（２か月後）の年月
	gGyomuYmd3MAfterYM  char(6);                             -- 業務日付（３か月後）の年月
	gBicCd VJIKO_ITAKU.BIC_CD%TYPE; --BICコード
/*==============================================================================*/

/*                カーソル定義                                                  */

/*==============================================================================*/

/*==============================================================================*/

/* IPI102SELECT                                                                 */

/*==============================================================================*/

	curIPI102SELECT CURSOR FOR
	SELECT SouHuriWork.ISIN_CD, -- ISINコード
	       VMG1.MGR_RNM, -- 銘柄略称
	       SouHuriWork.kofubi, -- 資金交付日
	       SouHuriWork.kensu, -- 件数
	       SouHuriWork.SHASAI_TOTAL, -- 合計金額
	       VMG1.HAKKO_YMD  -- 発行年月日
	  FROM MGR_KIHON_VIEW VMG1,
	       (SELECT MAX(WK1.ITAKU_KAISHA_CD) AS ITAKU_KAISHA_CD,
	               MIN(WK1.ISIN_CD) AS ISIN_CD,
	               count(distinct WK1.ISIN_CD) AS kensu,
	               trim(both TO_CHAR(SUM(WK1.SHASAI_TOTAL * WK1.HAKKO_KAGAKU / 100) -
	                            SUM(coalesce(WK1.ALL_TESU_KNGK, 0)) -
	                            SUM(coalesce(WK1.ALL_TESU_SZEI, 0)) -
	                            SUM(coalesce(WK1.HOSEI_ALL_TESU_KNGK, 0)) -
	                            SUM(coalesce(WK1.HOSEI_ALL_TESU_SZEI, 0)),
	                            '99,999,999,999,999')) AS SHASAI_TOTAL,
	               MAX(WK1.kofubi) AS kofubi
	          FROM (SELECT VMG1.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,
	                       VMG1.ISIN_CD AS ISIN_CD,
	                       VMG1.SHASAI_TOTAL AS SHASAI_TOTAL,
	                       VMG1.HAKKO_KAGAKU AS HAKKO_KAGAKU,
	                       SUM(coalesce(T01.ALL_TESU_KNGK, 0)) AS ALL_TESU_KNGK,
	                       SUM(coalesce(T01.ALL_TESU_SZEI, 0)) AS ALL_TESU_SZEI,
	                       SUM(coalesce(T01.HOSEI_ALL_TESU_KNGK, 0)) AS HOSEI_ALL_TESU_KNGK,
	                       SUM(coalesce(T01.HOSEI_ALL_TESU_SZEI, 0)) AS HOSEI_ALL_TESU_SZEI,
	                       VMG1.SKN_KOFU_YMD AS kofubi,
	                       VMG1.HAKKO_YMD    AS HAKKO_YMD
	                  FROM mgr_tesuryo_prm mg8, mgr_kihon_view vmg1
LEFT OUTER JOIN tesuryo t01 ON (VMG1.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD AND VMG1.MGR_CD = T01.MGR_CD AND '1' = T01.TESU_SASHIHIKI_KBN)
WHERE MG8.NYUKIN_KOZA_KBN = 'D' AND VMG1.SKN_KOFU_YMD = gGyomuYmd4After AND VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG8.MGR_CD AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')   GROUP BY VMG1.ITAKU_KAISHA_CD,
	                          VMG1.ISIN_CD,
	                          VMG1.SHASAI_TOTAL,
	                          VMG1.HAKKO_KAGAKU,
	                          VMG1.SKN_KOFU_YMD,
	                          VMG1.HAKKO_YMD) WK1
	         GROUP BY WK1.kofubi, WK1.HAKKO_YMD) SouHuriWork 
	 WHERE SouHuriWork.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	   AND SouHuriWork.ISIN_CD = VMG1.ISIN_CD
	   AND SouHuriWork.ITAKU_KAISHA_CD = l_inItakuKaishaCd;
/*==============================================================================*/

/* IPW001SELECT                                                                 */

/*==============================================================================*/

	curIPW001SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,       -- ISINコード
		M01.KOZA_TEN_CD,    -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		VMG1.MGR_RNM,       -- 銘柄略称
		K01.SHR_YMD,        -- 支払日
		K01.FINANCIAL_SECURITIES_KBN || K01.BANK_CD || K01.KOZA_KBN AS KIKO_KANYUSYA_CD  -- 機構加入者コード
	FROM
		MGR_KIHON_VIEW VMG1,
		KIKIN_SEIKYU K01,
		MHAKKOTAI M01
	WHERE
		    K01.TAX_KBN IN ('80','81')
		AND K01.SHR_YMD = gGyomuYmd
		AND VMG1.SAIKEN_SHURUI = '10'
		AND VMG1.KK_HAKKO_CD NOT LIKE '2%'
		AND VMG1.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = K01.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
		AND K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	
UNION ALL

	SELECT
		VMG1.ISIN_CD,        -- ISINコード
		M01.KOZA_TEN_CD,     -- 口座店コード
		M01.KOZA_TEN_CIFCD,  -- 口座店CIFコード
		VMG1.MGR_RNM,        -- 銘柄略称
		K01.SHR_YMD,         -- 支払日
		K01.FINANCIAL_SECURITIES_KBN || K01.BANK_CD || K01.KOZA_KBN AS KIKO_KANYUSYA_CD  -- 機構加入者コード
	FROM
		MGR_KIHON_VIEW VMG1,
		KIKIN_SEIKYU K01,
		MHAKKOTAI M01
	WHERE
		    K01.TAX_KBN IN ('80','81')
		AND K01.SHR_YMD = gGyomuYmd
		AND VMG1.SAIKEN_SHURUI <> '10'
		AND VMG1.KK_HAKKO_CD  LIKE '2%'
		AND VMG1.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = K01.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND VMG1.MGR_STAT_KBN = '1'
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
		AND K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd;
/*==============================================================================*/

/* IPI001SELECT                                                                 */

/*==============================================================================*/

	curIPI001SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,            -- ISINコード
		M01.KOZA_TEN_CD,         -- 口座店コード
		M01.KOZA_TEN_CIFCD,      -- 口座店CIFコード
		VMG1.MGR_RNM,            -- 銘柄略称
		MG3.SHOKAN_KJT,          -- 償還期日
		MG3.ED_PUTKOSHIKIKAN_YMD,-- 行使期間終了日
		MG3.SHOKAN_KBN            -- 償還区分
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01
	WHERE
		    MG3.SHOKAN_KBN IN ('40','41')
		AND SUBSTR(MG3.SHOKAN_KJT,1,6) = gGyomuYmd2MAfterYM
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	
UNION ALL

	SELECT
		VMG1.ISIN_CD,            -- ISINコード
		M01.KOZA_TEN_CD,         -- 口座店コード
		M01.KOZA_TEN_CIFCD,      -- 口座店CIFコード
		VMG1.MGR_RNM,            -- 銘柄略称
		MG3.SHOKAN_KJT,          -- 償還期日
		MG3.ED_PUTKOSHIKIKAN_YMD,-- 行使期間終了日
		MG3.SHOKAN_KBN            -- 償還区分
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01
	WHERE
		    MG3.SHOKAN_KBN IN ('50')
		AND SUBSTR(MG3.ED_PUTKOSHIKIKAN_YMD,1,6) = gGyomuYmd2MAfterYM
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd;
/*==============================================================================*/

/* IPW002SELECT                                                                 */

/*==============================================================================*/

	curIPW002SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,            -- ISINコード
		M01.KOZA_TEN_CD,         -- 口座店コード
		M01.KOZA_TEN_CIFCD,      -- 口座店CIFコード
		VMG1.MGR_RNM,            -- 銘柄略称
		MG3.SHOKAN_YMD            -- 償還年月日
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01
	WHERE (VMG1.RITSUKE_WARIBIKI_KBN = 'Z'
		 AND VMG1.HAKKO_YMD >= '20160101'
		 OR VMG1.RITSUKE_WARIBIKI_KBN <> 'Z'
		 AND VMG1.HAKKO_KAGAKU <= 90)
		AND MG3.SHOKAN_KBN NOT IN ('30')
		AND SUBSTR(MG3.SHOKAN_YMD,1,6) = gGyomuYmd2MAfterYM
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.TOKUTEI_KOUSHASAI_FLG = 'N'
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd;
/*==============================================================================*/

/* IPW003SELECT                                                                 */

/*==============================================================================*/

	curIPW003SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,            -- ISINコード
		M01.KOZA_TEN_CD,         -- 口座店コード
		M01.KOZA_TEN_CIFCD,      -- 口座店CIFコード
		VMG1.MGR_RNM,            -- 銘柄略称
		MG3.SHOKAN_YMD            -- 償還年月日
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01
	WHERE (VMG1.RITSUKE_WARIBIKI_KBN = 'Z'
		 AND VMG1.HAKKO_YMD >= '20160101'
		 OR VMG1.RITSUKE_WARIBIKI_KBN <> 'Z'
		 AND VMG1.HAKKO_KAGAKU <= 90)
		AND MG3.SHOKAN_KBN NOT IN ('30')
		AND MG3.SHOKAN_YMD = gGyomuYmd2After
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.TOKUTEI_KOUSHASAI_FLG = 'N'
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd;
/*==============================================================================*/

/* IPW013SELECT                                                                 */

/*==============================================================================*/

	curIPW013SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,            -- ISINコード
		VMG1.MGR_RNM,            -- 銘柄略称
		MG3.SHOKAN_YMD            -- 償還年月日
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MCALENDAR_HOSEI_JYOGAI M67
	WHERE
		    SUBSTR(MG3.SHOKAN_YMD,1,6) = gGyomuYmd3MAfterYM
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M67.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = M67.MGR_CD
		AND M67.DATE_SHURUI_CD IN ('22','33')
		AND M67.CHOOSE_FLG = '1'
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd;
/*==============================================================================*/

/* IPW014SELECT                                                                 */

/*==============================================================================*/

	curIPW014SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,  -- ISINコード
		VMG1.MGR_RNM,  -- 銘柄略称
		MG4.CHOKYU_YMD  -- 徴求日
	FROM
		MGR_TESKIJ MG4
		INNER JOIN MGR_KIHON_VIEW VMG1 
			ON MG4.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND MG4.MGR_CD = VMG1.MGR_CD
	WHERE
		    MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND (MG4.TESU_SHURUI_CD = '11' OR MG4.TESU_SHURUI_CD = '12')
		AND MG4.DISTRI_YMD IS NOT NULL
		AND VMG1.ISIN_CD IS NOT NULL;
/*==============================================================================*/

/* IPI103SELECT                                                                 */

/*==============================================================================*/

	curIPI103SELECT CURSOR FOR
	SELECT
		count(*) AS kensu  -- 件数
	FROM
		MHAKKOTAI2 BT01
	WHERE
		    BT01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND BT01.CIF_TOTSUGO_KEKKA_KBN = '2';
/*==============================================================================*/

/* IPW102SELECT                                                                 */

/*==============================================================================*/

	curIPW102SELECT CURSOR FOR
	SELECT
		M01.KOZA_TEN_CD,     -- 口座店コード
		M01.KOZA_TEN_CIFCD    -- 口座店CIFコード
	FROM
		MHAKKOTAI  M01,
		MHAKKOTAI2 BT01
	WHERE
		    BT01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND BT01.CIF_TOTSUGO_KEKKA_KBN = '9'
		AND M01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
		AND M01.HKT_CD = BT01.HKT_CD;
/*==============================================================================*/

/* IPI201SELECT                                                                 */

/*==============================================================================*/

	curIPI201SELECT CURSOR FOR
	SELECT
		COUNT(*) AS kensu  -- 件数
	FROM
		KIKIN_IDO K02
	WHERE
		    K02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND K02.KKN_IDO_KBN IN ('11','12','21','22')
		AND K02.DATA_SAKUSEI_KBN IN ('1','2')
		AND K02.IDO_YMD = gGyomuYmd1After;
/*==============================================================================*/

/* IPI202SELECT                                                                 */

/*==============================================================================*/

	curIPI202SELECT CURSOR FOR
	SELECT
		COUNT(*) AS kensu  -- 件数
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_TESKIJ MG4
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND MG4.TESU_SHURUI_CD IN ('11','12')
		AND VMG1.ITAKU_KAISHA_CD = MG4.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG4.MGR_CD
		AND MG4.CHOKYU_YMD = gGyomuYmd1After;
/*==============================================================================*/

/* IPI204SELECT                                                                 */

/*==============================================================================*/

	curIPI204SELECT CURSOR FOR
	SELECT
		CHOKYU_YMD,
		COUNT(*)
	FROM (SELECT
			K02.IDO_YMD AS CHOKYU_YMD    -- 異動年月日
		FROM
			MGR_KIHON_VIEW2 VMG2,
			KIKIN_IDO K02,
			MGR_TESURYO_CTL MG7
		WHERE
		    K02.TSUKA_CD = 'JPY'
			AND K02.IDO_YMD = gGyomuYmd6After
			AND ((K02.KKN_IDO_KBN = '11' AND VMG2.KOZA_FURI_KBN_GANKIN IN ('10','11','12','13','14'))
			OR (K02.KKN_IDO_KBN = '21' AND VMG2.KOZA_FURI_KBN_RIKIN IN ('10','11','12','13','14'))
			OR ((K02.KKN_IDO_KBN = '12'
				OR K02.KKN_IDO_KBN = '13')
				AND MG7.TESU_SHURUI_CD = '81'
				AND MG7.KOZA_FURI_KBN IN ('10','11','12','13','14'))
			OR ((K02.KKN_IDO_KBN = '22'
				OR K02.KKN_IDO_KBN = '23')
				AND MG7.TESU_SHURUI_CD IN ('61','82')
				AND MG7.KOZA_FURI_KBN IN ('10','11','12','13','14')))
			AND K02.DATA_SAKUSEI_KBN >= '1'
			AND VMG2.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD
			AND VMG2.MGR_CD = K02.MGR_CD
			AND VMG2.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
			AND VMG2.MGR_CD = MG7.MGR_CD
			AND VMG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
 	
UNION

	SELECT
		T01.CHOKYU_YMD AS CHOKYU_YMD    -- 異動年月日
	FROM
		MGR_KIHON_VIEW VMG1,
		TESURYO T01
	WHERE
		T01.TSUKA_CD = 'JPY'
		AND T01.CHOKYU_YMD = gGyomuYmd6After
		AND T01.TESU_SHURUI_CD IN ('11','12','41')
    	AND T01.KOZA_FURI_KBN IN ('10','11','12','13','14')
		AND T01.DATA_SAKUSEI_KBN >= '1'
		AND VMG1.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = T01.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd ) KOUHURIWK 
	GROUP BY
		CHOKYU_YMD;
	/*SELECT
		K02.IDO_YMD,   -- 異動年月日
		COUNT(*)       -- 件数
	FROM
		MGR_KIHON_VIEW VMG1,      -- 銘柄基本ビュー
		KIKIN_IDO K02,            -- 基金異動履歴
		MGR_TESURYO_CTL MG7       -- 銘柄手数料（制御情報）
	WHERE
		    K02.TSUKA_CD = 'JPY'
		AND K02.IDO_YMD = gGyomuYmd6After
		AND ((K02.KKN_IDO_KBN = '11' AND VMG1.KOZA_FURI_KBN IN ('10','11','12','13','14'))
			OR (K02.KKN_IDO_KBN = '21' AND VMG1.KOZA_FURI_KBN IN ('10','11','12','13','14'))
			OR ((K02.KKN_IDO_KBN = '12'
		     		OR K02.KKN_IDO_KBN = '13')
		    		AND MG7.TESU_SHURUI_CD = '81'
		    		AND MG7.KOZA_FURI_KBN IN ('10','11','12','13','14'))
			OR ((K02.KKN_IDO_KBN = '22'
		     		OR K02.KKN_IDO_KBN = '23')
		     		AND MG7.TESU_SHURUI_CD IN ('61','82')
		     		AND MG7.KOZA_FURI_KBN IN ('10','11','12','13','14')))
		AND K02.DATA_SAKUSEI_KBN >= '1'
		AND VMG1.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = K02.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG7.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	GROUP BY
		K02.IDO_YMD;*/
/*==============================================================================*/

/* IPW018SELECT                                                                 */

/*==============================================================================*/

	curIPW018SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,     -- ISINコード
		VMG1.MGR_RNM,     -- 銘柄略称
		VMG1.HAKKO_YMD     -- 発行年月日
	FROM
		MGR_KIHON_VIEW VMG1
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.MGR_STAT_KBN = '1'
		AND VMG1.JTK_KBN <> '2'
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
		AND VMG1.TOKUREI_SHASAI_FLG = 'N'
		AND VMG1.HAKKO_YMD > gGyomuYmd
		AND NOT(VMG1.SAIKEN_SHURUI IN ('80','89')
			AND VMG1.HAKKO_KAGAKU = 0)
		AND NOT EXISTS (
				SELECT
					B01.MGR_CD
				FROM
					SHINKIBOSHU B01
				WHERE
					    B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
					AND B01.MGR_CD = VMG1.MGR_CD
          and B01.shori_kbn='1'
          );
/*==============================================================================*/

/* IPW019SELECT                                                                 */

/*==============================================================================*/

	curIPW019SELECT CURSOR FOR
	SELECT  --新規記録情報未受信
		T1.ISIN_CD,
		T1.MGR_RNM,
		T1.HAKKO_YMD,
		T1.CNT AS CNT1,
		coalesce(T2.CNT,0) AS CNT2
	FROM (
		-- 未受信
		 SELECT
			VMG1.ITAKU_KAISHA_CD,
	                VMG1.MGR_CD,
	                VMG1.ISIN_CD,
	                VMG1.MGR_RNM,
	                VMG1.HAKKO_YMD,
	                COUNT(*) AS CNT
	         FROM
	         	MGR_KIHON_VIEW VMG1,
	                VSHINKI_REC_STATUS_MANAGEMENT B04
	         WHERE
			    VMG1.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD
	                AND VMG1.MGR_CD = B04.MGR_CD
	                AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	                AND VMG1.MGR_STAT_KBN = '1'
	                AND VMG1.HAKKO_YMD > gGyomuYmd
	                AND B04.DAIRI_MOTION_FLG != '1'            -- 0：機構加入者申請、1：代理人直接申請（VIEWは、機構申請は0、2がある）
	                AND B04.MASSHO_FLG <> '1'
	                AND B04.SHINCHOKU_STAT in ('H002', 'H103') -- H002：新規記録情報通知待ち、H103：新規記録情報取消通知待ち
	         GROUP BY
	                VMG1.ITAKU_KAISHA_CD,
	                VMG1.MGR_CD,
	                VMG1.ISIN_CD,
	                VMG1.MGR_RNM,
	                VMG1.HAKKO_YMD
	        ) t1
LEFT OUTER JOIN (
	         -- 受信済み
	         SELECT
	         	VMG1.ITAKU_KAISHA_CD,
	                VMG1.MGR_CD,
	                VMG1.ISIN_CD,
	                VMG1.MGR_RNM,
	                VMG1.HAKKO_YMD,
	                COUNT(*) AS CNT
	         FROM
	                MGR_KIHON_VIEW VMG1,
	                VSHINKI_REC_STATUS_MANAGEMENT B04
	         WHERE
			    VMG1.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD
	                AND VMG1.MGR_CD = B04.MGR_CD
	                AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	                AND VMG1.MGR_STAT_KBN = '1'
	                AND VMG1.HAKKO_YMD > gGyomuYmd
	                AND B04.DAIRI_MOTION_FLG != '1'  -- 0：機構加入者申請、1：代理人直接申請（VIEWは、機構申請は0、2がある）
	                AND B04.MASSHO_FLG <> '1'
	                AND B04.TOTSUGO_KEKKA_KBN != '3' -- 3：突合相手なし
	                AND B04.SHINCHOKU_STAT != 'H401' -- H401：新規募集情報承認待ち
	                AND B04.SHINCHOKU_STAT != 'H002' -- H002：新規記録情報通知待ち
	                AND B04.SHINCHOKU_STAT != 'H103' -- H103：新規記録情報取消通知待ち
	                AND B04.SHINCHOKU_STAT != 'H004' -- H004：新規記録情報取消完了
	         GROUP BY
	                VMG1.ITAKU_KAISHA_CD,
	                VMG1.MGR_CD,
	                VMG1.ISIN_CD,
	                VMG1.MGR_RNM,
	                VMG1.HAKKO_YMD
	         ) t2 ON (T1.ITAKU_KAISHA_CD = T2.ITAKU_KAISHA_CD AND T1.MGR_CD = T2.MGR_CD);
/*==============================================================================*/

/* IPW020SELECT                                                                 */

/*==============================================================================*/

	curIPW020SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,         -- ISINコード
		VMG1.MGR_RNM,         -- 銘柄略称
		VMG1.HAKKO_YMD,       -- 発行年月日
		'決済番号：' || B04.KESSAI_NO AS BIKO1, --予備１
		'金融機関：' || PKIPANAME.getBankRnm(B04.ITAKU_KAISHA_CD,B04.KAI_BANKID_CD,0,1) AS BIKO2 --予備２
	FROM
		MGR_KIHON_VIEW VMG1,
		SHINKIKIROKU B04
	WHERE
		    VMG1.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD
		AND VMG1.ISIN_CD = B04.ISIN_CD  -- ←項目なし
		AND B04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND B04.KK_PHASE || B04.KK_STAT IN ('H003','H101','H102')
		AND VMG1.MGR_STAT_KBN = '1'
		AND VMG1.JTK_KBN <> '2'
		AND VMG1.HAKKO_YMD > gGyomuYmd
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
		AND VMG1.TOKUREI_SHASAI_FLG = 'N';
/*==============================================================================*/

/* IPW009SELECT                                                                 */

/*==============================================================================*/

	curIPW009SELECT CURSOR FOR
	SELECT
		Z01.ITAKU_KAISHA_CD,  -- 委託会社コード
		Z01.MGR_CD,           -- 銘柄コード
		VMG1.ISIN_CD,	      -- ISINコード
		VMG1.MGR_RNM,         -- 銘柄略称
		Z01.SHOKAN_YMD,       -- 償還年月日
		Z01.GENSAI_KNGK,      -- 減債金額
		M01.KOZA_TEN_CD,      -- 口座店コード
		M01.KOZA_TEN_CIFCD,   -- 口座店CIFコード
		VMG1.SHOKAN_METHOD_CD  -- 償還方法コード
	FROM
		GENSAI_RIREKI Z01,
		MGR_KIHON_VIEW VMG1,
		MHAKKOTAI M01
	WHERE
		    Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND Z01.SHOKAN_YMD = gGyomuYmd
		AND Z01.SHOKAN_KBN = '30'
		AND Z01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		AND Z01.MGR_CD = VMG1.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD;
/*==============================================================================*/

/* IPW011SELECT                                                                 */

/*==============================================================================*/

	curIPW011SELECT CURSOR FOR
	SELECT
		COUNT(*) AS CNT,      -- 件数
		SUM(Z02.JISSHITSU_KNGK) AS JISSHITSU_KNGK, -- 実質金額
		SUM(Z02.KNGK) AS KNGK  -- 金額
	FROM
		TSUCHIJOHO Z02
	WHERE
		    Z02.ITAKU_KAISHA_CD = gIPW009ItakuKaishaCd
		AND Z02.KESSAI_YMD = gIPW009ShokanYmd
		AND Z02.FILE_SHUBETSU_CD = '20'
		AND Z02.ISIN_CD = gIPW009IsinCd
	GROUP BY
		Z02.ISIN_CD,
		Z02.KESSAI_YMD;
/*==============================================================================*/

/* IPW008SELECT                                                                 */

/*==============================================================================*/

	curIPW008SELECT CURSOR FOR
	SELECT
		Z01.ITAKU_KAISHA_CD,
		Z01.GENSAI_KNGK,
		Z01.MGR_CD,
		VMG1.ISIN_CD,
		VMG1.SHOKAN_METHOD_CD,
		VMG1.MGR_RNM,
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD,
		Z01.SHOKAN_YMD
	FROM
		GENSAI_RIREKI Z01,
		MGR_KIHON_VIEW VMG1,
		MHAKKOTAI M01
	WHERE
		    Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND Z01.SHOKAN_YMD = gGyomuYmd
		AND Z01.SHOKAN_KBN IN ('10','40','50')
		AND VMG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = Z01.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
	
UNION ALL

	SELECT
		Z01.ITAKU_KAISHA_CD,
		coalesce(Z01.GENSAI_KNGK,0) AS GENSAI_KNGK,
		Z01.MGR_CD,
		VMG1.ISIN_CD,
		VMG1.SHOKAN_METHOD_CD,
		VMG1.MGR_RNM,
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD,
		Z01.SHOKAN_YMD
	FROM
		GENSAI_RIREKI Z01,
		MGR_SHOKIJ MG3,
		MGR_KIHON_VIEW VMG1,
		MHAKKOTAI M01
	WHERE
		    Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND Z01.SHOKAN_YMD = gGyomuYmd
		AND Z01.SHOKAN_KBN = ('21')
		AND MG3.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
		AND MG3.MGR_CD = Z01.MGR_CD
		AND MG3.SHOKAN_YMD = Z01.SHOKAN_YMD
		AND MG3.SHOKAN_KBN = Z01.SHOKAN_KBN
		AND MG3.KAIJI =
			(
			SELECT
				MAX(MG3.KAIJI)
			FROM
				GENSAI_RIREKI Z01,
				MGR_SHOKIJ MG3
			WHERE
				    MG3.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
				AND MG3.MGR_CD = Z01.MGR_CD
			)
		AND VMG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = Z01.MGR_CD
		AND VMG1.MGR_CD = Z01.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD;
/*==============================================================================*/

/* IPW008SELECT                                                                 */

/*==============================================================================*/

	curIPW008SELECT_01 CURSOR FOR
	SELECT
		K01.FINANCIAL_SECURITIES_KBN || K01.BANK_CD || K01.KOZA_KBN AS KIKO_KANYUSYA_CD  -- 機構加入者コード
	FROM
		KIKIN_SEIKYU K01,
		MGR_KIHON_VIEW VMG1
	WHERE
		VMG1.ITAKU_KAISHA_CD = gIPW008ItakuKaishaCd
		AND VMG1.MGR_CD = gIPW008MgrCd
		AND VMG1.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = K01.MGR_CD
		AND K01.SHR_YMD = gIPW008ShokanYmd
		AND coalesce(trim(both K01.MASSHO_STATE),'0') = '0'
		AND VMG1.SHOKAN_TSUKA_CD = K01.TSUKA_CD;
/*==============================================================================*/

/* IPW010SELECT                                                                 */

/*==============================================================================*/

	curIPW010SELECT CURSOR FOR
	SELECT
		COUNT(*) AS CNT, -- 件数
		SUM((coalesce(trim(both RT02.ITEM020), 0))::numeric ) RT02_KNGK 	    -- 金額
	FROM
		KK_RENKEI RT02
	WHERE
		RT02.KK_SAKUSEI_DT LIKE gGyomuYmd || '%'	        -- 取り込み日時
		AND RT02.JIP_DENBUN_CD = 'R0211'     -- 電文コード
    AND RT02.ITEM013 = gIPW008IsinCd
		AND trim(both RT02.SR_BIC_CD) = trim(both gBicCd)          -- 送受信者BICコード
		AND (coalesce(trim(both RT02.GYOMU_STAT_CD)::text, '') = ''
		OR trim(both RT02.GYOMU_STAT_CD) != '99')	-- 業務状態コードが'99'(論理削除)以外
		AND trim(both RT02.SOUJU_ERR_CD) NOT IN ('10', '99','41');		-- フォーマットエラー、対象データなしエラー、業務処理エラーを除く
/*==============================================================================*/

/* IPW012SELECT                                                                 */

/*==============================================================================*/

	curIPW012SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		MG2.RBR_YMD,   -- 利払日
		'1' AS HANTEI_FLG  -- 判定フラグ
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_RBRKIJ MG2
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.KK_KANYO_FLG = '0'
		AND VMG1.JIKO_TOTAL_HKUK_KBN = '0'
		AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND MG2.RBR_YMD = gGyomuYmd3After
		AND NOT EXISTS (SELECT * FROM KIKIN_SEIKYU K01 WHERE K01.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND K01.SHR_YMD = MG2.RBR_YMD
									AND K01.MGR_CD = MG2.MGR_CD AND K01.SHORI_KBN = '1')
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		MG3.SHOKAN_YMD,   -- 利払日
		'1' AS HANTEI_FLG  -- 判定フラグ
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.KK_KANYO_FLG = '0'
		AND VMG1.JIKO_TOTAL_HKUK_KBN = '0'
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND MG3.SHOKAN_YMD = gGyomuYmd3After
		AND MG3.SHOKAN_KBN IN ('10','20','21','40','41','50')
		AND NOT EXISTS (SELECT * FROM KIKIN_SEIKYU K01 WHERE K01.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND K01.SHR_YMD = MG3.SHOKAN_YMD
									AND K01.MGR_CD = MG3.MGR_CD AND K01.SHORI_KBN = '1') 
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		MG2.RBR_YMD,   -- 利払日
		'2' AS HANTEI_FLG  -- 判定フラグ
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_RBRKIJ MG2
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND (VMG1.KK_KANYO_FLG = '0'
		OR (VMG1.KK_KANYO_FLG = '2' AND gOpFlg = '1'))
		AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND MG2.RBR_YMD = gGyomuYmd2After
		AND NOT EXISTS (SELECT * FROM KIKIN_SEIKYU K01 WHERE K01.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND K01.SHR_YMD = MG2.RBR_YMD
									AND K01.MGR_CD = MG2.MGR_CD AND K01.SHORI_KBN = '1') 
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		MG3.SHOKAN_YMD,   -- 利払日
		'2' AS HANTEI_FLG  -- 判定フラグ
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND (VMG1.KK_KANYO_FLG = '0'
		OR (VMG1.KK_KANYO_FLG = '2' AND gOpFlg = '1'))
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND MG3.SHOKAN_YMD = gGyomuYmd2After
		AND MG3.SHOKAN_KBN IN ('10','20','21','40','41','50')
		AND NOT EXISTS (SELECT * FROM KIKIN_SEIKYU K01 WHERE K01.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND K01.SHR_YMD = MG3.SHOKAN_YMD
									AND K01.MGR_CD = MG3.MGR_CD AND K01.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI004SELECT_1                                                               */

/*==============================================================================*/

	curIPI004SELECT_1 CURSOR FOR
	SELECT
		MG2_2.ISIN_CD, -- ISINコード
		MG2_2.MGR_RNM, -- 銘柄略称
		MG2_2.RBR_YMD, -- 利払日
		MG2_2.RBR_KJT,
		MG2_2.RBR_YMD2,
		MG2_2.KOZA_TEN_CD,
		MG2_2.KOZA_TEN_CIFCD
	FROM
		(
	         	SELECT
		                MG2.ITAKU_KAISHA_CD,
		                MG2.MGR_CD,
		                MIN(MG2.RBR_YMD) AS RBR_YMD,
		                MIN(MG2.RBR_KJT) AS RBR_KJT,
		                MIN(MG2_1.RBR_YMD) AS RBR_YMD2,
		                VMG1.ISIN_CD,
		                VMG1.MGR_RNM,
		                M01.KOZA_TEN_CD,
		                M01.KOZA_TEN_CIFCD
	                FROM
	                	MGR_RBRKIJ MG2,
	                        (
	                         	SELECT
		                                MG2.ITAKU_KAISHA_CD,
		                                MG2.MGR_CD,
		                                MG2.RBR_YMD,
		                                MG2.RBR_KJT,
		                                MG2.KAIJI
	                                FROM
	                                        MGR_RBRKIJ MG2
	                                WHERE (MG2.RBR_YMD = gGyomuYmd5After
	                                        OR MG2.RBR_YMD = gGyomuYmd4After
	                                        OR MG2.RBR_YMD = gGyomuYmd3After
	                                        OR MG2.RBR_YMD = gGyomuYmd2After
	                                        OR MG2.RBR_YMD = gGyomuYmd1After)
	                                        AND MG2.KAIJI <> 0
	                        ) MG2_1,
	                        MGR_KIHON_VIEW VMG1,
	                        MHAKKOTAI M01
	                WHERE
		                MG2_1.RBR_YMD < MG2.RBR_YMD
		                AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		                AND MG2_1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		                AND MG2_1.MGR_CD = MG2.MGR_CD
		                AND VMG1.ITAKU_KAISHA_CD = MG2_1.ITAKU_KAISHA_CD
		                AND VMG1.MGR_CD = MG2_1.MGR_CD
		                AND (coalesce(trim(both VMG1.KIJUN_KINRI_CD1)::text, '') = ''
		                     OR trim(both VMG1.KIJUN_KINRI_CD1) = '700')
		                AND (MG2.KAIJI <> '1' AND MG2.KAIJI <> '0')
		                AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		                AND VMG1.HKT_CD = M01.HKT_CD
		                AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
		               -- AND (MG2.KAIJI = '1' AND MG2.RBR_YMD < gGyomuYmd)
	                GROUP BY
	                        MG2.ITAKU_KAISHA_CD,
	                        MG2.MGR_CD,
	                        VMG1.ISIN_CD,
	                        VMG1.MGR_RNM,
	                        M01.KOZA_TEN_CD,
	                        M01.KOZA_TEN_CIFCD
	        ) MG2_2
	WHERE
		NOT EXISTS (
	                    	SELECT
	                        	*
	                        FROM
	                        	UPD_MGR_RBR MG22
	                        WHERE
	                                MG22.ITAKU_KAISHA_CD = MG2_2.ITAKU_KAISHA_CD
	                                AND MG22.SHR_KJT = MG2_2.RBR_KJT
	                                AND MG22.MGR_CD = MG2_2.MGR_CD
	                                AND MG22.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI004SELECT_2                                                               */

/*==============================================================================*/

	curIPI004SELECT_2 CURSOR FOR
	SELECT
		MG2_2.ISIN_CD, -- ISINコード
		MG2_2.MGR_RNM, -- 銘柄略称
		MG2_2.RBR_YMD, -- 利払日
		MG2_2.RBR_KJT,
		MG2_2.RBR_YMD2,
		MG2_2.KOZA_TEN_CD,
		MG2_2.KOZA_TEN_CIFCD
	FROM
		(
	         	SELECT
		                MG2.ITAKU_KAISHA_CD,
		                MG2.MGR_CD,
		                MIN(MG2.RBR_YMD) AS RBR_YMD,
		                MIN(MG2.RBR_KJT) AS RBR_KJT,
		                MIN(MG2_1.RBR_YMD) AS RBR_YMD2,
		                VMG1.ISIN_CD,
		                VMG1.MGR_RNM,
		                M01.KOZA_TEN_CD,
		                M01.KOZA_TEN_CIFCD
	                FROM
	                	MGR_RBRKIJ MG2,
	                        (
	                         	SELECT
		                                MG2.ITAKU_KAISHA_CD,
		                                MG2.MGR_CD,
		                                MG2.RBR_YMD,
		                                MG2.RBR_KJT,
		                                MG2.KAIJI
	                                FROM
	                                        MGR_RBRKIJ MG2
	                                WHERE (MG2.RBR_YMD = gGyomuYmd5After
	                                        OR MG2.RBR_YMD = gGyomuYmd4After
	                                        OR MG2.RBR_YMD = gGyomuYmd3After
	                                        OR MG2.RBR_YMD = gGyomuYmd2After
	                                        OR MG2.RBR_YMD = gGyomuYmd1After)
	                                        AND MG2.KAIJI <> 0
	                        ) MG2_1,
	                        MGR_KIHON_VIEW VMG1,
	                        MHAKKOTAI M01
	                WHERE
		                MG2_1.RBR_YMD < MG2.RBR_YMD
		                AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		                AND MG2_1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		                AND MG2_1.MGR_CD = MG2.MGR_CD
		                AND VMG1.ITAKU_KAISHA_CD = MG2_1.ITAKU_KAISHA_CD
		                AND VMG1.MGR_CD = MG2_1.MGR_CD
		                AND (MG2.KAIJI <> '1' AND MG2.KAIJI <> '0')
		                AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		                AND VMG1.HKT_CD = M01.HKT_CD
		                AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
		              --  AND (MG2.KAIJI = '1' AND MG2.RBR_YMD < gGyomuYmd)
 
	                GROUP BY
	                        MG2.ITAKU_KAISHA_CD,
	                        MG2.MGR_CD,
	                        VMG1.ISIN_CD,
	                        VMG1.MGR_RNM,
	                        M01.KOZA_TEN_CD,
	                        M01.KOZA_TEN_CIFCD
	        ) MG2_2
	WHERE
		NOT EXISTS (
	                    	SELECT
	                        	*
	                        FROM
	                        	UPD_MGR_RBR MG22
	                        WHERE
	                                MG22.ITAKU_KAISHA_CD = MG2_2.ITAKU_KAISHA_CD
	                                AND MG22.SHR_KJT = MG2_2.RBR_KJT
	                                AND MG22.MGR_CD = MG2_2.MGR_CD
	                                AND MG22.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI004SELECT_3                                                               */

/*==============================================================================*/

	curIPI004SELECT_3 CURSOR FOR
	SELECT
		MG2_2.ISIN_CD, -- ISINコード
		MG2_2.MGR_RNM, -- 銘柄略称
		MG2_2.RBR_YMD, -- 利払日
		MG2_2.RBR_KJT,
		MG2_2.KOZA_TEN_CD,
		MG2_2.KOZA_TEN_CIFCD
	FROM
	(
	SELECT
		MG2.ITAKU_KAISHA_CD,
		MG2.MGR_CD,
		VMG1.ISIN_CD,
		VMG1.MGR_RNM,
		MIN(MG2.RBR_YMD) AS RBR_YMD,
		MIN(MG2.RBR_KJT) AS RBR_KJT,
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_RBRKIJ MG2,
		(SELECT ITAKU_KAISHA_CD,MGR_CD,RBR_YMD FROM MGR_RBRKIJ WHERE KAIJI = '1') MG2WK,
		MHAKKOTAI M01
	WHERE
		VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = MG2WK.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2WK.MGR_CD
		AND (coalesce(trim(both VMG1.KIJUN_KINRI_CD1)::text, '') = ''
		 OR trim(both VMG1.KIJUN_KINRI_CD1) = '700')
		AND (MG2.KAIJI <> '1' AND MG2.KAIJI <> '0')
                AND MG2.RBR_YMD > gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
		AND MG2WK.RBR_YMD <= gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	GROUP BY
		MG2.ITAKU_KAISHA_CD,
		MG2.MGR_CD,
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD
	) MG2_2
	WHERE
		NOT EXISTS (
	                    	SELECT
	                        	*
	                        FROM
	                        	UPD_MGR_RBR MG22
	                        WHERE
	                                MG22.ITAKU_KAISHA_CD = MG2_2.ITAKU_KAISHA_CD
	                                AND MG22.SHR_KJT = MG2_2.RBR_KJT
	                                AND MG22.MGR_CD = MG2_2.MGR_CD
	                                AND MG22.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI004SELECT_4                                                               */

/*==============================================================================*/

	curIPI004SELECT_4 CURSOR FOR
	SELECT
		MG2_2.ISIN_CD, -- ISINコード
		MG2_2.MGR_RNM, -- 銘柄略称
		MG2_2.RBR_YMD, -- 利払日
		MG2_2.RBR_KJT,
		MG2_2.KOZA_TEN_CD,
		MG2_2.KOZA_TEN_CIFCD
	FROM
	(
	SELECT
		MG2.ITAKU_KAISHA_CD,
		MG2.MGR_CD,
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		MIN(MG2.RBR_YMD) AS RBR_YMD, -- 利払日
		MIN(MG2.RBR_KJT) AS RBR_KJT, -- 利払期日
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_RBRKIJ MG2,
		(SELECT ITAKU_KAISHA_CD,MGR_CD,RBR_YMD FROM MGR_RBRKIJ WHERE KAIJI = '1') MG2WK,
		MHAKKOTAI M01
	WHERE
		VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = MG2WK.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2WK.MGR_CD
		AND (MG2.KAIJI <> '1' AND MG2.KAIJI <> '0')
                AND MG2.RBR_YMD > gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
		AND MG2WK.RBR_YMD <= gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	GROUP BY
		MG2.ITAKU_KAISHA_CD,
		MG2.MGR_CD,
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD
	) MG2_2
	WHERE
		NOT EXISTS (
	                    	SELECT
	                        	*
	                        FROM
	                        	UPD_MGR_RBR MG22
	                        WHERE
	                                MG22.ITAKU_KAISHA_CD = MG2_2.ITAKU_KAISHA_CD
	                                AND MG22.SHR_KJT = MG2_2.RBR_KJT
	                                AND MG22.MGR_CD = MG2_2.MGR_CD
	                                AND MG22.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI004SELECT_5                                                               */

/*==============================================================================*/

	curIPI004SELECT_5 CURSOR FOR
	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM, -- 銘柄略称
		MG2.RBR_YMD,   -- 利払日
		MG2.RBR_KJT,   -- 利払期日
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_RBRKIJ MG2,
		MHAKKOTAI M01
	WHERE
	    	    VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND MG2.KAIJI = '1'
		AND VMG1.HAKKO_YMD <= gGyomuYmd
                AND MG2.RBR_YMD >= gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
		AND VMG1.RIRITSU = 99.9999999
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND NOT EXISTS (
			    	SELECT
					*
				FROM
					UPD_MGR_RBR MG22
				WHERE
					MG22.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
					AND MG22.SHR_KJT = MG2.RBR_KJT
					AND MG22.MGR_CD = MG2.MGR_CD
					AND MG22.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI203SELECT                                                                */

/*==============================================================================*/

	curIPI203SELECT CURSOR FOR
	SELECT
		MG2.RBR_YMD AS RBR_YMD
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_RBRKIJ MG2,
		(
		SELECT
			SKN_KESSAI_CD
		FROM
			SOWN_INFO SC18
		WHERE
			JIKO_DAIKO_KBN = '1'
		) SC18_WK
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SKN_KESSAI_CD = SC18_WK.SKN_KESSAI_CD
		AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND MG2.RBR_YMD = gGyomuYmd2After
	
UNION

	SELECT
		MG3.SHOKAN_YMD AS RBR_YMD
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		(
		SELECT
			SKN_KESSAI_CD
		FROM
			SOWN_INFO SC18
		WHERE
			JIKO_DAIKO_KBN = '1'
		) SC18_WK 
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SKN_KESSAI_CD = SC18_WK.SKN_KESSAI_CD
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND MG3.SHOKAN_YMD = gGyomuYmd2After;
/*==============================================================================*/

/* IPW201SELECT                                                                 */

/*==============================================================================*/

	curIPW201SELECT CURSOR FOR
	SELECT
		MG23_WK.SHR_KJT, -- 支払期日
		VMG1.ISIN_CD,    -- ISINコード
		VMG1.MGR_RNM,    -- 銘柄略称
		MG23_WK.CODE_RNM  -- コード略称
	FROM
		MGR_KIHON_VIEW VMG1,
		MITAKU_KAISHA2 BT02,
		MGR_RBRKIJ MG2,
		(
			SELECT
				MG23.ITAKU_KAISHA_CD, -- 委託会社コード
				MG23.MGR_CD,          -- 銘柄コード
				MG23.SHR_KJT,         -- 支払期日
				MG23.MGR_HENKO_KBN,   -- 銘柄情報変更区分
				MG3.SHOKAN_YMD,       -- 償還日
				SC04_WK.CODE_RNM       -- コード略称
			FROM
				UPD_MGR_SHN MG23,
				MGR_SHOKIJ MG3,
				(
					SELECT
						*
					FROM
						SCODE SC04
					WHERE
						CODE_SHUBETSU = '109'
				) SC04_WK
			WHERE
				    TO_CHAR(MG23.SHONIN_DT,'YYYYMMDD') = gGyomuYmd
				AND MG23.MGR_HENKO_KBN <> '30'
				AND MG23.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
				AND MG23.MGR_CD = MG3.MGR_CD
				AND MG23.SHR_KJT = MG3.SHOKAN_KJT
				AND MG23.MGR_HENKO_KBN = MG3.SHOKAN_KBN
				AND MG23.MGR_HENKO_KBN = SC04_WK.CODE_VALUE
			) MG23_WK
	WHERE
		    BT02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND BT02.SAIKEN_DAIKO_UMU = '1'
		AND BT02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		AND VMG1.ITAKU_KAISHA_CD = MG23_WK.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG23_WK.MGR_CD
		AND MG2.ITAKU_KAISHA_CD = MG23_WK.ITAKU_KAISHA_CD
		AND MG2.MGR_CD = MG23_WK.MGR_CD
		AND ((MG2.RBR_YMD BETWEEN pkDate.getPlusDateBusiness(MG23_WK.SHOKAN_YMD::character varying,1::integer)
				       AND pkDate.getPlusDateBusiness(MG23_WK.SHOKAN_YMD::character varying,3::integer))
			OR (MG2.RBR_YMD BETWEEN pkDate.getMinusDateBusiness(MG23_WK.SHOKAN_YMD::character varying,3::integer)
				       AND pkDate.getMinusDateBusiness(MG23_WK.SHOKAN_YMD::character varying,1::integer)));
/*==============================================================================*/

/* IPW006SELECT                                                                 */

/*==============================================================================*/

	curIPW006SELECT CURSOR FOR
	SELECT DISTINCT
		VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
		VMG1.MGR_CD,        -- 銘柄コード
		VMG1.ISIN_CD,       -- ISINコード
		VMG1.MGR_RNM,       -- 銘柄略称
		M01.KOZA_TEN_CD,    -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		MG3.SHOKAN_YMD,     -- 償還年月日
		MG3.KAIJI            -- 回次
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01,
		(
			SELECT
				KEY_CD, -- 識別コード
				ITEM001,-- アイテム１
				ITEM002 -- アイテム２
			FROM
				SREPORT_WK SC16
			WHERE
				    KEY_CD = l_inItakuKaishaCd
				AND SAKUSEI_YMD = gGyomuYmd
				AND CHOHYO_ID = 'KW931504651'
				AND HEADER_FLG = '1'
				AND NOT EXISTS (SELECT * FROM UPD_MGR_SHN MG23
							WHERE       SC16.KEY_CD = MG23.ITAKU_KAISHA_CD
								AND SC16.ITEM001 = MG23.MGR_CD
								AND SC16.ITEM002 = MG23.SHR_KJT
								AND MG23.MGR_HENKO_KBN = '21'
								AND MG23.SHORI_KBN = '1')
		) SC16_WK 
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'
 		AND MG3.SHOKAN_KBN = '21'
		AND VMG1.ITAKU_KAISHA_CD = SC16_WK.KEY_CD
		AND VMG1.MGR_CD = SC16_WK.ITEM001
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG3.ITAKU_KAISHA_CD = SC16_WK.KEY_CD
		AND MG3.MGR_CD = SC16_WK.ITEM001
		AND MG3.SHOKAN_KJT = SC16_WK.ITEM002;
/*==============================================================================*/

/* IPW006_01SELECT                                                              */

/*==============================================================================*/

	curIPW006_01SELECT CURSOR FOR
	SELECT
		COUNT(*) AS Kensu
	FROM
		MGR_KIHON_VIEW VMG1
	WHERE
		    VMG1.ITAKU_KAISHA_CD = gIPW006ItakuKaishaCd
		AND VMG1.MGR_CD = gIPW006MgrCd
		AND VMG1.TEIJI_SHOKAN_KNGK = 0;
/*==============================================================================*/

/* IPW007SELECT                                                                 */

/*==============================================================================*/

	curIPW007SELECT CURSOR FOR
	SELECT DISTINCT
		VMG1.ITAKU_KAISHA_CD,
		VMG1.MGR_CD,        -- 銘柄コード
		VMG1.ISIN_CD,       -- ISINコード
		VMG1.MGR_RNM,       -- 銘柄略称
		M01.KOZA_TEN_CD,    -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		MG2.RBR_YMD,        -- 利払年月日
		MG2.KAIJI            -- 回次
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_RBRKIJ MG2,
		MHAKKOTAI M01,
		(
			SELECT
				KEY_CD, -- 識別コード
				ITEM001,-- アイテム１
				ITEM002 -- アイテム２
			FROM
				SREPORT_WK SC16
			WHERE
				    KEY_CD = l_inItakuKaishaCd
				AND SAKUSEI_YMD = gGyomuYmd
				AND CHOHYO_ID = 'KW931504651'
				AND HEADER_FLG = '1'
				AND NOT EXISTS (SELECT * FROM UPD_MGR_RBR MG22
							WHERE       SC16.KEY_CD = MG22.ITAKU_KAISHA_CD
								AND SC16.ITEM001 = MG22.MGR_CD
								AND SC16.ITEM002 = MG22.SHR_KJT
								AND MG22.SHORI_KBN = '1')
		) SC16_WK 
	WHERE
		    VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
		AND MG2.KAIJI <> 0
		AND VMG1.ITAKU_KAISHA_CD = SC16_WK.KEY_CD
		AND VMG1.MGR_CD = SC16_WK.ITEM001
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG2.ITAKU_KAISHA_CD = SC16_WK.KEY_CD
		AND MG2.MGR_CD = SC16_WK.ITEM001
		AND MG2.RBR_KJT = SC16_WK.ITEM002;
/*==============================================================================*/

/* IPW007_01SELECT                                                              */

/*==============================================================================*/

	curIPW007_01SELECT CURSOR FOR
	SELECT
		COUNT(*) AS Kensu
	FROM
		MGR_KIHON_VIEW VMG1
	WHERE
		    VMG1.ITAKU_KAISHA_CD = gIPW007ItakuKaishaCd
		AND VMG1.MGR_CD = gIPW007MgrCd
		AND VMG1.RIRITSU = '99.9999999';
/*==============================================================================*/

/* IPI205SELECT                                                                 */

/*==============================================================================*/

	curIPI205SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,       -- ISINコード
		VMG1.MGR_RNM,       -- 銘柄略称
		M01.KOZA_TEN_CD,    -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		VMG1.HAKKO_YMD       -- 発行年月日
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9,
		MGR_STS MG0,
		MHAKKOTAI M01
	WHERE
		    VMG1.HAKKO_YMD > gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') < gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG0.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG0.HRKM_OUT_FLG = '1'
		AND MG0.HAKKO_TESU_TEISEI_YMD = gGyomuYmd;
/*==============================================================================*/

/* IPI003SELECT                                                               */

/*==============================================================================*/

	curIPI003SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD,       -- ISINコード
		VMG1.MGR_RNM,       -- 銘柄略称
		M01.KOZA_TEN_CD,    -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		VMG1.HAKKO_YMD       -- 発行年月日
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9,
		MGR_STS MG0,
		MHAKKOTAI M01
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.HAKKO_YMD > gGyomuYmd
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') < gGyomuYmd
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG0.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND (MG0.KICHU_TESU_TEISEI_YMD = gGyomuYmd
		OR  MG0.KICHU_KAIJI_TEISEI_YMD = gGyomuYmd
		OR  MG0.RBR_KAIJI_TEISEI_YMD = gGyomuYmd
		OR  MG0.SHOKAN_KAIJI_TEISEI_YMD = gGyomuYmd);
/*==============================================================================*/

/* IPI104SELECT                                                                 */

/*==============================================================================*/

	curIPI104SELECT CURSOR FOR
	SELECT
		BT03_WK.KENSU,
		BT03_WK.ISIN_CD,
		M01.KOZA_TEN_CD,
		M01.KOZA_TEN_CIFCD,
		MG1.MGR_RNM,
		BT03_WK.RIRITSU_KETTEI_YMD,
		BT03_WK.KIJUN_KINRI_CD1,
		BT03_WK.KINRIMAX,
		BT03_WK.KINRIFLOOR,
		SC04_WK01.CODE_NM AS CODE_NM1,
		SC04_WK02.CODE_NM AS CODE_NM2,
		SC04_WK03.CODE_NM AS CODE_NM3
	FROM (
			SELECT
				*
			FROM
				SCODE SC04
			WHERE
				CODE_SHUBETSU = '140'
		) sc04_wk01, mgr_kihon mg1, mhakkotai m01, (
		SELECT
			COUNT(*) AS KENSU,
			MIN(VMG2.ISIN_CD) AS ISIN_CD,
			MG2.RIRITSU_KETTEI_YMD,
			VMG2.KIJUN_KINRI_CD1,
			VMG2.KINRIMAX,
			VMG2.KINRIFLOOR
		FROM
			MGR_KIHON_VIEW2 VMG2,
			MGR_RBRKIJ MG2,
			MHAKKOTAI M01
		WHERE
			    VMG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND VMG2.RITSUKE_WARIBIKI_KBN = 'V'
			AND VMG2.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
			AND VMG2.MGR_CD = MG2.MGR_CD
			AND VMG2.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND VMG2.HKT_CD = M01.HKT_CD
			AND MG2.KAIJI <> 1
			AND MG2.KAIJI <> 0
			AND (trim(both VMG2.KIJUN_KINRI_CD1) IS NOT NULL AND (trim(both VMG2.KIJUN_KINRI_CD1))::text <> '')
			AND trim(both VMG2.KIJUN_KINRI_CD1) <> 700
			AND MG2.RIRITSU_KETTEI_YMD <= gGyomuYmd1After
			AND MG2.RBR_YMD >= gGyomuYmd1After
			AND NOT EXISTS ( SELECT * FROM UPD_MGR_RBR MG22 where MG22.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
										AND MG2.MGR_CD = MG22.MGR_CD
										AND MG2.RBR_KJT = MG22.SHR_KJT
										AND MG22.SHORI_KBN = '1')
		GROUP BY
			MG2.RIRITSU_KETTEI_YMD,
			VMG2.KIJUN_KINRI_CD1,
			VMG2.KINRIMAX,
			VMG2.KINRIFLOOR
		) bt03_wk
LEFT OUTER JOIN (
			SELECT
				*
			FROM
				SCODE SC04
			WHERE
				CODE_SHUBETSU = '140'
		) sc04_wk02 ON (BT03_WK.KINRIMAX = SC04_WK02.CODE_VALUE)
LEFT OUTER JOIN (
			SELECT
				*
			FROM
				SCODE SC04
			WHERE
				CODE_SHUBETSU = '140'
		) sc04_wk03 ON (BT03_WK.KINRIFLOOR = SC04_WK03.CODE_VALUE)
WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND BT03_WK.ISIN_CD = MG1.ISIN_CD AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD AND BT03_WK.KIJUN_KINRI_CD1 = SC04_WK01.CODE_VALUE;
/*==============================================================================*/

/* IPI002SELECT_01                                                              */

/*==============================================================================*/

	curIPI002SELECT_01 CURSOR FOR
	SELECT
		VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
		VMG1.MGR_CD,        -- 銘柄コード
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM,  -- 銘柄略称
		M01.KOZA_TEN_CD, -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		MG3.SHOKAN_YMD,     -- 償還日
		MG3.SHOKAN_KJT,     -- 償還期日
		MG3.KAIJI,           -- 回次
		VMG1.TEIJI_SHOKAN_KNGK     -- 定時償還額
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01,
		(SELECT
			ITAKU_KAISHA_CD,
			MGR_CD,
			CHOOSE_FLG
		 FROM
		 	MGR_TESURYO_CTL
		 WHERE
			TESU_SHURUI_CD = '81'
		) WK1
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.JTK_KBN <> '2'
		AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'
		AND MG3.SHOKAN_KBN = '21'
		-- 月中：当月（翌営以降）償還分・翌月償還分／月末：翌月〜翌々月償還分
		AND (MG3.SHOKAN_YMD  BETWEEN  gGessyoYmdAfter AND gGetsumatuYmdAfter
			OR (SUBSTR(MG3.SHOKAN_YMD,1,6) = SUBSTR(gGyomuYmd,1,6) AND MG3.SHOKAN_YMD > gGyomuYmd)
		)
		AND VMG1.ITAKU_KAISHA_CD = WK1.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = WK1.MGR_CD
		AND (MG3.KKNBILL_OUT_YMD = ' ' OR (WK1.CHOOSE_FLG = '1' AND  MG3.TESUBILL_OUT_YMD = ' '))
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND NOT EXISTS (SELECT *
			       FROM UPD_MGR_SHN MG23
			       WHERE  MG3.ITAKU_KAISHA_CD = MG23.ITAKU_KAISHA_CD
				      AND MG3.MGR_CD = MG23.MGR_CD
				      AND MG3.SHOKAN_KJT = MG23.SHR_KJT
				      AND MG3.SHOKAN_KBN = MG23.MGR_HENKO_KBN
				      AND MG23.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI002SELECT_02                                                              */

/*==============================================================================*/

	curIPI002SELECT_02 CURSOR FOR
	SELECT
		VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
		VMG1.MGR_CD,        -- 銘柄コード
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM,  -- 銘柄略称
		M01.KOZA_TEN_CD, -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		MG3.SHOKAN_YMD,     -- 償還日
		MG3.SHOKAN_KJT,     -- 償還期日
		MG3.KAIJI,           -- 回次
		VMG1.TEIJI_SHOKAN_KNGK     -- 定時償還額
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01,
		(SELECT
			ITAKU_KAISHA_CD,
			MGR_CD,
			CHOOSE_FLG,
			BILL_OUT_TMG1
		 FROM
		 	MGR_TESURYO_CTL
		 WHERE
			TESU_SHURUI_CD = '81'
		) WK1
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.JTK_KBN <> '2'
		AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'
		AND MG3.SHOKAN_KBN = '21'
		AND VMG1.ITAKU_KAISHA_CD = WK1.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = WK1.MGR_CD
		AND (VMG1.KKNBILL_OUT_TMG1 <> '7' AND MG3.KKNBILL_OUT_YMD = gGyomuYmd4After
		         OR (WK1.CHOOSE_FLG = '1' AND WK1.BILL_OUT_TMG1 <> '7' AND MG3.TESUBILL_OUT_YMD = gGyomuYmd4After)
		    OR VMG1.KKNBILL_OUT_TMG1 <> '7' AND MG3.KKNBILL_OUT_YMD = gGyomuYmd3After
		         OR (WK1.CHOOSE_FLG = '1' AND WK1.BILL_OUT_TMG1 <> '7' AND MG3.TESUBILL_OUT_YMD = gGyomuYmd3After)
		    OR VMG1.KKNBILL_OUT_TMG1 <> '7' AND MG3.KKNBILL_OUT_YMD = gGyomuYmd2After
		         OR (WK1.CHOOSE_FLG = '1' AND WK1.BILL_OUT_TMG1 <> '7' AND MG3.TESUBILL_OUT_YMD = gGyomuYmd2After)
		    OR VMG1.KKNBILL_OUT_TMG1 <> '7' AND MG3.KKNBILL_OUT_YMD = gGyomuYmd1After
		         OR (WK1.CHOOSE_FLG = '1' AND WK1.BILL_OUT_TMG1 <> '7' AND MG3.TESUBILL_OUT_YMD = gGyomuYmd1After)
		    OR (VMG1.KKNBILL_OUT_TMG1 <> '7' AND (trim(both VMG1.KKNBILL_OUT_TMG1) IS NOT NULL AND (trim(both VMG1.KKNBILL_OUT_TMG1))::text <> '') AND
       			                                 MG3.KKNBILL_OUT_YMD <= gGyomuYmd AND
       			                                 MG3.SHOKAN_YMD > gGyomuYmd)
       			 OR (WK1.CHOOSE_FLG = '1' AND WK1.BILL_OUT_TMG1 <> '7' AND (trim(both WK1.BILL_OUT_TMG1) IS NOT NULL AND (trim(both WK1.BILL_OUT_TMG1))::text <> '') AND
       			                                 MG3.TESUBILL_OUT_YMD <= gGyomuYmd AND
       			                                 MG3.SHOKAN_YMD > gGyomuYmd))
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND NOT EXISTS (SELECT *
			       FROM UPD_MGR_SHN MG23
			       WHERE  MG3.ITAKU_KAISHA_CD = MG23.ITAKU_KAISHA_CD
				      AND MG3.MGR_CD = MG23.MGR_CD
				      AND MG3.SHOKAN_KJT = MG23.SHR_KJT
				      AND MG3.SHOKAN_KBN = MG23.MGR_HENKO_KBN
				      AND MG23.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI002SELECT_03                                                              */

/*==============================================================================*/

	curIPI002SELECT_03 CURSOR FOR
	SELECT
		VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
		VMG1.MGR_CD,        -- 銘柄コード
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM,  -- 銘柄略称
		M01.KOZA_TEN_CD, -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		MG3.SHOKAN_YMD,     -- 償還日
		MG3.SHOKAN_KJT,     -- 償還期日
		MG3.KAIJI,           -- 回次
		VMG1.TEIJI_SHOKAN_KNGK     -- 定時償還額
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01,
		(SELECT
			ITAKU_KAISHA_CD,
			MGR_CD,
			CHOOSE_FLG,
			BILL_OUT_TMG1
		 FROM
		 	MGR_TESURYO_CTL
		 WHERE
			TESU_SHURUI_CD = '81'
		) WK1
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.JTK_KBN <> '2'
		AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'
		AND MG3.SHOKAN_KBN = '21'
		AND VMG1.ITAKU_KAISHA_CD = WK1.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = WK1.MGR_CD
		AND (MG3.KKNBILL_OUT_YMD = gGessyoYmdAfter
		     OR (WK1.CHOOSE_FLG = '1' AND   MG3.TESUBILL_OUT_YMD = gGessyoYmdAfter)
		     OR (VMG1.KKNBILL_OUT_TMG1 = '7' AND (trim(both VMG1.KKNBILL_OUT_TMG1) IS NOT NULL AND (trim(both VMG1.KKNBILL_OUT_TMG1))::text <> '') AND
       			                                 SUBSTR(MG3.SHOKAN_YMD, 1, 6) = SUBSTR(gGyomuYmd, 1, 6) AND
       			                                 MG3.SHOKAN_YMD > gGyomuYmd)
       	             OR (WK1.CHOOSE_FLG = '1' AND WK1.BILL_OUT_TMG1 = '7' AND (trim(both WK1.BILL_OUT_TMG1) IS NOT NULL AND (trim(both WK1.BILL_OUT_TMG1))::text <> '') AND
       			                                 SUBSTR(MG3.SHOKAN_YMD, 1, 6) = SUBSTR(gGyomuYmd, 1, 6) AND
       			                                 MG3.SHOKAN_YMD > gGyomuYmd))
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND NOT EXISTS (SELECT *
			       FROM UPD_MGR_SHN MG23
			       WHERE  MG3.ITAKU_KAISHA_CD = MG23.ITAKU_KAISHA_CD
				      AND MG3.MGR_CD = MG23.MGR_CD
				      AND MG3.SHOKAN_KJT = MG23.SHR_KJT
				      AND MG3.SHOKAN_KBN = MG23.MGR_HENKO_KBN
				      AND MG23.SHORI_KBN = '1');
/*==============================================================================*/

/* IPI002SELECT_04                                                              */

/*==============================================================================*/

	curIPI002SELECT_04 CURSOR FOR
	SELECT
		VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
		VMG1.MGR_CD,        -- 銘柄コード
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM,  -- 銘柄略称
		M01.KOZA_TEN_CD, -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		MG3.SHOKAN_YMD,     -- 償還日
		MG3.SHOKAN_KJT,     -- 償還期日
		MG3.KAIJI,           -- 回次
		VMG1.TEIJI_SHOKAN_KNGK     -- 定時償還額
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_SHOKIJ MG3,
		MHAKKOTAI M01,
		(SELECT
			ITAKU_KAISHA_CD,
			MGR_CD,
			CHOOSE_FLG,
			BILL_OUT_TMG1
		 FROM
		 	MGR_TESURYO_CTL
		 WHERE
			TESU_SHURUI_CD = '81'
		) WK1
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.JTK_KBN <> '2'
		AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'
		AND MG3.SHOKAN_KBN = '21'
		AND VMG1.ITAKU_KAISHA_CD = WK1.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = WK1.MGR_CD
		AND (
		      (VMG1.KKNBILL_OUT_TMG1 = '7' AND (trim(both VMG1.KKNBILL_OUT_TMG1) IS NOT NULL AND (trim(both VMG1.KKNBILL_OUT_TMG1))::text <> '') AND
       			                                 SUBSTR(MG3.SHOKAN_YMD, 1, 6) = SUBSTR(gGyomuYmd, 1, 6) AND
       			                                 MG3.SHOKAN_YMD > gGyomuYmd)
       	             OR (WK1.CHOOSE_FLG = '1' AND WK1.BILL_OUT_TMG1 = '7' AND (trim(both WK1.BILL_OUT_TMG1) IS NOT NULL AND (trim(both WK1.BILL_OUT_TMG1))::text <> '') AND
       			                                 SUBSTR(MG3.SHOKAN_YMD, 1, 6) = SUBSTR(gGyomuYmd, 1, 6) AND
       			                                 MG3.SHOKAN_YMD > gGyomuYmd))
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG3.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND NOT EXISTS (SELECT *
			       FROM UPD_MGR_SHN MG23
			       WHERE  MG3.ITAKU_KAISHA_CD = MG23.ITAKU_KAISHA_CD
				      AND MG3.MGR_CD = MG23.MGR_CD
				      AND MG3.SHOKAN_KJT = MG23.SHR_KJT
				      AND MG3.SHOKAN_KBN = MG23.MGR_HENKO_KBN
				      AND MG23.SHORI_KBN = '1');
/*==============================================================================*/

/* IPW005SELECT                                                               */

/*==============================================================================*/

	curIPW005SELECT CURSOR FOR
	SELECT
		VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
		VMG1.MGR_CD,        -- 銘柄コード
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM,  -- 銘柄略称
		M01.KOZA_TEN_CD, -- 口座店コード
		M01.KOZA_TEN_CIFCD, -- 口座店CIFコード
		MG4.TESU_SHURUI_CD,
		MG4.CHOKYU_YMD,
		PKIPACALCTESURYO.GETHOSEIKASANKNGK(T01.ALL_TESU_KNGK + T01.ALL_TESU_SZEI,T01.HOSEI_ALL_TESU_KNGK + T01.HOSEI_ALL_TESU_SZEI,T01.DATA_SAKUSEI_KBN ,T01.SHORI_KBN) AS ALL_TESU_KNGK, -- 請求金額
		PKIPACALCTESURYO.GETHOSEIKASANKNGK(T01.ALL_TESU_KNGK,T01.HOSEI_ALL_TESU_KNGK,T01.DATA_SAKUSEI_KBN ,T01.SHORI_KBN) AS ZEINUKI_TESU_KNGK,       -- 手数料金額（税抜）
		PKIPACALCTESURYO.GETHOSEIKASANKNGK(T01.ALL_TESU_SZEI,T01.HOSEI_ALL_TESU_SZEI,T01.DATA_SAKUSEI_KBN ,T01.SHORI_KBN) AS SZEI_TESU_KNGK             -- 消費税
	FROM
		MGR_KIHON_VIEW VMG1,
		MHAKKOTAI M01,
		MGR_TESKIJ MG4,
		MGR_TESURYO_PRM2 BT04,
		MGR_TESURYO_PRM MG7,
		TESURYO T01
	WHERE
		MG4.TESU_SHURUI_CD IN ('11','12')
		AND VMG1.ITAKU_KAISHA_CD = MG4.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG4.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG7.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.HKT_CD = M01.HKT_CD
		AND MG4.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
		AND MG4.MGR_CD = T01.MGR_CD
		AND MG4.CHOKYU_KJT = T01.CHOKYU_KJT
		AND MG4.TESU_SHURUI_CD = T01.TESU_SHURUI_CD
		AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.JTK_KBN <> '2'
		AND VMG1.ITAKU_KAISHA_CD = BT04.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = BT04.MGR_CD
		AND BT04.UKEIRE_YMD_PATTERN = '3'
-- 銘柄_期中手数料回次．徴求期日の休日補正後の当日
		AND pkDate.calcDateKyujitsuKbn(
-- 徴求期日、日数、信託報酬・社管手数料_徴求日休日処理区分、地域コード
		MG4.CHOKYU_KJT::character varying ,0::integer ,MG7.SS_CHOKYU_KYUJITSU_KBN::character,VMG1.AREACD::character
		)   = gGyomuYmd        -- 地域コード
		AND T01.DATA_SAKUSEI_KBN IN ('1','2');
/*==============================================================================*/

/* IPW017SELECT                                                               */

/*==============================================================================*/

	curIPW017SELECT CURSOR FOR
	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM   -- 銘柄略称
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SHOKAN_METHOD_CD <> '9'
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') = gGyomuYmd
		AND NOT EXISTS (SELECT * FROM  MCALENDAR_MAKE_INFO M62 WHERE M62.SAKUSEI_TAISHO_YYYY = SUBSTR(VMG1.FULLSHOKAN_KJT,1,4)
									AND M62.AREA_CD = '1' )
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM   -- 銘柄略称
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SHOKAN_METHOD_CD <> '9'
		AND VMG1.KYUJITSU_LD_FLG = 'Y'
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') = gGyomuYmd
		AND NOT EXISTS (SELECT * FROM  MCALENDAR_MAKE_INFO M62 WHERE M62.SAKUSEI_TAISHO_YYYY = SUBSTR(VMG1.FULLSHOKAN_KJT,1,4)
									AND M62.AREA_CD = '2' ) 
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM   -- 銘柄略称
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SHOKAN_METHOD_CD <> '9'
		AND VMG1.KYUJITSU_NY_FLG = 'Y'
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') = gGyomuYmd
		AND NOT EXISTS (SELECT * FROM  MCALENDAR_MAKE_INFO M62 WHERE M62.SAKUSEI_TAISHO_YYYY = SUBSTR(VMG1.FULLSHOKAN_KJT,1,4)
									AND M62.AREA_CD = '4' ) 
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM   -- 銘柄略称
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SHOKAN_METHOD_CD <> '9'
		AND VMG1.KYUJITSU_ETC_FLG = 'Y'
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') = gGyomuYmd
		AND NOT EXISTS (SELECT * FROM  MCALENDAR_MAKE_INFO M62 WHERE M62.SAKUSEI_TAISHO_YYYY = SUBSTR(VMG1.FULLSHOKAN_KJT,1,4)
									AND M62.AREA_CD = VMG1.ETCKAIGAI_AREA1 ) 
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM   -- 銘柄略称
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SHOKAN_METHOD_CD <> '9'
		AND VMG1.KYUJITSU_ETC_FLG = 'Y'
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') = gGyomuYmd
		AND NOT EXISTS (SELECT * FROM  MCALENDAR_MAKE_INFO M62 WHERE M62.SAKUSEI_TAISHO_YYYY = SUBSTR(VMG1.FULLSHOKAN_KJT,1,4)
									AND M62.AREA_CD = VMG1.ETCKAIGAI_AREA2 )
    and (trim(both VMG1.ETCKAIGAI_AREA2) IS NOT NULL AND (trim(both VMG1.ETCKAIGAI_AREA2))::text <> '') 
	
UNION

	SELECT
		VMG1.ISIN_CD, -- ISINコード
		VMG1.MGR_RNM   -- 銘柄略称
	FROM
		MGR_KIHON_VIEW VMG1,
		MGR_KIKO_KIHON MG9
	WHERE
		VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND VMG1.SHOKAN_METHOD_CD <> '9'
		AND VMG1.KYUJITSU_ETC_FLG = 'Y'
		AND VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG9.MGR_CD
		AND TO_CHAR(MG9.SAKUSEI_DT,'YYYYMMDD') = gGyomuYmd
		AND NOT EXISTS (SELECT * FROM  MCALENDAR_MAKE_INFO M62 WHERE M62.SAKUSEI_TAISHO_YYYY = SUBSTR(VMG1.FULLSHOKAN_KJT,1,4)
									AND M62.AREA_CD = VMG1.ETCKAIGAI_AREA3 )
    and (trim(both VMG1.ETCKAIGAI_AREA3) IS NOT NULL AND (trim(both VMG1.ETCKAIGAI_AREA3))::text <> '')           --2017/8/28 add by matsuda
 
;
	/*==============================================================================*/

/*                メイン処理                                                    */

/*==============================================================================*/

BEGIN
	RAISE NOTICE '[START] Function starting with: %, %, %', l_inItakuKaishaCd, l_inItakuKaishaRnm, l_inJikodaikoKbn;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	RAISE NOTICE '[GYOMU_YMD] Retrieved: %', gGyomuYmd;

	-- 月末営業日取得
	gGetsumatuYmd := pkDate.getGetsumatsuBusinessYmd(gGyomuYmd,0);
	-- 月初営業日取得
	gGessyoYmd := pkDate.getGesshoBusinessYmd(gGyomuYmd::character varying,'1'::character);
	-- 業務日付の1営業日前取得
	gBefGyomuYmd := pkdate.getMinusDateBusiness(gGyomuYmd::character varying,1::integer);
	-- 業務日付の1営業日後取得
	gGyomuYmd1After := pkDate.getPlusDateBusiness(gGyomuYmd::character varying,1::integer,'1'::character);
	-- 業務日付の2営業日後取得
	gGyomuYmd2After := pkDate.getPlusDateBusiness(gGyomuYmd::character varying,2::integer,'1'::character);
	-- 業務日付の3営業日後取得
	gGyomuYmd3After := pkDate.getPlusDateBusiness(gGyomuYmd::character varying,3::integer);
	-- 業務日付の4営業日後取得
	gGyomuYmd4After := pkDate.getPlusDateBusiness(gGyomuYmd::character varying,4::integer);
	-- 業務日付の5営業日後取得
	gGyomuYmd5After := pkDate.getPlusDateBusiness(gGyomuYmd::character varying,5::integer);
	-- 業務日付の6営業日後取得
	gGyomuYmd6After := pkDate.getPlusDateBusiness(gGyomuYmd::character varying,6::integer);
	-- 業務日付（２か月後）の年月取得
	gGyomuYmd2MAfterYM := SUBSTR(pkdate.calcMonth(gGyomuYmd::character varying,2::integer),1,6);
	-- レポートIDの設定
	IF l_inJikodaikoKbn = '1' THEN
		C_REPORT_ID := 'IP931511711';
	ELSE
		C_REPORT_ID := 'IP931511721';
	END IF;
/*==============================================================================*/

/* IPI102連絡データ作成(createIPI102)                                           */

/*==============================================================================*/
	RAISE NOTICE '[IPI102] Starting createIPI102 processing...';
	IF l_inJikodaikoKbn = '1' THEN
		BEGIN
			FOR recIPI102SELECT IN curIPI102SELECT LOOP
			RAISE NOTICE '[IPI102] Calling SFIPKEIKOKUINSERT for ISIN: %', recIPI102SELECT.ISIN_CD;
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
					  		'2',
					  		'IPI102',
					  		recIPI102SELECT.ISIN_CD,
					  		' ',
					  		' ',
					  		' ',
					  		recIPI102SELECT.MGR_RNM,
					  		'発行日',
							recIPI102SELECT.HAKKO_YMD,
					  		recIPI102SELECT.kensu,
					  		recIPI102SELECT.SHASAI_TOTAL,
							recIPI102SELECT.kofubi,
					  		' ',
					  		l_inJikodaikoKbn);
			-- エラー判定
			RAISE NOTICE '[IPI102] SFIPKEIKOKUINSERT returned: %', gFncResult;
			IF gFncResult != pkconstant.success() THEN
				RAISE NOTICE '[IPI102] ERROR: gFncResult != success, returning FATAL';
				RETURN pkconstant.FATAL();
			END IF;
			END LOOP;
			RAISE NOTICE '[IPI102] Finished processing all records';
		EXCEPTION
			WHEN OTHERS THEN
				RAISE NOTICE '[IPI102] EXCEPTION: % - %', SQLSTATE, SQLERRM;
				RETURN pkconstant.FATAL();
		END;
	END IF;
/*==============================================================================*/

/* IPW001連絡データ作成(createIPW001)                                           */

/*==============================================================================*/

	BEGIN
		FOR recIPW001SELECT IN curIPW001SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
					  	'1',
					  	'IPW001',
					  	recIPW001SELECT.ISIN_CD,
					  	recIPW001SELECT.KOZA_TEN_CD,
					  	recIPW001SELECT.KOZA_TEN_CIFCD,
					  	recIPW001SELECT.KIKO_KANYUSYA_CD,
					  	recIPW001SELECT.MGR_RNM,
					  	'利払日',
					  	recIPW001SELECT.SHR_YMD,
					  	' ',
					  	' ',
					  	' ',
					  	' ',
					  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	EXCEPTION
		WHEN OTHERS THEN
			RETURN pkconstant.FATAL();
	END;
/*==============================================================================*/

/* IPI001連絡データ作成(createIPI001)                                           */

/*==============================================================================*/

	IF gGyomuYmd = gGetsumatuYmd THEN
		FOR recIPI001SELECT IN curIPI001SELECT LOOP
			IF recIPI001SELECT.SHOKAN_KBN = '50' THEN
				gYobi1 := '行使期間終了日：' || SUBSTR(recIPI001SELECT.ED_PUTKOSHIKIKAN_YMD,1,4) || '/' || SUBSTR(recIPI001SELECT.ED_PUTKOSHIKIKAN_YMD,5,2) || '/' || SUBSTR(recIPI001SELECT.ED_PUTKOSHIKIKAN_YMD,7,2);
				gYobi2 := '{プット}';
			ELSE
				gYobi2 := '{コール}';
			END IF;
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  	'2',
						  	'IPI001',
						  	recIPI001SELECT.ISIN_CD,
						  	recIPI001SELECT.KOZA_TEN_CD,
						  	recIPI001SELECT.KOZA_TEN_CIFCD,
						  	' ',
						  	recIPI001SELECT.MGR_RNM,
						  	'償還期日',
						  	recIPI001SELECT.SHOKAN_KJT,
						  	gYobi1,
						  	gYobi2,
						  	' ',
						  	' ',
						  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPW002連絡データ作成(createIPW002)                                           */

/*==============================================================================*/

	IF gGyomuYmd = gGetsumatuYmd THEN
		FOR recIPW002SELECT IN curIPW002SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  	'1',
						  	'IPW002',
						  	recIPW002SELECT.ISIN_CD,
						  	recIPW002SELECT.KOZA_TEN_CD,
						  	recIPW002SELECT.KOZA_TEN_CIFCD,
						  	' ',
						  	recIPW002SELECT.MGR_RNM,
						  	'償還日',
						  	recIPW002SELECT.SHOKAN_YMD,
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPW003連絡データ作成(createIPW003)                                           */

/*==============================================================================*/

	BEGIN
		FOR recIPW003SELECT IN curIPW003SELECT LOOP
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
					  	'1',
					  	'IPW003',
					  	recIPW003SELECT.ISIN_CD,
					  	recIPW003SELECT.KOZA_TEN_CD,
					  	recIPW003SELECT.KOZA_TEN_CIFCD,
					  	' ',
					  	recIPW003SELECT.MGR_RNM,
					  	'償還日',
					  	recIPW003SELECT.SHOKAN_YMD,
					  	' ',
					  	' ',
					  	' ',
					  	' ',
					  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	EXCEPTION
		WHEN OTHERS THEN
			RETURN pkconstant.FATAL();
	END;
/*==============================================================================*/

/* IPW013連絡データ作成(createIPW013)                                           */

/*==============================================================================*/

	IF gGyomuYmd = gGetsumatuYmd THEN
		-- 業務日付（３か月後）の年月
		gGyomuYmd3MAfterYM := SUBSTR(pkdate.calcMonth(gGyomuYmd::character varying,3::integer),1,6);
		FOR recIPW013SELECT IN curIPW013SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  	'1',
						  	'IPW013',
						  	recIPW013SELECT.ISIN_CD,
						  	' ',
						  	' ',
						  	' ',
						  	recIPW013SELECT.MGR_RNM,
						  	'償還日',
						  	recIPW013SELECT.SHOKAN_YMD,
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPW014連絡データ作成(createIPW014)                                           */

/*==============================================================================*/

	BEGIN
		FOR recIPW014SELECT IN curIPW014SELECT LOOP
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
					  	'1',
					  	'IPW014',
					  	recIPW014SELECT.ISIN_CD,
					  	' ',
					  	' ',
					  	' ',
					  	recIPW014SELECT.MGR_RNM,
					  	'徴求日',
					  	recIPW014SELECT.CHOKYU_YMD,
					  	' ',
					  	' ',
					  	' ',
					  	' ',
					  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	EXCEPTION
		WHEN OTHERS THEN
			RETURN pkconstant.FATAL();
	END;
/*==============================================================================*/

/* IPI003連絡データ作成(createIPI003)                                           */

/*==============================================================================*/

	FOR recIPI103SELECT IN curIPI103SELECT LOOP
		IF recIPI103SELECT.kensu <> 0 THEN
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  	'2',
						  	'IPI103',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	gGyomuYmd,
						  	recIPI103SELECT.kensu,
						  	' ',
						  	' ',
						  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPW102連絡データ作成(createIPW102)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '1' THEN
		FOR recIPW102SELECT IN curIPW102SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  	'1',
						  	'IPW102',
						  	' ',
						  	recIPW102SELECT.KOZA_TEN_CD,
						  	recIPW102SELECT.KOZA_TEN_CIFCD,
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPI201連絡データ作成(createIPI201)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '2' THEN
		FOR recIPI201SELECT IN curIPI201SELECT LOOP
			IF recIPI201SELECT.kensu <> 0 THEN
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							  	'2',
							  	'IPI201',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	' ',
							  	l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPI202連絡データ作成(createIPI202)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '2' THEN
		FOR recIPI202SELECT IN curIPI202SELECT LOOP
			IF recIPI202SELECT.kensu <> 0 THEN
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							  	'2',
								'IPI202',
								' ',
								' ',
								' ',
								' ',
								' ',
								' ',
								' ',
								' ',
								' ',
								' ',
								' ',
								l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPI204連絡データ作成(createIPI204)                                           */

/*==============================================================================*/

	-- オプションフラグ取得
	gOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'IPZ10062030F0', '0');
	IF l_inJikodaikoKbn = '2'  AND gOptionFlg = '1' THEN
		FOR recIPI204SELECT IN curIPI204SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							  '2',
							  'IPI204',
							  ' ',
							  ' ',
							  ' ',
							  ' ',
							  ' ',
							  '徴求日',
							  recIPI204SELECT.CHOKYU_YMD,
							  ' ',
							  ' ',
							  ' ',
							  ' ',
							  l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPW018連絡データ作成(createIPW018)                                           */

/*==============================================================================*/

	FOR recIPW018SELECT IN curIPW018SELECT LOOP
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  '1',
						  'IPW018',
						  recIPW018SELECT.ISIN_CD,
						  ' ',
						  ' ',
						  ' ',
						  recIPW018SELECT.MGR_RNM,
						  '発行日',
						  recIPW018SELECT.HAKKO_YMD,
						  ' ',
						  ' ',
						  ' ',
						  ' ',
						  l_inJikodaikoKbn);
		-- エラー判定
		IF gFncResult != pkconstant.success() THEN
			RETURN pkconstant.FATAL();
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPW019連絡データ作成(createIPW019)                                           */

/*==============================================================================*/

	FOR recIPW019SELECT IN curIPW019SELECT LOOP
		-- 合計算出
		gIPW019CNT := recIPW019SELECT.CNT1 + recIPW019SELECT.CNT2;
		-- 備考の編集
		gIPW019BIKO := '機構申請' || LPAD(trim(both gIPW019CNT::text),3, ' ') || '件' ||
			       '(未受信' || LPAD(trim(both recIPW019SELECT.CNT1::text),3, ' ') || '件、' ||
			       '受信済' || LPAD(trim(both recIPW019SELECT.CNT2::text),3, ' ') || '件)';
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  '1',
						  'IPW019',
						  recIPW019SELECT.ISIN_CD,
						  ' ',
						  ' ',
						  ' ',
						  recIPW019SELECT.MGR_RNM,
						  '発行日',
						  recIPW019SELECT.HAKKO_YMD,
						  gIPW019BIKO,
						  ' ',
						  ' ',
						  ' ',
						  l_inJikodaikoKbn);
		-- エラー判定
		IF gFncResult != pkconstant.success() THEN
			RETURN pkconstant.FATAL();
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPW020連絡データ作成(createIPW020)                                           */

/*==============================================================================*/

	FOR recIPW020SELECT IN curIPW020SELECT LOOP
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  '1',
						  'IPW020',
						  recIPW020SELECT.ISIN_CD,
						  ' ',
						  ' ',
						  ' ',
						  recIPW020SELECT.MGR_RNM,
						  '発行日',
						  recIPW020SELECT.HAKKO_YMD,
						  recIPW020SELECT.BIKO1,
						  recIPW020SELECT.BIKO2,
						  ' ',
						  ' ',
						  l_inJikodaikoKbn);
		-- エラー判定
		IF gFncResult != pkconstant.success() THEN
			RETURN pkconstant.FATAL();
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPW009、011連絡データ作成(createIPW009_011)                                  */

/*==============================================================================*/

	FOR recIPW009SELECT IN curIPW009SELECT LOOP
		gIPW009ItakuKaishaCd := recIPW009SELECT.ITAKU_KAISHA_CD;
		gIPW009ShokanYmd := recIPW009SELECT.SHOKAN_YMD;
		gIPW009IsinCd := recIPW009SELECT.ISIN_CD;
		gIPW011CNT := '0';
		FOR recIPW011SELECT IN curIPW011SELECT LOOP
			gIPW011CNT := '1';
			IF recIPW009SELECT.SHOKAN_METHOD_CD = '2' THEN
				gHikakuKingaku := recIPW011SELECT.JISSHITSU_KNGK;
			ELSE
				gHikakuKingaku := recIPW011SELECT.KNGK;
			END IF;
			IF recIPW009SELECT.GENSAI_KNGK <> gHikakuKingaku THEN
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  		'1',
						  		'IPW011',
						  		recIPW009SELECT.ISIN_CD,
						  		recIPW009SELECT.KOZA_TEN_CD,
						  		recIPW009SELECT.KOZA_TEN_CIFCD,
						  		' ',
						  		recIPW009SELECT.MGR_RNM,
						  		' ',
						  		' ',
						  		' ',
						  		' ',
						  		' ',
						  		' ',
						  		l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
		IF gIPW011CNT = '0' THEN
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						  	'1',
						  	'IPW009',
						  	recIPW009SELECT.ISIN_CD,
						  	recIPW009SELECT.KOZA_TEN_CD,
						  	recIPW009SELECT.KOZA_TEN_CIFCD,
						  	' ',
						  	recIPW009SELECT.MGR_RNM,
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	' ',
						  	l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPW008、010連絡データ作成(createIPW008_010)                                  */

/*==============================================================================*/

	FOR recIPW008SELECT IN curIPW008SELECT LOOP
		gIPW008ItakuKaishaCd := recIPW008SELECT.ITAKU_KAISHA_CD;
		gIPW008ShokanYmd := recIPW008SELECT.SHOKAN_YMD;
		gIPW008MgrCd := recIPW008SELECT.MGR_CD;
		gIPW008IsinCd := recIPW008SELECT.ISIN_CD;
		gIPW010CNT := '0';
		SELECT
			VJ1.BIC_CD
    INTO STRICT
      gBicCd
		FROM
			VJIKO_ITAKU VJ1
		WHERE
			VJ1.KAIIN_ID = l_inItakuKaishaCd;
		FOR recIPW010SELECT IN curIPW010SELECT LOOP
			/* 保振の残高は名目残高のため、実質残高にして比較
			 */
			gDenbunGensaiKngk := recIPW010SELECT.RT02_KNGK;	-- 保振の減債額（名目残高）
			gPreviousShokanYmd := NULL;
			-- 償還方法コードを取得（ファクタ銘柄判定用）
			SELECT
				MG1.SHOKAN_METHOD_CD
			INTO STRICT
				gShokanMethodCd
			FROM
				MGR_KIHON_VIEW MG1
			WHERE
				MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND MG1.MGR_CD = gIPW008MgrCd
			;
			-- ファクタ銘柄の場合、保振の減債額を実質残高にする
			IF gShokanMethodCd = '2' THEN
				-- ファクタ取得（償還日前日時点）
				gPreviousShokanYmd := pkDate.getZenYmd(gIPW008ShokanYmd::character varying);
				gFactor := pkIpaZndk.getKjnZndk(
									l_inItakuKaishaCd,
									gIPW008MgrCd,
									gPreviousShokanYmd,	-- 基準日：償還日前日
									5					-- 実数：ファクタ
							);
				-- 実質残高をセット
				gDenbunGensaiKngk := gDenbunGensaiKngk * gFactor;
			END IF;
			-- 差異があれば連絡データ作成
			IF recIPW008SELECT.GENSAI_KNGK <> gDenbunGensaiKngk THEN
				gIPW010CNT := '1';
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
								'1',
								'IPW010',
								recIPW008SELECT.ISIN_CD,
							 	recIPW008SELECT.KOZA_TEN_CD,
							 	recIPW008SELECT.KOZA_TEN_CIFCD,
								' ',
								recIPW008SELECT.MGR_RNM,
								' ',
								' ',
								' ',
								' ',
								' ',
								' ',
								l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
---------IF gIPW010CNT = '0' THEN
			FOR recIPW008SELECT_01 IN curIPW008SELECT_01 LOOP
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
								'1',
								'IPW008',
								 recIPW008SELECT.ISIN_CD,
								 recIPW008SELECT.KOZA_TEN_CD,
								 recIPW008SELECT.KOZA_TEN_CIFCD,
								 recIPW008SELECT_01.KIKO_KANYUSYA_CD,
								 recIPW008SELECT.MGR_RNM,
								 '償還日',
								 recIPW008SELECT.SHOKAN_YMD,
								 ' ',
								 ' ',
								 ' ',
								 ' ',
								 l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END LOOP;
---------END IF;
	END LOOP;
/*==============================================================================*/

/* IPW012連絡データ作成(createIPW012)                                           */

/*==============================================================================*/

	-- オプションフラグ(実質記番号)取得
	gOpFlg := pkControl.getOPTION_FLG(      l_inItakuKaishaCd,
						'IPP1003302010',
						'0');
	-- 翌営業日の取得
	gYokuEigyoYmd := gGyomuYmd1After;
	FOR recIPW012SELECT IN curIPW012SELECT LOOP
		IF recIPW012SELECT.HANTEI_FLG = '1' THEN
			gIPW012BIKO := '利払日の2営業日前（' || substr(gYokuEigyoYmd,1,4) || '/' || substr(gYokuEigyoYmd,5,2) || '/' || substr(gYokuEigyoYmd,7,2) || '）';
		ELSE
			gIPW012BIKO := '利払日の前営業日（' || substr(gYokuEigyoYmd,1,4) || '/' || substr(gYokuEigyoYmd,5,2) || '/' || substr(gYokuEigyoYmd,7,2) || '）';
		END IF;
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						'1',
						'IPW012',
						recIPW012SELECT.ISIN_CD,
						' ',
						' ',
						' ',
						recIPW012SELECT.MGR_RNM,
						'利払日',
						recIPW012SELECT.RBR_YMD,
						gIPW012BIKO,
						' ',
						' ',
						' ',
						l_inJikodaikoKbn);
		-- エラー判定
		IF gFncResult != pkconstant.success() THEN
			RETURN pkconstant.FATAL();
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPI004連絡データ作成(createIPI004)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '1' THEN
		FOR recIPI004SELECT_1 IN curIPI004SELECT_1 LOOP
			g2MaeEigyoYmdIPI004 := pkdate.getMinusDateBusiness(recIPI004SELECT_1.RBR_YMD2::character varying, 2::integer);
			gIPI004BIKO1 := '（利率決定日　間近）';
			gIPI004BIKO2 := '決定利率を確認のうえ、' || SUBSTR(g2MaeEigyoYmdIPI004,1,4) || '/' || SUBSTR(g2MaeEigyoYmdIPI004,5,2) || '/' || SUBSTR(g2MaeEigyoYmdIPI004,7,2) || '目処に利率の登録を';
			gIPI004BIKO3 := 'してください。';
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI004',
							recIPI004SELECT_1.ISIN_CD,
					  		recIPI004SELECT_1.KOZA_TEN_CD,
							recIPI004SELECT_1.KOZA_TEN_CIFCD,
							' ',
							recIPI004SELECT_1.MGR_RNM,
							'利払期日',
							recIPI004SELECT_1.RBR_KJT,
							gIPI004BIKO1,
							gIPI004BIKO2,
							gIPI004BIKO3,
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
		FOR recIPI004SELECT_3 IN curIPI004SELECT_3 LOOP
			g8MaeEigyoYmdIPI004 := pkdate.getMinusDateBusiness(recIPI004SELECT_3.RBR_YMD::character varying, 8::integer);
			gIPI004BIKO1 := '（利率決定日　到来済）';
			gIPI004BIKO2 := SUBSTR(recIPI004SELECT_3.RBR_KJT,1,4) || '/' || SUBSTR(recIPI004SELECT_3.RBR_KJT,5,2) || '/' || SUBSTR(recIPI004SELECT_3.RBR_KJT,7,2) || '期日の変動利率が未登録（未承認）です。利';
			gIPI004BIKO3 := '払日の8営業日前（' || SUBSTR(g8MaeEigyoYmdIPI004,1,4) || '/' || SUBSTR(g8MaeEigyoYmdIPI004,5,2) || '/' || SUBSTR(g8MaeEigyoYmdIPI004,7,2) || '）迄に登録が必要です。';
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI004',
							recIPI004SELECT_3.ISIN_CD,
					  		recIPI004SELECT_3.KOZA_TEN_CD,
							recIPI004SELECT_3.KOZA_TEN_CIFCD,
							' ',
							recIPI004SELECT_3.MGR_RNM,
							'利払期日',
							recIPI004SELECT_3.RBR_KJT,
							gIPI004BIKO1,
							gIPI004BIKO2,
							gIPI004BIKO3,
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	ELSE
		FOR recIPI004SELECT_2 IN curIPI004SELECT_2 LOOP
			g2MaeEigyoYmdIPI004 := pkdate.getMinusDateBusiness(recIPI004SELECT_2.RBR_YMD2::character varying, 2::integer);
			gIPI004BIKO1 := '（利率決定日　間近）';
			gIPI004BIKO2 := '決定利率を確認のうえ、' || SUBSTR(g2MaeEigyoYmdIPI004,1,4) || '/' || SUBSTR(g2MaeEigyoYmdIPI004,5,2) || '/' || SUBSTR(g2MaeEigyoYmdIPI004,7,2) || '目処に利率の登録を';
			gIPI004BIKO3 := 'してください。';
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI004',
							recIPI004SELECT_2.ISIN_CD,
					  		recIPI004SELECT_2.KOZA_TEN_CD,
							recIPI004SELECT_2.KOZA_TEN_CIFCD,
							' ',
							recIPI004SELECT_2.MGR_RNM,
							'利払期日',
							recIPI004SELECT_2.RBR_KJT,
							gIPI004BIKO1,
							gIPI004BIKO2,
							gIPI004BIKO3,
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
		FOR recIPI004SELECT_4 IN curIPI004SELECT_4 LOOP
			g8MaeEigyoYmdIPI004 := pkdate.getMinusDateBusiness(recIPI004SELECT_4.RBR_YMD::character varying, 8::integer);
			gIPI004BIKO1 := '（利率決定日　到来済）';
			gIPI004BIKO2 := SUBSTR(recIPI004SELECT_4.RBR_KJT,1,4) || '/' || SUBSTR(recIPI004SELECT_4.RBR_KJT,5,2) || '/' || SUBSTR(recIPI004SELECT_4.RBR_KJT,7,2) || '期日の変動利率が未登録（未承認）です。利';
			gIPI004BIKO3 := '払日の8営業日前（' || SUBSTR(g8MaeEigyoYmdIPI004,1,4) || '/' || SUBSTR(g8MaeEigyoYmdIPI004,5,2) || '/' || SUBSTR(g8MaeEigyoYmdIPI004,7,2) || '）迄に登録が必要です。';
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI004',
							recIPI004SELECT_4.ISIN_CD,
					  		recIPI004SELECT_4.KOZA_TEN_CD,
							recIPI004SELECT_4.KOZA_TEN_CIFCD,
							' ',
							recIPI004SELECT_4.MGR_RNM,
							'利払期日',
							recIPI004SELECT_4.RBR_KJT,
							gIPI004BIKO1,
							gIPI004BIKO2,
							gIPI004BIKO3,
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
	FOR recIPI004SELECT_5 IN curIPI004SELECT_5 LOOP
		g8MaeEigyoYmdIPI004 := pkdate.getMinusDateBusiness(recIPI004SELECT_5.RBR_YMD::character varying, 8::integer);
		gIPI004BIKO1 := '（初回利払）';
		gIPI004BIKO2 := '初回利払期日の変動利率が未登録（未承認）です。初回';
		gIPI004BIKO3 := '利払日の8営業日前（' || SUBSTR(g8MaeEigyoYmdIPI004,1,4) || '/' || SUBSTR(g8MaeEigyoYmdIPI004,5,2) || '/' || SUBSTR(g8MaeEigyoYmdIPI004,7,2) || '）迄に登録が必要です。';
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						'2',
						'IPI004',
						recIPI004SELECT_5.ISIN_CD,
					  	recIPI004SELECT_5.KOZA_TEN_CD,
						recIPI004SELECT_5.KOZA_TEN_CIFCD,
						' ',
						recIPI004SELECT_5.MGR_RNM,
						'利払期日',
						recIPI004SELECT_5.RBR_KJT,
						gIPI004BIKO1,
						gIPI004BIKO2,
						gIPI004BIKO3,
						' ',
						l_inJikodaikoKbn);
		-- エラー判定
		IF gFncResult != pkconstant.success() THEN
			RETURN pkconstant.FATAL();
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPI203連絡データ作成(createIPI203)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '2' THEN
		FOR recIPI203SELECT IN curIPI203SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI203',
							' ',
							' ',
							' ',
							' ',
							' ',
							'利払日',
							recIPI203SELECT.RBR_YMD,
							' ',
							' ',
							' ',
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPW201連絡データ作成(createIPW201)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '2' THEN
		FOR recIPW201SELECT IN curIPW201SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'1',
							'IPW201',
							recIPW201SELECT.ISIN_CD,
							' ',
							' ',
							' ',
							recIPW201SELECT.MGR_RNM,
							'償還期日',
							recIPW201SELECT.SHR_KJT,
							recIPW201SELECT.CODE_RNM,
							' ',
							' ',
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPW006連絡データ作成(createIPW006)                                           */

/*==============================================================================*/

	FOR recIPW006SELECT IN curIPW006SELECT LOOP
		IF recIPW006SELECT.KAIJI = '1' THEN
			gIPW006ItakuKaishaCd := recIPW006SELECT.ITAKU_KAISHA_CD;
			gIPW006MgrCd         := recIPW006SELECT.MGR_CD;
			FOR recIPW006_01SELECT IN curIPW006_01SELECT LOOP
				IF recIPW006_01SELECT.Kensu <> 0 THEN
					gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						'1',
						'IPW006',
						recIPW006SELECT.ISIN_CD,
					  	recIPW006SELECT.KOZA_TEN_CD,
						recIPW006SELECT.KOZA_TEN_CIFCD,
						' ',
						recIPW006SELECT.MGR_RNM,
						'償還日',
						recIPW006SELECT.SHOKAN_YMD,
						' ',
						' ',
						' ',
						' ',
						l_inJikodaikoKbn);
				END IF;
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END LOOP;
		ELSE
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
				'1',
				'IPW006',
				recIPW006SELECT.ISIN_CD,
			  	recIPW006SELECT.KOZA_TEN_CD,
				recIPW006SELECT.KOZA_TEN_CIFCD,
				' ',
				recIPW006SELECT.MGR_RNM,
				'償還日',
				recIPW006SELECT.SHOKAN_YMD,
				' ',
				' ',
				' ',
				' ',
				l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPW007連絡データ作成(createIPW007)                                           */

/*==============================================================================*/

	FOR recIPW007SELECT IN curIPW007SELECT LOOP
		IF recIPW007SELECT.KAIJI = '1' THEN
			gIPW007ItakuKaishaCd := recIPW007SELECT.ITAKU_KAISHA_CD;
			gIPW007MgrCd         := recIPW007SELECT.MGR_CD;
			FOR recIPW007_01SELECT IN curIPW007_01SELECT LOOP
				IF recIPW007_01SELECT.Kensu <> 0 THEN
					gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
									'1',
									'IPW007',
									recIPW007SELECT.ISIN_CD,
								  	recIPW007SELECT.KOZA_TEN_CD,
									recIPW007SELECT.KOZA_TEN_CIFCD,
									' ',
									recIPW007SELECT.MGR_RNM,
									'利払日',
									recIPW007SELECT.RBR_YMD,
									' ',
									' ',
									' ',
									' ',
									l_inJikodaikoKbn);
					-- エラー判定
					IF gFncResult != pkconstant.success() THEN
						RETURN pkconstant.FATAL();
					END IF;
				END IF;
			END LOOP;
		ELSE
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
								'1',
								'IPW007',
								recIPW007SELECT.ISIN_CD,
								  recIPW007SELECT.KOZA_TEN_CD,
								recIPW007SELECT.KOZA_TEN_CIFCD,
								' ',
								recIPW007SELECT.MGR_RNM,
								'利払日',
								recIPW007SELECT.RBR_YMD,
								' ',
								' ',
								' ',
								' ',
								l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPI205連絡データ作成(createIPI205)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '2' THEN
		FOR recIPI205SELECT IN curIPI205SELECT LOOP
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI205',
							recIPI205SELECT.ISIN_CD,
							recIPI205SELECT.KOZA_TEN_CD,
							recIPI205SELECT.KOZA_TEN_CIFCD,
							' ',
							recIPI205SELECT.MGR_RNM,
							'発行日',
							recIPI205SELECT.HAKKO_YMD,
							' ',
							' ',
							' ',
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPI003連絡データ作成(createIPI003)                                           */

/*==============================================================================*/

	FOR recIPI003SELECT IN curIPI003SELECT LOOP
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						'2',
						'IPI003',
						recIPI003SELECT.ISIN_CD,
						recIPI003SELECT.KOZA_TEN_CD,
						recIPI003SELECT.KOZA_TEN_CIFCD,
						' ',
						recIPI003SELECT.MGR_RNM,
						' ',
						' ',
						' ',
						' ',
						' ',
						' ',
						l_inJikodaikoKbn);
		-- エラー判定
		IF gFncResult != pkconstant.success() THEN
			RETURN pkconstant.FATAL();
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPI104連絡データ作成(createIPI104)                                           */

/*==============================================================================*/

	IF l_inJikodaikoKbn = '1' THEN
		FOR recIPI104SELECT IN curIPI104SELECT LOOP
			gIPI104SELECTBIKO1  := recIPI104SELECT.CODE_NM1;
			gIPI104SELECTBIKO2  := recIPI104SELECT.CODE_NM2;
			gIPI104SELECTBIKO3  := recIPI104SELECT.CODE_NM3;
			IF (recIPI104SELECT.CODE_NM1 IS NOT NULL AND recIPI104SELECT.CODE_NM1::text <> '') AND (recIPI104SELECT.CODE_NM2 IS NOT NULL AND recIPI104SELECT.CODE_NM2::text <> '') AND (recIPI104SELECT.CODE_NM3 IS NOT NULL AND recIPI104SELECT.CODE_NM3::text <> '') THEN
				gIPI104SELECTBIKO1  := recIPI104SELECT.CODE_NM1 || '、';
				gIPI104SELECTBIKO2  := '（Ｃ）' || recIPI104SELECT.CODE_NM2 || '、';
				gIPI104SELECTBIKO3  := '（Ｆ）' || recIPI104SELECT.CODE_NM3;
			ELSIF (recIPI104SELECT.CODE_NM1 IS NOT NULL AND recIPI104SELECT.CODE_NM1::text <> '') AND (recIPI104SELECT.CODE_NM2 IS NOT NULL AND recIPI104SELECT.CODE_NM2::text <> '') AND coalesce(recIPI104SELECT.CODE_NM3::text, '') = '' THEN
				gIPI104SELECTBIKO1  := recIPI104SELECT.CODE_NM1 || '、';
				gIPI104SELECTBIKO2  := '（Ｃ）' || recIPI104SELECT.CODE_NM2;
				gIPI104SELECTBIKO3  := recIPI104SELECT.CODE_NM3;
			ELSIF (recIPI104SELECT.CODE_NM1 IS NOT NULL AND recIPI104SELECT.CODE_NM1::text <> '') AND coalesce(recIPI104SELECT.CODE_NM2::text, '') = '' AND coalesce(recIPI104SELECT.CODE_NM3::text, '') = '' THEN
				gIPI104SELECTBIKO1  := recIPI104SELECT.CODE_NM1;
				gIPI104SELECTBIKO2  := recIPI104SELECT.CODE_NM2;
				gIPI104SELECTBIKO3  := recIPI104SELECT.CODE_NM3;
			ELSIF (recIPI104SELECT.CODE_NM1 IS NOT NULL AND recIPI104SELECT.CODE_NM1::text <> '') AND coalesce(recIPI104SELECT.CODE_NM2::text, '') = '' AND (recIPI104SELECT.CODE_NM3 IS NOT NULL AND recIPI104SELECT.CODE_NM3::text <> '') THEN
				gIPI104SELECTBIKO1  := recIPI104SELECT.CODE_NM1 || '、';
				gIPI104SELECTBIKO2  := recIPI104SELECT.CODE_NM2;
				gIPI104SELECTBIKO3  := '（Ｆ）' || recIPI104SELECT.CODE_NM3;
			ELSIF coalesce(recIPI104SELECT.CODE_NM1::text, '') = '' AND (recIPI104SELECT.CODE_NM2 IS NOT NULL AND recIPI104SELECT.CODE_NM2::text <> '') AND (recIPI104SELECT.CODE_NM3 IS NOT NULL AND recIPI104SELECT.CODE_NM3::text <> '') THEN
				gIPI104SELECTBIKO1  := recIPI104SELECT.CODE_NM1;
				gIPI104SELECTBIKO2  := '（Ｃ）' || recIPI104SELECT.CODE_NM2 || '、';
				gIPI104SELECTBIKO3  := '（Ｆ）' || recIPI104SELECT.CODE_NM3;
			END IF;
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI104',
							recIPI104SELECT.ISIN_CD,
							recIPI104SELECT.KOZA_TEN_CD,
							recIPI104SELECT.KOZA_TEN_CIFCD,
							' ',
							recIPI104SELECT.MGR_RNM,
							'利率決定日',
							recIPI104SELECT.RIRITSU_KETTEI_YMD,
							recIPI104SELECT.kensu,
							gIPI104SELECTBIKO1,
							gIPI104SELECTBIKO2,
							gIPI104SELECTBIKO3,
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPI002連絡データ作成(createIPI002)                                           */

/*==============================================================================*/

	--▼(1)請求書出力日が前月16日の銘柄で、利払日（休日補正後）の前月初第1営業日になり、次回償還期日の変動償還額が未入力または未承認の場合
	IF gGyomuYmd = gGetsumatuYmd THEN
	-- 月末営業日の場合の対象償還日：翌月〜翌々月
		-- 月初営業日（１か月後）を取得
		gGessyoYmdAfter := pkDate.getYokuBusinessYmd(gGyomuYmd::character varying);
		-- 月末営業日（２か月後）を取得
		gGetsumatuYmdAfter := pkDate.getGetsumatsuBusinessYmd(gGyomuYmd::character varying,2::integer);
		FOR recIPI002SELECT_01 IN curIPI002SELECT_01 LOOP
			-- 次回償還期日の８営業日前を取得
			g8MaeEigyoYmdIPI002 := pkdate.getMinusDateBusiness(recIPI002SELECT_01.SHOKAN_YMD::character varying, 8::integer);
			IF recIPI002SELECT_01.KAIJI = '1' THEN
				IF recIPI002SELECT_01.TEIJI_SHOKAN_KNGK = 0 THEN
					gIPI002BIKO_01 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
					gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
										'2',
										'IPI002',
										recIPI002SELECT_01.ISIN_CD,
										recIPI002SELECT_01.KOZA_TEN_CD,
										recIPI002SELECT_01.KOZA_TEN_CIFCD,
										' ',
										recIPI002SELECT_01.MGR_RNM,
										'償還期日',
										recIPI002SELECT_01.SHOKAN_KJT,
										gIPI002BIKO_01,
										' ',
										' ',
										' ',
										l_inJikodaikoKbn);
					-- エラー判定
					IF gFncResult != pkconstant.success() THEN
						RETURN pkconstant.FATAL();
					END IF;
				END IF;
			ELSE
				gIPI002BIKO_01 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
									'2',
									'IPI002',
									recIPI002SELECT_01.ISIN_CD,
									recIPI002SELECT_01.KOZA_TEN_CD,
									recIPI002SELECT_01.KOZA_TEN_CIFCD,
									' ',
									recIPI002SELECT_01.MGR_RNM,
									'償還期日',
									recIPI002SELECT_01.SHOKAN_KJT,
									gIPI002BIKO_01,
									' ',
									' ',
									' ',
									l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
	ELSIF gGyomuYmd <> gGetsumatuYmd THEN
	-- 月末営業日でない場合の対象償還日：翌営業日（当月）〜翌月
		-- 業務営業日（１か月後）を取得
		gGyomuYmdAfter := pkdate.calcMonth(gGyomuYmd::character varying,1::integer);
		-- 月初営業日（１か月後）を取得
		gGessyoYmdAfter := pkDate.getGesshoBusinessYmd(gGyomuYmdAfter::character varying,'1'::character);
		-- 月末営業日（１か月後）を取得
		gGetsumatuYmdAfter := pkDate.getGetsumatsuBusinessYmd(gGyomuYmdAfter::character varying,0::integer);
		FOR recIPI002SELECT_01 IN curIPI002SELECT_01 LOOP
      -- 次回償還期日の８営業日前を取得
      g8MaeEigyoYmdIPI002 := pkdate.getMinusDateBusiness(recIPI002SELECT_01.SHOKAN_YMD::character varying, 8::integer);
			IF recIPI002SELECT_01.KAIJI = '1' THEN
				IF recIPI002SELECT_01.TEIJI_SHOKAN_KNGK = 0 THEN
						gIPI002BIKO_01 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
						gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
										'2',
										'IPI002',
										recIPI002SELECT_01.ISIN_CD,
										recIPI002SELECT_01.KOZA_TEN_CD,
										recIPI002SELECT_01.KOZA_TEN_CIFCD,
										' ',
										recIPI002SELECT_01.MGR_RNM,
										'償還期日',
										recIPI002SELECT_01.SHOKAN_KJT,
										gIPI002BIKO_01,
										' ',
										' ',
										' ',
										l_inJikodaikoKbn);
						-- エラー判定
						IF gFncResult != pkconstant.success() THEN
							RETURN pkconstant.FATAL();
						END IF;
				END IF;
			ELSE
				gIPI002BIKO_01 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
								'2',
								'IPI002',
								recIPI002SELECT_01.ISIN_CD,
								recIPI002SELECT_01.KOZA_TEN_CD,
								recIPI002SELECT_01.KOZA_TEN_CIFCD,
								' ',
								recIPI002SELECT_01.MGR_RNM,
								'償還期日',
								recIPI002SELECT_01.SHOKAN_KJT,
								gIPI002BIKO_01,
								' ',
								' ',
								' ',
								l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
	END IF;
	--▼(2)請求書出力日が償還日（休日補正後）n営業日前の銘柄で、請求書出力日の3営業日前になり、次回償還期日の変動償還額が未入力または未承認の場合
	FOR recIPI002SELECT_02 IN curIPI002SELECT_02 LOOP
    -- 次回償還期日の８営業日前を取得
    g8MaeEigyoYmdIPI002 := pkdate.getMinusDateBusiness(recIPI002SELECT_02.SHOKAN_YMD::character varying, 8::integer);
		IF recIPI002SELECT_02.KAIJI = '1' THEN
			IF recIPI002SELECT_02.TEIJI_SHOKAN_KNGK = 0 THEN
				gIPI002BIKO_02 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
								'2',
								'IPI002',
								recIPI002SELECT_02.ISIN_CD,
								recIPI002SELECT_02.KOZA_TEN_CD,
								recIPI002SELECT_02.KOZA_TEN_CIFCD,
								' ',
								recIPI002SELECT_02.MGR_RNM,
								'償還期日',
								recIPI002SELECT_02.SHOKAN_KJT,
								gIPI002BIKO_02,
								' ',
								' ',
								' ',
								l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		ELSE
			gIPI002BIKO_02 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'2',
							'IPI002',
							recIPI002SELECT_02.ISIN_CD,
							recIPI002SELECT_02.KOZA_TEN_CD,
							recIPI002SELECT_02.KOZA_TEN_CIFCD,
							' ',
							recIPI002SELECT_02.MGR_RNM,
							'償還期日',
							recIPI002SELECT_02.SHOKAN_KJT,
							gIPI002BIKO_02,
							' ',
							' ',
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END IF;
	END LOOP;
	--▼(3)請求書出力日が償還日(休日補正後)の当月第1営業日の銘柄で、償還日（休日補正後）の前月15日（休日の場合、前営業日）になり、次回償還期日の変動償還額が未入力または未承認の場合。
	-- 15日の休日判定区分を取得
	gHolidayCheck := pkdate.isBusinessDay((SUBSTR(gGyomuYmd,1,6) || 15)::character varying, '1'::character);
	-- 休日判定結果	＝'1'の場合
	IF gHolidayCheck = '1' THEN
		-- 共通部品にて、15日の前営業日を取得、ローカル変数．前営業日に設定する
		gMaeEigyoYmd := pkdate.getMinusDateBusiness((SUBSTR(gGyomuYmd,1,6) || 15)::character varying, 1::integer);
		-- 共通部品にて、警告出力日を取得、ローカル変数．警告出力日に設定する
		gWarningYmd := pkdate.getMinusDateBusiness(gMaeEigyoYmd::character varying, 1::integer);
	-- 休日判定結果	<>'1'の場合
	ELSE
		-- 共通部品にて、15日の前営業日を取得、ローカル変数．前営業日に設定する
		gWarningYmd := pkdate.getMinusDateBusiness((SUBSTR(gGyomuYmd,1,6) || 15)::character varying, 1::integer);
	END IF;
	-- ローカル変数．業務日付　＞＝　ローカル変数．警告出力日の場合
	IF gGyomuYmd >= gWarningYmd THEN
		-- １か月後の日付を取得
		gGyomuYmdAfter := pkdate.calcMonth(gGyomuYmd::character varying,1::integer);
		-- １か月後の月初営業日を取得
		gGessyoYmdAfter := pkDate.getGesshoBusinessYmd(gGyomuYmdAfter::character varying,'1'::character);
		FOR recIPI002SELECT_03 IN curIPI002SELECT_03 LOOP
      -- 次回償還期日の８営業日前を取得
      g8MaeEigyoYmdIPI002 := pkdate.getMinusDateBusiness(recIPI002SELECT_03.SHOKAN_YMD::character varying, 8::integer);
      IF recIPI002SELECT_03.KAIJI = '1' THEN
				IF recIPI002SELECT_03.TEIJI_SHOKAN_KNGK = 0  THEN
						gIPI002BIKO_03 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
						gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
										'2',
										'IPI002',
										recIPI002SELECT_03.ISIN_CD,
										recIPI002SELECT_03.KOZA_TEN_CD,
										recIPI002SELECT_03.KOZA_TEN_CIFCD,
										' ',
										recIPI002SELECT_03.MGR_RNM,
										'償還期日',
										recIPI002SELECT_03.SHOKAN_KJT,
										gIPI002BIKO_03,
										' ',
										' ',
										' ',
										l_inJikodaikoKbn);
						-- エラー判定
						IF gFncResult != pkconstant.success() THEN
							RETURN pkconstant.FATAL();
						END IF;
				END IF;
			ELSE
				gIPI002BIKO_03 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
								'2',
								'IPI002',
								recIPI002SELECT_03.ISIN_CD,
								recIPI002SELECT_03.KOZA_TEN_CD,
								recIPI002SELECT_03.KOZA_TEN_CIFCD,
								' ',
								recIPI002SELECT_03.MGR_RNM,
								'償還期日',
								recIPI002SELECT_03.SHOKAN_KJT,
								gIPI002BIKO_03,
								' ',
								' ',
								' ',
								l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
	ELSE
		FOR recIPI002SELECT_04 IN curIPI002SELECT_04 LOOP
      -- 次回償還期日の８営業日前を取得
      g8MaeEigyoYmdIPI002 := pkdate.getMinusDateBusiness(recIPI002SELECT_04.SHOKAN_YMD::character varying, 8::integer);
			IF recIPI002SELECT_04.KAIJI = '1' THEN
				IF recIPI002SELECT_04.TEIJI_SHOKAN_KNGK = 0  THEN
					gIPI002BIKO_04 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
					gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
									'2',
									'IPI002',
									recIPI002SELECT_04.ISIN_CD,
									recIPI002SELECT_04.KOZA_TEN_CD,
									recIPI002SELECT_04.KOZA_TEN_CIFCD,
									' ',
									recIPI002SELECT_04.MGR_RNM,
									'償還期日',
									recIPI002SELECT_04.SHOKAN_KJT,
									gIPI002BIKO_04,
									' ',
									' ',
									' ',
									l_inJikodaikoKbn);
					-- エラー判定
					IF gFncResult != pkconstant.success() THEN
						RETURN pkconstant.FATAL();
					END IF;
				END IF;
			ELSE
				gIPI002BIKO_04 := '次回償還日の8営業日前（' || substr(g8MaeEigyoYmdIPI002,1,4) || '/' || substr(g8MaeEigyoYmdIPI002,5,2) || '/' || substr(g8MaeEigyoYmdIPI002,7,2) || '）';
				gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
								'2',
								'IPI002',
								recIPI002SELECT_04.ISIN_CD,
								recIPI002SELECT_04.KOZA_TEN_CD,
								recIPI002SELECT_04.KOZA_TEN_CIFCD,
								' ',
								recIPI002SELECT_04.MGR_RNM,
								'償還期日',
								recIPI002SELECT_04.SHOKAN_KJT,
								gIPI002BIKO_04,
								' ',
								' ',
								' ',
								l_inJikodaikoKbn);
				-- エラー判定
				IF gFncResult != pkconstant.success() THEN
					RETURN pkconstant.FATAL();
				END IF;
			END IF;
		END LOOP;
	END IF;
/*==============================================================================*/

/* IPW005連絡データ作成(createIPW005)                                           */

/*==============================================================================*/

	FOR recIPW005SELECT IN curIPW005SELECT LOOP
		gFncResult := SFCALCKICHUHENREI(recIPW005SELECT.ITAKU_KAISHA_CD,
						recIPW005SELECT.MGR_CD,
						recIPW005SELECT.TESU_SHURUI_CD,
						recIPW005SELECT.CHOKYU_YMD,
						recIPW005SELECT.ALL_TESU_KNGK,
						recIPW005SELECT.ZEINUKI_TESU_KNGK,
						recIPW005SELECT.SZEI_TESU_KNGK,
						gALLHenreiKingaku,
						gZeinukiHenreiKingaku,
						gSzeiHenreiKingaku
						);
		IF gALLHenreiKingaku != 0 THEN
			gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
							'1',
							'IPW005',
							recIPW005SELECT.ISIN_CD,
							recIPW005SELECT.KOZA_TEN_CD,
							recIPW005SELECT.KOZA_TEN_CIFCD,
							' ',
							recIPW005SELECT.MGR_RNM,
							'徴求日',
							recIPW005SELECT.CHOKYU_YMD,
							TO_CHAR(gALLHenreiKingaku,'99G999G999G999'),
							' ',
							' ',
							' ',
							l_inJikodaikoKbn);
			-- エラー判定
			IF gFncResult != pkconstant.success() THEN
				RETURN pkconstant.FATAL();
			END IF;
		END IF;
	END LOOP;
/*==============================================================================*/

/* IPW017警告データ作成(createIPW017)                                           */

/*==============================================================================*/

	FOR recIPW017SELECT IN curIPW017SELECT LOOP
		gFncResult := SFIPKEIKOKUINSERT(l_inItakuKaishaCd,
						'1',
						'IPW017',
						recIPW017SELECT.ISIN_CD,
						' ',
						' ',
						' ',
						recIPW017SELECT.MGR_RNM,
						' ',
						' ',
						' ',
						' ',
						' ',
						' ',
						l_inJikodaikoKbn);
		-- エラー判定
		IF gFncResult != pkconstant.success() THEN
			RETURN pkconstant.FATAL();
		END IF;
	END LOOP;
/*==============================================================================*/

/* 警告・連絡情報リスト（公社債関連管理リスト）作成                             */

/*==============================================================================*/

	--帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE
			KEY_CD = l_inItakuKaishaCd
	AND		CHOHYO_ID = 'KW931504651';
	
	CALL SPIPX117K15R01(C_REPORT_ID,
			l_inItakuKaishaCd,
			l_inItakuKaishaRnm,
			l_inJikodaikoKbn,
			'BATCH',
			'1',
			gGyomuYmd,
			gRtnCd,
			gSqlErrM);
	IF gRtnCd = pkconstant.success() OR gRtnCd = '2'  THEN
		       CALL pkPrtOk.insertPrtOk('BATCH',
					   l_inItakuKaishaCd,
					   gGyomuYmd,
					   '1',
					   C_REPORT_ID);
		RETURN pkconstant.success();
	ELSE
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || gRtnCd);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM(gRtnCd));
		RETURN gRtnCd;
	END IF;
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		RAISE NOTICE '[ERROR] Exception caught: % - %', SQLSTATE, SQLERRM;
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx117k15r01_01 ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inItakuKaishaRnm SOWN_INFO.BANK_RNM%TYPE, l_inJikodaikoKbn text ) FROM PUBLIC;