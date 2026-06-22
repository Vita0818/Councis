import Foundation
import IntatisProviders

func printConfig(_ config: CLIConfig) {
    out("""
    endpoint : \(config.baseURL.absoluteString)
    model    : \(config.model)
    wire     : \(config.wire.rawValue)
    reasoning: \(config.reasoningEffort?.rawValue ?? "off")
    mode     : \(config.mode.rawValue)
    api key  : \(config.apiKey.isEmpty ? "(unset)" : "(set, hidden)")
    config   : \(ConfigFile.url.path)

    """)
}

func printHelp() {
    out("""
    Councis CLI — a local AI council prototype for ANY OpenAI-compatible endpoint.

    USAGE
      councis                 Start your default mode (set via `councis settings`)
      councis chat            Interactive streaming chat (no tools)
      councis chat "..."      One-shot streaming chat smoke test
      councis chat --mock "..."  One-shot mock chat smoke test
      councis code [dir]      Coding agent: read/search/edit files, git/shell (with approval)
      councis cowork [dir]    Multi-agent: /agent add <name> <path>, then @name <message>
      councis council "..."   Parallel candidate agents plus optional judge
      councis settings        Interactive settings (endpoint, key, model, reasoning, mode)
      councis config          Print the resolved config
      councis selftest        Offline smoke test (no key)
      councis help

    CONFIG  (env var > ~/.councis/config.json > default)
      COUNCIS_BASE_URL   default https://api.openai.com/v1
      COUNCIS_API_KEY    required for real model calls (any non-empty for local servers)
      COUNCIS_MODEL      default gpt-4o-mini
      COUNCIS_REASONING  minimal | low | medium | high
      COUNCIS_MODE       chat | code | cowork
      COUNCIS_USAGE      0 disables stream_options.include_usage

    In a session, type /help for slash commands (/model, /reasoning, /mode, /clear …).

    FIRST RUN
      councis settings        # set endpoint + API key once
      councis                 # then just run it — uses your saved config

    ANY VENDOR (same binary)
      COUNCIS_BASE_URL=http://localhost:11434/v1 COUNCIS_API_KEY=ollama COUNCIS_MODEL=llama3.1 councis chat
      COUNCIS_BASE_URL=https://api.deepseek.com/v1 COUNCIS_API_KEY=sk-... COUNCIS_MODEL=deepseek-chat councis chat

    COUNCIL
      councis council --mock "Explain Hamiltonian paths and cycles"
      councis council --preset smoke "Explain Hamiltonian paths and cycles"
      councis council --preset elite "Explain Hamiltonian paths and cycles"

    """)
}
