# Councis

Councis is a first-stage CLI prototype bootstrapped from the Intatis kernel.
The current goal is to prove four pieces before any GUI work:

- OpenAI-compatible API access through `baseURL`, `apiKey`, and `model`.
- Chat as a multi-model council: candidate answers plus judge synthesis.
- Work as the same council engine with restricted workspace file context.
- A single executor for approved file writes after judge synthesis.
- Run logs that record candidates, judge, and final answer.

Internal Swift module names still use `Intatis*` while this prototype settles.
That keeps the first pass small and reversible.

## Run

```bash
cd /Users/vita/Vitemis/Councis
swift run councis help
swift run councis config
swift run councis selftest
swift run councis chat --mock "Explain Hamiltonian paths and Hamiltonian cycles"
swift run councis work --mock "create note.txt and read it back"
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

`COUNCIS_API_KEY` is required for real model calls. `councis config`,
`councis selftest`, `councis chat --mock`, and `councis work --mock` work
without a key.

Real council-powered Chat smoke:

```bash
COUNCIS_API_KEY=sk-... \
COUNCIS_BASE_URL=https://api.openai.com/v1 \
COUNCIS_MODEL=gpt-4o-mini \
swift run councis chat "Say exactly: councis-ok"
```

## Chat / Work Presets

Project presets live under:

```text
.councis/presets/
```

Run logs are written to `.councis/runs/` and ignored by git.

```bash
swift run councis chat --preset elite-chat "Explain Hamiltonian paths and Hamiltonian cycles"
swift run councis work --preset elite-work "read README and summarize it"
```

Use the cheap `smoke` preset for real API validation before running larger
presets:

```bash
COUNCIS_API_KEY=sk-... \
COUNCIS_BASE_URL=https://api.openai.com/v1 \
swift run councis chat --preset smoke "Explain Hamiltonian paths and Hamiltonian cycles"
```

`councis council ...` is kept only as a deprecated compatibility alias for
`councis chat ...`. New usage should prefer `chat` or `work`.

The default `elite-chat` and `elite-work` presets are intentionally just
configuration. Model IDs can be changed without recompiling the CLI. Presets
never contain API keys.
