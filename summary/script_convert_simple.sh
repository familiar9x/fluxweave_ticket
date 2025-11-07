#!/bin/bash
# Comprehensive Oracle to PostgreSQL converter for complex files
# Handles nested functions, TYPE definitions, and some Oracle-specific patterns

convert_complex_file() {
    local file=$1
    local temp_file="${file}.tmp"
    
    echo "Converting: $file"
    
    #################################################################
    # Step 0: Fix invalid comment syntax " */;" (Oracle -> Postgres)
    # Oracle hay có dòng kết: " */;" sau block comment
    # PostgreSQL chỉ chấp nhận "*/" hoặc ";" chứ không chấp nhận "*/;"
    # Ở đây ta remove đoạn " */;" ở cuối dòng
    #################################################################
    sed -i 's/ \*\/;$//' "$file"
    
    #################################################################
    # Step 1: Basic signature conversion (function header)
    # Oracle:
    #   FUNCTION xxx (...) RETURN NUMBER IS
    # Postgres:
    #   ... RETURNS NUMERIC LANGUAGE plpgsql AS $body$
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
    # 3.1 Chuỗi
    sed -i 's/\bVARCHAR2\b/VARCHAR/g' "$file"
    sed -i 's/\bNVARCHAR2\b/VARCHAR/g' "$file"

    # 3.2 CHAR:
    # - CHAR(n) giữ nguyên
    # - CHAR (không có (n)) => TEXT

    # Bảo vệ CHAR(n) trước, tránh bị rule CHAR -> TEXT ăn mất
    sed -i -E 's/\bCHAR\s*\(([0-9]+)\)/__ORACLE_CHAR__\1__/g' "$file"

    # CHAR không độ dài -> TEXT
    sed -i -E 's/\bCHAR\b/TEXT/g' "$file"

    # Khôi phục lại CHAR(n)
    sed -i -E 's/__ORACLE_CHAR__([0-9]+)__/CHAR(\1)/g' "$file"

    # 3.3 Số
    sed -i 's/\bNUMBER\b/NUMERIC/g' "$file"
    sed -i 's/\bINTEGER(\([0-9]*\))/INTEGER/g' "$file"

    # 3.4 CLOB / LONG -> TEXT
    sed -i 's/\bCLOB\b/TEXT/g' "$file"
    sed -i 's/\bLONG\b/TEXT/g' "$file"

    # 3.5 Binary types
    sed -i 's/\bBLOB\b/BYTEA/g' "$file"
    sed -i -E 's/\bRAW\s*\(\s*[0-9]+\s*\)/BYTEA/g' "$file"
    sed -i 's/\bRAW\b/BYTEA/g' "$file"
    
    #################################################################
    # Step 4: Convert NVL to COALESCE
    #################################################################
    sed -i 's/\bNVL(/COALESCE(/g' "$file"

    #################################################################
    # Step 4b: Convert Oracle collection COUNT
    #   array_name.COUNT  ->  COALESCE(cardinality(array_name), 0)
    #################################################################
    sed -i 's/\b\([A-Za-z_][A-Za-z0-9_]*\)\.COUNT\b/COALESCE(cardinality(\1), 0)/g' "$file"
    
    #################################################################
    # Step 5: Add CALL for procedure calls (Oracle package proc -> Postgres CALL)
    # Oracle: PKLOG.ERROR(...)
    # PG:     CALL PKLOG.ERROR(...)
    #################################################################
    sed -i 's/\bPKLOG\./CALL PKLOG./g' "$file"
    
    #################################################################
    # Step 6: Convert cursor types
    # Oracle: TYPE t_cur IS REF CURSOR;
    #         v_cur t_cur;
    # PG:     v_cur REFCURSOR;
    #################################################################
    sed -i '/TYPE.*IS REF CURSOR;/d' "$file"
    sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\)\s*CURSOR_TYPE;/\1 REFCURSOR;/g' "$file"

    #################################################################
    # Step 6b: Remove alias from UPDATE target table
    # Oracle:
    #   UPDATE my_table t SET ...
    # PG:
    #   UPDATE my_table SET ...
    #################################################################
    sed -i -E 's/^(UPDATE[[:space:]]+(ONLY[[:space:]]+)?)([A-Za-z0-9_".]+)[[:space:]]+[A-Za-z0-9_"]+/\1\3/' "$file"
    
    #################################################################
    # Step 7: (TODO) TYPE ... IS TABLE OF ...  -- vẫn để xử lý tay / tool nâng cao hơn
    #################################################################
    
    #################################################################
    # Step 8: Convert Oracle block terminator "/" -> Postgres $body$;
    # Oracle:
    #   END;
    #   /
    # Postgres:
    #   END;
    #   $body$;
    #################################################################
    sed -i 's/^\/$/$body$;/' "$file"
    
    echo "Basic conversion complete for: $file"
}

# Main execution
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
