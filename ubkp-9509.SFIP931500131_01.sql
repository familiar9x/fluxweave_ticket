


DROP TYPE IF EXISTS sfip931500131_01_type_record;
CREATE TYPE sfip931500131_01_type_record AS (
    gTsukaCd            char(3)                               -- 通貨コード
  , gTsukaNm            char(3)                               -- 通貨名称
  , gHktCd              char(6)                              -- 発行体コード
  , gMgrCd              varchar(13)                              -- 銘柄コード
  , gMgrRnm             varchar(44)                             -- 銘柄略称
  , gIsinCd             char(12)                             -- ＩＳＩＮコード
  , gGnrbaraiKjt        char(8)              -- 元利払期日
  , gFurikaeKngk        decimal(16,2)              -- 仮受金からの振替金額（税込）
  , gFurikaeZei         decimal(16,2)              -- 仮受金からの振替消費税額
  , gHktHnrKngk         numeric                                              -- 発行体への返戻金額
  , gHktHnrZei          numeric                                              -- 発行体への返戻金額（消費税）
  , gFurikaeYmd         char(8)                 -- 仮受金からの振替日
  , gIsUpfKeijo         varchar(1)                                        -- アップフロント手数料勘定計上フラグ
  , gGenFuriKbn         varchar(1)                                        -- 現登振替区分
  , gGnrKbn             varchar(1)                                        -- 元利区分
  );


CREATE OR REPLACE FUNCTION sfip931500131_01 ( l_inUserId text          -- ユーザID
 , l_inItakuKaishaCd text   -- 委託会社コード
 , l_inKijun_Ym text        -- 基準年月
 , l_inKeijo_Ymd text       -- 収益計上日
 , l_inChohyo_Kbn text      -- 帳票区分
 , l_outErrMsg OUT text        -- エラーコメント
 , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

--********************************************************************************************************************
-- * アップフロント分伝票起票シート
-- * アップフロント分伝票起票シート帳票出力データを設定。
-- *
-- * @author	ASK
-- *
-- * @version $Revision: 1.0 $
-- *
-- * @param	l_inUserId			  ユーザＩＤ
-- * @param	l_inItakuKaishaCd	委託会社コード
-- * @param	l_inKijun_Ym			基準年月
-- * @param	l_inKeijo_Ymd			収益計上日
-- * @param	l_inChohyo_Kbn		帳票区分
-- * @param	l_outErrMsg		    エラーコメント
-- * @return	returnCd			リターンコード
-- ********************************************************************************************************************
--====================================================================
--					デバッグ機能										  
--====================================================================
  DEBUG numeric(1) := 1;
--==============================================================================
--          定数定義                                                            
--==============================================================================
  RTN_OK        CONSTANT integer  := 0;                       -- 正常
  RTN_NG        CONSTANT integer  := 1;                       -- 予期したエラー
  RTN_NODATA    CONSTANT integer  := 2;                       -- データなし
  RTN_FATAL     CONSTANT integer  := 99;                      -- 予期せぬエラー
  REPORT_ID     CONSTANT varchar(20) := 'IP931500131';       -- 固定値．帳票ID
  MSG_NODATA    CONSTANT varchar(20) := '対象データなし';    -- 検索結果0件
  PROGRAM_ID    CONSTANT varchar(32) := 'SFIP931500131_01';  -- プログラムＩＤ
  -- 書式フォーマット
  FMT_KNGK_J  CONSTANT char(18)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';   -- 金額
  FMT_SZEI_J    CONSTANT char(18)  := 'ZZZ,ZZZ,ZZZ,ZZ9'; -- 税金額
  FMT_TOTAL_J  CONSTANT char(21)  := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';  -- 合計金額
  -- 書式フォーマット（外資）
  FMT_KNGK_F  CONSTANT char(21)  := 'ZZZ,ZZZ,ZZZ,ZZ9.99';    -- 金額
  FMT_SZEI_F    CONSTANT char(21)  := 'Z,ZZZ,ZZZ,ZZ9.99';  -- 税金額
  FMT_TOTAL_F  CONSTANT char(21)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';   -- 合計金額
--=======================================================================================================*
-- * 変数定義
-- *=======================================================================================================
  gyomuYmd            char(8);                        -- 業務日付
  returnCd            numeric;                         -- リターンコード
  seqNo               integer :=  0;                     -- シーケンス
  tsukaCd             MTSUKA.TSUKA_CD%TYPE;                   -- 通貨コード
  tsukaNm             MTSUKA.TSUKA_NM%TYPE;                   -- 通貨名称
  gengoYm             varchar(20);                           -- 基準年月（西暦）取得
  hktCd               MGR_KIHON.HKT_CD%TYPE;                  -- 発行体コード
  mgrCd               MGR_KIHON.MGR_CD%TYPE;                  -- 銘柄コード
  mgrRnm              MGR_KIHON.MGR_RNM%TYPE;                 -- 銘柄略称
  isinCd              MGR_KIHON.ISIN_CD%TYPE;                 -- ＩＳＩＮコード
  gnrbaraiKjt         UPFR_TESURYO_KEIJYO.GNRBARAI_KJT%TYPE;  -- 元利払期日
  -- 行単位集計変数
  furikaeKngk         numeric := 0;                       -- 仮受金からの振替金額
  furikaeZei          numeric := 0;                       -- 仮受金からの振替消費税額
  ukeSouteiKngk       numeric := 0;                       -- 発行体からの受入想定金額
  ukeSouteiZei        numeric := 0;                       -- 発行体からの受入想定金額消費税額
  ukeSouteiKngkUpf    numeric := 0;                       -- 発行体からの受入想定金額(アップフロント勘定計上テーブル)
  ukeSouteiZeiUpf     numeric := 0;                       -- 発行体からの受入想定金額消費税額(アップフロント勘定計上テーブル)
  hktHnrKngk          numeric := 0;                       -- 発行体への返戻金額
  hktHnrZei           numeric := 0;                       -- 発行体への返戻金額消費税額
  syuekiKeijoKngk     numeric := 0;                       -- 収益計上金額
  syuekiKeijoZei      numeric := 0;                       -- 収益計上消費税額
  -- 発行体単位集計変数
  hktKngkSum          numeric := 0;                       -- 発行体合計
  hktKngkSumStr       varchar(16);                           -- 発行体合計（表示用）
  -- ページ単位集計変数
  furikaeKngkSum      numeric := 0;                   -- 仮受金からの振替金額（合計）
  furikaeZeiSum       numeric := 0;                   -- 仮受金からの振替消費税額（合計）
  ukeSouteiKngkSum    numeric := 0;                   -- 発行体からの受入想定金額（合計）
  ukeSouteiZeiSum     numeric := 0;                   -- 発行体からの受入想定金額消費税額（合計）
  hktHnrKngkSum       numeric := 0;                   -- 発行体への返戻金額（合計）
  hktHnrZeiSum        numeric := 0;                   -- 発行体への返戻金額消費税額（合計）
  syuekiKeijoKngkSum  numeric := 0;                   -- 収益計上金額（合計）
  syuekiKeijoZeiSum   numeric := 0;                   -- 収益計上消費税額（合計）
  hktKngkSumTotal     numeric := 0;                   -- 発行体合計（合計）
  -- フッタ部変数
  furikaeYmd          UPFR_TESURYO_KEIJYO.KEIJO_YMD%TYPE; -- 仮受金からの振替日
  tesuKngk            numeric := 0;                   -- 税抜手数料
  tesuKngkSzei        numeric := 0;                   -- 税込手数料
  sZei                numeric := 0;                   -- 消費税
  tesuKngkSum         numeric := 0;                   -- 手数料合計
  tesuZeiSum          numeric := 0;                   -- 手数料消費税額合計
  fncRtn              numeric := 0;                   -- FUNCTION戻り値格納
  gSQL                varchar(10000) := NULL;    -- SQL編集
  v_item              type_sreport_wk_item;          -- Composite type for pkPrint.insertData
  -- カーソル
  curMeisai REFCURSOR;
  -- DB取得項目
  -- 配列定義
  recMeisai SFIP931500131_01_TYPE_RECORD;                      -- レコード
  -- 書式フォーマット
  fmtKngk     varchar(21) := NULL;        -- 金額
  fmtSzei     varchar(21) := NULL;        -- 税金額
  fmtTotal    varchar(21) := NULL;        -- 合計金額
  gInvoiceFlg MOPTION_KANRI.OPTION_FLG%TYPE;    -- オプションフラグ取得
  gBunsho     varchar(150) := NULL;       -- インボイス文章
  gAryBun     pkIpaBun.BUN_ARRAY;
--====================================================================*
--        メイン
-- *====================================================================
BEGIN
  CALL pkLog.DEBUG(l_inUserId,PROGRAM_ID,'START');
  --	入力パラメータ必須チェック	
  IF   coalesce(trim(both l_inUserId)::text, '') = ''
    OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
    OR coalesce(trim(both l_inKijun_Ym)::text, '') = ''
    OR coalesce(trim(both l_inChohyo_Kbn)::text, '') = ''
  THEN
    -- パラメータエラー
    l_outErrMsg := '入力パラメータエラー';
    CALL pkLog.error(l_inUserId, PROGRAM_ID, l_outErrMsg);
    extra_param := RTN_NG;
    RETURN;
  END IF;
  -- 業務日付の取得
  gyomuYmd := pkDate.getGyomuYmd();
  -- 基準年月（西暦）の取得
  gengoYm := pkDate.seirekiChangeSuppressNenGappi(l_inKijun_Ym || '01');
  gengoYm := SUBSTR(gengoYm,1,LENGTH(gengoYm)-3);
  -- 帳票ワークの削除
  DELETE FROM SREPORT_WK
  WHERE    KEY_CD      = l_inItakuKaishaCd
  AND      USER_ID     = l_inUserId
  AND      CHOHYO_KBN  = l_inChohyo_Kbn
  AND      SAKUSEI_YMD = gyomuYmd
  AND      CHOHYO_ID   = REPORT_ID;
  -- オプションフラグ取得
  gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_A', '0');
  -- インボイス文章取得
  IF gInvoiceFlg = '1' THEN
    gAryBun := pkIpaBun.getBun(REPORT_ID, 'L0');
    FOR i IN 0..coalesce(cardinality(gAryBun), 0) - 1 LOOP
         IF i = 0 THEN
             gBunsho := gAryBun[i];
         END IF;
    END LOOP;
  END IF;
  -- 変数初期化
  furikaeKngk := 0;
  furikaeZei := 0;
  ukeSouteiKngk := 0;
  ukeSouteiZei := 0;
  ukeSouteiKngkUpf := 0;
  ukeSouteiZeiUpf := 0;
  hktHnrKngk := 0;
  hktHnrZei := 0;
  syuekiKeijoKngk := 0;
  syuekiKeijoZei := 0;
  furikaeKngkSum := 0;
  furikaeZeiSum := 0;
  ukeSouteiKngkSum := 0;
  ukeSouteiZeiSum := 0;
  hktHnrKngkSum := 0;
  syuekiKeijoKngkSum := 0;
  syuekiKeijoZeiSum := 0;
  hktKngkSumTotal := 0;
  mgrCd := NULL;
  -- ヘッダーレコード出力
  CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyo_Kbn, gyomuYmd, REPORT_ID);
  -- SQL編集 (inlined from sfip931500131_01_createSQL procedure)
  gSQL := '';
  gSQL := 'SELECT '
      ||'    ViewSELECT.TSUKA_CD, '                                                           -- 通貨コード
      ||'    ViewSELECT.TSUKA_NM, '                                                           -- 通貨名称
      ||'    ViewSELECT.HKT_CD, '                                                             -- 発行体コード
      ||'    ViewSELECT.MGR_CD, '                                                             -- 銘柄コード
      ||'    ViewSELECT.MGR_RNM, '                                                            -- 銘柄略称
      ||'    ViewSELECT.ISIN_CD, '                                                            -- ＩＳＩＮコード
      ||'    ViewSELECT.GNRBARAI_KJT, '                                                       -- 元利払期日
      ||'    COALESCE(SUM(ViewSELECT.FURIKAE_KNGK),0), '                                           -- 仮受金からの振替金額(税込)
      ||'    COALESCE(SUM(ViewSELECT.FURIKAE_ZEI),0), '                                            -- 仮受金からの振替消費税額
      ||'    COALESCE(ViewSELECT.FURIKAE_KNGK_HNR,0), '                                            -- 発行体への返戻金額
      ||'    COALESCE(ViewSELECT.FURIKAE_ZEI_HNR,0), '                                             -- 発行体への返戻消費税額
      ||'    CASE WHEN ViewSELECT.IS_UPF_KEIJO = ''0'' THEN NULL ELSE MAX((TRIM(ViewSELECT.FURIKAE_YMD))::numeric) END, ' -- 仮受金からの振替日
      ||'    ViewSELECT.IS_UPF_KEIJO, '                                                       -- アップフロント手数料勘定計上フラグ
      ||'    ViewSELECT.GEN_FURI_KBN, '                                                       -- 現登振替区分
      ||'    ViewSELECT.GNR_KBN '                                                             -- 元利区分
      ||'  FROM  '
      ||'    ( SELECT '
      ||'        VMG1.TSUKA_CD AS TSUKA_CD, '                                                 -- 通貨コード
      ||'        VMG1.TSUKA_NM AS TSUKA_NM, '                                                 -- 通貨名称
      ||'        VMG1.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '                                   -- 委託会社コード
      ||'        VMG1.HKT_CD AS HKT_CD, '                                                     -- 発行体コード
      ||'        VMG1.MGR_CD AS MGR_CD, '                                                     -- 銘柄コード
      ||'        VMG1.MGR_RNM AS MGR_RNM, '                                                   -- 銘柄略称
      ||'        VMG1.ISIN_CD AS ISIN_CD, '                                                   -- ＩＳＩＮコード
      ||'        VMG1.RBR_KJT AS GNRBARAI_KJT, '                                              -- 元利払期日
      ||'        UPF.KEIJO_YMD AS FURIKAE_YMD, '                                              -- 仮受金からの振替日
      ||'        (CASE '
      ||'          WHEN UPF.SYUEKI_KEIJO_KNGK IS NULL '
      ||'            THEN NULL '
      ||'          ELSE '
      ||'            UPF.SYUEKI_KEIJO_KNGK '
      ||'             + UPF.SYUEKI_KEIJO_ZEI '
      ||'        END '
      ||'        ) AS FURIKAE_KNGK, '                                                         -- 仮受金からの振替金額(税込)
      ||'        UPF.SYUEKI_KEIJO_ZEI AS FURIKAE_ZEI, '                                       -- 仮受金からの振替消費税額
      ||'        ( CASE '
      ||'          WHEN VMG1.GNR_KBN = ''1'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN GNK_HNR.GNK_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  GNK_HNR.GNK_SHR_KNGK '
      ||'                   + GNK_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          WHEN VMG1.GNR_KBN = ''2'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN KKN_HNR.RKIN_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  KKN_HNR.RKIN_SHR_KNGK '
      ||'                   + KKN_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          ELSE '
      ||'            0 '
      ||'        END '
      ||'        ) AS FURIKAE_KNGK_HNR, '                                                     -- 仮受金からの振替金額(返戻分)
      ||'        ( CASE '
      ||'          WHEN VMG1.GNR_KBN = ''1'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN GNK_HNR.GNK_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  GNK_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          WHEN VMG1.GNR_KBN = ''2'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN KKN_HNR.RKIN_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  KKN_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          ELSE '
      ||'            0 '
      ||'        END '
      ||'        ) AS FURIKAE_ZEI_HNR, '                                                      -- 仮受金からの振替消費税額(返戻分)
      ||'        VMG1.GEN_FURI_KBN AS GEN_FURI_KBN, '                                         -- 現登振替区分
      ||'        COALESCE(VMG1.IS_UPF_KEIJO,''0'') AS IS_UPF_KEIJO, '                              -- アップフロント手数料勘定計上フラグ
      ||'        VMG1.GNR_KBN AS GNR_KBN '
      ||'      FROM  '
      ||'        MGR_KIHON_VIEW_UPF VMG1 '
      ||'        LEFT JOIN UPFR_TESURYO_KEIJYO UPF '
      ||'          ON VMG1.ITAKU_KAISHA_CD = UPF.ITAKU_KAISHA_CD '
      ||'         AND VMG1.GEN_FURI_KBN = UPF.GEN_FURI_KBN '
      ||'         AND VMG1.MGR_CD = UPF.MGR_CD '
      ||'         AND VMG1.RBR_KJT = UPF.GNRBARAI_KJT '
      ||'      WHERE 1=1 '
      ||'        AND VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
      ||'        AND VMG1.GNR_KBN = ''1'' '
      ||'        AND VMG1.GEN_FURI_KBN IN (''0'',''9'') '
      ||'        LEFT OUTER JOIN '
      ||'          (SELECT ITAKU_KAISHA_CD, '
      ||'                  MGR_CD, '
      ||'                  GEN_FURI_KBN, '
      ||'                  GNRBARAI_KJT, '
      ||'                  SUM(COALESCE(GNK_SHR_KNGK,0)) AS GNK_SHR_KNGK, '
      ||'                  SUM(COALESCE(TSUKA_HNR_SHR_KNGK,0)) AS TSUKA_HNR_SHR_KNGK '
      ||'             FROM SHNRTSU_YOTEI_TEKIYO_KKN '
      ||'            WHERE HAKK_HNRT_KBN = ''0'' '
      ||'              AND GEN_FURI_KBN = ''0'' '
      ||'              AND GNR_KBN = ''1'' '
      ||'            GROUP BY ITAKU_KAISHA_CD,MGR_CD,GEN_FURI_KBN,GNRBARAI_KJT '
      ||'          ) GNK_HNR '
      ||'        ON (VMG1.ITAKU_KAISHA_CD = GNK_HNR.ITAKU_KAISHA_CD '
      ||'               AND VMG1.MGR_CD = GNK_HNR.MGR_CD '
      ||'               AND VMG1.GEN_FURI_KBN = GNK_HNR.GEN_FURI_KBN '
      ||'               AND VMG1.RBR_KJT = GNK_HNR.GNRBARAI_KJT '
      ||'               AND VMG1.GNR_KBN = ''1'') '
      ||'        LEFT OUTER JOIN '
      ||'          (SELECT ITAKU_KAISHA_CD, '
      ||'                  MGR_CD, '
      ||'                  GEN_FURI_KBN, '
      ||'                  GNRBARAI_KJT, '
      ||'                  SUM(COALESCE(RKIN_SHR_KNGK,0)) AS RKIN_SHR_KNGK, '
      ||'                  SUM(COALESCE(TSUKA_HNR_SHR_KNGK,0)) AS TSUKA_HNR_SHR_KNGK '
      ||'             FROM SHNRTSU_YOTEI_TEKIYO_KKN '
      ||'            WHERE HAKK_HNRT_KBN = ''0'' '
      ||'              AND GEN_FURI_KBN = ''0'' '
      ||'              AND GNR_KBN = ''2'' '
      ||'            GROUP BY ITAKU_KAISHA_CD,MGR_CD,GEN_FURI_KBN,GNRBARAI_KJT '
      ||'          ) KKN_HNR '
      ||'        ON (VMG1.ITAKU_KAISHA_CD = KKN_HNR.ITAKU_KAISHA_CD '
      ||'               AND VMG1.MGR_CD = KKN_HNR.MGR_CD '
      ||'               AND VMG1.GEN_FURI_KBN = KKN_HNR.GEN_FURI_KBN '
      ||'               AND VMG1.RBR_KJT = KKN_HNR.GNRBARAI_KJT '
      ||'               AND VMG1.GNR_KBN = ''2'') '
      ||'        UNION '
      ||'      SELECT '
      ||'        VMG1.TSUKA_CD AS TSUKA_CD, '                                                 -- 通貨コード
      ||'        VMG1.TSUKA_NM AS TSUKA_NM, '                                                 -- 通貨名称
      ||'        VMG1.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '                                   -- 委託会社コード
      ||'        VMG1.HKT_CD AS HKT_CD, '                                                     -- 発行体コード
      ||'        VMG1.MGR_CD AS MGR_CD, '                                                     -- 銘柄コード
      ||'        VMG1.MGR_RNM AS MGR_RNM, '                                                   -- 銘柄略称
      ||'        VMG1.ISIN_CD AS ISIN_CD, '                                                   -- ＩＳＩＮコード
      ||'        VMG1.RBR_KJT AS GNRBARAI_KJT, '                                              -- 元利払期日
      ||'        UPF.KEIJO_YMD AS FURIKAE_YMD, '                                              -- 仮受金からの振替日
      ||'        (CASE '
      ||'          WHEN UPF.SYUEKI_KEIJO_KNGK IS NULL '
      ||'            THEN NULL '
      ||'          ELSE '
      ||'            UPF.SYUEKI_KEIJO_KNGK '
      ||'             + UPF.SYUEKI_KEIJO_ZEI '
      ||'        END '
      ||'        ) AS FURIKAE_KNGK, '                                                         -- 仮受金からの振替金額(税込)
      ||'        UPF.SYUEKI_KEIJO_ZEI AS FURIKAE_ZEI, '                                       -- 仮受金からの振替消費税額
      ||'        ( CASE '
      ||'          WHEN VMG1.GNR_KBN = ''1'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN GNK_HNR.GNK_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  GNK_HNR.GNK_SHR_KNGK '
      ||'                   + GNK_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          WHEN VMG1.GNR_KBN = ''2'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN KKN_HNR.RKIN_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  KKN_HNR.RKIN_SHR_KNGK '
      ||'                   + KKN_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          ELSE '
      ||'            0 '
      ||'        END '
      ||'        ) AS FURIKAE_KNGK_HNR, '                                                     -- 仮受金からの振替金額(返戻分)
      ||'        ( CASE '
      ||'          WHEN VMG1.GNR_KBN = ''1'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN GNK_HNR.GNK_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  GNK_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          WHEN VMG1.GNR_KBN = ''2'' AND VMG1.GEN_FURI_KBN = ''0'' '
      ||'            THEN '
      ||'              CASE '
      ||'                WHEN KKN_HNR.RKIN_SHR_KNGK IS NULL '
      ||'                  THEN 0 '
      ||'                ELSE '
      ||'                  KKN_HNR.TSUKA_HNR_SHR_KNGK '
      ||'              END '
      ||'          ELSE '
      ||'            0 '
      ||'        END '
      ||'        ) AS FURIKAE_ZEI_HNR, '                                                      -- 仮受金からの振替消費税額(返戻分)
      ||'         VMG1.GNR_KBN AS GNR_KBN '
      ||'      FROM  '
      ||'        MGR_KIHON_VIEW_UPF VMG1 '
      ||'        LEFT JOIN UPFR_TESURYO_KEIJYO UPF '
      ||'          ON VMG1.ITAKU_KAISHA_CD = UPF.ITAKU_KAISHA_CD '
      ||'         AND VMG1.GEN_FURI_KBN = UPF.GEN_FURI_KBN '
      ||'         AND VMG1.MGR_CD = UPF.MGR_CD '
      ||'         AND VMG1.RBR_KJT = UPF.GNRBARAI_KJT '
      ||'      WHERE 1=1 '
      ||'        AND VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
      ||'        AND VMG1.GNR_KBN = ''2'' '
      ||'        AND VMG1.GEN_FURI_KBN IN (''0'',''9'') '
      ||'        LEFT OUTER JOIN '
      ||'          (SELECT ITAKU_KAISHA_CD, '
      ||'                  MGR_CD, '
      ||'                  GEN_FURI_KBN, '
      ||'                  GNRBARAI_KJT, '
      ||'                  SUM(COALESCE(GNK_SHR_KNGK,0)) AS GNK_SHR_KNGK, '
      ||'                  SUM(COALESCE(TSUKA_HNR_SHR_KNGK,0)) AS TSUKA_HNR_SHR_KNGK '
      ||'             FROM SHNRTSU_YOTEI_TEKIYO_KKN '
      ||'            WHERE HAKK_HNRT_KBN = ''0'' '
      ||'              AND GEN_FURI_KBN = ''0'' '
      ||'              AND GNR_KBN = ''1'' '
      ||'            GROUP BY ITAKU_KAISHA_CD,MGR_CD,GEN_FURI_KBN,GNRBARAI_KJT '
      ||'          ) GNK_HNR '
      ||'        ON (VMG1.ITAKU_KAISHA_CD = GNK_HNR.ITAKU_KAISHA_CD '
      ||'               AND VMG1.MGR_CD = GNK_HNR.MGR_CD '
      ||'               AND VMG1.GEN_FURI_KBN = GNK_HNR.GEN_FURI_KBN '
      ||'               AND VMG1.RBR_KJT = GNK_HNR.GNRBARAI_KJT '
      ||'               AND VMG1.GNR_KBN = ''1'') '
      ||'        LEFT OUTER JOIN '
      ||'          (SELECT ITAKU_KAISHA_CD, '
      ||'                  MGR_CD, '
      ||'                  GEN_FURI_KBN, '
      ||'                  GNRBARAI_KJT, '
      ||'                  SUM(COALESCE(RKIN_SHR_KNGK,0)) AS RKIN_SHR_KNGK, '
      ||'                  SUM(COALESCE(TSUKA_HNR_SHR_KNGK,0)) AS TSUKA_HNR_SHR_KNGK '
      ||'             FROM SHNRTSU_YOTEI_TEKIYO_KKN '
      ||'            WHERE HAKK_HNRT_KBN = ''0'' '
      ||'              AND GEN_FURI_KBN = ''0'' '
      ||'              AND GNR_KBN = ''2'' '
      ||'            GROUP BY ITAKU_KAISHA_CD,MGR_CD,GEN_FURI_KBN,GNRBARAI_KJT '
      ||'          ) KKN_HNR '
      ||'        ON (VMG1.ITAKU_KAISHA_CD = KKN_HNR.ITAKU_KAISHA_CD '
      ||'               AND VMG1.MGR_CD = KKN_HNR.MGR_CD '
      ||'               AND VMG1.GEN_FURI_KBN = KKN_HNR.GEN_FURI_KBN '
      ||'               AND VMG1.RBR_KJT = KKN_HNR.GNRBARAI_KJT '
      ||'               AND VMG1.GNR_KBN = ''2'') '
      ||'    ) ViewSELECT '
      ||'  WHERE '
      ||'        SUBSTR(ViewSELECT.GNRBARAI_KJT,1,6) = ''' || l_inKijun_Ym || ''''
      ||'  GROUP BY '
      ||'    ViewSELECT.ITAKU_KAISHA_CD, '                                                    -- 委託会社コード
      ||'    ViewSELECT.TSUKA_CD, '                                                           -- 通貨コード
      ||'    ViewSELECT.TSUKA_NM, '                                                           -- 通貨名称
      ||'    ViewSELECT.HKT_CD, '                                                             -- 発行体コード
      ||'    ViewSELECT.MGR_CD, '                                                             -- 銘柄コード
      ||'    ViewSELECT.MGR_RNM, '                                                            -- 銘柄略称
      ||'    ViewSELECT.ISIN_CD, '                                                            -- ＩＳＩＮコード
      ||'    ViewSELECT.GNRBARAI_KJT, '                                                       -- 元利払期日
      ||'    ViewSELECT.FURIKAE_KNGK_HNR, '                                                   -- 発行体への返戻金額
      ||'    ViewSELECT.FURIKAE_ZEI_HNR, '                                                    -- 発行体への返戻消費税額
      ||'    ViewSELECT.IS_UPF_KEIJO, '                                                       -- アップフロント手数料勘定計上フラグ
      ||'    ViewSELECT.GEN_FURI_KBN, '                                                       -- 現登振替区分
      ||'    ViewSELECT.FURIKAE_YMD, '
      ||'    ViewSELECT.GNR_KBN '                                                             -- 元利区分
      ||'  ORDER BY '
      ||'    CASE WHEN ViewSELECT.IS_UPF_KEIJO = ''0'' THEN NULL ELSE MAX((TRIM(ViewSELECT.FURIKAE_YMD))::numeric) END, '
      ||'    ViewSELECT.TSUKA_CD, '                                                           -- 通貨コード
      ||'    ViewSELECT.HKT_CD, '
      ||'    ViewSELECT.MGR_CD, '
      ||'    ViewSELECT.GNRBARAI_KJT ';
  -- カーソルオープン
  OPEN curMeisai FOR EXECUTE gSQL;
  LOOP
    FETCH curMeisai
    INTO
        recMeisai.gTsukaCd             -- 通貨コード
      , recMeisai.gTsukaNm             -- 通貨名称
      , recMeisai.gHktCd               -- 発行体コード
      , recMeisai.gMgrCd               -- 銘柄コード
      , recMeisai.gMgrRnm              -- 銘柄略称
      , recMeisai.gIsinCd              -- ＩＳＩＮコード
      , recMeisai.gGnrbaraiKjt         -- 元利払期日
      , recMeisai.gFurikaeKngk         -- 仮受金からの振替金額（税込）
      , recMeisai.gFurikaeZei          -- 仮受金からの振替消費税額
      , recMeisai.gHktHnrKngk          -- 発行体への返戻金額
      , recMeisai.gHktHnrZei           -- 発行体への返戻金額（消費税）
      , recMeisai.gFurikaeYmd          -- 仮受金からの振替日
      , recMeisai.gIsUpfKeijo          -- アップフロント手数料勘定計上フラグ
      , recMeisai.gGenFuriKbn          -- 現登振替区分
      , recMeisai.gGnrKbn              -- 元利区分
;
    -- データが無くなったらループを抜ける
    EXIT WHEN NOT FOUND;/* apply on curMeisai */
    -- 1回目のループの場合、発行体コード・銘柄コードを設定
    IF coalesce(mgrCd::text, '') = '' THEN
      hktCd := recMeisai.gHktCd;
      mgrCd := recMeisai.gMgrCd;
    END IF;
    -- 銘柄コードが変わった場合（改行条件）
    IF mgrCd != recMeisai.gMgrCd THEN
      -- 発行体からの受入想定金額を取得
      SELECT coalesce(SUM(TESURYO_SHIHARAI_KNGK),0), coalesce(SUM(TESURYO_SHIHARAI_KNGK_ZEI),0)
      INTO STRICT ukeSouteiKngkUpf, ukeSouteiZeiUpf
      FROM UPFR_TESURYO_KEIJYO
      WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MGR_CD = mgrCd
        AND SUBSTR(GNRBARAI_KJT,1,6) = l_inKijun_Ym
        AND KEIJO_STS_KBN = '1';
      -- 行単位変数の集計
      furikaeKngk := furikaeKngk - hktHnrKngk;  -- 仮受金からの振替金額 - 発行体への返戻金額
      furikaeZei := furikaeZei - hktHnrZei;     -- 仮受金からの振替消費税金額 - 発行体への返戻金額（消費税）
      hktHnrKngk := 0;
      hktHnrZei := 0;
      ukeSouteiKngk := ukeSouteiKngk + ukeSouteiKngkUpf;
      ukeSouteiZei := ukeSouteiZei + ukeSouteiZeiUpf;
      syuekiKeijoKngk :=
        (furikaeKngk - ukeSouteiKngk - hktHnrKngk);   -- 収益計上金額
      syuekiKeijoZei :=
        (furikaeZei - ukeSouteiZei - hktHnrZei);      -- 収益計上金額消費税額
      -- 発行体単位変数の集計
      hktKngkSum := (hktKngkSum + syuekiKeijoKngk);
      -- ページ単位集計変数の集計
      furikaeKngkSum := (furikaeKngkSum + furikaeKngk);                   -- 仮受金からの振替金額（合計）
      furikaeZeiSum := (furikaeZeiSum + furikaeZei);                      -- 仮受金からの振替消費税額（合計）
      ukeSouteiKngkSum := (ukeSouteiKngkSum + ukeSouteiKngk);             -- 発行体からの受入想定金額（合計）
      ukeSouteiZeiSum := (ukeSouteiZeiSum + ukeSouteiZei);                -- 発行体からの受入想定消費税額（合計）
      hktHnrKngkSum := (hktHnrKngkSum + hktHnrKngk);                      -- 発行体への返戻金額（合計）
      syuekiKeijoKngkSum := (syuekiKeijoKngkSum + syuekiKeijoKngk);       -- 収益計上金額（合計）
      syuekiKeijoZeiSum := (syuekiKeijoZeiSum + syuekiKeijoZei);          -- 収益計上消費税額（合計）
      hktKngkSumTotal := (hktKngkSumTotal + syuekiKeijoKngk);             -- 発行体合計（合計）
      -- 発行体単位集計変数の設定（発行体コードの切り替えまたはページ切り替え時）
      IF (hktCd != recMeisai.gHktCd) OR (tsukaCd != recMeisai.gTsukaCd) OR (coalesce(trim(both furikaeYmd)::text, '') = '' AND (trim(both recMeisai.gFurikaeYmd) IS NOT NULL AND (trim(both recMeisai.gFurikaeYmd))::text <> '')) OR ((trim(both furikaeYmd) IS NOT NULL AND (trim(both furikaeYmd))::text <> '') AND coalesce(trim(both recMeisai.gFurikaeYmd)::text, '') = '') OR (trim(both furikaeYmd) != trim(both recMeisai.gFurikaeYmd))
      THEN
        -- 発行体合計（表示用）を設定
        hktKngkSumStr := hktKngkSum::text;
        -- 発行体合計を初期化
        hktKngkSum := 0;
      ELSE
        -- 発行体合計（表示用）を初期化
        hktKngkSumStr := '';
      END IF;
      --明細数カウントを行う
      seqNo := seqNo + 1;
      -- 抽出した結果を１レコードずつ帳票ワークテーブルへ出力
      		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := tsukaNm;	-- 通貨
		v_item.l_inItem003 := gengoYm;	-- 基本年月
		v_item.l_inItem004 := mgrCd;	-- 銘柄コード
		v_item.l_inItem005 := isinCd;	-- ISINコード
		v_item.l_inItem006 := mgrRnm;	-- 銘柄略称
		v_item.l_inItem007 := furikaeKngk;	-- 仮受金からの振替金額
		v_item.l_inItem008 := furikaeZei;	-- 仮受金からの振替消費税金額
		v_item.l_inItem009 := ukeSouteiKngk;	-- 発行体からの受入想定金額
		v_item.l_inItem010 := ukeSouteiZei;	-- 発行体からの受入想定消費税金額
		v_item.l_inItem011 := hktHnrKngk;	-- 発行体への返戻金額
		v_item.l_inItem012 := syuekiKeijoKngk;	-- 収益計上金額
		v_item.l_inItem013 := syuekiKeijoZei;	-- 収益計上消費税金額
		v_item.l_inItem014 := hktKngkSumStr;	-- 発行体合計
		v_item.l_inItem015 := furikaeKngkSum;	-- 仮受金からの振替金額（合計）
		v_item.l_inItem016 := furikaeZeiSum;	-- 仮受金からの振替消費税金額（合計）
		v_item.l_inItem017 := ukeSouteiKngkSum;	-- 発行体からの受入想定金額（合計）
		v_item.l_inItem018 := ukeSouteiZeiSum;	-- 発行体からの受入想定消費税金額（合計）
		v_item.l_inItem019 := hktHnrKngkSum;	-- 発行体への返戻金額（合計）
		v_item.l_inItem020 := syuekiKeijoKngkSum;	-- 収益計上金額（合計）
		v_item.l_inItem021 := syuekiKeijoZeiSum;	-- 収益計上消費税金額（合計）
		v_item.l_inItem022 := hktKngkSumTotal;	-- 発行体合計（合計）
		v_item.l_inItem023 := furikaeYmd;	-- 仮受金からの振替日
		v_item.l_inItem024 := furikaeKngkSum;	-- 仮受金からの金額
		v_item.l_inItem025 := trim(both l_inKeijo_Ymd);	-- 収益計上日（関与）日付
		v_item.l_inItem026 := syuekiKeijoKngkSum;	-- 収益計上日（関与）金額
		v_item.l_inItem032 := gBunsho;	-- インボイス文章
		v_item.l_inItem033 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem028 := fmtKngk;	-- 金額フォーマット
		v_item.l_inItem029 := fmtSzei;	-- 税金額フォーマット
		v_item.l_inItem030 := fmtTotal;	-- 合計金額フォーマット
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyo_Kbn,
			l_inSakuseiYmd	=> gyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> seqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
      -- 行単位集計変数の初期化
      furikaeKngk := 0;
      furikaeZei := 0;
      ukeSouteiKngk := 0;
      ukeSouteiZei := 0;
      hktHnrKngk := 0;
      hktHnrZei := 0;
      -- 通貨コード・振替日が変わった場合（改ページ条件）
      IF tsukaCd != recMeisai.gTsukaCd OR (coalesce(trim(both furikaeYmd)::text, '') = '' AND (trim(both recMeisai.gFurikaeYmd) IS NOT NULL AND (trim(both recMeisai.gFurikaeYmd))::text <> '')) OR ((trim(both furikaeYmd) IS NOT NULL AND (trim(both furikaeYmd))::text <> '') AND coalesce(trim(both recMeisai.gFurikaeYmd)::text, '') = '') OR (trim(both furikaeYmd) != trim(both recMeisai.gFurikaeYmd))
      THEN
        -- ページ単位集計変数の初期化
        furikaeKngkSum := 0;
        furikaeZeiSum := 0;
        ukeSouteiKngkSum := 0;
        ukeSouteiZeiSum := 0;
        hktHnrKngkSum := 0;
        syuekiKeijoKngkSum := 0;
        syuekiKeijoZeiSum := 0;
        hktKngkSumTotal := 0;
      END IF;
    END IF;
    -- 抽出結果を変数に設定
    hktCd := recMeisai.gHktCd;                                          -- 発行体コード
    mgrCd := recMeisai.gMgrCd;                                          -- 銘柄コード
    mgrRnm := recMeisai.gMgrRnm;                                        -- 銘柄略称
    isinCd := recMeisai.gIsinCd;                                        -- ＩＳＩＮコード
    tsukaCd := recMeisai.gTsukaCd;                                      -- 通貨コード
    tsukaNm := recMeisai.gTsukaNm;                                      -- 通貨名称
    gnrbaraiKjt := recMeisai.gGnrbaraiKjt;                              -- 元利払期日
    -- 仮受金からの振替日の設定
    IF coalesce(trim(both furikaeYmd)::text, '') = '' THEN
      furikaeYmd := trim(both recMeisai.gFurikaeYmd);
    ELSIF coalesce(trim(both recMeisai.gFurikaeYmd)::text, '') = '' THEN
      -- 1件でもレコードが取得できない場合、空白を設定
      furikaeYmd := NULL;
    ELSIF (trim(both recMeisai.gFurikaeYmd))::numeric  > trim(both furikaeYmd) THEN
      -- 複数レコードを取得した場合、直近日を設定
      furikaeYmd := trim(both recMeisai.gFurikaeYmd);
    END IF;
    -- 書式フォーマットの設定
    IF tsukaCd = 'JPY' THEN
      -- 円
      fmtKngk := FMT_KNGK_J;    -- 金額
      fmtSzei := FMT_SZEI_J;    -- 消費税
      fmtTotal := FMT_TOTAL_J;  -- 合計
    ELSE
      -- 外貨
      fmtKngk := FMT_KNGK_F;    -- 金額
      fmtSzei := FMT_SZEI_F;    -- 消費税
      fmtTotal := FMT_TOTAL_F;  -- 合計  
    END IF;
    -- 行単位集計変数の設定
    furikaeKngk := (furikaeKngk + recMeisai.gFurikaeKngk);              -- 仮受金からの振替金額（税込）
    furikaeZei := (furikaeZei + recMeisai.gFurikaeZei);                 -- 仮受金からの振替消費税額
    IF trim(both recMeisai.gGenFuriKbn) = '1' AND trim(both recMeisai.gIsUpfKeijo) = '0' THEN
      -- 現登振替区分 = '1'（振替債）且つアップフロント手数料勘定計上フラグ ＝ '0'の場合
      -- 手数料取得
      fncRtn := pkIpaCalcTesukngkUpf.getTesuZeiUpf(
        l_inItakuKaishaCd, mgrCd, gnrbaraiKjt, recMeisai.gGnrKbn, l_inUserId, tesuKngk, tesuKngkSzei, sZei);
      IF fncRtn != pkconstant.success() THEN
        extra_param := fncRtn;
        RETURN;
      END IF;
      -- 手数料合計設定
      ukeSouteiKngk := ukeSouteiKngk + tesuKngkSzei;    -- 発行体からの受入想定金額（税込）
      ukeSouteiZei := ukeSouteiZei + sZei;              -- 発行体からの受入想定消費税額
    ELSIF trim(both recMeisai.gGenFuriKbn) = '0' AND trim(both recMeisai.gIsUpfKeijo) = '0' AND coalesce(trim(both isinCd)::text, '') = '' THEN
      -- 現登振替区分 = '0'（現登債：非並存銘柄）且つアップフロント手数料勘定計上フラグ ＝ '0'の場合
      ukeSouteiKngk := 0;
      ukeSouteiZei := 0;
    END IF;
    hktHnrKngk := (hktHnrKngk + recMeisai.gHktHnrKngk); -- 発行体への返戻金額
    hktHnrZei := (hktHnrZei + recMeisai.gHktHnrZei);    -- 発行体への返戻金額（消費税）
  END LOOP;
  IF coalesce(mgrCd::text, '') = '' THEN
    -- [明細データ抽出]で対象データ無しの場合、「対象データなし」を帳票ワークテーブルへ出力
    		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := gengoYm;	-- 基本年月
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem031 := MSG_NODATA;	-- 対象データ無し
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyo_Kbn,
			l_inSakuseiYmd	=> gyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
    extra_param := RTN_NODATA;
    RETURN;
  END IF;
  -- 発行体からの受入想定金額を取得
  SELECT coalesce(SUM(TESURYO_SHIHARAI_KNGK),0), coalesce(SUM(TESURYO_SHIHARAI_KNGK_ZEI),0)
  INTO STRICT ukeSouteiKngkUpf, ukeSouteiZeiUpf
  FROM UPFR_TESURYO_KEIJYO
  WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
    AND MGR_CD = mgrCd
    AND SUBSTR(GNRBARAI_KJT,1,6) = l_inKijun_Ym
    AND KEIJO_STS_KBN = '1';
  -- 行単位変数の集計
  furikaeKngk := furikaeKngk - hktHnrKngk;  -- 仮受金からの振替金額 - 発行体への返戻金額
  furikaeZei := furikaeZei - hktHnrZei;     -- 仮受金からの振替消費税金額 - 発行体への返戻金額（消費税）
  hktHnrKngk := 0;
  hktHnrZei := 0;
  ukeSouteiKngk := ukeSouteiKngk + ukeSouteiKngkUpf;
  ukeSouteiZei := ukeSouteiZei + ukeSouteiZeiUpf;
  syuekiKeijoKngk :=
    (furikaeKngk - ukeSouteiKngk - hktHnrKngk);   -- 収益計上金額
  syuekiKeijoZei :=
    (furikaeZei - ukeSouteiZei - hktHnrZei);      -- 収益計上金額消費税額
  -- 発行体単位変数の集計
  hktKngkSum := (hktKngkSum + syuekiKeijoKngk);
  -- ページ単位集計変数の集計
  furikaeKngkSum := (furikaeKngkSum + furikaeKngk);                   -- 仮受金からの振替金額（合計）
  furikaeZeiSum := (furikaeZeiSum + furikaeZei);                      -- 仮受金からの振替消費税額（合計）
  ukeSouteiKngkSum := (ukeSouteiKngkSum + ukeSouteiKngk);             -- 発行体からの受入想定金額（合計）
  ukeSouteiZeiSum := (ukeSouteiZeiSum + ukeSouteiZei);                -- 発行体からの受入想定消費税額（合計）
  hktHnrKngkSum := (hktHnrKngkSum + hktHnrKngk);                      -- 発行体への返戻金額（合計）
  syuekiKeijoKngkSum := (syuekiKeijoKngkSum + syuekiKeijoKngk);       -- 収益計上金額（合計）
  syuekiKeijoZeiSum := (syuekiKeijoZeiSum + syuekiKeijoZei);          -- 収益計上消費税額（合計）
  hktKngkSumTotal := (hktKngkSumTotal + syuekiKeijoKngk);             -- 発行体合計（合計）
  -- 抽出した結果を帳票ワークテーブルへ出力
  --明細数カウントを行う
  seqNo := seqNo + 1;
  		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := tsukaNm;	-- 通貨
		v_item.l_inItem003 := gengoYm;	-- 基本年月
		v_item.l_inItem004 := mgrCd;	-- 銘柄コード
		v_item.l_inItem005 := isinCd;	-- ISINコード
		v_item.l_inItem006 := mgrRnm;	-- 銘柄略称
		v_item.l_inItem007 := furikaeKngk;	-- 仮受金からの振替金額
		v_item.l_inItem008 := furikaeZei;	-- 仮受金からの振替消費税金額
		v_item.l_inItem009 := ukeSouteiKngk;	-- 発行体からの受入想定金額
		v_item.l_inItem010 := ukeSouteiZei;	-- 発行体からの受入想定消費税金額
		v_item.l_inItem011 := hktHnrKngk;	-- 発行体への返戻金額
		v_item.l_inItem012 := syuekiKeijoKngk;	-- 収益計上金額
		v_item.l_inItem013 := syuekiKeijoZei;	-- 収益計上消費税金額
		v_item.l_inItem014 := hktKngkSum;	-- 発行体合計
		v_item.l_inItem015 := furikaeKngkSum;	-- 仮受金からの振替金額（合計）
		v_item.l_inItem016 := furikaeZeiSum;	-- 仮受金からの振替消費税金額（合計）
		v_item.l_inItem017 := ukeSouteiKngkSum;	-- 発行体からの受入想定金額（合計）
		v_item.l_inItem018 := ukeSouteiZeiSum;	-- 発行体からの受入想定消費税金額（合計）
		v_item.l_inItem019 := hktHnrKngkSum;	-- 発行体への返戻金額（合計）
		v_item.l_inItem020 := syuekiKeijoKngkSum;	-- 収益計上金額（合計）
		v_item.l_inItem021 := syuekiKeijoZeiSum;	-- 収益計上消費税金額（合計）
		v_item.l_inItem022 := hktKngkSumTotal;	-- 発行体合計（合計）
		v_item.l_inItem023 := furikaeYmd;	-- 仮受金からの振替日
		v_item.l_inItem024 := furikaeKngkSum;	-- 仮受金からの金額
		v_item.l_inItem025 := trim(both l_inKeijo_Ymd);	-- 収益計上日（関与）日付
		v_item.l_inItem026 := syuekiKeijoKngkSum;	-- 収益計上日（関与）金額
		v_item.l_inItem032 := gBunsho;	-- インボイス文章
		v_item.l_inItem033 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem028 := fmtKngk;	-- 金額フォーマット
		v_item.l_inItem029 := fmtSzei;	-- 税金額フォーマット
		v_item.l_inItem030 := fmtTotal;	-- 合計金額フォーマット
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyo_Kbn,
			l_inSakuseiYmd	=> gyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> seqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
  extra_param := RTN_OK;
  RETURN;
EXCEPTION
    WHEN OTHERS THEN
      CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
      CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
      l_outErrMsg := SQLERRM;
      extra_param := RTN_FATAL;
      RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfip931500131_01 ( l_inUserId text , l_inItakuKaishaCd text , l_inKijun_Ym text , l_inKeijo_Ymd text , l_inChohyo_Kbn text , l_outErrMsg OUT text , OUT extra_param numeric) FROM PUBLIC;




-- NESTED PROCEDURE INLINED ABOVE - PostgreSQL does not support nested procedures accessing parent variables
/*
CREATE OR REPLACE PROCEDURE sfip931500131_01_createsql () AS $body$
BEGIN
  -- 変数を初期化
  gSql := '';
  -- 変数にSQLクエリ文を代入
  gSql := 'SELECT '
      ||'    ViewSELECT.TSUKA_CD, '                                                           -- 通貨コード
      ||'    ViewSELECT.TSUKA_NM, '                                                           -- 通貨名称
      ||'    ViewSELECT.HKT_CD, '                                                             -- 発行体コード
      ||'    ViewSELECT.MGR_CD, '                                                             -- 銘柄コード
      ||'    ViewSELECT.MGR_RNM, '                                                            -- 銘柄略称
      ||'    ViewSELECT.ISIN_CD, '                                                            -- ＩＳＩＮコード
      ||'    ViewSELECT.GNRBARAI_KJT, '                                                       -- 元利払期日
      ||'    COALESCE(SUM(ViewSELECT.FURIKAE_KNGK),0), '                                           -- 仮受金からの振替金額(税込)
      ||'    COALESCE(SUM(ViewSELECT.FURIKAE_ZEI),0), '                                            -- 仮受金からの振替消費税額
      ||'    COALESCE(ViewSELECT.FURIKAE_KNGK_HNR,0), '                                            -- 発行体への返戻金額
      ||'    COALESCE(ViewSELECT.FURIKAE_ZEI_HNR,0), '                                             -- 発行体への返戻消費税額
      ||'    CASE WHEN ViewSELECT.IS_UPF_KEIJO = ''0'' THEN NULL ELSE MAX((TRIM(ViewSELECT.FURIKAE_YMD))::numeric) END, ' -- 仮受金からの振替日
      ||'    ViewSELECT.IS_UPF_KEIJO, '                                                       -- アップフロント手数料勘定計上フラグ
      ||'    ViewSELECT.GEN_FURI_KBN, '                                                       -- 現登振替区分
      ||'    ViewSELECT.GNR_KBN '                                                             -- 元利区分
      ||'  FROM  '
      ||'    ( SELECT '
      ||'        VMG1.TSUKA_CD AS TSUKA_CD, '                                                 -- 通貨コード
      ||'        VMG1.TSUKA_NM AS TSUKA_NM, '                                                 -- 通貨名称
      ||'        VMG1.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '                                   -- 委託会社コード
      ||'        VMG1.HKT_CD AS HKT_CD, '                                                     -- 発行体コード
      ||'        VMG1.MGR_CD AS MGR_CD, '                                                     -- 銘柄コード
      ||'        VMG1.MGR_RNM AS MGR_RNM, '                                                   -- 銘柄略称
      ||'        VMG1.ISIN_CD AS ISIN_CD, '                                                   -- ＩＳＩＮコード
      ||'        VMG1.RBR_KJT AS GNRBARAI_KJT, '                                              -- 元利払期日
      ||'        VMG1.KKN_NYUKIN_KNGK AS FURIKAE_KNGK, '                                      -- 仮受金からの振替金額(税込)
      ||'        (CASE WHEN VMG1.KKN_IDO_KBN IN (''13'',''23'') '                             -- (コード種別:101、103)
      ||'          THEN VMG1.KKN_NYUKIN_KNGK '
      ||'          ELSE 0 '
      ||'         END) AS FURIKAE_ZEI, '                                                      -- 仮受金からの振替消費税額
      ||'        UPF.KEIJO_YMD AS FURIKAE_YMD, '                                              -- 仮受金からの振替日
      ||'        COALESCE(UPF.KEIJO_STS_KBN,''0'') AS IS_UPF_KEIJO, '                              -- アップフロント手数料勘定計上フラグ
      ||'        VMG1.GEN_FURI_KBN AS GEN_FURI_KBN, '                                         -- 現登振替区分
      ||'        ( CASE WHEN VMG1.GEN_FURI_KBN = ''0'' AND TRIM(VMG1.ISIN_CD) IS NULL THEN '  --(現登債)
      ||'             CASE VMG1.GNR_KBN WHEN ''1'' THEN ' -- 元金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.GNKN_TESU_KNGK),0) + '
      ||'                       COALESCE(SUM(KKN_HNR_GT.GNKN_TESU_KNGK_ZEI),0) '
      ||'               FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'               WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                 AND VMG1.MGR_CD = KKN_HNR_GT.MGR_CD '
      ||'                 AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                 AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             ELSE '                              -- 利金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.RKN_TESU_KNGK),0) +   '
      ||'                       COALESCE(SUM(KKN_HNR_GT.RKN_TESU_KNGK_ZEI),0) '
      ||'               FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'               WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                 AND VMG1.MGR_CD = KKN_HNR_GT.MGR_CD '
      ||'                 AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                 AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             END '
      ||'          WHEN VMG1.GEN_FURI_KBN = ''0'' THEN '                                      --(現登債:並存銘柄)
      ||'             CASE VMG1.GNR_KBN WHEN ''1'' THEN ' -- 元金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.GNKN_TESU_KNGK),0) +  '
      ||'                       COALESCE(SUM(KKN_HNR_GT.GNKN_TESU_KNGK_ZEI),0) '
      ||'                FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'                WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                  AND KKN_HNR_GT.MGR_CD = ( '
      ||'                     SELECT DISTINCT MG01.MGR_CD FROM B_MGR_KIHON MG01 '
      ||'                     WHERE MG01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
      ||'                       AND MG01.ISIN_CD = VMG1.ISIN_CD) '
      ||'                  AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                  AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             ELSE '                              -- 利金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.RKN_TESU_KNGK),0) + '
      ||'                       COALESCE(SUM(KKN_HNR_GT.RKN_TESU_KNGK_ZEI),0) '
      ||'                FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'                WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                  AND KKN_HNR_GT.MGR_CD = ( '
      ||'                     SELECT DISTINCT MG01.MGR_CD FROM B_MGR_KIHON MG01 '
      ||'                     WHERE MG01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
      ||'                       AND MG01.ISIN_CD = VMG1.ISIN_CD) '
      ||'                  AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                  AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             END '
      ||'          ELSE '                                                                     --(振替債)
      ||'            (SELECT COALESCE(SUM(KKN_HNR.SHR_TESU_KNGK),0) +   '
      ||'                    COALESCE(SUM(KKN_HNR.SHR_TESU_SZEI),0) '
      ||'            FROM KIKIN_HENREI KKN_HNR '
      ||'            WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR.ITAKU_KAISHA_CD '
      ||'              AND VMG1.MGR_CD = KKN_HNR.MGR_CD '
      ||'              AND VMG1.TSUKA_CD = KKN_HNR.TSUKA_CD '
      ||'              AND VMG1.RBR_KJT = KKN_HNR.RBR_KJT '
      ||'              AND VMG1.GNR_KBN = KKN_HNR.GNR_KBN) '
      ||'          END '
      ||'        ) AS FURIKAE_KNGK_HNR, '                                                     -- 仮受金からの振替金額(返戻分)
      ||'        ( CASE WHEN VMG1.GEN_FURI_KBN = ''0'' AND TRIM(VMG1.ISIN_CD) IS NULL THEN '  --(現登債)
      ||'             CASE VMG1.GNR_KBN WHEN ''1'' THEN ' -- 元金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.GNKN_TESU_KNGK_ZEI),0) '
      ||'               FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'               WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                 AND VMG1.MGR_CD = KKN_HNR_GT.MGR_CD '
      ||'                 AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                 AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             ELSE '                              -- 利金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.RKN_TESU_KNGK_ZEI),0) '
      ||'               FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'               WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                 AND VMG1.MGR_CD = KKN_HNR_GT.MGR_CD '
      ||'                 AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                 AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             END '
      ||'          WHEN VMG1.GEN_FURI_KBN = ''0'' THEN '                                      --(現登債:並存銘柄)
      ||'             CASE VMG1.GNR_KBN WHEN ''1'' THEN ' -- 元金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.GNKN_TESU_KNGK_ZEI),0) '
      ||'                FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'                WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                  AND KKN_HNR_GT.MGR_CD = ( '
      ||'                     SELECT DISTINCT MG01.MGR_CD FROM B_MGR_KIHON MG01 '
      ||'                     WHERE MG01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
      ||'                       AND MG01.ISIN_CD = VMG1.ISIN_CD) '
      ||'                  AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                  AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             ELSE '                              -- 利金
      ||'               (SELECT COALESCE(SUM(KKN_HNR_GT.RKN_TESU_KNGK_ZEI),0) '
      ||'                FROM B_KIKIN_HENREI KKN_HNR_GT '
      ||'                WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'                  AND KKN_HNR_GT.MGR_CD = ( '
      ||'                     SELECT DISTINCT MG01.MGR_CD FROM B_MGR_KIHON MG01 '
      ||'                     WHERE MG01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
      ||'                       AND MG01.ISIN_CD = VMG1.ISIN_CD) '
      ||'                  AND VMG1.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'                  AND VMG1.RBR_KJT = KKN_HNR_GT.RBR_KJT) '
      ||'             END '
      ||'          ELSE '                                                                     --(振替債)
      ||'            (SELECT COALESCE(SUM(KKN_HNR.SHR_TESU_SZEI),0) '
      ||'             FROM KIKIN_HENREI KKN_HNR '
      ||'             WHERE VMG1.ITAKU_KAISHA_CD = KKN_HNR.ITAKU_KAISHA_CD '
      ||'               AND VMG1.MGR_CD = KKN_HNR.MGR_CD '
      ||'               AND VMG1.TSUKA_CD = KKN_HNR.TSUKA_CD '
      ||'               AND VMG1.RBR_KJT = KKN_HNR.RBR_KJT '
      ||'               AND VMG1.GNR_KBN = KKN_HNR.GNR_KBN) '
      ||'          END '
      ||'        ) AS FURIKAE_ZEI_HNR, '                                                      -- 仮受金からの振替消費税額(返戻分)
      ||'         VMG1.GNR_KBN AS GNR_KBN '
      ||'      FROM  '
      ||'        MGR_KIHON_VIEW_UPF VMG1 '
      ||'        LEFT JOIN UPFR_TESURYO_KEIJYO UPF '
      ||'          ON VMG1.ITAKU_KAISHA_CD = UPF.ITAKU_KAISHA_CD '
      ||'         AND VMG1.GEN_FURI_KBN = UPF.GEN_FURI_KBN '
      ||'         AND VMG1.MGR_CD = UPF.MGR_CD '
      ||'         AND VMG1.RBR_KJT = UPF.GNRBARAI_KJT '
      ||'      WHERE 1=1 ';
  gSql := gSql ||'    ) ViewSELECT '
      ||'  WHERE '
      ||'        SUBSTR(ViewSELECT.GNRBARAI_KJT,1,6) = ''' || l_inKijun_Ym || ''''
      ||'  GROUP BY '
      ||'    ViewSELECT.ITAKU_KAISHA_CD, '                                                    -- 委託会社コード
      ||'    ViewSELECT.TSUKA_CD, '                                                           -- 通貨コード
      ||'    ViewSELECT.TSUKA_NM, '                                                           -- 通貨名称
      ||'    ViewSELECT.HKT_CD, '                                                             -- 発行体コード
      ||'    ViewSELECT.MGR_CD, '                                                             -- 銘柄コード
      ||'    ViewSELECT.MGR_RNM, '                                                            -- 銘柄略称
      ||'    ViewSELECT.ISIN_CD, '                                                            -- ＩＳＩＮコード
      ||'    ViewSELECT.GNRBARAI_KJT, '                                                       -- 元利払期日
      ||'    ViewSELECT.FURIKAE_KNGK_HNR, '                                                   -- 発行体への返戻金額
      ||'    ViewSELECT.FURIKAE_ZEI_HNR, '                                                    -- 発行体への返戻消費税額
      ||'    ViewSELECT.IS_UPF_KEIJO, '                                                       -- アップフロント手数料勘定計上フラグ
      ||'    ViewSELECT.GEN_FURI_KBN, '                                                       -- 現登振替区分
      ||'    ViewSELECT.FURIKAE_YMD, '
      ||'    ViewSELECT.GNR_KBN '                                                             -- 元利区分
      ||'  ORDER BY '
      ||'    CASE WHEN ViewSELECT.IS_UPF_KEIJO = ''0'' THEN NULL ELSE MAX((TRIM(ViewSELECT.FURIKAE_YMD))::numeric) END, '
      ||'    ViewSELECT.TSUKA_CD, '                                                           -- 通貨コード
      ||'    ViewSELECT.HKT_CD, '
      ||'    ViewSELECT.MGR_CD, '
      ||'    ViewSELECT.GNRBARAI_KJT ';
   EXCEPTION
  WHEN OTHERS THEN
    RAISE;
  END;
$body$
LANGUAGE PLPGSQL
;
*/
-- REVOKE ALL ON PROCEDURE sfip931500131_01_createsql () FROM PUBLIC;
