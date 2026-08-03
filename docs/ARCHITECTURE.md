# ARCHITECTURE

最近自查日期：2026-07-26

## 产品关系

Councis 不是另一套 agent kernel；它是共享 Intatis Cowork runtime 上的异构模型 team profile。共享层保留 `Intatis*` 名称，Councis 增加角色绑定、严格模型分配、强制 Judge、Chat/Work surface 和独立产品命名空间。

```text
                     shared Intatis modules
 Core / Protocol / Providers / Conversation / Tools / Permission
              AgentKernel / Cowork / Artifacts / UI
                              │
              ┌───────────────┼────────────────┐
              │               │                │
       Councis CLI       CouncisMac        IntatisMac / iOS
       Chat + Work       strict Cowork     existing product profiles
       strict team       strict team       Mac: Chat/Code/legacy Cowork
       mandatory Judge   mandatory Judge   iOS: tool-free Chat subset
```

`Upstream/Intatis` 是构建该包装时使用的固定只读来源快照；实际编译来自仓库正常的 `Packages/` 和 `Apps/`，不是从 `Upstream/` 编译。

## Councis runtime

CLI Chat 与 Work 的核心链路相同：

```text
IntatisCLI.main
  -> parse launch + load TeamPreset + CLIConfig
  -> Interactive.runMode / teamREPL
  -> Orchestrator.runtime(
       taskReviewPolicy: .always,
       modelAssignmentPolicy: strict preset policy,
       surfaceProfile: .chat or .work)
  -> attach fixed @main + reserved @judge
  -> submit root TaskContract
  -> TaskGraph / AgentScheduler
  -> AgentLoop -> provider selected by agent.modelBinding
  -> optional delegated workers / mediated messages / tools
  -> mandatory Judge review
  -> terminal OrchestratorRootResult
```

不存在固定 fan-out candidate 阶段，也不存在 `CouncilRunner` 或 `WorkCommand` 的旁路权限实现。`cowork` / `code` 只是 `work` 的 CLI 兼容 alias；`--mock` 已移除。

## 完整 provider/model binding

`AgentModelBinding` 由 `providerID` 和 `modelID` 共同组成。它是 agent 身份、持久化投影、provider 路由和占用检测的最小单位。

- `ProviderRegistry.agentProvider(for: binding)` 必须用 binding 中的真实 provider endpoint 和 model；不得只按 model 或 mutable default provider 路由。
- 严格 Councis session 固定 `@main`、`@judge`，并允许 preset 中的 worker pool。
- 活跃或 admission-pending 的数据平面 agent 不得复用同一完整 binding。
- 同一个 model ID 位于不同 provider 时是两个合法、不同的 binding。
- `spawn_agent` 要么同时给 provider 和 model，要么两者都省略。只给一个字段必须拒绝。
- 两者省略时，按 worker pool 顺序选择第一个满足 capability 且未占用的 binding。
- `inheritParentModel` 在 Councis strict policy 中为 `false`；新 worker 不继承 parent。
- 池耗尽按 preset 转为 reject 或 ask-user 结果，不回退到 parent/default model。
- detach 会释放 binding；pending reservation 防止 actor reentrancy 下并发 attach 获得同一 binding。

`ModelAssignmentPolicy.legacy` 只为未选择 Councis profile 的 Intatis/旧调用方保留。旧 model-only lifecycle 必须通过显式 `legacyProviderID` 迁移并写 `agent_model_bound`；严格 restore 不猜测 provider，也不接受重复或不在 policy 内的 binding。

## 强制 Judge：固定特殊数据平面身份

`@judge` (`Orchestrator.taskReviewerID`) 是与 `@main` 一样贯穿会话的固定特殊身份：它使用保留 Agent ID 和 preset 指定的完整 `AgentModelBinding`，并占用一个独立的数据平面唯一性槽。它不是一次字符串合成器，也不是权限控制平面；单次 review 仍是普通 TaskGraph/Scheduler 数据平面任务。

```text
@main root draft
  -> persist task_review_requested
  -> scheduler admits review TaskContract assigned to @judge
  -> Judge AgentLoop returns one strict TaskReviewVerdict JSON
  -> contract-directed reply crosses MessageBus -> Mediator
  -> decode mediated payload only
  -> persist task_review_settled
       approve -> root may complete
       revise / insufficient_evidence -> bounded @main revision round
       malformed / blocked / failed -> retry within bound
  -> no approval before limit -> task_review_exhausted -> root fails
```

关键不变量：

- Councis CLI 和 CouncisMac 都使用 `CoworkTaskReviewPolicy.always`；默认最多 2 轮、120 秒/轮、exhaustion disposition `.fail`。
- `@judge` 必须是保留 ID、固定完整 binding、`.readOnly`、coordination depth 0，并使用持久的 surface-specific reviewer capability/workspace lease；其 communication/delegation 都是 `.none`。用户、worker 和普通 coordinator 不可直接占用、移除或向其发送绕过 review 的消息。
- Judge 输出只有通过 `MessageBus` / `Mediator` 的 scheduled reply 后才可解码。scheduler 内部 result 不是批准证据。
- verdict 必须是无 prose/code fence/未知字段的严格 JSON。缺失 reviewer、Mediator block、invalid JSON、timeout、执行失败或 review 事件持久化失败均 fail closed。
- `task_review_settled` 必须先于 root `task_completed` 持久化。

### Judge 生命周期与故障隔离

Judge 的身份管理看齐 Main，故障边界看齐权限审查，但两者不合并执行平面：

- `TaskReviewerLifecycleHealth` 对外暴露 `disabled`、`healthy`、`degraded(reason)`、`quarantined(reason)`、`shuttingDown`。只有 `healthy` 接受新的 Councis root；CLI `/team` 显示状态，CouncisMac 同步状态并在非 healthy 时阻止提交。
- 每个 durable `task_review_requested` 记录 `createdAt` / `deadline`；超时预算从 review admission 开始，包含 scheduler queue 等待时间，而不是到 provider dispatch 才起算。排队阶段已过 deadline 会直接失败，不启动 provider，也不因此 quarantine。
- Judge provider 调用由与 EventLog session coordination key 关联的进程内 activity registry 跟踪。已 dispatch 的调用若因 timeout/cancel 返回、但无法证明底层 producer 已终止，该 session 在本进程内进入 sticky `quarantined`；晚到 provider 结果不能清除隔离，后续 review 和 root submission 均 fail closed。进程重启是有意设置的恢复边界。
- restore 先扫描 `task_review_requested` 但没有对应 `task_review_settled` 的 orphan。旧 review task 的 cancel 与 `verdict:nil`、`interrupted by restart` settlement 在同一 append transaction 中持久化，之后才重建 scheduler；旧 Judge 调用不会被重放。reconciliation 无法持久化时 health 为 degraded，不能接收新 root。
- `cancelAll` 先把 Judge 置为 `shuttingDown` 并关闭 admission，再取消和 drain 已排队/运行任务。quiesce 之后即使不配合取消的 provider 晚到合法 `approve`，该 verdict 也不能完成 root 或通过展示门。

这里的 quarantine 只处理“底层 Judge provider 是否仍在运行”这一不可证明的故障；它不授予 Judge 权限审查能力，也不允许 Judge 复用 Main 的完整 binding。

### 审批与用户交付是两个相邻但独立的门

AgentLoop 的 `message_delta` / `message_completed` 必须保留在 append-only EventLog 中，供后续上下文、恢复和审计使用；它们不是 Councis 的用户交付。CLI render 与 CouncisMac `CodeProjection` 都使用 `MandatoryReviewPresentationGate`：

1. 只显示显式标记为 `user_visible` 的 root 用户输入；worker、revision 与 Judge 输入不作为 public user message 持久化。
2. 隐藏 Main 初稿/修订稿、Judge raw JSON、agent 通信和 task contract 内容；同时按 tool call ID 追踪并隐藏 `send_message`、`ask_agent`、information/delegation 等内部协作工具的 raw args/results。工具分类默认隐藏，仅 shipped operational allowlist 可见；unknown、orphan result 或重复 in-flight call ID 均保持隐藏。
3. 记录每个 `(rootTaskID, attempt)` 的 durable `task_review_settled(approve)`。
4. 只在随后收到同一 attempt 的 root `task_completed` 时交付其 `result`，并去重为一次。
5. invalid verdict、review exhausted、task failed/cancelled 或没有匹配 approval 时永不交付草稿；review exhaustion 的用户错误使用通用文案，完整 verdict 只留在隐藏的 durable review 事件中。

同一 gate 同时用于历史 replay 与 live stream，因此重启不能绕过审批。该 gate 约束的是“答案通道”：非协作型 tool call/result、permission、patch、artifact 等操作审计仍可显示，以保留工具透明度和用户审批依据；它们不得被文档描述成已经 Judge 批准的答案。IntatisMac 的 standard projection 不启用该产品规则，以保持原有 Chat/Code/Cowork 兼容行为。

## Judge 与权限 reviewer 分离

| 维度 | `@judge` | `@permission-reviewer` |
|---|---|---|
| 职责 | root task 质量与证据审查 | 单次 tool permission 的控制平面审查 |
| 调度 | 普通 TaskGraph / AgentScheduler data plane | 独立 `PermissionReviewControlPlane`，不递归进入普通 TaskGraph |
| 输入 | 有界 task evidence + draft | deterministic gate snapshot + 有界因果上下文 |
| 输出 | `TaskReviewVerdict` | allow/ask/deny 的权限结论 |
| 模型唯一性 | 占一个数据平面 binding | 排除在数据平面唯一性槽之外，可复用 main binding |
| 失败行为 | root review 不批准并最终失败 | 回退 ask user 或 deny，不可越过硬 deny |

CLI 当前用 `TerminalResponder` 处理 ask-user；CouncisMac 会自动启动 permission reviewer，失效时 UI 回退用户确认。无论是否启用模型 reviewer，`DeterministicPolicyGate` 的 deny 和 execution-ticket 检查都不可旁路。

## Chat / Work surface

`CoworkSurfaceProfile` 只改变 capability/workspace lease，不另建 agent engine。

### Chat

- 使用 Application Support 下的私有、空、confined workspace，不使用启动目录。
- coordinator/worker 仍可按 lease 做 team communication/delegation。
- 不向 agent 暴露 filesystem、patch、shell、Git、browser、document 或 media 执行能力。
- reviewer workspace access 为 read-only；Chat profile 的 Judge 无工具和任意通信能力。

### Work

- 使用用户显式选择或 `--workspace` 指定的项目根。
- main/coordinator 可获得受 lease 限制的标准工作能力；worker 默认 read-only workspace。
- 每个 model tool call 都经过 capability lease、workspace lease、`PathConfinement`、permission gate 和 durable execution ticket。
- shell 是否可用还取决于 platform profile / entitlement；App Store profile 不能因为 preset 声明而获得 shell。

Team preset 不承载 tool 授权策略；runtime surface、capability/workspace lease 与 PermissionEngine 是唯一能力来源。旧 preset 即使含未知 `tools` 字段，也只会被兼容 decoder 忽略。

## Cowork 内核链路

```text
Orchestrator (actor + cross-process EventLog writer lease)
  -> AgentRegistry + pending model reservations
  -> TaskGraph policy + AgentScheduler + per-agent mailbox
  -> capability/workspace leases
  -> AgentLoop
       ContextBuilder / context projection
       -> ToolCallingProvider from exact AgentModelBinding
       -> tool call
       -> PermissionEngine + execution ticket
       -> ToolObservation
  -> EventLog append

agent communication
  -> MessageBus
  -> Mediator
       SecretScanner block
       oversized raw content block (>4000 chars)
       optional ForwardingReviewer
  -> append mediated event
```

所有 agent 间消息必须经过 MessageBus/Mediator。worker 不因创建方式获得 coordinator 权限；delegation depth、task budget、capability lease、workspace lease 和 task graph cycle policy共同限制协作。

## 权限和安全

1. `DeterministicPolicyGate` 先运行；敏感路径、越界、危险 shell 等硬 deny 终局。
2. 可选 `ModelPermissionReviewer` / permission-review control plane 只能收窄结果，不能把硬 deny 改成 allow。
3. `PermissionEngine` 组合 policy；需要用户决策时通过 responder，默认不静默放行。
4. 有副作用的实际执行还必须持有有效 execution ticket，避免“评审通过”和“真正执行”之间的旁路。

`PathConfinement` 拒绝 `..` 和越界绝对路径；`SecretScanner` 同时用于权限与跨 agent 内容边界。GUI 的产品命名空间由 `AppIdentity` 分开；CLI preset 不存 endpoint 或密钥。

## 持久化和兼容

| 数据 | 当前行为 |
|---|---|
| `EventLog` | 一行一个 Envelope 的 append-only JSONL；`seq` 单调；writer lease 防止同 session 多写者 |
| Cowork lifecycle | attach/spawn payload 可含 provider/model；`agent_model_bound` 为 additive migration event |
| Task review | `task_review_requested`（含 admission deadline）/ `settled` / `exhausted` 均持久化；restore 原子收敛未 settled orphan，不重放旧 review |
| ArtifactStore | `<root>/blobs` + `index.json`，保持原协议 |
| CLI team preset | `.councis/presets` 或 `~/.councis/presets`；schema v2，无秘密 |
| CLI current sessions | Application Support/Councis 下的 event-log JSONL |
| legacy Council run | `.councis/runs/*.json` 仅由 `councis runs` 读取，默认只显示 bounded summary |

旧事件字段通过 optional/additive decode 保持兼容；格式演进不得重写历史 JSONL。旧 Council JSON reader 不是 migration executor，不会修改或继续运行旧 run。

## macOS / iOS 产品边界

- `CouncisMac`：`COUNCIS_APP` + shared IntatisMac sources；只显示 Cowork。`CoworkTeamConfiguration` 从 provider catalog 固定 main/judge，把其余 binding 变为 worker pool；少于两个唯一 binding 时拒绝启动。
- `IntatisMac`：相同共享源码但无 `COUNCIS_APP`；保留 Chat、Code、Cowork 和 `.legacy` 模型分配，不强制 Councis Judge。
- `IntatisiOS`：只链接 7 个 chat/multimodal products；无 workspace、shell、permission、AgentKernel 或 Cowork。
- `PlatformProfile.current` 默认 `.iOS`（最受限）；每个 app 必须在启动时显式设置合适 profile。

## 来源快照边界

`Upstream/Intatis` 固定于来源 HEAD `437fcb8a962ad8a833cf23eee956c3f92a088a9c`（提交标题 `v0.26`）的 clean `main` 工作树，快照时间为 `2026-07-26T01:33:50Z`，manifest SHA-256 为 `9770e4ba257e19fd69fbe8ef93f42fad76c278c211ebc58cc7531e34a19f3aa0`。它没有 `.git`，不是 submodule，不参与 build；快照中随来源保留的 tracked Vendor 源码和 lockfile 不会成为 Councis 的构建依赖。任何来源更新必须重新审核并整体生成新快照，不能在现有目录中零散同步。
