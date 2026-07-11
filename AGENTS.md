# Councis 项目常驻上下文

本文件继承 `/Users/vita/Vitemis/AGENTS.md` 中的 Vitemis 通用 Agent 规则。若本文件与通用规则冲突，在不违反系统和用户指令的前提下，以更具体、更严格的项目规则为准。

本文是 AI Agent 每轮进入本仓库时的入口文件。执行任何代码修改、配置修改、构建脚本修改或测试源码修改之前，必须先按顺序阅读并核对下列文档：

0. `/Users/vita/Vitemis/AGENTS.md`
1. `docs/CURRENT_STATE.md`
2. `docs/PROJECT_MAP.md`
3. `docs/ARCHITECTURE.md`
4. `docs/DO_NOT_BREAK.md`
5. `docs/TESTING.md`
6. `docs/NEXT_TARGET.md`（如果存在）

如果文档与源码、工程配置、测试或脚本冲突，必须以当前源码和配置为准，并在最终报告中明确指出冲突位置和采用源码为准的原因。

> 注意：仓内 `ARCHITECTURE.md`（根目录）是 Intatis 架构文档的逐字副本（标题仍为"Intatis 架构设计"），不反映 Councis CLI 的实际 council 实现。以本目录 `docs/ARCHITECTURE.md` 为准。

## 工作目录检查

每轮开始先在项目根目录执行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
```

要求：

- `pwd` 与 `git rev-parse --show-toplevel` 必须指向同一个仓库根目录：`/Users/vita/Vitemis/Councis`。
- 如果当前目录不是 Git root，停止修改，只报告路径问题。
- 读取 `git status --short` 后，先区分用户已有改动与本轮计划改动；不得覆盖、回退或清理用户已有改动。

## 修改边界

本仓库是 Swift 多 target 工程（SwiftPM + XcodeGen 双构建系统），包含 Councis CLI、CouncisMac mock 壳、IntatisMac 全量 app、IntatisiOS chat 子集、11 个 Intatis* 内核模块及测试。

未来常规任务可以按用户要求修改业务源码；但在只要求项目自查或文档更新的任务中，只允许修改：

- `AGENTS.md`
- `docs/` 下的项目说明文档

除非用户明确要求，不要修改：

- `Apps/`（CouncisMac / IntatisMac / IntatisiOS / intatis-cli）
- `Packages/`（11 个 Intatis* 模块及其 Tests）
- `Package.swift`
- `project.yml`
- `Makefile`
- `NOTICE.md`
- `.councis/`

## 禁止事项

- 不执行破坏性 Git 操作：`git reset --hard`、`git clean -fd`、`git checkout .`、强制 push、删除用户未提交文件。
- 未经用户明文要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR；编辑、整理、修复、验证或准备工作都不等于提交请求。
- 若用户要求提交，只提交当前 Git root 中与本任务相关的文件；不得递归进入、暂存、提交或推送子仓库、submodule、nested Git repo 或依赖 checkout。
- 不引入新依赖，不改构建脚本，不改测试源码，除非任务明确要求。当前 v0.1 零第三方依赖（仅 stdlib/Foundation/SwiftUI/AppKit/Security），计划中的 SwiftGit2/libgit2 须先过许可证审查。
- 不把密钥、token、证书私钥、shared secret、账号密码、完整指纹、完整 API 响应、完整转写文本或个人隐私路径写入文档。
- 不绕过 3 层权限门（DeterministicPolicyGate / ModelPermissionReviewer / PermissionEngine）、PathConfinement 工作区边界、SecretScanner、Mediator 秘密拦截或 Keychain 凭据隔离。
- 不破坏 clean-room 声明：不复制 DeepCode / Codex / Claude Code / OpenCode 的源码、私有 prompt、图标、商标或品牌文案。
- 不把 Intatis 内核模块名（`Intatis*`）当作一次性内部细节随意改名；当前 README 明确这些名称是过渡性保留，改名须用户明确要求。
- 不把事件日志 JSONL schema、Envelope 格式、`seq` 单调性、ArtifactStore 索引格式当作一次性内部细节随意改动。
- 不把 Councis CLI 的 council 引擎（`Council.swift` / `WorkCommand.swift`，直接基于 `OpenAIWireProvider`）与 Intatis 内核（`AgentKernel` / `Cowork`）混为一谈——它们是两套独立 agent 模式。

## 项目理解要求

修改前至少确认：

- 入口：`Apps/intatis-cli/Sources/IntatisCLI.swift`（`@main struct CouncisCLI`，product 名 `councis`）、`Apps/CouncisMac/Sources/CouncisMacApp.swift`（`@main struct CouncisMacApp`，mock 壳）、`Apps/IntatisMac/Sources/IntatisMacApp.swift`（`@main struct IntatisMacApp`，全量 app）、`Apps/IntatisiOS/Sources/IntatisiOSApp.swift`（`@main struct IntatisiOSApp`，chat 子集）。
- Council 引擎链路（Councis CLI 实际使用）：`IntatisCLI.swift` → `Council.swift` 的 `CouncilRunner`（`withTaskGroup` 并行候选 + judge）→ `OpenAIWireProvider`；`WorkCommand.swift` 的 `runWorkCouncil`（自带 `PathConfinement` + `[y/N]` 审批，不走 `PermissionEngine`）。
- Intatis 内核链路（IntatisMac 使用，CLI 当前未触达）：`Agent` → `Orchestrator`(actor) → `AgentLoop` → `ContextBuilder` → `OpenAIWireProvider` → `runTool` → `PermissionEngine`（3 层门）→ `EventLog`(JSONL)；`MessageBus` → `Mediator`（SecretScanner + 长度上限 + reviewer）。
- 平台边界：iOS 是 macOS 的真子集（chat/multimodal/providers/artifacts，无 Tools/Permission/AgentKernel/Cowork）；`PlatformProfile.current` 默认 `.iOS`（最受限），忘记设置的 target 不会意外启用 shell/workspace。
- 权限 3 层：`DeterministicPolicyGate`（纯函数、模型无关、deny 终局）→ `ModelPermissionReviewer`（模型评审，只能收窄不能放行）→ `PermissionEngine`（组合，`pass` 默认 `askUser`）。
- 持久化：`EventLog`（append-only JSONL，`~/Library/Application Support/Intatis/<session>/events.jsonl`，`seq` 单调）、`ArtifactStore`（blobs + `index.json`）、`UserDefaults`（`intatis.baseURL`/`intatis.model`）、CLI config（`~/.councis/config.json`，`chmod 0600`）、Keychain（GUI，service `com.intatis.app`/`com.intatis.ios`；CLI 不用 Keychain，走 env/config）。
- 安全：`KeychainStore`（generic-password，凭据引用 `KeychainRef`，不在 config 存秘密）、`PathConfinement`（拒 `..` 与越界绝对路径）、`SecretScanner`（敏感路径/内容/受保护配置）、sandbox/entitlements（AppStore sandbox 无 shell；DeveloperID Hardened Runtime）。

不确定的模块必须标注 `UNKNOWN` 或 `需要后续确认`，不要编造。

## 文档索引

- `docs/PROJECT_MAP.md`：目录、target、入口、关键文件、生成物和脚本地图。
- `docs/ARCHITECTURE.md`：总体架构、双 agent 模式、主要链路、数据模型、权限与安全机制。
- `docs/CURRENT_STATE.md`：当前真实状态、已有能力、风险、工作区改动。
- `docs/TESTING.md`：环境、构建、测试、lint/format 与手动验证方式。
- `docs/DO_NOT_BREAK.md`：工程禁区、数据格式、协议、路径和回归要求。
- `docs/NEXT_TARGET.md`：临时下一目标记录；目标完成或不再有效后删除。

## 完成标准

完成任务前至少做到：

- 说明本轮实际阅读/检查过哪些源码、配置或测试。
- 只修改任务范围内文件。
- 保留用户已有改动。
- 运行与任务相称的检查；文档任务至少运行 `git diff --check` 与 `git status --short`。
- 将本轮已完成的持久性改动及时回写到相关项目文档；若无需更新文档，最终报告说明原因。
- 如未运行构建或测试，最终报告必须明确写"未运行构建/测试"。

## 最终报告格式

最终报告建议包含：

1. `MODEL_CHECK_RESULT`：当前模型名称；无法确认时写无法确认。
2. `PATH_CHECK_RESULT`：`pwd`、Git root、是否匹配预期。
3. `FILES_WRITTEN`：新增/修改文件。
4. `PROJECT_AUDIT_SUMMARY`：识别到的项目结构、主要模块和关键链路。
5. `DOCS_CONTENT_SUMMARY`：各文档内容摘要。
6. `VALIDATION_RESULT`：实际运行命令与结果。
7. `UNCERTAINTIES`：无法确认、需要人工确认的点。
8. `NEXT_RECOMMENDED_ACTION`：下一步建议；不要自动继续改业务源码。
