# DO_NOT_BREAK

文档状态：当前回归禁区
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 共享源码单一事实源

- `Package.swift` 与 `project.yml` 必须继续通过 `../Intatis` 解析唯一 Intatis checkout。
- 不得把 `IntatisCodexRuntime`、`IntatisCore`、`IntatisProtocol`、`IntatisProviders`、
  agent core、tools、MCP、Skills、Knowledge、SharedUI或其Vendor依赖复制回Councis。
- 不得新增Councis runtime wrapper、facade、typealias compatibility module、protocol translator、
  MCP translator、parallel/shadow backend或“临时”旧内核。
- Intatis API/版本/derivation/平台/许可证/签名不满足时必须明确失败，不得静默降级。
- Councis任务默认不得修改、清理、提交或同步Intatis工作树。

## Production runtime

- Code/Cowork production path只能构造`CodexAppServerSession`；不得调用旧`AgentLoop.send`、
  `Orchestrator.runtime`或旧scheduler执行用户turn。
- App Server必须继续拥有agent loop、tool scheduling、context、approval和native subagents。
- dynamic business tools只能通过official `dynamicTools` callback；失败不得改走shell/Python/MCP/旧tool host。
- exact executable必须同时通过version与derivation gate；同版本不同patch identity也拒绝。
- `COUNCIS_CODEX_RUNTIME`显式存在但不可用时不得回退`INTATIS_CODEX_RUNTIME`、PATH或用户安装。
- 每个session必须拥有独立`runtimeRootURL`/isolated `CODEX_HOME`；不同project/session不得共享可写root。
- credential只进入内存和子进程environment，不得进入argv、runtime files、EventLog、日志、文档或UI。
- persisted thread/runtime/toolset不能exact恢复时要求新session；不得创建空thread冒充迁移。

## Cowork

- Agents roster/history/message/archive必须来自verified Codex descendant thread facts，不得从display text、
  task title或assistant正文猜测。
- 模型只能选择host-advertised child profile/workspace preset，不能提交raw endpoint、credential、options或path。
- root grant不得泄漏给child；child MCP默认disabled，Knowledge/workspace/permission按exact profile授予。
- WorkTask是独立UI卡片记录，不得恢复旧scheduler、MessageBus或AgentInvocation ownership传播。
- Goal使用official thread Goal；不得恢复第二GoalRuntime/GoalVerifier continuation backend。
- runtime child/Goal/WorkTask终态不得互相伪造或传播。
- `judge_model`必须exact解析为read-only native child profile`judge`；不得获得
  workspace-write、coordination、run-control、Goal或最终决定authority。
- 在Intatis提供host-side fixed child admission前，不得把“已广告profile”写成
  “fresh session已attach Judge”；也不得以synthetic thread/第二runtime伪造。

## 工具与安全

- concrete tool必须来自同一Intatis ToolRegistry registration，并经过schema、CapabilityLease、
  WorkspaceLease、PathConfinement、PermissionEngine和durable execution。
- hard deny终局；reviewer只能收窄。
- read-only/locked/越界/sensitive path不得因Codex runtime切换而放宽。
- raw shell不得重新出现；managed exec/browser/document/MCP process仍须timeout/cancel/drain与sandbox。
- SecretScanner、Mediator、credential-path deny floor不得删减。
- tool failure只返回真实typed observation/settlement；不得由Councis host伪造成成功或重放未知副作用。

## EventLog 与持久化

- `events.jsonl` append-only，`seq`单调且不可复用；WAL/lock/checked replay不变量继续由共享实现保证。
- `session.json`仍是可重建projection，不能成为第二事实源。
- bookmark bytes只进入owner-only binary `workspace-access.plist`，不得进入EventLog/session.json/UI。
- ArtifactStore blob/index、runtime mapping与toolset identity必须保持owner-only/no-follow/atomic语义。
- App/CLI必须把root选为Councis Application Support；不得把session状态写进Intatis checkout。

## 产品身份

- 用户可见名称、App、CLI、Bundle ID、Application Support、config/env/UserDefaults必须保持Councis。
- 内部`Intatis*` module/type/runtime/wire名称是直接依赖事实，不得为字符串纯度复制或包装。
- App/CLI必须在任何共享storage/provider/runtime对象前调用
  `IntatisHostApplication.configure(name: "Councis")`；不得依赖默认Intatis host identity。
- `CodexBusinessToolHost`与`CodexRuntimeConfiguration`必须冻结同一Councis identity；
  不得让一个session的tool/runtime surface落入不同产品namespace。
- canonical config存在但非法时fail closed；不能回退另一产品配置。
- 正常启动不得读取`INTATIS_*`、`.config/intatis`、`.local/share/intatis`、
  `Application Support/Intatis`或Intatis bundle-domain defaults。旧Intatis数据只有
  单独、用户明确触发且可证明归属的迁移流程才可只读访问。
- 不读取或输出真实API key、auth JSON、`.env*`、Keychain、私钥、证书、cookie或session。

## UI

- 唯一macOS App入口仍是Cowork；不得恢复Chat/Code平行导航。
- 保持系统动态 window canvas、无色 Liquid Glass、Councis 图标和当前 Cowork-only composition；不得写死暖色、浅色或深色背景。
- 用户消息是唯一普通气泡；assistant/agent/system正文直接位于canvas；permission/task/error保留结构化surface。
- 不把Intatis用户可见品牌、Logo、图标或文案带入Councis。
- 不复制SharedUI/renderer以改内部类型名；产品差异应停在App theme/strings/composition boundary。
- Sidebar `+`与空白Cowork `New`必须继续只显示`Choose Folder…` / `No Folder`；
  后者必须创建session-owned managed workspace且删除session不删除workspace内容。

## App 生命周期

- session runtime由process manager按exact key持有；切换mode/session、Command-W或关闭最后窗口不得隐式stop。
-删除session先drain该Codex runtime；不得影响其他session或linked workspace内容。
-Command-Q先关闭admission，再并发shutdown并有界等待；timeout不能伪造settled。
-cancel/stop必须先drainprovider/tool/dynamic-tool/MCP/child resources，再发布terminal并恢复caller。

## macOS 分发

- 唯一App target是`CouncisMac`，Bundle ID `com.Vita0818.Councis`。
- 不得恢复iOS、Mac App Store、App Sandbox target/entitlements/scheme。
- shipping bundle必须包含active-architecture exact Codex runtime，并由Councis完成license closure、
  Developer ID签名、公证、staple与Gatekeeper。
- `../Intatis`、`.intatis/runtime-kit`、`~/.local/bin`和Homebrew只可用于开发，不是发行fallback。

## Git 与删除

- 未经用户明确要求，不add/commit/push/PR/stash。
- 禁止reset-hard、clean、checkout/restore丢弃、history rewrite和force push。
- 不删除用户改动或Intatis工作树文件。
- 删除旧复制目录前必须先证明它们退出manifest/project/import graph，并列出精确目录；若安全门要求，取得额外明文批准。

## 必须验证

- package dependency只指向`../Intatis`；
- `CodexRuntimeHostContract.publicAPIMajorVersion == 1`；
- CLI与App构建编译`IntatisCodexRuntime`；
- production source包含Codex session接线且无旧runtime fallback；
- Cowork-only导航、Councisconfig/state root和bundle identity保持；
- focused/full tests、XcodeGen、Debug/Release按任务风险执行；
- `git diff --check`与`git status --short`。
