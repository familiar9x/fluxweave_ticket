#!/bin/bash
################################################################################
# Batch Oracle to PostgreSQL Migration Script
# Process multiple files or entire directories
# Date: November 4, 2025
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTER_SCRIPT="$SCRIPT_DIR/mega_oracle_to_postgres.sh"

# Check if converter script exists
if [ ! -f "$CONVERTER_SCRIPT" ]; then
    echo -e "${RED}Error: Converter script not found at $CONVERTER_SCRIPT${NC}"
    exit 1
fi

# Make sure converter is executable
chmod +x "$CONVERTER_SCRIPT"

# Usage
usage() {
    cat << EOF
${MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗
║  Batch Oracle to PostgreSQL Migration Script                            ║
║  Process multiple files or entire directories                           ║
╚══════════════════════════════════════════════════════════════════════════╝${NC}

Usage: $0 [OPTIONS] <directory|file1.sql file2.sql ...>

OPTIONS:
  --check, -c       Dry run (check only, don't modify)
  --backup, -b      Create backup files before conversion
  --output, -o DIR  Output directory (default: same as input)
  --pattern PATTERN File pattern to match (default: *.sql *.SQL)
  --help, -h        Show this help message

EXAMPLES:
  # Convert all SQL files in a directory
  $0 db/plsql/ipa/

  # Convert specific files
  $0 file1.sql file2.sql file3.sql

  # Dry run to see what would be changed
  $0 --check db/plsql/ipa/

  # Convert with backups
  $0 --backup db/plsql/ipa/

  # Convert to different output directory
  $0 --output /tmp/converted db/plsql/ipa/

  # Convert only specific pattern
  $0 --pattern "PKI*.sql" db/plsql/ipa/

EOF
    exit 1
}

# Parse arguments
CHECK_ONLY=false
CREATE_BACKUP=false
OUTPUT_DIR=""
PATTERN="*.sql *.SQL"
INPUTS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --check|-c)
            CHECK_ONLY=true
            shift
            ;;
        --backup|-b)
            CREATE_BACKUP=true
            shift
            ;;
        --output|-o)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --pattern|-p)
            PATTERN="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            INPUTS+=("$1")
            shift
            ;;
    esac
done

# Validate inputs
if [ ${#INPUTS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No input files or directories specified${NC}"
    usage
fi

# Print banner
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                                          ║${NC}"
echo -e "${MAGENTA}║        BATCH Oracle to PostgreSQL Migration                             ║${NC}"
echo -e "${MAGENTA}║                                                                          ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Build file list
FILES=()
for input in "${INPUTS[@]}"; do
    if [ -f "$input" ]; then
        # Single file
        FILES+=("$input")
    elif [ -d "$input" ]; then
        # Directory - find SQL files
        while IFS= read -r -d '' file; do
            FILES+=("$file")
        done < <(find "$input" -type f \( -name "*.sql" -o -name "*.SQL" \) -print0)
    else
        echo -e "${YELLOW}Warning: '$input' not found, skipping${NC}"
    fi
done

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No SQL files found${NC}"
    exit 1
fi

echo -e "${CYAN}Files to process:${NC} ${GREEN}${#FILES[@]}${NC}"
if [ "$CHECK_ONLY" = true ]; then
    echo -e "${YELLOW}Mode:${NC} DRY RUN (no changes will be made)"
else
    echo -e "${GREEN}Mode:${NC} CONVERSION"
fi
if [ -n "$OUTPUT_DIR" ]; then
    echo -e "${CYAN}Output directory:${NC} $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi
echo ""

# Counters
TOTAL_FILES=${#FILES[@]}
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# Process each file
for ((i=0; i<${#FILES[@]}; i++)); do
    FILE="${FILES[$i]}"
    FILE_NUM=$((i+1))
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[$FILE_NUM/$TOTAL_FILES]${NC} Processing: ${YELLOW}$FILE${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Determine output file
    if [ -n "$OUTPUT_DIR" ]; then
        BASENAME=$(basename "$FILE")
        OUTPUT_FILE="$OUTPUT_DIR/$BASENAME"
    else
        OUTPUT_FILE="$FILE"
    fi
    
    # Build converter command
    CONVERTER_ARGS=()
    if [ "$CHECK_ONLY" = true ]; then
        CONVERTER_ARGS+=(--check)
    fi
    if [ "$CREATE_BACKUP" = true ]; then
        CONVERTER_ARGS+=(--backup)
    fi
    CONVERTER_ARGS+=("$FILE")
    if [ "$OUTPUT_FILE" != "$FILE" ]; then
        CONVERTER_ARGS+=("$OUTPUT_FILE")
    fi
    
    # Run converter
    if "$CONVERTER_SCRIPT" "${CONVERTER_ARGS[@]}"; then
        echo -e "${GREEN}✓ Success${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ Failed${NC}"
        ((FAILED_COUNT++))
    fi
    
    echo ""
done

# Print summary
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                                          ║${NC}"
echo -e "${MAGENTA}║                        BATCH CONVERSION SUMMARY                          ║${NC}"
echo -e "${MAGENTA}║                                                                          ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Total files:${NC}      $TOTAL_FILES"
echo -e "${GREEN}Successful:${NC}       $SUCCESS_COUNT"
echo -e "${RED}Failed:${NC}           $FAILED_COUNT"
echo -e "${YELLOW}Skipped:${NC}          $SKIPPED_COUNT"
echo ""

if [ $FAILED_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All files processed successfully!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some files failed to process${NC}"
    exit 1
fi
