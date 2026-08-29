// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DuPane",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DuPane",
            path: "Sources/DuPane",
            exclude: ["DuPaneApp.swift"],
            linkerSettings: [
                .linkedFramework("QuickLookUI", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "DuPaneUITests",
            dependencies: ["DuPane"],
            path: "Tests/DuPaneUITests"
        ),
        .testTarget(
            name: "DuPaneEndToEndUITests",
            dependencies: [],
            path: "UITests/DuPaneEndToEndUITests"
        )
    ]
)
