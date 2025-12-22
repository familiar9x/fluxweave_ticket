#!/bin/bash
# Convert DECODE and outer joins in SQL constants

FILE="eudm-1296.SPIP07861.sql"

# Backup
cp "$FILE" "${FILE}.bak2"

# Convert DECODE(VJ.JIKO_DAIKO_KBN,1,' ',VJ.BANK_RNM) to CASE WHEN
sed -i "s/DECODE(VJ\.JIKO_DAIKO_KBN,1,''/CASE WHEN VJ.JIKO_DAIKO_KBN=''1'' THEN ''/g" "$FILE"
sed -i "s/'',VJ\.BANK_RNM)/ '' ELSE VJ.BANK_RNM END/g" "$FILE"

# Convert outer join (+) to LEFT JOIN - this needs manual work per SQL
# Let me just do the basic pattern for now

echo "Basic conversion done. Manual LEFT JOIN conversion needed."
