// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RateLimiter",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "RateLimiter",
            targets: ["RateLimiter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/combine-schedulers.git", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "0.0.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2")
    ],
    targets: [
        .target(
            name: "RateLimiter",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .testTarget(
            name: "RateLimiterTests",
            dependencies: ["RateLimiter",
                           .product(name: "CombineSchedulers", package: "combine-schedulers")]),
    ])
