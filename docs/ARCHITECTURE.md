# ARCHITECTURE

最近自查日期：2026-06-25

## 总体架构

本仓库同时承载两个产品：

- **Councis** — CLI-first 原型，"council" 模式（多候选并行 + judge 评审）。
- **Intatis** — 全量 macOS/iOS app，单 agent 工具循环 + 多 agent Cowork 编排。

二者共享底层 `Intatis*` 模块（Core/Protocol/Providers/Conversation 等），但 agent 执行模式不同：Councis CLI 的 council 引擎直接基于 `OpenAIWireProvider`，**不走** `AgentKernel`/`Cowork`；IntatisMac 的 Cowork 走完整内核。

```text
                    ┌─────────────────────────────────────┐
                    │      Intatis* 内核模块（共享）        │
                    │  Core / Protocol / Providers         │
                    │  Conversation / Artifacts / Multimodal│
                    └──────────────┬──────────────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
   ┌────────▼─────────┐  ┌────────▼─────────┐  ┌─────────▼──────────┐
   │  Councis CLI      │  │  IntatisMac       │  │  IntatisiOS        │
   │  council 引擎     │  │  Cowork 内核      │  │  Chat 子集         │
   │  (OpenAIWire)     │  │  (AgentKernel)    │  │  (ChatLoop)        │
   └───────────────────┘  └───────────────────┘  └────────────────────┘
            │
   ┌────────▼─────────┐
   │  CouncisMac       │
   │  Mock SwiftUI 壳  │
   │  (不依赖内核)     │
   └───────────────────┘
```

## 主要链路

### Council 链路（Councis CLI 实际使用）

```text
用户命令 -> IntatisCLI.main() switch
  -> runChatCommand / runWorkCommand / runCouncilCommand(已废弃→chat)
  -> CouncilRunner (Council.swift)
       withTaskGroup: 并行候选模型 (OpenAIWireProvider.stream)
       -> 收集候选答案
       -> Judge 模型评审 (OpenAIWireProvider)
       -> finalAnswer（fail-soft: minSuccessfulCandidates 不足时降级）
  -> WorkCommand.runWorkCouncil (work 模式)
       自带 PathConfinement + approveWrite() [y/N] 提示
       （不走 PermissionEngine）
  -> 输出 + 写 .councis/runs/run-<ts>-<UUID>.json
```

关键不变量：
- Council 引擎不递归、不 spawn agent；候选并行、judge 一次性合成。
- Work 模式的写审批是交互式 `[y/N]`，不是内核 3 层门。
- Preset 不含 API key；key 从 env / config 解析。

### Cowork 链路（IntatisMac 使用）

```text
CoworkViewModel -> Orchestrator (actor)
  -> AgentRegistry / MessageBus(log:, mediator:) / PermissionEngine
  -> attach(agent) -> log agent_attached
  -> send(text, to:@mention) -> 路由到目标 agent
  -> 为每次 run 构建 AgentLoop + BusMessenger + OrchestratorManager
       coordinator(canCoordinate=true) -> ToolRegistry.standard + [AskAgent/Spawn/List/Remove]
       worker -> ToolRegistry.standard 仅
  -> AgentLoop.send() 循环（maxIterations 默认 50）
       ContextBuilder.initialMessages (system + priorHistory 投影 + user)
       -> provider.stream -> message_delta
       -> toolCalls -> runTool -> PermissionEngine.decide
            askUser -> PermissionResponder -> UI 卡片 (CheckedContinuation)
       -> ToolObservation 回填 -> 重复直至无 tool call
  -> 每次状态变更 append 到 EventLog
MessageBus.deliver -> Mediator.mediate
  -> SecretScanner.containsSecret -> block
  -> content.count > maxChars(4000) -> block "send a summary"
  -> ForwardingReviewer(可选)
  -> .forward (log agent_to_agent_message + permission_review allow)
```

关键不变量：
- 两级层级，无递归 spawn；worker 默认无 coordinator 工具。
- `@main` agent 不可被 remove。
- MessageBus 是唯一投递路径；Mediator 默认转发摘要不转发原始字节。
- 任何 model tool_call 到执行都必须过 PermissionEngine，无旁路。

### Chat 链路（iOS / 无工具子集）

```text
ChatLoop.send() -> buildHistory() from EventLog
  -> append userMessage -> provider.stream
  -> message_delta / message_completed -> turnStats
（无工具、无权限、无工作区，故 iOS 可链接子集而不引入 shell/workspace）
```

### 多模态链路

```text
MultimodalService.generateImage/transcribe/generateVideo(轮询 job)
  -> provider 调用 -> ArtifactStore 写入
  -> log: artifact_added / artifact_progress
```

## 数据模型

| 类型 | 职责 | 持久化方式 | 关键字段约束 |
|---|---|---|---|
| `Envelope` | 事件信封 | JSONL 一行一个 | `seq` 单调递增；`v:1`；18 种 `type` |
| `Event` | 事件 payload 联合 | 随 Envelope | 追加演进；replay 时不可解码行跳过 |
| `Agent` | agent 值类型 | 内存 | `canCoordinate: Bool`；默认 profile `.reviewed` |
| `Capability` | provider 能力枚举 | 配置 | chat/tool_calling/vision/realtime/audio/image/video/embedding |
| `PlatformProfile` | 平台能力信封 | launch-time | `.iOS`（最受限）/`.macAppStore`/`.macDeveloperID`；`current` 默认 `.iOS` |
| `PermissionProfile` | 每 agent 模式 | agent | manual/reviewed/autopilot/read_only/locked；硬 DENY 优先 |
| `Artifact` / `ArtifactRef` | blob + 索引 | blobs/<id>.<ext> + index.json | ISO-8601 日期；pretty JSON |
| `CouncilPreset` | council 配置 | `.councis/presets/<name>.json` | 候选/judge/minSuccessfulCandidates/failSoft；**不含 key** |
| `CouncilRunLog` | 运行日志 | `.councis/runs/run-*.json` | surface/preset/prompt/mock/candidateResults/judgeResult |

## 同步 / 通信机制

- **进程内**：v0.1 内核全进程内运行。`Orchestrator`/`EventLog`/`MessageBus` 均为 `actor`。
- **JSON-RPC 2.0 词汇**已定义（`JSONRPC.swift`：Command→request、Envelope→event notification），但**尚未挂传输**。未来 `intatis agent --stdio` / `intatis daemon` 是规划中管道。`UNKNOWN` — 当前无 out-of-process 传输实现。
- **Provider 线协议**：OpenAI 兼容 HTTP/SSE（`/chat/completions` streaming）。`WireFormat.openai` 是唯一 shipped 格式。

## 安全机制

### 凭据存储
- `KeychainStore`（GUI）：generic-password item，service `com.intatis.app`/`com.intatis.ios`，account `default-openai`。配置只存 `KeychainRef(service, account)` 引用，不存秘密；`KeychainSecretResolver` 懒加载。
- CLI：不用 Keychain；key 从 env（`COUNCIS_*` / legacy `INTATIS_*`）或 `~/.councis/config.json`（`chmod 0600`）解析。

### 工作区边界
- `PathConfinement.resolve`（`Core/PathConfinement.swift`）：拒 `..` 遍历与越界绝对路径。Tools 执行与权限门均使用。

### 权限 3 层门
1. `DeterministicPolicyGate`（纯函数、模型无关、runs first、`deny` 终局）：locked→deny；敏感路径→deny；路径越界→deny；read_only 下网络→deny；readOnly side-effect→allow；destructive→ask；exec→evaluateShell（`!allowsShell`→deny，dangerous→deny，network/install→ask，read-only cmd→allow，否则 pass）；write→evaluateWrite（read_only→deny，受保护配置→ask，否则 pass）。
2. `ModelPermissionReviewer`（模型评审）：只见 gate `pass`；只能收窄为 deny/ask，**不能**覆盖硬 deny；评审内容包为 untrusted `REVIEW_TARGET`，只读结构化 JSON 决策。
3. `PermissionEngine`（组合）：`pass` 且无 reviewer → `askUser`（v0.2 默认；v0.3 加 reviewer）。

### 秘密拦截
- `SecretScanner`：敏感路径/basename/扩展名、秘密内容标记（`-----BEGIN`、`PRIVATE KEY`、`AKIA`、`sk-`、`ssh-rsa`、`xoxb-`、`ghp_`、`AIza`…）、受保护配置路径（lockfile/CI/Dockerfile/Makefile）。
- `Mediator`：agent 间转发时拦截秘密 + 超长原始转储（>4000 字符要求发摘要）。

### Sandbox / Entitlements
- `IntatisMac.AppStore.entitlements`：`app-sandbox=true`、`network.client=true`、`files.user-selected.read-write`、`files.bookmarks.app-scope`。**无 `run_shell`**（AppStore 构建无法 shell）。
- `IntatisMac.DeveloperID.entitlements`：非 sandbox、Hardened Runtime（`allow-jit=false`、`disable-library-validation=false`）。须设置 `AppConfig.platformProfile = .macDeveloperID`。
- `Workspace.swift`：`NSOpenPanel` + `startAccessingSecurityScopedResource()` 处理用户选定工作区文件夹。

## 模式开关 / 内核切换

本项目无 Rokurics 式的新旧内核开关。但存在两套并存的 agent 执行模式：

- **Council 模式**（Councis CLI）：候选并行 + judge，无递归、无 spawn、无 3 层门（Work 模式用交互式审批）。
- **Cowork 模式**（IntatisMac）：完整内核，agent 图 + MessageBus + 3 层权限门。

二者不互通；CLI 声明了 AgentKernel/Cowork 依赖但当前仅服务于疑似死代码的 `Interactive.swift` REPL。

## 与文档/源码的关系

- 仓内根 `ARCHITECTURE.md` 是 Intatis 设计文档副本（draft-0, 2026-06-11），描述的是 Intatis 内核/Cowork 设计，**不**反映 Councis CLI 的 council 实现。本目录 `docs/ARCHITECTURE.md` 据实际源码重写。
- `not.txt` 内容为 "Councis work mock note"，是 mock Work 执行器在 prompt 说"create note.txt"时的写入内容（`WorkCommand.swift:125`）。
