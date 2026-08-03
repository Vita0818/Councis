# TEAM_PRESETS — AI Agent 编写与存放指南

本文面向在 Councis 仓库中工作的 AI Agent。目标是让 Agent 能够安全、确定性地创建或修改 CLI Team Preset，并准确说明它何时生效、如何验证、哪些内容绝不能写入。

本文描述当前工作树中的 schema v2。若本文与以下源码冲突，以源码为准，并同步修正文档：

- `Apps/intatis-cli/Sources/TeamPreset.swift`
- `Apps/intatis-cli/Sources/CLIConfig.swift`
- `Apps/intatis-cli/Sources/IntatisCLI.swift`
- `Apps/intatis-cli/Sources/Interactive.swift`
- `Packages/IntatisCowork/Sources/ModelAssignmentPolicy.swift`

## 1. 先判断是否应该写 Team Preset

仅在目标是配置 **Councis CLI 的异构模型团队** 时写 Team Preset。

Team Preset 负责：

- 固定 `@main` 的完整 `providerID/modelID` binding。
- 固定 `@judge` 的完整 `providerID/modelID` binding。
- 声明有序的 Worker model pool。
- 声明模型唯一性与 pool 耗尽策略。
- 保存不含秘密的 provider 展示 metadata。

Team Preset 不负责：

- endpoint URL、API key、token 或 credential reference。
- tool、workspace、shell、Git 或网络权限。
- Judge 的身份、权限、轮次、deadline 或故障生命周期。
- `@permission-reviewer` 的模型唯一性或权限策略。
- 每个角色独立的 reasoning、temperature、system prompt、上下文上限或 `maxSteps`。
- CouncisMac 的团队选择。

如果用户要求配置 CouncisMac，停止套用本文的 JSON 方案，转而检查 Provider Settings、`CoworkTeamConfiguration` 和项目持久化配置。CouncisMac 当前不加载 `.councis/presets/*.json`。

## 2. 文件应该保存在哪里

CLI 按以下顺序查找 `<name>.json`：

1. 当前工作目录下的 `.councis/presets/<name>.json`
2. 用户目录下的 `~/.councis/presets/<name>.json`

项目级同名文件优先于用户级文件。

这里的“项目级”严格指 **启动 `councis` 进程时的当前工作目录**。它不是
`--workspace` 指向的目录。要使用仓库内 preset，应先把 cwd 切到该仓库根目录；
从其他目录启动并传入 `--workspace` 不会改变 preset 查找根。

选择原则：

- 团队配置属于仓库、需要版本管理或需要团队共享时，写入：

  ```text
  <repository-root>/.councis/presets/<name>.json
  ```

- 配置仅供当前用户跨仓库复用时，写入：

  ```text
  ~/.councis/presets/<name>.json
  ```

- 未经用户明确要求，不要从仓库任务越界写入用户目录。
- 两个位置都不得保存秘密。
- preset 文件名只使用 ASCII 字母、数字、点、下划线和连字符：

  ```regex
  ^[A-Za-z0-9._-]+$
  ```

- `name` 字段应与文件名保持一致。当前 decoder 不强制二者相同，但 Agent 不应制造这种歧义。

示例：

```text
.councis/presets/research-work.json
~/.councis/presets/personal-chat.json
```

## 3. Preset 如何被选择

有效选择优先级为：

1. CLI 参数 `--preset <name>`
2. 环境变量 `COUNCIS_PRESET`
3. `~/.councis/config.json` 中的 `preset`
4. mode 默认值

mode 默认值：

| Mode | 默认 preset |
|---|---|
| `chat` | `elite-chat` |
| `work` | `elite-work` |

显式运行示例：

```sh
swift run councis chat --preset research-chat
swift run councis work --preset research-work --workspace /absolute/project/path
```

不要把一个固定的 Chat preset 写进全局 `preset` 配置后再假定 Work 会自动切换；preset 的 `mode` 与启动 mode 不一致时，加载会失败。需要同时支持 Chat 和 Work 时，分别创建两个命名文件，或在启动命令中显式使用 `--preset`。

会话内使用 `/mode` 切换表面时，当前实现会加载目标 mode 的默认 preset，而不是
沿用本次启动时显式选择的自定义 preset。需要继续使用自定义团队时，应退出后用
对应 mode 和 `--preset` 重新启动。

## 4. Schema v2 完整模板

新文件必须使用显式、可审计的 schema v2。不要依赖 legacy alias、字段缺省或未知字段被忽略的行为。

```json
{
  "schemaVersion": 2,
  "name": "research-work",
  "mode": "work",
  "main": {
    "name": "Main",
    "providerID": "primary",
    "model": "main-model-id",
    "required": true
  },
  "judge": {
    "name": "Judge",
    "providerID": "review",
    "model": "judge-model-id",
    "required": true
  },
  "workerModelPool": [
    {
      "name": "Researcher",
      "providerID": "primary",
      "model": "worker-model-id-1"
    },
    {
      "name": "Verifier",
      "providerID": "secondary",
      "model": "worker-model-id-2"
    }
  ],
  "modelAssignment": {
    "strategy": "unique",
    "onPoolExhaustion": "fail",
    "excludeControlPlaneAgents": true
  },
  "providers": [
    {
      "id": "primary",
      "displayName": "Primary OpenAI-compatible endpoint",
      "configHint": "Configure endpoint and apiKeyEnv in ~/.councis/config.json"
    },
    {
      "id": "review",
      "displayName": "Review OpenAI-compatible endpoint",
      "configHint": "Configure endpoint and apiKeyEnv in ~/.councis/config.json"
    },
    {
      "id": "secondary",
      "displayName": "Secondary OpenAI-compatible endpoint",
      "configHint": "Configure endpoint and apiKeyEnv in ~/.councis/config.json"
    }
  ]
}
```

JSON 不支持注释。不要把解释性 `//` 或 `/* ... */` 写进文件。

## 5. 字段语义

### 5.1 顶层字段

| 字段 | 新文件要求 | 当前语义 |
|---|---|---|
| `schemaVersion` | 必须写 `2` | 当前 Team Preset schema 版本 |
| `name` | 必须写 | preset 展示名；应与文件名一致 |
| `mode` | 应显式写 | 只能为 `chat` 或 `work`；防止在错误 surface 启动 |
| `main` | 必须写 | 固定 `@main` binding |
| `judge` | 必须写 | 固定 `@judge` binding |
| `workerModelPool` | 必须显式写数组 | 有序 Worker binding 池；允许空数组 |
| `modelAssignment` | 必须显式写 | 严格模型分配策略 |
| `providers` | 建议写 | 仅非秘密 metadata；省略时 runtime 会按角色推导简化 metadata |

当前 decoder 尚未强制验证 `schemaVersion` 的支持范围，因此其他整数也可能被读取。
这不是兼容承诺；AI Agent 必须固定写 `2`。

`mode` 的未知字符串当前可能被当作“未识别 mode”而跳过 mode mismatch 检查。
这同样不是可依赖行为；只能写精确的 `chat` 或 `work`。

### 5.2 Agent definition

`main`、`judge` 和每个 Worker entry 使用相同字段：

| 字段 | 新文件要求 | 当前语义 |
|---|---|---|
| `name` | 建议写 | 人类可读标签，不改变保留 Agent ID |
| `providerID` | 必须显式写 | 必须能解析到 CLI provider config 中的 provider |
| `model` | 必须写且非空 | endpoint 暴露的真实 model ID |
| `required` | Main/Judge 可保留为 `true` | 当前仅被 decode/encode，运行时没有额外行为 |

注意：

- `main.name` 不能把运行时 `@main` 改名。
- `judge.name` 不能把运行时 `@judge` 改名。
- legacy `provider` 字段和省略 `providerID` 的兼容行为只用于读取旧文件；新文件必须写 `providerID`。
- `required` 当前不是 admission 策略开关。不要声称把 Worker 写成 `required: true` 会自动创建该 Worker。
- model ID 虽然会用 trim 后的结果检查“是否为空”，当前 runtime 仍保留原字符串。
  不要在 `model` 两端留下空白。

### 5.3 `modelAssignment`

新文件应使用：

```json
{
  "strategy": "unique",
  "onPoolExhaustion": "fail",
  "excludeControlPlaneAgents": true
}
```

字段含义：

- `strategy`
  - 当前可运行的 Councis 值是 `unique`。
  - `legacy-compatible` 可以被 decoder 读取，但 strict Cowork runtime 会拒绝它。新文件不得使用。
- `onPoolExhaustion`
  - `fail`：没有未占用 Worker binding 时直接拒绝。
  - `require-explicit-model`：返回 ask-user/需要显式选择的结果。
  - 两者都不会自动复用 Main、Judge 或父 Agent binding。
  - `require-explicit-model` 不授权使用 pool 之外的任意模型；用户仍需选择 policy 允许的 binding，或修改并扩充 preset。
- `excludeControlPlaneAgents`
  - 必须为 `true`。
  - 这表示 `@permission-reviewer` 不占数据平面的唯一 binding 槽。
  - 这不适用于 `@judge`；Judge 是特殊数据平面 Agent，必须独占 binding。

### 5.4 `providers`

Preset 中的 `providers` 只是非秘密 metadata：

```json
{
  "id": "primary",
  "displayName": "Primary endpoint",
  "configHint": "Configure endpoint and apiKeyEnv in ~/.councis/config.json"
}
```

它不会创建 endpoint，也不会提供凭据。以下字段绝不能出现在 Team Preset：

- `baseURL`
- `apiKey`
- `token`
- `password`
- credential file path
- Keychain reference
- 完整认证响应

当前运行路径不使用 `providers`、`displayName` 或 `configHint` 做 provider routing；
真实 routing 只依赖角色定义中的 `providerID` 和 CLI provider config。

## 6. 完整 binding 与唯一性

Councis 使用完整的：

```text
(providerID, modelID)
```

作为模型 binding。

Agent 在写文件前必须对 `[main, judge] + workerModelPool` 执行以下检查：

1. 每个 `providerID` 都能解析到 CLI provider config。
2. 每个 `model` 都是非空字符串。
3. 每个完整 `providerID/model` 组合在整个 preset 中只出现一次。
4. Main 与 Judge 必须不同。
5. Worker 不能复用 Main 或 Judge binding。
6. Worker pool 内部也不能有重复 binding，即使这些 Worker 不会同时创建。

同一个 model ID 位于不同 provider 时是两个不同 binding，因此以下组合合法：

```json
{
  "main": {
    "providerID": "provider-a",
    "model": "shared-model"
  },
  "judge": {
    "providerID": "provider-b",
    "model": "shared-model"
  }
}
```

但只有在两个 provider 都真实配置、且都暴露该 model ID 时才能运行。

`openai-compatible` 有一条兼容解析规则：如果 CLI 只配置了一个 provider，preset 中的通用 `openai-compatible` 可以解析到该 provider。Agent 不应在多 provider 配置中依赖这个歧义；多 provider preset 应写精确 provider ID。

## 7. Provider 配置必须与 Preset 分离

CLI endpoint 配置位于：

```text
~/.councis/config.json
```

新配置应优先引用环境变量，不把秘密直接写入文件：

```json
{
  "defaultProvider": "primary",
  "providers": [
    {
      "id": "primary",
      "baseURL": "https://provider.example/v1",
      "apiKeyEnv": "PRIMARY_API_KEY",
      "wire": "openai"
    },
    {
      "id": "review",
      "baseURL": "https://review.example/v1",
      "apiKeyEnv": "REVIEW_API_KEY",
      "wire": "openai"
    }
  ]
}
```

当前 shipped wire format 只有 `openai`。

AI Agent 的安全要求：

- 不读取、打印或复制环境变量中的 key。
- 不把真实 key 写进示例、preset、报告或错误说明。
- 未经用户明确要求，不修改 `~/.councis/config.json`。
- 修改该文件时必须维持 `0600`，并只记录 secret 是否已配置，不记录内容。
- preset 中每个 `providerID` 必须与这里某个 provider `id` 对应。

## 8. Chat 与 Work 应分开写

Chat 与 Work 使用同一 Cowork 内核，但 capability/workspace envelope 不同。不要通过 preset 的自定义字段试图授予工具权限。

建议成对命名：

```text
.councis/presets/research-chat.json
.councis/presets/research-work.json
```

两个文件可以共享模型分配，但 `mode` 必须分别为：

```json
"mode": "chat"
```

和：

```json
"mode": "work"
```

Chat 不会因为 preset 添加 `tools`、`shell` 或 `workspace` 字段而获得这些能力。未知字段可能被 decoder 忽略，但 Agent 不得利用或依赖这一点。

未知字段会被忽略也意味着拼写错误可能静默退化为字段缺省行为。写完后必须按
canonical 字段名逐项复核，不能只以“JSON 能 decode”作为正确证据。内部兼容状态
`source` 也不是 JSON 字段，不得写入 preset。

## 9. Worker pool 的运行行为

Worker pool 是有序集合，不是启动时自动 fan-out 的 Agent 列表。

- 启动 session 时固定挂载 Main 和 Judge。
- Worker 只有在用户或协调逻辑请求创建时才会挂载。
- 省略显式 binding 时，选择第一个满足 capability 且未占用的 pool entry。
- Worker 不继承创建它的父 Agent 模型。
- 活跃和 admission-pending Agent 都占用 binding，避免并发创建抢占同一个模型。
- detach 成功后 binding 才能再次使用。

CLI 会话内检查与操作：

```text
/team
/agent add researcher
/agent add verifier /absolute/workspace/path secondary/worker-model-id-2
/agent remove researcher
```

`/team` 用于查看固定 Main/Judge、Judge health、Worker pool 及占用状态。普通命令不能删除或替换 Main/Judge。

## 10. Judge 与 Permission Reviewer

不要在 preset 中混淆两个 reviewer：

| 身份 | 是否写入 Team Preset | 是否占独立数据平面 binding |
|---|---|---|
| `@judge` | 是，使用顶层 `judge` | 是，且不能复用 Main |
| `@permission-reviewer` | 否 | 否，可复用 Main |

Preset 只决定 Judge 的完整模型 binding。Judge 的保留 ID、只读 profile、depth 0、reviewer leases、强制 review、deadline、quarantine 和 shutdown barrier 都由 runtime 固定，不能由 JSON 降级或关闭。

## 11. CouncisMac 差异

CouncisMac 当前不读取命名 Team Preset。

它从 Provider Catalog 自动派生：

1. 当前选中的 binding 固定为 Main。
2. 选择第一个不同 binding 作为 Judge，并优先不同 model ID。
3. 剩余 binding 按 catalog 顺序进入 Worker pool。
4. 少于两个唯一 binding 时拒绝创建或恢复 Councis Cowork。
5. 派生结果作为 `teamConfiguration` 随项目持久化；恢复时继续验证原绑定是否存在。

因此：

- 新建 `.councis/presets/foo.json` 不会改变 CouncisMac。
- 项目设置页当前主要展示派生结果，不是命名 preset 编辑器。
- 如果用户要求 CLI 与 Mac 共用 preset，标记为尚未实现的产品能力，不要声称已有支持。

## 12. 当前仓库内置 Preset

| 文件 | Mode | 用途 |
|---|---|---|
| `.councis/presets/elite-chat.json` | Chat | 默认 Chat 团队 |
| `.councis/presets/elite-work.json` | Work | 默认 Work 团队 |
| `.councis/presets/elite.json` | Chat | 兼容/显式选择名称 |
| `.councis/presets/smoke.json` | Chat | fake model/schema 示例，不用于普通 endpoint |

内置 Elite model ID 是 endpoint-specific 示例。文件通过本地结构校验，不代表用户 endpoint 一定提供这些模型。AI Agent 在创建新 preset 时必须使用用户实际 provider catalog 中存在的 model ID，或明确标记为需要用户确认。

`councis selftest` 当前使用源码内嵌的 fake provider 和内嵌 preset JSON，不直接读取
`.councis/presets/smoke.json`。不要把 selftest 通过描述成 `smoke.json` 已被加载。

## 13. 创建或修改 Preset 的标准流程

AI Agent 应按顺序执行：

1. 确认仓库根目录和 `git status --short`，保留所有既有用户改动。
2. 读取当前 `TeamPreset.swift`、`CLIConfig.swift` 和 `ModelAssignmentPolicy.swift`。
3. 确认目标是 CLI，而不是 CouncisMac。
4. 确认目标 mode、preset 名称和保存层级。
5. 获取 provider ID 与 model ID 的非秘密清单；无法确认远端模型时标记 `UNKNOWN`，不得编造。
6. 对 Main、Judge 和全部 Worker 做完整 binding 唯一性检查。
7. 使用 schema v2 模板写 JSON；不添加秘密或未经支持的字段。
8. 验证 JSON 语法。
9. 做静态 schema/约束复核。
10. 只有在用户已配置凭据且授权真实调用时，才执行真实 endpoint smoke。
11. 运行 `git diff --check` 和 `git status --short`。
12. 最终报告列出实际写入位置、选择命令、验证结果与未验证的 endpoint 边界。

## 14. 验证方法

### 14.1 JSON 语法

可使用：

```sh
python3 -m json.tool .councis/presets/<name>.json
```

这只验证 JSON 语法，不验证 Councis schema 或远端模型存在性。

### 14.2 静态约束

人工或脚本检查：

- `schemaVersion == 2`
- `name` 与文件名一致
- `mode` 为 `chat` 或 `work`
- `main`、`judge` 存在
- 每个 role 都显式含 `providerID` 和非空 `model`
- 完整 binding 全局唯一
- `strategy == "unique"`
- `excludeControlPlaneAgents == true`
- `onPoolExhaustion` 为 `fail` 或 `require-explicit-model`
- 没有 endpoint、key、token 或 credential 字段

当前 CLI 没有独立的 `preset validate` 子命令。不要把 `councis selftest` 描述成对任意自定义 preset 的验证；它验证的是内置 fake provider 和 schema 兼容路径。

以下命令也不验证自定义 preset：

- `swift run councis config`：只解析并展示 provider/config 状态。
- `swift run councis ... --help`：在加载 preset 前退出。

### 14.3 Runtime 加载

在 endpoint 与凭据已经安全配置后，可启动无 prompt 的 REPL，观察加载和固定团队 admission：

```sh
swift run councis chat --preset <name>
swift run councis work --preset <name> --workspace /absolute/project/path
```

启动后运行：

```text
/team
```

确认：

- Main 与 Judge binding 正确。
- Judge health 为 `healthy`。
- Worker pool 顺序正确。
- 没有重复或未知 provider。

退出 REPL 不证明模型真实可调用。真实 smoke 还需提交一个有界 prompt，并确认 Main、Judge 和需要时的 Worker 都由对应 endpoint/model 执行。没有用户授权时不要触发付费或外部模型调用。

CLI 启动时只强制检查 default provider 的 key。若 Judge 或 Worker 使用其他 provider，
该 provider 缺少凭据的问题可能直到对应 Agent 第一次调用时才暴露。

### 14.4 文档和 Git 检查

```sh
git diff --check
git status --short
```

不要自动 add、commit 或 push。

## 15. 常见失败及处理

| 错误/现象 | 原因 | Agent 应如何处理 |
|---|---|---|
| `missing team preset` | 两个发现位置都没有对应文件 | 核对当前目录、文件名和 `--preset` |
| `preset ... is for chat/work` | preset mode 与启动 mode 不一致 | 使用匹配文件，不要删除 mode 来掩盖错误 |
| `unknown provider` | `providerID` 不在 CLI provider config | 修正 provider ID；不要把 metadata 当 endpoint 配置 |
| `reuses provider/model` | Main/Judge/Worker 存在重复完整 binding | 分配不同 provider/model 组合 |
| `legacy-compatible ... migrate it` | strict runtime 不接受复用策略 | 改为 `unique` 并消除重复 |
| `worker model pool is exhausted` | 所有兼容 Worker binding 已占用或 pool 为空 | detach 不再需要的 Worker，或扩充 preset |
| `binding ... absent or ambiguous` | 显式 model 不是唯一 pool entry | 使用完整 `provider/model`，并确保它在 pool 内 |
| provider/model 404 或 unsupported | endpoint 不提供该 model，或 model ID 写错 | 向用户确认真实 catalog；结构校验不能解决 |
| tool calling 失败 | endpoint/model 不兼容当前 OpenAI tool wire | 更换兼容模型或扩展 provider adapter；不要通过 preset 绕过 |
| 写了 preset 但 CouncisMac 不变化 | GUI 不读取 CLI preset | 在 Provider Settings 配置 catalog，或实现统一 preset 支持 |

## 16. 当前尚不支持的角色级配置

以下内容不能写进 schema v2：

- `reasoning` per role
- `temperature`
- `maxTokens`
- `contextWindow`
- `systemPrompt`
- `maxSteps` per role
- `tools`
- `permissions`
- `workspaceAccess`
- `judgeTimeout`
- `judgeRounds`
- `lifecycle`
- `concurrency`

CLI 的 `reasoning` 和 `maxSteps` 当前是 session 级配置。能力和权限来自 `CoworkSurfaceProfile`、lease 与 `PermissionEngine`。Judge 生命周期来自固定 runtime policy。

若用户要求这些能力：

1. 不要把未知字段塞进 JSON 并声称生效。
2. 将需求标记为 schema/runtime 扩展。
3. 同步修改 decoder、validation、runtime policy、测试和本文。
4. 新字段应优先 additive/optional，保持旧 preset 可解码。

## 17. AI Agent 最终检查清单

交付前逐项回答：

- [ ] 文件位于正确的项目级或用户级目录。
- [ ] 文件名安全，且与 `name` 一致。
- [ ] `schemaVersion` 为 `2`。
- [ ] `mode` 与目标命令一致。
- [ ] Main 与 Judge 均为显式、不同的完整 binding。
- [ ] 所有 Worker binding 彼此不同，且不复用 Main/Judge。
- [ ] `strategy` 为 `unique`。
- [ ] `excludeControlPlaneAgents` 为 `true`。
- [ ] 没有 secret、endpoint 或 credential reference。
- [ ] 未把 `@permission-reviewer` 放进数据平面 pool。
- [ ] 未加入当前不支持的角色级字段。
- [ ] JSON 语法已验证。
- [ ] `git diff --check` 已通过。
- [ ] 真实 endpoint 未验证时已明确说明。
- [ ] 未修改 `Upstream/`，未自动提交或推送。
