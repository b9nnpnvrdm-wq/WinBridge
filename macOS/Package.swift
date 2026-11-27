// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WinBridge",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WinBridge", targets: ["WinBridge"])],
    targets: [
        .target(name: "WinBridgeCore"),
        .binaryTarget(
            name: "Sparkle",
            url: "https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-for-Swift-Package-Manager.zip",
            checksum: "4c2e48a3e50ebcc2c88a58a4c7264a1a99c3c31857ce754357afb9cdb323022a"
        ),
        .executableTarget(
            name: "WinBridge", dependencies: ["WinBridgeCore", "Sparkle"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "WinBridgeCoreTests", dependencies: ["WinBridgeCore"])
    ]
)
