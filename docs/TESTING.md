# TESTING

## 外部依赖与禁止兜底验证（Vitemis 强制规则）

本项目继承 `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`。涉及外部能力的变更必须验证：

- exact 外部依赖可用时只调用其官方 API/扩展点，不调用第一方重复实现。
- 依赖缺失、版本不兼容或构建/签名/许可证/平台/安全条件不成立时，产生明确、可诊断失败并停止该能力。
- 失败路径不会切换到 legacy、另一 provider/backend、adapter/shim、cache、mock、简化实现或不完整路径。
- 测试 double 只存在于测试 target，不进入 production selection 或 runtime fallback。
- Review 检查新增 wrapper/adapter/facade 是否仅为官方 API 必需的最薄接线；发现核心能力复制、第二实现或静默降级即判定失败。

文档状态：当前可执行验证规范

最近核对：2026-08-19

产品基线：v0.10（build 49）

## 1. 当前产品与验证边界

当前只验证以下 shipping/composition surfaces：

- macOS Developer ID 直分发 App：target/scheme `CouncisMac`，产物
  `Councis.app`，可执行文件 `Councis`，Bundle ID
  `com.Vita0818.Councis`；
- SwiftPM library/runtime/test graph：所有首方 module/target 使用 `Councis*`；
- CLI：target `CouncisCLI`，product/binary `councis`，支持 macOS/Linux；
- 开发期 MCP conformance executable：`CouncisMCPConformanceClient`。

仓库不再包含 iOS App target/source/resources，也不再包含历史
`IntatisMacAppStore` target、App Store scheme/entitlements 或 `.macAppStore`
host profile。它们不是默认构建、测试或 release gate。SwiftPM 为共享库可移植性
保留的 `.iOS` platform declaration、`canImport(UIKit)` 或 availability 分支不构成
iOS 产品。

不做 App Store 产品不允许跳过 Councis 自有安全验证：PermissionEngine、
CapabilityLease、WorkspaceLease、PathConfinement、SecretScanner、durable tool
execution、managed-terminal Seatbelt/default-network-deny、Hardened Runtime、签名与
公证合同均继续有效。

## 2. 环境与工作目录

从仓库根执行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
swift --version
xcodebuild -version
xcodegen --version
```

前两条必须都返回 `/Users/vita/Vitemis/Councis`。不得用清理、reset、checkout
或覆盖方式处理用户已有改动。

## 3. 快速静态门

每次产品身份、工程图、版本或发行脚本变更至少运行：

```sh
scripts/check-brand-boundary.sh
scripts/check-version-consistency.sh
zsh -n scripts/check-brand-boundary.sh
zsh -n scripts/check-version-consistency.sh
zsh -n scripts/hide-xcode-package-schemes.sh
zsh -n scripts/package-macos-release.sh
zsh -n scripts/validate-linux-cli.sh
plutil -lint Apps/CouncisMac/Info.plist
plutil -lint Apps/CouncisMac/CouncisMac.DeveloperID.entitlements
python3 -m json.tool Apps/SharedResources/Localizable.xcstrings >/dev/null
git diff --check
```

品牌边界门必须验证：

- `Package.swift` package/products/targets、`project.yml` project/target/scheme、
  App/CLI/icon 路径均使用 Councis；
- Bundle ID 精确为 `com.Vita0818.Councis`；
- 活跃 source/config/script/resource path 不含旧产品身份；
- 不存在 iOS App 或 Mac App Store target；
- 剩余 `Intatis` 只能位于明确的 source provenance、dated history、legacy
  read/decode bridge 或兼容 fixture 白名单中；
- canonical writer/help/schema/tool/prompt 不得广告旧 namespace。

版本一致性门必须验证 `project.yml`、macOS Info.plist、生成的 Xcode project 与
最终 App metadata 一致为 `0.10 (49)`，并复核产品名与 Bundle ID。

## 4. SwiftPM 构建与全量测试

基础构建：

```sh
swift build --disable-automatic-resolution
swift build --disable-automatic-resolution --product councis
```

全量测试：

```sh
swift test --disable-automatic-resolution
```

完整命令必须自然退出 0 才能记录为 full pass。若已知 SharedUI async waiter
再次静默停滞，应记录最后完成 suite、进程状态和终止方式，再分别运行 focused
suites；focused pass 不能冒充 full pass，且不得留下测试进程继续运行。

## 5. 脱钩与兼容 focused tests

品牌/旧值桥接至少覆盖：

```sh
swift test --disable-automatic-resolution --filter ProductIdentityTests
swift test --disable-automatic-resolution --filter ProductBrandCompatibilityTests
swift test --disable-automatic-resolution --filter AuthorizationSidecarTests
swift test --disable-automatic-resolution --filter SDKClientOnlySurfaceTests
swift test --disable-automatic-resolution --filter HangDiagnosticsCommandTests
swift test --disable-automatic-resolution --filter MessageRendererModeTests
swift test --disable-automatic-resolution --filter ExecutionTracePresentationTests
swift test --disable-automatic-resolution --filter CouncisTypographyTests
swift test --disable-automatic-resolution --filter MessageRenderingTests
```

验收语义：

- canonical 值只写 Councis；canonical 值存在时优先使用，不被 legacy 覆盖；
- legacy env/config/UserDefaults/Keychain/AAD/source raw value 只能作为缺失时的
  best-effort read/migrate 输入，失败不删除旧数据；
- `__councis_authorization_context` 是唯一新 provider-facing sidecar；旧字段即使
  出现也必须在 business executor 前被剥离并 typed reject；
- 旧 provider adapter/MCP source raw value可以 decode，但下一次 canonical encode
  必须输出 Councis identity；
- 旧 EventLog、authorization、lease、snapshot/checksum 不原地改写，也不自动
  映射成新的执行授权。

字体变更还必须证明：16 个 bundled TTF 与 OFL 逐文件 hash 匹配 JetBrains Mono 2.304
inventory；Latin Core Text resolution 为 `JetBrains Mono`，简体中文为 `PingFang SC`；App/SharedUI
源码不残留直接 `.system`/semantic Apple Latin font call；Markdown 可见 prose/code/selection 使用
caller configuration；`InlineMathAttachment` 不给 `MTMathUILabel.font` 赋 interface font，iosMath
公式测试继续通过。最终 `Councis.app` 必须读回 `Councis_CouncisSharedUI.bundle/Contents/Resources/Fonts`
中的 16 TTF、`OFL.txt` 与 `SHA256SUMS`。

用户已确认旧安装数据完整保留不是 release blocker。本轮不要求把整个旧
Application Support session tree 自动复制到新 root；任何已实现 bridge 都必须
是 best-effort、non-destructive、canonical-wins，且不得读取、打印或持久化真实
secret 内容。

## 6. 安全、权限与持久化 focused suites

涉及 namespace、sidecar、配置、terminal 或 durable identity 时，至少运行相关
组合：

```sh
swift test --disable-automatic-resolution --filter PathConfinementTests
swift test --disable-automatic-resolution --filter SecretScanner
swift test --disable-automatic-resolution --filter CapabilityLeaseTests
swift test --disable-automatic-resolution --filter ToolRegistryLeaseTests
swift test --disable-automatic-resolution --filter PermissionReviewProtocolTests
swift test --disable-automatic-resolution --filter CouncisPermissionReviewerTests
swift test --disable-automatic-resolution --filter PermissionReviewControlPlaneTests
swift test --disable-automatic-resolution --filter AutomaticPermissionReviewTests
swift test --disable-automatic-resolution --filter PermissionSettlementTransactionTests
swift test --disable-automatic-resolution --filter TerminalToolsTests
swift test --disable-automatic-resolution --filter TerminalAgentLoopTests
swift test --disable-automatic-resolution --filter WorkspaceSandboxDenialTests
swift test --disable-automatic-resolution --filter EventCompatibilityTests
swift test --disable-automatic-resolution --filter SubmittedIntentStoreTests
```

必须继续证明：

- 新旧敏感 config/auth 路径同时受 PathConfinement、SecretScanner 和 managed
  terminal deny floor 保护；
- automatic permission sidecar 只在同一 acting-model generation 的内存上下文
  使用，raw sidecar/transient exact args 不进入 durable lifecycle；
- EventLog append-only、`seq` 单调、first-write/first-terminal、unknown future event
  fail-closed 与 session writer lease 不因品牌变更而改变；
- managed terminal 不回退 raw `run_shell` 或裸 shell，macOS 仍保持 Seatbelt 与
  default-network-deny，Linux 缺 bwrap/PTY 时 fail closed。

## 7. Cowork / Agent / Provider 回归

核心组合：

```sh
swift test --disable-automatic-resolution --filter ContextProjectionTests
swift test --disable-automatic-resolution --filter CoworkEndToEndTests
swift test --disable-automatic-resolution --filter PerAgentInferenceProfileTests
swift test --disable-automatic-resolution --filter AgentInvocationNonRecursiveTests
swift test --disable-automatic-resolution --filter OrchestrationReliabilityTests
swift test --disable-automatic-resolution --filter MailboxCorrelationTests
swift test --disable-automatic-resolution --filter RunControlTests
swift test --disable-automatic-resolution --filter AgentLoopPolicyTests
swift test --disable-automatic-resolution --filter CLIProviderAdapterTests
swift test --disable-automatic-resolution --filter InferenceCatalogStoreResolverTests
```

这些测试应保持 fixed `@judge`、`@permission-reviewer`、GoalVerifier exact binding、
非递归 AgentLoop、mailbox/scheduler/event flow、CapabilityLease 以及 per-agent
inference binding 语义不变。为了删除 iOS target 而修改的 synthetic 多工作区场景
应使用 macOS App + CLI workspace，而不是重新创建 iOS 产品。

## 8. Knowledge、文档、MCP 与 Skill 回归

按变更范围选择：

```sh
swift test --disable-automatic-resolution --filter CouncisKnowledgeTests
swift test --disable-automatic-resolution --filter KnowledgeModelProviderTests
swift test --disable-automatic-resolution --filter ModelDrivenKnowledgeAgentLoopTests
swift test --disable-automatic-resolution --filter TurnGroundingEvidenceRegistryTests
swift test --disable-automatic-resolution --filter DocumentReadToolSplitTests
swift test --disable-automatic-resolution --filter DocumentToolContractTests
swift test --disable-automatic-resolution --filter DocumentInfrastructureTests
swift test --disable-automatic-resolution --filter DocumentToolsIntegrationTests
swift test --disable-automatic-resolution --filter MCPPreparedConfigurationTests
swift test --disable-automatic-resolution --filter MCPSecretStoreTests
swift test --disable-automatic-resolution --filter CouncisSkillsTests
```

项目内 Skill validator：

```sh
PYTHONDONTWRITEBYTECODE=1 python3 \
  .agents/skills/councis-skill-creator/scripts/quick_validate.py \
  Packages/CouncisSkills/Resources/BundledSkills/cowork-agent-orchestration
```

不得改写 byte-exact 第三方标准。`NOTICE.md`、`ThirdPartyNotices/`、vendored
ledger 必须同时反映 Councis 当前本地路径/修改身份与真实上游 provenance。

## 9. XcodeGen 与 macOS App 构建

生成工程：

```sh
xcodegen generate
```

只能生成 `Councis.xcodeproj`，且 shared scheme 只能指向 `CouncisMac`。Debug
unsigned build：

```sh
xcodebuild -quiet \
  -project Councis.xcodeproj \
  -scheme CouncisMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/councis-brand-derived \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Universal Release unsigned build：

```sh
xcodebuild -quiet \
  -project Councis.xcodeproj \
  -scheme CouncisMac \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/councis-brand-release \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

从最终 App 读回：

```sh
plutil -p /tmp/councis-brand-release/Build/Products/Release/Councis.app/Contents/Info.plist
file /tmp/councis-brand-release/Build/Products/Release/Councis.app/Contents/MacOS/Councis
lipo -archs /tmp/councis-brand-release/Build/Products/Release/Councis.app/Contents/MacOS/Councis
```

必须确认：

- `CFBundleIdentifier = com.Vita0818.Councis`；
- `CFBundleName = Councis`，`CFBundleExecutable = Councis`；
- `CFBundleShortVersionString = 0.10`，`CFBundleVersion = 49`；
- icon 名/文件为 `Councis`；
- Release executable 同时含 `arm64 x86_64`；
- `CouncisMac.DeveloperID.entitlements` 不含
  `com.apple.security.app-sandbox`，保留当前必要的 audio-input entitlement；
- project/target 没有 iOS/App Store product reference。

unsigned build 不能证明 Developer ID identity、Hardened Runtime、notarization 或
Gatekeeper acceptance；这些属于真实发行门。

## 10. CLI 验证

```sh
.build/debug/councis --help
.build/debug/councis selftest
```

help、环境变量说明、诊断、config/auth/MCP store 路径和所有新生成输出只能广告
Councis/councis/`COUNCIS_*`。不提供 `intatis` alias。真实 provider、credential、
network 或 Keychain smoke 必须显式 opt in；默认测试不得读取或打印用户秘密。

Linux gate 仅在对应容器/SDK/依赖环境具备时运行：

```sh
scripts/validate-linux-cli.sh
```

缺少 Linux 环境时应记录“未运行”，不得用 macOS CLI build 冒充 Linux 双架构
验证。

## 11. Developer ID 发行门

发行脚本唯一入口是：

```sh
scripts/package-macos-release.sh
```

日常脱钩验收只运行静态检查和 unsigned build，不触发真实签名、公证、staple 或
DMG 提交。正式发行还必须验证：

- `Developer ID Application` 签名与 timestamp；
- Hardened Runtime；
- nested code、helper、resource/notice inventory；
- universal architectures；
- App 与 DMG 独立 notarization submission ID 的 first-write/reuse 与恢复状态；
- `stapler validate`、`spctl`、最终 manifest/hash；
- `.councis/release-recovery` owner-only、atomic、non-destructive 恢复语义。

真实证书、notary profile、Keychain、网络与 Apple 服务不可用时必须明确标记未验证。

## 12. 手动运行态验收

在签名或合适 Debug App 中至少检查：

- sidebar 只显示 Councis、Cowork Recent/New、Settings；不恢复 Chat/Code 模式行；
- Sidebar `+` 与空白 Cowork 启动页 `New` 只显示 `Choose Folder…` / `No Folder` 两项菜单，且没有
  说明段落或提示卡；前者打开 folder picker 并保持 user-selected workspace 链，后者创建 exact
  `Application Support/Councis/Workspaces/<SessionID>` owner-only 工作区；两者的 settings/bookmark、
  fresh 十事件 bootstrap 与重启恢复保持同一链路；
- 新 session、恢复、rename/delete、窗口关闭、Command-Q drain 合同；
- `@main`、fixed `@judge`、permission reviewer 状态与右侧 rail；
- model/profile 选择、Send 冻结、附件、voice、usage、错误卡；
- managed terminal、Git、browser、文档、MCP、Knowledge 的权限与 workspace 边界；
- Light/Dark、Increase Contrast、Reduce Transparency、键盘导航和 VoiceOver；
- UI、菜单、路径、诊断、导出、About/notice 不出现活跃 Intatis 品牌。

未实际启动 App 或执行真实 provider 时，不能声称运行态/UI/网络验证完成。

## 13. 本轮 2026-08-17 脱钩验证记录

本轮实际结果：

- `swift build --disable-automatic-resolution`：通过；
- 脱钩 focused 组合：78 tests / 0 failures；
- 首次 full test 暴露两个旧测试夹具只提供未终止 SSE fragment、却错误声称已经交付
  semantic delta；改为显式 `\n\n` 完整 event 后，两条 retry-fence tests 通过；生产
  provider retry 代码未改；
- `swift test --disable-automatic-resolution` 最终自然退出 0：15 个 test bundles，
  2,116 tests executed，41 个真实 provider/browser/network 等显式 opt-in tests skipped，
  0 failures；
- `swift test --package-path Vendor/SwiftStreamingMarkdown --disable-automatic-resolution`：
  79 XCTest + 11 Swift Testing tests，合计 90 / 0 failures；
- `xcodegen generate`：通过，只生成 `Councis.xcodeproj`；
- `scripts/check-brand-boundary.sh`：通过；
- `scripts/check-version-consistency.sh`：通过，`0.48 (48)`；
- shell scripts `zsh -n`、Info.plist/entitlements `plutil -lint`、localization JSON parse、
  Skill validator 与 `git diff --check`：通过；
- `CouncisMac` Debug unsigned build：退出 0；最终 Debug App 读回为
  `Councis.app` / `Councis` / `com.Vita0818.Councis` / `0.48 (48)`，架构
  `arm64`；
- `CouncisMac` Release unsigned universal build：退出 0；最终 App 读回
  `CFBundleIdentifier=com.Vita0818.Councis`、`CFBundleName/Executable=Councis`、
  `0.48 (48)`、icon `Councis`、supported platform `MacOSX`，可执行架构为
  `x86_64 arm64`；
- Developer ID entitlements 源只含 audio-input 及显式未放宽的 JIT/library-validation
  flags，不含 App Sandbox；project/generated build settings 的 Hardened Runtime 为 YES；
- `swift build --product councis`、`.build/debug/councis --help` 与离线 `selftest`：
  通过且只广告/写出 canonical Councis identity。

未运行：真实 provider/credential/network、GUI 点击、Developer ID 正式签名、公证、
staple、Gatekeeper、DMG/manifest 发行和 Linux 双架构 gate。最终 Release App 是
unsigned/adhoc 验证产物，不能证明正式签名、公证或 Gatekeeper acceptance。

## 13A. 2026-08-19 全局字体验证记录

- `CouncisTypographyTests`：4/4；覆盖 16-face/OFL exact hash inventory、Latin family、
  PingFang SC 中文 cascade 与 App/SharedUI system-font bypass source audit。
- `MessageRenderingTests`：41/41；覆盖 JetBrains Mono Markdown configuration、Dynamic Type
  scale 与 `.latex` math mode。
- vendored `SwiftStreamingMarkdown` 独立 suite：80 XCTest + 11 Swift Testing，91 total / 0
  failures；新增 source contract 证明可见 code/list/table/selection 辅助 surface 使用 caller font，
  `InlineMathAttachment` 仍不设置 `MTMathUILabel.font`。
- 完整 root suite 首次运行只有 2 条旧 `.body` / `.callout` source-shape 断言失败；断言迁移到
  `councisBody` / `councisCallout` 后 focused 8/8 通过，随后 full
  `swift test --disable-automatic-resolution --skip-build` 自然退出 0：15 bundles、2,119 tests、
  41 skipped、0 failures。
- `xcodegen generate`、unsigned Debug 和 unsigned universal Release `CouncisMac` 构建通过。
  Release metadata 为 `com.Vita0818.Councis` / `0.10 (49)`，executable 为 `x86_64 arm64`。
  最终 `CouncisSharedUI` bundle 含 16 个 TTF、OFL、`SHA256SUMS`，16 TTF + OFL 全部 hash
  check 为 OK；App 另含 detailed notice 与完整 OFL license。
- Computer Use 只读启动最终 Release App，确认 Cowork empty-state 的 App-owned Latin glyph 呈现
  JetBrains Mono；未创建 session、未发送 provider 请求。未执行中文/LaTeX 同屏真实 conversation、
  VoiceOver/clipboard 字体交互、Developer ID 签名、公证、staple、Gatekeeper、DMG、
  Linux gate 或真实 provider/network；这些结论不得从 unsigned bundle 外推。

## 14. Release GO / NO-GO

只有以下条件同时成立才可把本次代码状态记为“脱钩代码验证通过”：

- brand/version/diff 静态门通过；
- SwiftPM build 与 full test 自然退出 0，或已明确记录无法归因于本次变更的既有
  full-suite 阻塞并完成全部受影响 focused suites；
- XcodeGen、Debug App、universal Release App 和 CLI 均通过；
- 最终 App metadata/architectures/entitlements 读回正确；
- 源码/配置/脚本/当前文档不再把 iOS/App Store 描述为 active product；
- 所有剩余旧身份都能解释为 provenance、legacy read/decode 或 fixture；
- 无用户改动被覆盖，无 add/commit/push/PR。

正式可分发 GO 还额外要求真实签名、公证、staple、Gatekeeper、DMG、manifest 和
运行态 smoke；unsigned 本地构建不能替代这些证据。
