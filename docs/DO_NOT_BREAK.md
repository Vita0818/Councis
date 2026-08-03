# DO_NOT_BREAK

本文列出 Councis/Intatis 共享工程不可破坏的边界。修改前必须按源码和测试重新核对。

## 仓库与来源边界

- 不执行 `git reset --hard`、`git clean`、`git checkout .`、强制 push 或删除用户未提交文件。
- 未经用户明文要求，不 add、commit、push 或创建 PR；只提交当前 Git root 中与任务相关的文件。
- `Upstream/Intatis` 是固定、只读的 first-party 来源快照。不得编辑、格式化、构建、codegen、删除或在其中产生缓存；不得把它变成 nested Git repository。
- 快照刷新必须显式、整体、重新记录来源 HEAD/时间/排除项/content manifest；禁止在现有快照中手工挑文件“同步”。
- 当前无第三方依赖。引入 dependency、尤其 SwiftGit2/libgit2，必须先做许可证与构建边界审查。

## Councis 产品不变量

### 同一 Cowork runtime

- CLI Chat 和 Work 必须继续共用 `Orchestrator` / TaskGraph / Scheduler / AgentLoop / MessageBus / PermissionEngine。
- Chat/Work 的差异必须落在 `CoworkSurfaceProfile` 的 capability/workspace lease，不得重新建立无权限门的旁路 engine。
- 不恢复 `CouncilRunner`、`WorkCommand`、旧 fixed-fan-out candidate 流程、mock CouncisMac 或 `--mock`。
- `.councis/runs` 中的旧 Council JSON 只能只读查看；不得把 reader 变成 executor、resume path 或原地 migration writer。

### 完整模型 binding

- agent 的路由身份是完整 `(providerID, modelID)`，不是只有 model。provider lookup 必须使用 `agent.modelBinding`，不得回退 mutable default provider。
- Councis 的活跃或 admission-pending 数据平面 agent（main、judge、workers）必须各占不同完整 binding。同 model 不同 provider **允许**，因为完整 binding 不同。
- `@main` 与 `@judge` 是按 Agent ID 固定的 binding；admission 与 restore 都必须验证“身份 → binding”的精确映射，不能只检查 binding 在 allowed list。worker 不能占用任一保留 binding，只能来自 policy 允许的 pool/显式 binding。
- 新 worker 不继承 parent model/binding；pool selection 必须确定性选择未占用、满足 capability 的 entry。
- `spawn_agent` 的 provider/model 必须同时给出或同时省略；partial binding 必须拒绝。pool 耗尽不得回退 parent/default model。
- pending reservation 必须参与唯一性检测；detach/失败回滚后才可释放 binding。
- strict restore 不得猜 provider，不得接纳重复或不在 policy 内的 binding。旧 model-only event 只能通过显式 `legacyProviderID` 迁移，并以 additive `agent_model_bound` 记录。
- `@permission-reviewer` 是控制平面，排除在数据平面唯一性槽之外；不得因此把 `@judge` 也排除。

### 强制 Judge

- Councis CLI 与 CouncisMac 的每个 root task 都必须使用 `CoworkTaskReviewPolicy.always`；未获得严格 `approve` verdict 不得写 root `task_completed`。
- `@judge` 必须是贯穿 session 的固定特殊数据平面身份：保留 ID、preset 指定且独占的完整 binding、`.readOnly`、coordination depth 0、使用 reviewer-specific capability/workspace lease，且不能被普通 add/remove/direct-send 绕过。它的 binding 不得复用 Main。
- review 必须作为普通 TaskGraph/Scheduler task 持久化。Judge 输出必须通过 `MessageBus` / `Mediator` 的 contract-directed reply；不得直接信任 scheduler 私有 result。
- 只接受严格 `TaskReviewVerdict` JSON。invalid/missing output、Mediator block、timeout、reviewer unavailable、执行或持久化失败、轮次耗尽均须 fail closed。
- `task_review_requested`、`task_review_settled`、`task_review_exhausted` 的次序和 root task 因果关系不可弱化。
- `task_review_requested` 的 end-to-end deadline 必须从 durable admission 覆盖 scheduler queue 等待；不得在 provider dispatch 时重置预算。pre-dispatch deadline 失败不得启动 provider，也不应误触发 provider quarantine。
- 已 dispatch 的 Judge provider 若因 timeout/cancel 结束外层等待、但不能证明底层 producer 已停止，必须保持 session/process-scoped sticky quarantine；晚到结果不得清除 quarantine，后续 Judge dispatch 与 root completion 必须 fail closed。
- restore 必须在恢复 scheduler 前收敛 requested-without-settled orphan：旧 review task cancellation 与 interrupted `task_review_settled(verdict:nil)` 同一批持久化，不得重放旧 Judge 调用；reconciliation 持久化失败时不得继续健康 admission。
- shutdown 必须先关闭 Judge admission 并进入 `shuttingDown`，再 cancel/drain。quiesce barrier 之后的晚到 approve 不得成为有效 completion 授权、完成 root 或通过展示门；即使 settlement append 已在竞态中 durable，生命周期复检仍必须阻止 root `task_completed`。
- `disabled` / `healthy` / `degraded` / `quarantined` / `shuttingDown` 是公开生命周期契约；Councis CLI/Mac 只能在 `healthy` 时接受新 root，状态原因不得含 secret 或 raw Judge output。
- raw `message_delta` / `message_completed` 可以作为 audit/context 持久化，但 Councis CLI/CouncisMac 不得在 approval 前把 Main 草稿、修订稿或 Judge JSON 展示为用户交付。只有同一 `(rootTaskID, attempt)` 已 durable approve 后的 root `task_completed.result` 可交付，且 replay/live 都只能交付一次。
- `send_message`、`ask_agent`、information/delegation 等内部协作工具的 raw args/results 必须随 semantic communication/task 事件一起从 strict thread 隐藏。tool 分类必须 default-hide；只显式放行审阅过的 shipped operational allowlist，unknown/orphan/重复 in-flight call ID 都要 fail closed，隐藏分类不可被同 ID 的可见工具覆盖。非协作型 tool/permission/patch/artifact 是操作审计而非答案，可继续显示；新增或改名 tool 必须同步审查 allowlist。
- strict session 的 public `user_message` 只用于显式用户可见的 root 输入；worker、revision、Judge 和内部 task 输入不得伪装成用户消息进入 thread。
- `MandatoryReviewPresentationGate` 必须 fail closed：invalid/exhausted/failed/cancelled/missing approval 均不能释放旧草稿；失败通道不得拼接模型生成的 Judge summary。Intatis standard projection 的兼容行为应通过显式 policy 分开，不能弱化 Councis gate。
- Judge 与 permission reviewer 的 ID、prompt、lease、事件和执行平面必须保持分离。Judge 的 deadline/quarantine/quiesce 语义可以看齐权限审查，但不得把 Judge 改成 permission control plane，也不得据此允许它复用 Main binding。

## 安全不变量

- 每个 model tool call 到执行都必须经过 capability lease、workspace lease、`PathConfinement`、`DeterministicPolicyGate` / `PermissionEngine` 和需要时的 durable execution ticket。
- deterministic hard deny 终局；`ModelPermissionReviewer` 只能收窄为 ask/deny，不能放行硬 deny。自动 reviewer 失败时回退用户确认或 deny，不得 silent allow。
- `MessageBus` 是 agent 间消息唯一通道；`Mediator.mediate` 必须先于投递和 verdict decode。
- `SecretScanner` 的敏感内容/路径规则与 Mediator 的超长 raw dump 限制不得删减或旁路。
- `PathConfinement.resolve` 必须拒绝 `..` 遍历和越界绝对路径；受保护配置写入必须 ask，敏感路径必须 deny。
- Chat profile 不得暴露 filesystem、patch、shell、Git、browser、document 或 media 工具；Work profile 的工具声明不能越权授予 runtime capability。
- Keychain/config 中的 secret 与 team preset 分离。preset、event log、报告、错误和 UI 摘要不得记录 API key 或凭据内容。

## 数据与协议不变量

- **EventLog JSONL**：一行一个 `{seq, ts, session, v, type, payload}` Envelope；per-session `seq` 单调，append-only。`append` 是唯一写入；replay/stream 通过投影读取，部分坏行不能使整个日志不可恢复。
- shipping runtime 必须持有同一 session 的 long-lived cross-process writer lease，防止多个 scheduler 同时写。
- Event 演进必须 additive/optional。不得删除或重命名既有 type；attach/spawn 的旧 model-only payload 必须继续可解码。
- **Task/lease 协议**：TaskContract、TaskGraph 因果、mailbox、workspace/capability lease、permission review 和 tool execution ticket 不得被 UI 或 provider 路径绕过。
- **ArtifactStore**：blobs 与 `index.json` 的 ID、日期、编码和索引语义保持兼容。
- **Team preset**：schema v2 位于 `.councis/presets/<name>.json` 或 `~/.councis/presets/<name>.json`；只存角色、binding、model policy 和非秘密 metadata。不得放 endpoint、API key 或 credential ref。
- **CLI config**：写入 `~/.councis/config.json`，保持原子写与 `0600`；解析优先级为 `COUNCIS_*` → `INTATIS_*` compatibility → Councis config → legacy Intatis config → defaults。所有新写入只到 Councis namespace。
- **Legacy Council run**：reader 默认只输出 bounded summary，完整答案必须显式 `--show-answer`；不写回源 JSON。
- **Provider wire**：当前 shipped format 是 OpenAI-compatible HTTP/SSE。增加 wire format 必须显式扩展 provider registry，不能把不同 provider 的同名 model 合并。

## 平台和产品隔离

- CouncisMac 必须定义 `COUNCIS_APP`、只显示 strict Cowork，并使用 Councis 的 bundle ID、Application Support、defaults、config 和 auth namespace。
- IntatisMac 不带 `COUNCIS_APP`，继续保留 Chat / Code / legacy Cowork；Councis strict policy 不得成为 Intatis 默认行为。
- `IntatisMacTeamSupport` 保持无 UI、可在 `swift test` 中验证；不要把 strict team 派生逻辑重新藏回 SwiftUI-only target。
- IntatisiOS 必须保持真子集：不得链接 Tools、Permission、AgentKernel、Cowork、TeamSupport 或 shell/Git/workspace stack。
- `PlatformProfile.current` 默认 `.iOS`（最受限）；未设置 profile 的 target 不得意外启用 shell/workspace。
- App Store entitlement 仍无 shell；Developer ID/Hardened Runtime 配置不得被 preset 或运行时布尔值绕开。
- `IntatisSharedUI` 的 `#if canImport(SwiftUI)` 无头守卫不得破坏；XCTest targets 不得依赖 app/UI target。

## Clean-room 与命名

- Clean-room 声明同时覆盖 Councis 和 Intatis。两者间复用 first-party 源码不改变禁止复制竞品源码、私有 prompt、图标、商标或品牌文案的边界。
- 共享 `Intatis*` 模块名是稳定的包装边界，未经用户明确要求不得大规模改名。
- 根 `ARCHITECTURE.md` 与 `Upstream/Intatis` 仅用于来源背景；Councis 当前行为必须以正常源码树和 `docs/` 为准。

## 验证要求

- 通用代码：`swift test` + `swift build`。
- CLI：`swift build --product councis` + `swift run councis selftest`。
- Mac wrapper / TeamSupport：`swift build --product CouncisMac`、相关定向 tests、`xcodegen generate`、CouncisMac 与 IntatisMac scheme build。
- iOS 边界：检查 `project.yml` products，并在 SDK 可用时 build IntatisiOS simulator scheme。
- 文档任务：至少 `git diff --check` + `git status --short`。
- 最终报告只记录实际执行结果；未运行构建/测试时必须明确说明。
