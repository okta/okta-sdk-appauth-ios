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