import XCTest
@testable import ParagonCore

/// Build 283: a sync waits for iCloud and starts by itself, instead of an alert.
final class SyncWaitTests: XCTestCase {
    func testTheSyncStartsOnlyWhenTheWholeVaultIsHere() {
        XCTAssertEqual(SyncWait.step(waiting: 0, updating: 0), .start)
        XCTAssertEqual(SyncWait.step(waiting: 2, updating: 0), .keepWaiting)
        XCTAssertEqual(SyncWait.step(waiting: 0, updating: 3), .keepWaiting)
        XCTAssertFalse(SyncWait.message.contains("Try again"))
        XCTAssertFalse(SyncWait.message.contains("wrong"))
    }

    /// Build 284: the waiting line says what waits and for what, and is not an alarm.
    func testTheWaitingLineNamesTheSyncAndICloud() {
        XCTAssertEqual(SyncWait.waitingLine, "Sync waiting for iCloud…")
    }
}
