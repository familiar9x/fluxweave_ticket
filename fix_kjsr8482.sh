#!/bin/bash
FILE="kjsr-8482_SFIPH007K00R01_clean.sql"

# 1. Fix TYPE definitions
sed -i 's/VTESURYO\.HKT_CD%TYPE/char(6)/g' $FILE
sed -i 's/VTESURYO\.KAIKEI_KBN%TYPE/char(2)/g' $FILE  
sed -i 's/VTESURYO\.TORIKESHI_FLG%TYPE/char(1)/g' $FILE

# 2. Fix integer(2) -> integer
sed -i 's/integer(2)/integer/g' $FILE

# 3. Fix array syntax () -> []
sed -i 's/recHeader(/recHeader[/g' $FILE
sed -i 's/recMeisai(/recMeisai[/g' $FILE
sed -i 's/recKbnTotal(/recKbnTotal[/g' $FILE
sed -i 's/recMgrTotal(/recMgrTotal[/g' $FILE
sed -i 's/l_outstr(/l_outstr[/g' $FILE
sed -i 's/l_outHeaderFlg(/l_outHeaderFlg[/g' $FILE
sed -i 's/l_kaikeiKbnArr(/l_kaikeiKbnArr[/g' $FILE

# 4. Add tmpRecHeader, tmpRecMeisai for FETCH INTO
sed -i '/DECLARE/a\\ttmpRecHeader sfiph007k00r01_type_rec_header;\n\ttmpRecMeisai sfiph007k00r01_type_rec_meisai;' $FILE

# 5. Add RTN constants
sed -i '/DECLARE/a\\tRTN_OK CONSTANT integer := 0;\n\tRTN_NG CONSTANT integer := 1;\n\tRTN_NODATA CONSTANT integer := 2;\n\tRTN_FATAL CONSTANT integer := 99;' $FILE

# 6. Replace pkconstant calls
sed -i 's/RETURN pkconstant\.error()/RETURN RTN_NG/g' $FILE
sed -i 's/RETURN pkconstant\.success()/RETURN RTN_OK/g' $FILE
sed -i 's/RETURN pkconstant\.FATAL()/RETURN RTN_FATAL/g' $FILE

# 7. Comment out PKLOG
sed -i 's/^\([[:space:]]*\)CALL PKLOG/\1-- CALL PKLOG/g' $FILE

# 8. Fix Oracle (+) outer join to LEFT JOIN - need manual review
echo "⚠️  Oracle (+) outer joins need manual conversion to LEFT JOIN"

# 9. Fix NVL to COALESCE  
sed -i 's/NVL(/COALESCE(/g' $FILE

# 10. Fix CASE NVL pattern (if exists)
sed -i 's/CASE COALESCE(\([^)]*\), *'"'"'\([^'"'"']*\)'"'"') WHEN/CASE COALESCE(\1, '"'"'\2'"'"') WHEN/g' $FILE

echo "✅ Applied all automatic fixes"
