// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NativeiOSIntegrations",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NativeiOSIntegrations",
            targets: ["NativeiOSIntegrations"]),
    ],
    dependencies: [
        .package(name: "PackageDeal", path: "../../PackageDeal"),
//        .package(url: "https://github.com/astro-bytes/PackageDeal.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NativeiOSIntegrations",
            dependencies: [
                .product(name: "GatewayBasics", package: "PackageDeal"),
                .product(name: "Logger", package: "PackageDeal")
            ]
        ),
        .testTarget(
            name: "NativeiOSIntegrationsTests",
            dependencies: ["NativeiOSIntegrations"]),
    ]
)
