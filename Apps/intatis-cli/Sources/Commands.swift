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
    Councis CLI — council-powered Chat and lightweight Work for ANY OpenAI-compatible endpoint.

    USAGE
      councis                 Chat one-line prompt; Chat is the default mode
      councis chat            Chat one-line prompt
      councis chat "..."      Council-powered Chat: candidates + judge synthesis
      councis chat --mock "..."  One-shot mock chat smoke test
      councis work "..."      Council-powered Work with restricted filesystem context
      councis work --mock "..."  Mock Work with controlled executor writes
      councis council "..."   Deprecated alias for `chat`
      councis settings        Interactive settings (endpoint, key, model, reasoning, mode)
      councis config          Print the resolved config
      councis selftest        Offline smoke test (no key)
      councis help

    CONFIG  (env var > ~/.councis/config.json > default)
      COUNCIS_BASE_URL   default https://api.openai.com/v1
      COUNCIS_API_KEY    required for real model calls (any non-empty for local servers)
      COUNCIS_MODEL      default gpt-4o-mini
      COUNCIS_REASONING  minimal | low | medium | high
      COUNCIS_MODE       chat | work
      COUNCIS_USAGE      0 disables stream_options.include_usage

    FIRST RUN
      councis settings        # set endpoint + API key once
      councis                 # then just run it — uses your saved config

    ANY VENDOR (same binary)
      COUNCIS_BASE_URL=http://localhost:11434/v1 COUNCIS_API_KEY=ollama COUNCIS_MODEL=llama3.1 councis chat
      COUNCIS_BASE_URL=https://api.deepseek.com/v1 COUNCIS_API_KEY=sk-... COUNCIS_MODEL=deepseek-chat councis chat

    COUNCIL ENGINE
      councis chat --mock "Explain Hamiltonian paths and cycles"
      councis chat --preset elite-chat "Explain Hamiltonian paths and cycles"
      councis work --mock "create note.txt and read it back"

    """)
}
