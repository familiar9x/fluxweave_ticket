#!/bin/bash
#
# Script: fix_invalid_comments.sh
# Purpose: Remove invalid Oracle comment syntax " */;" that causes PostgreSQL errors
# Usage: 
#   ./fix_invalid_comments.sh [directory]           # Fix all files
#   ./fix_invalid_comments.sh --check [directory]   # Check only, don't fix
#
# This pattern appears in Oracle-migrated PL/SQL files where comments end with " */;"
# PostgreSQL expects either "*/" or ";" but not both together.
#
# Example workflow:
#   1. ./fix_invalid_comments.sh --check    # Preview issues
#   2. ./fix_invalid_comments.sh            # Apply fixes
#   3. Compile and fix other errors
#

set +e  # Don't exit on error - grep returns 1 when no matches found

# Parse arguments
CHECK_ONLY=false
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --check|-c)
            CHECK_ONLY=true
            shift
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Default to plsql directory if no argument provided
TARGET_DIR="${TARGET_DIR:-../../jip-ipa/db/plsql}"

echo "================================================"
echo "  Fixing Invalid Comment Syntax in PL/SQL Files"
echo "================================================"
echo ""
if [ "$CHECK_ONLY" = true ]; then
    echo "🔍 MODE: CHECK ONLY (no changes will be made)"
else
    echo "🔧 MODE: FIX (will modify files)"
fi
echo "Target directory: $TARGET_DIR"
echo "Pattern to fix: ' */;' at end of lines"
echo ""

# Counter for tracking changes
TOTAL_FILES=0
FIXED_FILES=0
TOTAL_FIXES=0

# Find all .sql and .SQL files
while IFS= read -r -d '' file; do
    ((TOTAL_FILES++))
    
    # Count occurrences of " */;" in the file
    COUNT=$(grep -c " \*/;" "$file" 2>/dev/null || true)
    
    if [ "$COUNT" -gt 0 ]; then
        echo "📝 Found $COUNT invalid comment(s) in: $file"
        
        # Show line numbers for reference
        grep -n " \*/;" "$file" | while read -r line; do
            echo "   Line: $line"
        done
        
        if [ "$CHECK_ONLY" = false ]; then
            # Fix by removing " */;" and leaving just the comment close
            sed -i 's/ \*\/;$//' "$file"
            echo "   ✅ Fixed!"
        else
            echo "   ⚠️  Would fix (use without --check to apply)"
        fi
        
        ((FIXED_FILES++))
        ((TOTAL_FIXES+=COUNT))
        echo ""
    fi
done < <(find "$TARGET_DIR" -type f \( -name "*.sql" -o -name "*.SQL" \) -print0)

echo "================================================"
echo "  Summary"
echo "================================================"
echo "Total files scanned:  $TOTAL_FILES"
if [ "$CHECK_ONLY" = true ]; then
    echo "Files with issues:    $FIXED_FILES"
    echo "Total issues found:   $TOTAL_FIXES"
else
    echo "Files fixed:          $FIXED_FILES"
    echo "Total fixes applied:  $TOTAL_FIXES"
fi
echo ""

if [ "$TOTAL_FIXES" -gt 0 ]; then
    if [ "$CHECK_ONLY" = true ]; then
        echo "⚠️  Found invalid comments!"
        echo ""
        echo "To fix them, run:"
        echo "  ./fix_invalid_comments.sh $TARGET_DIR"
    else
        echo "✅ Invalid comments have been fixed!"
        echo ""
        echo "Next steps:"
        echo "1. Review changes with: git diff"
        echo "2. Test compilation"
        echo "3. Commit changes if everything works"
    fi
else
    echo "✨ No invalid comments found - all files are clean!"
fi

echo ""
echo "Done!"
