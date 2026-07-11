# TESTING

最近自查日期：2026-06-25

## 环境

- 操作系统 / 平台：macOS 13+（库与 CLI）；iOS 16+（IntatisiOS）；CLI 理论支持 Linux（`#if canImport(SwiftUI)` 守卫，无头）
- 工具链版本：Swift 5.9（`Package.swift:1`、`project.yml`）
- 依赖管理：SwiftPM（`Package.swift`）+ XcodeGen（`project.yml` → `Intatis.xcodeproj`）。v0.1 **零第三方依赖**。
- 凭据 / 配置：
  - GUI：Keychain（service `com.intatis.app`/`com.intatis.ios`，account `default-openai`）+ UserDefaults（`intatis.baseURL`、`intatis.model`）
  - CLI：env（`COUNCIS_*` / legacy `INTATIS_*`）+ `~/.councis/config.json`（`chmod 0600`）。CLI 不用 Keychain。

## 构建

### SwiftPM（库 + CLI + CouncisMac 可执行）

```sh
swift build                 # Debug
make build                  # 同上
swift build -c release      # Release，产物 .build/release/councis
make release                # 同上
make install                # 符号链接 .build/release/councis 到 BINDIR（默认 /usr/local/bin；BINDIR=$(HOME)/.local/bin 免 sudo）
```

### XcodeGen（.app bundle，SwiftPM 无法产 .app / iOS app）

```sh
make app                    # xcodegen generate && open Intatis.xcodeproj
xcodegen generate           # 仅生成工程
```

在 Xcode 中选择 `IntatisMac` / `IntatisiOS` / `CouncisMac` scheme 构建。

## 测试

```sh
swift test                  # 全部无头 XCTest
make test                   # 同上
```

- 测试 target（10）：`Packages/<Mod>/Tests/`。`IntatisSharedUI` 无测试。
- `swift test` 无头：无测试 target 依赖 UI/app target（`Package.swift:128`）。
- 跑特定测试：
  ```sh
  swift test --filter IntatisPermissionTests
  swift test --filter IntatisCoworkTests/OrchestratorTests
  ```

## Lint / Format

仓内无显式 lint/format 配置。`UNKNOWN` — 是否有 SwiftFormat/SwiftLint 需后续确认。建议至少 `swift build` 通过。

## 手动验证矩阵

| 场景 | 步骤 | 预期 | 状态 |
|---|---|---|---|
| CLI chat council | `swift run councis chat "你好"`（配好 key） | 候选并行 + judge 合成答案 | UNKNOWN（需真机 + key） |
| CLI work council | `swift run councis work "create note.txt"` | 写入审批 `[y/N]`，批准后写 note.txt | mock 路径已验证（`.councis/runs/` 有 mock 日志） |
| CLI council preset | `swift run councis chat --preset elite-chat "..."` | 用 `.councis/presets/elite-chat.json` 候选/judge | UNKNOWN |
| CLI config | `swift run councis config show` / `councis config set base_url ...` | 正确读写 `~/.councis/config.json` | UNKNOWN |
| CLI selftest | `swift run councis selftest` | 打印 `Mopelium selftest: OK`（注：源码字符串为 `Mopelium selftest`，疑似残留） | UNKNOWN — 需确认实际输出 |
| IntatisMac chat | `make app` → Xcode 运行 IntatisMac → chat 发消息 | 流式回复 | UNKNOWN（需真机 + key） |
| IntatisMac cowork | Xcode 运行 IntatisMac → cowork → @mention | agent 间路由 + 权限卡片 | UNKNOWN |
| IntatisiOS chat | Xcode 运行 IntatisiOS → chat | 流式回复，无工具/shell | UNKNOWN |
| iOS 子集边界 | 检查 IntatisiOS 链接的 product | 不含 Tools/Permission/AgentKernel/Cowork | 已确认（project.yml） |
| 权限门硬 deny | worker 尝试 spawn_agent | 被拒 | 已有测试覆盖 |

## 验证边界声明

- 文档任务：至少运行 `git diff --check` 与 `git status --short`；**未运行构建/测试**，须在最终报告中声明。
- 代码任务：按改动风险运行相称的 `make test` / `make build` / `make app`；未运行时须声明原因。
- `.councis/runs/` 含 23 个历史运行日志（22 个 2026-06-22、1 对 2026-06-25），其中样例为 `mock:true` 的 work 运行——可作为 council 行为参考，但不等价真机验证。

## 常见问题

- **Linux 构建**：`IntatisSharedUI` 用 `#if canImport(SwiftUI)` 守卫，包应能在 Linux 无头构建；但 `Interactive.swift` REPL 等 CLI 功能在 Linux 下的可用性 `UNKNOWN`。
- **Interactive.swift 死代码疑虑**：`IntatisCLI.main()` 的 switch 无 case 触达 REPL；若改动 CLI 命令分派，注意不要误激活未维护的 REPL 路径。
- **`selftest` 字符串残留**：`SelfTest.swift` 打印 `Mopelium selftest: OK`，疑似从 Mopelium 复制残留。`UNKNOWN` — 是否应改为 `Councis selftest` 需用户确认。
