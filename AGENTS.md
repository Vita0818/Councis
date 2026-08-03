# Councis 项目常驻上下文

本文件继承 `/Users/vita/Vitemis/AGENTS.md` 中的 Vitemis 通用 Agent 规则。若本文件与通用规则冲突，在不违反系统和用户指令的前提下，以更具体、更严格的项目规则为准。

本文是 AI Agent 每轮进入本仓库时的入口文件。执行任何代码、配置、构建脚本或测试修改前，必须按顺序阅读并核对：

0. `/Users/vita/Vitemis/AGENTS.md`
1. `docs/CURRENT_STATE.md`
2. `docs/PROJECT_MAP.md`
3. `docs/ARCHITECTURE.md`
4. `docs/DO_NOT_BREAK.md`
5. `docs/TESTING.md`
6. `docs/NEXT_TARGET.md`（如果存在）

文档与源码、工程配置、测试或脚本冲突时，以当前源码和配置为准，并在最终报告说明冲突和取舍。

> 根目录 `ARCHITECTURE.md` 是 Intatis 来源时代的架构文档，不完整描述 Councis 的异构模型、强制 Judge 和产品表面。Councis 的当前事实以 `docs/ARCHITECTURE.md` 为准。

## 工作目录检查

每轮开始先在项目根目录执行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
```

- `pwd` 与 Git root 必须都是 `/Users/vita/Vitemis/Councis`；否则停止修改并报告路径问题。
- 先区分用户已有改动与本轮改动，不得覆盖、回退或清理用户改动。

## 仓库边界与修改边界

本仓库是 SwiftPM + XcodeGen 双构建工程，包含 Councis CLI、CouncisMac、保留兼容行为的 IntatisMac、IntatisiOS 子集、11 个共享 `Intatis*` 内核模块，以及独立的 `IntatisMacTeamSupport` 模块。

- 常规任务可按用户明确要求修改业务源码。
- 只要求自查或文档更新时，仅修改任务明确列出的 `AGENTS.md`、`README.md`、`NOTICE.md` 或 `docs/` 文件。
- 未经明确要求，不改 `Apps/`、`Packages/`、`Package.swift`、`project.yml`、`Makefile`、`.councis/`。
- `Upstream/` 是来源快照边界：可读取，不得编辑、格式化、构建、生成文件或删除。刷新必须是显式、整体、可审计的快照操作。

## 禁止事项

- 不执行破坏性 Git 操作；未经用户明文要求，不 add、commit、push 或创建 PR。
- 不引入新依赖或更改构建、测试源码，除非任务明确要求。当前无第三方依赖；计划中的 SwiftGit2/libgit2 必须先过许可证审查。
- 不读取、输出或写入密钥、token、私钥、密码、完整 API 响应、完整转写或无关隐私数据。
- 不绕过 `DeterministicPolicyGate` / `ModelPermissionReviewer` / `PermissionEngine`、执行 ticket、`PathConfinement`、`SecretScanner`、`MessageBus` / `Mediator` 或凭据隔离。
- 不破坏 clean-room 声明：Councis 与 Intatis 均不得复制 DeepCode、Codex、Claude Code、OpenCode 等产品的源码、私有 prompt、图标、商标或品牌文案。
- 不随意重命名共享 `Intatis*` 模块、事件 JSONL schema、Envelope、单调 `seq`、Task/Lease 协议或 ArtifactStore 索引格式。
- 不恢复已删除的 `CouncilRunner` / `WorkCommand` / mock CouncisMac / `--mock` 路径。历史 Council JSON 只允许通过只读兼容 reader 查看。

## 项目理解要求

修改前至少确认：

- 入口：`Apps/intatis-cli/Sources/IntatisCLI.swift`（product `councis`）、`Apps/CouncisMac/Sources/CouncisMacApp.swift`、`Apps/IntatisMac/Sources/IntatisMacApp.swift`、`Apps/IntatisiOS/Sources/IntatisiOSApp.swift`。
- Councis CLI：Chat 与 Work 都走 `Interactive.runMode` → `Orchestrator` → `TaskGraph` / `AgentScheduler` → `AgentLoop`；差别仅是 `CoworkSurfaceProfile.chat` 与 `.work` 的 capability/workspace envelope。
- Councis 模型规则：agent 身份是完整 `AgentModelBinding(providerID, modelID)`；`@main`、`@judge` 和活跃 worker 的完整 binding 必须唯一，同模型不同 provider 允许；新 worker 从 preset pool 选未占用 binding，不继承父 agent；池耗尽时拒绝或要求用户选择。
- `@judge`：保留的数据平面 agent，所有 Councis root task 都必须经过其严格 JSON review；结果必须通过 `MessageBus` / `Mediator` 回传，缺失、无效、超时或轮次耗尽默认 fail closed。
- 展示门：raw Main/Judge 输出和内部协作 tool args/results 只作为 EventLog audit/context；Councis CLI/CouncisMac 仅在同一 root task attempt 已 durable `approve` 后把一次 `task_completed.result` 作为答案，失败通道不得回显 Judge summary，replay 与 live 不得旁路。普通 tool/permission/patch/artifact 审计仍可见。
- `@permission-reviewer`：权限控制平面，与 `@judge` 不同；不占数据平面唯一性槽，可复用 main binding，但只能收窄权限，不能覆盖硬 deny。
- CouncisMac：以 `COUNCIS_APP` 编译共享 IntatisMac 源码，只暴露严格 Cowork；至少需要两个唯一 binding，固定 main/judge 并把其余 binding 作为 worker pool。
- IntatisMac：不带 `COUNCIS_APP`，继续提供 Chat / Code / Cowork 和 `.legacy` 模型分配；不得因 Councis 包装而改变其兼容行为。IntatisiOS 仍是无 Tools/Permission/AgentKernel/Cowork 的 chat 子集。
- 持久化：`EventLog` 是 append-only JSONL；当前 Councis CLI 会话写入 Application Support 下的 Councis 目录。`.councis/runs` 是旧 Council JSON 的只读兼容来源，不是当前执行日志格式。
- 配置：team preset 只含非秘密的角色、provider/model binding 和策略；CLI endpoint/凭据位于 env 或 `~/.councis/config.json`（0600）；GUI 使用 Councis/Intatis 各自的 defaults、Application Support、配置和凭据命名空间。
- 来源：`Upstream/Intatis` 是 2026-07-26 固定只读源码快照，具体 HEAD、时间和 SHA-256 见 `Upstream/Intatis/SNAPSHOT.md`；后续实现只参考该快照，不再随外部 Intatis 工作树漂移。

不确定项必须标记 `UNKNOWN` 或“需要后续确认”，不得编造。

## 文档索引

- `docs/PROJECT_MAP.md`：目录、target、入口、关键文件和产物。
- `docs/ARCHITECTURE.md`：共享 Cowork 内核、异构模型、Judge、权限与产品表面。
- `docs/CURRENT_STATE.md`：当前实现、验证边界、风险和工作区状态。
- `docs/TESTING.md`：构建、测试、定向验证与真机矩阵。
- `docs/DO_NOT_BREAK.md`：协议、数据、模型策略、安全和快照禁区。
- `docs/NEXT_TARGET.md`：临时下一目标；目标完成或失效后删除。

## 完成标准

- 说明实际检查过的源码、配置、测试和文档。
- 只修改任务范围内文件，保留用户已有改动。
- 运行与风险相称的验证；纯文档任务至少运行 `git diff --check` 与 `git status --short`。
- 将持久性改动回写相关文档；若无需更新，最终报告说明原因。
- 未运行构建或测试时，明确写“未运行构建/测试”。

## 最终报告格式

建议包含：`MODEL_CHECK_RESULT`、`PATH_CHECK_RESULT`、`FILES_WRITTEN`、`PROJECT_AUDIT_SUMMARY`、`DOCS_CONTENT_SUMMARY`、`VALIDATION_RESULT`、`UNCERTAINTIES`、`NEXT_RECOMMENDED_ACTION`。
