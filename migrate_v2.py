#!/usr/bin/env python3
"""
Migrate SPIPX025K00R03 using line-based replacement
"""

# Read all lines
with open('/home/ec2-user/fluxweave_ticket/wtxw-1725.original.sql', 'r') as f:
    lines = f.readlines()

print(f"Original file has {len(lines)} lines")

# Find the three insertData calls by searching for characteristic patterns
insertData_locations = []
for i, line in enumerate(lines):
    if 'CALL pkPrint.insertData' in line:
        insertData_locations.append(i)
        print(f"Found insertData at line {i+1}: {line[:60].strip()}...")

print(f"\nFound {len(insertData_locations)} insertData calls at lines: {[x+1 for x in insertData_locations]}")

# For simplicity, let's manually create the output by rebuilding the file
# Keep everything before first insertData, replace first call, keep middle, replace second, etc.

# This is complex - let me use a different approach: read the file and manually handle each section

with open('/home/ec2-user/fluxweave_ticket/wtxw-1725.MIGRATED.sql', 'w') as out:
    i = 0
    call_num = 0
    while i < len(lines):
        line = lines[i]
        
        # Check if this is start of an insertData call
        if 'CALL pkPrint.insertData' in line and call_num < 3:
            call_num += 1
            print(f"\nProcessing call #{call_num} at line {i+1}")
            
            # Find the end of this call (look for ");")
            call_start = i
            call_end = i
            while call_end < len(lines) and ');' not in lines[call_end]:
                call_end += 1
            call_end += 1  # Include the line with ");"
            
            print(f"  Call spans lines {call_start+1} to {call_end}")
            
            # Extract all the parameter values from this call
            params = {}
            for j in range(call_start, call_end):
                call_line = lines[j]
                if '=>' in call_line:
                    # Parse: ,l_inItemXXX => value
                    parts = call_line.split('=>')
                    if len(parts) >= 2:
                        param_name = parts[0].strip().strip(',').strip()
                        param_value = parts[1].split('--')[0].strip().strip(',').strip()
                        params[param_name] = param_value
            
            print(f"  Extracted {len(params)} parameters")
            
            # Write the replacement code
            if call_num == 1:
                # First call has 74 items
                out.write("\t\t-- 帳票ワークへデータを追加\n")
                out.write("\t\t-- Initialize composite type with 200 NULL fields\n")
                out.write("\t\tv_item := ROW(\n")
                for row in range(20):
                    out.write("\t\t\tNULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL")
                    if row < 19:
                        out.write(",\n")
                    else:
                        out.write("\n")
                out.write("\t\t)::TYPE_SREPORT_WK_ITEM;\n")
                out.write("\t\t\n")
                out.write("\t\t-- Assign values to composite type fields\n")
                
                # Assign all the item values
                for item_num in range(1, 75):
                    param_name = f"l_inItem{item_num:03d}"
                    if param_name in params:
                        out.write(f"\t\tv_item.{param_name} := {params[param_name]};\n")
                
                out.write("\t\t\n")
                out.write("\t\tCALL pkPrint.insertData(\n")
                out.write(f"\t\t\tl_inKeyCd      => {params.get('l_inKeyCd', 'l_inItakuKaishaCd')},\n")
                out.write(f"\t\t\tl_inUserId     => {params.get('l_inUserId', 'l_inUserId')},\n")
                out.write(f"\t\t\tl_inChohyoKbn  => {params.get('l_inChohyoKbn', 'l_inChohyoKbn')},\n")
                out.write(f"\t\t\tl_inSakuseiYmd => {params.get('l_inSakuseiYmd', 'l_inGyomuYmd')},\n")
                out.write(f"\t\t\tl_inChohyoId   => {params.get('l_inChohyoId', 'C_REPORT_ID')},\n")
                out.write(f"\t\t\tl_inSeqNo      => {params.get('l_inSeqNo', 'gMainSeqNo')},\n")
                out.write("\t\t\tl_inHeaderFlg  => 1,\n")
                out.write("\t\t\tl_inItem       => v_item,\n")
                out.write(f"\t\t\tl_inKousinId   => {params.get('l_inKousinId', 'l_inUserId')},\n")
                out.write(f"\t\t\tl_inSakuseiId  => {params.get('l_inSakuseiId', 'l_inUserId')}\n")
                out.write("\t\t);\n")
            else:
                # NODATA calls (2nd and 3rd)
                out.write("\t\t-- Initialize composite type for NODATA\n")
                out.write("\t\tv_item := ROW(\n")
                for row in range(20):
                    out.write("\t\t\tNULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL")
                    if row < 19:
                        out.write(",\n")
                    else:
                        out.write("\n")
                out.write("\t\t)::TYPE_SREPORT_WK_ITEM;\n")
                
                # Assign only the needed item values for NODATA
                for item_num in range(1, 75):
                    param_name = f"l_inItem{item_num:03d}"
                    if param_name in params:
                        out.write(f"\t\tv_item.{param_name} := {params[param_name]};\n")
                
                out.write("\t\t\n")
                out.write("\t\tCALL pkPrint.insertData(\n")
                out.write(f"\t\t\tl_inKeyCd      => {params.get('l_inKeyCd', 'l_inItakuKaishaCd')},\n")
                out.write(f"\t\t\tl_inUserId     => {params.get('l_inUserId', 'l_inUserId')},\n")
                out.write(f"\t\t\tl_inChohyoKbn  => {params.get('l_inChohyoKbn', 'l_inChohyoKbn')},\n")
                out.write(f"\t\t\tl_inSakuseiYmd => {params.get('l_inSakuseiYmd', 'l_inGyomuYmd')},\n")
                out.write(f"\t\t\tl_inChohyoId   => {params.get('l_inChohyoId', 'C_REPORT_ID')},\n")
                
                if call_num == 2:
                    out.write(f"\t\t\tl_inSeqNo      => {params.get('l_inSeqNo', 'gMainSeqNo')},\n")
                else:  # call_num == 3
                    out.write("\t\t\tl_inSeqNo      => 1,\n")
                    
                out.write("\t\t\tl_inHeaderFlg  => 1,\n")
                out.write("\t\t\tl_inItem       => v_item,\n")
                out.write(f"\t\t\tl_inKousinId   => {params.get('l_inKousinId', 'l_inUserId')},\n")
                out.write(f"\t\t\tl_inSakuseiId  => {params.get('l_inSakuseiId', 'l_inUserId')}\n")
                out.write("\t\t);\n")
            
            # Skip to end of original call
            i = call_end
        else:
            # Write the line as-is
            out.write(line)
            i += 1

print(f"\n✓ Migration complete! Output written to wtxw-1725.MIGRATED.sql")
