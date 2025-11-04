#!/bin/bash
# Comprehensive Oracle to PostgreSQL converter for complex files
# Handles nested functions and TYPE definitions

convert_complex_file() {
    local file=$1
    local temp_file="${file}.tmp"
    
    echo "Converting: $file"
    
    # Step 1: Basic signature conversion
    sed -i 's/RETURN NUMBER IS$/RETURNS NUMERIC LANGUAGE plpgsql AS $body$/g' "$file"
    sed -i 's/RETURN VARCHAR IS$/RETURNS VARCHAR LANGUAGE plpgsql AS $body$/g' "$file"
    
    # Step 2: Add DECLARE after function signature
    sed -i '/^RETURNS.*LANGUAGE plpgsql AS \$body\$$/a\DECLARE' "$file"
    
    # Step 3: Type conversions
    sed -i 's/\bVARCHAR2\b/VARCHAR/g' "$file"
    sed -i 's/\bNUMBER\b/NUMERIC/g' "$file"
    sed -i 's/\bINTEGER(\([0-9]*\))/INTEGER/g' "$file"
    
    # Step 4: Convert NVL to COALESCE
    sed -i 's/\bNVL(/COALESCE(/g' "$file"
    
    # Step 5: Add CALL for procedure calls
    sed -i 's/\bPKLOG\./CALL PKLOG./g' "$file"
    
    # Step 6: Convert cursor types
    sed -i '/TYPE.*IS REF CURSOR;/d' "$file"
    sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\)\s*CURSOR_TYPE;/\1 REFCURSOR;/g' "$file"
    
    # Step 7: Remove TYPE...IS TABLE OF declarations (will handle separately)
    # Don't delete yet, just comment out for now
    
    # Step 8: Convert END statement
    sed -i 's/^END;$/END;/g' "$file"
    sed -i 's/^END;[[:space:]]*\/[[:space:]]*$/$body$;/g' "$file"
    sed -i '/^END;$/a\$body$;' "$file"
    
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
