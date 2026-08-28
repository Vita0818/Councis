# OPEN_SOURCE_REUSE

文档状态：当前来源与复用政策
最近核对：2026-08-28
产品基线：v0.10（build 49）

## Intatis 第一方依赖

Councis 不再以 snapshot/derived-copy 形式保存 Intatis 源码。当前采用方式是第一方 local SwiftPM dependency：

```text
source: /Users/vita/Vitemis/Intatis
package path from Councis: ../Intatis
relationship: first-party sibling project
integration: direct SwiftPM products + external Codex runtime
```

Intatis 的 package、runtime patch、third-party dependency、license、NOTICE、SBOM和upstream pins由Intatis
仓库拥有。Councis不得复制这些inventory作为独立可升级源码，也不得把Intatis标成第三方上游。

## 下游责任

直接依赖不免除Councis发行责任：

- 构建时记录实际Intatis revision和dirty状态；
- 最终App inventory列出实际链接/打包的Intatis products、resource bundles和external runtimes；
- Councis分发包必须包含适用的Intatis/third-party license与NOTICE文本；
- runtime executable、document/browser helper必须按Councis最终bundle重新做hash、architecture、signature和seal验证；
- 不能把Intatis开发checkout或用户安装当成正式发行依赖。

## Codex Runtime

共享Runtime来自Intatis固定的OpenAI Codex派生实现：

- upstream release：`rust-v0.145.0`；
- runtime version：`0.145.0-intatis.4`；
- exact patch/derivation identity由`CodexRuntimeExecutable`冻结；
- license/provenance/patch ledger位于Intatis仓库。

Councis只调用`IntatisCodexRuntime` public host surface，不复制Rust源码、patch、binary builder、App Server
protocol host或测试fixture。OpenAI官方Codex名称仅用于依赖/provenance/runtime事实，不作为Councis品牌。

## 共享第三方闭包

Markdown/iosMath、MCP Swift SDK、Swift Crypto、Yams、Docling/document runtime、browser runtime、
JetBrains Mono及其他闭包都由当前Intatis Package/RuntimeKit选择。Councis不得单独升级、替换或并行vendor。

若Councis新增自身独有第三方资产，仍须：

1. 固定URL/tag/commit/artifact hash；
2. 核对根许可证、文件头、NOTICE、传递依赖和资产许可；
3. 选择dependency/vendored/external-runtime形式；
4. 更新Councis `NOTICE.md` 与必要的本地notice；
5. 验证Developer ID、sandbox、资源、失败和cleanup边界。

## 禁止项

- 不复制Intatis/Codex runtime、tool host、SharedUI或Vendor源码来“方便改名”。
- 不使用泄露、私有、反编译或绕过访问控制的源码/prompt。
- 不复制第三方Logo、图标、截图、品牌文案或商标性外观。
- 不删除、模糊或错误声明上游版权/许可证。
- 不让外部实现绕过PermissionEngine、Lease、PathConfinement、SecretScanner、durable execution或EventLog。
- 不新增第二runtime/provider/backend作为依赖缺失fallback。

## Intatis 升级流程

1. 在Intatis仓库完成升级、测试、license/provenance和runtime version/derivation更新；
2. Councis不复制diff，只重新解析`../Intatis`；
3. 运行Councis public contract、CLI、App和UI回归；
4. source-breaking host API变更必须遵循`CodexRuntimeHostContract` major/version迁移说明；
5. 只有Councis host/theme/product行为需要的改动留在本仓库；
6. 发行时固定并记录实际Intatis revision，不以浮动dirty checkout声称可复现release。
