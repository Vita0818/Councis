import Foundation
import CouncisProviders

func printConfig(_ config: CLIConfig) {
    out("""
    endpoint : (configured, hidden) · \(config.selectedRouteLabel)
    model    : \(config.model)
    wire     : \(config.wire.rawValue)
    reasoning: \(config.reasoningEffort?.rawValue ?? "off")
    mode     : \(config.mode.rawValue)
    api key  : \(config.hasConfiguredCredential ? "(configured, hidden)" : "(unset)")
    routes   : \(config.providerRoutes.count)
    config   : \(config.configurationFileURL == nil ? ConfigFile.url.path : "(advanced Councis config, path hidden)")

    """)
}

func printHelp() {
    out("""
    Councis CLI — a local AI agent for ANY OpenAI-compatible endpoint.

    USAGE
      councis                 Start your default mode (set via `councis settings`)
      councis chat            Streaming chat (no tools)
      councis code [dir]      Coding agent: read/search/edit files, git/shell (with approval)
      councis cowork [dir]    Multi-agent work; use /goal <objective> for durable Goal execution
      councis settings        Interactive settings (endpoint, key, model, reasoning, mode)
      councis config          Print the resolved config
      councis selftest        Offline smoke test (no key)
      councis mcp help        Manage external MCP servers and session access
      councis exec --session <id> --agent <id> [--task <id>] --prompt <text> [--yes]
                              Run one exact durable Code/MCP turn
      councis diagnose-hang --pid <pid> [--output <directory>]
                              Capture a 10s sample and 5m Councis logs into an owner-only bundle
      councis help

    CONFIG  (env var > advanced Councis config > legacy config > default)
      COUNCIS_CONFIG     optional councis.json/jsonc using model + enabled_providers + provider map
      COUNCIS_BASE_URL   default https://api.openai.com/v1
      COUNCIS_API_KEY    required (any non-empty for local servers)
      COUNCIS_MODEL      default gpt-4o-mini
      COUNCIS_REASONING  minimal | low | medium | high
      COUNCIS_MODE       chat | code | cowork

    In a session, type /help for slash commands (/model, /reasoning, /mode, /clear …).

    FIRST RUN
      councis settings        # set endpoint + API key once
      councis                 # then just run it — uses your saved config

    ANY VENDOR (same binary)
      COUNCIS_BASE_URL=http://localhost:11434/v1 COUNCIS_API_KEY=ollama COUNCIS_MODEL=llama3.1 councis chat
      COUNCIS_BASE_URL=https://api.deepseek.com/v1 COUNCIS_API_KEY=sk-... COUNCIS_MODEL=deepseek-chat councis chat

    """)
}
