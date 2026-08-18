# Councis 产品身份与来源边界

文档状态：当前产品身份合同

最近核对：2026-08-18

产品基线：v0.10（build 49）

## 一句话定位

Councis 是 Apple-first、Swift-native 的本地 AI Cowork 产品。它在固定 Intatis source snapshot 的
业务能力基础上拥有独立的工程、模块、App、CLI、配置、存储、日志与协议 canonical identity；
macOS 只呈现 Cowork，但仍保留 Chat/Code runtime 与历史兼容。fresh Cowork 固定登记普通只读
数据面 `@judge`，Main 可按需取得多个候选并显式让 Judge 比较，最终产品与编排责任仍属于 Main。

## 固定来源

业务基线来自 `/Users/vita/Vitemis/Intatis` 的干净提交
`120eda64fcb098f1bdc4852fee886450e80b3722`（标题 `v0.54`，tree
`7fe2842aeec8fa08bec80e34342f971dc4226dcd`）。来源、archive digest、复制边界和排除项见
`docs/INTATIS_BASELINE.md`。

该来源事实必须保留，不能因为产品改名而把派生实现描述成无来源原创。仓库没有
`Upstream/Intatis` 或第二份实现树；所有实现直接修改 Councis 根工作树，不回到来源仓库改代码。

## 当前 Councis canonical identity

- 唯一 Apple App：macOS `Councis`。
- Xcode project：`Councis.xcodeproj`。
- App target/scheme：`CouncisMac`。
- App bundle/product/executable：`Councis.app` / `Councis`。
- Bundle ID：`com.Vita0818.Councis`。
- 分发：Developer ID、Hardened Runtime、公证、直接下载；无 Mac App Store target。
- 无 iOS App target/source/product。
- SwiftPM package：`Councis`。
- public libraries：`CouncisCore`、`CouncisProtocol`、`CouncisProviders`、
  `CouncisArtifacts`、`CouncisConversation`、`CouncisTools`、`CouncisKnowledge`、
  `CouncisSkills`、`CouncisPermission`、`CouncisMCP`、`CouncisMCPStdio`、
  `CouncisAgentKernel`、`CouncisCowork`、`CouncisMultimodal`、`CouncisSharedUI`。
- internal C/guard targets：`CouncisPTYLauncher`、`CouncisCurlTransport`、
  `CouncisMCPStdioGuard`。
- CLI target/product：`CouncisCLI` / `councis`；不提供新的 `intatis` alias。
- source roots：`Apps/CouncisMac`、`Apps/councis-cli`、`Packages/Councis*`、
  `Councis.icon`、`.agents/skills/councis-skill-creator`。
- Application Support：`~/Library/Application Support/Councis`。
- config/auth：`~/.config/councis/councis.json[c]`、`~/.config/councis/auth.json`；
  canonical override 使用 `COUNCIS_*`。
- UserDefaults、workspace metadata、Knowledge、tool registry、permission policy、MCP、diagnostic、
  MIME/UTI 与 sidecar canonical identity 使用 `councis` / `Councis` / `COUNCIS`。
- automatic permission sidecar：`__councis_authorization_context`。
- MCP Keychain service：`com.Vita0818.Councis.mcp.credentials`。

完整逐项清单、legacy 白名单和验证矩阵见 `docs/COUNcis_DECOUPLING_CHECKLIST.md`。

## 产品表面

- macOS 根界面不显示 Chat/Code/Cowork 模式切换；初始 selection 固定为 Cowork，sidebar 只显示
  Councis、Cowork Recent/New 与 Settings。
- Chat/Code view、runtime、session kind、EventLog replay 与历史数据兼容继续保留；隐藏不等于删除。
- CLI 继续提供 Chat/Code/Cowork、managed terminal、Skills、Knowledge 与 external MCP client。
- 项目不再提供 iOS App，也不再维护或验证 Mac App Store target。

## 固定 Judge

- fresh empty Cowork session 在任何模型请求前，以 settings-first 十事件 batch 原子登记 `@main`、
  `@judge` 与 `@permission-reviewer` 各自的 workspace lease、capability lease 和 identity。
- macOS fresh `New` 只提供 `Choose Folder…` 与 `No Folder` 两项：前者使用用户选择的 canonical
  workspace，后者创建 Councis-owned、per-session owner-only canonical workspace。三者共享该
  session canonical workspace，但 identity、lease 与 exact inference binding 独立。
- `judge_model` 是 macOS/modern CLI 高级 JSON/JSONC 的 canonical 顶层字段，不增加 Judge UI。
- 字段缺失只在配置解析层一次性继承同一 JSON 文档的顶层 `model`；显式 null/错误类型/空值、
  unknown/disabled route、损坏配置或不可证明来源均 fail closed，不回退 UI/session/Main/rebind。
- Judge 是 host 管理的 ordinary read-only data-plane agent，`coordinationDepth=0`；不可 ordinary
  attach/spawn/remove/detach/rebind/recycle，不进入 omitted/auto delegation，无 coordinator、
  run-control、Permission Reviewer 或 GoalVerifier authority。
- Main 只能通过既有显式 delegate/message/ask 路径使用 Judge。Judge report 是候选证据；Main 必须
  自己验证、选择、改写/综合、结算 WorkTask 并承担最终决定。
- 既有非空历史 session 不自动补写 Judge；已持久化 Judge 按 ordinary roster 恢复。

## Legacy Intatis 白名单

`Intatis` 不再是活跃 identity。它只可存在于：

- `docs/INTATIS_BASELINE.md`、固定 source commit/tree/archive、真实来源路径和 NOTICE/provenance；
- dated reports、历史事故/验证记录、byte-exact 第三方标准或必须保留的 upstream/local patch ledger；
- `LegacyIntatisCompatibility` 只读路径/key/env/raw value、旧 EventLog/schema/registry/policy decoder；
- 旧 config/auth/UserDefaults/bundle domain、CLI root/AAD、MCP Keychain service、provider adapter、
  permission sidecar 与敏感路径保护；
- 专门证明旧值可读但新 writer 只输出 Councis 的回归 fixture。

任何新的 target/module/type/path、CLI help、用户文案、配置模板、App/发行产物、新 EventLog/registry/
policy/schema identity 或 canonical writer 命中旧品牌都属于失败。`scripts/check-brand-boundary.sh` 对活跃
源码执行显式白名单门。

## 保持不变的安全与运行时边界

- EventLog append-only、`seq` 单调、WAL、session writer lease、checked replay 与 unknown-future-event
  fail-closed 不变；旧 JSONL 不原地改写。
- `session.json` 仍是可删除重建投影；bookmark 仍只进入 session-owned binary plist。
- PermissionEngine 三层门、CapabilityLease、WorkspaceLease、PathConfinement、SecretScanner、Mediator、
  durable execution ticket、managed-terminal Seatbelt/default-network-deny 不得弱化。
- AgentLoop 不同步递归；协作继续经 scheduler、mailbox、MessageBus 与 EventLog。
- `@permission-reviewer` 与 GoalVerifier 继续是彼此独立、无工具的控制面；Judge 不替代它们。
- 不因删除 App Store/iOS 产品面而扩大默认 platform profile；`PlatformProfile.current` 仍为
  `.restricted`，只有显式 `.macDeveloperID` host 获得本地 workspace/shell/MCP 能力。

## 实现纪律

- 新功能只使用 Councis canonical identity；需要读旧值时必须进入清晰的 legacy namespace 和测试。
- legacy bridge 必须只读来源、新写 Councis、canonical 值优先、不自动合并或删除旧数据；旧
  secret/config 路径继续受安全硬拒绝。
- 不从旧 Git 历史机械恢复其它 Councis 差异，不扩大 Judge/UI/authority，不恢复 iOS/App Store 产品面。
- 不把来源证明、第三方版权或 patch provenance 错误批量改成 Councis 原创。
