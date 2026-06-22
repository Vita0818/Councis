# Councis

Councis is a first-stage CLI prototype bootstrapped from the Intatis kernel.
The current goal is to prove four pieces before any GUI work:

- OpenAI-compatible API access through `baseURL`, `apiKey`, and `model`.
- Workspace-confined local file read, write, and list tools.
- Parallel candidate-agent execution.
- A small council workflow with optional judge synthesis.

Internal Swift module names still use `Intatis*` while this prototype settles.
That keeps the first pass small and reversible.

## Run

```bash
cd /Users/vita/Vitemis/Councis
swift run councis help
swift run councis config
swift run councis selftest
swift run councis council --mock "Explain Hamiltonian paths and Hamiltonian cycles"
```

## Config

Councis reads config from environment variables first, then
`~/.councis/config.json`, then built-in defaults.

```bash
COUNCIS_BASE_URL=https://api.openai.com/v1
COUNCIS_API_KEY=sk-...
COUNCIS_MODEL=gpt-4o-mini
COUNCIS_REASONING=low
COUNCIS_USAGE=0
```

`COUNCIS_API_KEY` is required for real model calls. `councis config` and
`councis council --mock` work without a key.

## Council Presets

Project presets live under:

```text
.councis/presets/
```

Run logs are written to `.councis/runs/` and ignored by git.

```bash
swift run councis council --preset elite "Explain Hamiltonian paths and Hamiltonian cycles"
```

The default `elite` preset is intentionally just configuration. Model IDs can be
changed without recompiling the CLI.
