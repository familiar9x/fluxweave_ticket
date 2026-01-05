CREATE OR REPLACE PROCEDURE spipk001k00r14 (
	l_inMgrCd CHAR,		-- 銘柄コード
	l_inItakuKaishaCd CHAR,		-- 委託会社コード
	l_inUserId CHAR,		-- ユーザーID
	l_inChohyoKbn CHAR,		-- 帳票区分
	l_inGyomuYmd CHAR,		-- 業務日付
	l_outSqlCode OUT integer,		-- リターン値
	l_outSqlErrM OUT text	-- エラーコメント
) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:銘柄情報個別照会画面から、特例社債情報リストを作成する。
--/* 引数　:l_inMgrCd			IN	CHAR		銘柄コード
--/* 　　　 l_inItakuKaishaCd	IN	CHAR		委託会社コード
--/* 　　　 l_inUserId		IN	CHAR		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	CHAR		帳票区分
--/* 　　　 l_inGyomuYmd		IN	CHAR		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR2	エラーコメント
--/* 返り値:なし
--/*@version $Revision: 1.16 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.31	JIP				新規作成
--/*
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					配列定義													
--==============================================================================
	-- TYPE SPIPK001K00R14_TYPE_VARCHAR2 IS TABLE OF varchar(100)	INDEX BY integer;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID1			CONSTANT char(11)	:= 'IPK30000141';			-- 帳票ID
	REPORT_ID2			CONSTANT char(11)	:= 'IPK30000142';			-- 帳票ID
	REPORT_ID3			CONSTANT char(11)	:= 'IPK30000143';			-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	gShoninStat			SCODE.CODE_NM%TYPE;								-- 承認状態
	gArySknKessaiCd varchar(100)[];									-- 社債管理会社受託会社コード１〜１０
	gArySknKessaiNm varchar(100)[];									-- 社債管理会社受託会社名１〜１０
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;						-- 委託会社略称
	gBankRnm			SOWN_INFO.BANK_RNM%TYPE;						-- 銀行略称
  		-- 西暦変換用
	gWkHakkoYmd				varchar(20) := NULL;			-- 発行年月日
	gWkSknChgYmd			varchar(20) := NULL;			-- 資金付替日
	gWkSknKofuYmd			varchar(20) := NULL;			-- 資金交付日
	gWkFullshokanKjt		varchar(20) := NULL;			-- 満期償還期日
	gWkStTeijishokanKjt		varchar(20) := NULL;			-- 初回定時償還期日
	gWkTrustShoshoYmd		varchar(20) := NULL;			-- 信託証書日付
	gWkHakkoKykYmd			varchar(20) := NULL;			-- 発行契約日
	gWkStRbrKjt				varchar(20) := NULL;			-- 初回利払期日
	gWkTeikyoEndYmd			varchar(20) := NULL;			-- 適用終了日
	gWkDefaultYmd			varchar(20) := NULL;			-- デフォルト日
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT 	VMG0.KIHON_TEISEI_YMD,							-- 基本訂正日
				VMG0.KIHON_TEISEI_USER_ID,						-- 基本訂正ユーザ
				VMG0.LAST_SHONIN_YMD,							-- 最終承認日
				VMG0.LAST_SHONIN_ID,							-- 最終承認ユーザ
				VMG0.MGR_STAT_KBN,								-- 銘柄ステータス区分
				(SELECT CODE_NM FROM SCODE WHERE VMG0.MGR_STAT_KBN = CODE_VALUE AND CODE_SHUBETSU = '161') AS SHONIN_STAT,		-- 承認状態
				VMG1.MGR_CD,									-- 銘柄コード
				VMG1.ISIN_CD,									-- ＩＳＩＮコード
				VMG1.MGR_RNM,									-- 銘柄略称
				VMG1.JTK_KBN_NM,								-- 受託区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.JIKO_TOTAL_HKUK_KBN = CODE_VALUE AND CODE_SHUBETSU = '146') AS TOTAL_HKUK_KBN_NM,		-- 総額引受区分名称
				VMG1.HKT_CD,									-- 発行体コード
				M01.HKT_RNM,									-- 発行体略称
				VMG1.EIGYOTEN_CD,								-- 営業店店番
				(SELECT	M04.BUTEN_RNM
					FROM vmg1
LEFT OUTER JOIN mbuten m04 ON (VMG1.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD AND VMG1.EIGYOTEN_CD = M04.BUTEN_CD) ) AS EIGYOTEN_NM,		-- 営業店名称
				VMG1.HAKKODAIRI_CD,								-- 発行代理人コード
				(SELECT	VM02.BANK_RNM
					FROM vmg1
LEFT OUTER JOIN vmbank vm02 ON (VMG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD)
, substrvmg1
LEFT OUTER JOIN vmbank vm02 ON (SUBSTR(VMG1.HAKKODAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN AND SUBSTR(VMG1.HAKKODAIRI_CD, 2) = VM02.BANK_CD)  ) AS HAKKODAIRI_RNM,	-- 発行代理人略称
				M01.KOZA_TEN_CD,								-- 口座店コード
				M01.KOZA_TEN_CIFCD,								-- 口座店ＣＩＦコード
				VMG1.SHRDAIRI_CD,								-- 支払代理人コード
				(SELECT	VM02.BANK_RNM
					FROM vmg1
LEFT OUTER JOIN vmbank vm02 ON (VMG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD)
, substrvmg1
LEFT OUTER JOIN vmbank vm02 ON (SUBSTR(VMG1.SHRDAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN AND SUBSTR(VMG1.SHRDAIRI_CD, 2) = VM02.BANK_CD)  ) AS SHRDAIRI_RNM,		-- 支払代理人略称
				VMG1.SKN_KESSAI_CD,								-- 資金決済会社コード
				pkIpaName.getSknKessaiRnm(VMG1.ITAKU_KAISHA_CD,VMG1.SKN_KESSAI_CD) AS SKN_KESSAI_RNM,	-- 資金決済会社略称
				VMG1.MGR_NM,									-- 銘柄の正式名称
				VMG1.KK_HAKKO_CD,								-- 機構発行体コード
				VMG1.KK_HAKKOSHA_RNM,							-- 機構発行者略称
				VMG1.KAIGO_ETC,									-- 回号等
				VMG1.BOSHU_KBN,									-- 募集区分
				VMG1.BOSHU_KBN_NM,								-- 募集区分名称
				VMG1.KOKYAKU_BOSHU_KBN_NM,						-- 対顧用募集区分名称
				VMG1.KOKYAKU_MGR_RNM,							-- 対顧用銘柄略称
				VMG1.SAIKEN_KBN_NM,								-- 債券種類名称
				VMG1.HOSHO_KBN_NM,								-- 保証区分名称
				VMG1.TANPO_KBN_NM,								-- 担保区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.GODOHAKKO_FLG = CODE_VALUE AND CODE_SHUBETSU = '513') AS GODOHAKKO_FLG_NM,		-- 合同発行フラグ名称
				VMG1.BOSHU_ST_YMD,								-- 募集開始日
				VMG1.HAKKO_YMD,									-- 発行年月日
				(SELECT CODE_NM FROM SCODE WHERE VMG1.SKNNZISNTOKU_UMU_FLG = CODE_VALUE AND CODE_SHUBETSU = '517') AS SKNNZISNTOKU_UMU_FLG_NM,		-- 責任財産限定特約有無フラグ名称
				VMG1.SKN_CHG_YMD,								-- 資金付替日
				VMG1.SKN_KOFU_YMD,								-- 資金交付日
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RETSUTOKU_UMU_FLG = CODE_VALUE AND CODE_SHUBETSU = '530') AS RETSUTOKU_UMU_FLG_NM,			-- 劣後特約有無フラグ名称
				CASE WHEN  VMG1.BNK_GUARANTEE_RATE=0 THEN NULL  ELSE VMG1.BNK_GUARANTEE_RATE END  AS BNK_GUARANTEE_RATE,	-- 銀行保証料率
				CASE WHEN  VMG1.HOSHO_GUARANTEE_RATE=0 THEN NULL  ELSE VMG1.HOSHO_GUARANTEE_RATE END  AS HOSHO_GUARANTEE_RATE,	-- 保証協会保証料率
				(SELECT TSUKA_NM FROM MTSUKA WHERE VMG1.HAKKO_TSUKA_CD = TSUKA_CD) AS HAKKO_TSUKA_NM,				-- 発行通貨名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.UCHIKIRI_HAKKO_FLG = CODE_VALUE AND CODE_SHUBETSU = '518') AS UCHIKIRI_HAKKO_FLG_NM,			-- 打切発行フラグ名称
				CASE WHEN VMG1.KAKUSHASAI_KNGK=0 THEN NULL  ELSE VMG1.KAKUSHASAI_KNGK END  AS KAKUSHASAI_KNGK,							-- 各社債の金額
				CASE WHEN VMG1.HAKKO_KAGAKU=0 THEN NULL  ELSE VMG1.HAKKO_KAGAKU END  AS HAKKO_KAGAKU,								-- 発行価額
				CASE WHEN VMG1.SHASAI_TOTAL=0 THEN NULL  ELSE VMG1.SHASAI_TOTAL END  AS SHASAI_TOTAL,								-- 社債の総額
				VMG1.SHUTOKU_SUM,								-- 適格機関投資家取得総額（少人数私募カウント除外分）
				VMG1.SHOKAN_METHOD_NM,							-- 償還方法名称
				(SELECT TSUKA_NM FROM MTSUKA WHERE VMG1.SHOKAN_TSUKA_CD = TSUKA_CD) AS SHOKAN_TSUKA_NM,				-- 償還通貨名称
				CASE WHEN  VMG1.KAWASE_RATE=0 THEN NULL  ELSE VMG1.KAWASE_RATE END  AS KAWASE_RATE,	-- 為替レート
				VMG1.CALLALL_UMU_FLG_NM,						-- コールオプション有無（全額）名称
				VMG1.FULLSHOKAN_KJT,							-- 満期償還期日
				(SELECT CODE_NM FROM SCODE WHERE VMG1.TEIJI_SHOKAN_TSUTI_KBN = CODE_VALUE AND CODE_SHUBETSU = '520') AS TEIJI_SHOKAN_TSUTI_KBN_NM,	-- 定時償還通知区分名称
				VMG1.CALLITIBU_UMU_FLG_NM,						-- コールオプション有無（一部）名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.NEN_TEIJI_SHOKAN_CNT = CODE_VALUE AND CODE_SHUBETSU = '142') AS NEN_TEIJI_SHOKAN_CNT,			-- 年定時償還回数(名称)
				CASE WHEN VMG1.TOTAL_TEIJI_SHOKAN_CNT=0 THEN NULL  ELSE VMG1.TOTAL_TEIJI_SHOKAN_CNT END  AS TOTAL_TEIJI_SHOKAN_CNT,									-- 総定時償還回数
				VMG1.PUTUMU_FLG_NM,								-- プットオプション有無名称
				VMG1.ST_TEIJISHOKAN_KJT,						-- 初回定時償還期日
				CASE WHEN VMG1.TEIJI_SHOKAN_KNGK=0 THEN NULL  ELSE VMG1.TEIJI_SHOKAN_KNGK END  AS TEIJI_SHOKAN_KNGK,	-- 定時償還金額
				MG6.BANK_CD AS SHASAI_KANRI_JUTAKU_CD,			-- 社債管理会社受託会社コード
				(SELECT	VM02.BANK_RNM
					FROM mg6
LEFT OUTER JOIN vmbank vm02 ON (MG6.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD AND MG6.FINANCIAL_SECURITIES_KBN = VM02.FINANCIAL_SECURITIES_KBN AND MG6.BANK_CD = VM02.BANK_CD) ) AS SHASAI_KANRI_JUTAKU_RNM,		-- 社債管理会社受託会社名称
				VMG1.TRUST_SHOSHO_YMD,							-- 信託証書日付
				VMG1.HAKKO_KYK_YMD,								-- 発行契約日
				(SELECT CODE_NM FROM SCODE WHERE VMG1.PARTHAKKO_UMU_FLG = CODE_VALUE AND CODE_SHUBETSU = '525') AS PARTHAKKO_UMU_FLG_NM,			-- 分割発行有無フラグ名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KYUJITSU_KBN = CODE_VALUE AND CODE_SHUBETSU = '506') AS KYUJITSU_KBN_NM,				-- 休日処理区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KYUJITSU_LD_FLG = CODE_VALUE AND CODE_SHUBETSU = '504') AS KYUJITSU_LD_FLG_NM,			-- 休日処理ロンドン名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KYUJITSU_NY_FLG = CODE_VALUE AND CODE_SHUBETSU = '504') AS KYUJITSU_NY_FLG_NM,			-- 休日処理ニューヨーク名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KYUJITSU_ETC_FLG = CODE_VALUE AND CODE_SHUBETSU = '504') AS KYUJITSU_ETC_FLG_NM,			-- 休日処理その他海外名称
				VMG1.RITSUKE_WARIBIKI_KBN_NM,					-- 利付割引区分名称
				(SELECT TSUKA_NM FROM vmg1, mtsuka  ) AS RBR_TSUKA_NM,						-- 利払通貨名称
				CASE WHEN VMG1.RBR_KAWASE_RATE=0 THEN NULL  ELSE VMG1.RBR_KAWASE_RATE END  AS RBR_KAWASE_RATE,								-- 利払為替レート
				(SELECT CODE_NM FROM SCODE WHERE VMG1.NENRBR_CNT = CODE_VALUE AND CODE_SHUBETSU = '142') AS NENRBR_CNT_NM,	-- 年利払回数(名称)
				CASE WHEN VMG1.TOTAL_RBR_CNT=0 THEN NULL  ELSE VMG1.TOTAL_RBR_CNT END  AS TOTAL_RBR_CNT,	-- 総利払回数
				VMG1.RBR_DD,									-- 利払日付
				VMG1.ST_RBR_KJT,								-- 初回利払期日
				(SELECT CODE_NM FROM SCODE WHERE VMG1.LAST_RBR_FLG = CODE_VALUE AND CODE_SHUBETSU = '515') AS LAST_RBR_FLG_NM,				-- 最終利払有無フラグ名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KIJUN_KINRI_CD1 = CODE_VALUE AND CODE_SHUBETSU = '140') AS KIJUN_KINRI_NM1,				-- 基準金利１名称,
				CASE WHEN VMG1.RIRITSU=0 THEN NULL  ELSE VMG1.RIRITSU END  AS RIRITSU,									-- 利率
				CASE WHEN VMG1.SPREAD=0 THEN NULL  ELSE VMG1.SPREAD END  AS SPREAD,	-- スプレッド
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KIJUN_KINRI_CD2 = CODE_VALUE AND CODE_SHUBETSU = '140') AS KIJUN_KINRI_NM2,				-- 基準金利２名称
				VMG1.KIJUN_KINRI_CMNT,							-- 基準金利コメント
				CASE WHEN VMG1.RIRITSU_KETTEI_TMG_DD=0 THEN NULL  ELSE VMG1.RIRITSU_KETTEI_TMG_DD END  AS RIRITSU_KETTEI_TMG_DD,						-- 利率決定タイミング日数
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RIRITSU_KETTEI_TMG1 = CODE_VALUE AND CODE_SHUBETSU = '222') AS RIRITSU_KETTEI_TMG_NM1,			-- 利率決定タイミング名称１
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RIRITSU_KETTEI_TMG2 = CODE_VALUE AND CODE_SHUBETSU = '132') AS RIRITSU_KETTEI_TMG_NM2,			-- 利率決定タイミング名称２
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RRT_KYUJITSU_KBN = CODE_VALUE AND CODE_SHUBETSU = '506') AS RRT_KYUJITSU_KBN_NM,			-- 利率決定休日処理区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RRT_LD_FLG = CODE_VALUE AND CODE_SHUBETSU = '504') AS RRT_LD_FLG_NM,					-- 利率決定ロンドン名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RRT_NY_FLG = CODE_VALUE AND CODE_SHUBETSU = '504') AS RRT_NY_FLG_NM,					-- 利率決定ニューヨーク名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RRT_ETC_FLG = CODE_VALUE AND CODE_SHUBETSU = '504') AS RRT_ETC_FLG_NM,				-- 利率決定その他海外名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RRT_TKY_INV_FLG = CODE_VALUE AND CODE_SHUBETSU = '221') AS RRT_TKY_INV_FLG_NM,				-- 利率決定東京無効化名称
				VMG1.RBR_KJT_MD1,								-- 利払期日（MD）（１）
				VMG1.RBR_KJT_MD2,								-- 利払期日（MD）（２）
				VMG1.RBR_KJT_MD3,								-- 利払期日（MD）（３）
				VMG1.RBR_KJT_MD4,								-- 利払期日（MD）（４）
				VMG1.RBR_KJT_MD5,								-- 利払期日（MD）（５）
				VMG1.RBR_KJT_MD6,								-- 利払期日（MD）（６）
				VMG1.RBR_KJT_MD7,								-- 利払期日（MD）（７）
				VMG1.RBR_KJT_MD8,								-- 利払期日（MD）（８）
				VMG1.RBR_KJT_MD9,								-- 利払期日（MD）（９）
				VMG1.RBR_KJT_MD10,								-- 利払期日（MD）（１０）
				VMG1.RBR_KJT_MD11,								-- 利払期日（MD）（１１）
				VMG1.RBR_KJT_MD12,								-- 利払期日（MD）（１２）
				(SELECT CODE_NM FROM SCODE WHERE VMG1.HANKANEN_KBN = CODE_VALUE AND CODE_SHUBETSU = '124') AS HANKANEN_KBN_NM,				-- 半ヶ年区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RBR_NISSU_SPAN = CODE_VALUE AND CODE_SHUBETSU = '131') AS RBR_NISSU_SPAN,				-- 利払日数計算間隔名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RBR_KJT_INCLUSION_KBN = CODE_VALUE AND CODE_SHUBETSU = '130') AS RBR_KJT_INCLUSION_KBN_NM,		-- 利払期日算入区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.RKN_ROUND_PROCESS = CODE_VALUE AND CODE_SHUBETSU = '128') AS RKN_ROUND_PROCESS_NM,			-- 利金計算単位未満端数処理名称
				CASE WHEN VMG1.SHIKIRI_RATE=0 THEN NULL  ELSE VMG1.SHIKIRI_RATE END  AS SHIKIRI_RATE,								-- 仕切りレート
				(SELECT CODE_NM FROM SCODE WHERE VMG1.FST_NISSUKSN_KBN = CODE_VALUE AND CODE_SHUBETSU = '121') AS FST_NISSUKSN_KBN_NM,			-- 初期実日数計算区分名称
				CASE WHEN VMG1.TSUKARISHI_KNGK_FAST=0 THEN NULL  ELSE VMG1.TSUKARISHI_KNGK_FAST END  AS TSUKARISHI_KNGK_FAST,						-- １通貨あたりの利子金額（初期）
				CASE WHEN VMG1.TSUKARISHI_KNGK_FAST_S=0 THEN NULL  ELSE VMG1.TSUKARISHI_KNGK_FAST_S END  AS TSUKARISHI_KNGK_FAST_S,					-- １通貨あたりの利子金額（初期）算出値
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KICHU_NISSUKSN_KBN = CODE_VALUE AND CODE_SHUBETSU = '121') AS KICHU_NISSUKSN_KBN_NM,			-- 期中実日数計算区分名称
				CASE WHEN VMG1.TSUKARISHI_KNGK_NORM=0 THEN NULL  ELSE VMG1.TSUKARISHI_KNGK_NORM END  AS TSUKARISHI_KNGK_NORM,						-- １通貨あたりの利子金額（通常）
				CASE WHEN VMG1.TSUKARISHI_KNGK_NORM_S=0 THEN NULL  ELSE VMG1.TSUKARISHI_KNGK_NORM_S END  AS TSUKARISHI_KNGK_NORM_S,					-- １通貨あたりの利子金額（通常）算出値
				(SELECT CODE_NM FROM SCODE WHERE VMG1.END_NISSUKSN_KBN = CODE_VALUE AND CODE_SHUBETSU = '121') AS END_NISSUKSN_KBN,				-- 終期実日数計算区分名称
				CASE WHEN VMG1.TSUKARISHI_KNGK_LAST=0 THEN NULL  ELSE VMG1.TSUKARISHI_KNGK_LAST END  AS TSUKARISHI_KNGK_LAST,						-- １通貨あたりの利子金額（終期）
				CASE WHEN VMG1.TSUKARISHI_KNGK_LAST_S=0 THEN NULL  ELSE VMG1.TSUKARISHI_KNGK_LAST_S END  AS TSUKARISHI_KNGK_LAST_S,					-- １通貨あたりの利子金額（終期）算出値
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KK_KANYO_FLG = CODE_VALUE AND CODE_SHUBETSU = '505') AS KK_KANYO_FLG_NM,				-- 機構関与方式採用フラグ名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KOBETSU_SHONIN_SAIYO_FLG = CODE_VALUE AND CODE_SHUBETSU = '511') AS KOBETSU_SHONIN_SAIYO_FLG_NM,	-- 個別承認採用フラグ名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KKN_ZNDK_KAKUTEI_KBN = CODE_VALUE AND CODE_SHUBETSU = '181') AS KKN_ZNDK_KAKUTEI_KBN_NM,	-- 基金残高確定区分
				(SELECT CODE_NM FROM SCODE WHERE VMG1.DPT_ASSUMP_FLG = CODE_VALUE AND CODE_SHUBETSU = '170') AS DPT_ASSUMP_FLG_NM,				-- デットアサンプション契約先フラグ名称
				(SELECT	KOZA_FURI_KBN_NM
					FROM	KOZA_FRK
					WHERE	ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
					AND		KOZA_FURI_KBN = VMG1.KOZA_FURI_KBN) AS KOZA_FURI_KBN_NM,	-- 口座振替区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KKN_CHOKYU_KYUJITSU_KBN = CODE_VALUE AND CODE_SHUBETSU = '506') AS KKN_CHOKYU_KYUJITSU_KBN_NM,	-- 基金徴求休日処理区分
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KKN_CHOKYU_TMG1 = CODE_VALUE AND CODE_SHUBETSU = '135') AS KKN_CHOKYU_TMG1_NM,			-- 基金徴求タイミング１名称
				VMG1.KKN_CHOKYU_DD,								-- 基金徴求タイミング日数
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KKN_CHOKYU_TMG2 = CODE_VALUE AND CODE_SHUBETSU = '132') AS KKN_CHOKYU_TMG2_NM,			-- 基金徴求タイミング２名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KOBETSUSEIKYUOUT_KBN = CODE_VALUE AND CODE_SHUBETSU = '165') AS KOBETSUSEIKYUOUT_KBN_NM,		-- 個別請求書出力区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KKNBILL_OUT_TMG1 = CODE_VALUE AND CODE_SHUBETSU = '135') AS KKNBILL_OUT_TMG1_NM,			-- 基金請求書出力タイミング１名称
				CASE WHEN VMG1.KKNBILL_OUT_DD=0 THEN NULL  ELSE VMG1.KKNBILL_OUT_DD END  AS KKNBILL_OUT_DD,	-- 基金請求書出力タイミング日数
				(SELECT CODE_NM FROM SCODE WHERE VMG1.KKNBILL_OUT_TMG2 = CODE_VALUE AND CODE_SHUBETSU = '132') AS KKNBILL_OUT_TMG2_NM,			-- 基金請求書出力タイミング２名称
				VMG1.SHANAI_KOMOKU1,							-- 社内処理用項目１
				VMG1.SHANAI_KOMOKU2,							-- 社内処理用項目２
				VMG1.YOBI1,										-- 予備１
				VMG1.YOBI2,										-- 予備２
				VMG1.YOBI3,										-- 予備３
				VMG1.DKJ_MGR_CD,								-- 独自銘柄コード
				(SELECT CODE_NM FROM SCODE WHERE trim(both VMG1.SHASAI_GENBO_OUT_KBN) = CODE_VALUE AND CODE_SHUBETSU = '169' ) AS SHASAI_GENBO_OUT_KBN_NM,		-- 社債原簿出力区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.TOKUREI_SHASAI_FLG = CODE_VALUE AND CODE_SHUBETSU = '522') AS TOKUREI_SHASAI_FLG_NM,			-- 特例社債フラグ名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.IKKATSUIKO_FLG = CODE_VALUE AND CODE_SHUBETSU = '503') AS IKKATSUIKO_FLG_NM,				-- 一括移行方式フラグ名称
				VMG1.GENISIN_CD,								-- 原ＩＳＩＮコード
				SUBSTR(VMG1.YOBI3, 1, 13) AS PARENT_MGR_CD,		-- 親銘柄コード
				(SELECT CODE_NM FROM SCODE WHERE SUBSTR(VMG1.YOBI3, 14, 1) = CODE_VALUE AND CODE_SHUBETSU = '190' ) AS SHOKAN_ZUMI_FLG_NM,		-- 子銘柄償還済みフラグ名称
				VMG1.TKTI_KOZA_CD,								-- 特定口座管理機関コード
				(SELECT	VM02.BANK_RNM
					FROM vmg1
LEFT OUTER JOIN vmbank vm02 ON (VMG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD)
, substrvmg1
LEFT OUTER JOIN vmbank vm02 ON (SUBSTR(VMG1.TKTI_KOZA_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN AND SUBSTR(VMG1.TKTI_KOZA_CD, 2) = VM02.BANK_CD)  ) AS TKTI_KOZA_RNM,	-- 特定口座管理機関略称
				VMG1.PARTMGR_KBN,				-- 分割銘柄区分
				(SELECT CODE_NM FROM SCODE WHERE VMG1.PARTMGR_KBN = CODE_VALUE AND CODE_SHUBETSU = '526') AS PARTMGR_KBN_NM,				-- 分割銘柄区分名称
				(SELECT CODE_NM FROM SCODE WHERE VMG1.HEIZON_MGR_FLG = CODE_VALUE AND CODE_SHUBETSU = '171') AS HEIZON_MGR_FLG_NM,				-- 併存銘柄フラグ名称
				VMG1.TEKIYO_END_YMD,							-- 適用終了日
				VMG1.NEWISIN_CD,								-- 新ＩＳＩＮコード
				VMG1.DEFAULT_YMD,								-- デフォルト日
				(SELECT		DE02.DEFAULT_RIYU_NM
					FROM	DEFAULT_RIYU_KANRI DE02
					WHERE	DE02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
					AND		DE02.DEFAULT_RIYU = VMG1.DEFAULT_RIYU) AS DEFAULT_RIYU_NM,			-- デフォルト理由名称
				VMG1.DEFAULT_BIKO,								-- デフォルト備考
				VJ1.BANK_RNM,									-- 銀行略称
				VJ1.JIKO_DAIKO_KBN,								-- 自行代行区分
				VMG1.TOKUTEI_KOUSHASAI_FLG_NM,					-- 特定公社債フラグ
					 (SELECT CODE_NM
					 FROM   SCODE
					 WHERE  BT01.KYOTEN_KBN = CODE_VALUE
					 AND    CODE_SHUBETSU = 'B02') AS KYOTEN_KBN_NM,                    -- 拠点区分名称
					 (SELECT KOZA_FURI_KBN_NM
					 FROM   KOZA_FRK
					 WHERE  ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD
					 AND    KOZA_FURI_KBN = BT03.KOZA_FURI_KBN_GANKIN) AS KOZA_FURI_KBN_GANKIN_NM, -- 口座振替区分（元金）名称
					 (SELECT KOZA_FURI_KBN_NM
					 FROM   KOZA_FRK
					 WHERE  ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD
					 AND    KOZA_FURI_KBN = BT03.KOZA_FURI_KBN_RIKIN) AS KOZA_FURI_KBN_RIKIN_NM,   -- 口座振替区分（利金）名称
					 (SELECT CODE_NM
					 FROM   SCODE
					 WHERE  BT03.DISPATCH_FLG = CODE_VALUE
					 AND    CODE_SHUBETSU = 'B05') AS DISPATCH_FLG_NM,                  -- 請求書発送区分名称
					 (SELECT CODE_NM
					 FROM   SCODE
					 WHERE  BT03.GNRSHROUT_KBN = CODE_VALUE
					 AND    CODE_SHUBETSU = 'B18') AS GNRSHROUT_KBN_NM,                 -- 元利金支払報告書出力区分名称
					 BT03.SHIHYOKINRI_NM_ETC,                                            -- その他指標金利コード内容
					 CASE WHEN BT03.KINRIMAX_SPREAD=0 THEN  NULL  ELSE BT03.KINRIMAX_SPREAD END  AS KINRIMAX_SPREAD,        -- 基準金利（上限）スプレッド
					 CASE WHEN BT03.KINRIFLOOR_SPREAD=0 THEN  NULL  ELSE BT03.KINRIFLOOR_SPREAD END  AS KINRIFLOOR_SPREAD,  -- 基準金利（下限）スプレッド
					 (SELECT CODE_NM
					 FROM   SCODE
					 WHERE  BT03.KINRIMAX = CODE_VALUE
					 AND    CODE_SHUBETSU = '140') AS KINRIMAX_NM,                      -- 基準金利（上限）名称,
					 (SELECT CODE_NM
					 FROM   SCODE
					 WHERE  BT03.KINRIFLOOR = CODE_VALUE
					 AND    CODE_SHUBETSU = '140') AS KINRIFLOOR_NM,                    -- 基準金利（下限）名称,
					 CASE WHEN BT03.MAX_KINRI=0 THEN  NULL  ELSE BT03.MAX_KINRI END  AS MAX_KINRI,       -- 上限金利
					 CASE WHEN BT03.FLOOR_KINRI=0 THEN  NULL  ELSE BT03.FLOOR_KINRI END  AS FLOOR_KINRI,  -- 下限金利
					 (SELECT CODE_RNM FROM SCODE WHERE CODE_VALUE = BT03.MUTB_FLG AND CODE_SHUBETSU = 'B23') AS MUTB_FLG_NM   -- 信託フラグ名称
		FROM vmgr_sts vmg0, vjiko_itaku vj1, mhakkotai m01, mgr_kihon2 bt03, mhakkotai2 bt01, vmgr_list vmg1
LEFT OUTER JOIN mgr_jutakuginko mg6 ON (VMG1.MGR_CD = MG6.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG6.ITAKU_KAISHA_CD)
WHERE VMG1.MGR_CD = l_inMgrCd AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.MGR_CD= VMG0.MGR_CD AND VMG1.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD AND VMG1.MGR_CD = BT03.MGR_CD AND VMG1.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD AND VMG1.HKT_CD = BT01.HKT_CD AND VMG1.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD   AND VMG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID ORDER BY 	MG6.JTK_KBN,
				MG6.INPUT_NUM;
	-- レコード
	recWkMeisai	RECORD;
	l_inItem TYPE_SREPORT_WK_ITEM := ROW();
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID1, 'SPIP10010 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inMgrCd::text), '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd::text), '') = ''
	OR coalesce(trim(both l_inUserId::text), '') = ''
	OR coalesce(trim(both l_inChohyoKbn::text), '') = ''
	OR coalesce(trim(both l_inGyomuYmd::text), '') = ''
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
	AND (CHOHYO_ID = REPORT_ID1 OR CHOHYO_ID = REPORT_ID2 OR CHOHYO_ID = REPORT_ID3);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID1);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID2);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID3);
	-- 配列の初期化
	FOR i IN 1..10 LOOP
		gArySknKessaiCd[i] := NULL;
		gArySknKessaiNm[i] := NULL;
	END LOOP;
	-- ５−１．自行情報マスタから銀行略称を取得
	SELECT
		BANK_RNM
	INTO STRICT
		gBankRnm
	FROM SOWN_INFO;
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		IF gSeqNo = 1 THEN
			gShoninStat := recMeisai.SHONIN_STAT;
			-- レコードのセット
			recWkMeisai := recMeisai;
		END IF;
		gArySknKessaiCd[gSeqNo] := recMeisai.SHASAI_KANRI_JUTAKU_CD;
		gArySknKessaiNm[gSeqNo] := recMeisai.SHASAI_KANRI_JUTAKU_RNM;
	END LOOP;
	IF gSeqNo > 0 THEN
	-- 対象データあり
		-- 委託会社略称の設定
		gItakuKaishaRnm := NULL;
		IF recWkMeisai.JIKO_DAIKO_KBN = '2' THEN
			gItakuKaishaRnm := recWkMeisai.BANK_RNM;
		END IF;
		-- 親銘柄コード
		IF recWkMeisai.PARTMGR_KBN = '0' THEN
			-- 単一銘柄('0')の場合は空初を設定
			recWkMeisai.PARENT_MGR_CD := NULL;
		END IF;
		-- 子銘柄償還済みフラグ名称
		IF recWkMeisai.PARTMGR_KBN != '2' THEN
			-- 子銘柄('2')以外は空白を設定
			recWkMeisai.SHOKAN_ZUMI_FLG_NM := NULL;
		END IF;
		--	発行年月日（西暦変換）
		gWkHakkoYmd		 := NULL;
		IF (trim(both recWkMeisai.HAKKO_YMD) IS NOT NULL AND (trim(both recWkMeisai.HAKKO_YMD::text)) <> '') THEN
			gWkHakkoYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.HAKKO_YMD);
		END IF;
		--	資金付替日（西暦変換）
		gWkSknChgYmd		 := NULL;
		IF (trim(both recWkMeisai.SKN_CHG_YMD) IS NOT NULL AND (trim(both recWkMeisai.SKN_CHG_YMD::text)) <> '') THEN
			gWkSknChgYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.SKN_CHG_YMD);
		END IF;
		--	資金交付日（西暦変換）
		gWkSknKofuYmd		 := NULL;
		IF (trim(both recWkMeisai.SKN_KOFU_YMD) IS NOT NULL AND (trim(both recWkMeisai.SKN_KOFU_YMD::text)) <> '') THEN
			gWkSknKofuYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.SKN_KOFU_YMD);
		END IF;
		--	満期償還期日（西暦変換）-- 99999999のデータだけありえるのでそれに対処。
		gWkFullshokanKjt := NULL;
		IF trim(both recWkMeisai.FULLSHOKAN_KJT) = '99999999'	--	償還期日が9999/99/99 だったら
		THEN
			gWkFullshokanKjt := recWkMeisai.FULLSHOKAN_KJT;
		ELSIF (trim(both recWkMeisai.FULLSHOKAN_KJT) IS NOT NULL AND (trim(both recWkMeisai.FULLSHOKAN_KJT::text)) <> '')
		THEN
			gWkFullshokanKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.FULLSHOKAN_KJT);
		END IF;
		--	初回定時償還期日（西暦変換）
		gWkStTeijishokanKjt		 := NULL;
		IF (trim(both recWkMeisai.ST_TEIJISHOKAN_KJT) IS NOT NULL AND (trim(both recWkMeisai.ST_TEIJISHOKAN_KJT::text)) <> '') THEN
			gWkStTeijishokanKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.ST_TEIJISHOKAN_KJT);
		END IF;
		--	信託証書日付（西暦変換）
		gWkTrustShoshoYmd		 := NULL;
		IF (trim(both recWkMeisai.TRUST_SHOSHO_YMD) IS NOT NULL AND (trim(both recWkMeisai.TRUST_SHOSHO_YMD::text)) <> '') THEN
			gWkTrustShoshoYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.TRUST_SHOSHO_YMD);
		END IF;
		--	発行契約日（西暦変換）
		gWkHakkoKykYmd		 := NULL;
		IF (trim(both recWkMeisai.HAKKO_KYK_YMD) IS NOT NULL AND (trim(both recWkMeisai.HAKKO_KYK_YMD::text)) <> '') THEN
			gWkHakkoKykYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.HAKKO_KYK_YMD);
		END IF;
		--	初回利払期日（西暦変換）
		gWkStRbrKjt		 := NULL;
		IF (trim(both recWkMeisai.ST_RBR_KJT) IS NOT NULL AND (trim(both recWkMeisai.ST_RBR_KJT::text)) <> '') THEN
			gWkStRbrKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.ST_RBR_KJT);
		END IF;
		--	適用終了日（西暦変換）
		gWkTeikyoEndYmd		 := NULL;
		IF (trim(both recWkMeisai.TEKIYO_END_YMD) IS NOT NULL AND (trim(both recWkMeisai.TEKIYO_END_YMD::text)) <> '') THEN
			gWkTeikyoEndYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.TEKIYO_END_YMD);
		END IF;
		--	デフォルト日（西暦変換）
		gWkDefaultYmd		 := NULL;
		IF (trim(both recWkMeisai.DEFAULT_YMD) IS NOT NULL AND (trim(both recWkMeisai.DEFAULT_YMD::text)) <> '') THEN
			gWkDefaultYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.DEFAULT_YMD);
		END IF;
		-- 帳票ワークへデータを追加
		l_inItem.l_inItem001		:=	l_inUserId; 									-- ユーザＩＤ
		l_inItem.l_inItem002		:=	recWkMeisai.KIHON_TEISEI_YMD; 				-- 基本訂正日
		l_inItem.l_inItem003		:=	recWkMeisai.KIHON_TEISEI_USER_ID; 			-- 基本訂正ユーザ
		l_inItem.l_inItem004		:=	recWkMeisai.LAST_SHONIN_YMD; 					-- 最終承認日
		l_inItem.l_inItem005		:=	recWkMeisai.LAST_SHONIN_ID; 					-- 最終承認ユーザ
		l_inItem.l_inItem006		:=	gShoninStat; 									-- 承認状態
		l_inItem.l_inItem007		:=	recWkMeisai.MGR_CD; 							-- 銘柄コード
		l_inItem.l_inItem008		:=	recWkMeisai.ISIN_CD; 							-- ＩＳＩＮコード
		l_inItem.l_inItem009		:=	recWkMeisai.MGR_RNM; 							-- 銘柄略称
		l_inItem.l_inItem010		:=	recWkMeisai.JTK_KBN_NM; 						-- 受託区分名称
		l_inItem.l_inItem011		:=	recWkMeisai.TOTAL_HKUK_KBN_NM; 				-- 総額引受区分名称
		l_inItem.l_inItem012		:=	recWkMeisai.HKT_CD; 							-- 発行体コード
		l_inItem.l_inItem013		:=	recWkMeisai.HKT_RNM; 							-- 発行体略称
		l_inItem.l_inItem014		:=	recWkMeisai.EIGYOTEN_CD; 						-- 営業店店番
		l_inItem.l_inItem015		:=	recWkMeisai.EIGYOTEN_NM; 						-- 営業店名称
		l_inItem.l_inItem016		:=	recWkMeisai.HAKKODAIRI_CD; 					-- 発行代理人コード
		l_inItem.l_inItem017		:=	recWkMeisai.HAKKODAIRI_RNM; 					-- 発行代理人略称
		l_inItem.l_inItem018		:=	recWkMeisai.KOZA_TEN_CD; 						-- 口座店コード
		l_inItem.l_inItem019		:=	recWkMeisai.KOZA_TEN_CIFCD; 					-- 口座店ＣＩＦコード
		l_inItem.l_inItem020		:=	recWkMeisai.SHRDAIRI_CD; 						-- 支払代理人コード
		l_inItem.l_inItem021		:=	recWkMeisai.SHRDAIRI_RNM; 					-- 支払代理人略称
		l_inItem.l_inItem022		:=	recWkMeisai.SKN_KESSAI_CD; 					-- 資金決済会社コード
		l_inItem.l_inItem023		:=	recWkMeisai.SKN_KESSAI_RNM; 					-- 資金決済会社略称
		l_inItem.l_inItem024		:=	recWkMeisai.MGR_NM; 							-- 銘柄の正式名称
		l_inItem.l_inItem025		:=	recWkMeisai.KK_HAKKO_CD; 						-- 機構発行体コード
		l_inItem.l_inItem026		:=	recWkMeisai.KK_HAKKOSHA_RNM; 					-- 機構発行者略称
		l_inItem.l_inItem027		:=	recWkMeisai.KAIGO_ETC; 						-- 回号等
		l_inItem.l_inItem028		:=	recWkMeisai.BOSHU_KBN; 						-- 募集区分
		l_inItem.l_inItem029		:=	recWkMeisai.BOSHU_KBN_NM; 					-- 募集区分名称
		l_inItem.l_inItem030		:=	recWkMeisai.KOKYAKU_BOSHU_KBN_NM; 			-- 対顧用募集区分名称
		l_inItem.l_inItem031		:=	recWkMeisai.KOKYAKU_MGR_RNM; 					-- 対顧用銘柄略称
		l_inItem.l_inItem032		:=	recWkMeisai.SAIKEN_KBN_NM; 					-- 債券種類名称
		l_inItem.l_inItem033		:=	recWkMeisai.HOSHO_KBN_NM; 					-- 保証区分名称
		l_inItem.l_inItem034		:=	recWkMeisai.TANPO_KBN_NM; 					-- 担保区分名称
		l_inItem.l_inItem035		:=	recWkMeisai.GODOHAKKO_FLG_NM; 				-- 合同発行フラグ名称
		l_inItem.l_inItem036		:=	gWkHakkoYmd; 									-- 発行年月日
		l_inItem.l_inItem037		:=	recWkMeisai.SKNNZISNTOKU_UMU_FLG_NM; 			-- 責任財産限定特約有無フラグ名称
		l_inItem.l_inItem038		:=	gWkSknChgYmd; 								-- 資金付替日
		l_inItem.l_inItem039		:=	gWkSknKofuYmd; 								-- 資金交付日
		l_inItem.l_inItem040		:=	recWkMeisai.RETSUTOKU_UMU_FLG_NM; 			-- 劣後特約有無フラグ名称
		l_inItem.l_inItem041		:=	recWkMeisai.BNK_GUARANTEE_RATE; 				-- 銀行保証料率
		l_inItem.l_inItem042		:=	recWkMeisai.HOSHO_GUARANTEE_RATE; 			-- 保証協会保証料率
		l_inItem.l_inItem043		:=	recWkMeisai.HAKKO_TSUKA_NM; 					-- 発行通貨名称
		l_inItem.l_inItem044		:=	recWkMeisai.UCHIKIRI_HAKKO_FLG_NM; 			-- 打切発行フラグ名称
		l_inItem.l_inItem045		:=	recWkMeisai.KAKUSHASAI_KNGK; 					-- 各社債の金額
		l_inItem.l_inItem046		:=	recWkMeisai.HAKKO_KAGAKU; 					-- 発行価額
		l_inItem.l_inItem047		:=	recWkMeisai.SHASAI_TOTAL; 					-- 社債の総額
		l_inItem.l_inItem048		:=	recWkMeisai.SHUTOKU_SUM; 						-- 適格機関投資家取得総額（少人数私募カウント除外分）
		l_inItem.l_inItem049		:=	recWkMeisai.SHOKAN_METHOD_NM; 				-- 償還方法名称
		l_inItem.l_inItem050		:=	recWkMeisai.SHOKAN_TSUKA_NM; 					-- 償還通貨名称
		l_inItem.l_inItem051		:=	recWkMeisai.KAWASE_RATE; 						-- 為替レート
		l_inItem.l_inItem052		:=	recWkMeisai.CALLALL_UMU_FLG_NM; 				-- コールオプション有無（全額）名称
		l_inItem.l_inItem053		:=	gWkFullshokanKjt; 							-- 満期償還期日
		l_inItem.l_inItem054		:=	recWkMeisai.TEIJI_SHOKAN_TSUTI_KBN_NM; 		-- 定時償還通知区分名称
		l_inItem.l_inItem055		:=	recWkMeisai.CALLITIBU_UMU_FLG_NM; 			-- コールオプション有無（一部）名称
		l_inItem.l_inItem056		:=	recWkMeisai.NEN_TEIJI_SHOKAN_CNT; 			-- 年定時償還回数
		l_inItem.l_inItem057		:=	recWkMeisai.TOTAL_TEIJI_SHOKAN_CNT; 			-- 総定時償還回数
		l_inItem.l_inItem058		:=	recWkMeisai.PUTUMU_FLG_NM; 					-- プットオプション有無名称
		l_inItem.l_inItem059		:=	gWkStTeijishokanKjt; 							-- 初回定時償還期日
		l_inItem.l_inItem060		:=	recWkMeisai.TEIJI_SHOKAN_KNGK; 				-- 定時償還金額
		l_inItem.l_inItem061		:=	gArySknKessaiCd[1];							-- 社債管理会社受託会社コード
		l_inItem.l_inItem062		:=	gArySknKessaiNm[1];							-- 社債管理会社受託会社名称
		l_inItem.l_inItem063		:=	gArySknKessaiCd[2];							-- 社債管理会社受託会社コード２
		l_inItem.l_inItem064		:=	gArySknKessaiNm[2];							-- 社債管理会社受託会社名称２
		l_inItem.l_inItem065		:=	gArySknKessaiCd[3];							-- 社債管理会社受託会社コード３
		l_inItem.l_inItem066		:=	gArySknKessaiNm[3];							-- 社債管理会社受託会社名称３
		l_inItem.l_inItem067		:=	gArySknKessaiCd[4];							-- 社債管理会社受託会社コード４
		l_inItem.l_inItem068		:=	gArySknKessaiNm[4];							-- 社債管理会社受託会社名称４
		l_inItem.l_inItem069		:=	gArySknKessaiCd[5];							-- 社債管理会社受託会社コード５
		l_inItem.l_inItem070		:=	gArySknKessaiNm[5];							-- 社債管理会社受託会社名称５
		l_inItem.l_inItem071		:=	gArySknKessaiCd[6];							-- 社債管理会社受託会社コード６
		l_inItem.l_inItem072		:=	gArySknKessaiNm[6];							-- 社債管理会社受託会社名称６
		l_inItem.l_inItem073		:=	gArySknKessaiCd[7];							-- 社債管理会社受託会社コード７
		l_inItem.l_inItem074		:=	gArySknKessaiNm[7];							-- 社債管理会社受託会社名称７
		l_inItem.l_inItem075		:=	gArySknKessaiCd[8];							-- 社債管理会社受託会社コード８
		l_inItem.l_inItem076		:=	gArySknKessaiNm[8];							-- 社債管理会社受託会社名称８
		l_inItem.l_inItem077		:=	gArySknKessaiCd[9];							-- 社債管理会社受託会社コード９
		l_inItem.l_inItem078		:=	gArySknKessaiNm[9];							-- 社債管理会社受託会社名称９
		l_inItem.l_inItem079		:=	gArySknKessaiCd[10];							-- 社債管理会社受託会社コード１０
		l_inItem.l_inItem080		:=	gArySknKessaiNm[10];							-- 社債管理会社受託会社名称１０
		l_inItem.l_inItem081		:=	gWkTrustShoshoYmd; 							-- 信託証書日付
		l_inItem.l_inItem082		:=	gWkHakkoKykYmd; 								-- 発行契約日
		l_inItem.l_inItem083		:=	recWkMeisai.PARTHAKKO_UMU_FLG_NM; 			-- 分割発行有無フラグ名称
		l_inItem.l_inItem084		:=	recWkMeisai.KYUJITSU_KBN_NM; 					-- 休日処理区分名称
		l_inItem.l_inItem085		:=	recWkMeisai.KYUJITSU_LD_FLG_NM; 				-- 休日処理ロンドン名称
		l_inItem.l_inItem086		:=	recWkMeisai.KYUJITSU_NY_FLG_NM; 				-- 休日処理ニューヨーク名称
		l_inItem.l_inItem087		:=	recWkMeisai.KYUJITSU_ETC_FLG_NM; 				-- 休日処理その他海外名称
		l_inItem.l_inItem088		:=	gItakuKaishaRnm; 								-- 委託会社略称
		l_inItem.l_inItem089		:=	REPORT_ID1;									-- 帳票ＩＤ
		l_inItem.l_inItem090		:=	FMT_HAKKO_KNGK_J; 							-- 発行金額書式フォーマット
		l_inItem.l_inItem091		:=	FMT_RBR_KNGK_J; 								-- 利払金額書式フォーマット
		l_inItem.l_inItem092		:=	FMT_SHOKAN_KNGK_J; 							-- 償還金額書式フォーマット
		l_inItem.l_inItem093		:=	'1';											-- ページNo
		l_inItem.l_inItem094		:=	'3';											-- ページ総数
		l_inItem.l_inItem100		:=	recWkMeisai.TOKUTEI_KOUSHASAI_FLG_NM; 		-- 特定公社債フラグ名称
		l_inItem.l_inItem101		:=	recWkMeisai.KYOTEN_KBN_NM;        -- 拠点区分名称
		l_inItem.l_inItem102		:=	gBankRnm; 									-- 銀行略称
		l_inItem.l_inItem103		:=	recWkMeisai.MUTB_FLG_NM; 						-- 信託フラグ名称
		l_inItem.l_inItem200		:=	'tokureiListFlg';							-- 特例社債情報リストかどうか判別するフラグ

		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 							-- 識別コード
			,l_inUserId			=>	l_inUserId 									-- ユーザＩＤ
			,l_inChohyoKbn		=>	l_inChohyoKbn 								-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 								-- 作成年月日
			,l_inChohyoId		=>	REPORT_ID1									-- 帳票ＩＤ
			,l_inSeqNo			=>	1											-- 連番
			,l_inHeaderFlg		=>	'1'											-- ヘッダフラグ
			,l_inItem				=> l_inItem
			,l_inKousinId		=>	l_inUserId 									-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 									-- 作成者ID
		);
		l_inItem := ROW();
		l_inItem.l_inItem001		:=	l_inUserId; 									-- ユーザＩＤ
		l_inItem.l_inItem002		:=	recWkMeisai.KIHON_TEISEI_YMD; 				-- 基本訂正日
		l_inItem.l_inItem003		:=	recWkMeisai.KIHON_TEISEI_USER_ID; 			-- 基本訂正ユーザ
		l_inItem.l_inItem004		:=	recWkMeisai.LAST_SHONIN_YMD; 					-- 最終承認日
		l_inItem.l_inItem005		:=	recWkMeisai.LAST_SHONIN_ID; 					-- 最終承認ユーザ
		l_inItem.l_inItem006		:=	gShoninStat; 									-- 承認状態
		l_inItem.l_inItem007		:=	recWkMeisai.MGR_CD; 							-- 銘柄コード
		l_inItem.l_inItem008		:=	recWkMeisai.ISIN_CD; 							-- ＩＳＩＮコード
		l_inItem.l_inItem009		:=	recWkMeisai.MGR_RNM; 							-- 銘柄略称
		l_inItem.l_inItem010		:=	recWkMeisai.RITSUKE_WARIBIKI_KBN_NM; 			-- 利付割引区分名称
		l_inItem.l_inItem011		:=	recWkMeisai.RBR_TSUKA_NM; 					-- 利払通貨名称
		l_inItem.l_inItem012		:=	recWkMeisai.RBR_KAWASE_RATE; 					-- 利払為替レート
		l_inItem.l_inItem013		:=	recWkMeisai.NENRBR_CNT_NM; 					-- 年利払回数
		l_inItem.l_inItem014		:=	recWkMeisai.TOTAL_RBR_CNT; 					-- 総利払回数
		l_inItem.l_inItem015		:=	recWkMeisai.RBR_DD; 							-- 利払日付
		l_inItem.l_inItem016		:=	gWkStRbrKjt; 									-- 初回利払期日
		l_inItem.l_inItem017		:=	recWkMeisai.LAST_RBR_FLG_NM; 					-- 最終利払有無フラグ名称
		l_inItem.l_inItem018		:=	recWkMeisai.KIJUN_KINRI_NM1;					-- 基準金利１名称,
		l_inItem.l_inItem019		:=	recWkMeisai.RIRITSU; 							-- 利率
		l_inItem.l_inItem020		:=	recWkMeisai.SPREAD; 							-- スプレッド
		l_inItem.l_inItem021		:=	recWkMeisai.KIJUN_KINRI_NM2;					-- 基準金利２名称
		l_inItem.l_inItem022		:=	recWkMeisai.KIJUN_KINRI_CMNT; 				-- 基準金利コメント
		l_inItem.l_inItem023		:=	recWkMeisai.RIRITSU_KETTEI_TMG_DD; 			-- 利率決定タイミング日数
		l_inItem.l_inItem024		:=	recWkMeisai.RIRITSU_KETTEI_TMG_NM2;			-- 利率決定タイミング名称２
		l_inItem.l_inItem025		:=	recWkMeisai.RRT_KYUJITSU_KBN_NM; 				-- 利率決定休日処理区分名称
		l_inItem.l_inItem026		:=	recWkMeisai.RRT_LD_FLG_NM; 					-- 利率決定ロンドン名称
		l_inItem.l_inItem027		:=	recWkMeisai.RRT_NY_FLG_NM; 					-- 利率決定ニューヨーク名称
		l_inItem.l_inItem028		:=	recWkMeisai.RRT_ETC_FLG_NM; 					-- 利率決定その他海外名称
		l_inItem.l_inItem029		:=	recWkMeisai.RBR_KJT_MD1;						-- 利払期日（MD）（１）
		l_inItem.l_inItem030		:=	recWkMeisai.RBR_KJT_MD2;						-- 利払期日（MD）（２）
		l_inItem.l_inItem031		:=	recWkMeisai.RBR_KJT_MD3;						-- 利払期日（MD）（３）
		l_inItem.l_inItem032		:=	recWkMeisai.RBR_KJT_MD4;						-- 利払期日（MD）（４）
		l_inItem.l_inItem033		:=	recWkMeisai.RBR_KJT_MD5;						-- 利払期日（MD）（５）
		l_inItem.l_inItem034		:=	recWkMeisai.RBR_KJT_MD6;						-- 利払期日（MD）（６）
		l_inItem.l_inItem035		:=	recWkMeisai.RBR_KJT_MD7;						-- 利払期日（MD）（７）
		l_inItem.l_inItem036		:=	recWkMeisai.RBR_KJT_MD8;						-- 利払期日（MD）（８）
		l_inItem.l_inItem037		:=	recWkMeisai.RBR_KJT_MD9;						-- 利払期日（MD）（９）
		l_inItem.l_inItem038		:=	recWkMeisai.RBR_KJT_MD10;					-- 利払期日（MD）（１０）
		l_inItem.l_inItem039		:=	recWkMeisai.RBR_KJT_MD11;					-- 利払期日（MD）（１１）
		l_inItem.l_inItem040		:=	recWkMeisai.RBR_KJT_MD12;					-- 利払期日（MD）（１２）
		l_inItem.l_inItem041		:=	recWkMeisai.HANKANEN_KBN_NM; 					-- 半ヶ年区分名称
		l_inItem.l_inItem042		:=	recWkMeisai.RBR_NISSU_SPAN; 					-- 利払日数計算間隔名称
		l_inItem.l_inItem043		:=	recWkMeisai.RBR_KJT_INCLUSION_KBN_NM; 		-- 利払期日算入区分名称
		l_inItem.l_inItem044		:=	recWkMeisai.RKN_ROUND_PROCESS_NM; 			-- 利金計算単位未満端数処理名称
		l_inItem.l_inItem045		:=	recWkMeisai.SHIKIRI_RATE; 					-- 仕切りレート
		l_inItem.l_inItem046		:=	recWkMeisai.FST_NISSUKSN_KBN_NM; 				-- 初期実日数計算区分名称
		l_inItem.l_inItem047		:=	recWkMeisai.TSUKARISHI_KNGK_FAST; 			-- １通貨あたりの利子金額（初期）
		l_inItem.l_inItem048		:=	recWkMeisai.TSUKARISHI_KNGK_FAST_S; 			-- １通貨あたりの利子金額（初期）算出値
		l_inItem.l_inItem049		:=	recWkMeisai.KICHU_NISSUKSN_KBN_NM; 			-- 期中実日数計算区分名称
		l_inItem.l_inItem050		:=	recWkMeisai.TSUKARISHI_KNGK_NORM; 			-- １通貨あたりの利子金額（通常）
		l_inItem.l_inItem051		:=	recWkMeisai.TSUKARISHI_KNGK_NORM_S; 			-- １通貨あたりの利子金額（通常）算出値
		l_inItem.l_inItem052		:=	recWkMeisai.END_NISSUKSN_KBN; 				-- 終期実日数計算区分名称
		l_inItem.l_inItem053		:=	recWkMeisai.TSUKARISHI_KNGK_LAST; 			-- １通貨あたりの利子金額（終期）
		l_inItem.l_inItem054		:=	recWkMeisai.TSUKARISHI_KNGK_LAST_S; 			-- １通貨あたりの利子金額（終期）算出値
		l_inItem.l_inItem055		:=	recWkMeisai.KK_KANYO_FLG_NM; 					-- 機構関与方式採用フラグ名称
		l_inItem.l_inItem056		:=	recWkMeisai.KOBETSU_SHONIN_SAIYO_FLG_NM; 		-- 個別承認採用フラグ名称
		l_inItem.l_inItem057		:=	recWkMeisai.KKN_ZNDK_KAKUTEI_KBN_NM; 			-- 基金残高確定区分名称
		l_inItem.l_inItem058		:=	recWkMeisai.DPT_ASSUMP_FLG_NM; 				-- デットアサンプション契約先フラグ名称
		l_inItem.l_inItem059		:=	recWkMeisai.KOZA_FURI_KBN_NM; 				-- 口座振替区分名称
		l_inItem.l_inItem060		:=	recWkMeisai.KKN_CHOKYU_KYUJITSU_KBN_NM; 		-- 基金徴求処理区分名称
		l_inItem.l_inItem061		:=	recWkMeisai.KKN_CHOKYU_TMG1_NM; 				-- 基金徴求タイミング１名称
		l_inItem.l_inItem062		:=	recWkMeisai.KKN_CHOKYU_DD; 					-- 基金徴求タイミング日数
		l_inItem.l_inItem063		:=	recWkMeisai.KKN_CHOKYU_TMG2_NM; 				-- 基金徴求タイミング２名称
		l_inItem.l_inItem064		:=	recWkMeisai.KOBETSUSEIKYUOUT_KBN_NM; 			-- 個別請求書出力区分名称
		l_inItem.l_inItem065		:=	recWkMeisai.KKNBILL_OUT_TMG1_NM; 				-- 基金請求書出力タイミング１名称
		l_inItem.l_inItem066		:=	recWkMeisai.KKNBILL_OUT_DD; 					-- 基金請求書出力タイミング日数
		l_inItem.l_inItem067		:=	recWkMeisai.KKNBILL_OUT_TMG2_NM; 				-- 基金請求書出力タイミング２名称
		l_inItem.l_inItem068		:=	recWkMeisai.SHANAI_KOMOKU1;					-- 社内処理用項目１
		l_inItem.l_inItem069		:=	recWkMeisai.SHANAI_KOMOKU2;					-- 社内処理用項目２
		l_inItem.l_inItem070		:=	recWkMeisai.YOBI1;							-- 予備１
		l_inItem.l_inItem071		:=	recWkMeisai.DKJ_MGR_CD; 						-- 独自銘柄コード
		l_inItem.l_inItem072		:=	recWkMeisai.YOBI2;							-- 予備２
		l_inItem.l_inItem073		:=	recWkMeisai.SHASAI_GENBO_OUT_KBN_NM; 			-- 社債原簿出力区分名称
		l_inItem.l_inItem074		:=	recWkMeisai.IKKATSUIKO_FLG_NM; 				-- 一括移行方式フラグ名称
		l_inItem.l_inItem075		:=	recWkMeisai.GENISIN_CD; 						-- 原ＩＳＩＮコード
		l_inItem.l_inItem076		:=	recWkMeisai.TKTI_KOZA_CD; 					-- 特定口座管理機関コード
		l_inItem.l_inItem077		:=	recWkMeisai.TKTI_KOZA_RNM; 					-- 特定口座管理機関略称
		l_inItem.l_inItem078		:=	recWkMeisai.PARTMGR_KBN_NM; 					-- 分割銘柄区分名称
		l_inItem.l_inItem079		:=	recWkMeisai.HEIZON_MGR_FLG_NM; 				-- 併存銘柄フラグ名称
		l_inItem.l_inItem080		:=	recWkMeisai.PARENT_MGR_CD; 					-- 親銘柄コード
		l_inItem.l_inItem081		:=	recWkMeisai.SHOKAN_ZUMI_FLG_NM; 				-- 子銘柄償還済みフラグ名称
		l_inItem.l_inItem082		:=	gWkTeikyoEndYmd; 								-- 適用終了日
		l_inItem.l_inItem083		:=	recWkMeisai.NEWISIN_CD; 						-- 新ＩＳＩＮコード
		l_inItem.l_inItem084		:=	gWkDefaultYmd; 								-- デフォルト日
		l_inItem.l_inItem085		:=	recWkMeisai.DEFAULT_BIKO; 					-- デフォルト備考
		l_inItem.l_inItem086		:=	gItakuKaishaRnm; 								-- 委託会社略称
		l_inItem.l_inItem087		:=	REPORT_ID1;									-- 帳票ＩＤ
		l_inItem.l_inItem088		:=	FMT_HAKKO_KNGK_J; 							-- 発行金額書式フォーマット
		l_inItem.l_inItem089		:=	FMT_RBR_KNGK_J; 								-- 利払金額書式フォーマット
		l_inItem.l_inItem090		:=	FMT_SHOKAN_KNGK_J; 							-- 償還金額書式フォーマット
		l_inItem.l_inItem091		:=	'2';											-- ページNo
		l_inItem.l_inItem092		:=	'3';											-- ページ総数
		--,l_inItem093														-- 作成年月日
		l_inItem.l_inItem094		:=	recWkMeisai.RIRITSU_KETTEI_TMG_NM1;			-- 利率決定タイミング名称１
		l_inItem.l_inItem095		:=	recWkMeisai.RRT_TKY_INV_FLG_NM; 				-- 利率決定東京無効化名称
		l_inItem.l_inItem099		:=	recWkMeisai.DEFAULT_RIYU_NM; 					-- デフォルト理由名称
		l_inItem.l_inItem100 	:=  recWkMeisai.KOZA_FURI_KBN_GANKIN_NM;     -- 口座振替区分（元金）
		l_inItem.l_inItem101 	:=  recWkMeisai.KOZA_FURI_KBN_RIKIN_NM;     -- 口座振替区分（利金）
		l_inItem.l_inItem102 	:=  recWkMeisai.DISPATCH_FLG_NM;     -- 請求書発送区分
		l_inItem.l_inItem103 	:=  recWkMeisai.GNRSHROUT_KBN_NM;     -- 元利払支払報告書出力区分
		l_inItem.l_inItem200		:=	'tokureiListFlg';							-- 特例社債情報リストかどうか判別するフラグ

		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 							-- 識別コード
			,l_inUserId			=>	l_inUserId 									-- ユーザＩＤ
			,l_inChohyoKbn		=>	l_inChohyoKbn 								-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 								-- 作成年月日
			,l_inChohyoId		=>	REPORT_ID2									-- 帳票ＩＤ
			,l_inSeqNo			=>	1											-- 連番
			,l_inHeaderFlg		=>	'1'											-- ヘッダフラグ
			,l_inItem				=>	l_inItem
			,l_inKousinId		=>	l_inUserId 									-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 									-- 作成者ID
		);

		l_inItem := ROW();
		l_inItem.l_inItem001 := l_inUserId;                        -- ユーザＩＤ
		l_inItem.l_inItem002 := recWkMeisai.KIHON_TEISEI_YMD;      -- 基本訂正日
		l_inItem.l_inItem003 := recWkMeisai.KIHON_TEISEI_USER_ID;  -- 基本訂正ユーザ
		l_inItem.l_inItem004 := recWkMeisai.LAST_SHONIN_YMD;       -- 最終承認日
		l_inItem.l_inItem005 := recWkMeisai.LAST_SHONIN_ID;        -- 最終承認ユーザ
		l_inItem.l_inItem006 := gShoninStat;                       -- 承認状態
		l_inItem.l_inItem007 := recWkMeisai.MGR_CD;                -- 銘柄コード
		l_inItem.l_inItem008 := recWkMeisai.ISIN_CD;               -- ＩＳＩＮコード
		l_inItem.l_inItem009 := recWkMeisai.MGR_RNM;               -- 銘柄略称
		l_inItem.l_inItem010 := recWkMeisai.SHIHYOKINRI_NM_ETC;    -- その他指標金利コード内容
		l_inItem.l_inItem011 := recWkMeisai.KINRIMAX_SPREAD;       -- 基準金利（上限）スプレッド
		l_inItem.l_inItem012 := recWkMeisai.KINRIFLOOR_SPREAD;     -- 基準金利（下限）スプレッド
		l_inItem.l_inItem013 := recWkMeisai.KINRIMAX_NM;           -- 基準金利（上限）名称
		l_inItem.l_inItem014 := recWkMeisai.KINRIFLOOR_NM;         -- 基準金利（下限）名称
		l_inItem.l_inItem015 := recWkMeisai.MAX_KINRI;             -- 上限金利
		l_inItem.l_inItem016 := recWkMeisai.FLOOR_KINRI;           -- 下限金利
		l_inItem.l_inItem017 := gItakuKaishaRnm;                      -- 委託会社略称
		l_inItem.l_inItem018 := REPORT_ID1;                          -- 帳票ＩＤ
		l_inItem.l_inItem019 := '3';                                 -- ページNo
		l_inItem.l_inItem020 := '3';                                 -- ページ総数
		l_inItem.l_inItem200	:= 'tokureiListFlg';							     -- 特例社債情報リストかどうか判別するフラグ

	    -- 帳票ワークへデータを追加
	    CALL pkPrint.insertData( l_inKeyCd  => l_inItakuKaishaCd                  -- 識別コード
	                                        , l_inUserId => l_inUserId                         -- ユーザＩＤ
	                                        , l_inChohyoKbn => l_inChohyoKbn                   -- 帳票区分
	                                        , l_inSakuseiYmd => l_inGyomuYmd                   -- 作成年月日
	                                        , l_inChohyoId  => REPORT_ID3                     -- 帳票ＩＤ
	                                        , l_inSeqNo     => 1                              -- 連番
	                                        , l_inHeaderFlg => '1'                            -- ヘッダフラグ
	                                        , l_inItem			=> l_inItem
	                                        , l_inKousinId =>  l_inUserId     -- 更新者ID
	                                        , l_inSakuseiId => l_inUserId     -- 作成者ID
	                                         );
	ELSE
	-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID1, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID1, 'SPIP10010 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID1, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID1, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipk001k00r14 ( l_inMgrCd CHAR, l_inItakuKaishaCd CHAR, l_inUserId CHAR, l_inChohyoKbn CHAR, l_inGyomuYmd CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;