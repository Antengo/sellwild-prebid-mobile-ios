# SellwildPrebid Fork Maintenance

## Why This Fork Exists

Prebid Mobile SDK uses a **singleton pattern** (`Prebid.shared`) — there's only one global Prebid configuration per app. When a host app (like WeatherBug) uses their own Prebid Mobile SDK for their ads, initializing Sellwild's SDK would **overwrite their Prebid Server URL**, breaking their ad setup.

This fork renames the module, public classes, AND all internal Objective-C symbols/headers/frameworks so Sellwild's Prebid can fully coexist with an unmodified `PrebidMobile` pod in the same app — via both SPM and CocoaPods.

## Fork Location

- **Upstream**: https://github.com/prebid/prebid-mobile-ios
- **Fork**: https://github.com/Antengo/sellwild-prebid-mobile-ios

## What Changed (three layers of renaming)

CocoaPods puts all pods in one Xcode project with header maps keyed by basename and a single link namespace, so surface-level renames aren't enough. Three layers were required:

### 1. Module & public API (`scripts/rename-namespace.sh`)

| Original | Renamed |
|----------|---------|
| Module: `PrebidMobile` | Module: `SellwildPrebidSDK` (⚠️ NOT `SellwildPrebid` — would collide with the class name and make `SellwildPrebid.BannerView` ambiguous) |
| Class: `Prebid` | Class: `SellwildPrebid` |
| Class: `BannerAdUnit` | Class: `SellwildBannerAdUnit` |
| Event handlers | `SellwildPrebidGAMEventHandler`, etc. |

### 2. Internal ObjC symbols & headers (`scripts/rename-pbm-prefix.sh`)

Needed because two pods with identically-named private headers / ObjC classes collide in CocoaPods (header shadowing + duplicate symbols at link time).

- All `PBM*` files and classes → `SWPBM*` (~654 files)
- `@objc(...)` exposed names in `Signals.swift`: `PBApi` → `SWPBApi`, `PBPlacement` → `SWPBPlacement`, etc.
- `OMSDKVersionProvider_Objc` → `SWOMSDKVersionProvider_Objc`
- `InternalUserConsentDataManager` → `SWInternalUserConsentDataManager`
- Colliding header basenames renamed: `Log+Extensions.h` → `SWLog+Extensions.h`, `SwiftImport.h` → `SWSwiftImport.h`, `Prebid+TestExtension.h` → `SellwildPrebid+TestExtension.h`

### 3. Vendored OMSDK framework (`scripts/rename-omsdk-framework.sh`)

- `OMSDK_Prebidorg.xcframework` → `OMSDK_Sellwild.xcframework` (embedded framework names must be unique per app)
- Referenced in both `Package.swift` and `SellwildPrebid.podspec`
- Note: the *classes inside* OMSDK (`OMIDPrebidorg*`) are unchanged (prebuilt binary) — a benign "class implemented in both" runtime warning is expected when coexisting.

## Distribution

### SPM

```swift
.package(url: "https://github.com/Antengo/sellwild-prebid-mobile-ios.git", exact: "1.4.2"),
// product: "SellwildPrebidSDK"
```

### CocoaPods

Podspecs in this repo: `SellwildPrebid`, `SellwildPrebidGAMEventHandlers`, `SellwildPrebidAdMobAdapters`, `SellwildPrebidMAXAdapters`. **Not on the public trunk** — partners use direct git refs:

```ruby
pod 'SellwildPrebid', :git => 'https://github.com/Antengo/sellwild-prebid-mobile-ios.git', :tag => '1.4.2'
pod 'SellwildPrebidGAMEventHandlers', :git => 'https://github.com/Antengo/sellwild-prebid-mobile-ios.git', :tag => '1.4.2'
```

Key podspec settings (do not remove):
- `SellwildPrebid.podspec` sets `module_name = 'SellwildPrebidSDK'` — keeps the CocoaPods module name identical to SPM and avoids the module/class name collision.

## Release Process

Versions here track **SellwildSDK versions** (e.g. 1.4.2), not upstream Prebid versions (3.3.x).

1. Bump `s.version` in all 4 podspecs (and the `SellwildPrebid` dependency pin inside the adapter podspecs)
2. Commit, tag (e.g. `1.4.3`), push with `--tags`
3. In `sellwild-sdk`: bump `SellwildSDK.podspec` (version + fork dependency pins), `Package.swift` (`exact:` pin), `AGENTS.md` and `docs-site/guide/ios.md` snippets; commit, tag, push
4. **Never move an existing tag** — cut a new version (partners' CocoaPods/SPM caches pin tag→SHA)

## Verification (required before declaring a release done)

```bash
# SPM path
cd sellwild-sdk/samples/feed-demo-ios
xcodebuild -project FeedDemo.xcodeproj -scheme FeedDemo \
  -destination "platform=iOS Simulator,name=iPhone 15" build

# CocoaPods coexistence path — Podfile with BOTH:
#   pod 'PrebidMobile', '~> 3.0'
#   pod 'SellwildSDK' (+ the two fork pods, via git tags)
pod install && xcodebuild -workspace TestApp.xcworkspace -scheme TestApp \
  -destination "platform=iOS Simulator,name=iPhone 15" build ENABLE_BITCODE=NO
```

Both must build with 0 errors and no duplicate-symbol link failures.

## How to Update the Fork (upstream Prebid bump)

```bash
cd sellwild-prebid-mobile-ios
git fetch upstream && git merge <upstream-tag>

# Re-apply all three rename layers to any new/changed files
./scripts/rename-namespace.sh
./scripts/rename-pbm-prefix.sh
./scripts/rename-omsdk-framework.sh   # only if upstream shipped a new OMSDK binary

# Hunt for missed renames
grep -rn "PrebidMobile" SellwildPrebid/ EventHandlers/ --include="*.swift" --include="*.h" --include="*.m"
grep -rn "\bPBM" SellwildPrebid/ --include="*.h" -l
grep -rn '@objc(PB' SellwildPrebid/

# Then run the full Verification section above, commit, tag, push
```

## Troubleshooting

- **"X is ambiguous for type lookup"** — a type exists in both `SellwildPrebidSDK` and `GoogleMobileAds`; fully qualify or add a typealias (`SellwildPrebidSDK.NativeAd`)
- **"'BannerView' is not a member type of class 'SellwildPrebid.SellwildPrebid'"** — module got renamed back to match the class name; module must stay `SellwildPrebidSDK`
- **Duplicate ObjC symbols when coexisting** — a new upstream `@objc` class or PBM file was missed by the rename scripts; grep as above
- **Private header not found in CocoaPods** — a header basename collides with upstream PrebidMobile's; rename it with an `SW` prefix
- **ObjC import errors** — check `SWSwiftImport.h` imports `SellwildPrebidSDK`, not `SellwildPrebid`
