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
    'vexe-2181': {
        'name': 'SPIPX005K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Real data test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx005k00r01('0005', 'TEST', '1', '202501', '001', '001', '001', 'MGR001', 'ISIN001', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'NODATA test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx005k00r01('9999', 'TEST', '1', '202501', '999', '999', '999', 'MGR999', 'ISIN999', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            }
        ]
    },
    'zwvg-7789': {
        'name': 'SPIPX004K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Real data test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx004k00r01('0005', 'TEST', '1', '202501', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'NODATA test (still returns 0 with no-data message)',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx004k00r01('9999', 'TEST', '1', '202501', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            }
        ]
    },
    'yxbt-4733': {
        'name': 'SPIPX002K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Real data test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx002k00r01('20250101', '20251231', '1', '0005', 'TEST', '1', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'NODATA test (still returns 0 with no-data message)',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx002k00r01('20250101', '20251231', '1', '9999', 'TEST', '1', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            }
        ]
    },
    'rfdc-5956': {
        'name': 'SPIPW022K00R02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Real data test (tojitu_kbn=0)',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipw022k00r02('0005', 'TEST', '1', '20250101', '0', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'NODATA test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipw022k00r02('9999', 'TEST', '1', '20250101', '0', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2
            }
        ]
    },
    'gyqf-4446': {
        'name': 'SPIPW020K00R02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Real data test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipw020k00r02('0005', 'TEST', '1', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'NODATA test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipw020k00r02('9999', 'TEST', '1', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2
            }
        ]
    },
    'wwdk-1653': {
        'name': 'SPIPW021K00R02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Real data test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipw021k00r02('0005', 'TEST', '1', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'NODATA test',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipw021k00r02('9999', 'TEST', '1', '20250101', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2
            }
        ]
    },
    'nmue-7982': {
        'name': 'SPIPX007K00R01 - 元利金支払基金引落一覧表 (wrapper)',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Test 1: Call wrapper procedure with date range',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx007k00r01('TESTUSER', '0005', '20250106', '20250110', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            }
        ]
    },
    'sbvb-6748': {
        'name': 'SPIPX011K00R01 - 基準残高報告書',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Test 1: ChohyoKbn=1 causes parameter error',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx011k00r01('0005', 'TESTUSER', '1', '20250112', '202501', '20250112', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 1
            },
            {
                'description': 'Test 2: ChohyoKbn=0 (real report mode) - success',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx011k00r01('0005', 'TESTUSER', '0', '20250112', '202501', '20250112', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            }
        ]
    },
    'praj-5311': {
        'name': 'SPIPW010K00R02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB balance reconciliation report - with data',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND user_id='TESTUSER' AND chohyo_id IN ('IPW30001011', 'WKW30001011');
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND kijun_ymd='20240401' AND list_sakusei_kbn='1' AND chohyo_id='IPW30001011';
    
    CALL spipw010k00r02('0005', 'TESTUSER', '1', '20240401', '20991231235959000001', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS (found matching data)
            }
        ]
    },
    'qkpu-7999': {
        'name': 'SPIPW001K00R09',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB exercise price history report - success',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND user_id='TESTUSER' AND chohyo_id='IPW300001A1';
    
    CALL spipw001k00r09('TEST0001', '0005', 'TESTUSER', '1', '20240401', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # RTN_OK
            }
        ]
    },
    'cqzt-5020': {
        'name': 'SPIPW004K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB mid-term info change confirmation list - success',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    
    CALL spipw004k00r01('0005', 'TESTUSER', '1', '20240401', 'TEST0001', '20240401', '20240401', 1, v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # RTN_OK
            }
        ]
    },
    'znjg-7874': {
        'name': 'SPIPX012K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Principal and interest payment fund balance report - success',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    
    CALL spipx012k00r01('0005', 'TESTUSER', '0', '20240401', 'IPX30001201', '', '', '', 'TEST0001', '', '202404', '20240401', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # RTN_OK
            }
        ]
    },
    'dssw-5190': {
        'name': 'SPIPW001K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB detailed info list - compiles and executes without syntax errors',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    
    CALL spipw001k00r01('TEST0001', '0005', 'TESTUSER', '1', '20240401', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # RTN_NODATA - test data doesn't exist (or 0/99 if dependencies exist)
            }
        ]
    },
    'fgrd-8742': {
        'name': 'SPIPW001K00R04',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB fee setup info - compiles and executes without syntax errors',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    
    CALL spipw001k00r04('TEST0001', '0005', 'TESTUSER', '1', '20240401', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # RTN_NODATA - test data doesn't exist
            }
        ]
    },
    'nnfh-4187': {
        'name': 'SPIPT113K01R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'New recording fee aggregation - compiles and executes',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    
    CALL spipt113k01r01('0005', 'TESTUSER', '1', NULL, NULL, NULL, NULL, NULL, '202401', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # Success or NODATA
            }
        ]
    },
    'ubrr-9171': {
        'name': 'SPIPW001K00R07',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB mid-term fee info list - with real data (SUCCESS)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    
    CALL spipw001k00r07('0005BF0210001', '0005', 'TESTUSER', '1', '20240401', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # RTN_OK - success with data
            },
            {
                'description': 'CB mid-term fee info list - no data (NODATA)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    
    CALL spipw001k00r07('TEST0001', '0005', 'TESTUSER', '1', '20240401', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # RTN_NODATA - test data doesn't exist
            }
        ]
    },
    'sdjw-9032': {
        'name': 'SPIPP014K00R02_02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Real record number management - option OFF (early return)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
BEGIN 
    CALL spipp014k00r02_02('0005', 'TESTUSER', '1', v_code);
    RAISE NOTICE 'Code: %', v_code;
END $$;
""",
                'expected': 0  # Option flag OFF - early return with code 0
            }
        ]
    },
    'fgrd-8742': {
        'name': 'SPIPW001K00R04',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB fee setting info - real data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipw001k00r04('0005BF0210001', '0005', 'TESTUSER', '1', '20250118', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # Should return 0 for real MGR_CD
            },
            {
                'description': 'CB fee setting info - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipw001k00r04('TEST9999', '0005', 'TESTUSER', '1', '20250118', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # NODATA for fake MGR_CD
            }
        ]
    },
    'dssw-5190': {
        'name': 'SPIPW001K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'CB basic attributes - real CB data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipw001k00r01('0005C02030001', '0005', 'TESTUSER', '1', '20250118', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # Should return 0 for real CB MGR_CD
            },
            {
                'description': 'CB basic attributes - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipw001k00r01('TEST9999', '0005', 'TESTUSER', '1', '20250118', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # NODATA for fake MGR_CD
            }
        ]
    },
    'nnfh-4187': {
        'name': 'SPIPT113K01R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'New registration fee aggregation - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipt113k01r01('0005', 'TESTUSER', '1', NULL, NULL, NULL, NULL, NULL, '202501', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # Should return 0 (no data means empty report, not error)
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
    """Execute PostgreSQL procedure test and parse NOTICE"""
    # Clear previous notices
    cursor.connection.notices.clear()
    cursor.execute(sql)
    # PostgreSQL procedures with RAISE NOTICE will have messages in notices
    if cursor.connection.notices:
        for notice in cursor.connection.notices:
            # Try different patterns
            if 'RESULT:' in notice:
                # Extract number after RESULT:
                return int(notice.split('RESULT:')[1].strip().split()[0])
            elif 'Code:' in notice:
                # Extract first number after Code:
                parts = notice.split('Code:')[1].strip().split(',')[0].strip()
                return int(parts)
            else:
                # Try to extract just a number from the notice
                # Pattern: NOTICE:  <number>
                import re
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
    print(f"{'='*70}\n")
    
    # Connect to database
    try:
        postgres_conn = psycopg2.connect(**POSTGRES_CONFIG)
        postgres_conn.set_session(autocommit=True)
        
        postgres_cursor = postgres_conn.cursor()
        
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
                if config['type'] == 'function':
                    postgres_result = test_postgres_function(postgres_cursor, test['postgres_sql'])
                else:
                    postgres_result = test_postgres_procedure(postgres_cursor, test['postgres_sql'])
                print(f"  PostgreSQL: {postgres_result}")
            except Exception as e:
                postgres_error = str(e)
                print(f"  PostgreSQL: ERROR - {postgres_error}")
            
            # Compare results
            expected = test['expected']
            print(f"  Expected:   {expected}")
            
            if postgres_error:
                print(f"  Status:     ❌ ERROR")
                all_passed = False
                test_results.append(False)
            elif postgres_result == expected:
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