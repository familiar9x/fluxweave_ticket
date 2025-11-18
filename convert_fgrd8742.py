#!/usr/bin/env python3
import re

# Read the file
with open('fgrd-8742.SPIPW001K00R04.SQL', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to find CALL pkPrint.insertData(...) with l_inItemXXX parameters
# This regex captures the entire CALL statement including all parameters
pattern = r'(CALL pkPrint\.insertData\(\s*l_inKeyCd\s*=>.*?)(,l_inItem\d{3}\s*=>.*?)(,l_inKousinId\s*=>.*?\);)'

matches = list(re.finditer(pattern, content, re.DOTALL))
print(f"Found {len(matches)} calls to convert")

if len(matches) == 0:
    print("No calls found to convert")
    exit(0)

# Process each match in reverse order to preserve positions
for match in reversed(matches):
    start_pos = match.start()
    end_pos = match.end()
    
    full_call = match.group(0)
    header_params = match.group(1)  # Everything before l_inItem
    item_params = match.group(2)    # All l_inItemXXX parameters
    trailer_params = match.group(3) # l_inKousinId and l_inSakuseiId
    
    # Extract all l_inItemXXX assignments
    item_pattern = r',l_inItem(\d{3})\s*=>\s*(.+?)(?=(?:,l_inItem\d{3}\s*=>|,l_inKousinId\s*=>))'
    items = re.findall(item_pattern, item_params, re.DOTALL)
    
    print(f"\nCall at line {content[:start_pos].count(chr(10)) + 1}")
    print(f"  Found {len(items)} l_inItem parameters")
    
    # Build composite type assignments
    composite_assigns = []
    composite_assigns.append("\t\tv_item := ROW();")
    
    for item_num, item_value in items:
        # Clean up the value (remove extra tabs/spaces, keep comment)
        value_clean = item_value.strip()
        composite_assigns.append(f"\t\tv_item.l_inItem{item_num} := {value_clean}::varchar;")
    
    # Build the new CALL statement with composite type
    new_call = header_params.rstrip() + "\n"
    new_call += "\t\t\t,l_inItem\t\t\t=>\tv_item\t\t\t\t\t\t\t\t\t\t\t-- Composite type\n"
    new_call += "\t\t\t" + trailer_params.strip()
    
    # Replace in content
    content = content[:start_pos] + "\n".join(composite_assigns) + "\n" + new_call + content[end_pos:]

# Write back
with open('fgrd-8742.SPIPW001K00R04.SQL', 'w', encoding='utf-8') as f:
    f.write(content)

print("\nConversion complete!")
