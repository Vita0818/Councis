# macOS 分发与沙箱边界

文档状态：当前发行合同

生效日期：2026-08-17

产品基线：v0.10（build 49）

## 产品决策

Councis 只提供一个 Apple App：macOS Developer ID 签名、公证和直接下载分发的 `Councis`。

- Xcode project：`Councis.xcodeproj`。
- target/scheme：`CouncisMac`。
- App/product/executable：`Councis.app` / `Councis`。
- Bundle ID：`com.Vita0818.Councis`。
- entitlements：`Apps/CouncisMac/CouncisMac.DeveloperID.entitlements`。
- 不做 Mac App Store；旧 App Store target/profile/entitlements 已删除。
- 不提供 iOS App；旧 iOS target/source/resources 已删除。

删除 App Store/iOS 产品面不改变 Councis 的本地能力与安全合同。macOS 产品继续保留 Chat/Code/Cowork
runtime、workspace/global Skills、managed terminal、本地 Git、browser/document helper、Knowledge、
stdio + HTTP MCP；当前 UI 仍只显示 Cowork 入口，Chat/Code 实现与历史兼容保留。

## 发行入口

仓库唯一正式打包入口是 `scripts/package-macos-release.sh`。它只构建 `CouncisMac`，要求：

1. `project.yml`、参考 plist、当前文档与最终 App 均为 `0.10 (49)`；
2. `scripts/check-brand-boundary.sh` 通过；
3. 最终 App 为 `Councis.app`、executable `Councis`、Bundle ID `com.Vita0818.Councis`；
4. universal Release 同时包含 `arm64` 与 `x86_64`；
5. Keychain 中存在有效 `Developer ID Application` identity；
6. `COUNCIS_NOTARY_PROFILE` 指向用户通过 `notarytool store-credentials` 保存的 profile；
7. 使用 Developer ID entitlements、secure timestamp 与 Hardened Runtime 完成签名；
8. App 公证 Accepted、staple/validate、strict codesign、Gatekeeper assessment 全部通过；
9. DMG 含 `/Applications` 拖放入口，单独签名、公证、staple/validate、codesign、Gatekeeper 全部通过；
10. 最终输出 Councis ZIP、DMG 与 SHA-256 清单。

使用方式：

```sh
COUNCIS_NOTARY_PROFILE=<本机 profile 名称> \
  scripts/package-macos-release.sh
```

访问 GitHub 需要代理/VPN而 Apple notarization 需要另一网络时：

```sh
COUNCIS_PAUSE_BEFORE_NOTARIZATION=1 \
COUNCIS_NOTARY_PROFILE=<本机 profile 名称> \
  scripts/package-macos-release.sh
```

脚本在 GitHub 不再需要后暂停；保持终端和脚本运行，切换网络后按 Return。上传使用可见 progress，
记录 submission ID，再有界等待。默认等待 30 分钟，可用 `COUNCIS_NOTARY_TIMEOUT=2h` 等正时长调整。

若状态仍为 `In Progress`、网络失败、进程被中断或 Apple 返回 Invalid，脚本必须保留 owner-only
`.councis/release-recovery/<run>/`：root/run 为 `0700`，state 为 `0600`，目录/state/App 均非
symlink 且属于当前 UID。恢复命令：

```sh
COUNCIS_NOTARY_PROFILE=<本机 profile 名称> \
COUNCIS_RESUME_RELEASE_DIR=<脚本打印的绝对路径> \
  scripts/package-macos-release.sh
```

恢复必须复用原 App/DMG submission ID，不重新构建或重复上传；只有 ZIP、DMG、manifest 全部成功
落盘后才清理 recovery。可用 `COUNCIS_DEVELOPER_IDENTITY` 精确选择多个证书中的一个，
`COUNCIS_OUTPUT_DIR` 改输出位置。证书、私钥、账号凭据和 profile 内容不得进入仓库。

## App Sandbox 与 Councis sandbox 的区别

项目没有 Mac App Store target，也不启用 `com.apple.security.app-sandbox`。因此不得仅为 App Store
兼容而删除或禁用 managed terminal、PTY、spawn-based Git、browser helper、stdio MCP、global
Skills，或新增进程内替代实现。

这不等于取消安全边界。以下继续是产品合同：

- `DeterministicPolicyGate` / `ModelPermissionReviewer` / `PermissionEngine`；
- `CapabilityLease`、`WorkspaceLease`、`PathConfinement`、`SecretScanner`、Mediator；
- EventLog/durable tool ticket 与 checked recovery；
- managed terminal 的 workspace-scoped Seatbelt、默认断网、最小环境、输入清洗和进程清理；
- browser broker + Chromium native sandbox；绝不使用 `--no-sandbox`；
- Developer ID Hardened Runtime、代码签名、公证、Keychain 与最小 entitlements；
- 麦克风必须同时有 TCC usage description 和最小 `com.apple.security.device.audio-input=true`；
- `PlatformProfile.current = .restricted`，只有 `CouncisMac` 显式选择 `.macDeveloperID`。

文档提到 `sandbox` 时必须明确是已删除的 Mac App Store App Sandbox 历史，还是仍在运行的 Seatbelt、
测试宿主 sandbox、Linux bwrap/guard、Chromium native sandbox 或权限/工作区围栏。

## 默认验证矩阵

1. `scripts/check-version-consistency.sh` 与 `scripts/check-brand-boundary.sh`；
2. 与改动相称的 SwiftPM focused/full tests；
3. `swift build`、`swift build --product councis` 与 CLI selftest；
4. `xcodegen generate`；
5. `CouncisMac` Debug unsigned build；
6. `CouncisMac` universal Release unsigned build；
7. 读回 `Councis.app` 的版本、Bundle ID、executable、双架构、icon、link/resource inventory；
8. 触及实际发行时才运行 Developer ID 签名、公证、staple、Gatekeeper 和最终 ZIP/DMG gate。

没有 iOS/App Store target 可构建或作为 release gate。不得通过重新加入这些 target 来获得“额外验证”。
