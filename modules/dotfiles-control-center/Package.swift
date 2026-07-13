// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DotfilesControlCenter",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "dotfiles-control-center",
            targets: ["DotfilesControlCenter"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "DotfilesControlCenter"
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
