


-- Oracle package 'pkipakessanhosei' declaration, please edit to match PostgreSQL syntax.

-- DROP SCHEMA IF EXISTS pkipakessanhosei CASCADE;
CREATE SCHEMA IF NOT EXISTS pkipakessanhosei;


--
-- * 未収前受収益計算パッケージ
-- *
-- * @author 吉末 美希
-- * @version $Id: pkIpaKessanHosei.sql,v 1.11.2.1 2019/12/27 07:56:41 saito Exp $
-- * @return returnCd	リターンコード 0:成功　1：予期したエラー　99：予期せぬエラー
-- 
CREATE OR REPLACE FUNCTION pkipakessanhosei.calchosei ( 
	l_inItakukaishaCd text,				-- 委託会社コード
 l_inKessanKijunYm text,				-- 決算基準年月（YYYYMM)
 l_inShiyoKyokumenKbn text,					-- 使用局面区分（1：未収前受収益一覧表で使用、2：新経理で使用）
 l_inUserId text				-- ユーザID
 ) RETURNS numeric AS $body$
DECLARE

--=======================================================================================================*
-- * 変数定義
-- *=======================================================================================================
	gReturnCd				numeric := 1;							-- リターンコード
	gGyomuYmd				char(8);									-- 業務日付
	gKessanKijunYmd			char(8);									-- 決算基準日
	gJikoBunpairitsuBunshi	MISYU_MAEUKE.OWN_DF_BUNSHI%TYPE;			-- 自行分配率（分子）
	gMishuMaeukeKbn			MISYU_MAEUKE.MISHU_MAEUKE_KBN%TYPE;			-- 未収前受区分
	gHoseiKikanBunshiStart	MISYU_MAEUKE.HOSEI_BUNSHI_ST_YMD%TYPE;		-- 補正期間分子開始日
	gHoseiKikanBunshiEnd	MISYU_MAEUKE.HOSEI_BUNSHI_ED_YMD%TYPE;		-- 補正期間分子終了日
	gHoseiNissuBunshi		numeric;										-- 補正日数分子
	gHoseiNissuBunbo		numeric;										-- 補正日数分母
	gTesuryo				MISYU_MAEUKE.TESU_NUKI_KNGK%TYPE;			-- 手数料
	gShohizei				MISYU_MAEUKE.SZEI_KNGK%TYPE;				-- 消費税
	gHoseiTesuryo			MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK%TYPE;		-- 補正手数料額
	gHoseiShohizei			MISYU_MAEUKE.HOSEI_SZEI_KNGK%TYPE;			-- 補正消費税
	gKirisuteFlg			numeric;										-- 切捨てフラグ
	gWakachiFlg				char(1);									-- 分かちフラグ（0：分かち計算しない、1：分かち計算する）
	gMishuCalcPatternFlg	char(1);									-- 未収計算方式フラグ
	gGetsumatsuZndk			numeric[];									-- 未収期間の月末残高を格納する配列
	gGetsumatsuShohizei		numeric;										-- 月末日時点の消費税率
	gShohiZeiBefore			numeric;										-- 未収期間開始時点の消費税率
	gShohiZeiAfter			numeric;										-- 未収期間終了時点の消費税率
	gTekiyostYmdAfter		char(8);									-- 消費税改定後の適用開始日
	gTsukisu				numeric;										-- 未収期間の月数
	gTsukisuBefore			numeric;										-- 未収期間の月数（消費税改定前）
	gTsukisuAfter			numeric;										-- 未収期間の月数（消費税改定後）
	gGetsuMatsuYmd			char(8);									-- 月末日
	gGesshoYmd				char(8);									-- 月初日
	gHasuNissu				numeric;										-- 端数日数
	
	gMisyuTesuryo			numeric;										-- 未収期間の1ヶ月分の未収手数料（税抜）
	
	gAllMisyuTesuryo		numeric;										-- 未収期間の全体の未収手数料（税抜）
	gAllMisyuTesuryoBefore	numeric;										-- 未収期間の全体の未収手数料（税抜）（消費税改定前）
	gAllMisyuTesuryoAfter	numeric;										-- 未収期間の全体の未収手数料（税抜）（消費税改定後）
	gAllMisyuTesuryoSZei	numeric;										-- 未収期間の全体の未収手数料（消費税）
	
	gTakoMisyuTesuryo		numeric;										-- 未収期間の他行分の未収手数料（税抜）
	gTakoMisyuTesuryoBefore	numeric;										-- 未収期間の他行分の未収手数料（税抜）（消費税改定前）
	gTakoMisyuTesuryoAfter	numeric;										-- 未収期間の他行分の未収手数料（税抜）（消費税改定後）
	gTakoMisyuTesuryoSZei	numeric;										-- 未収期間の他行分の未収手数料（消費税）
	gTakoMisyuTesuryoSum	numeric;										-- 未収期間の他行分の未収手数料（税抜）合計
	gTakoMisyuTesuryoSZeiSum	numeric;									-- 未収期間の他行分の未収手数料（消費税）合計
	
	gMisyuTeigaku			numeric;										-- 未収期間の未収手数料（定額）（税抜）
	gMisyuTeigakuSZei		numeric;										-- 未収期間の未収手数料（定額）（消費税）
	gMisyuTeigakuBefore		numeric;										-- 未収期間の未収手数料（定額）（税抜）（消費税改定前）
	gMisyuTeigakuAfter		numeric;										-- 未収期間の未収手数料（定額）（税抜）（消費税改定後）
	
	gJimuTesuryo			MISYU_MAEUKE.TESU_NUKI_KNGK%TYPE;			-- 期中事務代行手数料
	gJimuShohizei			MISYU_MAEUKE.SZEI_KNGK%TYPE;				-- 期中事務代行手数料（消費税）
	gJimuMisyuTesuryo		numeric;										-- 期中事務代行手数料の未収手数料（税抜）
	gJimuMisyuTesuryoSZei	numeric;										-- 期中事務代行手数料の未収手数料（消費税）
--=======================================================================================================*
-- * 定数定義
-- *=======================================================================================================
	DATA_SAKUSEI_KBN		CONSTANT	char(1)	:= '0';	-- データ作成区分
	MISHU					CONSTANT	char(1)	:= '1';	-- 未収
	KISHU					CONSTANT	char(1)	:= '2';	-- 既収
	C_SHONIN				CONSTANT	char(1)	:= '1';	-- 承認済み
	C_NOT_MASSHO			CONSTANT	char(1)	:= '0';	-- 抹消ではない
	C_REAL_VALUE            CONSTANT	integer	:=	3;	-- 残高共通関数用実数
--========================================================================================================*
-- * カーソル定義
-- *========================================================================================================
	-- 手数料計算前の未収/既収および予定/確定データを取得するカーソル
	beforeMishuMaeukeShueki CURSOR FOR

		SELECT
			T.MISHU_KISHU_FLG,
			T.YOTEI_KAKUTEI_FLG,
			T.ITAKU_KAISHA_CD,
			T.MGR_CD,
			T.TESU_SHURUI_CD,
			T.CHOKYU_YMD,
			T.CHOKYU_KJT,
			T.CALC_PATTERN_CD,
			T.SS_TEIGAKU_TESU_KNGK,
			T.HKT_CD,
			T.HAKKO_YMD,
			T.FULLSHOKAN_KJT,
			T.SS_TESU_BUNBO,
			T.SS_TESU_BUNSHI,
			T.SS_TESU_DF_BUNBO,
			T.SS_NENCHOKYU_CNT,
			T.DAY_MONTH_KBN,
			T.SZEI_SEIKYU_KBN
		FROM (
				--未収予定データ
				SELECT
					'1'					AS MISHU_KISHU_FLG,
					'1'					AS YOTEI_KAKUTEI_FLG,
					MG4.ITAKU_KAISHA_CD	AS ITAKU_KAISHA_CD,
					MG4.MGR_CD			AS MGR_CD,
					MG4.TESU_SHURUI_CD	AS TESU_SHURUI_CD,
					MG4.CHOKYU_YMD		AS CHOKYU_YMD,
					MG4.CHOKYU_KJT		AS CHOKYU_KJT,
					MG4.CALC_PATTERN_CD	AS CALC_PATTERN_CD,
					MG4.SS_TEIGAKU_TESU_KNGK AS SS_TEIGAKU_TESU_KNGK,
					VMG1.HKT_CD			AS HKT_CD,
					VMG1.HAKKO_YMD		AS HAKKO_YMD,
					VMG1.FULLSHOKAN_KJT	AS FULLSHOKAN_KJT,
					MG8.SS_TESU_BUNBO	AS SS_TESU_BUNBO,
					MG8.SS_TESU_BUNSHI	AS SS_TESU_BUNSHI,
					MG8.SS_TESU_DF_BUNBO AS SS_TESU_DF_BUNBO,
					MG8.SS_NENCHOKYU_CNT AS SS_NENCHOKYU_CNT,
					MG8.DAY_MONTH_KBN	AS DAY_MONTH_KBN,
					MG8.SZEI_SEIKYU_KBN	AS SZEI_SEIKYU_KBN
				FROM
					MGR_TESKIJ MG4,
					MGR_KIHON_VIEW VMG1,
					MGR_TESURYO_CTL MG7,
					MGR_TESURYO_PRM MG8
				WHERE
					MG4.ITAKU_KAISHA_CD = l_inItakukaishaCd
				AND
					MG4.CHOKYU_YMD > gGyomuYmd
				AND
					MG4.ST_CALC_YMD <= gKessanKijunYmd
				AND
					(trim(both MG4.ST_CALC_YMD) IS NOT NULL AND (trim(both MG4.ST_CALC_YMD))::text <> '')
				AND
					(trim(both MG4.ED_CALC_YMD) IS NOT NULL AND (trim(both MG4.ED_CALC_YMD))::text <> '')
				AND
					MG4.CHOKYU_YMD > gKessanKijunYmd
				AND
					MG4.TESU_SHURUI_CD IN ('11', '12')
				AND
					MG4.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = VMG1.MGR_CD
				AND
					VMG1.MGR_STAT_KBN = C_SHONIN
				AND
					VMG1.MASSHO_FLG = C_NOT_MASSHO
				AND
					(trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
				AND
					MG4.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG7.MGR_CD
				AND
					MG4.TESU_SHURUI_CD = MG7.TESU_SHURUI_CD
				AND
					MG4.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG8.MGR_CD
				-- 請求書出力可能な場合のみ(併存銘柄出力チェック)
				AND	PKIPACALCTESURYO.checkHeizonMgr(
									 MG4.ITAKU_KAISHA_CD
									,MG4.MGR_CD 
									,PKDATE.GETZENGETSUMATSUBUSINESSYMD(MG4.CHOKYU_KJT)	-- 徴求期日の前月末時点
									,'1') = 0  
				
UNION

				--既収予定データ
				SELECT
					'2'					AS MISHU_KISHU_FLG,
					'1'					AS YOTEI_KAKUTEI_FLG,
					MG4.ITAKU_KAISHA_CD	AS ITAKU_KAISHA_CD,
					MG4.MGR_CD			AS MGR_CD,
					MG4.TESU_SHURUI_CD	AS TESU_SHURUI_CD,
					MG4.CHOKYU_YMD		AS CHOKYU_YMD,
					MG4.CHOKYU_KJT		AS CHOKYU_KJT,
					MG4.CALC_PATTERN_CD	AS CALC_PATTERN_CD,
					MG4.SS_TEIGAKU_TESU_KNGK AS SS_TEIGAKU_TESU_KNGK,
					VMG1.HKT_CD			AS HKT_CD,
					VMG1.HAKKO_YMD		AS HAKKO_YMD,
					VMG1.FULLSHOKAN_KJT	AS FULLSHOKAN_KJT,
					MG8.SS_TESU_BUNBO	AS SS_TESU_BUNBO,
					MG8.SS_TESU_BUNSHI	AS SS_TESU_BUNSHI,
					MG8.SS_TESU_DF_BUNBO AS SS_TESU_DF_BUNBO,
					MG8.SS_NENCHOKYU_CNT AS SS_NENCHOKYU_CNT,
					MG8.DAY_MONTH_KBN	AS DAY_MONTH_KBN,
					MG8.SZEI_SEIKYU_KBN	AS SZEI_SEIKYU_KBN
				FROM
					MGR_TESKIJ MG4,
					MGR_KIHON_VIEW VMG1,
					MGR_TESURYO_CTL MG7,
					MGR_TESURYO_PRM MG8
				WHERE
					MG4.ITAKU_KAISHA_CD = l_inItakukaishaCd
				AND
					MG4.CHOKYU_YMD > gGyomuYmd
				AND
					MG4.ED_CALC_YMD > gKessanKijunYmd
				AND
					(trim(both MG4.ST_CALC_YMD) IS NOT NULL AND (trim(both MG4.ST_CALC_YMD))::text <> '')
				AND
					(trim(both MG4.ED_CALC_YMD) IS NOT NULL AND (trim(both MG4.ED_CALC_YMD))::text <> '')
				AND
					MG4.CHOKYU_YMD <= gKessanKijunYmd
				AND
					MG4.TESU_SHURUI_CD IN ('11', '12')
				AND
					MG4.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = VMG1.MGR_CD
				AND
					VMG1.MGR_STAT_KBN = C_SHONIN
				AND
					VMG1.MASSHO_FLG = C_NOT_MASSHO
				AND
					(trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
				AND
					MG4.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG7.MGR_CD
				AND
					MG4.TESU_SHURUI_CD = MG7.TESU_SHURUI_CD
				AND
					MG4.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG8.MGR_CD
				-- 請求書出力可能な場合のみ(併存銘柄出力チェック)
				AND	PKIPACALCTESURYO.checkHeizonMgr( 
									 MG4.ITAKU_KAISHA_CD
									,MG4.MGR_CD 
									,PKDATE.GETZENGETSUMATSUBUSINESSYMD(MG4.CHOKYU_KJT)	-- 徴求期日の前月末時点
									,'1') = 0  
				
UNION

				--未収確定データ
				SELECT
					'1'					AS MISHU_KISHU_FLG,
					'2'					AS YOTEI_KAKUTEI_FLG,
					T01.ITAKU_KAISHA_CD	AS ITAKU_KAISHA_CD,
					T01.MGR_CD			AS MGR_CD,
					T01.TESU_SHURUI_CD	AS TESU_SHURUI_CD,
					T01.CHOKYU_YMD		AS CHOKYU_YMD,
					T01.CHOKYU_KJT		AS CHOKYU_KJT,
					MG4.CALC_PATTERN_CD	AS CALC_PATTERN_CD,
					MG4.SS_TEIGAKU_TESU_KNGK AS SS_TEIGAKU_TESU_KNGK,
					VMG1.HKT_CD			AS HKT_CD,
					VMG1.HAKKO_YMD		AS HAKKO_YMD,
					VMG1.FULLSHOKAN_KJT	AS FULLSHOKAN_KJT,
					MG8.SS_TESU_BUNBO	AS SS_TESU_BUNBO,
					MG8.SS_TESU_BUNSHI	AS SS_TESU_BUNSHI,
					MG8.SS_TESU_DF_BUNBO AS SS_TESU_DF_BUNBO,
					MG8.SS_NENCHOKYU_CNT AS SS_NENCHOKYU_CNT,
					MG8.DAY_MONTH_KBN	AS DAY_MONTH_KBN,
					MG8.SZEI_SEIKYU_KBN	AS SZEI_SEIKYU_KBN
				FROM
					TESURYO T01,
					MGR_TESKIJ MG4,
					MGR_KIHON_VIEW VMG1,
					MGR_TESURYO_CTL MG7,
					MGR_TESURYO_PRM MG8
				WHERE
					MG4.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = T01.MGR_CD
				AND
					MG4.TESU_SHURUI_CD = T01.TESU_SHURUI_CD
				AND
					MG4.CHOKYU_KJT = T01.CHOKYU_KJT
				AND
					MG4.ITAKU_KAISHA_CD = l_inItakukaishaCd
				AND
					T01.CHOKYU_YMD <= gGyomuYmd
				AND
					MG4.ST_CALC_YMD <= gKessanKijunYmd
				AND
					(trim(both MG4.ST_CALC_YMD) IS NOT NULL AND (trim(both MG4.ST_CALC_YMD))::text <> '')
				AND
					(trim(both MG4.ED_CALC_YMD) IS NOT NULL AND (trim(both MG4.ED_CALC_YMD))::text <> '')
				AND (T01.NYUKIN_YMD > gKessanKijunYmd OR T01.NYUKIN_YMD = ' ')
				AND
					MG4.TESU_SHURUI_CD IN ('11', '12')
				AND
					MG4.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = VMG1.MGR_CD
				AND
					VMG1.MGR_STAT_KBN = C_SHONIN
				AND
					VMG1.MASSHO_FLG = C_NOT_MASSHO
				AND
					(trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
				AND
					MG4.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG7.MGR_CD
				AND
					MG4.TESU_SHURUI_CD = MG7.TESU_SHURUI_CD
				AND
					MG4.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG8.MGR_CD
				-- 請求書出力可能な場合のみ(併存銘柄出力チェック)
				AND	PKIPACALCTESURYO.checkHeizonMgr( 
									 MG4.ITAKU_KAISHA_CD
									,MG4.MGR_CD 
									,PKDATE.GETZENGETSUMATSUBUSINESSYMD(MG4.CHOKYU_KJT)	-- 徴求期日の前月末時点
									,'1') = 0  
				
UNION

				-- 既収確定データ
				SELECT
					'2'					AS MISHU_KISHU_FLG,
					'2'					AS YOTEI_KAKUTEI_FLG,
					T01.ITAKU_KAISHA_CD	AS ITAKU_KAISHA_CD,
					T01.MGR_CD			AS MGR_CD,
					T01.TESU_SHURUI_CD	AS TESU_SHURUI_CD,
					T01.CHOKYU_YMD		AS CHOKYU_YMD,
					T01.CHOKYU_KJT		AS CHOKYU_KJT,
					MG4.CALC_PATTERN_CD	AS CALC_PATTERN_CD,
					MG4.SS_TEIGAKU_TESU_KNGK AS SS_TEIGAKU_TESU_KNGK,
					VMG1.HKT_CD			AS HKT_CD,
					VMG1.HAKKO_YMD		AS HAKKO_YMD,
					VMG1.FULLSHOKAN_KJT	AS FULLSHOKAN_KJT,
					MG8.SS_TESU_BUNBO	AS SS_TESU_BUNBO,
					MG8.SS_TESU_BUNSHI	AS SS_TESU_BUNSHI,
					MG8.SS_TESU_DF_BUNBO AS SS_TESU_DF_BUNBO,
					MG8.SS_NENCHOKYU_CNT AS SS_NENCHOKYU_CNT,
					MG8.DAY_MONTH_KBN	AS DAY_MONTH_KBN,
					MG8.SZEI_SEIKYU_KBN	AS SZEI_SEIKYU_KBN
				FROM
					TESURYO T01,
					MGR_TESKIJ MG4,
					MGR_KIHON_VIEW VMG1,
					MGR_TESURYO_CTL MG7,
					MGR_TESURYO_PRM MG8
				WHERE
					MG4.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = T01.MGR_CD
				AND
					MG4.TESU_SHURUI_CD = T01.TESU_SHURUI_CD
				AND
					MG4.CHOKYU_KJT = T01.CHOKYU_KJT
				AND
					MG4.ITAKU_KAISHA_CD = l_inItakukaishaCd
				AND
					T01.CHOKYU_YMD <= gGyomuYmd
				AND
					MG4.ED_CALC_YMD > gKessanKijunYmd
				AND
					(trim(both MG4.ST_CALC_YMD) IS NOT NULL AND (trim(both MG4.ST_CALC_YMD))::text <> '')
				AND
					(trim(both MG4.ED_CALC_YMD) IS NOT NULL AND (trim(both MG4.ED_CALC_YMD))::text <> '')
				AND
					trim(both T01.NYUKIN_YMD) <= gKessanKijunYmd
				AND
					MG4.TESU_SHURUI_CD IN ('11', '12')
				AND
					MG4.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = VMG1.MGR_CD
				AND
					VMG1.MGR_STAT_KBN = C_SHONIN
				AND
					VMG1.MASSHO_FLG = C_NOT_MASSHO
				AND
					(trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
				AND
					MG4.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG7.MGR_CD
				AND
					MG4.TESU_SHURUI_CD = MG7.TESU_SHURUI_CD
				AND
					MG4.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
				AND
					MG4.MGR_CD = MG8.MGR_CD
				-- 請求書出力可能な場合のみ(併存銘柄出力チェック)
				AND	PKIPACALCTESURYO.checkHeizonMgr( 
									 MG4.ITAKU_KAISHA_CD
									,MG4.MGR_CD 
									,PKDATE.GETZENGETSUMATSUBUSINESSYMD(MG4.CHOKYU_KJT)	-- 徴求期日の前月末時点
									,'1') = 0  ) T 

			ORDER BY T.YOTEI_KAKUTEI_FLG,
					 T.MISHU_KISHU_FLG;

	-- 手数料計算後の未収/既収および予定/確定データを取得するカーソル
	afterMishuMaeukeShueki CURSOR(in_ItakuKaishaCd  text,
									in_mgrCd		  text,
									in_tesuShuruiCd   text,
									in_chokyuKjt	 text) FOR

		SELECT
			T01.ITAKU_KAISHA_CD		AS ITAKU_KAISHA_CD,
			T01.MGR_CD				AS MGR_CD,
			T01.TSUKA_CD			AS TSUKA_CD,
			T01.JTK_KBN				AS JTK_KBN,
			T01.TESU_SHURUI_CD		AS TESU_SHURUI_CD,
			T01.CHOKYU_KJT			AS CHOKYU_KJT,
			T01.CHOKYU_YMD			AS CHOKYU_YMD,
			T01.NYUKIN_YMD			AS NYUKIN_YMD,
			T01.KIJUN_ZNDK			AS KIJUN_ZNDK,
			T01.TESU_RITSU_BUNBO	AS TESU_RITSU_BUNBO,
			T01.TESU_RITSU_BUNSHI	AS TESU_RITSU_BUNSHI,
			T01.DF_BUNBO			AS DF_BUNBO,
			T01.OWN_TESU_KNGK		AS OWN_TESU_KNGK,
			T01.HOSEI_OWN_TESU_KNGK AS HOSEI_OWN_TESU_KNGK,
			T01.OWN_TESU_SZEI		AS OWN_TESU_SZEI,
			T01.HOSEI_OWN_TESU_SZEI AS HOSEI_OWN_TESU_SZEI,
			T03.CALC_F_YMD			AS CALC_F_YMD,
			T03.CALC_T_YMD			AS CALC_T_YMD,
			T01.DATA_SAKUSEI_KBN	AS DATA_SAKUSEI_KBN,
			T01.SHORI_KBN			AS SHORI_KBN
		FROM
			TESURYO T01,
			TESURYO_KICHU T03
		WHERE
			T01.ITAKU_KAISHA_CD = T03.ITAKU_KAISHA_CD
		AND
			T01.MGR_CD = T03.MGR_CD
		AND
			T01.TESU_SHURUI_CD = T03.TESU_SHURUI_CD
		AND
			T01.CHOKYU_KJT = T03.CHOKYU_KJT
		AND
			T01.ITAKU_KAISHA_CD = in_ItakuKaishaCd
		AND
			T01.MGR_CD = in_mgrCd
		AND
			T01.TESU_SHURUI_CD = in_tesuShuruiCd
		AND
			T01.CHOKYU_KJT = in_chokyuKjt;

	-- 他行の手数料分配率を取得するカーソル
	curMgrJutakuginko CURSOR(
				l_inItakukaishaCd    TESURYO.ITAKU_KAISHA_CD%TYPE,
				l_inMgrCd            TESURYO.MGR_CD%TYPE
	) FOR
		SELECT
			MG6.ITAKU_KAISHA_CD          AS ITAKU_KAISHA_CD,
			MG6.MGR_CD                   AS MGR_CD,
			MG6.JTK_KBN                  AS JTK_KBN,
			MG6.FINANCIAL_SECURITIES_KBN AS FINANCIAL_SECURITIES_KBN,
			MG6.BANK_CD                  AS BANK_CD,
			MG6.KICHU_BUN_DF_BUNSHI      AS KICHU_BUN_DF_BUNSHI
		FROM
			MGR_JUTAKUGINKO MG6
		WHERE
			MG6.ITAKU_KAISHA_CD = l_inItakukaishaCd
		AND MG6.MGR_CD          = l_inMgrCd
		AND MG6.JTK_KBN         = '2'    -- 他行分のみ抽出
	;

	-- 期中事務代行手数料情報を取得するカーソル
	curKichuJimuTesuryo CURSOR(
				l_inItakukaishaCd	 MGR_TESKIJ.ITAKU_KAISHA_CD%TYPE,
				l_inMgrCd			 MGR_TESKIJ.MGR_CD%TYPE,
				l_inChokyuKjt		 MGR_TESKIJ.CHOKYU_KJT%TYPE
	) FOR
		SELECT
			MG4.ITAKU_KAISHA_CD				AS ITAKU_KAISHA_CD,
			MG4.MGR_CD						AS MGR_CD,
			MG4.TESU_SHURUI_CD				AS TESU_SHURUI_CD,
			MG4.CHOKYU_KJT					AS CHOKYU_KJT,
			MG4.CHOKYU_YMD					AS CHOKYU_YMD,
			MG4.JMTEIGAKU_TESU_KNGK			AS JMTEIGAKU_TESU_KNGK,
			(MG8.KJ_NENCHOKYU_CNT)::numeric 	AS KJ_NENCHOKYU_CNT
		FROM
			MGR_TESKIJ MG4,
			MGR_TESURYO_PRM MG8
		WHERE
			MG4.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
		AND MG4.MGR_CD = MG8.MGR_CD
		AND MG4.ITAKU_KAISHA_CD = l_inItakukaishaCd
		AND MG4.MGR_CD = l_inMgrCd
		AND MG4.CHOKYU_KJT = l_inChokyuKjt
		AND MG4.TESU_SHURUI_CD = '21'	-- 事務手数料（期中）
	;
	
	-- 手数料計算結果情報を取得するカーソル
	curTesuryo CURSOR(
				l_inItakuKaishaCd  CHAR,
				l_inMgrCd          text,
				l_inTesuShuruiCd   CHAR,
				l_inChokyuKjt      CHAR
	) FOR
		SELECT
			T01.ITAKU_KAISHA_CD		AS ITAKU_KAISHA_CD,
			T01.MGR_CD				AS MGR_CD,
			T01.TESU_SHURUI_CD		AS TESU_SHURUI_CD,
			T01.CHOKYU_KJT			AS CHOKYU_KJT,
			T01.CHOKYU_YMD			AS CHOKYU_YMD,
			T01.NYUKIN_YMD			AS NYUKIN_YMD,
			T01.OWN_TESU_KNGK		AS OWN_TESU_KNGK,
			T01.HOSEI_OWN_TESU_KNGK AS HOSEI_OWN_TESU_KNGK,
			T01.OWN_TESU_SZEI		AS OWN_TESU_SZEI,
			T01.HOSEI_OWN_TESU_SZEI AS HOSEI_OWN_TESU_SZEI,
			T01.DATA_SAKUSEI_KBN	AS DATA_SAKUSEI_KBN,
			T01.SHORI_KBN			AS SHORI_KBN
		FROM
			TESURYO T01
		WHERE
			T01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND T01.MGR_CD = l_inMgrCd
		AND T01.TESU_SHURUI_CD = l_inTesuShuruiCd
		AND T01.CHOKYU_KJT = l_inChokyuKjt;
	
--========================================================================================================*
-- * メイン処理
-- *========================================================================================================
BEGIN

	--パラメータのチェック
	IF coalesce(trim(both l_inItakukaishaCd), '') = ''
	OR coalesce(trim(both l_inKessanKijunYm), '') = ''
	OR coalesce(trim(both l_inShiyoKyokumenKbn), '') = ''
	OR coalesce(trim(both l_inUserId), '') = '' THEN
		CALL pkLog.error('ECM501','pkIpaKessanHosei.calcHosei()', 'パラメータにNULLがあります');
		RETURN pkconstant.error();
	END IF;

	--業務日付を取得する
	gGyomuYmd		:= pkDate.getGyomuYmd();
	-- 決算基準年月より月末日を取得する（営業日補正なし）
	gKessanKijunYmd := to_char(((date_trunc('month',(to_date(l_inKessanKijunYm || '01','YYYYMMDD') )::timestamp + interval '1 month'))::timestamp(0) - interval '1 day'), 'YYYYMMDD');
	--日付のチェック
	IF (pkDate.validateDate(gKessanKijunYmd) = pkconstant.error()) THEN
		CALL pkLog.error('ECM502','pkIpaKessanHosei.calcHosei()', '決算基準日の取得に失敗しました');
		RETURN pkconstant.error();
	END IF;

	--未収前受収益テーブルより不要なデータを削除する
	gReturnCd := pkipakessanhosei.calchosei_deletemishumaeuke(l_inItakukaishaCd);

	IF gReturnCd != pkconstant.success() THEN
		CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '未収前受テーブルの削除に失敗しました');
		RETURN pkconstant.error();
	END IF;

	--手数料計算前カーソルをループする
	FOR recBefore IN beforeMishuMaeukeShueki
	LOOP
		-- 変数初期化
		gTsukisuBefore           := 0;  -- 消費税改定前の月数
		gTsukisuAfter            := 0;  -- 消費税改定後の月数
		gMisyuTesuryo            := 0;  -- 1ヶ月分の未収手数料
		gAllMisyuTesuryo         := 0;  -- 全体の未収手数料
		gAllMisyuTesuryoBefore   := 0;  -- 全体の未収手数料（消費税改定前）
		gAllMisyuTesuryoAfter    := 0;  -- 全体の未収手数料（消費税改定後）
		gTakoMisyuTesuryoSum     := 0;  -- 他行の未収手数料
		gTakoMisyuTesuryoSZeiSum := 0;  -- 他行の未収手数料（消費税）
		
		-- 各月末残高を格納する配列を初期化
		--   i=0:基準年月の当月末残高、i=1：基準年月の1ヶ月前の月末残高、・・・i=11：基準年月の11ヶ月前の月末残高
		gGetsumatsuZndk := ARRAY[0,0,0,0,0,0,0,0,0,0,0,0]::numeric[];
		FOR i IN 0..11 LOOP
			gGetsumatsuZndk[i+1] := 0;
		END LOOP;
	
		--予定確定区分が「1：予定」であれば期中手数料計算をおこなう
		IF recBefore.YOTEI_KAKUTEI_FLG = '1' THEN

			gReturnCd := PKIPAKICHUTESURYO.updateKichuTesuryoTbl(	recBefore.ITAKU_KAISHA_CD,
																	recBefore.MGR_CD,
																	recBefore.TESU_SHURUI_CD,
																	recBefore.CHOKYU_YMD,
																	DATA_SAKUSEI_KBN);

			IF gReturnCd != pkconstant.success() THEN
				CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '手数料計算に失敗しました');
				RETURN pkconstant.error();
			END IF;
		END IF;
		
		--手数料計算後カーソルをループする
		FOR recAfter IN afterMishuMaeukeShueki(recBefore.ITAKU_KAISHA_CD, recBefore.MGR_CD, recBefore.TESU_SHURUI_CD, recBefore.CHOKYU_KJT)
		LOOP

			--自行手数料が「0」の場合は処理を抜ける
			IF recAfter.OWN_TESU_KNGK != 0 THEN

				--未収前受収益テーブルへの更新準備
				--手数料計算結果分配テーブルより分配率分子を取得する
				gJikoBunpairitsuBunshi := pkipakessanhosei.calchosei_getjikobunpairitsu(recAfter.ITAKU_KAISHA_CD, recAfter.MGR_CD, recAfter.TESU_SHURUI_CD, recAfter.CHOKYU_KJT);

				--未収データの場合
				IF recBefore.MISHU_KISHU_FLG = MISHU THEN
				
					gMishuMaeukeKbn		 := MISHU;				   --未収前受区分には「1：未収」をセット
					gHoseiKikanBunshiStart  := recAfter.CALC_F_YMD;	 --計算期間分子開始日には計算期間FROMをセット
				
					--計算期間TO < 決算基準日 の場合
					IF recAfter.CALC_T_YMD < gKessanKijunYmd THEN
						gHoseiKikanBunshiEnd := recAfter.CALC_T_YMD;	--計算期間分子終了日には計算期間TOをセット
					ELSE
						gHoseiKikanBunshiEnd := gKessanKijunYmd;		--計算期間分子終了日には決算基準日をセット
					END IF;

					-- 自行手数料（税抜）、自行消費税をセットする
					IF recAfter.DATA_SAKUSEI_KBN = '2' AND recAfter.SHORI_KBN = '1' THEN
						gTesuryo  := recAfter.OWN_TESU_KNGK + recAfter.HOSEI_OWN_TESU_KNGK;
						gShohizei := recAfter.OWN_TESU_SZEI + recAfter.HOSEI_OWN_TESU_SZEI;
					ELSE
						gTesuryo  := recAfter.OWN_TESU_KNGK;
						gShohizei := recAfter.OWN_TESU_SZEI;
					END IF;
					
					-- 切捨てフラグをセットする
					IF recAfter.TSUKA_CD = 'JPY' THEN
						gKirisuteFlg := 0;
					ELSE
						gKirisuteFlg := 2;
					END IF;
					
					 -- 分かち確認
					 -- ※「未収期間開始時点の消費税率 <> 未収期間終了時点の消費税率」となる場合、分かちが発生する
					gShohiZeiBefore := pkIpaZei.getShohiZei(gHoseiKikanBunshiStart); -- 未収期間開始時点の消費税率
					gShohiZeiAfter  := pkIpaZei.getShohiZei(gHoseiKikanBunshiEnd);   -- 未収期間終了時点の消費税率
					
					IF gShohiZeiBefore <> gShohiZeiAfter THEN
						gWakachiFlg       := '1';
						gTekiyostYmdAfter := pkIpaZei.getShohiZeiStYmd(gHoseiKikanBunshiEnd);
					ELSE
						gWakachiFlg       := '0';
					END IF;
					
					-- 未収計算方式フラグを取得する（1：発行体が中部電力の銘柄、1以外：発行体が中部電力以外の銘柄）
					gMishuCalcPatternFlg := pkipakessanhosei.calchosei_getmishucalcpatternflg(recBefore.ITAKU_KAISHA_CD, recBefore.HKT_CD);
					
					-- 未収期間の月数を取得する（端数月も1ヶ月分とする）
					-- 例） 未収期間が2019/7/10 〜 2019/9/30の場合、月数は3
					gTsukisu := CEIL(oracle.months_between(to_date(gHoseiKikanBunshiEnd,'YYYYMMDD') + 1,
					                                to_date(gHoseiKikanBunshiStart,'YYYYMMDD')));
					
					-- 発行体が中部電力の場合
					IF gMishuCalcPatternFlg = '1' THEN
					
						-- 未収期間の全体の未収手数料を計算する
						FOR i IN 0..gTsukisu - 1
						LOOP
							-- 未収期間の月末日
							gGetsuMatsuYmd := pkDate.getGetsumatsuYmd(gHoseiKikanBunshiEnd, i * (-1));
							
							-- 未収期間の月末残高
							gGetsumatsuZndk[i+1] := pkIpaZndk.getKjnZndk(
														recAfter.ITAKU_KAISHA_CD,
														recAfter.MGR_CD,
														gGetsuMatsuYmd,
														C_REAL_VALUE
													);
							
							-- 期中管理手数料率（分母）が設定されている場合
							IF recBefore.SS_TESU_BUNBO <> 0 THEN
							
								-- 未収期間1ヶ月分の未収手数料（税抜）
								--   計算式） 未収計算期間月末残高 × 期中管理手数料率（分子） / 期中管理手数料率（分母） / 12
								gMisyuTesuryo := TRUNC((gGetsumatsuZndk[i+1] * recBefore.SS_TESU_BUNSHI / recBefore.SS_TESU_BUNBO / 12), gKirisuteFlg);
							
							END IF;
							
							-- 全体の未収手数料
							gAllMisyuTesuryo := gAllMisyuTesuryo + gMisyuTesuryo;
							
							-- 分かち計算する場合
							IF gWakachiFlg = '1' THEN
							
								-- 改定前の手数料、および月数を計算
								IF gGetsuMatsuYmd < gTekiyostYmdAfter THEN
								
									gAllMisyuTesuryoBefore := gAllMisyuTesuryoBefore + gMisyuTesuryo;
									gTsukisuBefore         := gTsukisuBefore + 1;
								
								-- 改定後の手数料、および月数を計算
								ELSE
									
									gAllMisyuTesuryoAfter := gAllMisyuTesuryoAfter + gMisyuTesuryo;
									gTsukisuAfter         := gTsukisuAfter + 1;
									
								END IF;
							
							END IF;
							
						END LOOP;
						
						-- 全体の未収手数料（消費税）を計算する
						IF gWakachiFlg = '1' THEN
							
							gAllMisyuTesuryoSZei := TRUNC((gAllMisyuTesuryoBefore * gShohiZeiBefore)::numeric, gKirisuteFlg::int)
							                        + TRUNC((gAllMisyuTesuryoAfter * gShohiZeiAfter)::numeric, gKirisuteFlg::int);
						ELSE
							
							gAllMisyuTesuryoSZei := TRUNC((gAllMisyuTesuryo * gShohiZeiAfter)::numeric, gKirisuteFlg::int);
							
						END IF;
						
						-- 他行分の未収手数料を計算する
						FOR recTako IN curMgrJutakuginko(recAfter.ITAKU_KAISHA_CD, recAfter.MGR_CD)
						LOOP
							-- 他行分の未収手数料（税抜）
							gTakoMisyuTesuryo := TRUNC((gAllMisyuTesuryo * recTako.KICHU_BUN_DF_BUNSHI / recBefore.SS_TESU_DF_BUNBO)::numeric, gKirisuteFlg::int);
							
							-- 他行分の未収手数料（消費税）
							-- ※切捨てタイミングによって1円の差異が出るので、全体の未収手数料（消費税）×分配率（分子）/分配率（分母）はNG
							IF gWakachiFlg = '1' THEN
								
								gTakoMisyuTesuryoBefore := TRUNC((gAllMisyuTesuryoBefore * recTako.KICHU_BUN_DF_BUNSHI / recBefore.SS_TESU_DF_BUNBO)::numeric, gKirisuteFlg::int);
								gTakoMisyuTesuryoAfter  := TRUNC((gAllMisyuTesuryoAfter * recTako.KICHU_BUN_DF_BUNSHI / recBefore.SS_TESU_DF_BUNBO)::numeric, gKirisuteFlg::int);
								
								gTakoMisyuTesuryoSZei   := TRUNC((gTakoMisyuTesuryoBefore * gShohiZeiBefore)::numeric, gKirisuteFlg::int)
								                           + TRUNC((gTakoMisyuTesuryoAfter * gShohiZeiAfter)::numeric, gKirisuteFlg::int);
							ELSE
								
								gTakoMisyuTesuryoSZei   := TRUNC((gTakoMisyuTesuryo * gShohiZeiAfter)::numeric, gKirisuteFlg::int);
								
							END IF;
							
							-- 他行分の未収手数料（税抜）合計
							gTakoMisyuTesuryoSum     := gTakoMisyuTesuryoSum + gTakoMisyuTesuryo;
							
							-- 他行分の未収手数料（消費税）合計
							gTakoMisyuTesuryoSZeiSum := gTakoMisyuTesuryoSZeiSum + gTakoMisyuTesuryoSZei;
							
							-- 自行が副受託の場合、当行分の未収手数料をセットしてループを抜ける
							IF recAfter.ITAKU_KAISHA_CD = recTako.BANK_CD THEN
								gHoseiTesuryo  := gTakoMisyuTesuryo;
								gHoseiShohizei := gTakoMisyuTesuryoSZei;
								EXIT;
							END IF;
							
						END LOOP;
						
						-- 受託区分が「1:代表（管理・受託）」の場合のみ、下記計算を行う
						IF recAfter.JTK_KBN = '1' THEN
							
							-- 当行分の未収手数料（税抜）
							gHoseiTesuryo  := gAllMisyuTesuryo - gTakoMisyuTesuryoSum;
							
							-- 当行分の未収手数料（消費税）
							gHoseiShohizei := gAllMisyuTesuryoSZei - gTakoMisyuTesuryoSZeiSum;
							
						END IF;
						
						-- 期中事務手数料の未収額を計算し、未収前受テーブルに登録する
						FOR recKichuJimuTesuryo IN curKichuJimuTesuryo(recAfter.ITAKU_KAISHA_CD, recAfter.MGR_CD, recAfter.CHOKYU_KJT)
						LOOP
							-- 期中事務手数料を計算する
							gReturnCd := pkIpaZaimuJimuTesuryo.updateZaimuJimuTesuryoTbl(
											recAfter.ITAKU_KAISHA_CD,
											recAfter.MGR_CD,
											'21', -- 事務手数料（期中）
											recAfter.CHOKYU_YMD,
											DATA_SAKUSEI_KBN
										);
				
							IF gReturnCd != pkconstant.success() THEN
								CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '期中事務の手数料計算に失敗しました');
								RETURN pkconstant.error();
							END IF;
							
							-- 手数料計算結果テーブルから期中事務手数料を取得する
							FOR recTesuryo IN curTesuryo(recAfter.ITAKU_KAISHA_CD, recAfter.MGR_CD, '21', recAfter.CHOKYU_KJT)
							LOOP
							
								-- 自行手数料（税抜）、自行消費税をセットする
								-- データ作成区分「2：補正」かつ処理区分「1：承認済」の場合
								IF recTesuryo.DATA_SAKUSEI_KBN = '2' AND recTesuryo.SHORI_KBN = '1' THEN
									gJimuTesuryo  := recTesuryo.OWN_TESU_KNGK + recTesuryo.HOSEI_OWN_TESU_KNGK;
									gJimuShohizei := recTesuryo.OWN_TESU_SZEI + recTesuryo.HOSEI_OWN_TESU_SZEI;
								ELSE
									gJimuTesuryo  := recTesuryo.OWN_TESU_KNGK;
									gJimuShohizei := recTesuryo.OWN_TESU_SZEI;
								END IF;
							
								-- 定額手数料の未収金額を計算する
								SELECT * FROM pkipakessanhosei.calchosei_calcmisyuteigakutesuryo(
												gWakachiFlg, gTsukisu, gTsukisuBefore, gTsukisuAfter, gKirisuteFlg, gShohiZeiBefore, gShohiZeiAfter, recKichuJimuTesuryo.JMTEIGAKU_TESU_KNGK, recKichuJimuTesuryo.KJ_NENCHOKYU_CNT) INTO STRICT gJimuMisyuTesuryo,         -- （outパラメータ）期中事務の未収手数料（税抜）
												gJimuMisyuTesuryoSZei      -- （outパラメータ）期中事務の未収手数料（消費税）
											;
					
								IF gReturnCd != pkconstant.success() THEN
									CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '定額手数料（期中事務）の未収金額計算に失敗しました');
									RETURN pkconstant.error();
								END IF;
								
								-- 未収前受テーブルに登録する
								INSERT INTO MISYU_MAEUKE(
									ITAKU_KAISHA_CD,        -- 委託会社コード
									MGR_CD,					-- 銘柄コード
									TSUKA_CD,				-- 通貨コード
									JTK_KBN,				-- 受託区分
									HOSEI_KIJUN_YM,			-- 補正基準年月
									TESU_SHURUI_CD,			-- 手数料種類コード
									MISHU_MAEUKE_KBN,		-- 未収前受区分
									CHOKYU_KJT,				-- 徴求期日
									CHOKYU_YMD,				-- 徴求日
									NYUKIN_YMD,				-- 入金日
									HAKKO_YMD,				-- 発行年月日
									FULLSHOKAN_KJT,			-- 満期償還期日
									TESU_NUKI_KNGK,			-- 手数料金額
									SZEI_KNGK,				-- 消費税金額
									HOSEI_BUNSHI_ST_YMD,	-- 補正期間分子開始日
									HOSEI_BUNSHI_ED_YMD,	-- 補正期間分子終了日
									HOSEI_BUNBO_ST_YMD,		-- 補正期間分母開始日
									HOSEI_BUNBO_ED_YMD,		-- 補正期間分母終了日
									HOSEI_TESU_NUKI_KNGK,	-- 補正手数料額（税抜）
									HOSEI_SZEI_KNGK,		-- 補正消費税額
									SAKUSEI_ID)				-- 作成者
								VALUES (
									l_inItakukaishaCd,
									recAfter.MGR_CD,
									recAfter.TSUKA_CD,
									recAfter.JTK_KBN,
									l_inKessanKijunYm,
									recTesuryo.TESU_SHURUI_CD,
									gMishuMaeukeKbn,
									recTesuryo.CHOKYU_KJT,
									recTesuryo.CHOKYU_YMD,
									coalesce(recTesuryo.NYUKIN_YMD,' '),
									recBefore.HAKKO_YMD,
									recBefore.FULLSHOKAN_KJT,
									gJimuTesuryo,
									gJimuShohizei,
									gHoseiKikanBunshiStart,
									gHoseiKikanBunshiEnd,
									recAfter.CALC_F_YMD,
									recAfter.CALC_T_YMD,
									gJimuMisyuTesuryo,
									gJimuMisyuTesuryoSZei,
									l_inUserId);
							
							END LOOP;
						END LOOP;
						
					-- 発行体が中部電力以外の場合
					ELSE
					
						-- 日割月割区分が1：月割日割か3：月割の場合
						IF recBefore.DAY_MONTH_KBN IN ('1', '3') THEN
						
							-- 未収期間の全体の未収手数料を計算する
							FOR i IN 0..gTsukisu - 1
							LOOP
								-- 未収期間の月末日
								gGetsuMatsuYmd := pkDate.getGetsumatsuYmd(gHoseiKikanBunshiEnd, i * (-1));
								
								-- 未収期間の月末残高
								gGetsumatsuZndk[i+1] := pkIpaZndk.getKjnZndk(
															recAfter.ITAKU_KAISHA_CD,
															recAfter.MGR_CD,
															gGetsuMatsuYmd,
															C_REAL_VALUE
														);
								
								-- 期中管理手数料率（分母）が設定されている場合
								IF recBefore.SS_TESU_BUNBO <> 0 THEN
								
									-- 消費税を請求する場合のみ、月末日時点の消費税率を取得する
									IF recBefore.SZEI_SEIKYU_KBN = '1' THEN
										gGetsumatsuShohizei := pkIpaZei.getShohiZei(gGetsuMatsuYmd);
									ELSE
										gGetsumatsuShohizei := 0;
									END IF;
									
									-- 「月割日割」の場合
									IF recBefore.DAY_MONTH_KBN = '1' THEN
									
										-- 補正期間分子開始月かつ、補正期間分子開始日が月初以外の場合、端数分を計算する
										IF i = gTsukisu - 1 AND SUBSTR(gHoseiKikanBunshiStart, 7, 2) <> '01' THEN
										
											-- 端数日数（補正期間分子開始日の月末日 - 補正期間分子開始日 + 1）
											gHasuNissu := ABS(to_date(gGetsuMatsuYmd,'YYYYMMDD') - to_date(gHoseiKikanBunshiStart,'YYYYMMDD')) + 1;
											
											-- 未収期間1ヶ月分の未収手数料（税込）
											gMisyuTesuryo := TRUNC((gGetsumatsuZndk[i+1] * recBefore.SS_TESU_BUNSHI / recBefore.SS_TESU_BUNBO
											                         * gHasuNissu / 365 * (1 + gGetsumatsuShohizei)), gKirisuteFlg);
											
										-- 補正期間分子終了月かつ、月末日 ≠ 補正期間分子終了日の場合、端数分を計算する
										ELSIF i = 0 AND gGetsuMatsuYmd <> gHoseiKikanBunshiEnd  THEN
										
											-- 補正期間分子終了月の月初日
											gGesshoYmd := pkDate.getGesshoYmd(gHoseiKikanBunshiEnd);
											
											-- 端数日数（補正期間分子終了日 - 補正期間分子終了月の月初日 + 1）
											gHasuNissu := ABS(to_date(gHoseiKikanBunshiEnd,'YYYYMMDD') - to_date(gGesshoYmd,'YYYYMMDD')) + 1;
											
											-- 未収期間1ヶ月分の未収手数料（税込）
											gMisyuTesuryo := TRUNC((gGetsumatsuZndk[i+1] * recBefore.SS_TESU_BUNSHI / recBefore.SS_TESU_BUNBO
											                         * gHasuNissu / 365 * (1 + gGetsumatsuShohizei)), gKirisuteFlg);
											
										-- 上記以外の場合
										ELSE
											-- 未収期間1ヶ月分の未収手数料（税込）
											gMisyuTesuryo := TRUNC((gGetsumatsuZndk[i+1] * recBefore.SS_TESU_BUNSHI / recBefore.SS_TESU_BUNBO
											                         / 12 * (1 + gGetsumatsuShohizei)), gKirisuteFlg);
										END IF;
										
									-- 「月割」の場合
									ELSE
										-- 未収期間1ヶ月分の未収手数料（税込）
										gMisyuTesuryo := TRUNC((gGetsumatsuZndk[i+1] * recBefore.SS_TESU_BUNSHI / recBefore.SS_TESU_BUNBO
										                         / 12 * (1 + gGetsumatsuShohizei)), gKirisuteFlg);
									END IF;
								
								END IF;
								
								
								-- 全体の未収手数料
								gAllMisyuTesuryo := gAllMisyuTesuryo + gMisyuTesuryo;
								
								-- 分かち計算する場合
								IF gWakachiFlg = '1' THEN
								
									IF gGetsuMatsuYmd < gTekiyostYmdAfter THEN
										-- 改定前の月数をカウント
										gTsukisuBefore := gTsukisuBefore + 1;
									ELSE
										-- 改定後の月数をカウント
										gTsukisuAfter  := gTsukisuAfter  + 1;
									END IF;
									
								END IF;
								
							END LOOP;
							
							
							-- 他行分の未収手数料を計算する
							FOR recTako IN curMgrJutakuginko(recAfter.ITAKU_KAISHA_CD, recAfter.MGR_CD)
							LOOP
								-- 他行分の未収手数料（税込）
								gTakoMisyuTesuryo := TRUNC((gAllMisyuTesuryo * recTako.KICHU_BUN_DF_BUNSHI / recBefore.SS_TESU_DF_BUNBO)::numeric, gKirisuteFlg::int);
								
								-- 他行分の未収手数料（税込）合計
								gTakoMisyuTesuryoSum := gTakoMisyuTesuryoSum + gTakoMisyuTesuryo;
								
								-- 自行が副受託の場合、当行分の未収手数料をセットしてループを抜ける
								IF recAfter.ITAKU_KAISHA_CD = recTako.BANK_CD THEN
									gHoseiTesuryo  := gTakoMisyuTesuryo;
									gHoseiShohizei := 0;
									EXIT;
								END IF;
								
							END LOOP;
							
							
							-- 受託区分が「1:代表（管理・受託）」の場合のみ、下記計算を行う
							IF recAfter.JTK_KBN = '1' THEN
							
								-- 消費税を請求しない場合、消費税率に0をセットする
								IF recBefore.SZEI_SEIKYU_KBN <> '1' THEN
									gShohiZeiBefore := 0;
									gShohiZeiAfter  := 0;
								END IF;
							
								-- 定額手数料の未収金額を計算する
								SELECT * FROM pkipakessanhosei.calchosei_calcmisyuteigakutesuryo(
												gWakachiFlg,                     -- 分かちフラグ
												gTsukisu,                        -- 月数
												gTsukisuBefore,                  -- 消費税率改定前の月数
												gTsukisuAfter,                   -- 消費税率改定後の月数
												gKirisuteFlg,                    -- 切捨てフラグ
												gShohiZeiBefore,                 -- 改定前の消費税率
												gShohiZeiAfter,                  -- 改定後の消費税率
												recBefore.SS_TEIGAKU_TESU_KNGK,  -- 信託報酬・社管手数料_定額手数料
												recBefore.SS_NENCHOKYU_CNT) INTO STRICT      -- 信託報酬・社管手数料_年徴求回数
												gMisyuTeigaku,                   -- （outパラメータ）定額手数料の未収金額（税抜）
												gMisyuTeigakuSZei                -- （outパラメータ）定額手数料の未収金額（消費税）
											;
					
								IF gReturnCd != pkconstant.success() THEN
									CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '定額手数料の未収金額計算に失敗しました');
									RETURN pkconstant.error();
								END IF;
							
								-- 当行分の未収手数料（税込）
								--   計算式） 全体分の未収手数料（税込） - 他行分の未収手数料（税込）合計 + 未収手数料定額（税込） 
								gHoseiTesuryo := gAllMisyuTesuryo - gTakoMisyuTesuryoSum + (gMisyuTeigaku + gMisyuTeigakuSZei);
								
								-- 当行分の未収手数料（消費税）
								--   計算式） 発行体が中部電力以外の場合、消費税は算出しないので、0固定
								gHoseiShohizei := 0;
								
							END IF;
							
						-- 日割月割区分が1：月割日割、3：月割以外の場合、パッケージの計算処理を行う
						ELSE
						
							--補正日数分子、補正日数分母をもとめる
							gHoseiNissuBunshi := PKDATE.calcNissuRyoha(gHoseiKikanBunshiStart, gHoseiKikanBunshiEnd);
							gHoseiNissuBunbo  := PKDATE.calcNissuRyoha(recAfter.CALC_F_YMD, recAfter.CALC_T_YMD);
						
							--補正手数料額、補正消費税額をもとめる
							SELECT * FROM pkipakessanhosei.calchosei_hoseitesuryo(	recAfter.DATA_SAKUSEI_KBN, 		--データ作成区分
														recAfter.SHORI_KBN, 				--処理区分
														recAfter.OWN_TESU_KNGK, 			--自行手数料
														recAfter.HOSEI_OWN_TESU_KNGK, 	--補正自行手数料
														recAfter.OWN_TESU_SZEI, 			--自行消費税額
														recAfter.HOSEI_OWN_TESU_SZEI, 	--補正自行消費税額
														recAfter.TSUKA_CD, 				--通貨コード
														gHoseiNissuBunshi, 				--補正日数分子
														gHoseiNissuBunbo) INTO STRICT 				--補正日数分母
														gTesuryo, 						--手数料
														gShohizei, 						--消費税
														gHoseiTesuryo, 					--補正手数料
														gHoseiShohizei;				--補正消費税
			
							IF gReturnCd != pkconstant.success() THEN
								RETURN pkconstant.error();
								CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '未収前受収益を計算し、手数料を補正する処理に失敗しました');
							END IF;
							
						END IF;
					END IF;
						
				--既収データの場合
				ELSE
					gMishuMaeukeKbn		 := KISHU;						--未収前受区分には「2：既収」をセット
					--決算基準日 < 計算開始日FROMの場合
					IF gKessanKijunYmd < recAfter.CALC_F_YMD THEN
						gHoseiKikanBunshiStart := recAfter.CALC_F_YMD;	--計算期間分子開始日には決算期間FROMをセット
					ELSE
						gHoseiKikanBunshiStart := pkDate.getYokuYmd(gKessanKijunYmd);	--計算期間分子開始日には決算基準日の翌日をセット
					END IF;

					gHoseiKikanBunshiEnd := recAfter.CALC_T_YMD;

					--補正日数分子、補正日数分母をもとめる
					gHoseiNissuBunshi := PKDATE.calcNissuRyoha(gHoseiKikanBunshiStart, gHoseiKikanBunshiEnd);
					gHoseiNissuBunbo  := PKDATE.calcNissuRyoha(recAfter.CALC_F_YMD, recAfter.CALC_T_YMD);
	
					--補正手数料額、補正消費税額をもとめる
					SELECT * FROM pkipakessanhosei.calchosei_hoseitesuryo(	recAfter.DATA_SAKUSEI_KBN, 		--データ作成区分
												recAfter.SHORI_KBN, 				--処理区分
												recAfter.OWN_TESU_KNGK, 			--自行手数料
												recAfter.HOSEI_OWN_TESU_KNGK, 	--補正自行手数料
												recAfter.OWN_TESU_SZEI, 			--自行消費税額
												recAfter.HOSEI_OWN_TESU_SZEI, 	--補正自行消費税額
												recAfter.TSUKA_CD, 				--通貨コード
												gHoseiNissuBunshi, 				--補正日数分子
												gHoseiNissuBunbo) INTO STRICT 				--補正日数分母
												gTesuryo, 						--手数料
												gShohizei, 						--消費税
												gHoseiTesuryo, 					--補正手数料
												gHoseiShohizei;					--補正消費税
	
					IF gReturnCd != pkconstant.success() THEN
						RETURN pkconstant.error();
						CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '未収前受収益を計算し、手数料を補正する処理に失敗しました');
					END IF;
					
				END IF;
				
				-- 計算パターンが月毎計算方式か定額方式以外の場合、各月末残高を0で初期化
				IF recBefore.CALC_PATTERN_CD NOT IN ('3', '4') THEN
				
					FOR i IN 0..11 LOOP
						gGetsumatsuZndk[i+1] := 0;
					END LOOP;
				
				END IF;
				
				-- 計算期間FROM 〜 計算期間TOが全て未収期間となる場合、
				-- 補正手数料額（税抜）、補正消費税額は、それぞれ自行手数料（税抜）、自行消費税と同じ金額をセットする
				IF gMishuMaeukeKbn = MISHU
					AND gHoseiKikanBunshiEnd = recAfter.CALC_T_YMD
				THEN
					gHoseiTesuryo  := gTesuryo;
					gHoseiShohizei := gShohizei;
				END IF;
				
				--未収前受テーブルに登録する
				INSERT INTO MISYU_MAEUKE(
					ITAKU_KAISHA_CD,		--委託会社コード
					MGR_CD,					--銘柄コード
					TSUKA_CD,				--通貨コード
					JTK_KBN,				--受託区分
					HOSEI_KIJUN_YM,			--補正基準年月
					TESU_SHURUI_CD,			--手数料種類コード
					MISHU_MAEUKE_KBN,		--未収前受区分
					CHOKYU_KJT,				--徴求期日
					CHOKYU_YMD,				--徴求日
					NYUKIN_YMD,				--入金日
					HAKKO_YMD,				--発行年月日
					FULLSHOKAN_KJT,			--満期償還期日
					KIJUN_YM_11_BF_GMATSU_ZNDK,	--基準年月の１１ヶ月前の月末残高
					KIJUN_YM_10_BF_GMATSU_ZNDK,	--基準年月の１０ヶ月前の月末残高
					KIJUN_YM_9_BF_GMATSU_ZNDK,	--基準年月の９ヶ月前の月末残高
					KIJUN_YM_8_BF_GMATSU_ZNDK,	--基準年月の８ヶ月前の月末残高
					KIJUN_YM_7_BF_GMATSU_ZNDK,	--基準年月の７ヶ月前の月末残高
					KIJUN_YM_6_BF_GMATSU_ZNDK,	--基準年月の６ヶ月前の月末残高
					KIJUN_YM_5_BF_GMATSU_ZNDK,	--基準年月の５ヶ月前の月末残高
					KIJUN_YM_4_BF_GMATSU_ZNDK,	--基準年月の４ヶ月前の月末残高
					KIJUN_YM_3_BF_GMATSU_ZNDK,	--基準年月の３ヶ月前の月末残高
					KIJUN_YM_2_BF_GMATSU_ZNDK,	--基準年月の２ヶ月前の月末残高
					KIJUN_YM_1_BF_GMATSU_ZNDK,	--基準年月の１ヶ月前の月末残高
					KIJUN_YM_GMATSU_ZNDK,	--基準年月の当月末残高
					KIJUN_ZNDK,				--基準残高
					TESU_RITSU_BUNBO,		--手数料率分母
					TESU_RITSU_BUNSHI,		--手数料率分子
					OWN_DF_BUNBO,			--自行分配率（分母）
					OWN_DF_BUNSHI,			--自行分配率（分子）
					TESU_NUKI_KNGK,			--手数料金額
					SZEI_KNGK,				--消費税金額
					HOSEI_BUNSHI_ST_YMD,	--補正期間分子開始日
					HOSEI_BUNSHI_ED_YMD,	--補正期間分子終了日
					HOSEI_BUNBO_ST_YMD,		--補正期間分母開始日
					HOSEI_BUNBO_ED_YMD,		--補正期間分母終了日
					HOSEI_TESU_NUKI_KNGK,	--補正手数料額（税抜）
					HOSEI_SZEI_KNGK,		--補正消費税額
					CALC_PATTERN_CD,		--計算パターン
					SAKUSEI_ID)				--作成者
				VALUES (
					l_inItakukaishaCd,
					recAfter.MGR_CD,
					recAfter.TSUKA_CD,
					recAfter.JTK_KBN,
					l_inKessanKijunYm,
					recAfter.TESU_SHURUI_CD,
					gMishuMaeukeKbn,
					recAfter.CHOKYU_KJT,
					recAfter.CHOKYU_YMD,
					coalesce(recAfter.NYUKIN_YMD,' '),
					recBefore.HAKKO_YMD,
					recBefore.FULLSHOKAN_KJT,
					gGetsumatsuZndk[12],
					gGetsumatsuZndk[11],
					gGetsumatsuZndk[10],
					gGetsumatsuZndk[9],
					gGetsumatsuZndk[8],
					gGetsumatsuZndk[7],
					gGetsumatsuZndk[6],
					gGetsumatsuZndk[5],
					gGetsumatsuZndk[4],
					gGetsumatsuZndk[3],
					gGetsumatsuZndk[2],
					gGetsumatsuZndk[1],
					recAfter.KIJUN_ZNDK,
					recAfter.TESU_RITSU_BUNBO,
					recAfter.TESU_RITSU_BUNSHI,
					recAfter.DF_BUNBO,
					gJikoBunpairitsuBunshi,
					gTesuryo,
					gShohizei,
					gHoseiKikanBunshiStart,
					gHoseiKikanBunshiEnd,
					recAfter.CALC_F_YMD,
					recAfter.CALC_T_YMD,
					gHoseiTesuryo,
					gHoseiShohizei,
					recBefore.CALC_PATTERN_CD,
					l_inUserId);
			END IF;
		END LOOP;
	END LOOP;

RETURN	greturnCd;

EXCEPTION
WHEN OTHERS THEN
	CALL pkLog.fatal('ECM701','pkIpaKessanHosei.calcHosei()', '未収前受データの登録に失敗しました');
	CALL pkLog.fatal('ECM701','pkIpaKessanHosei.calcHosei()', '【エラーメッセージ】'||SQLERRM);
	RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakessanhosei.calchosei ( l_inItakukaishaCd text, l_inKessanKijunYm text, l_inShiyoKyokumenKbn CHAR, l_inUserId text ) FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipakessanhosei.calchosei_deletemishumaeuke ( inItakukaishaCd MISYU_MAEUKE.ITAKU_KAISHA_CD%TYPE ) RETURNS numeric AS $body$
BEGIN

	--未収前受テーブルを削除する
	DELETE  FROM MISYU_MAEUKE T05
	WHERE   T05.ITAKU_KAISHA_CD = inItakukaishaCd;

RETURN pkconstant.success();

EXCEPTION
WHEN OTHERS THEN
	CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '【エラーメッセージ】'||SQLERRM);
RETURN
	pkconstant.error();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakessanhosei.calchosei_deletemishumaeuke ( inItakukaishaCd MISYU_MAEUKE.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipakessanhosei.calchosei_getjikobunpairitsu ( inItakuKaishaCd TESURYO.ITAKU_KAISHA_CD%TYPE, inMgrCd TESURYO.MGR_CD%TYPE, inTesuShuruiCd TESURYO.TESU_SHURUI_CD%TYPE, inChokyuKjt TESURYO.CHOKYU_KJT%TYPE ) RETURNS numeric AS $body$
DECLARE

	-- 変数定義 
	jikoBunpairitsuBunshi	numeric := 0;   -- 自行分配率（分子）
	counter					numeric := 0;   -- カウンター
	-- カーソル定義 
	curJikoTesuryo CURSOR FOR
		SELECT	T02.DF_BUNSHI	   AS DF_BUNSHI
		FROM	TESURYO_BUNPAI T02,
				VJIKO_ITAKU V01
		WHERE	T02.ITAKU_KAISHA_CD = inItakuKaishaCd
			AND	T02.MGR_CD = inMgrCd
			AND	T02.TESU_SHURUI_CD = inTesuShuruiCd
			AND	T02.CHOKYU_KJT = inChokyuKjt
			AND	T02.ITAKU_KAISHA_CD = V01.KAIIN_ID
			AND	T02.FINANCIAL_SECURITIES_KBN = V01.OWN_FINANCIAL_SECURITIES_KBN
			AND	T02.BANK_CD = V01.OWN_BANK_CD;

BEGIN
	-- 手数料計算結果分配テーブルより自行手数料を取得する
	FOR rec IN curJikoTesuryo
	LOOP
		-- カウンターを+1する
		counter := counter + 1;
		
		-- カーソルの件数が1件の場合
		IF counter = 1 THEN
			-- 自行手数料を取得する
			jikoBunpairitsuBunshi := rec.DF_BUNSHI;
		--カーソルの件数が0件or2件以上はありえないので異常終了
		ELSIF counter = 0 OR 1 < counter THEN
			RETURN pkconstant.fatal();
		END IF;
		
	END LOOP;

-- 手数料分配率（分子）をかえす
RETURN jikoBunpairitsuBunshi;

EXCEPTION
WHEN OTHERS THEN
	CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '手数料計算結果分配テーブルより自行手数料を取得するのに失敗しました');
	CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '【エラーメッセージ】'||SQLERRM);
RETURN
	pkconstant.error();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakessanhosei.calchosei_getjikobunpairitsu ( inItakuKaishaCd TESURYO.ITAKU_KAISHA_CD%TYPE, inMgrCd TESURYO.MGR_CD%TYPE, inTesuShuruiCd TESURYO.TESU_SHURUI_CD%TYPE, inChokyuKjt TESURYO.CHOKYU_KJT%TYPE ) FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipakessanhosei.calchosei_hoseitesuryo ( inDataSakuseiKbn TESURYO.DATA_SAKUSEI_KBN%TYPE, inShoriKbn TESURYO.SHORI_KBN%TYPE, inJikoTesuryo TESURYO.OWN_TESU_KNGK%TYPE, inHoseiJikoTesuryo TESURYO.HOSEI_OWN_TESU_KNGK%TYPE, inJikoShohizei TESURYO.OWN_TESU_SZEI%TYPE, inHoseiJikoShohizei TESURYO.HOSEI_OWN_TESU_SZEI%TYPE, inTukaCd TESURYO.TSUKA_CD%TYPE, inHoseiNissuBunshi numeric, inHoseiNissuBunbo numeric, outTesuryo OUT MISYU_MAEUKE.TESU_NUKI_KNGK%TYPE, outShohizei OUT MISYU_MAEUKE.SZEI_KNGK%TYPE, outHoseiTesuryo OUT MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK%TYPE, outHoseiShohizei OUT MISYU_MAEUKE.HOSEI_SZEI_KNGK%TYPE , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

	-- 変数定義 
	kirisuteFlg	 numeric := 0;	--切捨てフラグ
BEGIN

	--切捨てフラグをセットする
	IF inTukaCd = 'JPY' THEN
		kirisuteFlg := 0;
	ELSE
		kirisuteFlg := 2;
	END IF;

	-- 自行手数料（税抜）、自行消費税をセットする
	--データ作成区分「2：補正」かつ処理区分「1：承認済」の場合
	IF inDataSakuseiKbn = '2' AND inShoriKbn = '1' THEN
		outTesuryo	:=	inJikoTesuryo + inHoseiJikoTesuryo;
		outShohizei	:=	inJikoShohizei + inHoseiJikoShohizei;
	ELSE
		outTesuryo	:=	inJikoTesuryo;
		outShohizei	:=	inJikoShohizei;
	END IF;

	--補正手数料を算出する
	outHoseiTesuryo := TRUNC((outTesuryo * inHoseiNissuBunshi / inHoseiNissuBunbo)::numeric, kirisuteFlg::int);
	--補正消費税を算出する
	outHoseiShohizei := TRUNC((outShohizei * inHoseiNissuBunshi / inHoseiNissuBunbo)::numeric, kirisuteFlg::int);

--すべての処理に成功した場合
extra_param := pkconstant.success();
RETURN;

EXCEPTION
WHEN OTHERS THEN
	CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '【エラーメッセージ】'||SQLERRM);
extra_param := pkconstant.error();
RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakessanhosei.calchosei_hoseitesuryo ( inDataSakuseiKbn TESURYO.DATA_SAKUSEI_KBN%TYPE, inShoriKbn TESURYO.SHORI_KBN%TYPE, inJikoTesuryo TESURYO.OWN_TESU_KNGK%TYPE, inHoseiJikoTesuryo TESURYO.HOSEI_OWN_TESU_KNGK%TYPE, inJikoShohizei TESURYO.OWN_TESU_SZEI%TYPE, inHoseiJikoShohizei TESURYO.HOSEI_OWN_TESU_SZEI%TYPE, inTukaCd TESURYO.TSUKA_CD%TYPE, inHoseiNissuBunshi numeric, inHoseiNissuBunbo numeric, outTesuryo OUT MISYU_MAEUKE.TESU_NUKI_KNGK%TYPE, outShohizei OUT MISYU_MAEUKE.SZEI_KNGK%TYPE, outHoseiTesuryo OUT MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK%TYPE, outHoseiShohizei OUT MISYU_MAEUKE.HOSEI_SZEI_KNGK%TYPE , OUT extra_param numeric) FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipakessanhosei.calchosei_getmishucalcpatternflg ( l_inItakukaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inHktCd MGR_KIHON.HKT_CD%TYPE ) RETURNS char AS $body$
DECLARE

	result CHAR(1) := '0';

BEGIN
	-- Column MISHU_CALC_PATTERN_FLG does not exist in MHAKKOTAI2 table
	-- Always return default value '0'
	/*
	SELECT
		MISHU_CALC_PATTERN_FLG
	INTO STRICT
		result
	FROM
		MHAKKOTAI2
	WHERE
		ITAKU_KAISHA_CD = l_inItakukaishaCd
	AND HKT_CD          = l_inHktCd;
	*/
	
	RETURN result;
	
EXCEPTION
	WHEN no_data_found THEN
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakessanhosei.calchosei_getmishucalcpatternflg ( l_inItakukaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inHktCd MGR_KIHON.HKT_CD%TYPE ) FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipakessanhosei.calchosei_calcmisyuteigakutesuryo ( l_inWakachiFlg CHAR, l_inTsukisu numeric, l_inTsukisuBefore numeric, l_inTsukisuAfter numeric, l_inKirisuteFlg CHAR, l_inShohiZeiBefore numeric, l_inShohiZeiAfter numeric, l_inTeigakuTesuKngk numeric, l_inNenchokyuCnt CHAR, l_outHoseiTesuryo OUT MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK%TYPE, l_outHoseiShohizei OUT MISYU_MAEUKE.HOSEI_SZEI_KNGK%TYPE , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

	--** 変数定義 **
	gMisyuTeigakuBefore numeric;  -- 未収定額手数料（税抜）（消費税改定前）
	gMisyuTeigakuAfter  numeric;  -- 未収定額手数料（税抜）（消費税改定後）
BEGIN
	
	-- 分かち計算する場合
	IF l_inWakachiFlg = '1' THEN
	
		-- 未収定額手数料（税抜）（消費税改定前）
		gMisyuTeigakuBefore := TRUNC((l_inTeigakuTesuKngk * l_inNenchokyuCnt / 12 * l_inTsukisuBefore)::numeric, l_inKirisuteFlg::int);
		-- 未収定額手数料（税抜）（消費税改定後）
		gMisyuTeigakuAfter  := TRUNC((l_inTeigakuTesuKngk * l_inNenchokyuCnt / 12 * l_inTsukisuAfter)::numeric, l_inKirisuteFlg::int);
		
		-- 未収定額手数料（税抜）
		l_outHoseiTesuryo  := gMisyuTeigakuBefore + gMisyuTeigakuAfter;
		-- 未収定額手数料（消費税）
		l_outHoseiShohizei := TRUNC((gMisyuTeigakuBefore * l_inShohiZeiBefore)::numeric, l_inKirisuteFlg::int)
		                      + TRUNC((gMisyuTeigakuAfter * l_inShohiZeiAfter)::numeric, l_inKirisuteFlg::int);
		
	-- 分かち計算しない場合
	ELSE
		
		-- 未収定額手数料（税抜）
		l_outHoseiTesuryo  := TRUNC((l_inTeigakuTesuKngk * l_inNenchokyuCnt / 12 * l_inTsukisu)::numeric, l_inKirisuteFlg::int);
		-- 未収定額手数料（消費税）
		l_outHoseiShohizei := TRUNC((l_outHoseiTesuryo * l_inShohiZeiAfter)::numeric, l_inKirisuteFlg::int);
		
	END IF;

extra_param := pkconstant.success();

RETURN;

EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.error('ECM701','pkIpaKessanHosei.calcHosei()', '【エラーメッセージ】'||SQLERRM);
		extra_param := pkconstant.error();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakessanhosei.calchosei_calcmisyuteigakutesuryo ( l_inWakachiFlg CHAR, l_inTsukisu numeric, l_inTsukisuBefore numeric, l_inTsukisuAfter numeric, l_inKirisuteFlg CHAR, l_inShohiZeiBefore numeric, l_inShohiZeiAfter numeric, l_inTeigakuTesuKngk numeric, l_inNenchokyuCnt CHAR, l_outHoseiTesuryo OUT MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK%TYPE, l_outHoseiShohizei OUT MISYU_MAEUKE.HOSEI_SZEI_KNGK%TYPE , OUT extra_param numeric) FROM PUBLIC;
-- End of Oracle package 'pkipakessanhosei' declaration
