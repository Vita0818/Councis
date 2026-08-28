# Councis 项目常驻上下文

本文件继承 `/Users/vita/Vitemis/AGENTS.md` 与
`/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`。冲突时采用更具体、更严格且不违反上级指令的规则。

## 项目定位

Councis 是 Intatis 的第一方下游产品覆盖层，不再保存 Intatis 源码快照。

```text
/Users/vita/Vitemis/Intatis            唯一共享实现源码
  -> SwiftPM package Intatis
  -> IntatisCodexRuntime + Intatis* products
       -> CouncisMac product host / resources / branding
       -> councis CLI host
```

- `Package.swift` 与 `project.yml` 必须通过相对路径 `../Intatis` 直接依赖唯一 Intatis checkout。
- Intatis 中的 agent loop、tool scheduling、context、native subagents、approval、MCP、Skills、Knowledge、文档/浏览器工具与共享协议不得复制回 Councis。
- Councis 本地只保留产品身份、App/CLI 宿主接线、品牌视觉、图标、本地化、产品配置入口、必要测试与发行接线。
- Intatis checkout 的修改会在 Councis 下一次构建时生效；已运行 App 不热替换。
- 除非用户明确授权跨仓修改，Councis 任务只读 `/Users/vita/Vitemis/Intatis`，不得清理、覆盖或提交其中现有改动。

## 外部依赖优先与禁止兜底

- 直接使用 Intatis 官方 SwiftPM products、`CodexRuntimeHostContract` 与 App Server extension。
- 不新增 wrapper、facade、protocol translator、MCP translator、compatibility shim、parallel backend、shadow runtime、preview runtime 或旧 Swift AgentKernel fallback。
- `dynamicTools` 只承载 Councis/Intatis 已登记的第一方业务工具；App Server继续拥有 agent loop 和工具选择。
- exact Intatis API、runtime binary、版本、derivation、签名、许可证或平台条件不成立时，明确失败并停止对应能力，不切换旧实现、另一 provider、shell/Python 重写、mock 或简化路径。
- 安全 fail-closed 与明确的旧数据只读解码不是功能 fallback，但必须保持最窄范围。

## 每轮入口检查

在项目根目录运行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
```

`pwd` 与 Git root 必须同时为 `/Users/vita/Vitemis/Councis`。不匹配时停止修改。
读取状态后区分用户已有改动与本轮改动；不得覆盖、回退或清理用户工作。

## 修改前必读

按任务范围依次核对：

1. `/Users/vita/Vitemis/AGENTS.md`
2. `docs/COUNcis_IDENTITY.md`
3. `docs/VERSIONING.md`
4. `docs/CURRENT_STATE.md`
5. `docs/MACOS_DISTRIBUTION.md`
6. `docs/PROJECT_MAP.md`
7. `docs/ARCHITECTURE.md`
8. `docs/DO_NOT_BREAK.md`
9. `docs/OPEN_SOURCE_REUSE.md`
10. `docs/TESTING.md`
11. `docs/NEXT_TARGET.md`（存在时）
12. `docs/COWORK_PRINCIPLES.md`（Cowork/runtime/permission/agent 任务）
13. `docs/AI_PROVIDER_MODEL_CONFIGURATION.md`（provider/model/credential 任务）
14. `/Users/vita/Vitemis/Intatis/docs/CODEX_RUNTIME_INTEGRATION.md`（runtime 接入任务）

若文档与源码、manifest、工程或测试冲突，以当前源码与构建配置为准，并在最终报告指出冲突。

## 当前产品边界

- 唯一 App：macOS Developer ID/direct-distribution `CouncisMac`。
- Bundle ID：`com.Vita0818.Councis`。
- macOS 可见产品入口：Cowork；Chat/Code 兼容源码由共享 Intatis 图保留，但不作为平行 App 导航。
- CLI：`councis`，保留 Chat/Code/Cowork 命令；Code/Cowork 使用 `CodexAppServerSession`，Chat 使用共享 ChatLoop。
- 不存在 iOS App target、Mac App Store target、App Sandbox 产品分支或第二 App runtime。
- 产品版本事实源仍为 `project.yml`。

## Codex Runtime 接入合同

- 宿主 API major：`CodexRuntimeHostContract.publicAPIMajorVersion == 1`。
- exact runtime：`codex-cli 0.145.0-intatis.4`，并独立校验 pinned derivation ID。
- 每个 Councis session 必须拥有自己的 `runtimeRootURL`、isolated `CODEX_HOME`、workspace、credential 与权限状态；不同 session/project 不共享可写 runtime root。
- 开发期可由 `COUNCIS_CODEX_RUNTIME` 显式指定 executable；值缺失时可使用 Intatis runtime 的受审开发发现路径。canonical 值存在但非法时不得回退。
- 正式 App 必须把当前架构 exact executable 放入自己的 sealed bundle并完成 Councis 自己的签名、公证和 Gatekeeper 流程；`../Intatis` 与用户目录 executable 不是发行 fallback。
- credential 只存在内存和 App Server 子进程环境，不进入 argv、runtime files、EventLog、日志、文档或 UI。
- Code/Cowork send/start/cancel/shutdown 只调用 Codex Runtime；旧 `AgentLoop` / `Orchestrator` 不得成为 production execution path。
- Cowork Agents、child history/message/archive、Goal、WorkTask、MCP、Skills、Knowledge 和 session rename 直接使用同一 Intatis checkout 的第一方 public surface；不得在 Councis 重建一套等价状态机。

## Councis 产品身份

用户可见和产品拥有的 canonical 值继续使用 Councis：

- `CouncisMac`、`councis`、`com.Vita0818.Councis`；
- `~/Library/Application Support/Councis`；
- `~/.config/councis/councis.json[c]`；
- `COUNCIS_CONFIG`、`COUNCIS_AUTH_FILE`、`COUNCIS_MODEL`、
  `COUNCIS_BASE_URL`、`COUNCIS_API_KEY`、`COUNCIS_REASONING`、
  `COUNCIS_CODEX_RUNTIME`；
- `councis.*` UserDefaults 和 product-host identity。

共享 module/type/wire/runtime identity 使用 Intatis 是预期事实，不得为了字符串纯度复制或包装它们。

## 安全与持久化边界

- Councis session EventLog、ArtifactStore、workspace bookmark 与 UI projection 仍位于 Councis Application Support root，但实现直接来自 Intatis products。
- EventLog append-only、单调 `seq`、WAL、checked replay、owner-only storage 与 writer lease 不得弱化。
- `WorkspaceLease`、`CapabilityLease`、`PathConfinement`、`PermissionEngine`、`SecretScanner`、Mediator、durable tool execution 与 managed process cleanup 继续有效。
- App Server/native collaboration 是唯一 agent execution/scheduling core；WorkTask 只保留独立 UI 卡片记录，不得恢复旧 scheduler 或 MessageBus 执行后端。
- 旧 runtime/thread/toolset 不做静默迁移。无法证明 exact mapping 时要求新 session，不能创建空 thread 或注入旧历史冒充迁移成功。
- GUI 不读取、打印或写入真实 secret；不得读取 `.env*`、Keychain、auth JSON、provider config secret 值、证书或私钥。

## UI 不变量

- 保持 Councis 品牌、图标、系统动态 window canvas、无色原生 Liquid Glass、JetBrains Mono、Cowork-only sidebar 和现有 composer/rail/thread 交互。
- 用户消息仍是唯一普通对话气泡；assistant/agent/system 正文直接位于 canvas；permission/task/error 使用结构化表面。
- root window canvas 必须继续使用系统动态 window surface；不得写死暖色、浅色、深色或引入 Intatis 用户可见品牌。
- Sidebar `+` 与空白 Cowork `New` 必须继续只提供 `Choose Folder…` / `No Folder`；后者创建 session-owned managed workspace。
- `judge_model` 当前解析为只读 native Codex child profile `judge`，不得获得 coordination、run-control 或最终决定权。旧产品合同还要求它在首个 provider request 前已经作为固定 ordinary agent 登记；当前 public Runtime 没有 host-side child spawn/attach 入口，因此不得把 profile advertisement 宣称为完整等价。不得为补齐它恢复第二 runtime；需要 Intatis public surface 或用户明确调整该产品合同。
- 共享 Intatis UI 类型可以直接使用，但 App 层必须提供 Councis 主题与可见文案；不得复制共享 renderer/runtime 只为重命名内部类型。

## Git 与删除规则

- 未经用户明确要求具体 Git 操作，不 add、不 commit、不 push、不建 PR、不 stash。
- 禁止 `git reset --hard`、`git clean`、`git checkout .`、强制 push 或删除用户未提交文件。
- 删除旧复制快照时必须先证明目标已退出 `Package.swift`、`project.yml` 和 active source import graph；整目录删除要列出精确范围并取得所需安全批准。
- 不删除或修改 `/Users/vita/Vitemis/Intatis` 的源码、runtime kit、未提交文件或 Git 状态。

## 验证与完成标准

与改动相称地至少运行：

- `swift package dump-package`：确认唯一 local package dependency 是 `../Intatis`；
- `swift test --filter CouncisRuntimeIntegrationTests --disable-automatic-resolution`；
- `swift build --product councis --disable-automatic-resolution`；
- CLI/runtime 改动运行 `CouncisCLITests`；
- `xcodegen generate`；
- `CouncisMac` unsigned Debug build；高风险/发行改动再跑 universal Release；
- `scripts/check-version-consistency.sh`、`scripts/check-brand-boundary.sh`；
- `git diff --check`、`git status --short`。

完成前说明实际阅读的源码/配置/测试、只修改任务范围、保留用户改动，并及时更新当前文档。
未运行的构建、测试、真实 provider、签名、公证或 GUI 项必须明确标为未运行或 `UNKNOWN`。

## 最终报告

建议包含：

1. `MODEL_CHECK_RESULT`
2. `PATH_CHECK_RESULT`
3. `FILES_WRITTEN`
4. `PROJECT_AUDIT_SUMMARY`
5. `DOCS_CONTENT_SUMMARY`
6. `VALIDATION_RESULT`
7. `UNCERTAINTIES`
8. `NEXT_RECOMMENDED_ACTION`
