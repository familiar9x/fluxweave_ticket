#!/bin/bash
# Comprehensive Oracle to PostgreSQL converter for complex files
# - Convert một số pattern Oracle phổ biến sang PostgreSQL (an toàn)
# - Cảnh báo các cú pháp/hàm Oracle không tương thích để xử lý tay

###############################################
# Hàm check các hàm / cú pháp Oracle
# chưa tương thích / cần xem lại ở PostgreSQL
###############################################
check_oracle_incompat() {
    local file=$1

    echo "----------------------------------------"
    echo "Oracle compatibility check for: $file"
    echo "Các hàm/cú pháp sau nếu xuất hiện thì cần xem lại/convert tay:"
    echo "  - NVL (nếu còn sót), DECODE, TO_DATE, TO_CHAR, TO_TIMESTAMP"
    echo "  - ADD_MONTHS, MONTHS_BETWEEN, LAST_DAY, NEXT_DAY, TRUNC(date)"
    echo "  - ROWNUM, DBMS_*"
    echo "  - TYPE ... IS TABLE OF ... INDEX BY ..."
    echo "  - array.EXISTS(cnt)"
    echo "  - FETCH cursor INTO array[index]"
    echo "  - Outer join kiểu Oracle: ( + )"
    echo "  - NULL() (dùng sai trong PostgreSQL)"
    echo "  - IN OUT / INOUT parameter"
    echo "  - Gọi typeArray() để init (varA := typeArray())"
    echo "  - SQLCODE, SQLERRM(...)"
    echo "  - OID (cần xem lại nếu đang dùng để tham chiếu row)"
    echo

    # Mỗi entry dạng: "LABEL|REGEX"
    local checks=(
        # Hàm / expression Oracle
        "NVL|\\bNVL\\s*\\("
        "DECODE|\\bDECODE\\s*\\("
        "TO_DATE|\\bTO_DATE\\s*\\("
        "TO_CHAR|\\bTO_CHAR\\s*\\("
        "TO_TIMESTAMP|\\bTO_TIMESTAMP\\s*\\("
        "ADD_MONTHS|\\bADD_MONTHS\\s*\\("
        "MONTHS_BETWEEN|\\bMONTHS_BETWEEN\\s*\\("
        "LAST_DAY|\\bLAST_DAY\\s*\\("
        "NEXT_DAY|\\bNEXT_DAY\\s*\\("
        "TRUNC|\\bTRUNC\\s*\\("
        "ROWNUM|\\bROWNUM\\b"
        "DBMS_PACKAGE|\\bDBMS_[A-Z0-9_]+"

        # Oracle collection kiểu TABLE OF ... INDEX BY ...
        "TABLE_OF_INDEX_BY|TYPE[[:space:]]+[A-Za-z0-9_]+[[:space:]]+IS[[:space:]]+TABLE[[:space:]]+OF"

        # FETCH cursor INTO array[index]
        "FETCH_ARRAY_INTO|\\bFETCH[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+INTO[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\\["

        # array.EXISTS(idx)
        "ARRAY_EXISTS|\\b[A-Za-z_][A-Za-z0-9_]*\\s*\\.EXISTS\\s*\\("

        # Outer join Oracle: (+)
        "OUTER_JOIN_PLUS|\\(\\+\\)"

        # NULL() dùng như hàm
        "NULL_FUNC|\\bNULL\\s*\\("

        # IN OUT / INOUT parameter
        "INOUT_PARAM|\\bIN[[:space:]]+OUT\\b|\\bINOUT\\b"

        # typeArray() init: varA := typeArray()
        "TYPE_INIT_CALL|:=\\s*[A-Za-z_][A-Za-z0-9_]*\\s*\\(\\s*\\)"

        # SQLCODE, SQLERRM
        "SQLCODE_USAGE|\\bSQLCODE\\b"
        "SQLERRM_CALL|\\bSQLERRM\\s*\\("

        # OID usage
        "OID_USAGE|\\boid\\b"
    )

    local has_any=0

    for entry in "${checks[@]}"; do
        local label="${entry%%|*}"
        local regex="${entry#*|}"

        # grep -niE: -n = số dòng, -i = ignore case, -E = regex mở rộng
        local matches
        matches=$(grep -niE "$regex" "$file" 2>/dev/null || true)

        if [[ -n "$matches" ]]; then
            has_any=1
            echo ">>> [$label] tìm thấy các dòng sau (cần xem lại/convert tay):"
            echo "$matches"
            echo
        fi
    done

    if [[ $has_any -eq 0 ]]; then
        echo "Không phát hiện hàm/cú pháp Oracle 'nhạy cảm' trong danh sách check ở trên."
    fi

    echo "----------------------------------------"
    echo
}

convert_complex_file() {
    local file=$1
    
    echo "Converting: $file"
    
    #################################################################
    # Step 0: Fix invalid comment syntax " */;" (Oracle -> Postgres)
    #################################################################
    sed -i 's/ \*\/;$//' "$file"
    
    #################################################################
    # Step 1: Basic signature conversion (function header)
    #   FUNCTION xxx (...) RETURN NUMBER IS
    # -> RETURNS NUMERIC LANGUAGE plpgsql AS $body$
    #################################################################
    sed -i 's/RETURN NUMBER IS$/RETURNS NUMERIC LANGUAGE plpgsql AS $body$/g' "$file"
    sed -i 's/RETURN VARCHAR IS$/RETURNS VARCHAR LANGUAGE plpgsql AS $body$/g' "$file"
    
    #################################################################
    # Step 2: Add DECLARE after function signature
    #################################################################
    sed -i '/^RETURNS.*LANGUAGE plpgsql AS \$body\$$/a\DECLARE' "$file"
    
    #################################################################
    # Step 3: Type conversions (Oracle -> PostgreSQL)
    #################################################################
    # Chuỗi
    sed -i 's/\bVARCHAR2\b/VARCHAR/g' "$file"
    sed -i 's/\bNVARCHAR2\b/VARCHAR/g' "$file"

    # CHAR(n) giữ nguyên, CHAR không độ dài -> TEXT
    sed -i -E 's/\bCHAR\s*\(([0-9]+)\)/__ORACLE_CHAR__\1__/g' "$file"
    sed -i -E 's/\bCHAR\b/TEXT/g' "$file"
    sed -i -E 's/__ORACLE_CHAR__([0-9]+)__/CHAR(\1)/g' "$file"

    # Số
    sed -i 's/\bNUMBER\b/NUMERIC/g' "$file"
    sed -i 's/\bINTEGER(\([0-9]*\))/INTEGER/g' "$file"

    # CLOB / LONG -> TEXT
    sed -i 's/\bCLOB\b/TEXT/g' "$file"
    sed -i 's/\bLONG\b/TEXT/g' "$file"

    # Binary types
    sed -i 's/\bBLOB\b/BYTEA/g' "$file"
    sed -i -E 's/\bRAW\s*\(\s*[0-9]+\s*\)/BYTEA/g' "$file"
    sed -i 's/\bRAW\b/BYTEA/g' "$file"
    
    #################################################################
    # Step 4: NVL -> COALESCE (chỉ cho pattern chuẩn NVL(...)
    #################################################################
    sed -i 's/\bNVL(/COALESCE(/g' "$file"

    #################################################################
    # Step 4b: collection COUNT: arr.COUNT -> COALESCE(cardinality(arr), 0)
    #################################################################
    sed -i 's/\b\([A-Za-z_][A-Za-z0-9_]*\)\.COUNT\b/COALESCE(cardinality(\1), 0)/g' "$file"
    
    #################################################################
    # Step 5: PKLOG.ERROR(...) -> CALL PKLOG.ERROR(...)
    #################################################################
    sed -i 's/\bPKLOG\./CALL PKLOG./g' "$file"
    
    #################################################################
    # Step 6: REF CURSOR -> REFCURSOR (thô, cần review thêm)
    #################################################################
    sed -i '/TYPE.*IS REF CURSOR;/d' "$file"
    sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\)\s*CURSOR_TYPE;/\1 REFCURSOR;/g' "$file"

    #################################################################
    # Step 6b: Remove alias from UPDATE target table
    #   UPDATE my_table t SET ... -> UPDATE my_table SET ...
    # (DELETE giữ nguyên)
    #################################################################
    sed -i -E 's/^(UPDATE[[:space:]]+(ONLY[[:space:]]+)?)([A-Za-z0-9_".]+)[[:space:]]+[A-Za-z0-9_"]+/\1\3/' "$file"
    
    #################################################################
    # Step 7: SQLERRM(SQLCODE) -> SQLERRM (safe auto-convert)
    #################################################################
    sed -i 's/SQLERRM\s*(\s*SQLCODE\s*)/SQLERRM/g' "$file"
    
    #################################################################
    # Step 8: Oracle block terminator "/" -> $body$;
    #################################################################
    sed -i 's/^\/$/$body$;/' "$file"
    
    echo "Basic conversion complete for: $file"

    #####################################################
    # Chạy check cảnh báo các chỗ Oracle-style còn lại
    #####################################################
    check_oracle_incompat "$file"
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file1.sql> [file2.sql ...]"
    exit 1
fi

for file in "$@"; do
    if [ -f "$file" ]; then
        convert_complex_file "$file"
    else
        echo "File not found: $file"
    fi
done

echo "Conversion complete!"
