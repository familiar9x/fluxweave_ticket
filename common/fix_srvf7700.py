#!/usr/bin/env python3
"""Fix nested functions in srvf-7700.SFIPF013K01R03.sql"""

import re

with open('srvf-7700.SFIPF013K01R03.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix sfipf013k01r03_common_error function
# Original signature
old_common_error = r'''CREATE OR REPLACE FUNCTION sfipf013k01r03_common_error \( l_inShoriKbn TEXT,\s+-- 処理区分
 l_inTableName TEXT,\s+-- テーブル名
 l_inErrCode TEXT,\s+-- エラーコード
 l_inUkeTuban TEXT,\s+-- 受付通番
 l_inInoutKbn TEXT,\s+-- 入出金区分
 l_inMeisyou TEXT,\s+-- テーブル名称
 l_inMsgId TEXT DEFAULT NULL\s+-- メッセージID
\) RETURNS integer AS \$body\$
BEGIN'''

new_common_error = '''CREATE OR REPLACE FUNCTION sfipf013k01r03_common_error (
\tl_inShoriKbn TEXT,\t\t\t\t-- 処理区分
\tl_inTableName TEXT,\t\t\t\t-- テーブル名
\tl_inErrCode TEXT,\t\t\t\t-- エラーコード
\tl_inUkeTuban TEXT,\t\t\t\t-- 受付通番
\tl_inInoutKbn TEXT,\t\t\t\t-- 入出金区分
\tl_inMeisyou TEXT,\t\t\t\t-- テーブル名称
\tl_inCItaku_kaisha_cd TEXT,\t\t-- 委託会社コード
\tl_inCGyoumuDt char(8),\t\t\t-- 業務日付
\tl_inMsgId TEXT DEFAULT NULL\t\t-- メッセージID
) RETURNS integer AS $body$
DECLARE
\tvSql text;
\tvMsgLog text;
\tvMsgTsuchi text;
\tvTableName text;
\tvMsg_Err_list text;
\tiRet integer;
BEGIN'''

content = re.sub(old_common_error, new_common_error, content, flags=re.MULTILINE)

# Replace cItaku_kaisha_cd with l_inCItaku_kaisha_cd in common_error body
content = re.sub(
    r"'''' \|\| cItaku_kaisha_cd \|\| ''''",
    "'''' || l_inCItaku_kaisha_cd || ''''",
    content
)

# Fix sfipf013k01r03_common_func function  
old_common_func = r'''CREATE OR REPLACE FUNCTION sfipf013k01r03_common_func \( l_inMessage_id text,\s+-- メッセージＩＤ
 l_inMsgLog text,\s+-- ログ出力用メッセージ
 l_inMsgTsuchi text,\s+-- メッセージ通知用メッセージ
 l_inTableName text,\s+-- テーブル名称
 l_inMsg_Err_list text,\s+-- エラーリスト用メッセージ
 l_inUke_tuban text\s+-- 受付通番
 \) RETURNS integer AS \$body\$
BEGIN'''

new_common_func = '''CREATE OR REPLACE FUNCTION sfipf013k01r03_common_func (
\tl_inMessage_id text,\t\t\t-- メッセージＩＤ
\tl_inMsgLog text,\t\t\t-- ログ出力用メッセージ
\tl_inMsgTsuchi text,\t\t\t-- メッセージ通知用メッセージ
\tl_inTableName text,\t\t\t-- テーブル名称
\tl_inMsg_Err_list text,\t\t\t-- エラーリスト用メッセージ
\tl_inUke_tuban text,\t\t\t\t-- 受付通番
\tl_inCItaku_kaisha_cd TEXT,\t\t-- 委託会社コード
\tl_inCGyoumuDt char(8)\t\t\t-- 業務日付
) RETURNS integer AS $body$
DECLARE
\tnSqlCode integer;
\tvSqlErrM text;
\tiRet integer;
BEGIN'''

content = re.sub(old_common_func, new_common_func, content, flags=re.MULTILINE)

# Replace variables in common_func body
content = re.sub(
    r'\tcItaku_kaisha_cd,\n\t\t\'BATCH\',',
    '\tl_inCItaku_kaisha_cd,\n\t\t\'BATCH\',',
    content
)
content = re.sub(
    r'\t\tcGyoumuDt,',
    '\t\tl_inCGyoumuDt,',
    content
)

# Now fix all calls to SFIPF013K01R03_COMMON_ERROR
# Pattern: find calls and add cItaku_kaisha_cd, cGyoumuDt before closing
lines = content.split('\n')
output_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if this line has COMMON_ERROR call
    if 'SFIPF013K01R03_COMMON_ERROR(' in line:
        # Collect the full function call
        call_lines = [line]
        j = i + 1
        paren_count = line.count('(') - line.count(')')
        
        while paren_count > 0 and j < len(lines):
            call_lines.append(lines[j])
            paren_count += lines[j].count('(') - lines[j].count(')')
            j += 1
        
        # Modify the last line to add parameters
        if call_lines and call_lines[-1].strip().endswith(');'):
            # Find indentation
            indent = len(call_lines[-1]) - len(call_lines[-1].lstrip())
            call_lines[-1] = call_lines[-1].replace(
                ');',
                f',\n{" " * (indent + 4)}cItaku_kaisha_cd,\n{" " * (indent + 4)}cGyoumuDt\n{" " * indent});'
            )
        
        output_lines.extend(call_lines)
        i = j
        continue
    
    # Check if this line has COMMON_FUNC call
    if 'SFIPF013K01R03_COMMON_FUNC(' in line:
        call_lines = [line]
        j = i + 1
        paren_count = line.count('(') - line.count(')')
        
        while paren_count > 0 and j < len(lines):
            call_lines.append(lines[j])
            paren_count += lines[j].count('(') - lines[j].count(')')
            j += 1
        
        # Add parameters before closing
        if call_lines and call_lines[-1].strip().endswith(');'):
            indent = len(call_lines[-1]) - len(call_lines[-1].lstrip())
            call_lines[-1] = call_lines[-1].replace(
                ');',
                f',\n{" " * (indent + 4)}cItaku_kaisha_cd,\n{" " * (indent + 4)}cGyoumuDt\n{" " * indent});'
            )
        
        output_lines.extend(call_lines)
        i = j
        continue
    
    output_lines.append(line)
    i += 1

content = '\n'.join(output_lines)

with open('srvf-7700.SFIPF013K01R03.sql', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Fixed all nested functions and their calls")
