# Intatis Runtime 下游接入合同

文档状态：Councis 当前实施记录  
最近核对：2026-08-28

## 目标图

```text
/Users/vita/Vitemis/Intatis
  -> Intatis SwiftPM public products
  -> IntatisCodexRuntime
  -> exact Codex executable
       ↓
/Users/vita/Vitemis/Councis
  -> CouncisMac App host
  -> councis CLI host
  -> Councis identity/config/storage/UI/release
```

Councis 不再保存可编译的 Intatis 快照。共享实现只有一个事实源；下游只拥有
产品 composition 与发行责任。

进程入口必须先调用`IntatisHostApplication.configure(name: "Councis")`，再读取
共享配置、创建storage或构造Runtime。第一次共享identity读取会seal该值；晚改名
必须fail closed。

当前Intatis配置会把`hostApplicationIdentity`冻结进每个
`CodexRuntimeConfiguration`。Councis也把同一identity显式传给
`CodexBusinessToolHost`，保证tool registry、policy、prompt、diagnostic与runtime
config属于同一个产品namespace。

## 依赖

Councis 的真实相对路径是：

```swift
.package(path: "../Intatis")
```

XcodeGen 同样使用：

```yaml
packages:
  Intatis:
    path: ../Intatis
```

不得照抄目录层级不同项目的 `../../Intatis`，也不得添加第二 checkout、
Vendor mirror 或 copied module。

## API 层级

最小稳定合同由下游 public-import tests 固定：

- `IntatisCore`
- `IntatisProtocol`
- `IntatisProviders`
- `IntatisCodexRuntime`
- `CodexRuntimeHostContract.publicAPIMajorVersion == 1`

Councis 的完整 Cowork、MCP、Knowledge、Tools、SharedUI 产品需要额外直接链接
Intatis 第一方 public products。v1 清单之外的紧耦合 public surface 由 Councis
App/CLI 编译和回归测试负责及时跟随；不得复制成 wrapper/facade。

## Production path

```text
Councis ViewModel / CLI
  -> exact ResponsesRuntimeRoute
  -> CodexRuntimeConfiguration
       Councis SessionID
       canonical workspace
       <session>/codex-runtime
       optional COUNCIS_CODEX_RUNTIME
       dynamicTools / MCP / Skills / child profiles
  -> CodexAppServerSession
  -> events / runTurn / startTurn / waitForTurn
  -> approval resolution / interrupt / shutdown
  -> Councis UI/EventLog projection
```

旧 `AgentLoop.send`、`Orchestrator.runtime` 与 scheduler bodies可因共享
compatibility types编译，但 production entrypoint标为不可用且没有运行时选择
或错误 fallback。Runtime失败必须直接呈现。

## 状态隔离

- 每个 session 使用独立可写 runtime root 和 isolated `CODEX_HOME`；
- Runtime root 不位于 Intatis checkout；
- workspace 由用户选择或 Councis managed-workspace flow创建；
- credential只在内存和 App Server子进程环境中存在；
- credential不进入argv、runtime files、EventLog、日志、诊断或文档；
- persisted thread/toolset不能exact恢复时要求新session。
- 正常启动不读取`INTATIS_*`、Intatis config/auth路径或Intatis bundle defaults；
  旧Intatis数据只能由单独、显式且可证明归属的迁移流程读取。

## 工具

App Server拥有agent loop、context、tool scheduling和native collaboration。
Councis/Intatis business tools经official `dynamicTools` callback接入；schema、
CapabilityLease、WorkspaceLease、PathConfinement、PermissionEngine、durable
execution和shutdown仍由第一方tool host执行。失败不得切换shell/Python/MCP
translator或旧backend。

## executable 与发行

开发期可以显式指向：

```text
/Users/vita/Vitemis/Intatis/.intatis/runtime-kit/0.66/CodexRuntime/<arch>/codex
```

正式 Councis App 必须把 active architecture 的 exact executable 放入 sealed
bundle，完成 runtime/third-party license closure、nested signing、outer App
Developer ID签名、公证、staple、Gatekeeper与clean-machine验证。

Swift API major 与 executable version/derivation 是独立版本轴；任一不匹配都
必须失败。

## Intatis 只读取证

迁移开始核对：

- HEAD：`42cb5b36fb6be943ee7812aca3f8520c2e487b04`
- status：clean
- tracked diff hash：空 diff SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- non-ignored untracked count：0
- untracked inventory hash：同一空输入 SHA-256。

所有Councis写入、删除、XcodeGen和文档修改均只发生在Councis root；本线程对
Intatis只执行读取和编译。最新host-identity/storage内核仍位于同一HEAD上的dirty
working tree；Councis本次直接编译并验证这些当前字节。该状态适合本机接线验收，
但在Intatis形成可引用revision前不构成可复现的发行来源。

## 升级

Intatis变化会在Councis下一次构建生效。升级验收至少包含：

1. 记录Intatis HEAD/status；
2. `swift package dump-package`；
3. public contract tests；
4. CLI tests/build；
5. XcodeGen + Debug App；
6. 高风险时universal Release；
7. identity/version/runtime validators；
8. final Intatis read-only evidence；
9. `git diff --check`与status审计。
