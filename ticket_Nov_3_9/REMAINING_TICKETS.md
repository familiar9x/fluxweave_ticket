# REMAINING TICKETS - Complex Oracle Features

## Summary
2 tickets remain incomplete due to complex Oracle-specific features that require architectural changes beyond simple syntax conversion.

**Status: 14/16 tickets complete (87.5%)**
**Remaining work: ~6-8 hours for both tickets**

---

## kjsr-8482: SFIPH007K00R01.SQL (1,185 lines)
**Status:** 40% complete (basic syntax done, blocked on nested functions + types)
**File:** `/home/ec2-user/jip-ipa/db/plsql/ipa/option/chikoutai/SFIPH007K00R01.SQL`

### Completed:
- ✅ Function signature conversion
- ✅ VARCHAR2→VARCHAR, NUMBER→NUMERIC
- ✅ CURSOR declarations converted to REFCURSOR
- ✅ CALL keyword added for procedures

### Blocking Issues:
1. **3 Nested Functions** (lines 132, 340, 566):
   - `createSqlHeader()` - 200+ lines of dynamic SQL building
   - `createSqlMeisai()` - 200+ lines of dynamic SQL building  
   - `setNodataKaikeiKbn()` - Simple helper function
   - **Problem:** PostgreSQL doesn't support nested function definitions like Oracle
   - **Solution needed:** Extract to standalone functions, then call them

2. **6+ Complex Type Definitions** (lines 84-165):
   - `TYPE VCR_ARRAY10K IS TABLE OF VARCHAR(10000) INDEX BY BINARY_INTEGER`
   - `TYPE TYPE_REC_HEADER IS RECORD(...)` (5 fields)
   - `TYPE TYPE_TBL_REC_HEADER IS TABLE OF TYPE_REC_HEADER INDEX BY BINARY_INTEGER`
   - Similar for MEISAI (20 fields) and KBN_TOTAL (14 fields)
   - **Problem:** INDEX BY BINARY_INTEGER (Oracle associative arrays) not supported
   - **Solution needed:** 
     * Create external composite types (TYPE_REC_HEADER, TYPE_REC_MEISAI, TYPE_REC_KBN_TOTAL)
     * Convert TABLE OF to PostgreSQL arrays
     * Refactor INDEX BY BINARY_INTEGER access to 1-based numeric arrays

### Work Remaining:
1. Extract 3 helper functions to separate file (SFIPH007K00R01_helpers.sql)
2. Create composite types file (TYPE_SFIPH007K00R01.sql) - already created!
3. Convert TYPE...IS TABLE declarations to array syntax
4. Fix nested function calls to use standalone function names
5. Test and fix array access patterns (Oracle 0-based → PostgreSQL 1-based)
6. Compile and resolve remaining errors

**Estimated time:** 3-4 hours

---

## fsuj-6726: SPIPH006K00R02.SQL (1,658 lines)
**Status:** 30% complete (basic syntax done, blocked on types)
**File:** `/home/ec2-user/jip-ipa/db/plsql/ipa/option/chikoutai/SPIPH006K00R02.SQL`

### Completed:
- ✅ Function signature conversion  
- ✅ VARCHAR2→VARCHAR, NUMBER→NUMERIC
- ✅ Basic syntax converted

### Blocking Issues:
1. **3 Large TYPE...IS RECORD Definitions** (line 154+):
   - `TYPE_RECORD` - ~60 fields (gGankin1-8, gRkn1-8, gKaikeiKbn1-8, etc.)
   - Similar complexity to kjsr-8482 but larger record structures
   - Used throughout for complex CSV generation logic
   - **Problem:** Same as kjsr-8482 - TYPE...IS RECORD in function body not supported
   - **Solution needed:**
     * Extract to external CREATE TYPE statement
     * Convert usage to composite type
     * Handle %TYPE references in record fields

### Work Remaining:
1. Read and analyze the TYPE_RECORD structure (line 154)
2. Create external composite type file (TYPE_SPIPH006K00R02.sql)
3. Remove TYPE declaration from function body
4. Convert %TYPE references to actual types
5. Fix array/record access patterns if any
6. Compile and test

**Estimated time:** 2-3 hours

---

## Technical Notes

### Why These Are Complex:

**Oracle Feature:** Nested Functions
- Oracle allows FUNCTION/PROCEDURE definitions inside another function body
- These can access parent function's variables (closure)
- PostgreSQL requires all functions to be top-level
- Migration requires: extract → fix variable access → fix function calls

**Oracle Feature:** TYPE...IS RECORD in Function Body
- Oracle allows type definitions in DECLARE section
- Types are scoped to that function
- PostgreSQL requires types to be created at database level with CREATE TYPE
- Migration requires: extract type → replace %TYPE → update references

**Oracle Feature:** TABLE OF...INDEX BY BINARY_INTEGER
- Oracle's associative arrays (hash-like, arbitrary integer keys)
- PostgreSQL arrays are 1-based, sequential
- Migration requires: convert to arrays OR use hstore/jsonb OR refactor logic

### Files Created:
- `/home/ec2-user/jip-ipa/db/type/ipa/TYPE_SFIPH007K00R01.sql` ✅
  * TYPE_REC_HEADER composite type
  * TYPE_REC_MEISAI composite type
  * TYPE_REC_KBN_TOTAL composite type

- `/home/ec2-user/jip-ipa/db/plsql/ipa/option/chikoutai/SFIPH007K00R01_helpers.sql` ✅ (partial)
  * createSqlHeader() function
  * setNodataKaikeiKbn() function
  * **Note:** createSqlMeisai() still needs to be added

### Approach for Completion:

1. **For kjsr-8482:**
   ```bash
   # 1. Complete helper functions file (add createSqlMeisai)
   # 2. Remove nested functions from main file
   # 3. Convert TYPE declarations to arrays
   # 4. Compile types → helpers → main function
   # 5. Test and fix errors
   ```

2. **For fsuj-6726:**
   ```bash
   # 1. Extract TYPE_RECORD definition
   # 2. Create TYPE_SPIPH006K00R02.sql
   # 3. Remove TYPE from function body  
   # 4. Add type reference to top of function
   # 5. Compile and test
   ```

---

## Recommendation

These 2 files require **deep Oracle→PostgreSQL architectural migration**, not just syntax conversion. They involve:
- Refactoring code structure (nested → standalone functions)
- Type system changes (Oracle collections → PostgreSQL arrays/types)
- Logic refactoring (associative arrays → sequential arrays)

**Options:**
1. **Complete now:** 6-8 hours focused work
2. **Defer:** Mark as "advanced migration" tickets for specialized Oracle/PostgreSQL expert
3. **Alternative:** Rewrite these 2 functions from scratch in PostgreSQL-native style

**Impact:** These are "nice-to-have" ticket functions for complex CSV generation. Core system works with 87.5% completion.

