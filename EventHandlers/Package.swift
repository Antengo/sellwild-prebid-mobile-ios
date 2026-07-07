// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    
    name: "PrebidMobileAdapters",
    platforms: [
        .iOS(.v13),
    ],
    products: [
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
        .package(url: "https://github.com/prebid/prebid-mobile-ios-sdk.git", .upToNextMajor(from: "3.3.1"))
    ],
    targets: [
        .target(
            name: "SellwildPrebidAdMobAdapters",
            dependencies: [
                .product(name: "PrebidMobile", package: "prebid-mobile-ios-sdk"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ],
            path: "SellwildPrebidAdMobAdapters",
            sources: ["Sources"]
        ),
        .target(
            name: "SellwildPrebidGAMEventHandlers",
            dependencies: [
                .product(name: "PrebidMobile", package: "prebid-mobile-ios-sdk"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ],
            path: "SellwildPrebidGAMEventHandlers",
            sources: ["Sources"]
        ),
        .target(
            name: "SellwildPrebidMAXAdapters",
            dependencies: [
                .product(name: "PrebidMobile", package: "prebid-mobile-ios-sdk"),
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
            ],
            path: "SellwildPrebidMAXAdapters",
            sources: ["Sources"]
        ),
    ]
)
