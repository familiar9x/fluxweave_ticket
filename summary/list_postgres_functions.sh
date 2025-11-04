#!/bin/bash

###############################################################################
# List all functions in PostgreSQL database
###############################################################################

# Colors
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# PostgreSQL Connection
PG_HOST="jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com"
PG_PORT="5432"
PG_DATABASE="rh_mufg_ipa"
PG_USER="rh_mufg_ipa"
PG_PASSWORD="luxur1ous-Pine@pple"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           PostgreSQL Functions in rh_mufg_ipa                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

export PGPASSWORD=$PG_PASSWORD

echo -e "${YELLOW}Connecting to: $PG_HOST${NC}"
echo ""

# List all functions
echo -e "${BLUE}═══ All Functions ═══${NC}"
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" << 'EOF'
\x off
SELECT 
    proname as "Function Name",
    pronargs as "# Args",
    pg_get_function_result(oid) as "Returns",
    CASE 
        WHEN proname LIKE 'sf%' THEN 'Function'
        WHEN proname LIKE 'sp%' THEN 'Procedure'
        ELSE 'Other'
    END as "Type"
FROM pg_proc
WHERE proname LIKE 'sf%' OR proname LIKE 'sp%'
ORDER BY proname;

\echo ''
\echo '═══ Function Details ═══'

SELECT 
    proname as "Function",
    pg_get_function_arguments(oid) as "Arguments"
FROM pg_proc
WHERE proname LIKE 'sf%' OR proname LIKE 'sp%'
ORDER BY proname;
EOF

unset PGPASSWORD

echo ""
echo -e "${GREEN}✓ Query completed${NC}"
