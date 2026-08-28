# AI_PROVIDER_MODEL_CONFIGURATION

文档状态：当前 AI 配置操作合同
最后核对：2026-08-28
产品基线：v0.10（build 49）

## 适用范围

本文约束 Councis host 如何把 Councis-owned config安全投影为共享Intatis Responses Runtime route。
它不授权读取、输出或迁移真实credential。

## 配置链

```text
councis.json/jsonc or COUNCIS_* CLI values
  -> AppConfig / CLIProviderCatalog
  -> Intatis ProviderRegistry / immutable inference catalog
  -> exact AgentInferenceBinding or selected model
  -> ResponsesRuntimeRoute
  -> CodexRuntimeConfiguration
  -> Codex App Server child environment
```

Councis不实现provider wire或SDK adapter；这些来自`IntatisProviders`。

## Canonical Councis 输入

macOS：

1. `COUNCIS_CONFIG`；
2. `~/.config/councis/councis.json`；
3. `~/.config/councis/councis.jsonc`；
4. Councis Application Support `councis.json[c]`；
5. Councis-owned `config.json[c]` compatibility。

CLI override：

- `COUNCIS_BASE_URL`
- `COUNCIS_API_KEY`
- `COUNCIS_MODEL`
- `COUNCIS_REASONING`
- `COUNCIS_MODE`
- `COUNCIS_USAGE`
- `COUNCIS_MAX_STEPS`
- `COUNCIS_CODEX_RUNTIME`

UserDefaults：`councis.providerCatalog.v1`、`councis.providerSelection.v1`。

canonical值存在但损坏或不可解析时fail closed；不得改读Intatis/OpenCode app的配置来继续。
`INTATIS_CONFIG`、`INTATIS_AUTH_FILE`、其他`INTATIS_*`、
`~/.config/intatis`、`~/.local/share/intatis`、Intatis Application Support和Intatis
bundle-domain defaults均不进入正常发现链。需要旧数据时必须走另行设计并由用户
明确触发的迁移，不得把兼容读取重新变成启动fallback。

## Responses route

Code/Cowork只能启动能被`ProviderRegistry.responsesRuntimeRoute`精确表示的route：

- absolute HTTP(S) Responses base URL；
- exact model ID；
- exact request adapter/provider projection；
- secret仅在真实dispatch时解析；
- reasoning effort来自已配置variant/base route；
- unsupported Chat-Completions-only route在网络前失败。

不得用Chat Completions translator、URL猜测、model slug猜测或另一provider fallback把不兼容route伪装成
Responses route。

## Credential

- AI不得读取、打印、比较或摘要真实key。
- 新配置默认只写`{env:NAME}`，变量名必须匹配`^[A-Za-z_][A-Za-z0-9_]*$`。
- runtime可解析env/file/auth/provider-config reference，但AI不得擅自改变reference种类。
- secret不进入UserDefaults、EventLog、runtime files、argv、diagnostic、文档或tool output。
- Codex App Server使用`requires_openai_auth=false`和host提供的exact Responses credential；不得回退ChatGPT login。

## Codex executable

`COUNCIS_CODEX_RUNTIME`是Councis开发宿主的显式override。它只选择文件位置，不能改变：

- `CodexRuntimeExecutable.pinnedVersion`；
- `CodexRuntimeExecutable.pinnedDerivationID`；
- isolated runtime root；
- provider route或credential。

显式值非法时fail closed。缺失时共享Runtime可使用其受审开发发现路径；正式App必须使用bundle内exact runtime。

## Cowork profile

- root `@main`使用Send边界冻结的exact binding。
- host把安全inference options降为Codex child `agent_type` presets；role files不含endpoint、credential或raw options。
- 模型只能选择已广告preset，不能现场指定provider/model/path。
- existing child/thread不随mutable UI selector自动漂移。
- child route无法被pinned Runtime精确表达时不广告该preset。

## 专用模型

Knowledge、image、transcription等role继续由Intatis shared config/schema实现。Councis只提供canonical
config来源；不得在tool参数中恢复provider/model选择或隐藏默认模型。

## 安全示例

```json
{
  "$schema": "https://opencode.ai/config.json",
  "enabled_providers": ["primary"],
  "model": "primary/reasoning-model",
  "provider": {
    "primary": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Primary",
      "options": {
        "baseURL": "https://provider.example/v1",
        "apiKey": "{env:PRIMARY_API_KEY}"
      },
      "models": {
        "reasoning-model": {
          "name": "Reasoning Model",
          "options": { "reasoningEffort": "medium" }
        }
      }
    }
  }
}
```

示例不代表内置provider、账号、价格或可用性。

## 最低验证

- 不回显内容地解析JSON或用Councis loader验证JSONC；
- `councis config`只输出safe route summary；
- `CouncisRuntimeIntegrationTests`验证public runtime contract；
- `CLIProductBrandCompatibilityTests`验证存在旧Intatis env/path时仍只采用Councis输入；
- CLI/App build验证Responses route API可见；
- 真实provider、credential、network和cost测试只在用户明确授权后运行。

报告只能包含config path、route/model/variant ID、env变量名、safe binding和验证结果；不得包含secret、
完整endpoint dump、header/query、raw config或完整digest。
