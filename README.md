# Councis

当前版本：**v0.10**（build 49）
状态：pre-1.0；共享 Runtime 接入已迁移，当前正在进行的 Intatis v0.67
host-identity/storage改动使dependency工作树暂时不可稳定构建，正式发行尚未闭环。

Councis 是 Intatis 的第一方 macOS 产品覆盖层。它不再保存 Intatis 源码快照；App 与 CLI 都通过
SwiftPM local path `../Intatis` 直接编译同一份共享实现。Intatis 升级后，Councis 下一次构建即可
获得 Runtime、工具、权限、MCP、Skills、Knowledge 和共享 UI 的改动，不再进行源码复制/同步。

## 产品

- 唯一 App：`CouncisMac`；Bundle ID `com.Vita0818.Councis`。
- macOS 可见入口：Cowork。
- CLI：`councis`，支持 Chat/Code/Cowork。
- 分发：Developer ID、notarization、direct download。
- 不提供 iOS App 或 Mac App Store target。

Councis 保留自己的名称、图标、系统动态配色、Cowork-only 导航、两项 New 菜单、config/state root 和发行流程；
agent/runtime/core 实现直接来自 Intatis。

## 架构

```text
../Intatis
  -> IntatisCodexRuntime 0.145.0-intatis.4
  -> Intatis Core/Protocol/Providers/Tools/Permission/MCP/Skills/Knowledge/UI
       -> CouncisMac
       -> councis CLI
```

Code/Cowork 使用 `CodexAppServerSession`。Codex App Server拥有agent loop、context、tool scheduling、
approval和native subagents；Intatis business host通过official `dynamicTools`提供文档、浏览器、Knowledge、
WorkTask和session rename。没有旧Swift AgentLoop fallback、协议翻译层或第二provider backend。

详细说明：

- [产品身份](docs/COUNcis_IDENTITY.md)
- [Intatis 接入](docs/INTATIS_INTEGRATION.md)
- [当前状态](docs/CURRENT_STATE.md)
- [项目地图](docs/PROJECT_MAP.md)
- [架构](docs/ARCHITECTURE.md)
- [不可破坏合同](docs/DO_NOT_BREAK.md)
- [测试](docs/TESTING.md)
- [版本](docs/VERSIONING.md)

## 开发

需要：

- `/Users/vita/Vitemis/Intatis` checkout；
- Xcode 27 / Swift 6.x；
- XcodeGen。

常用命令：

```sh
swift package dump-package
swift test --filter CouncisRuntimeIntegrationTests \
  --disable-automatic-resolution
swift build --product councis --disable-automatic-resolution

xcodegen generate
xcodebuild -project Councis.xcodeproj -scheme CouncisMac \
  -configuration Debug -destination 'platform=macOS' \
  COMPILER_INDEX_STORE_ENABLE=NO CODE_SIGNING_ALLOWED=NO build
```

开发期可显式指定 shared exact executable：

```sh
COUNCIS_CODEX_RUNTIME=/absolute/path/to/intatis-codex \
  .build/debug/councis cowork /absolute/workspace
```

该值只选择 executable 路径；Runtime 仍校验 exact version 与 derivation。正式 App 不能依赖这个开发路径，
必须把当前架构 executable 放入自身 sealed bundle。

## 配置

macOS/CLI canonical 配置：

- `COUNCIS_CONFIG`；
- `~/.config/councis/councis.json[c]`；
- Councis Application Support `councis.json[c]`；
- CLI 的 `COUNCIS_BASE_URL`、`COUNCIS_API_KEY`、`COUNCIS_MODEL`、
  `COUNCIS_REASONING`、`COUNCIS_MODE`。

credential只从受控reference懒加载，不进入EventLog、diagnostic、文档或Git。不要把真实key写入仓库。

## 数据

每个session使用独立Councis Application Support目录，其中包含EventLog、projection、artifacts、bookmark
capability与isolated Codex runtime root。不同项目/session不得共享可写`CODEX_HOME`。

旧Swift runtime session没有exact current Codex mapping时不会静默迁移；请新建session。

## 分发状态

源码直接依赖已经工作，但正式发行仍须：

- bundle active-architecture exact Codex runtime；
- runtime/third-party license和hash closure；
- external document/browser runtime；
- bottom-up Developer ID签名；
- notarization、staple、Gatekeeper；
- 无Intatis checkout/PATH runtime的clean-machine smoke。

完成前不得把共享开发runtime或unsigned build作为正式release发布。
