#!/bin/bash
# =============================================================================
# Sellwild Prebid Mobile iOS Namespace Rename Script
# =============================================================================
#
# This script renames PrebidMobile to SellwildPrebid throughout the codebase
# to allow coexistence with a partner's existing PrebidMobile integration.
#
# Usage:
#   ./scripts/rename-namespace.sh
#
# After running, commit the changes and push to the fork.
#
# To update from upstream:
#   1. git fetch upstream
#   2. git merge upstream/master (resolve conflicts)
#   3. Run this script again
#   4. Commit and push
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

echo "============================================="
echo "Sellwild Prebid Mobile Namespace Rename"
echo "============================================="
echo ""
echo "Root directory: $ROOT_DIR"
echo ""

# -----------------------------------------------------------------------------
# Step 1: Rename directories
# -----------------------------------------------------------------------------
echo "Step 1: Renaming directories..."

# Main source directory
if [ -d "PrebidMobile" ] && [ ! -d "SellwildPrebid" ]; then
    mv PrebidMobile SellwildPrebid
    echo "  ✓ PrebidMobile -> SellwildPrebid"
fi

# Tests directory
if [ -d "PrebidMobileTests" ] && [ ! -d "SellwildPrebidTests" ]; then
    mv PrebidMobileTests SellwildPrebidTests
    echo "  ✓ PrebidMobileTests -> SellwildPrebidTests"
fi

# EventHandlers subdirectories
for dir in EventHandlers/PrebidMobile*; do
    if [ -d "$dir" ]; then
        newdir=$(echo "$dir" | sed 's/PrebidMobile/SellwildPrebid/g')
        if [ ! -d "$newdir" ]; then
            mv "$dir" "$newdir"
            echo "  ✓ $(basename $dir) -> $(basename $newdir)"
        fi
    fi
done

echo ""

# -----------------------------------------------------------------------------
# Step 2: Rename files
# -----------------------------------------------------------------------------
echo "Step 2: Renaming files containing 'PrebidMobile' in name..."

find . -type f -name "*PrebidMobile*" ! -path "./.git/*" | while read file; do
    newfile=$(echo "$file" | sed 's/PrebidMobile/SellwildPrebid/g')
    if [ "$file" != "$newfile" ]; then
        mkdir -p "$(dirname "$newfile")"
        mv "$file" "$newfile"
        echo "  ✓ $(basename $file) -> $(basename $newfile)"
    fi
done

echo ""

# -----------------------------------------------------------------------------
# Step 3: Update file contents - module/import references
# -----------------------------------------------------------------------------
echo "Step 3: Updating import statements and module references..."

# Swift files
find . -type f -name "*.swift" ! -path "./.git/*" -exec sed -i '' \
    -e 's/import PrebidMobile/import SellwildPrebid/g' \
    -e 's/@testable import PrebidMobile/@testable import SellwildPrebid/g' \
    -e 's/PrebidMobileAdMobAdapters/SellwildPrebidAdMobAdapters/g' \
    -e 's/PrebidMobileGAMEventHandlers/SellwildPrebidGAMEventHandlers/g' \
    -e 's/PrebidMobileMAXAdapters/SellwildPrebidMAXAdapters/g' \
    {} \;

echo "  ✓ Swift import statements updated"

# Objective-C files
find . -type f \( -name "*.h" -o -name "*.m" \) ! -path "./.git/*" -exec sed -i '' \
    -e 's/#import <PrebidMobile\//#import <SellwildPrebid\//g' \
    -e 's/@import PrebidMobile/@import SellwildPrebid/g' \
    -e 's/PrebidMobile\.h/SellwildPrebid.h/g' \
    {} \;

echo "  ✓ Objective-C import statements updated"

echo ""

# -----------------------------------------------------------------------------
# Step 4: Update Package.swift
# -----------------------------------------------------------------------------
echo "Step 4: Updating Package.swift..."

sed -i '' \
    -e 's/name: "PrebidMobile"/name: "SellwildPrebid"/g' \
    -e 's/"PrebidMobile"/"SellwildPrebid"/g' \
    -e 's/"PrebidMobileAdMobAdapters"/"SellwildPrebidAdMobAdapters"/g' \
    -e 's/"PrebidMobileGAMEventHandlers"/"SellwildPrebidGAMEventHandlers"/g' \
    -e 's/"PrebidMobileMAXAdapters"/"SellwildPrebidMAXAdapters"/g' \
    -e 's/"__PrebidMobileInternal"/"__SellwildPrebidInternal"/g' \
    -e 's/PrebidMobileOMSDK/SellwildPrebidOMSDK/g' \
    -e 's|path: "PrebidMobile"|path: "SellwildPrebid"|g' \
    Package.swift

echo "  ✓ Package.swift updated"

echo ""

# -----------------------------------------------------------------------------
# Step 5: Update Podspec files
# -----------------------------------------------------------------------------
echo "Step 5: Updating Podspec files..."

for podspec in *.podspec; do
    if [ -f "$podspec" ]; then
        newpodspec=$(echo "$podspec" | sed 's/PrebidMobile/SellwildPrebid/g')
        if [ "$podspec" != "$newpodspec" ]; then
            mv "$podspec" "$newpodspec"
        fi
        sed -i '' \
            -e "s/s\.name.*=.*['\"]PrebidMobile['\"]/s.name             = 'SellwildPrebid'/g" \
            -e 's/PrebidMobile/SellwildPrebid/g' \
            "$newpodspec" 2>/dev/null || true
        echo "  ✓ $newpodspec updated"
    fi
done

echo ""

# -----------------------------------------------------------------------------
# Step 6: Update xcframework references
# -----------------------------------------------------------------------------
echo "Step 6: Updating xcframework references..."

if [ -d "Frameworks/OMSDK_Prebidorg.xcframework" ]; then
    # Keep the OMSDK framework name as-is (it's a binary, renaming would break it)
    # But update references in Package.swift to use new target name
    echo "  ℹ OMSDK_Prebidorg.xcframework kept as-is (binary target)"
fi

echo ""

# -----------------------------------------------------------------------------
# Step 7: Update internal target references
# -----------------------------------------------------------------------------
echo "Step 7: Updating internal references..."

# Update path references in Package.swift for EventHandlers
sed -i '' \
    -e 's|path: "EventHandlers/PrebidMobile|path: "EventHandlers/SellwildPrebid|g' \
    Package.swift

echo "  ✓ EventHandler paths updated"

echo ""

# -----------------------------------------------------------------------------
# Step 8: Update Podfile
# -----------------------------------------------------------------------------
echo "Step 8: Updating Podfile..."

if [ -f "Podfile" ]; then
    sed -i '' \
        -e 's/PrebidMobile/SellwildPrebid/g' \
        Podfile
    echo "  ✓ Podfile updated"
fi

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "============================================="
echo "Namespace rename complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Build and test: swift build"
echo "  3. Commit: git add -A && git commit -m 'Rename PrebidMobile -> SellwildPrebid'"
echo "  4. Push: git push origin main"
echo ""
echo "To use in SellwildSDK:"
echo "  Update Package.swift dependency to point to this fork"
echo "  Change: import PrebidMobile"
echo "  To:     import SellwildPrebid"
echo ""
