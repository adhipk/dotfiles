// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "HelloUtility", platforms: [.macOS(.v13)], dependencies: [
    .package(path: "../../modules/dotfiles-control-center")
], targets: [.executableTarget(name: "HelloUtility", dependencies: [
    .product(name: "ExtensionKit", package: "dotfiles-control-center")
])])
