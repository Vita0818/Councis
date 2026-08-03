# Intatis v0.32 直接工作树基线

快照日期：2026-08-03  
来源路径：`/Users/vita/Vitemis/Intatis`

## 来源身份

- branch：`main`
- base HEAD：`6436cc47f56836ff8421147ec1fdea614140c862`（提交标题 `v0.32`）
- base tree：`6189a1b39efbdc89158e8ebaac31897c30a0f05f`
- 来源状态：dirty；30 个 tracked 文件有未暂存修改，0 个 staged change，另有 4 个
  untracked、non-ignored 文件。
- 4 个来源新文件：`docs/README.md`、`docs/VERSIONING.md`、
  `scripts/check-version-consistency.sh`、`scripts/package-macos-release.sh`。
- 复制前所选内容：`git ls-files --cached --others --exclude-standard` 返回 740 个 regular file。
- 所选内容 manifest SHA-256：
  `697c0adb842c9591386cd0aa381c011c74ba7833d826b16d0339fad80f64da4e`。

由于来源工作树不干净，base HEAD 本身不能完整复现此次基线；上述 manifest 才是所复制内容
的身份。来源没有被修改，Councis 的 `.git` 也没有被替换。

## 复制范围

复制包含来源仓库全部 tracked 文件和 4 个 non-ignored 新文件，包括 `Vendor/`、
`ThirdPartyNotices/`、`Package.resolved`、工程配置、测试和项目级 `.agents` Skill。

复制明确排除：

- 来源 `.git`；
- `.build`、`.swiftpm` 与 vendored package build cache；
- `.DS_Store`；
- 生成的 `Intatis.xcodeproj`；
- Node `node_modules`、实验 `dist`、Playwright cache 与 TypeScript incremental 输出；
- 空的本地 `tmp/`。

旧 Councis `Upstream/Intatis`、专用 App、preset 和 v0.4 迁移代码不属于当前工作树；需要考古时
应读取 Git 历史，不要恢复双树结构。

## 后续更新规则

本仓库根目录是唯一活跃实现。后续任何功能、修复、格式化、构建和测试都在根目录执行。
如果未来再次刷新来源，应把它当成一次显式的整体基线替换，先记录来源状态和内容身份，再
更新本文与 `docs/CURRENT_STATE.md`；不要创建新的只读源码镜像。
