-- Direct test for srsq-5658.SPIPI044K00R01.sql
-- Test calling the procedure to return code 0 (RTN_OK)

-- Check if there's any MGR_KIHON data we can use
SELECT 
    itaku_kaisha_cd,
    mgr_cd,
    isin_cd,
    jtk_kbn,
    tokurei_shasai_flg,
    kk_kanyo_flg,
    partmgr_kbn
FROM mgr_kihon
WHERE isin_cd <> ' '
  AND kk_kanyo_flg IN ('0','1')
  AND jtk_kbn NOT IN ('2','5')
  AND partmgr_kbn IN ('0','2')
LIMIT 5;

-- Test with first available data
DO $$
DECLARE
    v_itaku_kaisha_cd TEXT;
    v_mgr_cd TEXT;
    v_user_id TEXT := 'TEST01';
    v_chohyo_kbn TEXT := '0';
    v_gyomu_ymd TEXT := '20260129';
    v_sql_code INTEGER;
    v_sql_errm TEXT;
    v_count INTEGER;
BEGIN
    -- Get first available MGR_KIHON record
    SELECT 
        itaku_kaisha_cd,
        mgr_cd
    INTO v_itaku_kaisha_cd, v_mgr_cd
    FROM mgr_kihon
    WHERE isin_cd <> ' '
      AND kk_kanyo_flg IN ('0','1')
      AND jtk_kbn NOT IN ('2','5')
      AND partmgr_kbn IN ('0','2')
    LIMIT 1;
    
    IF v_itaku_kaisha_cd IS NULL THEN
        RAISE NOTICE 'No suitable MGR_KIHON data found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Testing srsq-5658.SPIPI044K00R01';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'ITAKU_KAISHA_CD: %', v_itaku_kaisha_cd;
    RAISE NOTICE 'MGR_CD: %', v_mgr_cd;
    RAISE NOTICE '';
    
    -- Clear previous test data
    DELETE FROM genbo_work 
    WHERE itaku_kaisha_cd = v_itaku_kaisha_cd 
      AND isin_cd IN (SELECT isin_cd FROM mgr_kihon WHERE itaku_kaisha_cd = v_itaku_kaisha_cd AND mgr_cd = v_mgr_cd);
    
    -- Call the procedure
    CALL spipi044k00r01(
        v_itaku_kaisha_cd,
        v_user_id,
        v_chohyo_kbn,
        v_gyomu_ymd,
        v_mgr_cd,
        v_sql_code,
        v_sql_errm
    );
    
    RAISE NOTICE '';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Test Result';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Return code: % (Expected: 0 = RTN_OK)', v_sql_code;
    RAISE NOTICE 'Error message: %', COALESCE(v_sql_errm, '(empty)');
    
    -- Check inserted data
    SELECT COUNT(*) INTO v_count
    FROM genbo_work
    WHERE itaku_kaisha_cd = v_itaku_kaisha_cd
      AND sakusei_id = v_user_id;
    
    RAISE NOTICE 'Records inserted into GENBO_WORK: %', v_count;
    RAISE NOTICE '';
    
    IF v_sql_code = 0 THEN
        RAISE NOTICE '✓ PASSED: Procedure returned RTN_OK (0)';
        IF v_count > 0 THEN
            RAISE NOTICE '✓ PASSED: Data inserted into GENBO_WORK';
        ELSE
            RAISE NOTICE '⚠ WARNING: No data inserted (might be expected if no historical data)';
        END IF;
    ELSE
        RAISE NOTICE '✗ FAILED: Expected code 0, got %', v_sql_code;
        RAISE NOTICE '  Error: %', v_sql_errm;
    END IF;
    RAISE NOTICE '=================================================';
    
END $$;

-- Show sample of inserted data
SELECT 
    itaku_kaisha_cd,
    hkt_cd,
    isin_cd,
    gnrbarai_kjt,
    shokan_kbn,
    gensai_kngk,
    genzon_kngk,
    meimoku_zndk
FROM genbo_work
WHERE sakusei_id = 'TEST01'
ORDER BY gnrbarai_kjt
LIMIT 10;
