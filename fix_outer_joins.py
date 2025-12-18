#!/usr/bin/env python3
"""
Fix Oracle outer join (+) syntax in SQL constants within eudm-1296.SPIP07861.sql
Convert FROM table1, table2 WHERE table1.col = table2.col(+)
to LEFT JOIN syntax
"""

import re

def fix_c_sql5(content):
    """Fix C_SQL5 - convert (+) joins to LEFT JOIN"""
    
    # Pattern for C_SQL5
    old_c_sql5_pattern = r"(C_SQL5\s+CONSTANT text\s+:=\s+'SELECT.*?FROM MGR_STS MG0,\s*MGR_KIHON MG1,\s*SGROUP SC08,\s*VJIKO_ITAKU VJ,)(.*?WHERE.*?AND B04a\.ITAKU_KAISHA_CD = VJ\.KAIIN_ID\(\+\).*?AND B04a\.GROUP_ID = SC08\.GROUP_ID\(\+\).*?AND B04a\.LAST_TEISEI_ID = S1\.USER_ID\(\+\))';"
    
    # New C_SQL5 with LEFT JOIN
    new_c_sql5 = r"""C_SQL5	CONSTANT text	:=	'SELECT B04a.GROUP_ID,SC08.GROUP_NM,S1.CODE_VALUE,S1.CODE_NM,B04a.LAST_TEISEI_ID,B04a.ITAKU_KAISHA_CD,CASE WHEN VJ.JIKO_DAIKO_KBN=''1'' THEN ''  '' ELSE VJ.BANK_RNM END AS BANK_RNM,VJ.JIKO_DAIKO_KBN, '' '' 
										  FROM MGR_STS MG0
										  INNER JOIN MGR_KIHON MG1 ON MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG0.MGR_CD
											INNER JOIN (SELECT
												B04.ITAKU_KAISHA_CD,
												B04.ISIN_CD,
												B04.SHONIN_STAT_CD,
												B04.GROUP_ID,
												SUM(B04.HKUK_KNGK) AS HKUK_KNGK,
												COUNT(B04.ROWID) AS MEISAI_COUNT,
												TO_CHAR(MAX(B04.KOUSIN_DT),''YYYY-MM-DD HH24:MI:SS.FF6'') AS KOUSIN_DT,
												MAX(B04.LAST_TEISEI_ID) LAST_TEISEI_ID
											FROM
												SHINKIKIROKU B04
											WHERE
												B04.SHONIN_STAT_CD IN(''AFFI'',''DAFI'')
												AND B04.MASSHO_FLG = ''0''
												AND B04.SHORI_KBN = ''0''
												AND B04.KK_PHASE = ''H1''
												AND	B04.KK_STAT = ''01''
												AND (B04.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' OR ''' || l_inItakuKaishaCd || ''' = ''' || pkconstant.DAIKO_KEY_CD() || ''')  
												AND B04.KESSAI_YMD >= ''' || l_inGyomuYmd || '''
											GROUP BY
												B04.ITAKU_KAISHA_CD,
												B04.ISIN_CD,
												B04.SHONIN_STAT_CD,
												B04.GROUP_ID) B04a ON B04a.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND B04a.ISIN_CD = MG1.ISIN_CD
											LEFT JOIN SGROUP SC08 ON B04a.GROUP_ID = SC08.GROUP_ID
											LEFT JOIN VJIKO_ITAKU VJ ON B04a.ITAKU_KAISHA_CD = VJ.KAIIN_ID
											LEFT JOIN (SELECT SC05.USER_ID USER_ID,MCD1.CODE_VALUE CODE_VALUE,MCD1.CODE_NM CODE_NM
												  FROM SUSER SC05,SCODE MCD1
												 WHERE MCD1.CODE_SHUBETSU = ''902''
												   AND SC05.USER_KNGN_CD = MCD1.CODE_VALUE
											   ) S1 ON B04a.LAST_TEISEI_ID = S1.USER_ID
										WHERE
											MG0.MASSHO_FLG = ''0''';"
    
    # Replace using simple string replacement for complex multi-line SQL
    # Find C_SQL5 definition
    start_marker = "-- 5 新規記録情報承認可否一覧"
    end_marker = "-- 6 資金振替済確認"
    
    start_idx = content.find(start_marker)
    end_idx = content.find(end_marker)
    
    if start_idx != -1 and end_idx != -1:
        # Extract the section
        before = content[:start_idx]
        after = content[end_idx:]
        
        # Insert new C_SQL5
        new_section = start_marker + "\n\t" + new_c_sql5 + "\n\t"
        content = before + new_section + after
    
    return content

# Read file
with open('/home/ansible/fluxweave_ticket/eudm-1296.SPIP07861.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix C_SQL5
content = fix_c_sql5(content)

# Simple regex pattern to fix other (+) joins
# Pattern: table.col(+) in WHERE clause
# Replace with LEFT JOIN

# Fix pattern: AND xxx.col = yyy.col(+)
# This is complex because we need to identify the table and move to JOIN clause
# For now, let's do manual replacement for each SQL constant

# Write back
with open('/home/ansible/fluxweave_ticket/eudm-1296.SPIP07861.sql', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed C_SQL5")
