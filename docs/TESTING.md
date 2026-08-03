# TESTING

最近自查日期：2026-07-26

本文列出当前实现的验证入口，不把“测试存在”写成“本轮已经运行”。最终交付报告必须记录实际命令、退出状态和未覆盖边界。

## 环境

- Swift tools version 5.9；macOS deployment target 13，iOS target 16。
- SwiftPM 负责库、CLI、CouncisMac executable 和 11 个无头 XCTest targets。
- XcodeGen 从 `project.yml` 生成 `Councis.xcodeproj`，负责 CouncisMac、IntatisMac、IntatisiOS app bundles。
- 当前无第三方 package dependency。
- 真实模型验证需要 endpoint 和 key；离线 `selftest`、unit tests、legacy run reader 不需要网络。

## 标准代码验证

```sh
swift test
swift build
swift build -c release
```

Makefile 等价入口：

```sh
make test
make build
make release
```

`swift test` 当前覆盖 11 个 targets：Core、Protocol、Providers、Artifacts、Conversation、Tools、Permission、AgentKernel、Cowork、Multimodal、MacTeamSupport。`IntatisSharedUI` 无独立 test target；app UI 由 Xcode build 和手动矩阵覆盖。

## Councis 定向验证

```sh
swift build --product councis
swift run councis selftest

swift test --filter ModelAssignmentPolicyTests
swift test --filter StrictModelAssignmentIntegrationTests
swift test --filter SpawnAgentToolModelBindingTests
swift test --filter CoworkSurfaceProfileTests
swift test --filter TaskReviewGateTests
swift test --filter JudgeLifecycleTests
swift test --filter ReviewedTaskPresentationTests
swift test --filter EventCompatibilityTests
swift test --filter CoworkTeamConfigurationTests
```

重点断言：

- full `(providerID, modelID)` 参与 hash、persist 和 provider route；同 model 不同 provider 可并存。
- main/judge/worker 重复 binding 被拒；并发 pending attach 不能抢同一 binding；detach 后可复用。
- omitted spawn 选择下一未占用 worker pool binding，不继承 parent；partial binding 和池耗尽 fail closed。
- permission reviewer 不消耗数据平面唯一性槽；Judge 必须消耗并使用固定不同 binding。
- Chat lease 不含 filesystem/shell/Git/browser/document/media；Work lease 仍经过 permission/ticket。
- root `task_review_settled` 在 root completion 前；invalid/blocked/timeout/persistence failure/exhaustion 不会被当成 approve。
- attach 固定 reserved Judge 后 health 为 `healthy`；缺失、配置错误、recovery failure、quarantine 和 shutdown 分别阻断新的 Councis root admission。
- restore 遇到 requested-without-settled orphan 时只写一份 interrupted settlement，并取消旧 review task；重复 restore 不重复 settlement，也不调用旧 Judge provider。
- review timeout 从 admission 起包含 scheduler start-gate/queue 等待；pre-dispatch expiry 不调用 provider、不触发 quarantine，并留下 durable timeout/deadline 诊断。
- 已 dispatch Judge provider timeout 或 cancellation 且 termination 不可证明时进入 sticky quarantine；下一 root fail closed，provider request count 不增加。
- `cancelAll` 先建立 shutdown barrier；不配合取消的 provider 晚到严格 approve 后，root 仍无 `task_completed`，展示投影仍无答案；即使 approve settlement 已在竞态前 durable，也不能在 quiesce 后成为 root completion 授权。
- strict presentation 在 approve 前隐藏 Main/Judge assistant-message text 及内部协作 tool args/results；unknown tool、orphan result 和 duplicate in-flight call ID fail closed，operational allowlist 与当前 descriptors 一致；invalid/exhausted/fail-closed 后不释放答案草稿或 Judge summary；匹配 approve 后只交付最终 root result 一次；历史 replay 与 live 使用相同 gate，standard Intatis projection 保持原行为。非协作型 tool/permission/patch/artifact 审计仍可见。
- 旧 model-only lifecycle 可在显式 provider migration 下恢复；strict restore 缺 provider、重复或越池时拒绝。

## CLI 离线检查

```sh
swift run councis help
swift run councis config
swift run councis selftest
swift run councis runs
swift run councis runs .councis/runs/RUN_FILE.json
swift run councis runs .councis/runs/RUN_FILE.json --show-answer
```

预期：

- help 只描述 Cowork-backed Chat/Work；`cowork`/`code` 为 Work alias。
- `--mock` 返回明确退役错误，不启动旧 Council engine。
- selftest 用 fake providers 覆盖 chat、workspace tool、preset/legacy decode、launch parser 和 durable root + Judge，不读取真实 key。
- `runs` 默认只打印 bounded prompt/metadata/answer length；仅 `--show-answer` 打印完整 stored answer；源 JSON 的内容、mtime 和 hash 不变化。

## CLI 真实 endpoint 矩阵

先配置 endpoint，使 preset 的 main 与 judge model ID 都真实可用且 binding 不同：

```sh
COUNCIS_API_KEY='…' swift run councis chat --preset elite-chat "Reply with a concise reviewed answer"
COUNCIS_API_KEY='…' swift run councis work --preset elite-work --workspace . "Read README.md and summarize the architecture"
```

检查：

1. root task 分配给 `@main`，终端输出标识实际 provider/model。
2. `@judge` 使用 preset 中不同 binding，并在 root terminal 前产生 verdict。
3. Chat 不能读取启动目录或调用 workspace/shell/Git/browser/document/media tools。
4. Work 的读取保持 workspace confinement；写入、shell、network 等风险操作出现预期 terminal approval，拒绝后不执行。
5. `/agent add <name>` 依次使用未占用 worker pool；无可用 binding 时拒绝而非复用 parent/main/judge。
6. 多 provider 场景中，provider endpoint 与 model 始终来自该 agent 的完整 binding。

真实 endpoint 的模型名、tool-calling 方言、usage 字段和限流属于外部兼容边界；unit tests 不能替代该矩阵。

## macOS build

```sh
swift build --product CouncisMac
xcodegen generate

xcodebuild \
  -project Councis.xcodeproj \
  -scheme CouncisMac \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project Councis.xcodeproj \
  -scheme IntatisMac \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Entitlement 静态检查：

```sh
plutil -lint Apps/CouncisMac/CouncisMac.DeveloperID.entitlements
plutil -lint Apps/IntatisMac/IntatisMac.DeveloperID.entitlements
plutil -lint Apps/IntatisMac/IntatisMac.AppStore.entitlements
```

`make app` 等于生成后打开 Xcode，适合手动运行，不适合作为无 UI CI 命令。

## macOS 手动矩阵

| 场景 | 操作 | 预期 |
|---|---|---|
| Councis surface | 启动 CouncisMac | 只显示 Cowork；不显示单 agent Chat/Code |
| team 前置条件 | provider catalog 仅一个唯一 binding | 新建/恢复项目明确失败，要求至少 main + judge 两个 binding |
| fixed roles | catalog 有两个以上 binding | main 固定为所选 binding；judge 固定为不同 binding；其余进入 worker pool |
| mandatory review | 提交 root prompt | Judge settle 后才完成；Judge 错误/无效输出不交付为成功 |
| Judge health | 启动、restore、运行 review、触发失败 | CLI `/team` 显示五态 health，CouncisMac view model 同步同一状态；非 `healthy` 时二者都不能提交新 root |
| queue deadline | 暂停 review scheduler start 超过 deadline | provider 不启动；root fail closed；Judge 不因 pre-dispatch expiry 被 quarantine |
| uncertain provider stop | 让已 dispatch review timeout/cancel 且 provider 忽略取消 | Judge 进入本进程 quarantine；后续 root 不再调用 Judge provider |
| restart reconciliation | 用 requested-without-settled event log 恢复 | 旧 review 原子 cancel+settle interrupted，不重放；重复恢复保持幂等 |
| shutdown barrier | Judge 调用中停止 session，再释放晚到 approve | health 进入 `shuttingDown`/非 healthy；晚到 approve 不完成 root、不释放答案 |
| worker assignment | 连续添加 worker | 依 catalog/pool 次序使用未占用 binding；耗尽时拒绝 |
| permission review | 触发需评审 tool | `@permission-reviewer` 状态与 `@judge` 独立；失败时回退用户审批，不 silent allow |
| persistence | 退出并恢复 session | main/judge/worker binding 和 team 配置稳定；重复/缺失 binding fail closed |
| product isolation | 分别运行 CouncisMac/IntatisMac | history、defaults、config/auth 和 Application Support 不串用 |
| Intatis regression | 启动 IntatisMac | 仍有 Chat/Code/Cowork；legacy Cowork 不被强制改成 Councis strict team |

## iOS 子集

静态检查 `project.yml`：IntatisiOS 只链接 Core、Protocol、Providers、Conversation、Artifacts、Multimodal、SharedUI。

SDK 可用时：

```sh
xcodebuild \
  -project Councis.xcodeproj \
  -scheme IntatisiOS \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

真机验证包括流式 chat、Keychain/provider config、附件/语音/多模态权限和 session 恢复。真机未运行时必须明确标记，不得以 simulator build 代替。

## 来源快照检查

- 阅读 `Upstream/Intatis/SNAPSHOT.md`，核对来源 HEAD、时间、included/excluded 和 manifest SHA-256。
- 确认 `Upstream/Intatis/.git`、`.build`、`.swiftpm`、生成工程和 runtime state 不存在。
- 确认 `Upstream/AGENTS.md` 仍声明只读边界，且本轮 diff 没有 snapshot 内文件。
- 不在快照中运行 build/test/codegen；验证 Councis 时只使用正常源码树。

## 文档和静态审计

```sh
rg -n 'CouncilRunner|WorkCommand|CouncilMockState|--mock.*work' \
  AGENTS.md README.md NOTICE.md docs Apps Packages
rg -n 'agentProvider\(for: agent\.modelBinding\)|modelAssignmentPolicy|taskReviewPolicy' \
  Apps Packages
git diff --check
git status --short
```

第一条允许在明确说明“已删除/已退役”的文档、CLI rejection 文案和 legacy compatibility test 中命中；不得命中 shipping executor 或 mock UI 实现。

## Lint / format 与报告边界

仓内没有 SwiftLint/SwiftFormat 配置。不要声称运行了不存在的 lint；以编译、tests、`git diff --check` 和 Xcode build 为准。

- 纯文档任务至少运行 `git diff --check` 与 `git status --short`，并明确“未运行构建/测试”。
- 代码任务按风险运行上述标准、定向和 app 验证。
- 只有当前命令输出可作为本轮通过证据；历史日志、测试文件存在、或其他任务曾经运行过都不能替代最终验证。

## 2026-07-26 验证时间边界

- 本轮最终全量 SwiftPM suite：554 tests executed、14 skipped、0 failures。
- `JudgeLifecycleTests`：7/7 通过，覆盖 health、orphan restore、queue-inclusive deadline、timeout/cancel quarantine，以及 provider-late 和 post-settlement 两类 shutdown race。
- 本轮 `swift build --product councis`、`swift build --product CouncisMac` 与 IntatisMac Xcode scheme 无签名构建通过。
- 真实 endpoint、浏览器 opt-in smoke、签名与真机验证仍不在上述离线结果内；14 个 skip 是显式 opt-in 的真实浏览器 smoke。
