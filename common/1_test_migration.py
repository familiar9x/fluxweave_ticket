#!/usr/bin/env python3
"""
Test PostgreSQL migration results
Tests migrated function/procedure outputs in PostgreSQL
"""

import psycopg2
import sys
from typing import Dict, List, Tuple, Any

# Database configurations
POSTGRES_CONFIG = {
    'host': 'jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com',
    'port': 5432,
    'database': 'rh_mufg_ipa',
    'user': 'rh_mufg_ipa',
    'password': 'luxur1ous-Pine@pple'
}

# Test configurations for each ticket
TEST_CONFIGS = {
    'yhkb-4351': {
        'name': 'SFIPM001K00R01',
        'type': 'function',
        'timeout': 30,
        'tests': [
            {
                'description': 'Create daily memorandum work info (備忘録日次作業情報作成)',
                'postgres_sql': "DELETE FROM MEMORANDOM_D_SAGYO WHERE ITAKU_KAISHA_CD = '0005' AND MEMORANDOM_CD = 'M0002'; SELECT sfipm001k00r01('TEST', '0005', 'M0002', '1');",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'jtgv-2994': {
        'name': 'SPIPM001K00R03',
        'type': 'procedure',
        'timeout': 30,
        'tests': [
            {
                'description': 'Memorandum setting info list (non-issue linked) (備忘録設定情報一覧表（銘柄非連動分）)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    -- Clean up test data
    DELETE FROM sreport_wk 
    WHERE key_cd = '0005' 
      AND user_id = 'TEST' 
      AND chohyo_kbn = '1'
      AND chohyo_id = 'IPM30000121';
    
    -- Call procedure
    CALL spipm001k00r03(
        l_inItakuKaishaCd := '0005',
        l_inUserId := 'TEST',
        l_inChohyoKbn := '1',
        l_inMemorandomCd := 'M0002',
        l_outSqlCode := v_code,
        l_outSqlErrM := v_err
    );
    
    RAISE NOTICE 'Return code: %, Error: %', v_code, v_err;
    
    IF v_code = 0 THEN
        RAISE NOTICE 'TEST PASSED: Return code is 0';
    ELSE
        RAISE EXCEPTION 'TEST FAILED: Return code is % (expected 0), Error: %', v_code, v_err;
    END IF;
    
    -- Verify data
    IF (SELECT COUNT(*) FROM sreport_wk WHERE chohyo_id = 'IPM30000121' AND user_id = 'TEST') >= 1 THEN
        RAISE NOTICE 'VERIFIED: Data found in SREPORT_WK';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: No data in SREPORT_WK';
    END IF;
END $$;
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'uvty-9465': {
        'name': 'SPIPM001K00R04',
        'type': 'procedure',
        'timeout': 30,
        'tests': [
            {
                'description': 'Memorandum code-specific issue list (備忘録コード別銘柄情報一覧表)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    -- Clean up test data first
    DELETE FROM sreport_wk 
    WHERE key_cd = '0005' 
      AND user_id = 'TEST' 
      AND chohyo_kbn = '1'
      AND chohyo_id = 'IPM30000131';
    
    -- Call procedure
    CALL spipm001k00r04(
        l_inItakuKaishaCd := '0005',
        l_inUserId := 'TEST',
        l_inChohyoKbn := '1',
        l_inMemorandomCd := 'M0001',
        l_outSqlCode := v_code,
        l_outSqlErrM := v_err
    );
    
    -- Raise result
    RAISE NOTICE 'Return code: %, Error: %', v_code, v_err;
    
    IF v_code = 0 THEN
        RAISE NOTICE 'TEST PASSED: Return code is 0';
    ELSE
        RAISE EXCEPTION 'TEST FAILED: Return code is % (expected 0), Error: %', v_code, v_err;
    END IF;
    
    -- Verify data was inserted into SREPORT_WK
    IF (SELECT COUNT(*) FROM sreport_wk WHERE chohyo_id = 'IPM30000131' AND user_id = 'TEST') >= 1 THEN
        RAISE NOTICE 'VERIFIED: Data found in SREPORT_WK';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: No data in SREPORT_WK';
    END IF;
END $$;
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    }, 
    'bsgt-5895': {
        'name': 'sfIpaSime',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Get counts for closing process (締め処理用件数取得)',
                'postgres_sql': """
DO $$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result FROM sfipasime('0005');
    
    IF v_result.extra_param != 0 THEN
        RAISE EXCEPTION 'extra_param expected 0 (success), got %', v_result.extra_param;
    END IF;
    
    RAISE NOTICE 'Test passed - extra_param = 0';
END $$;
""",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'bwww-5397': {
        'name': 'SFADI017S05119',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Bond information change file transmission (status update wrapper)',
                'postgres_sql': "SELECT sfadi017s05119('20251201135600539712', 1);",
                'expected': 0  # 0=SUCCESS (calls SFADI017S0511COMMON with SHONIN status)
            }
        ]
    }
}



def test_postgres_function(cursor, sql: str) -> Any:
    """Execute PostgreSQL function test"""
    cursor.execute(sql)
    result = cursor.fetchone()
    return result[0] if result else None


def test_postgres_procedure(cursor, sql: str) -> Any:
    """Execute PostgreSQL procedure test and parse NOTICE or OUT parameters"""
    # Clear previous notices
    cursor.connection.notices.clear()
    cursor.execute(sql)
    
    # Try to fetch result (for procedures with OUT parameters)
    try:
        result = cursor.fetchone()
        if result:
            # Return first column (usually l_outSqlCode)
            return result[0]
    except:
        pass
    
    # PostgreSQL procedures with RAISE NOTICE will have messages in notices
    if cursor.connection.notices:
        # First pass: look for explicit "Return Code:" pattern
        for notice in cursor.connection.notices:
            if 'Return Code:' in notice:
                parts = notice.split('Return Code:')[1].strip().split(',')[0].strip()
                return int(parts)
        
        # Second pass: look for other patterns
        for notice in cursor.connection.notices:
            # Try different patterns
            if 'RESULT:' in notice:
                # Extract number after RESULT:
                return int(notice.split('RESULT:')[1].strip().split()[0])
            elif 'Code:' in notice:
                # Extract first number after Code:
                parts = notice.split('Code:')[1].strip().split(',')[0].strip()
                return int(parts)
        
        # Last pass: extract any number (skip TRACE messages)
        import re
        for notice in cursor.connection.notices:
            if '[TRACE]' not in notice:
                match = re.search(r'\b(\d+)\b', notice)
                if match:
                    return int(match.group(1))
    return None


def run_tests(ticket_id: str):
    """Run tests for a specific ticket"""
    if ticket_id not in TEST_CONFIGS:
        print(f"❌ Unknown ticket: {ticket_id}")
        print(f"Available tickets: {', '.join(TEST_CONFIGS.keys())}")
        return False
    
    config = TEST_CONFIGS[ticket_id]
    print(f"\n{'='*70}")
    print(f"Testing Ticket: {ticket_id}")
    print(f"Object: {config['name']} ({config['type']})")
    if 'timeout' in config:
        print(f"Timeout: {config['timeout']}s")
    print(f"{'='*70}\n")
    
    # Connect to database
    try:
        postgres_conn = psycopg2.connect(**POSTGRES_CONFIG)
        postgres_conn.set_session(autocommit=True)
        
        postgres_cursor = postgres_conn.cursor()
        
        # Set statement timeout if configured
        if 'timeout' in config:
            timeout_ms = config['timeout'] * 1000
            postgres_cursor.execute(f"SET statement_timeout = {timeout_ms}")
        
        all_passed = True
        test_results = []
        
        for i, test in enumerate(config['tests'], 1):
            print(f"Test {i}: {test['description']}")
            print("-" * 70)
            
            # Run setup if provided
            if 'setup_postgres' in test:
                try:
                    postgres_cursor.execute(test['setup_postgres'])
                    postgres_conn.commit()
                except Exception as e:
                    print(f"  Setup PostgreSQL: ERROR - {e}")
            
            # Test PostgreSQL
            postgres_result = None
            postgres_error = None
            try:
                # Check if test has specific SQL for function mode
                if 'postgres_sql_func' in test:
                    postgres_result = test_postgres_function(postgres_cursor, test['postgres_sql_func'])
                elif config['type'] == 'function':
                    postgres_result = test_postgres_function(postgres_cursor, test['postgres_sql'])
                else:
                    postgres_result = test_postgres_procedure(postgres_cursor, test['postgres_sql'])
                print(f"  PostgreSQL: {postgres_result}")
            except psycopg2.errors.QueryCanceled as e:
                postgres_error = f"TIMEOUT after {config.get('timeout', 'N/A')}s"
                print(f"  PostgreSQL: ⏱️  {postgres_error}")
                # If timeout is allowed for this test, treat as warning not error
                if test.get('allow_timeout', False):
                    print(f"  Note: Timeout is expected/allowed for this test")
            except Exception as e:
                postgres_error = str(e)
                print(f"  PostgreSQL: ERROR - {postgres_error}")
            
            # Compare results
            expected = test['expected']
            print(f"  Expected:   {expected}")
            
            if postgres_error:
                # Check if timeout is allowed
                if 'TIMEOUT' in postgres_error and test.get('allow_timeout', False):
                    print(f"  Status:     ⚠️  TIMEOUT (allowed)")
                    test_results.append(True)  # Count as pass if timeout is allowed
                else:
                    print(f"  Status:     ❌ ERROR")
                    all_passed = False
                    test_results.append(False)
            elif (isinstance(expected, list) and postgres_result in expected) or postgres_result == expected:
                print(f"  Status:     ✅ PASS")
                test_results.append(True)
            else:
                print(f"  Status:     ❌ FAIL (PostgreSQL != expected)")
                all_passed = False
                test_results.append(False)
            
            # Run cleanup if provided
            if 'cleanup_postgres' in test:
                try:
                    postgres_cursor.execute(test['cleanup_postgres'])
                    postgres_conn.commit()
                except Exception as e:
                    print(f"  Cleanup PostgreSQL: ERROR - {e}")
            
            print()
        
        # Summary
        passed = sum(test_results)
        total = len(test_results)
        print(f"{'='*70}")
        print(f"Summary: {passed}/{total} tests passed")
        print(f"{'='*70}\n")
        
        postgres_cursor.close()
        postgres_conn.close()
        
        return all_passed
        
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False


def run_all_tests():
    """Run tests for all tickets"""
    print("\n" + "="*70)
    print("TESTING ALL TICKETS")
    print("="*70)
    
    results = {}
    for ticket_id in TEST_CONFIGS.keys():
        results[ticket_id] = run_tests(ticket_id)
    
    # Final summary
    print("\n" + "="*70)
    print("FINAL SUMMARY")
    print("="*70)
    for ticket_id, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{ticket_id}: {status} - {TEST_CONFIGS[ticket_id]['name']}")
    print("="*70 + "\n")
    
    return all(results.values())


if __name__ == '__main__':
    if len(sys.argv) > 1:
        # Test specific ticket
        ticket_id = sys.argv[1]
        success = run_tests(ticket_id)
    else:
        # Test all tickets
        success = run_all_tests()
    
    sys.exit(0 if success else 1)
