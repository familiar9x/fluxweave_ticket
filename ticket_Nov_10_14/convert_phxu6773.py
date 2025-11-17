#!/usr/bin/env python3
import re

# Read the file
with open('/home/ec2-user/fluxweave_ticket/phxu-6773.SPIPX007K00R01_01.sql', 'r') as f:
    content = f.read()

# Find all insertData calls and convert them
def convert_insertdata_to_composite(content):
    # Pattern to match insertData calls
    pattern = r'(CALL pkPrint\.insertData\s*\()(.*?)(l_inKousinId.*?\);)'
    
    def replace_call(match):
        prefix = match.group(1)  # "CALL pkPrint.insertData("
        params_block = match.group(2)  # All parameters except kousinid/sakuseiid
        suffix = match.group(3)  # l_inKousinId and l_inSakuseiId
        
        # Extract individual parameters
        lines = params_block.split('\n')
        
        # Find l_inItem parameters
        item_params = {}
        other_params = []
        
        for line in lines:
            if 'l_inItem' in line and '=>' in line:
                # Extract item number and value
                match_item = re.search(r'l_inItem(\d+)\s*=>\s*(.+?)\s*,?\s*(--.*)?$', line.strip())
                if match_item:
                    item_num = match_item.group(1)
                    item_value = match_item.group(2).rstrip(',').strip()
                    item_params[item_num] = item_value
            elif '=>' in line and 'l_inKousinId' not in line and 'l_inSakuseiId' not in line:
                other_params.append(line)
        
        if not item_params:
            return match.group(0)  # No conversion needed
        
        # Build composite type initialization
        composite_init = '\t\tv_item := ROW(' + ','.join(['NULL'] * 250) + ')::TYPE_SREPORT_WK_ITEM;\n'
        
        # Build field assignments
        field_assignments = ''
        for item_num in sorted(item_params.keys(), key=lambda x: int(x)):
            field_assignments += f'\t\tv_item.l_inItem{item_num} := {item_params[item_num]};\n'
        
        # Build new call with composite
        new_params = '\n'.join(other_params)
        if new_params and not new_params.endswith('\n'):
            new_params += '\n'
        new_params += '\t\t\tl_inItem       => v_item,\n'
        
        return composite_init + field_assignments + '\n' + prefix + new_params + '\t\t\t' + suffix
    
    # Replace all insertData calls
    content = re.sub(pattern, replace_call, content, flags=re.DOTALL)
    
    return content

# Add v_item variable declaration after gFm16_2
def add_v_item_declaration(content):
    # Find the variable declarations section
    pattern = r'(gFm16_2\s+varchar\(\d+\)\s+:=\s+NULL;.*?)(--==)'
    replacement = r'\1\tv_item\t\t\t\t\tTYPE_SREPORT_WK_ITEM;\t\t\t\t\t\t-- Composite type for insertData\n\t\2'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    return content

# Convert gSeqNo to numeric and add ::bigint casts
def fix_gseqno(content):
    # Change gSeqNo declaration from integer to numeric
    content = re.sub(r'gSeqNo\s+integer\s+:=\s+0;', 'gSeqNo numeric := 0;', content)
    
    # Add ::bigint cast to l_inSeqNo => gSeqNo
    content = re.sub(r'l_inSeqNo\s+=> gSeqNo,', 'l_inSeqNo      => gSeqNo::bigint,', content)
    
    return content

# Apply conversions
content = add_v_item_declaration(content)
content = convert_insertdata_to_composite(content)
content = fix_gseqno(content)

# Write back
with open('/home/ec2-user/fluxweave_ticket/phxu-6773.SPIPX007K00R01_01.sql', 'w') as f:
    f.write(content)

print("✅ Converted insertData calls to composite type")
print("✅ Added v_item declaration")
print("✅ Fixed gSeqNo type and casts")
