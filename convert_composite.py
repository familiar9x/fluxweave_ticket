#!/usr/bin/env python3
"""
Convert pkPrint.insertData calls from individual l_inItem001-031 parameters
to composite type pattern (v_item := ROW(); v_item.l_inItem001 := ...)
"""
import re

def convert_insertData_call(match):
    """Convert one CALL pkPrint.insertData(...) block"""
    indent = match.group(1)
    call_content = match.group(2)
    
    # Extract all l_inItem assignments
    item_pattern = r',\s*l_inItem(\d{3})\s*=>\s*(.+?)\s*(?=,\s*l_in|,\s*--|\))'
    items = re.findall(item_pattern, call_content, re.DOTALL)
    
    if not items:
        return match.group(0)  # No items found, return unchanged
    
    # Build composite type assignments
    assignments = []
    assignments.append(f"{indent}-- Clear composite type")
    assignments.append(f"{indent}v_item := ROW();")
    
    for item_num, value in items:
        # Clean up value (remove trailing comments and whitespace)
        value = re.sub(r'\s*--.*$', '', value.strip(), flags=re.MULTILINE)
        value = value.strip()
        assignments.append(f"{indent}v_item.l_inItem{item_num} := {value};")
    
    # Remove l_inItem* parameters from call, keep others
    new_call = re.sub(r',\s*l_inItem\d{3}\s*=>[^,\)]+(?=,|\))', '', call_content)
    # Add l_inItem => v_item before l_inKousinId
    new_call = re.sub(r'(,\s*l_inKousinId)', r',l_inItem\t\t=> v_item\1', new_call)
    
    result = "\n".join(assignments) + "\n" + indent + "CALL pkPrint.insertData(" + new_call
    return result

def main():
    with open('znjg-7874.SPIPX012K00R01.sql', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all CALL pkPrint.insertData blocks
    pattern = r'(\s+)CALL pkPrint\.insertData\((.*?)\);'
    
    converted = re.sub(pattern, convert_insertData_call, content, flags=re.DOTALL)
    
    with open('znjg-7874.SPIPX012K00R01.sql', 'w', encoding='utf-8') as f:
        f.write(converted)
    
    print("✅ Converted pkPrint.insertData calls to composite type pattern")

if __name__ == '__main__':
    main()
