# SellwildPrebidSDK Fork Maintenance

## Why This Fork Exists

Prebid Mobile SDK uses a **singleton pattern** (`Prebid.shared`) — there's only one global Prebid configuration per app. When a host app (like WeatherBug) uses their own Prebid Mobile SDK for their ads, initializing Sellwild's SDK would **overwrite their Prebid Server URL**, breaking their ad setup.

This fork renames all Prebid classes and the module itself so Sellwild can have its own isolated `SellwildPrebid.shared` singleton that coexists with the host app's `Prebid.shared`.

## What Changed

| Original | Renamed |
|----------|---------|
| Module: `PrebidMobile` | Module: `SellwildPrebidSDK` |
| Class: `Prebid` | Class: `SellwildPrebid` |
| Class: `BannerAdUnit` | Class: `SellwildBannerAdUnit` |
| Class: `BannerView` | Class: `BannerView` (same, but in `SellwildPrebidSDK` module) |
| Event handlers | `SellwildPrebidGAMEventHandler`, etc. |

## Fork Location

- **Upstream**: https://github.com/prebid/prebid-mobile-ios
- **Fork**: https://github.com/Antengo/sellwild-prebid-mobile-ios

## How to Update the Fork

When a new Prebid Mobile SDK version is released:

```bash
cd /path/to/sellwild-prebid-mobile-ios

# 1. Fetch upstream changes
git fetch upstream

# 2. Merge the new version (or a specific tag)
git merge upstream/master
# Or for a specific version:
# git merge v2.3.0

# 3. Run the namespace rename script
./scripts/rename-namespace.sh

# 4. Build and test
cd /path/to/sellwild-sdk/samples/feed-demo-ios
xcodebuild -project FeedDemo.xcodeproj -scheme FeedDemo \
  -destination "platform=iOS Simulator,name=iPhone 15" build

# 5. If build succeeds, commit and push
cd /path/to/sellwild-prebid-mobile-ios
git add -A
git commit -m "chore: merge upstream vX.Y.Z + re-apply namespace shading"
git push origin master
```

## Namespace Rename Script

The script at `scripts/rename-namespace.sh` handles:

1. Renaming directories: `PrebidMobile/` → `SellwildPrebid/`
2. Renaming files: `Prebid.swift` → `SellwildPrebid.swift`
3. Replacing class names in source code
4. Updating Package.swift module/target names
5. Updating Obj-C imports

## Using in SellwildSDK

In `Package.swift`:

```swift
dependencies: [
    .package(url: "git@github.com:Antengo/sellwild-prebid-mobile-ios.git", branch: "master"),
],
targets: [
    .target(
        name: "SellwildSDK",
        dependencies: [
            .product(name: "SellwildPrebidSDK", package: "sellwild-prebid-mobile-ios"),
        ],
    ),
]
```

In Swift code:

```swift
import SellwildPrebidSDK

// Use SellwildPrebid.shared instead of Prebid.shared
SellwildPrebid.shared.prebidServerAccountId = "weatherbug"

// Use SellwildBannerAdUnit instead of BannerAdUnit  
let adUnit = SellwildBannerAdUnit(configId: "zone-123")
```

## Troubleshooting

### Build errors after merge

If you get build errors after merging upstream:

1. Check if new files were added that need renaming
2. Run `grep -r "PrebidMobile" SellwildPrebid/` to find missed replacements
3. Check `Package.swift` for new targets that need updating

### Module ambiguity errors

If Swift complains about ambiguous types (e.g., `BannerView` exists in both `SellwildPrebidSDK` and `GoogleMobileAds`), use typealiases:

```swift
typealias PrebidBannerView = SellwildPrebidSDK.BannerView
```

### Obj-C import errors

Check `SellwildPrebid/Objc/PrivateHeaders/SwiftImport.h` — it should import `SellwildPrebidSDK`, not `SellwildPrebid`.
