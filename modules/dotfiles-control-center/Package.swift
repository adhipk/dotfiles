// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DotfilesControlCenter",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "ExtensionKit", targets: ["ExtensionKit"]),
        .executable(name: "dotfiles-utility", targets: ["UtilityCLI"]),
        .executable(name: "dotfiles-service-runner", targets: ["ServiceRunner"]),
        .executable(
            name: "dotfiles-control-center",
            targets: ["DotfilesControlCenter"]
        ),
    ],
    targets: [
        .target(name: "ExtensionKit"),
        .executableTarget(name: "UtilityCLI", dependencies: ["ExtensionKit"]),
        .executableTarget(name: "ServiceRunner", dependencies: ["ExtensionKit"]),
        .testTarget(name: "ExtensionKitTests", dependencies: ["ExtensionKit"]),
        .executableTarget(
            name: "DotfilesControlCenter",
            dependencies: ["ExtensionKit"]
        ),
        .testTarget(
            name: "DotfilesControlCenterTests",
            dependencies: ["DotfilesControlCenter"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
