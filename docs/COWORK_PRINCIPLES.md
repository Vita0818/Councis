# COWORK_PRINCIPLES

文档状态：当前 Codex-native Cowork 原则
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 核心原则

```text
Codex App Server owns the agent loop, context, approvals, and collaboration.
Intatis owns the shared runtime and business-tool implementation.
Councis owns the product host, branding, workspace selection, and UI.
No copied runtime. No fallback runtime. No protocol translation layer.
```

旧 Councis/Intatis Swift `AgentLoop + Orchestrator + AgentScheduler + MessageBus` 架构只保留在
Intatis 的历史/兼容源码中，不是 Councis production Cowork backend。

## Root 与 child

- `@main` 是 `CodexAppServerSession` root thread。
- child agent 是 App Server verified descendant thread，不是 Councis 自建 AgentInvocation。
- thread ID 是join key；不得从displayName、agent role文案、WorkTask title或assistant正文推断identity。
- child roster/history/message/archive/recovery使用同一runtime的public thread APIs和events。
- host只广告明确配置的child profile；省略profile时使用Codex official inheritance，不能由Councis猜model。
- profile包含exact Responses route、workspace preset、sandbox与permission profile；secret不写入role文件。
- `judge_model`只形成read-only native child profile`judge`；不得改成另一个
  Councis scheduler、预请求provider bootstrap或拥有最终决定权的控制面。

## 调度与递归

- 模型使用Codex native collaboration tools创建和协调child。
- Councis不得再运行自己的agent scheduler或递归调用另一个AgentLoop。
- native child tool调用继承同root `dynamicTools` extension，但host在callback时按verified child重新收窄
  workspace、permission与Knowledge capability。
- 无法证明child identity/workspace/profile时，business tool在permission前fail closed。
- 不增加Councis `spawn_agent`/`delegate_task` facade去翻译Codex control plane。

## WorkTask

WorkTask只保留用户可见计划卡片：

- stable ID、revision、DAG、status、result/evidence；
- 可选链接到verified Codex child；
- schema/permission/durable EventLog由共享`CodexWorkTaskController`处理；
- 不拥有thread、turn、Goal或agent；
- child/turn完成不自动完成WorkTask，WorkTask完成也不终止thread/Goal；
- 不恢复旧TaskGraph、scheduler、mailbox或retry backend。

## Goal

- `/goal`与Goal UI直接使用official Codex thread Goal。
- Goal状态、budget与恢复来自runtime snapshot/event。
- App cold start可先pause active Goal再resume thread，避免无用户动作自动续跑。
- 不运行第二套GoalRuntimeController、ContinuationRun loop或GoalVerifier backend。
- Goal、WorkTask和thread终态互不伪造。

## Context 与 history

- Codex Runtime拥有model history和context management。
- Councis EventLog只保存安全产品projection/tool audit，不重建或替换Codex prompt history。
- child history通过official thread history读取，不扫描root EventLog猜对话。
- 不把旧Swift model_history checkpoint注入Codex，不写自制summary/compaction fallback。

## Dynamic tools

```text
Codex tool selection
  -> dynamicTools callback
  -> verified root/child identity
  -> exact Intatis ToolRegistry
  -> lease + permission + durable execution
  -> bounded result returned to App Server
```

- App Server负责何时调用；业务host负责能否执行。
- root与child必须分别派生authority，不得以“同一session”共享全部能力。
- `rename_session`只允许Code root和Cowork exact root；child在audit前拒绝。
- Knowledge read/write按workspace access与explicit capability收窄。
- 工具失败不能切换另一backend或旧AgentLoop。

## Permission

- Codex approval request直接映射到Councis现有permission UI/CLI prompt。
- command/file/permissions request有stable request identity；late/duplicate resolution不能覆盖terminal。
- user accept/accept-for-session/decline/cancel保持各自语义。
- dynamic business tool仍使用Intatis PermissionEngine；hard deny终局。
- 不启动第二个acting-model Reporter或Councis reviewer AgentLoop。
- shutdown/cancel先drainrequest-owned runtime/tool work，再清UI waiter。

## MCP

- root native MCP config只能由durable root attachment/grant/consent投影。
- secret通过process environment reference传递，不写isolated config或EventLog。
- Cowork child role和resume配置默认完整禁用root MCP。
- partial/TTL/per-child/stdio/confidential OAuth无法精确表达时保持typed failure。
- 不恢复旧MCP client作为runtime fallback，不写translator/proxy。

## Skills

- repository Skills使用Codex cwd discovery。
- bundled orchestration Skill进入isolated runtime home。
- user Codex Skill roots通过official extra-roots API。
- Skill是context，不是权限；不能扩大workspace、tool、MCP或child profile。
- 不恢复legacy `activate_skill`/`read_skill_resource` product path作为第二套Skill runtime。

## Workspace 与安全

- root workspace来自用户明确选择与Councis session bookmark。
- child只可使用host-advertised exact preset workspace。
- broad/sensitive root拒绝、PathConfinement、WorkspaceLease identity和security-scope生命周期继续有效。
- runtime root位于Councis session目录，与workspace和Intatis checkout分离。
- shell/browser/document/MCP进程必须按各自sandbox/timeout/cancel/drain合同运行。

## UI 投影

- Agents rail来自verified thread descriptors并保留archived/detached历史。
- selected agent是window-local presentation，不改变runtime authority。
- root/child conversation分别从officialhistory与live events投影；不得按字符串归因。
- Goal/Tasks/permission/error/usage使用结构化数据，不解析assistant正文。
- UI可使用IntatisSharedUI类型，但必须保持Councis主题、文案和Cowork-only导航。
- Sidebar与空白页New入口只保留`Choose Folder…` / `No Folder`两项。

## 生命周期

- session manager拥有`CodexAppServerSession`；窗口关闭不隐式shutdown。
- model/config/MCP authority改变需要drain并按exact mapping restart，不热改正在运行的thread。
- Delete只shutdown/delete该session runtime root。
- Quit关闭admission、取消turn、draindynamic tools/MCP/children并有界等待。
- crash/restart只resume exact current runtime/toolset mapping；legacy session要求新建。

## 测试期望

至少覆盖：

```text
Councis directly imports IntatisCodexRuntime public contract
root turn streams and completes
approval request resolves exactly once
cancel interrupts the current turn
dynamic tools execute through Intatis permission/durable path
verified child appears in roster and history
unverified child cannot call business tools
root MCP is disabled for child profiles
Goal and WorkTask remain independent
session/runtime roots are isolated
shutdown drains runtime and tool hosts
no production AgentLoop/Orchestrator fallback call site exists
Cowork-only navigation and Councis product identity remain visible
```
