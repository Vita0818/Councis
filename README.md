# Councis

Councis is a heterogeneous-model product wrapper over the shared Intatis Cowork runtime. It keeps Intatis's scheduler, task graph, agent loop, mediated message bus, event log, tool system, and permission gates, while adding a strict team policy:

- every data-plane agent has a full `providerID/modelID` binding;
- active `@main`, `@judge`, and worker bindings are unique;
- workers receive the next unused binding from a fixed pool and never inherit the parent's model;
- every root task must pass the reserved, read-only `@judge` before completion;
- the permission reviewer remains a separate control-plane role.

The shared Swift modules retain their `Intatis*` names deliberately. Councis is a wrapper and policy profile, not a forked reimplementation of the kernel.

## Quick start

```sh
cd /Users/vita/Vitemis/Councis
swift run councis help
swift run councis selftest
swift run councis config
swift run councis chat --preset elite-chat
swift run councis work --preset elite-work --workspace /path/to/project
```

With a prompt, Chat and Work run one reviewed root task and exit:

```sh
swift run councis chat --preset elite-chat "Compare two implementation strategies"
swift run councis work --preset elite-work --workspace . "Review this repository"
```

Without a prompt they open the team REPL. `cowork` and `code` are compatibility aliases for `work`. The retired fixed-fan-out Council engine and `--mock` option are intentionally unavailable; use `councis selftest` for an offline smoke test.

## Chat and Work

Both modes run the same Cowork pipeline and mandatory Judge gate.

Main drafts and raw Judge output remain durable audit/context events but are not user answers. Internal communication/delegation tool arguments and results are hidden with those events. The CLI and CouncisMac release exactly one root result only after a matching persisted Judge approval; invalid or exhausted review fails closed without echoing model-authored Judge prose. Ordinary tool, permission, patch, and artifact audit remains visible. IntatisMac keeps its standard projection for compatibility.

- Chat uses a private confined workspace and a capability profile without filesystem, shell, Git, browser, document, or media tools.
- Work uses the selected workspace. Tool side effects remain confined and pass through the permission engine and durable execution-ticket checks.

## Team presets and providers

Project presets live in `.councis/presets/`; user presets may live in `~/.councis/presets/`. Schema v2 declares `main`, `judge`, `workerModelPool`, `modelAssignment`, and non-secret provider metadata. Presets never contain endpoints, API keys, or credential references.

Provider endpoints and credentials belong in environment variables or `~/.councis/config.json` (written with mode `0600`). Resolution precedence is `COUNCIS_*`, legacy `INTATIS_*`, Councis config, legacy Intatis config, then defaults. Multiple providers can be configured; per-provider keys use `COUNCIS_<PROVIDER_ID>_API_KEY` or a configured `apiKeyEnv`.

The shipped model IDs are endpoint-specific examples. Configure an endpoint that exposes those IDs, or edit the presets to use distinct models available to your provider.

## macOS apps

Generate the Xcode project with:

```sh
xcodegen generate
open Councis.xcodeproj
```

- `CouncisMac` compiles the shared IntatisMac workbench with `COUNCIS_APP`, exposes only strict heterogeneous Cowork, and requires at least two unique provider/model bindings for `@main` and `@judge`.
- `IntatisMac` keeps its existing Chat, Code, and legacy Cowork behavior.
- `IntatisiOS` remains the tool-free chat/multimodal subset.

Councis and Intatis use separate Application Support, preferences, configuration, and credential namespaces.

## Legacy Council logs

Old `.councis/runs/*.json` files remain readable but are never executed or rewritten:

```sh
swift run councis runs
swift run councis runs .councis/runs/run-example.json
swift run councis runs .councis/runs/run-example.json --show-answer
```

The default view prints bounded summaries; the stored final answer appears only with `--show-answer`. Current Cowork sessions use append-only event-log JSONL in Application Support instead.

## Intatis reference snapshot

`Upstream/Intatis` is a frozen, read-only copy of the Intatis working tree used to build this wrapper. Its provenance and content hash are recorded in `Upstream/Intatis/SNAPSHOT.md`. Do not edit or build inside the snapshot; implement changes in the normal Councis source tree.

See `docs/ARCHITECTURE.md`, `docs/PROJECT_MAP.md`, and `docs/TESTING.md` for implementation and verification details.
