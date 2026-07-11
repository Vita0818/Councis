# PROJECT_MAP

最近自查日期：2026-06-25

本文描述当前仓库结构。判断依据来自 `Package.swift`、`project.yml`、`Makefile`、源码、测试文件和脚本。

## 目录结构总览

```text
Councis/
├── .build/            SwiftPM 构建产物（gitignored）
├── .councis/          Councis 运行时数据
│   ├── presets/       Council preset JSON（committed）
│   └── runs/          运行日志 JSON（gitignored）
├── .git/              Git 仓库（remote: github.com/Vita0818/Councis）
├── .gitattributes     LF 规范化
├── .gitignore         忽略 .build、Intatis.xcodeproj、*.env、.councis/runs、.councis/config.json
├── Apps/              四个 app target
│   ├── CouncisMac/    Mock SwiftUI 壳（不依赖内核）
│   ├── IntatisMac/    全量 macOS app（链接全部 11 个 product）+ entitlements
│   ├── IntatisiOS/    Chat-only iOS app（7-product 子集）
│   └── intatis-cli/   `councis` CLI（真实 council 引擎）
├── ARCHITECTURE.md    Intatis 架构文档逐字副本（标题"Intatis 架构设计"，非 Councis 专属）
├── Makefile           build/test/release/install/app 便利 target
├── NOTICE.md          Clean-room 声明 + 依赖策略
├── Package.swift      SwiftPM manifest（11 lib + councis + CouncisMac + 10 test target）
├── Packages/          11 个库模块（各 Sources/ + Tests/，SharedUI 无 Tests）
├── README.md          Councis readme
├── note.txt           "Councis work mock note"（mock Work 写入内容）
└── project.yml        XcodeGen spec（生成 Intatis.xcodeproj）
```

## Target / 模块

### 库 target（11）— `Packages/<Name>/Sources`

| Target | 类型 | 依赖 | 职责 |
|---|---|---|---|
| `IntatisCore` | lib | — | 类型化 ID、错误、工作区路径约束、平台能力信封、会话类型 |
| `IntatisProtocol` | lib | Core | 结构化事件/线协议词汇（Event/Envelope/JSONRPC/Command/CoworkEvents/MultimodalEvents/TurnStats/JSONValue） |
| `IntatisProviders` | lib | Core, Protocol | OpenAI 兼容模型访问（ProviderRegistry/Capability/Endpoints/ChatProvider/OpenAIWireProvider/OpenAIToolCalling/SSE/HTTPDataClient/ImageGeneration/Transcription/VideoGeneration/ToolCalling） |
| `IntatisArtifacts` | lib | Core, Protocol | 文件-backed blob 存储 + JSON 索引（Artifact/ArtifactStore） |
| `IntatisConversation` | lib | Core, Protocol, Providers, Artifacts | 事件溯源会话 + UI 投影（EventLog JSONL / ChatLoop / Projection / CodeProjection） |
| `IntatisTools` | lib | Core, Protocol | 哑工具执行器（ToolProtocol/FileTools/PatchTool/PathConfinement/ShellGit） |
| `IntatisPermission` | lib | Core, Protocol, Providers | 3 层权限门（PermissionTypes/PermissionEngine/DeterministicPolicyGate/ModelPermissionReviewer/SecretScanner） |
| `IntatisAgentKernel` | lib | Core, Protocol, Providers, Tools, Permission, Conversation, Artifacts | 单 agent 工具循环（Agent/AgentLoop/ContextBuilder/PermissionResponder） |
| `IntatisCowork` | lib | Core, Protocol, Providers, Tools, Permission, Conversation, AgentKernel | 多 agent 编排（Orchestrator/MessageBus/Mediator/AgentRegistry/CoordinatorTools/AskAgentTool） |
| `IntatisMultimodal` | lib | Core, Protocol, Providers, Artifacts, Conversation | 图像/视频/转写 → artifacts（MultimodalService） |
| `IntatisSharedUI` | lib | Core, Protocol, Providers, Conversation, Artifacts | 跨平台 SwiftUI（ChatViewModel/CodeViews/CoworkViews/Views/ArtifactViews）。**无 Tests** |

### 可执行 target（SwiftPM）

| Target | Product | 平台 | 入口 | 依赖 |
|---|---|---|---|---|
| `IntatisCLI` | `councis` | CLI（macOS/Linux） | `Apps/intatis-cli/Sources/IntatisCLI.swift` `@main struct CouncisCLI` | Core, Protocol, Providers, Conversation, Tools, Permission, AgentKernel, Cowork |
| `CouncisMac` | `CouncisMac` | macOS | `Apps/CouncisMac/Sources/CouncisMacApp.swift` `@main struct CouncisMacApp` | **无**（mock 壳） |

### Xcode-only app target（`project.yml`，SwiftPM 无法产 `.app`）

| Target | 类型 | 平台 | Bundle ID | 链接 |
|---|---|---|---|---|
| `CouncisMac` | application | macOS | `com.councis.app` | 无 package 依赖 |
| `IntatisMac` | application | macOS | `com.intatis.app` | 全部 11 个 product |
| `IntatisiOS` | application | iOS | `com.intatis.ios` | 7 个 chat 子集 product（无 Tools/Permission/AgentKernel/Cowork） |

### 测试 target（10）— `Packages/<Mod>/Tests`

`IntatisCoreTests`、`IntatisProtocolTests`（+V02/V03/V04）、`IntatisProvidersTests`（+Multimodal/ToolCalling）、`IntatisArtifactsTests`、`IntatisConversationTests`（+Code）、`IntatisToolsTests`、`IntatisPermissionTests`（+Reviewer）、`IntatisAgentKernelTests`、`IntatisCoworkTests`、`IntatisMultimodalTests`。`IntatisSharedUI` 无测试。`swift test` 无头（无 UI/app target 依赖）。

## 关键文件

- 入口：`Apps/intatis-cli/Sources/IntatisCLI.swift`、`Apps/CouncisMac/Sources/CouncisMacApp.swift`、`Apps/IntatisMac/Sources/IntatisMacApp.swift`、`Apps/IntatisiOS/Sources/IntatisiOSApp.swift`
- Council 引擎（CLI 实际用）：`Apps/intatis-cli/Sources/Council.swift`（`CouncilRunner`）、`Apps/intatis-cli/Sources/WorkCommand.swift`（`runWorkCouncil`）
- Council preset：`.councis/presets/<name>.json`（elite-chat / elite-work / elite / smoke）
- CLI config：`~/.councis/config.json`
- 内核 agent 链路：`Packages/IntatisAgentKernel/Sources/AgentLoop.swift`、`Packages/IntatisCowork/Sources/Orchestrator.swift`
- 权限门：`Packages/IntatisPermission/Sources/PermissionEngine.swift`、`DeterministicPolicyGate.swift`、`ModelPermissionReviewer.swift`
- 事件日志：`Packages/IntatisConversation/Sources/EventLog.swift`
- Provider：`Packages/IntatisProviders/Sources/OpenAIWireProvider.swift`、`ProviderRegistry.swift`

## 生成物 / 产物

- SwiftPM 构建产物：`.build/`（含 `.build/release/councis`）
- Xcode 工程产物：`Intatis.xcodeproj`（xcodegen 生成，gitignored）
- App bundle：`IntatisMac.app` / `IntatisiOS.app` / `CouncisMac.app`（Xcode 构建产物）
- 运行日志：`.councis/runs/run-<timestamp>-<UUID>.json`（gitignored）

## 脚本与工具

| 脚本 | 用途 | 调用方式 |
|---|---|---|
| `Makefile` | build/test/release/install/app/clean 便利 target | `make build` / `make test` / `make app` 等 |
| `project.yml` | XcodeGen 工程规格 | `xcodegen generate`（`make app` 内调用） |

## 不确定项

- `Apps/intatis-cli/Sources/Interactive.swift`（358 行 REPL）疑似死代码：`IntatisCLI.main()` 的 switch 无 case 触达它。需编译确认是否经未搜索到的名称接入。`UNKNOWN` — 需后续确认。
- Councis 与 Intatis 的最终关系未在源码声明：README 称"bootstrapped from the Intatis kernel"、模块名过渡性保留 `Intatis*`，但仓内仍含完整 IntatisMac/iOS app。`UNKNOWN` — 是共存、取代还是回并，需用户确认。
