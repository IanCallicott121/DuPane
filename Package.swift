// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DuPane",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(
            name: "DuPane",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/DuPane",
            exclude: ["DuPaneApp.swift"],
            linkerSettings: [
                .linkedFramework("QuickLookUI", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "DuPaneUITests",
            dependencies: [
                "DuPane",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Tests/DuPaneUITests"
        ),
        .testTarget(
            name: "DuPaneEndToEndUITests",
            dependencies: [],
            path: "UITests/DuPaneEndToEndUITests"
        )
    ]
)
