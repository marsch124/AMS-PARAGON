import XCTest
@testable import ParagonCore

/// Build 285: the sync line is always there and says where the sync stands.
final class SyncStatusTests: XCTestCase {
    func testTheLineSaysWhereTheSyncStands() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 10))!
        let at = { (d: Int, h: Int, m: Int) in cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))! }
        func line(_ f: Date?, _ c: Int = 0, s: Bool = false, w: Bool = false) -> String {
            SyncStatus.line(syncing: s, waiting: w, finishedAt: f, conflicts: c, now: now, calendar: cal)
        }
        XCTAssertEqual(line(nil), "Not synced yet")
        XCTAssertEqual(line(at(11, 9, 12), s: true, w: true), "Syncing…")
        XCTAssertEqual(line(at(11, 9, 12), w: true), "Sync waiting for iCloud…")
        XCTAssertEqual(line(at(11, 9, 12)), "Synced at 09:12")
        XCTAssertEqual(line(at(10, 21, 40)), "Synced yesterday at 21:40")
        XCTAssertEqual(line(at(9, 21, 40)), "Synced 9 Nov at 21:40")
        XCTAssertEqual(line(at(11, 9, 12), 1), "Last sync: 1 conflict")
        XCTAssertEqual(line(at(11, 9, 12), 2), "Last sync: 2 conflicts")
        XCTAssertTrue(SyncStatus.isProblem(syncing: false, waiting: false, finishedAt: now, conflicts: 2))
        XCTAssertFalse(SyncStatus.isProblem(syncing: true, waiting: false, finishedAt: now, conflicts: 2))
        XCTAssertFalse(SyncStatus.isProblem(syncing: false, waiting: false, finishedAt: now, conflicts: 0))
    }
}
