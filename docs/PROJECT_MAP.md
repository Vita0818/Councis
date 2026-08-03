# PROJECT_MAP

最近自查日期：2026-07-26

本文依据当前 `Package.swift`、`project.yml`、`Makefile`、源码和测试布局描述仓库。

## 目录结构

```text
Councis/
├── .councis/
│   ├── presets/                 team preset v2（committed、无凭据）
│   └── runs/                    旧 Council JSON（gitignored、只读兼容）
├── Apps/
│   ├── intatis-cli/Sources/     `councis` CLI
│   ├── CouncisMac/Sources/      CouncisMac @main；复用 IntatisMac workbench
│   ├── IntatisMac/
│   │   ├── Sources/             共享 macOS Chat/Code/Cowork workbench
│   │   ├── TeamSupport/         可无头测试的 strict team 配置模块
│   │   └── TeamSupportTests/
│   └── IntatisiOS/Sources/      tool-free iOS chat 子集
├── Packages/                    11 个共享 Intatis* 内核/UI 模块
├── Upstream/
│   ├── AGENTS.md                快照只读边界
│   └── Intatis/                 2026-07-26 固定来源快照
├── codex-report/                用户要求的实现/审计报告
├── docs/                        Councis 当前权威项目文档
├── Package.swift                SwiftPM manifest
├── project.yml                 XcodeGen spec → Councis.xcodeproj
├── Makefile                    build/test/release/app 便利命令
├── README.md
└── NOTICE.md
```

根目录 `ARCHITECTURE.md` 是 Intatis 来源时代的背景文档，不是 Councis 当前包装策略的权威说明。

面向 AI Agent 的 CLI Team Preset 编写、存放、秘密隔离和验证流程见
`docs/TEAM_PRESETS.md`。该文档不适用于 CouncisMac 的自动 team 派生。

## SwiftPM library targets

### 共享 `Packages/` 模块（11）

| Target | 主要职责 |
|---|---|
| `IntatisCore` | Typed IDs、`AgentModelBinding`、错误、路径和平台 profile |
| `IntatisProtocol` | Event/Envelope、TaskGraph 契约、lease、permission/task review、tool execution 协议 |
| `IntatisProviders` | provider registry、完整 binding 路由、OpenAI-compatible HTTP/SSE、tool/multimodal wire |
| `IntatisArtifacts` | blob + `index.json` artifact 存储 |
| `IntatisConversation` | EventLog、ChatLoop、Code/Cowork/permission/tool projections |
| `IntatisTools` | 文件、patch、shell/Git、browser、document/media tool definitions |
| `IntatisPermission` | deterministic gate、model reviewer、permission engine、secret scanner |
| `IntatisAgentKernel` | Agent、AgentLoop、context projection、execution budget、tool dispatch |
| `IntatisCowork` | Orchestrator、TaskGraph/Scheduler、MessageBus/Mediator、model assignment、surface profile、Judge |
| `IntatisMultimodal` | image/video/transcription 到 artifacts |
| `IntatisSharedUI` | 跨平台 SwiftUI views/view models；无独立 test target |

### App-side support module（1）

| Target | 路径 | 职责 |
|---|---|---|
| `IntatisMacTeamSupport` | `Apps/IntatisMac/TeamSupport` | 从 provider catalog 派生/验证 Councis main、judge 和 worker pool，生成 strict `ModelAssignmentPolicy` |

## Executable 和 app targets

| Target / Product | 构建系统 | 入口与行为 |
|---|---|---|
| `IntatisCLI` / `councis` | SwiftPM + XcodeGen tool | `Apps/intatis-cli/Sources/IntatisCLI.swift`; Chat/Work 均走 Cowork runtime |
| `CouncisMac` | SwiftPM executable + Xcode app | `CouncisMacApp.swift`; 编译 `Apps/CouncisMac/Sources` + `Apps/IntatisMac/Sources`，定义 `COUNCIS_APP`，仅 strict Cowork |
| `IntatisMac` | Xcode app | `IntatisMacApp.swift`; 全量 Chat/Code/legacy Cowork，链接 11 共享模块 + TeamSupport |
| `IntatisiOS` | Xcode app | `IntatisiOSApp.swift`; 只链接 Core/Protocol/Providers/Conversation/Artifacts/Multimodal/SharedUI |

Bundle ID：`CouncisMac` 为 `com.Vita0818.CouncisMac`，`councis` 工具为 `com.Vita0818.Councis`，兼容 Target `IntatisMac` / `IntatisiOS` 分别为 `com.Vita0818.IntatisMac` / `com.Vita0818.Intatis`。

`CouncisMac` 与 `IntatisMac` 共享 workbench 源码，但由 `AppIdentity` 分离显示名、defaults、Application Support、配置和 auth 路径。CouncisMac 的导航只暴露 Cowork；IntatisMac 的产品表面保持不变。

## CLI 关键文件

- `IntatisCLI.swift`：命令分派；`chat` / `work` / aliases、`settings`、`config`、`runs`、`selftest`。
- `Interactive.swift`：实际 `runMode` / team REPL / one-shot root submission；构造 strict Orchestrator、attach `@main` / `@judge`、要求 Judge healthy，并在 `/team` 显示 lifecycle health。
- `TeamPreset.swift`：team schema v2、旧 candidates schema adapter、完整 binding 校验和 runtime model policy。
- `CLIConfig.swift`：多 provider endpoint/credential 解析，`COUNCIS_*` 优先并保留 `INTATIS_*` 迁移 fallback。
- `LegacyCouncilRun.swift`：旧 `.councis/runs/*.json` 的只读摘要 reader。
- `SelfTest.swift`：离线 provider、工具、preset/legacy decode、launch parser、durable root + Judge smoke。

已删除的 `Council.swift`、`WorkCommand.swift` 和 `ChatCommand.swift` 不是待恢复文件。

## Cowork 关键文件

- `Packages/IntatisCore/Sources/AgentModelBinding.swift`
- `Packages/IntatisAgentKernel/Sources/Agent.swift`
- `Packages/IntatisProviders/Sources/ProviderRegistry.swift`
- `Packages/IntatisCowork/Sources/Orchestrator.swift`
- `Packages/IntatisCowork/Sources/TaskReviewerLifecycle.swift`
- `Packages/IntatisCowork/Sources/ModelAssignmentPolicy.swift`
- `Packages/IntatisCowork/Sources/CoworkSurfaceProfile.swift`
- `Packages/IntatisCowork/Sources/MessageBus.swift` / `Mediator.swift`
- `Packages/IntatisProtocol/Sources/TaskReview.swift`
- `Packages/IntatisConversation/Sources/CoworkProjection.swift`
- `Packages/IntatisConversation/Sources/ReviewedTaskPresentation.swift`
- `Apps/IntatisMac/Sources/CoworkViewModel.swift`
- `Apps/IntatisMac/Sources/CoworkProjectSettings.swift`
- `Apps/IntatisMac/TeamSupport/CoworkTeamConfiguration.swift`

## Test layout

`Package.swift` 定义 11 个无头 XCTest target：

1. `IntatisCoreTests`
2. `IntatisProtocolTests`
3. `IntatisProvidersTests`
4. `IntatisArtifactsTests`
5. `IntatisConversationTests`
6. `IntatisToolsTests`
7. `IntatisPermissionTests`
8. `IntatisAgentKernelTests`
9. `IntatisCoworkTests`
10. `IntatisMultimodalTests`
11. `IntatisMacTeamSupportTests`

Councis 新策略的重点 suites 包括 `ModelAssignmentPolicyTests`、`StrictModelAssignmentIntegrationTests`、`SpawnAgentToolModelBindingTests`、`CoworkSurfaceProfileTests`、`TaskReviewGateTests`、`JudgeLifecycleTests`、`ReviewedTaskPresentationTests`、`EventCompatibilityTests` 和 `CoworkTeamConfigurationTests`。`JudgeLifecycleTests` 覆盖 fixed-identity health、restart orphan reconciliation、timeout/cancel quarantine、queue-inclusive deadline 和 shutdown late-approval barrier。

## 产物与持久化

- `.build/`：SwiftPM 产物；release CLI 为 `.build/release/councis`。
- `Councis.xcodeproj`：由 `xcodegen generate` 从 `project.yml` 生成。
- `.app`：CouncisMac / IntatisMac / IntatisiOS 的 Xcode 构建产物。
- 当前 CLI event logs：`~/Library/Application Support/Councis/cli/sessions/<mode_uuid>/events.jsonl`。
- GUI sessions：按 `AppIdentity` 分别位于 Councis 或 Intatis 的 Application Support 根下。
- `.councis/runs/*.json`：旧 Council run，只读兼容，不是当前 runtime 输出。
- `Upstream/Intatis`：来源快照，不是 build target、dependency checkout 或 nested Git repository。

## 构建入口

| 命令 | 用途 |
|---|---|
| `swift build` / `make build` | 全部 SwiftPM products debug build |
| `swift build --product councis` | CLI 定向构建 |
| `swift build --product CouncisMac` | 共享 Mac wrapper 的 SwiftPM 定向构建 |
| `swift test` / `make test` | 11 个无头 test targets |
| `swift build -c release` / `make release` | release CLI |
| `xcodegen generate` | 生成 `Councis.xcodeproj` |
| `make app` | 生成并打开 `Councis.xcodeproj` |
