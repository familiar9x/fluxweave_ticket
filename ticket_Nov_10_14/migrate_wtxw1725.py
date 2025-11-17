#!/usr/bin/env python3
"""
Migrate SPIPX025K00R03 from OLD STYLE (individual parameters) to NEW STYLE (composite type)
"""

# Read the original file
with open('/home/ec2-user/fluxweave_ticket/wtxw-1725.SPIPX025K00R03.sql', 'r') as f:
    content = f.read()

# Create the 200 NULL initialization for composite type
null_init = "ROW(\n\t\t\t"
nulls = []
for i in range(20):
    nulls.append("NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL")
null_init += ",\n\t\t\t".join(nulls)
null_init += "\n\t\t)::TYPE_SREPORT_WK_ITEM"

# Replace first insertData call (lines 387-469)
old_call_1 = """		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(l_inKeyCd      => l_inItakuKaishaCd 		  -- 識別コード
			  ,l_inUserId     => l_inUserId 				  -- ユーザＩＤ
			  ,l_inChohyoKbn  => l_inChohyoKbn 			  -- 帳票区分
			  ,l_inSakuseiYmd => l_inGyomuYmd 			  -- 作成年月日
			  ,l_inChohyoId   => C_REPORT_ID 			  -- 帳票ＩＤ
			  ,l_inSeqNo      => gMainSeqNo 				  -- 連番
			  ,l_inHeaderFlg  => '1'			          -- ヘッダフラグ
			  ,l_inItem001    => gItakuKaishaRnm 		          -- 委託会社略称
			  ,l_inItem002    => l_inKijunYm 		              -- 基準年月
			  ,l_inItem003    => recMeisai.NOZEI_YOU_HUYOU 		  -- 納税要不要
			  ,l_inItem004    => recMeisai.ITAKU_KAISHA_CD 	 	  -- 委託会社コード
			  ,l_inItem005    => recMeisai.HKT_CD 		          -- 発行体コード(改ページキー)
			  ,l_inItem006    => recMeisai.ZEIMUSHO_NM 		  -- 所轄税務署
			  ,l_inItem007    => recMeisai.SHOKATSU_ZEIMUSHO_CD 	  -- 税務署番号
			  ,l_inItem008    => recMeisai.SEIRI_NO 		          -- 整理番号
			  ,l_inItem009    => recMeisai.TSUKA_CD 		          -- 通貨コード(改ページキー)
			  ,l_inItem010    => recMeisai.TSUKA_CD_TYTLE 		  -- 通貨コード（タイトル）
			  ,l_inItem011    => recMeisai.HKT_NM 		          -- 発行体名称上段
			  ,l_inItem012    => gKokuZeiRate[4]		          -- 税率31:非課税信託財産（投資信託）税率
			  ,l_inItem013    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK31 -- 支払金額31
			  ,l_inItem014    => recMeisai.HKT_NM 		          -- 発行体名称下段	
			  ,l_inItem015    => gKokuZeiRate[5]		          -- 税率32:非課税信託財産（年金信託）税率
			  ,l_inItem016    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK32 -- 支払金額32
			  ,l_inItem017    => recMeisai.KOZA_TEN_CD 		  -- 口座店コード
			  ,l_inItem018    => recMeisai.KOZA_TEN_CIFCD 		  -- 口座店CIFコード
			  ,l_inItem019    => gKokuZeiRate[6]		          -- 税率40:非課税信託財産（マル優）税率
			  ,l_inItem020    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK40 -- 支払金額40	
			  ,l_inItem021    => gTSUKA_FORMAT
			  ,l_inItem022    => gKokuZeiRate[7]		                  -- 税率60:財形貯蓄非課税 税率
			  ,l_inItem023    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK60 -- 支払金額60	
			  ,l_inItem024    => recMeisai.TOKIJO_POST_NO 		  -- 送付先郵便番号
			  ,l_inItem025    => gKokuZeiRate[17]		          -- 税率93:マル優（分かち）非課税分 税率
			  ,l_inItem026    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK93 -- 支払金額93	
			  ,l_inItem027    => recMeisai.TOKIJO_ADD1		  -- 送付先住所１
			  ,l_inItem028    => recMeisai.TOKIJO_ADD2		  -- 送付先住所２
			  ,l_inItem029    => recMeisai.TOKIJO_ADD3		  -- 送付先住所３
			  ,l_inItem030    => gKokuZeiRate[3]		        -- 税率30:非課税法人 税率
			  ,l_inItem031    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK30 -- 支払金額30	
			  ,l_inItem032    => gKokuZeiRate[1]		                  -- 税率10:分離課税 税率
			  ,l_inItem033    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK10 -- 支払金額10	
			  ,l_inItem034    => recMeisai.GZEI_KNGK10                --税額10
			  ,l_inItem035    => gKokuZeiRate[2]		                  -- 税率20:総合課税 税率
			  ,l_inItem036    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK20-- 支払金額20	
			  ,l_inItem037    => recMeisai.GZEI_KNGK20                --税額20
			  ,l_inItem038    => gKokuZeiRate[16]		                  -- 税率92:マル優（分かち）分離課税区分 税率
			  ,l_inItem039    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK92 -- 支払金額92	
			  ,l_inItem040    => recMeisai.GZEI_KNGK92                --税額92
			  ,l_inItem041    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK20 -- 支払金額20
			  ,l_inItem042    => recMeisai.GZEI_KNGK20                --税額20
			  ,l_inItem043    => gKokuZeiRate[8]		                  -- 税率70:非住居者（0％）税率
			  ,l_inItem044    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK70 -- 支払金額70	
			  ,l_inItem045    => gKokuZeiRate[9]		                  -- 税率71:非住居者（10％）税率
			  ,l_inItem046    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK71 -- 支払金額71	
			  ,l_inItem047    => recMeisai.GZEI_KNGK71                --税額71
			  ,l_inItem048    => gKokuZeiRate[10]		                  -- 税率72:非住居者（12％）税率
			  ,l_inItem049    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK72 -- 支払金額72	
			  ,l_inItem050    => recMeisai.GZEI_KNGK72                --税額72
			  ,l_inItem051    => gKokuZeiRate[11]		                  -- 税率73:非住居者（12.5％）税率
			  ,l_inItem052    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK73 -- 支払金額73	
			  ,l_inItem053    => recMeisai.GZEI_KNGK73                --税額73
			  ,l_inItem054    => gKokuZeiRate[12]		                  -- 税率74:非住居者（15％）税率
			  ,l_inItem055    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK74 -- 支払金額74	
			  ,l_inItem056    => recMeisai.GZEI_KNGK74                --税額74
			  ,l_inItem057    => gKokuZeiRate[13]		                  -- 税率75:非住居者（25％）税率
			  ,l_inItem058    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK75 -- 支払金額75	
			  ,l_inItem059    => recMeisai.GZEI_KNGK75                --税額75
			  ,l_inItem060    => gKokuZeiRate[14]		                  -- 税率80:非住居者非課税制度対象分非課税（発行者源泉徴収分）税率
			  ,l_inItem061    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK80 -- 支払金額80	
			  ,l_inItem062    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK90 -- 支払金額90	
			  ,l_inItem063    => recMeisai.GZEI_KNGK90                --税額90
			  ,l_inItem064    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK91 -- 支払金額91
			  ,l_inItem065    => recMeisai.HASUU_MIBARAI            -- 端数未払金
			  ,l_inItem066    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK85 -- 支払金額85
			  ,l_inItem067    => gKokuZeiRate[15]		                  -- 税率81:非住居者非課税制度対象分非課税（口座管理機関源泉徴収分）税率
			  ,l_inItem068    => recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK81 -- 支払金額81
			  ,l_inItem069    => C_REPORT_ID                           -- 帳票ID
			  ,l_inItem070    => 'ZZZ,ZZ9.9'
			  ,l_inItem071    => recMeisai.TSUKA_NM  -- 発行通貨
			  ,l_inItem072    => recMeisai.TSUKA_NM  -- 発行通貨(支払金額)
			  ,l_inItem073    => recMeisai.TSUKA_NM  -- 発行通貨(税額)
			  ,l_inItem074    => l_inUserId 				  -- ユーザＩＤ
			  ,l_inKousinId   => l_inUserId 				  -- 更新者ID
			  ,l_inSakuseiId  => l_inUserId 				  -- 作成者ID
			);"""

new_call_1 = """		-- 帳票ワークへデータを追加
		-- Initialize composite type with 200 NULL fields
		v_item := """ + null_init + """;
		
		-- Assign values to composite type fields
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := l_inKijunYm;
		v_item.l_inItem003 := recMeisai.NOZEI_YOU_HUYOU;
		v_item.l_inItem004 := recMeisai.ITAKU_KAISHA_CD;
		v_item.l_inItem005 := recMeisai.HKT_CD;
		v_item.l_inItem006 := recMeisai.ZEIMUSHO_NM;
		v_item.l_inItem007 := recMeisai.SHOKATSU_ZEIMUSHO_CD;
		v_item.l_inItem008 := recMeisai.SEIRI_NO;
		v_item.l_inItem009 := recMeisai.TSUKA_CD;
		v_item.l_inItem010 := recMeisai.TSUKA_CD_TYTLE;
		v_item.l_inItem011 := recMeisai.HKT_NM;
		v_item.l_inItem012 := gKokuZeiRate[4];
		v_item.l_inItem013 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK31;
		v_item.l_inItem014 := recMeisai.HKT_NM;
		v_item.l_inItem015 := gKokuZeiRate[5];
		v_item.l_inItem016 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK32;
		v_item.l_inItem017 := recMeisai.KOZA_TEN_CD;
		v_item.l_inItem018 := recMeisai.KOZA_TEN_CIFCD;
		v_item.l_inItem019 := gKokuZeiRate[6];
		v_item.l_inItem020 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK40;
		v_item.l_inItem021 := gTSUKA_FORMAT;
		v_item.l_inItem022 := gKokuZeiRate[7];
		v_item.l_inItem023 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK60;
		v_item.l_inItem024 := recMeisai.TOKIJO_POST_NO;
		v_item.l_inItem025 := gKokuZeiRate[17];
		v_item.l_inItem026 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK93;
		v_item.l_inItem027 := recMeisai.TOKIJO_ADD1;
		v_item.l_inItem028 := recMeisai.TOKIJO_ADD2;
		v_item.l_inItem029 := recMeisai.TOKIJO_ADD3;
		v_item.l_inItem030 := gKokuZeiRate[3];
		v_item.l_inItem031 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK30;
		v_item.l_inItem032 := gKokuZeiRate[1];
		v_item.l_inItem033 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK10;
		v_item.l_inItem034 := recMeisai.GZEI_KNGK10;
		v_item.l_inItem035 := gKokuZeiRate[2];
		v_item.l_inItem036 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK20;
		v_item.l_inItem037 := recMeisai.GZEI_KNGK20;
		v_item.l_inItem038 := gKokuZeiRate[16];
		v_item.l_inItem039 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK92;
		v_item.l_inItem040 := recMeisai.GZEI_KNGK92;
		v_item.l_inItem041 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK20;
		v_item.l_inItem042 := recMeisai.GZEI_KNGK20;
		v_item.l_inItem043 := gKokuZeiRate[8];
		v_item.l_inItem044 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK70;
		v_item.l_inItem045 := gKokuZeiRate[9];
		v_item.l_inItem046 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK71;
		v_item.l_inItem047 := recMeisai.GZEI_KNGK71;
		v_item.l_inItem048 := gKokuZeiRate[10];
		v_item.l_inItem049 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK72;
		v_item.l_inItem050 := recMeisai.GZEI_KNGK72;
		v_item.l_inItem051 := gKokuZeiRate[11];
		v_item.l_inItem052 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK73;
		v_item.l_inItem053 := recMeisai.GZEI_KNGK73;
		v_item.l_inItem054 := gKokuZeiRate[12];
		v_item.l_inItem055 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK74;
		v_item.l_inItem056 := recMeisai.GZEI_KNGK74;
		v_item.l_inItem057 := gKokuZeiRate[13];
		v_item.l_inItem058 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK75;
		v_item.l_inItem059 := recMeisai.GZEI_KNGK75;
		v_item.l_inItem060 := gKokuZeiRate[14];
		v_item.l_inItem061 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK80;
		v_item.l_inItem062 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK90;
		v_item.l_inItem063 := recMeisai.GZEI_KNGK90;
		v_item.l_inItem064 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK91;
		v_item.l_inItem065 := recMeisai.HASUU_MIBARAI;
		v_item.l_inItem066 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK85;
		v_item.l_inItem067 := gKokuZeiRate[15];
		v_item.l_inItem068 := recMeisai.GZEIHIKI_BEF_CHOKYU_KNGK81;
		v_item.l_inItem069 := C_REPORT_ID;
		v_item.l_inItem070 := 'ZZZ,ZZ9.9';
		v_item.l_inItem071 := recMeisai.TSUKA_NM;
		v_item.l_inItem072 := recMeisai.TSUKA_NM;
		v_item.l_inItem073 := recMeisai.TSUKA_NM;
		v_item.l_inItem074 := l_inUserId;
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => l_inGyomuYmd,
			l_inChohyoId   => C_REPORT_ID,
			l_inSeqNo      => gMainSeqNo,
			l_inHeaderFlg  => 1,
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);"""

# Replace second insertData call (line 479)
old_call_2 = """		CALL pkPrint.insertData(l_inKeyCd => l_inItakuKaishaCd 	-- 識別コード
				   , l_inUserId => l_inUserId 	        -- ユーザＩＤ
				   , l_inChohyoKbn => l_inChohyoKbn 	-- 帳票区分
				   , l_inSakuseiYmd => l_inGyomuYmd 	-- 作成年月日
				   , l_inChohyoId => C_REPORT_ID 	-- 帳票ＩＤ
				   , l_inSeqNo => gMainSeqNo 		-- 連番
				   , l_inHeaderFlg  => '1'		-- ヘッダフラグ
				   , l_inItem002    => l_inKijunYm 	-- 基準年月
				   , l_inItem011    => '対象データなし' -- 対象データ
				   , l_inKousinId   => l_inUserId 	-- 更新者ID
				   , l_inSakuseiId  => l_inUserId 	-- 作成者ID
				   , l_inItem074    => l_inUserId 	-- ユーザＩＤ
				   , l_inItem069    => C_REPORT_ID       -- 帳票ID
				   , l_inItem001    => gItakuKaishaRnm 	-- 委託会社略称
				   );"""

new_call_2 = """		-- Initialize composite type for NODATA
		v_item := """ + null_init + """;
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := l_inKijunYm;
		v_item.l_inItem011 := '対象データなし';
		v_item.l_inItem069 := C_REPORT_ID;
		v_item.l_inItem074 := l_inUserId;
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => l_inGyomuYmd,
			l_inChohyoId   => C_REPORT_ID,
			l_inSeqNo      => gMainSeqNo,
			l_inHeaderFlg  => 1,
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);"""

# Replace third insertData call (line 502 - same as second)
old_call_3 = old_call_2
new_call_3 = new_call_2.replace('gMainSeqNo', '1')  # This one uses seqNo=1

# Apply replacements
if old_call_1 in content:
    content = content.replace(old_call_1, new_call_1, 1)
    print("✓ Replaced first insertData call")
else:
    print("✗ Could not find first insertData call")

if old_call_2 in content:
    # Replace first occurrence (line 479)
    pos = content.find(old_call_2)
    if pos != -1:
        content = content[:pos] + new_call_2 + content[pos+len(old_call_2):]
        print("✓ Replaced second insertData call")
        
        # Replace second occurrence (line 502) - need to modify for seqNo=1
        pos2 = content.find(old_call_3, pos + len(new_call_2))
        if pos2 != -1:
            final_call_3 = new_call_3.replace('l_inSeqNo      => gMainSeqNo,', 'l_inSeqNo      => 1,')
            content = content[:pos2] + final_call_3 + content[pos2+len(old_call_3):]
            print("✓ Replaced third insertData call")
        else:
            print("✗ Could not find third insertData call")
else:
    print("✗ Could not find NODATA insertData calls")

# Write the migrated file
with open('/home/ec2-user/fluxweave_ticket/wtxw-1725.SPIPX025K00R03.sql', 'w') as f:
    f.write(content)

print("\n✓ Migration complete!")
print("  - Converted 3 pkPrint.insertData calls to composite type pattern")
print("  - Original file backed up to wtxw-1725.SPIPX025K00R03.sql.bak")
