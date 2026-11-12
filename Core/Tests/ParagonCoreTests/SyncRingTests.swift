import XCTest
@testable import ParagonCore

/// Build 300: the clock ring on the iPhone's sync button.
final class SyncRingTests: XCTestCase {
    func testTheRingRunsDownAndChangesColour() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10, minute: 30))!
        let ago = { (m: Double) in now.addingTimeInterval(-m * 60) }
        func mood(_ f: Date?, _ c: Int = 0, s: Bool = false, w: Bool = false) -> SyncRing.Mood {
            SyncRing.mood(syncing: s, waiting: w, finishedAt: f, conflicts: c, now: now)
        }
        func fill(_ f: Date?, _ c: Int = 0) -> Double {
            SyncRing.fill(syncing: false, waiting: false, finishedAt: f, conflicts: c, now: now)
        }
        func word(_ f: Date?, _ c: Int = 0, s: Bool = false, w: Bool = false) -> String {
            SyncRing.word(syncing: s, waiting: w, finishedAt: f, conflicts: c, now: now, calendar: cal)
        }
        XCTAssertEqual(mood(nil), .none)
        XCTAssertEqual(mood(ago(25)), .fresh)
        XCTAssertEqual(mood(ago(90)), .aging)
        XCTAssertEqual(mood(ago(5), w: true), .aging)
        XCTAssertEqual(mood(ago(5), 2), .problem)
        XCTAssertEqual(fill(ago(0)), 1, accuracy: 0.001)
        XCTAssertEqual(fill(ago(60)), 0.5, accuracy: 0.001)
        XCTAssertEqual(fill(ago(300)), 0)
        XCTAssertEqual(fill(nil), 0)
        XCTAssertEqual(fill(ago(300), 1), 1)
        XCTAssertEqual(word(ago(25)), "10:05")
        XCTAssertEqual(word(ago(25), s: true), "Syncing")
        XCTAssertEqual(word(ago(25), w: true), "iCloud")
        XCTAssertEqual(word(nil), "Not synced yet")
        XCTAssertEqual(word(ago(25), 3), "3 conflicts")
        XCTAssertEqual(word(ago(24 * 60)), "Yesterday")
        XCTAssertEqual(word(ago(3 * 24 * 60)), "2026-11-09")
    }

    /// Build 312: the caption under the ring names the sync and says how long ago.
    func testTheCaptionSaysSyncedAndHowLongAgo() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10, minute: 30))!
        func caption(_ minutes: Double?, _ c: Int = 0, s: Bool = false, w: Bool = false) -> String {
            SyncRing.caption(syncing: s, waiting: w, finishedAt: minutes.map { now.addingTimeInterval(-$0 * 60) },
                             conflicts: c, now: now, calendar: cal)
        }
        XCTAssertEqual(caption(nil), "Not synced")
        XCTAssertEqual(caption(0.5), "Synced just now")
        XCTAssertEqual(caption(5), "Synced 5 min ago")
        XCTAssertEqual(caption(59.9), "Synced 59 min ago")
        XCTAssertEqual(caption(60), "Synced 1 h ago")
        XCTAssertEqual(caption(23 * 60), "Synced 23 h ago")
        XCTAssertEqual(caption(3 * 24 * 60), "Synced 2026-11-09")
        XCTAssertEqual(caption(5, s: true), "Syncing")
        XCTAssertEqual(caption(5, w: true), "iCloud")
        XCTAssertEqual(caption(5, 1), "1 conflict")
    }

    /// Build 304: the count of tasks due today beside the Mac menu bar ring.
    func testTheMenuBarShowsTodaysCountBesideTheRing() {
        XCTAssertNil(SyncRing.dueTodayBadge(0))
        XCTAssertEqual(SyncRing.dueTodayBadge(3), "3")
        XCTAssertEqual(SyncRing.dueTodayBadge(120), "99+")
        XCTAssertEqual(SyncRing.menuBarTitle(dueToday: 0, word: "11:20"), "11:20")
        XCTAssertEqual(SyncRing.menuBarTitle(dueToday: 2, word: "11:20"), "2 · 11:20")
    }
}
