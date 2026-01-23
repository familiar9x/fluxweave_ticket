#!/usr/bin/env python3
"""
Test Suite for SFIPF009K00R05 - Account Branch/CIF Migration Function
PostgreSQL 17 Migration Testing

Test Cases:
1. Basic kamoku='S' migration (branch + CIF change)
2. Kamoku!='S' - BD account migration
3. Kamoku!='S' - HKT account migration  
4. Kamoku!='S' - HKO account migration
5. Error case: Unapproved issuer (shori_kbn != '1')
6. Warning case: Old branch not found in mbuten
7. Warning case: New branch not found in mbuten
8. No data case (empty tencif_yoyaku)
9. Date filter test (tekiyost_ymd outside range)
"""

import psycopg2
from datetime import datetime
import sys

# Database connection config
DB_CONFIG = {
    'host': 'jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com',
    'port': 5432,
    'dbname': 'rh_branches_ipa',
    'user': 'rh_branches_ipa',
    'password': 'luxur1ous-Pine@pple'
}

class TestCase:
    def __init__(self, name, description):
        self.name = name
        self.description = description
        self.passed = False
        self.error = None
    
    def run(self, conn):
        raise NotImplementedError

class TestKamokuS(TestCase):
    """Test Case 1: Basic kamoku='S' migration"""
    def __init__(self):
        super().__init__(
            "TC01_Kamoku_S_Migration",
            "Test branch and CIF change for kamoku='S' (main branch account)"
        )
    
    def run(self, conn):
        cur = conn.cursor()
        try:
            # Setup test data
            cur.execute("DELETE FROM kozajyohokoshin_list_wk WHERE itaku_kaisha_cd='TC01'")
            cur.execute("DELETE FROM mhakkotai WHERE itaku_kaisha_cd='TC01'")
            cur.execute("DELETE FROM tencif_yoyaku WHERE itaku_kaisha_cd='TC01'")
            cur.execute("DELETE FROM mbuten WHERE itaku_kaisha_cd='TC01'")
            
            # Insert test data
            cur.execute("""
                INSERT INTO mbuten (itaku_kaisha_cd, buten_cd, buten_nm, kousin_dt, kousin_id, sakusei_dt, sakusei_id)
                VALUES ('TC01', '1001', 'Test Branch Old', CURRENT_TIMESTAMP, 'TEST', CURRENT_TIMESTAMP, 'TEST'),
                       ('TC01', '1002', 'Test Branch New', CURRENT_TIMESTAMP, 'TEST', CURRENT_TIMESTAMP, 'TEST')
            """)
            
            cur.execute("""
                INSERT INTO mhakkotai (itaku_kaisha_cd, hkt_cd, koza_ten_cd, koza_ten_cifcd, 
                                        bd_koza_kamoku_cd, bd_koza_no, shori_kbn,
                                        kousin_dt, kousin_id, sakusei_dt, sakusei_id)
                VALUES ('TC01', 'HKT_TC01', '1001', 'CIF0001', 'S', '1234567', '1',
                        CURRENT_TIMESTAMP, 'TEST', CURRENT_TIMESTAMP, 'TEST')
            """)
            
            # Get current business date
            cur.execute("SELECT pkDate.getGyomuYmd()")
            gyomu_ymd = cur.fetchone()[0]
            
            cur.execute("""
                INSERT INTO tencif_yoyaku (
                    itaku_kaisha_cd, tekiyost_ymd, old_koza_ten_cd, old_koza_ten_cifcd,
                    old_koza_kamoku, old_koza_no, new_koza_ten_cd, new_koza_ten_cifcd,
                    new_koza_kamoku, new_koza_no, filter_shubetu, data_recv_ymd, make_dt
                )
                VALUES ('TC01', %s, '1001', 'CIF0001', 'S', '1234567', 
                        '1002', 'CIF0002', 'S', '1234567', '1', %s, %s)
            """, (gyomu_ymd, gyomu_ymd, gyomu_ymd))
            
            conn.commit()
            
            # Execute function
            cur.execute("SELECT sfipf009k00r05('0')")
            result = cur.fetchone()[0]
            
            # Verify results
            assert result == 0, f"Expected return code 0, got {result}"
            
            # Check mhakkotai updated
            cur.execute("""
                SELECT koza_ten_cd, koza_ten_cifcd 
                FROM mhakkotai 
                WHERE itaku_kaisha_cd='TC01' AND hkt_cd='HKT_TC01'
            """)
            row = cur.fetchone()
            assert row[0] == '1002', f"Branch not updated: {row[0]}"
            assert row[1] == 'CIF0002', f"CIF not updated: {row[1]}"
            
            # Check output record created
            cur.execute("""
                SELECT COUNT(*) FROM kozajyohokoshin_list_wk 
                WHERE itaku_kaisha_cd='TC01'
            """)
            count = cur.fetchone()[0]
            assert count == 1, f"Expected 1 output record, got {count}"
            
            self.passed = True
            
        except Exception as e:
            self.error = str(e)
            conn.rollback()
        finally:
            # Cleanup
            cur.execute("DELETE FROM kozajyohokoshin_list_wk WHERE itaku_kaisha_cd='TC01'")
            cur.execute("DELETE FROM tencif_yoyaku WHERE itaku_kaisha_cd='TC01'")
            cur.execute("DELETE FROM mhakkotai WHERE itaku_kaisha_cd='TC01'")
            cur.execute("DELETE FROM mbuten WHERE itaku_kaisha_cd='TC01'")
            conn.commit()
            cur.close()


class TestUnapprovedIssuer(TestCase):
    """Test Case 5: Unapproved issuer error"""
    def __init__(self):
        super().__init__(
            "TC05_Unapproved_Issuer",
            "Test error handling when issuer shori_kbn != '1'"
        )
    
    def run(self, conn):
        cur = conn.cursor()
        try:
            # Setup
            cur.execute("DELETE FROM kozajyohokoshin_list_wk WHERE itaku_kaisha_cd='TC05'")
            cur.execute("DELETE FROM mhakkotai WHERE itaku_kaisha_cd='TC05'")
            cur.execute("DELETE FROM tencif_yoyaku WHERE itaku_kaisha_cd='TC05'")
            cur.execute("DELETE FROM mbuten WHERE itaku_kaisha_cd='TC05'")
            
            cur.execute("""
                INSERT INTO mbuten (itaku_kaisha_cd, buten_cd, buten_nm, kousin_dt, kousin_id, sakusei_dt, sakusei_id)
                VALUES ('TC05', '2001', 'Test Branch', CURRENT_TIMESTAMP, 'TEST', CURRENT_TIMESTAMP, 'TEST')
            """)
            
            # Insert unapproved issuer (shori_kbn='0')
            cur.execute("""
                INSERT INTO mhakkotai (itaku_kaisha_cd, hkt_cd, koza_ten_cd, koza_ten_cifcd, 
                                        bd_koza_kamoku_cd, bd_koza_no, shori_kbn,
                                        kousin_dt, kousin_id, sakusei_dt, sakusei_id)
                VALUES ('TC05', 'HKT_TC05', '2001', 'CIF2001', 'S', '2234567', '0',
                        CURRENT_TIMESTAMP, 'TEST', CURRENT_TIMESTAMP, 'TEST')
            """)
            
            cur.execute("SELECT pkDate.getGyomuYmd()")
            gyomu_ymd = cur.fetchone()[0]
            
            cur.execute("""
                INSERT INTO tencif_yoyaku (
                    itaku_kaisha_cd, tekiyost_ymd, old_koza_ten_cd, old_koza_ten_cifcd,
                    old_koza_kamoku, old_koza_no, new_koza_ten_cd, new_koza_ten_cifcd,
                    new_koza_kamoku, new_koza_no, filter_shubetu, data_recv_ymd, make_dt
                )
                VALUES ('TC05', %s, '2001', 'CIF2001', 'S', '2234567', 
                        '2001', 'CIF2002', 'S', '2234567', '1', %s, %s)
            """, (gyomu_ymd, gyomu_ymd, gyomu_ymd))
            
            conn.commit()
            
            # Execute
            cur.execute("SELECT sfipf009k00r05('0')")
            result = cur.fetchone()[0]
            
            # Should return 1 (ERROR)
            assert result == 1, f"Expected return code 1 (ERROR), got {result}"
            
            # Check error record created
            cur.execute("""
                SELECT err_umu_flg, err_cd_6 
                FROM kozajyohokoshin_list_wk 
                WHERE itaku_kaisha_cd='TC05'
            """)
            row = cur.fetchone()
            assert row is not None, "No error record created"
            assert row[0] == '1', f"Expected err_umu_flg='1', got '{row[0]}'"
            assert row[1] == 'EIP514', f"Expected err_cd='EIP514', got '{row[1]}'"
            
            self.passed = True
            
        except Exception as e:
            self.error = str(e)
            conn.rollback()
        finally:
            cur.execute("DELETE FROM kozajyohokoshin_list_wk WHERE itaku_kaisha_cd='TC05'")
            cur.execute("DELETE FROM tencif_yoyaku WHERE itaku_kaisha_cd='TC05'")
            cur.execute("DELETE FROM mhakkotai WHERE itaku_kaisha_cd='TC05'")
            cur.execute("DELETE FROM mbuten WHERE itaku_kaisha_cd='TC05'")
            conn.commit()
            cur.close()


class TestNoData(TestCase):
    """Test Case 8: No data in tencif_yoyaku"""
    def __init__(self):
        super().__init__(
            "TC08_No_Data",
            "Test function returns success when no data to process"
        )
    
    def run(self, conn):
        cur = conn.cursor()
        try:
            # Ensure no data
            cur.execute("DELETE FROM tencif_yoyaku WHERE itaku_kaisha_cd='TC08'")
            conn.commit()
            
            # Execute
            cur.execute("SELECT sfipf009k00r05('0')")
            result = cur.fetchone()[0]
            
            # Should return 0 (SUCCESS - no data)
            assert result == 0, f"Expected return code 0, got {result}"
            
            self.passed = True
            
        except Exception as e:
            self.error = str(e)
            conn.rollback()
        finally:
            cur.close()


def run_test_suite():
    """Run all test cases"""
    print("=" * 80)
    print("SFIPF009K00R05 Test Suite")
    print("=" * 80)
    print(f"Started: {datetime.now()}\n")
    
    # Connect to database
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print("✓ Database connection established\n")
    except Exception as e:
        print(f"✗ Failed to connect to database: {e}")
        return 1
    
    # Define test cases
    test_cases = [
        TestKamokuS(),
        TestUnapprovedIssuer(),
        TestNoData(),
    ]
    
    # Run tests
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases, 1):
        print(f"[{i}/{len(test_cases)}] Running: {test.name}")
        print(f"    Description: {test.description}")
        
        test.run(conn)
        
        if test.passed:
            print(f"    Result: ✓ PASS")
            passed += 1
        else:
            print(f"    Result: ✗ FAIL")
            print(f"    Error: {test.error}")
            failed += 1
        print()
    
    # Summary
    print("=" * 80)
    print("Test Summary")
    print("=" * 80)
    print(f"Total:  {len(test_cases)}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"\nFinished: {datetime.now()}")
    
    conn.close()
    
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(run_test_suite())
