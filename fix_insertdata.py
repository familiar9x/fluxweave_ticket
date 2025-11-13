#!/usr/bin/env python3
import re

with open('znjg-7874.SPIPX012K00R01.sql', 'r') as f:
    content = f.read()

def convert_insertdata_call(match):
    """Convert named parameter insertData call to composite type"""
    full_match = match.group(0)
    indent = re.match(r'(\s*)', full_match).group(1)
    
    # Extract all parameters
    params = {}
    for p in re.finditer(r'l_in(\w+)\s*=>\s*([^\n,]+?)(?:\s+--[^\n]*)?\s*(?:,|\))', full_match):
        param_name = p.group(1).lower()
        param_value = p.group(2).strip()
        params[param_name] = param_value
    
    # Build new call
    header_default = "'1'"
    result = f"{indent}CALL pkPrint.insertData(\n"
    result += f"{indent}\t {params.get('keycd', 'l_inItakuKaishaCd')}\n"
    result += f"{indent}\t,{params.get('userid', 'l_inUserId')}\n"
    result += f"{indent}\t,{params.get('chohyokbn', 'l_inChohyoKbn')}\n"
    result += f"{indent}\t,{params.get('sakuseiymd', 'l_inGyomuYmd')}\n"
    result += f"{indent}\t,{params.get('chohyoid', 'l_inChohyoId')}\n"
    result += f"{indent}\t,{params.get('seqno', 'gSeqNo')}\n"
    result += f"{indent}\t,{params.get('headerflg', header_default)}\n"
    result += f"{indent}\t,ROW(\n"
    
    # Add items 001-200
    for i in range(1, 201):
        item_key = f'item{i:03d}'
        value = params.get(item_key, 'NULL')
        comma = '' if i == 1 else ','
        result += f"{indent}\t\t{comma}{value}  -- {i:03d}\n"
    
    result += f"{indent}\t)::type_sreport_wk_item\n"
    result += f"{indent}\t,{params.get('kousinid', 'l_inUserId')}\n"
    result += f"{indent}\t,{params.get('sakuseiid', 'l_inUserId')}\n"
    result += f"{indent});\n"
    
    return result

# Find and replace all insertData calls
pattern = r'CALL pkPrint\.insertData\([^;]+\);'
new_content = re.sub(pattern, convert_insertdata_call, content, flags=re.DOTALL)

with open('znjg-7874.SPIPX012K00R01.sql', 'w') as f:
    f.write(new_content)

print("✓ Converted insertData calls to composite type")
