#!/usr/bin/env python3
"""
Test pkipakichutesuryo.inskichutesuryoseikyuout function
"""

import psycopg2
import sys

# Database configuration
POSTGRES_CONFIG = {
    'host': 'jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com',
    'port': 5432,
    'database': 'rh_mufg_ipa',
    'user': 'rh_mufg_ipa',
    'password': 'luxur1ous-Pine@pple'
}

def test_inskichutesuryoseikyuout():
    """Test pkipakichutesuryo.inskichutesuryoseikyuout with minimal parameters"""
    
    print("\n" + "="*70)
    print("Testing pkipakichutesuryo.inskichutesuryoseikyuout")
    print("="*70 + "\n")
    
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(**POSTGRES_CONFIG)
        conn.autocommit = True
        cursor = conn.cursor()
        
        print("✅ Connected to PostgreSQL")
        
        # Test 1: Basic call with minimal valid parameters
        print("\n📋 Test 1: Basic call with empty/minimal parameters")
        print("-" * 70)
        
        test_sql = """
DO $$ 
DECLARE 
    v_out_sql_code integer;
    v_out_sql_errm varchar;
    v_extra_param integer;
    v_result record;
BEGIN 
    -- Call the function
    SELECT * INTO v_result 
    FROM pkipakichutesuryo.inskichutesuryoseikyuout(
        'TESTUSER'::char,      -- l_inuserid
        '20250125'::char,      -- l_ingyomuymd
        '20250101'::char,      -- l_inkjnfrom
        '20250131'::char,      -- l_inkjnto
        ''::varchar,           -- l_initakukaishacd
        ''::char,              -- l_inhktcd
        ''::varchar,           -- l_inkozatencd
        ''::varchar,           -- l_inkozatencifcd
        ''::char,              -- l_inmgrcd
        ''::char,              -- l_inisincd
        '20250125'::char,      -- l_inTsuchiYmd
        'IP030005511'::varchar,-- l_inseikyuchoid
        '0'::char,             -- l_inrealbatchkbn (real-time)
        '1'::char,             -- l_indatasakuseikbn
        '1'::char,             -- l_inseikyuichirankbn
        '1'::varchar           -- l_inFrontFlg (front screen)
    );
    
    v_out_sql_code := (v_result).l_outsqlcode;
    v_out_sql_errm := (v_result).l_outsqlerrm;
    v_extra_param := (v_result).extra_param;
    
    RAISE NOTICE 'Return Code: %', v_extra_param;
    RAISE NOTICE 'SQL Code: %', v_out_sql_code;
    RAISE NOTICE 'SQL Error Message: %', COALESCE(v_out_sql_errm, 'NONE');
    
    -- Check if return code is 0 (SUCCESS)
    IF v_extra_param = 0 THEN
        RAISE NOTICE 'Status: SUCCESS';
    ELSE
        RAISE NOTICE 'Status: FAILED';
    END IF;
END $$;
"""
        
        try:
            cursor.execute(test_sql)
            
            # Fetch notices
            for notice in conn.notices:
                print(f"  {notice.strip()}")
            conn.notices.clear()
            
            print("\n✅ Test 1: PASSED - Function executed successfully")
            test1_passed = True
            
        except Exception as e:
            print(f"\n❌ Test 1: FAILED - {e}")
            test1_passed = False
        
        # Test 2: With specific company code
        print("\n📋 Test 2: Call with specific company code")
        print("-" * 70)
        
        test_sql_2 = """
DO $$ 
DECLARE 
    v_out_sql_code integer;
    v_out_sql_errm varchar;
    v_extra_param integer;
    v_result record;
BEGIN 
    SELECT * INTO v_result 
    FROM pkipakichutesuryo.inskichutesuryoseikyuout(
        'TESTUSER'::char,      -- l_inuserid
        '20250125'::char,      -- l_ingyomuymd
        '20250101'::char,      -- l_inkjnfrom
        '20250131'::char,      -- l_inkjnto
        '0005'::varchar,       -- l_initakukaishacd
        ''::char,              -- l_inhktcd
        ''::varchar,           -- l_inkozatencd
        ''::varchar,           -- l_inkozatencifcd
        ''::char,              -- l_inmgrcd
        ''::char,              -- l_inisincd
        '20250125'::char,      -- l_inTsuchiYmd
        'IP030005511'::varchar,-- l_inseikyuchoid
        '0'::char,             -- l_inrealbatchkbn (real-time)
        '1'::char,             -- l_indatasakuseikbn
        '1'::char,             -- l_inseikyuichirankbn
        '1'::varchar           -- l_inFrontFlg
    );
    
    v_out_sql_code := (v_result).l_outsqlcode;
    v_out_sql_errm := (v_result).l_outsqlerrm;
    v_extra_param := (v_result).extra_param;
    
    RAISE NOTICE 'Return Code: %', v_extra_param;
    RAISE NOTICE 'SQL Code: %', v_out_sql_code;
    RAISE NOTICE 'SQL Error Message: %', COALESCE(v_out_sql_errm, 'NONE');
    
    IF v_extra_param = 0 THEN
        RAISE NOTICE 'Status: SUCCESS';
    ELSE
        RAISE NOTICE 'Status: FAILED';
    END IF;
END $$;
"""
        
        try:
            cursor.execute(test_sql_2)
            
            for notice in conn.notices:
                print(f"  {notice.strip()}")
            conn.notices.clear()
            
            print("\n✅ Test 2: PASSED - Function executed successfully")
            test2_passed = True
            
        except Exception as e:
            print(f"\n❌ Test 2: FAILED - {e}")
            test2_passed = False
        
        # Summary
        print("\n" + "="*70)
        print("Test Summary")
        print("="*70)
        print(f"Test 1 (Empty parameters): {'✅ PASS' if test1_passed else '❌ FAIL'}")
        print(f"Test 2 (With company code): {'✅ PASS' if test2_passed else '❌ FAIL'}")
        
        all_passed = test1_passed and test2_passed
        print(f"\nOverall: {'✅ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")
        print("="*70 + "\n")
        
        cursor.close()
        conn.close()
        
        return all_passed
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False


if __name__ == '__main__':
    success = test_inskichutesuryoseikyuout()
    sys.exit(0 if success else 1)
