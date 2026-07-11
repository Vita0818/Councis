# CURRENT_STATE

最近一次自查日期：2026-06-25

## 当前真实状态总览

- 仓库是 Intatis 内核模块 + IntatisMac/iOS app + Councis CLI/Mac 原型的合并体，v0.1.x 阶段。
- Git：4 个 commit（Initial / v0.1 / v0.1.1 / v0.1.2），remote `github.com/Vita0818/Councis`。MARKETING_VERSION 0.5.0（`project.yml:27`）。
- Councis CLI 的 council 引擎已实现并跑过 mock 运行（`.councis/runs/` 有 23 个日志，含 mock work 运行）。
- IntatisMac/iOS 的内核 Cowork 链路代码就绪，有测试覆盖，但真机 + 真实 key 的端到端验证状态 `UNKNOWN`。
- CouncisMac 是 mock SwiftUI 壳，不链接内核，仅用于 UI 预演。
- 仓内根 `ARCHITECTURE.md` 是 Intatis 架构文档的逐字副本，不反映 Councis CLI 实际实现——以本目录 `docs/` 为准。

## 已有能力

| 能力 | 入口 / 关键类型 | 测试覆盖 | 手动验证 | 真机验证 |
|---|---|---|---|---|
| CLI council chat | `IntatisCLI.swift` / `Council.swift` `CouncilRunner` | 无（council 引擎无单测） | mock 运行日志存在 | UNKNOWN |
| CLI council work | `WorkCommand.swift` `runWorkCouncil` | 无 | mock 运行日志（写 note.txt） | UNKNOWN |
| CLI config 管理 | `CLIConfig.swift` / `Settings.swift` | `IntatisCoreTests`？UNKNOWN | UNKNOWN | UNKNOWN |
| CLI preset 加载 | `Council.swift`（`.councis/presets/`） | 无 | UNKNOWN | UNKNOWN |
| IntatisMac chat | `IntatisMacApp` / `ChatViewModel` / `ChatLoop` | `IntatisConversationTests` | UNKNOWN | UNKNOWN |
| IntatisMac cowork | `CoworkViewModel` / `Orchestrator` / `AgentLoop` | `IntatisCoworkTests` / `IntatisAgentKernelTests` | UNKNOWN | UNKNOWN |
| IntatisMac multimodal | `MultimodalService` | `IntatisMultimodalTests` | UNKNOWN | UNKNOWN |
| IntatisiOS chat | `IntatisiOSApp` / `IOSAppEnvironment` | 无（SharedUI 无测试） | UNKNOWN | UNKNOWN |
| 权限 3 层门 | `PermissionEngine` / `DeterministicPolicyGate` / `ModelPermissionReviewer` | `IntatisPermissionTests` / `ReviewerTests` | UNKNOWN | UNKNOWN |
| CouncisMac mock UI | `CouncisMacApp` / `CouncilMockState` | 无 | UNKNOWN | 仅 mock |
| Provider OpenAI 兼容 | `OpenAIWireProvider` / `SSE.swift` | `IntatisProvidersTests` | UNKNOWN | UNKNOWN |
| 事件日志 | `EventLog`（JSONL append-only） | `IntatisConversationTests` | UNKNOWN | UNKNOWN |
| Artifact 存储 | `ArtifactStore` | `IntatisArtifactsTests` | UNKNOWN | UNKNOWN |

## 未完成 / 进行中

- **Interactive.swift REPL 疑似死代码**：358 行交互式 REPL（`/help`、`/mode` chat↔work），但 `main()` switch 无 case 触达。`IntatisCLI` 依赖 AgentKernel/Cowork 似仅为此 REPL。需确认是计划接入还是废弃。
- **Councis vs Intatis 关系未定**：README 称模块名 `Intatis*` 过渡性保留，但最终是 Councis 取代、共存还是回并，源码未声明。
- **JSON-RPC out-of-process 传输未挂**：`JSONRPC.swift` 词汇已定义，`intatis agent --stdio` / `intatis daemon` 是规划中管道，当前内核全进程内运行。
- **SwiftGit2/libgit2 集成**：规划用于 sandbox 内 in-process git，GPLv2-with-linking-exception 许可证待审查。
- **ModelPermissionReviewer 默认启用**：v0.2 默认 `askUser`（无 reviewer），v0.3 加 reviewer。当前版本是否已切到 v0.3 行为 `UNKNOWN`。
- **CouncisMac 接内核**：当前 mock 壳不链接内核。是否计划接真实 council 引擎 `UNKNOWN`。

## 风险

- **文档漂移**：根 `ARCHITECTURE.md` 是 Intatis 副本，与 Councis CLI 实际实现不符；`SelfTest.swift` 残留 `Mopelium selftest` 字符串；`note.txt` 内容易被误认为笔记。
- **双 agent 模式混淆**：CLI council 引擎与 IntatisMac Cowork 内核是两套独立实现，CLI 声明依赖 AgentKernel/Cowork 但实际未用（除疑似死代码 REPL），易误判。
- **clean-room 覆盖范围**：`NOTICE.md` 以 "Intatis" 名义声明，是否覆盖 Councis（复用 Intatis 模块）未明示。
- **真机验证缺口**：大量能力有测试但真机 + 真实 key 的端到端验证状态 UNKNOWN。
- **CLI 不用 Keychain**：与 GUI 凭据隔离不一致，CLI key 经 env/明文 config 文件，泄露面不同。

## 工作区状态

本轮自查（2026-06-25）为只读分析，未产生仓库改动。`git status` 应为 clean（除用户已有改动）。`.councis/runs/` 与 `.councis/config.json` 被 `.gitignore` 忽略；`.councis/presets/` 已提交。

## 文档与源码冲突

| 冲突位置 | 冲突内容 | 采用源码为准的原因 | 建议 |
|---|---|---|---|
| 仓内根 `ARCHITECTURE.md` vs `docs/ARCHITECTURE.md`（本目录） | 根文档标题"Intatis 架构设计"，draft-0，全文描述 Intatis 内核/Cowork 设计，未提及 Councis；与 Councis CLI 的 council 实现不符 | 源码 `Council.swift`/`WorkCommand.swift` 是 council 实际实现，直接基于 `OpenAIWireProvider`，不走 AgentKernel/Cowork | 以本目录 `docs/ARCHITECTURE.md` 为准；建议后续用本目录版替换仓内根文档 |
| `NOTICE.md` clean-room 声明署名 "Intatis" vs 仓库产品 "Councis" | NOTICE 以 Intatis 名义声明不复制竞品源码 | 仓库实际含 Councis 产品，复用 Intatis 模块 | 建议明确 clean-room 声明覆盖 Councis |
| `SelfTest.swift` "Mopelium selftest" vs 产品 "Councis" | selftest 输出字符串疑似从 Mopelium 复制残留 | 源码事实 | 建议改为 "Councis selftest" |
