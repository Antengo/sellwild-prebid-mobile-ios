#!/bin/bash
# Rename internal PBM prefix to SWPBM so ObjC classes/headers/selectors don't
# collide with the upstream PrebidMobile pod when both are installed.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Replacing PBM -> SWPBM in file contents..."
find . -type f \
  \( -name "*.swift" -o -name "*.h" -o -name "*.m" -o -name "*.js" \
     -o -name "*.pbxproj" -o -name "*.xcscheme" -o -name "*.xctestplan" \
     -o -name "*.storyboard" -o -name "*.xml" -o -name "*.podspec" \
     -o -name "Package.swift" -o -name "*.modulemap" \) \
  -not -path "./.git/*" -print0 | while IFS= read -r -d '' f; do
    # Uppercase prefix (classes, headers, constants, macros)
    perl -pi -e 's/PBM/SWPBM/g' "$f"
    # Lowercase prefix (category method selectors) - word start only,
    # protects base64 blobs like "dpbm"
    perl -pi -e 's/(?<![a-zA-Z0-9])pbm/swpbm/g' "$f"
done

echo "==> Renaming files and directories..."
# Deepest paths first so parent renames don't invalidate child paths
find . -depth -name "*PBM*" -not -path "./.git/*" | while read -r path; do
    newpath="$(dirname "$path")/$(basename "$path" | sed 's/PBM/SWPBM/g')"
    git mv "$path" "$newpath" 2>/dev/null || mv "$path" "$newpath"
done

echo "==> Done. Verify with: grep -rn '\\bPBM' --include='*.swift' --include='*.h' --include='*.m' . | grep -v .git"
