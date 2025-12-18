


DROP TYPE IF EXISTS SPIPI002K14R01_l_items_type;
CREATE TYPE SPIPI002K14R01_l_items_type AS (SPIPI002K14R01_l_items_type varchar(400)[250]);
DROP TYPE IF EXISTS SPIPI002K14R01_gKib_type;
CREATE TYPE SPIPI002K14R01_gKib_type AS (SPIPI002K14R01_gKib_type char(6)[35]);
DROP TYPE IF EXISTS SPIPI002K14R01_gGanponShiYM_type;
CREATE TYPE SPIPI002K14R01_gGanponShiYM_type AS (SPIPI002K14R01_gGanponShiYM_type char(8)[35]);
DROP TYPE IF EXISTS SPIPI002K14R01_gJiyuCode_type;
CREATE TYPE SPIPI002K14R01_gJiyuCode_type AS (SPIPI002K14R01_gJiyuCode_type char(1)[35]);
DROP TYPE IF EXISTS SPIPI002K14R01_gBond_type;
CREATE TYPE SPIPI002K14R01_gBond_type AS (SPIPI002K14R01_gBond_type varchar(2)[35]);


CREATE OR REPLACE PROCEDURE spipi002k14r01 ( l_inItakuKaishaCd text,  -- 委託会社コード
 l_inUserId text,  -- ユーザーID
 l_inChohyoKbn text,  -- 帳票区分
 l_inGyomuYmd text,  -- 業務日付
 l_inYmdBe text,  -- 前年月
 l_inYmdBe1 text,  -- 前月末日
 l_inYmdBe2 text,  -- 前々年月
 l_inKaiGoCd text,  -- 銘柄・回号コード
 l_inHktCd text,  -- 発行体コード
 l_outSqlCode OUT integer,   -- リターン値
 l_outSqlErrM OUT text  -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:支払報告書ファイル、回号マスタを抽出し帳票を作成する
-- *        全利札支払済の回号マスタの元本出力抑制フラグを更新する
-- *
-- * 引数　:l_inItakuKaishaCd    IN VARCHAR,     委託会社コード
-- *       l_inUserId           IN VARCHAR,     ユーザーID
-- *       l_inChohyoKbn        IN VARCHAR,     帳票区分
-- *       l_inGyomuYmd         IN VARCHAR,     業務日付
-- *       l_inYmdBe            IN VARCHAR,     前年月
-- *       l_inYmdBe1           IN VARCHAR,     前月末日
-- *       l_inYmdBe2           IN VARCHAR,     前々年月
-- *       l_inKaiGoCd          IN VARCHAR,     銘柄・回号コード
-- *       l_inHktCd            IN VARCHAR,     発行体コード
-- *       l_outSqlCode         OUT NUMERIC,      リターン値
-- *       l_outSqlErrM         OUT VARCHAR     エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author 陳威宇
-- * @version $Id: SPIPI002K14R01.sql,v 1.4 2013/08/12 06:09:25 ito Exp $
-- *
-- 
  --==============================================================================
  --          定数定義                                                             
  --==============================================================================
  C_PROCEDURE_ID      CONSTANT text := 'SPIPI002K14R01';     -- プロシージャＩＤ
  C_PRGRAM_NAME       CONSTANT text := '元金状況表';          -- プロシージャ名
  TITLE1              CONSTANT text := '元金状況表（控）';       -- タイトル（１回目）
  TITLE2              CONSTANT text := '元金状況表';          -- タイトル（２回目）
  CHOHYOID1           CONSTANT text := 'IP931400211';        -- 固有の帳票ID（控）
  CHOHYOID2           CONSTANT text := 'IP931400212';        -- 固有の帳票ID
  --==============================================================================
  --      変数定義                                                                 
  --==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
  gRtnCd               numeric := pkconstant.success();            -- リターンコード
  gREPORT_ID           varchar(20);                                 -- 帳票ＩＤ
  gTitle               varchar(20);                                 -- タイトル
  gSeqNo               integer := 0;                            -- 連番
  gMgr                 char(7) := NULL;                         -- 銘柄コード
  gKaigo               char(6) := NULL;                         -- 回号コード
  gNm1                 varchar(40) := NULL;                    -- 回号正式名称１
  gNm2                 varchar(40) := NULL;                    -- 回号正式名称２
  gKen                 char(2) := NULL;                         -- 券種コード
  gNm                  varchar(14) := NULL;                    -- 券種名称
  l_Kibs SPIPI002K14R01_l_items_type;                                 -- 記番号XX
  l_GanponShiYMs SPIPI002K14R01_l_items_type;                                 -- 消滅年月XX
  l_JiyuCodes SPIPI002K14R01_l_items_type;                                 -- 事由コードXX
  l_Bonds SPIPI002K14R01_l_items_type;                                 -- 事故債券XX
  gKib SPIPI002K14R01_gKib_type;                                    -- 記番号XXリスト
  gGanponShiYM SPIPI002K14R01_gGanponShiYM_type;                            -- 消滅年月XXリスト
  gJiyuCode SPIPI002K14R01_gJiyuCode_type;                               -- 事由コードXXリスト
  gBond SPIPI002K14R01_gBond_type;                                   -- 事故債券XXリスト
  gKensuCount          numeric := 0;                             --件数
  
  errMsg               varchar(300);
  errCode              varchar(6);
  --==============================================================================
  --                  カーソル定義                                                  
  --==============================================================================
  --引数．銘柄・回号コード＝NULL　AND　引数．発行体コード＝NULLの場合
  curMeisai1 CURSOR(
                   itakushaCd GB_SHIHARAI_HOKOKUSHO.ITAKU_KAISHA_CD%TYPE,
                   inYmdBe GB_SHIHARAI_HOKOKUSHO.TORIHIKI_YM%TYPE,
                   inYmdBe2 GB_SHIHARAI_HOKOKUSHO.TORIHIKI_YM%TYPE
  ) FOR
   SELECT
        MGR,        --現物債銘柄コード
        KAIGO,      --回号コード
        NM1,        --回号正式名称１
        NM2,        --回号正式名称２
        (CASE WHEN coalesce(trim(both KEN)::text, '') = '' THEN KEN1 ELSE KEN END) KEN, --現物債券種コード（発行券種１?８）
        (CASE WHEN coalesce(trim(both NM)::text, '') = '' THEN KSNM1 ELSE NM END) NM,   --券種コード名称（券種名称１?８）
        KIB,        --記番号
        YMD,        --元本支払日
        GAN,        --元本異動事由
        WAR          --ワラント異動事由
    FROM(
    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU1 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM1 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,         --委託会社コード
                SH.GNBT_MGR_CD,             --現物債銘柄コード
                SH.KAIGO_CD                  --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE --記番号マスタ．委託会社コード ＝ 引数．委託会社コード
 GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND  --記番号マスタ．委託会社コード ＝ 回号マスタ．委託会社コード
 GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND  --記番号マスタ．現物債銘柄コード＝  回号マスタ．現物債銘柄コード
 GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND  --記番号マスタ．回号コード ＝  回号マスタ．回号コード
 GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．委託会社コード  ＝  券種マスタ．委託会社コード(+)
  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種１
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU1 AND  --記番号マスタ．委託会社コード＝SUB_TBL1．委託会社コード　ＡＮＤ
 GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND  --記番号マスタ．現物債銘柄コード＝SUB_TBL1．現物債銘柄コード　ＡＮＤ
 GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND  --記番号マスタ．回号コード＝SUB_TBL1．回号コード　ＡＮＤ
 GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND  --回号マスタ．記番号管理区分＝’1’（管理要）
 GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU2 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM2 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,      --委託会社コード
                SH.GNBT_MGR_CD,          --現物債銘柄コード
                SH.KAIGO_CD               --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR 
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種2
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU2 AND GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU3 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM3 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR 
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種3
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU3 AND GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU4 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM4 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR 
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種4
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU4 AND GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU5 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM5 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR 
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種5
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU5 AND GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU6 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM6 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR 
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種6
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU6 AND GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU7 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM7 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR 
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種7
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU7 AND GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU8 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM8 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM (
            SELECT
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
            FROM
                GB_SHIHARAI_HOKOKUSHO SH,
                GB_KAIGO  KAI,
                GB_GENSAI_RIREKI  GR 
            WHERE
                SH.ITAKU_KAISHA_CD = itakushaCd AND
                SH.TORIHIKI_YM = inYmdBe AND
                SH.GNR_KBN = '0' AND
                GR.TORIHIKI_ZANDAKA = 0 AND
                coalesce(trim(both GR.MUKO_FLG)::text, '') = '' AND
                SUBSTR(to_char(oracle.ADD_MONTHS(to_date(GR.TORIHIKI_YMD,'yyyymmdd'),120)+1,'yyyymmdd'),1,6) > inYmdBe2 AND
                SH.ITAKU_KAISHA_CD = GR.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = GR.GNBT_MGR_CD AND
                SH.KAIGO_CD = GR.KAIGO_CD AND
                SH.ITAKU_KAISHA_CD = KAI.ITAKU_KAISHA_CD AND
                SH.GNBT_MGR_CD = KAI.GNBT_MGR_CD AND
                SH.KAIGO_CD = KAI.KAIGO_CD AND
                KAI.KIBANGO_KANRI_KBN = '1' 
            GROUP BY
                SH.ITAKU_KAISHA_CD,--委託会社コード
                SH.GNBT_MGR_CD,    --現物債銘柄コード
                SH.KAIGO_CD         --回号コード
        ) sub_tbl1, gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD) 
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種8
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU8 AND GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = SUB_TBL1.KAIGO_CD AND GB_KAIGO.KIBANGO_KANRI_KBN = '1' )
    ORDER BY
        MGR,             --現物債銘柄コード
        KAIGO,           --回号コード
        KEN,             --現物債券種コード（発行券種１?８）
        KIB;             --記番号
  --引数．銘柄・回号コード　IS　NOT　NULL　OR　引数．発行体コード　IS　NOT　NULLの場合
  curMeisai2 CURSOR(
                    itakushaCd GB_SHIHARAI_HOKOKUSHO.ITAKU_KAISHA_CD%TYPE,
                    inKaiGoCd  text,
                    inHktCd  text
    ) FOR
    SELECT
        MGR,        --現物債銘柄コード
        KAIGO,      --回号コード
        NM1,        --回号正式名称１
        NM2,        --回号正式名称２
        (CASE WHEN coalesce(trim(both KEN)::text, '') = '' THEN KEN1 ELSE KEN END) KEN, --現物債券種コード（発行券種１?８）
        (CASE WHEN coalesce(trim(both NM)::text, '') = '' THEN KSNM1 ELSE NM END) NM,   --券種コード名称（券種名称１?８）
        KIB,        --記番号
        YMD,        --元本支払日
        GAN,        --元本異動事由
        WAR          --ワラント異動事由
    FROM(
    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
           GB_KAIGO.HAKKO_KENSHU1 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM1 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE --記番号マスタ．委託会社コード ＝ 引数．委託会社コード
 GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND  --記番号マスタ．委託会社コード ＝ 回号マスタ．委託会社コード
 GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND  --記番号マスタ．現物債銘柄コード＝  回号マスタ．現物債銘柄コード
 GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND  --記番号マスタ．回号コード ＝  回号マスタ．回号コード
 GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．委託会社コード  ＝  券種マスタ．委託会社コード(+)
  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種1
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU1 AND  --（（記番号マスタ．現物債銘柄コード ＝ 引数．銘柄・回号コードの先頭7桁 ＡＮＤ
 ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         --記番号マスタ．回号コード ＝ 引数．銘柄・回号コードの後6桁）OR
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         --記番号マスタ．現物債銘柄コードの先頭6桁 ＝ 引数．発行体コード）
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND  --回号マスタ．記番号管理区分＝’1’（管理要）
 GB_KAIGO.KIBANGO_KANRI_KBN = '1'
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU2 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM2 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種2
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU2 AND ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND GB_KAIGO.KIBANGO_KANRI_KBN = '1' 
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU3 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM3 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種3
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU3 AND ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND GB_KAIGO.KIBANGO_KANRI_KBN = '1' 
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU4 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM4 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種4
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU4 AND ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND GB_KAIGO.KIBANGO_KANRI_KBN = '1' 
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
           GB_KAIGO.HAKKO_KENSHU5 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM5 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種5
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU5 AND ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND GB_KAIGO.KIBANGO_KANRI_KBN = '1' 
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
           GB_KAIGO.HAKKO_KENSHU6 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM6 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種6
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU6 AND ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND GB_KAIGO.KIBANGO_KANRI_KBN = '1' 
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
        GB_KAIGO.HAKKO_KENSHU7 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM7 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種7
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU7 AND ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND GB_KAIGO.KIBANGO_KANRI_KBN = '1' 
     
UNION

    SELECT
        GB_KIBANGO.GNBT_MGR_CD MGR,        --現物債銘柄コード
        GB_KIBANGO.KAIGO_CD KAIGO,         --回号コード
        GB_KAIGO.KAIGO_NM1 NM1,            --回号正式名称１
        GB_KAIGO.KAIGO_NM2 NM2,            --回号正式名称２
        GB_KENSHU.GB_KENSHU_CD KEN,        --現物債券種コード（発行券種１?８）
           GB_KAIGO.HAKKO_KENSHU8 KEN1,       --発行券種
        GB_KENSHU.KENSHU_NM NM,            --券種コード名称（券種名称１?８）
        GB_KAIGO.KENSHU_NM8 KSNM1,         --券種名称
        GB_KIBANGO.KIBANGO KIB,            --記番号
        GB_KIBANGO.GANPON_SHIHARAI_YMD YMD,--元本支払日
        GB_KIBANGO.GANPON_IDO_JIYU GAN,    --元本異動事由
        GB_KIBANGO.WARRANT_IDO_JIYU WAR     --ワラント異動事由
    FROM gb_kaigo, gb_kibango
LEFT OUTER JOIN gb_kenshu ON (GB_KIBANGO.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD AND GB_KIBANGO.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD)
WHERE GB_KIBANGO.ITAKU_KAISHA_CD = itakushaCd AND GB_KIBANGO.ITAKU_KAISHA_CD = GB_KAIGO.ITAKU_KAISHA_CD AND GB_KIBANGO.GNBT_MGR_CD = GB_KAIGO.GNBT_MGR_CD AND GB_KIBANGO.KAIGO_CD = GB_KAIGO.KAIGO_CD  --記番号マスタ．発行券種  ＝  券種マスタ．現物債券種コード(+)
  AND  --記番号マスタ．発行券種 ＝  回号マスタ．発行券種8
 GB_KIBANGO.HAKKO_KENSHU = GB_KAIGO.HAKKO_KENSHU8 AND ((GB_KIBANGO.GNBT_MGR_CD = SUBSTR(inKaiGoCd , 1,7) AND
         GB_KIBANGO.KAIGO_CD = SUBSTR(inKaiGoCd,length(inKaiGoCd)-5,6)) OR
         SUBSTR(GB_KIBANGO.GNBT_MGR_CD,1,6) = inHktCd) AND GB_KAIGO.KIBANGO_KANRI_KBN = '1'  )
    ORDER BY
        MGR,             --現物債銘柄コード
        KAIGO,           --回号コード
        KEN,             --現物債券種コード（発行券種１?８）
        KIB;             --記番号
  recMeisai RECORD;
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
    OR coalesce(trim(both l_inYmdBe)::text, '') = ''            --前年月
    OR coalesce(trim(both l_inYmdBe2)::text, '') = '' THEN       --前々年月
        -- パラメータエラー
        errCode := 'ECM501';
        errMsg := '入力パラメータエラー';
        RAISE EXCEPTION 'errijou' USING ERRCODE = '50001';
    END IF;
    --１−３．帳票ワークの削除
    DELETE FROM SREPORT_WK
        WHERE KEY_CD = l_inItakuKaishaCd
            AND USER_ID = l_inUserId
            AND CHOHYO_KBN = l_inChohyoKbn
            AND SAKUSEI_YMD = l_inGyomuYmd
            AND (CHOHYO_ID = CHOHYOID1 OR CHOHYO_ID = CHOHYOID2);
    --２−１． 現物債銘柄マスタ、回号マスタデータを抽出する。
    --２−３．帳表ワークテーブルへ出力
    FOR cnt IN 1..2 LOOP
        IF cnt = 1 THEN
            gTitle := TITLE1;
            gREPORT_ID := CHOHYOID1;
        ELSE
            gTitle := TITLE2;
            gREPORT_ID := CHOHYOID2;
        END IF;
        --３−２−１．ヘッダーレコード出力
        CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gREPORT_ID);
        gSeqNo := 0;
        gKensuCount := 0;
        --引数．銘柄・回号コード＝NULL　AND　引数．発行体コード＝NULLの場合
        IF coalesce(trim(both l_inKaiGoCd)::text, '') = '' AND coalesce(trim(both l_inHktCd)::text, '') = '' THEN
            OPEN curMeisai1(l_inItakuKaishaCd,l_inYmdBe,l_inYmdBe2);
            FETCH curMeisai1 INTO recMeisai; -- カーソルの内容をフェッチする
            --対象データ無しの場合
            --２−３−２．「対象データなし」を帳表ワークテーブルへ出力する。
            IF NOT FOUND THEN
                -- Inline outNodataPrint
                gTitle := TITLE2;
                gREPORT_ID := CHOHYOID1;
                gSeqNo := 1;
                v_item := ROW();
                v_item.l_inItem003 := '対象データなし';
                v_item.l_inItem007 := gTitle;
                v_item := ROW();
                CALL pkPrint.insertData(
                    l_inKeyCd => l_inItakuKaishaCd,
                    l_inUserId => l_inUserId,
                    l_inChohyoKbn => l_inChohyoKbn,
                    l_inSakuseiYmd => l_inGyomuYmd,
                    l_inChohyoId => gREPORT_ID,
                    l_inSeqNo => gSeqNo,
                    l_inHeaderFlg => '1',
                    l_inItem => v_item,
                    l_inKousinId => l_inUserId,
                    l_inSakuseiId => l_inUserId
                );
                CLOSE curMeisai1;
                EXIT;
            END IF;
            --対象データ有りの場合
            --２−３−１．抽出した結果を１レコードずつ下記の処理を行い帳表ワークテーブルへ出力する。
            LOOP
                IF NOT FOUND THEN
                    -- Inline outPrint
                    gSeqNo := gSeqNo + 1;
                    --対象データを帳表ワークテーブルへ出力する。
                    		-- Clear composite type
                		v_item := ROW();
		
                		v_item.l_inItem001 := gMgr;	-- 銘柄コード
                		v_item.l_inItem002 := gKaigo;	-- 回号コード
                		v_item.l_inItem003 := gNm1;	-- 回号正式名称１
                		v_item.l_inItem004 := gNm2;	-- 回号正式名称２
                		v_item.l_inItem005 := gKen;	-- 券種コード
                		v_item.l_inItem006 := gNm;	-- 券種名称
                		v_item.l_inItem007 := gTitle;	-- タイトル
                		v_item.l_inItem008 := gKib[1];	-- 記番号1
                		v_item.l_inItem009 := gGanponShiYM[1];	-- 消滅年月1
                		v_item.l_inItem010 := gJiyuCode[1];	-- 事由コード1
                		v_item.l_inItem011 := gBond[1];	-- 事故債券1
                		v_item.l_inItem012 := gKib[2];	-- 記番号2
                		v_item.l_inItem013 := gGanponShiYM[2];	-- 消滅年月2
                		v_item.l_inItem014 := gJiyuCode[2];	-- 事由コード2
                		v_item.l_inItem015 := gBond[2];	-- 事故債券2
                		v_item.l_inItem016 := gKib[3];	-- 記番号3
                		v_item.l_inItem017 := gGanponShiYM[3];	-- 消滅年月3
                		v_item.l_inItem018 := gJiyuCode[3];	-- 事由コード3
                		v_item.l_inItem019 := gBond[3];	-- 事故債券3
                		v_item.l_inItem020 := gKib[4];	-- 記番号4
                		v_item.l_inItem021 := gGanponShiYM[4];	-- 消滅年月4
                		v_item.l_inItem022 := gJiyuCode[4];	-- 事由コード4
                		v_item.l_inItem023 := gBond[4];	-- 事故債券4
                		v_item.l_inItem024 := gKib[5];	-- 記番号5
                		v_item.l_inItem025 := gGanponShiYM[5];	-- 消滅年月5
                		v_item.l_inItem026 := gJiyuCode[5];	-- 事由コード5
                		v_item.l_inItem027 := gBond[5];	-- 事故債券5
                		v_item.l_inItem028 := gKib[6];	-- 記番号6
                		v_item.l_inItem029 := gGanponShiYM[6];	-- 消滅年月6
                		v_item.l_inItem030 := gJiyuCode[6];	-- 事由コード6
                		v_item.l_inItem031 := gBond[6];	-- 事故債券6
                		v_item.l_inItem032 := gKib[7];	-- 記番号7
                		v_item.l_inItem033 := gGanponShiYM[7];	-- 消滅年月7
                		v_item.l_inItem034 := gJiyuCode[7];	-- 事由コード7
                		v_item.l_inItem035 := gBond[7];	-- 事故債券7
                		v_item.l_inItem036 := gKib[8];	-- 記番号8
                		v_item.l_inItem037 := gGanponShiYM[8];	-- 消滅年月8
                		v_item.l_inItem038 := gJiyuCode[8];	-- 事由コード8
                		v_item.l_inItem039 := gBond[8];	-- 事故債券8
                		v_item.l_inItem040 := gKib[9];	-- 記番号9
                		v_item.l_inItem041 := gGanponShiYM[9];	-- 消滅年月9
                		v_item.l_inItem042 := gJiyuCode[9];	-- 事由コード9
                		v_item.l_inItem043 := gBond[9];	-- 事故債券9
                		v_item.l_inItem044 := gKib[10];	-- 記番号10
                		v_item.l_inItem045 := gGanponShiYM[10];	-- 消滅年月10
                		v_item.l_inItem046 := gJiyuCode[10];	-- 事由コード10
                		v_item.l_inItem047 := gBond[10];	-- 事故債券10
                		v_item.l_inItem048 := gKib[11];	-- 記番号11
                		v_item.l_inItem049 := gGanponShiYM[11];	-- 消滅年月11
                		v_item.l_inItem050 := gJiyuCode[11];	-- 事由コード11
                		v_item.l_inItem051 := gBond[11];	-- 事故債券11
                		v_item.l_inItem052 := gKib[12];	-- 記番号12
                		v_item.l_inItem053 := gGanponShiYM[12];	-- 消滅年月12
                		v_item.l_inItem054 := gJiyuCode[12];	-- 事由コード12
                		v_item.l_inItem055 := gBond[12];	-- 事故債券12
                		v_item.l_inItem056 := gKib[13];	-- 記番号13
                		v_item.l_inItem057 := gGanponShiYM[13];	-- 消滅年月13
                		v_item.l_inItem058 := gJiyuCode[13];	-- 事由コード13
                		v_item.l_inItem059 := gBond[13];	-- 事故債券13
                		v_item.l_inItem060 := gKib[14];	-- 記番号14
                		v_item.l_inItem061 := gGanponShiYM[14];	-- 消滅年月14
                		v_item.l_inItem062 := gJiyuCode[14];	-- 事由コード14
                		v_item.l_inItem063 := gBond[14];	-- 事故債券14
                		v_item.l_inItem064 := gKib[15];	-- 記番号15
                		v_item.l_inItem065 := gGanponShiYM[15];	-- 消滅年月15
                		v_item.l_inItem066 := gJiyuCode[15];	-- 事由コード15
                		v_item.l_inItem067 := gBond[15];	-- 事故債券15
                		v_item.l_inItem068 := gKib[16];	-- 記番号16
                		v_item.l_inItem069 := gGanponShiYM[16];	-- 消滅年月16
                		v_item.l_inItem070 := gJiyuCode[16];	-- 事由コード16
                		v_item.l_inItem071 := gBond[16];	-- 事故債券16
                		v_item.l_inItem072 := gKib[17];	-- 記番号17
                		v_item.l_inItem073 := gGanponShiYM[17];	-- 消滅年月17
                		v_item.l_inItem074 := gJiyuCode[17];	-- 事由コード17
                		v_item.l_inItem075 := gBond[17];	-- 事故債券17
                		v_item.l_inItem076 := gKib[18];	-- 記番18
                		v_item.l_inItem077 := gGanponShiYM[18];	-- 消滅年月18
                		v_item.l_inItem078 := gJiyuCode[18];	-- 事由コード18
                		v_item.l_inItem079 := gBond[18];	-- 事故債券18
                		v_item.l_inItem080 := gKib[19];	-- 記番号19
                		v_item.l_inItem081 := gGanponShiYM[19];	-- 消滅年月19
                		v_item.l_inItem082 := gJiyuCode[19];	-- 事由コード19
                		v_item.l_inItem083 := gBond[19];	-- 事故債券19
                		v_item.l_inItem084 := gKib[20];	-- 記番号20
                		v_item.l_inItem085 := gGanponShiYM[20];	-- 消滅年月20
                		v_item.l_inItem086 := gJiyuCode[20];	-- 事由コード20
                		v_item.l_inItem087 := gBond[20];	-- 事故債券20
                		v_item.l_inItem088 := gKib[21];	-- 記番号21
                		v_item.l_inItem089 := gGanponShiYM[21];	-- 消滅年月21
                		v_item.l_inItem090 := gJiyuCode[21];	-- 事由コード21
                		v_item.l_inItem091 := gBond[21];	-- 事故債券21
                		v_item.l_inItem092 := gKib[22];	-- 記番号22
                		v_item.l_inItem093 := gGanponShiYM[22];	-- 消滅年月22
                		v_item.l_inItem094 := gJiyuCode[22];	-- 事由コード22
                		v_item.l_inItem095 := gBond[22];	-- 事故債券22
                		v_item.l_inItem096 := gKib[23];	-- 記番号23
                		v_item.l_inItem097 := gGanponShiYM[23];	-- 消滅年月23
                		v_item.l_inItem098 := gJiyuCode[23];	-- 事由コード23
                		v_item.l_inItem099 := gBond[23];	-- 事故債券23
                		v_item.l_inItem100 := gKib[24];	-- 記番号24
                		v_item.l_inItem101 := gGanponShiYM[24];	-- 消滅年月24
                		v_item.l_inItem102 := gJiyuCode[24];	-- 事由コード24
                		v_item.l_inItem103 := gBond[24];	-- 事故債券24
                		v_item.l_inItem104 := gKib[25];	-- 記番号25
                		v_item.l_inItem105 := gGanponShiYM[25];	-- 消滅年月25
                		v_item.l_inItem106 := gJiyuCode[25];	-- 事由コード25
                		v_item.l_inItem107 := gBond[25];	-- 事故債券25
                		v_item.l_inItem108 := gKib[26];	-- 記番号26
                		v_item.l_inItem109 := gGanponShiYM[26];	-- 消滅年月26
                		v_item.l_inItem110 := gJiyuCode[26];	-- 事由コード26
                		v_item.l_inItem111 := gBond[26];	-- 事故債券26
                		v_item.l_inItem112 := gKib[27];	-- 記番号27
                		v_item.l_inItem113 := gGanponShiYM[27];	-- 消滅年月27
                		v_item.l_inItem114 := gJiyuCode[27];	-- 事由コード27
                		v_item.l_inItem115 := gBond[27];	-- 事故債券27
                		v_item.l_inItem116 := gKib[28];	-- 記番号28
                		v_item.l_inItem117 := gGanponShiYM[28];	-- 消滅年月28
                		v_item.l_inItem118 := gJiyuCode[28];	-- 事由コード28
                		v_item.l_inItem119 := gBond[28];	-- 事故債券28
                		v_item.l_inItem120 := gKib[29];	-- 記番号29
                		v_item.l_inItem121 := gGanponShiYM[29];	-- 消滅年月29
                		v_item.l_inItem122 := gJiyuCode[29];	-- 事由コード29
                		v_item.l_inItem123 := gBond[29];	-- 事故債券29
                		v_item.l_inItem124 := gKib[30];	-- 記番号30
                		v_item.l_inItem125 := gGanponShiYM[30];	-- 消滅年月30
                		v_item.l_inItem126 := gJiyuCode[30];	-- 事由コード30
                		v_item.l_inItem127 := gBond[30];	-- 事故債券30
                		v_item.l_inItem128 := gKib[31];	-- 記番号31
                		v_item.l_inItem129 := gGanponShiYM[31];	-- 消滅年月31
                		v_item.l_inItem130 := gJiyuCode[31];	-- 事由コード31
                		v_item.l_inItem131 := gBond[31];	-- 事故債券31
                		v_item.l_inItem132 := gKib[32];	-- 記番号32
                		v_item.l_inItem133 := gGanponShiYM[32];	-- 消滅年月32
                		v_item.l_inItem134 := gJiyuCode[32];	-- 事由コード32
                		v_item.l_inItem135 := gBond[32];	-- 事故債券32
                		v_item.l_inItem136 := gKib[33];	-- 記番号33
                		v_item.l_inItem137 := gGanponShiYM[33];	-- 消滅年月33
                		v_item.l_inItem138 := gJiyuCode[33];	-- 事由コード33
                		v_item.l_inItem139 := gBond[33];	-- 事故債券33
		
                		-- Call pkPrint.insertData with composite type
                				-- Clear composite type
                		v_item := ROW();
		
		
                		-- Call pkPrint.insertData with composite type
                		CALL pkPrint.insertData(
                			l_inKeyCd		=> l_inItakuKaishaCd,
                			l_inUserId		=> l_inUserId,
                			l_inChohyoKbn	=> l_inChohyoKbn,
                			l_inSakuseiYmd	=> l_inGyomuYmd,
                			l_inChohyoId	=> gREPORT_ID,
                			l_inSeqNo		=> gSeqNo,
                			l_inHeaderFlg	=> '1',
                			l_inItem		=> v_item,
                			l_inKousinId	=> l_inUserId,
                			l_inSakuseiId	=> l_inUserId
                		);
                    EXIT;
                END IF;
                -- Inline setMeisai
                    IF gKensuCount = 0 THEN
                            gKensuCount := 0;
                    gMgr := reMeisai.MGR;                    -- 銘柄コード
                    gKaigo := reMeisai.KAIGO;                -- 回号コード
                    gNm1 := reMeisai.NM1;                    -- 回号正式名称１
                    gNm2 := reMeisai.NM2;                    -- 回号正式名称２
                    gKen := reMeisai.KEN;                    -- 券種コード
                    gNm := reMeisai.NM;                      -- 券種名称
                    gKib           := ARRAY[]::char(6)[];           --記番号XXリスト
                    gGanponShiYM   := ARRAY[]::char(8)[];   --消滅年月XXリスト
                    gJiyuCode      := ARRAY[]::char(1)[];      --事由コードXXリスト
                    gBond          := ARRAY[]::varchar(2)[];          --事故債券XXリスト
                    ELSIF gKensuCount = 33  THEN
                            gSeqNo := gSeqNo + 1;
                    --対象データを帳表ワークテーブルへ出力する。
                    		-- Clear composite type
                		v_item := ROW();
		
                		v_item.l_inItem001 := gMgr;	-- 銘柄コード
                		v_item.l_inItem002 := gKaigo;	-- 回号コード
                		v_item.l_inItem003 := gNm1;	-- 回号正式名称１
                		v_item.l_inItem004 := gNm2;	-- 回号正式名称２
                		v_item.l_inItem005 := gKen;	-- 券種コード
                		v_item.l_inItem006 := gNm;	-- 券種名称
                		v_item.l_inItem007 := gTitle;	-- タイトル
                		v_item.l_inItem008 := gKib[1];	-- 記番号1
                		v_item.l_inItem009 := gGanponShiYM[1];	-- 消滅年月1
                		v_item.l_inItem010 := gJiyuCode[1];	-- 事由コード1
                		v_item.l_inItem011 := gBond[1];	-- 事故債券1
                		v_item.l_inItem012 := gKib[2];	-- 記番号2
                		v_item.l_inItem013 := gGanponShiYM[2];	-- 消滅年月2
                		v_item.l_inItem014 := gJiyuCode[2];	-- 事由コード2
                		v_item.l_inItem015 := gBond[2];	-- 事故債券2
                		v_item.l_inItem016 := gKib[3];	-- 記番号3
                		v_item.l_inItem017 := gGanponShiYM[3];	-- 消滅年月3
                		v_item.l_inItem018 := gJiyuCode[3];	-- 事由コード3
                		v_item.l_inItem019 := gBond[3];	-- 事故債券3
                		v_item.l_inItem020 := gKib[4];	-- 記番号4
                		v_item.l_inItem021 := gGanponShiYM[4];	-- 消滅年月4
                		v_item.l_inItem022 := gJiyuCode[4];	-- 事由コード4
                		v_item.l_inItem023 := gBond[4];	-- 事故債券4
                		v_item.l_inItem024 := gKib[5];	-- 記番号5
                		v_item.l_inItem025 := gGanponShiYM[5];	-- 消滅年月5
                		v_item.l_inItem026 := gJiyuCode[5];	-- 事由コード5
                		v_item.l_inItem027 := gBond[5];	-- 事故債券5
                		v_item.l_inItem028 := gKib[6];	-- 記番号6
                		v_item.l_inItem029 := gGanponShiYM[6];	-- 消滅年月6
                		v_item.l_inItem030 := gJiyuCode[6];	-- 事由コード6
                		v_item.l_inItem031 := gBond[6];	-- 事故債券6
                		v_item.l_inItem032 := gKib[7];	-- 記番号7
                		v_item.l_inItem033 := gGanponShiYM[7];	-- 消滅年月7
                		v_item.l_inItem034 := gJiyuCode[7];	-- 事由コード7
                		v_item.l_inItem035 := gBond[7];	-- 事故債券7
                		v_item.l_inItem036 := gKib[8];	-- 記番号8
                		v_item.l_inItem037 := gGanponShiYM[8];	-- 消滅年月8
                		v_item.l_inItem038 := gJiyuCode[8];	-- 事由コード8
                		v_item.l_inItem039 := gBond[8];	-- 事故債券8
                		v_item.l_inItem040 := gKib[9];	-- 記番号9
                		v_item.l_inItem041 := gGanponShiYM[9];	-- 消滅年月9
                		v_item.l_inItem042 := gJiyuCode[9];	-- 事由コード9
                		v_item.l_inItem043 := gBond[9];	-- 事故債券9
                		v_item.l_inItem044 := gKib[10];	-- 記番号10
                		v_item.l_inItem045 := gGanponShiYM[10];	-- 消滅年月10
                		v_item.l_inItem046 := gJiyuCode[10];	-- 事由コード10
                		v_item.l_inItem047 := gBond[10];	-- 事故債券10
                		v_item.l_inItem048 := gKib[11];	-- 記番号11
                		v_item.l_inItem049 := gGanponShiYM[11];	-- 消滅年月11
                		v_item.l_inItem050 := gJiyuCode[11];	-- 事由コード11
                		v_item.l_inItem051 := gBond[11];	-- 事故債券11
                		v_item.l_inItem052 := gKib[12];	-- 記番号12
                		v_item.l_inItem053 := gGanponShiYM[12];	-- 消滅年月12
                		v_item.l_inItem054 := gJiyuCode[12];	-- 事由コード12
                		v_item.l_inItem055 := gBond[12];	-- 事故債券12
                		v_item.l_inItem056 := gKib[13];	-- 記番号13
                		v_item.l_inItem057 := gGanponShiYM[13];	-- 消滅年月13
                		v_item.l_inItem058 := gJiyuCode[13];	-- 事由コード13
                		v_item.l_inItem059 := gBond[13];	-- 事故債券13
                		v_item.l_inItem060 := gKib[14];	-- 記番号14
                		v_item.l_inItem061 := gGanponShiYM[14];	-- 消滅年月14
                		v_item.l_inItem062 := gJiyuCode[14];	-- 事由コード14
                		v_item.l_inItem063 := gBond[14];	-- 事故債券14
                		v_item.l_inItem064 := gKib[15];	-- 記番号15
                		v_item.l_inItem065 := gGanponShiYM[15];	-- 消滅年月15
                		v_item.l_inItem066 := gJiyuCode[15];	-- 事由コード15
                		v_item.l_inItem067 := gBond[15];	-- 事故債券15
                		v_item.l_inItem068 := gKib[16];	-- 記番号16
                		v_item.l_inItem069 := gGanponShiYM[16];	-- 消滅年月16
                		v_item.l_inItem070 := gJiyuCode[16];	-- 事由コード16
                		v_item.l_inItem071 := gBond[16];	-- 事故債券16
                		v_item.l_inItem072 := gKib[17];	-- 記番号17
                		v_item.l_inItem073 := gGanponShiYM[17];	-- 消滅年月17
                		v_item.l_inItem074 := gJiyuCode[17];	-- 事由コード17
                		v_item.l_inItem075 := gBond[17];	-- 事故債券17
                		v_item.l_inItem076 := gKib[18];	-- 記番18
                		v_item.l_inItem077 := gGanponShiYM[18];	-- 消滅年月18
                		v_item.l_inItem078 := gJiyuCode[18];	-- 事由コード18
                		v_item.l_inItem079 := gBond[18];	-- 事故債券18
                		v_item.l_inItem080 := gKib[19];	-- 記番号19
                		v_item.l_inItem081 := gGanponShiYM[19];	-- 消滅年月19
                		v_item.l_inItem082 := gJiyuCode[19];	-- 事由コード19
                		v_item.l_inItem083 := gBond[19];	-- 事故債券19
                		v_item.l_inItem084 := gKib[20];	-- 記番号20
                		v_item.l_inItem085 := gGanponShiYM[20];	-- 消滅年月20
                		v_item.l_inItem086 := gJiyuCode[20];	-- 事由コード20
                		v_item.l_inItem087 := gBond[20];	-- 事故債券20
                		v_item.l_inItem088 := gKib[21];	-- 記番号21
                		v_item.l_inItem089 := gGanponShiYM[21];	-- 消滅年月21
                		v_item.l_inItem090 := gJiyuCode[21];	-- 事由コード21
                		v_item.l_inItem091 := gBond[21];	-- 事故債券21
                		v_item.l_inItem092 := gKib[22];	-- 記番号22
                		v_item.l_inItem093 := gGanponShiYM[22];	-- 消滅年月22
                		v_item.l_inItem094 := gJiyuCode[22];	-- 事由コード22
                		v_item.l_inItem095 := gBond[22];	-- 事故債券22
                		v_item.l_inItem096 := gKib[23];	-- 記番号23
                		v_item.l_inItem097 := gGanponShiYM[23];	-- 消滅年月23
                		v_item.l_inItem098 := gJiyuCode[23];	-- 事由コード23
                		v_item.l_inItem099 := gBond[23];	-- 事故債券23
                		v_item.l_inItem100 := gKib[24];	-- 記番号24
                		v_item.l_inItem101 := gGanponShiYM[24];	-- 消滅年月24
                		v_item.l_inItem102 := gJiyuCode[24];	-- 事由コード24
                		v_item.l_inItem103 := gBond[24];	-- 事故債券24
                		v_item.l_inItem104 := gKib[25];	-- 記番号25
                		v_item.l_inItem105 := gGanponShiYM[25];	-- 消滅年月25
                		v_item.l_inItem106 := gJiyuCode[25];	-- 事由コード25
                		v_item.l_inItem107 := gBond[25];	-- 事故債券25
                		v_item.l_inItem108 := gKib[26];	-- 記番号26
                		v_item.l_inItem109 := gGanponShiYM[26];	-- 消滅年月26
                		v_item.l_inItem110 := gJiyuCode[26];	-- 事由コード26
                		v_item.l_inItem111 := gBond[26];	-- 事故債券26
                		v_item.l_inItem112 := gKib[27];	-- 記番号27
                		v_item.l_inItem113 := gGanponShiYM[27];	-- 消滅年月27
                		v_item.l_inItem114 := gJiyuCode[27];	-- 事由コード27
                		v_item.l_inItem115 := gBond[27];	-- 事故債券27
                		v_item.l_inItem116 := gKib[28];	-- 記番号28
                		v_item.l_inItem117 := gGanponShiYM[28];	-- 消滅年月28
                		v_item.l_inItem118 := gJiyuCode[28];	-- 事由コード28
                		v_item.l_inItem119 := gBond[28];	-- 事故債券28
                		v_item.l_inItem120 := gKib[29];	-- 記番号29
                		v_item.l_inItem121 := gGanponShiYM[29];	-- 消滅年月29
                		v_item.l_inItem122 := gJiyuCode[29];	-- 事由コード29
                		v_item.l_inItem123 := gBond[29];	-- 事故債券29
                		v_item.l_inItem124 := gKib[30];	-- 記番号30
                		v_item.l_inItem125 := gGanponShiYM[30];	-- 消滅年月30
                		v_item.l_inItem126 := gJiyuCode[30];	-- 事由コード30
                		v_item.l_inItem127 := gBond[30];	-- 事故債券30
                		v_item.l_inItem128 := gKib[31];	-- 記番号31
                		v_item.l_inItem129 := gGanponShiYM[31];	-- 消滅年月31
                		v_item.l_inItem130 := gJiyuCode[31];	-- 事由コード31
                		v_item.l_inItem131 := gBond[31];	-- 事故債券31
                		v_item.l_inItem132 := gKib[32];	-- 記番号32
                		v_item.l_inItem133 := gGanponShiYM[32];	-- 消滅年月32
                		v_item.l_inItem134 := gJiyuCode[32];	-- 事由コード32
                		v_item.l_inItem135 := gBond[32];	-- 事故債券32
                		v_item.l_inItem136 := gKib[33];	-- 記番号33
                		v_item.l_inItem137 := gGanponShiYM[33];	-- 消滅年月33
                		v_item.l_inItem138 := gJiyuCode[33];	-- 事由コード33
                		v_item.l_inItem139 := gBond[33];	-- 事故債券33
		
                		-- Call pkPrint.insertData with composite type
                				-- Clear composite type
                		v_item := ROW();
		
		
                		-- Call pkPrint.insertData with composite type
                		CALL pkPrint.insertData(
                			l_inKeyCd		=> l_inItakuKaishaCd,
                			l_inUserId		=> l_inUserId,
                			l_inChohyoKbn	=> l_inChohyoKbn,
                			l_inSakuseiYmd	=> l_inGyomuYmd,
                			l_inChohyoId	=> gREPORT_ID,
                			l_inSeqNo		=> gSeqNo,
                			l_inHeaderFlg	=> '1',
                			l_inItem		=> v_item,
                			l_inKousinId	=> l_inUserId,
                			l_inSakuseiId	=> l_inUserId
                		);
                            gKensuCount := 0;
                    gMgr := reMeisai.MGR;                    -- 銘柄コード
                    gKaigo := reMeisai.KAIGO;                -- 回号コード
                    gNm1 := reMeisai.NM1;                    -- 回号正式名称１
                    gNm2 := reMeisai.NM2;                    -- 回号正式名称２
                    gKen := reMeisai.KEN;                    -- 券種コード
                    gNm := reMeisai.NM;                      -- 券種名称
                    gKib           := ARRAY[]::char(6)[];           --記番号XXリスト
                    gGanponShiYM   := ARRAY[]::char(8)[];   --消滅年月XXリスト
                    gJiyuCode      := ARRAY[]::char(1)[];      --事由コードXXリスト
                    gBond          := ARRAY[]::varchar(2)[];          --事故債券XXリスト
                    END IF;
                    IF gMgr <> reMeisai.MGR OR gKaigo <> reMeisai.KAIGO OR gKen <> reMeisai.KEN THEN
                            gSeqNo := gSeqNo + 1;
                    --対象データを帳表ワークテーブルへ出力する。
                    		-- Clear composite type
                		v_item := ROW();
		
                		v_item.l_inItem001 := gMgr;	-- 銘柄コード
                		v_item.l_inItem002 := gKaigo;	-- 回号コード
                		v_item.l_inItem003 := gNm1;	-- 回号正式名称１
                		v_item.l_inItem004 := gNm2;	-- 回号正式名称２
                		v_item.l_inItem005 := gKen;	-- 券種コード
                		v_item.l_inItem006 := gNm;	-- 券種名称
                		v_item.l_inItem007 := gTitle;	-- タイトル
                		v_item.l_inItem008 := gKib[1];	-- 記番号1
                		v_item.l_inItem009 := gGanponShiYM[1];	-- 消滅年月1
                		v_item.l_inItem010 := gJiyuCode[1];	-- 事由コード1
                		v_item.l_inItem011 := gBond[1];	-- 事故債券1
                		v_item.l_inItem012 := gKib[2];	-- 記番号2
                		v_item.l_inItem013 := gGanponShiYM[2];	-- 消滅年月2
                		v_item.l_inItem014 := gJiyuCode[2];	-- 事由コード2
                		v_item.l_inItem015 := gBond[2];	-- 事故債券2
                		v_item.l_inItem016 := gKib[3];	-- 記番号3
                		v_item.l_inItem017 := gGanponShiYM[3];	-- 消滅年月3
                		v_item.l_inItem018 := gJiyuCode[3];	-- 事由コード3
                		v_item.l_inItem019 := gBond[3];	-- 事故債券3
                		v_item.l_inItem020 := gKib[4];	-- 記番号4
                		v_item.l_inItem021 := gGanponShiYM[4];	-- 消滅年月4
                		v_item.l_inItem022 := gJiyuCode[4];	-- 事由コード4
                		v_item.l_inItem023 := gBond[4];	-- 事故債券4
                		v_item.l_inItem024 := gKib[5];	-- 記番号5
                		v_item.l_inItem025 := gGanponShiYM[5];	-- 消滅年月5
                		v_item.l_inItem026 := gJiyuCode[5];	-- 事由コード5
                		v_item.l_inItem027 := gBond[5];	-- 事故債券5
                		v_item.l_inItem028 := gKib[6];	-- 記番号6
                		v_item.l_inItem029 := gGanponShiYM[6];	-- 消滅年月6
                		v_item.l_inItem030 := gJiyuCode[6];	-- 事由コード6
                		v_item.l_inItem031 := gBond[6];	-- 事故債券6
                		v_item.l_inItem032 := gKib[7];	-- 記番号7
                		v_item.l_inItem033 := gGanponShiYM[7];	-- 消滅年月7
                		v_item.l_inItem034 := gJiyuCode[7];	-- 事由コード7
                		v_item.l_inItem035 := gBond[7];	-- 事故債券7
                		v_item.l_inItem036 := gKib[8];	-- 記番号8
                		v_item.l_inItem037 := gGanponShiYM[8];	-- 消滅年月8
                		v_item.l_inItem038 := gJiyuCode[8];	-- 事由コード8
                		v_item.l_inItem039 := gBond[8];	-- 事故債券8
                		v_item.l_inItem040 := gKib[9];	-- 記番号9
                		v_item.l_inItem041 := gGanponShiYM[9];	-- 消滅年月9
                		v_item.l_inItem042 := gJiyuCode[9];	-- 事由コード9
                		v_item.l_inItem043 := gBond[9];	-- 事故債券9
                		v_item.l_inItem044 := gKib[10];	-- 記番号10
                		v_item.l_inItem045 := gGanponShiYM[10];	-- 消滅年月10
                		v_item.l_inItem046 := gJiyuCode[10];	-- 事由コード10
                		v_item.l_inItem047 := gBond[10];	-- 事故債券10
                		v_item.l_inItem048 := gKib[11];	-- 記番号11
                		v_item.l_inItem049 := gGanponShiYM[11];	-- 消滅年月11
                		v_item.l_inItem050 := gJiyuCode[11];	-- 事由コード11
                		v_item.l_inItem051 := gBond[11];	-- 事故債券11
                		v_item.l_inItem052 := gKib[12];	-- 記番号12
                		v_item.l_inItem053 := gGanponShiYM[12];	-- 消滅年月12
                		v_item.l_inItem054 := gJiyuCode[12];	-- 事由コード12
                		v_item.l_inItem055 := gBond[12];	-- 事故債券12
                		v_item.l_inItem056 := gKib[13];	-- 記番号13
                		v_item.l_inItem057 := gGanponShiYM[13];	-- 消滅年月13
                		v_item.l_inItem058 := gJiyuCode[13];	-- 事由コード13
                		v_item.l_inItem059 := gBond[13];	-- 事故債券13
                		v_item.l_inItem060 := gKib[14];	-- 記番号14
                		v_item.l_inItem061 := gGanponShiYM[14];	-- 消滅年月14
                		v_item.l_inItem062 := gJiyuCode[14];	-- 事由コード14
                		v_item.l_inItem063 := gBond[14];	-- 事故債券14
                		v_item.l_inItem064 := gKib[15];	-- 記番号15
                		v_item.l_inItem065 := gGanponShiYM[15];	-- 消滅年月15
                		v_item.l_inItem066 := gJiyuCode[15];	-- 事由コード15
                		v_item.l_inItem067 := gBond[15];	-- 事故債券15
                		v_item.l_inItem068 := gKib[16];	-- 記番号16
                		v_item.l_inItem069 := gGanponShiYM[16];	-- 消滅年月16
                		v_item.l_inItem070 := gJiyuCode[16];	-- 事由コード16
                		v_item.l_inItem071 := gBond[16];	-- 事故債券16
                		v_item.l_inItem072 := gKib[17];	-- 記番号17
                		v_item.l_inItem073 := gGanponShiYM[17];	-- 消滅年月17
                		v_item.l_inItem074 := gJiyuCode[17];	-- 事由コード17
                		v_item.l_inItem075 := gBond[17];	-- 事故債券17
                		v_item.l_inItem076 := gKib[18];	-- 記番18
                		v_item.l_inItem077 := gGanponShiYM[18];	-- 消滅年月18
                		v_item.l_inItem078 := gJiyuCode[18];	-- 事由コード18
                		v_item.l_inItem079 := gBond[18];	-- 事故債券18
                		v_item.l_inItem080 := gKib[19];	-- 記番号19
                		v_item.l_inItem081 := gGanponShiYM[19];	-- 消滅年月19
                		v_item.l_inItem082 := gJiyuCode[19];	-- 事由コード19
                		v_item.l_inItem083 := gBond[19];	-- 事故債券19
                		v_item.l_inItem084 := gKib[20];	-- 記番号20
                		v_item.l_inItem085 := gGanponShiYM[20];	-- 消滅年月20
                		v_item.l_inItem086 := gJiyuCode[20];	-- 事由コード20
                		v_item.l_inItem087 := gBond[20];	-- 事故債券20
                		v_item.l_inItem088 := gKib[21];	-- 記番号21
                		v_item.l_inItem089 := gGanponShiYM[21];	-- 消滅年月21
                		v_item.l_inItem090 := gJiyuCode[21];	-- 事由コード21
                		v_item.l_inItem091 := gBond[21];	-- 事故債券21
                		v_item.l_inItem092 := gKib[22];	-- 記番号22
                		v_item.l_inItem093 := gGanponShiYM[22];	-- 消滅年月22
                		v_item.l_inItem094 := gJiyuCode[22];	-- 事由コード22
                		v_item.l_inItem095 := gBond[22];	-- 事故債券22
                		v_item.l_inItem096 := gKib[23];	-- 記番号23
                		v_item.l_inItem097 := gGanponShiYM[23];	-- 消滅年月23
                		v_item.l_inItem098 := gJiyuCode[23];	-- 事由コード23
                		v_item.l_inItem099 := gBond[23];	-- 事故債券23
                		v_item.l_inItem100 := gKib[24];	-- 記番号24
                		v_item.l_inItem101 := gGanponShiYM[24];	-- 消滅年月24
                		v_item.l_inItem102 := gJiyuCode[24];	-- 事由コード24
                		v_item.l_inItem103 := gBond[24];	-- 事故債券24
                		v_item.l_inItem104 := gKib[25];	-- 記番号25
                		v_item.l_inItem105 := gGanponShiYM[25];	-- 消滅年月25
                		v_item.l_inItem106 := gJiyuCode[25];	-- 事由コード25
                		v_item.l_inItem107 := gBond[25];	-- 事故債券25
                		v_item.l_inItem108 := gKib[26];	-- 記番号26
                		v_item.l_inItem109 := gGanponShiYM[26];	-- 消滅年月26
                		v_item.l_inItem110 := gJiyuCode[26];	-- 事由コード26
                		v_item.l_inItem111 := gBond[26];	-- 事故債券26
                		v_item.l_inItem112 := gKib[27];	-- 記番号27
                		v_item.l_inItem113 := gGanponShiYM[27];	-- 消滅年月27
                		v_item.l_inItem114 := gJiyuCode[27];	-- 事由コード27
                		v_item.l_inItem115 := gBond[27];	-- 事故債券27
                		v_item.l_inItem116 := gKib[28];	-- 記番号28
                		v_item.l_inItem117 := gGanponShiYM[28];	-- 消滅年月28
                		v_item.l_inItem118 := gJiyuCode[28];	-- 事由コード28
                		v_item.l_inItem119 := gBond[28];	-- 事故債券28
                		v_item.l_inItem120 := gKib[29];	-- 記番号29
                		v_item.l_inItem121 := gGanponShiYM[29];	-- 消滅年月29
                		v_item.l_inItem122 := gJiyuCode[29];	-- 事由コード29
                		v_item.l_inItem123 := gBond[29];	-- 事故債券29
                		v_item.l_inItem124 := gKib[30];	-- 記番号30
                		v_item.l_inItem125 := gGanponShiYM[30];	-- 消滅年月30
                		v_item.l_inItem126 := gJiyuCode[30];	-- 事由コード30
                		v_item.l_inItem127 := gBond[30];	-- 事故債券30
                		v_item.l_inItem128 := gKib[31];	-- 記番号31
                		v_item.l_inItem129 := gGanponShiYM[31];	-- 消滅年月31
                		v_item.l_inItem130 := gJiyuCode[31];	-- 事由コード31
                		v_item.l_inItem131 := gBond[31];	-- 事故債券31
                		v_item.l_inItem132 := gKib[32];	-- 記番号32
                		v_item.l_inItem133 := gGanponShiYM[32];	-- 消滅年月32
                		v_item.l_inItem134 := gJiyuCode[32];	-- 事由コード32
                		v_item.l_inItem135 := gBond[32];	-- 事故債券32
                		v_item.l_inItem136 := gKib[33];	-- 記番号33
                		v_item.l_inItem137 := gGanponShiYM[33];	-- 消滅年月33
                		v_item.l_inItem138 := gJiyuCode[33];	-- 事由コード33
                		v_item.l_inItem139 := gBond[33];	-- 事故債券33
		
                		-- Call pkPrint.insertData with composite type
                				-- Clear composite type
                		v_item := ROW();
		
		
                		-- Call pkPrint.insertData with composite type
                		CALL pkPrint.insertData(
                			l_inKeyCd		=> l_inItakuKaishaCd,
                			l_inUserId		=> l_inUserId,
                			l_inChohyoKbn	=> l_inChohyoKbn,
                			l_inSakuseiYmd	=> l_inGyomuYmd,
                			l_inChohyoId	=> gREPORT_ID,
                			l_inSeqNo		=> gSeqNo,
                			l_inHeaderFlg	=> '1',
                			l_inItem		=> v_item,
                			l_inKousinId	=> l_inUserId,
                			l_inSakuseiId	=> l_inUserId
                		);
                            gKensuCount := 0;
                    gMgr := reMeisai.MGR;                    -- 銘柄コード
                    gKaigo := reMeisai.KAIGO;                -- 回号コード
                    gNm1 := reMeisai.NM1;                    -- 回号正式名称１
                    gNm2 := reMeisai.NM2;                    -- 回号正式名称２
                    gKen := reMeisai.KEN;                    -- 券種コード
                    gNm := reMeisai.NM;                      -- 券種名称
                    gKib           := ARRAY[]::char(6)[];           --記番号XXリスト
                    gGanponShiYM   := ARRAY[]::char(8)[];   --消滅年月XXリスト
                    gJiyuCode      := ARRAY[]::char(1)[];      --事由コードXXリスト
                    gBond          := ARRAY[]::varchar(2)[];          --事故債券XXリスト
                    END IF;
                    gKensuCount := gKensuCount + 1;
                    --記番号XXリスト
                    gKib[gKensuCount] := reMeisai.KIB;
                    --消滅年月XXリスト
                    IF reMeisai.YMD = ' ' THEN
                        gGanponShiYM[gKensuCount] := NULL;
                    ELSE
                        gGanponShiYM[gKensuCount] := SUBSTR(reMeisai.YMD,3,2) || '/' || SUBSTR(reMeisai.YMD,5,2);
                    END IF;
                    --事由コードXXリスト
                    IF reMeisai.GAN = '0' AND (trim(both reMeisai.YMD) IS NOT NULL AND (trim(both reMeisai.YMD))::text <> '') THEN
                        gJiyuCode[gKensuCount] := '1';
                    ELSIF reMeisai.GAN = '4' THEN
                        gJiyuCode[gKensuCount] := '2';
                    ELSIF reMeisai.GAN = '5' THEN
                        gJiyuCode[gKensuCount] := '3';
                    ELSIF reMeisai.GAN = '3' OR reMeisai.GAN = '2' THEN
                        gJiyuCode[gKensuCount] := '4';
                    ELSIF reMeisai.GAN = 'F' AND reMeisai.WAR = 'F' THEN
                        gJiyuCode[gKensuCount] := '5';
                    ELSE
                        gJiyuCode[gKensuCount] := ' ';
                    END IF;
                    --事故債券XXリスト
                    IF reMeisai.GAN = '1' OR reMeisai.GAN = '3' OR reMeisai.GAN = '2' THEN
                        gBond[gKensuCount] := '*';
                    ELSE
                        gBond[gKensuCount] := ' ';
                    END IF;
                FETCH curMeisai1 INTO recMeisai; -- カーソルの内容をフェッチする
            END LOOP;
            CLOSE curMeisai1;
        END IF;
        --引数．銘柄・回号コード　IS　NOT　NULL　OR　引数．発行体コード　IS　NOT　NULLの場合
        IF (trim(both l_inKaiGoCd) IS NOT NULL AND (trim(both l_inKaiGoCd))::text <> '') OR (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
            OPEN curMeisai2(l_inItakuKaishaCd,l_inKaiGoCd,l_inHktCd);
            FETCH curMeisai2 INTO recMeisai; -- カーソルの内容をフェッチする
            --対象データ無しの場合
            --２−３−２．「対象データなし」を帳表ワークテーブルへ出力する。
            IF NOT FOUND THEN
                -- Inline outNodataPrint
                gTitle := TITLE2;
                gREPORT_ID := CHOHYOID1;
                gSeqNo := 1;
                v_item := ROW();
                v_item.l_inItem003 := '対象データなし';
                v_item.l_inItem007 := gTitle;
                v_item := ROW();
                CALL pkPrint.insertData(
                    l_inKeyCd => l_inItakuKaishaCd,
                    l_inUserId => l_inUserId,
                    l_inChohyoKbn => l_inChohyoKbn,
                    l_inSakuseiYmd => l_inGyomuYmd,
                    l_inChohyoId => gREPORT_ID,
                    l_inSeqNo => gSeqNo,
                    l_inHeaderFlg => '1',
                    l_inItem => v_item,
                    l_inKousinId => l_inUserId,
                    l_inSakuseiId => l_inUserId
                );
                CLOSE curMeisai2;
                EXIT;
            END IF;
            --対象データ有りの場合
            --２−３−１．抽出した結果を１レコードずつ下記の処理を行い帳表ワークテーブルへ出力する。
            LOOP
                IF NOT FOUND THEN
                    -- Inline outPrint
                    gSeqNo := gSeqNo + 1;
                    --対象データを帳表ワークテーブルへ出力する。
                    		-- Clear composite type
                		v_item := ROW();
		
                		v_item.l_inItem001 := gMgr;	-- 銘柄コード
                		v_item.l_inItem002 := gKaigo;	-- 回号コード
                		v_item.l_inItem003 := gNm1;	-- 回号正式名称１
                		v_item.l_inItem004 := gNm2;	-- 回号正式名称２
                		v_item.l_inItem005 := gKen;	-- 券種コード
                		v_item.l_inItem006 := gNm;	-- 券種名称
                		v_item.l_inItem007 := gTitle;	-- タイトル
                		v_item.l_inItem008 := gKib[1];	-- 記番号1
                		v_item.l_inItem009 := gGanponShiYM[1];	-- 消滅年月1
                		v_item.l_inItem010 := gJiyuCode[1];	-- 事由コード1
                		v_item.l_inItem011 := gBond[1];	-- 事故債券1
                		v_item.l_inItem012 := gKib[2];	-- 記番号2
                		v_item.l_inItem013 := gGanponShiYM[2];	-- 消滅年月2
                		v_item.l_inItem014 := gJiyuCode[2];	-- 事由コード2
                		v_item.l_inItem015 := gBond[2];	-- 事故債券2
                		v_item.l_inItem016 := gKib[3];	-- 記番号3
                		v_item.l_inItem017 := gGanponShiYM[3];	-- 消滅年月3
                		v_item.l_inItem018 := gJiyuCode[3];	-- 事由コード3
                		v_item.l_inItem019 := gBond[3];	-- 事故債券3
                		v_item.l_inItem020 := gKib[4];	-- 記番号4
                		v_item.l_inItem021 := gGanponShiYM[4];	-- 消滅年月4
                		v_item.l_inItem022 := gJiyuCode[4];	-- 事由コード4
                		v_item.l_inItem023 := gBond[4];	-- 事故債券4
                		v_item.l_inItem024 := gKib[5];	-- 記番号5
                		v_item.l_inItem025 := gGanponShiYM[5];	-- 消滅年月5
                		v_item.l_inItem026 := gJiyuCode[5];	-- 事由コード5
                		v_item.l_inItem027 := gBond[5];	-- 事故債券5
                		v_item.l_inItem028 := gKib[6];	-- 記番号6
                		v_item.l_inItem029 := gGanponShiYM[6];	-- 消滅年月6
                		v_item.l_inItem030 := gJiyuCode[6];	-- 事由コード6
                		v_item.l_inItem031 := gBond[6];	-- 事故債券6
                		v_item.l_inItem032 := gKib[7];	-- 記番号7
                		v_item.l_inItem033 := gGanponShiYM[7];	-- 消滅年月7
                		v_item.l_inItem034 := gJiyuCode[7];	-- 事由コード7
                		v_item.l_inItem035 := gBond[7];	-- 事故債券7
                		v_item.l_inItem036 := gKib[8];	-- 記番号8
                		v_item.l_inItem037 := gGanponShiYM[8];	-- 消滅年月8
                		v_item.l_inItem038 := gJiyuCode[8];	-- 事由コード8
                		v_item.l_inItem039 := gBond[8];	-- 事故債券8
                		v_item.l_inItem040 := gKib[9];	-- 記番号9
                		v_item.l_inItem041 := gGanponShiYM[9];	-- 消滅年月9
                		v_item.l_inItem042 := gJiyuCode[9];	-- 事由コード9
                		v_item.l_inItem043 := gBond[9];	-- 事故債券9
                		v_item.l_inItem044 := gKib[10];	-- 記番号10
                		v_item.l_inItem045 := gGanponShiYM[10];	-- 消滅年月10
                		v_item.l_inItem046 := gJiyuCode[10];	-- 事由コード10
                		v_item.l_inItem047 := gBond[10];	-- 事故債券10
                		v_item.l_inItem048 := gKib[11];	-- 記番号11
                		v_item.l_inItem049 := gGanponShiYM[11];	-- 消滅年月11
                		v_item.l_inItem050 := gJiyuCode[11];	-- 事由コード11
                		v_item.l_inItem051 := gBond[11];	-- 事故債券11
                		v_item.l_inItem052 := gKib[12];	-- 記番号12
                		v_item.l_inItem053 := gGanponShiYM[12];	-- 消滅年月12
                		v_item.l_inItem054 := gJiyuCode[12];	-- 事由コード12
                		v_item.l_inItem055 := gBond[12];	-- 事故債券12
                		v_item.l_inItem056 := gKib[13];	-- 記番号13
                		v_item.l_inItem057 := gGanponShiYM[13];	-- 消滅年月13
                		v_item.l_inItem058 := gJiyuCode[13];	-- 事由コード13
                		v_item.l_inItem059 := gBond[13];	-- 事故債券13
                		v_item.l_inItem060 := gKib[14];	-- 記番号14
                		v_item.l_inItem061 := gGanponShiYM[14];	-- 消滅年月14
                		v_item.l_inItem062 := gJiyuCode[14];	-- 事由コード14
                		v_item.l_inItem063 := gBond[14];	-- 事故債券14
                		v_item.l_inItem064 := gKib[15];	-- 記番号15
                		v_item.l_inItem065 := gGanponShiYM[15];	-- 消滅年月15
                		v_item.l_inItem066 := gJiyuCode[15];	-- 事由コード15
                		v_item.l_inItem067 := gBond[15];	-- 事故債券15
                		v_item.l_inItem068 := gKib[16];	-- 記番号16
                		v_item.l_inItem069 := gGanponShiYM[16];	-- 消滅年月16
                		v_item.l_inItem070 := gJiyuCode[16];	-- 事由コード16
                		v_item.l_inItem071 := gBond[16];	-- 事故債券16
                		v_item.l_inItem072 := gKib[17];	-- 記番号17
                		v_item.l_inItem073 := gGanponShiYM[17];	-- 消滅年月17
                		v_item.l_inItem074 := gJiyuCode[17];	-- 事由コード17
                		v_item.l_inItem075 := gBond[17];	-- 事故債券17
                		v_item.l_inItem076 := gKib[18];	-- 記番18
                		v_item.l_inItem077 := gGanponShiYM[18];	-- 消滅年月18
                		v_item.l_inItem078 := gJiyuCode[18];	-- 事由コード18
                		v_item.l_inItem079 := gBond[18];	-- 事故債券18
                		v_item.l_inItem080 := gKib[19];	-- 記番号19
                		v_item.l_inItem081 := gGanponShiYM[19];	-- 消滅年月19
                		v_item.l_inItem082 := gJiyuCode[19];	-- 事由コード19
                		v_item.l_inItem083 := gBond[19];	-- 事故債券19
                		v_item.l_inItem084 := gKib[20];	-- 記番号20
                		v_item.l_inItem085 := gGanponShiYM[20];	-- 消滅年月20
                		v_item.l_inItem086 := gJiyuCode[20];	-- 事由コード20
                		v_item.l_inItem087 := gBond[20];	-- 事故債券20
                		v_item.l_inItem088 := gKib[21];	-- 記番号21
                		v_item.l_inItem089 := gGanponShiYM[21];	-- 消滅年月21
                		v_item.l_inItem090 := gJiyuCode[21];	-- 事由コード21
                		v_item.l_inItem091 := gBond[21];	-- 事故債券21
                		v_item.l_inItem092 := gKib[22];	-- 記番号22
                		v_item.l_inItem093 := gGanponShiYM[22];	-- 消滅年月22
                		v_item.l_inItem094 := gJiyuCode[22];	-- 事由コード22
                		v_item.l_inItem095 := gBond[22];	-- 事故債券22
                		v_item.l_inItem096 := gKib[23];	-- 記番号23
                		v_item.l_inItem097 := gGanponShiYM[23];	-- 消滅年月23
                		v_item.l_inItem098 := gJiyuCode[23];	-- 事由コード23
                		v_item.l_inItem099 := gBond[23];	-- 事故債券23
                		v_item.l_inItem100 := gKib[24];	-- 記番号24
                		v_item.l_inItem101 := gGanponShiYM[24];	-- 消滅年月24
                		v_item.l_inItem102 := gJiyuCode[24];	-- 事由コード24
                		v_item.l_inItem103 := gBond[24];	-- 事故債券24
                		v_item.l_inItem104 := gKib[25];	-- 記番号25
                		v_item.l_inItem105 := gGanponShiYM[25];	-- 消滅年月25
                		v_item.l_inItem106 := gJiyuCode[25];	-- 事由コード25
                		v_item.l_inItem107 := gBond[25];	-- 事故債券25
                		v_item.l_inItem108 := gKib[26];	-- 記番号26
                		v_item.l_inItem109 := gGanponShiYM[26];	-- 消滅年月26
                		v_item.l_inItem110 := gJiyuCode[26];	-- 事由コード26
                		v_item.l_inItem111 := gBond[26];	-- 事故債券26
                		v_item.l_inItem112 := gKib[27];	-- 記番号27
                		v_item.l_inItem113 := gGanponShiYM[27];	-- 消滅年月27
                		v_item.l_inItem114 := gJiyuCode[27];	-- 事由コード27
                		v_item.l_inItem115 := gBond[27];	-- 事故債券27
                		v_item.l_inItem116 := gKib[28];	-- 記番号28
                		v_item.l_inItem117 := gGanponShiYM[28];	-- 消滅年月28
                		v_item.l_inItem118 := gJiyuCode[28];	-- 事由コード28
                		v_item.l_inItem119 := gBond[28];	-- 事故債券28
                		v_item.l_inItem120 := gKib[29];	-- 記番号29
                		v_item.l_inItem121 := gGanponShiYM[29];	-- 消滅年月29
                		v_item.l_inItem122 := gJiyuCode[29];	-- 事由コード29
                		v_item.l_inItem123 := gBond[29];	-- 事故債券29
                		v_item.l_inItem124 := gKib[30];	-- 記番号30
                		v_item.l_inItem125 := gGanponShiYM[30];	-- 消滅年月30
                		v_item.l_inItem126 := gJiyuCode[30];	-- 事由コード30
                		v_item.l_inItem127 := gBond[30];	-- 事故債券30
                		v_item.l_inItem128 := gKib[31];	-- 記番号31
                		v_item.l_inItem129 := gGanponShiYM[31];	-- 消滅年月31
                		v_item.l_inItem130 := gJiyuCode[31];	-- 事由コード31
                		v_item.l_inItem131 := gBond[31];	-- 事故債券31
                		v_item.l_inItem132 := gKib[32];	-- 記番号32
                		v_item.l_inItem133 := gGanponShiYM[32];	-- 消滅年月32
                		v_item.l_inItem134 := gJiyuCode[32];	-- 事由コード32
                		v_item.l_inItem135 := gBond[32];	-- 事故債券32
                		v_item.l_inItem136 := gKib[33];	-- 記番号33
                		v_item.l_inItem137 := gGanponShiYM[33];	-- 消滅年月33
                		v_item.l_inItem138 := gJiyuCode[33];	-- 事由コード33
                		v_item.l_inItem139 := gBond[33];	-- 事故債券33
		
                		-- Call pkPrint.insertData with composite type
                				-- Clear composite type
                		v_item := ROW();
		
		
                		-- Call pkPrint.insertData with composite type
                		CALL pkPrint.insertData(
                			l_inKeyCd		=> l_inItakuKaishaCd,
                			l_inUserId		=> l_inUserId,
                			l_inChohyoKbn	=> l_inChohyoKbn,
                			l_inSakuseiYmd	=> l_inGyomuYmd,
                			l_inChohyoId	=> gREPORT_ID,
                			l_inSeqNo		=> gSeqNo,
                			l_inHeaderFlg	=> '1',
                			l_inItem		=> v_item,
                			l_inKousinId	=> l_inUserId,
                			l_inSakuseiId	=> l_inUserId
                		);
                    EXIT;
                END IF;
                -- Inline setMeisai
                    IF gKensuCount = 0 THEN
                            gKensuCount := 0;
                    gMgr := reMeisai.MGR;                    -- 銘柄コード
                    gKaigo := reMeisai.KAIGO;                -- 回号コード
                    gNm1 := reMeisai.NM1;                    -- 回号正式名称１
                    gNm2 := reMeisai.NM2;                    -- 回号正式名称２
                    gKen := reMeisai.KEN;                    -- 券種コード
                    gNm := reMeisai.NM;                      -- 券種名称
                    gKib           := ARRAY[]::char(6)[];           --記番号XXリスト
                    gGanponShiYM   := ARRAY[]::char(8)[];   --消滅年月XXリスト
                    gJiyuCode      := ARRAY[]::char(1)[];      --事由コードXXリスト
                    gBond          := ARRAY[]::varchar(2)[];          --事故債券XXリスト
                    ELSIF gKensuCount = 33  THEN
                            gSeqNo := gSeqNo + 1;
                    --対象データを帳表ワークテーブルへ出力する。
                    		-- Clear composite type
                		v_item := ROW();
		
                		v_item.l_inItem001 := gMgr;	-- 銘柄コード
                		v_item.l_inItem002 := gKaigo;	-- 回号コード
                		v_item.l_inItem003 := gNm1;	-- 回号正式名称１
                		v_item.l_inItem004 := gNm2;	-- 回号正式名称２
                		v_item.l_inItem005 := gKen;	-- 券種コード
                		v_item.l_inItem006 := gNm;	-- 券種名称
                		v_item.l_inItem007 := gTitle;	-- タイトル
                		v_item.l_inItem008 := gKib[1];	-- 記番号1
                		v_item.l_inItem009 := gGanponShiYM[1];	-- 消滅年月1
                		v_item.l_inItem010 := gJiyuCode[1];	-- 事由コード1
                		v_item.l_inItem011 := gBond[1];	-- 事故債券1
                		v_item.l_inItem012 := gKib[2];	-- 記番号2
                		v_item.l_inItem013 := gGanponShiYM[2];	-- 消滅年月2
                		v_item.l_inItem014 := gJiyuCode[2];	-- 事由コード2
                		v_item.l_inItem015 := gBond[2];	-- 事故債券2
                		v_item.l_inItem016 := gKib[3];	-- 記番号3
                		v_item.l_inItem017 := gGanponShiYM[3];	-- 消滅年月3
                		v_item.l_inItem018 := gJiyuCode[3];	-- 事由コード3
                		v_item.l_inItem019 := gBond[3];	-- 事故債券3
                		v_item.l_inItem020 := gKib[4];	-- 記番号4
                		v_item.l_inItem021 := gGanponShiYM[4];	-- 消滅年月4
                		v_item.l_inItem022 := gJiyuCode[4];	-- 事由コード4
                		v_item.l_inItem023 := gBond[4];	-- 事故債券4
                		v_item.l_inItem024 := gKib[5];	-- 記番号5
                		v_item.l_inItem025 := gGanponShiYM[5];	-- 消滅年月5
                		v_item.l_inItem026 := gJiyuCode[5];	-- 事由コード5
                		v_item.l_inItem027 := gBond[5];	-- 事故債券5
                		v_item.l_inItem028 := gKib[6];	-- 記番号6
                		v_item.l_inItem029 := gGanponShiYM[6];	-- 消滅年月6
                		v_item.l_inItem030 := gJiyuCode[6];	-- 事由コード6
                		v_item.l_inItem031 := gBond[6];	-- 事故債券6
                		v_item.l_inItem032 := gKib[7];	-- 記番号7
                		v_item.l_inItem033 := gGanponShiYM[7];	-- 消滅年月7
                		v_item.l_inItem034 := gJiyuCode[7];	-- 事由コード7
                		v_item.l_inItem035 := gBond[7];	-- 事故債券7
                		v_item.l_inItem036 := gKib[8];	-- 記番号8
                		v_item.l_inItem037 := gGanponShiYM[8];	-- 消滅年月8
                		v_item.l_inItem038 := gJiyuCode[8];	-- 事由コード8
                		v_item.l_inItem039 := gBond[8];	-- 事故債券8
                		v_item.l_inItem040 := gKib[9];	-- 記番号9
                		v_item.l_inItem041 := gGanponShiYM[9];	-- 消滅年月9
                		v_item.l_inItem042 := gJiyuCode[9];	-- 事由コード9
                		v_item.l_inItem043 := gBond[9];	-- 事故債券9
                		v_item.l_inItem044 := gKib[10];	-- 記番号10
                		v_item.l_inItem045 := gGanponShiYM[10];	-- 消滅年月10
                		v_item.l_inItem046 := gJiyuCode[10];	-- 事由コード10
                		v_item.l_inItem047 := gBond[10];	-- 事故債券10
                		v_item.l_inItem048 := gKib[11];	-- 記番号11
                		v_item.l_inItem049 := gGanponShiYM[11];	-- 消滅年月11
                		v_item.l_inItem050 := gJiyuCode[11];	-- 事由コード11
                		v_item.l_inItem051 := gBond[11];	-- 事故債券11
                		v_item.l_inItem052 := gKib[12];	-- 記番号12
                		v_item.l_inItem053 := gGanponShiYM[12];	-- 消滅年月12
                		v_item.l_inItem054 := gJiyuCode[12];	-- 事由コード12
                		v_item.l_inItem055 := gBond[12];	-- 事故債券12
                		v_item.l_inItem056 := gKib[13];	-- 記番号13
                		v_item.l_inItem057 := gGanponShiYM[13];	-- 消滅年月13
                		v_item.l_inItem058 := gJiyuCode[13];	-- 事由コード13
                		v_item.l_inItem059 := gBond[13];	-- 事故債券13
                		v_item.l_inItem060 := gKib[14];	-- 記番号14
                		v_item.l_inItem061 := gGanponShiYM[14];	-- 消滅年月14
                		v_item.l_inItem062 := gJiyuCode[14];	-- 事由コード14
                		v_item.l_inItem063 := gBond[14];	-- 事故債券14
                		v_item.l_inItem064 := gKib[15];	-- 記番号15
                		v_item.l_inItem065 := gGanponShiYM[15];	-- 消滅年月15
                		v_item.l_inItem066 := gJiyuCode[15];	-- 事由コード15
                		v_item.l_inItem067 := gBond[15];	-- 事故債券15
                		v_item.l_inItem068 := gKib[16];	-- 記番号16
                		v_item.l_inItem069 := gGanponShiYM[16];	-- 消滅年月16
                		v_item.l_inItem070 := gJiyuCode[16];	-- 事由コード16
                		v_item.l_inItem071 := gBond[16];	-- 事故債券16
                		v_item.l_inItem072 := gKib[17];	-- 記番号17
                		v_item.l_inItem073 := gGanponShiYM[17];	-- 消滅年月17
                		v_item.l_inItem074 := gJiyuCode[17];	-- 事由コード17
                		v_item.l_inItem075 := gBond[17];	-- 事故債券17
                		v_item.l_inItem076 := gKib[18];	-- 記番18
                		v_item.l_inItem077 := gGanponShiYM[18];	-- 消滅年月18
                		v_item.l_inItem078 := gJiyuCode[18];	-- 事由コード18
                		v_item.l_inItem079 := gBond[18];	-- 事故債券18
                		v_item.l_inItem080 := gKib[19];	-- 記番号19
                		v_item.l_inItem081 := gGanponShiYM[19];	-- 消滅年月19
                		v_item.l_inItem082 := gJiyuCode[19];	-- 事由コード19
                		v_item.l_inItem083 := gBond[19];	-- 事故債券19
                		v_item.l_inItem084 := gKib[20];	-- 記番号20
                		v_item.l_inItem085 := gGanponShiYM[20];	-- 消滅年月20
                		v_item.l_inItem086 := gJiyuCode[20];	-- 事由コード20
                		v_item.l_inItem087 := gBond[20];	-- 事故債券20
                		v_item.l_inItem088 := gKib[21];	-- 記番号21
                		v_item.l_inItem089 := gGanponShiYM[21];	-- 消滅年月21
                		v_item.l_inItem090 := gJiyuCode[21];	-- 事由コード21
                		v_item.l_inItem091 := gBond[21];	-- 事故債券21
                		v_item.l_inItem092 := gKib[22];	-- 記番号22
                		v_item.l_inItem093 := gGanponShiYM[22];	-- 消滅年月22
                		v_item.l_inItem094 := gJiyuCode[22];	-- 事由コード22
                		v_item.l_inItem095 := gBond[22];	-- 事故債券22
                		v_item.l_inItem096 := gKib[23];	-- 記番号23
                		v_item.l_inItem097 := gGanponShiYM[23];	-- 消滅年月23
                		v_item.l_inItem098 := gJiyuCode[23];	-- 事由コード23
                		v_item.l_inItem099 := gBond[23];	-- 事故債券23
                		v_item.l_inItem100 := gKib[24];	-- 記番号24
                		v_item.l_inItem101 := gGanponShiYM[24];	-- 消滅年月24
                		v_item.l_inItem102 := gJiyuCode[24];	-- 事由コード24
                		v_item.l_inItem103 := gBond[24];	-- 事故債券24
                		v_item.l_inItem104 := gKib[25];	-- 記番号25
                		v_item.l_inItem105 := gGanponShiYM[25];	-- 消滅年月25
                		v_item.l_inItem106 := gJiyuCode[25];	-- 事由コード25
                		v_item.l_inItem107 := gBond[25];	-- 事故債券25
                		v_item.l_inItem108 := gKib[26];	-- 記番号26
                		v_item.l_inItem109 := gGanponShiYM[26];	-- 消滅年月26
                		v_item.l_inItem110 := gJiyuCode[26];	-- 事由コード26
                		v_item.l_inItem111 := gBond[26];	-- 事故債券26
                		v_item.l_inItem112 := gKib[27];	-- 記番号27
                		v_item.l_inItem113 := gGanponShiYM[27];	-- 消滅年月27
                		v_item.l_inItem114 := gJiyuCode[27];	-- 事由コード27
                		v_item.l_inItem115 := gBond[27];	-- 事故債券27
                		v_item.l_inItem116 := gKib[28];	-- 記番号28
                		v_item.l_inItem117 := gGanponShiYM[28];	-- 消滅年月28
                		v_item.l_inItem118 := gJiyuCode[28];	-- 事由コード28
                		v_item.l_inItem119 := gBond[28];	-- 事故債券28
                		v_item.l_inItem120 := gKib[29];	-- 記番号29
                		v_item.l_inItem121 := gGanponShiYM[29];	-- 消滅年月29
                		v_item.l_inItem122 := gJiyuCode[29];	-- 事由コード29
                		v_item.l_inItem123 := gBond[29];	-- 事故債券29
                		v_item.l_inItem124 := gKib[30];	-- 記番号30
                		v_item.l_inItem125 := gGanponShiYM[30];	-- 消滅年月30
                		v_item.l_inItem126 := gJiyuCode[30];	-- 事由コード30
                		v_item.l_inItem127 := gBond[30];	-- 事故債券30
                		v_item.l_inItem128 := gKib[31];	-- 記番号31
                		v_item.l_inItem129 := gGanponShiYM[31];	-- 消滅年月31
                		v_item.l_inItem130 := gJiyuCode[31];	-- 事由コード31
                		v_item.l_inItem131 := gBond[31];	-- 事故債券31
                		v_item.l_inItem132 := gKib[32];	-- 記番号32
                		v_item.l_inItem133 := gGanponShiYM[32];	-- 消滅年月32
                		v_item.l_inItem134 := gJiyuCode[32];	-- 事由コード32
                		v_item.l_inItem135 := gBond[32];	-- 事故債券32
                		v_item.l_inItem136 := gKib[33];	-- 記番号33
                		v_item.l_inItem137 := gGanponShiYM[33];	-- 消滅年月33
                		v_item.l_inItem138 := gJiyuCode[33];	-- 事由コード33
                		v_item.l_inItem139 := gBond[33];	-- 事故債券33
		
                		-- Call pkPrint.insertData with composite type
                				-- Clear composite type
                		v_item := ROW();
		
		
                		-- Call pkPrint.insertData with composite type
                		CALL pkPrint.insertData(
                			l_inKeyCd		=> l_inItakuKaishaCd,
                			l_inUserId		=> l_inUserId,
                			l_inChohyoKbn	=> l_inChohyoKbn,
                			l_inSakuseiYmd	=> l_inGyomuYmd,
                			l_inChohyoId	=> gREPORT_ID,
                			l_inSeqNo		=> gSeqNo,
                			l_inHeaderFlg	=> '1',
                			l_inItem		=> v_item,
                			l_inKousinId	=> l_inUserId,
                			l_inSakuseiId	=> l_inUserId
                		);
                            gKensuCount := 0;
                    gMgr := reMeisai.MGR;                    -- 銘柄コード
                    gKaigo := reMeisai.KAIGO;                -- 回号コード
                    gNm1 := reMeisai.NM1;                    -- 回号正式名称１
                    gNm2 := reMeisai.NM2;                    -- 回号正式名称２
                    gKen := reMeisai.KEN;                    -- 券種コード
                    gNm := reMeisai.NM;                      -- 券種名称
                    gKib           := ARRAY[]::char(6)[];           --記番号XXリスト
                    gGanponShiYM   := ARRAY[]::char(8)[];   --消滅年月XXリスト
                    gJiyuCode      := ARRAY[]::char(1)[];      --事由コードXXリスト
                    gBond          := ARRAY[]::varchar(2)[];          --事故債券XXリスト
                    END IF;
                    IF gMgr <> reMeisai.MGR OR gKaigo <> reMeisai.KAIGO OR gKen <> reMeisai.KEN THEN
                            gSeqNo := gSeqNo + 1;
                    --対象データを帳表ワークテーブルへ出力する。
                    		-- Clear composite type
                		v_item := ROW();
		
                		v_item.l_inItem001 := gMgr;	-- 銘柄コード
                		v_item.l_inItem002 := gKaigo;	-- 回号コード
                		v_item.l_inItem003 := gNm1;	-- 回号正式名称１
                		v_item.l_inItem004 := gNm2;	-- 回号正式名称２
                		v_item.l_inItem005 := gKen;	-- 券種コード
                		v_item.l_inItem006 := gNm;	-- 券種名称
                		v_item.l_inItem007 := gTitle;	-- タイトル
                		v_item.l_inItem008 := gKib[1];	-- 記番号1
                		v_item.l_inItem009 := gGanponShiYM[1];	-- 消滅年月1
                		v_item.l_inItem010 := gJiyuCode[1];	-- 事由コード1
                		v_item.l_inItem011 := gBond[1];	-- 事故債券1
                		v_item.l_inItem012 := gKib[2];	-- 記番号2
                		v_item.l_inItem013 := gGanponShiYM[2];	-- 消滅年月2
                		v_item.l_inItem014 := gJiyuCode[2];	-- 事由コード2
                		v_item.l_inItem015 := gBond[2];	-- 事故債券2
                		v_item.l_inItem016 := gKib[3];	-- 記番号3
                		v_item.l_inItem017 := gGanponShiYM[3];	-- 消滅年月3
                		v_item.l_inItem018 := gJiyuCode[3];	-- 事由コード3
                		v_item.l_inItem019 := gBond[3];	-- 事故債券3
                		v_item.l_inItem020 := gKib[4];	-- 記番号4
                		v_item.l_inItem021 := gGanponShiYM[4];	-- 消滅年月4
                		v_item.l_inItem022 := gJiyuCode[4];	-- 事由コード4
                		v_item.l_inItem023 := gBond[4];	-- 事故債券4
                		v_item.l_inItem024 := gKib[5];	-- 記番号5
                		v_item.l_inItem025 := gGanponShiYM[5];	-- 消滅年月5
                		v_item.l_inItem026 := gJiyuCode[5];	-- 事由コード5
                		v_item.l_inItem027 := gBond[5];	-- 事故債券5
                		v_item.l_inItem028 := gKib[6];	-- 記番号6
                		v_item.l_inItem029 := gGanponShiYM[6];	-- 消滅年月6
                		v_item.l_inItem030 := gJiyuCode[6];	-- 事由コード6
                		v_item.l_inItem031 := gBond[6];	-- 事故債券6
                		v_item.l_inItem032 := gKib[7];	-- 記番号7
                		v_item.l_inItem033 := gGanponShiYM[7];	-- 消滅年月7
                		v_item.l_inItem034 := gJiyuCode[7];	-- 事由コード7
                		v_item.l_inItem035 := gBond[7];	-- 事故債券7
                		v_item.l_inItem036 := gKib[8];	-- 記番号8
                		v_item.l_inItem037 := gGanponShiYM[8];	-- 消滅年月8
                		v_item.l_inItem038 := gJiyuCode[8];	-- 事由コード8
                		v_item.l_inItem039 := gBond[8];	-- 事故債券8
                		v_item.l_inItem040 := gKib[9];	-- 記番号9
                		v_item.l_inItem041 := gGanponShiYM[9];	-- 消滅年月9
                		v_item.l_inItem042 := gJiyuCode[9];	-- 事由コード9
                		v_item.l_inItem043 := gBond[9];	-- 事故債券9
                		v_item.l_inItem044 := gKib[10];	-- 記番号10
                		v_item.l_inItem045 := gGanponShiYM[10];	-- 消滅年月10
                		v_item.l_inItem046 := gJiyuCode[10];	-- 事由コード10
                		v_item.l_inItem047 := gBond[10];	-- 事故債券10
                		v_item.l_inItem048 := gKib[11];	-- 記番号11
                		v_item.l_inItem049 := gGanponShiYM[11];	-- 消滅年月11
                		v_item.l_inItem050 := gJiyuCode[11];	-- 事由コード11
                		v_item.l_inItem051 := gBond[11];	-- 事故債券11
                		v_item.l_inItem052 := gKib[12];	-- 記番号12
                		v_item.l_inItem053 := gGanponShiYM[12];	-- 消滅年月12
                		v_item.l_inItem054 := gJiyuCode[12];	-- 事由コード12
                		v_item.l_inItem055 := gBond[12];	-- 事故債券12
                		v_item.l_inItem056 := gKib[13];	-- 記番号13
                		v_item.l_inItem057 := gGanponShiYM[13];	-- 消滅年月13
                		v_item.l_inItem058 := gJiyuCode[13];	-- 事由コード13
                		v_item.l_inItem059 := gBond[13];	-- 事故債券13
                		v_item.l_inItem060 := gKib[14];	-- 記番号14
                		v_item.l_inItem061 := gGanponShiYM[14];	-- 消滅年月14
                		v_item.l_inItem062 := gJiyuCode[14];	-- 事由コード14
                		v_item.l_inItem063 := gBond[14];	-- 事故債券14
                		v_item.l_inItem064 := gKib[15];	-- 記番号15
                		v_item.l_inItem065 := gGanponShiYM[15];	-- 消滅年月15
                		v_item.l_inItem066 := gJiyuCode[15];	-- 事由コード15
                		v_item.l_inItem067 := gBond[15];	-- 事故債券15
                		v_item.l_inItem068 := gKib[16];	-- 記番号16
                		v_item.l_inItem069 := gGanponShiYM[16];	-- 消滅年月16
                		v_item.l_inItem070 := gJiyuCode[16];	-- 事由コード16
                		v_item.l_inItem071 := gBond[16];	-- 事故債券16
                		v_item.l_inItem072 := gKib[17];	-- 記番号17
                		v_item.l_inItem073 := gGanponShiYM[17];	-- 消滅年月17
                		v_item.l_inItem074 := gJiyuCode[17];	-- 事由コード17
                		v_item.l_inItem075 := gBond[17];	-- 事故債券17
                		v_item.l_inItem076 := gKib[18];	-- 記番18
                		v_item.l_inItem077 := gGanponShiYM[18];	-- 消滅年月18
                		v_item.l_inItem078 := gJiyuCode[18];	-- 事由コード18
                		v_item.l_inItem079 := gBond[18];	-- 事故債券18
                		v_item.l_inItem080 := gKib[19];	-- 記番号19
                		v_item.l_inItem081 := gGanponShiYM[19];	-- 消滅年月19
                		v_item.l_inItem082 := gJiyuCode[19];	-- 事由コード19
                		v_item.l_inItem083 := gBond[19];	-- 事故債券19
                		v_item.l_inItem084 := gKib[20];	-- 記番号20
                		v_item.l_inItem085 := gGanponShiYM[20];	-- 消滅年月20
                		v_item.l_inItem086 := gJiyuCode[20];	-- 事由コード20
                		v_item.l_inItem087 := gBond[20];	-- 事故債券20
                		v_item.l_inItem088 := gKib[21];	-- 記番号21
                		v_item.l_inItem089 := gGanponShiYM[21];	-- 消滅年月21
                		v_item.l_inItem090 := gJiyuCode[21];	-- 事由コード21
                		v_item.l_inItem091 := gBond[21];	-- 事故債券21
                		v_item.l_inItem092 := gKib[22];	-- 記番号22
                		v_item.l_inItem093 := gGanponShiYM[22];	-- 消滅年月22
                		v_item.l_inItem094 := gJiyuCode[22];	-- 事由コード22
                		v_item.l_inItem095 := gBond[22];	-- 事故債券22
                		v_item.l_inItem096 := gKib[23];	-- 記番号23
                		v_item.l_inItem097 := gGanponShiYM[23];	-- 消滅年月23
                		v_item.l_inItem098 := gJiyuCode[23];	-- 事由コード23
                		v_item.l_inItem099 := gBond[23];	-- 事故債券23
                		v_item.l_inItem100 := gKib[24];	-- 記番号24
                		v_item.l_inItem101 := gGanponShiYM[24];	-- 消滅年月24
                		v_item.l_inItem102 := gJiyuCode[24];	-- 事由コード24
                		v_item.l_inItem103 := gBond[24];	-- 事故債券24
                		v_item.l_inItem104 := gKib[25];	-- 記番号25
                		v_item.l_inItem105 := gGanponShiYM[25];	-- 消滅年月25
                		v_item.l_inItem106 := gJiyuCode[25];	-- 事由コード25
                		v_item.l_inItem107 := gBond[25];	-- 事故債券25
                		v_item.l_inItem108 := gKib[26];	-- 記番号26
                		v_item.l_inItem109 := gGanponShiYM[26];	-- 消滅年月26
                		v_item.l_inItem110 := gJiyuCode[26];	-- 事由コード26
                		v_item.l_inItem111 := gBond[26];	-- 事故債券26
                		v_item.l_inItem112 := gKib[27];	-- 記番号27
                		v_item.l_inItem113 := gGanponShiYM[27];	-- 消滅年月27
                		v_item.l_inItem114 := gJiyuCode[27];	-- 事由コード27
                		v_item.l_inItem115 := gBond[27];	-- 事故債券27
                		v_item.l_inItem116 := gKib[28];	-- 記番号28
                		v_item.l_inItem117 := gGanponShiYM[28];	-- 消滅年月28
                		v_item.l_inItem118 := gJiyuCode[28];	-- 事由コード28
                		v_item.l_inItem119 := gBond[28];	-- 事故債券28
                		v_item.l_inItem120 := gKib[29];	-- 記番号29
                		v_item.l_inItem121 := gGanponShiYM[29];	-- 消滅年月29
                		v_item.l_inItem122 := gJiyuCode[29];	-- 事由コード29
                		v_item.l_inItem123 := gBond[29];	-- 事故債券29
                		v_item.l_inItem124 := gKib[30];	-- 記番号30
                		v_item.l_inItem125 := gGanponShiYM[30];	-- 消滅年月30
                		v_item.l_inItem126 := gJiyuCode[30];	-- 事由コード30
                		v_item.l_inItem127 := gBond[30];	-- 事故債券30
                		v_item.l_inItem128 := gKib[31];	-- 記番号31
                		v_item.l_inItem129 := gGanponShiYM[31];	-- 消滅年月31
                		v_item.l_inItem130 := gJiyuCode[31];	-- 事由コード31
                		v_item.l_inItem131 := gBond[31];	-- 事故債券31
                		v_item.l_inItem132 := gKib[32];	-- 記番号32
                		v_item.l_inItem133 := gGanponShiYM[32];	-- 消滅年月32
                		v_item.l_inItem134 := gJiyuCode[32];	-- 事由コード32
                		v_item.l_inItem135 := gBond[32];	-- 事故債券32
                		v_item.l_inItem136 := gKib[33];	-- 記番号33
                		v_item.l_inItem137 := gGanponShiYM[33];	-- 消滅年月33
                		v_item.l_inItem138 := gJiyuCode[33];	-- 事由コード33
                		v_item.l_inItem139 := gBond[33];	-- 事故債券33
		
                		-- Call pkPrint.insertData with composite type
                				-- Clear composite type
                		v_item := ROW();
		
		
                		-- Call pkPrint.insertData with composite type
                		CALL pkPrint.insertData(
                			l_inKeyCd		=> l_inItakuKaishaCd,
                			l_inUserId		=> l_inUserId,
                			l_inChohyoKbn	=> l_inChohyoKbn,
                			l_inSakuseiYmd	=> l_inGyomuYmd,
                			l_inChohyoId	=> gREPORT_ID,
                			l_inSeqNo		=> gSeqNo,
                			l_inHeaderFlg	=> '1',
                			l_inItem		=> v_item,
                			l_inKousinId	=> l_inUserId,
                			l_inSakuseiId	=> l_inUserId
                		);
                            gKensuCount := 0;
                    gMgr := reMeisai.MGR;                    -- 銘柄コード
                    gKaigo := reMeisai.KAIGO;                -- 回号コード
                    gNm1 := reMeisai.NM1;                    -- 回号正式名称１
                    gNm2 := reMeisai.NM2;                    -- 回号正式名称２
                    gKen := reMeisai.KEN;                    -- 券種コード
                    gNm := reMeisai.NM;                      -- 券種名称
                    gKib           := ARRAY[]::char(6)[];           --記番号XXリスト
                    gGanponShiYM   := ARRAY[]::char(8)[];   --消滅年月XXリスト
                    gJiyuCode      := ARRAY[]::char(1)[];      --事由コードXXリスト
                    gBond          := ARRAY[]::varchar(2)[];          --事故債券XXリスト
                    END IF;
                    gKensuCount := gKensuCount + 1;
                    --記番号XXリスト
                    gKib[gKensuCount] := reMeisai.KIB;
                    --消滅年月XXリスト
                    IF reMeisai.YMD = ' ' THEN
                        gGanponShiYM[gKensuCount] := NULL;
                    ELSE
                        gGanponShiYM[gKensuCount] := SUBSTR(reMeisai.YMD,3,2) || '/' || SUBSTR(reMeisai.YMD,5,2);
                    END IF;
                    --事由コードXXリスト
                    IF reMeisai.GAN = '0' AND (trim(both reMeisai.YMD) IS NOT NULL AND (trim(both reMeisai.YMD))::text <> '') THEN
                        gJiyuCode[gKensuCount] := '1';
                    ELSIF reMeisai.GAN = '4' THEN
                        gJiyuCode[gKensuCount] := '2';
                    ELSIF reMeisai.GAN = '5' THEN
                        gJiyuCode[gKensuCount] := '3';
                    ELSIF reMeisai.GAN = '3' OR reMeisai.GAN = '2' THEN
                        gJiyuCode[gKensuCount] := '4';
                    ELSIF reMeisai.GAN = 'F' AND reMeisai.WAR = 'F' THEN
                        gJiyuCode[gKensuCount] := '5';
                    ELSE
                        gJiyuCode[gKensuCount] := ' ';
                    END IF;
                    --事故債券XXリスト
                    IF reMeisai.GAN = '1' OR reMeisai.GAN = '3' OR reMeisai.GAN = '2' THEN
                        gBond[gKensuCount] := '*';
                    ELSE
                        gBond[gKensuCount] := ' ';
                    END IF;
                FETCH curMeisai2 INTO recMeisai; -- カーソルの内容をフェッチする
            END LOOP;
            CLOSE curMeisai2;
        END IF;
    END LOOP;
    -- 正常終了処理
    l_outSqlCode    := gRtnCd;
    l_outSqlErrM    := '';
    -- 終了処理
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
        l_outSqlCode := pkconstant.FATAL();
        l_outSqlErrM := SQLERRM;
        CALL pkLog.debug(l_inUserId, CHOHYOID1, '×' || C_PROCEDURE_ID || ' END（例外発生）');
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi002k14r01 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_inYmdBe text, l_inYmdBe1 text, l_inYmdBe2 text, l_inKaiGoCd text, l_inHktCd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;
