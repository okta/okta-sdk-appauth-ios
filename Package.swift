// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OktaOidc",
    platforms: [
        .macOS(.v10_11),
        .iOS(.v10),
    ],
    products: [
        .library(
            name: "OktaOidc",
            targets: ["OktaOidc"]),
    ],
    targets: [
        .target(
            name: "OktaOidc",
            dependencies: [],
            path: "Okta")
    ],
    swiftLanguageVersions: [.v5]
)