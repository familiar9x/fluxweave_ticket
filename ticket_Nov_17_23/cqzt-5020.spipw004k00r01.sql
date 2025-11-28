




CREATE OR REPLACE PROCEDURE spipw004k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,            -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,           -- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,        -- 帳票区分
 l_inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE, -- 業務日付
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,             -- 銘柄コード
 l_inTekiyoYmd CB_MGR_KIHON.TEKIYOST_YMD%TYPE,    -- 適用日
 l_inKkTsuchiYmd CB_MGR_KHN_RUISEKI.KK_TSUCHI_YMD%TYPE,    -- 機構通知日
 l_inSeqNo CB_MGR_KHN_RUISEKI.SEQ_NO%TYPE,    -- シーケンスNo
 l_outSqlCode OUT integer,                            -- リターン値
 l_outSqlErrM OUT text                           -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2008
-- * 会社名:JIP
-- *
-- * 概要　:期中銘柄情報（ＣＢ）変更−銘柄情報−画面より、変更確認リストを作成する。
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inGyomuYmd      :業務日付
-- *        l_inMgrCd         :銘柄コード
-- *        l_inTekiyoYmd     :適用日
-- *        l_inSeqNo         :シーケンスNo
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author 藤本 和哉
-- * @version $Id: SPIPW004K00R01.sql,v 1.7 2019/09/25 02:03:17 hasegawa Exp $
-- *
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID CONSTANT varchar(50) := 'SPIPW004K00R01';         -- プロシージャＩＤ
	C_CHOHYO_ID1    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPW30000411';  -- 帳票ＩＤ
	C_CHOHYO_ID2    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPW30000412';  -- 帳票ＩＤ
	C_CHOHYO_ID3    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPW30000413';  -- 帳票ＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item                    type_sreport_wk_item;                     -- 帳票ワーク項目（NEW STYLE）
	gItakuKaishaRnm           SOWN_INFO.BANK_RNM%TYPE;                   -- 委託会社略名
	gCnt                      numeric;                                    -- カウンタ
	gUseKagakuHenkoFlgKf1     char(1) := '0';                       -- 行使価額変更フラグ（行使価額）
	gUseKagakuHenkoFlgKf2     char(1) := '0';                       -- 行使価額変更フラグ（社内処理用項目１）
	gKkTsuchiYmd              varchar(8);                               -- 機構通知日
	gBoshuKbn                 CB_MGR_KHN_RUISEKI.BOSHU_KBN%TYPE;         -- 募集区分
	gJojoKbnTo                CB_MGR_KHN_RUISEKI.JOJO_KBN_TO%TYPE;       -- 上場区分（東証）
	gJojoKbnDa                CB_MGR_KHN_RUISEKI.JOJO_KBN_DA%TYPE;       -- 上場区分（大証）
	gJojoKbnMe                CB_MGR_KHN_RUISEKI.JOJO_KBN_ME%TYPE;       -- 上場区分（名証）
	gJojoKbnFu                CB_MGR_KHN_RUISEKI.JOJO_KBN_FU%TYPE;       -- 上場区分（福証）
	gJojoKbnSa                CB_MGR_KHN_RUISEKI.JOJO_KBN_SA%TYPE;       -- 上場区分（札証）
	gJojoKbnJa                CB_MGR_KHN_RUISEKI.JOJO_KBN_JA%TYPE;       -- 上場区分（ジャスダック証）
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	--今回適用日分取得
	thisCurMeisai CURSOR FOR
				SELECT
				    MG1.ITAKU_KAISHA_CD,
				    MG1.MGR_CD,
				    MG1.ISIN_CD,
				    WMG12.KK_MGR_CD,
				    WMG12.TEKIYOST_YMD,
				    WMG12.KK_TSUCHI_YMD,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '176' AND CODE_VALUE = WMG12.KK_PHASE || WMG12.KK_STAT) AS KK_STAT_NM,
				    WMG12.HAKKODAIRI_CD,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.HAKKODAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.HAKKODAIRI_CD, 2) = VM02.BANK_CD ) AS HAKKODAIRI_RNM,
				    WMG12.SHRDAIRI_CD,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHRDAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHRDAIRI_CD, 2) = VM02.BANK_CD ) AS SHRDAIRI_RNM,
				    WMG12.SKN_KESSAI_CD,
				    pkIpaName.getSknKessaiRnm(WMG12.ITAKU_KAISHA_CD, WMG12.SKN_KESSAI_CD) AS SKNKESSAI_RNM,
				    WMG12.MGR_NM,
				    WMG12.KK_HAKKOSHA_RNM,
				    WMG12.KAIGO_ETC,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '528' AND CODE_VALUE = WMG12.BOSHU_KBN) AS BOSHU_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_TO) AS JOJO_KBN_TO_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_DA) AS JOJO_KBN_DA_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_ME) AS JOJO_KBN_ME_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_FU) AS JOJO_KBN_FU_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_SA) AS JOJO_KBN_SA_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_JA) AS JOJO_KBN_JA_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '514' AND CODE_VALUE = WMG12.SAIKEN_SHURUI) AS SAIKEN_SHURUI_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '527' AND CODE_VALUE = WMG12.HOSHO_KBN) AS HOSHO_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '519' AND CODE_VALUE = WMG12.TANPO_KBN) AS TANPO_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '513' AND CODE_VALUE = WMG12.GODOHAKKO_FLG) AS GODOHAKKO_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '530' AND CODE_VALUE = WMG12.RETSUTOKU_UMU_FLG) AS RETSUTOKU_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '517' AND CODE_VALUE = WMG12.SKNNZISNTOKU_UMU_FLG) AS SKNNZISNTOKU_UMU_FLG_NM,
				    WMG12.BOSHU_ST_YMD,
				    WMG12.HAKKO_YMD,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '518' AND CODE_VALUE = WMG12.UCHIKIRI_HAKKO_FLG) AS UCHIKIRI_HAKKO_FLG_NM,
				    WMG12.KAKUSHASAI_KNGK,
				    WMG12.SHASAI_TOTAL,
				    CASE WHEN WMG12.SHOKAN_PREMIUM=0 THEN  NULL  ELSE WMG12.SHOKAN_PREMIUM END  AS SHOKAN_PREMIUM, -- 償還プレミアムが０のときは NULL にする
				    WMG12.SHOKAN_PREMIUM + WMG12.KAKUSHASAI_KNGK AS SHOKAN_KAGAKU,
				    WMG12.FULLSHOKAN_KJT,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '101' AND CODE_VALUE = WMG12.CALLALL_UMU_FLG) AS CALLALL_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '101' AND CODE_VALUE = WMG12.PUTUMU_FLG) AS PUTUMU_FLG_NM,
				    SUBSTR(WMG12.SHASAI_KANRI_CD1, 2) AS SHASAI_KANRI_CD1,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD1, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD1, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM1,
				    SUBSTR(WMG12.SHASAI_KANRI_CD2, 2) AS SHASAI_KANRI_CD2,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD2, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD2, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM2,
				    SUBSTR(WMG12.SHASAI_KANRI_CD3, 2) AS SHASAI_KANRI_CD3,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD3, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD3, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM3,
				    SUBSTR(WMG12.SHASAI_KANRI_CD4, 2) AS SHASAI_KANRI_CD4,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD4, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD4, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM4,
				    SUBSTR(WMG12.SHASAI_KANRI_CD5, 2) AS SHASAI_KANRI_CD5,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD5, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD5, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM5,
				    SUBSTR(WMG12.SHASAI_KANRI_CD6, 2) AS SHASAI_KANRI_CD6,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD6, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD6, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM6,
				    SUBSTR(WMG12.SHASAI_KANRI_CD7, 2) AS SHASAI_KANRI_CD7,
				     (SELECT VM02.BANK_RNM
				        FROM VMBANK VM02
				       WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				         AND SUBSTR(WMG12.SHASAI_KANRI_CD7, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				         AND SUBSTR(WMG12.SHASAI_KANRI_CD7, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM7,
				    SUBSTR(WMG12.SHASAI_KANRI_CD8, 2) AS SHASAI_KANRI_CD8,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD8, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD8, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM8,
				    SUBSTR(WMG12.SHASAI_KANRI_CD9, 2) AS SHASAI_KANRI_CD9,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD9, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD9, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM9,
				    SUBSTR(WMG12.SHASAI_KANRI_CD10, 2) AS SHASAI_KANRI_CD10,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD10, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD10, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM10,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '525' AND CODE_VALUE = WMG12.PARTHAKKO_UMU_FLG) AS PARTHAKKO_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '506' AND CODE_VALUE = WMG12.KYUJITSU_KBN) AS KYUJITSU_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '529' AND CODE_VALUE = WMG12.RITSUKE_WARIBIKI_KBN) AS RITSUKE_WARIBIKI_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '142' AND CODE_VALUE = WMG12.NENRBR_CNT) AS NENRBR_CNT_NM,
				    WMG12.RBR_DD,
				    WMG12.ST_RBR_KJT,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '515' AND CODE_VALUE = WMG12.LAST_RBR_FLG) AS LAST_RBR_FLG_NM,
				    (WMG12.RIRITSU)::numeric  AS RIRITSU,
				    CASE WHEN WMG12.TSUKARISHI_KNGK_FAST=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_FAST)::numeric  END  AS TSUKARISHI_KNGK_FAST, -- 1通貨あたりの利子金額（初期）が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_NORM=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_NORM)::numeric  END  AS TSUKARISHI_KNGK_NORM, -- 1通貨あたりの利子金額（通常）が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_LAST=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_LAST)::numeric  END  AS TSUKARISHI_KNGK_LAST, -- 1通貨あたりの利子金額（終期）が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_FAST_S=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_FAST_S)::numeric  END  AS TSUKARISHI_KNGK_FAST_S, -- 1通貨あたりの利子金額（初期）算出値が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_NORM_S=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_NORM_S)::numeric  END  AS TSUKARISHI_KNGK_NORM_S, -- 1通貨あたりの利子金額（通常）算出値が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_LAST_S=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_LAST_S)::numeric  END  AS TSUKARISHI_KNGK_LAST_S, -- 1通貨あたりの利子金額（終期）算出値が０のときは NULL にする
				    WMG12.RBR_KJT_MD1,
				    WMG12.RBR_KJT_MD2,
				    WMG12.RBR_KJT_MD3,
				    WMG12.RBR_KJT_MD4,
				    WMG12.RBR_KJT_MD5,
				    WMG12.RBR_KJT_MD6,
				    WMG12.RBR_KJT_MD7,
				    WMG12.RBR_KJT_MD8,
				    WMG12.RBR_KJT_MD9,
				    WMG12.RBR_KJT_MD10,
				    WMG12.RBR_KJT_MD11,
				    WMG12.RBR_KJT_MD12,
				    WMG12.WRNT_TOTAL,
				    WMG12.WRNT_USE_KAGAKU_KETTEI_YMD,
				    WMG12.WRNT_USE_ST_YMD,
				    WMG12.WRNT_USE_ED_YMD,
				    WMG12.WRNT_HAKKO_KAGAKU,
				    WMG12.WRNT_USE_KAGAKU,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '596' AND CODE_VALUE = WMG12.USE_SEIKYU_UKE_BASHO) AS USE_SEIKYU_UKE_BASHO_NM,
				    WMG12.WRNT_BIKO,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '600' AND CODE_VALUE = WMG12.SHTK_JK_UMU_FLG) AS SHTK_JK_UMU_FLG_NM,
				    WMG12.SHTK_JK_YMD,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '597' AND CODE_VALUE = WMG12.SHTK_TAIKA_SHURUI) AS SHTK_TAIKA_SHURUI_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '601' AND CODE_VALUE = WMG12.HASU_SHOKAN_UMU_FLG) AS HASU_SHOKAN_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '505' AND CODE_VALUE = WMG12.KK_KANYO_FLG) AS KK_KANYO_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '511' AND CODE_VALUE = WMG12.KOBETSU_SHONIN_SAIYO_FLG) AS KOBETSU_SHONIN_SAIYO_FLG_NM,
				    WMG12.SHANAI_KOMOKU1,
				    WMG12.SHANAI_KOMOKU2,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '522' AND CODE_VALUE = WMG12.TOKUREI_SHASAI_FLG) AS TOKUREI_SHASAI_FLG_NM,
				    WMG12.USE_KAGAKU_HENKO_FLG,
				    MG1.BOSHU_KBN,
				    WMG12.JOJO_KBN_TO,
				    WMG12.JOJO_KBN_DA,
				    WMG12.JOJO_KBN_ME,
				    WMG12.JOJO_KBN_FU,
				    WMG12.JOJO_KBN_SA,
				    WMG12.JOJO_KBN_JA
				FROM cb_mgr_khn_ruiseki wmg12, mgr_sts mg0, mgr_kihon mg1
LEFT OUTER JOIN mhakkotai m01 ON (MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD AND '1' = M01.SHORI_KBN)
WHERE MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG0.MGR_CD AND MG1.ITAKU_KAISHA_CD = WMG12.ITAKU_KAISHA_CD AND MG1.MGR_CD = WMG12.MGR_CD    AND MG0.MASSHO_FLG = '0' AND MG0.SHORI_KBN = '1' AND MG1.JTK_KBN != '2' AND WMG12.TEKIYOST_YMD = l_inTekiyoYmd AND WMG12.SEQ_NO = l_inSeqNo AND MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = l_inMgrCd;
	--前回適用日分取得
	prevCurMeisai1 CURSOR FOR
				SELECT
				    MG1.ITAKU_KAISHA_CD,
				    MG1.MGR_CD,
				    MG1.ISIN_CD,
				    WMG12.KK_MGR_CD,
				    WMG12.TEKIYOST_YMD,
				    WMG12.KK_TSUCHI_YMD,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '176' AND CODE_VALUE = WMG12.KK_PHASE || WMG12.KK_STAT) AS KK_STAT_NM,
				    WMG12.HAKKODAIRI_CD,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.HAKKODAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.HAKKODAIRI_CD, 2) = VM02.BANK_CD ) AS HAKKODAIRI_RNM,
				    WMG12.SHRDAIRI_CD,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHRDAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHRDAIRI_CD, 2) = VM02.BANK_CD ) AS SHRDAIRI_RNM,
				    WMG12.SKN_KESSAI_CD,
				    pkIpaName.getSknKessaiRnm(WMG12.ITAKU_KAISHA_CD, WMG12.SKN_KESSAI_CD) AS SKNKESSAI_RNM,
				    WMG12.MGR_NM,
				    WMG12.KK_HAKKOSHA_RNM,
				    WMG12.KAIGO_ETC,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '528' AND CODE_VALUE = WMG12.BOSHU_KBN) AS BOSHU_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_TO) AS JOJO_KBN_TO_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_DA) AS JOJO_KBN_DA_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_ME) AS JOJO_KBN_ME_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_FU) AS JOJO_KBN_FU_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_SA) AS JOJO_KBN_SA_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '599' AND CODE_VALUE = WMG12.JOJO_KBN_JA) AS JOJO_KBN_JA_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '514' AND CODE_VALUE = WMG12.SAIKEN_SHURUI) AS SAIKEN_SHURUI_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '527' AND CODE_VALUE = WMG12.HOSHO_KBN) AS HOSHO_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '519' AND CODE_VALUE = WMG12.TANPO_KBN) AS TANPO_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '513' AND CODE_VALUE = WMG12.GODOHAKKO_FLG) AS GODOHAKKO_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '530' AND CODE_VALUE = WMG12.RETSUTOKU_UMU_FLG) AS RETSUTOKU_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '517' AND CODE_VALUE = WMG12.SKNNZISNTOKU_UMU_FLG) AS SKNNZISNTOKU_UMU_FLG_NM,
				    WMG12.BOSHU_ST_YMD,
				    WMG12.HAKKO_YMD,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '518' AND CODE_VALUE = WMG12.UCHIKIRI_HAKKO_FLG) AS UCHIKIRI_HAKKO_FLG_NM,
				    WMG12.KAKUSHASAI_KNGK,
				    WMG12.SHASAI_TOTAL,
				    CASE WHEN WMG12.SHOKAN_PREMIUM=0 THEN  NULL  ELSE WMG12.SHOKAN_PREMIUM END  AS SHOKAN_PREMIUM, -- 償還プレミアムが０のときは NULL にする
				    WMG12.SHOKAN_PREMIUM + WMG12.KAKUSHASAI_KNGK AS SHOKAN_KAGAKU,
				    WMG12.FULLSHOKAN_KJT,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '101' AND CODE_VALUE = WMG12.CALLALL_UMU_FLG) AS CALLALL_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '101' AND CODE_VALUE = WMG12.PUTUMU_FLG) AS PUTUMU_FLG_NM,
				    SUBSTR(WMG12.SHASAI_KANRI_CD1, 2) AS SHASAI_KANRI_CD1,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD1, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD1, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM1,
				    SUBSTR(WMG12.SHASAI_KANRI_CD2, 2) AS SHASAI_KANRI_CD2,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD2, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD2, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM2,
				    SUBSTR(WMG12.SHASAI_KANRI_CD3, 2) AS SHASAI_KANRI_CD3,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD3, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD3, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM3,
				    SUBSTR(WMG12.SHASAI_KANRI_CD4, 2) AS SHASAI_KANRI_CD4,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD4, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD4, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM4,
				    SUBSTR(WMG12.SHASAI_KANRI_CD5, 2) AS SHASAI_KANRI_CD5,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD5, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD5, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM5,
				    SUBSTR(WMG12.SHASAI_KANRI_CD6, 2) AS SHASAI_KANRI_CD6,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD6, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD6, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM6,
				    SUBSTR(WMG12.SHASAI_KANRI_CD7, 2) AS SHASAI_KANRI_CD7,
				     (SELECT VM02.BANK_RNM
				        FROM VMBANK VM02
				       WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				         AND SUBSTR(WMG12.SHASAI_KANRI_CD7, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				         AND SUBSTR(WMG12.SHASAI_KANRI_CD7, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM7,
				    SUBSTR(WMG12.SHASAI_KANRI_CD8, 2) AS SHASAI_KANRI_CD8,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD8, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD8, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM8,
				    SUBSTR(WMG12.SHASAI_KANRI_CD9, 2) AS SHASAI_KANRI_CD9,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD9, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD9, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM9,
				    SUBSTR(WMG12.SHASAI_KANRI_CD10, 2) AS SHASAI_KANRI_CD10,
				    (SELECT VM02.BANK_RNM
				       FROM VMBANK VM02
				      WHERE WMG12.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD10, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				        AND SUBSTR(WMG12.SHASAI_KANRI_CD10, 2) = VM02.BANK_CD ) AS SHASAI_KANRI_RNM10,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '525' AND CODE_VALUE = WMG12.PARTHAKKO_UMU_FLG) AS PARTHAKKO_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '506' AND CODE_VALUE = WMG12.KYUJITSU_KBN) AS KYUJITSU_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '529' AND CODE_VALUE = WMG12.RITSUKE_WARIBIKI_KBN) AS RITSUKE_WARIBIKI_KBN_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '142' AND CODE_VALUE = WMG12.NENRBR_CNT) AS NENRBR_CNT_NM,
				    WMG12.RBR_DD,
				    WMG12.ST_RBR_KJT,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '515' AND CODE_VALUE = WMG12.LAST_RBR_FLG) AS LAST_RBR_FLG_NM,
				    (WMG12.RIRITSU)::numeric  AS RIRITSU,
				    CASE WHEN WMG12.TSUKARISHI_KNGK_FAST=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_FAST)::numeric  END  AS TSUKARISHI_KNGK_FAST, -- 1通貨あたりの利子金額（初期）が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_NORM=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_NORM)::numeric  END  AS TSUKARISHI_KNGK_NORM, -- 1通貨あたりの利子金額（通常）が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_LAST=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_LAST)::numeric  END  AS TSUKARISHI_KNGK_LAST, -- 1通貨あたりの利子金額（終期）が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_FAST_S=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_FAST_S)::numeric  END  AS TSUKARISHI_KNGK_FAST_S, -- 1通貨あたりの利子金額（初期）算出値が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_NORM_S=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_NORM_S)::numeric  END  AS TSUKARISHI_KNGK_NORM_S, -- 1通貨あたりの利子金額（通常）算出値が０のときは NULL にする
				    CASE WHEN WMG12.TSUKARISHI_KNGK_LAST_S=0 THEN  NULL  ELSE (WMG12.TSUKARISHI_KNGK_LAST_S)::numeric  END  AS TSUKARISHI_KNGK_LAST_S, -- 1通貨あたりの利子金額（終期）算出値が０のときは NULL にする
				    WMG12.RBR_KJT_MD1,
				    WMG12.RBR_KJT_MD2,
				    WMG12.RBR_KJT_MD3,
				    WMG12.RBR_KJT_MD4,
				    WMG12.RBR_KJT_MD5,
				    WMG12.RBR_KJT_MD6,
				    WMG12.RBR_KJT_MD7,
				    WMG12.RBR_KJT_MD8,
				    WMG12.RBR_KJT_MD9,
				    WMG12.RBR_KJT_MD10,
				    WMG12.RBR_KJT_MD11,
				    WMG12.RBR_KJT_MD12,
				    WMG12.WRNT_TOTAL,
				    WMG12.WRNT_USE_KAGAKU_KETTEI_YMD,
				    WMG12.WRNT_USE_ST_YMD,
				    WMG12.WRNT_USE_ED_YMD,
				    WMG12.WRNT_HAKKO_KAGAKU,
				    WMG12.WRNT_USE_KAGAKU,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '596' AND CODE_VALUE = WMG12.USE_SEIKYU_UKE_BASHO) AS USE_SEIKYU_UKE_BASHO_NM,
				    WMG12.WRNT_BIKO,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '600' AND CODE_VALUE = WMG12.SHTK_JK_UMU_FLG) AS SHTK_JK_UMU_FLG_NM,
				    WMG12.SHTK_JK_YMD,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '597' AND CODE_VALUE = WMG12.SHTK_TAIKA_SHURUI) AS SHTK_TAIKA_SHURUI_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '601' AND CODE_VALUE = WMG12.HASU_SHOKAN_UMU_FLG) AS HASU_SHOKAN_UMU_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '505' AND CODE_VALUE = WMG12.KK_KANYO_FLG) AS KK_KANYO_FLG_NM,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '511' AND CODE_VALUE = WMG12.KOBETSU_SHONIN_SAIYO_FLG) AS KOBETSU_SHONIN_SAIYO_FLG_NM,
				    WMG12.SHANAI_KOMOKU1,
				    WMG12.SHANAI_KOMOKU2,
				    (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '522' AND CODE_VALUE = WMG12.TOKUREI_SHASAI_FLG) AS TOKUREI_SHASAI_FLG_NM,
				    WMG12.USE_KAGAKU_HENKO_FLG
				FROM cb_mgr_khn_ruiseki wmg12, mgr_sts mg0, mgr_kihon mg1
LEFT OUTER JOIN mhakkotai m01 ON (MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD AND '1' = M01.SHORI_KBN)
WHERE MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG0.MGR_CD AND MG1.ITAKU_KAISHA_CD = WMG12.ITAKU_KAISHA_CD AND MG1.MGR_CD = WMG12.MGR_CD    AND MG0.MASSHO_FLG = '0' AND MG0.SHORI_KBN = '1' AND MG1.JTK_KBN != '2' AND CASE WHEN WMG12.TEKIYOST_YMD='99999999' THEN  WMG12.KK_TSUCHI_YMD  ELSE WMG12.TEKIYOST_YMD END  || WMG12.TEKIYOST_YMD || LPAD(WMG12.SEQ_NO::text, 10, '0') =
				            (SELECT MAX(CASE WHEN WK.TEKIYOST_YMD='99999999' THEN  WK.KK_TSUCHI_YMD  ELSE WK.TEKIYOST_YMD END  || WK.TEKIYOST_YMD || LPAD(WK.SEQ_NO::text, 10, '0'))
				               FROM CB_MGR_KHN_RUISEKI WK
				              WHERE CASE WHEN l_inTekiyoYmd='99999999' THEN  coalesce(l_inKkTsuchiYmd, l_inGyomuYmd)  ELSE l_inTekiyoYmd END  || l_inTekiyoYmd || LPAD(l_inSeqNo::text, 10, '0') >
				              		CASE WHEN WK.TEKIYOST_YMD='99999999' THEN  WK.KK_TSUCHI_YMD  ELSE WK.TEKIYOST_YMD END  || WK.TEKIYOST_YMD || LPAD(WK.SEQ_NO::text, 10, '0')
				                AND WK.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
				                AND WK.MGR_CD = MG1.MGR_CD ) AND MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = l_inMgrCd;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータチェック
	-- 委託会社コード
	IF coalesce(l_inItakuKaishaCd::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROCEDURE_ID, '委託会社コード');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- ユーザID
	IF coalesce(l_inUserId::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROCEDURE_ID, 'ユーザID');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- 帳票区分
	IF coalesce(l_inChohyoKbn::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROCEDURE_ID, '帳票区分');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- 業務日付
	IF coalesce(l_inGyomuYmd::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROCEDURE_ID, '業務日付');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- 銘柄コード
	IF coalesce(l_inMgrCd::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROCEDURE_ID, '銘柄コード');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- 適用日
	IF coalesce(l_inTekiyoYmd::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROCEDURE_ID, '適用日');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- シーケンスＮｏ
	IF coalesce(l_inSeqNo::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROCEDURE_ID, 'シーケンスＮｏ');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- カウンタの初期化
	gCnt := 0;
	-- 委託会社略名取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN BANK_RNM  ELSE ' ' END
		INTO STRICT gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
	-- 帳票ワークテーブル削除処理
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID IN (C_CHOHYO_ID1, C_CHOHYO_ID2, C_CHOHYO_ID3);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_ID1);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_ID2);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_ID3);
	-- データ取得
	FOR thisRecMeisai IN thisCurMeisai
	LOOP
		-- CB-00289
		-- 機構通知日：総額買取型で行使価額のみ変更の場合は「−」
		gKkTsuchiYmd := thisRecMeisai.KK_TSUCHI_YMD;
		IF thisRecMeisai.USE_KAGAKU_HENKO_FLG = '2' THEN
			gKkTsuchiYmd := '−';
		END IF;
		-- 明細レコード追加
		v_item := NULL;
		v_item.l_inItem001 := l_inUserId::varchar;
		v_item.l_inItem002 := gItakuKaishaRnm::varchar;
		v_item.l_inItem003 := thisRecMeisai.KK_STAT_NM::varchar;
		v_item.l_inItem004 := l_inMgrCd::varchar;
		v_item.l_inItem005 := thisRecMeisai.ISIN_CD::varchar;
		v_item.l_inItem006 := l_inTekiyoYmd::varchar;
		v_item.l_inItem007 := thisRecMeisai.KK_MGR_CD::varchar;
		v_item.l_inItem008 := thisRecMeisai.HAKKODAIRI_CD::varchar;
		v_item.l_inItem009 := thisRecMeisai.HAKKODAIRI_RNM::varchar;
		v_item.l_inItem010 := thisRecMeisai.SHRDAIRI_CD::varchar;
		v_item.l_inItem011 := thisRecMeisai.SHRDAIRI_RNM::varchar;
		v_item.l_inItem012 := thisRecMeisai.SKN_KESSAI_CD::varchar;
		v_item.l_inItem013 := thisRecMeisai.SKNKESSAI_RNM::varchar;
		v_item.l_inItem014 := thisRecMeisai.MGR_NM::varchar;
		v_item.l_inItem015 := thisRecMeisai.KK_HAKKOSHA_RNM::varchar;
		v_item.l_inItem016 := thisRecMeisai.KAIGO_ETC::varchar;
		v_item.l_inItem017 := thisRecMeisai.BOSHU_KBN_NM::varchar;
		v_item.l_inItem018 := thisRecMeisai.JOJO_KBN_TO_NM::varchar;
		v_item.l_inItem019 := thisRecMeisai.JOJO_KBN_DA_NM::varchar;
		v_item.l_inItem020 := thisRecMeisai.JOJO_KBN_ME_NM::varchar;
		v_item.l_inItem021 := thisRecMeisai.JOJO_KBN_FU_NM::varchar;
		v_item.l_inItem022 := thisRecMeisai.JOJO_KBN_SA_NM::varchar;
		v_item.l_inItem023 := thisRecMeisai.JOJO_KBN_JA_NM::varchar;
		v_item.l_inItem024 := thisRecMeisai.SAIKEN_SHURUI_NM::varchar;
		v_item.l_inItem025 := thisRecMeisai.HOSHO_KBN_NM::varchar;
		v_item.l_inItem026 := thisRecMeisai.TANPO_KBN_NM::varchar;
		v_item.l_inItem027 := thisRecMeisai.GODOHAKKO_FLG_NM::varchar;
		v_item.l_inItem028 := thisRecMeisai.RETSUTOKU_UMU_FLG_NM::varchar;
		v_item.l_inItem029 := thisRecMeisai.SKNNZISNTOKU_UMU_FLG_NM::varchar;
		v_item.l_inItem030 := thisRecMeisai.BOSHU_ST_YMD::varchar;
		v_item.l_inItem031 := thisRecMeisai.HAKKO_YMD::varchar;
		v_item.l_inItem032 := thisRecMeisai.UCHIKIRI_HAKKO_FLG_NM::varchar;
		v_item.l_inItem033 := thisRecMeisai.KAKUSHASAI_KNGK::varchar;
		v_item.l_inItem034 := thisRecMeisai.SHASAI_TOTAL::varchar;
		v_item.l_inItem035 := C_CHOHYO_ID1::varchar;
		v_item.l_inItem036 := gKkTsuchiYmd::varchar;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar,
			l_inUserId     => l_inUserId::varchar,
			l_inChohyoKbn  => l_inChohyoKbn::varchar,
			l_inSakuseiYmd => l_inGyomuYmd::varchar,
			l_inChohyoId   => C_CHOHYO_ID1::varchar,
			l_inSeqNo      => 1,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId::varchar,
			l_inSakuseiId  => l_inUserId::varchar
		);
		-- 明細レコード追加
		v_item := NULL;
		v_item.l_inItem001 := l_inUserId::varchar;
		v_item.l_inItem002 := gItakuKaishaRnm::varchar;
		v_item.l_inItem003 := l_inMgrCd::varchar;
		v_item.l_inItem004 := thisRecMeisai.FULLSHOKAN_KJT::varchar;
		v_item.l_inItem005 := thisRecMeisai.SHOKAN_PREMIUM::varchar;
		v_item.l_inItem006 := thisRecMeisai.SHOKAN_KAGAKU::varchar;
		v_item.l_inItem007 := thisRecMeisai.CALLALL_UMU_FLG_NM::varchar;
		v_item.l_inItem008 := thisRecMeisai.PUTUMU_FLG_NM::varchar;
		v_item.l_inItem009 := thisRecMeisai.SHASAI_KANRI_CD1::varchar;
		v_item.l_inItem010 := thisRecMeisai.SHASAI_KANRI_RNM1::varchar;
		v_item.l_inItem011 := thisRecMeisai.SHASAI_KANRI_CD2::varchar;
		v_item.l_inItem012 := thisRecMeisai.SHASAI_KANRI_RNM2::varchar;
		v_item.l_inItem013 := thisRecMeisai.SHASAI_KANRI_CD3::varchar;
		v_item.l_inItem014 := thisRecMeisai.SHASAI_KANRI_RNM3::varchar;
		v_item.l_inItem015 := thisRecMeisai.SHASAI_KANRI_CD4::varchar;
		v_item.l_inItem016 := thisRecMeisai.SHASAI_KANRI_RNM4::varchar;
		v_item.l_inItem017 := thisRecMeisai.SHASAI_KANRI_CD5::varchar;
		v_item.l_inItem018 := thisRecMeisai.SHASAI_KANRI_RNM5::varchar;
		v_item.l_inItem019 := thisRecMeisai.SHASAI_KANRI_CD6::varchar;
		v_item.l_inItem020 := thisRecMeisai.SHASAI_KANRI_RNM6::varchar;
		v_item.l_inItem021 := thisRecMeisai.SHASAI_KANRI_CD7::varchar;
		v_item.l_inItem022 := thisRecMeisai.SHASAI_KANRI_RNM7::varchar;
		v_item.l_inItem023 := thisRecMeisai.SHASAI_KANRI_CD8::varchar;
		v_item.l_inItem024 := thisRecMeisai.SHASAI_KANRI_RNM8::varchar;
		v_item.l_inItem025 := thisRecMeisai.SHASAI_KANRI_CD9::varchar;
		v_item.l_inItem026 := thisRecMeisai.SHASAI_KANRI_RNM9::varchar;
		v_item.l_inItem027 := thisRecMeisai.SHASAI_KANRI_CD10::varchar;
		v_item.l_inItem028 := thisRecMeisai.SHASAI_KANRI_RNM10::varchar;
		v_item.l_inItem029 := thisRecMeisai.PARTHAKKO_UMU_FLG_NM::varchar;
		v_item.l_inItem030 := thisRecMeisai.KYUJITSU_KBN_NM::varchar;
		v_item.l_inItem031 := thisRecMeisai.RITSUKE_WARIBIKI_KBN_NM::varchar;
		v_item.l_inItem032 := thisRecMeisai.NENRBR_CNT_NM::varchar;
		v_item.l_inItem033 := thisRecMeisai.RBR_DD::varchar;
		v_item.l_inItem034 := thisRecMeisai.ST_RBR_KJT::varchar;
		v_item.l_inItem035 := thisRecMeisai.LAST_RBR_FLG_NM::varchar;
		v_item.l_inItem036 := thisRecMeisai.RIRITSU::varchar;
		v_item.l_inItem037 := thisRecMeisai.TSUKARISHI_KNGK_FAST::varchar;
		v_item.l_inItem038 := thisRecMeisai.TSUKARISHI_KNGK_NORM::varchar;
		v_item.l_inItem039 := thisRecMeisai.TSUKARISHI_KNGK_LAST::varchar;
		v_item.l_inItem040 := thisRecMeisai.TSUKARISHI_KNGK_FAST_S::varchar;
		v_item.l_inItem041 := thisRecMeisai.TSUKARISHI_KNGK_NORM_S::varchar;
		v_item.l_inItem042 := thisRecMeisai.TSUKARISHI_KNGK_LAST_S::varchar;
		v_item.l_inItem043 := thisRecMeisai.KK_KANYO_FLG_NM::varchar;
		v_item.l_inItem044 := thisRecMeisai.KOBETSU_SHONIN_SAIYO_FLG_NM::varchar;
		v_item.l_inItem045 := thisRecMeisai.RBR_KJT_MD1::varchar;
		v_item.l_inItem046 := thisRecMeisai.RBR_KJT_MD2::varchar;
		v_item.l_inItem047 := thisRecMeisai.RBR_KJT_MD3::varchar;
		v_item.l_inItem048 := thisRecMeisai.RBR_KJT_MD4::varchar;
		v_item.l_inItem049 := thisRecMeisai.RBR_KJT_MD5::varchar;
		v_item.l_inItem050 := thisRecMeisai.RBR_KJT_MD6::varchar;
		v_item.l_inItem051 := '（各社債の金額あたり）'::varchar;
		v_item.l_inItem052 := '（各社債の金額あたり）'::varchar;
		v_item.l_inItem053 := '（01〜31 ※99:月末日）'::varchar;
		v_item.l_inItem054 := C_CHOHYO_ID1::varchar;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar,
			l_inUserId     => l_inUserId::varchar,
			l_inChohyoKbn  => l_inChohyoKbn::varchar,
			l_inSakuseiYmd => l_inGyomuYmd::varchar,
			l_inChohyoId   => C_CHOHYO_ID2::varchar,
			l_inSeqNo      => 1,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId::varchar,
			l_inSakuseiId  => l_inUserId::varchar
		);
		-- CB-00289
		-- 行使価額：総額買取型の場合は機構送信対象外
		SELECT BOSHU_KBN,
		       JOJO_KBN_TO,
		       JOJO_KBN_DA,
		       JOJO_KBN_ME,
		       JOJO_KBN_FU,
		       JOJO_KBN_SA,
		       JOJO_KBN_JA
		  INTO STRICT gBoshuKbn,
		       gJojoKbnTo,
		       gJojoKbnDa,
		       gJojoKbnMe,
		       gJojoKbnFu,
		       gJojoKbnSa,
		       gJojoKbnJa
		  FROM CB_MGR_KHN_RUISEKI
		 WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
		   AND MGR_CD          = l_inMgrCd
		   AND KK_PHASE        = 'M1';
		IF gBoshuKbn = 'D' AND gJojoKbnTo = '0'
		   AND gJojoKbnMe = '0' AND gJojoKbnFu = '0' AND gJojoKbnSa = '0' THEN
			gUseKagakuHenkoFlgKf1 := '1';
		END IF;
		-- CB-00289
		-- 社内処理用項目１：総額買取型で行使価額のみ変更の場合は機構送信対象外
		IF thisRecMeisai.USE_KAGAKU_HENKO_FLG = '2' THEN
			gUseKagakuHenkoFlgKf2 := '1';
		END IF;
		-- 明細レコード追加
		v_item := NULL;
		v_item.l_inItem001 := l_inUserId::varchar;
		v_item.l_inItem002 := gItakuKaishaRnm::varchar;
		v_item.l_inItem003 := l_inMgrCd::varchar;
		v_item.l_inItem004 := thisRecMeisai.RBR_KJT_MD7::varchar;
		v_item.l_inItem005 := thisRecMeisai.RBR_KJT_MD8::varchar;
		v_item.l_inItem006 := thisRecMeisai.RBR_KJT_MD9::varchar;
		v_item.l_inItem007 := thisRecMeisai.RBR_KJT_MD10::varchar;
		v_item.l_inItem008 := thisRecMeisai.RBR_KJT_MD11::varchar;
		v_item.l_inItem009 := thisRecMeisai.RBR_KJT_MD12::varchar;
		v_item.l_inItem010 := thisRecMeisai.WRNT_TOTAL::varchar;
		v_item.l_inItem011 := thisRecMeisai.WRNT_USE_KAGAKU_KETTEI_YMD::varchar;
		v_item.l_inItem012 := thisRecMeisai.WRNT_USE_ST_YMD::varchar;
		v_item.l_inItem013 := thisRecMeisai.WRNT_USE_ED_YMD::varchar;
		v_item.l_inItem014 := thisRecMeisai.WRNT_HAKKO_KAGAKU::varchar;
		v_item.l_inItem015 := thisRecMeisai.WRNT_USE_KAGAKU::varchar;
		v_item.l_inItem016 := thisRecMeisai.USE_SEIKYU_UKE_BASHO_NM::varchar;
		v_item.l_inItem017 := thisRecMeisai.WRNT_BIKO::varchar;
		v_item.l_inItem018 := thisRecMeisai.SHTK_JK_UMU_FLG_NM::varchar;
		v_item.l_inItem019 := thisRecMeisai.SHTK_JK_YMD::varchar;
		v_item.l_inItem020 := thisRecMeisai.SHTK_TAIKA_SHURUI_NM::varchar;
		v_item.l_inItem021 := thisRecMeisai.HASU_SHOKAN_UMU_FLG_NM::varchar;
		v_item.l_inItem022 := thisRecMeisai.SHANAI_KOMOKU1::varchar;
		v_item.l_inItem023 := thisRecMeisai.SHANAI_KOMOKU2::varchar;
		v_item.l_inItem024 := thisRecMeisai.TOKUREI_SHASAI_FLG_NM::varchar;
		v_item.l_inItem025 := C_CHOHYO_ID1::varchar;
		v_item.l_inItem026 := gUseKagakuHenkoFlgKf1::varchar;
		v_item.l_inItem027 := gUseKagakuHenkoFlgKf2::varchar;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar,
			l_inUserId     => l_inUserId::varchar,
			l_inChohyoKbn  => l_inChohyoKbn::varchar,
			l_inSakuseiYmd => l_inGyomuYmd::varchar,
			l_inChohyoId   => C_CHOHYO_ID3::varchar,
			l_inSeqNo      => 1,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId::varchar,
			l_inSakuseiId  => l_inUserId::varchar
		);
		gCnt := gCnt + 1;
	END LOOP;
	-- 今回適用日が取得できない場合、対象データなし
	IF gCnt = 0 THEN
		-- 帳票ワーク登録
		v_item := NULL;
		v_item.l_inItem001 := l_inUserId::varchar;
		v_item.l_inItem002 := gItakuKaishaRnm::varchar;
		v_item.l_inItem035 := C_CHOHYO_ID1::varchar;
		v_item.l_inItem037 := '対象データなし'::varchar;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar,
			l_inUserId     => l_inUserId::varchar,
			l_inChohyoKbn  => l_inChohyoKbn::varchar,
			l_inSakuseiYmd => l_inGyomuYmd::varchar,
			l_inChohyoId   => C_CHOHYO_ID1::varchar,
			l_inSeqNo      => 1,
			l_inHeaderFlg  => 1,
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId::varchar,
			l_inSakuseiId  => l_inUserId::varchar
		);
	ELSE
		-- データ取得
		FOR prevRecMeisai1 IN prevCurMeisai1
		LOOP
			-- CB-00289
			-- 機構通知日：総額買取型で行使価額のみ変更の場合は「−」
			gKkTsuchiYmd := prevRecMeisai1.KK_TSUCHI_YMD;
			IF prevRecMeisai1.USE_KAGAKU_HENKO_FLG = '2' THEN
				gKkTsuchiYmd := '−';
			END IF;
			-- 明細レコード追加
			v_item := NULL;
			v_item.l_inItem001 := l_inUserId::varchar;
			v_item.l_inItem002 := gItakuKaishaRnm::varchar;
			v_item.l_inItem003 := prevRecMeisai1.KK_STAT_NM::varchar;
			v_item.l_inItem004 := l_inMgrCd::varchar;
			v_item.l_inItem005 := prevRecMeisai1.ISIN_CD::varchar;
			v_item.l_inItem006 := prevRecMeisai1.TEKIYOST_YMD::varchar;
			v_item.l_inItem007 := prevRecMeisai1.KK_MGR_CD::varchar;
			v_item.l_inItem008 := prevRecMeisai1.HAKKODAIRI_CD::varchar;
			v_item.l_inItem009 := prevRecMeisai1.HAKKODAIRI_RNM::varchar;
			v_item.l_inItem010 := prevRecMeisai1.SHRDAIRI_CD::varchar;
			v_item.l_inItem011 := prevRecMeisai1.SHRDAIRI_RNM::varchar;
			v_item.l_inItem012 := prevRecMeisai1.SKN_KESSAI_CD::varchar;
			v_item.l_inItem013 := prevRecMeisai1.SKNKESSAI_RNM::varchar;
			v_item.l_inItem014 := prevRecMeisai1.MGR_NM::varchar;
			v_item.l_inItem015 := prevRecMeisai1.KK_HAKKOSHA_RNM::varchar;
			v_item.l_inItem016 := prevRecMeisai1.KAIGO_ETC::varchar;
			v_item.l_inItem017 := prevRecMeisai1.BOSHU_KBN_NM::varchar;
			v_item.l_inItem018 := prevRecMeisai1.JOJO_KBN_TO_NM::varchar;
			v_item.l_inItem019 := prevRecMeisai1.JOJO_KBN_DA_NM::varchar;
			v_item.l_inItem020 := prevRecMeisai1.JOJO_KBN_ME_NM::varchar;
			v_item.l_inItem021 := prevRecMeisai1.JOJO_KBN_FU_NM::varchar;
			v_item.l_inItem022 := prevRecMeisai1.JOJO_KBN_SA_NM::varchar;
			v_item.l_inItem023 := prevRecMeisai1.JOJO_KBN_JA_NM::varchar;
			v_item.l_inItem024 := prevRecMeisai1.SAIKEN_SHURUI_NM::varchar;
			v_item.l_inItem025 := prevRecMeisai1.HOSHO_KBN_NM::varchar;
			v_item.l_inItem026 := prevRecMeisai1.TANPO_KBN_NM::varchar;
			v_item.l_inItem027 := prevRecMeisai1.GODOHAKKO_FLG_NM::varchar;
			v_item.l_inItem028 := prevRecMeisai1.RETSUTOKU_UMU_FLG_NM::varchar;
			v_item.l_inItem029 := prevRecMeisai1.SKNNZISNTOKU_UMU_FLG_NM::varchar;
			v_item.l_inItem030 := prevRecMeisai1.BOSHU_ST_YMD::varchar;
			v_item.l_inItem031 := prevRecMeisai1.HAKKO_YMD::varchar;
			v_item.l_inItem032 := prevRecMeisai1.UCHIKIRI_HAKKO_FLG_NM::varchar;
			v_item.l_inItem033 := prevRecMeisai1.KAKUSHASAI_KNGK::varchar;
			v_item.l_inItem034 := prevRecMeisai1.SHASAI_TOTAL::varchar;
			v_item.l_inItem035 := C_CHOHYO_ID1::varchar;
			v_item.l_inItem036 := gKkTsuchiYmd::varchar;
			CALL pkPrint.insertData(
				l_inKeyCd      => l_inItakuKaishaCd::varchar,
				l_inUserId     => l_inUserId::varchar,
				l_inChohyoKbn  => l_inChohyoKbn::varchar,
				l_inSakuseiYmd => l_inGyomuYmd::varchar,
				l_inChohyoId   => C_CHOHYO_ID1::varchar,
				l_inSeqNo      => 2,
				l_inHeaderFlg  => '1',
				l_inItem       => v_item,
				l_inKousinId   => l_inUserId::varchar,
				l_inSakuseiId  => l_inUserId::varchar
			);
			-- 明細レコード追加
			v_item := NULL;
			v_item.l_inItem001 := l_inUserId::varchar;
			v_item.l_inItem002 := gItakuKaishaRnm::varchar;
			v_item.l_inItem003 := l_inMgrCd::varchar;
			v_item.l_inItem004 := prevRecMeisai1.FULLSHOKAN_KJT::varchar;
			v_item.l_inItem005 := prevRecMeisai1.SHOKAN_PREMIUM::varchar;
			v_item.l_inItem006 := prevRecMeisai1.SHOKAN_KAGAKU::varchar;
			v_item.l_inItem007 := prevRecMeisai1.CALLALL_UMU_FLG_NM::varchar;
			v_item.l_inItem008 := prevRecMeisai1.PUTUMU_FLG_NM::varchar;
			v_item.l_inItem009 := prevRecMeisai1.SHASAI_KANRI_CD1::varchar;
			v_item.l_inItem010 := prevRecMeisai1.SHASAI_KANRI_RNM1::varchar;
			v_item.l_inItem011 := prevRecMeisai1.SHASAI_KANRI_CD2::varchar;
			v_item.l_inItem012 := prevRecMeisai1.SHASAI_KANRI_RNM2::varchar;
			v_item.l_inItem013 := prevRecMeisai1.SHASAI_KANRI_CD3::varchar;
			v_item.l_inItem014 := prevRecMeisai1.SHASAI_KANRI_RNM3::varchar;
			v_item.l_inItem015 := prevRecMeisai1.SHASAI_KANRI_CD4::varchar;
			v_item.l_inItem016 := prevRecMeisai1.SHASAI_KANRI_RNM4::varchar;
			v_item.l_inItem017 := prevRecMeisai1.SHASAI_KANRI_CD5::varchar;
			v_item.l_inItem018 := prevRecMeisai1.SHASAI_KANRI_RNM5::varchar;
			v_item.l_inItem019 := prevRecMeisai1.SHASAI_KANRI_CD6::varchar;
			v_item.l_inItem020 := prevRecMeisai1.SHASAI_KANRI_RNM6::varchar;
			v_item.l_inItem021 := prevRecMeisai1.SHASAI_KANRI_CD7::varchar;
			v_item.l_inItem022 := prevRecMeisai1.SHASAI_KANRI_RNM7::varchar;
			v_item.l_inItem023 := prevRecMeisai1.SHASAI_KANRI_CD8::varchar;
			v_item.l_inItem024 := prevRecMeisai1.SHASAI_KANRI_RNM8::varchar;
			v_item.l_inItem025 := prevRecMeisai1.SHASAI_KANRI_CD9::varchar;
			v_item.l_inItem026 := prevRecMeisai1.SHASAI_KANRI_RNM9::varchar;
			v_item.l_inItem027 := prevRecMeisai1.SHASAI_KANRI_CD10::varchar;
			v_item.l_inItem028 := prevRecMeisai1.SHASAI_KANRI_RNM10::varchar;
			v_item.l_inItem029 := prevRecMeisai1.PARTHAKKO_UMU_FLG_NM::varchar;
			v_item.l_inItem030 := prevRecMeisai1.KYUJITSU_KBN_NM::varchar;
			v_item.l_inItem031 := prevRecMeisai1.RITSUKE_WARIBIKI_KBN_NM::varchar;
			v_item.l_inItem032 := prevRecMeisai1.NENRBR_CNT_NM::varchar;
			v_item.l_inItem033 := prevRecMeisai1.RBR_DD::varchar;
			v_item.l_inItem034 := prevRecMeisai1.ST_RBR_KJT::varchar;
			v_item.l_inItem035 := prevRecMeisai1.LAST_RBR_FLG_NM::varchar;
			v_item.l_inItem036 := prevRecMeisai1.RIRITSU::varchar;
			v_item.l_inItem037 := prevRecMeisai1.TSUKARISHI_KNGK_FAST::varchar;
			v_item.l_inItem038 := prevRecMeisai1.TSUKARISHI_KNGK_NORM::varchar;
			v_item.l_inItem039 := prevRecMeisai1.TSUKARISHI_KNGK_LAST::varchar;
			v_item.l_inItem040 := prevRecMeisai1.TSUKARISHI_KNGK_FAST_S::varchar;
			v_item.l_inItem041 := prevRecMeisai1.TSUKARISHI_KNGK_NORM_S::varchar;
			v_item.l_inItem042 := prevRecMeisai1.TSUKARISHI_KNGK_LAST_S::varchar;
			v_item.l_inItem043 := prevRecMeisai1.KK_KANYO_FLG_NM::varchar;
			v_item.l_inItem044 := prevRecMeisai1.KOBETSU_SHONIN_SAIYO_FLG_NM::varchar;
			v_item.l_inItem045 := prevRecMeisai1.RBR_KJT_MD1::varchar;
			v_item.l_inItem046 := prevRecMeisai1.RBR_KJT_MD2::varchar;
			v_item.l_inItem047 := prevRecMeisai1.RBR_KJT_MD3::varchar;
			v_item.l_inItem048 := prevRecMeisai1.RBR_KJT_MD4::varchar;
			v_item.l_inItem049 := prevRecMeisai1.RBR_KJT_MD5::varchar;
			v_item.l_inItem050 := prevRecMeisai1.RBR_KJT_MD6::varchar;
			v_item.l_inItem054 := C_CHOHYO_ID1::varchar;
			CALL pkPrint.insertData(
				l_inKeyCd      => l_inItakuKaishaCd::varchar,
				l_inUserId     => l_inUserId::varchar,
				l_inChohyoKbn  => l_inChohyoKbn::varchar,
				l_inSakuseiYmd => l_inGyomuYmd::varchar,
				l_inChohyoId   => C_CHOHYO_ID2::varchar,
				l_inSeqNo      => 2,
				l_inHeaderFlg  => '1',
				l_inItem       => v_item,
				l_inKousinId   => l_inUserId::varchar,
				l_inSakuseiId  => l_inUserId::varchar
			);
			-- 明細レコード追加
			-- 明細レコード追加
			v_item := NULL;
			v_item.l_inItem001 := l_inUserId::varchar;
			v_item.l_inItem002 := gItakuKaishaRnm::varchar;
			v_item.l_inItem003 := l_inMgrCd::varchar;
			v_item.l_inItem004 := prevRecMeisai1.RBR_KJT_MD7::varchar;
			v_item.l_inItem005 := prevRecMeisai1.RBR_KJT_MD8::varchar;
			v_item.l_inItem006 := prevRecMeisai1.RBR_KJT_MD9::varchar;
			v_item.l_inItem007 := prevRecMeisai1.RBR_KJT_MD10::varchar;
			v_item.l_inItem008 := prevRecMeisai1.RBR_KJT_MD11::varchar;
			v_item.l_inItem009 := prevRecMeisai1.RBR_KJT_MD12::varchar;
			v_item.l_inItem010 := prevRecMeisai1.WRNT_TOTAL::varchar;
			v_item.l_inItem011 := prevRecMeisai1.WRNT_USE_KAGAKU_KETTEI_YMD::varchar;
			v_item.l_inItem012 := prevRecMeisai1.WRNT_USE_ST_YMD::varchar;
			v_item.l_inItem013 := prevRecMeisai1.WRNT_USE_ED_YMD::varchar;
			v_item.l_inItem014 := prevRecMeisai1.WRNT_HAKKO_KAGAKU::varchar;
			v_item.l_inItem015 := prevRecMeisai1.WRNT_USE_KAGAKU::varchar;
			v_item.l_inItem016 := prevRecMeisai1.USE_SEIKYU_UKE_BASHO_NM::varchar;
			v_item.l_inItem017 := prevRecMeisai1.WRNT_BIKO::varchar;
			v_item.l_inItem018 := prevRecMeisai1.SHTK_JK_UMU_FLG_NM::varchar;
			v_item.l_inItem019 := prevRecMeisai1.SHTK_JK_YMD::varchar;
			v_item.l_inItem020 := prevRecMeisai1.SHTK_TAIKA_SHURUI_NM::varchar;
			v_item.l_inItem021 := prevRecMeisai1.HASU_SHOKAN_UMU_FLG_NM::varchar;
			v_item.l_inItem022 := prevRecMeisai1.SHANAI_KOMOKU1::varchar;
			v_item.l_inItem023 := prevRecMeisai1.SHANAI_KOMOKU2::varchar;
			v_item.l_inItem024 := prevRecMeisai1.TOKUREI_SHASAI_FLG_NM::varchar;
			v_item.l_inItem025 := C_CHOHYO_ID1::varchar;
			v_item.l_inItem026 := gUseKagakuHenkoFlgKf1::varchar;
			v_item.l_inItem027 := gUseKagakuHenkoFlgKf2::varchar;
			CALL pkPrint.insertData(
				l_inKeyCd      => l_inItakuKaishaCd::varchar,
				l_inUserId     => l_inUserId::varchar,
				l_inChohyoKbn  => l_inChohyoKbn::varchar,
				l_inSakuseiYmd => l_inGyomuYmd::varchar,
				l_inChohyoId   => C_CHOHYO_ID3::varchar,
				l_inSeqNo      => 2,
				l_inHeaderFlg  => '1',
				l_inItem       => v_item,
				l_inKousinId   => l_inUserId::varchar,
				l_inSakuseiId  => l_inUserId::varchar
			);
		END LOOP;
	END IF;	
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipw004k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inTekiyoYmd CB_MGR_KIHON.TEKIYOST_YMD%TYPE, l_inKkTsuchiYmd CB_MGR_KHN_RUISEKI.KK_TSUCHI_YMD%TYPE, l_inSeqNo CB_MGR_KHN_RUISEKI.SEQ_NO%TYPE, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;