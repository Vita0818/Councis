# Councis 底层品牌脱钩实施清单

> 历史记录：本文描述2026-08-17快照时期的品牌脱钩，不是当前共享实现架构。
> 2026-08-28起当前事实见`COUNcis_IDENTITY.md`、`INTATIS_INTEGRATION.md`
> 与manifest；旧`Packages/Councis*`快照已删除。

文档状态：代码脱钩与本地 unsigned 验证完成；真实发行门待独立执行

建立日期：2026-08-17

产品基线：v0.48（build 48）

## 1. 用户确认的最终边界

- 唯一 shipping App 是 macOS `Councis`。
- macOS Bundle ID 固定为 `com.Vita0818.Councis`。
- 不再提供 iOS App 产品：删除 iOS App target、scheme、App source/resources 与其发行/验收入口。
  共享 Swift library 中为源码可移植性保留的条件编译不自动视为 iOS 产品面；除非构建图清理要求，
  本轮不机械删除与 macOS/CLI 共用的实现。
- 删除遗留 Mac App Store target、scheme、App Store entitlements 与只为该 target 存在的编译分支；
  不得因此弱化 Developer ID、Hardened Runtime、PermissionEngine、WorkspaceLease、Seatbelt 或其他
  Councis 自有安全边界。
- 旧 Intatis 安装数据不是 release blocker；允许做尽力而为、可回退、不自动删除旧数据的桥接。
- 所有新建或继续写出的活跃工程、代码、配置、路径、日志、协议、工具、发行物与用户可见身份均须
  使用 Councis。`Intatis` 只允许出现在本清单第 4 节定义的 legacy/provenance 白名单中。
- 不新增 `intatis` CLI alias，不新增 `INTATIS_*` canonical 配置，不以兼容名继续生成新数据。

## 2. Canonical Councis 命名

### 2.1 工程、目录与产品

- [x] SwiftPM package：`Intatis` → `Councis`。
- [x] 15 个 public library products 全部改为 `Councis*`：
  `Core`、`Protocol`、`Providers`、`Artifacts`、`Conversation`、`Tools`、`Knowledge`、`Skills`、
  `Permission`、`MCP`、`MCPStdio`、`AgentKernel`、`Cowork`、`Multimodal`、`SharedUI`。
- [x] 3 个 internal C/guard targets 改为 `CouncisPTYLauncher`、`CouncisCurlTransport`、
  `CouncisMCPStdioGuard`。
- [x] CLI target/product：`IntatisCLI` / `intatis` → `CouncisCLI` / `councis`。
- [x] 开发期 conformance executable：`IntatisMCPConformanceClient` →
  `CouncisMCPConformanceClient`。
- [x] 15 个 SwiftPM test targets 及首方 test suite/type/file 名改为 `Councis*Tests`。
- [x] `Packages/Intatis*` → `Packages/Councis*`。
- [x] `Apps/IntatisMac` → `Apps/CouncisMac`；`Apps/intatis-cli` → `Apps/councis-cli`。
- [x] `Intatis.icon` → `Councis.icon`，主图标资源名改为 `Councis`。
- [x] `Intatis.xcodeproj` → `Councis.xcodeproj`；project/target/scheme 使用 `Councis` / `CouncisMac`。
- [x] macOS App bundle/product/executable 使用 `Councis.app` / `Councis`。
- [x] App bundle identifier 使用 `com.Vita0818.Councis`。
- [x] Developer ID entitlements 文件使用 `Apps/CouncisMac/CouncisMac.DeveloperID.entitlements`。

### 2.2 删除的产品面

- [x] 删除 `IntatisMacAppStore` target/scheme、`IntatisMac.AppStore.entitlements`，以及只为
  `INTATIS_MAC_APP_STORE` 存在的 App composition 分支。
- [x] 删除 `IntatisiOS` target/scheme、`Apps/IntatisiOS/` 与 iOS App 专用设置/本地化资源。
- [x] 从 `project.yml`、版本检查、Makefile、发行脚本、文档与默认验证矩阵移除上述两个产品面。
- [x] 重新确认 macOS Developer ID target 不启用 `com.apple.security.app-sandbox`，仍保留最小
  audio-input entitlement、Hardened Runtime 与现有本地能力安全链。

### 2.3 首方源码身份

- [x] 所有活跃首方 Swift/C symbol、typealias、modifier、launch argument、compile condition、header
  guard、C function、test identity、diagnostic label 与 source filename 从 `Intatis*` / `intatis*` /
  `INTATIS_*` 改为对应 `Councis*` / `councis*` / `COUNCIS_*`。
- [x] model-facing product name、Code/Cowork runtime manifest、Skill catalog delimiter 与 prompt 标识只
  使用 Councis；不改变 `@main`、`@judge`、`@permission-reviewer` 的职责与权限。
- [x] accessibility identifier、OSLog subsystem、renderer/watchdog schema、临时文件前缀与诊断 bundle
  名称使用 Councis。
- [x] MIME/UTI、MCP client version、configuration provenance 与首方 schema title 使用 Councis。

## 3. Canonical 运行时命名空间

### 3.1 配置与本地路径

- [x] Application Support canonical root：`~/Library/Application Support/Councis`。
- [x] 用户配置 canonical root：`~/.config/councis`；主配置文件为 `councis.json` / `councis.jsonc`。
- [x] 兼容 auth canonical root：`~/.config/councis/auth.json`，必要时另支持
  `~/.local/share/councis/auth.json`。
- [x] canonical 环境变量使用 `COUNCIS_CONFIG`、`COUNCIS_AUTH_FILE`、`COUNCIS_API_KEY`、
  `COUNCIS_BASE_URL`、`COUNCIS_MODEL`、`COUNCIS_MODE`、`COUNCIS_REASONING`、
  `COUNCIS_MAX_STEPS`、`COUNCIS_USAGE` 及对应验证/发行变量。
- [x] UserDefaults canonical keys 使用 `councis.*`；旧 `intatis.*` 只作一次性、只读迁移来源。
- [x] workspace metadata 使用 `.councis/browser`、`.councis/git-worktrees` 与 `.councis/`。
- [x] Knowledge 发布布局使用 `.councis-rag-store.json`、`.councis-rag-snapshots/`、
  `.councis-rag-host/` 与 `.councis-rag/`。
- [x] Developer ID 发行恢复根使用 `.councis/release-recovery`。
- [x] 文档 runtime、诊断、hang bundle、临时 LibreOffice/voice/image/process 路径使用 Councis 前缀。

### 3.2 有限 best-effort 旧值桥接纪律

用户已确认旧安装数据完整保留不是 release blocker，因此本轮只实现有限、非破坏性
bridge，不承诺迁移整个旧 Application Support session tree、browser profile 或 Knowledge
snapshot。

- [x] 新写入只写 Councis canonical 路径/key；不得继续向 Intatis namespace 产生新状态。
- [x] canonical 值优先；只有 canonical 缺失时才尝试 legacy 输入。新旧同时存在时使用
  canonical，不合并、不猜测，也不把旧值写回新值之上。
- [x] 正常启动不再提供legacy config/env/UserDefaults、CLI config root或MCP Keychain
  fallback；MCP namespace由最新Intatis host identity派生。旧workspace bookmark只可由
  显式迁移读取。
- [x] 需要真实复制/重封装的显式迁移必须使用现有owner/lock/atomic边界并写入可验证
  durable marker；未授权启动链不得探测或认领旧产品数据。
- [x] 不自动删除旧 Application Support、配置、UserDefaults、Keychain item、CLI store、browser profile
  或 Knowledge snapshot。
- [x] 旧 secret/config 路径永久保留在 SecretScanner、PathConfinement、managed-terminal deny floor 与
  诊断 redaction 中；加入 Councis 新路径时不得移除旧保护。
- [x] 正常启动只读取`COUNCIS_*`；legacy `INTATIS_*`即使存在也不参与配置或
  credential discovery。任何敏感值都不得打印、写入文档或进入EventLog。

## 4. 允许保留 `Intatis` 的白名单

下列内容可以保留旧名称；除此之外，活跃源码/配置/产物不得出现旧身份：

- 历史固定来源证明只保留在Git历史；当前共享来源与revision见`docs/INTATIS_INTEGRATION.md`。
- `NOTICE.md`、`ThirdPartyNotices/`、vendored patch/upstream ledger 中必须真实保留的历史 provenance、
  copyright、旧文件名或固定 upstream/local-adoption 记录。
- Git 历史、dated `codex-report/`、历史事故样本、旧版本验证结果与 byte-exact 第三方标准。
- 明确命名为 `LegacyIntatis*`（或等价清晰 legacy namespace）的只读迁移常量、decoder、旧路径/旧 raw
  value/旧 digest-domain 映射与兼容错误说明。
- 旧 EventLog、UserDefaults、配置、Keychain、CLI encrypted store、Knowledge snapshot 和 workspace
  metadata 的回归 fixture；fixture 必须证明旧值可读，不能成为新 writer 的期望值。
- 旧 Intatis schema/registry/policy/digest identity 的 replay/verification 分支。它们不得被解释为新的
  Councis authorization，也不得扩大旧 capability/lease。
- 历史公开接口兼容测试中必须出现的旧 launch argument、环境变量或文件名。

白名单验收规则：剩余旧名必须能逐项解释为 provenance、legacy read/decode 或 fixture；任何新 writer、
新 target/module、shipping resource、canonical path、CLI help、用户文案或新协议 identity 命中旧名即失败。

## 5. 协议与安全身份迁移

- [x] provider-facing sidecar canonical 字段改为 `__councis_authorization_context`；新 provider schema
  只广告 Councis 字段，宿主仍把旧字段视为保留字段并禁止其进入 business executor。
- [x] 新 tool registry/policy identity 使用版本化 Councis namespace，例如
  `councis.standard.v1`、`councis.cowork.v1`、`councis.cowork.admission.v1`、
  `councis.workspace-admission.v1`、`councis.deterministic-policy.v1`。
- [x] 旧 EventLog/schema 保持原字节可解码；不原地改写 JSONL，也不把旧 registry/policy/allow
  自动映射成 Councis 新执行权。无法证明兼容的旧授权应重新取得。
- [x] MCP Keychain canonical service 使用 `com.Vita0818.Councis.mcp.credentials`；旧 service 只作
  尽力而为的只读迁移来源，迁移失败不删除旧 item。
- [x] CLI MCP encrypted store 使用 Councis authenticated context；旧 store 必须先以旧 context 成功认证，
  再重加密到新文件，禁止仅改文件名或 AAD。
- [x] MCP configuration source、client version、runtime fingerprint 与 catalog/tool-search identity 使用
  Councis；legacy Codable raw values 继续 decode。
- [x] Knowledge profile/schema/domain separator/adapter identity 使用 Councis；旧 immutable snapshot
  不原地改写 checksum-protected 内容，无法以当前 identity 证明时从原 source 重建。
- [x] `EventLog` Envelope/type/seq/WAL/first-write/first-terminal、ArtifactStore 与 session schema 不因品牌
  更名被重写；所有变化必须 additive 或由新 namespace generation 表达。

## 6. App Store/iOS 删除后的平台合同

- [x] macOS Developer ID/direct-distribution 是唯一 Apple App 产品面。
- [x] CLI 继续支持 macOS/Linux；Linux bwrap/guard/PTY fail-closed 边界不变。
- [x] `PlatformProfile.current` 仍须默认最受限；删除 iOS App 不得让忘记设置 profile 的 host 自动获得
  shell/workspace 权限。
- [x] SharedUI/Providers 等库可保留必要的 Apple 条件编译，但文档、target map、release gate 与产品
  声明不得继续把它们描述为 iOS App。
- [x] 删除 App Store profile/target 后，stdio MCP、global Skills、managed terminal、Git、browser 与
  document helper 只由 Developer ID product contract约束，安全机制不得删减。

## 7. 执行批次

### Batch A — 删除旧产品面并完成编译结构更名

- [x] 删除 iOS App 与 legacy Mac App Store target/source artifacts。
- [x] 重命名目录、文件、SwiftPM products/targets/tests、imports、Swift/C symbols。
- [x] 生成 `Councis.xcodeproj`，使 `swift build`、focused tests 与 `CouncisMac` unsigned build恢复通过。

### Batch B — 产品、CLI、脚本与发行身份

- [x] 切换 Bundle ID、App/product/executable、icon、entitlements、Makefile、版本检查、watchdog 与发行脚本。
- [x] CLI/help/install/Linux validation 只使用 `councis`。
- [x] ZIP/DMG/manifest、recovery state、diagnostic/hang bundle 和 OSLog 使用 Councis。

### Batch C — 配置、存储与工作区 namespace

- [x] 切换 Application Support、配置、auth、UserDefaults、workspace browser/worktree、document runtime。
- [x] 增加有限 best-effort、canonical-wins 的 legacy bridge，并同时保护新旧敏感路径。
- [x] 通过 brand compatibility/identity/sidecar/MCP/CLI focused tests 覆盖已实现 bridge；完整旧安装树
  迁移按用户决定不作为本轮验收条件。

### Batch D — durable identity、MCP、权限 sidecar 与 Knowledge

- [x] 切换 canonical registry/policy/digest/schema/MCP/Knowledge identities。
- [x] 保留旧 EventLog/schema/store 的精确 legacy decode/replay，不重写旧 authorization 或 checksum。
- [x] 运行权限、lease、EventLog、MCP、Knowledge、terminal 与恢复 focused suites。

### Batch E — 文档、NOTICE、残留门与完整验证

- [x] 更新根 `AGENTS.md`、README、NOTICE 与当前 docs；历史来源/报告不做虚假重写。
- [x] 增加可维护的品牌边界检查，按第 4 节白名单解释每个剩余旧名。
- [x] 完成第 8 节验证并记录未执行的真实 provider/credential/signing/notarization 项。

## 8. 验收矩阵

- [x] `git diff --check`。
- [x] 品牌边界扫描：活跃 source/target/config/script/resource/new fixture 不再产生 Intatis identity。
- [x] `swift build --disable-automatic-resolution`。
- [x] 受影响 focused tests：Core/Protocol/Providers/Conversation/Tools/Knowledge/Skills/Permission/MCP/
  AgentKernel/Cowork/SharedUI/CLI。
- [x] 完整 `swift test --disable-automatic-resolution`；若既有 SharedUI waiter 再次停滞，记录精确位置，
  单独复跑并不得冒充 full pass。
- [x] `xcodegen generate` 只生成 `Councis.xcodeproj`。
- [x] `scripts/check-version-consistency.sh` 通过。
- [x] `CouncisMac` Debug unsigned build。
- [x] `CouncisMac` universal Release unsigned build，最终可执行含 `arm64 x86_64`。
- [x] 最终 App 读回 `CFBundleIdentifier=com.Vita0818.Councis`、`0.48 (48)`、无 App Sandbox、保留
  audio-input entitlement、Hardened Runtime 配置未弱化。
- [x] `swift build --product councis` 与 CLI help/selftest/focused tests。
- [ ] 环境具备时运行 Linux CLI 双架构 gate；缺环境时明确标记未验证。
- [x] 已实现的 legacy bridge fixtures：config/env、UserDefaults、provider adapter、MCP source/Keychain/AAD、
  sidecar；完整 Application Support/browser/Knowledge 迁移按用户决定不作为 release blocker。
- [x] `zsh -n scripts/package-macos-release.sh` 与不触发真实签名/公证的静态发行门。
- [x] 最终 `git status --short`，区分本任务改动；不执行 add/commit/push/PR。

本轮未运行：Linux 双架构 gate、真实 provider/credential/network、GUI 点击、Developer ID 正式签名、
公证、staple、Gatekeeper 与 DMG 发行。unsigned/adhoc App 只能证明代码、工程图、metadata、架构与
source build settings，不能冒充正式可分发证据。

## 9. 不随本次脱钩改变的架构

- Chat/Code 源码、session 历史兼容与 runtime 继续保留，只维持当前 macOS Cowork-only 可见入口。
- fixed `@judge`、`@permission-reviewer`、GoalVerifier 的职责与 exact binding 边界不变。
- AgentLoop 不递归；协作继续通过 scheduler、mailbox、MessageBus 与 EventLog。
- PermissionEngine 三层门、CapabilityLease、WorkspaceLease、PathConfinement、SecretScanner、Mediator、
  durable tool ticket、managed-terminal Seatbelt/default-network-deny 均不得弱化。
- EventLog append-only、`seq` 单调、WAL、session writer lease、unknown-future-event fail-closed、
  `session.json` 可重建投影、bookmark 独立能力存储和 ArtifactStore 原子性保持不变。
- 本轮不新增或升级第三方依赖，不修改第三方标准 byte-exact 内容，不把 Intatis 来源历史错误改写成
  Councis 原创。
