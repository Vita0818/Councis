# Councis 文档索引（固定 Intatis v0.54 来源基线）

当前产品基线：**v0.48**（build 48）
最近核对：2026-08-17

这个索引区分“当前规范”和“历史证据”。版本、产品状态或下一步判断只允许从当前规范
读取；带旧版本号的历史文件保留用于解释迁移和兼容性，不能覆盖当前源码。

Councis 根工作树当前直接来自 Intatis 提交 `120eda64fcb098f1bdc4852fee886450e80b3722`
（标题 `v0.54`，产品版本仍由 `project.yml` 定义为 `0.48 (48)`）。当前已完成 Councis
SwiftPM/Xcode/App/CLI/config/storage/log/protocol canonical identity；唯一 App 为 macOS
`Councis.app` / `CouncisMac` / `com.Vita0818.Councis`，iOS 与 legacy Mac App Store 产品面已删除。
macOS 继续只显示 Cowork，fresh Cowork 固定 `@judge`，Chat/Code 实现与历史兼容仍保留。
当前事实与目标边界见 `COUNcis_IDENTITY.md`，精确来源、保留文档和排除项见
`INTATIS_BASELINE.md`。

## 当前规范

| 文档 | 权威范围 |
|---|---|
| `COUNcis_IDENTITY.md` | Councis 完整产品身份、固定 `@judge`、canonical namespace、legacy/provenance 边界 |
| `COUNcis_DECOUPLING_CHECKLIST.md` | 2026-08-17 底层脱钩决策、批次、legacy 白名单与验收矩阵 |
| `INTATIS_BASELINE.md` | Intatis 快照来源、tree、复制边界、排除项与核验方式 |
| `VERSIONING.md` | 产品版本与 build number 的唯一治理规则 |
| `CURRENT_STATE.md` | 当前 Councis 产品图、canonical/legacy identity、验证与风险 |
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
| `NEXT_TARGET.md` | 已完成的底层品牌脱钩边界与等待用户指定的下一目标 |

根 `README.md` 是当前 Councis 产品入口；根 `ARCHITECTURE.md` 仅为兼容链接，架构正文
只维护在 `docs/ARCHITECTURE.md`。根 `AGENTS.md` 是 Councis 操作入口；它与上述两份 Councis
专属文档定义项目边界。

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
- `NEXT_TARGET.md` 只保留一个经用户确认的 Councis 目标，完成后删除或替换。
- `TESTING.md` 保存当前命令和最新证据；旧性能数字或事故细节留在报告中。
- 不批量替换依赖、协议、schema、历史里程碑中的版本号。
- 修改产品版本后必须运行 `scripts/check-version-consistency.sh`；任何活跃 identity 变更还必须运行
  `scripts/check-brand-boundary.sh`。
