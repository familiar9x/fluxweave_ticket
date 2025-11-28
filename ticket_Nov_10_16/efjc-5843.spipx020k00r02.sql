




CREATE OR REPLACE PROCEDURE spipx020k00r02 ( l_inHakkoYmdF TEXT,                          -- 発行年月日（From）
 l_inHakkoYmdT TEXT,                          -- 発行年月日（To）
 l_inHktCd TEXT,                          -- 発行体コード
 l_inKozaTenCd TEXT,                          -- 口座店店番
 l_inKozaTenCifcd TEXT,                          -- 口座店CIFコード
 l_inMgrCd TEXT,                          -- 銘柄コード
 l_inIsinCd TEXT,                          -- ISINコード
 l_inKanyoFlg TEXT,                          -- 機構関与方式採用フラグ
 l_inMgrStatKbn TEXT,                          -- 承認区分
 l_inItakuKaishaCd TEXT,                          -- 委託会社コード
 l_inUserId TEXT,                          -- ユーザーID
 l_inChohyoKbn TEXT,                          -- 帳票区分
 l_inGyomuYmd TEXT,                          -- 業務日付
 l_outSqlCode OUT integer,                        -- リターン値
 l_outSqlErrM OUT text                       -- エラーコメント
 ) AS $body$
DECLARE

/**
 * 著作権:Copyright(c)2018
 * 会社名:JIP
 *
 * 概要　:事務管理帳票出力指示画面より、印刷条件の指定を受けて、機構送信項目リスト（ＣＢ）の作成
 *
 * 引数　:l_inHakkoYmdF     :発行年月日（From）
 *        l_inHakkoYmdT     :発行年月日（To）
 *        l_inHktCd         :発行体コード
 *        l_inKozaTenCd     :口座店店番
 *        l_inKozaTenCifcd  :口座店ＣＩＦコード
 *        l_inMgrCd         :銘柄コード
 *        l_inIsinCd        :ISINコード
 *        l_inKanyoFlg      :機構関与方式採用フラグ
 *        l_inMgrStatKbn    :承認区分
 *        l_inItakuKaishaCd :委託会社コード
 *        l_inUserId        :ユーザーＩＤ
 *        l_inChohyoKbn     :帳票区分
 *        l_inGyomuYmd      :業務日付
 *        l_outSqlCode      :リターン値
 *        l_outSqlErrM      :エラーコメント
 *
 * 返り値: なし
 *
 * @author 宋暁楽(USI)
 * @version 1.0
 */
	/*==============================================================================*
		デバッグ機能
	 *==============================================================================*/
	DEBUG numeric(1) := 0;	-- 0:オフ 1:オン
	
	/*==============================================================================*/

	/*          配列定義                          */

	/*==============================================================================*/

	-- PostgreSQL uses standard arrays instead of associative arrays
	/*==============================================================================*/

	/*                  定数定義                                                    */

	/*==============================================================================*/

	C_PROCEDURE_ID  CONSTANT varchar(50) := 'SPIPX020K00R02';           -- プロシージャＩＤ
	C_CHOHYO_ID     CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPX30002021'; -- 帳票ＩＤ
	RTN_OK          CONSTANT integer := 0;    -- 正常
	RTN_NG          CONSTANT integer := 1;    -- 予期したエラー
	RTN_NODATA      CONSTANT integer := 2;    -- データなし
	RTN_FATAL       CONSTANT integer := 99;   -- 予期せぬエラー
	
	/*==============================================================================*/

	/*                  変数定義                                                    */

	/*==============================================================================*/

	gRtnCd            integer := RTN_OK;            -- リターンコード
	gSeqNo            integer := 0;                 -- シーケンス
	gItakuKaishaRnm   SOWN_INFO.BANK_RNM%TYPE;           -- 委託会社略名
	gLastShoninId     MGR_STS.LAST_SHONIN_ID%TYPE;       -- 最終承認ユーザ
	gLastShoninYmd    MGR_STS.LAST_SHONIN_YMD%TYPE;      -- 最終承認日
	gMgrCd            MGR_KIHON.MGR_CD%TYPE;             -- 銘柄コード
	gArySknKessaiCd   varchar(100)[];                     -- 社債管理会社受託会社コード１〜１０
	gArySknKessaiNm   varchar(100)[];                     -- 社債管理会社受託会社名１〜１０
	v_item            TYPE_SREPORT_WK_ITEM;              -- Composite type for insertData
	
	-- プットオプション関連
	gPutShokanKjt			UPD_MGR_SHN.SHR_KJT%TYPE;
	gPutShokanPremium		UPD_MGR_SHN.SHOKAN_PREMIUM%TYPE;
    gPutStkoshikikanYmd		UPD_MGR_SHN.ST_PUTKOSHIKIKAN_YMD%TYPE;
    gPutEdkoshikikanYmd		UPD_MGR_SHN.ED_PUTKOSHIKIKAN_YMD%TYPE;
    gPutKkStat				UPD_MGR_SHN.KK_STAT%TYPE;
    wkPutShokanKagaku		numeric;
	/*==============================================================================*/

	/*                  カーソル定義                                                */

	/*==============================================================================*/

	curMeisai CURSOR FOR
		SELECT
			MG1.ITAKU_KAISHA_CD as ITAKU_KAISHA_CD,                 -- 委託会社コード
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG0.MGR_STAT_KBN = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '161') as SHONIN_STAT,    -- 承認状態
			MG0.MGR_STAT_KBN as MGR_STAT_KBN,                       -- 銘柄ステータス区分
			MG0.KIHON_TEISEI_YMD as KIHON_TEISEI_YMD,               -- 基本訂正日
			MG0.KIHON_TEISEI_USER_ID as KIHON_TEISEI_USER_ID,       -- 基本訂正ユーザ
			MG0.LAST_SHONIN_YMD as LAST_SHONIN_YMD,                 -- 最終承認日
			MG0.LAST_SHONIN_ID as LAST_SHONIN_ID,                   -- 最終承認ユーザ
			MG1.MGR_CD as MGR_CD,                                   -- 銘柄コード
			MG1.ISIN_CD as ISIN_CD,                                 -- ＩＳＩＮコード
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.SHNK_HNK_TRKSH_KBN = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '598') as SHNK_HNK_TRKSH_KBN_NM,    -- 新規変更取消区分名称
			WMG1.TEKIYOST_YMD as TEKIYOST_YMD,                      -- 適用開始日
			WMG1.KK_MGR_CD as KK_MGR_CD,                            -- 機構銘柄コード
			MG1.MGR_RNM as MGR_RNM,                                 -- 銘柄略称
			MG1.HAKKODAIRI_CD as HAKKODAIRI_CD,                     -- 発行代理人コード
			(SELECT
				VM02.BANK_RNM
			FROM
				VMBANK VM02
			WHERE
				MG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				AND MG1.HAKKODAIRI_CD = VM02.FINANCIAL_SECURITIES_KBN || VM02.BANK_CD) as HAKKODAIRI_RNM, -- 発行代理人略称
			MG1.SHRDAIRI_CD as SHRDAIRI_CD,                         -- 支払代理人コード
			(SELECT
				VM02.BANK_RNM
			FROM
				VMBANK VM02
			WHERE
				MG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				AND MG1.SHRDAIRI_CD = VM02.FINANCIAL_SECURITIES_KBN || VM02.BANK_CD) as SHRDAIRI_RNM, -- 支払代理人略称
		MG1.SKN_KESSAI_CD as SKN_KESSAI_CD,                     -- 資金決済会社コード
		pkIpaName.getSknKessaiRnm(MG1.ITAKU_KAISHA_CD,MG1.SKN_KESSAI_CD) as SKN_KESSAI_RNM, -- 資金決済会社略称
		MG1.MGR_NM as MGR_NM,                                   -- 銘柄の正式名称
			MG1.KK_HAKKO_CD as KK_HAKKO_CD,                         -- 機構発行体コード
			MG1.KK_HAKKOSHA_RNM as KK_HAKKOSHA_RNM,                 -- 機構発行者略称
			MG1.KAIGO_ETC as KAIGO_ETC,                             -- 回号等
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.BOSHU_KBN = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '528') as BOSHU_KBN_NM,   -- 募集区分名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.JOJO_KBN_TO = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '599') as JOJO_KBN_TO_NM,    -- 上場区分(東証)内容
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.JOJO_KBN_ME = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '599') as JOJO_KBN_ME_NM,    -- 上場区分(名証)内容
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.JOJO_KBN_FU = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '599') as JOJO_KBN_FU_NM,    -- 上場区分(福証)内容
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.JOJO_KBN_SA = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '599') as JOJO_KBN_SA_NM,    -- 上場区分(札証)内容
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.SAIKEN_SHURUI = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '514') as SAIKEN_KBN_NM,   -- 債券種類名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.HOSHO_KBN = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '527') as HOSHO_KBN_NM,     -- 保証区分名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.TANPO_KBN = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '519') as TANPO_KBN_NM,     -- 担保区分名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.GODOHAKKO_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '513') as GODOHAKKO_FLG_NM,  -- 合同発行フラグ名称
			MG1.BOSHU_ST_YMD as BOSHU_ST_YMD,                       -- 募集開始日
			MG1.HAKKO_YMD as HAKKO_YMD,                             -- 発行年月日
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.SKNNZISNTOKU_UMU_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '517') as SKNNZISNTOKU_UMU_FLG_NM, -- 責任財産限定特約有無フラグ名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.RETSUTOKU_UMU_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '530') as RETSUTOKU_UMU_FLG_NM, -- 劣後特約有無フラグ名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.UCHIKIRI_HAKKO_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '518') as UCHIKIRI_HAKKO_FLG_NM, -- 打切発行フラグ名称
			MG1.KAKUSHASAI_KNGK as KAKUSHASAI_KNGK,                     -- 各社債の金額
			MG1.SHASAI_TOTAL as SHASAI_TOTAL,                           -- 社債の総額
			MG1.FULLSHOKAN_KJT as FULLSHOKAN_KJT,                       -- 満期償還期日
			WMG1.SHOKAN_PREMIUM + MG1.KAKUSHASAI_KNGK as SHOKAN_KAGAKU, -- 償還価額
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.CALLALL_UMU_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '101') as CALLALL_UMU_FLG_NM, -- コールオプション有無（全額）名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.PUTUMU_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '101') as PUTUMU_FLG_NM,       -- プットオプション有無名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.KYUJITSU_KBN = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '506') as KYUJITSU_KBN_NM,      -- 休日処理区分名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.RITSUKE_WARIBIKI_KBN = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '529') as RITSUKE_WARIBIKI_KBN_NM, -- 利付割引区分名称
			MG1.ST_RBR_KJT as ST_RBR_KJT,                           -- 初回利払期日
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.LAST_RBR_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '515') as LAST_RBR_FLG_NM, -- 最終利払有無フラグ名称
			CASE WHEN MG1.RIRITSU=0 THEN  NULL  ELSE MG1.RIRITSU END  as RIRITSU,   -- 利率
			MG1.RBR_KJT_MD1 as RBR_KJT_MD1,                         -- 利払期日（MD）（1）
			MG1.RBR_KJT_MD2 as RBR_KJT_MD2,                         -- 利払期日（MD）（2）
			MG1.RBR_KJT_MD3 as RBR_KJT_MD3,                         -- 利払期日（MD）（3）
			MG1.RBR_KJT_MD4 as RBR_KJT_MD4,                         -- 利払期日（MD）（4）
			MG1.RBR_KJT_MD5 as RBR_KJT_MD5,                         -- 利払期日（MD）（5）
			MG1.RBR_KJT_MD6 as RBR_KJT_MD6,                         -- 利払期日（MD）（6）
			MG1.RBR_KJT_MD7 as RBR_KJT_MD7,                         -- 利払期日（MD）（7）
			MG1.RBR_KJT_MD8 as RBR_KJT_MD8,                         -- 利払期日（MD）（8）
			MG1.RBR_KJT_MD9 as RBR_KJT_MD9,                         -- 利払期日（MD）（9）
			MG1.RBR_KJT_MD10 as RBR_KJT_MD10,                       -- 利払期日（MD）10）
			MG1.RBR_KJT_MD11 as RBR_KJT_MD11,                       -- 利払期日（MD）（11）
			MG1.RBR_KJT_MD12 as RBR_KJT_MD12,                       -- 利払期日（MD）（12）
			CASE WHEN MG1.TSUKARISHI_KNGK_FAST=0 THEN  NULL  ELSE MG1.TSUKARISHI_KNGK_FAST END  as TSUKARISHI_KNGK_FAST,       -- １通貨あたりの利子金額（初期）
			CASE WHEN MG1.TSUKARISHI_KNGK_NORM=0 THEN  NULL  ELSE MG1.TSUKARISHI_KNGK_NORM END  as TSUKARISHI_KNGK_NORM,       -- １通貨あたりの利子金額（通常）
			CASE WHEN MG1.TSUKARISHI_KNGK_LAST=0 THEN  NULL  ELSE MG1.TSUKARISHI_KNGK_LAST END  as TSUKARISHI_KNGK_LAST,       -- １通貨あたりの利子金額（終期）
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				MG1.KK_KANYO_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '505') as KK_KANYO_FLG_NM, -- 機構関与方式採用フラグ名称
			CASE WHEN MG1.KK_KANYO_FLG = '1' THEN (SELECT
					SCODE.CODE_NM
				FROM
					SCODE
				WHERE
					MG1.KOBETSU_SHONIN_SAIYO_FLG = SCODE.CODE_VALUE
					AND SCODE.CODE_SHUBETSU = '511')
				ELSE NULL
			END as KOBETSU_SHONIN_SAIYO_FLG_NM, -- 個別承認採用フラグ名称
			CASE WHEN MG1.TANPO_KBN = '2' THEN (SELECT
					SCODE.CODE_NM
				FROM
					SCODE
				WHERE
					MG1.PARTHAKKO_UMU_FLG = SCODE.CODE_VALUE
					AND SCODE.CODE_SHUBETSU = '525')
				ELSE NULL
			END as PARTHAKKO_UMU_FLG_NM, -- 分割発行有無フラグ名称
			WMG1.WRNT_TOTAL as WRNT_TOTAL,                            -- 新株予約権の総数
			WMG1.WRNT_USE_ST_YMD as WRNT_USE_ST_YMD,                  -- 新株予約権の行使期間開始日
			WMG1.WRNT_USE_ED_YMD as WRNT_USE_ED_YMD,                  -- 新株予約権の行使期間終了日
			WMG1.WRNT_HAKKO_KAGAKU as WRNT_HAKKO_KAGAKU,              -- 新株予約権の発行価額
			WMG1.WRNT_USE_KAGAKU as WRNT_USE_KAGAKU,                  -- 新株予約権の行使価額
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.HASU_SHOKAN_UMU_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '601') as HASU_SHOKAN_UMU_FLG_NM, -- 端数償還金有無フラグ内容
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.USE_SEIKYU_UKE_BASHO = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '596') as USE_SEIKYU_UKE_BASHO_NM, -- 行使請求受付場所名称
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.SHTK_JK_UMU_FLG = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '600') as SHTK_JK_UMU_FLG_NM, -- 取得条項有無フラグ内容
			WMG1.SHTK_JK_YMD as SHTK_JK_YMD,                         -- 取得条項に係る取得日
			(SELECT
				SCODE.CODE_NM
			FROM
				SCODE
			WHERE
				WMG1.SHTK_TAIKA_SHURUI = SCODE.CODE_VALUE
				AND SCODE.CODE_SHUBETSU = '597') as SHTK_TAIKA_SHURUI_NM, -- 取得対価(交付財産)の種類名称
			WMG1.SHANAI_KOMOKU1 as SHANAI_KOMOKU1,                        -- 社内処理用項目1
			WMG1.SHANAI_KOMOKU2 as SHANAI_KOMOKU2,                        -- 社内処理用項目2
			CASE WHEN MG8.GNKN_SHR_TESU_BUNBO=0 THEN  NULL  ELSE MG8.GNKN_SHR_TESU_BUNBO END  as GNKN_SHR_TESU_BUNBO,               -- 元金支払手数料率（分母）
			CASE WHEN MG8.GNKN_SHR_TESU_BUNSHI=0 THEN  NULL  ELSE MG8.GNKN_SHR_TESU_BUNSHI END  as GNKN_SHR_TESU_BUNSHI,             -- 元金支払手数料率（分子）
			CASE WHEN MG8.RKN_SHR_TESU_BUNBO=0 THEN  NULL  ELSE MG8.RKN_SHR_TESU_BUNBO END  as RKN_SHR_TESU_BUNBO,                 -- 利金支払手数料率（分母）
			CASE WHEN MG8.RKN_SHR_TESU_BUNSHI=0 THEN  NULL  ELSE MG8.RKN_SHR_TESU_BUNSHI END  as RKN_SHR_TESU_BUNSHI,               -- 利金支払手数料率（分子）
			CASE WHEN MG7.TESU_SHURUI_CD = '61'
				THEN (SELECT
					SCODE.CODE_NM
				FROM
					SCODE
				WHERE
					SCODE.CODE_SHUBETSU = '138'
					AND SCODE.CODE_VALUE = '1')
			WHEN MG7.TESU_SHURUI_CD = '82'
				THEN (SELECT
					SCODE.CODE_NM
				FROM
					SCODE
				WHERE
					SCODE.CODE_SHUBETSU = '138'
					AND SCODE.CODE_VALUE = '2')
			ELSE
				NULL
			END as RKN_TESU_KIJUN                         -- 利金手数料率基準
		FROM cb_mgr_kihon wmg1, mgr_sts mg0, mhakkotai m01, mgr_kihon mg1
LEFT OUTER JOIN mgr_tesuryo_prm mg8 ON (MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG8.MGR_CD)
LEFT OUTER JOIN mgr_tesuryo_ctl mg7 ON (MG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG7.MGR_CD AND MG7.TESU_SHURUI_CD IN ('61','82')   AND '1' = MG7.CHOOSE_FLG)
WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = MG0.MGR_CD AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD AND MG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD AND MG1.MGR_CD = WMG1.MGR_CD AND MG1.JTK_KBN <> '2' AND MG1.TOKUREI_SHASAI_FLG <> 'Y' AND MG1.SAIKEN_SHURUI IN ('80','89') AND MG0.MASSHO_FLG = '0' AND MG1.HAKKO_YMD >= l_inHakkoYmdF AND MG1.HAKKO_YMD <= l_inHakkoYmdT       AND (coalesce(trim(both l_inHktCd)::text, '') = '' OR MG1.HKT_CD = trim(both l_inHktCd)) AND (coalesce(trim(both l_inKozaTenCd)::text, '') = '' OR M01.KOZA_TEN_CD = trim(both l_inKozaTenCd)) AND (coalesce(trim(both l_inKozaTenCifcd)::text, '') = '' OR M01.KOZA_TEN_CIFCD = l_inKozaTenCifcd) AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR MG1.MGR_CD = trim(both l_inMgrCd)) AND (coalesce(trim(both l_inIsinCd)::text, '') = '' OR MG1.ISIN_CD = trim(both l_inIsinCd)) AND (coalesce(trim(both l_inKanyoFlg)::text, '') = '' OR MG1.KK_KANYO_FLG = trim(both l_inKanyoFlg)) AND (coalesce(trim(both l_inMgrStatKbn)::text, '') = '' OR MG0.MGR_STAT_KBN = trim(both l_inMgrStatKbn)) ORDER BY
			MG1.ITAKU_KAISHA_CD,                           -- 委託会社コード
			MG1.MGR_CD;                                     -- 銘柄コード
	-- 銘柄受託銀行情報取得
	curJutakuginko CURSOR(inMgrCd  MGR_KIHON.MGR_CD%TYPE, inItakuKaishaCd  MGR_KIHON.ITAKU_KAISHA_CD%TYPE) FOR
			SELECT
				MG6.ITAKU_KAISHA_CD,
				MG6.MGR_CD,
				MG6.INPUT_NUM,
				MG6.FINANCIAL_SECURITIES_KBN,
				MG6.BANK_CD as BANK_CD,
				M02.BANK_RNM as BANK_RNM
			FROM
				MBANK M02,
				MGR_JUTAKUGINKO MG6
			WHERE
				MG6.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN
				AND MG6.BANK_CD = M02.BANK_CD
				AND MG6.ITAKU_KAISHA_CD = inItakuKaishaCd
				AND MG6.MGR_CD = inMgrCd
			ORDER BY
				MG6.INPUT_NUM;
/*==============================================================================*/

/*                  メイン処理                                                  */

/*==============================================================================*/

BEGIN
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''   -- 委託会社コード
	OR coalesce(trim(both l_inHakkoYmdF)::text, '') = ''       -- 発行年月日（From）
	OR coalesce(trim(both l_inHakkoYmdT)::text, '') = ''       -- 発行年月日（To）
	OR coalesce(trim(both l_inUserId)::text, '') = ''          -- ユーザーID
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''       -- 帳票区分
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN    -- 業務日付
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID, 3, 12), 'パラメータエラー');
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_ID);
	-- 委託会社略名取得
	BEGIN
		SELECT
			CASE WHEN JIKO_DAIKO_KBN='1' THEN NULL  ELSE BANK_RNM END  INTO STRICT gItakuKaishaRnm
		FROM
			VJIKO_ITAKU
		WHERE
			KAIIN_ID = l_inItakuKaishaCd;
	EXCEPTION WHEN no_data_found THEN
		gItakuKaishaRnm := NULL;
	END;
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		-- シーケンスの設定
		gSeqNo := gSeqNo + 1;
		-- 最終承認ユーザ及び最終承認日の設定
		gLastShoninId := NULL;
		gLastShoninYmd := NULL;
		IF recMeisai.MGR_STAT_KBN = '1' THEN
			gLastShoninId := recMeisai.LAST_SHONIN_ID;
			gLastShoninYmd := recMeisai.LAST_SHONIN_YMD;
		END IF;
		-- ローカル変数の設定
		gMgrCd := recMeisai.MGR_CD;
		-- 配列の初期化
		FOR i IN 1 .. 10
		LOOP
			gArySknKessaiCd[i] := NULL;
			gArySknKessaiNm[i] := NULL;
		END LOOP;
		-- 取得した件数分、下記の処理を繰り返す
		FOR recJutakuginko IN curJutakuginko(gMgrCd,l_inItakuKaishaCd)
		LOOP
			IF recJutakuginko.INPUT_NUM = 1 THEN
				gArySknKessaiCd[1] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[1] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 2 THEN
				gArySknKessaiCd[2] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[2] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 3 THEN
				gArySknKessaiCd[3] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[3] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 4 THEN
				gArySknKessaiCd[4] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[4] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 5 THEN
				gArySknKessaiCd[5] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[5] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 6 THEN
				gArySknKessaiCd[6] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[6] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 7 THEN
				gArySknKessaiCd[7] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[7] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 8 THEN
				gArySknKessaiCd[8] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[8] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 9 THEN
				gArySknKessaiCd[9] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[9] := recJutakuginko.BANK_RNM;
			ELSIF recJutakuginko.INPUT_NUM = 10 THEN
				gArySknKessaiCd[10] := recJutakuginko.BANK_CD;
				gArySknKessaiNm[10] := recJutakuginko.BANK_RNM;
			END IF;
	END LOOP;
	-- 銘柄情報通知（ＣＢ）改善オプションフラグ ＝ "1" の場合
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'CBMGR_TSUCHI', '0') = '1' THEN
		-- プットオプション行使条件を取得する
		SELECT l_outputshokankjt, l_outputshokanpremium, l_outputstkoshikikanymd, l_outputedkoshikikanymd, l_outkkstat
			INTO gPutShokanKjt, gPutShokanPremium, gPutStkoshikikanYmd, gPutEdkoshikikanYmd, gPutKkStat
			FROM sfIpGetPutOption(l_inItakuKaishaCd, gMgrCd);
		-- プットオプション行使条件が取得できた場合
		IF (trim(both gPutShokanKjt) IS NOT NULL AND (trim(both gPutShokanKjt))::text <> '') THEN
				wkPutShokanKagaku := gPutShokanPremium + recMeisai.KAKUSHASAI_KNGK;
			ELSE
				gPutShokanKjt := NULL;
				wkPutShokanKagaku := NULL;
				gPutStkoshikikanYmd := NULL;
				gPutEdkoshikikanYmd := NULL;
			END IF;
		END IF;
		-- 明細レコード追加
		-- Initialize composite type
		v_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
		              )::TYPE_SREPORT_WK_ITEM;
		-- Set field values
		v_item.l_inItem001 := l_inUserId;
		v_item.l_inItem002 := l_inItakuKaishaCd;
		v_item.l_inItem003 := gItakuKaishaRnm;
		v_item.l_inItem004 := recMeisai.SHONIN_STAT;
		v_item.l_inItem005 := recMeisai.KIHON_TEISEI_YMD;
		v_item.l_inItem006 := recMeisai.KIHON_TEISEI_USER_ID;
		v_item.l_inItem007 := recMeisai.LAST_SHONIN_YMD;
		v_item.l_inItem008 := recMeisai.LAST_SHONIN_ID;
		v_item.l_inItem009 := recMeisai.MGR_CD;
		v_item.l_inItem010 := recMeisai.ISIN_CD;
		v_item.l_inItem011 := recMeisai.SHNK_HNK_TRKSH_KBN_NM;
		v_item.l_inItem012 := recMeisai.TEKIYOST_YMD;
		v_item.l_inItem013 := recMeisai.KK_MGR_CD;
		v_item.l_inItem014 := recMeisai.MGR_RNM;
		v_item.l_inItem015 := recMeisai.HAKKODAIRI_CD;
		v_item.l_inItem016 := recMeisai.HAKKODAIRI_RNM;
		v_item.l_inItem017 := recMeisai.SHRDAIRI_CD;
		v_item.l_inItem018 := recMeisai.SHRDAIRI_RNM;
		v_item.l_inItem019 := recMeisai.SKN_KESSAI_CD;
		v_item.l_inItem020 := recMeisai.SKN_KESSAI_RNM;
		v_item.l_inItem021 := recMeisai.MGR_NM;
		v_item.l_inItem022 := recMeisai.KK_HAKKOSHA_RNM;
		v_item.l_inItem023 := recMeisai.KAIGO_ETC;
		v_item.l_inItem024 := recMeisai.BOSHU_KBN_NM;
		v_item.l_inItem025 := recMeisai.JOJO_KBN_TO_NM;
		v_item.l_inItem026 := recMeisai.JOJO_KBN_ME_NM;
		v_item.l_inItem027 := recMeisai.JOJO_KBN_FU_NM;
		v_item.l_inItem028 := recMeisai.JOJO_KBN_SA_NM;
		v_item.l_inItem029 := recMeisai.SAIKEN_KBN_NM;
		v_item.l_inItem030 := recMeisai.HOSHO_KBN_NM;
		v_item.l_inItem031 := recMeisai.TANPO_KBN_NM;
		v_item.l_inItem032 := recMeisai.GODOHAKKO_FLG_NM;
		v_item.l_inItem033 := recMeisai.BOSHU_ST_YMD;
		v_item.l_inItem034 := recMeisai.HAKKO_YMD;
		v_item.l_inItem035 := recMeisai.SKNNZISNTOKU_UMU_FLG_NM;
		v_item.l_inItem036 := recMeisai.RETSUTOKU_UMU_FLG_NM;
		v_item.l_inItem037 := recMeisai.UCHIKIRI_HAKKO_FLG_NM;
		v_item.l_inItem038 := recMeisai.KAKUSHASAI_KNGK;
		v_item.l_inItem039 := recMeisai.SHASAI_TOTAL;
		v_item.l_inItem040 := recMeisai.FULLSHOKAN_KJT;
		v_item.l_inItem041 := recMeisai.SHOKAN_KAGAKU;
		v_item.l_inItem042 := recMeisai.CALLALL_UMU_FLG_NM;
		v_item.l_inItem043 := recMeisai.PUTUMU_FLG_NM;
		v_item.l_inItem044 := gArySknKessaiCd[1];
		v_item.l_inItem045 := gArySknKessaiNm[1];
		v_item.l_inItem046 := gArySknKessaiCd[2];
		v_item.l_inItem047 := gArySknKessaiNm[2];
		v_item.l_inItem048 := gArySknKessaiCd[3];
		v_item.l_inItem049 := gArySknKessaiNm[3];
		v_item.l_inItem050 := gArySknKessaiCd[4];
		v_item.l_inItem051 := gArySknKessaiNm[4];
		v_item.l_inItem052 := gArySknKessaiCd[5];
		v_item.l_inItem053 := gArySknKessaiNm[5];
		v_item.l_inItem054 := gArySknKessaiCd[6];
		v_item.l_inItem055 := gArySknKessaiNm[6];
		v_item.l_inItem056 := gArySknKessaiCd[7];
		v_item.l_inItem057 := gArySknKessaiNm[7];
		v_item.l_inItem058 := gArySknKessaiCd[8];
		v_item.l_inItem059 := gArySknKessaiNm[8];
		v_item.l_inItem060 := gArySknKessaiCd[9];
		v_item.l_inItem061 := gArySknKessaiNm[9];
		v_item.l_inItem062 := gArySknKessaiCd[10];
		v_item.l_inItem063 := gArySknKessaiNm[10];
		v_item.l_inItem064 := recMeisai.KYUJITSU_KBN_NM;
		v_item.l_inItem065 := recMeisai.RITSUKE_WARIBIKI_KBN_NM;
		v_item.l_inItem066 := recMeisai.ST_RBR_KJT;
		v_item.l_inItem067 := recMeisai.LAST_RBR_FLG_NM;
		v_item.l_inItem068 := recMeisai.RIRITSU;
		v_item.l_inItem069 := recMeisai.RBR_KJT_MD1;
		v_item.l_inItem070 := recMeisai.RBR_KJT_MD2;
		v_item.l_inItem071 := recMeisai.RBR_KJT_MD3;
		v_item.l_inItem072 := recMeisai.RBR_KJT_MD4;
		v_item.l_inItem073 := recMeisai.RBR_KJT_MD5;
		v_item.l_inItem074 := recMeisai.RBR_KJT_MD6;
		v_item.l_inItem075 := recMeisai.RBR_KJT_MD7;
		v_item.l_inItem076 := recMeisai.RBR_KJT_MD8;
		v_item.l_inItem077 := recMeisai.RBR_KJT_MD9;
		v_item.l_inItem078 := recMeisai.RBR_KJT_MD10;
		v_item.l_inItem079 := recMeisai.RBR_KJT_MD11;
		v_item.l_inItem080 := recMeisai.RBR_KJT_MD12;
		v_item.l_inItem081 := recMeisai.TSUKARISHI_KNGK_FAST;
		v_item.l_inItem082 := recMeisai.TSUKARISHI_KNGK_NORM;
		v_item.l_inItem083 := recMeisai.TSUKARISHI_KNGK_LAST;
		v_item.l_inItem084 := recMeisai.KK_KANYO_FLG_NM;
		v_item.l_inItem085 := recMeisai.KOBETSU_SHONIN_SAIYO_FLG_NM;
		v_item.l_inItem086 := recMeisai.WRNT_TOTAL;
		v_item.l_inItem087 := recMeisai.WRNT_USE_ST_YMD;
		v_item.l_inItem088 := recMeisai.WRNT_USE_ED_YMD;
		v_item.l_inItem089 := recMeisai.WRNT_HAKKO_KAGAKU;
		v_item.l_inItem090 := recMeisai.WRNT_USE_KAGAKU;
		v_item.l_inItem091 := recMeisai.HASU_SHOKAN_UMU_FLG_NM;
		v_item.l_inItem092 := recMeisai.USE_SEIKYU_UKE_BASHO_NM;
		v_item.l_inItem093 := recMeisai.SHTK_JK_UMU_FLG_NM;
		v_item.l_inItem094 := recMeisai.SHTK_JK_YMD;
		v_item.l_inItem095 := recMeisai.SHTK_TAIKA_SHURUI_NM;
		v_item.l_inItem096 := recMeisai.SHANAI_KOMOKU1;
		v_item.l_inItem097 := recMeisai.SHANAI_KOMOKU2;
		v_item.l_inItem098 := recMeisai.GNKN_SHR_TESU_BUNBO;
		v_item.l_inItem099 := recMeisai.GNKN_SHR_TESU_BUNSHI;
		v_item.l_inItem100 := recMeisai.RKN_SHR_TESU_BUNBO;
		v_item.l_inItem101 := recMeisai.RKN_SHR_TESU_BUNSHI;
		v_item.l_inItem102 := recMeisai.RKN_TESU_KIJUN;
		v_item.l_inItem103 := recMeisai.PARTHAKKO_UMU_FLG_NM;
		v_item.l_inItem104 := C_CHOHYO_ID;
		v_item.l_inItem106 := gPutShokanKjt;
		v_item.l_inItem107 := wkPutShokanKagaku;
		v_item.l_inItem108 := gPutStkoshikikanYmd;
		v_item.l_inItem109 := gPutEdkoshikikanYmd;
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => l_inGyomuYmd,
			l_inChohyoId   => C_CHOHYO_ID,
			l_inSeqNo      => gSeqNo,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
	END LOOP;
	-- 終了処理
	IF gSeqNo = 0 THEN
		-- 明細レコード追加（対象データなし）
		v_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
		              )::TYPE_SREPORT_WK_ITEM;
		v_item.l_inItem001 := l_inUserId;
		v_item.l_inItem003 := gItakuKaishaRnm;
		v_item.l_inItem104 := C_CHOHYO_ID;
		v_item.l_inItem105 := '対象データなし';
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => l_inGyomuYmd,
			l_inChohyoId   => C_CHOHYO_ID,
			l_inSeqNo      => 1,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
		gRtnCd := RTN_NODATA;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID ||' END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx020k00r02 ( l_inHakkoYmdF TEXT, l_inHakkoYmdT TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifcd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inKanyoFlg TEXT, l_inMgrStatKbn TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;