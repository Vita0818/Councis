#if canImport(SwiftUI)
import Foundation

/// Product-specific names used by the shared macOS workbench sources.
///
/// Councis compiles these sources with `COUNCIS_APP`; IntatisMac compiles the
/// same files without it. Keeping product identity at this boundary lets both
/// apps share the real Chat / Code / Cowork runtime without sharing mutable
/// preferences, session history, or provider credentials.
enum AppIdentity {
    #if COUNCIS_APP
    static let isCouncis = true
    static let displayName = "Councis"
    static let tagline = "Multi-model AI workbench"
    static let defaultsPrefix = "councis"
    static let applicationSupportDirectoryName = "Councis"
    static let configurationDirectoryName = "councis"
    static let configurationFileStem = "councis"
    static let configEnvironmentVariable = "COUNCIS_CONFIG"
    static let authEnvironmentVariable = "COUNCIS_AUTH_FILE"
    #else
    static let isCouncis = false
    static let displayName = "Intatis"
    static let tagline = "Local AI workbench"
    static let defaultsPrefix = "intatis"
    static let applicationSupportDirectoryName = "Intatis"
    static let configurationDirectoryName = "intatis"
    static let configurationFileStem = "intatis"
    static let configEnvironmentVariable = "INTATIS_CONFIG"
    static let authEnvironmentVariable = "INTATIS_AUTH_FILE"
    #endif

    static var configurationDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(configurationDirectoryName, isDirectory: true)
    }

    static var localShareDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share", isDirectory: true)
            .appendingPathComponent(configurationDirectoryName, isDirectory: true)
    }

    static var productConfigurationFileNames: [String] {
        ["\(configurationFileStem).json", "\(configurationFileStem).jsonc"]
    }
}
#endif
