# TESTING

文档状态：当前验证矩阵
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 环境与边界

- Xcode 27 / Swift 6.x / XcodeGen；
- 唯一App target：`CouncisMac`；
- Bundle ID：`com.Vita0818.Councis`；
- local SwiftPM dependency：`../Intatis`；
- no iOS / no Mac App Store；
- exact Codex Runtime：`0.145.0-intatis.4` + pinned derivation。

外层managed sandbox若阻止SwiftPM/Xcode nested process或Seatbelt，获准后在真实host重跑；不得把环境失败
改成产品失败，也不得用skip冒充通过。

## 依赖图

```sh
swift package dump-package
```

必须证明：

- dependency identity `intatis`解析到`/Users/vita/Vitemis/Intatis`；
- `Package.swift`没有Councis runtime library products；
- CLI直接链接`IntatisCodexRuntime`；
- `project.yml`直接链接同一Intatis package和`IntatisCodexRuntime`；
- 不存在第二个vendored/shared runtime dependency。

## 下游 public contract

```sh
swift test --filter CouncisRuntimeIntegrationTests \
  --disable-automatic-resolution
```

验证：

- `CodexRuntimeHostContract.publicAPIMajorVersion == 1`；
- package/product/module identity；
- pinned runtime version；
- 下游只用public imports可构造isolated `CodexRuntimeConfiguration`和`CodexAppServerSession`；
- config description不泄漏bearer token。

Intatis自身的`CodexRuntimePublicContractTests`仍是共享API source-compat authority；Councis不复制该suite。

## CLI

```sh
swift build --product councis --disable-automatic-resolution
swift test --filter CouncisCLITests --disable-automatic-resolution
.build/debug/councis --help
```

必须检查：

- help/usage只显示`councis`与`COUNCIS_*`；
- Code/Cowork走`CodexRuntimeCLI`；`councis exec`明确disabled；
- config discovery使用Councis paths；
- `COUNCIS_CODEX_RUNTIME`存在时传给public configuration override；
- fake runtime测试同时校验version与`--intatis-derivation-id`（共享runtime协议名不得改写）；
- `INTATIS_*`、`.config/intatis`与Intatis Application Support即使存在也不会被
  App/CLI正常配置发现采用；
- Chat保留共享ChatLoop，Code/Cowork没有旧AgentLoop fallback。

## macOS App

```sh
xcodegen generate

xcodebuild -quiet \
  -project Councis.xcodeproj \
  -scheme CouncisMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO build
```

高风险/发行前再跑：

```sh
xcodebuild -quiet \
  -project Councis.xcodeproj \
  -scheme CouncisMac \
  -configuration Release \
  -destination 'platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO build
```

最终bundle检查：

```sh
plutil -extract CFBundleShortVersionString raw -o - <App>/Contents/Info.plist
plutil -extract CFBundleVersion raw -o - <App>/Contents/Info.plist
plutil -extract CFBundleIdentifier raw -o - <App>/Contents/Info.plist
lipo -archs <App>/Contents/MacOS/Councis
```

期望`0.10`、`49`、`com.Vita0818.Councis`，universal Release为`arm64 x86_64`。

## Runtime host focused checks

至少静态/编译证明：

- `CodeViewModel`/`CoworkViewModel`构造`CodexRuntimeConfiguration`；
- App/CLI先安装Councis host identity，并把同一冻结identity显式传给business
  tool host与runtime configuration；
- runtime root位于exact Councis session directory；
- App/CLI均支持`COUNCIS_CODEX_RUNTIME`；
- event stream处理assistant、approval、usage、Goal和child；
- business tools来自`CodexBusinessToolHost.dynamicTools()`；
- shutdown调用`CodexAppServerSession.shutdown()`并drain tool host；
- 无production `AgentLoop.send`/`Orchestrator.runtime`执行入口。

真实runtime smoke只在用户授权后运行。建议使用Intatis runtime kit当前架构executable，启动fresh临时
Councis session，验证ready、one turn、approval、child/tool、shutdown和无残留。

## UI 回归

macOS GUI至少检查：

- sidebar只显示Cowork；
-标题/Settings/config/error文案为Councis；
-系统动态 window canvas、Liquid Glass 与当前 Councis 视觉保持；
-Sidebar `+` 与空白页 `New` 只显示 `Choose Folder…` / `No Folder`；
-Chat/Code未作为平行导航出现；
-Agents rail、child切换、Goal、Tasks、permission、usage、MCP入口仍存在；
-用户消息/assistant/agent/structure card视觉层级保持；
-Light/Dark、Reduce Transparency、Increase Contrast、VoiceOver未验证时标`UNKNOWN`。

## Config 与secret

- JSON验证不得回显内容；
-只检查secret env是否存在，不读取值；
-Councis source/test/docs不得包含真实key；
-runtime argv/EventLog/diagnostic不得含credential；
-canonical config损坏不得回退Intatis/OpenCode配置。

## 版本、身份和静态门

```sh
scripts/check-version-consistency.sh
scripts/check-brand-boundary.sh
git diff --check
git status --short
```

identity gate应允许active imports中的`Intatis*`共享module/type，但必须拒绝：

- local copied runtime packages；
- local Vendor/runtime mirror；
- production旧AgentLoop fallback；
-用户可见Intatis品牌；
-Councis canonical config/state写入回退Intatis。

## 发行

正式发行还必须验证：

- Councis bundle内active-architecture exact Codex executable；
- version + derivation；
- runtime和third-party license/NOTICE闭包；
- external document/browser runtime inventory；
- bottom-up Developer ID签名、Hardened Runtime、notarization、staple、Gatekeeper；
- fresh-user/clean-machine startup；
- bundle不依赖`../Intatis`、用户home、Homebrew或`.local/bin`。

这些证据未完成前不得写release GO。

## 本轮直接结果

截至2026-08-28：

- `swift package dump-package`：通过，Intatis local dependency解析成功；
- `swift build --product councis --disable-automatic-resolution`：通过；
- `CouncisRuntimeIntegrationTests`：3 tests / 0 failures；
- `CLIProductBrandCompatibilityTests`：2 tests / 0 failures；
- `CouncisCLITests`：52 tests / 8 opt-in skips / 0 failures；
- 完整当前 Councis `swift test --disable-automatic-resolution`：55 tests / 8 opt-in skips / 0 failures；
- `xcodegen generate`：通过；
- `CouncisMac` unsigned Debug：通过；
- 当前Intatis working tree上的`CouncisMac` unsigned universal Release：通过，
  读回`0.10 (49)`、`com.Vita0818.Councis`、executable `Councis`、
  `x86_64 arm64`；
- App bundle中的`ThirdPartyNotices/OpenAICodexRuntime.md`与Intatis来源逐字节一致；
- Intatis runtime kit 0.66 的Codex/Document/Browser arm64+x86_64 static validation：通过；
- arm64/x86_64 Codex executable均报告`0.145.0-intatis.4`和相同pinned derivation；
- App bundle包含IntatisSharedUI JetBrains Mono资源与31份Intatis ThirdPartyNotices；
- CLI help/offline selftest、brand/version gate与`git diff --check`：通过；
- 未运行真实GUI/VoiceOver视觉smoke；
- 未运行真实provider、Developer ID签名、公证、staple、Gatekeeper或clean-machine验证。

Councis迁移开始时Intatis为clean
`42cb5b36fb6be943ee7812aca3f8520c2e487b04`。本次最终验证消费同一HEAD上最新的
host-identity/storage dirty working tree；结束时为123 modified/2 untracked，
tracked diff SHA-256为
`62722284c7136df497be9921a698d35cc11a1563c2a2837d3135aa7c459ad9d0`。
Councis没有写入Intatis。该结果证明当前本机字节可接线/编译/测试，但在Intatis
形成可引用revision前不构成发行级可复现来源。

Xcode 27对若干warning-only SwiftCompile步骤输出“command failed with exit code
0”噪声；Debug与Release命令最终均返回0，且产物存在并通过bundle identity与
architecture读回。既有unused-result和deprecated `onChange` warnings仍存在。
