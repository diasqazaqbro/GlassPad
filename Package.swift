// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassPad",
    defaultLocalization: "en",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "GlassPad", targets: ["GlassPad"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.10.0")
    ],
    targets: [
        // C shim that dlopen()s the private MultitouchSupport framework so we can
        // detect the 4-finger trackpad pinch (no build-time link dependency).
        .target(
            name: "CMultitouch",
            path: "Sources/CMultitouch"
        ),
        .executableTarget(
            name: "GlassPad",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                "CMultitouch"
            ],
            path: "Sources/GlassPad",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("CoreFoundation")
            ]
        )
    ]
)
