import XCTest
@testable import ParagonCore

/// Build 325: overdue and **Due today** go by the earlier of do-day and deadline.
final class DeadlineCountsTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 11, day: 16)

    func testTheDayThatPressesFirstDecides() throws {
        let note = Note(relativePath: "Projects/P.md", kind: .project, text: """
        - [ ] Later do-day, deadline passed >2026-11-20 @deadline(2026-11-15)
        - [ ] Deadline today, no do-day @deadline(2026-11-16)
        - [ ] Do-day passed, deadline later >2026-11-14 @deadline(2026-11-30)
        - [ ] Neither yet >2026-11-18 @deadline(2026-11-25)
        - [ ] Plain today >2026-11-16
        """)
        let index = NoteIndex(notes: [note])
        let dated = index.openTasks(dueOnOrBefore: today)
        XCTAssertEqual(dated.filter { $0.task.isOverdue(on: today) }.map(\.task.title),
                       ["Do-day passed, deadline later", "Later do-day, deadline passed"])
        XCTAssertEqual(Set(dated.filter { $0.task.isDue(on: today) }.map(\.task.title)),
                       ["Deadline today, no do-day", "Plain today"])
        // Close the day moves do-days only: a passed deadline alone does not bring a task back.
        XCTAssertEqual(Set(index.openTasks(dueOnOrBefore: today, byDeadlineToo: false).map(\.task.title)),
                       ["Do-day passed, deadline later", "Plain today"])
        let snap = index.widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        XCTAssertEqual(snap.overdue, 2)
        XCTAssertEqual(snap.dueToday, 2)
    }
}
