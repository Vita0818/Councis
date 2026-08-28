# Councis 产品身份与共享实现边界

文档状态：当前产品身份合同
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 一句话定位

Councis 是 Apple-first、Swift-native 的本地 AI Cowork 产品，也是唯一
`/Users/vita/Vitemis/Intatis` checkout 的第一方下游产品覆盖层。Councis
拥有自己的 App/CLI、品牌、UI composition、配置、数据根、session/workspace
生命周期与发行闭包；共享 agent/runtime/core/tool 实现直接来自 Intatis
SwiftPM products，不再复制或同步源码快照。

## 当前 Councis canonical identity

- 唯一 App：macOS `Councis`。
- Xcode project：`Councis.xcodeproj`。
- App target/scheme：`CouncisMac`。
- App bundle/product/executable：`Councis.app` / `Councis`。
- Bundle ID：`com.Vita0818.Councis`。
- CLI target/product：`CouncisCLI` / `councis`。
- Application Support：`~/Library/Application Support/Councis`。
- config：`~/.config/councis/councis.json[c]` / `COUNCIS_CONFIG`。
- auth：`~/.config/councis/auth.json` / `COUNCIS_AUTH_FILE`。
- UserDefaults 与 product host keys：`councis.*`。
- development Runtime override：`COUNCIS_CODEX_RUNTIME`。
- 分发：Developer ID、Hardened Runtime、公证、直接下载。
- 无 iOS App、无 Mac App Store target、无 App Sandbox 产品分支。

共享 Swift modules、public types、wire identity、Codex Runtime version 与
derivation 使用 `Intatis*` / `intatis` 是实现来源事实，不是 Councis
用户品牌，也不允许为了字符串纯度再复制或包装实现。

App与CLI在构造任何共享storage/provider/runtime前调用
`IntatisHostApplication.configure(name: "Councis")`，使Intatis共享实现中明确
属于embedding host的路径、环境变量、defaults与diagnostic namespace解析为
Councis；固定Swift module/runtime/protocol provenance仍保持Intatis。

## 唯一共享实现

`Package.swift` 与 `project.yml` 都通过 `../Intatis` 指向：

```text
/Users/vita/Vitemis/Intatis
```

当前核对 revision 与工作树形态：

```text
42cb5b36fb6be943ee7812aca3f8520c2e487b04  v0.66 HEAD
同一 checkout 上叠加尚未提交的最新 host-identity/storage 内核改动
```

Councis 本次适配与验证消费的是上述当前工作树字节，而不是仅消费 HEAD commit。
因此源码接线结果可验证，但在 Intatis 把这些字节形成可引用 revision 前，发行级
可复现性仍为 `UNKNOWN`。

Councis 直接链接实际需要的 `IntatisCore`、`IntatisProtocol`、
`IntatisProviders`、Conversation、Artifacts、Tools、Knowledge、Skills、
Permission、MCP、MCPStdio、AgentKernel compatibility types、Cowork、
SharedUI、Multimodal 与 `IntatisCodexRuntime` products。具体 App/CLI 清单见
`Package.swift`、`project.yml` 和 `docs/PROJECT_MAP.md`。

## 运行时身份

- 宿主 API：`CodexRuntimeHostContract.publicAPIMajorVersion == 1`。
- exact executable：`codex-cli 0.145.0-intatis.4`。
- version 与 pinned derivation ID 独立复核。
- 每个 Councis session 使用自己的 `runtimeRootURL`、isolated
  `CODEX_HOME`、workspace、credential 与权限状态。
- Code/Cowork production send、approval、cancel、Goal、child 和 shutdown
  只走 `CodexAppServerSession`。
- 项目/第一方工具只经 official `dynamicTools` extension；不存在旧
  AgentLoop/Orchestrator production fallback。
- 开发期可显式使用 `COUNCIS_CODEX_RUNTIME`；正式 App 必须自带 exact
  current-architecture executable，不依赖 sibling checkout 或 PATH。

## 产品表面

- macOS 只显示 Cowork history/New 与 Settings；Chat/Code 共享实现与 CLI
  命令继续编译，但不成为平行 App 导航。
- Sidebar `+` 与空白 Cowork `New` 继续只显示
  `Choose Folder…` / `No Folder`。
- `No Folder` 创建
  `~/Library/Application Support/Councis/Workspaces/<SessionID>` 的
  owner-only managed workspace；删除 session 不删除 workspace 内容。
- Councis 继续使用系统动态 window canvas、原生 Liquid Glass、JetBrains
  Mono、现有 Cowork rail/composer/thread 布局和 Councis 图标/文案。

## Judge

`judge_model` 仍由 Councis config 解析为 exact base inference binding，显式
非法值 fail closed。fresh Cowork 把它登记为 host-advertised、read-only native
Codex child profile `judge`：

- 只能比较、批评、选择、改写或综合候选；
- sandbox 与 permission profile 均为 read-only；
- 不获得 coordination、run-control、Goal 或最终决定权；
- Main 仍承担事实复核、选择、WorkTask settlement 与最终答复。

共享 Runtime 的 native child thread identity/历史由 Codex App Server拥有；
Councis 不再维护另一套固定 AgentLoop/Judge scheduler。既有旧 Swift runtime
session 若无法 exact 映射到 current Codex thread/toolset，不静默迁移，要求新
session。

与旧产品合同相比仍有一个明确 gap：当前 public Runtime 只能广告 `judge`
profile，不能由 host 在零 provider 请求下预先创建/attach该child。因此fresh UI
在Judge尚未由Main创建前不能证明已有同一可选conversation row。这项strict
功能/UI parity尚未完成；不得用第二Runtime或synthetic thread伪造。

## 旧 Intatis 数据边界

正常 App/CLI 启动不再自动读取：

- `INTATIS_*` 环境变量；
- `~/.config/intatis` 或 `~/.local/share/intatis`；
- `~/Library/Application Support/Intatis`；
- Intatis bundle domain中的provider/model/UserDefaults。

`LegacyIntatisCompatibility` 当前只保留旧 workspace bookmark key，供未来明确
发起、确认归属的迁移路径解码；正常session restore与Cowork启动不调用它。当前
产品没有自动认领旧Intatis配置、凭据或workspace capability的入口。新writer、
App/CLI help、config template、UserDefaults、Application Support、diagnostic和
用户可见文案只使用Councis identity；共享SecretScanner仍由Intatis保留旧敏感
路径的deny floor。

## 已删除的旧快照

2026-08-28 迁移删除了 661 个 Git-tracked snapshot 文件，范围为：

- `Packages/Councis*`；
- `Vendor/`；
- `ThirdPartyStandards/`；
- `Tests/MCPBM25ParityOracle/`；
- `Tests/MCPConformance/`。

ignored build cache 未被递归清理；它们不属于 manifest、active import graph 或
production fallback。共享源码、Vendor、standards、tests、NOTICE 和 runtime
provenance 现在只由 Intatis checkout 维护。

Councis本地只保留dev-only `councis-skill-creator`自身的notice/license；共享依赖
notice不再复制维护，App从Intatis canonical目录打包。
