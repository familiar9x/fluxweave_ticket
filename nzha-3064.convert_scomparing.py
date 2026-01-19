#!/usr/bin/env python3
"""
Convert Oracle outer join syntax (+) to PostgreSQL LEFT JOIN syntax
for SCOMPARING_CONDITION table data
"""

import re
from typing import Dict, List, Tuple

def parse_outer_join_conditions(where_clause: str) -> Tuple[List[str], List[str], List[str]]:
    """
    Parse WHERE clause to extract:
    - Conditions with (+) that need to be moved to LEFT JOIN
    - Regular join conditions (without +)
    - Filter conditions
    """
    conditions = [c.strip() for c in where_clause.split(' AND ')]
    
    left_join_conditions = []
    join_conditions = []
    filter_conditions = []
    
    for cond in conditions:
        if '(+)' in cond:
            # This is an outer join condition
            left_join_conditions.append(cond)
        elif '=' in cond and not any(op in cond for op in ['!=', '>=', '<=', '<>', 'IN (', 'SELECT']):
            # This is a regular join condition
            # Check if it involves table aliases from both sides
            join_conditions.append(cond)
        else:
            # This is a filter condition
            filter_conditions.append(cond)
    
    return left_join_conditions, join_conditions, filter_conditions

def convert_outer_join_to_left_join(from_clause: str, where_clause: str) -> Tuple[str, str]:
    """
    Convert Oracle outer join syntax to PostgreSQL LEFT JOIN
    Manual conversion based on specific patterns
    """
    if not where_clause or '(+)' not in where_clause:
        return from_clause, where_clause
    
    # Special handling for R0411
    if 'RT02S.JIP_DENBUN_CD(+) = \'S0511\'' in where_clause:
        new_from = """KK_RENKEI RT02R, MGR_KIHON_VIEW VMG1
    LEFT OUTER JOIN KK_RENKEI RT02S ON (RT02S.JIP_DENBUN_CD = 'S0511' 
        AND pkIpaName.getBicNoShitenCd(RT02R.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD) 
        AND RT02R.ITEM005 = RT02S.ITEM005)"""
        new_where = "RT02R.ITEM005 = VMG1.ISIN_CD"
        return new_from, new_where
    
    # Special handling for R1521
    if 'RT02S.JIP_DENBUN_CD(+) = \'S1511\'' in where_clause:
        new_from = """KK_RENKEI RT02R, MGR_KIHON VMG1, MGR_STS MG0
    LEFT OUTER JOIN KK_RENKEI RT02S ON (RT02S.JIP_DENBUN_CD = 'S1511' 
        AND pkIpaName.getBicNoShitenCd(RT02R.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD) 
        AND TRIM(RT02R.ITEM139) = TRIM(RT02S.ITEM139) 
        AND RT02S.ITEM005 = RT02R.ITEM005)"""
        
        new_where = """TRIM(RT02R.ITEM139) = VMG1.MGR_CD 
        AND MG0.KK_STAT IN ('03', '04') 
        AND MG0.MGR_CD = VMG1.MGR_CD 
        AND MG0.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD 
        AND MG0.MASSHO_FLG = '0' 
        AND RT02S.KK_SAKUSEI_DT = (SELECT MAX(K01.KK_SAKUSEI_DT) 
            FROM KK_RENKEI K01 
            WHERE K01.JIP_DENBUN_CD = 'S1511' 
                AND RT02S.ITEM005 = K01.ITEM005 
                AND RT02S.ITEM139 = K01.ITEM139 
                AND pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(K01.SR_BIC_CD)) 
        AND RT02S.DENBUN_STAT != '15'"""
        return new_from, new_where
    
    return from_clause, where_clause

# Data from SCOMPARING_CONDITION table
records = [
    {
        'totsugo_no': 'R0411',
        'select_clause': 'VMG1.MGR_CD, VMG1.MGR_RNM, RT02R.ITEM005, RT02R.ITEM006, RT02R.ITEM009, RT02R.ITEM016, RT02R.ITEM021, RT02R.ITEM025, RT02R.ITEM029, RT02R.ITEM038, RT02R.SOUJU_METHOD_CD, RT02S.DENBUN_MEISAI_NO',
        'from_clause': 'KK_RENKEI RT02R, KK_RENKEI RT02S, MGR_KIHON_VIEW VMG1',
        'where_clause': "RT02S.JIP_DENBUN_CD(+) = 'S0511' AND pkIpaName.getBicNoShitenCd(RT02R.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD(+)) AND RT02R.ITEM005 = RT02S.ITEM005(+) AND RT02R.ITEM005 = VMG1.ISIN_CD",
        'order_by_clause': 'RT02S.KK_SAKUSEI_DT DESC',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0411_01',
        'select_clause': '',
        'from_clause': 'MGR_KIHON_VIEW VMG1, KK_RENKEI RT02R',
        'where_clause': 'RT02R.ITEM005 = VMG1.ISIN_CD',
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0411_02',
        'select_clause': '',
        'from_clause': 'MGR_KIHON_VIEW VMG1, MGR_RBRKIJ MG2, KK_RENKEI RT02R',
        'where_clause': 'RT02R.ITEM005 = VMG1.ISIN_CD AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG2.MGR_CD',
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0411_10',
        'select_clause': '',
        'from_clause': 'MGR_KIHON_VIEW VMG1, MGR_SHOKIJ MG3, KK_RENKEI RT02R',
        'where_clause': "RT02R.ITEM005 = VMG1.ISIN_CD AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG3.MGR_CD AND MG3.SHOKAN_KBN = '10'",
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0411_20',
        'select_clause': '',
        'from_clause': 'MGR_KIHON_VIEW VMG1, MGR_SHOKIJ MG3, KK_RENKEI RT02R',
        'where_clause': "RT02R.ITEM005 = VMG1.ISIN_CD AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG3.MGR_CD AND MG3.SHOKAN_KBN IN ('20','21')",
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R04114',
        'select_clause': 'VMG1.MGR_CD, VMG1.MGR_RNM, RT02.ITEM005, MG3.ITAKU_KAISHA_CD',
        'from_clause': 'KK_RENKEI RT02, MGR_SHOKIJ MG3, MGR_KIHON_VIEW VMG1',
        'where_clause': "MG3.SHOKAN_KJT = RT02.ITEM025 AND MG3.SHOKAN_KBN IN ('20','21')",
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0411_40',
        'select_clause': '',
        'from_clause': 'MGR_KIHON_VIEW VMG1, MGR_SHOKIJ MG3, KK_RENKEI RT02R',
        'where_clause': "RT02R.ITEM005 = VMG1.ISIN_CD AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG3.MGR_CD AND MG3.SHOKAN_KBN = '40'",
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0411_41',
        'select_clause': '',
        'from_clause': 'MGR_KIHON_VIEW VMG1, MGR_SHOKIJ MG3, KK_RENKEI RT02R',
        'where_clause': "RT02R.ITEM005 = VMG1.ISIN_CD AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG3.MGR_CD AND MG3.SHOKAN_KBN = '41'",
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R04115',
        'select_clause': 'VMG1.MGR_CD, VMG1.MGR_RNM, RT02.ITEM005, MG3.ITAKU_KAISHA_CD',
        'from_clause': 'KK_RENKEI RT02, MGR_SHOKIJ MG3, MGR_KIHON_VIEW VMG1',
        'where_clause': "MG3.SHOKAN_KJT = RT02.ITEM029 AND MG3.SHOKAN_KBN = '41'",
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0411_50',
        'select_clause': '',
        'from_clause': 'MGR_KIHON_VIEW VMG1, MGR_SHOKIJ MG3, KK_RENKEI RT02R',
        'where_clause': "RT02R.ITEM005 = VMG1.ISIN_CD AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG3.MGR_CD AND MG3.SHOKAN_KBN = '50'",
        'order_by_clause': '',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R0811',
        'select_clause': 'B01W.MGR_MEISAI_NO',
        'from_clause': 'SHINKIKIROKU B04',
        'where_clause': "B04.TOTSUGO_KEKKA_KBN IN ('0','2','3') AND B04.ITAKU_KAISHA_CD = B01W.ITAKU_KAISHA_CD AND B04.ISIN_CD = B01W.ISIN_CD AND B04.HKUK_KNGK = B01W.HKUK_KNGK AND pkIpaName.getBicNoShitenCd(B04.KAI_BANKID_CD) = B01W.KAI_BANKID_CD_BIC",
        'order_by_clause': 'B01W.MGR_MEISAI_NO',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R1521',
        'select_clause': 'TRIM(RT02R.ITEM139), RT02R.ITEM007, RT02R.ITEM008, RT02R.ITEM014, RT02R.ITEM018, RT02R.ITEM019, RT02R.ITEM020, RT02R.ITEM141, RT02S.DENBUN_MEISAI_NO, MG0.MGR_TAIKEI_KBN, VMG1.MGR_RNM, MG0.KK_STAT, VMG1.ITAKU_KAISHA_CD, VMG1.PARTMGR_KBN, RT02S.KK_SAKUSEI_DT, RT02S.GYOMU_STAT_CD',
        'from_clause': 'KK_RENKEI RT02R, KK_RENKEI RT02S, MGR_KIHON VMG1, MGR_STS MG0',
        'where_clause': "RT02S.JIP_DENBUN_CD(+) = 'S1511' AND pkIpaName.getBicNoShitenCd(RT02R.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD(+)) AND TRIM(RT02R.ITEM139) = TRIM(RT02S.ITEM139(+)) AND TRIM(RT02R.ITEM139) = VMG1.MGR_CD AND MG0.KK_STAT IN ('03', '04') AND MG0.MGR_CD = VMG1.MGR_CD AND MG0.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND MG0.MASSHO_FLG = '0' AND RT02S.ITEM005 = RT02R.ITEM005 AND RT02S.KK_SAKUSEI_DT = (SELECT MAX(K01.KK_SAKUSEI_DT) FROM KK_RENKEI K01 WHERE K01.JIP_DENBUN_CD = 'S1511' AND RT02S.ITEM005 = K01.ITEM005 AND RT02S.ITEM139 = K01.ITEM139 AND pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(K01.SR_BIC_CD) ) AND RT02S.DENBUN_STAT != '15'",
        'order_by_clause': 'RT02S.KK_SAKUSEI_DT DESC',
        'group_by_clause': ''
    },
    {
        'totsugo_no': 'R2811',
        'select_clause': 'VMG1.MGR_CD, VMG1.ISIN_CD, VMG1.MGR_RNM',
        'from_clause': 'KK_RENKEI RT02, MGR_KIHON_VIEW VMG1',
        'where_clause': 'RT02.ITEM004 = VMG1.ISIN_CD',
        'order_by_clause': '',
        'group_by_clause': ''
    }
]

def escape_sql_string(s: str) -> str:
    """Escape single quotes in SQL strings"""
    if not s:
        return "''"
    return "'" + s.replace("'", "''") + "'"

def generate_insert_statement(record: Dict) -> str:
    """Generate INSERT statement for a record"""
    totsugo_no = record['totsugo_no']
    select_clause = record['select_clause']
    from_clause = record['from_clause']
    where_clause = record['where_clause']
    order_by_clause = record['order_by_clause']
    group_by_clause = record['group_by_clause']
    
    # Convert outer joins if needed
    if where_clause and '(+)' in where_clause:
        from_clause, where_clause = convert_outer_join_to_left_join(from_clause, where_clause)
    
    # Generate INSERT statement
    insert = f"""INSERT INTO scomparing_condition (
    totsugo_no,
    select_clause,
    from_clause,
    where_clause,
    order_by_clause,
    group_by_clause,
    kousin_dt,
    kousin_id,
    sakusei_dt,
    sakusei_id
) VALUES (
    {escape_sql_string(totsugo_no)},
    {escape_sql_string(select_clause) if select_clause else 'NULL'},
    {escape_sql_string(from_clause)},
    {escape_sql_string(where_clause) if where_clause else 'NULL'},
    {escape_sql_string(order_by_clause) if order_by_clause else 'NULL'},
    {escape_sql_string(group_by_clause) if group_by_clause else 'NULL'},
    CURRENT_TIMESTAMP,
    'SYSTEM',
    CURRENT_TIMESTAMP,
    'SYSTEM'
);"""
    
    return insert

# Generate SQL file
def main():
    output_file = '/home/ansible/jip-ipa/db/scomparing_condition_data.sql'
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('-- Migration script for SCOMPARING_CONDITION table\n')
        f.write('-- Converted Oracle outer join syntax (+) to PostgreSQL LEFT JOIN\n')
        f.write('-- Generated by nzha-3064.convert_scomparing.py\n\n')
        
        f.write('-- Clear existing data\n')
        f.write('DELETE FROM scomparing_condition;\n\n')
        
        for record in records:
            f.write(f"-- Record: {record['totsugo_no']}\n")
            if '(+)' in (record['where_clause'] or ''):
                f.write("-- NOTE: Converted Oracle outer join (+) to LEFT OUTER JOIN\n")
            f.write(generate_insert_statement(record))
            f.write('\n\n')
    
    print(f"Generated {output_file}")
    print(f"Total records: {len(records)}")
    print(f"Records with outer joins converted: {sum(1 for r in records if '(+)' in (r['where_clause'] or ''))}")

if __name__ == '__main__':
    main()
