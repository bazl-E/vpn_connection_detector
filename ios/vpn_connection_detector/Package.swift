// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "vpn_connection_detector",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "vpn-connection-detector", targets: ["vpn_connection_detector"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "vpn_connection_detector",
            dependencies: [],
            resources: [
                // If your plugin requires a privacy manifest, uncomment the following line.
                // .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
