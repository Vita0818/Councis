// swift-tools-version:5.9
import PackageDescription

// Councis is a first-party product overlay on the single Intatis checkout.
// Agent/runtime/core changes are compiled directly from ../Intatis; this
// package owns only the Councis product hosts, tests, and resources.
let package = Package(
    name: "Councis",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .executable(name: "councis", targets: ["CouncisCLI"]),
    ],
    dependencies: [
        // Canonical shared implementation. The relative path intentionally
        // resolves to /Users/vita/Vitemis/Intatis from this repository.
        .package(path: "../Intatis"),
    ],
    targets: [
        .target(
            name: "CouncisProductSupport",
            path: "Sources/CouncisProductSupport"
        ),
        .executableTarget(
            name: "CouncisCLI",
            dependencies: [
                "CouncisProductSupport",
                .product(name: "IntatisCore", package: "Intatis"),
                .product(name: "IntatisProtocol", package: "Intatis"),
                .product(name: "IntatisProviders", package: "Intatis"),
                .product(name: "IntatisConversation", package: "Intatis"),
                .product(name: "IntatisArtifacts", package: "Intatis"),
                .product(name: "IntatisTools", package: "Intatis"),
                .product(name: "IntatisKnowledge", package: "Intatis"),
                .product(name: "IntatisSkills", package: "Intatis"),
                .product(name: "IntatisPermission", package: "Intatis"),
                .product(name: "IntatisMCP", package: "Intatis"),
                .product(name: "IntatisMCPStdio", package: "Intatis"),
                .product(name: "IntatisAgentKernel", package: "Intatis"),
                .product(name: "IntatisCowork", package: "Intatis"),
                .product(name: "IntatisSharedUI", package: "Intatis"),
                .product(name: "IntatisCodexRuntime", package: "Intatis"),
            ],
            path: "Apps/councis-cli/Sources"
        ),
        .testTarget(
            name: "CouncisCLITests",
            dependencies: [
                "CouncisCLI",
                "CouncisProductSupport",
                .product(name: "IntatisCore", package: "Intatis"),
                .product(name: "IntatisProtocol", package: "Intatis"),
                .product(name: "IntatisProviders", package: "Intatis"),
                .product(name: "IntatisConversation", package: "Intatis"),
                .product(name: "IntatisArtifacts", package: "Intatis"),
                .product(name: "IntatisTools", package: "Intatis"),
                .product(name: "IntatisKnowledge", package: "Intatis"),
                .product(name: "IntatisSkills", package: "Intatis"),
                .product(name: "IntatisPermission", package: "Intatis"),
                .product(name: "IntatisMCP", package: "Intatis"),
                .product(name: "IntatisMCPStdio", package: "Intatis"),
                .product(name: "IntatisAgentKernel", package: "Intatis"),
                .product(name: "IntatisCowork", package: "Intatis"),
                .product(name: "IntatisSharedUI", package: "Intatis"),
                .product(name: "IntatisCodexRuntime", package: "Intatis"),
            ],
            path: "Apps/councis-cli/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "CouncisRuntimeIntegrationTests",
            dependencies: [
                .product(name: "IntatisCore", package: "Intatis"),
                .product(name: "IntatisProtocol", package: "Intatis"),
                .product(name: "IntatisProviders", package: "Intatis"),
                .product(name: "IntatisCodexRuntime", package: "Intatis"),
            ],
            path: "Tests/CouncisRuntimeIntegrationTests"
        ),
    ]
)
