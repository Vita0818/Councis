import Foundation

/// Councis-owned development override for the exact shared Intatis Codex
/// executable. The runtime performs executable, version, and derivation checks.
enum CouncisCodexRuntimeOverride {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let raw = environment["COUNCIS_CODEX_RUNTIME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: raw).standardizedFileURL
    }
}

