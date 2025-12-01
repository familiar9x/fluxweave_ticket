#!/usr/bin/env python3
"""
Convert pkPrint.insertData calls from individual parameters to composite type
"""
import re
import sys

def convert_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add v_item declaration in DECLARE section
    # Find DECLARE section and add v_item declaration
    declare_pattern = r'(--==============================================================================\s*--\s*変数定義.*?\s*--==============================================================================)'
    match = re.search(declare_pattern, content, re.DOTALL)
    if match:
        # Add v_item declaration after variable definitions section header
        insert_pos = match.end()
        if 'v_item type_sreport_wk_item;' not in content[:insert_pos + 500]:
            content = content[:insert_pos] + '\n\tv_item type_sreport_wk_item;\t\t\t\t\t\t-- Composite type for pkPrint.insertData' + content[insert_pos:]
            print("✅ Added v_item declaration")
    
    # Pattern to match CALL pkPrint.insertData with many parameters
    pattern = r'CALL pkPrint\.insertData\s*\((.*?)\);'
    
    def replace_call(match):
        params_str = match.group(1)
        lines = params_str.strip().split('\n')
        
        # Extract keyCd, userId, chohyoKbn, sakuseiYmd, chohyoId, seqNo, headerFlg, kousinId, sakuseiId
        header_params = {}
        item_params = []
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('--'):
                continue
                
            # Match parameter => value
            param_match = re.match(r',?\s*l_in(\w+)\s*=>\s*(.+?)(?:,?\s*--.*)?$', line)
            if param_match:
                param_name = param_match.group(1).lower()
                param_value = param_match.group(2).strip().rstrip(',')
                comment_match = re.search(r'--\s*(.+)$', line)
                comment = comment_match.group(1) if comment_match else ''
                
                if param_name in ['keycd', 'userid', 'chohyokbn', 'sakuseiymd', 'chohyoid', 'seqno', 'headerflg', 'kousinid', 'sakuseiid']:
                    header_params[param_name] = (param_value, comment)
                elif param_name.startswith('item'):
                    item_params.append((param_name, param_value, comment))
        
        if not item_params:
            # No item parameters, return original
            return match.group(0)
        
        # Build new code
        result = '\t\t-- Clear composite type\n'
        result += '\t\tv_item := ROW();\n'
        result += '\t\t\n'
        
        # Assign item values
        for param_name, param_value, comment in item_params:
            if comment:
                result += f'\t\tv_item.l_in{param_name.capitalize()} := {param_value};\t-- {comment}\n'
            else:
                result += f'\t\tv_item.l_in{param_name.capitalize()} := {param_value};\n'
        
        result += '\t\t\n'
        result += '\t\t-- Call pkPrint.insertData with composite type\n'
        result += '\t\tCALL pkPrint.insertData(\n'
        
        # Add header parameters
        if 'keycd' in header_params:
            result += f'\t\t\tl_inKeyCd\t\t=> {header_params["keycd"][0]},\n'
        if 'userid' in header_params:
            result += f'\t\t\tl_inUserId\t\t=> {header_params["userid"][0]},\n'
        if 'chohyokbn' in header_params:
            result += f'\t\t\tl_inChohyoKbn\t=> {header_params["chohyokbn"][0]},\n'
        if 'sakuseiymd' in header_params:
            result += f'\t\t\tl_inSakuseiYmd\t=> {header_params["sakuseiymd"][0]},\n'
        if 'chohyoid' in header_params:
            result += f'\t\t\tl_inChohyoId\t=> {header_params["chohyoid"][0]},\n'
        if 'seqno' in header_params:
            result += f'\t\t\tl_inSeqNo\t\t=> {header_params["seqno"][0]},\n'
        if 'headerflg' in header_params:
            result += f'\t\t\tl_inHeaderFlg\t=> {header_params["headerflg"][0]},\n'
        
        result += '\t\t\tl_inItem\t\t=> v_item,\n'
        
        if 'kousinid' in header_params:
            result += f'\t\t\tl_inKousinId\t=> {header_params["kousinid"][0]},\n'
        if 'sakuseiid' in header_params:
            result += f'\t\t\tl_inSakuseiId\t=> {header_params["sakuseiid"][0]}\n'
        
        result += '\t\t);'
        
        return result
    
    # Replace all occurrences
    new_content, count = re.subn(pattern, replace_call, content, flags=re.DOTALL)
    
    if count > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"✅ Converted {count} pkPrint.insertData calls")
        return True
    else:
        print("❌ No pkPrint.insertData calls found")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 convert_pkprint_calls.py <sql_file>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    convert_file(filepath)
