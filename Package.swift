// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Inscribe",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        // Main app product
        .library(
            name: "Inscribe",
            targets: ["InscribeApp"]
        ),
        
        // Internal library products for each module
        .library(
            name: "InscribeCore",
            targets: ["InscribeCore"]
        ),
        .library(
            name: "InscribeCanvas",
            targets: ["InscribeCanvas"]
        ),
        .library(
            name: "InscribeRendering",
            targets: ["InscribeRendering"]
        ),
        .library(
            name: "InscribePencil",
            targets: ["InscribePencil"]
        ),
        .library(
            name: "InscribeDocuments",
            targets: ["InscribeDocuments"]
        ),
        .library(
            name: "InscribeStorage",
            targets: ["InscribeStorage"]
        ),
        .library(
            name: "InscribeUI",
            targets: ["InscribeUI"]
        ),
        .library(
            name: "InscribeUtilities",
            targets: ["InscribeUtilities"]
        ),
    ],
    dependencies: [
        // No external dependencies for Phase 1.
        // Future phases may add:
        // .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        // MARK: - App Target
        .target(
            name: "InscribeApp",
            dependencies: [
                "InscribeCore",
                "InscribeCanvas",
                "InscribeRendering",
                "InscribePencil",
                "InscribeDocuments",
                "InscribeStorage",
                "InscribeUI",
                "InscribeUtilities",
            ],
            path: "Inscribe/App"
        ),
        
        // MARK: - Core Module
        .target(
            name: "InscribeCore",
            dependencies: [],
            path: "Inscribe/Core"
        ),
        
        // MARK: - Canvas Module
        .target(
            name: "InscribeCanvas",
            dependencies: [
                "InscribeCore",
                "InscribeRendering",
                "InscribePencil",
            ],
            path: "Inscribe/Canvas"
        ),
        
        // MARK: - Rendering Module
        .target(
            name: "InscribeRendering",
            dependencies: [
                "InscribeCore",
                "InscribePencil",
            ],
            path: "Inscribe/Rendering"
        ),
        
        // MARK: - Pencil Module
        .target(
            name: "InscribePencil",
            dependencies: [
                "InscribeCore",
            ],
            path: "Inscribe/Pencil"
        ),
        
        // MARK: - Documents Module
        .target(
            name: "InscribeDocuments",
            dependencies: [
                "InscribeCore",
                "InscribeStorage",
            ],
            path: "Inscribe/Documents"
        ),

        // MARK: - Storage Module
        .target(
            name: "InscribeStorage",
            dependencies: [
                "InscribeCore",
            ],
            path: "Inscribe/Storage"
        ),

        // MARK: - UI Module
        .target(
            name: "InscribeUI",
            dependencies: [
                "InscribeCore",
                "InscribeCanvas",
                "InscribeDocuments",
            ],
            path: "Inscribe/UI"
        ),

        // MARK: - Extensions Module
        .target(
            name: "InscribeExtensions",
            dependencies: [],
            path: "Inscribe/Extensions"
        ),
        
        // MARK: - Utilities Module
        .target(
            name: "InscribeUtilities",
            dependencies: [],
            path: "Inscribe/Utilities"
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "InscribeCoreTests",
            dependencies: ["InscribeCore"],
            path: "InscribeTests/UnitTests/Core"
        ),
        .testTarget(
            name: "InscribeStorageTests",
            dependencies: ["InscribeStorage"],
            path: "InscribeTests/UnitTests/Storage"
        ),
    ]
)
