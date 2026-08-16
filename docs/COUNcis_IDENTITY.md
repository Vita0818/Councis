# Councis Cowork 特性定位

文档状态：项目定位、已实现有限差异与边界
最近核对：2026-08-15

## 一句话定位

Councis 是 **Intatis 现有 Cowork 的有限产品表面、角色与提示词修饰**：macOS 直接呈现 Cowork，
不显示 Chat/Code/Cowork 模式切换；fresh Cowork session 在现有 `@main` 与
`@permission-reviewer` 之外固定登记数据面身份 `@judge`，并通过系统提示词和 Skill 建议 Main
按需使用多 Agent 尝试与 Judge 比较。这些差异复用既有 Cowork 工作流、权限与持久化机制，
不另建一套 Judge 编排或控制面。

## 当前事实

当前业务树直接采用 Intatis 干净提交
`120eda64fcb098f1bdc4852fee886450e80b3722`；提交标题为 `v0.54`，`project.yml` 定义的产品
版本是 `0.48 (48)`。工程名、模块名、产品 target、bundle ID、可执行文件、配置/存储命名空间
和运行时行为仍是该 Intatis 快照事实；用户可见 UI 品牌已单独覆盖为 Councis。

2026-08-14 的整体基线替换没有保留旧 Councis 业务源码差异。2026-08-15 已按用户随后明确的
两个有限范围重新实现：用户 UI 控制面的 Councis 品牌覆盖，以及 macOS Cowork-only 可见入口、
fresh Cowork 固定 `@judge`、`judge_model`、Main/Judge prompt 与 Cowork Skill。源码仍保留
Chat/Code 的实现、session 数据与 runtime；这里的 Cowork-only 是隐藏产品入口，不是删除能力。

仓库没有 `Upstream/Intatis` 或另一份实现树；后续功能直接修改 Councis 根工作树。精确来源、
tree、复制边界和排除项见 `docs/INTATIS_BASELINE.md`。旧 Councis 代码只可作为 Git 历史证据，
不能机械覆盖新基线；重新实现时必须根据 `v0.54` 当前源码逐项做最小改动和回归验证。

## 已实现的有限差异

- macOS 与 iOS 的 App 显示名、应用内标题/标签/输入提示、系统麦克风说明、iOS Settings bundle、
  MCP 授权/批准交互、诊断导出用户说明及共享 GUI 错误中的产品品牌显示为 `Councis`。
- macOS 根界面不显示 Chat、Code 或 Cowork 模式入口；窗口初始选择固定为 Cowork，侧栏只投影
  Cowork Recent，`+` 沿用现有 Cowork workspace 选择与新建流程。
- fresh Cowork session 在任何模型请求前以一个 settings-first 十事件 batch 原子登记 `@main`、
  `@judge` 与 `@permission-reviewer` 各自的 workspace lease、capability lease 和 identity。三者共享
  用户选择的 canonical workspace，但 identity、lease 与 exact inference binding 相互独立。
- `judge_model` 是 macOS/modern CLI 高级 JSON/JSONC 配置的 canonical 顶层字段，不增加任何
  Judge UI、picker 或 session setting。值必须解析为 enabled provider 中已配置的
  `<provider>/<model-id>` base profile；字段缺失时只在解析该 JSON 文档时一次性继承同一文档的
  顶层 `model`。显式 `null`、错误类型、空值、未知/禁用 route、不可解析引用或整份配置损坏均
  fail closed；不得回退 Chat/Cowork UI selection、session default、live/historical `@main` 或后续 rebind。
- `@judge` 是 host bootstrap 管理的固定只读 ordinary data-plane agent：Main 不能 spawn/remove
  或 rebind 该身份，自动 worker 选择不会选中它，Judge 自身没有 coordinator 或 run-control 工具；
  Main 可以通过现有显式 delegation/task/message/ask 路径使用它。
- Main 继续自主决定是否创建 Sub-agent、创建多少个，以及它们的配置、模型、策略和任务；Main 也
  自主决定何时、如何使用 Judge。
- Main/Judge 系统提示词与 Cowork Skill 可以建议“让多个 Agent 处理同一问题，再由 Judge 比较”。
  这些内容是建议，不是新的运行时规则。
- Judge 通过现有 Cowork 机制接收任务并返回一段普通文本。比较、选择、改写或综合等具体行为由
  Main 的任务说明、系统提示词和 Skill 决定；Judge 报告只是候选证据，最终产品与编排决定仍由 Main
  负责。

## 保持不变

- Cowork 现有工作流程和运行机制保持不变；Judge 直接使用已有的 Agent、任务、消息、权限、持久化
  与恢复能力。
- `@permission-reviewer` 仍只负责权限审查，Goal Verifier 仍负责原有职责；`@judge` 不替代它们。
- 既有非空历史 session 不被自动补写 Judge；fresh bootstrap 与已经持久化的 Judge 可恢复 roster
  分别沿用现有路径。没有新增 EventLog event type、Envelope 字段或 session schema。
- macOS Chat/Code 的可见入口被隐藏，但其继承实现、session 数据和 runtime 合同不因这一步改变。
- iOS 仍是原有 Chat 子集；除已覆盖的 App/UI 显示品牌外，其运行时不变。CLI 以及内部工程命名、
  配置和存储命名空间保持 Intatis 基线。
- 没有更名 Swift target/module/type、bundle ID、可执行文件、App 图标资源、配置/存储路径、内部
  日志/协议 schema、标识符或命名空间。

## 实现纪律

后续维护只可在上述有限差异内做必要的最小修改，并继续复用当前 Cowork 实现。不得把 Judge
扩展成权限审查者、Goal Verifier、run authority、自动 worker、递归 coordinator 或新的 UI/设置面；
也不得因为 Chat/Code 入口隐藏而删除其源码、session 兼容或 runtime。每项变化只同步真正受影响的
文档与测试，未受影响的 Intatis 基线保持不变。
