// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    
    name: "SellwildPrebidSDK",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "SellwildPrebidSDK",
            targets: ["SellwildPrebidSDK", "__SellwildPrebidInternal"]
        ),
        .library(
            name: "SellwildPrebidAdMobAdapters",
            targets: ["SellwildPrebidAdMobAdapters"]
        ),
        .library(
            name: "SellwildPrebidGAMEventHandlers",
            targets: ["SellwildPrebidGAMEventHandlers"]
        ),
        .library(
            name: "SellwildPrebidMAXAdapters",
            targets: ["SellwildPrebidMAXAdapters"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", .upToNextMajor(from: "13.0.0")),
        .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", .upToNextMajor(from: "13.0.0")),
    ],
    targets: [
        .target(
            name: "SellwildPrebidSDK",
            path: "SellwildPrebid",
            sources: ["Swift"]
        ),
        .target(
            name: "__SellwildPrebidInternal",
            dependencies: [
                "SellwildPrebidSDK",
                "SellwildPrebidOMSDK",
            ],
            path: "SellwildPrebid",
            sources: ["Objc"],
            cSettings: [
                .headerSearchPath("./Objc/PrivateHeaders"),
                .define("PrebidMobile_SPM", to: "1"),
            ]
        ),
        .binaryTarget(
            name: "SellwildPrebidOMSDK",
            path: "Frameworks/OMSDK_Prebidorg.xcframework"
        ),
        .target(
            name: "SellwildPrebidAdMobAdapters",
            dependencies: [
                "SellwildPrebidSDK",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ],
            path: "EventHandlers/SellwildPrebidAdMobAdapters",
            sources: ["Sources"]
        ),
        .target(
            name: "SellwildPrebidGAMEventHandlers",
            dependencies: [
                "SellwildPrebidSDK",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ],
            path: "EventHandlers/SellwildPrebidGAMEventHandlers",
            sources: ["Sources"]
        ),
        .target(
            name: "SellwildPrebidMAXAdapters",
            dependencies: [
                "SellwildPrebidSDK",
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
            ],
            path: "EventHandlers/SellwildPrebidMAXAdapters",
            sources: ["Sources"]
        ),
    ]
)
