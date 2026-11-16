import XCTest
@testable import ParagonCore

/// Build 330: many days from one walk give exactly what one day at a time gives.
final class DayOverviewsTests: XCTestCase {
    func testManyDaysAtOnceEqualOneDayAtATime() {
        let a = Note(relativePath: "Projects/Trip.md", kind: .project, text: """
        # Trip
        - [ ] Book the ferry >2026-11-17
        - [ ] Pack !! >2026-11-17T09:00
        - [x] Buy a map @done(2026-11-16 10:00)
        - [ ] Some day
        """)
        let b = Note(relativePath: "Calendar/20261117.md", kind: .daily, text: """
        # 2026-11-17
        - [ ] Loose thought
        - [x] Call Anna @done(2026-11-17 08:00)
        """)
        let index = NoteIndex(notes: [a, b])
        let days = (15...19).map { DateOnly(year: 2026, month: 11, day: $0) }
        let together = index.dayOverviews(for: days)
        XCTAssertEqual(together.count, days.count)
        for day in days {
            XCTAssertEqual(together[day], index.dayOverview(for: day), "\(day)")
        }
        XCTAssertEqual(together[days[2]]?.due.count, 2)
    }
}
