// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassPad",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "GlassPad", targets: ["GlassPad"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.10.0")
    ],
    targets: [
        .executableTarget(
            name: "GlassPad",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/GlassPad",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
