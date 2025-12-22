




CREATE OR REPLACE PROCEDURE spipi003k14r01 ( 
  l_inItakuKaishaCd text,    -- 委託会社コード
 l_inUserId text,  -- ユーザーID
 l_inChohyoKbn text,  -- 帳票区分
 l_inGyomuYmd text,  -- 業務日付
 l_inBaYmd text,    -- 基準年度
 l_inPaCls text,    -- 期別区分
 l_inMiShuFlg text,    --未収手数料・無担保
 l_inMiShuFlg1 text,    --未収手数料・担保附
 l_inMiKeikaFlg text,    --未経過手数料・無担保
 l_inMiKeikaFlg1 text,    --未経過手数料・担保附
 l_outSqlCode OUT integer,       -- リターン値
 l_outSqlErrM OUT text  -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:四半期毎に未収/未経過手数料を計算し「受入手数料期間対応収益一覧」に出力する。
-- *        出力対象となる手数料は以下の通りとする。
-- *        期中信託報酬
-- *        期中管理手数料
-- *
-- * 引数　:l_inItakuKaishaCd IN VARCHAR2,     委託会社コード
-- *       l_inUserId           IN VARCHAR2,     ユーザーID
-- *       l_inChohyoKbn        IN VARCHAR2,   帳票区分
-- *       l_inGyomuYmd         IN VARCHAR2,     業務日付
-- *       l_inBaYmd         IN VARCHAR2,    基準年度
-- *       l_inPaCls         IN VARCHAR2,    期別区分
-- *       l_inMiShuFlg      IN VARCHAR2,      未収手数料・無担保
-- *       l_inMiShuFlg1     IN VARCHAR2,      未収手数料・担保附
-- *       l_inMiKeikaFlg    IN VARCHAR2,      未経過手数料・無担保
-- *       l_inMiKeikaFlg1   IN VARCHAR2,      未経過手数料・担保附
-- *       l_outSqlCode         OUT NUMBER,          リターン値
-- *       l_outSqlErrM         OUT VARCHAR2     エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author 陳威宇
-- * @version $Id: SPIPI003K14R01.sql,v 1.4 2013/07/08 09:20:18 nakamura Exp $
-- *
-- 
    --==============================================================================
    --          定数定義                                                            
    --==============================================================================
  C_PROCEDURE_ID      CONSTANT text := 'SPIPI003K14R01';         -- プロシージャＩＤ
  C_PRGRAM_NAME       CONSTANT text := '受入手数料期間対応収益一覧'; -- プロシージャ名
  CHOHYOID            CONSTANT text := 'IPQ30000311';            --固定値．帳票ID
  
  --==============================================================================
    --      変数定義                               
    --==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
  gRtnCd              numeric := pkconstant.success();       -- リターンコード 
  gBaYm               varchar(6) := NULL;                --変数．基準年月
  gCount              integer := 0;                       --変数．件数
  gTesu               numeric := 0;                        --変数．手数料率
  gDateCnt            integer := 0;                       --変数．未既収日数
  gBiCnt              integer := 0;                       --変数．期間日数
  gRet                numeric := 0;                        --リターン値
  gPlaCls             varchar(300);                           --期別
  gTitleCls           varchar(300);                           --タイトル　分類
  --エラー処理用 
  
  errMsg               varchar(300);
  errCode              varchar(6);
  --==============================================================================
    --                  カーソル定義                
    --==============================================================================
  curMeisai CURSOR(
                  BaYm MISYU_MAEUKE.HOSEI_KIJUN_YM%TYPE,
                  inItakuKaishaCd MISYU_MAEUKE.ITAKU_KAISHA_CD%TYPE,
                  inMiShuFlg    numeric,
                  inMiShuFlg1   numeric,                         
                  inMiKeikaFlg  numeric,                             
                  inMiKeikaFlg1 numeric
  ) FOR
    SELECT
      MI,     --受託区分
      MISHU,  --未既収区分
      ISIN,   --ISINコード
      MGR,    --銘柄コード
      RNM,    --銘柄略称
      SRC,    --手数料種類コード
      SRN,    --手数料種類名称
      ZNDK,   --基準残高
      NYU,    --入金日
      BUNS,   --自行分配率(分子)
      BUNB,   --自行分配率(分母)
      RS,     --手数料率分子
      RB,     --手数料率分母
      TNK,    --手数料金額(税抜)
      SK,     --消費税金額
      HBS,    --補正期間分子開始日
      HBE,    --補正期間分子終了日
      HBBS,   --補正期間分母開始日
      HBBE,   --補正期間分母終了日
      HTNK,   --補正_手数料額（税抜）
      HSK,    --補正_消費税額
      CPC,    --計算パターン
      FB       --手数料分類
    FROM (
      SELECT MISYU_MAEUKE.JTK_KBN MI,                 --受託区分
             '未収' MISHU,                             --'未収'                                             
             MGR_KIHON.ISIN_CD ISIN,                  --ISINコード                                              
             MISYU_MAEUKE.MGR_CD MGR,                 --銘柄コード                                              
             MGR_KIHON.MGR_RNM RNM,                   --銘柄略称                                                
             TESURYO_KANRI.TESU_SHURUI_CD SRC,        --手数料種類コード                                                
             TESURYO_KANRI.KONAI_TESU_SHURUI_NM SRN,        --手数料種類名称                                              
             MISYU_MAEUKE.KIJUN_ZNDK ZNDK,            --基準残高
             MISYU_MAEUKE.NYUKIN_YMD NYU,             --入金日                                              
             MISYU_MAEUKE.OWN_DF_BUNSHI BUNS,         --自行分配率(分子)                                                
             MISYU_MAEUKE.OWN_DF_BUNBO BUNB,          --自行分配率(分母)                                                
             MISYU_MAEUKE.TESU_RITSU_BUNSHI RS,       --手数料率分子                                                
             MISYU_MAEUKE.TESU_RITSU_BUNBO RB,        --手数料率分母                                                
             MISYU_MAEUKE.TESU_NUKI_KNGK TNK,         --手数料金額(税抜)                                                
             MISYU_MAEUKE.SZEI_KNGK SK,               --消費税金額                                              
             MISYU_MAEUKE.HOSEI_BUNSHI_ST_YMD HBS,    --補正期間分子開始日                                              
             MISYU_MAEUKE.HOSEI_BUNSHI_ED_YMD HBE,    --補正期間分子終了日                                              
             MISYU_MAEUKE.HOSEI_BUNBO_ST_YMD HBBS,    --補正期間分母開始日                                              
             MISYU_MAEUKE.HOSEI_BUNBO_ED_YMD HBBE,    --補正期間分母終了日                                              
             MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK HTNK,  --補正_手数料額（税抜）                                               
             MISYU_MAEUKE.HOSEI_SZEI_KNGK HSK,        --補正_消費税額                                               
             MISYU_MAEUKE.CALC_PATTERN_CD CPC,        --計算パターン                                                
             MT_TESURYO_KANRI.FEE_BUNRUI FB            --手数料分類                          
      FROM 
          
          MISYU_MAEUKE,
          
          MGR_KIHON,
          
          MGR_STS,
          
          TESURYO_KANRI,
          
          MT_TESURYO_KANRI
      WHERE 
          --未収前受収益．補正基準年月　＝　変数．基準年月 and
          MISYU_MAEUKE.HOSEI_KIJUN_YM = BaYm AND 
          --未収前受収益．委託会社コード　＝　引数．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = inItakuKaishaCd AND
          --未収前受収益．委託会社コード　＝　銘柄基本．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = MGR_KIHON.ITAKU_KAISHA_CD AND
          --未収前受収益．銘柄コード　＝　銘柄基本．銘柄コード and
          MISYU_MAEUKE.MGR_CD = MGR_KIHON.MGR_CD AND
          --銘柄基本．委託会社コード　＝　銘柄ステータス管理．委託会社コード and
          MGR_KIHON.ITAKU_KAISHA_CD = MGR_STS.ITAKU_KAISHA_CD AND
          --銘柄基本．銘柄コード　＝　銘柄ステータス管理．銘柄コード and
          MGR_KIHON.MGR_CD = MGR_STS.MGR_CD AND
          --銘柄ステータス管理．銘柄ステータス区分　＝　’1’（承認済み） and
          MGR_STS.MGR_STAT_KBN = '1' AND 
          --銘柄ステータス管理．抹消フラグ　!＝　’1’（抹消） and
          MGR_STS.MASSHO_FLG <> '1' AND
          --銘柄基本．ISINコード　IS　NOT　NULL　and
          (MGR_KIHON.ISIN_CD IS NOT NULL AND MGR_KIHON.ISIN_CD::text <> '') AND
          --未収前受収益．委託会社コード　＝　手数料管理．委託会社コード　and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = TESURYO_KANRI.ITAKU_KAISHA_CD AND
          --未収前受収益．手数料種類コード　＝　手数料管理．手数料種類コード　and
          MISYU_MAEUKE.TESU_SHURUI_CD = TESURYO_KANRI.TESU_SHURUI_CD AND
          --手数料管理MT．委託会社コード　＝　未収前受収益．委託会社コード　and
          MT_TESURYO_KANRI.ITAKU_KAISHA_CD = MISYU_MAEUKE.ITAKU_KAISHA_CD AND
          --手数料管理MT．手数料種類コード　＝　未収前受収益．手数料種類コード　and
          MT_TESURYO_KANRI.TESU_SHURUI_CD = MISYU_MAEUKE.TESU_SHURUI_CD AND
          --手数料管理MT．手数料分類　＝　'2'（無担保）　and
          MT_TESURYO_KANRI.FEE_BUNRUI = '2' AND
          --未収前受収益．未収前受区分　＝　'1'（未収）
          MISYU_MAEUKE.MISHU_MAEUKE_KBN = '1' AND
          --引数．未収手数料・無担保＝1
          inMiShuFlg = '1' 
      
UNION

      SELECT MISYU_MAEUKE.JTK_KBN MI,                 --受託区分
             '未収' MISHU,                             --'未収'                                             
             MGR_KIHON.ISIN_CD ISIN,                  --ISINコード                                              
             MISYU_MAEUKE.MGR_CD MGR,                 --銘柄コード                                              
             MGR_KIHON.MGR_RNM RNM,                   --銘柄略称                                                
             TESURYO_KANRI.TESU_SHURUI_CD SRC,        --手数料種類コード                                                
             TESURYO_KANRI.KONAI_TESU_SHURUI_NM SRN,        --手数料種類名称                                          
             MISYU_MAEUKE.KIJUN_ZNDK ZNDK,            --基準残高
             MISYU_MAEUKE.NYUKIN_YMD NYU,             --入金日                                              
             MISYU_MAEUKE.OWN_DF_BUNSHI BUNS,         --自行分配率(分子)                                                
             MISYU_MAEUKE.OWN_DF_BUNBO BUNB,          --自行分配率(分母)                                                
             MISYU_MAEUKE.TESU_RITSU_BUNSHI RS,       --手数料率分子                                                
             MISYU_MAEUKE.TESU_RITSU_BUNBO RB,        --手数料率分母                                                
             MISYU_MAEUKE.TESU_NUKI_KNGK TNK,         --手数料金額(税抜)                                                
             MISYU_MAEUKE.SZEI_KNGK SK,               --消費税金額                                              
             MISYU_MAEUKE.HOSEI_BUNSHI_ST_YMD HBS,    --補正期間分子開始日                                              
             MISYU_MAEUKE.HOSEI_BUNSHI_ED_YMD HBE,    --補正期間分子終了日                                              
             MISYU_MAEUKE.HOSEI_BUNBO_ST_YMD HBBS,    --補正期間分母開始日                                              
             MISYU_MAEUKE.HOSEI_BUNBO_ED_YMD HBBE,    --補正期間分母終了日                                              
             MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK HTNK,  --補正_手数料額（税抜）                                               
             MISYU_MAEUKE.HOSEI_SZEI_KNGK HSK,        --補正_消費税額                                               
             MISYU_MAEUKE.CALC_PATTERN_CD CPC,        --計算パターン                                                
             MT_TESURYO_KANRI.FEE_BUNRUI FB            --手数料分類                          
      FROM 
          
          MISYU_MAEUKE,
          
          MGR_KIHON,
          
          MGR_STS,
          
          TESURYO_KANRI,
          
          MT_TESURYO_KANRI
      WHERE 
          --未収前受収益．補正基準年月　＝　変数．基準年月 and
          MISYU_MAEUKE.HOSEI_KIJUN_YM = BaYm AND
          --未収前受収益．委託会社コード　＝　引数．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = inItakuKaishaCd AND
          --未収前受収益．委託会社コード　＝　銘柄基本．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = MGR_KIHON.ITAKU_KAISHA_CD AND
          --未収前受収益．銘柄コード　＝　銘柄基本．銘柄コード and
          MISYU_MAEUKE.MGR_CD = MGR_KIHON.MGR_CD AND
          --銘柄基本．委託会社コード　＝　銘柄ステータス管理．委託会社コード and
          MGR_KIHON.ITAKU_KAISHA_CD = MGR_STS.ITAKU_KAISHA_CD AND
          --銘柄基本．銘柄コード　＝　銘柄ステータス管理．銘柄コード and
          MGR_KIHON.MGR_CD = MGR_STS.MGR_CD AND
          --銘柄ステータス管理．銘柄ステータス区分　＝　’1’（承認済み） and
          MGR_STS.MGR_STAT_KBN = '1' AND 
          --銘柄ステータス管理．抹消フラグ　!＝　’1’（抹消） and
          MGR_STS.MASSHO_FLG <> '1' AND
          --銘柄基本．ISINコード　IS　NOT　NULL　and
          (MGR_KIHON.ISIN_CD IS NOT NULL AND MGR_KIHON.ISIN_CD::text <> '') AND
          --未収前受収益．委託会社コード　＝　手数料管理．委託会社コード　and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = TESURYO_KANRI.ITAKU_KAISHA_CD AND
          --未収前受収益．手数料種類コード　＝　手数料管理．手数料種類コード　and
          MISYU_MAEUKE.TESU_SHURUI_CD = TESURYO_KANRI.TESU_SHURUI_CD AND
          --手数料管理MT．委託会社コード　＝　未収前受収益．委託会社コード　and
          MT_TESURYO_KANRI.ITAKU_KAISHA_CD = MISYU_MAEUKE.ITAKU_KAISHA_CD AND
          --手数料管理MT．手数料種類コード　＝　未収前受収益．手数料種類コード　and
          MT_TESURYO_KANRI.TESU_SHURUI_CD = MISYU_MAEUKE.TESU_SHURUI_CD AND
          --手数料管理MT．手数料分類　＝　'1'（担保附）　and
          MT_TESURYO_KANRI.FEE_BUNRUI = '1' AND
          --未収前受収益．未収前受区分　＝　'1'（未収）
          MISYU_MAEUKE.MISHU_MAEUKE_KBN = '1' AND
          --引数．未収手数料・担保附＝1の場合
          inMiShuFlg1 = '1' 
      
UNION

      SELECT MISYU_MAEUKE.JTK_KBN MI,                 --受託区分
             '未経過' MISHU,                           --'未経過'
             MGR_KIHON.ISIN_CD ISIN,                  --ISINコード
             MISYU_MAEUKE.MGR_CD MGR,                 --銘柄コード
             MGR_KIHON.MGR_RNM RNM,                   --銘柄略称
             TESURYO_KANRI.TESU_SHURUI_CD SRC,        --手数料種類コード                                                
             TESURYO_KANRI.KONAI_TESU_SHURUI_NM SRN,        --手数料種類名称
             MISYU_MAEUKE.KIJUN_ZNDK ZNDK,            --基準残高
             MISYU_MAEUKE.NYUKIN_YMD NYU,             --入金日
             MISYU_MAEUKE.OWN_DF_BUNSHI BUNS,         --自行分配率(分子)
             MISYU_MAEUKE.OWN_DF_BUNBO BUNB,          --自行分配率(分母)
             MISYU_MAEUKE.TESU_RITSU_BUNSHI RS,       --手数料率分子
             MISYU_MAEUKE.TESU_RITSU_BUNBO RB,        --手数料率分母
             MISYU_MAEUKE.TESU_NUKI_KNGK TNK,         --手数料金額(税抜)
             MISYU_MAEUKE.SZEI_KNGK SK,               --消費税金額
             MISYU_MAEUKE.HOSEI_BUNSHI_ST_YMD HBS,    --補正期間分子開始日
             MISYU_MAEUKE.HOSEI_BUNSHI_ED_YMD HBE,    --補正期間分子終了日
             MISYU_MAEUKE.HOSEI_BUNBO_ST_YMD HBBS,    --補正期間分母開始日
             MISYU_MAEUKE.HOSEI_BUNBO_ED_YMD HBBE,    --補正期間分母終了日
             MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK HTNK,  --補正_手数料額（税抜）
             MISYU_MAEUKE.HOSEI_SZEI_KNGK HSK,        --補正_消費税額
             MISYU_MAEUKE.CALC_PATTERN_CD CPC,        --計算パターン
             MT_TESURYO_KANRI.FEE_BUNRUI FB            --手数料分類
      FROM
          
          MISYU_MAEUKE,
          
          MGR_KIHON,
          
          MGR_STS,
          
          TESURYO_KANRI,
          
          MT_TESURYO_KANRI
      WHERE
          --未収前受収益．補正基準年月　＝　変数．基準年月 and
          MISYU_MAEUKE.HOSEI_KIJUN_YM = BaYm AND
          --未収前受収益．委託会社コード　＝　引数．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = inItakuKaishaCd AND
          --未収前受収益．委託会社コード　＝　銘柄基本．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = MGR_KIHON.ITAKU_KAISHA_CD AND
          --未収前受収益．銘柄コード　＝　銘柄基本．銘柄コード and
          MISYU_MAEUKE.MGR_CD = MGR_KIHON.MGR_CD AND
          --銘柄基本．委託会社コード　＝　銘柄ステータス管理．委託会社コード and
          MGR_KIHON.ITAKU_KAISHA_CD = MGR_STS.ITAKU_KAISHA_CD AND
          --銘柄基本．銘柄コード　＝　銘柄ステータス管理．銘柄コード and
          MGR_KIHON.MGR_CD = MGR_STS.MGR_CD AND
          --銘柄ステータス管理．銘柄ステータス区分　＝　’1’（承認済み） and
          MGR_STS.MGR_STAT_KBN = '1' AND
          --銘柄ステータス管理．抹消フラグ　!＝　’1’（抹消） and
          MGR_STS.MASSHO_FLG <> '1' AND
          --銘柄基本．ISINコード　IS　NOT　NULL　and
          (MGR_KIHON.ISIN_CD IS NOT NULL AND MGR_KIHON.ISIN_CD::text <> '') AND
          --未収前受収益．委託会社コード　＝　手数料管理．委託会社コード　and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = TESURYO_KANRI.ITAKU_KAISHA_CD AND
          --未収前受収益．手数料種類コード　＝　手数料管理．手数料種類コード　and
          MISYU_MAEUKE.TESU_SHURUI_CD = TESURYO_KANRI.TESU_SHURUI_CD AND
          --手数料管理MT．委託会社コード　＝　未収前受収益．委託会社コード　and
          MT_TESURYO_KANRI.ITAKU_KAISHA_CD = MISYU_MAEUKE.ITAKU_KAISHA_CD AND
          --手数料管理MT．手数料種類コード　＝　未収前受収益．手数料種類コード　and
          MT_TESURYO_KANRI.TESU_SHURUI_CD = MISYU_MAEUKE.TESU_SHURUI_CD AND
          --手数料管理MT．手数料分類　＝　'2'（無担保）　and
          MT_TESURYO_KANRI.FEE_BUNRUI = '2' AND
          --未収前受収益．未収前受区分　＝　'2'（未経過）
          MISYU_MAEUKE.MISHU_MAEUKE_KBN = '2' AND
          --引数．未経過手数料・無担保＝1の場合
          inMiKeikaFlg = '1' 
      
UNION

      SELECT MISYU_MAEUKE.JTK_KBN MI,                 --受託区分
             '未経過' MISHU,                           --'未経過'
             MGR_KIHON.ISIN_CD ISIN,                  --ISINコード
             MISYU_MAEUKE.MGR_CD MGR,                 --銘柄コード 
             MGR_KIHON.MGR_RNM RNM,                   --銘柄略称
             TESURYO_KANRI.TESU_SHURUI_CD SRC,        --手数料種類コード                                                
             TESURYO_KANRI.KONAI_TESU_SHURUI_NM SRN,        --手数料種類名称
             MISYU_MAEUKE.KIJUN_ZNDK ZNDK,            --基準残高
             MISYU_MAEUKE.NYUKIN_YMD NYU,             --入金日
             MISYU_MAEUKE.OWN_DF_BUNSHI BUNS,         --自行分配率(分子)
             MISYU_MAEUKE.OWN_DF_BUNBO BUNB,          --自行分配率(分母)
             MISYU_MAEUKE.TESU_RITSU_BUNSHI RS,       --手数料率分子
             MISYU_MAEUKE.TESU_RITSU_BUNBO RB,        --手数料率分母
             MISYU_MAEUKE.TESU_NUKI_KNGK TNK,         --手数料金額(税抜)
             MISYU_MAEUKE.SZEI_KNGK SK,               --消費税金額
             MISYU_MAEUKE.HOSEI_BUNSHI_ST_YMD HBS,    --補正期間分子開始日
             MISYU_MAEUKE.HOSEI_BUNSHI_ED_YMD HBE,    --補正期間分子終了日
             MISYU_MAEUKE.HOSEI_BUNBO_ST_YMD HBBS,    --補正期間分母開始日
             MISYU_MAEUKE.HOSEI_BUNBO_ED_YMD HBBE,    --補正期間分母終了日
             MISYU_MAEUKE.HOSEI_TESU_NUKI_KNGK HTNK,  --補正_手数料額（税抜）
             MISYU_MAEUKE.HOSEI_SZEI_KNGK HSK,        --補正_消費税額
             MISYU_MAEUKE.CALC_PATTERN_CD CPC,        --計算パターン
             MT_TESURYO_KANRI.FEE_BUNRUI FB            --手数料分類
      FROM
          
          MISYU_MAEUKE,
          
          MGR_KIHON,
          
          MGR_STS,
          
          TESURYO_KANRI,
          
          MT_TESURYO_KANRI
      WHERE
          --未収前受収益．補正基準年月　＝　変数．基準年月 and
          MISYU_MAEUKE.HOSEI_KIJUN_YM = BaYm AND
          --未収前受収益．委託会社コード　＝　引数．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = inItakuKaishaCd AND
          --未収前受収益．委託会社コード　＝　銘柄基本．委託会社コード and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = MGR_KIHON.ITAKU_KAISHA_CD AND
          --未収前受収益．銘柄コード　＝　銘柄基本．銘柄コード and
          MISYU_MAEUKE.MGR_CD = MGR_KIHON.MGR_CD AND
          --銘柄基本．委託会社コード　＝　銘柄ステータス管理．委託会社コード and
          MGR_KIHON.ITAKU_KAISHA_CD = MGR_STS.ITAKU_KAISHA_CD AND
          --銘柄基本．銘柄コード　＝　銘柄ステータス管理．銘柄コード and
          MGR_KIHON.MGR_CD = MGR_STS.MGR_CD AND
          --銘柄ステータス管理．銘柄ステータス区分　＝　’1’（承認済み） and
          MGR_STS.MGR_STAT_KBN = '1' AND
          --銘柄ステータス管理．抹消フラグ　!＝　’1’（抹消） and
          MGR_STS.MASSHO_FLG <> '1' AND
          --銘柄基本．ISINコード　IS　NOT　NULL　and
          (MGR_KIHON.ISIN_CD IS NOT NULL AND MGR_KIHON.ISIN_CD::text <> '') AND
          --未収前受収益．委託会社コード　＝　手数料管理．委託会社コード　and
          MISYU_MAEUKE.ITAKU_KAISHA_CD = TESURYO_KANRI.ITAKU_KAISHA_CD AND
          --未収前受収益．手数料種類コード　＝　手数料管理．手数料種類コード　and
          MISYU_MAEUKE.TESU_SHURUI_CD = TESURYO_KANRI.TESU_SHURUI_CD AND
          --手数料管理MT．委託会社コード　＝　未収前受収益．委託会社コード　and
          MT_TESURYO_KANRI.ITAKU_KAISHA_CD = MISYU_MAEUKE.ITAKU_KAISHA_CD AND
          --手数料管理MT．手数料種類コード　＝　未収前受収益．手数料種類コード　and
          MT_TESURYO_KANRI.TESU_SHURUI_CD = MISYU_MAEUKE.TESU_SHURUI_CD AND
          --手数料管理MT．手数料分類　＝　'1'（担保附）　and
          MT_TESURYO_KANRI.FEE_BUNRUI = '1' AND
          --未収前受収益．未収前受区分　＝　'2'（未経過）
          MISYU_MAEUKE.MISHU_MAEUKE_KBN = '2' AND
          --引数．未経過手数料・担保附＝1の場合
          inMiKeikaFlg1 = '1' 
    ) alias5 
    ORDER BY
    --DECODE（未既収区分,'未収',1,2）、手数料分類（降順）、
    CASE WHEN MISHU='未収' THEN 1  ELSE 2 END ,FB DESC,
    --DECODE(受託区分,'2',2,1）、ISINコード、手数料種類コード
    CASE WHEN MI='2' THEN 2  ELSE 1 END ,ISIN,SRC;
  --==============================================================================
  --                  メイン処理                  
  --==============================================================================
BEGIN
  CALL pkLog.debug(l_inUserId,  '○' || C_PRGRAM_NAME ||'('|| C_PROCEDURE_ID||')', ' START');
--１．初期処理
 --１−１．引数（必須）データチェック
  --下記の項目は必須項目であり、ＮＵＬＬの場合、エラーにする
  IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' -- 委託会社コード
  OR coalesce(trim(both l_inUserId)::text, '') = ''         -- ユーザーID
  OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''        -- 帳票区分
  OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''       -- 業務日付
  OR coalesce(trim(both l_inBaYmd)::text, '') = ''            -- 基準年度
  OR coalesce(trim(both l_inPaCls)::text, '') = ''    THEN     -- 期別区分
     errCode := 'ECM501';
     errMsg := '入力パラメータエラー';
     RAISE EXCEPTION 'errijou' USING ERRCODE = '50001';
  END IF;
--１−２．帳票ワークの削除
  DELETE FROM SREPORT_WK
  WHERE KEY_CD = l_inItakuKaishaCd   --識別コード = 引数．委託会社コード
    AND USER_ID = l_inUserId         --ユーザID = 引数．ユーザID
    AND CHOHYO_KBN = l_inChohyoKbn   --帳票区分 = 引数．帳票区分
    AND SAKUSEI_YMD = l_inGyomuYmd   --作成年月日 = 引数．業務日付
    AND CHOHYO_ID = CHOHYOID;       --帳票ID = 固定値．帳票ID
--１−３．変数．基準年月設定
 --１−３−１．引数．期別区分＝「1」（第１四半期）の場合
 IF l_inPaCls = '1' THEN
  --変数．基準年月　：＝　引数．基準年度　||　'06'
  gBaYm := l_inBaYmd || '06';
  gPlaCls := '第１四半期';
 END IF;
 --１−３−２．引数．期別区分＝「2」（第２四半期）または「5」（上半期）の場合
 IF l_inPaCls = '2' OR l_inPaCls = '5' THEN
  --変数．基準年月　：＝　引数．基準年度　||　'09'
  gBaYm := l_inBaYmd || '09';
  IF l_inPaCls = '2' THEN
  gPlaCls := '第２四半期';
  ELSE gPlaCls := '上半期';
  END IF;
 END IF;
 --１−３−３．引数．期別区分＝「3」（第３四半期）の場合
 IF l_inPaCls = '3' THEN
  --変数．基準年月　：＝　引数．基準年度　||　'12'
  gBaYm := l_inBaYmd || '12';
  gPlaCls := '第３四半期';
 END IF;
 --１−３−４．引数．期別区分＝「4：第４四半期」または「6：下半期」の場合
 IF l_inPaCls = '4' OR l_inPaCls = '6' THEN
  --変数．基準年月　：＝　引数．基準年度　+　1　||　'03'
  gBaYm := pkcharacter.numeric_to_char(l_inBaYmd::integer + 1) || '03';
  IF l_inPaCls = '4' THEN
  gPlaCls := '第４四半期';
  ELSE gPlaCls := '下半期';
  END IF;
 END IF;
--１−４．引数担保区分判定
 --１−４−１．引数．未収手数料・無担保、引数．未収手数料・担保附、引数．未経過手数料・無担保、引数．未経過手数料・担保附いずれも"0"（チェックOFF）の場合
 IF l_inMiShuFlg <> '0' OR l_inMiShuFlg1 <> '0' OR l_inMiKeikaFlg <> '0' OR l_inMiKeikaFlg1 <> '0' THEN
--２．ヘッダーレコード出力
 --pkPrint.insertHeader(引数．委託会社コード, 引数．ユーザID, 引数．帳票区分, 引数．業務日付, 固定値．帳票ID);
 CALL pkPrint.insertHeader(l_inItakuKaishaCd,l_inUserId,l_inChohyoKbn,l_inGyomuYmd,CHOHYOID);
--３．未収前受収益計算処理実行
 --pkIpaKessanHosei.calcHosei（引数．委託会社コード,変数．基準年月,'1',引数．ユーザーID）；
 gRet :=pkIpaKessanHosei.calcHosei(l_inItakuKaishaCd,gBaYm,'1',l_inUserId);
 IF gRet <> 0 THEN
   l_outSqlCode := gRet;
   RETURN;
 END IF;
--４．帳票ワークテーブルへ出力
 FOR reMeisai IN curMeisai(gBaYm,l_inItakuKaishaCd,l_inMiShuFlg,l_inMiShuFlg1,l_inMiKeikaFlg,l_inMiKeikaFlg1) LOOP
 --４−１−１．件数カウントアップ
  --変数．件数　：＝　変数．件数　+　1；
   gCount := gCount + 1;
 --４−１−２．手数料率設定
  --変数．手数料率　：＝　TRUNC(明細データ抽出．手数料率分子/明細データ抽出．手数料率分母,4）;
  IF reMeisai.RB <> 0 THEN
  gTesu := TRUNC(reMeisai.RS/reMeisai.RB * 10000::numeric, 4);
  END IF;
 --４−１−３．未既収日数取得
 IF (trim(both reMeisai.HBS) IS NOT NULL AND (trim(both reMeisai.HBS))::text <> '') AND (trim(both reMeisai.HBE) IS NOT NULL AND (trim(both reMeisai.HBE))::text <> '') THEN
  --変数．未既収日数　：＝　PKDATE.calcNissuRyoha（明細データ抽出．補正期間分子開始日,明細データ抽出．補正期間分子終了日）;
  gDateCnt := PKDATE.calcNissuRyoha(reMeisai.HBS,reMeisai.HBE);
 ELSE gDateCnt := 0;
 END IF;
 --４−１−４．期間日数取得
 IF (trim(both reMeisai.HBBS) IS NOT NULL AND (trim(both reMeisai.HBBS))::text <> '') AND (trim(both reMeisai.HBBE) IS NOT NULL AND (trim(both reMeisai.HBBE))::text <> '') THEN
  --変数．期間日数　：＝　PKDATE.calcNissuRyoha（明細データ抽出．補正期間分母開始日,明細データ抽出．補正期間分母終了日）;
  gBiCnt := PKDATE.calcNissuRyoha(reMeisai.HBBS,reMeisai.HBBE);
 ELSE gBiCnt := 0;
 END IF;
 --タイトル　分類
  --1．「未収・未経過」項目が「未収」の場合
  IF reMeisai.MISHU = '未収' THEN
   --　1-1．「手数料分類」が「1：担保附社債」の場合
   IF reMeisai.FB = '1' THEN
    --1-1-1．「受託区分」が「2：副受託」以外の場合
    IF reMeisai.MI <> '2' THEN
     --「担保附社債信託料に係る未収手数料（代表受託区分）」
     gTitleCls :='担保附社債信託料に係る未収手数料（代表受託分）';
    ELSE
     --「担保附社債信託料に係る未収手数料（副受託分）」
     gTitleCls :='担保附社債信託料に係る未収手数料（副受託分）';
    END IF;
   END IF;
   --1-2．「手数料分類」が「2：無担保社債」の場合
   IF reMeisai.FB = '2' THEN
    --1-2-1．「受託区分」が「2：副受託」以外の場合
    IF reMeisai.MI <> '2' THEN
     --「受入手数料（証券）に係る未収手数料（代表受託区分）」
     gTitleCls :='受入手数料（証券）に係る未収手数料（代表受託分）';
    ELSE
     --「受入手数料（証券）に係る未収手数料（副受託分）」
     gTitleCls :='受入手数料（証券）に係る未収手数料（副受託分）';
    END IF;
   END IF;
  END IF;
  --2．「未収・未経過」項目が「未経過」の場合
  IF reMeisai.MISHU = '未経過' THEN
   --　2-1．「手数料分類」が「1：担保附社債」の場合
   IF reMeisai.FB = '1' THEN
    --2-1-1．「受託区分」が「2：副受託」以外の場合
    IF reMeisai.MI <> '2' THEN
     --「担保附社債信託料に係る未経過手数料（代表受託区分）」
     gTitleCls :='担保附社債信託料に係る未経過手数料（代表受託分）';
    ELSE
     --「担保附社債信託料に係る未経過手数料（副受託分）」
     gTitleCls :='担保附社債信託料に係る未経過手数料（副受託分）';
    END IF;
   END IF;
   --2-2．「手数料分類」が「2：無担保社債」の場合
   IF reMeisai.FB = '2' THEN
    --2-2-1．「受託区分」が「2：副受託」以外の場合
    IF reMeisai.MI <> '2' THEN
     --「受入手数料（証券）に係る未経過手数料（代表受託区分）」
     gTitleCls :='受入手数料（証券）に係る未経過手数料（代表受託分）';
    ELSE
     --「受入手数料（証券）に係る未経過手数料（副受託分）」
     gTitleCls :='受入手数料（証券）に係る未経過手数料（副受託分）';
    END IF;
   END IF;
  END IF;
 --４−１−５．レコードのINSERT処理を行う
  		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inBaYmd;	-- 引数．基準年度
		v_item.l_inItem002 := gPlaCls;	-- 期別
		v_item.l_inItem003 := reMeisai.FB;	-- 明細データ抽出．手数料分類
		v_item.l_inItem004 := reMeisai.MISHU;	-- 明細データ抽出．未既収区分
		v_item.l_inItem005 := reMeisai.ISIN;	-- 明細データ抽出．ISINコード
		v_item.l_inItem006 := reMeisai.MGR;	-- 明細データ抽出．銘柄コード
		v_item.l_inItem007 := reMeisai.RNM;	-- 明細データ抽出．銘柄略称
		v_item.l_inItem008 := reMeisai.ZNDK;	-- 明細データ抽出．基準残高
		v_item.l_inItem009 := gTesu;	-- 変数．手数料率
		v_item.l_inItem010 := reMeisai.SRN;	-- 明細データ抽出．手数料種類名称
		v_item.l_inItem011 := reMeisai.NYU;	-- 明細データ抽出．入金日
		v_item.l_inItem012 := reMeisai.MI;	-- 明細データ抽出．受託区分
		v_item.l_inItem013 := reMeisai.HBBS;	-- 明細データ抽出．補正期間分母開始日
		v_item.l_inItem014 := reMeisai.HBBE;	-- 明細データ抽出．補正期間分母終了日
		v_item.l_inItem015 := gDateCnt;	-- 変数．未既収日数
		v_item.l_inItem016 := gBiCnt;	-- 変数．期間日数
		v_item.l_inItem017 := reMeisai.BUNS;	-- 明細データ抽出．自行分配率(分子)
		v_item.l_inItem018 := reMeisai.BUNB;	-- 明細データ抽出．自行分配率(分母)
		v_item.l_inItem019 := reMeisai.HTNK;	-- 明細データ抽出．補正_手数料額（税抜)
		v_item.l_inItem020 := reMeisai.HSK;	-- 明細データ抽出．補正_消費税額
		v_item.l_inItem021 := CHOHYOID;	-- 固定値．帳票ID
		v_item.l_inItem022 := reMeisai.CPC;	-- 明細データ抽出．計算パターン
		v_item.l_inItem023 := gTitleCls;	-- タイトル　分類
		v_item.l_inItem024 := l_inUserId;	-- ユーザＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> CHOHYOID,
			l_inSeqNo		=> gCount,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
  END LOOP;
 ELSE
  CALL pkPrint.insertHeader(l_inItakuKaishaCd,l_inUserId,l_inChohyoKbn,l_inGyomuYmd,CHOHYOID);
 END IF;
 --４−２．変数．件数が「0」の場合（対象データがない場合）
 IF gCount = 0 THEN
  		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem004 := '未収';	-- 未収
		v_item.l_inItem021 := CHOHYOID;	-- 固定値．帳票ID
		v_item.l_inItem023 := '対象データなし';	-- 対象データなし
		v_item.l_inItem024 := l_inUserId;	-- ユーザＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> CHOHYOID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
  --４−２−１．リターン値＝2：対象データなしを戻す。
  l_outSqlCode := 2;
  l_outSqlErrM := '対象データなし';
 ELSE
  --リターン値＝0：正常終了を戻す。
  l_outSqlCode := gRtnCd;
  l_outSqlErrM := '';
 END IF;
 --処理終了
 CALL pkLog.debug(l_inUserId,  '○' || C_PRGRAM_NAME ||'('|| C_PROCEDURE_ID||')', ' END');
-- 例外処理
EXCEPTION
    WHEN SQLSTATE '50002' THEN
        --COMMIT;
        CALL pkLog.debug(l_inUserId, '△' || C_PRGRAM_NAME ||'('|| C_PROCEDURE_ID||')', 'warnGyom');
        l_outSqlCode    := gRtnCd;
        l_outSqlErrM    := '';
    WHEN SQLSTATE '50001' THEN
        --ROLLBACK;
        CALL pkLog.debug(l_inUserId, '×' || C_PRGRAM_NAME ||'('|| C_PROCEDURE_ID||')', 'errIjou');
        CALL pklog.error(errCode, C_PROCEDURE_ID, errMsg);
        l_outSqlCode    := pkconstant.error();
        l_outSqlErrM    := '';
    WHEN OTHERS THEN
        --ROLLBACK;
        CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'SQLCODE:' || SQLSTATE);
        CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'SQLERRM:' || SQLERRM);
        l_outSqlCode := pkconstant.fatal();
        l_outSqlErrM := SQLERRM;
        CALL pkLog.debug(l_inUserId, CHOHYOID, '×' || C_PROCEDURE_ID || ' END（例外発生）');
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi003k14r01 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_inBaYmd text, l_inPaCls text, l_inMiShuFlg text, l_inMiShuFlg1 text, l_inMiKeikaFlg text, l_inMiKeikaFlg1 text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;