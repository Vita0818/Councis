# Intatis 直接工作树基线（源提交 120eda6）

快照日期：2026-08-14

来源路径：`/Users/vita/Vitemis/Intatis`

目标根目录：`/Users/vita/Vitemis/Councis`

## 来源身份

- branch：`main`
- source HEAD：`120eda64fcb098f1bdc4852fee886450e80b3722`（提交标题 `v0.54`）
- source tree：`7fe2842aeec8fa08bec80e34342f971dc4226dcd`
- 产品版本：`project.yml` 中的 `MARKETING_VERSION = 0.48`、
  `CURRENT_PROJECT_VERSION = 48`；提交标题不是产品版本事实源。
- 快照采集时来源状态：clean；0 个 tracked/staged change，0 个 untracked non-ignored 文件。
- tree 条目：903 个，其中 870 个普通 `100644` blob、7 个可执行 `100755` blob、
  26 个 `160000` gitlink。
- `git archive --format=tar 120eda64fcb098f1bdc4852fee886450e80b3722` 的 SHA-256：
  `d75787128446e6ad1cf2976ee42491ef10eb5bac7998572afe38f5d2e398c026`。

准备快照期间来源曾从 `v0.53` 前进到 `v0.54`。旧的中间归档没有用于根替换；最终落盘只读取
上述固定 commit object，因此后续来源工作树继续变化不会改变本基线身份。

## 落盘方式

1. 先确认 Councis 的 `pwd` 与 Git root 都是 `/Users/vita/Vitemis/Councis`，且替换前工作树
   没有用户未提交改动。
2. 备份六份 Councis 控制/覆盖文档，并记录逐文件 SHA-256。
3. 以固定 source HEAD 执行 Git archive，解包到独立临时目录；没有复制来源 `.git`。
4. 将归档中的源码、配置、测试、通用文档、脚本、资源、声明和 tracked 报告覆盖到 Councis
   根目录，同时排除六份 Councis 文档。
5. 删除旧基线中已不属于 source tree 的 3 个普通 tracked 文件，并清除旧 `.build`、`.swiftpm`、
   生成的 `Intatis.xcodeproj`、`.DS_Store` 和过时的并列 `Intatis/` 中间快照。
6. 按来源实际工作树规范化落盘权限（包括 8 份 `0444` 第三方许可证），并逐一比较所有
   非 Councis 覆盖 blob 的内容与权限。

旧基线中按 source tree 删除的文件是：

- `Packages/IntatisConversation/Sources/ExplicitGoalIntent.swift`
- `Packages/IntatisConversation/Tests/ExplicitGoalIntentClassifierTests.swift`
- `codex-report/08_07_26-21_56-cowork-run-terminal-control-and-mailbox-livelock-report.md`

与替换前 Councis index 比较，source tree 另有 146 个新条目；其余同路径 tracked 文件直接覆盖。
源提交中存在一个字面文件名为 `:-` 的顶层 blob，它不是本轮临时文件，已按 source tree 保留。

## Councis 保留层

以下文件没有直接采用 Intatis 版本，而是在技术内容对齐新基线后保留 Councis 项目覆盖：

- 根 `AGENTS.md`：Councis 路径、工作规则、目标身份和基线入口；
- `docs/COUNcis_IDENTITY.md`：Councis 目标范围与非目标；
- 本文：固定来源、复制方法、排除项和验证边界；
- `docs/README.md`：文档权威层级与 Councis 入口；
- `docs/CURRENT_STATE.md`：Intatis 当前能力与 Councis 当前实现差异；
- `docs/NEXT_TARGET.md`：Councis 唯一下一目标，不继承 Intatis 临时发行任务。

Councis 自己的 `.git`、remote、index 和历史也保留；本轮没有执行 `git add`、commit、branch、push
或 PR 操作。根工作树是唯一活跃实现，不存在 `Upstream/Intatis` 或并列 `Intatis/` 实现树。

## 排除项与 gitlink 边界

下列内容不属于固定 commit 的普通 blob，因此没有从来源工作区复制：

- 来源 `.git`、ignored/untracked 内容和 nested repository metadata；
- `.build`、`.swiftpm`、生成的 `Intatis.xcodeproj`、`.DS_Store`、临时目录与工具缓存；
- `/Users/vita/Vitemis/Intatis/OpenSource/` 下各 nested checkout 的实际工作树内容。

source tree 的 26 个 `OpenSource/*` 条目是 `160000` gitlink，但仓库没有能让
`git submodule status` 完整解析它们的 `.gitmodules` mapping。Git archive 只表示这些 gitlink
目录，不包含嵌套仓库的 blob；本轮也没有用 `git update-index` 把 gitlink 写入 Councis index。
它们的精确 object identity 仍由固定 source tree 保存。当前构建使用仓内 `Vendor/`、SwiftPM
依赖和 `NOTICE.md` 所描述的采用项；不得把外部 checkout 当成已复制的产品源码。

## 当前 Councis 差异状态

整体替换落盘时，业务源码、配置、测试和 `.agents/` 中没有 `Councis`、固定 `@judge` 或
`judge_model` 实现。2026-08-15 按用户两次明确授权，在当前根工作树重新实现了：

- 用户 UI 控制面品牌覆盖：macOS/iOS App 显示名、应用内 UI、系统权限/设置说明、MCP 授权
  交互、诊断导出说明及共享 GUI 错误显示 `Councis`；
- macOS Cowork-only 可见入口：默认选择 Cowork，并隐藏而不删除 Chat/Code/模式导航；
- fresh Cowork 固定 `@judge`、macOS/modern CLI 顶层 `judge_model` exact binding、独立 read-only
  lease/identity、Main/Judge system prompt、Cowork orchestration Skill 与直接回归测试。

2026-08-17 用户进一步明确授权 Councis 底层产品身份脱钩：

- SwiftPM package、public/internal targets、test targets、Apps/Packages/source symbol、Xcode project、
  App、CLI、配置/存储/日志/协议 canonical namespace 改为 Councis；
- 唯一 App 为 macOS Developer ID `Councis.app`，target `CouncisMac`，Bundle ID
  `com.Vita0818.Councis`；
- iOS App 与遗留 Mac App Store target/source/entitlements 删除；
- 旧 Intatis 名称只保留在本文等来源证明、只读 legacy bridge/decode、安全保护和对应 fixture；
  新 writer 不再产生旧 identity。精确清单见 `docs/COUNcis_DECOUPLING_CHECKLIST.md`。

因此当前边界是：

- 业务能力继续源自上述固定 Intatis `v0.54` source tree，但当前活跃产品/工程/runtime identity 已是
  Councis；这项派生关系必须由本文与 NOTICE 保留，不得改写成无来源原创；
- Swift target/module/type、Bundle ID、可执行文件、App 图标资源名、CLI、配置、存储、日志和
  协议 canonical namespace 均使用 Councis；
- fresh Cowork 现在用既有 EventLog event types 以十事件 batch 原子登记 `@main`、`@judge` 和
  `@permission-reviewer`；没有新增 Envelope、EventLog event type 或 session schema；
- Judge 是固定 ordinary read-only data-plane identity，不是权限审查者、Goal Verifier、run authority
  或自动 worker；既有非空历史 session 不会自动补写 Judge；
- Chat/Code 源码、session 历史兼容和 runtime 仍保留；项目不再提供 iOS App；
- 后续实现只能直接修改本根工作树，并针对 `v0.54` 当前架构逐项审查和验证；不得机械恢复旧
  blob、旧补丁或旧测试数量，也不得修改来源仓库。

## 验证与后续规则

基线替换落盘时的内容核验以固定 source commit 为准：source tree 的 877 个 blob 中，4 个同路径文件属于
有意的 Councis 文档覆盖（根 `AGENTS.md`、`docs/README.md`、`docs/CURRENT_STATE.md`、
`docs/NEXT_TARGET.md`）；其余 873 个 blob 必须与来源工作树逐文件字节和实际权限一致。另有
2 份只存在于 Councis 的控制文档。旧基线的 3 个 source-deleted 文件必须不存在。文档修改后
还必须运行 `git diff --check` 与 `git status --short`。2026-08-15 之后，当前工作树与固定 source
tree 的额外差异仅允许来自本文记录的 Councis UI/Judge 差异和 2026-08-17 用户明确授权的底层
identity 脱钩及后续明确实现。

本次没有复制或信任旧构建缓存，也没有把 Intatis 源仓已有的历史测试/发行证据解释为 Councis
新根工作树的验证。2026-08-15 已从 `project.yml` 重新生成 Xcode 工程，并在 Councis 根工作树
重新运行 SwiftPM build、Judge/配置/prompt 定向测试与当时的 `IntatisMac` unsigned Debug build；
该结果只是脱钩前历史。2026-08-17 起必须以当前 `CouncisMac` / `Councis.app` 构建和新命名测试结果
为准；精确命令、通过数量和未运行项见 `docs/CURRENT_STATE.md` 与 `docs/TESTING.md`。

未来若再次刷新来源，必须作为新的显式整体基线替换：先核对两边 Git 状态，固定 source
HEAD/tree/archive digest，重新记录 tracked 条目、gitlink、排除项和 Councis 保留层，并同步更新
根 `AGENTS.md`、本文、`docs/COUNcis_IDENTITY.md`、`docs/README.md`、
`docs/CURRENT_STATE.md` 与 `docs/NEXT_TARGET.md`。
