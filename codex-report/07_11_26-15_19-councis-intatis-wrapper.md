# Councis 基于 Intatis Cowork 的产品包装模式

## MODEL_CHECK_RESULT

GPT-5 Codex；无法从当前运行环境确认更细的模型版本号。

## PATH_CHECK_RESULT

- 当前目录：`/Users/vita/Vitemis/Councis`
- Git root：`/Users/vita/Vitemis/Councis`
- 路径与预期仓库根一致。
- 当前工作区包含本次 Intatis 同步、Councis 包装实现、测试和文档改动；未执行 add、commit、push 或破坏性 Git 操作。

## FILES_WRITTEN

- 固定来源：`Upstream/Intatis/` 与快照说明。
- 产品入口：`Apps/intatis-cli/`、`Apps/CouncisMac/`、共享的 `Apps/IntatisMac/` 和保留子集的 `Apps/IntatisiOS/`。
- 共享运行时：`Packages/IntatisCore`、`IntatisProtocol`、`IntatisProviders`、`IntatisConversation`、`IntatisAgentKernel`、`IntatisCowork`、`IntatisPermission`、`IntatisTools`、`IntatisSharedUI` 及对应测试。
- 工程与配置：`Package.swift`、`project.yml`、`Councis.xcodeproj`、`Makefile`、`.councis/presets/`。
- 项目说明：`AGENTS.md`、`README.md`、`NOTICE.md`、`docs/` 与本报告。

## EXECUTIVE_CONCLUSION

Councis 已按以下定位落地：

> **Councis = Intatis Cowork 内核 + 异构模型分配策略 + Judge 审查工作流 + Councis 产品外壳。**

Councis 不再维护一套与 Intatis 平行的多 Agent 内核。共享的 Intatis 模块提供 AgentKernel、Cowork、任务图、调度、上下文投影、消息总线、权限和持久化能力；Councis 定义不同模型如何组成团队、Judge 如何参与工作流，以及 Councis 自己的 preset、CLI、UI 和运行摘要。

主执行模式是 **Main-led heterogeneous-model Cowork**：用户默认只与 `@main` 交互，`@main` 创建和委派任务，不同 Agent 分别使用不同模型，结果通过受控消息与结构化 Task Report 返回，并在强制 Judge 审查通过后由 `@main` 对用户交付。

```text
用户
  ↓
@main · Model A
  ↓ 创建 root TaskContract、拆解与委派
TaskGraph + AgentScheduler
  ├─ @agent-b · Model B
  ├─ @agent-c · Model C
  └─ @agent-d · Model D
       ↓
MessageBus / Mediator / Task Report
       ↓
@judge · Model J（Councis 强制审查）
       ↓
@main 修正、综合并向用户交付
```

## PRODUCT_BOUNDARY

### Intatis 负责的共享内核

以下能力原则上应直接继承 Intatis，不在 Councis 中重新设计：

- `Agent` / `AgentLoop`
- `TaskContract` / `TaskGraph` / `AgentScheduler`
- scoped context projection
- `CapabilityLease` / `WorkspaceLease`
- `MessageBus` / `Mediator` / mailbox
- `PermissionEngine`、deterministic hard deny 和人工兜底
- EventLog append-only 事件、恢复、attempt、timeout、cancel
- tool execution prepare/settle 与非幂等崩溃对账
- PathConfinement、SecretScanner、ProviderRegistry

这些机制共同构成一套一致的运行时。迁移时不得只复制 `Orchestrator.swift`；至少应把相关 `IntatisProtocol`、`IntatisConversation`、`IntatisAgentKernel`、`IntatisCowork`、`IntatisPermission`、`IntatisProviders`、`IntatisTools`、依赖模块及对应测试作为同一源码快照同步。

### Councis 负责的产品包装

Councis 独有部分应尽量保持轻量：

- Councis CLI / macOS 产品入口与品牌
- team/model preset
- `ModelAssignmentPolicy`
- `JudgePolicy`
- 默认 Agent roster 与 model pool
- Chat/Work 的能力策略
- 面向用户的团队状态、Judge 结果和运行摘要
- 旧 Council run log 的兼容读取或迁移投影

这样 Councis 是 Intatis 的一个产品 profile，而不是 Intatis 内核的长期 fork。

## TARGET_RUNTIME_MODEL

### 1. 用户只面对 `@main`

无 `@mention` 的输入默认进入 `@main`。每条输入必须先成为 durable root `TaskContract`，再进入 TaskGraph 与 Scheduler。`@main` 负责：

- 判断是否需要多个 Agent；
- 创建或选择 Agent；
- 定义 task objective、role hint 和 expected deliverable；
- 并行或顺序委派；
- 收集结构化 Task Reports；
- 必要时送交 Judge；
- 根据 Judge 意见修正并交付最终结果。

不能恢复成“用户消息直接调用 AgentLoop”或“AgentLoop 同步递归调用另一个 AgentLoop”的旧模式。

### 2. Agent 身份持久，角色属于任务

每个 Agent 的持久身份可以包含：

```text
AgentIdentity
- id / displayName
- providerID
- modelID
- default workspace / workspace lease reference
- permission profile
- mailbox / status
```

Agent 不应永久硬编码为 coder、reviewer 或 leaf。某一轮负责写代码、下一轮负责分析、另一轮负责复核，均由 `TaskContract.roleHint` 和当前 capability lease 决定。

模型绑定属于 Agent 身份；任务角色不负责选择或改变模型。若必须换模型，应创建新 Agent，或通过显式、可审计的 rebind 事件完成，不能在请求前静默替换。

### 3. 所有 Agent 使用同一种 AgentLoop

不同 Agent 不需要不同内核类。它们都运行 Intatis 的通用 AgentLoop，差异来自：

- `ModelRef(providerID, modelID)`
- 当前 TaskContract
- scoped context
- CapabilityLease / WorkspaceLease
- permission profile
- token、timeout 和 attempt policy

同一 Agent 必须 single-flight；不同 Agent 可以在 Scheduler 的并发上限内运行。

## HETEROGENEOUS_MODEL_POLICY

Councis 的核心差异应由显式模型分配策略表达，而不是散落在 prompt 中。

Councis 已落地的规则：

```text
uniqueModelPerActiveAgent = true
inheritParentModel = false
assignment = explicit-or-unused-pool
onModelPoolExhausted = ask-user | reject
```

### Agent 创建时的模型选择

`spawn_agent` 显式传入 model 时：

1. 解析为允许列表中的 `ModelRef`；
2. 检查当前活跃 Agent 是否已经占用；
3. 检查 pool 声明是否包含当前 admission 所需的 `toolCalling` 能力；当前并未在 spawn 时探测 vision 或远端真实能力；
4. 检查 endpoint/provider 是否已配置；
5. attach 成功后把 provider/model 绑定写入 Agent lifecycle event。

`spawn_agent` 未传 model 时：

1. 从 preset 的 model pool 中选择尚未使用且声明支持 `toolCalling` 的模型；
2. 不得默认继承调用者模型；
3. 没有可用模型时询问用户或明确拒绝；
4. 不得为了继续执行而静默复用已有模型。

唯一性应至少按完整 `(providerID, modelID)` 判断。如果产品要求同一底层模型即使经不同 endpoint 也不能重复，可再增加 normalized model family 约束。

### Provider 边界

运行时使用完整 `AgentModelBinding(providerID, modelID)` 作为 Agent 身份的一部分。即使全部模型经同一个 OpenAI-compatible 聚合 endpoint 调用，请求也按该 binding 路由；跨供应商、Base URL 或凭据时，`ProviderRegistry.agentProvider(for:)` 会根据完整 binding 解析 provider，不能回退可变的 session 默认模型。

API key 不得写入 team preset、Agent event 或项目报告。preset 只引用 provider/model 标识，secret 继续由独立 provider catalog、环境变量或受保护配置解析。

### 已采用的 preset schema v2

```json
{
  "schemaVersion": 2,
  "name": "example-work",
  "mode": "work",
  "main": {
    "providerID": "provider-a",
    "model": "model-a"
  },
  "judge": {
    "providerID": "provider-b",
    "model": "model-b"
  },
  "workerModelPool": [
    { "providerID": "provider-c", "model": "model-c" },
    { "providerID": "provider-d", "model": "model-d" }
  ],
  "modelAssignment": {
    "strategy": "unique",
    "onPoolExhaustion": "fail",
    "excludeControlPlaneAgents": true
  },
  "providers": [
    { "id": "provider-a" },
    { "id": "provider-b" },
    { "id": "provider-c" },
    { "id": "provider-d" }
  ]
}
```

示例只描述非 secret 元数据；provider endpoint 与凭据仍保存在独立配置中。

## JUDGE_MODEL

### Judge 的职责

Councis 预置保留身份 `@judge`，为其绑定独立模型。Judge 负责：

- 审核 worker Task Reports；
- 检查结论是否互相矛盾；
- 检查证据是否足够；
- 检查任务是否满足 expected deliverable；
- 对代码任务检查 diff、测试结果、风险和遗漏；
- 返回结构化 verdict 与 revision requests。

Judge 只接受以下严格 JSON 形状（字段缺失、未知字段、代码围栏或附加 prose 均拒绝）：

```json
{
  "decision": "approve | revise | insufficient_evidence",
  "summary": "...",
  "findings": ["..."],
  "requiredRevisions": ["..."]
}
```

最终用户交付仍由 `@main` 完成。这样用户保持单一对话入口，`@main` 可以根据 Judge 意见补做任务、修正答案或解释未解决风险。

### Judge 是特殊配置，不是特殊内核旁路

Judge 可以在产品策略层被保留、自动创建或设为 mandatory review，但它仍然是普通 Agent 执行单元：

- 通过 TaskContract 接收审查任务；
- 经 Scheduler 运行；
- 只看到 scoped context 和明确共享的报告/产物；
- 结果通过 MessageBus/Mediator 返回；
- 不绕过 EventLog、权限门或任务终态；
- 默认不获得写入、网络、spawn/remove 等能力。

Judge 不应直接看到完整全局 transcript、secret、完整 API 响应或无关 Agent 的私有上下文。

### Judge 与 Permission Reviewer 必须分离

两者不能合并：

| 身份 | 职责 | 工具 | 调度面 |
|---|---|---|---|
| `@judge` | 审查任务质量与最终交付 | 默认只读 | 普通 TaskGraph/Scheduler |
| `@permission-reviewer` | 判断单次工具权限请求 | 无工具 | 独立控制面 FIFO/single-flight |

`@permission-reviewer` 不能批准 deterministic hard deny；`@judge` 也无权替代 PermissionEngine。

### Judge 触发策略

Councis CLI 与 CouncisMac 固定采用 `CoworkTaskReviewPolicy.always`。只有严格 `approve` 才允许 root task 完成；invalid/missing verdict、Mediator block、reviewer 不可用、timeout、持久化失败或轮次耗尽均 fail closed。`deliverWithWarnings` 只保留为显式的 Intatis 兼容选项，不是 Councis 默认策略。

## CHAT_AND_WORK_SURFACES

Chat 与 Work 不应继续是两套 Agent 引擎，而应是同一 Cowork runtime 的不同 lease/profile：

### Chat

- 可以创建不同模型 Agent 并通信；
- 无 workspace 写入工具；
- 无 shell/git/browser 等本地执行能力；
- Judge 只审查文本结论。

### Work

- 绑定用户授权 workspace；
- capability/workspace lease 控制工具；
- 所有 model tool call 经过 PermissionEngine；
- tool intent、permission resolution、execution prepare/result/settled 持久化；
- Judge 可读取结构化 diff、测试结果和任务报告，但默认不能写文件。

旧 `WorkCommand`、硬编码 context collector、固定 fan-out `CouncilRunner` 和 mock CouncisMac 已删除；`--mock` 只返回明确的退役错误。

## IMPLEMENTATION_STATUS

本报告提出的包装模式已经实现，而不是仍停留在迁移建议：

- CLI `chat` / `work` 均进入同一 `Orchestrator` Cowork runtime；有 prompt 时提交 durable root `TaskContract` 后退出，无 prompt 时进入 team REPL。
- `Agent` 持久化完整 `AgentModelBinding`；`ProviderRegistry` 按 binding 路由，生命周期事件用 additive 字段保持旧 model-only JSON 可读。
- `ModelAssignmentPolicy` 对 active 与 admission-pending 数据平面 Agent 执行完整 binding 唯一性；固定 main/judge，worker 只从 pool 或显式允许 binding 进入，不继承 parent。
- `@judge` 使用不同 binding、只读 reviewer lease 和普通 TaskGraph/Scheduler task。审查输入为受限的 `councis.task_review_evidence.v1`，包含任务域内 root/worker report 与有界 diff/test evidence；结果必须经 MessageBus/Mediator 的 contract-directed reply 才能解码。
- `@main` 与 `@judge` 的固定 binding 同时在新 admission 和 EventLog restore 中按 Agent ID 校验；交换两者 binding、让 worker 占用保留 binding、重复 binding 或越出 worker pool 都会 fail closed。CouncisMac 还会对 durable roster 与恢复后的 runtime roster 做第二次一致性核对，发现旧式、错配、越池或重复身份时不恢复任务，也不改写原日志。
- `.always` review 默认 fail closed；`@permission-reviewer` 仍是无工具、独立 FIFO/single-flight 控制面。
- CLI 与 CouncisMac 使用 `MandatoryReviewPresentationGate`：Main 草稿、修订草稿、Judge 原始 JSON、agent 通信和内部 task 输入保留在 append-only 日志中供上下文与审计使用，但不成为用户答案；`send_message` / `ask_agent` / delegation 等内部协作工具的 raw args/results 也会从 strict thread 隐藏。tool 分类默认隐藏，只显式放行当前 shipped operational allowlist；unknown/orphan/重复 in-flight call ID 均 fail closed。只有同一 `(rootTaskID, attempt)` 已先持久化严格 `approve`，随后出现 root `task_completed` 时，才展示一次 `task_completed.result`；replay 与 live stream 使用同一规则。IntatisMac 的 standard projection 保持兼容行为。
- 这是“最终答案交付门”，不是把整个运行过程变成黑盒：非协作型 tool call/result、permission、patch、artifact 和经过 Mediator/结构校验的 Judge 状态可以继续作为操作审计显示。review fail-closed 时只显示通用未批准错误，不把模型生成的 Judge summary 复制到失败通道；成功 approve 后可显示解码后的 bounded Judge summary。
- `CoworkSurfaceProfile.chat` 不暴露文件、shell、Git、browser、document 或 media 数据工具；`.work` 的副作用继续经过 PathConfinement、PermissionEngine 和 durable execution ticket。
- 旧 Council run 由 `councis runs [FILE] [--show-answer]` 只读查看；不执行、不恢复、不改写旧 JSON。
- CouncisMac 复用真实 IntatisMac workbench 并只显示 strict Cowork；IntatisMac 保留 Chat/Code/legacy Cowork，IntatisiOS 保持 tool-free 子集。

## SOURCE_SYNC_RESULT

Intatis 源码已完整复制并固定为 `Upstream/Intatis` 只读参考快照，同时其共享模块、测试和 app 源码已同步到 Councis 的正常构建树进行微调。

| 项目 | 固定值 |
|---|---|
| 来源 HEAD | `7d89c47ac43d09c4e4cd34bfbcf6df21857e2040` |
| 快照时间 | `2026-07-11T12:02:37Z` |
| 来源状态 | 当时 working tree，含 86 个 modified/untracked 路径 |
| 内容 manifest SHA-256 | `d89e957e50bb71594ade74950f27925950712c3edc7455ab576ffbcbbddfe610` |
| 排除项 | `.git`、`.build`、`.swiftpm`、生成 Xcode 工程与本地 runtime state |

快照不是 clean HEAD checkout，而是明确记录的 working-tree baseline；这避免 Intatis 后续同时修改时改变 Councis 的参考面。`Upstream/AGENTS.md` 禁止在快照中编辑、格式化、构建或生成缓存。后续刷新必须整体重制并重新记录 provenance，不能零散覆盖。

长期若两个产品持续共同演进，仍建议把共享 `Intatis*` 模块提取成单一 first-party Swift package；在此之前，固定快照加显式 Councis patch 是可审计的过渡方案。

## IMPLEMENTATION_CHECKLIST

1. 固定 Intatis working-tree baseline：完成。
2. 同步共享模块、事件协议、应用源码与测试：完成。
3. 将正式 CLI 切换到 Cowork runtime：完成。
4. 统一 Chat/Work runtime，仅按 surface/lease 区分：完成。
5. 增加完整 provider/model binding 与逐 Agent provider routing：完成。
6. 增加唯一 pool 分配、pending reservation、无 parent inheritance、固定角色 binding 和 strict restore：完成。
7. 增加独立 `@judge`、严格 verdict、Mediator 回传、fail-closed review 与强制展示门：完成。
8. 增加旧 Council run 只读兼容入口：完成。
9. 增加异构模型、跨 provider、恢复、权限、surface 和 Judge 回归测试：完成。
10. 删除旧 `CouncilRunner`、`WorkCommand`、mock UI 与 `--mock` executor：完成。

## TEST_COVERAGE

现有自动化覆盖：逐 Agent request 使用各自 binding、跨 provider route、重复/pending binding 拒绝、确定性 pool 分配、池耗尽、detach 后复用、legacy restore migration、固定 main/judge admission/restore、strict restore fail-closed、permission reviewer 排除、worker/coordinator lease、Chat/Work capability、Judge 严格 decode、Mediator block/rewrite、review 超时/持久化失败/轮次耗尽，以及旧事件和 run log 读取。

新增 `ReviewedTaskPresentationTests` 和 `TaskReviewGateTests` 集成断言覆盖：approve 前 assistant-message 草稿与 raw Judge JSON 不展示；内部协作、unknown、orphan 与 duplicate-ID tool args/results 不形成旁路；invalid/exhausted/fail-closed 后不展示答案草稿或 Judge summary；approve 后只交付最终 revision 一次；历史 replay 与 live 规则一致；Intatis standard projection 不受影响。测试源码已静态复核，生产源码已由四个 Xcode scheme 编译；由于最后新增展示门后 SwiftPM 在 sandbox 中无法写 Clang cache，而提权重试被平台用量限制拒绝，这组新增断言和最终全量 suite 尚未重新执行，不能把较早的全量结果误写成最终提交态结果。

CLI `selftest` 另外覆盖 Chat、Work workspace tool、schema v2/旧 candidates preset、legacy run reader、one-shot 参数解析，以及 durable root → Judge → terminal 的顺序。

## RISKS_AND_UNCERTAINTIES

- shipped preset 中的模型 ID 与 capability 声明是 endpoint-specific；只有真实 endpoint smoke test 能确认远端是否提供这些模型、tool-calling 方言、usage 字段与限流行为。
- 未使用真实 API key 运行多 provider 网络矩阵，因此凭据解析和 HTTP/SSE 边界虽然有单元覆盖，仍需在用户实际 provider 上验收。
- macOS app 已通过无签名构建，iOS 已通过 generic Simulator 构建；真实签名、Keychain entitlement、流式 UI、多模态权限和设备恢复仍需真机验证。
- 最后一轮展示门与恢复硬化之后，产品源码已全部重新编译并通过离线 CLI smoke；但新增 XCTest 尚未在该最终源码状态执行。环境恢复后应先补跑定向测试和全量 `swift test`，这属于验证债务，不是已观察到的代码失败。
- strict thread 的 operational tool allowlist 与当前 shipped descriptors 已静态逐项比对一致；未来增加/改名工具时必须同时审查其展示分类。普通 operational args/results、patch 和 artifact 仍可能包含模型生成内容，因为它们是明确保留的操作审计，而不是 Judge 批准后的答案通道。
- `Upstream/Intatis` 是冻结历史证据；外部 Intatis 后续修复不会自动进入 Councis，刷新时需要重新比对。
- SwiftGit2/libgit2 仍未引入，许可证审查仍是未来依赖决策，而不是本次 wrapper 的未完成代码。

## VALIDATION_RESULT

实际运行结果按源码时间边界记录如下：

- 在最后展示门与 Mac restore 硬化之前：`swift test` 通过，538 tests executed、14 skipped、0 failures；`swift build` 与 `swift build -c release` 通过；完整 `IntatisCoworkTests` 186/186、`TaskReviewGateTests` 10/10 通过。
- 固定角色 binding 硬化之后、展示门加入之前：`StrictModelAssignmentIntegrationTests` 14/14 通过，包括交换 main/judge binding 和 worker 占用保留 binding 的 admission/restore 拒绝。
- 最终生产源码状态：`xcodegen generate` 通过；`xcodebuild` 的 CouncisMac、IntatisMac、IntatisiOS generic Simulator、`councis` 四个 scheme 均 `BUILD SUCCEEDED`（`CODE_SIGNING_ALLOWED=NO`）。这证明新增展示门及最终 Mac restore 代码已在所有 shipping target 编译。
- 最终 Xcode-built `councis selftest`：Chat、Work、team preset、legacy run、launch parser、durable root + Judge 全部 PASS；`help` 退出 0；`chat --mock test` 按预期退出 1；`runs` 退出 0并只读列出 25 个 legacy run 摘要。
- 最终 `git diff --check`、preset JSON、entitlement、旧 engine 静态旁路和 snapshot 只读边界检查均通过。
- 未完成：最后新增的 `ReviewedTaskPresentationTests`、更新后的 `TaskReviewGateTests` 与最终全量 `swift test` 未重新运行。首次 sandbox 运行因 Clang cache 无写权限失败；提权重试因平台用量限制被拒绝，未采用规避路径。该限制不是测试断言失败。

构建警告限于未签名构建的 hardened-runtime/AppIntents metadata 提示及编译器的非致命 warning；没有观察到编译失败或已执行测试失败。

## NEXT_RECOMMENDED_ACTION

代码层面的 Intatis 包装、异构模型分配、强制 Judge、交付展示门和产品隔离已经完成，不需要恢复或维护旧 Council engine。环境允许时应先补跑 `ReviewedTaskPresentationTests`、`TaskReviewGateTests` 与最终全量 `swift test`；随后只剩用户真实 provider 的多模型 smoke matrix，以及发布所需的 macOS/iOS 签名、真机 UI/Keychain/权限验证。
