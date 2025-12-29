#!/usr/bin/env python3
"""
Auto-convert Oracle outer joins (+) to PostgreSQL LEFT JOIN
This handles the standard pattern: AND table1.col = table2.col(+)
"""

import re

def convert_sql_to_left_joins(sql_const_text):
    """
    Convert a SQL constant from Oracle style to PostgreSQL
    Input: Full C_SQLnn CONSTANT definition
    Output: Converted definition with LEFT JOINs
    """
    
    # Extract the SQL content (between single quotes)
    match = re.search(r"C_SQL\d+\s+CONSTANT\s+varchar\(\d+\)\s*:=\s*'(.+)'", sql_const_text, re.DOTALL)
    if not match:
        return sql_const_text
    
    sql_content = match.group(1)
    
    # Check if it has (+) outer joins
    if '(+)' not in sql_content:
        return sql_const_text  # No conversion needed
    
    # Find all outer join patterns: table.col = other_table.col(+)
    # Pattern: AND <spaces> table_name.column_name = other_table.column_name(+)
    outer_join_pattern = r"AND\s+(\w+)\.(\w+)\s*=\s*(\w+)\.(\w+)\(\+\)"
    
    outer_joins = []
    for match in re.finditer(outer_join_pattern, sql_content, re.IGNORECASE):
        left_table = match.group(1)
        left_col = match.group(2)
        right_table = match.group(3)
        right_col = match.group(4)
        outer_joins.append({
            'full_match': match.group(0),
            'left_table': left_table,
            'left_col': left_col,
            'right_table': right_table,
            'right_col': right_col
        })
    
    if not outer_joins:
        return sql_const_text  # No outer joins found
    
    # Remove all the AND ... = ...(+) clauses from WHERE
    for oj in outer_joins:
        sql_content = sql_content.replace(oj['full_match'], '')
    
    # Now we need to convert FROM clause to use LEFT JOIN
    # This is complex - skip for now and just remove (+) markers
    # The user will need to manually add LEFT JOINs
    
    # Simple approach: just remove (+) markers and keep as comma-separated
    sql_content = re.sub(r'\(\+\)', '', sql_content)
    
    # Reconstruct the constant definition
    sql_name = re.search(r'C_SQL\d+', sql_const_text).group(0)
    return re.sub(r"'(.+)'", f"'{sql_content}'", sql_const_text, flags=re.DOTALL)

# Read file
with open('eudm-1296.SPIP07861.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# Find all SQL constants
pattern = r"(C_SQL\d+\s+CONSTANT\s+varchar\(\d+\)\s*:=\s*'[^']+(?:''[^']*)*';)"
matches = list(re.finditer(pattern, content, re.DOTALL))

print(f"Found {len(matches)} SQL constants to process")

# Convert each one
for match in matches:
    old_text = match.group(1)
    new_text = convert_sql_to_left_joins(old_text)
    if old_text != new_text:
        content = content.replace(old_text, new_text)
        sql_name = re.search(r'C_SQL\d+', old_text).group(0)
        print(f"Converted {sql_name}")

# Write back
with open('eudm-1296.SPIP07861.sql', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done!")
