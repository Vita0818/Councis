import Foundation
import XCTest
import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisCodexRuntime

final class CouncisRuntimeIntegrationTests: XCTestCase {
    func testConsumesThePublishedIntatisRuntimeContractDirectly() {
        XCTAssertEqual(CodexRuntimeHostContract.publicAPIMajorVersion, 1)
        XCTAssertEqual(CodexRuntimeHostContract.packageName, "Intatis")
        XCTAssertEqual(
            CodexRuntimeHostContract.productName,
            "IntatisCodexRuntime")
        XCTAssertEqual(
            CodexRuntimeHostContract.pinnedRuntimeVersion,
            "0.145.0-intatis.4")
    }

    func testCouncisCanConstructAnIsolatedRuntimeUsingOnlyPublicTypes() throws {
        let hostApplicationIdentity = try IntatisHostApplicationIdentity(
            name: "Councis")
        let route = ResponsesRuntimeRoute(
            endpointID: "councis-test",
            model: ModelID(rawValue: "fixture-model"),
            baseURL: URL(string: "https://example.invalid/v1")!,
            bearerToken: "fixture-token")
        let configuration = CodexRuntimeConfiguration(
            sessionID: SessionID(rawValue: "sess_councis_fixture"),
            mode: .cowork,
            workspaceURL: URL(fileURLWithPath: "/tmp/councis-workspace"),
            runtimeRootURL: URL(fileURLWithPath: "/tmp/councis-runtime"),
            route: route,
            executableOverride: URL(fileURLWithPath: "/tmp/codex"),
            hostApplicationIdentity: hostApplicationIdentity)

        XCTAssertFalse(configuration.description.contains("fixture-token"))
        XCTAssertEqual(
            configuration.hostApplicationIdentity,
            hostApplicationIdentity)
        XCTAssertNotNil(CodexAppServerSession(configuration: configuration))
    }

    func testHostIdentityPreservesCouncisNamespaces() throws {
        let identity = try IntatisHostApplicationIdentity(name: "Councis")

        XCTAssertEqual(identity.storageName, "Councis")
        XCTAssertEqual(identity.fileNameStem, "councis")
        XCTAssertEqual(identity.environmentVariable("CONFIG"), "COUNCIS_CONFIG")
        XCTAssertEqual(identity.userDefaultsKey("model"), "councis.model")
        XCTAssertEqual(identity.hiddenWorkspaceDirectoryName, ".councis")
        XCTAssertEqual(
            identity.keychainService("mcp.credentials"),
            "com.vitemis.councis.mcp.credentials")
        XCTAssertEqual(
            identity.authorizationContextFieldName,
            "__councis_authorization_context")
    }
}
