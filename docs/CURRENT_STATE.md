# CURRENT_STATE

文档状态：当前源码摘要；底层品牌脱钩代码与本地 unsigned 验证完成

最近核对：2026-08-19

产品基线：v0.10（build 49）

## 2026-08-19 JetBrains Mono 全局字体

- Councis-owned Latin/English UI roles、纯文本消息、Markdown prose/heading/list/table/link、inline
  code、code block 与 selection surface 已统一为随 `CouncisSharedUI` bundle 分发的 exact
  JetBrains Mono 2.304；既有名义字号与 weight 保留。
- 16 个标准静态 TTF（8 weights + matching italics）直接来自官方 `v2.304` release，逐文件
  SHA-256、OFL、commit 与 release archive identity 已进入 resource/NOTICE/ThirdPartyNotices。
  runtime 从 bundle URL 创建 Core Text descriptor，不依赖用户安装或全局字体注册。
- 简体中文通过 explicit same-weight cascade 继续使用 Apple PingFang SC。字体定向测试已证明
  Latin family 为 `JetBrains Mono`、中文 resolved family 为 `PingFang SC`。
- LaTeX 保持例外：公式继续由 iosMath 的 `MTMathUILabel` 默认数学字体排版，界面字体只影响周围
  Markdown 和公式 point size，不给 math label 设置新 family。
- 当前验证：`CouncisTypographyTests` 4/4、`MessageRenderingTests` 41/41；vendored renderer
  80 XCTest + 11 Swift Testing（91 total）全部通过；`xcodegen generate` 与 unsigned
  `CouncisMac` Debug build 退出 0，最终 App 的 `CouncisSharedUI` resource bundle 已读回全部
  16 TTF、OFL 与 `SHA256SUMS`，抽查 Regular/OFL hash 与仓内一致。
- 首次 full suite 仅暴露 2 条仍检查旧 `.body` / `.callout` 字面值的 presentation source-shape
  断言；迁移为当前 `councisBody` / `councisCallout` 合同后，focused 8/8 通过，随后完整
  `swift test --disable-automatic-resolution --skip-build` 自然退出 0：15 bundles、2,119 tests、
  41 个显式 opt-in skipped、0 failures。
- unsigned universal Release `Councis.app` 构建退出 0，最终 executable 为 `x86_64 arm64`，metadata
  为 `com.Vita0818.Councis` / `0.10 (49)`；最终字体 bundle 的 16 TTF + OFL 全部通过
  `SHA256SUMS`，App 同时包含 JetBrains Mono detailed notice、完整 OFL、Markdown/Math notices。
- Computer Use 只读启动最终 Release App，Cowork empty-state/sidebar/settings 可见 Latin glyph 已呈现
  JetBrains Mono；没有创建 session 或发送 provider 请求。中文 cascade 与公式 family 隔离由 Core Text/
  renderer tests 证明，本轮未完成同屏真实 conversation、VoiceOver 或 clipboard 视觉/交互验收。

## 2026-08-18 v0.10（build 49）版本验证

- `project.yml` 与 shipping App `Info.plist` 已统一为 marketing version `0.10`、递增 build `49`；
  `scripts/check-version-consistency.sh` 与 `scripts/check-brand-boundary.sh` 均通过。
- `xcodegen generate` 成功；unsigned Debug `Councis.app` 构建成功，包内读取结果为
  `CFBundleShortVersionString=0.10`、`CFBundleVersion=49`、Bundle ID
  `com.Vita0818.Councis`。
- unsigned universal Release `Councis.app` 构建成功，最终可执行文件同时包含 `x86_64` 与 `arm64`，
  包内版本仍为 `0.10 (49)`。
- 本轮版本修改未执行 Developer ID 签名、公证或 SwiftPM/XCTest 全量测试；这些仍属于正式发布前验证。

## 来源与仓库边界

- 当前业务能力来自 `/Users/vita/Vitemis/Intatis` 固定干净提交
  `120eda64fcb098f1bdc4852fee886450e80b3722`（标题 `v0.54`，tree
  `7fe2842aeec8fa08bec80e34342f971dc4226dcd`）。产品版本事实源仍是本仓库
  `project.yml` 的 `0.10 (49)`，不是提交标题。固定来源快照自身的 `0.48 (48)` 只属于 provenance。
- Councis 根工作树是唯一活跃实现；没有 `Upstream/Intatis` 或并列实现树，也不回来源仓库改代码。
- 来源、archive digest、复制边界、gitlink 和 provenance 见 `docs/INTATIS_BASELINE.md`。
- 2026-08-15 完成 Councis UI/Cowork-only/fixed-Judge 差异；2026-08-17 用户明确授权完整底层
  product identity 脱钩、删除 iOS 与 legacy Mac App Store 产品面。

## 当前产品身份

- 唯一 Apple App：macOS `Councis`，Developer ID/direct-distribution。
- Xcode project：`Councis.xcodeproj`。
- target/scheme：`CouncisMac`。
- product/executable：`Councis.app` / `Councis`。
- Bundle ID：`com.Vita0818.Councis`。
- canonical icon source/name：`Councis.icon` / `Councis`。
- source root：`Apps/CouncisMac`。
- Mac App Store target/profile/entitlements 已删除；App Sandbox 不再存在于产品图。
- iOS App target/source/resources 已删除；共享库中的条件编译不构成 iOS 产品面。
- CLI target/product/source：`CouncisCLI` / `councis` / `Apps/councis-cli`；不提供新的 `intatis` alias。

## SwiftPM 与模块图

根 SwiftPM package 名为 `Councis`，包含 15 个 public libraries：

```text
CouncisCore
CouncisProtocol
CouncisProviders
CouncisArtifacts
CouncisConversation
CouncisTools
CouncisKnowledge
CouncisSkills
CouncisPermission
CouncisMCP
CouncisMCPStdio
CouncisAgentKernel
CouncisCowork
CouncisMultimodal
CouncisSharedUI
```

内部 C/guard targets 为 `CouncisPTYLauncher`、`CouncisCurlTransport`、
`CouncisMCPStdioGuard`；另有 `CouncisMCPConformanceClient`、`CouncisCLI` 和 15 个
`Councis*Tests` test targets。全部首方路径位于 `Packages/Councis*`。

## 当前产品面

### macOS

- UI 只显示 Cowork history/New 与 Settings，初始 selection 固定 Cowork；Chat/Code/mode navigation
  不渲染。
- Sidebar `+` 与空白 Cowork 启动页的原有 `New` 控件保持原布局，展开且只展开
  `Choose Folder…` / `No Folder` 两项短菜单；不增加说明文案、提示卡或独立页面。前者继续使用原
  folder picker，后者创建 `~/Library/Application Support/Councis/Workspaces/<SessionID>` owner-only
  独立工作区。
- Chat/Code views、runtime、SessionKind、EventLog replay、历史数据与工具实现仍保留；隐藏不等于删除。
- Cowork 继续使用 `Orchestrator`、FIFO scheduler、MessageBus/Mediator、WorkTask/Goal/
  ContinuationRun、per-agent exact inference binding、独立 Permission Reviewer 与 GoalVerifier。
- Code/Cowork 使用共享 headless `AgentRuntime`；工具仍经过 ToolRegistry、CapabilityLease、
  WorkspaceLease、PathConfinement、PermissionEngine 与 durable execution ticket。
- production registry 不暴露 raw `run_shell`；shell-capable host 使用 runtime-owned
  `exec_command` / `write_stdin`，macOS 走 workspace-scoped Seatbelt、默认断网、最小环境和进程清理。
- 文档/媒体、provider-hosted search、browser、Git、Knowledge 与 external MCP client 能力保持原边界。
- Settings 保留 provider/model/MCP/renderer/diagnostic/third-party notices；诊断 ZIP 仍本地、脱敏、
  不上传。

### CLI

- `councis` 提供 Chat/Code/Cowork REPL、managed terminal、Skills、per-agent profiles、Knowledge、
  external MCP client、exact durable execution 与 hang diagnosis。
- canonical 环境变量为 `COUNCIS_*`；help/usage/example 只广告 `councis` 与 Councis config。
- macOS/Linux 的 stdio、Seatbelt/bwrap/guard 和 PTY 仍按 host 能力 fail closed。

## 固定 Judge 与权限控制面

- brand-new empty GUI/CLI Cowork 在任何 provider request 前，以 settings-first 十事件 batch 原子登记
  `@main`、ordinary read-only `@judge` 与 `@permission-reviewer` 的独立 identity/workspace/capability
  lease；三者共享 canonical workspace，但 exact binding 与 lease 独立。
- `judge_model` 与 `permission_reviewer_model` 是高级 config canonical 顶层字段；字段缺失只继承
  同一 JSON 顶层 `model`，显式非法/损坏/未知来源 fail closed，不回退 UI/session/Main/rebind。
- Judge 固定 read-only、depth 0、不可 ordinary attach/spawn/remove/rebind/recycle，不参与 omitted/auto
  delegation，无 coordinator/run-control/permission/Goal authority；Main 只能显式使用它。
- Permission Reviewer 保持 no-tools、独立 FIFO/single-flight/timeout/cancel，不占普通 scheduler 槽；
  GoalVerifier 仍独立冻结首个可解析 Main binding，三者互不替代。
- automatic business schema canonical sidecar 为 `__councis_authorization_context`；旧
  `__intatis_authorization_context` 只作为 reserved legacy 输入识别、剥离并在业务执行前拒绝。
- raw sidecar 与 complete transient args 不进入 EventLog/permission lifecycle；durable history 只保存
  stripped business call。hard deny、missing/malformed/secret-bearing、binding drift、duplicate/recovery
  与 settled-first authorization 边界不变。

## Canonical 数据与配置 identity

- Application Support：`~/Library/Application Support/Councis`。
- User config：`~/.config/councis/councis.json` / `councis.jsonc`。
- auth：`~/.config/councis/auth.json`，兼容 shared path `~/.local/share/councis/auth.json`。
- UserDefaults：`councis.providerCatalog.v1`、`councis.providerSelection.v1`、
  `councis.baseURL`、`councis.model` 和其它 `councis.*` keys。
- config overrides：`COUNCIS_CONFIG` / `COUNCIS_AUTH_FILE`，CLI 使用其它 `COUNCIS_*`。
- workspace metadata：`.councis/browser`、`.councis/git-worktrees`、`.councis/`。
- Knowledge publish：`.councis-rag-store.json`、`.councis-rag-snapshots/`、
  `.councis-rag-host/`、`.councis-rag/`。
- production registry/policy：`councis.standard.v4`、`councis.cowork.v4`、
  `councis.cowork.admission.v1`、`councis.workspace-admission.v1`、
  `councis.deterministic-policy.v1`。
- MCP Keychain service：`com.Vita0818.Councis.mcp.credentials`；CLI MCP encrypted store 使用
  `Councis MCP CLI credential store v1` AAD。
- diagnostics/log/MIME/UTI/provider adapter/schema/digest identities 使用 Councis namespace。

## Legacy bridge 与来源白名单

旧数据不是 release blocker，但当前实现提供受限、非破坏性桥接：

- macOS config/auth discovery 可在 Councis canonical 候选之后只读检查旧 Intatis config/auth；新模板、
  设置保存和 secret 写入仍只落 Councis。
- App provider catalog/selection/base/model 可从当前 defaults domain 或旧
  `com.Vita0818.IntatisMac` persistent domain 的旧 key 迁入当前 Councis key。
- CLI 可读取旧 `INTATIS_*` env（新 `COUNCIS_*` 优先），可在 canonical config root 缺失时在锁内
  非破坏性复制安全 legacy CLI root；旧源不删除。
- CLI MCP store 能验证旧 `Intatis MCP CLI credential store v1` AAD；后续 mutation 以 Councis AAD
  重写 canonical store。
- macOS MCP Keychain canonical service 缺 item 时，可尽力从旧 service 读取并复制到新 service；
  失败不删除旧 item。
- provider adapter `intatis:*` 与 MCP provenance `intatis_user` 可兼容 decode，但新 encode 使用 Councis。
- 旧 config/auth/Knowledge 路径继续同时存在于 PathConfinement、SecretScanner 和 terminal deny floor；
  改名绝不让旧 secret/store 变成可读写普通文件。
- 旧 EventLog、authorization、Knowledge immutable snapshot 和 checksum 不原地改写；无法证明兼容时
  fail closed，而不是把旧 allow 映射成新执行权。

`scripts/check-brand-boundary.sh` 扫描活跃 source/config/script/resource。剩余旧名必须位于
`LegacyIntatisCompatibility`、安全保护、legacy decoder 或专门 fixture 的显式文件白名单；
`docs/INTATIS_BASELINE.md`、NOTICE provenance 与 dated reports 不属于活跃 identity。

## 持久化与安全边界

- EventLog JSONL 仍是 session canonical truth；append-only、跨进程锁、WAL、`seq` 单调、checked
  replay、unknown future event 与 writer lease 合同不变。
- `session.json` 仍是 owner-only schema-v2 可重建 projection；EventLog full fold 永远获胜。
- `workspace-access.plist` 与 `knowledge-access.plist` 继续是 session-owned owner-only binary bookmark
  capability，不进入 EventLog、session.json、UserDefaults 或模型上下文。
- ArtifactStore blob/index/no-follow/owner/single-link/atomic replace 合同不变。
- SecretScanner、Mediator、data-protection Keychain、Hardened Runtime、managed terminal Seatbelt、
  browser native sandbox 与 Linux bwrap/guard 不因产品面删除或品牌改名弱化。
- `PlatformProfile.current = .restricted`；`CouncisMac` 显式选择 `.macDeveloperID`。

## 2026-08-18 fresh Cowork 托管工作区验证

- macOS Sidebar `+` 与空白启动页 `New` 已接为相同的两项菜单；folder-backed 与 app-owned
  workspace 两条路径均完成代码接线，`CouncisMac` Debug unsigned Xcode build 退出 0。
- `SessionStateProtocolTests`、`SessionProjectionStoreTests`、`AutomaticPermissionReviewTests` 与
  `CouncisCoreTests` 合计 119 tests / 0 failures；`CoworkEndToEndTests` 与
  `OrchestrationReliabilityTests` 合计 47 tests / 0 failures。
- 两项 New 菜单修正后，`ThreadLayoutTests` 22 tests 与 `AutomaticPermissionReviewTests` 42 tests
  再次通过，合计 64 tests / 0 failures。
- `xcodegen generate`、品牌门、版本门、Icon Composer JSON 与 `git diff --check` 通过。
- 系统沙箱外的临时 owner directory smoke 证明 `.withSecurityScope` bookmark 可生成、解析回 exact URL，
  且 `stale=false`；没有把临时目录注册为真实 Councis session。
- 未启动真实 GUI 创建用户 session，未执行真实 provider/network、Developer ID 签名或公证；运行态
  folder-picker absence、目录落盘/bookmark readback 与 fresh 十事件 EventLog 仍需人工 smoke 最终确认。

## 2026-08-17 当前验证状态

已完成：

- `swift build --disable-automatic-resolution`：通过；全部 Councis modules/CLI 编译成功，仅有既有 warning。
- 品牌/bridge focused tests：78 tests / 0 failures，包括 ProductIdentity、legacy adapter/source/env、
  sidecar、SDK client-only target surface、Cowork macOS+CLI multi-workspace scenario 与 Core suites。
- `swift test --disable-automatic-resolution`：最终自然退出 0；15 个 test bundles 合计
  2,116 tests executed、41 个显式 opt-in tests skipped、0 failures。首次运行暴露的两条
  incomplete-SSE test fixture 已改为真实 `\n\n` semantic event，生产 retry 逻辑未改。
- vendored SwiftStreamingMarkdown 独立 package tests：79 XCTest + 11 Swift Testing，
  合计 90 / 0 failures。
- `xcodegen generate`：只生成 `Councis.xcodeproj`，唯一 scheme `CouncisMac`。
- `CouncisMac` macOS Debug unsigned build：退出 0；Xcode 只报告既有 warning 与 exit-code-0
  Swift driver 噪声。
- 最终 Debug bundle 读回：`Councis.app`、Bundle ID `com.Vita0818.Councis`、CFBundleName/executable/icon
  `Councis`、版本 `0.48 (48)`、架构 `arm64`。
- `CouncisMac` universal Release unsigned build：退出 0；最终 App supported platform 只有
  `MacOSX`，metadata 为 `Councis` / `com.Vita0818.Councis` / `0.48 (48)`，可执行含
  `x86_64 arm64`，App 资源路径不含旧产品身份。
- Developer ID entitlements 源不含 App Sandbox、保留 audio-input；project 与生成工程均把
  Hardened Runtime 设为 YES。unsigned/adhoc 产物本身不证明正式签名或公证。
- `scripts/check-version-consistency.sh`：通过。
- `scripts/check-brand-boundary.sh`：通过。
- 相关 shell scripts `zsh -n`、Info.plist/entitlements lint、localization JSON parse、Skill validator、
  `git diff --check`：通过。
- `swift build --product councis`、`.build/debug/councis --help` 和离线 `selftest`：通过；只显示/
  写出 Councis CLI/config identity。

未执行（不属于本地 unsigned 脱钩完成证据）：

- Linux CLI 双架构 gate；
- Developer ID 正式签名、公证、staple、Gatekeeper、ZIP/DMG/manifest；
- 真实 provider/credential/network、真实旧 Keychain/session bridge、GUI/VoiceOver/长时性能 smoke。

## 当前风险与限制

- 旧 Application Support session root 没有自动整树复制；旧 session 延续不作为本次 release blocker。
- Bundle ID 变化会让系统把 Councis 视为新 App identity；TCC 麦克风授权需要重新授予，旧
  data-protection Keychain item 也可能因 application identity 无法读取。bridge 是 best effort。
- Knowledge 旧 immutable snapshot 不原地改名；要进入新 Councis layout 应从原 source 重建。
- 完整 SwiftPM suite 历史上偶发 SharedUI async waiter 停滞；本轮没有复现并已自然退出 0，未来
  若再出现仍须记录精确 test，不能用 focused pass 冒充 full pass。
- macOS 27/Xcode 27 仍是 beta toolchain evidence；最低支持系统和真实分发矩阵仍需独立验证。
