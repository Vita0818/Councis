# CURRENT_STATE

最近自查日期：2026-07-26

## 当前真实状态

- Councis 已从旧的“固定候选并行 + 一次 judge 合成”原型迁移为 **Intatis Cowork 的异构模型产品包装**。旧 `Council.swift`、`WorkCommand.swift`、mock CouncisMac 和 `--mock` 执行路径已删除。
- `councis chat` 与 `councis work` 现在调用同一套 `Orchestrator` / TaskGraph / Scheduler / AgentLoop / MessageBus / PermissionEngine runtime；两者只在 `CoworkSurfaceProfile` 的 capability 和 workspace envelope 上不同。
- 每个 agent 使用完整 `AgentModelBinding(providerID, modelID)`。Councis 的 `@main`、`@judge` 与活跃 worker 必须使用不同的完整 binding；同一 model ID 位于不同 provider 时视为不同 binding。
- 新 worker 从 preset 的固定 `workerModelPool` 按顺序选择未占用 binding，不继承 parent binding。并发 admission 也会预留 binding；池耗尽按配置拒绝或要求用户明确选择。
- `@judge` 是会话级固定的特殊只读数据平面身份：保留 ID、完整 binding 唯一、`.readOnly`、depth 0、reviewer-specific leases；身份管理看齐 Main，但每轮 review 仍走 TaskGraph/Scheduler/MessageBus/Mediator。Councis 对所有 root task 使用 `.always` review。
- Judge 公开 `disabled` / `healthy` / `degraded` / `quarantined` / `shuttingDown` 健康状态。review deadline 从 durable admission 起覆盖排队；已 dispatch 的 provider timeout/cancel 若无法证明底层终止，会触发本进程内 sticky quarantine，后续 root fail closed。restore 原子 cancel+settle 未完成 orphan 且不重放旧 review；`cancelAll` 先 quiesce，晚到 approve 不能完成 root。
- CLI 与 CouncisMac 还使用强制答案展示门：raw Main/Judge message、内部 task/agent communication 事件及其协作工具 args/results 只作为 durable audit/context，不进入 strict thread；tool 分类默认隐藏，只有 shipped operational allowlist 可见，unknown/orphan/duplicate-ID fail closed。只有同一 root task attempt 已持久化 `approve` 后的 `task_completed.result` 才作为答案交付一次。非协作型 tool/permission/patch/artifact 操作审计仍可显示。
- `@permission-reviewer` 是单独的权限控制平面，不等于 Judge；它不占数据平面唯一性槽，可以复用 main binding，但只能收窄权限。
- CouncisMac 不再是 mock 壳。它用 `COUNCIS_APP` 编译共享 IntatisMac workbench，只显示严格 Cowork；IntatisMac 不带该标志，继续提供 Chat / Code / legacy Cowork。
- IntatisiOS 仍是工具无关的 chat/multimodal 子集，不链接 Tools、Permission、AgentKernel 或 Cowork。
- 外部 Intatis 的工作树已固定复制到 `Upstream/Intatis`。Councis 后续只参考这份只读快照，不追随外部仓库变化。

## 固定来源快照

| 项目 | 值 |
|---|---|
| 路径 | `Upstream/Intatis` |
| 来源 HEAD | `437fcb8a962ad8a833cf23eee956c3f92a088a9c`（提交标题 `v0.26`） |
| 快照时间 | `2026-07-26T01:33:50Z` |
| 来源状态 | clean `main` working tree；434 个 tracked 文件；本地 `origin/main` 0 ahead / 0 behind，未联网 fetch |
| 内容 manifest SHA-256 | `9770e4ba257e19fd69fbe8ef93f42fad76c278c211ebc58cc7531e34a19f3aa0` |

快照不含 `.git`、构建缓存、生成的 Xcode 工程、本地运行时数据或本地秘密配置；包含该 HEAD 已跟踪的 `Vendor/SwiftStreamingMarkdown` 派生源码、许可证、第三方 notices 与 `Package.resolved`。这些内容只属于来源快照，不进入 Councis 当前构建依赖。权威明细与 manifest 算法见 `Upstream/Intatis/SNAPSHOT.md`；该目录不可编辑或构建。

## 已实现能力

| 能力 | 当前实现 / 证据位置 |
|---|---|
| CLI Chat / Work | `IntatisCLI.swift` → `Interactive.swift` 的 `runMode` / `teamREPL` → `Orchestrator.submit` |
| 异构 team preset | `TeamPreset.swift`；schema v2 包含 main/judge/worker pool/model assignment/providers，旧 candidates schema 可迁移读取 |
| 完整模型路由 | `AgentModelBinding.swift`、`Agent.swift`、`ProviderRegistry.agentProvider(for:)` |
| 严格模型分配 | `ModelAssignmentPolicy.swift` + Orchestrator admission/restore；完整 binding 唯一、固定 main/judge 逐身份校验、无父模型继承、池耗尽处理 |
| 强制 Judge | `CoworkTaskReviewPolicy.always`、`attachTaskReviewer`、`task_review_*` 事件和 `TaskReviewGateTests` |
| Judge 回传边界 | review task 走普通 TaskGraph/Scheduler；仅解码通过 `MessageBus` / `Mediator` 的 contract-directed reply |
| Judge 固定身份与健康 | `TaskReviewerLifecycle.swift` + `Orchestrator.taskReviewerHealth()`；固定 reserved/read-only/depth-0 身份，公开五态 health；CLI `/team` 显示、CouncisMac view model 消费该状态，二者都拒绝 unhealthy submission |
| Judge deadline 与 quarantine | `task_review_requested.createdAt/deadline` 覆盖 queue wait；已 dispatch timeout/cancel 且 producer termination 不可证明时，session 在当前进程内 sticky quarantine，后续不再 dispatch |
| Judge restart / shutdown barrier | restore 将 requested-without-settled orphan 原子 cancel+settle 为 interrupted 且不重放；`cancelAll` 先进入 `shuttingDown`，晚到 approve 不得完成 root |
| Judge 展示边界 | `MandatoryReviewPresentationGate` + strict `CodeProjection` / CLI render；approve 前草稿、raw Judge JSON 与内部协作 tool side channel 不成为用户答案，失败错误不回显 Judge summary，replay/live 同规则 |
| 权限评审分离 | `@permission-reviewer` / `PermissionReviewControlPlane` 与 `@judge` 为不同 ID、lease、prompt 和事件 |
| Chat / Work 表面 | `CoworkSurfaceProfile.chat` 移除工作区副作用能力；`.work` 使用权限和 execution-ticket 保护的工作区能力 |
| CouncisMac strict team | `COUNCIS_APP`、`CoworkTeamConfiguration`、`CoworkProjectSettings.teamConfiguration`；至少两个 binding，固定 main/judge |
| Intatis 兼容 | IntatisMac 继续 `.legacy` 分配和 Chat/Code/Cowork；旧 model-only lifecycle 可经显式 legacy provider 迁移 |
| 历史 run 查看 | `LegacyCouncilRun.swift`；`councis runs [FILE] [--show-answer]` 只读且默认不输出完整答案 |
| 事件与投影 | append-only JSONL；新增 `agent_model_bound` 与 `task_review_requested/settled/exhausted`，旧 payload 保持可解码 |
| TeamSupport 无头测试 | `IntatisMacTeamSupport` / `IntatisMacTeamSupportTests` 将 Mac team 派生策略从 UI target 中抽出 |

## 最近验证状态

- 本轮最终 `swift test`：554 executed、14 skipped、0 failures；其中 `JudgeLifecycleTests` 7/7 通过，既有 `TaskReviewGateTests`、`ReviewedTaskPresentationTests`、权限审查、恢复和模型分配 suites 同轮通过。
- 本轮最终 `swift build --product councis` 与 `swift build --product CouncisMac` 通过；IntatisMac Xcode scheme 的无签名构建也在本轮通过。
- 更早的 CouncisMac、IntatisMac、IntatisiOS generic Simulator、`councis` 四个 Xcode scheme 与 Xcode-built CLI `selftest` 验证仍是历史证据；真实 endpoint 与真机边界不由离线 suite 覆盖。

## 仍需验证的边界

- 真实 endpoint、多 provider 凭据、流式模型行为，以及 macOS/iOS 真机交互仍需使用用户环境验证；离线测试不能证明第三方 endpoint 的模型 ID 或能力匹配。
- IntatisiOS 真机构建/运行取决于本地 Xcode、SDK 与签名；代码检查和 simulator build 不能替代设备验证。
- JSON-RPC 词汇仍未接 out-of-process transport；这不是当前 Councis wrapper 的执行路径。
- SwiftGit2/libgit2 仍未引入，许可证审查未完成。

## 风险与注意事项

- `Upstream/Intatis` 是刻意冻结的历史证据；外部 Intatis 后续修复不会自动进入 Councis，刷新必须显式比对和重新制作快照。
- shipped preset 的模型 ID 取决于所配置 endpoint。preset 通过结构校验不代表远端一定提供该模型。
- CLI 允许从 `~/.councis/config.json` 的兼容字段读取明文 key；文件必须保持 `0600`，优先使用环境变量或 `apiKeyEnv`。
- 根目录 `ARCHITECTURE.md` 仍是 Intatis 来源文档，不能作为 Councis 异构 team 和强制 Judge 的权威说明。
- 工作树当前包含本轮大范围未提交实现和用户报告。不得用 clean/reset/checkout 清理，也不得把它们误判为可覆盖的生成物。

## 文档与源码取舍

| 位置 | 结论 |
|---|---|
| 根 `ARCHITECTURE.md` | 保留来源背景；Councis 当前架构以本目录 `ARCHITECTURE.md` 和源码为准。 |
| `.councis/runs/*.json` | 仅为旧 Council 历史记录；当前 runtime 不执行、不追加、不重写该格式。 |
| `Upstream/Intatis/**` | 来源快照而非活跃实现；相同文件名冲突时，仓库正常源码树是 Councis 的运行事实。 |
