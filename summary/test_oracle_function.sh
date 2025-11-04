#!/bin/bash

###############################################################################
# Oracle Function/Procedure Test Script
# Usage: ./test_oracle_function.sh <function_name> [param1] [param2] ...
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Oracle Connection Settings
ORACLE_HOST="jip-ipa-cp.cvmszg1k9xhh.us-east-1.rds.amazonaws.com"
ORACLE_PORT="1521"
ORACLE_SID="ORCL"
ORACLE_USER="RH_MUFG_IPA"
ORACLE_PASSWORD="g1normous-pik@chu"

# Function to show usage
show_usage() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            Oracle Function/Procedure Tester                   ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Usage: $0 <function_name> [param1] [param2] ..."
    echo ""
    echo "Examples:"
    echo "  # Test function with no parameters"
    echo "  $0 SFBKH001A00R01"
    echo ""
    echo "  # Test function with parameters (use Oracle syntax)"
    echo "  $0 SFBKH002A00R01 \"'001'\" \"'USER001'\" \"'20250101'\""
    echo ""
    echo "  # Test function with multiple parameters"
    echo "  $0 SFIPH007K00R01 \"'001'\" \"'USER001'\" \"1\" \"'20250101'\" \"'20250101'\" \"'20251231'\" \"''\" \"''\" \"''\""
    echo ""
    echo "  # Execute procedure (use EXECUTE or EXEC)"
    echo "  $0 --procedure MY_PROCEDURE \"'param1'\" \"'param2'\""
    echo ""
    echo "  # Use anonymous PL/SQL block"
    echo "  $0 --block MY_FUNCTION \"'param1'\" \"'param2'\""
    echo ""
    echo "Options:"
    echo "  --procedure    Use EXECUTE for procedure call"
    echo "  --block        Use anonymous PL/SQL block (for complex calls)"
    echo "  --verbose      Show connection info and full query"
    echo "  --help         Show this help message"
    echo ""
    echo "Connection:"
    echo "  Host: $ORACLE_HOST"
    echo "  SID: $ORACLE_SID"
    echo "  User: $ORACLE_USER"
    echo ""
}

# Parse options
IS_PROCEDURE=0
IS_BLOCK=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --procedure)
            IS_PROCEDURE=1
            shift
            ;;
        --block)
            IS_BLOCK=1
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

# Build SQL query based on type
if [ $IS_BLOCK -eq 1 ]; then
    # Anonymous PL/SQL block
    SQL="DECLARE
    v_result NUMBER;
BEGIN
    v_result := ${FUNCTION_NAME}(${PARAMS});
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_result);
END;
/"
elif [ $IS_PROCEDURE -eq 1 ]; then
    # Procedure execution
    SQL="EXECUTE ${FUNCTION_NAME}(${PARAMS});"
else
    # Function call via SELECT
    SQL="SELECT ${FUNCTION_NAME}(${PARAMS}) FROM DUAL;"
fi

# Show info if verbose
if [ $VERBOSE -eq 1 ]; then
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Connection Info                            ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Host:${NC}     $ORACLE_HOST"
    echo -e "${YELLOW}Port:${NC}     $ORACLE_PORT"
    echo -e "${YELLOW}SID:${NC}      $ORACLE_SID"
    echo -e "${YELLOW}User:${NC}     $ORACLE_USER"
    echo ""
fi

# Show query
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Executing Query                          ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}Function:${NC} $FUNCTION_NAME"
if [ -n "$PARAMS" ]; then
    echo -e "${YELLOW}Parameters:${NC} $PARAMS"
fi
echo -e "${YELLOW}SQL:${NC}"
echo "$SQL"
echo ""

# Create connection string using EZConnect format
CONN_STR="${ORACLE_USER}/\"${ORACLE_PASSWORD}\"@//${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SID}"

# Execute query
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                          Result                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"

# Check if sqlplus is available
if ! command -v sqlplus &> /dev/null; then
    echo -e "${RED}✗ Error: sqlplus is not installed or not in PATH${NC}"
    echo ""
    echo "Install Oracle Instant Client:"
    echo "  https://www.oracle.com/database/technologies/instant-client/downloads.html"
    exit 1
fi

# Execute the function using sqlplus
RESULT=$(sqlplus -S "$CONN_STR" <<EOF
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 1000
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

$SQL

EXIT;
EOF
)

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
