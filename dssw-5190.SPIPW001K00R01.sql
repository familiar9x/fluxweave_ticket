




CREATE OR REPLACE PROCEDURE spipw001k00r01 ( l_inMgrCd TEXT, -- 銘柄コード
 l_inItakuKaishaCd TEXT, -- 委託会社コード
 l_inUserId TEXT, -- ユーザーID
 l_inChohyoKbn TEXT, -- 帳票区分
 l_inGyomuYmd TEXT, -- 業務日付
 l_outSqlCode OUT integer,  -- リターン値
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

	--
--  /* 著作権:Copyright(c)2008
--  /* 会社名:JIP
--  /* 概要　:銘柄情報個別照会画面から、銘柄詳細情報リスト（基本属性）を作成する。
--  /* 引数　:l_inMgrCd          IN  TEXT    銘柄コード
--  /* 　　　 l_inItakuKaishaCd  IN  TEXT    委託会社コード
--  /* 　　　 l_inUserId         IN  TEXT    ユーザーID
--  /* 　　　 l_inChohyoKbn      IN  TEXT    帳票区分
--  /* 　　　 l_inGyomuYmd       IN  TEXT    業務日付
--  /* 　　　 l_outSqlCode       OUT INTEGER   リターン値
--  /* 　　　 l_outSqlErrM       OUT VARCHAR  エラーコメント
--  /* 返り値:なし
--/* @version $Id: SPIPW001K00R01.sql,v 1.9 2009/06/05 09:22:08 fujimoto Exp $
--  /*
--  ***************************************************************************
--  /* ログ　:
--  /* 　　　日付  開発者名    目的
--  /* -------------------------------------------------------------------
--  /*　2008.02.14 JIP       新規作成
--  /*　2017.12.14 呉志尚    法貸移管対応：信託フラグの追加
--  ***************************************************************************
--	
--	/*==============================================================================
	--          配列定義                          
	--==============================================================================
	-- TYPE SPIPW001K00R01_TYPE_VARCHAR2 IS TABLE OF varchar(100) INDEX BY integer;
	-- In PostgreSQL, we'll use varchar[] arrays instead
	--==============================================================================
	--          定数定義                          
	--==============================================================================
	RTN_OK     CONSTANT integer := 0;  -- 正常
	RTN_NG     CONSTANT integer := 1;  -- 予期したエラー
	RTN_NODATA CONSTANT integer := 2;  -- データなし
	RTN_FATAL  CONSTANT integer := 99; -- 予期せぬエラー
	REPORT_ID1 CONSTANT char(11) := 'IPW30000111'; -- 帳票ID
	REPORT_ID2 CONSTANT char(11) := 'IPW30000112'; -- 帳票ID
	REPORT_ID3 CONSTANT char(11) := 'IPW30000113'; -- 帳票ID
	--==============================================================================
	--          変数定義                          
	--==============================================================================
	gRtnCd integer := RTN_OK; -- リターンコード
	gSeqNo integer := 0; -- シーケンス
	gArySknKessaiCd varchar[];  -- 社債管理者コード１〜１０
	gArySknKessaiNm varchar[];  -- 社債管理者名１〜１０
	gItakuKaishaRnm VJIKO_ITAKU.BANK_RNM%TYPE; -- 委託会社略称
	gBankRnm        SOWN_INFO.BANK_RNM%TYPE;   -- 銀行略称
	
	-- 西暦変換用
	gWkBoshuStYmd              varchar(20) := NULL; -- 募集開始日
	gWkHakkoYmd                varchar(20) := NULL; -- 発行年月日
	gWkSknChgYmd               varchar(20) := NULL; -- 資金付替日
	gWkSknKofuYmd              varchar(20) := NULL; -- 資金交付日
	gWkFullshokanKjt           varchar(20) := NULL; -- 満期償還期日
	gWkTrustShoshoYmd          varchar(20) := NULL; -- 信託証書日付
	gWkHakkoKykYmd             varchar(20) := NULL; -- 発行契約日
	gWkStRbrKjt                varchar(20) := NULL; -- 初回利払期日
	gWkTeikyoStYmd             varchar(20) := NULL; -- 適用開始日
	gWkWrntUseKagakuKetteiYmd  varchar(20) := NULL; -- 行使価額決定日
	gWkWrntUseStYmd            varchar(20) := NULL; -- 行使期間開始日
	gWkWrntUseEdYmd            varchar(20) := NULL; -- 行使期間終了日
	gWkShtkJkYmd               varchar(20) := NULL; -- 取得条項に係る取得日
	gWkDefaultYmd              varchar(20) := NULL; -- デフォルト日
	
	-- 最終承認ユーザ及び最終承認日
	gLastShoninId              VMGR_STS.LAST_SHONIN_ID%TYPE;      -- 最終承認ユーザId
	gLastShoninYmd             VMGR_STS.LAST_SHONIN_YMD%TYPE;     -- 最終承認日
	gYobi3 MGR_KIHON.YOBI3%TYPE; -- 予備３
	gRetenFlg MGR_STS.MGR_SEND_TAISHO_FLG%TYPE; -- 機構送信対象フラグ
	
	-- プットオプション関連
	gPutShokanKjt			UPD_MGR_SHN.SHR_KJT%TYPE;
	gPutShokanPremium		UPD_MGR_SHN.SHOKAN_PREMIUM%TYPE;
    gPutStkoshikikanYmd		UPD_MGR_SHN.ST_PUTKOSHIKIKAN_YMD%TYPE;
    gPutEdkoshikikanYmd		UPD_MGR_SHN.ED_PUTKOSHIKIKAN_YMD%TYPE;
    gPutKkStat				UPD_MGR_SHN.KK_STAT%TYPE;
    wkPutShokanKagaku		numeric;
	v_item                  type_sreport_wk_item;          -- 帳票ワーク項目
	--==============================================================================
	--          カーソル定義                          
	--==============================================================================
	curMeisai CURSOR FOR
	     SELECT  MG0.KIHON_TEISEI_YMD,                            -- 基本訂正日
	             MG0.KIHON_TEISEI_USER_ID,                        -- 基本訂正ユーザ
	             MG0.LAST_SHONIN_YMD,                             -- 最終承認日
	             MG0.LAST_SHONIN_ID,                              -- 最終承認ユーザ
	             MG0.MGR_STAT_KBN,                                -- 銘柄ステータス区分
	             (SELECT  CODE_NM
	              FROM    SCODE
	              WHERE   MG0.MGR_STAT_KBN = CODE_VALUE AND
	                      CODE_SHUBETSU = '161') AS SHONIN_STAT,  -- 承認状態
	             MG0.MGR_SEND_TAISHO_FLG,                         -- 銘柄機構送信対象フラグ
	             VMG1.MGR_CD,                                     -- 銘柄コード
	             VMG1.ISIN_CD,                                    -- ＩＳＩＮコード
	             VMG1.MGR_RNM,                                    -- 銘柄略称
	             WMG1.TEKIYOST_YMD,                               -- 適用開始日
	             WMG1.KK_MGR_CD,                                  -- 機構銘柄コード
	             VMG1.JTK_KBN_NM,                                 -- 受託区分名称
	             VMG1.HKT_CD,                                     -- 発行体コード
	             M01.HKT_RNM,                                     -- 発行体略称
	             VMG1.EIGYOTEN_CD,                                -- 営業店店番
	             (SELECT  M04.BUTEN_RNM
	              FROM    MBUTEN M04
	              WHERE   VMG1.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD
	              AND     VMG1.EIGYOTEN_CD = M04.BUTEN_CD) AS EIGYOTEN_NM,      -- 営業店名称
	             VMG1.HAKKODAIRI_CD,                                            -- 発行代理人コード
	             (SELECT VM02.BANK_RNM
	              FROM   VMBANK VM02
	              WHERE  VMG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
	              AND    substr(VMG1.HAKKODAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
	              AND    substr(VMG1.HAKKODAIRI_CD, 2) = VM02.BANK_CD ) AS HAKKODAIRI_RNM,             -- 発行代理人略称
	             M01.KOZA_TEN_CD,                                 -- 口座店コード
	             M01.KOZA_TEN_CIFCD,                              -- 口座店ＣＩＦコード
	             VMG1.SHRDAIRI_CD,                                -- 支払代理人コード
	             (SELECT  VM02.BANK_RNM
	              FROM    VMBANK VM02
	              WHERE  VMG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
	              AND    substr(VMG1.SHRDAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN 
	              AND    substr(VMG1.SHRDAIRI_CD, 2) = VM02.BANK_CD ) AS SHRDAIRI_RNM,                 -- 支払代理人略称
	             VMG1.SKN_KESSAI_CD,                              -- 資金決済会社コード
	             pkIpaName.getSknKessaiRnm(VMG1.ITAKU_KAISHA_CD,VMG1.SKN_KESSAI_CD) AS SKN_KESSAI_RNM,-- 資金決済会社略
	             VMG1.MGR_NM,                                     -- 銘柄の正式名称
	             VMG1.KK_HAKKO_CD,                                -- 機構発行体コード
	             VMG1.KK_HAKKOSHA_RNM,                            -- 機構発行者略称
	             VMG1.KAIGO_ETC,                                  -- 回号等
	             VMG1.BOSHU_KBN,                                  -- 募集区分
	             VMG1.BOSHU_KBN_NM,                               -- 募集区分名称
	             VMG1.KOKYAKU_BOSHU_KBN_NM,                       -- 対顧用募集区分名称
	             VMG1.KOKYAKU_MGR_RNM,                            -- 対顧用銘柄略称
	              (SELECT  CODE_NM
	              FROM    SCODE
	              WHERE   WMG1.JOJO_KBN_TO = CODE_VALUE AND
	                      CODE_SHUBETSU = '599') AS JOJO_KBN_TO,  -- 上場区分（東証)
	              (SELECT  CODE_NM
	              FROM    SCODE
	              WHERE   WMG1.JOJO_KBN_DA = CODE_VALUE AND
	                      CODE_SHUBETSU = '599') AS JOJO_KBN_DA,  -- 上場区分（大証)
	                       (SELECT  CODE_NM
	              FROM    SCODE
	              WHERE   WMG1.JOJO_KBN_ME = CODE_VALUE AND
	                      CODE_SHUBETSU = '599') AS JOJO_KBN_ME,  -- 上場区分（名証)
	                       (SELECT  CODE_NM
	              FROM    SCODE
	              WHERE   WMG1.JOJO_KBN_FU = CODE_VALUE AND
	                      CODE_SHUBETSU = '599') AS JOJO_KBN_FU,  -- 上場区分（福証)
	                       (SELECT  CODE_NM
	              FROM    SCODE
	              WHERE   WMG1.JOJO_KBN_SA = CODE_VALUE AND
	                      CODE_SHUBETSU = '599') AS JOJO_KBN_SA,  -- 上場区分（札証)
	              (SELECT  CODE_NM
	              FROM    SCODE
	              WHERE   WMG1.JOJO_KBN_JA = CODE_VALUE AND
	                      CODE_SHUBETSU = '599') AS JOJO_KBN_JA,  -- 上場区分（ジャスダック証)
	             VMG1.SAIKEN_KBN_NM,                              -- 債券種類名称
	             VMG1.HOSHO_KBN_NM,                               -- 保証区分名称
	             VMG1.TANPO_KBN_NM,                               -- 担保区分名称
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.GODOHAKKO_FLG = CODE_VALUE 
	              AND    CODE_SHUBETSU = '513') AS GODOHAKKO_FLG_NM,                 -- 合同発行フラグ名称
	             VMG1.BOSHU_ST_YMD,                               -- 募集開始日
	             VMG1.HAKKO_YMD,                                  -- 発行年月日
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.SKNNZISNTOKU_UMU_FLG = CODE_VALUE 
	              AND    CODE_SHUBETSU = '517') AS SKNNZISNTOKU_UMU_FLG_NM,          -- 責任財産限定特約有無フラグ名称
	             VMG1.SKN_CHG_YMD,                                -- 資金付替日
	             VMG1.SKN_KOFU_YMD,                               -- 資金交付日
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.RETSUTOKU_UMU_FLG = CODE_VALUE AND
	                     CODE_SHUBETSU = '530') AS RETSUTOKU_UMU_FLG_NM, -- 劣後特約有無フラグ名称
	             CASE WHEN VMG1.BNK_GUARANTEE_RATE=0 THEN  NULL  ELSE VMG1.BNK_GUARANTEE_RATE END  AS BNK_GUARANTEE_RATE,       -- 銀行保証料率
	             CASE WHEN VMG1.HOSHO_GUARANTEE_RATE=0 THEN  NULL  ELSE VMG1.HOSHO_GUARANTEE_RATE END  AS HOSHO_GUARANTEE_RATE, -- 保証協会保証料率
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.UCHIKIRI_HAKKO_FLG = CODE_VALUE 
	              AND    CODE_SHUBETSU = '518') AS UCHIKIRI_HAKKO_FLG_NM,                        -- 打切発行フラグ名称
	             CASE WHEN VMG1.KAKUSHASAI_KNGK=0 THEN  NULL  ELSE VMG1.KAKUSHASAI_KNGK END  AS KAKUSHASAI_KNGK, -- 各社債の金額
	             VMG1.HAKKO_KAGAKU,                  -- 発行価額
	             CASE WHEN VMG1.SHASAI_TOTAL=0 THEN  NULL  ELSE VMG1.SHASAI_TOTAL END  AS SHASAI_TOTAL,          -- 社債の総額
	             VMG1.FULLSHOKAN_KJT,                            -- 満期償還期日
                 CASE WHEN WMG1.SHOKAN_PREMIUM=0 THEN  NULL  ELSE WMG1.SHOKAN_PREMIUM END  AS SHOKAN_PREMIUM,    -- 償還プレミアム
	             (KAKUSHASAI_KNGK + WMG1.SHOKAN_PREMIUM) AS SHOKAN_KAGAKU,                       -- 償還価額
	             VMG1.CALLALL_UMU_FLG_NM,                        -- コールオプション有無（全額）名称
	             VMG1.PUTUMU_FLG_NM,                             -- プットオプション有無名称
	             MG6.BANK_CD AS SHASAI_KANRI_JUTAKU_CD,          -- 社債管理者コード
	             (SELECT VM02.BANK_RNM
	              FROM   VMBANK VM02
	              WHERE  MG6.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
	              AND    MG6.FINANCIAL_SECURITIES_KBN = VM02.FINANCIAL_SECURITIES_KBN
	              AND    MG6.BANK_CD = VM02.BANK_CD) AS SHASAI_KANRI_JUTAKU_RNM,                 -- 社債管理者名称
	             VMG1.TRUST_SHOSHO_YMD,                          -- 信託証書日付
	             VMG1.HAKKO_KYK_YMD,                             -- 発行契約日
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.PARTHAKKO_UMU_FLG = CODE_VALUE 
	              AND    CODE_SHUBETSU = '525') AS PARTHAKKO_UMU_FLG_NM,        -- 分割発行有無フラグ名称
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.KYUJITSU_KBN = CODE_VALUE 
	              AND    CODE_SHUBETSU = '506') AS KYUJITSU_KBN_NM,             -- 休日処理区分名称
	             VMG1.RITSUKE_WARIBIKI_KBN_NM,                                  -- 利付割引区分名称
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.NENRBR_CNT = CODE_VALUE
	              AND    CODE_SHUBETSU = '142') AS NENRBR_CNT_NM,-- 年利払回数(名称)
	             CASE WHEN VMG1.TOTAL_RBR_CNT=0 THEN  NULL  ELSE VMG1.TOTAL_RBR_CNT END  AS TOTAL_RBR_CNT,          -- 総利払回数
	             VMG1.RBR_DD, -- 利払日付
	             VMG1.ST_RBR_KJT,                                               -- 初回利払期日
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.LAST_RBR_FLG = CODE_VALUE 
	              AND    CODE_SHUBETSU = '515') AS LAST_RBR_FLG_NM,             -- 最終利払有無フラグ名称
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.KIJUN_KINRI_CD1 = CODE_VALUE 
	              AND    CODE_SHUBETSU = '140') AS KIJUN_KINRI_NM1,             -- 基準金利１名称,
	             CASE WHEN VMG1.RIRITSU=0 THEN  NULL  ELSE VMG1.RIRITSU END  AS RIRITSU,        -- 利率
	             CASE WHEN VMG1.SPREAD=0 THEN  NULL  ELSE VMG1.SPREAD END  AS SPREAD,           -- スプレッド
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.KIJUN_KINRI_CD2 = CODE_VALUE 
	              AND    CODE_SHUBETSU = '140') AS KIJUN_KINRI_NM2,             -- 基準金利２名称
	             VMG1.KIJUN_KINRI_CMNT, -- 基準金利コメント
	             CASE WHEN VMG1.RIRITSU_KETTEI_TMG_DD=0 THEN  NULL  ELSE VMG1.RIRITSU_KETTEI_TMG_DD END  AS RIRITSU_KETTEI_TMG_DD, -- 利率決定タイミング日数
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.RIRITSU_KETTEI_TMG1 = CODE_VALUE 
	              AND    CODE_SHUBETSU = '222') AS RIRITSU_KETTEI_TMG_NM1,      -- 利率決定タイミング名称１
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.RIRITSU_KETTEI_TMG2 = CODE_VALUE
	              AND    CODE_SHUBETSU = '132') AS RIRITSU_KETTEI_TMG_NM2,      -- 利率決定タイミング名称２
	             (SELECT CODE_NM
	              FROM   SCODE
	              WHERE  VMG1.RRT_KYUJITSU_KBN = CODE_VALUE
	              AND    CODE_SHUBETSU = '506') AS RRT_KYUJITSU_KBN_NM,         -- 利率決定休日処理区分名称
	              VMG1.RBR_KJT_MD1,                              -- 利払期日（MD）（１）
	              VMG1.RBR_KJT_MD2,                              -- 利払期日（MD）（２）
	              VMG1.RBR_KJT_MD3,                              -- 利払期日（MD）（３）
	              VMG1.RBR_KJT_MD4,                              -- 利払期日（MD）（４）
	              VMG1.RBR_KJT_MD5,                              -- 利払期日（MD）（５）
	              VMG1.RBR_KJT_MD6,                              -- 利払期日（MD）（６）
	              VMG1.RBR_KJT_MD7,                              -- 利払期日（MD）（７）
	              VMG1.RBR_KJT_MD8,                              -- 利払期日（MD）（８）
	              VMG1.RBR_KJT_MD9,                              -- 利払期日（MD）（９）
	              VMG1.RBR_KJT_MD10,                             -- 利払期日（MD）（１０）
	              VMG1.RBR_KJT_MD11,                             -- 利払期日（MD）（１１）
	              VMG1.RBR_KJT_MD12,                             -- 利払期日（MD）（１２）
	              (SELECT CODE_NM
	               FROM   SCODE
	               WHERE  VMG1.HANKANEN_KBN = CODE_VALUE
	               AND    CODE_SHUBETSU = '124') AS HANKANEN_KBN_NM,            -- 半ヶ年区分名称
	              (SELECT CODE_NM
	               FROM   SCODE
	               WHERE  VMG1.RBR_NISSU_SPAN = CODE_VALUE
	               AND    CODE_SHUBETSU = '131') AS RBR_NISSU_SPAN,             -- 利払日数計算間隔名称
	              (SELECT CODE_NM
	               FROM   SCODE
	              WHERE  VMG1.RBR_KJT_INCLUSION_KBN = CODE_VALUE 
	              AND    CODE_SHUBETSU = '130') AS RBR_KJT_INCLUSION_KBN_NM,    -- 利払期日算入区分名称
	              (SELECT CODE_NM
	               FROM   SCODE
	               WHERE  VMG1.RKN_ROUND_PROCESS = CODE_VALUE
	               AND    CODE_SHUBETSU = '128') AS RKN_ROUND_PROCESS_NM,       -- 利金計算単位未満端数処理名称
	              CASE WHEN VMG1.SHIKIRI_RATE=0 THEN  NULL  ELSE VMG1.SHIKIRI_RATE END  AS SHIKIRI_RATE, -- 仕切りレート
	              (SELECT CODE_NM
	               FROM   SCODE
	               WHERE  VMG1.FST_NISSUKSN_KBN = CODE_VALUE
	               AND    CODE_SHUBETSU = '121') AS FST_NISSUKSN_KBN_NM,        -- 初期実日数計算区分名称
	              CASE WHEN VMG1.TSUKARISHI_KNGK_FAST=0 THEN  NULL  ELSE VMG1.TSUKARISHI_KNGK_FAST END  AS TSUKARISHI_KNGK_FAST,       -- １通貨あたりの利子金額（初期）
	              CASE WHEN VMG1.TSUKARISHI_KNGK_FAST_S=0 THEN  NULL  ELSE VMG1.TSUKARISHI_KNGK_FAST_S END  AS TSUKARISHI_KNGK_FAST_S, -- １通貨あたりの利子金額（初期）算出値
	              (SELECT CODE_NM
	               FROM   SCODE
	               WHERE  VMG1.KICHU_NISSUKSN_KBN = CODE_VALUE
	               AND    CODE_SHUBETSU = '121') AS KICHU_NISSUKSN_KBN_NM,     -- 期中実日数計算区分名称
	               CASE WHEN VMG1.TSUKARISHI_KNGK_NORM=0 THEN  NULL  ELSE VMG1.TSUKARISHI_KNGK_NORM END  AS TSUKARISHI_KNGK_NORM,       -- １通貨あたりの利子金額（通常）
	               CASE WHEN VMG1.TSUKARISHI_KNGK_NORM_S=0 THEN  NULL  ELSE VMG1.TSUKARISHI_KNGK_NORM_S END  AS TSUKARISHI_KNGK_NORM_S, -- １通貨あたりの利子金額（通常）算出値
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.END_NISSUKSN_KBN = CODE_VALUE
	                AND    CODE_SHUBETSU = '121') AS END_NISSUKSN_KBN,         -- 終期実日数計算区分名称
	               CASE WHEN VMG1.TSUKARISHI_KNGK_LAST=0 THEN  NULL  ELSE VMG1.TSUKARISHI_KNGK_LAST END  AS TSUKARISHI_KNGK_LAST,       -- １通貨あたりの利子金額（終期）
	               CASE WHEN VMG1.TSUKARISHI_KNGK_LAST_S=0 THEN  NULL  ELSE VMG1.TSUKARISHI_KNGK_LAST_S END  AS TSUKARISHI_KNGK_LAST_S, -- １通貨あたりの利子金額（終期）算出値
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KKN_ZNDK_KAKUTEI_KBN = CODE_VALUE
	                AND    CODE_SHUBETSU = '181') AS KKN_ZNDK_KAKUTEI_KBN_NM,  -- 基金残高確定区分
	               WMG1.WRNT_TOTAL,                                            -- 新株予約権の総数
	               WMG1.WRNT_USE_KAGAKU_KETTEI_YMD,                            -- 新株予約権の行使価額決定日
	               WMG1.WRNT_USE_ST_YMD,                                       -- 新株予約権の行使期間開始日
	               WMG1.WRNT_USE_ED_YMD,                                       -- 新株予約権の行使期間終了日
	               WMG1.WRNT_HAKKO_KAGAKU,                                     -- 新株予約権の発行価額
	               WMG1.WRNT_USE_KAGAKU,                                       -- 新株予約権の行使価額
 	               (SELECT SUBSTR(CODE_NM, 1, 15)
	                FROM   SCODE
	                WHERE  WMG1.USE_SEIKYU_UKE_BASHO = CODE_VALUE
	                AND    CODE_SHUBETSU = '596') AS useSeikyuUkeBasho,        -- 行使請求受付場所名称
 	               WMG1.WRNT_BIKO,                                             -- 新株予約権に係る備考
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  WMG1.SHTK_JK_UMU_FLG = CODE_VALUE
	                AND    CODE_SHUBETSU = '600') AS SHTK_JK_UMU_FLG,          -- 取得条項有無フラグ
	               WMG1.SHTK_JK_YMD,                                           -- 取得条項に係る取得日
                  (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  WMG1.SHTK_TAIKA_SHURUI = CODE_VALUE
	                AND    CODE_SHUBETSU = '597') AS  SHTK_TAIKA_SHURUI,       -- 取得対価の種類名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  WMG1.HASU_SHOKAN_UMU_FLG = CODE_VALUE
	                AND    CODE_SHUBETSU = '601') AS HASU_SHOKAN_UMU_FLG,      -- 端数償還金有無フラグ
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KK_KANYO_FLG = CODE_VALUE
	                AND    CODE_SHUBETSU = '164') AS KK_KANYO_FLG_NM,          -- 機構関与方式採用フラグ名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KOBETSU_SHONIN_SAIYO_FLG = CODE_VALUE
	                AND    CODE_SHUBETSU = '511') AS KOBETSU_SHONIN_SAIYO_FLG_NM,   -- 個別承認採用フラグ名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.DPT_ASSUMP_FLG = CODE_VALUE 
	                AND    CODE_SHUBETSU = '170') AS DPT_ASSUMP_FLG_NM,         -- デットアサンプション契約先フラグ名称
	               (SELECT KOZA_FURI_KBN_NM
	                FROM   KOZA_FRK
	                WHERE  ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD 
	                AND    KOZA_FURI_KBN = VMG1.KOZA_FURI_KBN) AS KOZA_FURI_KBN_NM, -- 口座振替区分名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KKN_CHOKYU_TMG1 = CODE_VALUE 
	                AND    CODE_SHUBETSU = '135') AS KKN_CHOKYU_TMG1_NM,         -- 元利基金徴求タイミング１名称
	               VMG1.KKN_CHOKYU_DD,                                           -- 元利基金徴求タイミング日数
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KKN_CHOKYU_TMG2 = CODE_VALUE 
	                AND    CODE_SHUBETSU = '132') AS KKN_CHOKYU_TMG2_NM,         -- 元利基金徴求タイミング２名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KOBETSUSEIKYUOUT_KBN = CODE_VALUE
	                AND    CODE_SHUBETSU = '165') AS KOBETSUSEIKYUOUT_KBN_NM,    -- 個別請求書出力区分名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KKNBILL_OUT_TMG1 = CODE_VALUE
	                AND    CODE_SHUBETSU = '135') AS KKNBILL_OUT_TMG1_NM,        -- 基金請求書出力タイミング１名称
	               CASE WHEN VMG1.KKNBILL_OUT_DD=0 THEN  NULL  ELSE VMG1.KKNBILL_OUT_DD END  AS KKNBILL_OUT_DD,   -- 基金請求書出力タイミング日数
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KKNBILL_OUT_TMG2 = CODE_VALUE 
	                AND    CODE_SHUBETSU = '132') AS KKNBILL_OUT_TMG2_NM,        -- 基金請求書出力タイミング２名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.KKN_CHOKYU_KYUJITSU_KBN = CODE_VALUE 
	                AND    CODE_SHUBETSU = '506') AS KKN_CHOKYU_KYUJITSU_KBN_NM, -- 基金徴求休日処理区分
	               WMG1.SHANAI_KOMOKU1,                          -- 社内処理用項目１
	               WMG1.SHANAI_KOMOKU2,                          -- 社内処理用項目２
	               VMG1.YOBI1,                                   -- 予備１
	               VMG1.YOBI2,                                   -- 予備２
	               VMG1.YOBI3,                                   -- 予備３
	               VMG1.DKJ_MGR_CD,                              -- 独自銘柄コード
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  TRIM(BOTH FROM VMG1.SHASAI_GENBO_OUT_KBN) = CODE_VALUE
	                AND    CODE_SHUBETSU = '169' ) AS SHASAI_GENBO_OUT_KBN_NM,          -- 社債原簿出力区分名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.TOKUREI_SHASAI_FLG = CODE_VALUE
	                AND CODE_SHUBETSU = '522') AS TOKUREI_SHASAI_FLG_NM,               -- 特例社債フラグ名称
	               (SELECT CODE_NM
	                FROM   SCODE
	                WHERE  VMG1.HEIZON_MGR_FLG = CODE_VALUE 
	                AND    CODE_SHUBETSU = '171') AS HEIZON_MGR_FLG_NM,                -- 併存銘柄フラグ名称
	               VMG1.DEFAULT_YMD,                             -- デフォルト日
	               (SELECT  DE02.DEFAULT_RIYU_NM
	                FROM    DEFAULT_RIYU_KANRI DE02
	                WHERE   DE02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	                AND     DE02.DEFAULT_RIYU = VMG1.DEFAULT_RIYU) AS DEFAULT_RIYU_NM, -- デフォルト理由名称
	               VMG1.DEFAULT_BIKO,                            -- デフォルト備考
	               VJ1.BANK_RNM,                                 -- 銀行略称
	               VJ1.JIKO_DAIKO_KBN,                           -- 自行代行区分
	               VMG1.TOKUREI_SHASAI_FLG,                      -- 特例債フラグ
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
	               CASE WHEN BT03.FLOOR_KINRI=0 THEN  NULL  ELSE BT03.FLOOR_KINRI END  AS FLOOR_KINRI, -- 下限金利
	               (SELECT CODE_RNM FROM SCODE WHERE CODE_VALUE = BT03.MUTB_FLG AND CODE_SHUBETSU = 'B23') AS MUTB_FLG_NM  -- 信託フラグ名称
	    FROM cb_mgr_kihon wmg1, vjiko_itaku vj1, mgr_sts mg0, mhakkotai m01, mgr_kihon2 bt03, mhakkotai2 bt01, vmgr_list vmg1
LEFT OUTER JOIN mgr_jutakuginko mg6 ON (VMG1.MGR_CD = MG6.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG6.ITAKU_KAISHA_CD)
WHERE VMG1.MGR_CD = l_inMgrCd AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.MGR_CD = MG0.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND VMG1.MGR_CD = BT03.MGR_CD AND VMG1.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = BT01.HKT_CD AND VMG1.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD   AND VMG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID AND VMG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD AND VMG1.MGR_CD = WMG1.MGR_CD
	    ORDER  BY 
	               MG6.JTK_KBN,
	               MG6.INPUT_NUM;
	-- レコード
	recWkMeisai RECORD;
	--==============================================================================
	--  メイン処理 
	--==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF   coalesce(trim(both l_inMgrCd)::text, '') = '' OR
	     coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR
	     coalesce(trim(both l_inUserId)::text, '') = '' OR
	     coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR
	     coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
	    -- パラメータエラー
	    l_outSqlCode := RTN_NG;
	    l_outSqlErrM := '';
	    CALL pkLog.error(l_inUserId, REPORT_ID1, 'SQLERRM:' || '');
	    RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE  KEY_CD = l_inItakuKaishaCd
	AND    USER_ID = l_inUserId
	AND    CHOHYO_KBN = l_inChohyoKbn 
	AND    SAKUSEI_YMD = l_inGyomuYmd 
	AND (CHOHYO_ID = REPORT_ID1 OR CHOHYO_ID = REPORT_ID2 OR CHOHYO_ID = REPORT_ID3);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID1);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID2);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID3);
	-- 配列の初期化
	gArySknKessaiCd := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gArySknKessaiNm := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	-- ５−０．自行情報マスタから銀行略称を取得
	SELECT
	    BANK_RNM
	INTO STRICT
	    gBankRnm
	FROM SOWN_INFO;
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
	    gSeqNo := gSeqNo + 1;
	    IF gSeqNo = 1
	    THEN
	        -- レコードのセット
	        recWkMeisai := recMeisai;
	    END IF;
	    gArySknKessaiCd[gSeqNo] := recMeisai.SHASAI_KANRI_JUTAKU_CD;
	    gArySknKessaiNm[gSeqNo] := recMeisai.SHASAI_KANRI_JUTAKU_RNM;
	END LOOP;
	IF gSeqNo > 0
	THEN
	    -- 対象データあり
	    -- 委託会社略称の設定
	    gItakuKaishaRnm := NULL;
	    IF recWkMeisai.JIKO_DAIKO_KBN = '2'
	    THEN
	        gItakuKaishaRnm := recWkMeisai.BANK_RNM;
	    END IF;
	    --  募集開始日（西暦編集）
	    gWkBoshuStYmd := NULL;
	    IF (trim(both recWkMeisai.BOSHU_ST_YMD) IS NOT NULL AND (trim(both recWkMeisai.BOSHU_ST_YMD))::text <> '')
	    THEN
	        gWkBoshuStYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.BOSHU_ST_YMD);
	    END IF;
	    --  発行年月日（西暦編集）
	    gWkHakkoYmd := NULL;
	    IF (trim(both recWkMeisai.HAKKO_YMD) IS NOT NULL AND (trim(both recWkMeisai.HAKKO_YMD))::text <> '')
	    THEN
	        gWkHakkoYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.HAKKO_YMD);
	    END IF;
	    --  資金付替日（西暦編集）
	    gWkSknChgYmd := NULL;
	    IF (trim(both recWkMeisai.SKN_CHG_YMD) IS NOT NULL AND (trim(both recWkMeisai.SKN_CHG_YMD))::text <> '')
	    THEN
	        gWkSknChgYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.SKN_CHG_YMD);
	    END IF;
	    --  資金交付日（西暦編集）
	    gWkSknKofuYmd := NULL;
	    IF (trim(both recWkMeisai.SKN_KOFU_YMD) IS NOT NULL AND (trim(both recWkMeisai.SKN_KOFU_YMD))::text <> '')
	    THEN
	        gWkSknKofuYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.SKN_KOFU_YMD);
	    END IF;
	    --  満期償還期日（西暦編集）-- 99999999のデータだけありえるのでそれに対処。
	    gWkFullshokanKjt := NULL;
	    IF trim(both recWkMeisai.FULLSHOKAN_KJT) = '99999999'	--	償還期日が9999/99/99 だったら
	    THEN
	        gWkFullshokanKjt := recWkMeisai.FULLSHOKAN_KJT;
	    ELSIF (trim(both recWkMeisai.FULLSHOKAN_KJT) IS NOT NULL AND (trim(both recWkMeisai.FULLSHOKAN_KJT))::text <> '')
	    THEN
	        gWkFullshokanKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.FULLSHOKAN_KJT);
	    END IF;
	    --  信託証書日付（西暦編集）
	    gWkTrustShoshoYmd := NULL;
	    IF (trim(both recWkMeisai.TRUST_SHOSHO_YMD) IS NOT NULL AND (trim(both recWkMeisai.TRUST_SHOSHO_YMD))::text <> '')
	    THEN
	        gWkTrustShoshoYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.TRUST_SHOSHO_YMD);
	    END IF;
	    --  発行契約日（西暦編集）
	    gWkHakkoKykYmd := NULL;
	    IF (trim(both recWkMeisai.HAKKO_KYK_YMD) IS NOT NULL AND (trim(both recWkMeisai.HAKKO_KYK_YMD))::text <> '')
	    THEN
	        gWkHakkoKykYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.HAKKO_KYK_YMD);
	    END IF;
	    --  初回利払期日（西暦編集）
	    gWkStRbrKjt := NULL;
	    IF (trim(both recWkMeisai.ST_RBR_KJT) IS NOT NULL AND (trim(both recWkMeisai.ST_RBR_KJT))::text <> '')
	    THEN
	        gWkStRbrKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.ST_RBR_KJT);
	    END IF;
	    --  適用開始日（西暦編集）
	    gWkTeikyoStYmd := recWkMeisai.TEKIYOST_YMD;
	    IF (trim(both gWkTeikyoStYmd) IS NOT NULL AND (trim(both gWkTeikyoStYmd))::text <> '') AND gWkTeikyoStYmd != '99999999'
	    THEN
	        gWkTeikyoStYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.TEKIYOST_YMD);
	    END IF;
	    --  行使価額決定日（西暦編集）
	    gWkWrntUseKagakuKetteiYmd := NULL;
	    IF (trim(both recWkMeisai.WRNT_USE_KAGAKU_KETTEI_YMD) IS NOT NULL AND (trim(both recWkMeisai.WRNT_USE_KAGAKU_KETTEI_YMD))::text <> '')
	    THEN
	        gWkWrntUseKagakuKetteiYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.WRNT_USE_KAGAKU_KETTEI_YMD);
	    END IF;
	     --  行使期間開始日（西暦編集）
	    gWkWrntUseStYmd := NULL;
	    IF (trim(both recWkMeisai.WRNT_USE_ST_YMD) IS NOT NULL AND (trim(both recWkMeisai.WRNT_USE_ST_YMD))::text <> '')
	    THEN
	        gWkWrntUseStYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.WRNT_USE_ST_YMD);
	    END IF;
	     --  行使期間終了日（西暦編集）-- 99999999のデータだけありえるのでそれに対処。
	    gWkWrntUseEdYmd := NULL;
	    IF trim(both recWkMeisai.WRNT_USE_ED_YMD) = '99999999'	--	行使期間終了日が9999/99/99 だったら
	    THEN
	        gWkWrntUseEdYmd := recWkMeisai.WRNT_USE_ED_YMD;
	    ELSIF (trim(both recWkMeisai.WRNT_USE_ED_YMD) IS NOT NULL AND (trim(both recWkMeisai.WRNT_USE_ED_YMD))::text <> '')
	    THEN
	        gWkWrntUseEdYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.WRNT_USE_ED_YMD);
	    END IF;
	     --  取得条項に係る取得日（西暦編集）
	    gWkShtkJkYmd := NULL;
	    IF (trim(both recWkMeisai.SHTK_JK_YMD) IS NOT NULL AND (trim(both recWkMeisai.SHTK_JK_YMD))::text <> '')
	    THEN
	        gWkShtkJkYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.SHTK_JK_YMD);
	    END IF;
	    --  デフォルト日（西暦編集）
	    gWkDefaultYmd := NULL;
	    IF (trim(both recWkMeisai.DEFAULT_YMD) IS NOT NULL AND (trim(both recWkMeisai.DEFAULT_YMD))::text <> '')
	    THEN
	        gWkDefaultYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.DEFAULT_YMD);
	    END IF;
	    -- 最終承認ユーザの表示非表示切り替え
	    -- はじめに初期化しておく
	    gLastShoninYmd := NULL;
	    gLastShoninId  := NULL;
	    -- 承認ステータスが承認以外の場合には表示しないようにする
	    IF recWkMeisai.MGR_STAT_KBN = '1'
	    THEN
	        gLastShoninYmd := recWkMeisai.LAST_SHONIN_YMD;
	        gLastShoninId  := recWkMeisai.LAST_SHONIN_ID;
	    END IF;
	    -- 予備３ -- 特例債銘柄の場合、表示しないようにする。
	    gYobi3 := NULL;
	    IF recWkMeisai.TOKUREI_SHASAI_FLG <> 'Y'
	    THEN
	        gYobi3 := recWkMeisai.YOBI3;
	    END IF;
	    -- 仮登録時も機構送信項目にレ点を表示させる。
	    gRetenFlg := NULL;
	    IF recWkMeisai.MGR_STAT_KBN = '2' THEN
	        gRetenFlg := '1';
	    ELSE
	        gRetenFlg := recWkMeisai.MGR_SEND_TAISHO_FLG;
	    END IF;
	    -- 銘柄情報通知（ＣＢ）改善オプションフラグ ＝ "1" の場合
		IF pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'CBMGR_TSUCHI', '0')::integer = 1 THEN
			-- プットオプション行使条件を取得する
			SELECT l_outPutShokanKjt, l_outPutShokanPremium, l_outPutStkoshikikanYmd, 
			       l_outPutEdkoshikikanYmd, l_outKkStat, extra_param
			INTO gPutShokanKjt, gPutShokanPremium, gPutStkoshikikanYmd, 
			     gPutEdkoshikikanYmd, gPutKkStat, gRtnCd
			FROM sfIpGetPutOption(l_inItakuKaishaCd, l_inMgrCd);
			-- プットオプション行使条件が取得できた場合
			IF (trim(both gPutShokanKjt) IS NOT NULL AND (trim(both gPutShokanKjt))::text <> '') THEN
				wkPutShokanKagaku := gPutShokanPremium + recWkMeisai.KAKUSHASAI_KNGK;
			ELSE
				gPutShokanKjt := NULL;
				wkPutShokanKagaku := NULL;
				gPutStkoshikikanYmd := NULL;
				gPutEdkoshikikanYmd := NULL;
			END IF;
		END IF;
	    -- 帳票ワークへデータを追加
	    v_item := ROW();
	    v_item.l_inItem001 := l_inUserId::varchar;                    -- ユーザＩＤ
	    v_item.l_inItem002 := recWkMeisai.KIHON_TEISEI_YMD::varchar;  -- 基本訂正日
	    v_item.l_inItem003 := recWkMeisai.KIHON_TEISEI_USER_ID::varchar;   -- 基本訂正ユーザ
	    v_item.l_inItem004 := gLastShoninYmd::varchar;                -- 最終承認日
	    v_item.l_inItem005 := gLastShoninId::varchar;                 -- 最終承認ユーザ
	    v_item.l_inItem006 := recWkMeisai.SHONIN_STAT::varchar;       -- 承認状態
	    v_item.l_inItem007 := recWkMeisai.MGR_CD::varchar;            -- 銘柄コード
	    v_item.l_inItem008 := recWkMeisai.ISIN_CD::varchar;           -- ＩＳＩＮコード
	    v_item.l_inItem009 := recWkMeisai.MGR_RNM::varchar;           -- 銘柄略称
	    v_item.l_inItem010 := gWkTeikyoStYmd::varchar;                --適用開始日
	    v_item.l_inItem011 := recWkMeisai.KK_MGR_CD::varchar;         --機構銘柄コード
	    v_item.l_inItem012 := recWkMeisai.JTK_KBN_NM::varchar;        -- 受託区分名称
	    v_item.l_inItem013 := recWkMeisai.HKT_CD::varchar;            -- 発行体コード
	    v_item.l_inItem014 := recWkMeisai.HKT_RNM::varchar;           -- 発行体略称
	    v_item.l_inItem015 := recWkMeisai.EIGYOTEN_CD::varchar;       -- 営業店店番
	    v_item.l_inItem016 := recWkMeisai.EIGYOTEN_NM::varchar;       -- 営業店名称
	    v_item.l_inItem017 := recWkMeisai.HAKKODAIRI_CD::varchar;     -- 発行代理人コード
	    v_item.l_inItem018 := recWkMeisai.HAKKODAIRI_RNM::varchar;    -- 発行代理人略称
	    v_item.l_inItem019 := recWkMeisai.KOZA_TEN_CD::varchar;       -- 口座店コード
	    v_item.l_inItem020 := recWkMeisai.KOZA_TEN_CIFCD::varchar;    -- 口座店ＣＩＦコード
	    v_item.l_inItem021 := recWkMeisai.SHRDAIRI_CD::varchar;       -- 支払代理人コード
	    v_item.l_inItem022 := recWkMeisai.SHRDAIRI_RNM::varchar;      -- 支払代理人略称
	    v_item.l_inItem023 := recWkMeisai.SKN_KESSAI_CD::varchar;     -- 資金決済会社コード
	    v_item.l_inItem024 := recWkMeisai.SKN_KESSAI_RNM::varchar;    -- 資金決済会社略称
	    v_item.l_inItem025 := recWkMeisai.MGR_NM::varchar;            -- 銘柄の正式名称
	    v_item.l_inItem026 := recWkMeisai.KK_HAKKO_CD::varchar;       -- 機構発行体コード
	    v_item.l_inItem027 := recWkMeisai.KK_HAKKOSHA_RNM::varchar;   -- 機構発行者略称
	    v_item.l_inItem028 := recWkMeisai.KAIGO_ETC::varchar;         -- 回号等
	    v_item.l_inItem029 := recWkMeisai.BOSHU_KBN::varchar;         -- 募集区分
	    v_item.l_inItem030 := recWkMeisai.BOSHU_KBN_NM::varchar;      -- 募集区分名称
	    v_item.l_inItem031 := recWkMeisai.KOKYAKU_BOSHU_KBN_NM::varchar;   -- 対顧用募集区分名称
	    v_item.l_inItem032 := recWkMeisai.KOKYAKU_MGR_RNM::varchar;   -- 対顧用銘柄略称
	    v_item.l_inItem033 := recWkMeisai.JOJO_KBN_TO::varchar;       -- 上場区分（東証)
	    v_item.l_inItem034 := recWkMeisai.JOJO_KBN_DA::varchar;       -- 上場区分（大証)
	    v_item.l_inItem035 := recWkMeisai.JOJO_KBN_ME::varchar;       -- 上場区分（名証)
	    v_item.l_inItem036 := recWkMeisai.JOJO_KBN_FU::varchar;       -- 上場区分（福証)
	    v_item.l_inItem037 := recWkMeisai.JOJO_KBN_SA::varchar;       -- 上場区分（札証)
	    v_item.l_inItem038 := recWkMeisai.JOJO_KBN_JA::varchar;       -- 上場区分（ジャスダック証)
	    v_item.l_inItem039 := recWkMeisai.SAIKEN_KBN_NM::varchar;     -- 債券種類名称
	    v_item.l_inItem040 := recWkMeisai.HOSHO_KBN_NM::varchar;      -- 保証区分名称
	    v_item.l_inItem041 := recWkMeisai.TANPO_KBN_NM::varchar;      -- 担保区分名称
	    v_item.l_inItem042 := recWkMeisai.GODOHAKKO_FLG_NM::varchar;  -- 合同発行フラグ名称
	    v_item.l_inItem043 := gWkBoshuStYmd::varchar;                 -- 募集開始日
	    v_item.l_inItem044 := gWkHakkoYmd::varchar;                   -- 発行年月日
	    v_item.l_inItem045 := recWkMeisai.SKNNZISNTOKU_UMU_FLG_NM::varchar;  -- 責任財産限定特約有無フラグ名称
	    v_item.l_inItem046 := gWkSknChgYmd::varchar;                  -- 資金付替日
	    v_item.l_inItem047 := gWkSknKofuYmd::varchar;                 -- 資金交付日
	    v_item.l_inItem048 := recWkMeisai.RETSUTOKU_UMU_FLG_NM::varchar;   -- 劣後特約有無フラグ名称
	    v_item.l_inItem049 := recWkMeisai.BNK_GUARANTEE_RATE::varchar;     -- 銀行保証料率
	    v_item.l_inItem050 := recWkMeisai.HOSHO_GUARANTEE_RATE::varchar;   -- 保証協会保証料率
	    v_item.l_inItem051 := recWkMeisai.UCHIKIRI_HAKKO_FLG_NM::varchar;  -- 打切発行フラグ名称
	    v_item.l_inItem052 := recWkMeisai.KAKUSHASAI_KNGK::varchar;  -- 各社債の金額
	    v_item.l_inItem053 := recWkMeisai.HAKKO_KAGAKU::varchar;     -- 発行価額
	    v_item.l_inItem054 := recWkMeisai.SHASAI_TOTAL::varchar;     -- 社債の総額
	    v_item.l_inItem055 := gWkFullshokanKjt::varchar;  -- 満期償還期日
	    v_item.l_inItem056 := recWkMeisai.SHOKAN_PREMIUM::varchar;      -- 償還プレミアム
	    v_item.l_inItem057 := recWkMeisai.CALLALL_UMU_FLG_NM::varchar;  -- コールオプション有無（全額）名称
	    v_item.l_inItem058 := recWkMeisai.PUTUMU_FLG_NM::varchar;       -- プットオプション有無名称
	    v_item.l_inItem059 := gArySknKessaiCd[1]::varchar; -- 社債管理者コード
	    v_item.l_inItem060 := gArySknKessaiNm[1]::varchar; -- 社債管理者名称
	    v_item.l_inItem061 := gArySknKessaiCd[2]::varchar; -- 社債管理者コード２
	    v_item.l_inItem062 := gArySknKessaiNm[2]::varchar; -- 社債管理者名称２
	    v_item.l_inItem063 := gArySknKessaiCd[3]::varchar; -- 社債管理者コード３
	    v_item.l_inItem064 := gArySknKessaiNm[3]::varchar; -- 社債管理者名称３
	    v_item.l_inItem065 := gArySknKessaiCd[4]::varchar; -- 社債管理者コード４
	    v_item.l_inItem066 := gArySknKessaiNm[4]::varchar; -- 社債管理者名称４
	    v_item.l_inItem067 := gArySknKessaiCd[5]::varchar;  -- 社債管理者コード５
	    v_item.l_inItem068 := gArySknKessaiNm[5]::varchar; -- 社債管理者名称５
	    v_item.l_inItem069 := gArySknKessaiCd[6]::varchar;  -- 社債管理者コード６
	    v_item.l_inItem070 := gArySknKessaiNm[6]::varchar; -- 社債管理者名称６
	    v_item.l_inItem071 := gArySknKessaiCd[7]::varchar; -- 社債管理者コード７
	    v_item.l_inItem072 := gArySknKessaiNm[7]::varchar; -- 社債管理者名称７
	    v_item.l_inItem073 := gArySknKessaiCd[8]::varchar; -- 社債管理者コード８
	    v_item.l_inItem074 := gArySknKessaiNm[8]::varchar; -- 社債管理者名称８
	    v_item.l_inItem075 := gArySknKessaiCd[9]::varchar; -- 社債管理者コード９
	    v_item.l_inItem076 := gArySknKessaiNm[9]::varchar; -- 社債管理者名称９
	    v_item.l_inItem077 := gArySknKessaiCd[10]::varchar; -- 社債管理者コード１０
	    v_item.l_inItem078 := gArySknKessaiNm[10]::varchar; -- 社債管理者名称１０
	    v_item.l_inItem079 := gWkTrustShoshoYmd::varchar;    -- 信託証書日付
	    v_item.l_inItem080 := gWkHakkoKykYmd::varchar;       -- 発行契約日
	    v_item.l_inItem081 := recWkMeisai.PARTHAKKO_UMU_FLG_NM::varchar;  -- 分割発行有無フラグ名称
	    v_item.l_inItem082 := recWkMeisai.KYUJITSU_KBN_NM::varchar;       -- 休日処理区分名称
	    v_item.l_inItem083 := gItakuKaishaRnm::varchar;      -- 委託会社略称
	    v_item.l_inItem084 := REPORT_ID1::varchar;          -- 帳票ＩＤ
	    v_item.l_inItem085 := '1'::varchar;                 -- ページNo
	    v_item.l_inItem086 := '3'::varchar;                 -- ページ総数
	    v_item.l_inItem087 := recWkMeisai.MGR_SEND_TAISHO_FLG::varchar;  -- 銘柄送信対象フラグ
	    v_item.l_inItem088 := recWkMeisai.SHOKAN_KAGAKU::varchar;        -- 償還価額
	    v_item.l_inItem092 := gRetenFlg::varchar;            -- レ点フラグ
	    v_item.l_inItem093 := recWkMeisai.KYOTEN_KBN_NM::varchar;        -- 拠点区分名称
	    v_item.l_inItem094 := gBankRnm::varchar;                         -- 銀行略称
	    v_item.l_inItem095 := recWkMeisai.MUTB_FLG_NM::varchar;          -- 信託フラグ名称
	    v_item.l_inItem096 := gPutShokanKjt::varchar;        -- プットオプション繰上償還期日
	    v_item.l_inItem097 := wkPutShokanKagaku::varchar;    -- プットオプション償還価額
	    v_item.l_inItem098 := gPutStkoshikikanYmd::varchar;  -- プットオプション行使期間開始日
	    v_item.l_inItem099 := gPutEdkoshikikanYmd::varchar;  -- プットオプション行使期間終了日
	    v_item.l_inItem250 := 'furikaeSort1'::varchar;      -- 帳票の出力順
	    
	    CALL pkPrint.insertData(
	        l_inKeyCd      => l_inItakuKaishaCd,
	        l_inUserId     => l_inUserId,
	        l_inChohyoKbn  => l_inChohyoKbn,
	        l_inSakuseiYmd => l_inGyomuYmd,
	        l_inChohyoId   => REPORT_ID1,
	        l_inSeqNo      => 1,
	        l_inHeaderFlg  => '1',
	        l_inItem       => v_item,
	        l_inKousinId   => l_inUserId,
	        l_inSakuseiId  => l_inUserId
	    );
	    -- 帳票ワークへデータを追加
	    v_item := ROW();
	    v_item.l_inItem001 := l_inUserId::varchar;  -- ユーザＩＤ
	    v_item.l_inItem002 := recWkMeisai.KIHON_TEISEI_YMD::varchar;  -- 基本訂正日
	    v_item.l_inItem003 := recWkMeisai.KIHON_TEISEI_USER_ID::varchar;  -- 基本訂正ユーザ
	    v_item.l_inItem004 := gLastShoninYmd::varchar;  -- 最終承認日
	    v_item.l_inItem005 := gLastShoninId::varchar;  -- 最終承認ユーザ
	    v_item.l_inItem006 := recWkMeisai.SHONIN_STAT::varchar;  -- 承認状態
	    v_item.l_inItem007 := recWkMeisai.MGR_CD::varchar;  -- 銘柄コード
	    v_item.l_inItem008 := recWkMeisai.ISIN_CD::varchar;  -- ＩＳＩＮコード
	    v_item.l_inItem009 := recWkMeisai.MGR_RNM::varchar;  -- 銘柄略称
	    v_item.l_inItem010 := recWkMeisai.RITSUKE_WARIBIKI_KBN_NM::varchar;  -- 利付割引区分名称
	    v_item.l_inItem011 := recWkMeisai.NENRBR_CNT_NM::varchar;  -- 年利払回数
	    v_item.l_inItem012 := recWkMeisai.TOTAL_RBR_CNT::varchar;  -- 総利払回数
	    v_item.l_inItem013 := recWkMeisai.RBR_DD::varchar;  -- 利払日付
	    v_item.l_inItem014 := gWkStRbrKjt::varchar;  -- 初回利払期日
	    v_item.l_inItem015 := recWkMeisai.LAST_RBR_FLG_NM::varchar;  -- 最終利払有無フラグ名称
	    v_item.l_inItem016 := recWkMeisai.KIJUN_KINRI_NM1::varchar;  -- 基準金利１名称,
	    v_item.l_inItem017 := recWkMeisai.RIRITSU::varchar;  -- 利率
	    v_item.l_inItem018 := recWkMeisai.SPREAD::varchar;  -- スプレッド
	    v_item.l_inItem019 := recWkMeisai.KIJUN_KINRI_NM2::varchar;  -- 基準金利２名称
	    v_item.l_inItem020 := recWkMeisai.KIJUN_KINRI_CMNT::varchar;  -- 基準金利コメント
	    v_item.l_inItem021 := recWkMeisai.RIRITSU_KETTEI_TMG_NM1::varchar;  -- 利率決定タイミング名称１
	    v_item.l_inItem022 := recWkMeisai.RIRITSU_KETTEI_TMG_DD::varchar;  -- 利率決定タイミング日
	    v_item.l_inItem023 := recWkMeisai.RIRITSU_KETTEI_TMG_NM2::varchar;  -- 利率決定タイミング名称２
	    v_item.l_inItem024 := recWkMeisai.RRT_KYUJITSU_KBN_NM::varchar;  -- 利率決定休日処理区分名称
	    v_item.l_inItem025 := recWkMeisai.RBR_KJT_MD1::varchar;  -- 利払期日（MD）（１）
	    v_item.l_inItem026 := recWkMeisai.RBR_KJT_MD2::varchar;  -- 利払期日（MD）（２）
	    v_item.l_inItem027 := recWkMeisai.RBR_KJT_MD3::varchar;  -- 利払期日（MD）（３）
	    v_item.l_inItem028 := recWkMeisai.RBR_KJT_MD4::varchar;  -- 利払期日（MD）（４）
	    v_item.l_inItem029 := recWkMeisai.RBR_KJT_MD5::varchar;  -- 利払期日（MD）（５）
	    v_item.l_inItem030 := recWkMeisai.RBR_KJT_MD6::varchar;  -- 利払期日（MD）（６）
	    v_item.l_inItem031 := recWkMeisai.RBR_KJT_MD7::varchar;  -- 利払期日（MD）（７）
	    v_item.l_inItem032 := recWkMeisai.RBR_KJT_MD8::varchar;  -- 利払期日（MD）（８）
	    v_item.l_inItem033 := recWkMeisai.RBR_KJT_MD9::varchar;  -- 利払期日（MD）（９）
	    v_item.l_inItem034 := recWkMeisai.RBR_KJT_MD10::varchar;  -- 利払期日（MD）（１０）
	    v_item.l_inItem035 := recWkMeisai.RBR_KJT_MD11::varchar;  -- 利払期日（MD）（１１）
	    v_item.l_inItem036 := recWkMeisai.RBR_KJT_MD12::varchar;  -- 利払期日（MD）（１２）
	    v_item.l_inItem037 := recWkMeisai.HANKANEN_KBN_NM::varchar;  -- 半ヶ年区分名称
	    v_item.l_inItem038 := recWkMeisai.RBR_NISSU_SPAN::varchar;  -- 利払日数計算間隔名称
	    v_item.l_inItem039 := recWkMeisai.RBR_KJT_INCLUSION_KBN_NM::varchar;  -- 利払期日算入区分名称
	    v_item.l_inItem040 := recWkMeisai.RKN_ROUND_PROCESS_NM::varchar;  -- 利金計算単位未満端数処理名称
	    v_item.l_inItem041 := recWkMeisai.SHIKIRI_RATE::varchar;  -- 仕切りレート
	    v_item.l_inItem042 := recWkMeisai.FST_NISSUKSN_KBN_NM::varchar;  -- 初期実日数計算区分名称
	    v_item.l_inItem043 := recWkMeisai.TSUKARISHI_KNGK_FAST::varchar;  -- １通貨あたりの利子金額（初期）
	    v_item.l_inItem044 := recWkMeisai.TSUKARISHI_KNGK_FAST_S::varchar;  -- １通貨あたりの利子金額（初期）算出値
	    v_item.l_inItem045 := recWkMeisai.KICHU_NISSUKSN_KBN_NM::varchar;  -- 期中実日数計算区分名称
	    v_item.l_inItem046 := recWkMeisai.TSUKARISHI_KNGK_NORM::varchar;  -- １通貨あたりの利子金額（通常）
	    v_item.l_inItem047 := recWkMeisai.TSUKARISHI_KNGK_NORM_S::varchar;  -- １通貨あたりの利子金額（通常）算出値
	    v_item.l_inItem048 := recWkMeisai.END_NISSUKSN_KBN::varchar;  -- 終期実日数計算区分名称
	    v_item.l_inItem049 := recWkMeisai.TSUKARISHI_KNGK_LAST::varchar;  -- １通貨あたりの利子金額（終期）
	    v_item.l_inItem050 := recWkMeisai.TSUKARISHI_KNGK_LAST_S::varchar;  -- １通貨あたりの利子金額（終期）算出値
	    v_item.l_inItem051 := recWkMeisai.KK_KANYO_FLG_NM::varchar;  -- 機構関与方式採用フラグ名称
	    v_item.l_inItem052 := recWkMeisai.KOBETSU_SHONIN_SAIYO_FLG_NM::varchar;  -- 個別承認採用フラグ名称
	    v_item.l_inItem053 := recWkMeisai.WRNT_TOTAL::varchar;  -- 新株予約権の総数
	    v_item.l_inItem054 := gWkWrntUseKagakuKetteiYmd::varchar;  -- 行使価額決定日
	    v_item.l_inItem055 := gWkWrntUseStYmd::varchar;  -- 行使期間開始日
	    v_item.l_inItem056 := gWkWrntUseEdYmd::varchar;  -- 行使期間終了日
	    v_item.l_inItem057 := recWkMeisai.WRNT_HAKKO_KAGAKU::varchar;  -- 新株予約権の発行価額
	    v_item.l_inItem058 := recWkMeisai.WRNT_USE_KAGAKU::varchar;  -- 新株予約権の行使価額
	    v_item.l_inItem059 := recWkMeisai.useSeikyuUkeBasho::varchar;  -- 行使請求受付場所名称
	    v_item.l_inItem060 := recWkMeisai.WRNT_BIKO::varchar;  -- 新株予約権に係る備考
	    v_item.l_inItem061 := recWkMeisai.SHTK_JK_UMU_FLG::varchar;  -- 取得条項有無フラグ
	    v_item.l_inItem062 := gWkShtkJkYmd::varchar;  -- 取得条項に係る取得日
	    v_item.l_inItem063 := recWkMeisai.SHTK_TAIKA_SHURUI::varchar;  -- 取得対価の種類
	    v_item.l_inItem064 := recWkMeisai.KKN_ZNDK_KAKUTEI_KBN_NM::varchar;  -- 基金残高確定区分名称
	    v_item.l_inItem065 := recWkMeisai.DPT_ASSUMP_FLG_NM::varchar;  -- デットアサンプション契約先フラグ名称
	    v_item.l_inItem066 := recWkMeisai.KOZA_FURI_KBN_NM::varchar;  -- 口座振替区分名称
	    v_item.l_inItem067 := recWkMeisai.KKN_CHOKYU_KYUJITSU_KBN_NM::varchar;  -- 基金徴求休日処理区分名称
	    v_item.l_inItem068 := recWkMeisai.KKN_CHOKYU_TMG1_NM::varchar;  -- 基金徴求タイミング１名称
	    v_item.l_inItem069 := recWkMeisai.KKN_CHOKYU_DD::varchar;  -- 基金徴求タイミング日数
	    v_item.l_inItem070 := recWkMeisai.KKN_CHOKYU_TMG2_NM::varchar;  -- 基金徴求タイミング２名称
	    v_item.l_inItem071 := recWkMeisai.KOBETSUSEIKYUOUT_KBN_NM::varchar;  -- 個別請求書出力区分名称
	    v_item.l_inItem072 := recWkMeisai.KKNBILL_OUT_TMG1_NM::varchar;  -- 基金請求書出力タイミング１名称
	    v_item.l_inItem073 := recWkMeisai.KKNBILL_OUT_DD::varchar;  -- 基金請求書出力タイミング日数
	    v_item.l_inItem074 := recWkMeisai.KKNBILL_OUT_TMG2_NM::varchar;  -- 基金請求書出力タイミング２名称
	    v_item.l_inItem075 := recWkMeisai.SHANAI_KOMOKU1::varchar;  -- 社内処理用項目１
	    v_item.l_inItem076 := recWkMeisai.SHANAI_KOMOKU2::varchar;  -- 社内処理用項目２
	    v_item.l_inItem077 := recWkMeisai.YOBI1::varchar;  -- 予備１
	    v_item.l_inItem078 := recWkMeisai.DKJ_MGR_CD::varchar;  -- 独自銘柄コード
	    v_item.l_inItem079 := recWkMeisai.YOBI2::varchar;  -- 予備２
	    v_item.l_inItem080 := recWkMeisai.SHASAI_GENBO_OUT_KBN_NM::varchar;  -- 社債原簿出力区分名称
	    v_item.l_inItem081 := gYobi3::varchar;  -- 予備３
	    v_item.l_inItem082 := recWkMeisai.TOKUREI_SHASAI_FLG_NM::varchar;  -- 特例社債フラグ名称
	    v_item.l_inItem083 := recWkMeisai.HEIZON_MGR_FLG_NM::varchar;  -- 併存銘柄フラグ名称
	    v_item.l_inItem084 := gWkDefaultYmd::varchar;  -- デフォルト日
	    v_item.l_inItem085 := recWkMeisai.DEFAULT_BIKO::varchar;  -- デフォルト備考
	    v_item.l_inItem086 := recWkMeisai.DEFAULT_RIYU_NM::varchar;  -- デフォルト事由名称
	    v_item.l_inItem087 := gItakuKaishaRnm::varchar;  -- 委託会社略称
	    v_item.l_inItem088 := REPORT_ID1::varchar;  -- 帳票ＩＤ
	    v_item.l_inItem089 := '2'::varchar;  -- ページNo
	    v_item.l_inItem090 := '3'::varchar;  -- ページ総数
	    v_item.l_inItem091 := recWkMeisai.MGR_SEND_TAISHO_FLG::varchar;  -- 銘柄送信対象フラグ
	    v_item.l_inItem092 := recWkMeisai.HASU_SHOKAN_UMU_FLG::varchar;  -- 端数償還金有無フラグ
	    v_item.l_inItem094 := gRetenFlg::varchar;  -- レ点フラグ
	    v_item.l_inItem095 := recWkMeisai.KOZA_FURI_KBN_GANKIN_NM::varchar;  -- 口座振替区分（元金）名称
	    v_item.l_inItem096 := recWkMeisai.KOZA_FURI_KBN_RIKIN_NM::varchar;  -- 口座振替区分（利金）名称
	    v_item.l_inItem097 := recWkMeisai.DISPATCH_FLG_NM::varchar;  -- 請求書発送区分名称
	    v_item.l_inItem098 := recWkMeisai.GNRSHROUT_KBN_NM::varchar;  -- 元利金支払報告書出力区分名称
	    v_item.l_inItem250 := 'furikaeSort1'::varchar;  -- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
	    
	    CALL pkPrint.insertData(
	        l_inKeyCd      => l_inItakuKaishaCd,
	        l_inUserId     => l_inUserId,
	        l_inChohyoKbn  => l_inChohyoKbn,
	        l_inSakuseiYmd => l_inGyomuYmd,
	        l_inChohyoId   => REPORT_ID2,
	        l_inSeqNo      => 1,
	        l_inHeaderFlg  => '1',
	        l_inItem       => v_item,
	        l_inKousinId   => l_inUserId,
	        l_inSakuseiId  => l_inUserId
	    );
	    -- 帳票ワークへデータを追加
	    v_item := ROW();
	    v_item.l_inItem001 := l_inUserId::varchar;  -- ユーザＩＤ
	    v_item.l_inItem002 := recWkMeisai.KIHON_TEISEI_YMD::varchar;  -- 基本訂正日
	    v_item.l_inItem003 := recWkMeisai.KIHON_TEISEI_USER_ID::varchar;  -- 基本訂正ユーザ
	    v_item.l_inItem004 := gLastShoninYmd::varchar;  -- 最終承認日
	    v_item.l_inItem005 := gLastShoninId::varchar;  -- 最終承認ユーザ
	    v_item.l_inItem006 := recWkMeisai.SHONIN_STAT::varchar;  -- 承認状態
	    v_item.l_inItem007 := recWkMeisai.MGR_CD::varchar;  -- 銘柄コード
	    v_item.l_inItem008 := recWkMeisai.ISIN_CD::varchar;  -- ＩＳＩＮコード
	    v_item.l_inItem009 := recWkMeisai.MGR_RNM::varchar;  -- 銘柄略称
	    v_item.l_inItem010 := recWkMeisai.SHIHYOKINRI_NM_ETC::varchar;  -- その他指標金利コード内容
	    v_item.l_inItem011 := recWkMeisai.KINRIMAX_SPREAD::varchar;  -- 基準金利（上限）スプレッド
	    v_item.l_inItem012 := recWkMeisai.KINRIFLOOR_SPREAD::varchar;  -- 基準金利（下限）スプレッド
	    v_item.l_inItem013 := recWkMeisai.KINRIMAX_NM::varchar;  -- 基準金利（上限）名称
	    v_item.l_inItem014 := recWkMeisai.KINRIFLOOR_NM::varchar;  -- 基準金利（下限）名称
	    v_item.l_inItem015 := recWkMeisai.MAX_KINRI::varchar;  -- 上限金利
	    v_item.l_inItem016 := recWkMeisai.FLOOR_KINRI::varchar;  -- 下限金利
	    v_item.l_inItem017 := gItakuKaishaRnm::varchar;  -- 委託会社略称
	    v_item.l_inItem018 := REPORT_ID1::varchar;  -- 帳票ＩＤ
	    v_item.l_inItem019 := '3'::varchar;  -- ページNo
	    v_item.l_inItem020 := '3'::varchar;  -- ページ総数
	    v_item.l_inItem021 := recWkMeisai.MGR_SEND_TAISHO_FLG::varchar;  -- 銘柄送信対象フラグ
	    v_item.l_inItem023 := gRetenFlg::varchar;  -- レ点フラグ
	    v_item.l_inItem250 := 'furikaeSort1'::varchar;  -- 帳票の出力順が、既存では帳票ＩＤの順になってしまい、振替ＣＢの場合は銘柄情報のように、
	    
	    CALL pkPrint.insertData(
	        l_inKeyCd      => l_inItakuKaishaCd,
	        l_inUserId     => l_inUserId,
	        l_inChohyoKbn  => l_inChohyoKbn,
	        l_inSakuseiYmd => l_inGyomuYmd,
	        l_inChohyoId   => REPORT_ID3,
	        l_inSeqNo      => 1,
	        l_inHeaderFlg  => '1',
	        l_inItem       => v_item,
	        l_inKousinId   => l_inUserId,
	        l_inSakuseiId  => l_inUserId
	    );
	ELSE
	-- 対象データなし
	   v_item := ROW();
	   v_item.l_inItem088 := REPORT_ID1::varchar;
	   v_item.l_inItem089 := '対象データなし'::varchar;
	   v_item.l_inItem250 := 'furikaeSort1'::varchar;
	   
	   CALL pkPrint.insertData(
	       l_inKeyCd      => l_inItakuKaishaCd,
	       l_inUserId     => l_inUserId,
	       l_inChohyoKbn  => l_inChohyoKbn,
	       l_inSakuseiYmd => l_inGyomuYmd,
	       l_inChohyoId   => REPORT_ID1,
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
	-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
	   RAISE NOTICE 'DEBUG EXCEPTION: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
	   CALL pkLog.fatal('ECM701', REPORT_ID1, 'SQLCODE:' || SQLSTATE);
	   CALL pkLog.fatal('ECM701', REPORT_ID1, 'SQLERRM:' || SQLERRM);
	   l_outSqlCode := RTN_FATAL;
	   l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipw001k00r01 ( l_inMgrCd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;