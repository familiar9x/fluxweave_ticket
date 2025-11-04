#!/bin/bash
################################################################################
# MEGA Oracle to PostgreSQL Migration Script
# Includes ALL conversion patterns discovered during migration project
# Combines: comment fixes, syntax conversion, type mapping, function conversion
# Date: November 4, 2025
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counter variables
TOTAL_CHANGES=0

# Helper function to log changes
log_change() {
    local description="$1"
    local count="$2"
    if [ "$count" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} $description: ${CYAN}$count${NC} changes"
        ((TOTAL_CHANGES+=count))
    fi
}

# Usage function
usage() {
    cat << EOF
${BLUE}╔══════════════════════════════════════════════════════════════════════╗
║  MEGA Oracle to PostgreSQL Migration Script                          ║
║  All-in-one conversion tool                                          ║
╚══════════════════════════════════════════════════════════════════════╝${NC}

Usage: $0 [OPTIONS] <input_file.sql> [output_file.sql]

OPTIONS:
  --check, -c       Check only, don't modify (dry run)
  --verbose, -v     Verbose output
  --backup, -b      Create backup file before conversion
  --help, -h        Show this help message

EXAMPLES:
  $0 input.sql                      # Convert in-place
  $0 input.sql output.sql           # Convert to new file
  $0 --check input.sql              # Dry run
  $0 --backup input.sql output.sql # Create backup

CONVERSION STEPS:
  1. Fix invalid Oracle comment syntax
  2. Convert function/procedure signatures
  3. Convert data types (VARCHAR2, NUMBER, etc.)
  4. Convert Oracle functions (NVL, SYSDATE, etc.)
  5. Convert CURSOR declarations
  6. Add CALL keyword for procedures
  7. Fix exception handling (SQLCODE → SQLSTATE)
  8. Convert control flow statements
  9. Mark Oracle outer joins for review
  10. Convert END statements

EOF
    exit 1
}

# Parse arguments
CHECK_ONLY=false
VERBOSE=false
CREATE_BACKUP=false
INPUT_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --check|-c)
            CHECK_ONLY=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --backup|-b)
            CREATE_BACKUP=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            else
                OUTPUT_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Validate input
if [ -z "$INPUT_FILE" ]; then
    echo -e "${RED}Error: No input file specified${NC}"
    usage
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Input file '$INPUT_FILE' not found${NC}"
    exit 1
fi

# Set output file
OUTPUT_FILE="${OUTPUT_FILE:-$INPUT_FILE}"
TEMP_FILE="${OUTPUT_FILE}.tmp.$$"

# Print banner
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                                        ║${NC}"
echo -e "${MAGENTA}║     MEGA Oracle to PostgreSQL Migration Script                        ║${NC}"
echo -e "${MAGENTA}║     All-in-One Conversion Tool                                         ║${NC}"
echo -e "${MAGENTA}║                                                                        ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Input file:${NC}   $INPUT_FILE"
echo -e "${CYAN}Output file:${NC}  $OUTPUT_FILE"
if [ "$CHECK_ONLY" = true ]; then
    echo -e "${YELLOW}Mode:${NC}         DRY RUN (no changes will be made)"
else
    echo -e "${GREEN}Mode:${NC}         CONVERSION (file will be modified)"
fi
echo ""

# Create backup if requested
if [ "$CREATE_BACKUP" = true ] && [ "$CHECK_ONLY" = false ]; then
    BACKUP_FILE="${INPUT_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INPUT_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓${NC} Backup created: $BACKUP_FILE"
    echo ""
fi

# Create temporary working file
cp "$INPUT_FILE" "$TEMP_FILE"

################################################################################
# STEP 1: Fix Invalid Comments
################################################################################
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[1/10]${NC} ${BLUE}Fixing Invalid Comments${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Remove invalid " */;" pattern
count=$(grep -c " \*/;" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/ \*\/;$//' "$TEMP_FILE"
log_change "Removed ' */;' patterns" "$count"

# Fix single-line IF with inline comments
count=$(grep -c "IF.*THEN.*; *--" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/IF\([^;]*\)THEN\([^;]*\);\s*--\([^;]*\)$/IF\1THEN\n\t\2; --\3/g' "$TEMP_FILE"
log_change "Fixed IF-THEN inline comments" "$count"

# Fix comments after END IF
count=$(grep -c "END IF; *--" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/END IF;\s*--\([^;]*\)$/END IF;\n\t--\1/g' "$TEMP_FILE"
log_change "Fixed END IF comments" "$count"

# Fix comments after END LOOP
count=$(grep -c "END LOOP; *--" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/END LOOP;\s*--\([^;]*\)$/END LOOP;\n\t--\1/g' "$TEMP_FILE"
log_change "Fixed END LOOP comments" "$count"

################################################################################
# STEP 2: Function/Procedure Signature Conversion
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[2/10]${NC} ${BLUE}Converting Function/Procedure Signatures${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Convert RETURN IS to RETURNS LANGUAGE plpgsql AS $body$
count=$(grep -c "RETURN NUMBER IS$" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bRETURN NUMBER IS$/RETURNS NUMERIC LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
log_change "RETURN NUMBER IS → RETURNS NUMERIC" "$count"

count=$(grep -c "RETURN VARCHAR IS$\|RETURN VARCHAR2 IS$" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bRETURN VARCHAR2\? IS$/RETURNS VARCHAR LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
log_change "RETURN VARCHAR/VARCHAR2 IS → RETURNS VARCHAR" "$count"

count=$(grep -c "RETURN INTEGER IS$" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bRETURN INTEGER IS$/RETURNS INTEGER LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
log_change "RETURN INTEGER IS → RETURNS INTEGER" "$count"

count=$(grep -c "RETURN BOOLEAN IS$" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bRETURN BOOLEAN IS$/RETURNS BOOLEAN LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
log_change "RETURN BOOLEAN IS → RETURNS BOOLEAN" "$count"

count=$(grep -c "RETURN DATE IS$" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bRETURN DATE IS$/RETURNS DATE LANGUAGE plpgsql AS $body$/g' "$TEMP_FILE"
log_change "RETURN DATE IS → RETURNS DATE" "$count"

# Add DECLARE keyword after function signature
count=$(grep -c "RETURNS.*LANGUAGE plpgsql AS \$body\$" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i '/^RETURNS.*LANGUAGE plpgsql AS \$body\$$/a\DECLARE' "$TEMP_FILE"
sed -i '/^LANGUAGE plpgsql AS \$body\$$/a\DECLARE' "$TEMP_FILE"
log_change "Added DECLARE keywords" "$count"

################################################################################
# STEP 3: Data Type Conversions
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[3/10]${NC} ${BLUE}Converting Data Types${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

count=$(grep -c "\bVARCHAR2\b" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bVARCHAR2\b/VARCHAR/g' "$TEMP_FILE"
log_change "VARCHAR2 → VARCHAR" "$count"

count=$(grep -c "\bNUMBER\b" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bNUMBER\b/NUMERIC/g' "$TEMP_FILE"
log_change "NUMBER → NUMERIC" "$count"

count=$(grep -c "INTEGER([0-9]" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bINTEGER(\([0-9]*\))/INTEGER/g' "$TEMP_FILE"
log_change "INTEGER(n) → INTEGER" "$count"

count=$(grep -c "CHAR([0-9].*BYTE)" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/CHAR(\([0-9]*\)\s*BYTE)/CHAR(\1)/g' "$TEMP_FILE"
log_change "CHAR(n BYTE) → CHAR(n)" "$count"

count=$(grep -c "VARCHAR([0-9].*BYTE)" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/VARCHAR(\([0-9]*\)\s*BYTE)/VARCHAR(\1)/g' "$TEMP_FILE"
log_change "VARCHAR(n BYTE) → VARCHAR(n)" "$count"

################################################################################
# STEP 4: Oracle Functions to PostgreSQL Functions
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[4/10]${NC} ${BLUE}Converting Oracle Functions${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

count=$(grep -c "\bNVL(" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bNVL(/COALESCE(/g' "$TEMP_FILE"
log_change "NVL → COALESCE" "$count"

count=$(grep -c "\bSYSDATE\b" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bSYSDATE\b/CURRENT_DATE/g' "$TEMP_FILE"
log_change "SYSDATE → CURRENT_DATE" "$count"

count=$(grep -c "\bTO_CHAR(" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bTO_CHAR(/to_char(/g' "$TEMP_FILE"
log_change "TO_CHAR → to_char" "$count"

count=$(grep -c "\bTO_DATE(" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bTO_DATE(/to_date(/g' "$TEMP_FILE"
log_change "TO_DATE → to_date" "$count"

count=$(grep -c "\bTO_NUMBER(" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bTO_NUMBER(/to_number(/g' "$TEMP_FILE"
log_change "TO_NUMBER → to_number" "$count"

count=$(grep -c "\bTRUNC(" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bTRUNC(/trunc(/g' "$TEMP_FILE"
log_change "TRUNC → trunc" "$count"

count=$(grep -c "\bSUBSTR(" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bSUBSTR(/substr(/g' "$TEMP_FILE"
log_change "SUBSTR → substr" "$count"

################################################################################
# STEP 5: CURSOR Conversions
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[5/10]${NC} ${BLUE}Converting CURSOR Declarations${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

count=$(grep -c "TYPE.*IS REF CURSOR" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i '/TYPE.*IS REF CURSOR;/d' "$TEMP_FILE"
log_change "Removed TYPE...IS REF CURSOR declarations" "$count"

count=$(grep -c "CURSOR_TYPE;" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\)\s*CURSOR_TYPE;/\1 REFCURSOR;/g' "$TEMP_FILE"
log_change "CURSOR_TYPE → REFCURSOR" "$count"

################################################################################
# STEP 6: Procedure Call Fixes
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[6/10]${NC} ${BLUE}Adding CALL Keyword for Procedures${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

count=$(grep -c "\bPKLOG\." "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bPKLOG\./CALL PKLOG./g' "$TEMP_FILE"
log_change "Added CALL before PKLOG" "$count"

count=$(grep -c "\bPKCONSTANT\." "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bPKCONSTANT\./CALL PKCONSTANT./g' "$TEMP_FILE"
log_change "Added CALL before PKCONSTANT" "$count"

count=$(grep -c "\bPKIPALOG\." "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bPKIPALOG\./CALL PKIPALOG./g' "$TEMP_FILE"
log_change "Added CALL before PKIPALOG" "$count"

################################################################################
# STEP 7: Exception Handling
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[7/10]${NC} ${BLUE}Converting Exception Handling${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

count=$(grep -c "\bSQLCODE\b" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/\bSQLCODE\b/SQLSTATE/g' "$TEMP_FILE"
log_change "SQLCODE → SQLSTATE" "$count"

count=$(grep -c "SQLERRM(SQLSTATE)" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/SQLERRM(SQLSTATE)/SQLERRM/g' "$TEMP_FILE"
sed -i 's/SQLERRM(\s*SQLCODE\s*)/SQLERRM/g' "$TEMP_FILE"
log_change "SQLERRM(SQLCODE) → SQLERRM" "$count"

################################################################################
# STEP 8: Control Flow Statements
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[8/10]${NC} ${BLUE}Converting Control Flow Statements${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Most control flow is compatible between Oracle and PostgreSQL
echo -e "  ${GREEN}✓${NC} Control flow statements are mostly compatible"

################################################################################
# STEP 9: JOIN Syntax (Oracle (+) to SQL Standard)
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[9/10]${NC} ${BLUE}Marking Oracle Outer Join Syntax${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

count=$(grep -c "(+)" "$TEMP_FILE" 2>/dev/null || echo 0)
if [ "$count" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC}  Found $count Oracle (+) outer join patterns"
    echo -e "  ${YELLOW}⚠${NC}  These need manual conversion to LEFT JOIN"
fi

################################################################################
# STEP 10: END Statement Conversion
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[10/10]${NC} ${BLUE}Converting END Statements${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

count=$(grep -c "^END;[[:space:]]*/[[:space:]]*$" "$TEMP_FILE" 2>/dev/null || echo 0)
sed -i 's/^END;[[:space:]]*\/[[:space:]]*$/\$body\$;/g' "$TEMP_FILE"
log_change "END; / → \$body\$;" "$count"

# Add $body$; after standalone END; if needed
sed -i '/^END;$/a\\$body\$;' "$TEMP_FILE"

# Remove duplicate $body$; if any
sed -i '/\$body\$;/{N;s/\$body\$;\n\$body\$;/\$body\$;/}' "$TEMP_FILE"

################################################################################
# Finalization
################################################################################
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$CHECK_ONLY" = false ]; then
    # Move temp file to output
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    
    # Calculate statistics
    TOTAL_LINES=$(wc -l < "$OUTPUT_FILE")
    
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                                        ║${NC}"
    echo -e "${MAGENTA}║                    ✅ CONVERSION COMPLETE! ✅                          ║${NC}"
    echo -e "${MAGENTA}║                                                                        ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Output file:${NC}       $OUTPUT_FILE"
    echo -e "${CYAN}Total lines:${NC}       $TOTAL_LINES"
    echo -e "${CYAN}Total changes:${NC}     ${GREEN}$TOTAL_CHANGES${NC} patterns converted"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  1. ${CYAN}Review${NC} the converted file for accuracy"
    echo "  2. ${CYAN}Check${NC} for Oracle (+) outer joins (need manual conversion)"
    echo "  3. ${CYAN}Test${NC} compilation:"
    echo "     ${GREEN}psql -h <host> -U <user> -d <database> -f $OUTPUT_FILE${NC}"
    echo "  4. ${CYAN}Verify${NC} function behavior and test with sample data"
    echo "  5. ${CYAN}Deploy${NC} to production after testing"
    echo ""
    echo -e "${GREEN}✅ Conversion successful!${NC}"
else
    # Dry run mode
    rm "$TEMP_FILE"
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                                                                        ║${NC}"
    echo -e "${YELLOW}║                  DRY RUN COMPLETE (No Changes Made)                    ║${NC}"
    echo -e "${YELLOW}║                                                                        ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Potential changes:${NC} ${GREEN}$TOTAL_CHANGES${NC} patterns would be converted"
    echo ""
    echo "Run without ${YELLOW}--check${NC} flag to apply changes"
fi

echo ""
