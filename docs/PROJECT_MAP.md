# PROJECT_MAP

文档状态：当前仓库地图

最近自查日期：2026-08-18

产品基线：v0.10（build 49）

本文以当前 `Package.swift`、`project.yml`、源码、测试和脚本为准。固定来源与旧路径只在
`docs/INTATIS_BASELINE.md` 和 legacy bridge 中说明，不属于活跃工程图。

## 产品与入口

| 产品 | Target / product | 入口 | 平台与边界 |
|---|---|---|---|
| macOS App | `CouncisMac` / `Councis.app` | `Apps/CouncisMac/Sources/CouncisMacApp.swift` | 唯一 Apple App；Developer ID/direct-distribution；Bundle ID `com.Vita0818.Councis`；UI 只显示 Cowork，Chat/Code runtime/history 保留 |
| CLI | `CouncisCLI` / `councis` | `Apps/councis-cli/Sources/CouncisCLI.swift` | macOS/Linux；Chat/Code/Cowork、managed terminal、Knowledge、Skills、external MCP |
| MCP conformance | `CouncisMCPConformanceClient` | `Packages/CouncisMCPConformanceClient/Sources/Main.swift` | 仅开发期 external-client conformance driver，不进入发行 App |

Mac App Store 与 iOS App target/source/scheme 已删除，不属于产品、构建或验证矩阵。

## 目录结构

```text
Councis/
├── .agents/skills/councis-skill-creator/
├── .build/                         # SwiftPM generated, ignored
├── .councis/                       # local runtime/release state, ignored
├── AGENTS.md
├── Apps/
│   ├── CouncisMac/
│   │   ├── Sources/
│   │   ├── Resources/
│   │   ├── Info.plist
│   │   └── CouncisMac.DeveloperID.entitlements
│   ├── SharedResources/            # macOS English + zh-Hans catalog
│   └── councis-cli/
│       ├── Sources/
│       └── Tests/
├── Councis.icon/                   # canonical Apple Icon Composer source
├── Councis.xcodeproj/              # generated, ignored
├── Packages/Councis*/              # first-party Swift/C targets and tests
├── Vendor/
│   ├── SwiftStreamingMarkdown/
│   └── MCPClientSDK/
├── ThirdPartyNotices/
├── ThirdPartyStandards/
├── Tests/
├── docs/
├── scripts/
├── Package.swift
├── Package.resolved
├── project.yml
├── Makefile
└── NOTICE.md
```

旧 `.intatis/` 仍被忽略，且旧 config/auth/Knowledge 路径仍受安全硬拒绝；这只是 legacy 数据保护，
不是活跃产品目录。

## SwiftPM products / targets

### Public libraries（15）

| Target | 主要依赖 | 职责 |
|---|---|---|
| `CouncisCore` | — | typed IDs、`CouncisError`、platform profile、PathConfinement、SessionHistory、workspace bookmark、diagnostic、durable owner-only file、current/legacy product identity |
| `CouncisProtocol` | Core | Event/Envelope/JSONRPC、Goal/WorkTask/ContinuationRun、leases、model history、permission、tool execution、turn outcome/stats 等 additive wire types |
| `CouncisProviders` | Core, Protocol | OpenAI-compatible Chat/Agent/image/transcription/Knowledge providers、adapter/options、catalog/exact binding、hosted search、retry/timeout/no-redirect |
| `CouncisArtifacts` | Core, Protocol | owner-only blob/index store 与 bounded image resolver |
| `CouncisConversation` | Core, Protocol, Providers, Artifacts | EventLog/WAL/checked replay、ChatLoop、projection、session cache、submitted intent、auto title |
| `CouncisTools` | Core, Protocol, PTYLauncher | file/patch/Git/managed terminal、document/media、browser、hosted search、ToolRegistry；不暴露 raw `run_shell` |
| `CouncisKnowledge` | Core, Protocol, Tools, Providers, Permission, Yams | OKF profile/writer/validator、immutable store、embedding/rerank/search、KnowledgeLease、path-aware build/search tools |
| `CouncisSkills` | Core, Protocol, Tools, Permission | bounded Skill discovery/snapshot/catalog/resources、MCP dependency preflight、bundled Cowork orchestration Skill |
| `CouncisPermission` | Core, Protocol, Providers | DeterministicPolicyGate、ModelPermissionReviewer、PermissionEngine、SecretScanner、plain-text verdict |
| `CouncisMCP` | Core, Protocol, Tools, SDK, CurlTransport | external MCP client-only core、catalog/import/HTTP/OAuth/callback/tasks/resources/prompts/completions、secret/output safety |
| `CouncisMCPStdio` | MCP, Core, Protocol, Tools, guard | runtime-owned local MCP stdio process、Seatbelt/bwrap/guard、network gateway、cleanup |
| `CouncisAgentKernel` | Core, Protocol, Providers, Tools, Permission, Conversation, Artifacts, MCP, Skills | shared headless AgentRuntime/AgentLoop、context/model history/compaction、authorization sidecar、provider-bound services |
| `CouncisCowork` | Core, Protocol, Providers, Tools, Permission, Conversation, AgentKernel, Skills | Orchestrator、scheduler、MessageBus/Mediator、agent registry、WorkTask/Goal/run、permission and verifier control planes |
| `CouncisMultimodal` | Core, Protocol, Providers, Artifacts, Conversation | image/video/transcription artifact services |
| `CouncisSharedUI` | Core, Protocol, Providers, Conversation, Artifacts, renderer vendor | cross-platform SwiftUI library；macOS current UI、bounded 16-row history、composer、permission/task/agent presentation |

### Internal targets（3）

| Target | 职责 |
|---|---|
| `CouncisPTYLauncher` | macOS `forkpty` controlling terminal 与 CLOEXEC startup-error channel |
| `CouncisCurlTransport` | MCP Streamable HTTP native libcurl socket-binding boundary |
| `CouncisMCPStdioGuard` | Linux stdio descendant exec/network seccomp/ptrace guard；Apple 平台为空实现 |

### Executables / tests

- `CouncisCLI` → product `councis`。
- `CouncisMCPConformanceClient` → dev-only executable。
- 15 个 tests：`CouncisCoreTests`、`CouncisProtocolTests`、`CouncisProvidersTests`、
  `CouncisArtifactsTests`、`CouncisConversationTests`、`CouncisToolsTests`、
  `CouncisKnowledgeTests`、`CouncisSkillsTests`、`CouncisPermissionTests`、`CouncisMCPTests`、
  `CouncisCLITests`、`CouncisAgentKernelTests`、`CouncisCoworkTests`、
  `CouncisMultimodalTests`、`CouncisSharedUITests`。

## Xcode target

`project.yml` 只声明 `CouncisMac`：

- `type: application`、`platform: macOS`、`productName: Councis`；
- `PRODUCT_BUNDLE_IDENTIFIER: com.Vita0818.Councis`；
- App icon `Councis` 来自根 `Councis.icon`；
- entitlements 为 `Apps/CouncisMac/CouncisMac.DeveloperID.entitlements`；
- Hardened Runtime + audio-input resource access；无 App Sandbox；
- 链接完整 15-product macOS stack（含 Knowledge、MCP 与 MCPStdio）。

唯一 shared scheme 是 `CouncisMac`。SwiftPM package schemes 由
`scripts/hide-xcode-package-schemes.sh` 管理；没有 App Store/iOS scheme。

## 关键运行链路

### Chat

```text
ChatViewModel -> GoalInputParser -> ChatLoop -> exact ProviderRegistry route
  -> EventLog append-only -> ConversationProjection -> SharedUI
```

Chat 无本地 Agent tools；macOS UI 隐藏入口但 runtime/history 保留。

### Code

```text
CodeViewModel -> AgentRuntime.code -> AgentLoop
  -> ContextBuilder + exact provider/tool snapshot
  -> ToolRegistry -> Capability/WorkspaceLease -> PermissionEngine
  -> durable prepare -> executor -> result/settled -> EventLog -> CodeProjection
```

### Cowork

```text
CoworkViewModel -> SubmittedIntentStore -> EventLog acceptance
  -> Orchestrator.runtime + writer lease -> FIFO AgentScheduler
  -> shared AgentRuntime.cowork / AgentLoop
  -> MessageBus + Mediator / WorkTask / Goal / ContinuationRun
  -> independent PermissionReviewControlPlane + GoalVerifierControlPlane
  -> EventLog -> CoworkProjection -> bounded per-agent SharedUI page
```

macOS Sidebar `+` 与空白 Cowork 启动页的既有 `New` 控件共享一个两项菜单：`Choose Folder…` 进入
原 NSOpenPanel workspace admission，`No Folder` 在 inference binding 预检成功后创建
`~/Library/Application Support/Councis/Workspaces/<SessionID>`。后者与 session EventLog、artifacts 和
capability sidecars 分离；两条路径经同一 bookmark/WorkspaceLease/root-identity 链进入下述 bootstrap。

fresh empty session 先原子写十事件：settings、Main/Judge/reviewer 各自 workspace/capability/identity。
Judge 为 fixed ordinary read-only data-plane agent；Permission Reviewer/GoalVerifier 为独立 no-tools control
planes。

### Managed terminal

```text
exec_command/write_stdin -> ToolRegistry/Permission/durable ticket
  -> ProcessTerminalSessionManager -> CouncisPTYLauncher or managed pipes
  -> macOS Seatbelt/default-network-deny -> bounded drain/cleanup
```

### Knowledge

```text
Agent file/document tools -> OKF draft -> build_knowledge
  -> configured embedding + validator + immutable .councis-rag publish
  -> search_knowledge -> configured query embedding + required reranker
  -> bounded evidence + current-turn final revalidation
```

## Canonical local identity

| 类型 | Canonical value |
|---|---|
| Application Support | `~/Library/Application Support/Councis` |
| Fresh Cowork workspace | `~/Library/Application Support/Councis/Workspaces/<SessionID>` |
| Config | `~/.config/councis/councis.json[c]` / `COUNCIS_CONFIG` |
| Auth | `~/.config/councis/auth.json` / `COUNCIS_AUTH_FILE` |
| UserDefaults | `councis.*` |
| Workspace browser | `.councis/browser` |
| Managed worktrees | `.councis/git-worktrees` |
| Knowledge | `.councis-rag-store.json`、`.councis-rag-snapshots/`、`.councis-rag-host/`、`.councis-rag/` |
| Tool registries | `councis.standard.v4` / `councis.cowork.v4` |
| Automatic sidecar | `__councis_authorization_context` |
| MCP Keychain | `com.Vita0818.Councis.mcp.credentials` |
| Release recovery | `.councis/release-recovery` |

旧 Intatis 值只在 `LegacyIntatisCompatibility`、安全保护、legacy decoder 和 fixture 中出现；
`scripts/check-brand-boundary.sh` 是活跃身份 gate。

## 生成物

- SwiftPM：`.build/`，CLI 为 `.build/debug|release/councis`。
- Xcode project：`Councis.xcodeproj`（generated/ignored）。
- App：`Councis.app`，executable `Contents/MacOS/Councis`。
- Release：`Councis-<version>-<build>-macOS-universal.{zip,dmg}` 与 SHA-256 manifest。

## 脚本

| 文件 | 用途 |
|---|---|
| `Makefile` | version/brand/build/test/app/release/install/uninstall 入口 |
| `scripts/check-version-consistency.sh` | 版本、Bundle ID、product 与 generated project 门 |
| `scripts/check-brand-boundary.sh` | 活跃 Councis identity + legacy 文件白名单门 |
| `scripts/hide-xcode-package-schemes.sh` | Xcode scheme visibility |
| `scripts/package-macos-release.sh` | Developer ID App/DMG build/sign/notary/recovery pipeline |
| `scripts/RendererValidationWatchdog.swift` | hash-pinned renderer/session validation watchdog |
| `scripts/validate-linux-cli.sh` | Linux musl 双架构 static CLI gate |

## 当前不确定项

- 真实旧 Application Support/Keychain/CLI store bridge 未以用户数据执行；best-effort 路径不等于保证。
- universal Release unsigned 已验证为 `x86_64 arm64`；Developer ID 正式签名、公证、staple、
  Gatekeeper 与最终 ZIP/DMG 未运行，仍属于独立发行门。
- 最低 macOS、Intel 真机、真实 provider/MCP/OAuth、长时 browser/GUI/VoiceOver/性能矩阵仍需外部环境。
