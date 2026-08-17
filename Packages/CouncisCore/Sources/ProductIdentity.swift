import Foundation

/// Frozen first-party identity used by current Councis writers and product
/// composition roots. These values are not runtime branding preferences.
public enum CouncisProductIdentity {
    public static let productName = "Councis"
    public static let bundleIdentifier = "com.Vita0818.Councis"
    public static let applicationSupportDirectoryName = "Councis"
    public static let configurationDirectoryRelativePath = ".config/councis"
    public static let sharedDataDirectoryRelativePath = ".local/share/councis"
    public static let configurationFileName = "councis.json"
    public static let configurationJSONCFileName = "councis.jsonc"
    public static let mcpKeychainService =
        "com.Vita0818.Councis.mcp.credentials"
}

/// Read-only compatibility constants for data written by the fixed Intatis
/// source baseline before Councis adopted its own bottom-layer identity.
///
/// Current writers must never use these values. Call sites may use them only
/// to discover, decode, protect, or non-destructively bridge legacy state.
public enum LegacyIntatisCompatibility {
    public static let macOSBundleIdentifier = "com.Vita0818.IntatisMac"
    public static let applicationSupportDirectoryName = "Intatis"
    public static let configurationDirectoryRelativePath = ".config/intatis"
    public static let sharedDataDirectoryRelativePath = ".local/share/intatis"
    public static let configurationFileName = "intatis.json"
    public static let configurationJSONCFileName = "intatis.jsonc"
    public static let mcpKeychainService =
        "com.vitemis.intatis.mcp.credentials"

    public enum Environment {
        public static let config = "INTATIS_CONFIG"
        public static let authFile = "INTATIS_AUTH_FILE"
        public static let baseURL = "INTATIS_BASE_URL"
        public static let apiKey = "INTATIS_API_KEY"
        public static let model = "INTATIS_MODEL"
        public static let reasoning = "INTATIS_REASONING"
        public static let mode = "INTATIS_MODE"
        public static let usage = "INTATIS_USAGE"
        public static let maxSteps = "INTATIS_MAX_STEPS"
        public static let showExecutionTrace =
            "INTATIS_SHOW_EXECUTION_TRACE"
    }

    public enum UserDefaultsKey {
        public static let baseURL = "intatis.baseURL"
        public static let model = "intatis.model"
        public static let providerCatalog = "intatis.providerCatalog.v1"
        public static let providerSelection = "intatis.providerSelection.v1"
        public static let messageRenderingMode =
            "intatis.messageRendering.mode.v1"
        public static let coworkProjectSettingsPrefix =
            "intatis.cowork.projectSettings."
        public static let workspaceBookmarks =
            "intatis.workspace.bookmarks"
        public static let workspaceSessionBookmarkPrefix =
            "intatis.workspace.sessionBookmark."
        public static let workspaceSessionPathPrefix =
            "intatis.workspace.sessionPath."
    }

    public enum ProtocolIdentity {
        public static let authorizationContextField =
            "__intatis_authorization_context"
        public static let standardToolRegistryV4 = "intatis.standard.v4"
        public static let coworkToolRegistryV4 = "intatis.cowork.v4"
        public static let coworkAdmissionV1 = "intatis.cowork.admission.v1"
        public static let workspaceAdmissionV1 =
            "intatis.workspace-admission.v1"
        public static let deterministicPolicyV1 =
            "intatis.deterministic-policy.v1"
    }

    public enum LaunchArgument {
        public static let plainSafeMessages =
            "-IntatisPlainSafeMessages"
        public static let microsoftMarkdownMessages =
            "-IntatisMicrosoftMarkdownMessages"
        public static let richTextMessages =
            "-IntatisRichTextMessages"
        public static let showExecutionTrace =
            "-IntatisShowExecutionTrace"
    }
}
