#!/bin/bash
# Properly rename OMSDK_Prebidorg.framework -> OMSDK_Sellwild.framework inside
# the xcframework: directory, binary, install name, modulemap, Info.plists.
set -euo pipefail
XCFW="$(dirname "$0")/../Frameworks/OMSDK_Sellwild.xcframework"
cd "$XCFW"

for slice in */; do
  slice="${slice%/}"
  [ -d "$slice/OMSDK_Prebidorg.framework" ] || continue
  echo "==> $slice"
  mv "$slice/OMSDK_Prebidorg.framework" "$slice/OMSDK_Sellwild.framework"
  FW="$slice/OMSDK_Sellwild.framework"
  mv "$FW/OMSDK_Prebidorg" "$FW/OMSDK_Sellwild"
  install_name_tool -id "@rpath/OMSDK_Sellwild.framework/OMSDK_Sellwild" "$FW/OMSDK_Sellwild"
  # Module map
  sed -i '' 's/OMSDK_Prebidorg/OMSDK_Sellwild/g' "$FW/Modules/module.modulemap"
  # Framework Info.plist
  plutil -replace CFBundleExecutable -string "OMSDK_Sellwild" "$FW/Info.plist"
  plutil -replace CFBundleName -string "OMSDK_Sellwild" "$FW/Info.plist"
  plutil -replace CFBundleIdentifier -string "com.sellwild.OMSDK-Sellwild" "$FW/Info.plist"
  # Ad-hoc re-sign after binary modification
  codesign -f -s - "$FW/OMSDK_Sellwild" 2>/dev/null || true
done

# xcframework Info.plist: update BinaryPath / LibraryPath
sed -i '' 's/OMSDK_Prebidorg/OMSDK_Sellwild/g' Info.plist
plutil -lint Info.plist
echo "==> Done"
