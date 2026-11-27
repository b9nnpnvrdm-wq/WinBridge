// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WinBridge",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WinBridge", targets: ["WinBridge"])],
    targets: [
        .target(name: "WinBridgeCore"),
        .executableTarget(name: "WinBridge", dependencies: ["WinBridgeCore"]),
        .testTarget(name: "WinBridgeCoreTests", dependencies: ["WinBridgeCore"])
    ]
)
