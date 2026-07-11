# DO_NOT_BREAK

本文列出不可破坏的工程禁区、数据格式、协议、路径和回归要求。修改前必须确认不违反下列任一条目。

## 工程禁区

- 不执行破坏性 Git 操作：`git reset --hard`、`git clean -fd`、`git checkout .`、强制 push、删除未提交文件。
- 未经用户明文要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR；编辑、整理、修复、验证或准备工作都不等于提交请求。
- 若用户要求提交，只提交当前 Git root 中与本任务相关的文件；不得递归进入、暂存、提交或推送子仓库、submodule、nested Git repo 或依赖 checkout。
- 不引入新依赖，不改构建脚本，不改测试源码，除非任务明确要求。v0.1 零第三方依赖；计划中的 SwiftGit2/libgit2（GPLv2-with-linking-exception）须先过许可证审查。
- 不绕过 3 层权限门（`DeterministicPolicyGate` / `ModelPermissionReviewer` / `PermissionEngine`）、`PathConfinement`、`SecretScanner`、`Mediator` 秘密拦截或 Keychain 凭据隔离。

## 数据格式禁区

- **事件日志 JSONL**：`~/Library/Application Support/Intatis/<session>/events.jsonl`。一行一个 `Envelope`：`{seq, ts, session, v:1, type, payload}`。`seq` 单调递增（per session）；追加演进；replay 时不可解码行跳过（不得因部分行损坏而整体失败）。18 种 event `type`。
- **ArtifactStore**：blobs 在 `<root>/blobs/<id>.<ext>`，索引在 `<root>/index.json`（`[ArtifactRef]`）。ISO-8601 日期，pretty JSON。
- **GUI config**：UserDefaults 键 `intatis.baseURL`、`intatis.model`（mac/iOS 共用同一键名）。
- **CLI config**：`~/.councis/config.json`（JSON `[String:String]`，`chmod 0600`）。字段解析优先级：env（`COUNCIS_*`，legacy `INTATIS_*`）→ config 文件 → 默认。
- **Council preset**：`.councis/presets/<name>.json` 或 `~/.councis/presets/<name>.json`。`CouncilPreset` Codable。**不含 API key**。
- **Council run log**：`.councis/runs/run-<timestamp>-<UUID>.json`（gitignored）。`CouncilRunLog` Codable，pretty + sorted keys。
- **Provider 线协议**：OpenAI 兼容 HTTP/SSE（`/chat/completions` streaming）。`WireFormat.openai` 是唯一 shipped 格式。

> 这些格式承载真实会话数据或跨端契约，改名、重排字段、改单位、改编码都可能造成数据丢失或对端不识别。

## 协议禁区

- **Cowork 投递协议**：`MessageBus.deliver` 是唯一 agent 间投递路径。`Mediator.mediate` 必须先于转发运行（`.forward` / `.block`）。不得新增绕过 Mediator 的直投路径。
- **Coordinator 工具**：`spawn_agent` / `list_agents` / `remove_agent` / `ask_agent` 只对 `canCoordinate==true` 的 agent 暴露；worker 默认不得获得 coordinator 能力。`@main` agent 不可被 remove。
- **权限协议**：硬 DENY 终局；`ModelPermissionReviewer` 只能收窄不能放行；任何 model tool_call 到执行都必须过 `PermissionEngine`，无旁路。
- **JSON-RPC 词汇**：`Command`→request、`Envelope`→event notification 的映射已定义，但传输未挂。不得在未确认 out-of-process 传输设计前随意改词汇结构。

## 路径禁区

- **工作区根**：`PathConfinement.resolve` 拒绝 `..` 遍历与越界绝对路径。Tools 执行与权限门均依赖此约束。
- **受保护配置路径**：lockfile / CI / Dockerfile / Makefile 等（`SecretScanner.isProtectedConfigPath`）→ 写操作必须 `ask`，不得自动放行。
- **敏感路径**：`~/.ssh`、`~/Library/Keychains`、secret/token/key 目录等（`SecretScanner.isSensitivePath`）→ 硬 deny。
- **CLI config 路径**：`~/.councis/config.json`，权限 `0600`。原子写。

## 回归要求

- iOS 必须保持 macOS 真子集：chat/multimodal/providers/artifacts，**不得**链接 Tools/Permission/AgentKernel/Cowork 或 shell/git/patch/local-agent workspace 模块。
- `PlatformProfile.current` 默认 `.iOS`（最受限）：忘记设置的 target 不得意外启用 shell/workspace。
- `IntatisSharedUI` 用 `#if canImport(SwiftUI)`，使包能在 Linux 构建：不得引入 macOS 专属 API 而破坏 Linux/无头构建。
- `swift test` 无头：不得让测试 target 依赖 UI/app target。
- AppStore 构建无 `run_shell` entitlement：不得为 AppStore 配置启用 shell。
- Council 引擎与 Cowork 内核是两套独立模式：不得在未确认前提下让 CLI council 路径调用 `AgentKernel`/`Cowork`，也不得让 `WorkCommand` 的交互式审批绕过/取代 `PermissionEngine`（二者各管各的边界）。

## 不可降级项

- `EventLog` append-only：`append` 是唯一 mutation；`replay`/`stream` 是投影；resume = 从 `seq` 读。不得引入原地修改或删除。
- `seq` 单调性：不得回退或重排。
- `Mediator` 默认转发摘要、不转发原始字节：不得退化成透传完整内容。
- `SecretScanner` 标记集（`-----BEGIN`、`PRIVATE KEY`、`AKIA`、`sk-`、`ssh-rsa`、`xoxb-`、`ghp_`、`AIza`…）不得删减。
- Keychain 凭据引用（`KeychainRef`）不存秘密本身：config 不得出现明文 key。
- Council preset 不含 API key：不得把 key 写入 preset JSON。
- Clean-room 声明：不复制 DeepCode / Codex / Claude Code / OpenCode 的源码、私有 prompt、图标、商标、品牌文案。

## 验证要求

修改后必须运行哪些验证才能视为安全：

- `make test`（`swift test`，无头）
- `make build`（`swift build`）
- 改 GUI/app：`make app`（xcodegen + Xcode）
- 文档任务：至少 `git diff --check` + `git status --short`
- 未运行构建/测试时，最终报告必须声明"未运行构建/测试"。
