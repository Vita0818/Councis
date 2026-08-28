# macOS 分发与 Runtime 边界

文档状态：当前发行合同
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 产品决策

Councis 只通过 Developer ID签名、公证和直接下载分发。唯一App target是`CouncisMac`，Bundle ID
`com.Vita0818.Councis`。不提供Mac App Store、App Sandbox或iOS产品图。

取消App Store约束不允许移除PermissionEngine、Lease、PathConfinement、SecretScanner、managed process
sandbox、Hardened Runtime或签名/公证。

## 源码依赖与发行制品必须分离

开发构建通过`../Intatis`直接编译共享源码。正式App不得在运行时依赖：

- `/Users/vita/Vitemis/Intatis`；
- `.intatis/runtime-kit`；
- `~/.local/bin/intatis-codex`或`codex`；
- Homebrew、PATH或开发机cache；
- Councis旧`Packages/`或`Vendor/`副本。

源码共享只解决维护和升级，不解决二进制分发。

## Codex Runtime bundle

正式App必须把当前process architecture对应的exact executable放入sealed bundle，例如：

```text
Councis.app/Contents/Resources/CodexRuntime/arm64/codex
Councis.app/Contents/Resources/CodexRuntime/x86_64/codex
```

发行门必须证明：

1. runtime version是`0.145.0-intatis.4`；
2. derivation ID等于`CodexRuntimeExecutable.pinnedDerivationID`；
3. source/patch/Cargo.lock/toolchain/binary hash可追溯到Intatis runtime kit；
4. architecture正确，无开发机绝对load path；
5. license/NOTICE closure完整；
6. nested executable先用与outer App相同Developer ID identity签名；
7. outer App strict resource seal、Hardened Runtime和entitlements通过；
8. notarization、staple、codesign和Gatekeeper通过；
9. fresh user/clean machine在无Intatis checkout、无PATH runtime时启动成功。

`COUNCIS_CODEX_RUNTIME`只用于开发。shipping composition必须明确传入/发现bundle内runtime，不能让
external Runtime的开发发现路径成为发行fallback。

## 业务 external runtimes

文档和浏览器等runtime由Intatis共享源码/spec/validator拥有，但Councis正式包仍须按自己的最终bundle
重新完成architecture、hash、SBOM、license、signature与clean-machine验证。缺失或损坏时对应能力typed
fail closed，不下载、不切换Homebrew/系统偶然安装/另一backend。

## 权限与凭据

- Developer ID target使用最小audio-input entitlement；不启用App Sandbox。
- provider credential只进入Codex child process environment，不进入argv或bundle。
- isolated `CODEX_HOME`位于Councis session Application Support root，不写进App bundle或Intatis checkout。
- runtime process、dynamic tools、MCP和business helper在quit/delete/cancel时必须有界drain。

## 打包脚本状态

`package-macos-release.sh` 已按当前 Intatis runtime-kit 发行图接入三组双架构 roots：Codex、Document、
Browser。Councis 的 `validate-*-runtime.sh` 只是解析 `../Intatis` 并直接执行共享 validator；没有复制
validator 或 runtime builder。脚本继续拥有 Councis bundle/version/identity、Developer ID、notary、
recovery、ZIP/DMG 和 Gatekeeper 阶段。

当前缺少经 Councis 最终发行流程验收的真实三组双架构 signed roots 与 clean-machine 证据，因此：

- 不运行正式发行；
- 不把 unsigned/ad-hoc App 或共享开发 runtime 发布为正式产物；
- 不声称 ZIP/DMG、公证或 clean-machine 已闭环。

## 默认验证

1. SwiftPM dependency/contract tests；
2. Councis CLI build/tests；
3. XcodeGen；
4. CouncisMac Debug + universal Release；
5. final bundle identity/resource/link inventory；
6. exact Codex runtime version/derivation/architecture/license/signature；
7. Developer ID/notary/staple/Gatekeeper；
8. clean-machine startup与核心Cowork smoke。
