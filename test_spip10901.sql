-- Test wrapper for SPIP10901
-- Create wrapper function that calls SPIP10901 procedure

DROP FUNCTION IF EXISTS test_spip10901() CASCADE;

CREATE OR REPLACE FUNCTION test_spip10901(
    p_mgr_cd TEXT DEFAULT '0005',
    p_itaku_kaisha_cd TEXT DEFAULT '0005', 
    p_chohyo_kbn TEXT DEFAULT '0'
) RETURNS INTEGER AS $$
DECLARE
    v_sqlcode INTEGER := 0;
    v_sqlerrm TEXT := '';
    v_user_id TEXT := 'TESTUSER';
    v_gyomu_ymd TEXT := '20070521';
BEGIN
    -- Call the SPIP10901 procedure
    CALL rh_mufg_ipa.spip10901(
        p_mgr_cd,                -- l_inMgrCd
        p_itaku_kaisha_cd,       -- l_inItakuKaishaCd  
        v_user_id,               -- l_inUserId
        p_chohyo_kbn,            -- l_inChohyoKbn
        v_gyomu_ymd,             -- l_inGyomuYmd
        v_sqlcode,               -- l_outSqlCode
        v_sqlerrm                -- l_outSqlErrM
    );
    
    -- Log the result
    RAISE NOTICE 'SPIP10901 Result: sqlcode=%, errmsg=%', v_sqlcode, substring(v_sqlerrm, 1, 100);
    
    -- Return the result code
    RETURN v_sqlcode;
END;
$$ LANGUAGE plpgsql;
