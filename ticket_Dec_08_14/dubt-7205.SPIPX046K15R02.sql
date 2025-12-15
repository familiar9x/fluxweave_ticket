


DROP TYPE IF EXISTS spipx046k15r02_type_record;
CREATE TYPE spipx046k15r02_type_record AS (
  HKT_CD   char(6),     -- 発行体コード
  KOZA_TEN_CD  char(4),    -- 口座店コード
  KOZA_TEN_CIFCD  char(11),    -- 口座店CIFコード
  SFSK_POST_NO  char(7),    -- 送付先郵便番号
  ADD1   varchar(50),       -- 送付先住所１
  ADD2   varchar(50),       -- 送付先住所２
  ADD3   varchar(50),       -- 送付先住所３
  HKT_NM   varchar(100),     -- 発行体名称
  SFSK_BUSHO_NM  varchar(50),    -- 送付先部署名
  BANK_NM   varchar(50),    -- 委託会社名称
  BUSHO_NM1  varchar(50),    -- 担当部署名称１
  MGR_NM   varchar(400),     -- 銘柄名称
  ISIN_CD   char(12),     -- ISINコード
  RBR_YMD   char(8),     -- 利払日
  RIWATARIBI  char(8),     -- 利渡日
  KIJUN_ZNDK  numeric(14),    -- 基準残高
  TSUKARISHI_KNGK  decimal(14,13),   -- １通貨あたりの利子金額
  RIRITSU   decimal(9,7),      -- 利率
  SPANANBUN_BUNBO  numeric(3),   -- 期間按分分母
  SPANANBUN_BUNSHI numeric(3),  -- 期間按分分子
  KAKUSHASAI_KNGK  numeric(14),    -- 各社債の金額
  RKN_CALC_F_YMD  char(8),    -- 利金計算期間（FROM）
  RKN_CALC_T_YMD  char(8),    -- 利金計算期間（TO）
  IDO_YMD   char(8),        -- 異動年月日
  KOZA_FURI_KBN  varchar(2),            -- 口座振替区分
  KOZA_TEN_CD2  varchar(4),      -- 口座店コード２
  BUTEN_NM  varchar(50),        -- 部店名称
  KAMOKU_NM  varchar(40),        -- 科目名称
  KOZA_NO   varchar(7),      -- 口座番号
  TSUKA_CD  char(3),    -- 通貨コード
  TSUKA_NM  char(3),     -- 通貨名称
  HAKKO_TSUKA_CD  char(3),    -- 発行通貨
  RBR_TSUKA_CD  char(3),    -- 利払通貨
  SHOKAN_TSUKA_CD  char(3),    -- 償還通貨
  KKN_IDO_KBN  char(2),    -- 基金異動区分
  FUNIT_GENSAI_KNGK numeric(14), -- 振替単位元本減債金額
  FUNIT_SKN_PREMIUM numeric(14), -- 振替単位償還プレミアム
  KKN_NYUKIN_KNGK  decimal(16,2),    -- 基金入金額
  CHOOSE_FLG  char(1),   -- 選択フラグ
  CHOOSE_FLG_GN  char(1),   -- 選択フラグ（元金支払手数料）
  GNKN_SHR_TESU_BUNBO numeric(5),    -- 元金支払手数料率（分母）
  GNKN_SHR_TESU_BUNSHI decimal(17,14),   -- 元金支払手数料率（分子）
  RKN_SHR_TESU_BUNBO numeric(5),     -- 利金支払手数料率（分母）
  RKN_SHR_TESU_BUNSHI decimal(17,14),    -- 利金支払手数料率（分子）
  TESU_SHURUI_CD  char(2),      -- 手数料種類コード
  RYOSHU_OUT_KBN  char(1),       -- 領収書出力区分
  RKN_ROUND_PROCESS char(1),      -- 利金計算単位未満端数処理
  NENRBR_CNT  char(2),            -- 年利払回数
  RBR_KAWASE_RATE  decimal(7,4),            -- 利払為替レート
  DISPATCH_FLG  char(1),            -- 請求書発送区分
  KYOTEN_KBN  char(1),            -- 拠点区分
  MGR_RNM   varchar(44),                  -- 銘柄略称
  TOKUREI_SHASAI_FLG char(1),      -- 特例社債フラグ
  RITSUKE_WARIBIKI_KBN char(1),      -- 利付割引区分
  HAKKO_YMD  char(8),            -- 発行日
   KAIJI  numeric(3),            -- 回次
   MGR_CD  varchar(13),            -- 銘柄コード
   DPT_ASSUMP_FLG  char(1),            -- デットアサンプション契約先フラグ
   RBR_KJT  char(8),                           -- 利払期日
  TSUKARISHI_KNGK_NORM  decimal(14,13),         -- １通貨あたりの利子額（算出値）
  KK_KANYO_FLG  char(1), -- 機構関与方式採用フラグ
  HANKANEN_KBN  char(1), -- 半ヶ年区分
  SZEI_SEIKYU_KBN  char(1),    -- 消費税請求区分
  gInvoiceSeikyuKngk  decimal(18,2), -- 適格請求書_請求額
  gInvoiceKikinTesuryo decimal(18,2), -- 適格請求書_基金および手数料
  gInvoiceTesuKngk  decimal(16,2) -- 適格請求書_手数料
 );
DROP TYPE IF EXISTS spipx046k15r02_type_record_set;
CREATE TYPE spipx046k15r02_type_record_set AS (
  HKT_CD   char(6),     -- 発行体コード
  KOZA_TEN_CD  char(4),    -- 口座店コード
  KOZA_TEN_CIFCD  char(11),    -- 口座店CIFコード
  SFSK_POST_NO  char(7),    -- 送付先郵便番号
  ADD1   varchar(50),       -- 送付先住所１
  ADD2   varchar(50),       -- 送付先住所２
  ADD3   varchar(50),       -- 送付先住所３
  HKT_NM   varchar(100),     -- 発行体名称
  SFSK_BUSHO_NM  varchar(50),    -- 送付先部署名
  BANK_NM   varchar(50),    -- 銀行名称
  BUSHO_NM1  varchar(50),    -- 担当部署名称１
  MGR_NM   varchar(400),     -- 銘柄名称
  ISIN_CD   char(12),     -- ISINコード
  RBR_YMD   char(8),     -- 利払日
  RIWATARIBI  char(8),     -- 利渡日
  KIJUN_ZNDK  numeric(14),    -- 基準残高
  TSUKARISHI_KNGK  decimal(14,13),   -- １通貨あたりの利子金額
  RIRITSU   decimal(9,7),      -- 利率
  SPANANBUN_BUNBO  numeric(3),   -- 期間按分分母
  SPANANBUN_BUNSHI numeric(3),  -- 期間按分分子
  KAKUSHASAI_KNGK  numeric(14),    -- 各社債の金額
  RKN_CALC_F_YMD  char(8),    -- 利金計算期間（FROM）
  RKN_CALC_T_YMD  char(8),    -- 利金計算期間（TO）
  IDO_YMD   char(8),        -- 異動年月日
  KOZA_FURI_KBN  varchar(2),            -- 口座振替区分
  KOZA_TEN_CD2  varchar(4),      -- 口座店コード２
  BUTEN_NM  varchar(50),        -- 部店名称
  KAMOKU_NM  varchar(40),        -- 科目名称
  KOZA_NO   varchar(7),      -- 口座番号
  TSUKA_CD  char(3),    -- 通貨コード
  TSUKA_NM  char(3),     -- 通貨名称
  HAKKO_TSUKA_CD  char(3),    -- 発行通貨
  RBR_TSUKA_CD  char(3),    -- 利払通貨
  SHOKAN_TSUKA_CD  char(3),    -- 償還通貨
  KKN_IDO_KBN  char(2),    -- 基金異動区分
  FUNIT_GENSAI_KNGK numeric(14), -- 振替単位元本減債金額
  FUNIT_SKN_PREMIUM numeric(14), -- 振替単位償還プレミアム
  KKN_NYUKIN_KNGK  decimal(16,2),    -- 基金入金額
  CHOOSE_FLG  char(1),   -- 選択フラグ
  CHOOSE_FLG_GN  char(1),   -- 選択フラグ（元金支払手数料）
  GNKN_SHR_TESU_BUNBO numeric(5),    -- 元金支払手数料率（分母）
  GNKN_SHR_TESU_BUNSHI decimal(17,14),   -- 元金支払手数料率（分子）
  RKN_SHR_TESU_BUNBO numeric(5),     -- 利金支払手数料率（分母）
  RKN_SHR_TESU_BUNSHI decimal(17,14),    -- 利金支払手数料率（分子）
  TESU_SHURUI_CD  char(2),      -- 手数料種類コード
  RYOSHU_OUT_KBN  char(1),       -- 領収書出力区分
  RKN_ROUND_PROCESS char(1),      -- 利金計算単位未満端数処理
  NENRBR_CNT  char(2),            -- 年利払回数
  RBR_KAWASE_RATE  decimal(7,4),            -- 利払為替レート
  DISPATCH_FLG  varchar(2),                   -- 請求書発送区分
  KYOTEN_KBN  char(1),            -- 拠点区分
  MGR_RNM   varchar(44),                  -- 銘柄略称
  TOKUREI_SHASAI_FLG char(1),      -- 特例社債フラグ
  RITSUKE_WARIBIKI_KBN char(1),      -- 利付割引区分
  SEIKIN   decimal(16,2),                -- 請求金額
  GANKIN   decimal(16,2),                -- 元金
  RIKIN   decimal(16,2),                -- 利金
  GANKIN_TESURYO  decimal(14,2),                -- 元金手数料
  RIKIN_TESURYO  decimal(14,2),                -- 利金手数料
  GANKIN_TESURYO_ZEI  decimal(10,2),                -- 元金手数料（内消費税）
  RIKIN_TESURYO_ZEI decimal(10,2),                -- 利金手数料（内消費税）
  HAKKO_YMD  char(8),            -- 発行日
   KAIJI  numeric(3),            -- 回次
   MGR_CD  varchar(13),           -- 銘柄コード
   RBR_KJT  char(8),                        -- 利払期日
   TSUKARISHI_KNGK_NORM  decimal(14,13),         -- １通貨あたりの利子額（算出値）
   KK_KANYO_FLG char(1),         -- 機構関与方式採用フラグ
  HANKANEN_KBN  char(1),  -- 半ヶ年区分
  SZEI_SEIKYU_KBN  char(1),    -- 消費税請求区分
  gInvoiceSeikyuKngk  decimal(18,2), -- 適格請求書_請求額
  gInvoiceTesuKngk  decimal(16,2), -- 適格請求書_手数料
  gInvoiceKikinTesuryo decimal(18,2) -- 適格請求書_基金および手数料
 );


CREATE OR REPLACE PROCEDURE spipx046k15r02 (l_inUserId text, -- ユーザーID
 l_inGyomuYmd TEXT, -- 業務日付
 l_inKijunYmdFrom TEXT, -- 基準日From
 l_inKijunYmdTo TEXT, -- 基準日To
 l_inItakuKaishaCd TEXT, -- 委託会社コード
 l_inHktCd TEXT, -- 発行体CD
 l_inKozatenCd text, -- 口座店CD
 l_inKozatenCifCd TEXT, -- 口座店CIFCD
 l_inMgrCd text, -- 銘柄CD
 l_inIsinCd TEXT, -- ISINCD
 l_inTsuchiYmd text, -- 通知日
 l_inChohyoId text, -- 請求書ID
 l_inRBKbn TEXT, -- リアルバッチ区分
 l_outSqlCode OUT integer, -- リターン値
 l_outSqlErrM OUT TEXT -- エラーコメント
 ) AS $body$
DECLARE

  --
--   * 著作権:Copyright(c)2016
--   * 会社名:JIP
--   * 概要　:元利払基金・手数料請求書【単票】を作成する。
--   *
--   * @param    l_inUserId              IN  TEXT        ユーザーID
--   * @param    l_inGyomuYmd            IN  TEXT        業務日付
--   * @param    l_inKijunYmdFrom        IN  TEXT        基準日From
--   * @param    l_inKijunYmdTo          IN  TEXT        基準日To
--   * @param    l_inItakuKaishaCd       IN  TEXT        委託会社コード
--   * @param    l_inHktCd            IN  TEXT        発行体CD
--   * @param    l_inKozatenCd        IN VARCHAR     口座店CD
--   * @param    l_inKozatenCifCd        IN VARCHAR     口座店CIFCD
--   * @param    l_inMgrCd         IN TEXT        銘柄CD
--   * @param    l_inIsinCd         IN TEXT        ISINCD
--   * @param    l_inTsuchiYmd         IN TEXT        通知日
--   * @param    l_inChohyoId            IN  TEXT        請求書ID
--   * @param    l_inRBKbn        IN  TEXT        リアルバッチ区分
--   * @param    l_outSqlCode            OUT INTEGER     リターン値
--   * @param    l_outSqlErrM            OUT VARCHAR    エラーコメント
--   *
--   * @return なし
--   *
--   * @author Y.Nagano
--   * @version $Id: SPIPX046K15R02.sql,v 1.00 2016.12.27 14:24:18 Y.Nagano Exp $
--   *
--  
  --==============================================================================
  --                    定数定義                                                  
  --==============================================================================
  C_PROCEDURE_ID  CONSTANT varchar(50) := 'SPIPX046K15R02';     -- プロシージャＩＤ
 C_REPORT_ID_SEIK   CONSTANT varchar(50) := 'IP931504651';     -- レポートＩＤ(請求書)
 C_REPORT_ID_RYO    CONSTANT varchar(50) := 'IP931504661';     -- レポートＩＤ(領収書)
 TSUCHI_YMD_DEF CONSTANT char(16) := '      年  月  日'; -- 平成10年10月10日
  --==============================================================================
  --                    変数定義                                                  
  --==============================================================================
 v_item type_sreport_wk_item;      -- Composite type for pkPrint.insertData
  gSQL   varchar(32000) := NULL;    -- SQL格納用変数
 gSeqNoS   integer;     -- カウンター（請求書）
 gSeqNoR   integer;     -- カウンター（領収書）
 gRecCnt   integer := -1;     -- レコード件数
 gKjtFrom  char(8);    -- 基準日Ｆｒｏｍ
 gKjtTo   char(8);    -- 基準日Ｔｏ
 gWrkTsuchiYmd      varchar(16) := NULL;     -- 通知日(西暦)
 gWrkChokyuYmd      varchar(16) := NULL;     -- 徴求日(西暦)
 gYokuBusinessYmd      varchar(16) := NULL;     -- 翌営業日
 aryBun      pkIpaBun.BUN_ARRAY;      -- 請求文章
 gSeikBun1  varchar(150) := NULL;    -- 請求文章１行目
 gSeikBun2  varchar(7500) := NULL;    -- 請求文章２行目
 gKoFriLabel  varchar(10) := NULL;    -- 口座振替区分ラベル
 gKozaTenTitle  varchar(10) := NULL;    -- 口座店タイトル
 gKozaNoTitle  varchar(10) := NULL;    -- 口座番号タイトル
 gKozaTenNm  varchar(70) := NULL;    -- 口座店名称
 gRisokuKinLabel  varchar(22) := NULL;    -- 利息金額根拠ラベル
 gRisokuKinCalcLabel varchar(12) := NULL;    -- 利息金額計算根拠振替債ラベル
 gRisokuKinTsuka1GAI varchar(4) := NULL;    -- 利息金額（振替債）通貨１（外貨）
 gRisokuKin1  decimal(16,2);     -- 利息金額（振替債）１
 gRisokuKinTsuka1YEN varchar(4) := NULL;    -- 利息金額（振替債）通貨１（円貨）
 gCalcZandakaTsuka1GAI varchar(4)  := NULL;    -- 計算根拠残高（振替債）通貨１（外貨）
 gCalcZandaka1  decimal(16,2);     -- 計算根拠残高（振替債）
 gCalcZandakaTsuka1YEN varchar(4)  := NULL;    -- 計算根拠残高（振替債）通貨１（円貨）
 gMultiSign1  varchar(2) := NULL;    -- 乗算符号１
 gTSUKARISHI_KNGK1 numeric(14,13);   -- １通貨あたりの利子額１
 gRisiGaku  varchar(4) := NULL;    -- 利子額注
 gEqualSign1  varchar(2) := NULL;    -- 等号符号１
 gRisokuKinTsuka2GAI varchar(4)  := NULL;    -- 利息金額（振替債）通貨２（外貨）
 gRisokuKin2  decimal(16,2);     -- 利息金額（振替債）２
 gRisokuKinTsuka2YEN varchar(4)  := NULL;    -- 利息金額（振替債）通貨２（円貨）
 gRisokuKinHasu  varchar(14) := NULL;    -- 利息金額端数
 gRisigakuMongon  varchar(24) := NULL;    -- 注１利子額文言
 gKAKUSHASAI_KNGK1 bigint;    -- 各社債の金額１
 gMultiSign2  varchar(2) := NULL;    -- 乗算符号２
 gRIRITSU  numeric(9,7);         -- 計算根拠利率（振替債）
 gMultiSign3  varchar(2) := NULL;    -- 乗算符号３
 gSPANANBUN_BUNSHI1 smallint;    -- 期間日数（振替債）１
 gCalcDateBunsi  varchar(6) := NULL;    -- 計算根拠日数（分子）（振替債）
 gDivSign1  varchar(2) := NULL;    -- 除算符号１
 gSPANANBUN_BUNBO smallint;      -- 期間日数（分母）（振替債）
 gCalcDateBunbo  varchar(2) := NULL;    -- 計算根拠日数（分母）（振替債）
 gEqualSign2  varchar(2) := NULL;    -- 等号符号２
 gTSUKARISHI_KNGK2 numeric(14,13);   -- １通貨あたりの利子額２
 gEqualSign3  varchar(2) := NULL;    -- 等号符号３
 gRisokuKin3  decimal(16,2);     -- 利息金額（振替債）３
 gCalcHasuProc  varchar(14) := NULL;    -- 計算根拠端数処理（振替債）
 gRisokuKin4  decimal(16,2);     -- 利息金額（振替債）４
 gDivSign2  varchar(2) := NULL;    -- 除算符号２
 gKAKUSHASAI_KNGK2 bigint;    -- 各社債の金額２
 gEqualSign4  varchar(2) := NULL;    -- 等号符号４
 gTSUKARISHI_KNGK3 numeric(14,13);   -- １通貨あたりの利子額３
 gRisokuCalcSpan  varchar(4) := NULL;    -- 利息計算期間注
 gWrkRisokuCalcStart     varchar(16) := NULL;     -- 利息計算開始日（和暦）
 gDate1   varchar(4) := NULL;    -- 日１
 gWrkRisokuCalcEnd     varchar(16) := NULL;     -- 利息計算終了日（和暦）
 gDate2   varchar(4) := NULL;    -- 日２
 gFrontParentheses varchar(2) := NULL;    -- 前括弧１
 gSPANANBUN_BUNSHI2 smallint;   -- 期間日数(振替債)２
 gSpanBackParentheses varchar(6) := NULL;    -- 日間後括弧１
 gTesuryoLabel  varchar(19) := NULL;    -- 手数料ラベル
 gGankinTesuryoLabel varchar(14) := NULL;    -- 元金手数料ラベル
 gGankinTesuryoFuriSai varchar(17) := NULL;    -- 元金支払手数料率振替債分項目
 gGNKN_SHR_TESU_BUNBO integer;      -- 元金支払手数料率（分母）
 gGnkn_Shr_Tesu_Mngn  varchar(4) := NULL;    -- 元金支払手数料率項目文言
 gGNKN_SHR_TESU_BUNSHI numeric(17,14);  -- 元金支払手数料率（分子）
 gGankinBackParentheses varchar(2) := NULL;    -- 元金支払手数料率項目後括弧
 gGNKN_TSUKA_CD_GAI char(3);    -- 元金支払手数料通貨（外貨）
 gGANKIN_TESURYO  decimal(16,2);                   -- 元金支払手数料
 gGNKN_TSUKA_CD_YEN char(3);    -- 元金支払手数料通貨（円貨）
 gGankinShohizeiLabel varchar(18) := NULL;    -- 元金消費税ラベル
 gGNKN_TSUKA_CD_GAI_ZEI char(3);    -- 元金支払手数料内消費税通貨（外貨）
 gGANKIN_TESURYO_ZEI decimal(16,2);                  -- 元金支払手数料消費税等
 gGNKN_TSUKA_CD_YEN_ZEI char(3);    -- 元金支払手数料内消費税通貨（円貨）
 gRikinTesuryoLabel varchar(14) := NULL;    -- 利金手数料ラベル
 gRikinTesuryoLabel2 varchar(28) := NULL;    -- 利金手数料ラベル２
 gRikinTesuryoFuriSai varchar(17) := NULL;    -- 利金支払手数料率振替債分項目
 gRKN_SHR_TESU_BUNBO integer;      -- 利金支払手数料率（分母）
 gRkn_Shr_Tesu_Mngn  varchar(4) := NULL;    -- 利金支払手数料率項目文言
 gRKN_SHR_TESU_BUNSHI numeric(17,14);  -- 利金支払手数料率（分子）
 gRikinBackParentheses varchar(2) := NULL;    -- 利金支払手数料率項目後括弧
 gRKN_TSUKA_CD_GAI char(3);    -- 利金支払手数料通貨（外貨）
 gRIKIN_TESURYO  decimal(16,2);                   -- 利金支払手数料
 gRKN_TSUKA_CD_YEN char(3);    -- 利金支払手数料通貨（円貨）
 gRikinShohizeiLabel varchar(18) := NULL;    -- 利金消費税ラベル
 gRKN_TSUKA_CD_GAI_ZEI char(3);    -- 利金支払手数料内消費税通貨（外貨）
 gRIKIN_TESURYO_ZEI decimal(16,2);                  -- 利金支払手数料消費税等
 gRKN_TSUKA_CD_YEN_ZEI char(3);    -- 利金支払手数料内消費税通貨（円貨）
 gTSUKA_NM_YEN  char(3);        -- 通貨コード（円）
 gTSUKA_NM_GAI  char(3);        -- 通貨コード（外貨）
 gSUCCESS_PROC_FLG integer;      -- 正常処理フラグ
 gAtena              varchar(200) := NULL;     -- 宛名
 gTSUKARISHI_KNGK decimal(16,2);     -- １通貨あたりの利子額（特例債）
 gCalcHasu  varchar(14) := NULL;    -- 計算根拠端数処理
 gInshiZei  varchar(14) := NULL;     -- 印紙税
 gTSUKA_FORMAT  varchar(21) := NULL;    -- 通貨フォーマット
 gRtnCd       integer := pkconstant.success();   -- リターンコード
 gJIKO_DAIKO_KBN     TEXT := NULL;      -- 自行代行区分
 gKEY_IDO_YMD     char(8);           -- 異動年月日（キー）
 gKEY_TSUKA_CD  char(3);      -- 通貨コード（キー）
 gKEY_KOZA_FURI_KBN varchar(2);              -- 口座振替区分（キー）
 gKEY_RBR_YMD  char(8);       -- 利払日（キー）
 gKEY_HKT_CD  char(6);       -- 発行体コード（キー）
 gKEY_ISIN_CD  char(12);       -- ISINコード（キー）
 gKeisansikiFlg  varchar(1) := NULL;    -- 計算式出力フラグ
 gKikanFlg   varchar(1) := NULL;    -- 計算期間出力フラグ
 
 --インボイス制度対応
 gOptionFlg     char(1);   -- インボイスオプションフラグ
 gInvoiceTourokuNo   char(14); -- 適格請求書発行事業者登録番号
 gHikazeiMenzeiFlg   varchar(4);   -- 非課税免税フラグ
 gHikazeiMenzeiNm   varchar(40);      -- 非課税免税名称
 gHikazeiMenzeiRNm   varchar(20);     -- 非課税免税略称
 gSzeiSeikyuKbn    char(1); -- 消費税請求区分
 gShzKijunYmd    varchar(8);       -- 消費税率適用基準日
 gShzKijunProcess   varchar(4);   -- 消費税率適用基準日対応
 gInvoiceKikinTesuryoLabel  varchar(50) := NULL;    -- 適格請求書_基金および手数料ラベル
 gInvoice_Kkn_Tesu   decimal(18,2) := 0;     -- 適格請求書_基金および手数料（非課税）
 gInvoiceTesuRitsuLabel  varchar(50) := NULL;    -- 適格請求書_手数料率ラベル
 gInvoiceTesuRitsu   numeric;      -- 適格請求書_手数料率（Ｚ９％）
    gInvoice_Szei               numeric;      -- 適格請求書_内消費税
 gInvoiceBunSeikyusho   varchar(150);     -- インボイス文章（請求書）
 gInvoiceBunRyoshusho  varchar(150);     -- インボイス文章（領収書）
 gInvoiceAryBun    pkIpaBun.BUN_ARRAY;      -- インボイス文章配列（請求書）
 gInvoiceAryBun2    pkIpaBun.BUN_ARRAY;      -- インボイス文章配列（領収書）
 PF_gTsukaCd     char(3) := ' ';   -- 通貨コード
 PF_gIdoYmd     char(8) := ' ';   -- 異動年月日
 PF_gHktCd     char(6) := ' ';   -- 発行体コード
 PF_gDispatchFlg    char(1) := ' ';       -- 請求書発送区分
 PF_gKozaFuriKbn    char(2) := ' '; -- 口座振替区分
 PF_gHakkoYmd    char(8) := ' ';  -- 発行日
 --CSVジャーナル用
 gjournal_Atena1    varchar(400) := NULL;    -- 発行体名称
 gjournal_Atena2    varchar(400) := NULL;    -- 発行体名称
 gjournal_Atena3    varchar(400) := NULL;    -- 送付先担当部署名称
    gjournal_Atena4    varchar(400) := NULL;    -- 送付先_御中
 gjournal_ZeiKbnNm   varchar(40);      -- 非課税免税名称
    gjournal_Kigocd          varchar(20)  := NULL;    -- 実質記番号タイトル
 -- 特例債計算用
 gNENRBR_CNT   numeric := 1;
 gRBR_KAWASE_RATE  numeric := 1;
 gKAKUSHASAI_KNGK  numeric := 1;
 -- カーソル (PostgreSQL refcursor)
 curMeisai refcursor;
 -- レコードタイプ宣言
 -- 元利払請求データSELECT
 -- 値格納用
 -- 配列定義 (PostgreSQL array syntax)
 recMeisai SPIPX046K15R02_TYPE_RECORD;
 rec spipx046k15r02_type_record_set[];
 temp_rec spipx046k15r02_type_record_set;
  --==============================================================================
  --    メイン処理    
  --==============================================================================
BEGIN
 -- 入力パラメータのチェック
 IF coalesce(trim(both l_inChohyoId)::text, '') = '' OR coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' OR coalesce(trim(both l_inKijunYmdTo)::text, '') = '' OR
    coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR coalesce(trim(both l_inUserId)::text, '') = '' OR coalesce(trim(both l_inRBKbn)::text, '') = '' OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
    -- ログ書込み
       CALL pkLog.error('ECM501', C_PROCEDURE_ID, '');
       l_outSqlCode := pkconstant.error();
       l_outSqlErrM := '';
       RETURN;
 END IF;
 -- 自行代行区分の取得
 BEGIN
  SELECT
   JIKO_DAIKO_KBN,INVOICE_TOUROKU_NO
  INTO STRICT
   gJIKO_DAIKO_KBN,gInvoiceTourokuNo
  FROM
   VJIKO_ITAKU
  WHERE
   KAIIN_ID = l_inItakuKaishaCd;
 EXCEPTION
  WHEN no_data_found THEN
   gJIKO_DAIKO_KBN := NULL;
 END;
 --オプションフラグ取得
 gOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_A', '0');
 --ローカル変数．オプションフラグ　＝　'1' （インボイスオプション有り）の場合
 IF gOptionFlg = '1' THEN
  --共通部品にて、インボイスオプション（非課税・免税）を取得し、ローカル変数．非課税免税フラグに設定する
  gHikazeiMenzeiFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'INVOICE_ZeiNm', '0');
  --非課税免税名称の取得
  SELECT CODE_NM, CODE_RNM
    INTO STRICT gHikazeiMenzeiNm, gHikazeiMenzeiRNm
    FROM SCODE
   WHERE CODE_VALUE = gHikazeiMenzeiFlg
   AND CODE_SHUBETSU = '246';
  gInvoiceKikinTesuryoLabel := '基金および手数料（' || trim(both gHikazeiMenzeiNm) || '）';
  --CSVジャーナル対応
  gjournal_ZeiKbnNm := gHikazeiMenzeiNm;
  --共通部品にて、文章情報を取得し、ローカル変数．インボイス文章配列に設定する（請求書）
  gInvoiceAryBun := pkIpaBun.getBun(C_REPORT_ID_SEIK, 'L0');
  FOR i IN 0..coalesce(cardinality(gInvoiceAryBun), 0) - 1 LOOP
      IF i = 0 THEN
    gInvoiceBunSeikyusho := gInvoiceAryBun[i];
    gInvoiceAryBun[i] := NULL;
   ELSE
    gInvoiceAryBun[i] := NULL;
   END IF;
  END LOOP;
  --共通部品にて、文章情報を取得し、ローカル変数．インボイス文章配列に設定する（領収書）
  gInvoiceAryBun2 := pkIpaBun.getBun(C_REPORT_ID_RYO, 'L0');
  FOR i IN 0..coalesce(cardinality(gInvoiceAryBun2), 0) - 1 LOOP
      IF i = 0 THEN
    gInvoiceBunRyoshusho := gInvoiceAryBun2[i];
    gInvoiceAryBun2[i] := NULL;
   ELSE
    gInvoiceAryBun2[i] := NULL;
   END IF;
  END LOOP;
 END IF;
 -- 帳票ワークの削除
 DELETE FROM SREPORT_WK
    WHERE KEY_CD = l_inItakuKaishaCd
      AND USER_ID = l_inUserId
      AND SAKUSEI_YMD = l_inGyomuYmd
      AND CHOHYO_ID IN (C_REPORT_ID_SEIK, C_REPORT_ID_RYO);
 -- ヘッダレコードを追加
 -- 請求書
 CALL pkPrint.insertHeader(l_inItakuKaishaCd,
                      l_inUserId,
                      l_inRBKbn,
                      l_inGyomuYmd,
                      C_REPORT_ID_SEIK);
 -- 領収書
 CALL pkPrint.insertHeader(l_inItakuKaishaCd,
                      l_inUserId,
                      l_inRBKbn,
                      l_inGyomuYmd,
                      C_REPORT_ID_RYO);
 -- 連番取得(請求書)
 gSeqNoS := 1;
 -- 連番取得(領収書)
 gSeqNoR := 1;
 -- SQL編集 (inline from SPIPX046K15R02_createSQL procedure)
 -- Build dynamic SQL query - CONVERTED TO LEFT JOIN SYNTAX  
 gSql := '';
 gSql :='SELECT DISTINCT'
 || '   M01.HKT_CD '
 || ' , M01.KOZA_TEN_CD '
 || ' , M01.KOZA_TEN_CIFCD '
 || ' , M01.SFSK_POST_NO '
 || ' , M01.ADD1 '
 || ' , M01.ADD2 '
 || ' , M01.ADD3 '
 || ' , M01.HKT_NM '
 || ' , M01.SFSK_BUSHO_NM '
 || ' , VJ1.BANK_NM '
 || ' , VJ1.BUSHO_NM1 '
 || ' , MG1.MGR_NM '
 || ' , MG1.ISIN_CD '
 || ' , K022.RBR_YMD '
 || ' , (CASE WHEN MG1.RBR_NISSU_SPAN <> ''1'' ' 
 || '  THEN K022.RBR_YMD '      
 || '  ELSE K022.RBR_KJT '      
 || '  END) AS RIWATARIBI '
 || ' , K022.KIJUN_ZNDK '
 || ' , MG2.TSUKARISHI_KNGK '
 || ' , MG2.RIRITSU '
 || ' , MG2.SPANANBUN_BUNBO '
 || ' , MG2.SPANANBUN_BUNSHI '
 || ' , MG1.KAKUSHASAI_KNGK '
 || ' , MG2.RKN_CALC_F_YMD '
 || ' , MG2.RKN_CALC_T_YMD '
 || ' , K022.IDO_YMD '
 || ' , K022.KOZA_FURI_KBN '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN BT01.HKO_KOZA_TEN_CD1 '
 || '    WHEN K022.KOZA_FURI_KBN = ''11'' THEN BT01.HKO_KOZA_TEN_CD2 '
 || '    WHEN K022.KOZA_FURI_KBN = ''12'' THEN BT01.HKO_KOZA_TEN_CD3 '
 || '    WHEN K022.KOZA_FURI_KBN = ''13'' THEN BT01.HKO_KOZA_TEN_CD4 '
 || '    WHEN K022.KOZA_FURI_KBN = ''14'' THEN BT01.HKO_KOZA_TEN_CD5 '
 || '    ELSE S06.KOZA_TEN_CD '
 || '   END) AS KOZA_TEN_CD2 '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN M041.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''11'' THEN M044.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''12'' THEN M045.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''13'' THEN M046.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''14'' THEN M047.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN >= ''20'' AND K022.KOZA_FURI_KBN < ''29'' THEN M042.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''60'' THEN M043.BUTEN_NM '
 || '   END) AS BUTEN_NM '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN MCD1.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''11'' THEN MCD2.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''12'' THEN MCD3.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''13'' THEN MCD4.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''14'' THEN MCD5.CODE_NM '
 || '    ELSE MCD6.CODE_NM '
 || '   END) AS KAMOKU_NM '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN M01.HKO_KOZA_NO '
 || '    WHEN K022.KOZA_FURI_KBN = ''11'' THEN BT01.HKO_KOZA_NO2 '
 || '    WHEN K022.KOZA_FURI_KBN = ''12'' THEN BT01.HKO_KOZA_NO3 '
 || '    WHEN K022.KOZA_FURI_KBN = ''13'' THEN BT01.HKO_KOZA_NO4 '
 || '    WHEN K022.KOZA_FURI_KBN = ''14'' THEN BT01.HKO_KOZA_NO5 '
 || '    ELSE S06.KOZA_NO '
 || '   END) AS KOZA_NO '
 || ' , K022.TSUKA_CD '
 || ' , M64.TSUKA_NM '
 || ' , MG1.HAKKO_TSUKA_CD '
 || ' , MG1.RBR_TSUKA_CD '
 || ' , MG1.SHOKAN_TSUKA_CD '
 || ' , K022.KKN_IDO_KBN '
 || ' , MG3.FUNIT_GENSAI_KNGK '
 || ' , MG3.FUNIT_SKN_PREMIUM '
 || ' , K022.KKN_NYUKIN_KNGK '
 || ' , MG7.CHOOSE_FLG '
 || ' , MG7GN.CHOOSE_FLG AS CHOOSE_FLG_GN'
 || ' , MG8.GNKN_SHR_TESU_BUNBO  AS GNKN_SHR_TESU_BUNBO '
 || ' , MG8.GNKN_SHR_TESU_BUNSHI AS GNKN_SHR_TESU_BUNSHI '
 || ' , MG8.RKN_SHR_TESU_BUNBO   AS RKN_SHR_TESU_BUNBO '
 || ' , MG8.RKN_SHR_TESU_BUNSHI  AS RKN_SHR_TESU_BUNSHI '
 || ' , MG7.TESU_SHURUI_CD       AS TESU_SHURUI_CD '
 || ' , M01.RYOSHU_OUT_KBN '
 || ' , MG1.RKN_ROUND_PROCESS '
 || ' , MG1.NENRBR_CNT '
 || ' , MG1.RBR_KAWASE_RATE '
 || ' , K022.DISPATCH_FLG '
 || ' , BT01.KYOTEN_KBN '
 || ' , MG1.MGR_RNM '
 || ' , MG1.TOKUREI_SHASAI_FLG '
 || ' , MG1.RITSUKE_WARIBIKI_KBN '
 || ' , MG1.HAKKO_YMD '
 || ' , MG2.KAIJI '
 || ' , MG1.MGR_CD '
 || ' , MG1.DPT_ASSUMP_FLG '
 || ' , MG2.RBR_KJT '
 || ' , MG1.TSUKARISHI_KNGK_NORM '
 || ' , MG1.KK_KANYO_FLG '
 || ' , MG1.HANKANEN_KBN '
 || ' , MG8.SZEI_SEIKYU_KBN '
 || 'FROM ' 
 || '   (SELECT '
 || '        K021.ITAKU_KAISHA_CD '
 || '      , K021.MGR_CD '
 || '      , K021.TSUKA_CD '
 || '      , K021.RBR_YMD '
 || '      , K021.IDO_YMD '
 || '      , K021.KKN_NYUKIN_KNGK '
 || '      , K021.KOZA_FURI_KBN '
 || '      , K021.KKNBILL_SHURUI '
 || '      , K021.KKN_IDO_KBN '
 || '      , K021.RBR_KJT '
 || '      , K021.KIJUN_ZNDK '
 || '      , K021.ZNDK_KIJUN_YMD '
 || '      , K021.KKMEMBER_FS_KBN '
 || '      , K021.TESU_SHURUI_CD '
 || '      , K021.DISPATCH_FLG '
 || '      FROM '
 || '    ( '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , BT03.KOZA_FURI_KBN_GANKIN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , '' ''  AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '         KIKIN_IDO  K02 '
 || '       , MGR_KIHON2 BT03 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN = ''11'' '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 gSql := gSql || '     UNION ALL '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , BT03.KOZA_FURI_KBN_RIKIN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , '' ''  AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '       KIKIN_IDO  K02 '
 || '       , MGR_KIHON2 BT03 '
 || '       , MGR_KIHON MG1 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN = ''21'' '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG1.MGR_CD ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || '     UNION ALL '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , MG7.KOZA_FURI_KBN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , MG7.TESU_SHURUI_CD AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '       KIKIN_IDO  K02 '
 || '       , MGR_TESURYO_CTL MG7 '
 || '       , MGR_KIHON2 BT03 '
 || '       , MGR_KIHON MG1 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN IN (''12'', ''13'') '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG7.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG1.MGR_CD '
 || '     AND  MG7.TESU_SHURUI_CD = ''81'' '
 || '     AND  MG7.HAKKO_KICHU_KBN = ''2'' ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || '     UNION ALL '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , MG7.KOZA_FURI_KBN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , MG7.TESU_SHURUI_CD AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '       KIKIN_IDO  K02 '
 || '       , MGR_TESURYO_CTL MG7 '
 || '       , MGR_KIHON2 BT03 '
 || '       , MGR_KIHON MG1 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN IN (''22'', ''23'') '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG7.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG1.MGR_CD '
 || '     AND  MG7.TESU_SHURUI_CD IN (''61'', ''82'') '
 || '     AND  MG7.CHOOSE_FLG = ''1'' '
 || '     AND  MG7.HAKKO_KICHU_KBN = ''2'' ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || '    ) K021 '
 || '      ORDER BY '
 || '      K021.ITAKU_KAISHA_CD '
 || '    , K021.MGR_CD '
 || '    , K021.TSUKA_CD '
 || '    , K021.RBR_YMD '
 || '    , K021.IDO_YMD '
 || '    , K021.KOZA_FURI_KBN '
 || '    , K021.KKNBILL_SHURUI '
 || '    , K021.KKN_IDO_KBN '
 || '    , K021.RBR_KJT '
 || '   ) K022 '
 || ' CROSS JOIN MGR_KIHON MG1 '
 || ' INNER JOIN MHAKKOTAI M01 ON (MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD) '
 || ' INNER JOIN MHAKKOTAI2 BT01 ON (MG1.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND MG1.HKT_CD = BT01.HKT_CD) '
 || ' CROSS JOIN MGR_STS MG0 '
 || ' CROSS JOIN MGR_TESURYO_PRM MG8 '
 || ' CROSS JOIN KOZA_FRK S06 '
 || ' CROSS JOIN VJIKO_ITAKU VJ1 '
 || ' LEFT JOIN MGR_RBRKIJ MG2 ON (K022.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND K022.MGR_CD = MG2.MGR_CD AND K022.RBR_KJT = MG2.RBR_KJT) '
 || ' LEFT JOIN (SELECT * FROM MGR_TESURYO_CTL WHERE TESU_SHURUI_CD IN (''61'',''82'') AND CHOOSE_FLG = ''1'' AND ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ) MG7 ON (K022.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD AND K022.MGR_CD = MG7.MGR_CD) '
 || ' LEFT JOIN (SELECT * FROM MGR_TESURYO_CTL WHERE TESU_SHURUI_CD = ''81'' AND CHOOSE_FLG = ''1'' AND ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ) MG7GN ON (K022.ITAKU_KAISHA_CD = MG7GN.ITAKU_KAISHA_CD AND K022.MGR_CD = MG7GN.MGR_CD) '
 || ' LEFT JOIN (SELECT ITAKU_KAISHA_CD, MGR_CD, SHOKAN_KJT, SUM(FUNIT_GENSAI_KNGK) AS FUNIT_GENSAI_KNGK, SUM(FUNIT_SKN_PREMIUM) AS FUNIT_SKN_PREMIUM FROM MGR_SHOKIJ WHERE SHOKAN_KBN <> ''30'' GROUP BY ITAKU_KAISHA_CD, MGR_CD, SHOKAN_KJT) MG3 ON (K022.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND K022.MGR_CD = MG3.MGR_CD AND K022.RBR_KJT = MG3.SHOKAN_KJT) '
 || ' LEFT JOIN MBUTEN M041 ON (BT01.ITAKU_KAISHA_CD = M041.ITAKU_KAISHA_CD AND BT01.HKO_KOZA_TEN_CD1 = M041.BUTEN_CD) '
 || ' LEFT JOIN MBUTEN M042 ON (S06.ITAKU_KAISHA_CD = M042.ITAKU_KAISHA_CD AND S06.KOZA_TEN_CD = M042.BUTEN_CD) '
 || ' LEFT JOIN MBUTEN M043 ON (M01.ITAKU_KAISHA_CD = M043.ITAKU_KAISHA_CD AND M01.EIGYOTEN_CD = M043.BUTEN_CD) '
 || ' LEFT JOIN MBUTEN M044 ON (BT01.ITAKU_KAISHA_CD = M044.ITAKU_KAISHA_CD AND BT01.HKO_KOZA_TEN_CD2 = M044.BUTEN_CD) '
 || ' LEFT JOIN MBUTEN M045 ON (BT01.ITAKU_KAISHA_CD = M045.ITAKU_KAISHA_CD AND BT01.HKO_KOZA_TEN_CD3 = M045.BUTEN_CD) '
 || ' LEFT JOIN MBUTEN M046 ON (BT01.ITAKU_KAISHA_CD = M046.ITAKU_KAISHA_CD AND BT01.HKO_KOZA_TEN_CD4 = M046.BUTEN_CD) '
 || ' LEFT JOIN MBUTEN M047 ON (BT01.ITAKU_KAISHA_CD = M047.ITAKU_KAISHA_CD AND BT01.HKO_KOZA_TEN_CD5 = M047.BUTEN_CD) '
 || ' LEFT JOIN SCODE MCD1 ON (MCD1.CODE_SHUBETSU = ''707'' AND M01.HKO_KAMOKU_CD = MCD1.CODE_VALUE) '
 || ' LEFT JOIN SCODE MCD2 ON (MCD2.CODE_SHUBETSU = ''707'' AND BT01.HKO_KAMOKU_CD2 = MCD2.CODE_VALUE) '
 || ' LEFT JOIN SCODE MCD3 ON (MCD3.CODE_SHUBETSU = ''707'' AND BT01.HKO_KAMOKU_CD3 = MCD3.CODE_VALUE) '
 || ' LEFT JOIN SCODE MCD4 ON (MCD4.CODE_SHUBETSU = ''707'' AND BT01.HKO_KAMOKU_CD4 = MCD4.CODE_VALUE) '
 || ' LEFT JOIN SCODE MCD5 ON (MCD5.CODE_SHUBETSU = ''707'' AND BT01.HKO_KAMOKU_CD5 = MCD5.CODE_VALUE) '
 || ' LEFT JOIN SCODE MCD6 ON (MCD6.CODE_SHUBETSU = ''707'' AND S06.KOZA_KAMOKU = MCD6.CODE_VALUE) '
 || ' LEFT JOIN MTSUKA M64 ON (K022.TSUKA_CD = M64.TSUKA_CD) ';
 IF l_inRBKbn = '1' THEN
  gSql := gSql || '  , SREPORT_WK SC16 ';
 END IF;
 gSql := gSql || 'WHERE '
        || ' K022.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG0.MGR_CD '
        || '  AND K022.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG8.MGR_CD '
        || '  AND MG1.JTK_KBN NOT IN (''2'',''5'') '
        || '  AND MG0.MGR_STAT_KBN = ''1'' '
        || '  AND MG0.MASSHO_FLG = ''0'' '
        || '  AND MG1.PARTMGR_KBN IN (''0'',''2'') '
        || '  AND (MG1.PARTMGR_KBN IN (''0'',''1'') OR SUBSTR(MG1.YOBI3,14,1) = ''0'') '
        || '  AND K022.ITAKU_KAISHA_CD = S06.ITAKU_KAISHA_CD '
        || '  AND K022.KOZA_FURI_KBN = S06.KOZA_FURI_KBN '
        || '  AND VJ1.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' ';
 IF l_inRBKbn = '1' THEN
  gSql := gSql || '  AND K022.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
       || '  AND K022.MGR_CD = MG1.MGR_CD '
       || '  AND SC16.USER_ID = ''' || pkconstant.BATCH_USER() || ''' '
       || '  AND SC16.SAKUSEI_YMD = ''' || l_inGyomuYmd || ''' '
       || '  AND SC16.CHOHYO_ID = ''WK931504651'' '
       || '  AND K022.ITAKU_KAISHA_CD = SC16.KEY_CD '
          || '  AND K022.MGR_CD = SC16.ITEM001 '
          || '  AND K022.RBR_KJT = SC16.ITEM002 '
          || '  AND K022.IDO_YMD = SC16.ITEM003 ';
 ELSE
  gSql := gSql || '  AND K022.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
       || '  AND K022.MGR_CD = MG1.MGR_CD ';
 END IF;
 IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
  gSql := gSql || '  AND M01.HKT_CD = ''' || l_inHktCd || ''' ';
 END IF;
 IF (trim(both l_inKozatenCd) IS NOT NULL AND (trim(both l_inKozatenCd))::text <> '') THEN
  gSql := gSql || '  AND M01.KOZA_TEN_CD = ''' || l_inKozatenCd || ''' ';
 END IF;
 IF (trim(both l_inKozatenCifCd) IS NOT NULL AND (trim(both l_inKozatenCifCd))::text <> '') THEN
  gSql := gSql || '  AND M01.KOZA_TEN_CIFCD = ''' || l_inKozatenCifCd || ''' ';
 END IF;
 IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.MGR_CD = ''' || l_inMgrCd || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || 'ORDER BY '
        || ' K022.TSUKA_CD ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || ' , K022.IDO_YMD '
       || ' , M01.KOZA_TEN_CD '
       || ' , M01.KOZA_TEN_CIFCD '
       || ' , BT01.KYOTEN_KBN '
       || ' , K022.DISPATCH_FLG '
       || ' , K022.KOZA_FURI_KBN '
       || ' , MG1.DPT_ASSUMP_FLG '
       || ' , MG1.HAKKO_YMD '
       || ' , MG1.ISIN_CD '
       || ' , K022.RBR_YMD ';
 ELSE
  gSql := gSql || ' , M01.KOZA_TEN_CD '
       || ' , M01.KOZA_TEN_CIFCD '
       || ' , BT01.KYOTEN_KBN '
       || ' , K022.DISPATCH_FLG '
       || ' , K022.IDO_YMD '
       || ' , K022.KOZA_FURI_KBN '
       || ' , MG1.DPT_ASSUMP_FLG '
       || ' , MG1.HAKKO_YMD '
       || ' , MG1.ISIN_CD ';
 END IF;
 
 -- カーソルオープン
 OPEN curMeisai FOR EXECUTE gSQL;
 -- データ取得
 LOOP
  FETCH curMeisai
     INTO recMeisai.HKT_CD,
   recMeisai.KOZA_TEN_CD,
   recMeisai.KOZA_TEN_CIFCD,
   recMeisai.SFSK_POST_NO,
   recMeisai.ADD1,
   recMeisai.ADD2,
   recMeisai.ADD3,
   recMeisai.HKT_NM,
   recMeisai.SFSK_BUSHO_NM,
   recMeisai.BANK_NM,
   recMeisai.BUSHO_NM1,
   recMeisai.MGR_NM,
   recMeisai.ISIN_CD,
   recMeisai.RBR_YMD,
   recMeisai.RIWATARIBI,
   recMeisai.KIJUN_ZNDK,
   recMeisai.TSUKARISHI_KNGK,
   recMeisai.RIRITSU,
   recMeisai.SPANANBUN_BUNBO,
   recMeisai.SPANANBUN_BUNSHI,
   recMeisai.KAKUSHASAI_KNGK,
   recMeisai.RKN_CALC_F_YMD,
   recMeisai.RKN_CALC_T_YMD,
   recMeisai.IDO_YMD,
   recMeisai.KOZA_FURI_KBN,
   recMeisai.KOZA_TEN_CD2,
   recMeisai.BUTEN_NM,
   recMeisai.KAMOKU_NM,
   recMeisai.KOZA_NO,
   recMeisai.TSUKA_CD,
   recMeisai.TSUKA_NM,
   recMeisai.HAKKO_TSUKA_CD,
   recMeisai.RBR_TSUKA_CD,
   recMeisai.SHOKAN_TSUKA_CD,
   recMeisai.KKN_IDO_KBN,
   recMeisai.FUNIT_GENSAI_KNGK,
   recMeisai.FUNIT_SKN_PREMIUM,
   recMeisai.KKN_NYUKIN_KNGK,
   recMeisai.CHOOSE_FLG,
   recMeisai.CHOOSE_FLG_GN,
   recMeisai.GNKN_SHR_TESU_BUNBO,
   recMeisai.GNKN_SHR_TESU_BUNSHI,
   recMeisai.RKN_SHR_TESU_BUNBO,
   recMeisai.RKN_SHR_TESU_BUNSHI,
   recMeisai.TESU_SHURUI_CD,
   recMeisai.RYOSHU_OUT_KBN,
   recMeisai.RKN_ROUND_PROCESS,
   recMeisai.NENRBR_CNT,
   recMeisai.RBR_KAWASE_RATE,
   recMeisai.DISPATCH_FLG,
   recMeisai.KYOTEN_KBN,
   recMeisai.MGR_RNM,
   recMeisai.TOKUREI_SHASAI_FLG,
   recMeisai.RITSUKE_WARIBIKI_KBN,
   recMeisai.HAKKO_YMD,
   recMeisai.KAIJI,
   recMeisai.MGR_CD,
   recMeisai.DPT_ASSUMP_FLG,
   recMeisai.RBR_KJT,
   recMeisai.TSUKARISHI_KNGK_NORM,
   recMeisai.KK_KANYO_FLG,
   recMeisai.HANKANEN_KBN,
   recMeisai.SZEI_SEIKYU_KBN;
  -- データが無くなったらループを抜ける
  EXIT WHEN NOT FOUND;/* apply on curMeisai */
  IF (gKEY_IDO_YMD <> recMeisai.IDO_YMD OR gKEY_TSUKA_CD <> recMeisai.TSUKA_CD OR gKEY_KOZA_FURI_KBN <> recMeisai.KOZA_FURI_KBN OR
      gKEY_RBR_YMD <> recMeisai.RBR_YMD OR gKEY_HKT_CD <> recMeisai.HKT_CD OR gKEY_ISIN_CD <> recMeisai.ISIN_CD) OR gRecCnt = -1 THEN
   -- シーケンスナンバーをカウントアップしておく
   gRecCnt := gRecCnt + 1;
   -- Build temp record and append to array
   temp_rec.HKT_CD := recMeisai.HKT_CD;
   temp_rec.KOZA_TEN_CD := recMeisai.KOZA_TEN_CD;
   temp_rec.KOZA_TEN_CIFCD := recMeisai.KOZA_TEN_CIFCD;
   temp_rec.SFSK_POST_NO := recMeisai.SFSK_POST_NO;
   temp_rec.ADD1 := recMeisai.ADD1;
   temp_rec.ADD2 := recMeisai.ADD2;
    temp_rec.ADD3 := recMeisai.ADD3;
   temp_rec.HKT_NM := recMeisai.HKT_NM;
   temp_rec.SFSK_BUSHO_NM := recMeisai.SFSK_BUSHO_NM;
   temp_rec.BANK_NM := recMeisai.BANK_NM;
   temp_rec.BUSHO_NM1 := recMeisai.BUSHO_NM1;
   temp_rec.MGR_NM := recMeisai.MGR_NM;
   temp_rec.ISIN_CD := recMeisai.ISIN_CD;
   temp_rec.RBR_YMD := recMeisai.RBR_YMD;
   temp_rec.RIWATARIBI := recMeisai.RIWATARIBI;
   temp_rec.KIJUN_ZNDK := recMeisai.KIJUN_ZNDK;
   temp_rec.TSUKARISHI_KNGK := recMeisai.TSUKARISHI_KNGK;
   temp_rec.RIRITSU := recMeisai.RIRITSU;
   temp_rec.SPANANBUN_BUNBO := recMeisai.SPANANBUN_BUNBO;
   temp_rec.SPANANBUN_BUNSHI := recMeisai.SPANANBUN_BUNSHI;
   temp_rec.KAKUSHASAI_KNGK := recMeisai.KAKUSHASAI_KNGK;
   temp_rec.RKN_CALC_F_YMD := recMeisai.RKN_CALC_F_YMD;
   temp_rec.RKN_CALC_T_YMD := recMeisai.RKN_CALC_T_YMD;
   temp_rec.IDO_YMD := recMeisai.IDO_YMD;
   temp_rec.KOZA_FURI_KBN := recMeisai.KOZA_FURI_KBN;
   temp_rec.KOZA_TEN_CD2 := recMeisai.KOZA_TEN_CD2;
   temp_rec.BUTEN_NM := recMeisai.BUTEN_NM;
   temp_rec.KAMOKU_NM := recMeisai.KAMOKU_NM;
   temp_rec.KOZA_NO := recMeisai.KOZA_NO;
   temp_rec.TSUKA_CD := recMeisai.TSUKA_CD;
   temp_rec.TSUKA_NM := recMeisai.TSUKA_NM;
   temp_rec.HAKKO_TSUKA_CD := recMeisai.HAKKO_TSUKA_CD;
   temp_rec.RBR_TSUKA_CD := recMeisai.RBR_TSUKA_CD;
   temp_rec.SHOKAN_TSUKA_CD := recMeisai.SHOKAN_TSUKA_CD;
   temp_rec.KKN_IDO_KBN := recMeisai.KKN_IDO_KBN;
   temp_rec.FUNIT_GENSAI_KNGK := recMeisai.FUNIT_GENSAI_KNGK;
   temp_rec.FUNIT_SKN_PREMIUM := recMeisai.FUNIT_SKN_PREMIUM;
   temp_rec.KKN_NYUKIN_KNGK := recMeisai.KKN_NYUKIN_KNGK;
   temp_rec.CHOOSE_FLG := recMeisai.CHOOSE_FLG;
   temp_rec.CHOOSE_FLG_GN := recMeisai.CHOOSE_FLG_GN;
   temp_rec.GNKN_SHR_TESU_BUNBO := recMeisai.GNKN_SHR_TESU_BUNBO;
   temp_rec.GNKN_SHR_TESU_BUNSHI := recMeisai.GNKN_SHR_TESU_BUNSHI;
   temp_rec.RKN_SHR_TESU_BUNBO := recMeisai.RKN_SHR_TESU_BUNBO;
   temp_rec.RKN_SHR_TESU_BUNSHI := recMeisai.RKN_SHR_TESU_BUNSHI;
   temp_rec.TESU_SHURUI_CD := recMeisai.TESU_SHURUI_CD;
   temp_rec.RYOSHU_OUT_KBN := recMeisai.RYOSHU_OUT_KBN;
    temp_rec.RKN_ROUND_PROCESS := recMeisai.RKN_ROUND_PROCESS;
   temp_rec.NENRBR_CNT := recMeisai.NENRBR_CNT;
   temp_rec.RBR_KAWASE_RATE := recMeisai.RBR_KAWASE_RATE;
   temp_rec.DISPATCH_FLG := recMeisai.DISPATCH_FLG;
   temp_rec.KYOTEN_KBN := recMeisai.KYOTEN_KBN;
   temp_rec.MGR_RNM := recMeisai.MGR_RNM;
   temp_rec.TOKUREI_SHASAI_FLG := recMeisai.TOKUREI_SHASAI_FLG;
   temp_rec.RITSUKE_WARIBIKI_KBN := recMeisai.RITSUKE_WARIBIKI_KBN;
   temp_rec.HAKKO_YMD := recMeisai.HAKKO_YMD;
   temp_rec.SEIKIN := 0;
   temp_rec.GANKIN := 0;
   temp_rec.RIKIN := 0;
   temp_rec.GANKIN_TESURYO := 0;
   temp_rec.RIKIN_TESURYO := 0;
   temp_rec.GANKIN_TESURYO_ZEI := 0;
   temp_rec.RIKIN_TESURYO_ZEI := 0;
   temp_rec.KAIJI := recMeisai.KAIJI;
   temp_rec.MGR_CD := recMeisai.MGR_CD;
   temp_rec.RBR_KJT := recMeisai.RBR_KJT;
   temp_rec.TSUKARISHI_KNGK_NORM := recMeisai.TSUKARISHI_KNGK_NORM;
   temp_rec.KK_KANYO_FLG := recMeisai.KK_KANYO_FLG;
   temp_rec.HANKANEN_KBN := recMeisai.HANKANEN_KBN;
   temp_rec.SZEI_SEIKYU_KBN := recMeisai.SZEI_SEIKYU_KBN;
   temp_rec.gInvoiceSeikyuKngk := 0;
   temp_rec.gInvoiceTesuKngk := 0;
   temp_rec.gInvoiceKikinTesuryo := 0;
   -- Append to array
   rec := array_append(rec, temp_rec);
  END IF;
  -- Update current record (read from array, modify, write back)
  temp_rec := rec[gRecCnt+1];
  -- 請求金額
  IF coalesce(trim(both temp_rec.SEIKIN)::text, '') = '' THEN
   temp_rec.SEIKIN := recMeisai.KKN_NYUKIN_KNGK;
  ELSE
   temp_rec.SEIKIN := temp_rec.SEIKIN  + recMeisai.KKN_NYUKIN_KNGK;
  END IF;
  -- 元金
  IF recMeisai.KKN_IDO_KBN = '11' THEN
   temp_rec.GANKIN := recMeisai.KKN_NYUKIN_KNGK;
  END IF;
  -- 利金
  IF recMeisai.KKN_IDO_KBN = '21' THEN
   temp_rec.RIKIN := recMeisai.KKN_NYUKIN_KNGK;
  END IF;
  -- 元金手数料
  IF recMeisai.KKN_IDO_KBN = '12' THEN
   temp_rec.GANKIN_TESURYO := temp_rec.GANKIN_TESURYO + recMeisai.KKN_NYUKIN_KNGK;
   temp_rec.GNKN_SHR_TESU_BUNBO := recMeisai.GNKN_SHR_TESU_BUNBO;
   temp_rec.GNKN_SHR_TESU_BUNSHI := recMeisai.GNKN_SHR_TESU_BUNSHI;
  END IF;
  -- 利金手数料
  IF recMeisai.KKN_IDO_KBN = '22' THEN
   temp_rec.RIKIN_TESURYO := temp_rec.RIKIN_TESURYO + recMeisai.KKN_NYUKIN_KNGK;
   temp_rec.RKN_SHR_TESU_BUNBO := recMeisai.RKN_SHR_TESU_BUNBO;
   temp_rec.RKN_SHR_TESU_BUNSHI := recMeisai.RKN_SHR_TESU_BUNSHI;
  END IF;
  -- 元金手数料
  IF recMeisai.KKN_IDO_KBN = '13' THEN
   temp_rec.GANKIN_TESURYO_ZEI := recMeisai.KKN_NYUKIN_KNGK;
   temp_rec.GANKIN_TESURYO := temp_rec.GANKIN_TESURYO + recMeisai.KKN_NYUKIN_KNGK;
  END IF;
  -- 利金手数料
  IF recMeisai.KKN_IDO_KBN = '23' THEN
   temp_rec.RIKIN_TESURYO_ZEI := recMeisai.KKN_NYUKIN_KNGK;
   temp_rec.RIKIN_TESURYO := temp_rec.RIKIN_TESURYO + recMeisai.KKN_NYUKIN_KNGK;
  END IF;
  -- キー項目の退避
  gKEY_IDO_YMD := recMeisai.IDO_YMD;
  gKEY_TSUKA_CD := recMeisai.TSUKA_CD;
  gKEY_KOZA_FURI_KBN := recMeisai.KOZA_FURI_KBN;
  gKEY_RBR_YMD := recMeisai.RBR_YMD;
  gKEY_HKT_CD := recMeisai.HKT_CD;
  gKEY_ISIN_CD := recMeisai.ISIN_CD;
  --ローカル変数．オプションフラグ　＝　'1' （インボイスオプション有り）の場合
  IF gOptionFlg = '1' THEN
   --適格請求書_請求額の加算
   temp_rec.gInvoiceSeikyuKngk := coalesce(temp_rec.gInvoiceSeikyuKngk, 0) + recMeisai.KKN_NYUKIN_KNGK;
   IF (recMeisai.KKN_IDO_KBN IN ('11', '21')) OR (recMeisai.KKN_IDO_KBN IN ('12', '22') AND recMeisai.SZEI_SEIKYU_KBN = '0') THEN
    temp_rec.gInvoiceKikinTesuryo := coalesce(temp_rec.gInvoiceKikinTesuryo, 0) + recMeisai.KKN_NYUKIN_KNGK;
   ELSIF (recMeisai.KKN_IDO_KBN IN ('12', '13', '22', '23') AND recMeisai.SZEI_SEIKYU_KBN = '1') THEN
    temp_rec.gInvoiceTesuKngk := coalesce(temp_rec.gInvoiceTesuKngk, 0) + recMeisai.KKN_NYUKIN_KNGK;
   END IF;
  END IF;
  -- Write back updated record to array
  rec[gRecCnt+1] := temp_rec;
 END LOOP;
 CLOSE curMeisai;
 -- 通知日(西暦)の取得
 IF l_inRBKbn = '0' THEN
  -- 通知日(西暦)
  IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
   gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
  ELSE
   gWrkTsuchiYmd := TSUCHI_YMD_DEF;
  END IF;
 ELSE
  -- 翌営業日取得
  gYokuBusinessYmd := pkDate.getYokuBusinessYmd(l_inGyomuYmd);
  -- 通知日(西暦)
  IF (trim(both gYokuBusinessYmd) IS NOT NULL AND (trim(both gYokuBusinessYmd))::text <> '') THEN
   gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(gYokuBusinessYmd);
  ELSE
   gWrkTsuchiYmd := TSUCHI_YMD_DEF;
  END IF;
 END IF;
 -- データの登録 (PostgreSQL arrays are 1-based)
 FOR gInsCnt IN 1..(gRecCnt+1) LOOP
  -- 変数の初期化 (inlined from SPIPX046K15R02_initData)
  gKoFriLabel  := NULL;
  gKozaTenTitle  := NULL;
  gKozaNoTitle  := NULL;
  gKozaTenNm  := NULL;
  gRisokuKinLabel  := NULL;
  gRisokuKinCalcLabel := NULL;
  gRisokuKinTsuka1GAI := NULL;
  gRisokuKin1  := NULL;
  gRisokuKinTsuka1YEN := NULL;
  gCalcZandakaTsuka1GAI := NULL;
  gCalcZandaka1  := NULL;
  gCalcZandakaTsuka1YEN := NULL;
  gMultiSign1  := NULL;
  gTSUKARISHI_KNGK1 := NULL;
  gRisiGaku  := NULL;
  gEqualSign1  := NULL;
  gRisokuKinTsuka2GAI := NULL;
  gRisokuKin2  := NULL;
  gRisokuKinTsuka2YEN := NULL;
  gRisokuKinHasu  := NULL;
  gRisigakuMongon  := NULL;
  gKAKUSHASAI_KNGK1 := NULL;
  gMultiSign2  := NULL;
  gRIRITSU  := NULL;
  gMultiSign3  := NULL;
  gSPANANBUN_BUNSHI1 := NULL;
  gCalcDateBunsi  := NULL;
  gDivSign1  := NULL;
  gSPANANBUN_BUNBO := NULL;
  gCalcDateBunbo  := NULL;
  gEqualSign2  := NULL;
  gTSUKARISHI_KNGK2 := NULL;
  gEqualSign3  := NULL;
  gRisokuKin3  := NULL;
  gCalcHasuProc  := NULL;
  gRisokuKin4  := NULL;
  gDivSign2  := NULL;
  gKAKUSHASAI_KNGK2 := NULL;
  gEqualSign4  := NULL;
  gTSUKARISHI_KNGK3 := NULL;
  gRisokuCalcSpan  := NULL;
  gWrkRisokuCalcStart     := NULL;
  gDate1   := NULL;
  gWrkRisokuCalcEnd     := NULL;
  gDate2   := NULL;
  gFrontParentheses := NULL;
  gSPANANBUN_BUNSHI2 := NULL;
  gSpanBackParentheses := NULL;
  gTesuryoLabel  := NULL;
  gGankinTesuryoLabel := NULL;
  gGankinTesuryoFuriSai := NULL;
  gGNKN_SHR_TESU_BUNBO := NULL;
  gGnkn_Shr_Tesu_Mngn  := NULL;
  gGNKN_SHR_TESU_BUNSHI := NULL;
  gGankinBackParentheses := NULL;
  gGNKN_TSUKA_CD_GAI := NULL;
  gGANKIN_TESURYO  := NULL;
  gGNKN_TSUKA_CD_YEN := NULL;
  gGankinShohizeiLabel := NULL;
  gGNKN_TSUKA_CD_GAI_ZEI := NULL;
  gGANKIN_TESURYO_ZEI := NULL;
  gGNKN_TSUKA_CD_YEN_ZEI := NULL;
  gRikinTesuryoLabel := NULL;
  gRikinTesuryoLabel2 := NULL;
  gRikinTesuryoFuriSai := NULL;
  gRKN_SHR_TESU_BUNBO := NULL;
  gRkn_Shr_Tesu_Mngn  := NULL;
  gRKN_SHR_TESU_BUNSHI := NULL;
  gRikinBackParentheses := NULL;
  gRKN_TSUKA_CD_GAI := NULL;
  gRIKIN_TESURYO  := NULL;
  gRKN_TSUKA_CD_YEN := NULL;
  gRikinShohizeiLabel := NULL;
  gRKN_TSUKA_CD_GAI_ZEI := NULL;
  gRIKIN_TESURYO_ZEI := NULL;
  gRKN_TSUKA_CD_YEN_ZEI := NULL;
  gSzeiSeikyuKbn := NULL;
  -- 改ページ
  IF PF_gTsukaCd <> rec[gRecCnt+1].TSUKA_CD
  OR PF_gIdoYmd <> rec[gRecCnt+1].IDO_YMD
  OR PF_gHktCd <> rec[gRecCnt+1].HKT_CD
  OR PF_gDispatchFlg <> rec[gRecCnt+1].DISPATCH_FLG
  OR PF_gKozaFuriKbn <> rec[gRecCnt+1].KOZA_FURI_KBN
  OR PF_gHakkoYmd <> rec[gInsCnt].HAKKO_YMD THEN
   -- 消費税率適用基準日切り替え
   IF gShzKijunProcess = '1' THEN
    gShzKijunYmd := rec[gRecCnt+1].RBR_YMD;
   ELSE
    gShzKijunYmd := rec[gRecCnt+1].IDO_YMD;
   END IF;
   PF_gTsukaCd := rec[gRecCnt+1].TSUKA_CD;
   PF_gIdoYmd := rec[gRecCnt+1].IDO_YMD;
   PF_gHktCd := rec[gRecCnt+1].HKT_CD;
   PF_gDispatchFlg := rec[gRecCnt+1].DISPATCH_FLG;
   PF_gKozaFuriKbn := rec[gRecCnt+1].KOZA_FURI_KBN;
   PF_gHakkoYmd := rec[gInsCnt].HAKKO_YMD;
  END IF;
  -- 請求文章の取得
  aryBun := SPIPX046K15R02_createBun(C_REPORT_ID_SEIK, rec[gInsCnt].KOZA_FURI_KBN);
  -- 請求文章格納用変数の初期化
  gSeikBun1 := NULL;
  gSeikBun2 := NULL;
  FOR gBunCnt IN 0..coalesce(cardinality(aryBun), 0)-1 LOOP
   IF gBunCnt = 0 THEN
    gSeikBun1 := aryBun[0];
   ELSE
    gSeikBun2 := gSeikBun2 || aryBun[gBunCnt];
   END IF;
   aryBun[gBunCnt] := NULL;
  END LOOP;
  IF rec[gInsCnt].KOZA_FURI_KBN >= '10' AND rec[gInsCnt].KOZA_FURI_KBN <= '19' THEN
   gKoFriLabel := '引落し口座';
   gKozaTenTitle := '取引店名';
   gKozaNoTitle := '口座番号';
   IF l_inRBKbn = '1' THEN
    IF coalesce(trim(both rec[gInsCnt].BUTEN_NM)::text, '') = '' OR coalesce(trim(both rec[gInsCnt].KAMOKU_NM)::text, '') = '' OR coalesce(trim(both rec[gInsCnt].KOZA_NO)::text, '') = '' THEN
     -- 警告ワークに登録
      l_outSqlCode := SFIPKEIKOKUINSERT(l_inItakuKaishaCd
              , '1'
              , 'IPW021'
              , rec[gInsCnt].ISIN_CD
              , rec[gInsCnt].KOZA_TEN_CD
              , rec[gInsCnt].KOZA_TEN_CIFCD
              , NULL
              , rec[gInsCnt].MGR_RNM
              , '徴求日'
              , rec[gInsCnt].IDO_YMD
              , NULL
              , NULL
              , NULL
              , NULL
              , gJIKO_DAIKO_KBN
             );
     NULL;
    END IF;
   END IF;
  END IF;
  IF rec[gInsCnt].KOZA_FURI_KBN >= '20' AND rec[gInsCnt].KOZA_FURI_KBN <= '29' THEN
   gKoFriLabel := 'お振込口座';
   gKozaTenTitle := '振込先店名';
   gKozaNoTitle := '口座番号';
  END IF;
  -- 書式フォーマット、通貨コードの設定
  IF rec[gInsCnt].TSUKA_CD = 'JPY' THEN
   gTSUKA_FORMAT := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';
   gTSUKA_NM_YEN := rec[gInsCnt].TSUKA_NM;
   gTSUKA_NM_GAI := NULL;
  ELSE
   gTSUKA_FORMAT := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';
   gTSUKA_NM_YEN := NULL;
   gTSUKA_NM_GAI := rec[gInsCnt].TSUKA_NM;
  END IF;
  -- 宛名編集
  CALL pkIpaName.getMadoFutoAtena(rec[gInsCnt].HKT_NM, rec[gInsCnt].SFSK_BUSHO_NM, gSUCCESS_PROC_FLG, gAtena);
  -- CSVジャーナル宛名
        gjournal_Atena1 := substr(gAtena, 1, 50);           -- 発行体名称１（御中込）
  gjournal_Atena2 := substr(gAtena, 51, 50);           -- 発行体名称２（御中込）
  gjournal_Atena3 := substr(gAtena, 101, 50);          -- 送付先担当部署名称（御中込）
  gjournal_Atena4 := substr(gAtena, 151, 50);                                        -- 送付先_御中
  --ローカル変数．オプションフラグ　＝　'1' （インボイスオプション有り）の場合
  IF gOptionFlg = '1' THEN
   gInvoiceTesuRitsu := NULL;
               gSzeiSeikyuKbn := rec[gInsCnt].SZEI_SEIKYU_KBN;
   IF gSzeiSeikyuKbn = '1' THEN
    --共通部品にて、基準日の税率の取得を行い、ローカル変数．適格請求書_手数料率（Ｚ９％）に設定する
    gInvoiceTesuRitsu := pkIpaZei.getShohiZeiRate(gShzKijunYmd);
    gInvoiceTesuRitsuLabel := '手数料（' || SUBSTR('　' || oracle.to_multi_byte(gInvoiceTesuRitsu), -2) || '％対象）';
   ELSIF gSzeiSeikyuKbn = '0' THEN
    gInvoiceTesuRitsuLabel := '手数料';
   END IF;
  ELSE
   -- 消費税率適用基準日切り替え
   IF gShzKijunProcess = '1' THEN
    gShzKijunYmd := rec[gRecCnt+1].RBR_YMD;
   ELSE
    gShzKijunYmd := rec[gRecCnt+1].IDO_YMD;
   END IF;
  END IF;
  -- 利息金額計算根拠の編集 （実質記番号銘柄以外）
  IF rec[gInsCnt].RIKIN <> '0' AND rec[gInsCnt].KK_KANYO_FLG <> '2' THEN
   gRisokuKinLabel := '（利息金額の計算根拠）';
   gRisokuKinCalcLabel := '＜振替債分＞';
   gRisokuKinTsuka1GAI := gTSUKA_NM_GAI;
   gRisokuKin1 := rec[gInsCnt].RIKIN;
   gRisokuKinTsuka1YEN := gTSUKA_NM_YEN;
   gCalcZandakaTsuka1GAI := gTSUKA_NM_GAI;
   gCalcZandaka1 := rec[gInsCnt].KIJUN_ZNDK;
   gCalcZandakaTsuka1YEN := gTSUKA_NM_YEN;
   gMultiSign1 := '×';
   gTSUKARISHI_KNGK1 := rec[gInsCnt].TSUKARISHI_KNGK;
   gRisiGaku := '(*1)';
   gEqualSign1 := '＝';
   gRisokuKinTsuka2GAI := gTSUKA_NM_GAI;
   gRisokuKin2 := rec[gInsCnt].RIKIN;
   gRisokuKinTsuka2YEN := gTSUKA_NM_YEN;
   -- 通貨がJPYの場合、（円未満切捨）を表示する
   IF (gTSUKA_NM_YEN IS NOT NULL AND gTSUKA_NM_YEN::text <> '') THEN
    gRisokuKinHasu := '（円未満切捨）';
   END IF;
            -- 銘柄_基本．機構関与方式採用フラグ＝'2'の場合「※実質記番号銘柄」を表示
   IF rec[gInsCnt].KK_KANYO_FLG = '2' THEN
    gjournal_Kigocd := '※実質記番号銘柄';
            ELSE
                gjournal_Kigocd := NULL;
   END IF;
   gRisigakuMongon := '(*1)１通貨あたりの利子額';
   -- 1通貨利子額計算根拠と利息計算期間の出力判定
   gKikanFlg        -- [OUT]利息計算期間の出力判定
        := SPIPX046K15R02_keisansikihantei(
         rec[gInsCnt].MGR_CD     -- 銘柄コード
, rec[gInsCnt].KAIJI      -- （利払）回次
, rec[gInsCnt].HAKKO_TSUKA_CD   -- 発行通貨
, rec[gInsCnt].RBR_TSUKA_CD    -- 利払通貨
, rec[gInsCnt].TSUKARISHI_KNGK   -- 1通貨あたりの利子額
, rec[gInsCnt].RBR_KJT     -- 利払期日
, rec[gInsCnt].RITSUKE_WARIBIKI_KBN  -- 利付割引区分
, rec[gInsCnt].TSUKARISHI_KNGK_NORM  -- 1通貨あたりの利子額（通常）
, rec[gInsCnt].HANKANEN_KBN    -- 半ヶ年区分
, rec[gInsCnt].SPANANBUN_BUNBO   -- 期間按分分母
);
   -- 1通貨利子額計算根拠の編集
   IF gKeisansikiFlg = '0' THEN
    gRIRITSU := rec[gInsCnt].RIRITSU;
    gMultiSign3 := '×';
       IF rec[gInsCnt].RITSUKE_WARIBIKI_KBN = 'V' THEN
          IF rec[gInsCnt].SPANANBUN_BUNBO > 12 THEN
                     gSPANANBUN_BUNSHI1 := rec[gInsCnt].SPANANBUN_BUNSHI;
                   ELSE
                     gCalcDateBunsi:= rec[gInsCnt].SPANANBUN_BUNSHI;
                   END IF;
                ELSIF rec[gInsCnt].RITSUKE_WARIBIKI_KBN = 'F' THEN
                   gCalcDateBunsi:= rec[gInsCnt].SPANANBUN_BUNSHI;
                END IF;
    gDivSign1 := '／';
    gSPANANBUN_BUNBO := rec[gInsCnt].SPANANBUN_BUNBO;
    -- ローカル変数．（ローカル変数．カウンター）．特例社債フラグ　＝　'Y'の場合
    IF rec[gInsCnt].TOKUREI_SHASAI_FLG = 'Y' THEN
     gKAKUSHASAI_KNGK1 := rec[gInsCnt].KAKUSHASAI_KNGK;
     gMultiSign2 := '×';
     gEqualSign3 := '＝';
     -- 1通貨あたりの利子額算出（特例債）（sfOnceTsukarishiKngk）を実行
     CALL SPIPX046K15R02_calcTokureiTukaRishi(rec[gInsCnt].RKN_ROUND_PROCESS,
            rec[gInsCnt].KAKUSHASAI_KNGK,
            rec[gInsCnt].RIRITSU,
            rec[gInsCnt].RBR_KAWASE_RATE,
            rec[gInsCnt].SPANANBUN_BUNBO,
            rec[gInsCnt].SPANANBUN_BUNSHI,
            gTSUKARISHI_KNGK,
            gCalcHasu);
     gRisokuKin3 := gTSUKARISHI_KNGK;
     IF (gTSUKA_NM_YEN IS NOT NULL AND gTSUKA_NM_YEN::text <> '') THEN
      gCalcHasuProc := gCalcHasu;
     ELSE
      gCalcHasuProc := NULL;
     END IF;
     gRisokuKin4 := gTSUKARISHI_KNGK;
     gDivSign2 := '／';
     gKAKUSHASAI_KNGK2 := rec[gInsCnt].KAKUSHASAI_KNGK;
     gEqualSign4 := '＝';
     gTSUKARISHI_KNGK3 := rec[gInsCnt].TSUKARISHI_KNGK;
     gEqualSign2 := NULL;
     gTSUKARISHI_KNGK2 := NULL;
    ELSE
     gEqualSign2 := '＝';
     gTSUKARISHI_KNGK2 := rec[gInsCnt].TSUKARISHI_KNGK;
    END IF;
    -- 利息計算期間の編集
    IF gKikanFlg = '0' THEN
     gCalcDateBunbo := '日';
     gRisokuCalcSpan := '(*2)';
     gWrkRisokuCalcStart := pkDate.seirekiChangeSuppressNenGappi(rec[gInsCnt].RKN_CALC_F_YMD);
     gDate1 := 'から';
     gWrkRisokuCalcEnd := pkDate.seirekiChangeSuppressNenGappi(rec[gInsCnt].RKN_CALC_T_YMD);
     gDate2 := 'まで';
     gFrontParentheses := '（';
     gSPANANBUN_BUNSHI2 := rec[gInsCnt].SPANANBUN_BUNSHI;
     gSpanBackParentheses := '日間）';
     gCalcDateBunsi := '日(*2)';
    END IF;
   END IF;
  END IF;
  -- 手数料の編集（元金支払手数料か利金支払手数料が選択されている銘柄）
  IF coalesce(rec[gInsCnt].CHOOSE_FLG, '0') <> '0' OR coalesce(rec[gInsCnt].CHOOSE_FLG_GN, '0') <> '0' THEN
   -- 元金
   gTesuryoLabel := '(2)元利金支払手数料';
   gGankinTesuryoLabel := '元金支払手数料';
   IF rec[gInsCnt].GNKN_SHR_TESU_BUNBO <> 0 THEN
    gGankinTesuryoFuriSai := '（料率 振替債分：';
    gGNKN_SHR_TESU_BUNBO := rec[gInsCnt].GNKN_SHR_TESU_BUNBO;
    gGnkn_Shr_Tesu_Mngn := '分の';
    gGNKN_SHR_TESU_BUNSHI := rec[gInsCnt].GNKN_SHR_TESU_BUNSHI;
    gGankinBackParentheses := '）';
   END IF;
   gGNKN_TSUKA_CD_GAI := gTSUKA_NM_GAI;
   gGANKIN_TESURYO := rec[gInsCnt].GANKIN_TESURYO;
   gGNKN_TSUKA_CD_YEN := gTSUKA_NM_YEN;
   gGankinShohizeiLabel := '（●　内消費税等）';
   gGNKN_TSUKA_CD_GAI_ZEI := gTSUKA_NM_GAI;
   gGANKIN_TESURYO_ZEI := rec[gInsCnt].GANKIN_TESURYO_ZEI;
   gGNKN_TSUKA_CD_YEN_ZEI := gTSUKA_NM_YEN;
   -- 利金
   gTesuryoLabel := '(2)元利金支払手数料';
   gRikinTesuryoLabel := '利金支払手数料';
   IF rec[gInsCnt].TESU_SHURUI_CD = '61' THEN
    gRikinTesuryoLabel2 := '（＝元金×利金支払手数料率）';
   END IF;
   IF rec[gInsCnt].RKN_SHR_TESU_BUNBO <> 0 THEN
    gRikinTesuryoFuriSai := '（料率 振替債分：';
    gRKN_SHR_TESU_BUNBO := rec[gInsCnt].RKN_SHR_TESU_BUNBO;
    gRkn_Shr_Tesu_Mngn := '分の';
    gRKN_SHR_TESU_BUNSHI := rec[gInsCnt].RKN_SHR_TESU_BUNSHI;
    gRikinBackParentheses := '）';
   END IF;
   gRKN_TSUKA_CD_GAI := gTSUKA_NM_GAI;
   gRIKIN_TESURYO := rec[gInsCnt].RIKIN_TESURYO;
   gRKN_TSUKA_CD_YEN := gTSUKA_NM_YEN;
   gRikinShohizeiLabel := '（●　内消費税等）';
   gRKN_TSUKA_CD_GAI_ZEI := gTSUKA_NM_GAI;
   gRIKIN_TESURYO_ZEI := rec[gInsCnt].RIKIN_TESURYO_ZEI;
   gRKN_TSUKA_CD_YEN_ZEI := gTSUKA_NM_YEN;
  END IF;
            -- 割り戻し
   gInvoice_Szei := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(gShzKijunYmd,
                rec[gInsCnt].gInvoiceTesuKngk,
                rec[gInsCnt].TSUKA_CD
                );
  -- 帳票ワークへデータを追加（請求書）
    -- Clear composite type
  v_item := ROW();
  
  v_item.l_inItem001 := gWrkTsuchiYmd;
  v_item.l_inItem002 := rec[gInsCnt].KOZA_TEN_CD;
  v_item.l_inItem003 := rec[gInsCnt].KOZA_TEN_CIFCD;
  v_item.l_inItem004 := rec[gInsCnt].SFSK_POST_NO;
  v_item.l_inItem005 := rec[gInsCnt].ADD1;
  v_item.l_inItem006 := rec[gInsCnt].ADD2;
  v_item.l_inItem007 := rec[gInsCnt].ADD3;
  v_item.l_inItem008 := gAtena;
  v_item.l_inItem009 := rec[gInsCnt].BANK_NM;
  v_item.l_inItem010 := rec[gInsCnt].BUSHO_NM1;
  v_item.l_inItem011 := gTSUKA_NM_GAI;
  v_item.l_inItem012 := rec[gInsCnt].SEIKIN;
  v_item.l_inItem013 := gTSUKA_NM_YEN;
  v_item.l_inItem014 := rec[gInsCnt].MGR_NM;
  v_item.l_inItem015 := rec[gInsCnt].ISIN_CD;
  v_item.l_inItem016 := SUBSTR(rec[gInsCnt].RIWATARIBI,1,4) || '年' || trim(both TO_CHAR((SUBSTR(rec[gInsCnt].RIWATARIBI,5,2))::numeric , 'FM90')) || '月' || trim(both TO_CHAR((SUBSTR(rec[gInsCnt].RIWATARIBI,7,2))::numeric , 'FM90')) || '日';
  v_item.l_inItem017 := gTSUKA_NM_GAI;
  v_item.l_inItem018 := rec[gInsCnt].GANKIN;
  v_item.l_inItem019 := gTSUKA_NM_YEN;
  v_item.l_inItem020 := gTSUKA_NM_GAI;
  v_item.l_inItem021 := rec[gInsCnt].RIKIN;
  v_item.l_inItem022 := gTSUKA_NM_YEN;
  v_item.l_inItem023 := gRisokuKinLabel;
  v_item.l_inItem024 := gRisokuKinCalcLabel;
  v_item.l_inItem025 := gRisokuKinTsuka1GAI;
  v_item.l_inItem026 := gRisokuKin1;
  v_item.l_inItem027 := gRisokuKinTsuka1YEN;
  v_item.l_inItem028 := gCalcZandakaTsuka1GAI;
  v_item.l_inItem029 := gCalcZandaka1;
  v_item.l_inItem030 := gCalcZandakaTsuka1YEN;
  v_item.l_inItem031 := gMultiSign1;
  v_item.l_inItem032 := gTSUKARISHI_KNGK1;
  v_item.l_inItem033 := gRisiGaku;
  v_item.l_inItem034 := gEqualSign1;
  v_item.l_inItem035 := gRisokuKinTsuka2GAI;
  v_item.l_inItem036 := gRisokuKin2;
  v_item.l_inItem037 := gRisokuKinTsuka2YEN;
  v_item.l_inItem038 := gRisokuKinHasu;
  v_item.l_inItem039 := gRisigakuMongon;
  v_item.l_inItem040 := gKAKUSHASAI_KNGK1;
  v_item.l_inItem041 := gMultiSign2;
  v_item.l_inItem042 := gRIRITSU;
  v_item.l_inItem043 := gMultiSign3;
  v_item.l_inItem044 := gSPANANBUN_BUNSHI1;
  v_item.l_inItem045 := gCalcDateBunsi;
  v_item.l_inItem046 := gDivSign1;
  v_item.l_inItem047 := gSPANANBUN_BUNBO;
  v_item.l_inItem048 := gCalcDateBunbo;
  v_item.l_inItem049 := gEqualSign2;
  v_item.l_inItem050 := gTSUKARISHI_KNGK2;
  v_item.l_inItem051 := gEqualSign3;
  v_item.l_inItem052 := gRisokuKin3;
  v_item.l_inItem053 := gCalcHasuProc;
  v_item.l_inItem054 := gRisokuKin4;
  v_item.l_inItem055 := gDivSign2;
  v_item.l_inItem056 := gKAKUSHASAI_KNGK2;
  v_item.l_inItem057 := gEqualSign4;
  v_item.l_inItem058 := gTSUKARISHI_KNGK3;
  v_item.l_inItem059 := gRisokuCalcSpan;
  v_item.l_inItem060 := gWrkRisokuCalcStart;
  v_item.l_inItem061 := gDate1;
  v_item.l_inItem062 := gWrkRisokuCalcEnd;
  v_item.l_inItem063 := gDate2;
  v_item.l_inItem064 := gFrontParentheses;
  v_item.l_inItem065 := gSPANANBUN_BUNSHI2;
  v_item.l_inItem066 := gSpanBackParentheses;
  v_item.l_inItem067 := gTesuryoLabel;
  v_item.l_inItem068 := gGankinTesuryoLabel;
  v_item.l_inItem069 := gGankinTesuryoFuriSai;
  v_item.l_inItem070 := gGNKN_SHR_TESU_BUNBO;
  v_item.l_inItem071 := gGnkn_Shr_Tesu_Mngn;
  v_item.l_inItem072 := gGNKN_SHR_TESU_BUNSHI;
  v_item.l_inItem073 := gGankinBackParentheses;
  v_item.l_inItem074 := gGNKN_TSUKA_CD_GAI;
  v_item.l_inItem075 := gGANKIN_TESURYO;
  v_item.l_inItem076 := gGNKN_TSUKA_CD_YEN;
  v_item.l_inItem077 := gGankinShohizeiLabel;
  v_item.l_inItem078 := gGNKN_TSUKA_CD_GAI_ZEI;
  v_item.l_inItem079 := gGANKIN_TESURYO_ZEI;
  v_item.l_inItem080 := gGNKN_TSUKA_CD_YEN_ZEI;
  v_item.l_inItem081 := gRikinTesuryoLabel;
  v_item.l_inItem082 := gRikinTesuryoLabel2;
  v_item.l_inItem083 := gRikinTesuryoFuriSai;
  v_item.l_inItem084 := gRKN_SHR_TESU_BUNBO;
  v_item.l_inItem085 := gRkn_Shr_Tesu_Mngn;
  v_item.l_inItem086 := gRKN_SHR_TESU_BUNSHI;
  v_item.l_inItem087 := gRikinBackParentheses;
  v_item.l_inItem088 := gRKN_TSUKA_CD_GAI;
  v_item.l_inItem089 := gRIKIN_TESURYO;
  v_item.l_inItem090 := gRKN_TSUKA_CD_YEN;
  v_item.l_inItem091 := gRikinShohizeiLabel;
  v_item.l_inItem092 := gRKN_TSUKA_CD_GAI_ZEI;
  v_item.l_inItem093 := gRIKIN_TESURYO_ZEI;
  v_item.l_inItem094 := gRKN_TSUKA_CD_YEN_ZEI;
  v_item.l_inItem096 := '尚、' || trim(both TO_CHAR((SUBSTR(rec[gInsCnt].IDO_YMD,5,2))::numeric , 'FM90')) || '月' || trim(both TO_CHAR((SUBSTR(rec[gInsCnt].IDO_YMD,7,2))::numeric , 'FM90')) || '日' || gSeikBun1;
  v_item.l_inItem097 := gSeikBun2;
  v_item.l_inItem098 := gKoFriLabel;
  v_item.l_inItem099 := gKozaTenTitle;
  v_item.l_inItem100 := gKozaNoTitle;
  v_item.l_inItem101 := rec[gInsCnt].BUTEN_NM;
  v_item.l_inItem102 := rec[gInsCnt].KAMOKU_NM;
  v_item.l_inItem103 := rec[gInsCnt].KOZA_NO;
  v_item.l_inItem104 := gTSUKA_FORMAT;
  v_item.l_inItem106 := rec[gInsCnt].KYOTEN_KBN;
  v_item.l_inItem107 := rec[gInsCnt].DISPATCH_FLG;
  v_item.l_inItem108 := rec[gInsCnt].KOZA_FURI_KBN;
  v_item.l_inItem109 := rec[gInsCnt].TSUKA_CD;
  v_item.l_inItem110 := rec[gInsCnt].IDO_YMD;
  v_item.l_inItem111 := rec[gInsCnt].HKT_CD;
  v_item.l_inItem112 := rec[gInsCnt].HAKKO_YMD;
  v_item.l_inItem113 := rec[gInsCnt].KK_KANYO_FLG;
  v_item.l_inItem114 := gInvoiceTourokuNo; -- 適格請求書発行事業者登録番号
  v_item.l_inItem115 := gTSUKA_NM_GAI; -- 適格請求書_請求額合計（外貨）
  v_item.l_inItem116 := rec[gInsCnt].gInvoiceSeikyuKngk; -- 適格請求書_請求額合計
  v_item.l_inItem117 := gTSUKA_NM_YEN; -- 適格請求書_請求額合計（円貨）
  v_item.l_inItem118 := gTSUKA_NM_GAI; -- 適格請求書_基金および手数料（非課税）（外貨）
  v_item.l_inItem119 := gInvoiceKikinTesuryoLabel; -- 適格請求書_基金および手数料ラベル
  v_item.l_inItem120 := rec[gInsCnt].gInvoiceKikinTesuryo; -- 適格請求書_基金および手数料合計
  v_item.l_inItem121 := gTSUKA_NM_YEN; -- 適格請求書_基金および手数料（非課税）（円貨）
  v_item.l_inItem122 := gTSUKA_NM_GAI; -- 適格請求書_手数料（外貨）
  v_item.l_inItem123 := gInvoiceTesuRitsuLabel; -- 適格請求書_手数料率ラベル
  v_item.l_inItem124 := rec[gInsCnt].gInvoiceTesuKngk; -- 適格請求書_手数料合計
  v_item.l_inItem125 := gTSUKA_NM_YEN; -- 適格請求書_手数料（円貨）
  v_item.l_inItem126 := gTSUKA_NM_GAI; -- 内消費税（外貨）
  v_item.l_inItem127 := gInvoice_Szei; -- 適格請求書_内消費税
  v_item.l_inItem128 := gTSUKA_NM_YEN; -- 内消費税（円貨）
  v_item.l_inItem129 := gShzKijunYmd; -- 消費税率適用基準日
  v_item.l_inItem130 := gInvoiceBunSeikyusho; -- インボイス文章(請求書)
  v_item.l_inItem131 := gOptionFlg; -- インボイスオプションフラグ
  v_item.l_inItem132 := gSzeiSeikyuKbn; -- 消費税請求区分
  v_item.l_inItem133 := gjournal_Atena1; -- 発行体名称（ジャーナル）
  v_item.l_inItem134 := gjournal_Atena2; -- 発行体名称（ジャーナル）
  v_item.l_inItem135 := gjournal_Atena3; -- 送付先担当部署名称（ジャーナル）
  v_item.l_inItem136 := gjournal_Atena4; -- 送付先担当部署名称（ジャーナル）
  v_item.l_inItem137 := gjournal_ZeiKbnNm; -- インボイス税区分名称（ジャーナル）
  v_item.l_inItem138 := gInvoiceTesuRitsu; -- 消費税率（ジャーナル）
  v_item.l_inItem139 := PF_gIdoYmd; -- 異動年月日（ジャーナル）
  v_item.l_inItem140 := gjournal_Kigocd; -- 実質記番号タイトル
  v_item.l_inItem141 := CASE WHEN (gSPANANBUN_BUNSHI1 IS NOT NULL AND gSPANANBUN_BUNSHI1::text <> '') THEN gSPANANBUN_BUNSHI1 ELSE gCalcDateBunsi END; -- 1通貨あたりの利子額計算根拠_期間按分分子
  
  -- Call pkPrint.insertData with composite type
  CALL pkPrint.insertData(
   l_inKeyCd  => l_inItakuKaishaCd,
   l_inUserId  => l_inUserId,
   l_inChohyoKbn => l_inRBKbn,
   l_inSakuseiYmd => l_inGyomuYmd,
   l_inChohyoId => C_REPORT_ID_SEIK,
   l_inSeqNo  => gSeqNoS,
   l_inHeaderFlg => '1',
   l_inItem  => v_item,
   l_inKousinId => pkconstant.BATCH_USER(),
   l_inSakuseiId => pkconstant.BATCH_USER()
  );
  -- ローカル変数．連番（請求書）をカウントアップ
  gSeqNoS := gSeqNoS +1;
  -- ローカル変数．（ローカル変数．カウンター）．領収書出力区分　＝　'1'の場合
  IF rec[gInsCnt].RYOSHU_OUT_KBN = '1' THEN
   -- 通知日(西暦)の取得
   IF (trim(both rec[gInsCnt].IDO_YMD) IS NOT NULL AND (trim(both rec[gInsCnt].IDO_YMD))::text <> '') THEN
    gWrkChokyuYmd := pkDate.seirekiChangeSuppressNenGappi(rec[gInsCnt].IDO_YMD);
   ELSE
    gWrkChokyuYmd := TSUCHI_YMD_DEF;
   END IF;
   -- 印紙税の計算
   IF (gTSUKA_NM_YEN IS NOT NULL AND gTSUKA_NM_YEN::text <> '') THEN
    gInshiZei := pkIpaStampTax.getStampTax(rec[gInsCnt].TSUKA_CD     -- 通貨コード
        , rec[gInsCnt].GANKIN + rec[gInsCnt].RIKIN      -- 元利基金
        , rec[gInsCnt].GANKIN_TESURYO + rec[gInsCnt].RIKIN_TESURYO  -- 元利金支払手数料金額（税抜）
         - gInvoice_Szei
       );
   ELSE
    gInshiZei := NULL;
   END IF;
   -- 帳票ワークへデータを追加（領収書）
     -- Clear composite type
  v_item := ROW();
  
  v_item.l_inItem001 := gWrkChokyuYmd;
  v_item.l_inItem002 := rec[gInsCnt].KOZA_TEN_CD;
  v_item.l_inItem003 := rec[gInsCnt].KOZA_TEN_CIFCD;
  v_item.l_inItem004 := rec[gInsCnt].SFSK_POST_NO;
  v_item.l_inItem005 := rec[gInsCnt].ADD1;
  v_item.l_inItem006 := rec[gInsCnt].ADD2;
  v_item.l_inItem007 := rec[gInsCnt].ADD3;
  v_item.l_inItem008 := gAtena;
  v_item.l_inItem009 := rec[gInsCnt].BANK_NM;
  v_item.l_inItem010 := rec[gInsCnt].BUSHO_NM1;
  v_item.l_inItem011 := gTSUKA_NM_GAI;
  v_item.l_inItem012 := rec[gInsCnt].SEIKIN;
  v_item.l_inItem013 := gTSUKA_NM_YEN;
  v_item.l_inItem014 := rec[gInsCnt].MGR_NM;
  v_item.l_inItem015 := rec[gInsCnt].ISIN_CD;
  v_item.l_inItem016 := SUBSTR(rec[gInsCnt].RIWATARIBI,1,4) || '年' || trim(both TO_CHAR((SUBSTR(rec[gInsCnt].RIWATARIBI,5,2))::numeric , 'FM90')) || '月' || trim(both TO_CHAR((SUBSTR(rec[gInsCnt].RIWATARIBI,7,2))::numeric , 'FM90')) || '日';
  v_item.l_inItem017 := gTSUKA_NM_GAI;
  v_item.l_inItem018 := rec[gInsCnt].GANKIN;
  v_item.l_inItem019 := gTSUKA_NM_YEN;
  v_item.l_inItem020 := gTSUKA_NM_GAI;
  v_item.l_inItem021 := rec[gInsCnt].RIKIN;
  v_item.l_inItem022 := gTSUKA_NM_YEN;
  v_item.l_inItem023 := gRisokuKinLabel;
  v_item.l_inItem024 := gRisokuKinCalcLabel;
  v_item.l_inItem025 := gRisokuKinTsuka1GAI;
  v_item.l_inItem026 := gRisokuKin1;
  v_item.l_inItem027 := gRisokuKinTsuka1YEN;
  v_item.l_inItem028 := gCalcZandakaTsuka1GAI;
  v_item.l_inItem029 := gCalcZandaka1;
  v_item.l_inItem030 := gCalcZandakaTsuka1YEN;
  v_item.l_inItem031 := gMultiSign1;
  v_item.l_inItem032 := gTSUKARISHI_KNGK1;
  v_item.l_inItem033 := gRisiGaku;
  v_item.l_inItem034 := gEqualSign1;
  v_item.l_inItem035 := gRisokuKinTsuka2GAI;
  v_item.l_inItem036 := gRisokuKin2;
  v_item.l_inItem037 := gRisokuKinTsuka2YEN;
  v_item.l_inItem038 := gRisokuKinHasu;
  v_item.l_inItem039 := gRisigakuMongon;
  v_item.l_inItem040 := gKAKUSHASAI_KNGK1;
  v_item.l_inItem041 := gMultiSign2;
  v_item.l_inItem042 := gRIRITSU;
  v_item.l_inItem043 := gMultiSign3;
  v_item.l_inItem044 := gSPANANBUN_BUNSHI1;
  v_item.l_inItem045 := gCalcDateBunsi;
  v_item.l_inItem046 := gDivSign1;
  v_item.l_inItem047 := gSPANANBUN_BUNBO;
  v_item.l_inItem048 := gCalcDateBunbo;
  v_item.l_inItem049 := gEqualSign2;
  v_item.l_inItem050 := gTSUKARISHI_KNGK2;
  v_item.l_inItem051 := gEqualSign3;
  v_item.l_inItem052 := gRisokuKin3;
  v_item.l_inItem053 := gCalcHasuProc;
  v_item.l_inItem054 := gRisokuKin4;
  v_item.l_inItem055 := gDivSign2;
  v_item.l_inItem056 := gKAKUSHASAI_KNGK2;
  v_item.l_inItem057 := gEqualSign4;
  v_item.l_inItem058 := gTSUKARISHI_KNGK3;
  v_item.l_inItem059 := gRisokuCalcSpan;
  v_item.l_inItem060 := gWrkRisokuCalcStart;
  v_item.l_inItem061 := gDate1;
  v_item.l_inItem062 := gWrkRisokuCalcEnd;
  v_item.l_inItem063 := gDate2;
  v_item.l_inItem064 := gFrontParentheses;
  v_item.l_inItem065 := gSPANANBUN_BUNSHI2;
  v_item.l_inItem066 := gSpanBackParentheses;
  v_item.l_inItem067 := gTesuryoLabel;
  v_item.l_inItem068 := gGankinTesuryoLabel;
  v_item.l_inItem069 := gGankinTesuryoFuriSai;
  v_item.l_inItem070 := gGNKN_SHR_TESU_BUNBO;
  v_item.l_inItem071 := gGnkn_Shr_Tesu_Mngn;
  v_item.l_inItem072 := gGNKN_SHR_TESU_BUNSHI;
  v_item.l_inItem073 := gGankinBackParentheses;
  v_item.l_inItem074 := gGNKN_TSUKA_CD_GAI;
  v_item.l_inItem075 := gGANKIN_TESURYO;
  v_item.l_inItem076 := gGNKN_TSUKA_CD_YEN;
  v_item.l_inItem077 := gGankinShohizeiLabel;
  v_item.l_inItem078 := gGNKN_TSUKA_CD_GAI_ZEI;
  v_item.l_inItem079 := gGANKIN_TESURYO_ZEI;
  v_item.l_inItem080 := gGNKN_TSUKA_CD_YEN_ZEI;
  v_item.l_inItem081 := gRikinTesuryoLabel;
  v_item.l_inItem082 := gRikinTesuryoLabel2;
  v_item.l_inItem083 := gRikinTesuryoFuriSai;
  v_item.l_inItem084 := gRKN_SHR_TESU_BUNBO;
  v_item.l_inItem085 := gRkn_Shr_Tesu_Mngn;
  v_item.l_inItem086 := gRKN_SHR_TESU_BUNSHI;
  v_item.l_inItem087 := gRikinBackParentheses;
  v_item.l_inItem088 := gRKN_TSUKA_CD_GAI;
  v_item.l_inItem089 := gRIKIN_TESURYO;
  v_item.l_inItem090 := gRKN_TSUKA_CD_YEN;
  v_item.l_inItem091 := gRikinShohizeiLabel;
  v_item.l_inItem092 := gRKN_TSUKA_CD_GAI_ZEI;
  v_item.l_inItem093 := gRIKIN_TESURYO_ZEI;
  v_item.l_inItem094 := gRKN_TSUKA_CD_YEN_ZEI;
  v_item.l_inItem095 := gInshiZei;
  v_item.l_inItem104 := gTSUKA_FORMAT;
  v_item.l_inItem105 := '印紙';
  v_item.l_inItem106 := rec[gInsCnt].KYOTEN_KBN;
  v_item.l_inItem107 := rec[gInsCnt].DISPATCH_FLG;
  v_item.l_inItem108 := rec[gInsCnt].KOZA_FURI_KBN;
  v_item.l_inItem109 := rec[gInsCnt].TSUKA_CD;
  v_item.l_inItem110 := rec[gInsCnt].IDO_YMD;
  v_item.l_inItem111 := rec[gInsCnt].HKT_CD;
  v_item.l_inItem112 := rec[gInsCnt].HAKKO_YMD;
  v_item.l_inItem113 := rec[gInsCnt].KK_KANYO_FLG;
  v_item.l_inItem114 := gInvoiceTourokuNo; -- 適格請求書発行事業者登録番号
  v_item.l_inItem115 := gTSUKA_NM_GAI; -- 適格請求書_請求額合計（外貨）
  v_item.l_inItem116 := rec[gInsCnt].gInvoiceSeikyuKngk; -- 適格請求書_請求額合計
  v_item.l_inItem117 := gTSUKA_NM_YEN; -- 適格請求書_請求額合計（円貨）
  v_item.l_inItem118 := gTSUKA_NM_GAI; -- 適格請求書_基金および手数料（非課税）（外貨）
  v_item.l_inItem119 := gInvoiceKikinTesuryoLabel; -- 適格請求書_基金および手数料ラベル
  v_item.l_inItem120 := rec[gInsCnt].gInvoiceKikinTesuryo; -- 適格請求書_基金および手数料合計
  v_item.l_inItem121 := gTSUKA_NM_YEN; -- 適格請求書_基金および手数料（非課税）（円貨）
  v_item.l_inItem122 := gTSUKA_NM_GAI; -- 適格請求書_手数料（外貨）
  v_item.l_inItem123 := gInvoiceTesuRitsuLabel; -- 適格請求書_手数料率ラベル
  v_item.l_inItem124 := rec[gInsCnt].gInvoiceTesuKngk; -- 適格請求書_手数料合計
  v_item.l_inItem125 := gTSUKA_NM_YEN; -- 適格請求書_手数料（円貨）
  v_item.l_inItem126 := gTSUKA_NM_GAI; -- 内消費税（外貨）
  v_item.l_inItem127 := gInvoice_Szei; -- 適格請求書_内消費税
  v_item.l_inItem128 := gTSUKA_NM_YEN; -- 内消費税（円貨）
  v_item.l_inItem129 := gShzKijunYmd; -- 消費税率適用基準日
  v_item.l_inItem130 := gInvoiceBunRyoshusho; -- インボイス文章(領収書)
  v_item.l_inItem131 := gOptionFlg; -- インボイスオプションフラグ
  v_item.l_inItem132 := gSzeiSeikyuKbn; -- 消費税請求区分
  
  -- Call pkPrint.insertData with composite type
  CALL pkPrint.insertData(
   l_inKeyCd  => l_inItakuKaishaCd,
   l_inUserId  => l_inUserId,
   l_inChohyoKbn => l_inRBKbn,
   l_inSakuseiYmd => l_inGyomuYmd,
   l_inChohyoId => C_REPORT_ID_RYO,
   l_inSeqNo  => gSeqNoR,
   l_inHeaderFlg => '1',
   l_inItem  => v_item,
   l_inKousinId => pkconstant.BATCH_USER(),
   l_inSakuseiId => pkconstant.BATCH_USER()
  );
   -- ローカル変数．連番（領収書）をカウントアップ
   gSeqNoR := gSeqNoR +1;
  END IF;
 END LOOP;
 -- ローカル変数．連番（請求書）　＝　1　かつ 引数．リアルバッチ区分　＝　0の場合
 IF gSeqNoS = 1 AND l_inRBKbn = '0' THEN
  -- 帳票ワークへデータを追加(請求書)
  gRtnCd := PKIPACALCTESURYO.setNoDataPrint(l_inItakuKaishaCd,
         l_inUserId,
         l_inGyomuYmd,
         C_REPORT_ID_SEIK,
         l_inRBKbn,
         14,
         gWrkTsuchiYmd,
         1,
         NULL,
         2,
         '対象データなし',
         0,
         gInvoiceBunSeikyusho,
         132,
         gOptionFlg,
         133);
 END IF;
 -- ローカル変数．連番（請求書）　≠　1　の場合
 IF gSeqNoS <> 1 THEN
  --ローカル変数．インボイスオプションフラグ　＝　'1' （インボイスオプション有り）の場合
  IF gOptionFlg = '1' THEN
        -- CSVジャーナルの追加
        l_outSqlCode := pkCsvJournal.insertData(l_inItakuKaishaCd,
                                          l_inUserId,
                                       l_inRBKbn,
                                       l_inGyomuYmd,
                                       'IP931504651'
                                      );
     END IF;
  IF l_inRBKbn = '1' THEN
   IF gRtnCd = pkconstant.success() THEN
    -- バッチ帳票印刷管理テーブルにデータを登録する
    CALL PKIPACALCTESURYO.insertDataPrtOk(
          inItakuKaishaCd  => l_inItakuKaishaCd,
          inKijunYmd       => l_inGyomuYmd,
          inListSakuseiKbn => '1',
          inChohyoId       => C_REPORT_ID_SEIK
         );
   END IF;
  END IF;
 END IF;
 -- 終了処理
 l_outSqlCode := gRtnCd;
 l_outSqlErrM := '';
-- エラー処理
EXCEPTION
  WHEN OTHERS THEN
    CALL pkLog.fatal('ECM701', l_inChohyoId, 'SQLCODE:' || SQLSTATE);
    CALL pkLog.fatal('ECM701', l_inChohyoId, 'SQLERRM:' || SQLERRM);
    l_outSqlCode := pkconstant.FATAL();
    l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx046k15r02 (l_inUserId text, l_inGyomuYmd TEXT, l_inKijunYmdFrom TEXT, l_inKijunYmdTo TEXT, l_inItakuKaishaCd TEXT, l_inHktCd TEXT, l_inKozatenCd text, l_inKozatenCifCd TEXT, l_inMgrCd text, l_inIsinCd TEXT, l_inTsuchiYmd text, l_inChohyoId text, l_inRBKbn TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipx046k15r02_calctokureitukarishi (l_in_RKN_ROUND_PROCESS text, l_in_KAKUSHASAI_KNGK numeric, l_in_RIRITSU numeric, l_in_RBR_KAWASE_RATE numeric, l_in_SPANANBUN_BUNBO numeric, l_in_SPANANBUN_BUNSHI numeric, l_in_TSUKARISHI_KNGK OUT numeric, l_in_CalcHasu OUT text) AS $body$
DECLARE
 gRBR_KAWASE_RATE numeric;
 gKAKUSHASAI_KNGK numeric;
BEGIN
 IF l_in_RBR_KAWASE_RATE <> 0 THEN
  gRBR_KAWASE_RATE := l_in_RBR_KAWASE_RATE;
 END IF;
 IF l_in_KAKUSHASAI_KNGK = 0 THEN
  gKAKUSHASAI_KNGK := l_in_KAKUSHASAI_KNGK;
 END IF;
 -- 引数．利金計算単位未満端数処理 ＝ '1'の場合
 IF l_in_RKN_ROUND_PROCESS = '1' THEN
  l_in_TSUKARISHI_KNGK := TRUNC(TRUNC(l_in_KAKUSHASAI_KNGK * l_in_RIRITSU / 100 * l_in_SPANANBUN_BUNSHI / l_in_SPANANBUN_BUNBO / gRBR_KAWASE_RATE) / gKAKUSHASAI_KNGK + 0.00000000000009::numeric, 13);
  l_in_CalcHasu := '（円未満切捨）';
 END IF;
 -- 引数．利金計算単位未満端数処理　＝　'2'の場合
 IF l_in_RKN_ROUND_PROCESS = '2' THEN
  l_in_TSUKARISHI_KNGK := TRUNC(ROUND(l_in_KAKUSHASAI_KNGK * l_in_RIRITSU / 100 * l_in_SPANANBUN_BUNSHI / l_in_SPANANBUN_BUNBO / gRBR_KAWASE_RATE) / gKAKUSHASAI_KNGK + 0.00000000000009::numeric, 13);
  l_in_CalcHasu := '（四捨五入）';
 END IF;
 -- 引数．利金計算単位未満端数処理　＝　'3'の場合
 IF l_in_RKN_ROUND_PROCESS = '3' THEN
  l_in_TSUKARISHI_KNGK := TRUNC(TRUNC((l_in_KAKUSHASAI_KNGK * l_in_RIRITSU / 100 * l_in_SPANANBUN_BUNSHI / l_in_SPANANBUN_BUNBO / gRBR_KAWASE_RATE) + .9)/ gKAKUSHASAI_KNGK + .00000000000009, 13);
  l_in_CalcHasu := '（円未満切上）';
 END IF;
EXCEPTION
WHEN OTHERS THEN
 RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx046k15r02_calctokureitukarishi (l_in_RKN_ROUND_PROCESS text, l_in_KAKUSHASAI_KNGK numeric, l_in_RIRITSU numeric, l_in_RBR_KAWASE_RATE numeric, l_in_SPANANBUN_BUNBO numeric, l_in_SPANANBUN_BUNSHI numeric, l_in_TSUKARISHI_KNGK OUT numeric, l_in_CalcHasu OUT text) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipx046k15r02_createbun ( l_in_ReportID TEXT, l_in_PatternCd char(2)) RETURNS PKIPABUN.BUN_ARRAY AS $body$
DECLARE

 -- 請求文章(ワーク)
 aryBunWk pkIpaBun.BUN_ARRAY;

BEGIN
-- 請求文章の取得
aryBunWk := pkIpaBun.getBun(l_in_ReportID, l_in_PatternCd);
RETURN aryBunWk;
EXCEPTION
WHEN OTHERS THEN
 RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx046k15r02_createbun ( l_in_ReportID TEXT, l_in_PatternCd char(2)) FROM PUBLIC;

-- COMMENTED OUT: spipx046k15r02_createsql - code has been inlined into main procedure
/*



CREATE OR REPLACE PROCEDURE spipx046k15r02_createsql () AS $body$
BEGIN
-- 変数を初期化
gSql := '';
-- 変数にSQLクエリ文を代入
gSql :='SELECT DISTINCT'
 || '   M01.HKT_CD '
 || ' , M01.KOZA_TEN_CD '
 || ' , M01.KOZA_TEN_CIFCD '
 || ' , M01.SFSK_POST_NO '
 || ' , M01.ADD1 '
 || ' , M01.ADD2 '
 || ' , M01.ADD3 '
 || ' , M01.HKT_NM '
 || ' , M01.SFSK_BUSHO_NM '
 || ' , VJ1.BANK_NM '
 || ' , VJ1.BUSHO_NM1 '
 || ' , MG1.MGR_NM '
 || ' , MG1.ISIN_CD '
 || ' , K022.RBR_YMD '
 || ' , (CASE WHEN MG1.RBR_NISSU_SPAN <> ''1'' ' -- 利渡分 の日付
 || '  THEN K022.RBR_YMD '      -- 2:利払日間隔　 …休日補正後
 || '  ELSE K022.RBR_KJT '      -- 1:利払期日間隔 …休日補正前
 || '  END) AS RIWATARIBI '
 || ' , K022.KIJUN_ZNDK '
 || ' , MG2.TSUKARISHI_KNGK '
 || ' , MG2.RIRITSU '
 || ' , MG2.SPANANBUN_BUNBO '
 || ' , MG2.SPANANBUN_BUNSHI '
 || ' , MG1.KAKUSHASAI_KNGK '
 || ' , MG2.RKN_CALC_F_YMD '
 || ' , MG2.RKN_CALC_T_YMD '
 || ' , K022.IDO_YMD '
 || ' , K022.KOZA_FURI_KBN '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN BT01.HKO_KOZA_TEN_CD1 '
 || '    WHEN K022.KOZA_FURI_KBN = ''11'' THEN BT01.HKO_KOZA_TEN_CD2 '
 || '    WHEN K022.KOZA_FURI_KBN = ''12'' THEN BT01.HKO_KOZA_TEN_CD3 '
 || '    WHEN K022.KOZA_FURI_KBN = ''13'' THEN BT01.HKO_KOZA_TEN_CD4 '
 || '    WHEN K022.KOZA_FURI_KBN = ''14'' THEN BT01.HKO_KOZA_TEN_CD5 '
 || '    ELSE S06.KOZA_TEN_CD '
 || '   END) AS KOZA_TEN_CD2 '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN M041.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''11'' THEN M044.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''12'' THEN M045.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''13'' THEN M046.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''14'' THEN M047.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN >= ''20'' AND K022.KOZA_FURI_KBN < ''29'' THEN M042.BUTEN_NM '
 || '          WHEN K022.KOZA_FURI_KBN = ''60'' THEN M043.BUTEN_NM '
 || '   END) AS BUTEN_NM '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN MCD1.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''11'' THEN MCD2.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''12'' THEN MCD3.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''13'' THEN MCD4.CODE_NM '
 || '    WHEN K022.KOZA_FURI_KBN = ''14'' THEN MCD5.CODE_NM '
 || '    ELSE MCD6.CODE_NM '
 || '   END) AS KAMOKU_NM '
 || ' , (CASE WHEN K022.KOZA_FURI_KBN = ''10'' THEN M01.HKO_KOZA_NO '
 || '    WHEN K022.KOZA_FURI_KBN = ''11'' THEN BT01.HKO_KOZA_NO2 '
 || '    WHEN K022.KOZA_FURI_KBN = ''12'' THEN BT01.HKO_KOZA_NO3 '
 || '    WHEN K022.KOZA_FURI_KBN = ''13'' THEN BT01.HKO_KOZA_NO4 '
 || '    WHEN K022.KOZA_FURI_KBN = ''14'' THEN BT01.HKO_KOZA_NO5 '
 || '    ELSE S06.KOZA_NO '
 || '   END) AS KOZA_NO '
 || ' , K022.TSUKA_CD '
 || ' , M64.TSUKA_NM '
 || ' , MG1.HAKKO_TSUKA_CD '
 || ' , MG1.RBR_TSUKA_CD '
 || ' , MG1.SHOKAN_TSUKA_CD '
 || ' , K022.KKN_IDO_KBN '
 || ' , MG3.FUNIT_GENSAI_KNGK '
 || ' , MG3.FUNIT_SKN_PREMIUM '
 || ' , K022.KKN_NYUKIN_KNGK '
 || ' , MG7.CHOOSE_FLG '
 || ' , MG7GN.CHOOSE_FLG AS CHOOSE_FLG_GN'
 || ' , MG8.GNKN_SHR_TESU_BUNBO  AS GNKN_SHR_TESU_BUNBO '
 || ' , MG8.GNKN_SHR_TESU_BUNSHI AS GNKN_SHR_TESU_BUNSHI '
 || ' , MG8.RKN_SHR_TESU_BUNBO   AS RKN_SHR_TESU_BUNBO '
 || ' , MG8.RKN_SHR_TESU_BUNSHI  AS RKN_SHR_TESU_BUNSHI '
 || ' , MG7.TESU_SHURUI_CD       AS TESU_SHURUI_CD '
 || ' , M01.RYOSHU_OUT_KBN '
 || ' , MG1.RKN_ROUND_PROCESS '
 || ' , MG1.NENRBR_CNT '
 || ' , MG1.RBR_KAWASE_RATE '
 || ' , K022.DISPATCH_FLG '
 || ' , BT01.KYOTEN_KBN '
 || ' , MG1.MGR_RNM '
 || ' , MG1.TOKUREI_SHASAI_FLG '
 || ' , MG1.RITSUKE_WARIBIKI_KBN '
 || ' , MG1.HAKKO_YMD '
 || ' , MG2.KAIJI '
 || ' , MG1.MGR_CD '
 || ' , MG1.DPT_ASSUMP_FLG '
 || ' , MG2.RBR_KJT '
 || ' , MG1.TSUKARISHI_KNGK_NORM '
 || ' , MG1.KK_KANYO_FLG '
 || ' , MG1.HANKANEN_KBN '
 || ' , MG8.SZEI_SEIKYU_KBN '
 || 'FROM '
 || '   MHAKKOTAI M01 '
 || ' , MHAKKOTAI2 BT01 '
 || ' , MGR_STS MG0 '
 || ' , MGR_KIHON MG1 '
 || ' , MGR_RBRKIJ MG2 '
 || ' , (SELECT * FROM MGR_TESURYO_CTL WHERE TESU_SHURUI_CD IN (''61'',''82'') AND CHOOSE_FLG = ''1'' AND ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ) MG7 '
 || ' , (SELECT * FROM MGR_TESURYO_CTL WHERE TESU_SHURUI_CD = ''81'' AND CHOOSE_FLG = ''1'' AND ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ) MG7GN '
 || ' , (SELECT   ITAKU_KAISHA_CD '
 || '   , MGR_CD '
 || '   , SHOKAN_KJT '
 || '   , SUM(FUNIT_GENSAI_KNGK) AS FUNIT_GENSAI_KNGK '
 || '   , SUM(FUNIT_SKN_PREMIUM) AS FUNIT_SKN_PREMIUM '
 || '   FROM MGR_SHOKIJ '
 || '   WHERE SHOKAN_KBN <> ''30'' '
 || '   GROUP BY ITAKU_KAISHA_CD, MGR_CD, SHOKAN_KJT) MG3 '
 || ' , MGR_TESURYO_PRM MG8 '
 || ' , KOZA_FRK S06 '
 || ' , VJIKO_ITAKU VJ1 '
 || ' , MBUTEN M041 '
 || ' , MBUTEN M042 '
 || ' , MBUTEN M043 '
 || ' , MBUTEN M044 '
 || ' , MBUTEN M045 '
 || ' , MBUTEN M046 '
 || ' , MBUTEN M047 '
 || ' , SCODE MCD1 '
 || ' , SCODE MCD2 '
 || ' , SCODE MCD3 '
 || ' , SCODE MCD4 '
 || ' , SCODE MCD5 '
 || ' , SCODE MCD6 '
 || ' , MTSUKA M64 '
 || '   , (SELECT '
 || '        K021.ITAKU_KAISHA_CD '
 || '      , K021.MGR_CD '
 || '      , K021.TSUKA_CD '
 || '      , K021.RBR_YMD '
 || '      , K021.IDO_YMD '
 || '      , K021.KKN_NYUKIN_KNGK '
 || '      , K021.KOZA_FURI_KBN '
 || '      , K021.KKNBILL_SHURUI '
 || '      , K021.KKN_IDO_KBN '
 || '      , K021.RBR_KJT '
 || '      , K021.KIJUN_ZNDK '
 || '      , K021.ZNDK_KIJUN_YMD '
 || '      , K021.KKMEMBER_FS_KBN '
 || '      , K021.TESU_SHURUI_CD '
 || '      , K021.DISPATCH_FLG '
 || '      FROM '
 || '    ( '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , BT03.KOZA_FURI_KBN_GANKIN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , '' ''  AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '         KIKIN_IDO  K02 '
 || '       , MGR_KIHON2 BT03 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN = ''11'' '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 gSql := gSql || '     UNION ALL '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , BT03.KOZA_FURI_KBN_RIKIN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , '' ''  AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '       KIKIN_IDO  K02 '
 || '       , MGR_KIHON2 BT03 '
 || '       , MGR_KIHON MG1 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN = ''21'' '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG1.MGR_CD ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || '     UNION ALL '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , MG7.KOZA_FURI_KBN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , MG7.TESU_SHURUI_CD AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '       KIKIN_IDO  K02 '
 || '       , MGR_TESURYO_CTL MG7 '
 || '       , MGR_KIHON2 BT03 '
 || '       , MGR_KIHON MG1 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN IN (''12'', ''13'') '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG7.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG1.MGR_CD '
 || '     AND  MG7.TESU_SHURUI_CD = ''81'' '
 || '     AND  MG7.HAKKO_KICHU_KBN = ''2'' ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || '     UNION ALL '
 || '     SELECT '
 || '         K02.ITAKU_KAISHA_CD '
 || '       , K02.MGR_CD '
 || '       , K02.TSUKA_CD '
 || '       , K02.RBR_YMD '
 || '       , K02.IDO_YMD '
 || '       , K02.KKN_NYUKIN_KNGK '
 || '       , MG7.KOZA_FURI_KBN AS KOZA_FURI_KBN '
 || '       , K02.KKNBILL_SHURUI '
 || '       , K02.KKN_IDO_KBN '
 || '       , K02.RBR_KJT '
 || '       , K02.KIJUN_ZNDK '
 || '       , K02.ZNDK_KIJUN_YMD '
 || '       , K02.KKMEMBER_FS_KBN '
 || '       , MG7.TESU_SHURUI_CD AS TESU_SHURUI_CD '
 || '       , BT03.DISPATCH_FLG '
 || '     FROM '
 || '       KIKIN_IDO  K02 '
 || '       , MGR_TESURYO_CTL MG7 '
 || '       , MGR_KIHON2 BT03 '
 || '       , MGR_KIHON MG1 '
 || '     WHERE '
 || '       K02.ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' '
 || '     AND  K02.KKN_IDO_KBN IN (''22'', ''23'') '
 || '     AND  K02.DATA_SAKUSEI_KBN >= ''1'' '
 || '     AND  K02.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG7.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = BT03.MGR_CD '
 || '     AND  K02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
 || '     AND  K02.MGR_CD = MG1.MGR_CD '
 || '     AND  MG7.TESU_SHURUI_CD IN (''61'', ''82'') '
 || '     AND  MG7.CHOOSE_FLG = ''1'' '
 || '     AND  MG7.HAKKO_KICHU_KBN = ''2'' ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || '     AND  K02.IDO_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 ELSE
  gSql := gSql || '     AND  K02.RBR_YMD BETWEEN  ''' || l_inKijunYmdFrom || ''' AND  ''' || l_inKijunYmdTo || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || '    ) K021 '
 || '      ORDER BY '
 || '      K021.ITAKU_KAISHA_CD '
 || '    , K021.MGR_CD '
 || '    , K021.TSUKA_CD '
 || '    , K021.RBR_YMD '
 || '    , K021.IDO_YMD '
 || '    , K021.KOZA_FURI_KBN '
 || '    , K021.KKNBILL_SHURUI '
 || '    , K021.KKN_IDO_KBN '
 || '    , K021.RBR_KJT '
 || '   ) K022 ';
 IF l_inRBKbn = '1' THEN
  gSql := gSql || '  , SREPORT_WK SC16 ';
 END IF;
 gSql := gSql || 'WHERE '
        || ' K022.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG0.MGR_CD '
        || '  AND K022.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG7.MGR_CD '
        || '  AND K022.ITAKU_KAISHA_CD = MG7GN.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG7GN.MGR_CD '
        || '  AND K022.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG8.MGR_CD '
        || '  AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD '
        || '  AND MG1.HKT_CD = M01.HKT_CD '
        || '  AND MG1.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD '
        || '  AND MG1.HKT_CD = BT01.HKT_CD '
        || '  AND MG1.JTK_KBN NOT IN (''2'',''5'') '
        || '  AND MG0.MGR_STAT_KBN = ''1'' '
        || '  AND MG0.MASSHO_FLG = ''0'' '
        || '  AND MG1.PARTMGR_KBN IN (''0'',''2'') '
        || '  AND (MG1.PARTMGR_KBN IN (''0'',''1'') OR SUBSTR(MG1.YOBI3,14,1) = ''0'') '
        || '  AND K022.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG2.MGR_CD '
        || '  AND K022.RBR_KJT = MG2.RBR_KJT '
        || '  AND K022.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD '
        || '  AND K022.MGR_CD = MG3.MGR_CD '
        || '  AND K022.RBR_KJT = MG3.SHOKAN_KJT '
        || '  AND K022.ITAKU_KAISHA_CD = S06.ITAKU_KAISHA_CD '
        || '  AND K022.KOZA_FURI_KBN = S06.KOZA_FURI_KBN '
        || '  AND VJ1.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' '
        || '  AND BT01.ITAKU_KAISHA_CD = M041.ITAKU_KAISHA_CD '
        || '  AND BT01.HKO_KOZA_TEN_CD1 = M041.BUTEN_CD '
        || '  AND BT01.ITAKU_KAISHA_CD = M044.ITAKU_KAISHA_CD '
        || '  AND BT01.HKO_KOZA_TEN_CD2 = M044.BUTEN_CD '
        || '  AND BT01.ITAKU_KAISHA_CD = M045.ITAKU_KAISHA_CD '
        || '  AND BT01.HKO_KOZA_TEN_CD3 = M045.BUTEN_CD '
        || '  AND BT01.ITAKU_KAISHA_CD = M046.ITAKU_KAISHA_CD '
        || '  AND BT01.HKO_KOZA_TEN_CD4 = M046.BUTEN_CD '
        || '  AND BT01.ITAKU_KAISHA_CD = M047.ITAKU_KAISHA_CD '
        || '  AND BT01.HKO_KOZA_TEN_CD5 = M047.BUTEN_CD '
        || '  AND S06.ITAKU_KAISHA_CD = M042.ITAKU_KAISHA_CD '
        || '  AND S06.KOZA_TEN_CD = M042.BUTEN_CD '
        || '  AND M01.ITAKU_KAISHA_CD = M043.ITAKU_KAISHA_CD '
        || '  AND M01.EIGYOTEN_CD = M043.BUTEN_CD '
        || '  AND MCD1.CODE_SHUBETSU = ''707'' '
        || '  AND M01.HKO_KAMOKU_CD = MCD1.CODE_VALUE '
        || '  AND MCD2.CODE_SHUBETSU = ''707'' '
        || '  AND BT01.HKO_KAMOKU_CD2 = MCD2.CODE_VALUE '
        || '  AND MCD3.CODE_SHUBETSU = ''707'' '
        || '  AND BT01.HKO_KAMOKU_CD3 = MCD3.CODE_VALUE '
        || '  AND MCD4.CODE_SHUBETSU = ''707'' '
        || '  AND BT01.HKO_KAMOKU_CD4 = MCD4.CODE_VALUE '
        || '  AND MCD5.CODE_SHUBETSU = ''707'' '
        || '  AND BT01.HKO_KAMOKU_CD5 = MCD5.CODE_VALUE '
        || '  AND MCD6.CODE_SHUBETSU = ''707'' '
        || '  AND S06.KOZA_KAMOKU = MCD6.CODE_VALUE '
        || '  AND K022.TSUKA_CD = M64.TSUKA_CD ';
 IF l_inRBKbn = '1' THEN
  gSql := gSql || '  AND K022.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
       || '  AND K022.MGR_CD = MG1.MGR_CD '
       || '  AND SC16.USER_ID = ''' || pkconstant.BATCH_USER() || ''' '
       || '  AND SC16.SAKUSEI_YMD = ''' || l_inGyomuYmd || ''' '
       || '  AND SC16.CHOHYO_ID = ''WK931504651'' '
       || '  AND K022.ITAKU_KAISHA_CD = SC16.KEY_CD '
          || '  AND K022.MGR_CD = SC16.ITEM001 '
          || '  AND K022.RBR_KJT = SC16.ITEM002 '
          || '  AND K022.IDO_YMD = SC16.ITEM003 ';
 ELSE
  gSql := gSql || '  AND K022.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD '
       || '  AND K022.MGR_CD = MG1.MGR_CD ';
 END IF;
 IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
  gSql := gSql || '  AND M01.HKT_CD = ''' || l_inHktCd || ''' ';
 END IF;
 IF (trim(both l_inKozatenCd) IS NOT NULL AND (trim(both l_inKozatenCd))::text <> '') THEN
  gSql := gSql || '  AND M01.KOZA_TEN_CD = ''' || l_inKozatenCd || ''' ';
 END IF;
 IF (trim(both l_inKozatenCifCd) IS NOT NULL AND (trim(both l_inKozatenCifCd))::text <> '') THEN
  gSql := gSql || '  AND M01.KOZA_TEN_CIFCD = ''' || l_inKozatenCifCd || ''' ';
 END IF;
 IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.MGR_CD = ''' || l_inMgrCd || ''' ';
 END IF;
 IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
  gSql := gSql || '  AND MG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
 END IF;
 gSql := gSql || 'ORDER BY '
        || ' K022.TSUKA_CD ';
 IF l_inRBKbn = '0' THEN
  gSql := gSql || ' , K022.IDO_YMD '
       || ' , M01.KOZA_TEN_CD '
       || ' , M01.KOZA_TEN_CIFCD '
       || ' , BT01.KYOTEN_KBN '
       || ' , K022.DISPATCH_FLG '
       || ' , K022.KOZA_FURI_KBN '
       || ' , MG1.DPT_ASSUMP_FLG '
       || ' , MG1.HAKKO_YMD '
       || ' , MG1.ISIN_CD '
       || ' , K022.RBR_YMD ';
 ELSE
  gSql := gSql || ' , M01.KOZA_TEN_CD '
       || ' , M01.KOZA_TEN_CIFCD '
       || ' , BT01.KYOTEN_KBN '
       || ' , K022.DISPATCH_FLG '
       || ' , K022.IDO_YMD '
       || ' , K022.KOZA_FURI_KBN '
       || ' , MG1.DPT_ASSUMP_FLG '
       || ' , MG1.HAKKO_YMD '
       || ' , MG1.ISIN_CD ';
 END IF;
EXCEPTION
 WHEN OTHERS THEN
  RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
*/
-- REVOKE ALL ON PROCEDURE spipx046k15r02_createsql () FROM PUBLIC;

-- COMMENTED OUT: spipx046k15r02_initdata - code has been inlined into main procedure
/*



CREATE OR REPLACE PROCEDURE spipx046k15r02_initdata () AS $body$
BEGIN
 gKoFriLabel  := NULL;
 gKozaTenTitle  := NULL;
 gKozaNoTitle  := NULL;
 gKozaTenNm  := NULL;
 gRisokuKinLabel  := NULL;
 gRisokuKinCalcLabel := NULL;
 gRisokuKinTsuka1GAI := NULL;
 gRisokuKin1  := NULL;
 gRisokuKinTsuka1YEN := NULL;
 gCalcZandakaTsuka1GAI := NULL;
 gCalcZandaka1  := NULL;
 gCalcZandakaTsuka1YEN := NULL;
 gMultiSign1  := NULL;
 gTSUKARISHI_KNGK1 := NULL;
 gRisiGaku  := NULL;
 gEqualSign1  := NULL;
 gRisokuKinTsuka2GAI := NULL;
 gRisokuKin2  := NULL;
 gRisokuKinTsuka2YEN := NULL;
 gRisokuKinHasu  := NULL;
 gRisigakuMongon  := NULL;
 gKAKUSHASAI_KNGK1 := NULL;
 gMultiSign2  := NULL;
 gRIRITSU  := NULL;
 gMultiSign3  := NULL;
 gSPANANBUN_BUNSHI1 := NULL;
 gCalcDateBunsi  := NULL;
 gDivSign1  := NULL;
 gSPANANBUN_BUNBO := NULL;
 gCalcDateBunbo  := NULL;
 gEqualSign2  := NULL;
 gTSUKARISHI_KNGK2 := NULL;
 gEqualSign3  := NULL;
 gRisokuKin3  := NULL;
 gCalcHasuProc  := NULL;
 gRisokuKin4  := NULL;
 gDivSign2  := NULL;
 gKAKUSHASAI_KNGK2 := NULL;
 gEqualSign4  := NULL;
 gTSUKARISHI_KNGK3 := NULL;
 gRisokuCalcSpan  := NULL;
 gWrkRisokuCalcStart     := NULL;
 gDate1   := NULL;
 gWrkRisokuCalcEnd     := NULL;
 gDate2   := NULL;
 gFrontParentheses := NULL;
 gSPANANBUN_BUNSHI2 := NULL;
 gSpanBackParentheses := NULL;
 gTesuryoLabel  := NULL;
 gGankinTesuryoLabel := NULL;
 gGankinTesuryoFuriSai := NULL;
 gGNKN_SHR_TESU_BUNBO := NULL;
 gGnkn_Shr_Tesu_Mngn  := NULL;
 gGNKN_SHR_TESU_BUNSHI := NULL;
 gGankinBackParentheses := NULL;
 gGNKN_TSUKA_CD_GAI := NULL;
 gGANKIN_TESURYO  := NULL;
 gGNKN_TSUKA_CD_YEN := NULL;
 gGankinShohizeiLabel := NULL;
 gGNKN_TSUKA_CD_GAI_ZEI := NULL;
 gGANKIN_TESURYO_ZEI := NULL;
 gGNKN_TSUKA_CD_YEN_ZEI := NULL;
 gRikinTesuryoLabel := NULL;
 gRikinTesuryoLabel2 := NULL;
 gRikinTesuryoFuriSai := NULL;
 gRKN_SHR_TESU_BUNBO := NULL;
 gRkn_Shr_Tesu_Mngn  := NULL;
 gRKN_SHR_TESU_BUNSHI := NULL;
 gRikinBackParentheses := NULL;
 gRKN_TSUKA_CD_GAI := NULL;
 gRIKIN_TESURYO  := NULL;
 gRKN_TSUKA_CD_YEN := NULL;
 gRikinShohizeiLabel := NULL;
 gRKN_TSUKA_CD_GAI_ZEI := NULL;
 gRIKIN_TESURYO_ZEI := NULL;
 gRKN_TSUKA_CD_YEN_ZEI := NULL;
        gSzeiSeikyuKbn := NULL;
EXCEPTION
WHEN OTHERS THEN
 RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
*/
-- REVOKE ALL ON PROCEDURE spipx046k15r02_initdata () FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipx046k15r02_keisansikihantei ( l_inMgrCd varchar(13), l_inKaiji smallint, l_inHAKKO_TSUKA_CD char(3), l_inRBR_TSUKA_CD char(3), l_inTSUKARISHI_KNGK numeric(14,13), l_inRBR_KJT char(8), l_inRITSUKE_WARIBIKI_KBN char(1), l_inTSUKARISHI_KNGK_NORM numeric(14,13), l_inHANKANEN_KBN char(1), l_inSPANANBUN_BUNBO smallint, l_outKikanHantei OUT text , OUT extra_param varchar) RETURNS record AS $body$
DECLARE

 result   varchar(1);     -- リターン値
 gMaxRbrKjt  char(8);  -- 最終利払期日
 gShokanKbn  char(2);  -- 償還区分（コール分）
BEGIN
 -- 結果を初期化
 l_outKikanHantei := '1'; -- 出力対象外
 result := '0';    -- 出力対象
 -- リバースデュアル債判定
 IF l_inHAKKO_TSUKA_CD <> l_inRBR_TSUKA_CD THEN
  result := '1';
  extra_param := result;
  RETURN;
 END IF;
 --応答日
 IF l_inKaiji <> 0 THEN
  -- 固定利付債の場合
  IF l_inRITSUKE_WARIBIKI_KBN = 'F' THEN
   -- 初回利払１通貨あたりの利子額判定
   IF l_inKaiji = 1 THEN
    IF l_inTSUKARISHI_KNGK <> l_inTSUKARISHI_KNGK_NORM THEN
     result := '1';
     extra_param := result;
     RETURN;
    END IF;
   END IF;
   -- 最終利払期日取得
   SELECT
    trim(both MAX(RBR_KJT))
   INTO STRICT
    gMaxRbrKjt
   FROM
    MGR_RBRKIJ
   WHERE
    ITAKU_KAISHA_CD = l_inItakuKaishaCd
   AND MGR_CD = l_inMgrCd;
   -- 最終利払１通貨あたりの利子額判定
   IF l_inRBR_KJT = gMaxRbrKjt THEN
    IF l_inTSUKARISHI_KNGK <> l_inTSUKARISHI_KNGK_NORM THEN
     result := '1';
     extra_param := result;
     RETURN;
    END IF;
   END IF;
  END IF;
  -- 変動利付債の場合
  IF l_inRITSUKE_WARIBIKI_KBN = 'V' THEN
   -- 初回利払 半ヶ年区分の判定
   IF l_inKaiji = 1 THEN
    IF l_inHANKANEN_KBN = '1' THEN   --半ヶ年（年利払回数割）
     result := '1';
     extra_param := result;
     RETURN;
    END IF;
   END IF;
   -- 最終利払期日取得
   SELECT
    trim(both MAX(RBR_KJT))
   INTO STRICT
    gMaxRbrKjt
   FROM
    MGR_RBRKIJ
   WHERE
    ITAKU_KAISHA_CD = l_inItakuKaishaCd
   AND MGR_CD = l_inMgrCd;
   -- 最終利払 半ヶ年区分の判定
   IF l_inRBR_KJT = gMaxRbrKjt THEN
    IF l_inHANKANEN_KBN = '1' THEN   --半ヶ年（年利払回数割）
     result := '1';
     extra_param := result;
     RETURN;
    END IF;
   END IF;
  END IF;
 --非応答日
 ELSE
  -- 固定利付債の場合
  IF l_inRITSUKE_WARIBIKI_KBN = 'F' THEN
   result := '1';
   extra_param := result;
   RETURN;
  END IF;
  -- 変動利付債の場合
  IF l_inRITSUKE_WARIBIKI_KBN = 'V' THEN
   --半ヶ年区分の判定
   IF l_inHANKANEN_KBN = '1' THEN    -- 半ヶ年（年利払回数割）
    result := '1';
    extra_param := result;
    RETURN;
   END IF;
   -- コール（全額・一部）の判定
   SELECT SHOKAN_KBN INTO STRICT gShokanKbn
   FROM MGR_SHOKIJ
   WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
   AND MGR_CD = l_inMgrCd
   AND SHOKAN_KJT = l_inRBR_KJT
   AND SHOKAN_KBN IN ('40', '41');
   IF gShokanKbn = '41' THEN     -- コール（一部）
    result := '1';
    extra_param := result;
    RETURN;
   END IF;
  END IF;
 END IF;
 -- 利息計算期間の出力判定（1通貨利子の計算根拠出力対象に対して行う）
 IF l_inRITSUKE_WARIBIKI_KBN = 'V' AND l_inHANKANEN_KBN <> '1' AND l_inSPANANBUN_BUNBO > 12 THEN
  -- 変動利付債 かつ 半ヶ年（年利払回数割）以外 かつ 期間按分分母＞12 の場合
  l_outKikanHantei := '0'; -- 出力対象
 END IF;
 extra_param := result;
 RETURN; -- 0：出力対象
EXCEPTION
 WHEN OTHERS THEN
  CALL pkLog.fatal('ECM701', C_PROCEDURE_ID ||'.keisansikihantei','委託会社コード：' || l_inItakuKaishaCd || ' 銘柄コード：' || l_inMgrCd || ' 支払期日：' || l_inRBR_KJT);
  RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx046k15r02_keisansikihantei ( l_inMgrCd varchar(13), l_inKaiji smallint, l_inHAKKO_TSUKA_CD char(3), l_inRBR_TSUKA_CD char(3), l_inTSUKARISHI_KNGK numeric(14,13), l_inRBR_KJT char(8), l_inRITSUKE_WARIBIKI_KBN char(1), l_inTSUKARISHI_KNGK_NORM numeric(14,13), l_inHANKANEN_KBN char(1), l_inSPANANBUN_BUNBO smallint, l_outKikanHantei OUT text , OUT extra_param varchar) FROM PUBLIC;