#!/usr/bin/env python3
"""
Script to convert insertData calls in hyms-2185.SPIPX020K00R01.sql
to use composite type TYPE_SREPORT_WK_ITEM
"""

# First insertData call (lines 476-585) - 97 l_inItem parameters
first_call_params = {
    '001': 'l_inUserId',
    '002': 'l_inItakuKaishaCd',
    '003': 'gItakuKaishaRnm',
    '004': 'recMeisai.SHONIN_STAT',
    '005': 'recMeisai.KIHON_TEISEI_YMD',
    '006': 'recMeisai.KIHON_TEISEI_USER_ID',
    '007': 'gLastShoninYmd',
    '008': 'gLastShoninId',
    '009': 'recMeisai.MGR_CD',
    '010': 'recMeisai.ISIN_CD',
    '011': 'recMeisai.MGR_RNM',
    '012': 'recMeisai.HAKKODAIRI_CD',
    '013': 'recMeisai.HAKKODAIRI_RNM',
    '014': 'recMeisai.SHRDAIRI_CD',
    '015': 'recMeisai.SHRDAIRI_RNM',
    '016': 'recMeisai.SKN_KESSAI_CD',
    '017': 'recMeisai.SKN_KESSAI_RNM',
    '018': 'recMeisai.MGR_NM',
    '019': 'recMeisai.KK_HAKKO_CD',
    '020': 'recMeisai.KK_HAKKOSHA_RNM',
    '021': 'recMeisai.KAIGO_ETC',
    '022': 'recMeisai.BOSHU_KBN_NM',
    '023': 'recMeisai.SAIKEN_KBN_NM',
    '024': 'recMeisai.TOKUTEI_KOUSHASAI_FLG_NM',
    '025': 'recMeisai.GODOHAKKO_FLG_NM',
    '026': 'recMeisai.HOSHO_KBN_NM',
    '027': 'recMeisai.TANPO_KBN_NM',
    '028': 'recMeisai.SKNNZISNTOKU_UMU_FLG_NM',
    '029': 'recMeisai.BOSHU_ST_YMD',
    '030': 'recMeisai.HAKKO_YMD',
    '031': 'recMeisai.RETSUTOKU_UMU_FLG_NM',
    '032': 'recMeisai.HAKKO_TSUKA_CD',
    '033': 'recMeisai.UCHIKIRI_HAKKO_FLG_NM',
    '034': 'recMeisai.SHUTOKU_SUM',
    '035': 'recMeisai.KAKUSHASAI_KNGK',
    '036': 'recMeisai.SHASAI_TOTAL',
    '037': 'recMeisai.SHOKAN_METHOD_NM',
    '038': 'recMeisai.SHOKAN_TSUKA_CD',
    '039': 'recMeisai.CALLALL_UMU_FLG_NM',
    '040': 'recMeisai.KAWASE_RATE',
    '041': 'recMeisai.FULLSHOKAN_KJT',
    '042': 'recMeisai.CALLITIBU_UMU_FLG_NM',
    '043': 'recMeisai.TEIJI_SHOKAN_TSUTI_KBN_NM',
    '044': 'recMeisai.ST_TEIJISHOKAN_KJT',
    '045': 'recMeisai.PUTUMU_FLG_NM',
    '046': 'recMeisai.TEIJI_SHOKAN_KNGK',
    '047': 'gArySknKessaiCd[1]',
    '048': 'gArySknKessaiNm[1]',
    '049': 'gArySknKessaiCd[2]',
    '050': 'gArySknKessaiNm[2]',
    '051': 'gArySknKessaiCd[3]',
    '052': 'gArySknKessaiNm[3]',
    '053': 'gArySknKessaiCd[4]',
    '054': 'gArySknKessaiNm[4]',
    '055': 'gArySknKessaiCd[5]',
    '056': 'gArySknKessaiNm[5]',
    '057': 'gArySknKessaiCd[6]',
    '058': 'gArySknKessaiNm[6]',
    '059': 'gArySknKessaiCd[7]',
    '060': 'gArySknKessaiNm[7]',
    '061': 'gArySknKessaiCd[8]',
    '062': 'gArySknKessaiNm[8]',
    '063': 'gArySknKessaiCd[9]',
    '064': 'gArySknKessaiNm[9]',
    '065': 'gArySknKessaiCd[10]',
    '066': 'gArySknKessaiNm[10]',
    '067': 'recMeisai.TRUST_SHOSHO_YMD',
    '068': 'recMeisai.PARTHAKKO_UMU_FLG_NM',
    '069': 'recMeisai.KYUJITSU_KBN_NM',
    '070': 'recMeisai.KYUJITSU_LD_FLG_NM',
    '071': 'recMeisai.KYUJITSU_NY_FLG_NM',
    '072': 'recMeisai.KYUJITSU_ETC_FLG_NM',
    '073': 'recMeisai.RITSUKE_WARIBIKI_KBN_NM',
    '074': 'recMeisai.RBR_TSUKA_CD',
    '075': 'recMeisai.ST_RBR_KJT',
    '076': 'recMeisai.LAST_RBR_FLG_NM',
    '077': 'recMeisai.RIRITSU',
    '078': 'recMeisai.RBR_KJT_MD1',
    '079': 'recMeisai.RBR_KJT_MD2',
    '080': 'recMeisai.RBR_KJT_MD3',
    '081': 'recMeisai.RBR_KJT_MD4',
    '082': 'recMeisai.RBR_KJT_MD5',
    '083': 'recMeisai.RBR_KJT_MD6',
    '084': 'recMeisai.RBR_KJT_MD7',
    '085': 'recMeisai.RBR_KJT_MD8',
    '086': 'recMeisai.RBR_KJT_MD9',
    '087': 'recMeisai.RBR_KJT_MD10',
    '088': 'recMeisai.RBR_KJT_MD11',
    '089': 'recMeisai.RBR_KJT_MD12',
    '090': 'recMeisai.TSUKARISHI_KNGK_FAST',
    '091': 'recMeisai.TSUKARISHI_KNGK_NORM',
    '092': 'recMeisai.TSUKARISHI_KNGK_LAST',
    '093': 'recMeisai.KK_KANYO_FLG_NM',
    '094': 'recMeisai.KOBETSU_SHONIN_SAIYO_FLG_NM',
    '095': 'recMeisai.SHANAI_KOMOKU1',
    '096': 'recMeisai.SHANAI_KOMOKU2',
    '097': 'C_CHOHYO_ID',
}

# Second insertData call (lines 588-599) - 4 l_inItem parameters
second_call_params = {
    '001': 'l_inUserId',
    '003': 'gItakuKaishaRnm',
    '097': 'C_CHOHYO_ID',
    '098': "'対象データなし'",
}

def generate_first_call():
    """Generate code for the first insertData call"""
    null_fields = ','.join(['NULL'] * 250)
    
    lines = []
    lines.append("\t\t-- 明細レコード追加")
    lines.append(f"\t\tv_item := ROW({null_fields})::TYPE_SREPORT_WK_ITEM;")
    
    # Set each field
    for num, value in sorted(first_call_params.items()):
        lines.append(f"\t\tv_item.l_inItem{num} := {value};")
    
    lines.append("")
    lines.append("\t\tCALL pkPrint.insertData(")
    lines.append("\t\t\tl_inKeyCd      => l_inItakuKaishaCd,              -- 識別コード")
    lines.append("\t\t\tl_inUserId     => l_inUserId,                     -- ユーザＩＤ")
    lines.append("\t\t\tl_inChohyoKbn  => l_inChohyoKbn,                  -- 帳票区分")
    lines.append("\t\t\tl_inSakuseiYmd => l_inGyomuYmd,                   -- 作成日付")
    lines.append("\t\t\tl_inChohyoId   => C_CHOHYO_ID,                    -- 帳票ＩＤ")
    lines.append("\t\t\tl_inSeqNo      => gSeqNo::bigint,                 -- SQE№")
    lines.append("\t\t\tl_inHeaderFlg  => '1',                            -- ヘッダフラグ")
    lines.append("\t\t\tl_inItem       => v_item,                         -- 項目")
    lines.append("\t\t\tl_inKousinId   => l_inUserId,                     -- 更新者")
    lines.append("\t\t\tl_inSakuseiId  => l_inUserId                      -- 作成者")
    lines.append("\t\t);")
    
    return '\n'.join(lines)

def generate_second_call():
    """Generate code for the second insertData call"""
    null_fields = ','.join(['NULL'] * 250)
    
    lines = []
    lines.append("\t\t-- 明細レコード追加（対象データなし）")
    lines.append(f"\t\tv_item := ROW({null_fields})::TYPE_SREPORT_WK_ITEM;")
    
    # Set each field
    for num, value in sorted(second_call_params.items()):
        lines.append(f"\t\tv_item.l_inItem{num} := {value};")
    
    lines.append("")
    lines.append("\t\tCALL pkPrint.insertData(")
    lines.append("\t\t\tl_inKeyCd      => l_inItakuKaishaCd, -- 識別コード")
    lines.append("\t\t\tl_inUserId     => l_inUserId,        -- ユーザＩＤ")
    lines.append("\t\t\tl_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分")
    lines.append("\t\t\tl_inSakuseiYmd => l_inGyomuYmd,      -- 作成日付")
    lines.append("\t\t\tl_inChohyoId   => C_CHOHYO_ID,       -- 帳票ＩＤ")
    lines.append("\t\t\tl_inSeqNo      => 1,                 -- 連番")
    lines.append("\t\t\tl_inHeaderFlg  => '1',               -- ヘッダフラグ")
    lines.append("\t\t\tl_inItem       => v_item,            -- 項目")
    lines.append("\t\t\tl_inKousinId   => l_inUserId,        -- 更新者")
    lines.append("\t\t\tl_inSakuseiId  => l_inUserId         -- 作成者")
    lines.append("\t\t);")
    
    return '\n'.join(lines)

if __name__ == '__main__':
    print("=" * 80)
    print("FIRST insertData CALL (lines 476-585)")
    print("=" * 80)
    print(generate_first_call())
    print("\n")
    print("=" * 80)
    print("SECOND insertData CALL (lines 588-599)")
    print("=" * 80)
    print(generate_second_call())
