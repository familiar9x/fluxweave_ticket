# Database Testing Scripts

Scripts để test function/procedure trên PostgreSQL và Oracle.

## 📝 Files

1. **test_postgres_function.sh** - Test PostgreSQL functions/procedures
2. **test_oracle_function.sh** - Test Oracle functions/procedures  
3. **test_db_interactive.sh** - Interactive menu cho cả 2 databases

## 🚀 Quick Start

### Interactive Mode (Khuyên dùng)
```bash
./test_db_interactive.sh
```

### PostgreSQL - Command Line

#### Test function không parameters
```bash
./test_postgres_function.sh SFBKH001A00R01
# Note: Function names auto-convert to lowercase
```

#### Test function với parameters (PostgreSQL auto-converts to lowercase)
```bash
./test_postgres_function.sh SFBKH002A00R01 "'001'::character" "'USER001'::varchar" "1" "'20250101'::character" "'001'::character" "'001'::character" "''::character" "1"
```

#### Test stub function SFIPH007K00R01 (kjsr-8482) 
```bash
./test_postgres_function.sh SFIPH007K00R01 "'001'::character" "'USER001'::varchar" "'1'::character" "'20250101'::character" "'20250101'::character" "'20251231'::character" "''::character" "''::varchar" "''::character"

# Expected output:
# NOTICE: SFIPH007K00R01 stub - TODO: implement full logic
# sfiph007k00r01: 0
```

#### Test procedure (dùng CALL)
```bash
./test_postgres_function.sh --procedure MY_PROCEDURE 'param1' 'param2'
```

#### Verbose mode (xem connection info)
```bash
./test_postgres_function.sh --verbose SFBKH001A00R01
```

### Oracle - Command Line

#### Test function với SELECT FROM DUAL
```bash
./test_oracle_function.sh SFBKH001A00R01
```

#### Test function với parameters
```bash
# Note: Oracle strings cần quote kép ngoài
./test_oracle_function.sh SFBKH002A00R01 "'001'" "'USER001'" "'20250101'"
```

#### Test procedure với EXECUTE
```bash
./test_oracle_function.sh --procedure MY_PROCEDURE "'param1'" "'param2'"
```

#### Test với PL/SQL block
```bash
./test_oracle_function.sh --block MY_FUNCTION "'001'" "'USER001'"
```

## 🔧 Connection Settings

### PostgreSQL
```
Host:     jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com
Port:     5432
Database: rh_mufg_ipa
User:     rh_mufg_ipa
Password: luxur1ous-Pine@pple
```

### Oracle
```
Host:     jip-ipa-cp.cvmszg1k9xhh.us-east-1.rds.amazonaws.com
Port:     1521
SID:      ORCL
User:     RH_MUFG_IPA
Password: g1normous-pik@chu
```

## 📚 Examples

### Test các migrated functions

#### 1. Test sfiph007k00r01 (kjsr-8482 - STUB)
```bash
# PostgreSQL
./test_postgres_function.sh SFIPH007K00R01 "'001'::character" "'USER001'::varchar" "'1'::character" "'20250101'::character" "'20250101'::character" "'20251231'::character" "''::character" "''::varchar" "''::character"

# Expected: Returns 0 with NOTICE message

# Oracle (if function exists)
./test_oracle_function.sh SFIPH007K00R01 "'001'" "'USER001'" "'1'" "'20250101'" "'20250101'" "'20251231'" "''" "''" "''"
```

#### 2. Test sfiph999_tesyuryo_kaikei (pswa-2379)
```bash
# PostgreSQL
./test_postgres_function.sh SFIPH999_TESYURYO_KAIKEI "'001'::character" "'USER001'::varchar" "'1'::character" "'20250101'::character" "'20250101'::character"

# Oracle
./test_oracle_function.sh SFIPH999_TESYURYO_KAIKEI "'001'" "'USER001'" "'1'" "'20250101'" "'20250101'"
```

#### 3. List all available functions
```bash
# PostgreSQL - List all functions
PGPASSWORD='luxur1ous-Pine@pple' psql -h jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com -p 5432 -U rh_mufg_ipa -d rh_mufg_ipa -c "SELECT proname, pronargs FROM pg_proc WHERE proname LIKE 'sf%' OR proname LIKE 'sp%' ORDER BY proname;"
```

### So sánh kết quả PostgreSQL vs Oracle

```bash
echo "=== Testing on PostgreSQL ==="
./test_postgres_function.sh SFBKH001A00R01 '001' 'USER001' '1' '20250101'

echo ""
echo "=== Testing on Oracle ==="
./test_oracle_function.sh SFBKH001A00R01 "'001'" "'USER001'" "1" "'20250101'"
```

## 🎯 Features

### test_postgres_function.sh
- ✅ Auto-check if function exists
- ✅ Color-coded output (success/error)
- ✅ Support both SELECT and CALL
- ✅ Verbose mode để debug
- ✅ Pretty formatted results

### test_oracle_function.sh
- ✅ Support SELECT FROM DUAL
- ✅ Support EXECUTE for procedures
- ✅ Support PL/SQL anonymous blocks
- ✅ DBMS_OUTPUT enabled
- ✅ Error handling with WHENEVER SQLERROR

### test_db_interactive.sh
- ✅ Interactive menu
- ✅ User-friendly prompts
- ✅ Auto-format parameters
- ✅ Clear visual feedback
- ✅ Repeat testing without retyping

## ⚠️ Requirements

### PostgreSQL
- `psql` client (đã cài sẵn)
- Network access to RDS

### Oracle
- `sqlplus` client (Oracle Instant Client)
- Network access to RDS

Install Oracle Instant Client nếu chưa có:
```bash
# Download from Oracle
wget https://download.oracle.com/otn_software/linux/instantclient/...

# Install
sudo rpm -ivh oracle-instantclient-basic-*.rpm
sudo rpm -ivh oracle-instantclient-sqlplus-*.rpm

# Setup environment
export ORACLE_HOME=/usr/lib/oracle/19.x/client64
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
```

## 🐛 Troubleshooting

### PostgreSQL: "function not found"
```bash
# List all functions
psql -h jip-cp-ipa-postgre17... -U postgres -d rh_mufg_ipa \
  -c "SELECT proname FROM pg_proc WHERE proname LIKE '%SFBKH%';"
```

### Oracle: "sqlplus not found"
```bash
# Check if installed
which sqlplus

# Check Oracle client
sqlplus -v
```

### Connection refused
```bash
# Test PostgreSQL connection
psql -h jip-cp-ipa-postgre17... -U postgres -d rh_mufg_ipa -c "SELECT 1;"

# Test Oracle connection (if sqlplus installed)
sqlplus admin/oracle19@jip-cp-ipa-oracle19c...:1521/ORCL
```

## 📖 Tips

1. **Interactive mode** là dễ nhất cho người mới
2. **Verbose mode** (`--verbose`) giúp debug connection issues
3. **Oracle strings** phải quote kép: `"'value'"` 
4. **PostgreSQL strings** chỉ cần quote đơn: `'value'`
5. Dùng **empty string** cho optional params: `''` (PG) hoặc `"''"` (Oracle)
6. **Test stub functions** sẽ return 0 và log notice message

## 🎉 Success Criteria

Khi test thành công, bạn sẽ thấy:
- ✅ Green "Success" message
- ✅ Function result/output
- ✅ Exit code 0

Khi test fail, bạn sẽ thấy:
- ❌ Red "Error" message  
- ❌ Error details
- ❌ Exit code non-zero

---

**Created:** November 4, 2025  
**Purpose:** Test migrated functions on PostgreSQL and compare with Oracle
