# NOTICE

## Councis product

Councis is a first-party macOS product overlay maintained by Vitemis. Its
product-owned material includes the Councis name, bundle identity, command,
icon, system-native visual composition, App/CLI hosts, localization,
configuration namespace, compatibility-only legacy state discovery, and
distribution wiring.

Councis does not use leaked or private source code or prompts, and does not
adopt third-party names, logos, screenshots, UI assets, or brand copy as its
product identity.

## Intatis shared implementation

Councis directly compiles the sibling first-party Swift package at:

```text
/Users/vita/Vitemis/Intatis
```

The package is referenced from this repository as `../Intatis`. Intatis is
the single source of truth for the shared core, protocol, providers,
conversation/event storage, artifacts, tools, permissions, MCP, Skills,
Knowledge, shared UI, and `IntatisCodexRuntime`. Councis no longer distributes
an independently maintained snapshot or vendored copy of those implementations.

The Intatis checkout owns the exact upstream pins, source inventories, patch
ledgers, combined license texts, NOTICE attributions, runtime specifications,
and SBOM records for products and resources compiled into Councis. The
`CouncisMac` target copies the current Intatis `ThirdPartyNotices` directory
into the App so those distribution materials remain available to users.

## OpenAI Codex Runtime

Councis Code and Cowork use the OpenAI Codex App Server runtime through the
first-party `IntatisCodexRuntime` product. The current exact derived runtime is:

```text
codex-cli 0.145.0-intatis.4
```

Its pinned upstream release, source commit, Intatis patch set, derivation ID,
Apache-2.0 license, and upstream NOTICE obligations are maintained in Intatis.
Councis does not copy or independently modify the Rust runtime, App Server
protocol host, binary builder, or patch set.

The Codex, OpenAI, and Intatis names identify implementation dependencies and
provenance. They are not Councis branding and do not imply endorsement.

## Councis-specific material

The Councis App icon, Cowork-only navigation, system-native theme, configuration
and storage namespaces, managed-workspace choice, and compatibility-only
legacy Intatis discovery remain Councis-owned product behavior.

The project-local `.agents/skills/councis-skill-creator/` is a modified
derivative of the public OpenAI Codex `skill-creator` sample from
`rust-v0.145.0`, under Apache License 2.0. Its file-level provenance remains in
`ThirdPartyNotices/OpenAICodexSkillCreator.md` and
`ThirdPartyNotices/Licenses/Codex-61a44880-Apache-2.0.txt`.

## Distribution responsibility

A source dependency does not make an App release self-contained. Before
shipping, Councis must independently verify its final bundle inventory and
include every applicable Intatis/upstream license and NOTICE, exact Codex and
business-runtime binary hashes, architecture closure, Developer ID signatures,
notarization, staple, Gatekeeper assessment, and clean-machine behavior.

The development Intatis checkout, `.intatis/runtime-kit`, user-installed
executables, package caches, Homebrew, and local source paths are not release
fallbacks.
