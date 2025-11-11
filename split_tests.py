#!/usr/bin/env python3
"""
Split test file into 2 parts: old completed tickets and new active tickets
"""

import re

# Define ticket groups
OLD_TICKETS = {'mktz-2195', 'erhp-9810', 'rawx-4418', 'judr-5235', 
               'fyzx-7563', 'ncvs-0805', 'zavs-0115', 'ayds-6394', 'bdrw-0478'}

# Read original file
with open('common/1_test_migration.py', 'r') as f:
    lines = f.readlines()

# Find TEST_CONFIGS start and end
config_start = None
config_end = None
for i, line in enumerate(lines):
    if line.strip() == 'TEST_CONFIGS = {':
        config_start = i
    if config_start and line.strip() == '}' and i > config_start + 10:
        config_end = i
        break

print(f"TEST_CONFIGS from line {config_start+1} to {config_end+1}")

# Extract header (before TEST_CONFIGS)
header = lines[:config_start+1]

# Extract footer (after TEST_CONFIGS closing)
footer = lines[config_end:]

# Parse ticket entries
current_ticket = None
ticket_data = {}
ticket_start = {}
bracket_count = 0
in_ticket = False

for i in range(config_start+1, config_end):
    line = lines[i]
    
    # Check if this is a ticket start
    match = re.match(r"\s+'([a-z0-9-]+)':\s+{", line)
    if match and bracket_count == 0:
        current_ticket = match.group(1)
        ticket_start[current_ticket] = i
        ticket_data[current_ticket] = [line]
        in_ticket = True
        bracket_count = line.count('{') - line.count('}')
        continue
    
    if in_ticket and current_ticket:
        ticket_data[current_ticket].append(line)
        bracket_count += line.count('{') - line.count('}')
        
        # Ticket entry complete when brackets balance and we hit '},\n'
        if bracket_count == 0 and line.strip() in ['},', '}']:
            in_ticket = False
            current_ticket = None

print(f"\nFound {len(ticket_data)} tickets:")
for ticket in sorted(ticket_data.keys()):
    print(f"  {ticket}: {len(ticket_data[ticket])} lines")

# Create old tickets file
old_config_lines = []
for ticket in sorted(OLD_TICKETS):
    if ticket in ticket_data:
        old_config_lines.extend(ticket_data[ticket])

old_file_content = header + old_config_lines + ['}', '\n', '\n'] + footer

with open('common/1_test_migration_old.py', 'w') as f:
    f.writelines(old_file_content)

print(f"\nCreated 1_test_migration_old.py with {len(OLD_TICKETS)} tickets")

# Create new tickets file  
new_config_lines = []
for ticket in sorted(ticket_data.keys()):
    if ticket not in OLD_TICKETS:
        new_config_lines.extend(ticket_data[ticket])

new_file_content = header + new_config_lines + ['}', '\n', '\n'] + footer

with open('common/1_test_migration_new.py', 'w') as f:
    f.writelines(new_file_content)

print(f"Created 1_test_migration_new.py with {len(ticket_data) - len(OLD_TICKETS)} tickets")
print("\nDone!")
