




CREATE OR REPLACE PROCEDURE spipx025k00r03 ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inKijunYm TEXT,                               -- 基準年月
 l_inHktCd MHAKKOTAI.HKT_CD%TYPE,              -- 発行体コード
 l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE,         -- 口座店コード
 l_inZeimushoCd MZEIMUSHO.ZEIMUSHO_CD%TYPE,         -- 税務署コード
 l_inSdFlg MITAKU_KAISHA2.SD_FLG%TYPE,         -- SDフラグ
 l_inNouzeiFlg text,                            -- 納税有フラグ
 l_inChohyoKbn text,                            -- 帳票区分
 l_inUserId SUSER.USER_ID%TYPE,                 -- ユーザーID
 l_inGyomuYmd TEXT,                               -- 業務日付
 l_outSqlCode OUT integer,                            -- リターン値
 l_outSqlErrM OUT text                           -- エラーコメント
 ) AS $body$
DECLARE

	--
--	 * 著作権:Copyright(c)2016
--	 * 会社名:JIP
--	 * 概要　:利金に係る国税の納税事務を支援するための帳票データを作成する。
--	 *
--	 * 引数　:
--	 *	  @param l_inItakuKaishaCd IN MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
--	 *	  @param l_inKijunYm       IN TEXT,                               -- 基準年月
--	 *	  @param l_inHktCd         IN MHAKKOTAI.HKT_CD%TYPE,              -- 発行体コード
--	 *	  @param l_inKozaTenCd     IN MHAKKOTAI.KOZA_TEN_CD%TYPE,         -- 口座店コード
--	 *	  @param l_inZeimushoCd    IN MZEIMUSHO.ZEIMUSHO_CD%TYPE,         -- 税務署コード
--	 *	  @param l_inSdFlg         IN MITAKU_KAISHA2.SD_FLG%TYPE,         -- SDフラグ
--	 *	  @param l_inNouzeiFlg     IN VARCHAR,                            -- 納税有フラグ
--	 *	  @param l_inChohyoKbn     IN VARCHAR,                            -- 帳票区分
--	 *	  @param l_inUserId	  IN SUSER.USER_ID%TYPE,                 -- ユーザーID
--	 *	  @param l_inGyomuYmd	  IN TEXT,                               -- 業務日付
--	 *	  @param l_outSqlCode	  OUT NUMERIC,                            -- リターン値
--	 *	  @param l_outSqlErrM	  OUT VARCHAR                           -- エラーコメント
--	 *
--	 * 返り値:なし
--	 *
--	 * @author Y.Yamada
--	 * @version $Id: SPIPX025K00R03.sql,v 1.00 2016/12/06 16:07:10 Y.Yamada Exp $
--	 
	 
--==============================================================================
--                定数定義                                                      
--==============================================================================
	C_PROCEDURE_ID  CONSTANT varchar(50) := 'SPIPX025K00R03';	-- プロシージャＩＤ
	C_REPORT_ID     CONSTANT varchar(50) := 'IPX30002531';		-- 納税資料
--==============================================================================
--                変数定義                                                      
--==============================================================================
	gSeqNo		integer := 0;				 -- カウンター
	gRtnCd 		integer := pkconstant.success(); 		 -- リターンコード
	gZeimushoCd     MZEIMUSHO.ZEIMUSHO_CD%TYPE := NULL;         -- 税務署コード
	gHktCd          MHAKKOTAI.HKT_CD%TYPE := NULL;              -- 発行体コード
	gKozaTenCd	MHAKKOTAI.KOZA_TEN_CD%TYPE := NULL;         -- 口座店コード
	gNouzeiFlg      varchar(1) := NULL;                         -- 納税有フラグ
	gItakuKaishaCd  MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;              -- 委託会社コード
	gItakuKaishaRnm  SOWN_INFO.BANK_RNM%TYPE;                        -- 委託会社略名
	gTSUKA_FORMAT	varchar(21) := NULL;		         -- 通貨フォーマット
	gMainSeqNo	integer := 0;				 -- メインカウンター
  
  --税区分取得用変数
	gRet			     numeric       := 0;
 	gTaxNm         MTAX.TAX_NM%TYPE := NULL;
 	gTaxRnm        MTAX.TAX_RNM%TYPE := NULL;
	gChihoZeiRate  MTAX.CHIHO_ZEI_RATE%TYPE  := 0;
	gTempKokuZeiRate MTAX.KOKU_ZEI_RATE%TYPE; -- Temp variable for array assignment
  --配列定義
	gTaxKbn MTAX.TAX_KBN%TYPE[] := ARRAY['10','20','30','31','32','40','60','70','71','72','73','74','75','80','81','92','93'];
	gKokuZeiRate MTAX.KOKU_ZEI_RATE%TYPE[];
	v_item             TYPE_SREPORT_WK_ITEM; -- アイテム用composite type
--==============================================================================
--                    カーソル定義                                              
--==============================================================================
	curMeisai CURSOR FOR
	SELECT
		MAIN_K01.ITAKU_KAISHA_CD, --委託会社コード
        CASE
            WHEN MAIN_K01.GZEI_KNGK_SUM > 0 THEN
             '*'
            ELSE
             ' '
        END AS NOZEI_YOU_HUYOU, --国税金額の合計（納税用不要）
		MAIN_K01.ZEIMUSHO_NM, --税務署名称
		MAIN_K01.SHOKATSU_ZEIMUSHO_CD, --税務署番号
		MAIN_K01.SEIRI_NO, --整理番号
		MAIN_K01.TSUKA_CD, --通貨コード
		M64.TSUKA_NM, --通貨出力用名称
		CASE WHEN MAIN_K01.TSUKA_CNT  = 1 THEN
			CASE WHEN MAIN_K01.TSUKA_CD = 'JPY' THEN
				'合計'
		     	ELSE
				'明細'
			END 			
		ELSE
			'明細'
		END TSUKA_CD_TYTLE, --通貨コード(タイトル)
		MAIN_K01.HKT_CD, --発行体コード
		BT01.HKT_NM_GTAX AS HKT_NM, --発行体名称
		MAIN_K01.KOZA_TEN_CD, --口座店コード
		MAIN_K01.KOZA_TEN_CIFCD, --口座店CIFコード
		MAIN_K01.TOKIJO_POST_NO, --郵便番号
		MAIN_K01.TOKIJO_ADD1, --送付先住所1
		MAIN_K01.TOKIJO_ADD2, --送付先住所2
		MAIN_K01.TOKIJO_ADD3, --送付先住所3
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK31, --非課税信託財産（投資信託）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK32, --非課税信託財産（年金信託）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK40, --非課税信託財産（マル優）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK60, --財形貯蓄非課税 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK93, --マル優（分かち）非課税分 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK30, --非課税法人 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK10, --分離課税 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK20, --総合課税 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK92, --マル優（分かち）分離課税区分 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK70, --非住居者（0％）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK71, --非住居者（10％）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK72, --非住居者（12％）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK73, --非住居者（12.5％）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK74, --非住居者（15％）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK75, --非住居者（25％）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK80, --非住居者非課税制度対象分非課税（発行者源泉徴収分）利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK90, --非住居者課税分 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK91, --非住居者非課税分 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK85, --口座管理機関源泉徴収分 利金
		MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK81, --非住居者非課税制度対象分非課税（口座管理機関源泉徴収分）利金
		MAIN_K01.GZEI_KNGK10, --分離課税 税額
		MAIN_K01.GZEI_KNGK20, --総合課税 税額
		MAIN_K01.GZEI_KNGK92, --マル優（分かち）分離課税区分 税額
		MAIN_K01.GZEI_KNGK71, --非住居者（10％）税額
		MAIN_K01.GZEI_KNGK72, --非住居者（12％）税額
		MAIN_K01.GZEI_KNGK73, --非住居者（12.5％）税額
		MAIN_K01.GZEI_KNGK74, --非住居者（15％）税額
		MAIN_K01.GZEI_KNGK75, --非住居者（25％）税額
		MAIN_K01.GZEI_KNGK90, --非住居者課税分 税額
		MAIN_K01.KKN_NYUKIN_KNGK - MAIN_K01.GZEIHIKI_BEF_CHOKYU_KNGK_SUM AS HASUU_MIBARAI
	FROM mtsuka m64, (SELECT
			SUB_K01.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, --委託会社コード
			M41.ZEIMUSHO_NM, --税務署名称
			M01.SHOKATSU_ZEIMUSHO_CD, --税務署番号
			M01.SEIRI_NO, --整理番号
			SUB_K01.TSUKA_CD, --通貨コード
			FIRST_VALUE(SUB_K01.TSUKA_CD) OVER (PARTITION BY SUB_K01.ITAKU_KAISHA_CD, M01.HKT_CD ORDER BY SUB_K01.ITAKU_KAISHA_CD, M01.HKT_CD) AS TSUKA_CNT, --委託会社・発行体毎の通貨コード件数
			M01.HKT_CD, --発行体コード
			M01.KOZA_TEN_CD, --口座店コード
			M01.KOZA_TEN_CIFCD, --口座店CIFコード
			M01.TOKIJO_POST_NO, --郵便番号
			M01.TOKIJO_ADD1, --送付先住所1
			M01.TOKIJO_ADD2, --送付先住所2
			M01.TOKIJO_ADD3, --送付先住所3
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK31, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK31, --非課税信託財産（投資信託）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK32, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK32, --非課税信託財産（年金信託）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK40, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK40, --非課税信託財産（マル優）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK60, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK60, --財形貯蓄非課税 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK93, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK93, --マル優（分かち）非課税分 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK30, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK30, --非課税法人 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK10, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK10, --分離課税 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK20, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK20, --総合課税 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK92, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK92, --マル優（分かち）分離課税区分 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK70, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK70, --非住居者（0％）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK71, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK71, --非住居者（10％）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK72, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK72, --非住居者（12％）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK73, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK73, --非住居者（12.5％）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK74, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK74, --非住居者（15％）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK75, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK75, --非住居者（25％）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK80, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK80, --非住居者非課税制度対象分非課税（発行者源泉徴収分）利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK90, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK90, --非住居者課税分 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK91, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK91, --非住居者非課税分 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK85, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK85, --口座管理機関源泉徴収分 利金
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK81, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK81, --非住居者非課税制度対象分非課税（口座管理機関源泉徴収分）利金
			SUM(coalesce(SUB_K01.GZEI_KNGK10, 0)) AS GZEI_KNGK10, --分離課税 税額
			SUM(coalesce(SUB_K01.GZEI_KNGK20, 0)) AS GZEI_KNGK20, --総合課税 税額
			SUM(coalesce(SUB_K01.GZEI_KNGK92, 0)) AS GZEI_KNGK92, --マル優（分かち）分離課税区分 税額
			SUM(coalesce(SUB_K01.GZEI_KNGK71, 0)) AS GZEI_KNGK71, --非住居者（10％）税額
			SUM(coalesce(SUB_K01.GZEI_KNGK72, 0)) AS GZEI_KNGK72, --非住居者（12％）税額
			SUM(coalesce(SUB_K01.GZEI_KNGK73, 0)) AS GZEI_KNGK73, --非住居者（12.5％）税額
			SUM(coalesce(SUB_K01.GZEI_KNGK74, 0)) AS GZEI_KNGK74, --非住居者（15％）税額
			SUM(coalesce(SUB_K01.GZEI_KNGK75, 0)) AS GZEI_KNGK75, --非住居者（25％）税額
			SUM(coalesce(SUB_k01.GZEI_KNGK90, 0)) AS GZEI_KNGK90,  --非住居者課税分 税額
			SUM(coalesce(SUB_K01.GZEIHIKI_BEF_CHOKYU_KNGK_SUM, 0)) AS GZEIHIKI_BEF_CHOKYU_KNGK_SUM,  --支払金額の合計（端数未払金の計算用）
			SUM(coalesce(SUB_K01.GZEI_KNGK, 0)) AS GZEI_KNGK_SUM,  --国税額の合計（納税有無判定用）
			SUM(coalesce(K02.KKN_NYUKIN_KNGK,0)) AS KKN_NYUKIN_KNGK
			FROM mgr_kihon mg1, (SELECT
					K01.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,
					k01.MGR_CD AS MGR_CD,
					k01.SHR_YMD AS SHR_YMD,
					K01.TSUKA_CD AS TSUKA_CD,
					SUM(K01.GZEIHIKI_BEF_CHOKYU_KNGK) AS GZEIHIKI_BEF_CHOKYU_KNGK_SUM,   --支払金額の合計（端数未払金の計算用）
					SUM(k01.GZEI_KNGK) AS GZEI_KNGK,
					SUM(CASE WHEN K01.TAX_KBN='31' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK31,
					SUM(CASE WHEN K01.TAX_KBN='32' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK32,
					SUM(CASE WHEN K01.TAX_KBN='40' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK40,
					SUM(CASE WHEN K01.TAX_KBN='60' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK60,
					SUM(CASE WHEN K01.TAX_KBN='93' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK93,
					SUM(CASE WHEN K01.TAX_KBN='30' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK30,
					SUM(CASE WHEN K01.TAX_KBN='10' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK10,
					SUM(CASE WHEN K01.TAX_KBN='10' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK10,
					SUM(CASE WHEN K01.TAX_KBN='20' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK20,
					SUM(CASE WHEN K01.TAX_KBN='20' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK20,
					SUM(CASE WHEN K01.TAX_KBN='92' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK92,
					SUM(CASE WHEN K01.TAX_KBN='92' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK92,
					SUM(CASE WHEN K01.TAX_KBN='70' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK70,
					SUM(CASE WHEN K01.TAX_KBN='71' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK71,
					SUM(CASE WHEN K01.TAX_KBN='71' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK71,
					SUM(CASE WHEN K01.TAX_KBN='72' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK72,
					SUM(CASE WHEN K01.TAX_KBN='72' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK72,
					SUM(CASE WHEN K01.TAX_KBN='73' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK73,
					SUM(CASE WHEN K01.TAX_KBN='73' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK73,
					SUM(CASE WHEN K01.TAX_KBN='74' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK74,
					SUM(CASE WHEN K01.TAX_KBN='74' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK74,
					SUM(CASE WHEN K01.TAX_KBN='75' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK75,
					SUM(CASE WHEN K01.TAX_KBN='75' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK75,
					SUM(CASE WHEN K01.TAX_KBN='80' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK80,
					SUM(CASE WHEN K01.TAX_KBN='90' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK90,
					SUM(CASE WHEN K01.TAX_KBN='90' THEN  K01.GZEI_KNGK  ELSE 0 END ) AS GZEI_KNGK90,
					SUM(CASE WHEN K01.TAX_KBN='91' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK91,
					SUM(CASE WHEN K01.TAX_KBN='85' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK85,
					SUM(CASE WHEN K01.TAX_KBN='81' THEN  K01.GZEIHIKI_BEF_CHOKYU_KNGK  ELSE 0 END ) AS GZEIHIKI_BEF_CHOKYU_KNGK81
				FROM
					KIKIN_SEIKYU K01,
					 MGR_STS MG0
				WHERE
					K01.ITAKU_KAISHA_CD = gItakuKaishaCd
					AND	SUBSTR(K01.SHR_YMD, 1, 6) = l_inKijunYm
					AND (
							K01.KK_KANYO_UMU_FLG = '1'
								OR (K01.KK_KANYO_UMU_FLG != '1'
							 AND	K01.SHORI_KBN = '1')
						)
					AND K01.TAX_KBN <> '00' 
					AND K01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
					AND K01.MGR_CD = MG0.MGR_CD
					AND MG0.MASSHO_FLG = '0' 
					AND MG0.MGR_STAT_KBN  = '1'  
				GROUP BY
					K01.ITAKU_KAISHA_CD,
					k01.MGR_CD,
					k01.SHR_YMD,
					K01.TSUKA_CD
				) sub_k01
LEFT OUTER JOIN kikin_ido k02 ON (SUB_K01.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD AND SUB_K01.MGR_CD = K02.MGR_CD AND SUB_K01.TSUKA_CD = K02.TSUKA_CD AND SUB_K01.SHR_YMD = K02.RBR_YMD AND SUB_K01.TSUKA_CD = K02.TSUKA_CD AND '21' = K02.KKN_IDO_KBN AND '1' >= K02.DATA_SAKUSEI_KBN)
, mhakkotai m01
LEFT OUTER JOIN mzeimusho m41 ON (M01.SHOKATSU_ZEIMUSHO_CD = M41.ZEIMUSHO_CD)
WHERE SUB_K01.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND SUB_K01.MGR_CD = MG1.MGR_CD AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD       -- 入金（利払）
  -- 請求書出力済
  AND (CASE WHEN  coalesce(l_inHktCd::text, '') = '' THEN
					      gHktCd
					   ELSE MG1.HKT_CD
					 END) = gHktCd AND (CASE WHEN  coalesce(l_inKozaTenCd::text, '') = '' THEN
						      gKozaTenCd
						ELSE M01.KOZA_TEN_CD
					 END) = gKozaTenCd AND (CASE WHEN coalesce(l_inZeimushoCd::text, '') = '' THEN
						     gZeimushoCd
						ELSE M41.ZEIMUSHO_CD
					 END) = gZeimushoCd  GROUP BY
				SUB_K01.ITAKU_KAISHA_CD, --委託会社コード
				M41.ZEIMUSHO_NM, --税務署名称
				M01.SHOKATSU_ZEIMUSHO_CD, --税務署番号
				M01.SEIRI_NO, --整理番号
				SUB_K01.TSUKA_CD, --通貨コード
				M01.HKT_CD, --発行体コード
				M01.KOZA_TEN_CD, --口座店コード
				M01.KOZA_TEN_CIFCD, --口座店CIFコード
				M01.TOKIJO_POST_NO, --郵便番号
				M01.TOKIJO_ADD1, --送付先住所1
				M01.TOKIJO_ADD2, --送付先住所2
				M01.TOKIJO_ADD3 --送付先住所3
		) main_k01
LEFT OUTER JOIN mhakkotai2 bt01 ON (MAIN_K01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND MAIN_K01.HKT_CD = BT01.HKT_CD)
WHERE MAIN_K01.TSUKA_CD = M64.TSUKA_CD   AND (CASE
				WHEN coalesce(l_inNouzeiFlg::text, '') = '' THEN
					gNouzeiFlg
				ELSE
					CASE	WHEN MAIN_K01.GZEI_KNGK_SUM > 0 THEN
						'*'
					ELSE
						' '
					END
			 END
		) = gNouzeiFlg ORDER BY
		MAIN_K01.ITAKU_KAISHA_CD,
		NOZEI_YOU_HUYOU DESC,
		MAIN_K01.KOZA_TEN_CD,
		MAIN_K01.KOZA_TEN_CIFCD,
		MAIN_K01.TSUKA_CD;
	--------------------------------------------------------------------------------
	-- 委託会社コードの取得カーソル
	--------------------------------------------------------------------------------
	curItakuKaisha CURSOR FOR
	SELECT	V01.KAIIN_ID,
			CASE WHEN V01.JIKO_DAIKO_KBN='1' THEN  ' '  ELSE V01.BANK_RNM END  AS BANK_RNM
	FROM vjiko_itaku v01
LEFT OUTER JOIN mitaku_kaisha2 bt02 ON (V01.KAIIN_ID = BT02.ITAKU_KAISHA_CD)
WHERE V01.KAIIN_ID =
				CASE WHEN l_inItakuKaishaCd=pkconstant.DAIKO_KEY_CD() THEN  V01.KAIIN_ID  ELSE l_inItakuKaishaCd END AND V01.JIKO_DAIKO_KBN = 
				CASE WHEN l_inItakuKaishaCd=pkconstant.DAIKO_KEY_CD() THEN  '2'  ELSE V01.JIKO_DAIKO_KBN END --代行一括出力の場合、自行は除外する。
  AND V01.DAIKO_FLG = 
				CASE WHEN l_inItakuKaishaCd=pkconstant.DAIKO_KEY_CD() THEN  '1'  ELSE V01.DAIKO_FLG END --代行一括出力の場合、事務代行利用ありのユーザーのみを取得（「他金融機関」を除外する）
  AND (coalesce(l_inSdFlg::text, '') = ''
				OR BT02.SD_FLG = l_inSdFlg) --代行一括出力で、SDフラグを選択した場合は、SDフラグが同じ委託会社のみを選択する
 ORDER BY KAIIN_ID;
--==============================================================================
--                メイン処理                                                       
--==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR coalesce(trim(both l_inKijunYm)::text, '') = '' OR coalesce(trim(both l_inUserId)::text, '') = '' OR
	   coalesce(trim(both l_inGyomuYmd)::text, '') = '' OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''  THEN
		-- パラメータエラー
		CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	--入力パラメータ税務署コード設定
	IF coalesce(l_inZeimushoCd::text, '') = '' THEN
		gZeimushoCd := '';
	ELSE
		gZeimushoCd := l_inZeimushoCd;	
	END IF;
	--入力パラメータ発行体コード設定
	IF coalesce(l_inHktCd::text, '') = '' THEN
		gHktCd := '';
	ELSE
		gHktCd := l_inHktCd;	
	END IF;
	--入力パラメータ口座店店番設定
	IF coalesce(l_inKozaTenCd::text, '') = '' THEN
		gKozaTenCd := '';
	ELSE
		gKozaTenCd := l_inKozaTenCd;	
	END IF;
	--入力パラメータ納税有フラグ設定
	IF (l_inNouzeiFlg IS NOT NULL AND l_inNouzeiFlg::text <> '') THEN
		IF l_inNouzeiFlg = '0' THEN
			gNouzeiFlg := ' ';
		ELSE
			gNouzeiFlg := '*';
		END IF;
	ELSE
		gNouzeiFlg := ' ';	
	END IF;
	-- 国税率の設定
	FOR cnt IN 1..coalesce(cardinality(gTaxKbn), 0) LOOP
		gKokuZeiRate := array_append(gKokuZeiRate, null);
		SELECT l_outtaxnm, l_outtaxrnm, l_outkokuzeirate, l_outchihozeirate 
			INTO gTaxNm, gTaxRnm, gTempKokuZeiRate, gChihoZeiRate 
			FROM pkIpaZei.getMTax(
					gTaxKbn[cnt],
					l_inKijunYm || '01'
					);
		gKokuZeiRate[cnt] := gTempKokuZeiRate;
	END LOOP;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = C_REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd,
			     l_inUserId,
			     l_inChohyoKbn,
			     l_inGyomuYmd,
			     C_REPORT_ID);
	-- データ登録処理
	FOR recItakuKaisha IN curItakuKaisha LOOP
		--委託会社コードのセット
		gItakuKaishaCd := recItakuKaisha.KAIIN_ID;
		-- 委託会社略名取得
		gItakuKaishaRnm := recItakuKaisha.BANK_RNM;
		gSeqNo := 0;
		gMainSeqNo := gMainSeqNo + 1;
		FOR recMeisai IN curMeisai LOOP
			-- シーケンスナンバーをカウントアップしておく
			gSeqNo := gSeqNo + 1;
			-- 書式フォーマット、通貨コードの設定
			IF recMeisai.TSUKA_CD = 'JPY' THEN
				gTSUKA_FORMAT := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';
			ELSE
				gTSUKA_FORMAT := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';
			END IF;
			-- 帳票ワークへデータを追加
			CALL pkPrint.insertData(l_inKeyCd      => l_inItakuKaishaCd 		  -- 識別コード
				  ,l_inUserId     => l_inUserId 				  -- ユーザＩＤ
				  ,l_inChohyoKbn  => l_inChohyoKbn 			  -- 帳票区分
				  ,l_inSakuseiYmd => l_inGyomuYmd 			  -- 作成年月日
				  ,l_inChohyoId   => C_REPORT_ID 			  -- 帳票ＩＤ
				  ,l_inSeqNo      => gMainSeqNo 				  -- 連番
				  ,l_inHeaderFlg  => '1'			          -- ヘッダフラグ
				  ,l_inItem001    => gItakuKaishaRnm 		          -- 委託会社略称
				  ,l_inItem002    => l_inKijunYm 		              -- 基準年月
				  ,l_inItem003    => recMeisai.NOZEI_YOU_HUYOU 		  -- 納税要不要
				  ,l_inItem004    => recMeisai.ITAKU_KAISHA_CD 	 	  -- 委託会社コード
				  ,l_inItem005    => recMeisai.HKT_CD 		          -- 発行体コード(改ページキー)
				  ,l_inItem006    => recMeisai.ZEIMUSHO_NM 		  -- 所轄税務署
				  ,l_inItem007    => recMeisai.SHOKATSU_ZEIMUSHO_CD 	  -- 税務署番号
				  ,l_inItem008    => recMeisai.SEIRI_NO 		          -- 整理番号
				  ,l_inItem009    => recMeisai.TSUKA_CD 		          -- 通貨コード(改ページキー)
				  ,l_inItem010    => recMeisai.TSUKA_CD_TYTLE 		  -- 通貨コード（タイトル）
				  ,l_inItem011    => recMeisai.HKT_NM 		          -- 発行体名称上段
				  ,l_inItem012    => gKokuZeiRate[4]		          -- 税率31:非課税信託財産（投資信託）税率
				  ,l_inItem013    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK31 -- 支払金額31
				  ,l_inItem014    => recMeisai.HKT_NM 		          -- 発行体名称下段	
				  ,l_inItem015    => gKokuZeiRate[5]		          -- 税率32:非課税信託財産（年金信託）税率
				  ,l_inItem016    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK32 -- 支払金額32
				  ,l_inItem017    => recMeisai.KOZA_TEN_CD 		  -- 口座店コード
				  ,l_inItem018    => recMeisai.KOZA_TEN_CIFCD 		  -- 口座店CIFコード
				  ,l_inItem019    => gKokuZeiRate[6]		          -- 税率40:非課税信託財産（マル優）税率
				  ,l_inItem020    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK40 -- 支払金額40	
				  ,l_inItem021    => gTSUKA_FORMAT
				  ,l_inItem022    => gKokuZeiRate[7]		                  -- 税率60:財形貯蓄非課税 税率
				  ,l_inItem023    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK60 -- 支払金額60	
				  ,l_inItem024    => recMeisai.TOKIJO_POST_NO 		  -- 送付先郵便番号
				  ,l_inItem025    => gKokuZeiRate[17]		          -- 税率93:マル優（分かち）非課税分 税率
				  ,l_inItem026    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK93 -- 支払金額93	
				  ,l_inItem027    => recMeisai.TOKIJO_ADD1		  -- 送付先住所１
				  ,l_inItem028    => recMeisai.TOKIJO_ADD2		  -- 送付先住所２
				  ,l_inItem029    => recMeisai.TOKIJO_ADD3		  -- 送付先住所３
				  ,l_inItem030    => gKokuZeiRate[3]		        -- 税率30:非課税法人 税率
				  ,l_inItem031    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK30 -- 支払金額30	
				  ,l_inItem032    => gKokuZeiRate[1]		                  -- 税率10:分離課税 税率
				  ,l_inItem033    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK10 -- 支払金額10	
				  ,l_inItem034    => recMeisai.GZEI_KNGK10                --税額10
				  ,l_inItem035    => gKokuZeiRate[2]		                  -- 税率20:総合課税 税率
				  ,l_inItem036    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK20-- 支払金額20	
				  ,l_inItem037    => recMeisai.GZEI_KNGK20                --税額20
				  ,l_inItem038    => gKokuZeiRate[16]		                  -- 税率92:マル優（分かち）分離課税区分 税率
				  ,l_inItem039    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK92 -- 支払金額92	
				  ,l_inItem040    => recMeisai.GZEI_KNGK92                --税額92
				  ,l_inItem041    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK20 -- 支払金額20
				  ,l_inItem042    => recMeisai.GZEI_KNGK20                --税額20
				  ,l_inItem043    => gKokuZeiRate[8]		                  -- 税率70:非住居者（0％）税率
				  ,l_inItem044    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK70 -- 支払金額70	
				  ,l_inItem045    => gKokuZeiRate[9]		                  -- 税率71:非住居者（10％）税率
				  ,l_inItem046    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK71 -- 支払金額71	
				  ,l_inItem047    => recMeisai.GZEI_KNGK71                --税額71
				  ,l_inItem048    => gKokuZeiRate[10]		                  -- 税率72:非住居者（12％）税率
				  ,l_inItem049    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK72 -- 支払金額72	
				  ,l_inItem050    => recMeisai.GZEI_KNGK72                --税額72
				  ,l_inItem051    => gKokuZeiRate[11]		                  -- 税率73:非住居者（12.5％）税率
				  ,l_inItem052    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK73 -- 支払金額73	
				  ,l_inItem053    => recMeisai.GZEI_KNGK73                --税額73
				  ,l_inItem054    => gKokuZeiRate[12]		                  -- 税率74:非住居者（15％）税率
				  ,l_inItem055    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK74 -- 支払金額74	
				  ,l_inItem056    => recMeisai.GZEI_KNGK74                --税額74
				  ,l_inItem057    => gKokuZeiRate[13]		                  -- 税率75:非住居者（25％）税率
				  ,l_inItem058    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK75 -- 支払金額75	
				  ,l_inItem059    => recMeisai.GZEI_KNGK75                --税額75
				  ,l_inItem060    => gKokuZeiRate[14]		                  -- 税率80:非住居者非課税制度対象分非課税（発行者源泉徴収分）税率
				  ,l_inItem061    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK80 -- 支払金額80	
				  ,l_inItem062    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK90 -- 支払金額90	
				  ,l_inItem063    => recMeisai.GZEI_KNGK90                --税額90
				  ,l_inItem064    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK91 -- 支払金額91
				  ,l_inItem065    => recMeisai.HASUU_MIBARAI            -- 端数未払金
				  ,l_inItem066    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK85 -- 支払金額85
				  ,l_inItem067    => gKokuZeiRate[15]		                  -- 税率81:非住居者非課税制度対象分非課税（口座管理機関源泉徴収分）税率
				  ,l_inItem068    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK81 -- 支払金額81
				  ,l_inItem069    => C_REPORT_ID                           -- 帳票ID
				  ,l_inItem070    => 'ZZZ,ZZ9.9'
				  ,l_inItem071    => recMeisai.TSUKA_NM  -- 発行通貨
				  ,l_inItem072    => recMeisai.TSUKA_NM  -- 発行通貨(支払金額)
				  ,l_inItem073    => recMeisai.TSUKA_NM  -- 発行通貨(税額)
				  ,l_inItem074    => l_inUserId 				  -- ユーザＩＤ
				  ,l_inKousinId   => l_inUserId 				  -- 更新者ID
				  ,l_inSakuseiId  => l_inUserId 				  -- 作成者ID
				);
			gMainSeqNo := gMainSeqNo + 1;
		-- レコード数分ループの終了
		END LOOP;
		-- 「対象データなし」レコード登録
		IF gSeqNo = 0 THEN
			-- リターンコードのセット
			gRtnCd := pkconstant.NO_DATA_FIND();
		-- 帳票ワークへデータを追加
			CALL pkPrint.insertData(l_inKeyCd => l_inItakuKaishaCd 	-- 識別コード
					   , l_inUserId => l_inUserId 	        -- ユーザＩＤ
					   , l_inChohyoKbn => l_inChohyoKbn 	-- 帳票区分
					   , l_inSakuseiYmd => l_inGyomuYmd 	-- 作成年月日
					   , l_inChohyoId => C_REPORT_ID 	-- 帳票ＩＤ
					   , l_inSeqNo => gMainSeqNo 		-- 連番
					   , l_inHeaderFlg  => '1'		-- ヘッダフラグ
					   , l_inItem002    => l_inKijunYm 	-- 基準年月
					   , l_inItem011    => '対象データなし' -- 対象データ
					   , l_inKousinId   => l_inUserId 	-- 更新者ID
					   , l_inSakuseiId  => l_inUserId 	-- 作成者ID
					   , l_inItem074    => l_inUserId 	-- ユーザＩＤ
					   , l_inItem069    => C_REPORT_ID       -- 帳票ID
					   , l_inItem001    => gItakuKaishaRnm 	-- 委託会社略称
					   );
		END IF;
	END LOOP;
	IF l_inItakuKaishaCd = 'JIMU' THEN
		-- 「対象データなし」レコード登録
		IF gMainSeqNo = 0 THEN
			-- リターンコードのセット
			gRtnCd := pkconstant.NO_DATA_FIND();
		-- 帳票ワークへデータを追加
			CALL pkPrint.insertData(l_inKeyCd => l_inItakuKaishaCd 	-- 識別コード
					   , l_inUserId => l_inUserId 	        -- ユーザＩＤ
					   , l_inChohyoKbn => l_inChohyoKbn 	-- 帳票区分
					   , l_inSakuseiYmd => l_inGyomuYmd 	-- 作成年月日
					   , l_inChohyoId => C_REPORT_ID 	-- 帳票ＩＤ
					   , l_inSeqNo => 1		        -- 連番
					   , l_inHeaderFlg  => '1'		-- ヘッダフラグ
					   , l_inItem002    => l_inKijunYm 	-- 基準年月
					   , l_inItem011    => '対象データなし' -- 対象データ
					   , l_inKousinId   => l_inUserId 	-- 更新者ID
					   , l_inSakuseiId  => l_inUserId 	-- 作成者ID
					   , l_inItem074    => l_inUserId 	-- ユーザＩＤ
					   , l_inItem069    => C_REPORT_ID       -- 帳票ID
					   , l_inItem001    => gItakuKaishaRnm 	-- 委託会社略称
					);
		END IF;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
  -- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_REPORT_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_REPORT_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx025k00r03 ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inKijunYm TEXT, l_inHktCd MHAKKOTAI.HKT_CD%TYPE, l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE, l_inZeimushoCd MZEIMUSHO.ZEIMUSHO_CD%TYPE, l_inSdFlg MITAKU_KAISHA2.SD_FLG%TYPE, l_inNouzeiFlg text, l_inChohyoKbn text, l_inUserId SUSER.USER_ID%TYPE, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;