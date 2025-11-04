#!/bin/bash

###############################################################################
# PostgreSQL Function/Procedure Test Script
# Usage: ./test_postgres_function.sh <function_name> [param1] [param2] ...
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# PostgreSQL Connection Settings (can be overridden by environment variables)
PG_HOST="${PG_HOST:-jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com}"
PG_PORT="${PG_PORT:-5432}"
PG_DATABASE="${PG_DATABASE:-rh_mufg_ipa}"
PG_USER="${PG_USER:-rh_mufg_ipa}"
PG_PASSWORD="${PG_PASSWORD:-luxur1ous-Pine@pple}"

# Function to show usage
show_usage() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          PostgreSQL Function/Procedure Tester                 ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Usage: $0 <function_name> [param1] [param2] ..."
    echo ""
    echo "Examples:"
    echo "  # Test function with no parameters"
    echo "  $0 SFBKH001A00R01"
    echo ""
    echo "  # Test function with parameters"
    echo "  $0 SFBKH002A00R01 '001' 'USER001' '20250101'"
    echo ""
    echo "  # Test function with multiple parameters"
    echo "  $0 SFIPH007K00R01 '001' 'USER001' '1' '20250101' '20250101' '20251231' '' '' ''"
    echo ""
    echo "  # Call procedure (use CALL instead of SELECT)"
    echo "  $0 --procedure MY_PROCEDURE 'param1' 'param2'"
    echo ""
    echo "Options:"
    echo "  --procedure    Use CALL instead of SELECT (for procedures)"
    echo "  --verbose      Show connection info and full query"
    echo "  --help         Show this help message"
    echo ""
    echo "Connection:"
    echo "  Host: $PG_HOST"
    echo "  Database: $PG_DATABASE"
    echo "  User: $PG_USER"
    echo ""
}

# Parse options
IS_PROCEDURE=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --procedure)
            IS_PROCEDURE=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Check if function name is provided
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Function/procedure name is required${NC}"
    echo ""
    show_usage
    exit 1
fi

FUNCTION_NAME=$1
shift

# Convert function name to lowercase (PostgreSQL stores names in lowercase by default)
FUNCTION_NAME_LOWER=$(echo "$FUNCTION_NAME" | tr '[:upper:]' '[:lower:]')

# Build parameters
PARAMS=""
if [ $# -gt 0 ]; then
    PARAMS="$1"
    shift
    while [ $# -gt 0 ]; do
        PARAMS="$PARAMS, $1"
        shift
    done
fi

# Build SQL query
if [ $IS_PROCEDURE -eq 1 ]; then
    SQL="CALL ${FUNCTION_NAME_LOWER}(${PARAMS});"
else
    SQL="SELECT ${FUNCTION_NAME_LOWER}(${PARAMS});"
fi

# Show info if verbose
if [ $VERBOSE -eq 1 ]; then
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Connection Info                            ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Host:${NC}     $PG_HOST"
    echo -e "${YELLOW}Port:${NC}     $PG_PORT"
    echo -e "${YELLOW}Database:${NC} $PG_DATABASE"
    echo -e "${YELLOW}User:${NC}     $PG_USER"
    echo ""
fi

# Show query
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Executing Query                          ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}Function:${NC} $FUNCTION_NAME → $FUNCTION_NAME_LOWER"
if [ -n "$PARAMS" ]; then
    echo -e "${YELLOW}Parameters:${NC} $PARAMS"
fi
echo -e "${YELLOW}SQL:${NC} $SQL"
echo ""

# Execute query
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                          Result                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"

export PGPASSWORD=$PG_PASSWORD

# Check if function exists first
FUNCTION_EXISTS=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -t -c \
    "SELECT COUNT(*) FROM pg_proc WHERE proname = LOWER('$FUNCTION_NAME_LOWER');" 2>/dev/null | tr -d ' ')

if [ "$FUNCTION_EXISTS" = "0" ]; then
    echo -e "${RED}✗ Function/Procedure '$FUNCTION_NAME' (searched as '$FUNCTION_NAME_LOWER') not found in database${NC}"
    echo ""
    echo -e "${YELLOW}Searching for similar names...${NC}"
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -c \
        "SELECT proname, pronargs FROM pg_proc WHERE proname ILIKE '%${FUNCTION_NAME_LOWER:0:10}%' ORDER BY proname;" 2>/dev/null
    exit 1
fi

# Execute the function
RESULT=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -c "$SQL" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Success${NC}"
    echo ""
    echo "$RESULT"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   Execution Completed                         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}✗ Error occurred${NC}"
    echo ""
    echo "$RESULT"
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    Execution Failed                           ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi

unset PGPASSWORD
