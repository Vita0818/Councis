# CURRENT_STATE

文档状态：当前源码摘要
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 当前结论

Councis 已从完整 Intatis 源码快照切换为第一方下游产品：

```text
Councis Package.swift / project.yml
  -> ../Intatis
  -> IntatisCodexRuntime + selected Intatis* products
  -> CouncisMac / councis product hosts
```

`Package.swift` 不再声明 Councis runtime libraries；本地仅保留
`CouncisProductSupport`、`councis` CLI、CLI tests 与下游 Runtime contract
tests。`project.yml` 的唯一 App target 直接链接同一 Intatis checkout。

当前 Intatis HEAD仍是`v0.66` commit：

```text
42cb5b36fb6be943ee7812aca3f8520c2e487b04
```

迁移前取证为HEAD不变、clean status、tracked diff hash与untracked inventory
hash均为空输入SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
此后Intatis的host-identity/storage工作在同一HEAD上形成尚未提交的最新working
tree；Councis本轮只读并直接编译该当前工作树，没有修改Intatis。最终复验记录
实际status/diff证据；在这些字节形成可引用revision前，发行可复现性仍为
`UNKNOWN`。

## 删除范围

已删除 661 个 Git-tracked snapshot 文件：

- `Packages/Councis*`；
- `Vendor/`；
- `ThirdPartyStandards/`；
- `Tests/MCPBM25ParityOracle/`；
- `Tests/MCPConformance/`。

删除前先证明这些目录退出 `Package.swift`、`project.yml`、active imports 和
production runtime call graph。ignored local build cache没有递归清理，不属于源码、
构建图或fallback。

另删除27份已由Intatis canonical notice目录拥有的重复第三方声明；本地只保留
Councis dev-only `councis-skill-creator`对应的notice与Apache-2.0文本。最终App从
`../Intatis/ThirdPartyNotices`复制当前31份共享声明。

## 产品与身份

- 唯一 App：`CouncisMac` / `Councis.app`。
- Bundle ID：`com.Vita0818.Councis`。
- 版本：`0.10 (49)`。
- macOS 可见入口：Cowork。
- CLI：`councis`。
- canonical config/state：Application Support `Councis`、
  `councis.json[c]`、`COUNCIS_*`、`councis.*`。
- 内部 Swift modules/public types/runtime identity 使用 Intatis，是直接依赖事实。
- 无 iOS、Mac App Store或App Sandbox产品分支。

## 运行时主链

### Code / Cowork

```text
Councis ViewModel / CLI host
  -> exact Intatis ResponsesRuntimeRoute
  -> CodexRuntimeConfiguration
       session-owned runtimeRootURL
       workspaceURL
       optional COUNCIS_CODEX_RUNTIME
       dynamic tools / native MCP / Skills / child profiles
  -> CodexAppServerSession.start/resume
  -> runTurn / startTurn / waitForTurn
  -> CodexRuntimeEvent
  -> Councis EventLog/UI projection
```

Codex App Server拥有agent loop、context、tool scheduling、approval和native
collaboration。第一方business tools只经official `dynamicTools` callback接入；
Code/Cowork production send、cancel和shutdown没有旧AgentLoop/Orchestrator
fallback。CLI `councis exec`明确disabled。

### Chat

CLI Chat与保留兼容源码继续使用Intatis共享ChatLoop。CouncisMac导航只展示Cowork。

## Cowork 与 UI 保持

- `@main` root、native child tree、Agents rail、child transcript/message/archive、
  official thread Goal、WorkTask cards、permission、usage、MCP和dynamic tools继续接线。
- `judge_model`编译为exact、read-only native child profile `judge`；不获得
  coordination、run-control或最终决定权。
- 当前public Runtime没有host-side零请求child attach；所以旧“fresh bootstrap即
  固定显示Judge”的精确语义尚未证明等价。这是已记录的产品parity gap，不以
  synthetic UI row或第二runtime兜底。
- Sidebar `+`与空白Cowork `New`继续只显示
  `Choose Folder…` / `No Folder`。
- `No Folder`继续创建
  `~/Library/Application Support/Councis/Workspaces/<SessionID>` managed workspace。
- Cowork-only navigation、系统动态window canvas、原生Liquid Glass、JetBrains
  Mono、Councis图标和用户文案保持。
- 旧Swift runtime session没有exact current Codex thread/toolset mapping时不静默
  迁移；需要新建session。

## 配置

macOS canonical discovery：

1. `COUNCIS_CONFIG`；
2. `~/.config/councis/councis.json[c]`；
3. Councis Application Support `councis.json[c]`；
4. Councis-owned `config.json[c]` compatibility。

CLI使用`COUNCIS_CONFIG`、`COUNCIS_BASE_URL`、`COUNCIS_API_KEY`、
`COUNCIS_MODEL`、`COUNCIS_REASONING`、`COUNCIS_MODE`。
`COUNCIS_CODEX_RUNTIME`只指定开发期executable；Runtime仍验证exact version和
derivation。正常启动明确忽略legacy `INTATIS_*`、`.config/intatis`、
`.local/share/intatis`、Intatis Application Support与Intatis bundle defaults；
旧Intatis workspace bookmark keys仅留在未接入正常启动的显式迁移实现中。

## 当前验证

已完成：

- `swift package dump-package`：只解析
  `/Users/vita/Vitemis/Intatis`；
- `swift build --product councis --disable-automatic-resolution`：通过；
- `CouncisRuntimeIntegrationTests`：3 tests / 0 failures，包括host identity派生和
  configuration冻结；
- `CLIProductBrandCompatibilityTests`：2 tests / 0 failures，证明Intatis env/path
  不进入Councis discovery；
- `CouncisCLITests`：52 tests / 8 opt-in skips / 0 failures；
- `xcodegen generate`：通过；
- 完整 `swift test --disable-automatic-resolution`：55 tests / 8 opt-in
  skips / 0 failures；
- 当前Intatis working tree上的`CouncisMac` unsigned Debug与unsigned universal
  Release：均通过；Release读回`0.10 (49)`、`com.Vita0818.Councis`、
  executable `Councis`、`x86_64 arm64`；
- App资源包含IntatisSharedUI的JetBrains Mono variable fonts与31份
  `ThirdPartyNotices`，Codex Runtime notice与Intatis来源逐字节一致；
- Intatis RuntimeKit 0.66的Codex/Document/Browser arm64+x86_64六项
  static validation：通过；
- 两架构Codex executable均报告`0.145.0-intatis.4`和同一pinned
  derivation
  `0003-sha256:9cd57fc61366cb7410f6e551aa48ec762094e9a4edbfcbf0ae4670b7ba1f2285`；
- CLI `--help`与offline `selftest`：通过；
- `scripts/check-brand-boundary.sh`、版本门、`git diff --check`：通过；
- 验证结束时Intatis仍是HEAD `42cb5b3`加123 modified/2 untracked的外部dirty
  worktree；tracked diff SHA-256为
  `62722284c7136df497be9921a698d35cc11a1563c2a2837d3135aa7c459ad9d0`。
  Councis没有修改该仓库。

Xcode 27在warning-only SwiftCompile步骤输出了“command failed with exit code 0”
驱动噪声；两个`xcodebuild`最终均返回0，且Debug/Release产物存在并通过上述bundle
读回。既有unused-result/deprecated `onChange` warnings未在本次接线范围内修改。

## 未执行/不外推

- 真实provider、credential与billable request；
- Developer ID签名、公证、staple、Gatekeeper；
- clean-machine runtime验证；
- 完整GUI/VoiceOver/Reduce Transparency/Increase Contrast人工回归。

unsigned build和开发期source/runtime共享不能冒充正式发行完成。
