// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Schwips",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    products: [
        .library(name: "SchwipsCore", targets: ["SchwipsCore"]),
        .library(name: "SchwipsWebCellar", targets: ["SchwipsWebCellar"]),
        .executable(name: "schwips", targets: ["Schwips"]),
    ],
    targets: [
        // Display-free core: model, store, operations, import and pure logic.
        .target(
            name: "SchwipsCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Reads the SvelteKit web app's SQLite database once, for the copy on
        // first launch. Its own target so the core stays Foundation and SwiftData.
        .target(
            name: "SchwipsWebCellar",
            dependencies: ["SchwipsCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The Mac app. Every declaration is @MainActor by default.
        .executableTarget(
            name: "Schwips",
            dependencies: ["SchwipsCore", "SchwipsWebCellar"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self),
            ]
        ),
        .testTarget(
            name: "SchwipsCoreTests",
            dependencies: ["SchwipsCore", "SchwipsWebCellar"],
            // The fixtures are read through #filePath, not as package resources.
            exclude: ["Fixtures"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
