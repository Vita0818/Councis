import Foundation

func printConfig(_ config: CLIConfig) {
    out("""
    default provider: \(config.defaultProviderID)
    default model   : \(config.model)
    reasoning       : \(config.reasoningEffort?.rawValue ?? "off")
    mode            : \(config.mode.rawValue)
    preset          : \(config.preset ?? "(mode default)")
    config          : \(ConfigFile.url.path)
    providers       :

    """)
    for provider in config.providers {
        out("  \(provider.id) · \(provider.baseURL.absoluteString) · \(provider.wire.rawValue) · key \(provider.apiKey?.isEmpty == false ? "set (hidden)" : "unset")\n")
    }
    out("\n")
}

func printHelp() {
    out("""
    Councis CLI — heterogeneous model teams on the Intatis Cowork runtime.

    USAGE
      councis                         Start the configured default mode
      councis chat [--preset NAME] [PROMPT...]
                                      REPL without PROMPT; otherwise run one
                                      reviewed @main task in a confined workspace
      councis work [--preset NAME] [--workspace DIR] [PROMPT...]
                                      REPL without PROMPT; otherwise run one
                                      reviewed @main task in DIR
      councis work DIR                Compatibility workspace form only when DIR
                                      exists and is the sole positional argument
      councis cowork ...              Compatibility alias for `councis work`
      councis settings                Edit the default endpoint, key, model, and mode
      councis config                  Print resolved config (secrets hidden)
      councis runs [FILE]             Read legacy Council run summaries
        [--show-answer]               Explicitly include the stored final answer
      councis selftest                Offline smoke tests (no key or network)
      councis help

    LAUNCH OPTIONS
      --preset NAME                   Select the heterogeneous team preset
      --workspace DIR, --dir DIR      Work-mode workspace (default: current dir)
      --                              Treat all remaining tokens as prompt text

      Multiple prompt tokens are joined with spaces. Chat positionals are always
      prompt text. The retired `--mock` Council engine is not available; use
      `councis selftest` for an offline smoke test.

    TEAM PRESETS
      Project: .councis/presets/<name>.json
      User   : ~/.councis/presets/<name>.json

      A preset declares @main, @judge, workerModelPool, modelAssignment, and
      provider metadata. Credentials and endpoint URLs belong only in config.

    CONFIG  (COUNCIS_* > INTATIS_* compatibility vars > config > defaults)
      COUNCIS_BASE_URL       default https://api.openai.com/v1
      COUNCIS_API_KEY        key for the default provider
      COUNCIS_PROVIDER       default provider id
      COUNCIS_MODEL          fallback model, default gpt-4o-mini
      COUNCIS_REASONING      minimal | low | medium | high
      COUNCIS_MODE           chat | work
      COUNCIS_PRESET         override the mode's default preset
      COUNCIS_MAX_STEPS      maximum tool round-trips per agent turn

    Multiple providers can be declared in ~/.councis/config.json. Give each an
    `apiKeyEnv`, or set COUNCIS_<PROVIDER_ID>_API_KEY (punctuation becomes `_`).

    In a session, type /help for slash commands.

    """)
}
