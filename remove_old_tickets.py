#!/usr/bin/env python3
"""
Remove old/completed tickets from main test file
"""

import re

# Tickets to remove
REMOVE_TICKETS = {'mktz-2195', 'erhp-9810', 'rawx-4418', 'judr-5235', 
                  'fyzx-7563', 'ncvs-0805', 'zavs-0115', 'ayds-6394', 'bdrw-0478'}

# Read file
with open('common/1_test_migration.py', 'r') as f:
    lines = f.readlines()

# Find TEST_CONFIGS bounds
config_start = None
config_end = None
for i, line in enumerate(lines):
    if line.strip() == 'TEST_CONFIGS = {':
        config_start = i
    if config_start and line.strip() == '}' and i > config_start + 100:
        config_end = i
        break

print(f"TEST_CONFIGS: lines {config_start+1} to {config_end+1}")

# Parse and filter tickets
output_lines = lines[:config_start+1]  # Keep header and TEST_CONFIGS = {
current_ticket = None
ticket_lines = []
bracket_count = 0
in_ticket = False
removed_count = 0
kept_count = 0

for i in range(config_start+1, config_end):
    line = lines[i]
    
    # Check if this is a ticket start
    match = re.match(r"\s+'([a-z0-9-]+)':\s+\{", line)
    if match and bracket_count == 0:
        # Save previous ticket if exists
        if current_ticket and ticket_lines:
            if current_ticket not in REMOVE_TICKETS:
                output_lines.extend(ticket_lines)
                kept_count += 1
                print(f"  ✅ Kept: {current_ticket}")
            else:
                removed_count += 1
                print(f"  ❌ Removed: {current_ticket}")
        
        # Start new ticket
        current_ticket = match.group(1)
        ticket_lines = [line]
        in_ticket = True
        bracket_count = line.count('{') - line.count('}')
        continue
    
    if in_ticket and current_ticket:
        ticket_lines.append(line)
        bracket_count += line.count('{') - line.count('}')
        
        # Ticket complete when brackets balance
        if bracket_count == 0:
            in_ticket = False

# Handle last ticket
if current_ticket and ticket_lines:
    if current_ticket not in REMOVE_TICKETS:
        output_lines.extend(ticket_lines)
        kept_count += 1
        print(f"  ✅ Kept: {current_ticket}")
    else:
        removed_count += 1
        print(f"  ❌ Removed: {current_ticket}")

# Add closing brace and footer
output_lines.append('}\n')
output_lines.extend(lines[config_end+1:])

# Write output
with open('common/1_test_migration.py', 'w') as f:
    f.writelines(output_lines)

print(f"\n✅ Done! Kept {kept_count} tickets, removed {removed_count} tickets")
print(f"Output: {len(output_lines)} lines (was {len(lines)} lines)")
