#!/usr/bin/env python3
"""
Convert all 4 insertData calls in fmnp-0291.SPIPX015K00R01.sql to use composite type
"""
import re

with open('fmnp-0291.SPIPX015K00R01.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to match insertData calls
pattern = r'CALL pkPrint\.insertData\(\s*l_inKeyCd[^;]+\);'

matches = list(re.finditer(pattern, content, re.DOTALL))
print(f"Found {len(matches)} insertData calls")

# We'll replace from end to start to preserve positions
for i, match in enumerate(reversed(matches), 1):
    call_num = len(matches) - i + 1
    print(f"\nProcessing call {call_num} at position {match.start()}-{match.end()}")
    
    old_call = match.group(0)
    
    # Extract l_inItem parameters
    item_pattern = r'l_inItem(\d+)\s*=>\s*([^,\)]+)'
    items = re.findall(item_pattern, old_call)
    
    print(f"  Found {len(items)} l_inItem parameters")
    
    # Build composite initialization
    null_row = ','.join(['NULL'] * 250)
    new_call = f"\t\tv_item := ROW({null_row})::TYPE_SREPORT_WK_ITEM;\n"
    
    for item_num, item_value in items:
        new_call += f"\t\tv_item.l_inItem{item_num} := {item_value.strip()};\n"
    
    new_call += "\n\t\tCALL pkPrint.insertData(\n"
    new_call += "\t\t\tl_inKeyCd      => l_inItakuKaishaCd,\n"
    new_call += "\t\t\tl_inUserId     => l_inUserId,\n"
    new_call += "\t\t\tl_inChohyoKbn  => l_inChohyoKbn,\n"
    new_call += "\t\t\tl_inSakuseiYmd => l_inGyomuYmd,\n"
    new_call += "\t\t\tl_inChohyoId   => C_REPORT_ID,\n"
    
    # Extract l_inSeqNo value
    seq_match = re.search(r'l_inSeqNo\s*=>\s*([^,\)]+)', old_call)
    if seq_match:
        seq_val = seq_match.group(1).strip()
        if 'gSeqNo' in seq_val and '::bigint' not in seq_val:
            seq_val = 'gSeqNo::bigint'
        new_call += f"\t\t\tl_inSeqNo      => {seq_val},\n"
    
    new_call += "\t\t\tl_inHeaderFlg  => '1',\n"
    new_call += "\t\t\tl_inItem       => v_item,\n"
    new_call += "\t\t\tl_inKousinId   => l_inUserId,\n"
    new_call += "\t\t\tl_inSakuseiId  => l_inUserId\n"
    new_call += "\t\t);"
    
    # Replace
    content = content[:match.start()] + new_call + content[match.end():]

# Write back
with open('fmnp-0291.SPIPX015K00R01.sql', 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n✅ Converted all {len(matches)} insertData calls")
