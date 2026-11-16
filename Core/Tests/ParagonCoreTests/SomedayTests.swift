import XCTest
@testable import ParagonCore

/// Build 330: one task put aside for someday, and the loose tasks of the weekly review.
final class SomedayTests: XCTestCase {
    private func note(_ path: String, _ kind: ParaKind, _ text: String, touched: TimeInterval = 0) -> Note {
        var note = Note(relativePath: path, kind: kind, text: text)
        note.modifiedAt = Date(timeIntervalSince1970: touched)
        return note
    }

    func testPuttingAsideTakesTheDateOffAndComesBackWhole() throws {
        let n = note("Projects/Trip.md", .project, "# Trip\n- [ ] Book the ferry #next >2026-11-20 @deadline(2026-12-01)\n")
        let task = try XCTUnwrap(n.tasks.first)
        let aside = task.settingSomeday(true)
        XCTAssertTrue(aside.isSomeday)
        XCTAssertNil(aside.dueDate)
        XCTAssertEqual(aside.deadline, task.deadline)
        XCTAssertFalse(aside.tags.contains("next"))
        XCTAssertEqual(aside.settingSomeday(true), aside, "twice is once")
        let back = aside.settingSomeday(false)
        XCTAssertFalse(back.isSomeday)
        XCTAssertFalse(back.title.contains("#someday"))
        XCTAssertTrue(back.title.contains("Book the ferry"))
    }

    func testASomedayTaskIsNeverTheNextThingAndHidesFromAllActions() {
        let n = note("Projects/Trip.md", .project, "# Trip\n- [ ] Learn Spanish #someday\n- [ ] Book the ferry\n")
        XCTAssertEqual(n.nextThing?.title, "Book the ferry")
        let all = NoteIndex(notes: [n]).openTasks()
        let today = DateOnly(year: 2026, month: 11, day: 16)
        XCTAssertEqual(ActionFilter().apply(to: all, today: today).map(\.task.title), ["Book the ferry"])
        XCTAssertEqual(ActionFilter(marks: [.someday]).apply(to: all, today: today).count, 1)
        XCTAssertFalse(ActionFilter.tagChoices(among: all).contains("someday"))
    }

    func testLooseTasksAreTheOnesNothingElseLooksAt() {
        let old = note("Areas/Home.md", .area, """
        # Home
        - [ ] Sort the cellar
        - [ ] Paint the fence >2026-11-20
        - [ ] Call the plumber #waiting
        - [ ] Build a sauna #someday
        - [x] Done already
        """, touched: 100)
        let project = note("Projects/Trip.md", .project, "# Trip\n- [ ] Book the ferry\n- [ ] Buy a map\n", touched: 200)
        let inbox = note("Inbox.md", .inbox, "# Inbox\n- [ ] Unsorted\n", touched: 50)
        let loose = NoteIndex(notes: [project, old, inbox]).looseTasks(inboxPath: "Inbox.md")
        XCTAssertEqual(loose.map(\.task.title), ["Sort the cellar", "Buy a map"],
                       "longest untouched note first; next action, dated, waiting, someday and Inbox left out")
    }
}
