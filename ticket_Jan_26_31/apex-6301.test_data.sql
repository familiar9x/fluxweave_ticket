-- Test data for apex-6301.SPIPF014K01R03.sql
-- Testing scenario where no data is returned (0 records)

-- =====================================================
-- Test Case 1: No matching records in knjganrikichuif
-- =====================================================
-- This test should return RTN_NODATA (40) and insert "対象データなし"

-- Setup test parameters
DO $$
DECLARE
    v_itaku_kaisha_cd TEXT := 'TEST001';
    v_user_id TEXT := 'TESTUSER';
    v_chohyo_kbn TEXT := '0';
    v_gyomu_ymd TEXT := '20260127';
    v_shori_ymd TEXT := '20260127';
    v_sql_code INTEGER;
    v_sql_errm TEXT;
BEGIN
    -- Clear any existing test data
    DELETE FROM SREPORT_WK 
    WHERE KEY_CD = v_itaku_kaisha_cd 
      AND USER_ID = v_user_id 
      AND CHOHYO_KBN = v_chohyo_kbn;
    
    DELETE FROM knjganrikichuif
    WHERE ITAKU_KAISHA_CD = v_itaku_kaisha_cd
      AND KNJ_SHORI_YMD = v_shori_ymd;
    
    -- Ensure vjiko_itaku has test company (optional - for testing vItakuKaishaRnm)
    INSERT INTO vjiko_itaku (kaiin_id, jiko_daiko_kbn, bank_rnm)
    VALUES (v_itaku_kaisha_cd, '2', 'テスト会社')
    ON CONFLICT (kaiin_id, jiko_daiko_kbn) DO UPDATE 
    SET bank_rnm = 'テスト会社';
    
    -- No data in knjganrikichuif - this will cause 0 records in cursor
    
    RAISE NOTICE 'Test setup completed - knjganrikichuif has 0 matching records';
END $$;

-- Execute the procedure with test parameters
DO $$
DECLARE
    v_itaku_kaisha_cd TEXT := 'TEST001';
    v_user_id TEXT := 'TESTUSER';
    v_chohyo_kbn TEXT := '0';
    v_gyomu_ymd TEXT := '20260127';
    v_shori_ymd TEXT := '20260127';
    v_sql_code INTEGER;
    v_sql_errm TEXT;
BEGIN
    CALL spipf014k01r03(
        v_itaku_kaisha_cd,
        v_user_id,
        v_chohyo_kbn,
        v_gyomu_ymd,
        v_shori_ymd,
        v_sql_code,
        v_sql_errm
    );
    
    RAISE NOTICE 'Return code: %, Error message: %', v_sql_code, v_sql_errm;
    
    -- Expected: v_sql_code = 40 (RTN_NODATA)
    IF v_sql_code = 40 THEN
        RAISE NOTICE 'SUCCESS: Procedure returned RTN_NODATA as expected';
    ELSE
        RAISE NOTICE 'FAILED: Expected return code 40, got %', v_sql_code;
    END IF;
END $$;

-- Verify the result in SREPORT_WK
SELECT 
    KEY_CD,
    USER_ID,
    CHOHYO_KBN,
    SAKUSEI_YMD,
    CHOHYO_ID,
    SEQ_NO,
    ITEM027 as NO_DATA_MESSAGE,
    ITEM001 as USER_ID_IN_REPORT,
    ITEM003 as ITAKU_KAISHA_RNM
FROM SREPORT_WK
WHERE KEY_CD = 'TEST001'
  AND USER_ID = 'TESTUSER'
  AND CHOHYO_KBN = '0'
  AND SAKUSEI_YMD = '20260127'
  AND CHOHYO_ID = 'IPF30101411'
ORDER BY SEQ_NO;

-- Expected result: 
-- - One header record (HEADER_FLG = 0)
-- - One data record (HEADER_FLG = 1) with ITEM027 = '対象データなし'

-- =====================================================
-- Test Case 2: No matching vjiko_itaku record
-- =====================================================
-- This tests the scenario where vItakuKaishaRnm would be NULL

DO $$
DECLARE
    v_itaku_kaisha_cd TEXT := 'TEST002';
    v_user_id TEXT := 'TESTUSER';
    v_chohyo_kbn TEXT := '0';
    v_gyomu_ymd TEXT := '20260127';
    v_shori_ymd TEXT := '20260127';
    v_sql_code INTEGER;
    v_sql_errm TEXT;
BEGIN
    -- Clear any existing test data
    DELETE FROM SREPORT_WK 
    WHERE KEY_CD = v_itaku_kaisha_cd 
      AND USER_ID = v_user_id;
    
    DELETE FROM knjganrikichuif
    WHERE ITAKU_KAISHA_CD = v_itaku_kaisha_cd;
    
    -- Remove vjiko_itaku record to test NULL scenario
    DELETE FROM vjiko_itaku
    WHERE kaiin_id = v_itaku_kaisha_cd;
    
    RAISE NOTICE 'Test setup completed - vjiko_itaku has 0 matching records';
    
    -- Call procedure
    CALL spipf014k01r03(
        v_itaku_kaisha_cd,
        v_user_id,
        v_chohyo_kbn,
        v_gyomu_ymd,
        v_shori_ymd,
        v_sql_code,
        v_sql_errm
    );
    
    RAISE NOTICE 'Return code: %, Error message: %', v_sql_code, v_sql_errm;
    
    -- Check if ITEM003 (vItakuKaishaRnm) is NULL
    PERFORM 1 FROM SREPORT_WK
    WHERE KEY_CD = v_itaku_kaisha_cd
      AND USER_ID = v_user_id
      AND ITEM003 IS NULL;
    
    IF FOUND THEN
        RAISE NOTICE 'SUCCESS: vItakuKaishaRnm is NULL as expected when no vjiko_itaku record';
    ELSE
        RAISE NOTICE 'INFO: vItakuKaishaRnm has a value';
    END IF;
END $$;

-- =====================================================
-- Cleanup (optional)
-- =====================================================
-- Uncomment to clean up test data
/*
DELETE FROM SREPORT_WK WHERE KEY_CD IN ('TEST001', 'TEST002');
DELETE FROM knjganrikichuif WHERE ITAKU_KAISHA_CD IN ('TEST001', 'TEST002');
DELETE FROM vjiko_itaku WHERE kaiin_id IN ('TEST001', 'TEST002');
*/
