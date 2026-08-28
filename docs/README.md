# Councis 文档索引

当前产品基线：**v0.10**（build 49）
最近核对：2026-08-28

Councis 当前是 Intatis 的第一方下游产品，不再维护来源快照。当前事实从 `Package.swift`、
`project.yml`、Councis App/CLI host和`../Intatis`实际public surface共同确定。

## 当前规范

| 文档 | 权威范围 |
|---|---|
| `COUNcis_IDENTITY.md` | 下游产品定位、实现所有权、功能/UI保持边界 |
| `INTATIS_INTEGRATION.md` | Intatis local dependency、Runtime、删除边界与升级合同 |
| `VERSIONING.md` | marketing version和build number |
| `CURRENT_STATE.md` | 当前接线、验证与缺口 |
| `PROJECT_MAP.md` | 两仓目录、target、入口与数据路径 |
| `ARCHITECTURE.md` | Codex Runtime、dynamic tools、Cowork、MCP、持久化与生命周期 |
| `DO_NOT_BREAK.md` | 单一共享源码、无fallback、安全、UI和发行禁区 |
| `TESTING.md` | 下游contract、CLI、App、GUI和发行验证 |
| `MACOS_DISTRIBUTION.md` | Developer ID与runtime bundle合同 |
| `OPEN_SOURCE_REUSE.md` | Intatis第一方依赖与下游license责任 |
| `COWORK_PRINCIPLES.md` | Codex-native Cowork边界 |
| `AI_PROVIDER_MODEL_CONFIGURATION.md` | Councis config到Responses route的安全投影 |

根 `AGENTS.md` 是操作入口。根 `ARCHITECTURE.md` 只保留指向当前架构的兼容链接。

## Intatis 合同

Runtime 接入任务同时读取：

- `/Users/vita/Vitemis/Intatis/docs/CODEX_RUNTIME_INTEGRATION.md`
- `/Users/vita/Vitemis/Intatis/Packages/IntatisCodexRuntime/Sources/`
- `CodexRuntimePublicContractTests`

Councis不复制这些内容；构建直接使用当前Intatis checkout。

## 历史文档

旧 `COWORK_*`、`INTATIS_MULTI_AGENT_MIGRATION_AUDIT.md`、dated reports和旧identity migration文档只说明
快照时期发生过什么，不是当前runtime事实。若它们与当前manifest/source或上方规范冲突，以当前事实为准。

`SNAPSHOT.md` 已删除；不得恢复为更新机制。

## 维护纪律

- Intatis实现升级在Intatis仓库完成，Councis只重新构建/验证，不复制diff。
- Councis文档只记录下游product host差异和实际dependency revision/状态。
- `NEXT_TARGET.md`只在存在尚未完成的单一目标时创建；当前迁移目标已完成，因此文件不存在。
- 不批量改写历史报告、第三方许可证或runtime version。
- 版本变化必须运行`scripts/check-version-consistency.sh`。
