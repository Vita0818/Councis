import XCTest
import IntatisProtocol
@testable import IntatisCowork

final class CoworkSurfaceProfileTests: XCTestCase {
    func testChatCoordinatorCanCoordinateButHasNoWorkspaceOrExecutionCapabilities() {
        let lease = CoworkSurfaceProfile.chat.capabilityLease(
            coordinator: true,
            reviewer: false)

        XCTAssertTrue(lease.tools.contains(.delegateTask))
        XCTAssertTrue(lease.tools.contains(.attachWorkspace))
        XCTAssertFalse(lease.tools.contains(.readWorkspace))
        XCTAssertFalse(lease.tools.contains(.applyPatch))
        XCTAssertFalse(lease.tools.contains(.runShell))
        XCTAssertFalse(lease.tools.contains(.gitControl))
        XCTAssertFalse(lease.tools.contains(.browseWeb))
        XCTAssertEqual(
            CoworkSurfaceProfile.chat.workspaceAccess(coordinator: true, reviewer: false),
            .readOnly)
    }

    func testChatReviewerHasNoToolsCommunicationOrDelegation() {
        let lease = CoworkSurfaceProfile.chat.capabilityLease(
            coordinator: false,
            reviewer: true)

        XCTAssertTrue(lease.tools.isEmpty)
        if case .none = lease.communication {} else { XCTFail("chat reviewer must not communicate") }
        if case .none = lease.delegation {} else { XCTFail("chat reviewer must not delegate") }
    }

    func testWorkReviewerIsReadOnlyAndCannotCoordinate() {
        let lease = CoworkSurfaceProfile.work.capabilityLease(
            coordinator: false,
            reviewer: true)

        XCTAssertTrue(lease.tools.contains(.readWorkspace))
        XCTAssertFalse(lease.tools.contains(.applyPatch))
        XCTAssertFalse(lease.tools.contains(.attachWorkspace))
        XCTAssertEqual(
            CoworkSurfaceProfile.work.workspaceAccess(coordinator: false, reviewer: true),
            .readOnly)
    }
}
