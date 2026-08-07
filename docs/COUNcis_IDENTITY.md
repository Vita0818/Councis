# Councis Cowork 特性定位

文档状态：项目定位与目标边界；不是当前实现清单
最近核对：2026-08-06

## 一句话定位

Councis 是 **Intatis 现有 Cowork 的有限产品表面、角色与提示词修饰**：macOS 直接呈现 Cowork，
不显示 Chat/Code/Cowork 模式切换；fresh Cowork session 在现有 `@main` 与
`@permission-reviewer` 之外固定登记数据面身份 `@judge`，并通过系统提示词和 Skill 建议 Main
按需使用多 Agent 尝试与 Judge 比较。这些差异不改变 Cowork 工作流程或运行时。

## 当前事实

当前业务树直接采用 Intatis 干净提交
`2d849dbe592a4532a23d0b5a0f84c4e52e459505`；提交标题为 `v0.37`，`project.yml` 定义的产品
版本是 `0.36 (36)`。工程名、模块名、产品 target、bundle ID、可执行文件、配置/存储命名空间
和运行时行为仍是该快照事实。当前已实现的产品覆盖包括：把 macOS、iOS、CLI 及其直接面向用户
的提示、权限说明、诊断导出名称和浏览器授权身份显示为 `Councis`；以及在 macOS 根侧栏隐藏
Chat/Code/Cowork 三个模式按钮、默认呈现 Cowork，并让侧栏 `+` 新建 Cowork session。这些变化
没有迁移内部命名空间，也没有删除继承的 Chat/Code 实现。

当前 fresh Cowork session 以同一原子十事件 batch 登记 settings，以及 `@main`、权限控制面的
`@permission-reviewer` 和只读数据面的 `@judge` 各自独立的 workspace/capability lease 与
identity。Judge 使用顶层 `judge_model` 对应的 exact inference binding；字段缺失时继承配置的
`model`，显式值无法解析时 fresh session 创建失败，不静默回退。注册本身不调用 provider；已有
历史 session 不自动补建 Judge。仓库没有 `Upstream/Intatis` 或另一份实现树；后续功能直接修改
Councis 根工作树。精确来源、manifest 和复制边界见
`docs/INTATIS_BASELINE.md`。旧 Councis v0.4/v0.5 代码只可作为 Git 历史证据，不能机械覆盖快照。

## 已确认差异

- macOS 根界面不显示 Chat、Code 或 Cowork 模式入口；窗口初始选择固定为 Cowork，侧栏只投影
  Cowork Recent，`+` 沿用现有 Cowork workspace 选择与新建流程。
- fresh Cowork session 增加第三个固定身份 `@judge`。
- `@judge` 是 host bootstrap 管理的固定只读 ordinary data-plane agent：Main 不能 spawn/remove
  该身份，自动 worker 选择不会选中它，但 Main 可以通过现有显式 delegation/task/message 路径使用它。
- Main 继续自主决定是否创建 Sub-agent、创建多少个，以及它们的配置、模型、策略和任务；Main 也
  自主决定何时、如何使用 Judge。
- Main/Judge 系统提示词与 Cowork Skill 可以建议“让多个 Agent 处理同一问题，再由 Judge 比较”。
  这些内容是建议，不是新的运行时规则。
- Judge 通过现有 Cowork 机制接收任务并返回一段普通文本。比较、选择、改写或综合等具体行为由
  Main 的任务说明、系统提示词和 Skill 决定。

## 保持不变

- Cowork 现有工作流程和运行机制保持不变；Judge 直接使用已有的 Agent、任务、消息、权限、持久化
  与恢复能力。
- `@permission-reviewer` 仍只负责权限审查，Goal Verifier 仍负责原有职责；`@judge` 不替代它们。
- macOS Chat/Code 的可见入口被隐藏，但其继承实现、session 数据和 runtime 合同不因这一步改变；
  iOS、CLI 以及内部工程命名、配置和存储命名空间保持不变。

## 实现纪律

已实现部分只为固定 `@judge` 身份、`judge_model` 解析、Main/Judge 系统提示词和 Cowork Skill
建议做必要的最小修改，并复用当前 Cowork 实现。后续每项变化仍只同步真正受影响的文档；未受
影响的 Intatis 基线不改。
