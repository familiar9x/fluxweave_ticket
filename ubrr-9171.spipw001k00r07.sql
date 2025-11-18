




CREATE OR REPLACE PROCEDURE spipw001k00r07 ( 
    l_inMgrCd TEXT,		-- 銘柄コード
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2008
--/* 会社名:JIP
--/* 概要　:銘柄情報(ＣＢ)個別照会画面から、銘柄詳細情報リスト（期中手数料情報）を作成する。
--/* 引数　:l_inMgrCd			IN	TEXT		銘柄コード
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2008.03.13	JIP				新規作成
--/*　2019.10.16	JIP				和暦表記の箇所を西暦表記に変更
--/*
--/* @version $Id: SPIPW001K00R07.SQL,v 1.6 2013/10/16 09:21:09 touma Exp $
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					配列定義												
--==============================================================================
	-- PostgreSQL arrays (converted from Oracle associative arrays)
	-- TYPE SPIPW001K00R07_TYPE_VARCHAR2 IS TABLE OF varchar(100)	INDEX BY integer;
	-- TYPE SPIPW001K00R07_TYPE_NUMBER IS TABLE OF numeric(5)		INDEX BY integer;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID1			CONSTANT char(11)	:= 'IPW30000171';			-- 帳票ID
	REPORT_ID2			CONSTANT char(11)	:= 'IPW30000172';			-- 帳票ID
	REPORT_ID3			CONSTANT char(11)	:= 'IPW30000173';			-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(18)	:= 'ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(18)	:= 'ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(18)	:= 'ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
	
	-- 編集項目
	TESU_SASHIHIKI_KBN1	CONSTANT varchar(10)	:= '差引く';			-- 手数料差引区分
	TESU_SASHIHIKI_KBN2	CONSTANT varchar(10)	:= '差引かない';		-- 手数料差引区分
	NO_TAX				CONSTANT decimal(4,2) := 0;				-- 消費税率なし
	C_PROCEDURE_ID CONSTANT varchar(50) := 'SPIPW001K00R07';			-- プロシージャＩＤ
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21) := NULL;						-- 発行金額
	gFmtRbrKngk			varchar(21) := NULL;						-- 利払金額
	gFmtShokanKngk		varchar(21) := NULL;						-- 償還金額
	gAryJtkKbnRnm varchar(100)[];					-- 受託区分名称１〜１０
	gAryShasaiJutakuCd varchar(100)[];					-- 委託会社コード１〜１０
	gAryShasaiJutakuNm varchar(100)[];					-- 社債管理会社・受託会社略称（委託会社）１〜１０
	gAryKichuDfBunshi numeric(5)[];					-- 期中分分配率（分子）１〜１０
	gAryKichuDfBunbo numeric(5)[];					-- 信託報酬・社債管理手数料分配率（分母）１〜１０
	gYukoDataCnt						numeric := 0;				-- 有効な信託報酬・社債管理手数料情報カウント
	gTax								numeric := 0;				-- 消費税率
	gYukoTesuShuruiCd1					char(2) := NULL;			-- 選択フラグの立っている手数料種類コード１
	gYukoTesuShuruiCd2					char(2) := NULL;			-- 選択フラグの立っている手数料種類コード２
	gZNenchokyuCntNm					varchar(10) := NULL;		-- 財務代理手数料_年徴求回数
	gZChokyuKyujitsuKbnNm				varchar(40) := NULL;		-- 徴求期日の休日処理区分名称
	gZChokyuKjt1						varchar(12) := NULL;		-- 徴求期日１回目
	gZChokyuKjt2						varchar(12) := NULL;		-- 徴求期日２回目
	gZChokyuKjtEnd						varchar(12) := NULL;		-- 徴求期日最終
	gZChokyuKjt2GmatsuFlgNm				varchar(10) := NULL;		-- 財務代理手数料_徴求期日月末フラグ２内容
	gTesuSashihikiKbnNm1				varchar(10) := NULL;		-- 手数料差引区分名称
	gTesuSashihikiKbnNm2				varchar(10) := NULL;		-- 手数料差引区分名称
	gZkSsKichuTesuKngk1					decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料１回目（税込）
	gZkSsKichuTesuKngk2					decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料２回目（税込）
	gZkSsKichuTesuKngkEnd				decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料最終（税込）
	gSsKichuTesuKngk1					decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料１回目
	gSsKichuTesuKngk2					decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料２回目
	gSsKichuTesuKngkEnd					decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料最終
	gSsKichuSzei1						decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料消費税１回目
	gSsKichuSzei2						decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料消費税２回目
	gSsKichuSzeiEnd						decimal(14,2) := NULL;		-- 信託報酬・社管手数料_定額手数料消費税最終
	gZkZaimuDairiTesuKngk1				decimal(14,2) := NULL;		-- 定額財務代理人手数料１回目（税込）
	gZkZaimuDairiTesuKngk2				decimal(14,2) := NULL;		-- 定額財務代理人手数料２回目（税込）
	gZkZaimuDairiTesuKngkEnd			decimal(14,2) := NULL;		-- 定額財務代理人手数料最終（税込）
	gZaimuDairiTesuKngk1				decimal(14,2) := NULL;		-- 定額財務代理人手数料１回目
	gZaimuDairiTesuKngk2				decimal(14,2) := NULL;		-- 定額財務代理人手数料２回目
	gZaimuDairiTesuKngkEnd				decimal(14,2) := NULL;		-- 定額財務代理人手数料最終
	gZaimuDairiSzei1					decimal(14,2) := NULL;		-- 定額財務代理人手数料消費税１回目
	gZaimuDairiSzei2					decimal(14,2) := NULL;		-- 定額財務代理人手数料消費税２回目
	gZaimuDairiSzeiEnd					decimal(14,2) := NULL;		-- 定額財務代理人手数料消費税最終
	gSdNenchokyuCntNm					varchar(10) := NULL;		-- 支払代理人手数料_年徴求回数
	gSdChokyuKyujitsuKbnNm				varchar(40) := NULL;		-- 支払代理人手数料_徴求期日の休日処理区分名称
	gSdChokyuKjt1						varchar(12) := NULL;		-- 支払代理人手数料_徴求期日１回目
	gSdChokyuKjt2						varchar(12) := NULL;		-- 支払代理人手数料_徴求期日２回目
	gSdChokyuKjtEnd						varchar(12) := NULL;		-- 支払代理人手数料_徴求期日最終
	gSdChokyuKjt2GmatsuFlgNm			varchar(10) := NULL;		-- 支払代理人手数料_財務代理手数料_徴求期日月末フラグ２内容
	gSdTesuSashihikiKbnNm				varchar(10) := NULL;		-- 支払代理人手数料_手数料差引区分名称
	gSdZkDairiTesuKngk1					decimal(14,2) := NULL;		-- 支払代理人手数料_１回目（税込）
	gSdZkDairiTesuKngk2					decimal(14,2) := NULL;		-- 支払代理人手数料_２回目（税込）
	gSdZkDairiTesuKngkEnd				decimal(14,2) := NULL;		-- 支払代理人手数料_最終（税込）
	gSdDairiTesuKngk1					decimal(14,2) := NULL;		-- 支払代理人手数料_１回目
	gSdDairiTesuKngk2					decimal(14,2) := NULL;		-- 支払代理人手数料_２回目
	gSdDairiTesuKngkEnd					decimal(14,2) := NULL;		-- 支払代理人手数料_最終
	gSdDairiSzei1						decimal(14,2) := NULL;		-- 支払代理人手数料消費税_１回目
	gSdDairiSzei2						decimal(14,2) := NULL;		-- 支払代理人手数料消費税_２回目
	gSdDairiSzeiEnd						decimal(14,2) := NULL;		-- 支払代理人手数料消費税_最終
	gEtc1NenchokyuCntNm					varchar(10) := NULL;		-- その他期中手数料１_年徴求回数
	gEtc1ChokyuKyujitsuKbnNm			varchar(40) := NULL;		-- その他期中手数料１_徴求期日の休日処理区分名称
	gEtc1ChokyuKjt1						varchar(12) := NULL;		-- その他期中手数料１_徴求期日１回目
	gEtc1ChokyuKjt2						varchar(12) := NULL;		-- その他期中手数料１_徴求期日２回目
	gEtc1ChokyuKjtEnd					varchar(12) := NULL;		-- その他期中手数料１_徴求期日最終
	gEtc1ChokyuKjt2GmatsuFlgNm			varchar(10) := NULL;		-- その他期中手数料１_財務代理手数料_徴求期日月末フラグ２内容
	gEtc1TesuSashihikiKbnNm				varchar(10) := NULL;		-- その他期中手数料１_手数料差引区分名称
	gEtc1ZkDairiTesuKngk1				decimal(14,2) := NULL;		-- その他期中手数料１_１回目（税込）
	gEtc1ZkDairiTesuKngk2				decimal(14,2) := NULL;		-- その他期中手数料１_２回目（税込）
	gEtc1ZkDairiTesuKngkEnd				decimal(14,2) := NULL;		-- その他期中手数料１_最終（税込）
	gEtc1DairiTesuKngk1					decimal(14,2) := NULL;		-- その他期中手数料１_１回目
	gEtc1DairiTesuKngk2					decimal(14,2) := NULL;		-- その他期中手数料１_２回目
	gEtc1DairiTesuKngkEnd				decimal(14,2) := NULL;		-- その他期中手数料１_最終
	gEtc1DairiSzei1						decimal(14,2) := NULL;		-- その他期中手数料１消費税_１回目
	gEtc1DairiSzei2						decimal(14,2) := NULL;		-- その他期中手数料１消費税_２回目
	gEtc1DairiSzeiEnd					decimal(14,2) := NULL;		-- その他期中手数料１消費税_最終
	gGnknShrTesuCap						decimal(14,2) := NULL;		-- 元利金支払手数料 ＣＡＰ（税込）
	gRknShrTesuCap						decimal(14,2) := NULL;		-- 利金支払手数料 ＣＡＰ（税込）
	gKaiireShokyakuTesuCap				decimal(14,2) := NULL;		-- 買入消却手数料 ＣＡＰ（税込）
	-- 日付編集
	gDtSsChokyuKjt1						varchar(12) := NULL;		-- 信託報酬・社管手数料_徴求期日（1回目）
	gDtSsChokyuKjt2						varchar(12) := NULL;		-- 信託報酬・社管手数料_徴求期日（2回目）
	gDtSsChokyuKjtEnd					varchar(12) := NULL;		-- 信託報酬・社管手数料_徴求期日（最終）
	gDtSsCalcYmd1						varchar(12) := NULL;		-- 信託報酬・社管手数料_計算期間（1回目）
	gDtSsCalcYmd2						varchar(12) := NULL;		-- 信託報酬・社管手数料_計算期間（2回目）
	gDtSsCalcYmdSt						varchar(12) := NULL;		-- 信託報酬・社管手数料_計算期間（最終開始日）
	gDtSsCalcYmdEnd						varchar(12) := NULL;		-- 信託報酬・社管手数料_計算期間（最終終了日）
	gDtSsZndkKijunYmd1					varchar(12) := NULL;		-- 信託報酬・社管手数料_残高基準日（1回目）
	gDtSsZndkKijunYmd2					varchar(12) := NULL;		-- 信託報酬・社管手数料_残高基準日（2回目）
	gDtSsZndkKijunYmdEnd				varchar(12) := NULL;		-- 信託報酬・社管手数料_残高基準日（最終）
	gItakuKaishaRnm						VJIKO_ITAKU.BANK_RNM%TYPE;		-- 委託会社略称
	-- 最終承認ユーザ及び最終承認日
	gLastShoninId				VMGR_STS.LAST_SHONIN_ID%TYPE;		-- 最終承認ユーザId
	gLastShoninYmd				VMGR_STS.LAST_SHONIN_YMD%TYPE;		-- 最終承認日
	gRetenFlg MGR_STS.MGR_SEND_TAISHO_FLG%TYPE; -- レ点フラグ
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT 	VMG0.KICHU_TESU_TEISEI_YMD,							-- 期中手数料訂正日
				VMG0.KICHU_TESU_TEISEI_USER_ID,						-- 期中手数料訂正ユーザ
				VMG0.LAST_SHONIN_YMD,								-- 最終承認日
				VMG0.LAST_SHONIN_ID,								-- 最終承認ユーザ
				VMG1.MGR_CD,										-- 銘柄コード
				VMG1.ISIN_CD,										-- ＩＳＩＮコード
				VMG1.MGR_RNM,										-- 銘柄略称
				VMG1.JTK_KBN_NM,									-- 受託区分名称
				VMG1.TANPO_KBN_NM,									-- 担保区分名称
				VMG1.HAKKO_TSUKA_CD,								-- 発行通貨コード
				VMG1.RBR_TSUKA_CD,									-- 利払通貨コード
				VMG1.SHOKAN_TSUKA_CD,								-- 償還通貨コード
				VMG1.HAKKO_YMD,										-- 発行日
				VMG6.JTK_KBN_RNM,									-- 受託区分名称
				VMG6.BANK_CD,										-- 社債管理会社・受託会社コード（委託会社）
				VMG6.SHASAI_JUTAKU_NM,								-- 社債管理会社・受託会社略称（委託会社）
				CASE WHEN VMG6.KICHU_BUN_DF_BUNSHI=0 THEN NULL  ELSE VMG6.KICHU_BUN_DF_BUNSHI END  AS KICHU_BUN_DF_BUNSHI,	-- 期中分分配率（分子）
				CASE WHEN VMG8.SS_TESU_DF_BUNBO=0 THEN NULL  ELSE VMG8.SS_TESU_DF_BUNBO END  AS SS_TESU_DF_BUNBO,				-- 信託報酬・社債管理手数料分配率（分母）
				CASE WHEN VMG8.SS_TESU_BUNSHI=0 THEN NULL  ELSE VMG8.SS_TESU_BUNSHI END  AS SS_TESU_BUNSHI,					-- 信託報酬・社債管理手数料率（分子）
				CASE WHEN VMG8.SS_TESU_BUNBO=0 THEN NULL  ELSE VMG8.SS_TESU_BUNBO END  AS SS_TESU_BUNBO,						-- 信託報酬・社債管理手数料率（分母）
				MCD1.CODE_NM AS SS_NENCHOKYU_CNT_NM,				-- 年徴求回数名称
				MCD2.CODE_NM AS CALC_PATTERN_NM,					-- 計算パターン名称
				MCD3.CODE_NM AS ZNDK_KAKUTEI_KBN_NM,				-- 残高確定区分名称
				MCD4.CODE_NM AS ZENGO_KBN_NM,						-- 前取後取区分名称
				MCD5.CODE_NM AS DAY_MONTH_KBN_NM,					-- 日割月割区分名称
				MCD6.CODE_NM AS HASU_NISSU_CALC_KBN_NM,				-- 端数日数計算区分名称
				MCD41.CODE_NM AS UKEIRE_YMD_PATTERN_NM,             -- 受入日算出パターン名称
				MCD42.CODE_NM AS KICYU_KANRI_TESU_CHOKYU_TMG1NM,    -- 期中管理手数料徴求タイミング１名称
				MCD43.CODE_NM AS KICYU_KANRI_TESU_CHOKYU_TMG2NM,    -- 期中管理手数料徴求タイミング２名称
				CASE WHEN BT04.KICYU_KANRI_TESU_CHOKYU_DD=0 THEN  NULL  ELSE BT04.KICYU_KANRI_TESU_CHOKYU_DD END  AS KICYU_KANRI_TESU_CHOKYU_DD, -- 期中管理手数料徴求タイミング日数
				MCD7.CODE_NM AS CALC_YMD_KBN_NM,					-- 計算期間区分名称
				MCD8.CODE_NM AS SS_CHOKYU_KYUJITSU_KBN_NM,			-- 休日処理区分名称
				VMG8.SS_CHOKYU_KJT1,								-- 信託報酬・社管手数料_徴求期日（1回目）
				VMG8.SS_CHOKYU_KJT2,								-- 信託報酬・社管手数料_徴求期日（2回目）
				MCD9.CODE_NM AS SS_CHOKYU_KJT_2_GMATSU_FLG_NM,		-- 徴求日月末フラグ名称
				VMG8.SS_CHOKYU_KJT_END,								-- 信託報酬・社管手数料_徴求期日（最終）
				VMG8.SS_CALC_YMD1,									-- 信託報酬・社管手数料_計算期間（1回目）
				VMG8.SS_CALC_YMD2,									-- 信託報酬・社管手数料_計算期間（2回目）
				MCD10.CODE_NM AS SS_CALC_YMD_2_GMATSU_FLG_NM,		-- 計算期間月末フラグ名称,
				VMG8.SS_CALC_YMD_ST,								-- 信託報酬・社管手数料_計算期間（最終開始日）
				VMG8.SS_CALC_YMD_END,								-- 信託報酬・社管手数料_計算期間（最終終了日）
				VMG8.SS_ZNDK_KIJUN_YMD1,							-- 信託報酬・社管手数料_残高基準日（1回目）
				VMG8.SS_ZNDK_KIJUN_YMD2,							-- 信託報酬・社管手数料_残高基準日（2回目）
				MCD11.CODE_NM AS SS_ZNDK_YMD_2_GMATSU_FLG_NM,		-- 残高基準日月末フラグ名称
				VMG8.SS_ZNDK_KIJUN_YMD_END,							-- 信託報酬・社管手数料_残高基準日（最終）
				CASE WHEN VMG8.SS_TEIGAKU_TESU_KNGK_F=0 THEN NULL  ELSE VMG8.SS_TEIGAKU_TESU_KNGK_F END  AS SS_TEIGAKU_TESU_KNGK_F,	-- 信託報酬・社管手数料_定額手数料（初期）
				CASE WHEN VMG8.SS_TEIGAKU_TESU_KNGK_M=0 THEN NULL  ELSE VMG8.SS_TEIGAKU_TESU_KNGK_M END  AS SS_TEIGAKU_TESU_KNGK_M,	-- 信託報酬・社管手数料_定額手数料（中期）
				CASE WHEN VMG8.SS_TEIGAKU_TESU_KNGK_E=0 THEN NULL  ELSE VMG8.SS_TEIGAKU_TESU_KNGK_E END  AS SS_TEIGAKU_TESU_KNGK_E,	-- 信託報酬・社管手数料_定額手数料（終期）
				MCD12.CODE_NM AS DISTRI_TMG_NM,						-- 分配タイミング名称
				CASE WHEN BT04.DISTRI_TMG_DD=0 THEN  NULL  ELSE BT04.DISTRI_TMG_DD END  AS DISTRI_TMG_DD,                           -- 分配タイミング日付
				MG71.TESU_SASHIHIKI_KBN AS TESU_SASHIHIKI_KBN1,		-- 手数料差引区分(信託報酬・社債管理手数料情報)
				MCD13.CODE_NM AS KSHOKAN_KJT_FLG_NM,				-- 償還期日算入フラグ
				MCD29.CODE_NM AS KURIAGE_SHOKAN_CHOKYU_KBN,			-- 繰上償還時信託報酬徴求区分
				CASE WHEN VMG8.KURIAGE_SHOKAN_CHOKYU_DD=0 THEN NULL  ELSE VMG8.KURIAGE_SHOKAN_CHOKYU_DD END  AS KURIAGE_SHOKAN_CHOKYU_DD,	-- 繰上償還時徴求日付
				CASE WHEN VMG8.GNKN_SHR_TESU_BUNSHI=0 THEN NULL  ELSE VMG8.GNKN_SHR_TESU_BUNSHI END  AS GNKN_SHR_TESU_BUNSHI,			-- 元金支払手数料率（分子）
				CASE WHEN VMG8.GNKN_SHR_TESU_BUNBO=0 THEN NULL  ELSE VMG8.GNKN_SHR_TESU_BUNBO END  AS GNKN_SHR_TESU_BUNBO,			-- 元金支払手数料率（分母）
				CASE WHEN VMG8.GNKN_SHR_TESU_CAP=0 THEN NULL  ELSE VMG8.GNKN_SHR_TESU_CAP END  AS GNKN_SHR_TESU_CAP,					-- 元金支払手数料ＣＡＰ
				MCD18.CODE_NM AS GNKN_SHR_TESU_CHOKYU_TMG1_NM,		-- 元金支払手数料徴求タイミング１名称
				CASE WHEN VMG8.GNKN_SHR_TESU_CHOKYU_DD=0 THEN NULL  ELSE VMG8.GNKN_SHR_TESU_CHOKYU_DD END  AS GNKN_SHR_TESU_CHOKYU_DD,-- 元金支払手数料徴求タイミング日数
				MCD19.CODE_NM AS GNKN_SHR_TESU_CHOKYU_TMG2_NM,		-- 元金支払手数料徴求タイミング２名称
				CASE WHEN VMG8.RKN_SHR_TESU_BUNSHI=0 THEN NULL  ELSE VMG8.RKN_SHR_TESU_BUNSHI END  AS RKN_SHR_TESU_BUNSHI,			-- 利金支払手数料率（分子）
				CASE WHEN VMG8.RKN_SHR_TESU_BUNBO=0 THEN NULL  ELSE VMG8.RKN_SHR_TESU_BUNBO END  AS RKN_SHR_TESU_BUNBO,				-- 利金支払手数料率（分母）
				CASE WHEN VMG8.RKN_SHR_TESU_CAP=0 THEN NULL  ELSE VMG8.RKN_SHR_TESU_CAP END  AS RKN_SHR_TESU_CAP,						-- 利金支払手数料ＣＡＰ
				MCD20.CODE_NM AS RKN_SHR_TESU_CHOKYU_TMG1_NM,		-- 利金支払手数料徴求タイミング１名称
				CASE WHEN VMG8.RKN_SHR_TESU_CHOKYU_DD=0 THEN NULL  ELSE VMG8.RKN_SHR_TESU_CHOKYU_DD END  AS RKN_SHR_TESU_CHOKYU_DD,	-- 利金支払手数料徴求タイミング日数
				MCD21.CODE_NM AS RKN_SHR_TESU_CHOKYU_TMG2_NM,		-- 利金支払手数料徴求タイミング２名称
				CASE WHEN VMG8.KAIIRE_SHOKYAKU_TESU_BUNSHI=0 THEN NULL  ELSE VMG8.KAIIRE_SHOKYAKU_TESU_BUNSHI END  AS KAIIRE_SHOKYAKU_TESU_BUNSHI,-- 買入消却手数料率（分子）
				CASE WHEN VMG8.KAIIRE_SHOKYAKU_TESU_BUNBO=0 THEN NULL  ELSE VMG8.KAIIRE_SHOKYAKU_TESU_BUNBO END  AS KAIIRE_SHOKYAKU_TESU_BUNBO,	-- 買入消却手数料率（分母）
				CASE WHEN VMG8.KAIIRE_SHOKYAKU_TESU_CAP=0 THEN NULL  ELSE VMG8.KAIIRE_SHOKYAKU_TESU_CAP END  AS KAIIRE_SHOKYAKU_TESU_CAP,			-- 買入消却手数料ＣＡＰ
				MCD22.CODE_NM AS KAIIRE_SHOKYAKU_KYUJITSU_NM,		-- 買入消却手数料休日処理区分名称
				MCD23.CODE_NM AS KAIIRE_SHOKYAKU_K_CHOKYU_NM,		-- 個別徴求フラグ名称
				CASE WHEN VMG8.KAIIRE_SHOKYAKU_CHOKYU_DD=0 THEN NULL  ELSE VMG8.KAIIRE_SHOKYAKU_CHOKYU_DD END  AS KAIIRE_SHOKYAKU_CHOKYU_DD,		-- 買入消却手数料_徴求日付,
				MCD24.CODE_NM AS KAIIRE_SHOKYAKU_CHOKYU_NM,			-- 徴求日区分名称,
				MCD25.CODE_NM AS KAIIRE_SHOKYAKU_T_CHOKYU_NM,		-- 定期徴求フラグ名称
				MCD26.CODE_NM AS KAIIRE_SHOKYAKU_NENCHOKYU_NM,		-- 買入消却手数料年徴求回数名称
				VMG8.KAIIRE_SHOKYAKU_CHOKYU_MMDD,					-- 買入消却手数料_徴求月日
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN MCD14.CODE_NM
					WHEN MG72.TESU_SHURUI_CD = '22' THEN MCD15.CODE_NM
				END AS NENCHOKYU_CNT_NM,							-- 期中事務手数料年徴求回数名称／財務代理手数料年徴求回数名称
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN MCD27.CODE_NM
					WHEN MG72.TESU_SHURUI_CD = '22' THEN MCD16.CODE_NM
				END AS CHOKYU_KYUJITSU_KBN_NM,						-- 期中事務手数料休日処理区分／財務代理手数料休日処理区分
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN VMG8.KJ_CHOKYU_KJT1
					WHEN MG72.TESU_SHURUI_CD = '22' THEN VMG8.ZCHOKYU_KJT1
				END AS CHOKYU_KJT_1,								-- 期中事務手数料_徴求期日（1回目）／財務代理手数料_徴求期日（1回目）
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN VMG8.KJ_CHOKYU_KJT2
					WHEN MG72.TESU_SHURUI_CD = '22' THEN VMG8.ZCHOKYU_KJT2
				END AS CHOKYU_KJT_2,								-- 期中事務手数料_徴求期日（2回目）／財務代理手数料_徴求期日（2回目）
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN MCD28.CODE_NM
					WHEN MG72.TESU_SHURUI_CD = '22' THEN MCD17.CODE_NM
				END AS CHOKYU_KJT_2_GMATSU_FLG_NM,					-- 期中事務手数料徴求期日月末フラグ名称／財務代理手数料徴求期日月末フラグ名称
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN VMG8.KJ_CHOKYU_KJT_END
					WHEN MG72.TESU_SHURUI_CD = '22' THEN VMG8.ZCHOKYU_KJT_END
				END AS CHOKYU_KJT_END,								-- 期中事務手数料_徴求期日（最終）／財務代理手数料_徴求期日（最終）,
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN CASE WHEN VMG8.KJ_TEIGAKU_TESU_KNGK_F=0 THEN NULL  ELSE VMG8.KJ_TEIGAKU_TESU_KNGK_F END
					WHEN MG72.TESU_SHURUI_CD = '22' THEN CASE WHEN VMG8.ZTEIGAKU_TESU_KNGK_F=0 THEN NULL  ELSE VMG8.ZTEIGAKU_TESU_KNGK_F END 
				END AS TEIGAKU_TESU_KNGK_F,							-- 期中事務手数料_定額手数料（初期）／財務代理手数料_定額手数料（初期）
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN CASE WHEN VMG8.KJ_TEIGAKU_TESU_KNGK_M=0 THEN NULL  ELSE VMG8.KJ_TEIGAKU_TESU_KNGK_M END 
					WHEN MG72.TESU_SHURUI_CD = '22' THEN CASE WHEN VMG8.ZTEIGAKU_TESU_KNGK_M=0 THEN NULL  ELSE VMG8.ZTEIGAKU_TESU_KNGK_M END 
				END AS TEIGAKU_TESU_KNGK_M,							-- 期中事務手数料_定額手数料（中期）／財務代理手数料_定額手数料（中期）
				CASE
					WHEN MG72.TESU_SHURUI_CD = '21' THEN CASE WHEN VMG8.KJ_TEIGAKU_TESU_KNGK_E=0 THEN NULL  ELSE VMG8.KJ_TEIGAKU_TESU_KNGK_E END 
					WHEN MG72.TESU_SHURUI_CD = '22' THEN CASE WHEN VMG8.ZTEIGAKU_TESU_KNGK_E=0 THEN NULL  ELSE VMG8.ZTEIGAKU_TESU_KNGK_E END 
				END AS TEIGAKU_TESU_KNGK_E,							-- 期中事務手数料_定額手数料（終期）／財務代理手数料_定額手数料（終期）
				MG72.TESU_SASHIHIKI_KBN AS TESU_SASHIHIKI_KBN2,		-- 手数料差引区分
				MCD30.CODE_NM AS SD_NENCHOKYU_CNT_NM,				--支払代理人手数料_年徴求回数名称
				MCD31.CODE_NM AS SD_CHOKYU_KYUJITSU_KBN_NM,			--支払代理人手数料_徴求日休日処理区分名称
				VMG8.SD_CHOKYU_KJT1,								--支払代理人手数料_徴求期日（1回目）
				VMG8.SD_CHOKYU_KJT2,								--支払代理人手数料_徴求期日（2回目）
				MCD32.CODE_NM AS SD_CHOKYU_KJT2_GMATSU_FLG_NM,		--支払代理人手数料_徴求期日月末フラグ２名称
				VMG8.SD_CHOKYU_KJT_END,								--支払代理人手数料_徴求期日（最終）
				CASE WHEN VMG8.SD_TEIGAKU_TESU_KNGK_F=0 THEN NULL  ELSE VMG8.SD_TEIGAKU_TESU_KNGK_F END  AS SD_TEIGAKU_TESU_KNGK_F,   --支払代理人手数料_定額手数料（初期）
				CASE WHEN VMG8.SD_TEIGAKU_TESU_KNGK_M=0 THEN NULL  ELSE VMG8.SD_TEIGAKU_TESU_KNGK_M END  AS SD_TEIGAKU_TESU_KNGK_M,   --支払代理人手数料_定額手数料（中期）
				CASE WHEN VMG8.SD_TEIGAKU_TESU_KNGK_E=0 THEN NULL  ELSE VMG8.SD_TEIGAKU_TESU_KNGK_E END  AS SD_TEIGAKU_TESU_KNGK_E,   --支払代理人手数料_定額手数料（終期）
				MG752.TESU_SASHIHIKI_KBN AS SD_TESU_SASHIHIKI_KBN,	--支払代理人手数料_手数料差引区分
				MCD33.CODE_NM AS ETC1_NENCHOKYU_CNT_NM,				--その他期中手数料１_年徴求回数名称
				MCD34.CODE_NM AS ETC1_CHOKYU_KYUJITSU_KBN_NM,		--その他期中手数料１_徴求日休日処理区分名称
				VMG8.ETCKC1_CHOKYU_KJT1 AS ETC1_CHOKYU_KJT1,		--その他期中手数料１_徴求期日（1回目）
				VMG8.ETCKC1_CHOKYU_KJT2 AS ETC1_CHOKYU_KJT2,		--その他期中手数料１_徴求期日（2回目）
				MCD35.CODE_NM AS ETC1_CHOKYU_KJT2_GMATSU_FLG_NM,	--その他期中手数料１_徴求期日月末フラグ２名称
				VMG8.ETCKC1_CHOKYU_KJT_END AS ETC1_CHOKYU_KJT_END,	--その他期中手数料１_徴求期日（最終）
				CASE WHEN VMG8.ETCKC1_TEIGAKU_TESU_KNGK_F=0 THEN NULL  ELSE VMG8.ETCKC1_TEIGAKU_TESU_KNGK_F END  AS ETC1_TEIGAKU_TESU_KNGK_F,  --その他期中手数料１_定額手数料（初期）
				CASE WHEN VMG8.ETCKC1_TEIGAKU_TESU_KNGK_M=0 THEN NULL  ELSE VMG8.ETCKC1_TEIGAKU_TESU_KNGK_M END  AS ETC1_TEIGAKU_TESU_KNGK_M,  --その他期中手数料１_定額手数料（中期）
				CASE WHEN VMG8.ETCKC1_TEIGAKU_TESU_KNGK_E=0 THEN NULL  ELSE VMG8.ETCKC1_TEIGAKU_TESU_KNGK_E END  AS ETC1_TEIGAKU_TESU_KNGK_E,  --その他期中手数料１_定額手数料（終期）
				MG791.TESU_SASHIHIKI_KBN AS ETC1_TESU_SASHIHIKI_KBN,--その他期中手数料１_手数料差引区分
				CASE WHEN VMG8.WRNT_USE_TESU_BUNSHI=0 THEN NULL  ELSE VMG8.WRNT_USE_TESU_BUNSHI END  AS WRNT_USE_TESU_BUNSHI,-- 新株予約権行使手数料率（分子）
				CASE WHEN VMG8.WRNT_USE_TESU_BUNBO=0 THEN NULL  ELSE VMG8.WRNT_USE_TESU_BUNBO END  AS WRNT_USE_TESU_BUNBO,	-- 新株予約権行使手数料率（分母）
				MCD36.CODE_NM AS WRNT_USE_TESU_KYUJITSU_NM,		-- 新株予約権行使手数料休日処理区分名称
				MCD37.CODE_NM AS WRNT_USE_K_CHOKYU_NM,		-- 個別徴求フラグ名称
				CASE WHEN VMG8.WRNT_USE_CHOKYU_DD=0 THEN NULL  ELSE VMG8.WRNT_USE_CHOKYU_DD END  AS WRNT_USE_TESU_CHOKYU_DD,		-- 新株予約権行使手数料_徴求日付,
				MCD38.CODE_NM AS WRNT_USE_TESU_CHOKYU_NM,			-- 徴求日区分名称,
				MCD39.CODE_NM AS WRNT_USE_T_CHOKYU_NM,		-- 定期徴求フラグ名称
				MCD40.CODE_NM AS WRNT_USE_NENCHOKYU_NM,		-- 新株予約権行使手数料年徴求回数名称
				VMG8.WRNT_USE_CHOKYU_MMDD,					-- 新株予約権行使手数料_徴求月日
				VJ1.BANK_RNM,										-- 銀行略称
				VJ1.JIKO_DAIKO_KBN  									-- 自行代行区分
				,(SELECT CODE_NM FROM SCODE WHERE VMG0.MGR_STAT_KBN = CODE_VALUE AND CODE_SHUBETSU = '161') AS SHONIN_STAT_NM 		-- 承認状態
				,VMG0.MGR_STAT_KBN 									-- 銘柄ステータス区分
				,VMG8.SZEI_SEIKYU_KBN 								-- 消費税請求区分
				,VMG0.MGR_SEND_TAISHO_FLG 							-- 銘柄機構送信対象フラグ
		FROM vmgr_sts vmg0, vjiko_itaku vj1, vmgr_list vmg1
LEFT OUTER JOIN vmgr_jutakuginko vmg6 ON (VMG1.MGR_CD = VMG6.MGR_CD AND VMG1.ITAKU_KAISHA_CD = VMG6.ITAKU_KAISHA_CD)
LEFT OUTER JOIN mgr_tesuryo_ctl mg71 ON (VMG1.MGR_CD = MG71.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG71.ITAKU_KAISHA_CD AND gYukoTesuShuruiCd1 = MG71.TESU_SHURUI_CD)
LEFT OUTER JOIN cb_mgr_kiko_kihon wmg9 ON (VMG1.MGR_CD = WMG9.MGR_CD AND VMG1.ITAKU_KAISHA_CD = WMG9.ITAKU_KAISHA_CD)
LEFT OUTER JOIN mgr_tesuryo_ctl mg72 ON (VMG1.MGR_CD = MG72.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG72.ITAKU_KAISHA_CD AND gYukoTesuShuruiCd2 = MG72.TESU_SHURUI_CD)
LEFT OUTER JOIN mgr_tesuryo_ctl mg752 ON (VMG1.MGR_CD = MG752.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG752.ITAKU_KAISHA_CD AND '52' = MG752.TESU_SHURUI_CD)
LEFT OUTER JOIN mgr_tesuryo_ctl mg791 ON (VMG1.MGR_CD = MG791.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG791.ITAKU_KAISHA_CD AND '91' = MG791.TESU_SHURUI_CD)
, vmgr_tesuryo_prm vmg8
LEFT OUTER JOIN scode mcd1 ON (VMG8.SS_NENCHOKYU_CNT = MCD1.CODE_VALUE AND '123' = MCD1.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd2 ON (VMG8.CALC_PATTERN_CD = MCD2.CODE_VALUE AND '105' = MCD2.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd3 ON (VMG8.ZNDK_KAKUTEI_KBN = MCD3.CODE_VALUE AND '107' = MCD3.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd4 ON (VMG8.ZENGO_KBN = MCD4.CODE_VALUE AND '117' = MCD4.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd5 ON (VMG8.DAY_MONTH_KBN = MCD5.CODE_VALUE AND '120' = MCD5.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd6 ON (VMG8.HASU_NISSU_CALC_KBN = MCD6.CODE_VALUE AND '118' = MCD6.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd7 ON (VMG8.CALC_YMD_KBN = MCD7.CODE_VALUE AND '106' = MCD7.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd8 ON (VMG8.SS_CHOKYU_KYUJITSU_KBN = MCD8.CODE_VALUE AND '506' = MCD8.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd9 ON (VMG8.SS_CHOKYU_KJT2_GMATSU_FLG = MCD9.CODE_VALUE AND '172' = MCD9.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd10 ON (VMG8.SS_CALC_YMD2_GMATSU_FLG = MCD10.CODE_VALUE AND '172' = MCD10.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd11 ON (VMG8.SS_ZNDK_KIJUN_YMD2_GMATSU_FLG = MCD11.CODE_VALUE AND '172' = MCD11.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd12 ON (VMG8.DISTRI_TMG = MCD12.CODE_VALUE AND '125' = MCD12.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd13 ON (VMG8.KSHOKAN_KJT_FLG = MCD13.CODE_VALUE AND '114' = MCD13.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd14 ON (VMG8.KJ_NENCHOKYU_CNT = MCD14.CODE_VALUE AND '123' = MCD14.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd15 ON (VMG8.ZNENCHOKYU_CNT = MCD15.CODE_VALUE AND '123' = MCD15.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd16 ON (VMG8.ZCHOKYU_KYUJITSU_KBN = MCD16.CODE_VALUE AND '506' = MCD16.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd17 ON (VMG8.ZCHOKYU_KJT2_GMATSU_FLG = MCD17.CODE_VALUE AND '172' = MCD17.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd18 ON (VMG8.GNKN_SHR_TESU_CHOKYU_TMG1 = MCD18.CODE_VALUE AND '135' = MCD18.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd19 ON (VMG8.GNKN_SHR_TESU_CHOKYU_TMG2 = MCD19.CODE_VALUE AND '132' = MCD19.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd20 ON (VMG8.RKN_SHR_TESU_CHOKYU_TMG1 = MCD20.CODE_VALUE AND '135' = MCD20.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd21 ON (VMG8.RKN_SHR_TESU_CHOKYU_TMG2 = MCD21.CODE_VALUE AND '132' = MCD21.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd22 ON (VMG8.KAIIRE_SHOKYAKU_KYUJITSU_KBN = MCD22.CODE_VALUE AND '506' = MCD22.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd23 ON (VMG8.KAIIRE_SHOKYAKU_K_CHOKYU_FLG = MCD23.CODE_VALUE AND '173' = MCD23.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd24 ON (VMG8.KAIIRE_SHOKYAKU_CHOKYU_KBN = MCD24.CODE_VALUE AND '134' = MCD24.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd25 ON (VMG8.KAIIRE_SHOKYAKU_T_CHOKYU_FLG = MCD25.CODE_VALUE AND '174' = MCD25.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd26 ON (VMG8.KAIIRE_SHOKYAKU_NENCHOKYU_CNT = MCD26.CODE_VALUE AND '123' = MCD26.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd27 ON (VMG8.KJ_CHOKYU_KYUJITSU_KBN = MCD27.CODE_VALUE AND '506' = MCD27.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd28 ON (VMG8.KJ_CHOKYU_KJT2_GMATSU_FLG = MCD28.CODE_VALUE AND '172' = MCD28.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd29 ON (VMG8.KURIAGE_SHOKAN_CHOKYU_KBN = MCD29.CODE_VALUE AND '115' = MCD29.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd30 ON (VMG8.SD_NENCHOKYU_CNT = MCD30.CODE_VALUE AND '123' = MCD30.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd31 ON (VMG8.SD_CHOKYU_KYUJITSU_KBN = MCD31.CODE_VALUE AND '506' = MCD31.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd32 ON (VMG8.SD_CHOKYU_KJT2_GMATSU_FLG = MCD32.CODE_VALUE AND '172' = MCD32.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd33 ON (VMG8.ETCKC1_NENCHOKYU_CNT = MCD33.CODE_VALUE AND '123' = MCD33.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd34 ON (VMG8.ETCKC1_CHOKYU_KYUJITSU_KBN = MCD34.CODE_VALUE AND '506' = MCD34.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd35 ON (VMG8.ETCKC1_CHOKYU_KJT2_GMATSU_FLG = MCD35.CODE_VALUE AND '172' = MCD35.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd36 ON (VMG8.WRNT_USE_KYUJITSU_KBN = MCD36.CODE_VALUE AND '506' = MCD36.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd37 ON (VMG8.WRNT_USE_K_CHOKYU_FLG = MCD37.CODE_VALUE AND '173' = MCD37.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd38 ON (VMG8.WRNT_USE_CHOKYU_KBN = MCD38.CODE_VALUE AND '231' = MCD38.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd39 ON (VMG8.WRNT_USE_T_CHOKYU_FLG = MCD39.CODE_VALUE AND '174' = MCD39.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd40 ON (VMG8.WRNT_USE_CHOKYU_CNT = MCD40.CODE_VALUE AND '123' = MCD40.CODE_SHUBETSU)
, mgr_tesuryo_prm2 bt04
LEFT OUTER JOIN scode mcd41 ON (BT04.UKEIRE_YMD_PATTERN = MCD41.CODE_VALUE AND 'B08' = MCD41.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd42 ON (BT04.KICYU_KANRI_TESU_CHOKYU_TMG1 = MCD42.CODE_VALUE AND 'B09' = MCD42.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd43 ON (BT04.KICYU_KANRI_TESU_CHOKYU_TMG2 = MCD43.CODE_VALUE AND '132' = MCD43.CODE_SHUBETSU)
WHERE VMG1.MGR_CD = l_inMgrCd AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.MGR_CD = VMG0.MGR_CD AND VMG1.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD   AND VMG1.MGR_CD = VMG8.MGR_CD AND VMG1.ITAKU_KAISHA_CD = VMG8.ITAKU_KAISHA_CD               AND VJ1.KAIIN_ID = l_inItakuKaishaCd                                                                                       AND VMG1.ITAKU_KAISHA_CD = BT04.ITAKU_KAISHA_CD AND VMG1.MGR_CD = BT04.MGR_CD ORDER BY 	VMG6.JTK_KBN,
					VMG6.INPUT_NUM;
	curMeisai_noRecored CURSOR FOR
		SELECT 	VMG0.KICHU_TESU_TEISEI_YMD,							-- 期中手数料訂正日
				VMG0.KICHU_TESU_TEISEI_USER_ID,						-- 期中手数料訂正ユーザ
				VMG0.LAST_SHONIN_YMD,								-- 最終承認日
				VMG0.LAST_SHONIN_ID,								-- 最終承認ユーザ
				VMG1.MGR_CD,										-- 銘柄コード
				VMG1.ISIN_CD,										-- ＩＳＩＮコード
				VMG1.MGR_RNM,										-- 銘柄略称
				VMG1.JTK_KBN_NM,									-- 受託区分名称
				VMG1.TANPO_KBN_NM,									-- 担保区分名称
				VJ1.BANK_RNM,										-- 銀行略称
				VJ1.JIKO_DAIKO_KBN  									-- 自行代行区分
				,(SELECT CODE_NM FROM SCODE WHERE VMG0.MGR_STAT_KBN = CODE_VALUE AND CODE_SHUBETSU = '161') AS SHONIN_STAT_NM 		-- 承認状態
				,VMG0.MGR_STAT_KBN 									-- 銘柄ステータス区分
		FROM 	VMGR_LIST VMG1,
				VMGR_STS VMG0,
				VJIKO_ITAKU VJ1
		WHERE 	VMG1.MGR_CD = l_inMgrCd
		AND 	VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND 	VMG1.MGR_CD = VMG0.MGR_CD
		AND 	VMG1.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD
		AND 	VJ1.KAIIN_ID = l_inItakuKaishaCd;
	-- レコード
	recWkMeisai	RECORD;
	recMeisai_noRecored	RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID1, C_PROCEDURE_ID || 'START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inMgrCd)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID1, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID1, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND (CHOHYO_ID = REPORT_ID1
	OR		CHOHYO_ID = REPORT_ID2
	OR		CHOHYO_ID = REPORT_ID3);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID1);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID2);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID3);
	-- 配列の初期化
	FOR i IN 1..10 LOOP
		gAryJtkKbnRnm[i] := NULL;			-- 受託区分名称１〜１０
		gAryShasaiJutakuCd[i] := NULL;		-- 委託会社コード１〜１０
		gAryShasaiJutakuNm[i] := NULL;		-- 社債管理会社・受託会社略称（委託会社）１〜１０
		gAryKichuDfBunshi[i] := NULL;		-- 期中分分配率（分子）１〜１０
		gAryKichuDfBunbo[i] := NULL;		-- 信託報酬・社債管理手数料分配率（分母）１〜１０
	END LOOP;
	-- 選択フラグが立っている手数料種類コードを取得
	gYukoTesuShuruiCd1 := SPIPW001K00R07_getTesuShuruiCd(l_inMgrCd, l_inItakuKaishaCd, '11','12');
	gYukoTesuShuruiCd2 := SPIPW001K00R07_getTesuShuruiCd(l_inMgrCd, l_inItakuKaishaCd, '21','22');
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		IF gSeqNo = 1 THEN
			-- 消費税率の取得
			gTax := pkIpaZei.getShohiZei(recMeisai.HAKKO_YMD);
			-- 消費税請求区分が「１：請求する」の場合、gTaxをそのまま利用する。
			IF recMeisai.SZEI_SEIKYU_KBN = '1' THEN
				gTax := gTax;
			ELSE 	-- 消費税請求区分が「１：請求する」以外の場合、NO_TAXをgTaxへ代入する。
				gTax := NO_TAX;
			END IF;
			-- 書式フォーマットの設定
			-- 発行
			IF recMeisai.HAKKO_TSUKA_CD = 'JPY' THEN
				gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
			ELSE
				gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
			END IF;
			-- 利払
			IF recMeisai.RBR_TSUKA_CD = 'JPY' THEN
				gFmtRbrKngk := FMT_RBR_KNGK_J;
			ELSE
				gFmtRbrKngk := FMT_RBR_KNGK_F;
			END IF;
			-- 償還
			IF recMeisai.SHOKAN_TSUKA_CD = 'JPY' THEN
				gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
			ELSE
				gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
			END IF;
			-- 信託報酬・社管手数料計算 **************************************
			IF (trim(both (recMeisai.SS_TEIGAKU_TESU_KNGK_F)::text) IS NOT NULL AND (trim(both (recMeisai.SS_TEIGAKU_TESU_KNGK_F)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.SS_TEIGAKU_TESU_KNGK_F,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gSsKichuTesuKngk1,
																	gZkSsKichuTesuKngk1,
																	gSsKichuSzei1
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.SS_TEIGAKU_TESU_KNGK_M)::text) IS NOT NULL AND (trim(both (recMeisai.SS_TEIGAKU_TESU_KNGK_M)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.SS_TEIGAKU_TESU_KNGK_M,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gSsKichuTesuKngk2,
																	gZkSsKichuTesuKngk2,
																	gSsKichuSzei2
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.SS_TEIGAKU_TESU_KNGK_E)::text) IS NOT NULL AND (trim(both (recMeisai.SS_TEIGAKU_TESU_KNGK_E)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.SS_TEIGAKU_TESU_KNGK_E,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gSsKichuTesuKngkEnd,
																	gZkSsKichuTesuKngkEnd,
																	gSsKichuSzeiEnd
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			-- 財務代理人・事務手数料計算 **************************************
			gZNenchokyuCntNm := recMeisai.NENCHOKYU_CNT_NM;									-- 財務代理手数料_年徴求回数
			gZChokyuKyujitsuKbnNm := recMeisai.CHOKYU_KYUJITSU_KBN_NM;						-- 徴求期日の休日処理区分名称
			gZChokyuKjt2GmatsuFlgNm := recMeisai.CHOKYU_KJT_2_GMATSU_FLG_NM;				-- 財務代理手数料_徴求期日月末フラグ２内容
			IF (trim(both (recMeisai.TEIGAKU_TESU_KNGK_F)::text) IS NOT NULL AND (trim(both (recMeisai.TEIGAKU_TESU_KNGK_F)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.TEIGAKU_TESU_KNGK_F,		-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gZaimuDairiTesuKngk1,
																	gZkZaimuDairiTesuKngk1,
																	gZaimuDairiSzei1
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.TEIGAKU_TESU_KNGK_M)::text) IS NOT NULL AND (trim(both (recMeisai.TEIGAKU_TESU_KNGK_M)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.TEIGAKU_TESU_KNGK_M,		-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gZaimuDairiTesuKngk2,
																	gZkZaimuDairiTesuKngk2,
																	gZaimuDairiSzei2
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.TEIGAKU_TESU_KNGK_E)::text) IS NOT NULL AND (trim(both (recMeisai.TEIGAKU_TESU_KNGK_E)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.TEIGAKU_TESU_KNGK_E,		-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gZaimuDairiTesuKngkEnd,
																	gZkZaimuDairiTesuKngkEnd,
																	gZaimuDairiSzeiEnd
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			-- 支払代理人手数料計算 ********************************************
			gSdNenchokyuCntNm := recMeisai.SD_NENCHOKYU_CNT_NM;								-- 支払代理人手数料_年徴求回数
			gSdChokyuKyujitsuKbnNm := recMeisai.SD_CHOKYU_KYUJITSU_KBN_NM;					-- 支払代理人手数料_徴求期日の休日処理区分名称
			gSdChokyuKjt2GmatsuFlgNm := recMeisai.SD_CHOKYU_KJT2_GMATSU_FLG_NM;				-- 支払代理人手数料_徴求期日月末フラグ２内容
			IF (trim(both (recMeisai.SD_TEIGAKU_TESU_KNGK_F)::text) IS NOT NULL AND (trim(both (recMeisai.SD_TEIGAKU_TESU_KNGK_F)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.SD_TEIGAKU_TESU_KNGK_F,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gSdDairiTesuKngk1,
																	gSdZkDairiTesuKngk1,
																	gSdDairiSzei1
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.SD_TEIGAKU_TESU_KNGK_M)::text) IS NOT NULL AND (trim(both (recMeisai.SD_TEIGAKU_TESU_KNGK_M)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.SD_TEIGAKU_TESU_KNGK_M,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gSdDairiTesuKngk2,
																	gSdZkDairiTesuKngk2,
																	gSdDairiSzei2
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.SD_TEIGAKU_TESU_KNGK_E)::text) IS NOT NULL AND (trim(both (recMeisai.SD_TEIGAKU_TESU_KNGK_E)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.SD_TEIGAKU_TESU_KNGK_E,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gSdDairiTesuKngkEnd,
																	gSdZkDairiTesuKngkEnd,
																	gSdDairiSzeiEnd
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			-- その他期中手数料１計算 ******************************************
			gEtc1NenchokyuCntNm := recMeisai.ETC1_NENCHOKYU_CNT_NM;							-- その他期中手数料１_年徴求回数
			gEtc1ChokyuKyujitsuKbnNm := recMeisai.ETC1_CHOKYU_KYUJITSU_KBN_NM;				-- その他期中手数料１_徴求期日の休日処理区分名称
			gEtc1ChokyuKjt2GmatsuFlgNm := recMeisai.ETC1_CHOKYU_KJT2_GMATSU_FLG_NM;			-- その他期中手数料１_徴求期日月末フラグ２内容
			IF (trim(both (recMeisai.ETC1_TEIGAKU_TESU_KNGK_F)::text) IS NOT NULL AND (trim(both (recMeisai.ETC1_TEIGAKU_TESU_KNGK_F)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.ETC1_TEIGAKU_TESU_KNGK_F,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gEtc1DairiTesuKngk1,
																	gEtc1ZkDairiTesuKngk1,
																	gEtc1DairiSzei1
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.ETC1_TEIGAKU_TESU_KNGK_M)::text) IS NOT NULL AND (trim(both (recMeisai.ETC1_TEIGAKU_TESU_KNGK_M)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.ETC1_TEIGAKU_TESU_KNGK_M,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gEtc1DairiTesuKngk2,
																	gEtc1ZkDairiTesuKngk2,
																	gEtc1DairiSzei2
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			IF (trim(both (recMeisai.ETC1_TEIGAKU_TESU_KNGK_E)::text) IS NOT NULL AND (trim(both (recMeisai.ETC1_TEIGAKU_TESU_KNGK_E)::text))::text <> '') THEN
				gRtnCd := PKIPACALCTESUKNGK.GETTESUZEITEIGAKUCOMMON(l_inItakuKaishaCd,
																	recMeisai.MGR_CD,
																	recMeisai.ETC1_TEIGAKU_TESU_KNGK_E,	-- 手数料計算根拠の額面
																	recMeisai.HAKKO_TSUKA_CD,			-- 通貨コード
																	recMeisai.HAKKO_YMD,				-- 消費税取得の基準日
																	gEtc1DairiTesuKngkEnd,
																	gEtc1ZkDairiTesuKngkEnd,
																	gEtc1DairiSzeiEnd
																	);
				IF gRtnCd <> pkconstant.success() THEN
				-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--				   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := SQLERRM;
					RETURN;
				END IF;
			END IF;
			-- 各ＣＡＰを外貨に対応させる
			-- 元利金支払手数料　ＣＡＰ（償還通貨コードで判断）
			IF recMeisai.SHOKAN_TSUKA_CD = 'JPY' THEN
				-- 国内通貨
				gGnknShrTesuCap := TRUNC(recMeisai.GNKN_SHR_TESU_CAP * (1 + gTax), 0);
			ELSE
				-- 海外通貨
				gGnknShrTesuCap := TRUNC(recMeisai.GNKN_SHR_TESU_CAP * (1 + gTax), 2);
			END IF;
			-- 利金支払手数料　ＣＡＰ（利払通貨コードで判断）
			IF recMeisai.RBR_TSUKA_CD = 'JPY' THEN
				-- 国内通貨
				gRknShrTesuCap := TRUNC(recMeisai.RKN_SHR_TESU_CAP * (1 + gTax), 0);
			ELSE
				-- 海外通貨
				gRknShrTesuCap := TRUNC(recMeisai.RKN_SHR_TESU_CAP * (1 + gTax), 2);
			END IF;
			-- 買入消却手数料　ＣＡＰ（発行通貨コードで判断）
			IF recMeisai.HAKKO_TSUKA_CD = 'JPY' THEN
				-- 国内通貨
				gKaiireShokyakuTesuCap := TRUNC(recMeisai.KAIIRE_SHOKYAKU_TESU_CAP * (1 + gTax), 0);
			ELSE
				-- 海外通貨
				gKaiireShokyakuTesuCap := TRUNC(recMeisai.KAIIRE_SHOKYAKU_TESU_CAP * (1 + gTax), 2);
			END IF;
			-- 手数料差引区分を名称に変換
			IF recMeisai.TESU_SASHIHIKI_KBN1 = '1' THEN
				gTesuSashihikiKbnNm1 := TESU_SASHIHIKI_KBN1;
			ELSIF recMeisai.TESU_SASHIHIKI_KBN1 = '2' THEN
				gTesuSashihikiKbnNm1 := TESU_SASHIHIKI_KBN2;
			END IF;
			-- 財務代理手数料_年徴求回数が入力されている場合のみ、手数料差引区分を表示させる
			IF (gZNenchokyuCntNm IS NOT NULL AND gZNenchokyuCntNm::text <> '') THEN
				IF recMeisai.TESU_SASHIHIKI_KBN2 = '1' THEN
					gTesuSashihikiKbnNm2 := TESU_SASHIHIKI_KBN1;
				ELSIF recMeisai.TESU_SASHIHIKI_KBN2 = '2' THEN
					gTesuSashihikiKbnNm2 := TESU_SASHIHIKI_KBN2;
				END IF;
			ELSE
				gTesuSashihikiKbnNm2 := NULL;
			END IF;
			-- 支払代理人手数料_年徴求回数が入力されている場合のみ、手数料差引区分を表示させる
			IF (gSdNenchokyuCntNm IS NOT NULL AND gSdNenchokyuCntNm::text <> '') THEN
				IF recMeisai.SD_TESU_SASHIHIKI_KBN = '1' THEN
					gSdTesuSashihikiKbnNm := TESU_SASHIHIKI_KBN1;
				ELSIF recMeisai.SD_TESU_SASHIHIKI_KBN = '2' THEN
					gSdTesuSashihikiKbnNm := TESU_SASHIHIKI_KBN2;
				END IF;
			ELSE
				gSdTesuSashihikiKbnNm := NULL;
			END IF;
			-- その他期中手数料１_年徴求回数が入力されている場合のみ、手数料差引区分を表示させる
			IF (gEtc1NenchokyuCntNm IS NOT NULL AND gEtc1NenchokyuCntNm::text <> '') THEN
				IF recMeisai.ETC1_TESU_SASHIHIKI_KBN = '1' THEN
					gEtc1TesuSashihikiKbnNm := TESU_SASHIHIKI_KBN1;
				ELSIF recMeisai.ETC1_TESU_SASHIHIKI_KBN = '2' THEN
					gEtc1TesuSashihikiKbnNm := TESU_SASHIHIKI_KBN2;
				END IF;
			ELSE
				gEtc1TesuSashihikiKbnNm := NULL;
			END IF;
			-- 日付編集
			-- 徴求期日１回目(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.CHOKYU_KJT_1)::text) IS NOT NULL AND (trim(both (recMeisai.CHOKYU_KJT_1)::text))::text <> '') THEN
				gZChokyuKjt1 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.CHOKYU_KJT_1);
			END IF;
			-- 徴求期日２回目(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.CHOKYU_KJT_2)::text) IS NOT NULL AND (trim(both (recMeisai.CHOKYU_KJT_2)::text))::text <> '') THEN
				gZChokyuKjt2 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.CHOKYU_KJT_2);
			END IF;
			-- 徴求期日最終(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.CHOKYU_KJT_END)::text) IS NOT NULL AND (trim(both (recMeisai.CHOKYU_KJT_END)::text))::text <> '') THEN
				gZChokyuKjtEnd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.CHOKYU_KJT_END);
			END IF;
			-- 支払代理人手数料_徴求期日１回目(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SD_CHOKYU_KJT1)::text) IS NOT NULL AND (trim(both (recMeisai.SD_CHOKYU_KJT1)::text))::text <> '') THEN
				gSdChokyuKjt1 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SD_CHOKYU_KJT1);
			END IF;
			-- 支払代理人手数料_徴求期日２回目(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SD_CHOKYU_KJT2)::text) IS NOT NULL AND (trim(both (recMeisai.SD_CHOKYU_KJT2)::text))::text <> '') THEN
				gSdChokyuKjt2 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SD_CHOKYU_KJT2);
			END IF;
			-- 支払代理人手数料_徴求期日最終(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SD_CHOKYU_KJT_END)::text) IS NOT NULL AND (trim(both (recMeisai.SD_CHOKYU_KJT_END)::text))::text <> '') THEN
				gSdChokyuKjtEnd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SD_CHOKYU_KJT_END);
			END IF;
			-- その他期中手数料１_徴求期日１回目(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.ETC1_CHOKYU_KJT1)::text) IS NOT NULL AND (trim(both (recMeisai.ETC1_CHOKYU_KJT1)::text))::text <> '') THEN
				gEtc1ChokyuKjt1 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.ETC1_CHOKYU_KJT1);
			END IF;
			-- その他期中手数料１_徴求期日２回目(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.ETC1_CHOKYU_KJT2)::text) IS NOT NULL AND (trim(both (recMeisai.ETC1_CHOKYU_KJT2)::text))::text <> '') THEN
				gEtc1ChokyuKjt2 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.ETC1_CHOKYU_KJT2);
			END IF;
			-- その他期中手数料１_徴求期日最終(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.ETC1_CHOKYU_KJT_END)::text) IS NOT NULL AND (trim(both (recMeisai.ETC1_CHOKYU_KJT_END)::text))::text <> '') THEN
				gEtc1ChokyuKjtEnd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.ETC1_CHOKYU_KJT_END);
			END IF;
			-- 信託報酬・社管手数料_徴求期日（1回目）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_CHOKYU_KJT1)::text) IS NOT NULL AND (trim(both (recMeisai.SS_CHOKYU_KJT1)::text))::text <> '') THEN
				gDtSsChokyuKjt1 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_CHOKYU_KJT1);
			END IF;
			-- 信託報酬・社管手数料_徴求期日（2回目）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_CHOKYU_KJT2)::text) IS NOT NULL AND (trim(both (recMeisai.SS_CHOKYU_KJT2)::text))::text <> '') THEN
				gDtSsChokyuKjt2 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_CHOKYU_KJT2);
			END IF;
			-- 信託報酬・社管手数料_徴求期日（最終）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_CHOKYU_KJT_END)::text) IS NOT NULL AND (trim(both (recMeisai.SS_CHOKYU_KJT_END)::text))::text <> '') THEN
				gDtSsChokyuKjtEnd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_CHOKYU_KJT_END);
			END IF;
			-- 信託報酬・社管手数料_計算期間（1回目）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_CALC_YMD1)::text) IS NOT NULL AND (trim(both (recMeisai.SS_CALC_YMD1)::text))::text <> '') THEN
				gDtSsCalcYmd1 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_CALC_YMD1);
			END IF;
			-- 信託報酬・社管手数料_計算期間（2回目）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_CALC_YMD2)::text) IS NOT NULL AND (trim(both (recMeisai.SS_CALC_YMD2)::text))::text <> '') THEN
				gDtSsCalcYmd2 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_CALC_YMD2);
			END IF;
			-- 信託報酬・社管手数料_計算期間（最終開始日）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_CALC_YMD_ST)::text) IS NOT NULL AND (trim(both (recMeisai.SS_CALC_YMD_ST)::text))::text <> '') THEN
				gDtSsCalcYmdSt := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_CALC_YMD_ST);
			END IF;
			-- 信託報酬・社管手数料_計算期間（最終終了日）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_CALC_YMD_END)::text) IS NOT NULL AND (trim(both (recMeisai.SS_CALC_YMD_END)::text))::text <> '') THEN
				gDtSsCalcYmdEnd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_CALC_YMD_END);
			END IF;
			-- 信託報酬・社管手数料_残高基準日（1回目）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_ZNDK_KIJUN_YMD1)::text) IS NOT NULL AND (trim(both (recMeisai.SS_ZNDK_KIJUN_YMD1)::text))::text <> '') THEN
				gDtSsZndkKijunYmd1 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_ZNDK_KIJUN_YMD1);
			END IF;
			-- 信託報酬・社管手数料_残高基準日（2回目）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_ZNDK_KIJUN_YMD2)::text) IS NOT NULL AND (trim(both (recMeisai.SS_ZNDK_KIJUN_YMD2)::text))::text <> '') THEN
				gDtSsZndkKijunYmd2 := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_ZNDK_KIJUN_YMD2);
			END IF;
			-- 信託報酬・社管手数料_残高基準日（最終）(9999/99/99(西暦編集))
			IF (trim(both (recMeisai.SS_ZNDK_KIJUN_YMD_END)::text) IS NOT NULL AND (trim(both (recMeisai.SS_ZNDK_KIJUN_YMD_END)::text))::text <> '') THEN
				gDtSsZndkKijunYmdEnd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.SS_ZNDK_KIJUN_YMD_END);
			END IF;
			-- レコードのセット
			recWkMeisai := recMeisai;
		END IF;
		IF recMeisai.KICHU_BUN_DF_BUNSHI <> 0 THEN
			gYukoDataCnt := gYukoDataCnt + 1;
			gAryJtkKbnRnm[gYukoDataCnt] := recMeisai.JTK_KBN_RNM;				-- 受託区分名称１〜１０
			gAryShasaiJutakuCd[gYukoDataCnt] := recMeisai.BANK_CD;				-- 社債管理会社・受託会社コード１〜１０
			gAryShasaiJutakuNm[gYukoDataCnt] := recMeisai.SHASAI_JUTAKU_NM;		-- 社債管理会社・受託会社略称（委託会社）１〜１０
			gAryKichuDfBunshi[gYukoDataCnt] := recMeisai.KICHU_BUN_DF_BUNSHI;	-- 期中分分配率（分子）１〜１０
			gAryKichuDfBunbo[gYukoDataCnt] := recMeisai.SS_TESU_DF_BUNBO;		-- 信託報酬・社債管理手数料分配率（分母）１〜１０
		END IF;
	END LOOP;
	IF gSeqNo > 0 THEN
	-- 対象データあり
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recWkMeisai.JIKO_DAIKO_KBN = '2' THEN
			gItakuKaishaRnm := recWkMeisai.BANK_RNM;
		END IF;
		-- 最終承認ユーザの表示非表示切り替え
		-- はじめに初期化しておく
		gLastShoninYmd	:= NULL;
		gLastShoninId	:= NULL;		
		-- 承認ステータスが承認以外の場合には表示しないようにする
		IF recWkMeisai.MGR_STAT_KBN = '1' THEN
			gLastShoninYmd	:= recWkMeisai.LAST_SHONIN_YMD;
			gLastShoninId	:= recWkMeisai.LAST_SHONIN_ID;
		END IF;
		-- 仮登録時も機構送信項目にレ点を表示させる。
	    gRetenFlg := NULL;
	    IF recWkMeisai.MGR_STAT_KBN = '2' THEN
	        gRetenFlg := '1';
	    ELSE
	        gRetenFlg := recWkMeisai.MGR_SEND_TAISHO_FLG;
	    END IF;
		-- 有効な信託報酬・社債管理手数料情報があければ信託報酬・社債管理手数料情報を表示
		IF gYukoDataCnt > 0 THEN
			-- 帳票ワークへデータを追加(1ページ目)
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recWkMeisai.KICHU_TESU_TEISEI_YMD;	-- 期中手数料訂正日
		v_item.l_inItem003 := recWkMeisai.KICHU_TESU_TEISEI_USER_ID;	-- 期中手数料訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd;	-- 最終承認日
		v_item.l_inItem005 := gLastShoninId;	-- 最終承認ユーザ
		v_item.l_inItem006 := recWkMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := recWkMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem008 := recWkMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recWkMeisai.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recWkMeisai.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem011 := gAryJtkKbnRnm[1];	-- 受託区分名称１
		v_item.l_inItem012 := gAryShasaiJutakuCd[1];	-- 社債管理会社・受託会社１
		v_item.l_inItem013 := gAryShasaiJutakuNm[1];	-- 社債管理会社・受託会社名称１
		v_item.l_inItem014 := gAryKichuDfBunshi[1];	-- 期中分分配率（分子）１
		v_item.l_inItem015 := gAryKichuDfBunbo[1];	-- 期中分配率（分母）１
		v_item.l_inItem016 := gAryJtkKbnRnm[2];	-- 受託区分名称２
		v_item.l_inItem017 := gAryShasaiJutakuCd[2];	-- 社債管理会社・受託会社２
		v_item.l_inItem018 := gAryShasaiJutakuNm[2];	-- 社債管理会社・受託会社略称（委託会社）２
		v_item.l_inItem019 := gAryKichuDfBunshi[2];	-- 期中分分配率（分子）２
		v_item.l_inItem020 := gAryKichuDfBunbo[2];	-- 期中分配率（分母）２
		v_item.l_inItem021 := gAryJtkKbnRnm[3];	-- 受託区分名称３
		v_item.l_inItem022 := gAryShasaiJutakuCd[3];	-- 社債管理会社・受託会社３
		v_item.l_inItem023 := gAryShasaiJutakuNm[3];	-- 社債管理会社・受託会社略称（委託会社）３
		v_item.l_inItem024 := gAryKichuDfBunshi[3];	-- 期中分分配率（分子）３
		v_item.l_inItem025 := gAryKichuDfBunbo[3];	-- 期中分配率（分母）３
		v_item.l_inItem026 := gAryJtkKbnRnm[4];	-- 受託区分名称４
		v_item.l_inItem027 := gAryShasaiJutakuCd[4];	-- 社債管理会社・受託会社４
		v_item.l_inItem028 := gAryShasaiJutakuNm[4];	-- 社債管理会社・受託会社略称（委託会社）４
		v_item.l_inItem029 := gAryKichuDfBunshi[4];	-- 期中分分配率（分子）４
		v_item.l_inItem030 := gAryKichuDfBunbo[4];	-- 期中分配率（分母）４
		v_item.l_inItem031 := gAryJtkKbnRnm[5];	-- 受託区分名称５
		v_item.l_inItem032 := gAryShasaiJutakuCd[5];	-- 社債管理会社・受託会社５
		v_item.l_inItem033 := gAryShasaiJutakuNm[5];	-- 社債管理会社・受託会社略称（委託会社）５
		v_item.l_inItem034 := gAryKichuDfBunshi[5];	-- 期中分分配率（分子）５
		v_item.l_inItem035 := gAryKichuDfBunbo[5];	-- 期中分配率（分母）５
		v_item.l_inItem036 := gAryJtkKbnRnm[6];	-- 受託区分名称６
		v_item.l_inItem037 := gAryShasaiJutakuCd[6];	-- 社債管理会社・受託会社６
		v_item.l_inItem038 := gAryShasaiJutakuNm[6];	-- 社債管理会社・受託会社略称（委託会社）６
		v_item.l_inItem039 := gAryKichuDfBunshi[6];	-- 期中分分配率（分子）６
		v_item.l_inItem040 := gAryKichuDfBunbo[6];	-- 期中分配率（分母）６
		v_item.l_inItem041 := gAryJtkKbnRnm[7];	-- 受託区分名称７
		v_item.l_inItem042 := gAryShasaiJutakuCd[7];	-- 社債管理会社・受託会社７
		v_item.l_inItem043 := gAryShasaiJutakuNm[7];	-- 社債管理会社・受託会社略称（委託会社）７
		v_item.l_inItem044 := gAryKichuDfBunshi[7];	-- 期中分分配率（分子）７
		v_item.l_inItem045 := gAryKichuDfBunbo[7];	-- 期中分配率（分母）７
		v_item.l_inItem046 := gAryJtkKbnRnm[8];	-- 受託区分名称８
		v_item.l_inItem047 := gAryShasaiJutakuCd[8];	-- 社債管理会社・受託会社８
		v_item.l_inItem048 := gAryShasaiJutakuNm[8];	-- 社債管理会社・受託会社略称（委託会社）８
		v_item.l_inItem049 := gAryKichuDfBunshi[8];	-- 期中分分配率（分子）８
		v_item.l_inItem050 := gAryKichuDfBunbo[8];	-- 期中分配率（分母）８
		v_item.l_inItem051 := gAryJtkKbnRnm[9];	-- 受託区分名称９
		v_item.l_inItem052 := gAryShasaiJutakuCd[9];	-- 社債管理会社・受託会社９
		v_item.l_inItem053 := gAryShasaiJutakuNm[9];	-- 社債管理会社・受託会社略称（委託会社）９
		v_item.l_inItem054 := gAryKichuDfBunshi[9];	-- 期中分分配率（分子）９
		v_item.l_inItem055 := gAryKichuDfBunbo[9];	-- 期中分配率（分母）９
		v_item.l_inItem056 := gAryJtkKbnRnm[10];	-- 受託区分名称１０
		v_item.l_inItem057 := gAryShasaiJutakuCd[10];	-- 社債管理会社・受託会社１０
		v_item.l_inItem058 := gAryShasaiJutakuNm[10];	-- 社債管理会社・受託会社略称（委託会社）１０
		v_item.l_inItem059 := gAryKichuDfBunshi[10];	-- 期中分分配率（分子）１０
		v_item.l_inItem060 := gAryKichuDfBunbo[10];	-- 期中分配率（分母）１０
		v_item.l_inItem061 := TRUNC(recWkMeisai.SS_TESU_BUNSHI * (1 + gTax), 4);	-- 税込期中手数料率（分子）
		v_item.l_inItem062 := recWkMeisai.SS_TESU_BUNBO;	-- 税込期中手数料率（分母）
		v_item.l_inItem063 := recWkMeisai.SS_TESU_BUNSHI;	-- 期中手数料率（分子）
		v_item.l_inItem064 := recWkMeisai.SS_TESU_BUNBO;	-- 期中手数料率（分母）
		v_item.l_inItem065 := recWkMeisai.SS_NENCHOKYU_CNT_NM;	-- 信託報酬・社管手数料_年徴求回数名称
		v_item.l_inItem066 := recWkMeisai.CALC_PATTERN_NM;	-- 計算パターン名称
		v_item.l_inItem067 := recWkMeisai.ZNDK_KAKUTEI_KBN_NM;	-- 残高確定区分名称
		v_item.l_inItem068 := recWkMeisai.ZENGO_KBN_NM;	-- 前取後取区分名称
		v_item.l_inItem069 := recWkMeisai.DAY_MONTH_KBN_NM;	-- 日割月割区分名称
		v_item.l_inItem070 := recWkMeisai.HASU_NISSU_CALC_KBN_NM;	-- 端数日数計算区分名称
		v_item.l_inItem071 := recWkMeisai.CALC_YMD_KBN_NM;	-- 計算期間区分名称
		v_item.l_inItem072 := recWkMeisai.SS_CHOKYU_KYUJITSU_KBN_NM;	-- 信託報酬・社管手数料_徴求日休日処理区分
		v_item.l_inItem073 := gDtSsChokyuKjt1;	-- 信託報酬・社管手数料_徴求期日（1回目）
		v_item.l_inItem074 := gDtSsChokyuKjt2;	-- 信託報酬・社管手数料_徴求期日（2回目）
		v_item.l_inItem075 := recWkMeisai.SS_CHOKYU_KJT_2_GMATSU_FLG_NM;	-- 信託報酬・社管手数料_徴求日月末フラグ２内容
		v_item.l_inItem076 := gDtSsChokyuKjtEnd;	-- 信託報酬・社管手数料_徴求期日（最終）
		v_item.l_inItem077 := gDtSsCalcYmd1;	-- 信託報酬・社管手数料_計算期間（1回目）
		v_item.l_inItem078 := gDtSsCalcYmd2;	-- 信託報酬・社管手数料_計算期間（2回目）
		v_item.l_inItem079 := recWkMeisai.SS_CALC_YMD_2_GMATSU_FLG_NM;	-- 信託報酬・社管手数料_計算期間月末フラグ２内容
		v_item.l_inItem080 := gDtSsCalcYmdSt;	-- 信託報酬・社管手数料_計算期間（最終開始日）
		v_item.l_inItem081 := gDtSsCalcYmdEnd;	-- 信託報酬・社管手数料_計算期間（最終終了日）
		v_item.l_inItem082 := gDtSsZndkKijunYmd1;	-- 信託報酬・社管手数料_残高基準日（1回目）
		v_item.l_inItem083 := gDtSsZndkKijunYmd2;	-- 信託報酬・社管手数料_残高基準日（2回目）
		v_item.l_inItem084 := recWkMeisai.SS_ZNDK_YMD_2_GMATSU_FLG_NM;	-- 信託報酬・社管手数料_残高基準日月末フラグ２内容
		v_item.l_inItem085 := gDtSsZndkKijunYmdEnd;	-- 信託報酬・社管手数料_残高基準日（最終）
		v_item.l_inItem086 := gZkSsKichuTesuKngk1;	-- 定額期中管理手数料１回目（税込）
		v_item.l_inItem087 := gZkSsKichuTesuKngk2;	-- 定額期中管理手数料２回目（税込）
		v_item.l_inItem088 := gZkSsKichuTesuKngkEnd;	-- 定額期中管理手数料最終（税込）
		v_item.l_inItem089 := gSsKichuTesuKngk1;	-- 定額期中管理手数料１回目
		v_item.l_inItem090 := gSsKichuTesuKngk2;	-- 定額期中管理手数料２回目
		v_item.l_inItem091 := gSsKichuTesuKngkEnd;	-- 定額期中管理手数料最終
		v_item.l_inItem092 := recWkMeisai.DISTRI_TMG_NM;	-- 分配タイミング名称
		v_item.l_inItem093 := recWkMeisai.KSHOKAN_KJT_FLG_NM;	-- 繰上償還時償還期日算入フラグ内容
		v_item.l_inItem094 := recWkMeisai.KURIAGE_SHOKAN_CHOKYU_KBN;	-- 繰上償還時徴求日区分名称
		v_item.l_inItem095 := recWkMeisai.KURIAGE_SHOKAN_CHOKYU_DD;	-- 繰上償還時徴求日付
		v_item.l_inItem096 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem097 := REPORT_ID1;	-- 帳票ＩＤ
		v_item.l_inItem098 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem099 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem100 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem102 := gTesuSashihikiKbnNm1;	-- 手数料差引区分
		v_item.l_inItem103 := recWkMeisai.SHONIN_STAT_NM;	-- 承認ステータス名称
		v_item.l_inItem104 := 1;	-- ページ数
		v_item.l_inItem105 := 3;	-- 総ページ数
		v_item.l_inItem107 := recWkMeisai.MGR_SEND_TAISHO_FLG;	-- 銘柄送信対象フラグ
		v_item.l_inItem108 := gRetenFlg;	-- レ点フラグ
		v_item.l_inItem109 := recWkMeisai.UKEIRE_YMD_PATTERN_NM;	-- 受入日算出パターン名称
		v_item.l_inItem110 := recWkMeisai.KICYU_KANRI_TESU_CHOKYU_TMG1NM;	-- 期中管理手数料徴求タイミング１名称
		v_item.l_inItem111 := recWkMeisai.KICYU_KANRI_TESU_CHOKYU_TMG2NM;	-- 期中管理手数料徴求タイミング2名称
		v_item.l_inItem112 := recWkMeisai.KICYU_KANRI_TESU_CHOKYU_DD;	-- 期中管理手数料徴求タイミング日数
		v_item.l_inItem113 := recWkMeisai.DISTRI_TMG_DD;	-- 分配タイミング日付
		v_item.l_inItem250 := 'furikaeSort7';	-- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID1,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- 有効な信託報酬・社債管理手数料情報が無かった場合は1ページ目はヘッダのみ
		ELSE
			-- 帳票ワークへデータを追加
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recWkMeisai.KICHU_TESU_TEISEI_YMD;	-- 期中手数料訂正日
		v_item.l_inItem003 := recWkMeisai.KICHU_TESU_TEISEI_USER_ID;	-- 期中手数料訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd;	-- 最終承認日
		v_item.l_inItem005 := gLastShoninId;	-- 最終承認ユーザ
		v_item.l_inItem006 := recWkMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := recWkMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem008 := recWkMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recWkMeisai.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recWkMeisai.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem096 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem097 := REPORT_ID1;	-- 帳票ＩＤ
		v_item.l_inItem098 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem099 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem100 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem103 := recWkMeisai.SHONIN_STAT_NM;	-- 承認ステータス名称
		v_item.l_inItem104 := 1;	-- ページ数
		v_item.l_inItem105 := 3;	-- 総ページ数
		v_item.l_inItem107 := recWkMeisai.MGR_SEND_TAISHO_FLG;	-- 銘柄送信対象フラグ
		v_item.l_inItem108 := gRetenFlg;	-- レ点フラグ
		v_item.l_inItem250 := 'furikaeSort7';	-- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID1,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		END IF;
		-- 帳票ワークへデータを追加(2ページ目)
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recWkMeisai.KICHU_TESU_TEISEI_YMD;	-- 期中手数料訂正日
		v_item.l_inItem003 := recWkMeisai.KICHU_TESU_TEISEI_USER_ID;	-- 期中手数料訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd;	-- 最終承認日
		v_item.l_inItem005 := gLastShoninId;	-- 最終承認ユーザ
		v_item.l_inItem006 := recWkMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := recWkMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem008 := recWkMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recWkMeisai.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recWkMeisai.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem011 := gZNenchokyuCntNm;	-- 財務代理手数料_年徴求回数名称
		v_item.l_inItem012 := gZChokyuKyujitsuKbnNm;	-- 徴求期日の休日処理区分名称
		v_item.l_inItem013 := gZChokyuKjt1;	-- 徴求期日１回目
		v_item.l_inItem014 := gZChokyuKjt2;	-- 徴求期日２回目
		v_item.l_inItem015 := gZChokyuKjt2GmatsuFlgNm;	-- 財務代理手数料_徴求期日月末フラグ２内容
		v_item.l_inItem016 := gZChokyuKjtEnd;	-- 徴求期日最終
		v_item.l_inItem017 := gZkZaimuDairiTesuKngk1;	-- 定額財務代理人手数料１回目（税込）
		v_item.l_inItem018 := gZkZaimuDairiTesuKngk2;	-- 定額財務代理人手数料２回目（税込）
		v_item.l_inItem019 := gZkZaimuDairiTesuKngkEnd;	-- 定額財務代理人手数料最終（税込）
		v_item.l_inItem020 := gZaimuDairiTesuKngk1;	-- 定額財務代理人手数料１回目
		v_item.l_inItem021 := gZaimuDairiTesuKngk2;	-- 定額財務代理人手数料２回目
		v_item.l_inItem022 := gZaimuDairiTesuKngkEnd;	-- 定額財務代理人手数料最終
		v_item.l_inItem023 := TRUNC(recWkMeisai.GNKN_SHR_TESU_BUNSHI * (1 + gTax), 7);	-- 税込元金支払手数料率（分子）
		v_item.l_inItem024 := recWkMeisai.GNKN_SHR_TESU_BUNBO;	-- 税込元金支払手数料率（分母）
		v_item.l_inItem025 := recWkMeisai.GNKN_SHR_TESU_BUNSHI;	-- 元金支払手数料率（分子）
		v_item.l_inItem026 := recWkMeisai.GNKN_SHR_TESU_BUNBO;	-- 元金支払手数料率（分母）
		v_item.l_inItem027 := gGnknShrTesuCap;	-- 税込元金支払手数料ＣＡＰ（税込）
		v_item.l_inItem028 := recWkMeisai.GNKN_SHR_TESU_CAP;	-- 元金支払手数料ＣＡＰ
		v_item.l_inItem029 := recWkMeisai.GNKN_SHR_TESU_CHOKYU_TMG1_NM;	-- 元金支払手数料徴求タイミング１名称
		v_item.l_inItem030 := recWkMeisai.GNKN_SHR_TESU_CHOKYU_DD;	-- 元金支払手数料徴求タイミング日数
		v_item.l_inItem031 := recWkMeisai.GNKN_SHR_TESU_CHOKYU_TMG2_NM;	-- 元金支払手数料徴求タイミング２名称
		v_item.l_inItem032 := TRUNC(recWkMeisai.RKN_SHR_TESU_BUNSHI * (1 + gTax), 7);	-- 税込利金支払手数料率（分子）
		v_item.l_inItem033 := recWkMeisai.RKN_SHR_TESU_BUNBO;	-- 税込利金支払手数料率（分母）
		v_item.l_inItem034 := recWkMeisai.RKN_SHR_TESU_BUNSHI;	-- 利金支払手数料率（分子）
		v_item.l_inItem035 := recWkMeisai.RKN_SHR_TESU_BUNBO;	-- 利金支払手数料率（分母）
		v_item.l_inItem036 := gRknShrTesuCap;	-- 税込利金支払手数料ＣＡＰ（税込）
		v_item.l_inItem037 := recWkMeisai.RKN_SHR_TESU_CAP;	-- 利金支払手数料ＣＡＰ
		v_item.l_inItem038 := recWkMeisai.RKN_SHR_TESU_CHOKYU_TMG1_NM;	-- 利金支払手数料徴求タイミング１名称
		v_item.l_inItem039 := recWkMeisai.RKN_SHR_TESU_CHOKYU_DD;	-- 利金支払手数料徴求タイミング日数
		v_item.l_inItem040 := recWkMeisai.RKN_SHR_TESU_CHOKYU_TMG2_NM;	-- 利金支払手数料徴求タイミング２名称
		v_item.l_inItem041 := TRUNC(recWkMeisai.KAIIRE_SHOKYAKU_TESU_BUNSHI * (1 + gTax), 4);	-- 税込買入消却手数料率（分子）
		v_item.l_inItem042 := recWkMeisai.KAIIRE_SHOKYAKU_TESU_BUNBO;	-- 税込買入消却手数料率（分母）
		v_item.l_inItem043 := recWkMeisai.KAIIRE_SHOKYAKU_TESU_BUNSHI;	-- 買入消却手数料率（分子）
		v_item.l_inItem044 := recWkMeisai.KAIIRE_SHOKYAKU_TESU_BUNBO;	-- 買入消却手数料率（分母）
		v_item.l_inItem045 := gKaiireShokyakuTesuCap;	-- 税込買入消却手数料ＣＡＰ（税込）
		v_item.l_inItem046 := recWkMeisai.KAIIRE_SHOKYAKU_TESU_CAP;	-- 買入消却手数料ＣＡＰ
		v_item.l_inItem047 := recWkMeisai.KAIIRE_SHOKYAKU_KYUJITSU_NM;	-- 買入消却手数料_徴求日休日処理区分
		v_item.l_inItem048 := recWkMeisai.KAIIRE_SHOKYAKU_K_CHOKYU_NM;	-- 買入消却手数料_個別徴求フラグ名称
		v_item.l_inItem049 := recWkMeisai.KAIIRE_SHOKYAKU_CHOKYU_DD;	-- 買入消却手数料_徴求日付
		v_item.l_inItem050 := recWkMeisai.KAIIRE_SHOKYAKU_CHOKYU_NM;	-- 買入消却手数料_徴求日区分名称
		v_item.l_inItem051 := recWkMeisai.KAIIRE_SHOKYAKU_T_CHOKYU_NM;	-- 買入消却手数料_定期徴求フラグ名称
		v_item.l_inItem052 := recWkMeisai.KAIIRE_SHOKYAKU_NENCHOKYU_NM;	-- 買入消却手数料_年徴求回数名称
		v_item.l_inItem053 := recWkMeisai.KAIIRE_SHOKYAKU_CHOKYU_MMDD;	-- 買入消却手数料_徴求月日
		v_item.l_inItem054 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem055 := REPORT_ID1;	-- 帳票ＩＤ
		v_item.l_inItem056 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem057 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem058 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem059 := gTesuSashihikiKbnNm2;	-- 手数料差引区分
		v_item.l_inItem060 := recWkMeisai.SHONIN_STAT_NM;	-- 承認ステータス名称
		v_item.l_inItem061 := 2;	-- ページ数
		v_item.l_inItem062 := 3;	-- 総ページ数
		v_item.l_inItem064 := gSdNenchokyuCntNm;	-- 支払代理人手数料_財務代理手数料_年徴求回数名称
		v_item.l_inItem065 := gSdChokyuKyujitsuKbnNm;	-- 支払代理人手数料_徴求期日の休日処理区分名称
		v_item.l_inItem066 := gSdChokyuKjt1;	-- 支払代理人手数料_徴求期日１回目
		v_item.l_inItem067 := gSdChokyuKjt2;	-- 支払代理人手数料_徴求期日２回目
		v_item.l_inItem068 := gSdChokyuKjt2GmatsuFlgNm;	-- 支払代理人手数料_財務代理手数料_徴求期日月末フラグ２内容
		v_item.l_inItem069 := gSdChokyuKjtEnd;	-- 支払代理人手数料_徴求期日最終
		v_item.l_inItem070 := gSdZkDairiTesuKngk1;	-- 支払代理人手数料_定額財務代理人手数料１回目（税込）
		v_item.l_inItem071 := gSdZkDairiTesuKngk2;	-- 支払代理人手数料_定額財務代理人手数料２回目（税込）
		v_item.l_inItem072 := gSdZkDairiTesuKngkEnd;	-- 支払代理人手数料_定額財務代理人手数料最終（税込）
		v_item.l_inItem073 := gSdDairiTesuKngk2;	-- 支払代理人手数料_定額財務代理人手数料２回目
		v_item.l_inItem074 := gSdDairiTesuKngk1;	-- 支払代理人手数料_定額財務代理人手数料１回目
		v_item.l_inItem075 := gSdDairiTesuKngkEnd;	-- 支払代理人手数料_定額財務代理人手数料最終
		v_item.l_inItem076 := gSdTesuSashihikiKbnNm;	-- 支払代理人手数料_手数料差引区分
		v_item.l_inItem077 := gRetenFlg;	-- レ点フラグ
		v_item.l_inItem078 := recWkMeisai.MGR_SEND_TAISHO_FLG;	-- 銘柄送信対象フラグ
		v_item.l_inItem250 := 'furikaeSort7';	-- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID2,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- 帳票ワークへデータを追加(3ページ目)
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recWkMeisai.KICHU_TESU_TEISEI_YMD;	-- 期中手数料訂正日
		v_item.l_inItem003 := recWkMeisai.KICHU_TESU_TEISEI_USER_ID;	-- 期中手数料訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd;	-- 最終承認日
		v_item.l_inItem005 := gLastShoninId;	-- 最終承認ユーザ
		v_item.l_inItem006 := recWkMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := recWkMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem008 := recWkMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recWkMeisai.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recWkMeisai.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem012 := 3;	-- ページ数
		v_item.l_inItem013 := 3;	-- 総ページ数
		v_item.l_inItem014 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem015 := recWkMeisai.SHONIN_STAT_NM;	-- 承認ステータス名称
		v_item.l_inItem016 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem017 := gEtc1NenchokyuCntNm;	-- その他期中手数料１_財務代理手数料_年徴求回数名称
		v_item.l_inItem018 := gEtc1ChokyuKyujitsuKbnNm;	-- その他期中手数料１_徴求期日の休日処理区分名称
		v_item.l_inItem019 := gEtc1ChokyuKjt1;	-- その他期中手数料１_徴求期日１回目
		v_item.l_inItem020 := gEtc1ChokyuKjt2;	-- その他期中手数料１_徴求期日２回目
		v_item.l_inItem021 := gEtc1ChokyuKjt2GmatsuFlgNm;	-- その他期中手数料１_財務代理手数料_徴求期日月末フラグ２内容
		v_item.l_inItem022 := gEtc1ChokyuKjtEnd;	-- その他期中手数料１_徴求期日最終
		v_item.l_inItem023 := gEtc1ZkDairiTesuKngk1;	-- その他期中手数料１_定額財務代理人手数料１回目（税込）
		v_item.l_inItem024 := gEtc1ZkDairiTesuKngk2;	-- その他期中手数料１_定額財務代理人手数料２回目（税込）
		v_item.l_inItem025 := gEtc1ZkDairiTesuKngkEnd;	-- その他期中手数料１_定額財務代理人手数料最終（税込）
		v_item.l_inItem026 := gEtc1DairiTesuKngk2;	-- その他期中手数料１_定額財務代理人手数料２回目
		v_item.l_inItem027 := gEtc1DairiTesuKngk1;	-- その他期中手数料１_定額財務代理人手数料１回目
		v_item.l_inItem028 := gEtc1DairiTesuKngkEnd;	-- その他期中手数料１_定額財務代理人手数料最終
		v_item.l_inItem029 := gEtc1TesuSashihikiKbnNm;	-- その他期中手数料１_手数料差引区分
		v_item.l_inItem030 := REPORT_ID1;	-- 帳票ＩＤ
		v_item.l_inItem031 := TRUNC(recWkMeisai.WRNT_USE_TESU_BUNSHI * (1 + gTax), 7);	-- 税込予約権行使手数料率（分子）
		v_item.l_inItem032 := recWkMeisai.WRNT_USE_TESU_BUNBO;	-- 税込予約権行使手数料率（分母）
		v_item.l_inItem033 := recWkMeisai.WRNT_USE_TESU_BUNSHI;	-- 新株予約権行使手数料率（分子）
		v_item.l_inItem034 := recWkMeisai.WRNT_USE_TESU_BUNBO;	-- 新株予約権行使手数料率（分母）
		v_item.l_inItem035 := recWkMeisai.WRNT_USE_TESU_KYUJITSU_NM;	-- 新株予約権行使手数料_徴求日休日処理区分
		v_item.l_inItem036 := recWkMeisai.WRNT_USE_K_CHOKYU_NM;	-- 新株予約権行使手数料_個別徴求フラグ名称
		v_item.l_inItem037 := recWkMeisai.WRNT_USE_TESU_CHOKYU_DD;	-- 新株予約権行使手数料_徴求日付
		v_item.l_inItem038 := recWkMeisai.WRNT_USE_TESU_CHOKYU_NM;	-- 新株予約権行使手数料_徴求日区分名称
		v_item.l_inItem039 := recWkMeisai.WRNT_USE_T_CHOKYU_NM;	-- 新株予約権行使手数料_定期徴求フラグ名称
		v_item.l_inItem040 := recWkMeisai.WRNT_USE_NENCHOKYU_NM;	-- 新株予約権行使手数料_年徴求回数名称
		v_item.l_inItem041 := recWkMeisai.WRNT_USE_CHOKYU_MMDD;	-- 新株予約権行使手数料_徴求月日
		v_item.l_inItem042 := recWkMeisai.MGR_SEND_TAISHO_FLG;	-- 銘柄送信対象フラグ
		v_item.l_inItem043 := gRetenFlg;	-- レ点フラグ
		v_item.l_inItem250 := 'furikaeSort7';	-- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID3,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	ELSE
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 対象データなし用カーソル
		OPEN curMeisai_noRecored;
		FETCH curMeisai_noRecored INTO recMeisai_noRecored;
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recMeisai_noRecored.JIKO_DAIKO_KBN = '2' THEN
			gItakuKaishaRnm := recMeisai_noRecored.BANK_RNM;
		END IF;
		-- 最終承認ユーザの表示非表示切り替え
		-- はじめに初期化しておく
		gLastShoninYmd	:= NULL;
		gLastShoninId	:= NULL;		
		-- 承認ステータスが承認以外の場合には表示しないようにする
		IF recMeisai_noRecored.MGR_STAT_KBN = '1' THEN
			gLastShoninYmd	:= recMeisai_noRecored.LAST_SHONIN_YMD;
			gLastShoninId	:= recMeisai_noRecored.LAST_SHONIN_ID;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recMeisai_noRecored.KICHU_TESU_TEISEI_YMD;	-- 期中手数料訂正日
		v_item.l_inItem003 := recMeisai_noRecored.KICHU_TESU_TEISEI_USER_ID;	-- 期中手数料訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd;	-- 最終承認日
		v_item.l_inItem005 := gLastShoninId;	-- 最終承認ユーザ
		v_item.l_inItem006 := recMeisai_noRecored.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := recMeisai_noRecored.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem008 := recMeisai_noRecored.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recMeisai_noRecored.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recMeisai_noRecored.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem096 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem097 := REPORT_ID1;	-- 帳票ＩＤ
		v_item.l_inItem098 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem099 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem100 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem101 := '対象データなし';
		v_item.l_inItem103 := recMeisai_noRecored.SHONIN_STAT_NM;	-- 承認ステータス名称
		v_item.l_inItem104 := 1;	-- ページ数
		v_item.l_inItem105 := 3;	-- 総ページ数
		v_item.l_inItem250 := 'furikaeSort7';	-- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID1,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recMeisai_noRecored.KICHU_TESU_TEISEI_YMD;	-- 期中手数料訂正日
		v_item.l_inItem003 := recMeisai_noRecored.KICHU_TESU_TEISEI_USER_ID;	-- 期中手数料訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd;	-- 最終承認日
		v_item.l_inItem005 := gLastShoninId;	-- 最終承認ユーザ
		v_item.l_inItem006 := recMeisai_noRecored.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := recMeisai_noRecored.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem008 := recMeisai_noRecored.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recMeisai_noRecored.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recMeisai_noRecored.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem054 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem055 := REPORT_ID1;	-- 帳票ＩＤ
		v_item.l_inItem056 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem057 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem058 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem060 := recMeisai_noRecored.SHONIN_STAT_NM;	-- 承認ステータス名称
		v_item.l_inItem061 := 2;	-- ページ数
		v_item.l_inItem062 := 3;	-- 総ページ数
		v_item.l_inItem250 := 'furikaeSort7';	-- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID2,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recMeisai_noRecored.KICHU_TESU_TEISEI_YMD;	-- 期中手数料訂正日
		v_item.l_inItem003 := recMeisai_noRecored.KICHU_TESU_TEISEI_USER_ID;	-- 期中手数料訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd;	-- 最終承認日
		v_item.l_inItem005 := gLastShoninId;	-- 最終承認ユーザ
		v_item.l_inItem006 := recMeisai_noRecored.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := recMeisai_noRecored.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem008 := recMeisai_noRecored.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recMeisai_noRecored.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recMeisai_noRecored.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem012 := 3;	-- ページ数
		v_item.l_inItem013 := 3;	-- 総ページ数
		v_item.l_inItem014 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem015 := recMeisai_noRecored.SHONIN_STAT_NM;	-- 承認ステータス名称
		v_item.l_inItem016 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem030 := REPORT_ID1;	-- 帳票ＩＤ
		v_item.l_inItem250 := 'furikaeSort7';	-- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID3,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		CLOSE curMeisai_noRecored;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID1, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID1, C_PROCEDURE_ID || 'END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID1, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID1, 'SQLERRM:'||SQLERRM);
		CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'USER_ID:' || l_inUserId
						|| ', ITAKU_KAISHA_CD:' || l_inItakuKaishaCd || ', MGR_CD:' ||  l_inMgrCd);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipw001k00r07 ( l_inMgrCd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipw001k00r07_gettesushuruicd ( l_inMgrCd TEXT, l_inItakuKaishaCd TEXT, l_inTesuShuruiCd1 TEXT, l_inTesuShuruiCd2 TEXT ) RETURNS char AS $body$
DECLARE

	gTesuShuruiCd		char(2)	:= '';
	gCount				numeric	:= 0;

BEGIN
	SELECT
		count(*)
	INTO STRICT
		gCount
	FROM
		MGR_TESURYO_CTL
	WHERE
		MGR_CD = l_inMgrCd AND
		ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
		TESU_SHURUI_CD IN (l_inTesuShuruiCd1, l_inTesuShuruiCd2) AND
		CHOOSE_FLG = '1';
	IF gCount > 0 THEN
		SELECT
			TESU_SHURUI_CD
		INTO STRICT
			gTesuShuruiCd
		FROM
			MGR_TESURYO_CTL
		WHERE
			MGR_CD = l_inMgrCd AND
			ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
			TESU_SHURUI_CD IN (l_inTesuShuruiCd1, l_inTesuShuruiCd2) AND
			CHOOSE_FLG = '1';
	END IF;
	RETURN gTesuShuruiCd;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipw001k00r07_gettesushuruicd ( l_inMgrCd TEXT, l_inItakuKaishaCd TEXT, l_inTesuShuruiCd1 TEXT, l_inTesuShuruiCd2 TEXT ) FROM PUBLIC;