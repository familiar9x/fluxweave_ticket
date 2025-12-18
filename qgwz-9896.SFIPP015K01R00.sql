-- Main function SFIPP015K01R00
-- Bond settlement system linkage data (non-institutional method)

CREATE OR REPLACE FUNCTION SFIPP015K01R00()
RETURNS integer AS $body$
DECLARE
    /* Return code */
    result integer;
    /* Function ID */
    SP_ID CONSTANT text := 'SFIPP015K01R00';
    /* User ID */
    USER_ID varchar(10);
    /* Constants */
    KOBETSU_SHONIN_HIKANYO CONSTANT text := 'A';
    KK_KANYO_FLG_HIKANYO CONSTANT text := '2';
    DVP_KBN_NOT_DVP CONSTANT text := '0';
    DEFAULT_SPACE CONSTANT text := ' ';
    DEFAULT_TSUKA_CD CONSTANT text := 'JPY';
    OP_OPTION_CD CONSTANT text := 'IPP1003302020';
    OP_OPTION_FLG CONSTANT text := '1';
    KNJ_FLG CONSTANT text := ' ';
    MASSHO_STATE CONSTANT text := ' ';
    TAX_KBN CONSTANT text := '85';
    KOZA_JIKOGUTI CONSTANT text := '00';
    
    /* Variables */
    gShrYmd text;
    gBefShrYmd text;
    gTimeStamp timestamp := TO_TIMESTAMP(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.FF6');
    gShrKbn text;
    gRecCnt integer := 0;
    gInsertCnt integer := 0;
    
    /* Variables for key tracking */
    key_itaku_kaisha_cd text := '';
    key_mgr_cd text := '';
    key_fin_sec_kbn text := '';
    key_bank_cd text := '';
    key_koza_kbn text := '';
    key_aite_bcd text := '';
    key_aite_scd text := '';
    
    /* Variables for calculation */
    calc_zeihiki_bef numeric := 0;
    calc_zeihiki_aft numeric := 0;
    calc_koku_zei numeric := 0;
    calc_chiho_zei numeric := 0;
    calc_shokan_seikyu numeric := 0;
    calc_gnr_zndk numeric := 0;
    
    /* Variables for summary */
    sum_gzeihiki_bef numeric := 0;
    sum_gzei numeric := 0;
    sum_zeihiki_aft numeric := 0;
    sum_shokan_seikyu numeric := 0;
    sum_gnr_zndk numeric := 0;
    
    /* Cursor record */
    rSeikyu record;

BEGIN
    USER_ID := pkConstant.BATCH_USER();
    CALL pkLog.debug(USER_ID, SP_ID, '機構非関与銘柄元利金請求データ（実質記番号方式）作成 START');
    
    /* Get payment date (business date + 2 business days) */
    gShrYmd := pkDate.getPlusDateBusiness(pkDate.getGyomuYmd(), 2);
    
    /* Get payment date - 1 day */
    gBefShrYmd := pkDate.getMinusDate(gShrYmd, 1);
    
    /* Main cursor loop */
    FOR rSeikyu IN (
        SELECT DISTINCT
            VMG1.ITAKU_KAISHA_CD,
            VMG1.MGR_CD,
            MG2.RBR_YMD,
            P05.TRHK_CD,
            SUBSTR(P05.TRHK_CD, 10, 2) AS TRHK_SORT,
            COALESCE((SELECT M93.CTL_VALUE FROM MPROCESS_CTL M93
                WHERE VJ1.KAIIN_ID = M93.KEY_CD AND M93.CTL_SHUBETSU = 'SFIPP015K01R001'),
                VJ1.OWN_FINANCIAL_SECURITIES_KBN) AS FINANCIAL_SECURITIES_KBN,
            COALESCE((SELECT M93.CTL_VALUE FROM MPROCESS_CTL M93
                WHERE VJ1.KAIIN_ID = M93.KEY_CD AND M93.CTL_SHUBETSU = 'SFIPP015K01R002'),
                VJ1.OWN_BANK_CD) AS BANK_CD,
            COALESCE((SELECT M93.CTL_VALUE FROM MPROCESS_CTL M93
                WHERE VJ1.KAIIN_ID = M93.KEY_CD AND M93.CTL_SHUBETSU = 'SFIPP015K01R003'),
                KOZA_JIKOGUTI) AS KOZA_KBN,
            VJ1.SKN_KESSAI_CD,
            MG2.RBR_KJT,
            pkIpaZndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, gBefShrYmd, '7')::numeric AS OSAE_KNGK
        FROM MGR_KIHON_VIEW VMG1,
            KBG_SHOKBG P02,
            KBG_MTORISAKI P05,
            MGR_RBRKIJ MG2,
            VJIKO_ITAKU VJ1
        WHERE P02.ITAKU_KAISHA_CD = P05.ITAKU_KAISHA_CD
            AND P02.TRHK_CD = P05.TRHK_CD
            AND P05.TRHK_ZOKUSEI <> '3'
            AND P02.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
            AND P02.MGR_CD = MG2.MGR_CD
            AND (P02.SHOKAN_KJT >= MG2.RBR_KJT OR TRIM(P02.SHOKAN_KJT) IS NULL)
            AND MG2.RBR_YMD = gShrYmd
            AND VMG1.KK_KANYO_FLG = KK_KANYO_FLG_HIKANYO
            AND P02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
            AND P02.MGR_CD = VMG1.MGR_CD
            AND P02.ITAKU_KAISHA_CD IN (
                SELECT VJ1.KAIIN_ID FROM MOPTION_KANRI O1
                WHERE VJ1.KAIIN_ID = O1.KEY_CD
                    AND O1.OPTION_CD = OP_OPTION_CD
                    AND O1.OPTION_FLG = OP_OPTION_FLG)
            AND NOT EXISTS (SELECT 1 FROM KIKIN_SEIKYU K01
                WHERE K01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                    AND K01.MGR_CD = VMG1.MGR_CD
                    AND K01.SHR_YMD = gShrYmd)
            AND NOT EXISTS (SELECT 1 FROM KIKIN_SEIKYU2 K02
                WHERE K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                    AND K02.MGR_CD = VMG1.MGR_CD
                    AND K02.SHR_YMD = gShrYmd)
            AND (0 <> pkIpaZndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, gBefShrYmd, '2')::numeric)
        ORDER BY VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, TRHK_SORT
    ) LOOP
        /* Key break processing */
        IF key_itaku_kaisha_cd <> rSeikyu.ITAKU_KAISHA_CD
            OR key_mgr_cd <> rSeikyu.MGR_CD
            OR key_koza_kbn <> rSeikyu.KOZA_KBN THEN
            
            IF gRecCnt > 0 THEN
                /* Insert request data */
                gInsertCnt := gInsertCnt + 1;
                
                INSERT INTO KIKIN_SEIKYU(
                    ITAKU_KAISHA_CD, MGR_CD, SHR_YMD, TSUKA_CD,
                    FINANCIAL_SECURITIES_KBN, BANK_CD, KOZA_KBN, TAX_KBN,
                    GZEIHIKI_BEF_CHOKYU_KNGK, GZEI_KNGK, GZEIHIKI_AFT_CHOKYU_KNGK,
                    SHOKAN_SEIKYU_KNGK, AITE_SKN_KESSAI_BCD, AITE_SKN_KESSAI_SCD,
                    KESSAI_NO, KOBETSU_SHONIN_SAIYO_FLG, KK_KANYO_UMU_FLG,
                    DVP_KBN, GNR_ZNDK, MASSHO_STATE, SHORI_KBN,
                    KOUSIN_ID, SAKUSEI_DT, SAKUSEI_ID)
                VALUES (
                    key_itaku_kaisha_cd, key_mgr_cd, gShrYmd, DEFAULT_TSUKA_CD,
                    key_fin_sec_kbn, key_bank_cd, key_koza_kbn, TAX_KBN,
                    sum_gzeihiki_bef, sum_gzei, sum_zeihiki_aft,
                    sum_shokan_seikyu, key_aite_bcd, key_aite_scd,
                    DEFAULT_SPACE, KOBETSU_SHONIN_HIKANYO, KK_KANYO_FLG_HIKANYO,
                    DVP_KBN_NOT_DVP, sum_gnr_zndk, MASSHO_STATE, gShrKbn,
                    USER_ID, gTimeStamp, USER_ID);
                
                INSERT INTO KIKIN_SEIKYU2(
                    ITAKU_KAISHA_CD, MGR_CD, SHR_YMD, TSUKA_CD,
                    FINANCIAL_SECURITIES_KBN, BANK_CD, KOZA_KBN, TAX_KBN, KNJ_FLG,
                    GZEIHIKI_BEF_CHOKYU_KNGK, GZEI_KNGK, GZEIHIKI_AFT_CHOKYU_KNGK,
                    SHOKAN_SEIKYU_KNGK, AITE_SKN_KESSAI_BCD, AITE_SKN_KESSAI_SCD,
                    KESSAI_NO, KOBETSU_SHONIN_SAIYO_FLG, KK_KANYO_UMU_FLG,
                    DVP_KBN, GNR_ZNDK, SHORI_KBN,
                    KOUSIN_ID, SAKUSEI_DT, SAKUSEI_ID)
                VALUES (
                    key_itaku_kaisha_cd, key_mgr_cd, gShrYmd, DEFAULT_TSUKA_CD,
                    key_fin_sec_kbn, key_bank_cd, key_koza_kbn, TAX_KBN, KNJ_FLG,
                    sum_gzeihiki_bef, sum_gzei, sum_zeihiki_aft,
                    sum_shokan_seikyu, key_aite_bcd, key_aite_scd,
                    DEFAULT_SPACE, KOBETSU_SHONIN_HIKANYO, KK_KANYO_FLG_HIKANYO,
                    DVP_KBN_NOT_DVP, sum_gnr_zndk, gShrKbn,
                    USER_ID, gTimeStamp, USER_ID);
                
                gRecCnt := 0;
            END IF;
            
            /* Set key information */
            key_itaku_kaisha_cd := rSeikyu.ITAKU_KAISHA_CD;
            key_mgr_cd := rSeikyu.MGR_CD;
            key_fin_sec_kbn := rSeikyu.FINANCIAL_SECURITIES_KBN;
            key_bank_cd := rSeikyu.BANK_CD;
            key_koza_kbn := rSeikyu.KOZA_KBN;
            key_aite_bcd := SUBSTR(rSeikyu.SKN_KESSAI_CD, 1, 4);
            key_aite_scd := SUBSTR(rSeikyu.SKN_KESSAI_CD, 5, 3);
            
            /* Clear summary area */
            sum_gzeihiki_bef := 0;
            sum_gzei := 0;
            sum_zeihiki_aft := 0;
            sum_shokan_seikyu := 0;
            sum_gnr_zndk := 0;
        END IF;
        
        /* Get tax amount by client - call Pkipakibango.calcZeigaku */
        IF Pkipakibango.calcZeigaku(
                rSeikyu.ITAKU_KAISHA_CD,
                rSeikyu.MGR_CD,
                rSeikyu.RBR_KJT,
                gBefShrYmd,
                rSeikyu.TRHK_CD,
                calc_zeihiki_bef,
                calc_zeihiki_aft,
                calc_koku_zei,
                calc_chiho_zei,
                '') <> pkconstant.success() THEN
            calc_zeihiki_bef := 0;
            calc_zeihiki_aft := 0;
            calc_koku_zei := 0;
            calc_chiho_zei := 0;
        END IF;
        
        /* Get principal amount by client */
        calc_shokan_seikyu := pkipakibango.getGankinTrhk(
            rSeikyu.ITAKU_KAISHA_CD,
            rSeikyu.MGR_CD,
            gShrYmd,
            rSeikyu.TRHK_CD);
        
        /* Get transfer bond standard balance by client */
        calc_gnr_zndk := pkipakibango.getKjnZndkTrhk(
            rSeikyu.ITAKU_KAISHA_CD,
            rSeikyu.MGR_CD,
            gBefShrYmd,
            rSeikyu.TRHK_CD);
        
        /* Aggregate */
        sum_gzeihiki_bef := sum_gzeihiki_bef + calc_zeihiki_bef;
        sum_gzei := sum_gzei + calc_koku_zei;
        sum_zeihiki_aft := sum_zeihiki_aft + (calc_zeihiki_bef - calc_koku_zei);
        sum_shokan_seikyu := sum_shokan_seikyu + calc_shokan_seikyu;
        sum_gnr_zndk := sum_gnr_zndk + calc_gnr_zndk;
        
        /* Set processing division */
        IF rSeikyu.OSAE_KNGK > 0 THEN
            gShrKbn := '0';
        ELSE
            gShrKbn := '1';
        END IF;
        
        /* Count records */
        gRecCnt := gRecCnt + 1;
    END LOOP;
    
    IF gRecCnt > 0 THEN
        /* Final insert */
        gInsertCnt := gInsertCnt + 1;
        
        INSERT INTO KIKIN_SEIKYU(
            ITAKU_KAISHA_CD, MGR_CD, SHR_YMD, TSUKA_CD,
            FINANCIAL_SECURITIES_KBN, BANK_CD, KOZA_KBN, TAX_KBN,
            GZEIHIKI_BEF_CHOKYU_KNGK, GZEI_KNGK, GZEIHIKI_AFT_CHOKYU_KNGK,
            SHOKAN_SEIKYU_KNGK, AITE_SKN_KESSAI_BCD, AITE_SKN_KESSAI_SCD,
            KESSAI_NO, KOBETSU_SHONIN_SAIYO_FLG, KK_KANYO_UMU_FLG,
            DVP_KBN, GNR_ZNDK, MASSHO_STATE, SHORI_KBN,
            KOUSIN_ID, SAKUSEI_DT, SAKUSEI_ID)
        VALUES (
            key_itaku_kaisha_cd, key_mgr_cd, gShrYmd, DEFAULT_TSUKA_CD,
            key_fin_sec_kbn, key_bank_cd, key_koza_kbn, TAX_KBN,
            sum_gzeihiki_bef, sum_gzei, sum_zeihiki_aft,
            sum_shokan_seikyu, key_aite_bcd, key_aite_scd,
            DEFAULT_SPACE, KOBETSU_SHONIN_HIKANYO, KK_KANYO_FLG_HIKANYO,
            DVP_KBN_NOT_DVP, sum_gnr_zndk, MASSHO_STATE, gShrKbn,
            USER_ID, gTimeStamp, USER_ID);
        
        INSERT INTO KIKIN_SEIKYU2(
            ITAKU_KAISHA_CD, MGR_CD, SHR_YMD, TSUKA_CD,
            FINANCIAL_SECURITIES_KBN, BANK_CD, KOZA_KBN, TAX_KBN, KNJ_FLG,
            GZEIHIKI_BEF_CHOKYU_KNGK, GZEI_KNGK, GZEIHIKI_AFT_CHOKYU_KNGK,
            SHOKAN_SEIKYU_KNGK, AITE_SKN_KESSAI_BCD, AITE_SKN_KESSAI_SCD,
            KESSAI_NO, KOBETSU_SHONIN_SAIYO_FLG, KK_KANYO_UMU_FLG,
            DVP_KBN, GNR_ZNDK, SHORI_KBN,
            KOUSIN_ID, SAKUSEI_DT, SAKUSEI_ID)
        VALUES (
            key_itaku_kaisha_cd, key_mgr_cd, gShrYmd, DEFAULT_TSUKA_CD,
            key_fin_sec_kbn, key_bank_cd, key_koza_kbn, TAX_KBN, KNJ_FLG,
            sum_gzeihiki_bef, sum_gzei, sum_zeihiki_aft,
            sum_shokan_seikyu, key_aite_bcd, key_aite_scd,
            DEFAULT_SPACE, KOBETSU_SHONIN_HIKANYO, KK_KANYO_FLG_HIKANYO,
            DVP_KBN_NOT_DVP, sum_gnr_zndk, gShrKbn,
            USER_ID, gTimeStamp, USER_ID);
    END IF;
    
    result := pkconstant.success();
    CALL pkLog.debug(USER_ID, SP_ID, '機構非関与銘柄元利金請求データ作成（実質記番号方式） END result=' || result);
    RETURN result;

EXCEPTION
    WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
        RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL;
