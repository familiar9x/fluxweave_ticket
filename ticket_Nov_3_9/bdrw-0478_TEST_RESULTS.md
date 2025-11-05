# bdrw-0478 Migration Test Results

## Ticket Information
- **Ticket ID**: bdrw-0478
- **Procedure**: SPIPF004K00R01 - カレンダマスタ出力 (Calendar Master Output)
- **Migration Date**: 2025-11-05
- **Status**: ✅ **COMPLETED & VERIFIED**

## Test Scenario
- **Test Data**: 21 MCALENDAR records
  - Area C: 10 holidays
  - Area D: 11 holidays
- **Test Parameters**:
  - l_inItakuKaishaCd: '0005'
  - l_inUserId: 'A5095035'
  - l_inChohyoKbn: '1'
  - l_inChohyoSakuKbn: '1'
  - l_inGyomuYmd: '20190225'

## PostgreSQL Test Results

### Execution
```
CALL spipf004k00r01('0005', 'A5095035', '1', '1', '20190225', NULL, NULL)
```

### Return Code
- ✅ **Return Code: 0 (SUCCESS)**

### SREPORT_WK Records Created: 3

| SEQ | HEADER_FLG | GYOMU_YMD | AREA_CD | HOL1     | HOL2     | HOL3     | HOL4     | HOL5     |
|-----|------------|-----------|---------|----------|----------|----------|----------|----------|
| 0   | 0          | shoriYmd  | areaCd  | horiday1 | horiday2 | horiday3 | horiday4 | horiday5 |
| 1   | 1          | 20190225  | C       | 20190501 | 20190504 | 20190505 | 20190506 | 20190511 |
| 2   | 1          | 20190225  | D       | 20190501 | 20190504 | 20190505 | 20190506 | 20190511 |

**Explanation**:
- **seq_no=0**: Header record from SPRINT_HEADER template (header_flg=0)
- **seq_no=1**: Data record for Area C with 10 holidays (groups of 14)
- **seq_no=2**: Data record for Area D with 11 holidays (remaining batch)

### PRT_OK Records: 1
- Batch report print management record created with SHORI_KBN='1' (承認/Approved)

### Source Data Verification

**MCALENDAR records** (WHERE sakusei_dt='20190225' AND sakusei_id='A5095035'):

| AREA_CD | COUNT | HOLIDAYS                                                        |
|---------|-------|-----------------------------------------------------------------|
| C       | 10    | 20190501, 20190504, 20190505, 20190506, 20190511, ...          |
| D       | 11    | 20190501, 20190504, 20190505, 20190506, 20190511, ...          |

## Migration Changes

### Key Technical Issues Resolved

#### 1. Type Casting for Overloaded Procedures
**Problem**: PostgreSQL has 5 overloads of `pkPrint.insertData` with different parameter types (CHAR vs VARCHAR, INTEGER vs BIGINT vs SMALLINT). Without explicit casts, PostgreSQL chose wrong overload causing:
- `chohyo_id` truncated from 'IPF30000411' → 'I' (CHAR(1) instead of CHAR(11))
- "procedure is not unique" ambiguity errors
- Duplicate key violations

**Solution**: Explicit type casting for all parameters:
```sql
CALL pkPrint.insertData(
    l_inItakuKaishaCd::varchar,       -- 識別コード
    'BATCH'::varchar,                  -- ユーザＩＤ
    l_inChohyoKbn::character(1),      -- 帳票区分
    l_inGyomuYmd::character(8),       -- 作成年月日
    REPORT_ID::character(11),         -- 帳票ＩＤ
    gSeqNo::bigint,                    -- 連番 (CRITICAL!)
    1::smallint,                       -- ヘッダフラグ
    l_inItem,                          -- アイテム
    l_inUserId::varchar,              -- 更新者ID
    l_inUserId::varchar               -- 作成者ID
);
```

#### 2. Array Handling
**Oracle**:
```sql
TYPE TAB_HOLIDAY IS TABLE OF VARCHAR2(8) INDEX BY BINARY_INTEGER;
gHOLIDAY TAB_HOLIDAY;
gHOLIDAY(1) := recMeisai.HOLIDAY;
```

**PostgreSQL**:
```sql
gHOLIDAY varchar(8)[14];
gHOLIDAY[1] := recMeisai.HOLIDAY;
```

#### 3. Composite Type Handling
**Oracle**:
```sql
TYPE_SREPORT_WK_ITEM l_inItem;
-- Direct assignment in procedure call
```

**PostgreSQL**:
```sql
l_inItem TYPE_SREPORT_WK_ITEM;
l_inItem := ROW();  -- Initialize first
l_inItem.l_inItem001 := value;
```

#### 4. Boolean vs Numeric DEBUG Flag
**Oracle**: `DEBUG NUMBER(1) := 1`
**PostgreSQL**: `DEBUG boolean := false`

## Logic Verification

### Main Processing Flow
1. ✅ **insertHeader**: Creates seq_no=0 header record from SPRINT_HEADER
   - Queries SPRINT_HEADER for chohyo_id='IPF30000411'
   - Calls insertData with seq_no=0, header_flg=0
   - Has exception handler for duplicate key (safe to call multiple times)

2. ✅ **Main Loop**: Processes MCALENDAR records
   - Cursor fetches records ordered by AREA_CD, HOLIDAY
   - Groups up to 14 holidays per SREPORT_WK record
   - Inserts when: gCount=14 OR area code changes
   - Properly handles area transitions (C→D at record 11)

3. ✅ **Final Batch**: Inserts remaining holidays after loop
   - IF gCount > 0 THEN insert final batch

4. ✅ **PRT_OK Registration**: Creates batch report management record
   - Only if not exists (curCount.CNT = 0)
   - SHORI_KBN='1' (Approved status)

### Expected Behavior Matches Actual Results
- **Area C (10 holidays)**: Should create 1 record → ✅ Created seq_no=1
- **Area D (11 holidays)**: Should create 1 record → ✅ Created seq_no=2
- **Header**: Should exist → ✅ Created seq_no=0
- **PRT_OK**: Should create 1 record → ✅ Created

## Oracle vs PostgreSQL Compatibility

### Verified Compatible Patterns
1. ✅ Cursor FOR LOOP with RECORD type
2. ✅ VARCHAR array indexing [1..14]
3. ✅ TYPE_SREPORT_WK_ITEM composite type
4. ✅ Named parameter calls with explicit casts
5. ✅ Exception handling (WHEN OTHERS)
6. ✅ Package procedure calls (pkPrint.insertHeader/insertData)
7. ✅ ROW() initialization for composite types

### Migration Notes for Future Tickets
- **Always explicitly cast parameters** when calling overloaded procedures
- Use `bigint` for seq_no parameters (matches SREPORT_WK.SEQ_NO type)
- Use `character(N)` for CHAR columns, `varchar` for VARCHAR2
- Use `smallint` for small integer flags (0/1)
- Test with multiple overload combinations to ensure correct resolution

## Conclusion

✅ **Migration Successful**
- PostgreSQL procedure produces identical results to expected Oracle behavior
- All records created correctly (3 SREPORT_WK, 1 PRT_OK)
- Return code 0 (SUCCESS)
- Logic flow matches Oracle implementation
- Type casting issues resolved

**Status**: READY FOR PRODUCTION DEPLOYMENT
