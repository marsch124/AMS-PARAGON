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
        XCTAssertEqual(word(nil), "Not yet")
        XCTAssertEqual(word(ago(25), 3), "3 conflicts")
        XCTAssertEqual(word(ago(24 * 60)), "Yesterday")
        XCTAssertEqual(word(ago(3 * 24 * 60)), "9 Nov")
    }
}
