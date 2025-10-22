#!/bin/bash
# Disable all debug flags in GDScript files

# Files with DEBUG_DISABLED
for file in script/*.gd scene/*/*.gd; do
    [ -f "$file" ] || continue
    
    # Set all DEBUG flags to false
    sed -i '' 's/const\s\+DEBUG_DISABLED\s*=\s*true/const DEBUG_DISABLED = false/g' "$file"
    sed -i '' 's/const\s\+DEBUG_ENABLED\s*=\s*true/const DEBUG_ENABLED = false/g' "$file"
    sed -i '' 's/const\s\+DEBUG_PRINTS\s*=\s*true/const DEBUG_PRINTS = false/g' "$file"
    sed -i '' 's/const\s\+DEBUG_DISABLED\s*=\s*false/const DEBUG_DISABLED = true/g' "$file"
done

echo "Debug flags disabled successfully"
