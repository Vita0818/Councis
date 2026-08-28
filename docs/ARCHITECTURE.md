# ARCHITECTURE

文档状态：当前架构规范
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 强制依赖原则

Councis 直接集成 Intatis 官方 SwiftPM products 和 Codex App Server extension。不得复制或重写
Intatis 的 agent loop、tool scheduler、context、approval、native collaboration、MCP、Skills、Knowledge、
document/browser backend、EventLog 或 security core；不得增加 facade、translator、fallback 或平行 runtime。

## 总体结构

```text
                         ../Intatis
          ┌──────────────────────────────────────────┐
          │ IntatisCore / Protocol / Providers       │
          │ Conversation / Artifacts / Tools         │
          │ Permission / MCP / Skills / Knowledge    │
          │ IntatisCodexRuntime                      │
          │ IntatisSharedUI                          │
          └──────────────────┬───────────────────────┘
                             │ direct SwiftPM products
             ┌───────────────┴────────────────┐
             │                                │
      ┌──────▼────────┐                ┌──────▼────────┐
      │ CouncisMac   │                │ councis CLI  │
      │ product host  │                │ product host  │
      └───────────────┘                └───────────────┘
```

Councis 不发布中间 runtime library。App 与 CLI 是两个宿主，直接使用同一 Intatis checkout。
两个进程入口都在任何共享对象构造前安装
`IntatisHostApplication.configure(name: "Councis")`，使host-owned namespace保持
Councis而不改写Intatis implementation/protocol identity。
Code、Cowork与CLI在构造`CodexBusinessToolHost`和
`CodexRuntimeConfiguration`时显式传入同一已安装identity；configuration再冻结
该值，避免一个session内的tool/runtime命名空间漂移。

## Codex Runtime 会话

每个 Code/Cowork session 构造：

```text
Councis session ID + canonical workspace
  -> exact ResponsesRuntimeRoute
  -> session-owned runtimeRootURL/codex-runtime
  -> optional COUNCIS_CODEX_RUNTIME executable override
  -> CodexRuntimeConfiguration
       mode: code | cowork
       dynamicTools
       native MCP configuration
       native Skill extra roots
       host-approved child profiles
       root PermissionProfile
  -> CodexAppServerSession
```

启动时依次验证：

1. runtime root 是安全 owner-only 目录；
2. executable 存在且可执行；
3. version 等于 `0.145.0-intatis.4`；
4. derivation ID 等于共享 Runtime 的 pinned patch identity；
5. persisted thread/toolset/runtime mapping 与当前配置兼容；
6. exact Responses route 可表达且 credential 只进入子进程环境。

任一失败都明确终止启动。没有旧 AgentLoop、另一 executable、另一 provider 或空 thread fallback。

## Code / Cowork turn

```text
UI/CLI Send
  -> startCodexRuntime / current session
  -> runTurn or startTurn + waitForTurn
  -> App Server owns agent loop/context/tool choice
  -> CodexRuntimeEvent stream
       ready
       turnStarted / turnCompleted
       assistantDelta / assistantCompleted
       reasoningDelta
       itemStarted / itemCompleted
       approvalRequested / approvalResolved
       responsesUsage
       goalUpdated
       child events
       runtimeError
  -> EventLog-safe Councis projection
  -> existing thread/rail/composer UI
```

consumer event switches保留 default，允许 Intatis/Codex additive event演进。

## 动态业务工具

第一方业务能力通过 official `thread/start.dynamicTools` 注册：

```text
Codex Runtime ToolCall
  -> CodexRuntimeDynamicToolCall
  -> Intatis CodexBusinessToolHost
  -> exact ToolRegistry registration
  -> WorkspaceLease / CapabilityLease
  -> PermissionEngine
  -> durable tool execution
  -> CodexRuntimeDynamicToolResult
```

App Server拥有调度和tool selection；业务 host拥有schema、authorization、workspace、execution与durable
settlement。失败不得改走旧 Swift AgentLoop、MCP translator、raw shell、Python或另一 backend。

当前工具包括文档、PDF、浏览器、Knowledge、session rename 和 Cowork WorkTask cards。工具 surface随
Intatis checkout更新，Councis 不维护副本。

## Native Cowork

Cowork 使用 Codex native subagent/thread control plane：

- `@main` 是 root thread；
- child agent 是 verified descendant thread；
- roster、状态、history、message、archive 与 restart recovery 由 App Server thread metadata/events提供；
- exact host-approved child profile只携带安全 model/workspace/sandbox/permission facts；模型不能提交raw
  endpoint、credential、request options或任意path；
- WorkTask 只保存独立卡片DAG、revision、result/evidence及可选verified-child关联，不恢复旧scheduler；
- Goal 直接读写 official thread Goal，不启动第二套 continuation runtime；
- native child和root的权限、workspace、Knowledge/MCP能力按host配置隔离。
- Councis 顶层`judge_model`被编译为host-advertised、read-only native child
  profile`judge`；它只能由Main用于候选比较/批评/综合，不拥有coordination、
  run-control、Goal或最终决定权。

## MCP 与 Skills

- root Streamable HTTP MCP authority从Councis session的durable attachment/grant投影到isolated
  `CODEX_HOME` native config；secret只进入process environment。
- child profile/resume默认完整禁用root MCP，不能继承root grant。
- per-child/partial/TTL/stdio/OAuth等无法由当前official extension精确表达的能力保持fail closed。
- repository Skills由Codex cwd discovery；bundled orchestration Skill与user Codex roots使用official Skill
  configuration/extra-roots，不恢复legacy Skill tools。

## 持久化所有权

Councis选择Application Support root，Intatis products实现安全存储：

- `events.jsonl`：session canonical product history；
- `session.json`：可重建投影；
- `workspace-access.plist`：opaque bookmark capability；
- `artifacts/`：blob/index；
- `codex-runtime/`：isolated App Server home/storage/mapping。

不同session和不同项目不得共享可写runtime root。credential、bookmark bytes、完整tool args/output和private
path不得进入不应出现的文本投影。

## 配置与凭据

Councis host解析自己的config/env，再把exact route投影为`ResponsesRuntimeRoute`。runtime不读取ChatGPT
login替代Councis provider credential。secret不进入argv、EventLog、runtime files、diagnostic或文档。

正常启动只发现`COUNCIS_*`、`~/.config/councis`、Councis Application Support和
Councis UserDefaults。`INTATIS_*`及Intatis-owned config/auth/defaults/path即使存在
也不参与precedence；旧数据只有单独、明确授权的迁移流程才可读取。

`COUNCIS_CODEX_RUNTIME`只影响executable location；不能改变pinned version/derivation。显式值非法时fail
closed，不能退回legacy或PATH candidate。

## UI 架构

Councis直接复用`IntatisSharedUI`的结构化thread/composer/rail/renderer，并在App层提供：

- `CouncisTheme` / `CouncisSystemCanvas`；
- Cowork-only navigation；
- Councis文案、Bundle ID、icon和config入口；
- window container background与透明toolbar backing。
- Sidebar `+`与空白Cowork `New`继续只组合`Choose Folder…` / `No Folder`；
  managed workspace仍由Councis host创建。

不为了改内部类型名复制SharedUI。Intatis-prefixed Swift symbols是共享实现身份，不是用户品牌。

## 生命周期

- runtime由process级`AppSessionRuntimeManager`按exact session持有；窗口只持有presentation选择；
-切换/Command-W不stop runtime；
- Delete先drain exact Codex session再删该session state；
- Command-Q关闭admission、并发shutdown全部runtime并有界等待；
- shutdown取消turn、approval、dynamic tools、MCP和child resources后再释放workspace scope；
- restart只resume exact compatible Codex mapping，不恢复旧Swift execution stack。

## 发行

开发期直接编译`../Intatis`，可使用shared runtime kit。正式Councis bundle必须自带active-architecture
exact Codex executable和所需external business runtimes，完成Councis自己的license inventory、bottom-up
Developer ID签名、公证、staple、Gatekeeper与clean-machine验证。源码共享不等于发行制品共享。
