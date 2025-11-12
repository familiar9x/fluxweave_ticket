#!/usr/bin/env python3
"""
Script to analyze and convert insertData calls in fmnp-0291.SPIPX015K00R01.sql
"""

# Read the file to identify all l_inItem parameters used
with open('fmnp-0291.SPIPX015K00R01.sql', 'r') as f:
    content = f.read()

# All 4 calls use the same parameters (001-020, where 018 appears twice with different values)
# Pattern: First 3 calls use same parameters, 4th call (no data) uses only 001, 003, 016

print("First 3 insertData calls use l_inItem001-020 (18 appears twice)")
print("4th insertData call (no data) uses only l_inItem001, 003, 016")
print()
print("=" * 80)
print("COMPOSITE TYPE INITIALIZATION FOR CALLS 1-3")
print("=" * 80)

null_fields = ','.join(['NULL'] * 250)

code = f"""
-- First 3 insertData calls (with data)
v_item := ROW({null_fields})::TYPE_SREPORT_WK_ITEM;
v_item.l_inItem001 := l_inUserId;
v_item.l_inItem002 := l_inGyomuYmd;
v_item.l_inItem003 := gItakuKaishaRnm;
v_item.l_inItem004 := wkKessaiYmd;
v_item.l_inItem005 := wkDvpNm;
v_item.l_inItem006 := wkTsukaNm;
v_item.l_inItem010 := wkGnrZndkSum;
v_item.l_inItem011 := wkShokanKngkSum;
v_item.l_inItem012 := wkZeihikiBefKngkSum;
v_item.l_inItem013 := wkZeiKngkSum;
v_item.l_inItem014 := wkZeihikiAftKngkSum;
v_item.l_inItem015 := wkShrKngkTotal;
v_item.l_inItem016 := C_REPORT_ID;
v_item.l_inItem017 := gKngkFormat;
v_item.l_inItem018 := wkKbnTitle;
v_item.l_inItem019 := wkTsukaCd;
v_item.l_inItem020 := wkDvpKbn;

CALL pkPrint.insertData(
    l_inKeyCd      => l_inItakuKaishaCd,
    l_inUserId     => l_inUserId,
    l_inChohyoKbn  => l_inChohyoKbn,
    l_inSakuseiYmd => l_inGyomuYmd,
    l_inChohyoId   => C_REPORT_ID,
    l_inSeqNo      => gSeqNo::bigint,
    l_inHeaderFlg  => '1',
    l_inItem       => v_item,
    l_inKousinId   => l_inUserId,
    l_inSakuseiId  => l_inUserId
);
"""

print(code)

print()
print("=" * 80)
print("COMPOSITE TYPE INITIALIZATION FOR CALL 4 (NO DATA)")
print("=" * 80)

code2 = f"""
-- Fourth insertData call (no data)
v_item := ROW({null_fields})::TYPE_SREPORT_WK_ITEM;
v_item.l_inItem001 := l_inUserId;
v_item.l_inItem003 := gItakuKaishaRnm;
v_item.l_inItem016 := C_REPORT_ID;

CALL pkPrint.insertData(
    l_inKeyCd      => l_inItakuKaishaCd,
    l_inUserId     => l_inUserId,
    l_inChohyoKbn  => l_inChohyoKbn,
    l_inSakuseiYmd => l_inGyomuYmd,
    l_inChohyoId   => C_REPORT_ID,
    l_inSeqNo      => 1,
    l_inHeaderFlg  => '1',
    l_inItem       => v_item,
    l_inKousinId   => l_inUserId,
    l_inSakuseiId  => l_inUserId
);
"""

print(code2)
