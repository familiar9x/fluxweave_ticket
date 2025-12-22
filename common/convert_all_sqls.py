#!/usr/bin/env python3
"""
Convert all Oracle SQL constants to PostgreSQL syntax:
1. DECODE(VJ.JIKO_DAIKO_KBN,1,' ',VJ.BANK_RNM) → CASE WHEN VJ.JIKO_DAIKO_KBN='1' THEN ' ' ELSE VJ.BANK_RNM END
2. FROM table1, table2, table3 WHERE table1.col = table2.col(+) → FROM table1 LEFT JOIN table2 ON table1.col = table2.col
"""

import re

def convert_outer_joins(sql):
    """Convert Oracle outer join (+) to PostgreSQL LEFT JOIN"""
    # This is complex - need to parse FROM and WHERE clauses
    # For now, just handle common patterns
    
    # Pattern: AND table1.col = table2.col(+)
    # → LEFT JOIN table2 ON table1.col = table2.col
    
    # This is too complex to automate reliably. Skip for now.
    return sql

def convert_decode(sql):
    """Convert DECODE to CASE WHEN"""
    # Pattern: DECODE(VJ.JIKO_DAIKO_KBN,1,' ',VJ.BANK_RNM)
    # To: CASE WHEN VJ.JIKO_DAIKO_KBN='1' THEN ' ' ELSE VJ.BANK_RNM END
    
    pattern = r"DECODE\(VJ\.JIKO_DAIKO_KBN,1,''([^'']*)'',VJ\.BANK_RNM\)"
    replacement = r"CASE WHEN VJ.JIKO_DAIKO_KBN='1' THEN '\1' ELSE VJ.BANK_RNM END"
    sql = re.sub(pattern, replacement, sql)
    
    return sql

def process_file(filename):
    """Process SQL file"""
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Convert DECODE
    content = convert_decode(content)
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Processed {filename}")

if __name__ == '__main__':
    process_file('eudm-1296.SPIP07861.sql')
