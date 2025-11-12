#!/bin/bash
FILE="fmnp-0291.SPIPX015K00R01.sql"

# Strategy: Replace each of the 4 insertData calls one by one
# We'll match the entire call block and replace with composite version

# Backup
cp $FILE ${FILE}.tmp

# Calls 1, 2, 4 are similar (use Items 001-020)
# Call 3 is different (no data, uses Items 001-004, 016, 021-022)

# Rather than sed, let's just add gSeqNo::bigint cast where needed
# and note the line numbers to manually fix later

echo "Converting insertData calls..."
echo "Line 182: First call"
echo "Line 233: Second call"  
echo "Line 271: Third call (no data)"
echo "Line 297: Fourth call (final)"

# For now, just add ::bigint cast to gSeqNo
sed -i 's/l_inSeqNo\s*=>\s*gSeqNo,/l_inSeqNo => gSeqNo::bigint,/g' $FILE
sed -i 's/l_inSeqNo\s*=>\s*gSeqNo$/l_inSeqNo => gSeqNo::bigint/g' $FILE

echo "Added ::bigint casts. Now need to manually convert to composite types."
