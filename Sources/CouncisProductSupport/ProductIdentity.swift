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
}

/// Read-only keys retained solely for an explicitly initiated migration of old
/// workspace bookmarks. Normal App/CLI startup never reads these values.
public enum LegacyIntatisCompatibility {
    public enum UserDefaultsKey {
        public static let workspaceBookmarks =
            "intatis.workspace.bookmarks"
        public static let workspaceSessionBookmarkPrefix =
            "intatis.workspace.sessionBookmark."
        public static let workspaceSessionPathPrefix =
            "intatis.workspace.sessionPath."
    }
}
