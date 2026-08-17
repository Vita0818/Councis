// swift-tools-version:5.9
import PackageDescription

// Councis root SwiftPM manifest. Product versioning is owned by project.yml;
// package comments below that mention early v0.x milestones describe when a
// subsystem was introduced, not the current product version. See
// docs/VERSIONING.md.

let package = Package(
    name: "Councis",
    platforms: [
        .macOS("26.0"),
        // Source-portability declaration for shared Apple libraries. Councis
        // ships no iOS App target, scheme, resources, or release artifact.
        .iOS("26.0"),
    ],
    products: [
        .library(name: "CouncisCore", targets: ["CouncisCore"]),
        .library(name: "CouncisProtocol", targets: ["CouncisProtocol"]),
        .library(name: "CouncisProviders", targets: ["CouncisProviders"]),
        .library(name: "CouncisArtifacts", targets: ["CouncisArtifacts"]),
        .library(name: "CouncisConversation", targets: ["CouncisConversation"]),
        .library(name: "CouncisTools", targets: ["CouncisTools"]),
        .library(name: "CouncisKnowledge", targets: ["CouncisKnowledge"]),
        .library(name: "CouncisSkills", targets: ["CouncisSkills"]),
        .library(name: "CouncisPermission", targets: ["CouncisPermission"]),
        .library(name: "CouncisMCP", targets: ["CouncisMCP"]),
        .library(name: "CouncisMCPStdio", targets: ["CouncisMCPStdio"]),
        .library(name: "CouncisAgentKernel", targets: ["CouncisAgentKernel"]),
        .library(name: "CouncisCowork", targets: ["CouncisCowork"]),
        .library(name: "CouncisMultimodal", targets: ["CouncisMultimodal"]),
        .library(name: "CouncisSharedUI", targets: ["CouncisSharedUI"]),
        // The CLI IS a SwiftPM executable (no Xcode needed): `swift run councis chat`.
        .executable(name: "councis", targets: ["CouncisCLI"]),
        // The CouncisMac GUI is an Xcode App target, not an SPM product —
        // SwiftPM cannot build a .app bundle. See project.yml + README.
    ],
    dependencies: [
        // Audited in-tree thin derivative of Microsoft SwiftStreamingMarkdown
        // v0.6.0. Provenance and local patches live beside the vendored source.
        .package(path: "Vendor/SwiftStreamingMarkdown"),
        // Audited client-only derivative of the official Model Context
        // Protocol Swift SDK 0.12.1 at a0ae212e. Its upstream identity,
        // exclusions, licenses, and patch ledger live beside the source.
        .package(path: "Vendor/MCPClientSDK"),
        // Official portable CryptoKit-compatible backend for Linux CLI builds.
        // Exact release provenance and license inventory are recorded in
        // ThirdPartyNotices/SwiftCrypto.md.
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            exact: "4.5.1"
        ),
        // Safe YAML parser for bounded OKF frontmatter in CouncisKnowledge.
        // Exact commit/license provenance is recorded in
        // ThirdPartyNotices/KnowledgeRetrieval.md.
        .package(
            url: "https://github.com/jpsim/Yams.git",
            exact: "6.2.2"
        ),
    ],
    targets: [
        // MARK: Library targets (module == target)
        .target(
            name: "CouncisCore",
            path: "Packages/CouncisCore/Sources"
        ),
        .target(
            name: "CouncisProtocol",
            dependencies: ["CouncisCore"],
            path: "Packages/CouncisProtocol/Sources"
        ),
        .target(
            name: "CouncisProviders",
            dependencies: [
                "CouncisCore", "CouncisProtocol",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisProviders/Sources"
        ),
        .target(
            name: "CouncisArtifacts",
            dependencies: ["CouncisCore", "CouncisProtocol"],
            path: "Packages/CouncisArtifacts/Sources"
        ),
        .target(
            name: "CouncisConversation",
            // ChatLoop drives a ChatProvider, so Conversation depends on
            // Providers while remaining tool-free.
            dependencies: ["CouncisCore", "CouncisProtocol", "CouncisProviders", "CouncisArtifacts"],
            path: "Packages/CouncisConversation/Sources"
        ),
        // v0.2 — Code: tools, deterministic permission gate, single-agent kernel.
        .target(
            name: "CouncisPTYLauncher",
            path: "Packages/CouncisPTYLauncher",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CouncisTools",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisPTYLauncher",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisTools/Sources"
        ),
        // OKF/Profile snapshots, deterministic validation, local embedding,
        // derived indexes, and the snapshot-bound search_knowledge tool.
        // Only the current macOS/CLI compositions link this product.
        .target(
            name: "CouncisKnowledge",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisTools",
                "CouncisProviders", "CouncisPermission",
                .product(name: "Yams", package: "Yams"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisKnowledge",
            exclude: ["Tests"],
            sources: ["Sources"],
            resources: [
                .copy("Resources/Schemas"),
            ]
        ),
        .target(
            name: "CouncisSkills",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisTools",
                "CouncisPermission",
            ],
            path: "Packages/CouncisSkills",
            exclude: ["Tests"],
            sources: ["Sources"],
            resources: [
                .copy("Resources/BundledSkills"),
            ]
        ),
        .target(
            name: "CouncisPermission",
            // Providers added in v0.3 for the model-backed reviewer (layer B).
            dependencies: ["CouncisCore", "CouncisProtocol", "CouncisProviders"],
            path: "Packages/CouncisPermission/Sources"
        ),
        // Production remote MCP HTTP/OAuth requests use libcurl's
        // CURLOPT_RESOLVE socket binding on macOS and Linux. Councis ships no
        // iOS MCP product.
        .target(
            name: "CouncisCurlTransport",
            path: "Packages/CouncisCurlTransport",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("curl"),
            ]
        ),
        // External MCP Server client core, including the client-side handlers
        // for callbacks initiated by a connected server. This target contains
        // no MCP Server implementation or server-facing product seam. It has
        // no dependency on Conversation, Providers, AgentKernel, Cowork, or an
        // app target; those layers inject event/artifact/inference services
        // through narrow interfaces.
        .target(
            name: "CouncisMCP",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisTools",
                .target(
                    name: "CouncisCurlTransport",
                    condition: .when(platforms: [.macOS, .linux])
                ),
                .product(name: "MCP", package: "MCPClientSDK"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisMCP/Sources"
        ),
        // Linux-only kernel execution guard support for local MCP stdio.
        // The C shim is inert on Apple platforms; keeping it separate avoids
        // placing fork/ptrace/seccomp code in the portable client core.
        .target(
            name: "CouncisMCPStdioGuard",
            path: "Packages/CouncisMCPStdio/ExecutionGuard",
            publicHeadersPath: "include"
        ),
        // Local stdio process ownership is a separate linkage boundary from
        // the portable MCP client core.
        .target(
            name: "CouncisMCPStdio",
            dependencies: [
                "CouncisMCP", "CouncisMCPStdioGuard",
                "CouncisCore", "CouncisProtocol", "CouncisTools",
                .product(name: "MCP", package: "MCPClientSDK"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisMCPStdio/Sources"
        ),
        .target(
            name: "CouncisAgentKernel",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisProviders",
                "CouncisTools", "CouncisPermission", "CouncisConversation",
                "CouncisArtifacts", "CouncisMCP", "CouncisSkills",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisAgentKernel/Sources"
        ),
        // v0.3 — Cowork: multi-agent orchestration over a mediated message bus.
        .target(
            name: "CouncisCowork",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisProviders", "CouncisTools",
                "CouncisPermission", "CouncisConversation", "CouncisAgentKernel",
                "CouncisSkills",
            ],
            path: "Packages/CouncisCowork/Sources"
        ),
        // v0.4 — Multimodal: image/video generation + transcription → artifacts.
        .target(
            name: "CouncisMultimodal",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisProviders",
                "CouncisArtifacts", "CouncisConversation",
            ],
            path: "Packages/CouncisMultimodal/Sources"
        ),
        .target(
            name: "CouncisSharedUI",
            // Providers is needed because ChatViewModel drives ProviderRegistry.
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisProviders",
                "CouncisConversation", "CouncisArtifacts",
                .product(
                    name: "SwiftStreamingMarkdown",
                    package: "SwiftStreamingMarkdown",
                    condition: .when(platforms: [.macOS, .iOS])
                ),
            ],
            path: "Packages/CouncisSharedUI/Sources"
        ),
        // v0.6 — CLI: Swift-native `councis` command (chat + code agent), talks to
        // any OpenAI-compatible endpoint via env vars.
        .executableTarget(
            name: "CouncisCLI",
            dependencies: [
                "CouncisCore", "CouncisProtocol", "CouncisProviders", "CouncisConversation",
                "CouncisArtifacts", "CouncisTools", "CouncisPermission", "CouncisAgentKernel", "CouncisCowork",
                "CouncisMCP", "CouncisMCPStdio", "CouncisSkills", "CouncisKnowledge",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Apps/councis-cli/Sources"
        ),
        // Development-only executable exercised by the pinned official MCP
        // client conformance runner. It is not a shipped product and contains
        // no MCP server implementation or server-facing API.
        .executableTarget(
            name: "CouncisMCPConformanceClient",
            dependencies: [
                "CouncisMCP", "CouncisCore", "CouncisProtocol",
                .product(name: "MCP", package: "MCPClientSDK"),
            ],
            path: "Packages/CouncisMCPConformanceClient/Sources"
        ),
        // The CouncisMac app target is defined in the Xcode project generated
        // from project.yml and links these library products.

        // MARK: Test targets (none depend on app targets; SharedUI tests run headlessly on macOS)
        .testTarget(
            name: "CouncisCoreTests",
            dependencies: ["CouncisCore"],
            path: "Packages/CouncisCore/Tests"
        ),
        .testTarget(
            name: "CouncisProtocolTests",
            dependencies: ["CouncisProtocol", "CouncisCore"],
            path: "Packages/CouncisProtocol/Tests"
        ),
        .testTarget(
            name: "CouncisProvidersTests",
            dependencies: ["CouncisProviders", "CouncisCore", "CouncisProtocol"],
            path: "Packages/CouncisProviders/Tests"
        ),
        .testTarget(
            name: "CouncisArtifactsTests",
            dependencies: ["CouncisArtifacts", "CouncisCore"],
            path: "Packages/CouncisArtifacts/Tests"
        ),
        .testTarget(
            name: "CouncisConversationTests",
            dependencies: ["CouncisConversation", "CouncisCore", "CouncisProtocol", "CouncisProviders"],
            path: "Packages/CouncisConversation/Tests"
        ),
        .testTarget(
            name: "CouncisToolsTests",
            dependencies: ["CouncisTools", "CouncisCore"],
            path: "Packages/CouncisTools/Tests"
        ),
        .testTarget(
            name: "CouncisKnowledgeTests",
            dependencies: [
                "CouncisKnowledge", "CouncisCore", "CouncisProtocol",
                "CouncisTools",
            ],
            path: "Packages/CouncisKnowledge/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "CouncisSkillsTests",
            dependencies: [
                "CouncisSkills", "CouncisCore", "CouncisProtocol", "CouncisTools",
            ],
            path: "Packages/CouncisSkills/Tests"
        ),
        .testTarget(
            name: "CouncisPermissionTests",
            dependencies: ["CouncisPermission", "CouncisCore", "CouncisProtocol", "CouncisProviders"],
            path: "Packages/CouncisPermission/Tests"
        ),
        .testTarget(
            name: "CouncisMCPTests",
            dependencies: [
                "CouncisMCP", "CouncisMCPStdio", "CouncisCore",
                "CouncisProtocol", "CouncisTools",
                .product(name: "MCP", package: "MCPClientSDK"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisMCP/Tests"
        ),
        .testTarget(
            name: "CouncisCLITests",
            dependencies: [
                "CouncisCLI", "CouncisAgentKernel",
                "CouncisConversation", "CouncisCore",
                "CouncisMCP", "CouncisProtocol",
            ],
            path: "Apps/councis-cli/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "CouncisAgentKernelTests",
            dependencies: [
                "CouncisAgentKernel", "CouncisCore", "CouncisProtocol", "CouncisProviders",
                "CouncisTools", "CouncisPermission", "CouncisConversation",
                "CouncisArtifacts", "CouncisMCP", "CouncisSkills", "CouncisKnowledge",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/CouncisAgentKernel/Tests"
        ),
        .testTarget(
            name: "CouncisCoworkTests",
            dependencies: [
                "CouncisCowork", "CouncisCore", "CouncisProtocol", "CouncisProviders",
                "CouncisTools", "CouncisPermission", "CouncisConversation", "CouncisAgentKernel",
                "CouncisSkills",
            ],
            path: "Packages/CouncisCowork/Tests"
        ),
        .testTarget(
            name: "CouncisMultimodalTests",
            dependencies: [
                "CouncisMultimodal", "CouncisCore", "CouncisProtocol", "CouncisProviders",
                "CouncisArtifacts", "CouncisConversation",
            ],
            path: "Packages/CouncisMultimodal/Tests"
        ),
        .testTarget(
            name: "CouncisSharedUITests",
            dependencies: ["CouncisSharedUI"],
            path: "Packages/CouncisSharedUI/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
