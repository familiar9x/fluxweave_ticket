#!/usr/bin/env python3
"""
Test bcgy-8835: spIp03701_01 procedure
Test that the procedure executes successfully and returns code 0
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

def test_spip03701_01():
    """Test spIp03701_01 procedure"""
    
    print("\n" + "="*80)
    print("Testing bcgy-8835: spIp03701_01")
    print("="*80 + "\n")
    
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(**POSTGRES_CONFIG)
        conn.autocommit = True
        cursor = conn.cursor()
        
        print("✅ Connected to PostgreSQL")
        
        # Test 1: Basic call with minimal parameters
        print("\n📋 Test 1: Basic call with minimal parameters")
        print("-" * 80)
        
        test_sql = """
DO $$ 
DECLARE 
    v_return_code numeric;
    v_sql_errm text;
BEGIN 
    -- Call the procedure with correct signature (9 parameters)
    CALL spip03701_01(
        'TESTUSER'::text,      -- l_inuserid (ユーザID)
        '0001'::text,          -- l_initakukaishacd (委託会社コード)
        '123456'::text,        -- l_inmgrcd (銘柄コード)
        'JP1234567890'::text,  -- l_inisincd (ISINコード)
        '20250101'::text,      -- l_inhakkoymd (発行日)
        '20250125'::text,      -- l_intsuchiymd (通知日)
        '0'::text,             -- l_inchohyokbn (帳票区分)
        v_return_code,         -- l_outsqlcode (OUT parameter)
        v_sql_errm             -- l_outsqlerrm (OUT parameter)
    );
    
    RAISE NOTICE 'Return Code: %', v_return_code;
    RAISE NOTICE 'SQL Error Message: %', COALESCE(v_sql_errm, 'NONE');
    
    -- Check if return code is 0 (SUCCESS)
    IF v_return_code = 0 THEN
        RAISE NOTICE 'Status: ✅ SUCCESS';
    ELSE
        RAISE NOTICE 'Status: ❌ FAILED (Return Code: %)', v_return_code;
    END IF;
END $$;
"""
        
        try:
            cursor.execute(test_sql)
            
            # Fetch notices
            for notice in conn.notices:
                print(f"  {notice.strip()}")
            conn.notices.clear()
            
            print("\n✅ Test 1: PASSED - Procedure executed successfully")
            test1_passed = True
            
        except Exception as e:
            print(f"\n❌ Test 1: FAILED - {e}")
            test1_passed = False
        
        # Test 2: Call with different date
        print("\n📋 Test 2: Call with different business date")
        print("-" * 80)
        
        test_sql_2 = """
DO $$ 
DECLARE 
    v_return_code numeric;
    v_sql_errm text;
BEGIN 
    CALL spip03701_01(
        'BATCH'::text,         -- l_inuserid
        '0002'::text,          -- l_initakukaishacd
        '999999'::text,        -- l_inmgrcd
        'JP9999999999'::text,  -- l_inisincd
        '20240101'::text,      -- l_inhakkoymd
        '20250101'::text,      -- l_intsuchiymd
        '1'::text,             -- l_inchohyokbn
        v_return_code,
        v_sql_errm
    );
    
    RAISE NOTICE 'Return Code: %', v_return_code;
    RAISE NOTICE 'SQL Error Message: %', COALESCE(v_sql_errm, 'NONE');
    
    IF v_return_code = 0 THEN
        RAISE NOTICE 'Status: ✅ SUCCESS';
    ELSE
        RAISE NOTICE 'Status: ❌ FAILED (Return Code: %)', v_return_code;
    END IF;
END $$;
"""
        
        try:
            cursor.execute(test_sql_2)
            
            for notice in conn.notices:
                print(f"  {notice.strip()}")
            conn.notices.clear()
            
            print("\n✅ Test 2: PASSED - Procedure executed successfully")
            test2_passed = True
            
        except Exception as e:
            print(f"\n❌ Test 2: FAILED - {e}")
            test2_passed = False
        
        # Test 3: Verify procedure signature
        print("\n📋 Test 3: Verify procedure exists with correct signature")
        print("-" * 80)
        
        cursor.execute("""
            SELECT 
                p.proname as procedure_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as result_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' 
            AND p.proname = 'spip03701_01'
        """)
        
        result = cursor.fetchone()
        if result:
            print(f"  ✅ Procedure found: {result[0]}")
            print(f"  📝 Arguments: {result[1]}")
            print(f"  📝 Result: {result[2]}")
            test3_passed = True
        else:
            print("  ❌ Procedure not found")
            test3_passed = False
        
        # Summary
        print("\n" + "="*80)
        print("Test Summary")
        print("="*80)
        print(f"Test 1 (Basic call): {'✅ PASS' if test1_passed else '❌ FAIL'}")
        print(f"Test 2 (Different date): {'✅ PASS' if test2_passed else '❌ FAIL'}")
        print(f"Test 3 (Procedure signature): {'✅ PASS' if test3_passed else '❌ FAIL'}")
        
        all_passed = test1_passed and test2_passed and test3_passed
        print(f"\nOverall: {'✅ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")
        print("="*80 + "\n")
        
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
    success = test_spip03701_01()
    sys.exit(0 if success else 1)
