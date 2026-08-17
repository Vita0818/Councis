import Foundation

/// Compile-/launch-time capability envelope for a build.
///
/// CouncisMac explicitly selects the Developer ID profile. The default remains
/// a separate most-restricted envelope so any host that forgets to opt in can
/// never gain workspace, shell, or MCP process authority.
///
/// `allowsShell` gates process-backed exec tools such as browser/document
/// backends. Production registries do not model-expose raw `run_shell`.
public struct PlatformProfile: Sendable, Equatable {
    public let surfaces: Set<SessionKind>
    public let allowsWorkspace: Bool
    public let allowsShell: Bool
    public let allowsMCPRemoteHTTP: Bool
    public let allowsMCPStdio: Bool

    public init(surfaces: Set<SessionKind>,
                allowsWorkspace: Bool,
                allowsShell: Bool,
                allowsMCPRemoteHTTP: Bool,
                allowsMCPStdio: Bool) {
        self.surfaces = surfaces
        self.allowsWorkspace = allowsWorkspace
        self.allowsShell = allowsShell
        self.allowsMCPRemoteHTTP = allowsMCPRemoteHTTP
        self.allowsMCPStdio = allowsMCPStdio
    }

    public static let restricted = PlatformProfile(
        surfaces: [.chat],
        allowsWorkspace: false,
        allowsShell: false,
        allowsMCPRemoteHTTP: false,
        allowsMCPStdio: false
    )

    public static let macDeveloperID = PlatformProfile(
        surfaces: [.chat, .code, .cowork],
        allowsWorkspace: true,
        allowsShell: true,
        allowsMCPRemoteHTTP: true,
        allowsMCPStdio: true
    )

    /// Apps set this once at launch. The default is the most restricted profile,
    /// so a target that forgets to set it can never accidentally enable shell or
    /// workspace access.
    public static var current: PlatformProfile = .restricted

    public func supports(_ kind: SessionKind) -> Bool { surfaces.contains(kind) }
}
