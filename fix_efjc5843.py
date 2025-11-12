#!/usr/bin/env python3
"""
Script to convert pkPrint.insertData calls to use TYPE_SREPORT_WK_ITEM composite type
"""

# Read the SQL file
with open('efjc-5843.spipx020k00r02.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# First insertData call (lines ~516-635) - has 109 l_inItem parameters
first_call_start = content.find('-- 明細レコード追加\n\t\tCALL pkPrint.insertData(\n\t\t\tl_inKeyCd      => l_inItakuKaishaCd,              -- 識別コード')
first_call_end = content.find('\t\t);\n\tEND LOOP;', first_call_start)

if first_call_start > 0 and first_call_end > 0:
    # Build the replacement
    replacement = """-- 明細レコード追加
\t\t-- Initialize composite type
\t\tv_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
\t\t              )::TYPE_SREPORT_WK_ITEM;
\t\t-- Set field values
\t\tv_item.l_inItem001 := l_inUserId;
\t\tv_item.l_inItem002 := l_inItakuKaishaCd;
\t\tv_item.l_inItem003 := gItakuKaishaRnm;
\t\tv_item.l_inItem004 := recMeisai.SHONIN_STAT;
\t\tv_item.l_inItem005 := recMeisai.KIHON_TEISEI_YMD;
\t\tv_item.l_inItem006 := recMeisai.KIHON_TEISEI_USER_ID;
\t\tv_item.l_inItem007 := recMeisai.LAST_SHONIN_YMD;
\t\tv_item.l_inItem008 := recMeisai.LAST_SHONIN_ID;
\t\tv_item.l_inItem009 := recMeisai.MGR_CD;
\t\tv_item.l_inItem010 := recMeisai.ISIN_CD;
\t\tv_item.l_inItem011 := recMeisai.SHNK_HNK_TRKSH_KBN_NM;
\t\tv_item.l_inItem012 := recMeisai.TEKIYOST_YMD;
\t\tv_item.l_inItem013 := recMeisai.KK_MGR_CD;
\t\tv_item.l_inItem014 := recMeisai.MGR_RNM;
\t\tv_item.l_inItem015 := recMeisai.HAKKODAIRI_CD;
\t\tv_item.l_inItem016 := recMeisai.HAKKODAIRI_RNM;
\t\tv_item.l_inItem017 := recMeisai.SHRDAIRI_CD;
\t\tv_item.l_inItem018 := recMeisai.SHRDAIRI_RNM;
\t\tv_item.l_inItem019 := recMeisai.SKN_KESSAI_CD;
\t\tv_item.l_inItem020 := recMeisai.SKN_KESSAI_RNM;
\t\tv_item.l_inItem021 := recMeisai.MGR_NM;
\t\tv_item.l_inItem022 := recMeisai.KK_HAKKOSHA_RNM;
\t\tv_item.l_inItem023 := recMeisai.KAIGO_ETC;
\t\tv_item.l_inItem024 := recMeisai.BOSHU_KBN_NM;
\t\tv_item.l_inItem025 := recMeisai.JOJO_KBN_TO_NM;
\t\tv_item.l_inItem026 := recMeisai.JOJO_KBN_ME_NM;
\t\tv_item.l_inItem027 := recMeisai.JOJO_KBN_FU_NM;
\t\tv_item.l_inItem028 := recMeisai.JOJO_KBN_SA_NM;
\t\tv_item.l_inItem029 := recMeisai.SAIKEN_KBN_NM;
\t\tv_item.l_inItem030 := recMeisai.HOSHO_KBN_NM;
\t\tv_item.l_inItem031 := recMeisai.TANPO_KBN_NM;
\t\tv_item.l_inItem032 := recMeisai.GODOHAKKO_FLG_NM;
\t\tv_item.l_inItem033 := recMeisai.BOSHU_ST_YMD;
\t\tv_item.l_inItem034 := recMeisai.HAKKO_YMD;
\t\tv_item.l_inItem035 := recMeisai.SKNNZISNTOKU_UMU_FLG_NM;
\t\tv_item.l_inItem036 := recMeisai.RETSUTOKU_UMU_FLG_NM;
\t\tv_item.l_inItem037 := recMeisai.UCHIKIRI_HAKKO_FLG_NM;
\t\tv_item.l_inItem038 := recMeisai.KAKUSHASAI_KNGK;
\t\tv_item.l_inItem039 := recMeisai.SHASAI_TOTAL;
\t\tv_item.l_inItem040 := recMeisai.FULLSHOKAN_KJT;
\t\tv_item.l_inItem041 := recMeisai.SHOKAN_KAGAKU;
\t\tv_item.l_inItem042 := recMeisai.CALLALL_UMU_FLG_NM;
\t\tv_item.l_inItem043 := recMeisai.PUTUMU_FLG_NM;
\t\tv_item.l_inItem044 := gArySknKessaiCd[1];
\t\tv_item.l_inItem045 := gArySknKessaiNm[1];
\t\tv_item.l_inItem046 := gArySknKessaiCd[2];
\t\tv_item.l_inItem047 := gArySknKessaiNm[2];
\t\tv_item.l_inItem048 := gArySknKessaiCd[3];
\t\tv_item.l_inItem049 := gArySknKessaiNm[3];
\t\tv_item.l_inItem050 := gArySknKessaiCd[4];
\t\tv_item.l_inItem051 := gArySknKessaiNm[4];
\t\tv_item.l_inItem052 := gArySknKessaiCd[5];
\t\tv_item.l_inItem053 := gArySknKessaiNm[5];
\t\tv_item.l_inItem054 := gArySknKessaiCd[6];
\t\tv_item.l_inItem055 := gArySknKessaiNm[6];
\t\tv_item.l_inItem056 := gArySknKessaiCd[7];
\t\tv_item.l_inItem057 := gArySknKessaiNm[7];
\t\tv_item.l_inItem058 := gArySknKessaiCd[8];
\t\tv_item.l_inItem059 := gArySknKessaiNm[8];
\t\tv_item.l_inItem060 := gArySknKessaiCd[9];
\t\tv_item.l_inItem061 := gArySknKessaiNm[9];
\t\tv_item.l_inItem062 := gArySknKessaiCd[10];
\t\tv_item.l_inItem063 := gArySknKessaiNm[10];
\t\tv_item.l_inItem064 := recMeisai.KYUJITSU_KBN_NM;
\t\tv_item.l_inItem065 := recMeisai.RITSUKE_WARIBIKI_KBN_NM;
\t\tv_item.l_inItem066 := recMeisai.ST_RBR_KJT;
\t\tv_item.l_inItem067 := recMeisai.LAST_RBR_FLG_NM;
\t\tv_item.l_inItem068 := recMeisai.RIRITSU;
\t\tv_item.l_inItem069 := recMeisai.RBR_KJT_MD1;
\t\tv_item.l_inItem070 := recMeisai.RBR_KJT_MD2;
\t\tv_item.l_inItem071 := recMeisai.RBR_KJT_MD3;
\t\tv_item.l_inItem072 := recMeisai.RBR_KJT_MD4;
\t\tv_item.l_inItem073 := recMeisai.RBR_KJT_MD5;
\t\tv_item.l_inItem074 := recMeisai.RBR_KJT_MD6;
\t\tv_item.l_inItem075 := recMeisai.RBR_KJT_MD7;
\t\tv_item.l_inItem076 := recMeisai.RBR_KJT_MD8;
\t\tv_item.l_inItem077 := recMeisai.RBR_KJT_MD9;
\t\tv_item.l_inItem078 := recMeisai.RBR_KJT_MD10;
\t\tv_item.l_inItem079 := recMeisai.RBR_KJT_MD11;
\t\tv_item.l_inItem080 := recMeisai.RBR_KJT_MD12;
\t\tv_item.l_inItem081 := recMeisai.TSUKARISHI_KNGK_FAST;
\t\tv_item.l_inItem082 := recMeisai.TSUKARISHI_KNGK_NORM;
\t\tv_item.l_inItem083 := recMeisai.TSUKARISHI_KNGK_LAST;
\t\tv_item.l_inItem084 := recMeisai.KK_KANYO_FLG_NM;
\t\tv_item.l_inItem085 := recMeisai.KOBETSU_SHONIN_SAIYO_FLG_NM;
\t\tv_item.l_inItem086 := recMeisai.WRNT_TOTAL;
\t\tv_item.l_inItem087 := recMeisai.WRNT_USE_ST_YMD;
\t\tv_item.l_inItem088 := recMeisai.WRNT_USE_ED_YMD;
\t\tv_item.l_inItem089 := recMeisai.WRNT_HAKKO_KAGAKU;
\t\tv_item.l_inItem090 := recMeisai.WRNT_USE_KAGAKU;
\t\tv_item.l_inItem091 := recMeisai.HASU_SHOKAN_UMU_FLG_NM;
\t\tv_item.l_inItem092 := recMeisai.USE_SEIKYU_UKE_BASHO_NM;
\t\tv_item.l_inItem093 := recMeisai.SHTK_JK_UMU_FLG_NM;
\t\tv_item.l_inItem094 := recMeisai.SHTK_JK_YMD;
\t\tv_item.l_inItem095 := recMeisai.SHTK_TAIKA_SHURUI_NM;
\t\tv_item.l_inItem096 := recMeisai.SHANAI_KOMOKU1;
\t\tv_item.l_inItem097 := recMeisai.SHANAI_KOMOKU2;
\t\tv_item.l_inItem098 := recMeisai.GNKN_SHR_TESU_BUNBO;
\t\tv_item.l_inItem099 := recMeisai.GNKN_SHR_TESU_BUNSHI;
\t\tv_item.l_inItem100 := recMeisai.RKN_SHR_TESU_BUNBO;
\t\tv_item.l_inItem101 := recMeisai.RKN_SHR_TESU_BUNSHI;
\t\tv_item.l_inItem102 := recMeisai.RKN_TESU_KIJUN;
\t\tv_item.l_inItem103 := recMeisai.PARTHAKKO_UMU_FLG_NM;
\t\tv_item.l_inItem104 := C_CHOHYO_ID;
\t\tv_item.l_inItem106 := gPutShokanKjt;
\t\tv_item.l_inItem107 := wkPutShokanKagaku;
\t\tv_item.l_inItem108 := gPutStkoshikikanYmd;
\t\tv_item.l_inItem109 := gPutEdkoshikikanYmd;
\t\t
\t\tCALL pkPrint.insertData(
\t\t\tl_inKeyCd      => l_inItakuKaishaCd,
\t\t\tl_inUserId     => l_inUserId,
\t\t\tl_inChohyoKbn  => l_inChohyoKbn,
\t\t\tl_inSakuseiYmd => l_inGyomuYmd,
\t\t\tl_inChohyoId   => C_CHOHYO_ID,
\t\t\tl_inSeqNo      => gSeqNo,
\t\t\tl_inHeaderFlg  => 1,
\t\t\tl_inItem       => v_item,
\t\t\tl_inKousinId   => l_inUserId,
\t\t\tl_inSakuseiId  => l_inUserId
\t\t);\n\tEND LOOP;"""
    
    content = content[:first_call_start] + replacement + content[first_call_end+15:]

# Second insertData call (対象データなし) - simpler with only 4 l_inItem parameters
second_call_pattern = """-- 明細レコード追加（対象データなし）
\t\tCALL pkPrint.insertData(
\t\t\tl_inKeyCd      => l_inItakuKaishaCd, -- 識別コード
\t\t\tl_inUserId     => l_inUserId,        -- ユーザＩＤ
\t\t\tl_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分
\t\t\tl_inSakuseiYmd => l_inGyomuYmd,      -- 作成日付
\t\t\tl_inChohyoId   => C_CHOHYO_ID,       -- 帳票ＩＤ
\t\t\tl_inSeqNo      => 1,                 -- 連番
\t\t\tl_inHeaderFlg  => '1',               -- ヘッダフラグ
\t\t\tl_inItem001    => l_inUserId,        -- ユーザＩＤ
\t\t\tl_inItem003    => gItakuKaishaRnm,   -- 委託会社略称
\t\t\tl_inItem104    => C_CHOHYO_ID,       -- 帳票ＩＤ
\t\t\tl_inKousinId   => l_inUserId,        -- 更新者
\t\t\tl_inSakuseiId  => l_inUserId,        -- 作成者
\t\t\tl_inItem105    => '対象データなし'       -- 対象データなし
\t\t);"""

second_replacement = """-- 明細レコード追加（対象データなし）
\t\tv_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
\t\t              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
\t\t              )::TYPE_SREPORT_WK_ITEM;
\t\tv_item.l_inItem001 := l_inUserId;
\t\tv_item.l_inItem003 := gItakuKaishaRnm;
\t\tv_item.l_inItem104 := C_CHOHYO_ID;
\t\tv_item.l_inItem105 := '対象データなし';
\t\t
\t\tCALL pkPrint.insertData(
\t\t\tl_inKeyCd      => l_inItakuKaishaCd,
\t\t\tl_inUserId     => l_inUserId,
\t\t\tl_inChohyoKbn  => l_inChohyoKbn,
\t\t\tl_inSakuseiYmd => l_inGyomuYmd,
\t\t\tl_inChohyoId   => C_CHOHYO_ID,
\t\t\tl_inSeqNo      => 1,
\t\t\tl_inHeaderFlg  => 1,
\t\t\tl_inItem       => v_item,
\t\t\tl_inKousinId   => l_inUserId,
\t\t\tl_inSakuseiId  => l_inUserId
\t\t);"""

content = content.replace(second_call_pattern, second_replacement)

# Write the fixed content
with open('efjc-5843.spipx020k00r02.sql', 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ Fixed both pkPrint.insertData calls to use TYPE_SREPORT_WK_ITEM composite type")
