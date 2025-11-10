#!/usr/bin/env python3
"""
Convert pkPrint.insertData calls in fsuj-6726_SPIPH006K00R02.sql
from individual parameter syntax to composite type syntax
"""

import re

# Read the file
with open('fsuj-6726_SPIPH006K00R02.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# Function to convert a single insertData call
def convert_insertdata_call(match):
    full_match = match.group(0)
    
    # Extract parameters
    params = {}
    
    # Find all parameter assignments
    param_pattern = r'l_in(\w+)\s*=>\s*([^,\)]+?)(?=\s*(?:,\s*l_in|\s*\);))'
    
    for param_match in re.finditer(param_pattern, full_match, re.DOTALL):
        param_name = param_match.group(1).strip()
        param_value = param_match.group(2).strip()
        params[param_name] = param_value
    
    # Build the conversion
    lines = []
    
    # Add item assignments (l_inItem001 through l_inItem128)
    item_count = 0
    for i in range(1, 129):
        item_key = f'Item{i:03d}'
        if item_key in params:
            item_count += 1
            value = params[item_key]
            lines.append(f'\t\tl_inItem.l_inItem{i:03d} := {value};')
    
    # Add the CALL statement with composite type
    call_line = '\t\tCALL pkPrint.insertData('
    call_params = []
    
    # Add non-item parameters in order
    param_order = ['KeyCd', 'UserId', 'ChohyoKbn', 'SakuseiYmd', 'ChohyoId', 
                   'SeqNo', 'HeaderFlg', 'KousinId', 'SakuseiId']
    
    for param in param_order:
        if param in params:
            call_params.append(f'l_in{param} => {params[param]}')
    
    # Add the composite item
    call_params.append('l_inItem => l_inItem')
    
    call_line += ',\n\t\t\t'.join(call_params)
    call_line += ');'
    
    lines.append(call_line)
    
    result = '\n'.join(lines)
    print(f'Converted {item_count} item assignments')
    return result

# Pattern to match CALL pkPrint.insertData(...);
# This needs to capture multi-line statements
pattern = r'CALL\s+pkPrint\.insertData\s*\([^;]+\);'

# Find all matches
matches = list(re.finditer(pattern, content, re.DOTALL | re.IGNORECASE))
print(f'Found {len(matches)} insertData calls to convert')

# Convert each match
converted_content = content
for i, match in enumerate(reversed(matches)):  # Reverse to maintain positions
    print(f'\nConverting call {len(matches) - i}:')
    converted = convert_insertdata_call(match)
    converted_content = converted_content[:match.start()] + converted + converted_content[match.end():]

# Write back
with open('fsuj-6726_SPIPH006K00R02.sql', 'w', encoding='utf-8') as f:
    f.write(converted_content)

print(f'\nConversion complete! Modified fsuj-6726_SPIPH006K00R02.sql')
