#!/usr/bin/env python3
"""
Remove specific tickets from TEST_CONFIGS dict
Preserves file structure and handles nested brackets correctly
"""

# Tickets to remove
REMOVE_TICKETS = {'mktz-2195', 'erhp-9810', 'rawx-4418', 'judr-5235', 
                  'fyzx-7563', 'ncvs-0805', 'zavs-0115', 'ayds-6394', 'bdrw-0478'}

with open('common/1_test_migration_backup.py', 'r') as f:
    content = f.read()

# Split into sections
parts = content.split('TEST_CONFIGS = {')
if len(parts) != 2:
    print("ERROR: Could not find TEST_CONFIGS")
    exit(1)

header = parts[0] + 'TEST_CONFIGS = {'
rest = parts[1]

# Find closing brace of TEST_CONFIGS
brace_count = 1
config_end = 0
for i, char in enumerate(rest):
    if char == '{':
        brace_count += 1
    elif char == '}':
        brace_count -= 1
        if brace_count == 0:
            config_end = i
            break

config_body = rest[:config_end]
footer = rest[config_end:]

# Parse tickets
import re
lines = config_body.split('\n')
output_lines = []
current_ticket = None
skip_mode = False
bracket_depth = 0
ticket_start_depth = 0

for line in lines:
    # Check for ticket start
    match = re.match(r"^    '([a-z0-9-]+)':\s*\{", line)
    if match:
        current_ticket = match.group(1)
        skip_mode = (current_ticket in REMOVE_TICKETS)
        ticket_start_depth = bracket_depth
        
        if skip_mode:
            print(f"❌ Removing: {current_ticket}")
        else:
            print(f"✅ Keeping: {current_ticket}")
    
    # Track bracket depth
    bracket_depth += line.count('{') - line.count('}')
    
    # Add line if not skipping
    if not skip_mode:
        output_lines.append(line)
    
    # Check if ticket ended (back to start depth and line ends with },)
    if skip_mode and bracket_depth == ticket_start_depth and (line.strip() == '},' or line.strip() == '}'):
        skip_mode = False
        current_ticket = None

# Rebuild file
new_content = header + '\n'.join(output_lines) + footer

with open('common/1_test_migration.py', 'w') as f:
    f.write(new_content)

print(f"\n✅ Done! File updated")
