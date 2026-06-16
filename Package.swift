// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassPad",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "GlassPad", targets: ["GlassPad"])
    ],
    targets: [
        .executableTarget(
            name: "GlassPad",
            path: "Sources/GlassPad",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
