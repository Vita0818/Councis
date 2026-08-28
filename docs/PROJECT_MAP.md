# PROJECT_MAP

文档状态：当前仓库地图
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 两仓边界

```text
/Users/vita/Vitemis/Intatis/
├── Package.swift
├── Packages/IntatisCodexRuntime/
├── Packages/Intatis{Core,Protocol,Providers,...}/
├── Vendor/
├── ThirdPartyNotices/
└── .intatis/runtime-kit/0.66/CodexRuntime/{arm64,x86_64}/codex

/Users/vita/Vitemis/Councis/
├── Apps/CouncisMac/                 Councis App host/resources/identity
├── Apps/councis-cli/                Councis CLI host/tests
├── Apps/SharedResources/              Councis localization catalog
├── Councis.icon/                     Councis App icon
├── Tests/CouncisRuntimeIntegrationTests/
├── Sources/CouncisProductSupport/      canonical identity + explicit-migration-only keys
├── docs/                              下游产品合同
├── scripts/                           Councis build/version/release gates
├── Package.swift                      ../Intatis local dependency + CLI
├── project.yml                        ../Intatis products + CouncisMac
├── NOTICE.md
└── Makefile
```

旧 `Packages/Councis*`、`Vendor/`、`ThirdPartyStandards/` 与旧 root test harness 的
Git-tracked源码/fixture已删除。少量ignored build cache有意保留在原路径，不属于当前模块地图。

## SwiftPM

Councis 的唯一 package dependency：

```swift
.package(path: "../Intatis")
```

本地 product：

| Product | Target | 作用 |
|---|---|---|
| `councis` | `CouncisCLI` | Councis Chat/Code/Cowork CLI host |

本地非runtime support target：`CouncisProductSupport`，只保存Councis canonical
identity与显式legacy workspace迁移所需的最窄只读key；正常启动不读取旧Intatis
config/auth/path/defaults，也不包装任何Intatis API。

下游合同测试 target：`CouncisRuntimeIntegrationTests`。

CLI 直接链接以下 Intatis products：

```text
IntatisCore                 IntatisProtocol
IntatisProviders            IntatisConversation
IntatisArtifacts            IntatisTools
IntatisKnowledge            IntatisSkills
IntatisPermission           IntatisMCP
IntatisMCPStdio             IntatisAgentKernel (compat types only)
IntatisCowork               IntatisSharedUI
IntatisCodexRuntime
```

`IntatisAgentKernel` / `IntatisCowork` 当前仍提供业务 host 所需兼容类型和 WorkTask controller；
生产 agent execution 由 `IntatisCodexRuntime` / Codex App Server拥有，不调用旧 AgentLoop。

## Xcode App

| Target | 平台 | Bundle ID | 依赖 |
|---|---|---|---|
| `CouncisMac` | macOS 26+ | `com.Vita0818.Councis` | `../Intatis` 的完整 macOS products + `IntatisCodexRuntime` |

不存在 iOS 或 Mac App Store target/scheme/entitlements。

App 入口：[CouncisMacApp.swift](../Apps/CouncisMac/Sources/CouncisMacApp.swift)。
CLI 入口：[CouncisCLI.swift](../Apps/councis-cli/Sources/CouncisCLI.swift)。

## App 宿主文件

- `CouncisMacApp.swift`：composition root、session manager、termination drain、Cowork presentation。
- `CodeViewModel.swift`：Code Codex session、event projection、approval、dynamic tools。
- `CoworkViewModel.swift`：Cowork root/children/Goal/WorkTask/native MCP/Skills/runtime projection。
- fresh Cowork把`judge_model`登记为read-only native child profile`judge`。
- `CouncisMacRootView.swift`：Cowork-only navigation、Recent/New/Settings、Councis canvas。
- `CouncisDesign.swift`：系统动态配色与 App-local surface mapping。
- `AppConfig.swift` / `Keychain.swift` / `AppInferenceCatalog.swift`：Councis-owned config discovery、
  secret references和exact Responses route编译。
- `CouncisCodexRuntimeOverride.swift`：`COUNCIS_CODEX_RUNTIME` → public configuration override。
- `MCPProductIntegration.swift` / `MCPProjectSettingsSurfaces.swift`：root native MCP authority projection与UI。
- `SessionRuntimeManager.swift`：exact-session process lifecycle。

## CLI 宿主文件

- `CouncisCLI.swift`：命令分派。
- `CodexRuntimeCLI.swift`：Code/Cowork `CodexAppServerSession` REPL。
- `CLIConfig.swift` / `CLIProviderCatalog.swift` / `CLIInferenceProfiles.swift`：Councis config与Responses route。
- `CouncisCodexRuntimeOverride.swift`：CLI executable override。
- `MCPCLI*`：native root MCP管理面。

## Runtime 数据路径

```text
~/Library/Application Support/Councis/<session>/
├── events.jsonl
├── session.json
├── workspace-access.plist
├── artifacts/
└── codex-runtime/
    ├── home/                  isolated CODEX_HOME
    ├── storage/
    └── mapping/ownership state
```

每个 session 使用独立可写 root。Intatis checkout、Councis session 和其他项目 session 不共享该目录。

fresh `No Folder` workspace位于独立的
`~/Library/Application Support/Councis/Workspaces/<SessionID>`，不等于session
runtime root；删除session不删除workspace内容。

## 生成物与本地状态

- `.build/`、`.swiftpm/`：SwiftPM；
- `Councis.xcodeproj/`：XcodeGen；
- `.councis/`：Councis workspace/release state；
- `dist/`：只有发行门全部通过后的产物。

这些都不是共享源码事实源。
