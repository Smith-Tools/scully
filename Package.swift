// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "scully",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "scully",
            targets: ["ScullyCLI"]
        ),
        .library(
            name: "ScullyCore",
            targets: ["ScullyCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.40.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(path: "../smith-rag"),
        .package(path: "../smith-docs"),
    ],
    targets: [
        .executableTarget(
            name: "ScullyCLI",
            dependencies: [
                "ScullyCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "ScullyTypes",
            dependencies: [
                .product(name: "SmithDocs", package: "smith-docs")
            ]
        ),
        .target(
            name: "ScullyCore",
            dependencies: [
                "ScullyTypes",
                "ScullyAnalysis",
                "ScullyFetch",
                "ScullyProcess",
                "ScullyDatabase",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "SmithRAG", package: "smith-rag"),
            ]
        ),
        .target(
            name: "ScullyAnalysis",
            dependencies: [
                "ScullyTypes",
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .target(
            name: "ScullyFetch",
            dependencies: [
                "ScullyTypes",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "ScullyProcess",
            dependencies: [
                "ScullyTypes",
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),
        .target(
            name: "ScullyDatabase",
            dependencies: [
                "ScullyTypes",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "ScullyTests",
            dependencies: [
                "ScullyCore",
                "ScullyAnalysis",
                "ScullyFetch",
                "ScullyProcess",
                "ScullyDatabase",
            ],
            path: "Tests"
        ),
    ]
)