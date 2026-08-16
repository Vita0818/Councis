# NEXT_TARGET

文档状态：上一项用户确认目标已完成；等待用户指定下一目标

最近核对：2026-08-15

产品基线：v0.48（build 48）；来源提交标题：v0.54

## 已完成目标：Councis 最小产品差异

在固定 Intatis source tree
`120eda64fcb098f1bdc4852fee886450e80b3722` 上，已经按用户确认的精确范围完成：

- 保留并重新验证 Councis 品牌覆盖；
- macOS 初始产品面固定为 Cowork，Chat/Code/模式切换仅隐藏，源码、runtime 与历史数据未删除；
- fresh Cowork 以同一 settings-first 十事件 batch 原子登记 `@main`、固定 ordinary read-only
  `@judge` 与 `@permission-reviewer` 的独立 identity/workspace/capability lease；
- macOS 与 modern CLI 支持 canonical 顶层 `judge_model`，字段缺失只继承同一 JSON 文档的顶层
  `model`，显式非法或不可证明配置 fail closed；未新增 Judge UI 或 session setting；
- `@judge` 不可 spawn/remove/rebind，不进入省略目标/auto delegation，不获得 coordinator、
  run-control、权限审查或 Goal verification authority；Main 只能通过既有显式 data-plane 路径使用它；
- Main/Judge system prompt 与 bundled `cowork-agent-orchestration` Skill 已加入可选的多候选 + Judge
  比较建议；这只是调度建议，不是强制运行时仪式；
- 已补充配置继承/非法值、三身份原子 bootstrap、独立 exact binding、Judge 固定边界、显式路由与
  prompt 的直接回归。

对应当前事实见 `docs/COUNcis_IDENTITY.md`、`docs/CURRENT_STATE.md`、`docs/ARCHITECTURE.md`、
`docs/DO_NOT_BREAK.md` 与 `docs/COWORK_PRINCIPLES.md`。

## 当前边界

- 不回到 `/Users/vita/Vitemis/Intatis` 修改源码，也不恢复 `Upstream/Intatis` 双树结构。
- 不更名 Swift target/module/type、bundle ID、可执行文件、CLI、配置或持久化命名空间。
- 不删除被隐藏的 Chat/Code 实现，不改变 iOS Chat-only 产品边界。
- 不给 Judge 新增 UI、设置页、权限审查、Goal verdict、run control、自动 delegation 或递归协调能力。
- 不自动继承 Intatis 的 Developer ID 公证/发行任务，也不默认构建 legacy Mac App Store target。

## 等待下一指令

当前没有自动延伸的业务源码目标。下一步只能由用户明确指定；在此之前不要继续增加 Judge 功能、
恢复 Chat/Code 可见入口、改内部 Intatis 命名，或启动发行/提交工作。
