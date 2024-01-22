// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FirebaseIntegrations",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FirebaseIntegrations",
            targets: ["FirebaseIntegrations"]
        ),
    ],
    dependencies: [
        // Uncomment for local workspace
        .package(name: "PackageDeal", path: "../../PackageDeal"),
//        .package(url: "https://github.com/astro-bytes/PackageDeal.git", branch: "main"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "10.17.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FirebaseIntegrations",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "GatewayBasics", package: "PackageDeal"),
                .product(name: "Logger", package: "PackageDeal"),
            ]
        ),
        .testTarget(
            name: "FirebaseIntegrationsTests",
            dependencies: [
                "FirebaseIntegrations",
                .product(name: "Utility", package: "PackageDeal"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
