#!/usr/bin/env python3
"""Replace %TYPE references with concrete PostgreSQL types"""

import re
import sys

# Mapping of table.column%TYPE to concrete PostgreSQL types
TYPE_MAP = {
    'MHAKKOTAI.HKT_CD': 'character(6)',
    'MHAKKOTAI.SFSK_POST_NO': 'character(7)',
    'MHAKKOTAI.ADD1': 'character varying(50)',
    'MHAKKOTAI.ADD2': 'character varying(50)',
    'MHAKKOTAI.ADD3': 'character varying(50)',
    'MHAKKOTAI.HKT_NM': 'character varying(100)',
    'MHAKKOTAI.SFSK_BUSHO_NM': 'character varying(50)',
    'MHAKKOTAI.EIGYOTEN_CD': 'character(4)',
    'VJIKO_ITAKU.BANK_NM': 'character varying(100)',
    'VJIKO_ITAKU.BUSHO_NM1': 'character varying(40)',
    'VJIKO_ITAKU.TESURYO_KOMI_FLG': 'character(1)',
    'MGR_KIHON_VIEW.ISIN_CD': 'character(12)',
    'MGR_KIHON_VIEW.MGR_NM': 'character varying(200)',
    'KIKIN_SEIKYU.SHR_YMD': 'character(8)',
    'KIKIN_SEIKYU.SHOKAN_SEIKYU_KNGK': 'numeric(16,2)',
    'KIKIN_SEIKYU.GZEIHIKI_BEF_CHOKYU_KNGK': 'numeric(16,2)',
    'KIKIN_SEIKYU.GZEI_KNGK': 'numeric(16,2)',
    'KIKIN_SEIKYU.GZEIHIKI_AFT_CHOKYU_KNGK': 'numeric(16,2)',
    'KIKIN_SEIKYU.MGR_CD': 'character(14)',
    'KIKIN_SEIKYU.TAX_KBN': 'character(2)',
    'MTSUKA.TSUKA_NM': 'character varying(10)',
    'MTAX.TAX_NM': 'character varying(60)',
    'MTAX.TAX_RNM': 'character varying(6)',
    'MTAX.KOKU_ZEI_RATE': 'numeric(15,13)',
    'MTAX.CHIHO_ZEI_RATE': 'numeric(5,3)',
    'MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNSHI': 'numeric(10,7)',
    'MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNBO': 'numeric(10,7)',
    'MGR_TESURYO_PRM.RKN_SHR_TESU_BUNSHI': 'numeric(10,7)',
    'MGR_TESURYO_PRM.RKN_SHR_TESU_BUNBO': 'numeric(10,7)',
    'KIKIN_IDO.KKN_SHUKIN_KNGK': 'numeric(16,2)',
    'MBUTEN.BUTEN_NM': 'character varying(50)',
    'MOPTION_KANRI.OPTION_CD': 'character(13)',
    'MOPTION_KANRI.OPTION_FLG': 'character(1)',
    'MGR_RBRKIJ.RBR_KJT': 'character(8)',
    'MPROCESS_CTL.CTL_VALUE': 'character varying(200)',
    'BUN.BUN_PATTERN_CD': 'character(2)',
    'GROSSUP_MGR_TAX.GRS_KOKU_ZEI_RATE': 'numeric(15,13)',
    'GROSSUP_MGR_TAX.TEKIYO_RBR_KJT': 'character(8)',
    'SREPORT_WK_SSKM.KEY_CD': 'character varying(10)',
    'SREPORT_WK_SSKM.USER_ID': 'character varying(10)',
    'SREPORT_WK_SSKM.CHOHYO_KBN': 'character(1)',
    'SREPORT_WK_SSKM.SAKUSEI_YMD': 'character(8)',
    'SREPORT_WK_SSKM.CHOHYO_ID': 'character(11)',
    'SREPORT_WK_SSKM.SEQ_NO': 'bigint',
}

def replace_types(content):
    """Replace all %TYPE references with concrete types"""
    for table_column, pg_type in TYPE_MAP.items():
        # Replace pattern like: MHAKKOTAI.HKT_CD%TYPE
        pattern = re.escape(table_column) + r'%TYPE'
        content = re.sub(pattern, pg_type, content, flags=re.IGNORECASE)
    return content

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 fix_type_references.py <sql_file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    content = replace_types(content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Replaced %TYPE references in {file_path}")
    else:
        print(f"ℹ️  No %TYPE references found in {file_path}")
