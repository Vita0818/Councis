# Councis 文档索引（Intatis 快照基线）

当前产品基线：**v0.36**（build 36）
最近核对：2026-08-06

这个索引区分“当前规范”和“历史证据”。版本、产品状态或下一步判断只允许从当前规范
读取；带旧版本号的历史文件保留用于解释迁移和兼容性，不能覆盖当前源码。

Councis 直接继承 Intatis 快照，只在现有 Cowork 上增加固定数据面身份 `@judge`，并通过
Main/Judge 系统提示词与 Cowork Skill 提供协作建议；它不改变 Cowork 工作流程，也不是整个产品
的重设计。先读 `COUNcis_IDENTITY.md` 确认范围，再用其余当前规范理解继承实现；精确来源见
`INTATIS_BASELINE.md`。除项目覆盖段落外，继承文档描述的是当前 Intatis 基线事实；`@judge`
修饰、`judge_model` 及其测试状态以当前规范和源码为准。

## 当前规范

| 文档 | 权威范围 |
|---|---|
| `COUNcis_IDENTITY.md` | Councis 固定 `@judge` 身份、提示词/Skill 修饰、范围与非目标 |
| `INTATIS_BASELINE.md` | Intatis 快照来源、manifest、复制边界与项目覆盖规则 |
| `VERSIONING.md` | 产品版本与 build number 的唯一治理规则 |
| `CURRENT_STATE.md` | Intatis 快照能力、验证状态，以及 Councis 文档/实现状态 |
| `PROJECT_MAP.md` | 当前目录、target、入口、关键文件和脚本 |
| `ARCHITECTURE.md` | 当前运行时链路、数据模型、安全与平台边界 |
| `CHAT_HOSTED_SEARCH.md` | 当前模型自主托管搜索、接入点适配、静默不搜索与实现边界 |
| `DO_NOT_BREAK.md` | 协议、持久化、权限、工具与 UI 回归禁区 |
| `TESTING.md` | 当前测试矩阵、命令和最近一次证据 |
| `MACOS_DISTRIBUTION.md` | Developer ID 直接分发合同 |
| `OPEN_SOURCE_REUSE.md` | 第三方源码、prompt、依赖和 NOTICE 准入 |
| `COWORK_PRINCIPLES.md` | 当前 Cowork/AgentKernel 编排原则 |
| `PER_AGENT_INFERENCE_PROFILES.md` | per-agent exact inference binding 契约 |
| `CURRENT_UI_COLOR_SYSTEM.md` | 当前 Apple 原生表面与 Liquid Glass 规范 |
| `NEXT_TARGET.md` | Councis 唯一下一目标；不得自动继承 Intatis 临时发版任务 |

根 `README.md` 仍是当前 Intatis 快照的产品入口；根 `ARCHITECTURE.md` 仅为兼容链接，架构正文
只维护在 `docs/ARCHITECTURE.md`。根 `AGENTS.md` 是 Councis 操作入口；它与上述两份 Councis
专属文档定义项目边界，不把尚未实现的 Cowork 特性写成当前能力。

## 操作政策与供应链资料

下列文件不是产品状态页，不应复制当前版本号：

- 根目录与 `docs/` 下的 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md`：agent 操作规则或继承入口；
- `NOTICE.md`、`ThirdPartyNotices/` 和依赖附带的 README/LICENSE：来源与许可证证据；
- `.agents/skills/` 下的文档：项目级 skill 说明；
- `codex-report/`、`claude-report/`、`gemini-report/`：按日期冻结的执行报告。

这些资料保留自己的规则、依赖版本或历史日期。不得为追齐 Intatis marketing version 而
批量替换其中的版本数字。

## 历史设计与验证

以下文件冻结旧阶段，不再作为当前事实源：

- `COWORK_AGENT_ARCHITECTURE.md`
- `COWORK_AGENT_INVOCATION_MODEL.md`
- `COWORK_CURRENT_FINDINGS.md`
- `COWORK_MIGRATION_PLAN.md`
- `COWORK_TASK_CONTEXT_MODEL.md`
- `COWORK_V0_10_SMOKE.md`
- `COWORK_V0_10_STATUS.md`
- `UI_COLOR_SYSTEM.md`
- 根 `design-qa.md`
- `codex-report/`、`claude-report/`、`gemini-report/` 中的 dated reports

历史文档里的版本、测试数量、截图路径和环境结果只能说明当时发生过什么。若它们与
当前源码、工程配置或上方当前规范冲突，以源码/配置和当前规范为准，并记录冲突。

## 维护纪律

- 当前状态文档保持摘要化；完成事项留在 Git 历史和 dated report，不继续无限追加。
- `NEXT_TARGET.md` 只保留一个经用户确认的 Councis 目标；来源快照中的临时发版目标不自动继承。
- `TESTING.md` 保存当前命令和最新证据；旧性能数字或事故细节留在报告中。
- 不批量替换依赖、协议、schema、历史里程碑中的版本号。
- 修改产品版本后必须运行 `scripts/check-version-consistency.sh`。
