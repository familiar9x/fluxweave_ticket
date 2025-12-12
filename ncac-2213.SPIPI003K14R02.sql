


DROP TYPE IF EXISTS SPIPI003K14R02_typeDeSuRoList;
CREATE TYPE SPIPI003K14R02_typeDeSuRoList AS (item char(2));


CREATE OR REPLACE PROCEDURE spipi003k14r02 ( l_inItakuKaishaCd text,    -- 委託会社コード
 l_inUserId text,    -- ユーザーID
 l_inChohyoKbn text,    -- 帳票区分
 l_inGyomuYmd text,    -- 業務日付
 l_inBaYmFrom text,    --基準年月FROM
 l_inBaYmTo text,    --基準年月TO
 l_inEiGyouTenCd text,    --営業店コード
 l_outSqlCode OUT integer,     -- リターン値
 l_outSqlErrM OUT text    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:指定された期間の発行時手数料、期中手数料を集計し「収益予想表」に出力する。
-- *       
-- *
-- * 引数　:l_inItakuKaishaCd IN VARCHAR,     委託会社コード
-- *       l_inUserId           IN VARCHAR,     ユーザーID
-- *       l_inChohyoKbn        IN VARCHAR,   帳票区分
-- *       l_inGyomuYmd         IN VARCHAR,     業務日付
-- *       l_inBaYmFrom      IN VARCHAR,    基準年月FROM
-- *       l_inBaYmTo        IN VARCHAR,      基準年月TO
-- *       l_inEiGyouTenCd   IN VARCHAR,    営業店コード
-- *       l_outSqlCode         OUT NUMERIC,          リターン値
-- *       l_outSqlErrM         OUT VARCHAR     エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author 陳威宇
-- * @version $Id: SPIPI003K14R02.sql,v 1.4 2013/07/08 09:22:30 nakamura Exp $
-- *
-- 
    --==============================================================================
    --          定数定義                                                            
    --==============================================================================
  C_PROCEDURE_ID      CONSTANT varchar(20) := 'SPIPI003K14R02';      -- プロシージャＩＤ
  C_PRGRAM_NAME       CONSTANT varchar(30) := '収益予想表';           -- プロシージャ名
  CHOHYOID            CONSTANT varchar(20) := 'IPQ30000321';         --固有の帳票ID
  
  --==============================================================================
    --      変数定義                               
    --==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
  gRtnCd               numeric := pkconstant.success();            -- リターンコード
  gBaYmFrom             varchar(8) := NULL;                    --変数．基準年月日From
  gBaYmTo               varchar(8) := NULL;                    --変数．基準年月日To
  gDeSuRoList CONSTANT char(2)[] := ARRAY['02','03','04']; --配列．発行時手数料
  gCaseCnt              numeric := 0;                                 --変数．件数
  gJudaKu               varchar(8) := NULL;                    --変数．受託
  gSQL                  varchar(10000) := NULL;                -- SQL編集
  gDeSuRo               char(2);
  gCNT                  numeric := 0;                                 --受託銀行取得．カウント
  curMeisai refcursor;                                             -- 明細ダデータカーソル
  gItakuKaishaCd        MGR_STS.ITAKU_KAISHA_CD%TYPE;                --委託会社コード
  gMgrCd                MGR_STS.MGR_CD%TYPE;                         --銘柄コード
  gShinuYmd             MGR_KIHON.SKN_KOFU_YMD%TYPE;                 --徴求日
  gRet                  numeric := 0;                            -- リターン値
  --エラー処理用 
  
  errMsg               varchar(300);
  errCode              varchar(6);
    --==============================================================================
    --                  カーソル定義                
    --==============================================================================
  curKiqu CURSOR(
    inItakuKaishaCd MGR_STS.ITAKU_KAISHA_CD%TYPE,      --引数．委託会社コード
    BaYmFrom  MGR_TESKIJ.CHOKYU_YMD%TYPE,              --変数．基準年月日FROM
    gBaYmTo    MGR_TESKIJ.CHOKYU_YMD%TYPE,             --変数．基準年月日TO
    inEiGyouTenCd MHAKKOTAI.EIGYOTEN_CD%TYPE            --引数．営業店コード
  )
  FOR
  SELECT
    MG4.ITAKU_KAISHA_CD,      --委託会社コード
    MG4.MGR_CD,               --銘柄コード
    MG4.TESU_SHURUI_CD,       --手数料種類コード
    MG4.CHOKYU_YMD             --徴求日
  FROM
    MGR_STS MG0,
    MGR_KIHON MG1,
    MGR_TESKIJ MG4,
    MHAKKOTAI M01
  WHERE
    --銘柄ステータス管理．委託会社コード　＝　引数．委託会社コード and
    MG0.ITAKU_KAISHA_CD = inItakuKaishaCd
    --銘柄手数料回次．徴求日　BETWEEN　変数．基準年月日FROM　and　変数．基準年月日TO　and
    AND MG4.CHOKYU_YMD BETWEEN BaYmFrom AND gBaYmTo
    --銘柄手数料回次．手数料種類コード　IN　（'11','12','21','22','41','52','91'）　and
    AND MG4.TESU_SHURUI_CD IN ('11','12','21','22','41','52','91')
    --銘柄ステータス管理．銘柄ステータス区分　＝　'1' and
    AND MG0.MGR_STAT_KBN = '1'
    --銘柄ステータス管理．抹消フラグ　＝　'0' and
    AND MG0.MASSHO_FLG = '0'
    --TRIM（銘柄基本．ISINコード）　IS　NOT　NULL　　and
    AND (trim(both MG1.ISIN_CD) IS NOT NULL AND (trim(both MG1.ISIN_CD))::text <> '')
    --銘柄手数料回次．委託会社コード　＝　銘柄ステータス管理．委託会社コード　and
    AND MG4.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
    --銘柄手数料回次．銘柄コード　＝銘柄ステータス管理．銘柄コード　and
    AND MG4.MGR_CD = MG0.MGR_CD
    --銘柄基本．委託会社コード　＝　銘柄ステータス管理．委託会社コード　and
    AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
    --銘柄基本．銘柄コード　＝　銘柄ステータス管理．銘柄コード　and
    AND MG1.MGR_CD = MG0.MGR_CD
    --銘柄基本．委託会社コード　＝　発行体マスタ．委託会社コード　and
    AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
    --銘柄基本．発行体コード　＝　発行体マスタ．発行体コード　and
    AND MG1.HKT_CD = M01.HKT_CD
    --引数の営業店コードがNOT　NULLの場合以下を設定
    --発行体マスタ．営業店コード　＝　引数．営業店コード　and
    AND M01.EIGYOTEN_CD = (CASE  WHEN (inEiGyouTenCd IS NOT NULL AND inEiGyouTenCd::text <> '') THEN inEiGyouTenCd ELSE M01.EIGYOTEN_CD END)
    AND PKIPACALCTESURYO.checkHeizonMgr(
                              MG4.ITAKU_KAISHA_CD
                            , MG4.MGR_CD
                            , PKDATE.GETZENGETSUMATSUBUSINESSYMD(MG4.CHOKYU_KJT)
                            , '1') = 0;
  --明細データ抽出 
  curMeisai1 CURSOR(
        inItakuKaishaCd TESURYO.ITAKU_KAISHA_CD%TYPE,-- 委託会社コード
        inBaYmFrom TESURYO.CHOKYU_YMD%TYPE,--基準年月FROM
        inBaYmTo TESURYO.CHOKYU_YMD%TYPE,   --基準年月TO
        inEiGyouTenCd MHAKKOTAI.EIGYOTEN_CD%TYPE            --引数．営業店コード
  ) FOR
SELECT
    MGR.ITAKU_KAISHA_CD ITCD,    --委託会社コード
    MGR.MGR_CD MGR,             --銘柄コード
    MGR.ISIN_CD ISIN,            --ISINコード
    MGR.MGR_RNM RNM,            --銘柄略称
    MGR.TANPO_KBN TANPO,          --担保区分
    MGR.BUTEN_CD TENCD,          --部店コード
    MGR.BUTEN_RNM TENRNM,         --部店略称
    MGR.JTK_KBN JTKKBN,            --受託区分
    SCODE.CODE_RNM CODENM,         --受託区分略称
    THFT.KNGK THFTGK,              --担保附当初金額
    THFKY.KNGK FKYGK,             --担保附期中金額
    THNS.KNGK NSGK,              --無担保当初金額
    THKY.KNGK KYGK,              --無担保期中金額
    SNT.KNGK  SNTGK                --その他金額
  FROM scode, (SELECT MG1.ITAKU_KAISHA_CD,
            MG1.MGR_CD,
            MG1.ISIN_CD,
            MG1.MGR_RNM,
            MG1.TANPO_KBN,
            MG1.JTK_KBN,
            M04.BUTEN_CD,
            M04.BUTEN_RNM
       FROM MGR_KIHON MG1,
            TESURYO T01,
            MGR_STS MG0,
            MBUTEN M04,
            MHAKKOTAI M01,
            MT_TESURYO_KANRI MT05
      WHERE MG1.ITAKU_KAISHA_CD = inItakuKaishaCd
        AND MG1.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
        AND MG1.MGR_CD = T01.MGR_CD
        AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
        AND MG1.MGR_CD = MG0.MGR_CD 
        AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
        AND MG1.HKT_CD = M01.HKT_CD
        AND M01.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD
        AND M01.EIGYOTEN_CD = M04.BUTEN_CD
	    AND T01.ITAKU_KAISHA_CD = MT05.ITAKU_KAISHA_CD
	    AND T01.TESU_SHURUI_CD = MT05.TESU_SHURUI_CD
	    AND MT05.FEE_BUNRUI IN ('1','2','3')
        AND T01.CHOKYU_YMD BETWEEN inBaYmFrom AND inBaYmTo
        AND T01.TSUKA_CD = 'JPY'
        AND MG0.SHORI_KBN = '1'
        AND MG0.MASSHO_FLG = '0' 
       )mgr
LEFT OUTER JOIN (SELECT
     T01.ITAKU_KAISHA_CD ITKCD       --手数料計算結果．委託会社コード
    ,T01.MGR_CD MGR                  --手数料計算結果．銘柄コード
    ,T01.EIGYOTEN_CD EGCD            --手数料計算結果．営業店コード
    ,T01.JTK_KBN JTK                 --手数料計算結果．受託区分
    ,MT05.FEE_BUNRUI FEE             --手数料管理．手数料分類
    ,SUM(T01.OWN_TESU_KNGK + 
     CASE WHEN T01.DATA_SAKUSEI_KBN || T01.SHORI_KBN='21' THEN T01.HOSEI_OWN_TESU_KNGK  ELSE 0 END ) KNGK --金額
  FROM
     TESURYO T01
     ,MT_TESURYO_KANRI MT05
     ,MGR_STS MG0
  WHERE
    --手数料計算結果．委託会社コード　＝　手数料管理．委託会社コード　AND
    T01.ITAKU_KAISHA_CD = MT05.ITAKU_KAISHA_CD
    --手数料計算結果．手数料種類コード　＝　手数料管理．手数料種類コード　AND
    AND T01.TESU_SHURUI_CD = MT05.TESU_SHURUI_CD
    --手数料計算結果．委託会社コード　＝　銘柄ステータス管理．委託会社コード　AND
    AND T01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
    --手数料計算結果．銘柄コード　＝　銘柄ステータス管理．銘柄コード　AND
    AND T01.MGR_CD = MG0.MGR_CD
    --手数料計算結果．委託会社コード　＝　C引数．委託会社コード　AND
    AND T01.ITAKU_KAISHA_CD = inItakuKaishaCd
    --手数料計算結果．徴求日　BETWEEN　C引数．基準年月日FROM　AND　C引数．基準年月日TO　AND
    AND T01.CHOKYU_YMD BETWEEN inBaYmFrom AND  inBaYmTo
    --手数料計算結果．通貨コード　＝　'JPY'　AND
    AND T01.TSUKA_CD = 'JPY'
    --手数料管理．手数料分類　＝　'1'　--　担保附　AND
    AND MT05.FEE_BUNRUI = '1'
    --手数料管理．発行・期中フラグ　＝　'1'　--　発行　AND
    AND MT05.HAKKO_KICHU_FLG = '1'
    --銘柄ステータス管理．処理区分　＝　'1'　--　承認　AND
    AND MG0.SHORI_KBN = '1'
    --銘柄ステータス管理．抹消フラグ　＝　'0'　--　非抹消済　AND
    AND MG0.MASSHO_FLG = '0'
    --C引数．営業店コードに値が設定されていた場合
    --手数料計算結果．営業店コード　＝　C引数．営業店コード　AND
    AND T01.EIGYOTEN_CD = (CASE WHEN (inEiGyouTenCd IS NOT NULL AND inEiGyouTenCd::text <> '') THEN inEiGyouTenCd ELSE T01.EIGYOTEN_CD END) 
    GROUP BY
	    T01.ITAKU_KAISHA_CD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD               --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD           --手数料計算結果．営業店コード
	    ,T01.JTK_KBN               --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI           --手数料管理．手数料分類
    ) thft ON (MGR.ITAKU_KAISHA_CD = THFT.ITKCD AND MGR.MGR_CD = THFT.MGR)
LEFT OUTER JOIN (SELECT
	     T01.ITAKU_KAISHA_CD ITKCD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD MGR                  --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD EGCD            --手数料計算結果．営業店コード
	    ,T01.JTK_KBN JTK                 --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI FEE             --手数料管理．手数料分類
	    ,SUM(T01.OWN_TESU_KNGK + 
	     CASE WHEN T01.DATA_SAKUSEI_KBN || T01.SHORI_KBN='21' THEN T01.HOSEI_OWN_TESU_KNGK  ELSE 0 END ) KNGK --金額
     FROM
	  TESURYO T01
	  ,MT_TESURYO_KANRI MT05
	  ,MGR_STS MG0
     WHERE
	    --手数料計算結果．委託会社コード　＝　手数料管理．委託会社コード　AND
	    T01.ITAKU_KAISHA_CD = MT05.ITAKU_KAISHA_CD
	    --手数料計算結果．手数料種類コード　＝　手数料管理．手数料種類コード　AND
	    AND T01.TESU_SHURUI_CD = MT05.TESU_SHURUI_CD
	    --手数料計算結果．委託会社コード　＝　銘柄ステータス管理．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	    --手数料計算結果．銘柄コード　＝　銘柄ステータス管理．銘柄コード　AND
	    AND T01.MGR_CD = MG0.MGR_CD
	    --手数料計算結果．委託会社コード　＝　C引数．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = inItakuKaishaCd
	    --手数料計算結果．徴求日　BETWEEN　C引数．基準年月日FROM　AND　C引数．基準年月日TO　AND
	    AND T01.CHOKYU_YMD BETWEEN inBaYmFrom AND  inBaYmTo
	    --手数料計算結果．通貨コード　＝　'JPY'　AND
	    AND T01.TSUKA_CD = 'JPY'
	    --手数料管理．手数料分類　＝　'1'　--　担保附　AND
	    AND MT05.FEE_BUNRUI = '1'
	    --手数料管理．発行・期中フラグ　＝　'2'　--　期中　AND
	    AND MT05.HAKKO_KICHU_FLG = '2'
	    --銘柄ステータス管理．処理区分　＝　'1'　--　承認　AND
	    AND MG0.SHORI_KBN = '1'
	    --銘柄ステータス管理．抹消フラグ　＝　'0'　--　非抹消済　AND
	    AND MG0.MASSHO_FLG = '0'
	    --C引数．営業店コードに値が設定されていた場合
	    --手数料計算結果．営業店コード　＝　C引数．営業店コード　AND
	    AND T01.EIGYOTEN_CD = (CASE WHEN (inEiGyouTenCd IS NOT NULL AND inEiGyouTenCd::text <> '') THEN inEiGyouTenCd ELSE T01.EIGYOTEN_CD END) 
    GROUP BY
	    T01.ITAKU_KAISHA_CD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD               --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD           --手数料計算結果．営業店コード
	    ,T01.JTK_KBN               --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI           --手数料管理．手数料分類
    ) thfky ON (MGR.ITAKU_KAISHA_CD = THFKY.ITKCD AND MGR.MGR_CD = THFKY.MGR)
LEFT OUTER JOIN (SELECT
	     T01.ITAKU_KAISHA_CD ITKCD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD MGR                  --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD EGCD            --手数料計算結果．営業店コード
	    ,T01.JTK_KBN JTK                 --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI FEE             --手数料管理．手数料分類
	    ,SUM(T01.OWN_TESU_KNGK + 
	     CASE WHEN T01.DATA_SAKUSEI_KBN || T01.SHORI_KBN='21' THEN T01.HOSEI_OWN_TESU_KNGK  ELSE 0 END ) KNGK --金額
     FROM
	  TESURYO T01
	  ,MT_TESURYO_KANRI MT05
	  ,MGR_STS MG0
     WHERE
	    --手数料計算結果．委託会社コード　＝　手数料管理．委託会社コード　AND
	    T01.ITAKU_KAISHA_CD = MT05.ITAKU_KAISHA_CD
	    --手数料計算結果．手数料種類コード　＝　手数料管理．手数料種類コード　AND
	    AND T01.TESU_SHURUI_CD = MT05.TESU_SHURUI_CD
	    --手数料計算結果．委託会社コード　＝　銘柄ステータス管理．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	    --手数料計算結果．銘柄コード　＝　銘柄ステータス管理．銘柄コード　AND
	    AND T01.MGR_CD = MG0.MGR_CD
	    --手数料計算結果．委託会社コード　＝　C引数．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = inItakuKaishaCd
	    --手数料計算結果．徴求日　BETWEEN　C引数．基準年月日FROM　AND　C引数．基準年月日TO　AND
	    AND T01.CHOKYU_YMD BETWEEN inBaYmFrom AND  inBaYmTo
	    --手数料計算結果．通貨コード　＝　'JPY'　AND
	    AND T01.TSUKA_CD = 'JPY'
	    --手数料管理．手数料分類　＝　'2'　--　無担保　AND
	    AND MT05.FEE_BUNRUI = '2'
	    --手数料管理．発行・期中フラグ　＝　'1'　--　発行　AND
	    AND MT05.HAKKO_KICHU_FLG = '1'
	    --銘柄ステータス管理．処理区分　＝　'1'　--　承認　AND
	    AND MG0.SHORI_KBN = '1'
	    --銘柄ステータス管理．抹消フラグ　＝　'0'　--　非抹消済　AND
	    AND MG0.MASSHO_FLG = '0'
	    --C引数．営業店コードに値が設定されていた場合
	    --手数料計算結果．営業店コード　＝　C引数．営業店コード　AND
	    AND T01.EIGYOTEN_CD = (CASE WHEN (inEiGyouTenCd IS NOT NULL AND inEiGyouTenCd::text <> '') THEN inEiGyouTenCd ELSE T01.EIGYOTEN_CD END) 
    GROUP BY
	    T01.ITAKU_KAISHA_CD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD               --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD           --手数料計算結果．営業店コード
	    ,T01.JTK_KBN               --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI           --手数料管理．手数料分類
    ) thns ON (MGR.ITAKU_KAISHA_CD = THNS.ITKCD AND MGR.MGR_CD = THNS.MGR)
LEFT OUTER JOIN (SELECT
	     T01.ITAKU_KAISHA_CD ITKCD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD MGR                  --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD EGCD            --手数料計算結果．営業店コード
	    ,T01.JTK_KBN JTK                 --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI FEE             --手数料管理．手数料分類
	    ,SUM(T01.OWN_TESU_KNGK + 
	     CASE WHEN T01.DATA_SAKUSEI_KBN || T01.SHORI_KBN='21' THEN T01.HOSEI_OWN_TESU_KNGK  ELSE 0 END ) KNGK --金額
     FROM
	  TESURYO T01
	  ,MT_TESURYO_KANRI MT05
	  ,MGR_STS MG0
     WHERE
	    --手数料計算結果．委託会社コード　＝　手数料管理．委託会社コード　AND
	    T01.ITAKU_KAISHA_CD = MT05.ITAKU_KAISHA_CD
	    --手数料計算結果．手数料種類コード　＝　手数料管理．手数料種類コード　AND
	    AND T01.TESU_SHURUI_CD = MT05.TESU_SHURUI_CD
	    --手数料計算結果．委託会社コード　＝　銘柄ステータス管理．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	    --手数料計算結果．銘柄コード　＝　銘柄ステータス管理．銘柄コード　AND
	    AND T01.MGR_CD = MG0.MGR_CD
	    --手数料計算結果．委託会社コード　＝　C引数．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = inItakuKaishaCd
	    --手数料計算結果．徴求日　BETWEEN　C引数．基準年月日FROM　AND　C引数．基準年月日TO　AND
	    AND T01.CHOKYU_YMD BETWEEN inBaYmFrom AND  inBaYmTo
	    --手数料計算結果．通貨コード　＝　'JPY'　AND
	    AND T01.TSUKA_CD = 'JPY'
	    --手数料管理．手数料分類　＝　'2'　--　無担保　AND
	    AND MT05.FEE_BUNRUI = '2'
	    --手数料管理．発行・期中フラグ　＝　'2'　--　期中　AND
	    AND MT05.HAKKO_KICHU_FLG = '2'
	    --銘柄ステータス管理．処理区分　＝　'1'　--　承認　AND
	    AND MG0.SHORI_KBN = '1'
	    --銘柄ステータス管理．抹消フラグ　＝　'0'　--　非抹消済　AND
	    AND MG0.MASSHO_FLG = '0'
	    --C引数．営業店コードに値が設定されていた場合
	    --手数料計算結果．営業店コード　＝　C引数．営業店コード　AND
	    AND T01.EIGYOTEN_CD = (CASE WHEN (inEiGyouTenCd IS NOT NULL AND inEiGyouTenCd::text <> '') THEN inEiGyouTenCd ELSE T01.EIGYOTEN_CD END) 
    GROUP BY
	    T01.ITAKU_KAISHA_CD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD               --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD           --手数料計算結果．営業店コード
	    ,T01.JTK_KBN               --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI           --手数料管理．手数料分類
    ) thky ON (MGR.ITAKU_KAISHA_CD = THKY.ITKCD AND MGR.MGR_CD = THKY.MGR)
LEFT OUTER JOIN (SELECT
	     T01.ITAKU_KAISHA_CD ITKCD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD MGR                  --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD EGCD            --手数料計算結果．営業店コード
	    ,T01.JTK_KBN JTK                 --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI FEE             --手数料管理．手数料分類
	    ,SUM(T01.OWN_TESU_KNGK + 
	     CASE WHEN T01.DATA_SAKUSEI_KBN || T01.SHORI_KBN='21' THEN T01.HOSEI_OWN_TESU_KNGK  ELSE 0 END ) KNGK --金額
     FROM
		  TESURYO T01
		  ,MT_TESURYO_KANRI MT05
		  ,MGR_STS MG0
     WHERE
	    --手数料計算結果．委託会社コード　＝　手数料管理．委託会社コード　AND
	    T01.ITAKU_KAISHA_CD = MT05.ITAKU_KAISHA_CD
	    --手数料計算結果．手数料種類コード　＝　手数料管理．手数料種類コード　AND
	    AND T01.TESU_SHURUI_CD = MT05.TESU_SHURUI_CD
	    --手数料計算結果．委託会社コード　＝　銘柄ステータス管理．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	    --手数料計算結果．銘柄コード　＝　銘柄ステータス管理．銘柄コード　AND
	    AND T01.MGR_CD = MG0.MGR_CD
	    --手数料計算結果．委託会社コード　＝　C引数．委託会社コード　AND
	    AND T01.ITAKU_KAISHA_CD = inItakuKaishaCd
	    --手数料計算結果．徴求日　BETWEEN　C引数．基準年月日FROM　AND　C引数．基準年月日TO　AND
	    AND T01.CHOKYU_YMD BETWEEN inBaYmFrom AND  inBaYmTo
	    --手数料計算結果．通貨コード　＝　'JPY'　AND
	    AND T01.TSUKA_CD = 'JPY'
	    --手数料管理．手数料分類　＝　'3'　--　その他　AND
	    AND MT05.FEE_BUNRUI = '3'
	    --手数料管理．発行・期中フラグ　＝　'2'　--　期中　AND
	    AND MT05.HAKKO_KICHU_FLG = '2'
	    --銘柄ステータス管理．処理区分　＝　'1'　--　承認　AND
	    AND MG0.SHORI_KBN = '1'
	    --銘柄ステータス管理．抹消フラグ　＝　'0'　--　非抹消済　AND
	    AND MG0.MASSHO_FLG = '0'
	    --C引数．営業店コードに値が設定されていた場合
	    --手数料計算結果．営業店コード　＝　C引数．営業店コード　AND
	    AND T01.EIGYOTEN_CD = (CASE WHEN (inEiGyouTenCd IS NOT NULL AND inEiGyouTenCd::text <> '') THEN inEiGyouTenCd ELSE T01.EIGYOTEN_CD END) 
    GROUP BY
	    T01.ITAKU_KAISHA_CD       --手数料計算結果．委託会社コード
	    ,T01.MGR_CD               --手数料計算結果．銘柄コード
	    ,T01.EIGYOTEN_CD           --手数料計算結果．営業店コード
	    ,T01.JTK_KBN               --手数料計算結果．受託区分
	    ,MT05.FEE_BUNRUI           --手数料管理．手数料分類
    ) snt ON (MGR.ITAKU_KAISHA_CD = SNT.ITKCD AND MGR.MGR_CD = SNT.MGR)
WHERE --コードマスタ．コード種別　＝　'112'　AND
   SCODE.CODE_SHUBETSU = '112' --コードマスタ．コード値　＝　銘柄基本．受託区分　AND
  AND SCODE.CODE_VALUE = MGR.JTK_KBN GROUP BY
    MGR.ITAKU_KAISHA_CD ,    --委託会社コード
    MGR.MGR_CD ,             --銘柄コード
    MGR.ISIN_CD ,            --ISINコード
    MGR.MGR_RNM ,            --銘柄略称
    MGR.TANPO_KBN ,          --担保区分
    MGR.BUTEN_CD ,          --部店コード
    MGR.BUTEN_RNM ,         --部店略称
    MGR.JTK_KBN ,            --受託区分
    SCODE.CODE_RNM ,         --受託区分略称
    THFT.KNGK ,              --担保附当初金額
    THFKY.KNGK ,             --担保附期中金額
    THNS.KNGK ,              --無担保当初金額
    THKY.KNGK ,              --無担保期中金額
    SNT.KNGK                  --その他金額
    ORDER BY
    	MGR.BUTEN_CD
    	,CASE WHEN MGR.TANPO_KBN='2' THEN 1  ELSE 2 END 	-- 物上担保2→それ以外
    	,CASE WHEN MGR.JTK_KBN='2' THEN 3 WHEN MGR.JTK_KBN='1' THEN 2  ELSE 1 END 	-- 単（財務・非受託）→主（代表）→副（副受託）
    	,MGR.ISIN_CD;
  --==============================================================================
  --                  メイン処理                  
  --==============================================================================
BEGIN
  CALL pkLog.debug(l_inUserId,  '○' || C_PRGRAM_NAME ||'('|| C_PROCEDURE_ID||')', ' START');
--１．初期処理
 --１−１．引数（必須）データチェック
  --下記の項目は必須項目であり、ＮＵＬＬの場合、エラーにする
  IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''    --委託会社コード
  OR coalesce(trim(both l_inUserId)::text, '') = ''           --ユーザID
  OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''        --帳票区分
  OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''         --業務日付
  OR coalesce(trim(both l_inBaYmFrom)::text, '') = ''         --基準年月FROM
  OR coalesce(trim(both l_inBaYmTo)::text, '') = '' THEN       --基準年月TO
     -- パラメータエラー
     errCode := 'ECM501';
     errMsg := '入力パラメータエラー';
     RAISE EXCEPTION 'errijou' USING ERRCODE = '50001';
  END IF;
 --１−２．基準年月日の設定
  --変数．基準年月日FROM　：＝　引数．基準年月FROM　||　'01'；　
  gBaYmFrom := l_inBaYmFrom || '01';
  --変数．基準年月日TO　：＝　TO_CHAR（LAST_DAY（TO_DATE（引数．基準年月TO　||　'01','YYYYMMDD'））,'YYYYMMDD');
  gBaYmTo := TO_CHAR(oracle.LAST_DAY(to_date(l_inBaYmTo || '01','YYYYMMDD')),'YYYYMMDD');
 --１−３．帳票ワークの削除
  DELETE FROM SREPORT_WK
  WHERE KEY_CD = l_inItakuKaishaCd   --識別コード = 引数．委託会社コード
    AND USER_ID = l_inUserId         --ユーザID = 引数．ユーザID
    AND CHOHYO_KBN = l_inChohyoKbn   --帳票区分 = 引数．帳票区分
    AND SAKUSEI_YMD = l_inGyomuYmd   --作成年月日 = 引数．業務日付
    AND CHOHYO_ID = CHOHYOID;     --帳票ID = 固定値．帳票ID
    
--２．発行時手数料作成
 --２−２．発行時手数料配列LOOP処理開始
 FOR i IN 1..3 LOOP
  --２−２−１．発行時手数料作成カーソルオープン
  gDeSuRo := gDeSuRoList[i];
  -- SQL編集
  gSQL := '';
  gSQL := gSQL || 'SELECT ';
  gSQL := gSQL || 'MG0.ITAKU_KAISHA_CD,';    --委託会社コード
  gSQL := gSQL || 'MG0.MGR_CD,';             --銘柄コード
  gSQL := gSQL || 'CASE WHEN MG7.TESU_SASHIHIKI_KBN = ''1'' THEN MG1.SKN_KOFU_YMD WHEN MG7.TESU_SASHIHIKI_KBN = ''2'' THEN PKIPACALCTESURYO.getChokyuKjt(MG7.HAKKO_TESU_CHOKYU_KBN,MG1.HAKKO_YMD,''1'') END '; --徴求日
  gSQL := gSQL || 'FROM ';
  gSQL := gSQL || 'MGR_STS MG0, ';            --銘柄ステータス管理
  gSQL := gSQL || 'MGR_KIHON MG1, ';          --銘柄_基本
  gSQL := gSQL || 'MGR_TESURYO_CTL MG7, ';    --銘柄手数料（制御情報）
  gSQL := gSQL || 'MGR_TESURYO_PRM MG8, ';    --銘柄手数料（計算情報）
  gSQL := gSQL || 'MHAKKOTAI M01 ';          --発行体マスタ
  gSQL := gSQL || 'WHERE ';
  gSQL := gSQL || 'MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD ';
  gSQL := gSQL || 'AND MG0.MGR_CD = MG1.MGR_CD ';
  gSQL := gSQL || 'AND MG0.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD ';
  gSQL := gSQL || 'AND MG0.MGR_CD = MG7.MGR_CD ';
  gSQL := gSQL || 'AND MG7.TESU_SHURUI_CD = ''' || gDeSuRo || ''' ';
  gSQL := gSQL || 'AND MG7.HAKKO_KICHU_KBN = ''1'' ';
  gSQL := gSQL || 'AND MG7.CHOOSE_FLG = ''1'' ';
  gSQL := gSQL || 'AND MG0.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD ';
  gSQL := gSQL || 'AND MG0.MGR_CD = MG8.MGR_CD ';
  gSQL := gSQL || 'AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
  gSQL := gSQL || 'AND MG1.HKT_CD = M01.HKT_CD ';
  gSQL := gSQL || 'AND MG0.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
  gSQL := gSQL || 'AND MG0.MGR_STAT_KBN = ''1'' ';
  gSQL := gSQL || 'AND MG0.MASSHO_FLG = ''0'' ';
  gSQL := gSQL || 'AND TRIM(MG1.ISIN_CD) IS NOT NULL ';
  --　配列．発行時手数料（n）が'02'の場合
  IF gDeSuRo = '02' THEN
      gSQL := gSQL || 'AND (MG8.BOSHU_TESU_BUNBO <> 0 OR MG8.BOSHUTESU_KNGK_TEIGAKU <> 0) ';
  -- 配列．発行時手数料（n）が'03'の場合
  ELSIF gDeSuRo = '03' THEN
      gSQL := gSQL || 'AND (MG8.FJM_RATE_BUNBO <> 0 OR MG8.FJM_TESU_KNGK_TEIGAKU <> 0) ';
  --　配列．発行時手数料（n）が'04'の場合
  ELSIF gDeSuRo = '04' THEN
      gSQL := gSQL || 'AND (MG8.FZD_RATE_BUNBO <> 0 OR MG8.FZD_TESU_KNGK_TEIGAKU <> 0) ';
  END IF;
  gSQL := gSQL ||'AND CASE WHEN MG7.TESU_SASHIHIKI_KBN = ''1'' THEN MG1.SKN_KOFU_YMD WHEN MG7.TESU_SASHIHIKI_KBN = ''2'' THEN PKIPACALCTESURYO.getChokyuKjt(MG7.HAKKO_TESU_CHOKYU_KBN,MG1.HAKKO_YMD,''1'') END >= ''' || trim(both gBaYmFrom) || ''' ';
  gSQL := gSQL ||'AND CASE WHEN MG7.TESU_SASHIHIKI_KBN = ''1'' THEN MG1.SKN_KOFU_YMD WHEN MG7.TESU_SASHIHIKI_KBN = ''2'' THEN PKIPACALCTESURYO.getChokyuKjt(MG7.HAKKO_TESU_CHOKYU_KBN,MG1.HAKKO_YMD,''1'') END <= ''' || trim(both gBaYmTo) || ''' ';
  IF (l_inEiGyouTenCd IS NOT NULL AND l_inEiGyouTenCd <> '') THEN
      gSQL := gSQL ||'AND M01.EIGYOTEN_CD = ''' || l_inEiGyouTenCd || ''' ';
  END IF;
  
  OPEN curMeisai FOR EXECUTE gSQL;
  LOOP
  FETCH curMeisai INTO gItakuKaishaCd,gMgrCd,gShinuYmd;
  EXIT WHEN NOT FOUND;/* apply on curMeisai */
   --２−２−１−１．手数料テーブル作成処理
    --２−２−１−１−１．配列．発行時手数料（n）＝'02’の場合   -- 当初信託報酬
    IF gDeSuRo = '02' THEN
        gRet :=PKIPABOSHUTESURYO.updateBoshuTesuryo(gItakuKaishaCd,gMgrCd,gDeSuRo,PKIPACALCTESURYO.C_DATA_KBN_YOTEI());
    END IF;
    --２−２−１−１−２．配列．発行時手数料（n）＝'03'OR　'04'の場合
    IF gDeSuRo = '03' OR gDeSuRo = '04' THEN
        gRet :=PKIPAZAIMUJIMUTESURYO.updateZaimuJimuTesuryoTbl(gItakuKaishaCd::character, gMgrCd::character, gDeSuRo, gShinuYmd, '0'::character);
    END IF;
  --２−２−１−２．戻り値判定
  IF gRet <> 0 THEN
      l_outSqlCode := gRet;
      l_outSqlErrM := '手数料計算結果テーブル作成処理が失敗しました。';
      CALL pkLog.error('ECM701',CHOHYOID,'エラーメッセージ：手数料種類コード' || gDeSuRo || '-' || l_outSqlErrM);
      RETURN;
  END IF;
  END LOOP;
  CLOSE curMeisai;
 END LOOP;
--３．期中手数料作成
 --３−１．期中手数料作成カーソルオープン
 IF gRet = 0 THEN
	 FOR reKiqu IN curKiqu(l_inItakuKaishaCd,gBaYmFrom,gBaYmTo,l_inEiGyouTenCd) LOOP
	     --３−１−１．手数料テーブル作成処理
	     IF reKiqu.TESU_SHURUI_CD = '11' OR reKiqu.TESU_SHURUI_CD = '12' THEN 	-- 期中管理手数料,期中信託報酬
	     	gRet :=pkIpaKichuTesuryo.updateKichuTesuryoTbl(reKiqu.ITAKU_KAISHA_CD::character varying, reKiqu.MGR_CD::character varying, reKiqu.TESU_SHURUI_CD::character varying, reKiqu.CHOKYU_YMD::character varying, '0'::character varying);
	     ELSIF reKiqu.TESU_SHURUI_CD = '21' OR reKiqu.TESU_SHURUI_CD = '22' THEN 	-- 事務手数料（期中）,財務代理人手数料（期中）
	     	gRet :=pkIpaZaimuJimuTesuryo.updateZaimuJimuTesuryoTbl(reKiqu.ITAKU_KAISHA_CD, reKiqu.MGR_CD::character, reKiqu.TESU_SHURUI_CD, reKiqu.CHOKYU_YMD, '0'::character);
	     ELSIF reKiqu.TESU_SHURUI_CD = '41' THEN  	-- 買入消却手数料
	     	gRet :=pkIpaKaiireTesuryo.updateKaiireTesuryoTbl(reKiqu.ITAKU_KAISHA_CD,reKiqu.MGR_CD,reKiqu.CHOKYU_YMD,0,0);
	     ELSIF reKiqu.TESU_SHURUI_CD = '52'	OR reKiqu.TESU_SHURUI_CD = '91'	THEN  -- 支払代理人手数料,その他期中手数料１
	     	gRet :=pkIpaPayEtcKichuTesuryo.updatePayEtcKichuTesuryoTbl(reKiqu.ITAKU_KAISHA_CD, reKiqu.MGR_CD::character, reKiqu.TESU_SHURUI_CD, reKiqu.CHOKYU_YMD, '0'::character);
	     END IF;
	     IF gRet <> 0 THEN
	         l_outSqlCode := gRet;
	         l_outSqlErrM := '手数料計算結果テーブル作成処理が失敗しました。';
	         CALL pkLog.error('ECM701',CHOHYOID,'エラーメッセージ：手数料種類コード' || reKiqu.TESU_SHURUI_CD || '-' || l_outSqlErrM);
	         RETURN;
	     END IF;
	 END LOOP;
 END IF;
 IF gRet = 0 THEN
	--ヘッダーレコード出力
	 CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, CHOHYOID);
	--４．帳票ワークテーブルへ出力
	 --４−１．データ取得
	 FOR reMeiSai1 IN curMeisai1(l_inItakuKaishaCd,gBaYmFrom,gBaYmTo,l_inEiGyouTenCd) LOOP
	  --４−１−１．件数カウントアップ
	  --変数．件数　：＝　変数．件数　+　1；
	  gCaseCnt := gCaseCnt + 1;
	  --４−１−２．受託名称設定
	   --４−１−２−１．明細データ抽出．担保区分　＝　'2'（物上担保）の場合
	   IF reMeiSai1.TANPO = '2' THEN
	    --４−１−２−１−１．明細データ抽出．受託区分　＝　'2'（副受託）の場合
	    IF reMeiSai1.JTKKBN = '2' THEN
	     --変数．受託　：＝　'副受託';
	     gJudaKu := '副受託';
	    --明細データ抽出．受託区分　＝　'1'（代表）の場合
	    ELSIF  reMeiSai1.JTKKBN = '1' THEN
	        gJudaKu := '主受託';
	    ELSE
	    --明細データ抽出．受託区分　＝　'3'（財務）OR'4'（非受託）の場合
	        gJudaKu := '単独受託';
	    END IF;
	    --４−１−２−２．明細データ抽出．担保区分　＝　'2'（物上担保）以外の場合
	   ELSE
	    --４−１−２−２−１．明細データ抽出．受託区分　＝　'2'（副受託）の場合
	    IF reMeiSai1.JTKKBN = '2' THEN
	     --変数．受託　：＝　'副受託';
	     gJudaKu := '副管理';
	    --明細データ抽出．受託区分　＝　'1'（代表）の場合
	    ELSIF  reMeiSai1.JTKKBN = '1' THEN
	        gJudaKu := '主管理';
	    ELSE
	    --明細データ抽出．受託区分　＝　'3'（財務）OR'4'（非受託）の場合
	        gJudaKu := '単独管理';
	    END IF;
	   END IF;
	   --４−１−３．レコードのINSERT処理を行う
	          		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inBaYmFrom;	-- YYYYMM
		v_item.l_inItem002 := l_inBaYmTo;	-- YYYYMM
		v_item.l_inItem003 := reMeiSai1.TENCD;	-- 部店コード
		v_item.l_inItem004 := reMeisai1.TENRNM;	-- 部店略称
		v_item.l_inItem005 := gJudaKu;	-- 受託区分名称
		v_item.l_inItem006 := reMeisai1.ISIN;	-- ISINコード
		v_item.l_inItem007 := reMeisai1.MGR;	-- 銘柄コード
		v_item.l_inItem008 := reMeisai1.RNM;	-- 銘柄略称
		v_item.l_inItem009 := reMeisai1.THFTGK;	-- 手数料金額１（担保附（当初））
		v_item.l_inItem010 := reMeisai1.FKYGK;	-- 手数料金額２（担保附（期中））
		v_item.l_inItem011 := reMeisai1.NSGK;	-- 手数料金額３（無担保（当初））
		v_item.l_inItem012 := reMeisai1.KYGK;	-- 手数料金額４（無担保（期中））
		v_item.l_inItem013 := reMeisai1.SNTGK;	-- 手数料金額５（その他）
		v_item.l_inItem014 := CHOHYOID;	-- 帳票ID
		v_item.l_inItem015 := ''::text;	-- 空
		v_item.l_inItem016 := l_inUserId;	-- ユーザＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> CHOHYOID,
			l_inSeqNo		=> gCaseCnt,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	 END LOOP;
	 --４−２．変数．件数が「0」の場合（対象データがない場合）
	 IF gCaseCnt = 0 THEN
	     --「対象データなし」を帳票ワークテーブルへ出力する。
	     		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem014 := CHOHYOID;	-- 固定値．帳票ID
		v_item.l_inItem015 := '対象データなし'::text;	-- 回号正式名称１
		v_item.l_inItem016 := l_inUserId;	-- ユーザＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> CHOHYOID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	      --４−２−１．リターン値＝2：対象データなしを戻す。
	      l_outSqlCode := 2;
	 ELSE
	     l_outSqlCode := 0;
	 END IF;
	 -- 終了処理
	 CALL pkLog.debug(l_inUserId,  '○' || C_PRGRAM_NAME ||'('|| C_PROCEDURE_ID||')', ' END');
 END IF;
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
-- REVOKE ALL ON PROCEDURE spipi003k14r02 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_inBaYmFrom text, l_inBaYmTo text, l_inEiGyouTenCd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;



-- REVOKE ALL ON PROCEDURE spipi003k14r02_createsql () FROM PUBLIC;