# NEXT_TARGET

文档状态：当前目标已完成；等待用户指定下一目标
最近核对：2026-08-08
产品基线：v0.36（build 36）

## 已完成目标：同步 Cowork current-run 终态控制与 mailbox correlation

按用户指定清单，从固定 Intatis 提交
`5e86e525d97a3b8489e49f5514c06a9da944a09f` 选择性同步
`finish_run` / `stop_run`、RunID first-write close claim、exact-run admission/drain/restore
fence，以及 information request/reply 的 fresh correlation、stable conversation root、
`inReplyTo` / `basedOn` 和 no-ACK authority split。能直接复用的补丁与新增文件采用固定
Git blob；仅在 Councis Judge/品牌差异处三方合并。

## 已确认合同

- 只有 exact `@main` root、issuer=nil、current RunID 非空且 lease 含 `controlRun` 时才可见
  run-control tools；`@judge`、worker、child coordinator、mailbox task 与 reviewer 均不可见。
- 模型只提供有界 reason；session/run/Goal/submission/root TaskID 与 typed source 全由宿主绑定。
  普通 final 不伪造显式 close claim。
- in-process tombstone 先阻断重入 admission/authorization；durable first-write claim 先于等待旧
  admission 和 exact-run drain；恢复不得复活已 claim run，也不得影响其他 run。
- ordinary mailbox message one-way/no ACK；information request 只接受一个 exact
  `reply_message(inReplyTo:)` terminal；reply receipt 不 ACK，实质追问以 fresh RequestID +
  `based_on` 继续同一 conversation。
- EventLog/schema/lease/projection 只做 additive 演进，旧 JSONL 与 legacy nil correlation 继续
  保守解码，歧义 fail closed。
- fresh session 的固定 `@judge`、独立 read-only lease、Judge prompt/Skill 建议和 Main 动态
  决策权必须保持不变。

## 已实现范围

1. 直接应用与 Intatis v0.38 preimage 相同文件的 v0.39 原始补丁。
2. 整文件复制 5 个新增 Swift 源码/测试文件。
3. 三方合并带 Councis Judge/品牌差异的源码、测试、Skill 与合同文档。
4. 增加 Main/Judge `controlRun` 隔离回归。
5. focused/full SwiftPM、Skill validator、版本一致性与 macOS/iOS unsigned Debug build
   均已通过；完整 suite 首次瞬时停滞经隔离重跑和完整重跑确认为非稳定失败。
6. 已按用户建议初始化 Computer Use 并两次尝试连接；Sky 服务均在启动阶段失败，未能进行真实
   UI smoke，也没有改用 AppleScript 绕过该技能。此项环境限制不影响源码/测试/构建结论，不能
   被表述为 GUI 已验收。

## 边界

本轮不改 App UI、版本、工程配置、依赖、发行脚本或第三方声明，不修改 Intatis 来源仓库，也不
重写 Councis 品牌/Judge 产品边界。历史 incident report 保留为当时调查记录；若其“普通 Main final
自动安装 close claim”建议与已提交 v0.39 源码冲突，以当前实现和回归
`testRootFinalResponseDoesNotForgeExplicitRunCloseClaim` 为准。
