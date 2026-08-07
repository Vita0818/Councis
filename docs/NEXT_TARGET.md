# NEXT_TARGET

文档状态：上一目标已实现；等待用户指定下一目标
最近核对：2026-08-06
产品基线：v0.36（build 36）

## 已完成目标：在现有 Cowork 中增加固定 `@judge`

Councis 已在 fresh Cowork session 中增加第三个固定身份 `@judge`，并通过 Main/Judge
系统提示词与 Cowork Skill 提供多 Agent 尝试和 Judge 比较的协作建议。现有 Cowork 工作流程、
运行时和产品结构保持不变。

## 已确认合同

- 当前 Intatis 快照是唯一实现树；后续直接在 Councis 根目录修改，不建立 `Upstream/Intatis`。
- fresh session 通过同一原子十事件 batch 固定登记 `@main`、`@permission-reviewer` 与
  `@judge`；初始化不调用模型/provider。
- `@judge` 直接使用现有 Cowork 的 Agent、任务和消息机制，并返回普通文本。
- Main 自主决定 Sub-agent 数量、模型、策略、任务和 Judge 的使用方式；系统提示词与 Skill 只给
  建议，不改变现有工作流程。
- 已完成可见品牌覆盖、macOS Cowork-only 根入口、`@judge` 固定身份、`judge_model` 配置解析及
  Main/Judge 提示词与 Cowork Skill 修饰。

## 已实现范围

1. 在 fresh Cowork session 中登记固定 `@judge`。
2. 让 Main 能通过现有 Cowork 机制使用 Judge。
3. 调整 Main/Judge 系统提示词与 Cowork Skill，同时保留 Main 的动态决策权。
4. 为以上差异补充必要的最小测试。
5. 新增 canonical `judge_model`；缺失时继承 `model`，显式无法解析时 fresh 创建 fail closed。

## 边界

固定 `@judge` 与相关提示词/Skill 不得修改其余 Cowork 行为。已完成的 macOS
Cowork-only 根入口只是独立的产品表面收口，不授权改变工作流。Main 不受固定的 Sub-agent 数量、
模型或策略限制；来源快照中的 Intatis v0.36 发版临时任务也不自动成为 Councis 目标。

当前没有自动推断的新目标；等待用户明确指定下一项修改。
