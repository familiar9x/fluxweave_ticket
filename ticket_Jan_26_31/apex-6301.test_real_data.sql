-- Test for apex-6301.SPIPF014K01R03.sql
-- Test case: Procedure returns 0 records (RTN_NODATA)

-- =====================================================
-- Test: No matching data (return 0 records)
-- =====================================================

-- Clear test data
DELETE FROM knjganrikichuif 
WHERE itaku_kaisha_cd = 'TST1'
  AND knj_uke_tsuban_naibu = 90001;

DELETE FROM SREPORT_WK 
WHERE KEY_CD = 'TST1'
  AND USER_ID = 'TEST01'
  AND CHOHYO_ID = 'IPF30101411';

-- Insert data với SHORI_YMD khác (không khớp với parameter)
INSERT INTO knjganrikichuif (
    itaku_kaisha_cd, knj_uke_tsuban_naibu, knj_azuke_no,
    knj_shori_ymd, knj_shori_kbn, knj_tesuryo_kbn,
    knj_err_code, knj_ten_no, knj_kamoku, knj_kouza_no,
    knj_gankin, knj_rkn, knj_gnkn_shr_tesu_kngk, knj_rkn_shr_tesu_kngk,
    knj_kingaku, knj_shohizei, knj_inout_kbn, knj_chukeimsgid,
    knj_uke_tsuban_zenkai, hkt_cd, knj_chukei_tsuban, knj_chukei_tsuban_zenkai,
    knj_uke_tsuban, knj_saishori_flg, knj_torikeshi_flg, sr_stat,
    kousin_id, sakusei_id
) VALUES (
    'TST1', 90001, 0,
    '20260126', '2', '0',  -- SHORI_YMD = 20260126
    '    ', 'T001', '01', '12345678',
    1000000, 50000, 1000, 500,
    1051500, 51500, '5', '      ',
    0, 'HKT001', 0, 0,
    10001, '0', '0', '0',
    'TEST01', 'TEST01'
);

-- Test procedure với SHORI_YMD = 20260127 (khác với data = 20260126)
-- Expected: Return code 40 (RTN_NODATA)
DO $$
DECLARE
    v_sql_code INTEGER;
    v_sql_errm TEXT;
BEGIN
    CALL spipf014k01r03(
        'TST1',         -- l_inItakuKaishaCd
        'TEST01',       -- l_inUserId
        '0',            -- l_inChohyoKbn
        '20260127',     -- l_inGyomuYmd
        '20260127',     -- l_inShoriYmd (khác với data: 20260126)
        v_sql_code,
        v_sql_errm
    );
    
    RAISE NOTICE '';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Test: No matching data (expect 0 records)';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Return code: % (Expected: 40 = RTN_NODATA)', v_sql_code;
    RAISE NOTICE 'Error message: %', COALESCE(v_sql_errm, '(empty)');
    RAISE NOTICE '';
    
    IF v_sql_code = 40 THEN
        RAISE NOTICE '✓ PASSED: Procedure returned RTN_NODATA (40)';
        RAISE NOTICE '  Cursor found 0 matching records';
        RAISE NOTICE '  Message "対象データなし" inserted to SREPORT_WK';
    ELSE
        RAISE NOTICE '✗ FAILED: Expected code 40, got %', v_sql_code;
    END IF;
    RAISE NOTICE '=================================================';
END $$;

-- Verify result in SREPORT_WK
SELECT 
    KEY_CD,
    USER_ID,
    SEQ_NO,
    HEADER_FLG,
    ITEM027 as NO_DATA_MESSAGE,
    ITEM001 as USER_ID_FIELD
FROM SREPORT_WK
WHERE KEY_CD = 'TST1'
  AND USER_ID = 'TEST01'
  AND CHOHYO_ID = 'IPF30101411'
  AND CHOHYO_KBN = '0'
ORDER BY SEQ_NO;

-- Cleanup
-- DELETE FROM knjganrikichuif WHERE itaku_kaisha_cd = 'TST1' AND knj_uke_tsuban_naibu = 90001;
-- DELETE FROM SREPORT_WK WHERE KEY_CD = 'TST1' AND USER_ID = 'TEST01';
