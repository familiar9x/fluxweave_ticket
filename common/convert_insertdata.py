#!/usr/bin/env python3
"""
Convert old-style pkPrint.insertData calls to new composite type style
"""
import re
import sys

def extract_items_from_call(call_text):
    """Extract all l_inItemXXX => value pairs from a call"""
    items = {}
    lines = call_text.split('\n')
    
    for line in lines:
        # Match patterns like: , l_inItem001 => value -- comment
        match = re.search(r',\s*l_inItem(\d+)\s*=>\s*(.+?)(?:\s*--(.*))?$', line)
        if match:
            item_num = match.group(1)
            value = match.group(2).strip()
            comment = match.group(3).strip() if match.group(3) else ''
            items[item_num] = (value, comment)
    
    return items

def extract_params_from_call(call_text):
    """Extract main parameters from the call"""
    params = {}
    param_names = ['l_inKeyCd', 'l_inUserId', 'l_inChohyoKbn', 'l_inSakuseiYmd', 
                   'l_inChohyoId', 'l_inSeqNo', 'l_inHeaderFlg', 'l_inKousinId', 'l_inSakuseiId']
    
    for param in param_names:
        pattern = rf'{re.escape(param)}\s*=>\s*([^,\n]+)'
        match = re.search(pattern, call_text)
        if match:
            params[param] = match.group(1).strip()
    
    return params

def generate_new_call(items, params, indent='\t    '):
    """Generate the new composite-type style call"""
    lines = []
    lines.append(f'{indent}-- 帳票ワークへデータを追加')
    lines.append(f'{indent}v_item := ROW();')
    
    # Sort items by number and add assignments
    for item_num in sorted(items.keys(), key=lambda x: int(x)):
        value, comment = items[item_num]
        comment_part = f'  -- {comment}' if comment else ''
        lines.append(f'{indent}v_item.l_inItem{item_num} := {value}::varchar;{comment_part}')
    
    lines.append(f'{indent}')
    lines.append(f'{indent}CALL pkPrint.insertData(')
    lines.append(f'{indent}    l_inKeyCd      => {params.get("l_inKeyCd", "l_inItakuKaishaCd")},')
    lines.append(f'{indent}    l_inUserId     => {params.get("l_inUserId", "l_inUserId")},')
    lines.append(f'{indent}    l_inChohyoKbn  => {params.get("l_inChohyoKbn", "l_inChohyoKbn")},')
    lines.append(f'{indent}    l_inSakuseiYmd => {params.get("l_inSakuseiYmd", "l_inGyomuYmd")},')
    lines.append(f'{indent}    l_inChohyoId   => {params.get("l_inChohyoId", "REPORT_ID1")},')
    lines.append(f'{indent}    l_inSeqNo      => {params.get("l_inSeqNo", "1")},')
    headerflg_val = params.get("l_inHeaderFlg", "'1'")
    lines.append(f'{indent}    l_inHeaderFlg  => {headerflg_val},')
    lines.append(f'{indent}    l_inItem       => v_item,')
    lines.append(f'{indent}    l_inKousinId   => {params.get("l_inKousinId", "l_inUserId")},')
    lines.append(f'{indent}    l_inSakuseiId  => {params.get("l_inSakuseiId", "l_inUserId")}')
    lines.append(f'{indent});')
    
    return '\n'.join(lines)

def convert_file(filepath):
    """Convert all old-style calls in a file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match CALL pkPrint.insertData with old style
    # We need to find calls that have l_inItem### parameters
    pattern = r'(\t    )?-- 帳票ワークへデータを追加\s*\n\s*CALL pkPrint\.insertData\(\s*l_inKeyCd[^;]+?l_inItem\d+[^;]+?\);'
    
    matches = list(re.finditer(pattern, content, re.DOTALL))
    print(f"Found {len(matches)} old-style calls")
    
    # Convert from last to first to preserve positions
    for match in reversed(matches):
        call_text = match.group(0)
        items = extract_items_from_call(call_text)
        params = extract_params_from_call(call_text)
        
        if items:  # Only convert if we found items
            new_call = generate_new_call(items, params)
            content = content[:match.start()] + new_call + content[match.end():]
            print(f"Converted call at position {match.start()} with {len(items)} items")
    
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Conversion complete!")

if __name__ == '__main__':
    convert_file('dssw-5190.SPIPW001K00R01.sql')
