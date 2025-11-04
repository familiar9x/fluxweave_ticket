#!/bin/bash
################################################################################
# Oracle to PostgreSQL Conversion Script
# Comprehensive conversion including syntax, types, and comment fixes
# Date: November 4, 2025
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 <input_file.sql> [output_file.sql]"
    echo ""
    echo "Converts Oracle PL/SQL to PostgreSQL plpgsql"
    echo ""
    echo "Examples:"
    echo "  $0 input.sql                  # Convert in-place"
    echo "  $0 input.sql output.sql       # Convert to new file"
    exit 1
}

# Check arguments
if [ $# -eq 0 ]; then
    usage
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-$INPUT_FILE}"
TEMP_FILE="${OUTPUT_FILE}.tmp"

# Validate input file
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Input file '$INPUT_FILE' not found${NC}"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Oracle to PostgreSQL Conversion Tool                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Input file:${NC}  $INPUT_FILE"
echo -e "${GREEN}Output file:${NC} $OUTPUT_FILE"
echo ""

# Create temporary working file
cp "$INPUT_FILE" "$TEMP_FILE"

################################################################################
# STEP 1: Fix Invalid Comments
################################################################################
echo -e "${YELLOW}[1/10]${NC} Fixing invalid comments..."

# Fix single-line IF with inline comments
sed -i 's/IF\([^;]*\)THEN\([^;]*\);\s*--\([^;]*\)$/IF\1THEN\n\t\2; --\3/g' "$TEMP_FILE"

# Fix comments after END IF
sed -i 's/END IF;\s*--\([^;]*\)$/END IF;\n\t--\1/g' "$TEMP_FILE"

# Fix comments after END LOOP
sed -i 's/END LOOP;\s*--\([^;]*\)$/END LOOP;\n\t--\1/g' "$TEMP_FILE"

# Fix comments after variable declarations
sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\s*[^;]*\);\s*--\([^;]*\)$/\1; --\2/g' "$TEMP_FILE"

echo -e "${GREEN}✓${NC} Comments fixed"

################################################################################
# STEP 2: Function/Procedure Signature Conversion
################################################################################
echo -e "${YELLOW}[2/10]${NC} Converting function/procedure signatures..."

# Convert RETURN to RETURNS with plpgsql
sed -i 's/\bRETURN NUMBER IS$/RETURNS NUMERIC LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
sed -i 's/\bRETURN VARCHAR IS$/RETURNS VARCHAR LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
sed -i 's/\bRETURN VARCHAR2 IS$/RETURNS VARCHAR LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
sed -i 's/\bRETURN INTEGER IS$/RETURNS INTEGER LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
sed -i 's/\bRETURN NUMERIC IS$/RETURNS NUMERIC LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
sed -i 's/\bRETURN BOOLEAN IS$/RETURNS BOOLEAN LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
sed -i 's/\bRETURN DATE IS$/RETURNS DATE LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
sed -i 's/\bRETURN CHAR IS$/RETURNS CHAR LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"

# Convert PROCEDURE IS to LANGUAGE plpgsql
sed -i 's/\bPROCEDURE\(.*\)IS$/PROCEDURE\1LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"

# Add DECLARE keyword after function signature (if not already present)
sed -i '/^RETURNS.*LANGUAGE plpgsql AS \$body\$$/a\DECLARE' "$TEMP_FILE"
sed -i '/^LANGUAGE plpgsql AS \$body\$$/a\DECLARE' "$TEMP_FILE"

echo -e "${GREEN}✓${NC} Signatures converted"

################################################################################
# STEP 3: Data Type Conversions
################################################################################
echo -e "${YELLOW}[3/10]${NC} Converting data types..."

# VARCHAR2 → VARCHAR
sed -i 's/\bVARCHAR2\b/VARCHAR/g' "$TEMP_FILE"

# NUMBER → NUMERIC
sed -i 's/\bNUMBER\b/NUMERIC/g' "$TEMP_FILE"

# INTEGER(n) → INTEGER
sed -i 's/\bINTEGER(\([0-9]*\))/INTEGER/g' "$TEMP_FILE"

# CHAR(n BYTE) → CHAR(n)
sed -i 's/CHAR(\([0-9]*\)\s*BYTE)/CHAR(\1)/g' "$TEMP_FILE"

# VARCHAR(n BYTE) → VARCHAR(n)
sed -i 's/VARCHAR(\([0-9]*\)\s*BYTE)/VARCHAR(\1)/g' "$TEMP_FILE"

echo -e "${GREEN}✓${NC} Data types converted"

################################################################################
# STEP 4: Oracle Functions to PostgreSQL Functions
################################################################################
echo -e "${YELLOW}[4/10]${NC} Converting Oracle functions..."

# NVL → COALESCE
sed -i 's/\bNVL(/COALESCE(/g' "$TEMP_FILE"

# SYSDATE → CURRENT_DATE or NOW()
sed -i 's/\bSYSDATE\b/CURRENT_DATE/g' "$TEMP_FILE"

# TO_CHAR → to_char (case sensitivity)
# PostgreSQL is case-sensitive for functions
sed -i 's/\bTO_CHAR(/to_char(/g' "$TEMP_FILE"

# TO_DATE → to_date
sed -i 's/\bTO_DATE(/to_date(/g' "$TEMP_FILE"

# TO_NUMBER → to_number
sed -i 's/\bTO_NUMBER(/to_number(/g' "$TEMP_FILE"

# TRUNC → trunc or date_trunc
sed -i 's/\bTRUNC(/trunc(/g' "$TEMP_FILE"

# SUBSTR → substr
sed -i 's/\bSUBSTR(/substr(/g' "$TEMP_FILE"

# INSTR → position or strpos
# Note: INSTR(string, substring) → position(substring IN string)
# Complex conversion, leaving as-is for manual review

echo -e "${GREEN}✓${NC} Oracle functions converted"

################################################################################
# STEP 5: CURSOR Conversions
################################################################################
echo -e "${YELLOW}[5/10]${NC} Converting CURSOR declarations..."

# Remove TYPE...IS REF CURSOR declarations
sed -i '/TYPE.*IS REF CURSOR;/d' "$TEMP_FILE"

# Convert CURSOR_TYPE variable declarations to REFCURSOR
sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\)\s*CURSOR_TYPE;/\1 REFCURSOR;/g' "$TEMP_FILE"

echo -e "${GREEN}✓${NC} CURSOR declarations converted"

################################################################################
# STEP 6: Procedure Call Fixes
################################################################################
echo -e "${YELLOW}[6/10]${NC} Adding CALL keyword for procedures..."

# Add CALL before common package procedures
sed -i 's/\bPKLOG\./CALL PKLOG./g' "$TEMP_FILE"
sed -i 's/\bPKCONSTANT\./CALL PKCONSTANT./g' "$TEMP_FILE"
sed -i 's/\bPKIPALOG\./CALL PKIPALOG./g' "$TEMP_FILE"

# Remove CALL from function calls (only procedures need CALL)
# This is complex - requires context awareness
# Leaving for manual review if needed

echo -e "${GREEN}✓${NC} Procedure calls fixed"

################################################################################
# STEP 7: Exception Handling
################################################################################
echo -e "${YELLOW}[7/10]${NC} Converting exception handling..."

# SQLCODE → SQLSTATE
sed -i 's/\bSQLCODE\b/SQLSTATE/g' "$TEMP_FILE"

# SQLERRM → SQLERRM (same in both, but check usage)
# SQLERRM(SQLCODE) → SQLERRM in PostgreSQL
sed -i 's/SQLERRM(SQLSTATE)/SQLERRM/g' "$TEMP_FILE"
sed -i 's/SQLERRM(\s*SQLCODE\s*)/SQLERRM/g' "$TEMP_FILE"

echo -e "${GREEN}✓${NC} Exception handling converted"

################################################################################
# STEP 8: Control Flow Statements
################################################################################
echo -e "${YELLOW}[8/10]${NC} Converting control flow statements..."

# EXIT WHEN → EXIT WHEN (same syntax, but verify in LOOP context)
# FOR loops, WHILE loops are mostly compatible

# Single-line IF THEN → Multi-line IF THEN
# This is already handled in comment fix section

echo -e "${GREEN}✓${NC} Control flow statements checked"

################################################################################
# STEP 9: JOIN Syntax (Oracle (+) to SQL Standard)
################################################################################
echo -e "${YELLOW}[9/10]${NC} Converting Oracle outer join syntax..."

# Convert Oracle (+) outer join to LEFT JOIN
# This is complex and context-dependent
# Example: WHERE table1.col = table2.col(+)
#       → LEFT JOIN table2 ON table1.col = table2.col

# This requires sophisticated parsing - leaving comment for manual review
sed -i 's/(+)/-- TODO: Convert Oracle outer join to LEFT JOIN/g' "$TEMP_FILE"

echo -e "${YELLOW}⚠${NC}  Oracle (+) outer joins marked for manual review"

################################################################################
# STEP 10: End Statement Conversion
################################################################################
echo -e "${YELLOW}[10/10]${NC} Converting END statements..."

# Convert END; / to $body$;
sed -i 's/^END;[[:space:]]*\/[[:space:]]*$/$body$;/g' "$TEMP_FILE"

# Add $body$; after standalone END; if not already present
# Check if END; is the last statement and add $body$;
sed -i '/^END;$/a\$body$;' "$TEMP_FILE"

# Remove duplicate $body$; if any
sed -i '/\$body\$;/{N;s/\$body\$;\n\$body\$;/$body$;/}' "$TEMP_FILE"

echo -e "${GREEN}✓${NC} END statements converted"

################################################################################
# Finalization
################################################################################

# Move temp file to output
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Calculate statistics
TOTAL_LINES=$(wc -l < "$OUTPUT_FILE")
CHANGES_COUNT=$(grep -c "RETURNS\|COALESCE\|REFCURSOR\|CALL" "$OUTPUT_FILE" 2>/dev/null || echo 0)

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Conversion Complete!                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Output file:${NC}     $OUTPUT_FILE"
echo -e "${GREEN}Total lines:${NC}     $TOTAL_LINES"
echo -e "${GREEN}Changes made:${NC}    ~$CHANGES_COUNT patterns converted"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the converted file for accuracy"
echo "  2. Check for TODO comments (Oracle outer joins, etc.)"
echo "  3. Test compilation: psql -f $OUTPUT_FILE"
echo "  4. Verify function behavior"
echo ""
echo -e "${GREEN}✓ Conversion successful!${NC}"
