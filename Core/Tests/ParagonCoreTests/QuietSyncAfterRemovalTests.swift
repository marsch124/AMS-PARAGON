import XCTest
@testable import ParagonCore

/// Build 334: the quiet sync shortly after a delete made here.
final class QuietSyncAfterRemovalTests: XCTestCase {
    func testTheQuietSyncWaitsForUndoAndLongerAfterTyping() {
        let t = Date(timeIntervalSince1970: 1_000)
        // A delete by a button: 12 seconds on, past the Undo offer.
        let first = QuietSyncAfterRemoval.due(removalAt: t, byTyping: false, plannedFor: nil)
        XCTAssertEqual(first, t.addingTimeInterval(12))
        // Another delete 5 seconds later pushes it back.
        let second = QuietSyncAfterRemoval.due(removalAt: t.addingTimeInterval(5), byTyping: false, plannedFor: first)
        XCTAssertEqual(second, t.addingTimeInterval(17))
        // A line taken out by typing waits a minute; a button delete after it does not cut that short.
        let typed = QuietSyncAfterRemoval.due(removalAt: t, byTyping: true, plannedFor: nil)
        XCTAssertEqual(typed, t.addingTimeInterval(60))
        XCTAssertEqual(QuietSyncAfterRemoval.due(removalAt: t.addingTimeInterval(5), byTyping: false, plannedFor: typed), typed)

        XCTAssertEqual(QuietSyncAfterRemoval.plan(due: first, removedHereIsEmpty: false, syncRunning: false), .run(at: first))
        // A sync is running: once after it, not now.
        XCTAssertEqual(QuietSyncAfterRemoval.plan(due: first, removedHereIsEmpty: false, syncRunning: true), .afterRunningSync)
        // Nothing waiting (empty list, or nothing due): nothing planned, running or not.
        XCTAssertEqual(QuietSyncAfterRemoval.plan(due: first, removedHereIsEmpty: true, syncRunning: false), .none)
        XCTAssertEqual(QuietSyncAfterRemoval.plan(due: first, removedHereIsEmpty: true, syncRunning: true), .none)
        XCTAssertEqual(QuietSyncAfterRemoval.plan(due: nil, removedHereIsEmpty: false, syncRunning: false), .none)
    }
}
