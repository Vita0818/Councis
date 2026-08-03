# Councis 产品身份与方向

文档状态：项目方向；不是当前实现清单  
最近核对：2026-08-03

## 当前事实

Councis 当前代码树是 Intatis v0.32 工作树快照的直接副本。源码、测试、工程名、模块名、
产品 target、bundle ID、配置/存储命名空间和运行时行为仍沿用该基线；Apple App 的系统显示名、
界面标题和用户可见品牌文案已经以纯文本替换恢复为 Councis。仓库不再保留
`Upstream/Intatis`，后续工作必须直接在根工作树上演进。

此前 Councis v0.4 的专用功能实现仍可从本仓库 Git 历史恢复，但没有叠加到当前基线。这样可以
避免把旧版 API 和新 v0.32 runtime 机械拼接，也避免产生一份“参考快照”和一份“实际源码”
长期漂移的双树结构。

## 必须保留的产品方向

Councis 仍定位为建立在 Intatis Cowork 内核之上的异构模型协作产品。后续重新实现时应保留：

- `@main`、`@judge` 与活跃 worker 使用明确、可恢复的 inference binding，并执行团队级
  唯一性策略；worker 不应无条件继承父 agent 的模型。
- 每个用户 root task 在公开答案前经过独立、固定、只读的 `@judge` 数据平面审查；无效、
  超时、缺失或轮次耗尽默认 fail closed。
- Judge 回传仍经过 TaskGraph、scheduler、MessageBus 与 Mediator，不能读取未经中介的
  provider 原始结果作为最终裁决。
- raw Main 草稿、raw Judge 输出和内部协作工具参数/结果仅用于审计与上下文；只有同一 root
  attempt 已持久化 approve 后的最终结果可以对用户展示。
- `@permission-reviewer` 是权限控制平面，不等于负责结果质量的 `@judge`，两者的身份、lease、
  prompt、事件与失败边界必须分离。
- Chat 与 Work 可以共享 Cowork runtime，但必须通过显式 capability/workspace envelope 区分；
  Chat 不得获得工作区副作用能力。
- 当前只恢复 Councis 的可见品牌文字；若未来重新引入并行的 Councis/Intatis 产品二进制，
  届时才必须隔离持久化目录、偏好设置和凭据命名空间，并保持迁移路径可审计。

## 实现纪律

以上条目目前是目标，不是验收通过的功能。重新落地时应优先利用 v0.32 已有的 exact
`AgentInferenceBinding`、Orchestrator、Goal/WorkTask、MCP、Skills、权限和 EventLog 能力，
逐项实现并增加回归测试；不得直接把旧 v0.4 文件覆盖回新基线，也不得在文档中提前写成
“已完成”。

任何重新引入的 Councis 产品面都应同步更新 `README.md`、`docs/CURRENT_STATE.md`、
`docs/PROJECT_MAP.md`、`docs/ARCHITECTURE.md`、`docs/TESTING.md` 和 `NOTICE.md`。
