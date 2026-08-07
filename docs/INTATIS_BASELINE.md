# Intatis 直接工作树基线（源提交 2d849db）

快照日期：2026-08-06

来源路径：`/Users/vita/Vitemis/Intatis`

目标根目录：`/Users/vita/Vitemis/Councis`

## 来源身份

- branch：`main`
- source HEAD：`2d849dbe592a4532a23d0b5a0f84c4e52e459505`（提交标题 `v0.37`）
- source tree：`6d046befde8af37126b3300f155721de433f6202`
- 产品版本：`project.yml` 中的 `MARKETING_VERSION = 0.36`、
  `CURRENT_PROJECT_VERSION = 36`；提交标题不是产品版本事实源。
- 快照采集时来源状态：clean；0 个 tracked/staged change，0 个 untracked non-ignored 文件，无 submodule。
- 来源选择：`git ls-files` 返回 754 个 tracked path。
- 来源 tracked-content manifest SHA-256：
  `b663cdad158e775d2bb1f8ebfef41e479cda588ff00fa932e95ea79264f3278a`。

manifest 的生成方式是在来源根目录按 `git ls-files -z` 顺序对每个路径执行 SHA-256，再对包含
路径与逐文件摘要的完整输出再次执行 SHA-256。来源工作树干净，因此 source HEAD/source tree
可以复现本次所选业务内容；来源仓库没有被修改，Councis 的 `.git`、remote 与历史也没有被替换。
快照完成后来源工作树可以继续变化；后续一致性检查必须比较上述固定 commit tree/blob，不能把
`/Users/vita/Vitemis/Intatis` 当下未提交的工作树内容重新解释为本基线。

## 落盘方式与边界

本次从 source HEAD 直接生成 Git archive，并解包到 Councis 根目录。源码、测试、工程配置、
`Vendor/`、`ThirdPartyNotices/`、脚本、报告和 Intatis 当前文档均取自该提交；相比上一基线，
来源增加的 14 个 tracked path 也已直接进入根工作树。

以下内容属于 Councis 专属控制层，不被 Intatis 快照覆盖：

- 根 `AGENTS.md`：保留 Councis 路径、工作规则和身份文档入口；
- `docs/COUNcis_IDENTITY.md`：记录 Councis 作为 Cowork 有限特性变体的范围与非目标；
- 本文：记录精确来源、复制方法和复现边界。

以下三个来源文档允许保留最小 Councis 项目覆盖：

- `docs/README.md`：文档权威层级与项目入口；
- `docs/CURRENT_STATE.md`：快照能力与 Councis 实现状态；
- `docs/NEXT_TARGET.md`：Councis 当前唯一下一目标，不继承 Intatis 的临时发版任务。

2026-08-06 初次落盘时，除根 `AGENTS.md` 外的 753 个来源 tracked path 已逐文件验证一致。
文档校准后，根 `AGENTS.md` 与上述三个来源文档成为有意差异。随后经用户明确授权增加一层
纯展示品牌覆盖：Apple `CFBundleDisplayName`/参考 plist、麦克风权限说明与 iOS Settings 文案，
macOS/iOS/CLI 的可见标题、占位符、提示与错误文案，共享本地化目录、诊断导出显示名称，以及
OAuth 浏览器页/动态注册的可见 client name 使用 `Councis`。与这些输出直接耦合的最小测试期望
同步更新；这组差异不改变运行逻辑。

上述品牌覆盖没有更改 Swift target/module/type、bundle ID、可执行文件和 `intatis` 命令、
App icon 资产名、配置/存储路径与 key、Keychain/UserDefaults namespace、日志 subsystem、启动
参数、协议/schema、持久化格式或 model-facing prompt；这些仍与固定来源提交一致。
工作区策略拒绝重复覆盖受保护的 `.agents/` 文件及恢复其目录时间戳，但目录级递归 diff 为空，
因此该提示不构成内容缺口。

## Councis 修改范围

该快照是唯一实现起点。除独立、纯展示的 `Councis` 品牌覆盖外，已实现的有限差异是在 fresh Cowork
session 中增加固定数据面身份 `@judge` 与 `judge_model` 配置，并通过 Main/Judge 系统提示词和
Cowork Skill 提供协作建议。它不改变既有 Cowork 工作流程，不代表重做整个 Intatis 产品、合并现有模式或为 Chat/Code
引入全局新合同。当前基线能力继续由来源架构、状态、测试和禁区文档描述；项目定位以
`docs/COUNcis_IDENTITY.md` 为准。只有该最小修饰真实影响相应事实时，才同步修改来源文档。

来源 `.git`、ignored/untracked 构建缓存、`.build`、`.swiftpm`、生成的 `Intatis.xcodeproj`、
`.DS_Store`、`node_modules`、`dist`、Playwright cache 和 `tmp/` 不属于 source HEAD archive，
也不属于本基线身份。目标仓库的 `Intatis.xcodeproj` 已在落盘后由新 `project.yml` 重新生成以
通过版本一致性检查，但它和其他 ignored 本地生成物仍是派生产物，不属于快照内容身份。

旧 Councis 专用 App、preset、v0.4/v0.5 迁移代码只保留在本仓库 Git 历史中，没有与当前
Intatis 基线混合。需要考古时读取 Git 历史，不要恢复 `Upstream/Intatis` 或双树结构。

## 后续更新规则

本仓库根目录是唯一活跃实现。后续任何功能、修复、格式化、构建和测试都直接在根目录执行，
不得对照 `/Users/vita/Vitemis/Intatis` 另写一套实现。如果未来再次刷新来源，应把它作为一次
显式整体基线替换：先核对两边 Git 状态，再记录 source HEAD/tree、内容 manifest、排除项和
Councis 控制层差异，并更新根 `AGENTS.md`、本文、`docs/COUNcis_IDENTITY.md` 及三个最小项目
覆盖文档。除非用户明确要求或真实 Cowork 特性已经影响相应合同，不得为添加 Councis 注解而
修改从 Intatis 快照取得的其他文档。
