// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DOpusMac",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DOpusMac",
            path: "Sources/DOpusMac",
            exclude: ["DOpusMacApp.swift"],
            linkerSettings: [
                .linkedFramework("QuickLookUI", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "DOpusMacUITests",
            dependencies: ["DOpusMac"],
            path: "Tests/DOpusMacUITests"
        ),
        .testTarget(
            name: "DOpusMacEndToEndUITests",
            dependencies: [],
            path: "UITests/DOpusMacEndToEndUITests"
        )
    ]
)
