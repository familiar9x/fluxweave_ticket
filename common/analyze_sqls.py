#!/usr/bin/env python3
"""
Automated conversion of all remaining SQL constants from Oracle to PostgreSQL
"""

import re

# Read the file
with open('eudm-1296.SPIP07861.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to find each SQL constant definition
# C_SQLnn CONSTANT varchar(2000) := 'SELECT ... FROM ... WHERE ...';

def convert_one_sql(sql_text):
    """Convert a single SQL from Oracle to PostgreSQL"""
    
    # Step 1: Already done - DECODE converted by earlier script
    
    # Step 2: Convert FROM clause with multiple tables to JOIN syntax
    # Find FROM ... WHERE pattern
    from_match = re.search(r"FROM\s+([\w\s,()]+)\s+WHERE", sql_text, re.IGNORECASE | re.DOTALL)
    if not from_match:
        return sql_text  # No FROM clause found
    
    tables_section = from_match.group(1)
    
    # Check if it uses comma-separated tables (Oracle old style)
    if ',' not in tables_section:
        return sql_text  # Already using JOIN syntax
    
    # This is complex - need to parse WHERE clause for (+) patterns
    # For now, skip automatic conversion - too error-prone
    return sql_text

# Find all C_SQLnn constants
pattern = r"(C_SQL\d+\s+CONSTANT\s+varchar\(\d+\)\s*:=\s*'[^']+(?:''[^']*)*')"

matches = list(re.finditer(pattern, content, re.DOTALL))

print(f"Found {len(matches)} SQL constants")

# Since automatic conversion is complex and error-prone,
# let's just identify which ones have (+) outer joins
for match in matches:
    sql_def = match.group(1)
    sql_name = re.search(r'C_SQL\d+', sql_def).group(0)
    
    if '(+)' in sql_def:
        print(f"{sql_name} needs (+) conversion")
    else:
        print(f"{sql_name} is OK")
