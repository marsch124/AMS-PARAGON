import XCTest
@testable import ParagonCore

/// Build 334: the quiet sync a few seconds after a delete made here.
final class QuietSyncAfterRemovalTests: XCTestCase {
    func testTheQuietSyncWaitsEightSecondsAfterTheLastRemoval() {
        let t = Date(timeIntervalSince1970: 1_000)
        // A removal is waiting: 8 seconds after it.
        XCTAssertEqual(QuietSyncAfterRemoval.plan(lastRemoval: t, removedHereIsEmpty: false, syncRunning: false),
                       .run(at: t.addingTimeInterval(8)))
        // Another delete 5 seconds later pushes it back.
        let later = t.addingTimeInterval(5)
        XCTAssertEqual(QuietSyncAfterRemoval.plan(lastRemoval: later, removedHereIsEmpty: false, syncRunning: false),
                       .run(at: t.addingTimeInterval(13)))
        // A sync is running: once after it, not now.
        XCTAssertEqual(QuietSyncAfterRemoval.plan(lastRemoval: t, removedHereIsEmpty: false, syncRunning: true),
                       .afterRunningSync)
        // Nothing waiting (empty list, or no removal): nothing planned, running or not.
        XCTAssertEqual(QuietSyncAfterRemoval.plan(lastRemoval: t, removedHereIsEmpty: true, syncRunning: false), .none)
        XCTAssertEqual(QuietSyncAfterRemoval.plan(lastRemoval: t, removedHereIsEmpty: true, syncRunning: true), .none)
        XCTAssertEqual(QuietSyncAfterRemoval.plan(lastRemoval: nil, removedHereIsEmpty: false, syncRunning: false), .none)
    }
}
