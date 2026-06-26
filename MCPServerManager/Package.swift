// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MCPServerManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MCPServerManager",
            targets: ["MCPServerManager"]
        ),
        // Agent-first command-line interface. Built by `swift build`; not part
        // of the Mac App Store target (see Package.swift.appstore).
        .executable(
            name: "mcp-panel",
            targets: ["MCPPanelCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "MCPServerManager",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "MCPServerManager",
            exclude: ["Info.plist", "MCPServerManager.entitlements"],
            resources: [
                .process("Resources"),
                .process("Assets.xcassets")
            ]
        ),
        // Self-contained CLI target (pure Foundation, no SwiftUI/Sparkle) that
        // shares MCP Panel's on-disk format and UserDefaults cache.
        .executableTarget(
            name: "MCPPanelCLI",
            path: "CLI"
        )
    ]
)
