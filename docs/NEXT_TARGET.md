# NEXT_TARGET

文档状态：当前目标完成；等待用户指定下一目标

最近核对：2026-08-17

产品基线：v0.10（build 49）；来源提交标题：v0.54

## 当前目标：Councis 底层产品身份脱钩

用户已确认：

- 唯一 Apple App 为 macOS `Councis`；target/scheme 为 `CouncisMac`；Bundle ID 为
  `com.Vita0818.Councis`；
- 不再提供 iOS App；
- 新建或继续写出的活跃身份不得采用 Intatis；旧名只可用于固定来源、只读 legacy
  bridge/decode、安全保护和回归 fixture；
- 删除遗留 Mac App Store target，而不是继续保留或验证它；
- 旧安装数据不是 release blocker，允许尽力而为且不删除旧数据的桥接。

完整实施与验收清单见 `docs/COUNcis_DECOUPLING_CHECKLIST.md`。

## 已完成到当前工作树的内容

- SwiftPM package、15 个 public library products、3 个内部 C/guard targets、CLI、开发期
  conformance executable 与 15 个 test targets 已改为 Councis；
- `Apps/CouncisMac`、`Apps/councis-cli`、`Packages/Councis*`、`Councis.icon` 与
  `.agents/skills/councis-skill-creator` 已成为 canonical source paths；
- iOS App source/target/scheme 与 Mac App Store target/entitlements/条件 composition 已删除；
- XcodeGen 只生成 `Councis.xcodeproj` / `CouncisMac` / `Councis.app`；最终 Debug 与 universal
  Release unsigned bundles 已读回 `CFBundleIdentifier=com.Vita0818.Councis`、executable/icon
  `Councis`、版本 `0.48 (48)`，Release executable 含 `x86_64 arm64`；
- CLI product/help 使用 `councis`，不新增 `intatis` alias；
- Application Support、配置、auth、UserDefaults、workspace metadata、Knowledge、diagnostic、
  registry/policy/sidecar/MCP 等 canonical writer identity 已切到 Councis；
- 旧 config/auth/UserDefaults/bundle domain、CLI config root/AAD、MCP Keychain service、provider
  adapter/source kind 与 sidecar 只以受控 legacy bridge/decode 方式保留；新写入仍只使用 Councis；
- 新旧敏感 config/Knowledge 路径同时保留在 PathConfinement、SecretScanner 和 terminal deny floor；
- `scripts/check-brand-boundary.sh` 已建立活跃 identity 与 legacy 白名单门。
- 当前权威文档、NOTICE、ThirdPartyNotices 与 vendored local-adoption/patch ledger 已收口为 Councis；
  固定来源 commit/tree/license/copyright 没有伪造或删除。
- SwiftPM build、15-bundle full test（2,116 tests executed、41 opt-in skipped、0 failures）、CLI
  product/help/selftest、vendored renderer package 90 tests、Skill validator、品牌/版本/脚本/plist/
  JSON/diff 静态门均通过。

## 本目标不包含、仍需独立授权/环境的发行验证

- Linux CLI 双架构 gate；
- Developer ID 正式签名、公证、staple、Gatekeeper、ZIP/DMG/manifest；
- 真实 provider/credential/network、真实旧 Keychain/session bridge、GUI/VoiceOver/长时性能 smoke。

这些未执行项不改变本轮“底层身份脱钩代码与本地 unsigned 验证完成”的结论，但在实际
发布前仍须按 `docs/TESTING.md` 和 `docs/MACOS_DISTRIBUTION.md` 独立完成。

## 当前不自动延伸的事项

- 不重新引入 iOS 或 Mac App Store 产品面；
- 不改变 Chat/Code 隐藏但保留的 runtime/history compatibility；
- 不扩大 Judge、Permission Reviewer、GoalVerifier 或普通 worker authority；
- 不自动安装、签名、公证、提交或发布 App；
- 不删除用户旧 Application Support、配置、Keychain、CLI store、browser 或 Knowledge 数据。
