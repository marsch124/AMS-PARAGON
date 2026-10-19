import XCTest
@testable import ParagonCore

/// The weekly bars on the Projects list (build 255). Monday 19 October 2026 is "today", so this
/// week runs from the 19th to the 25th and the week before it from the 12th to the 18th.
final class WeeklyFinishedTests: XCTestCase {
    let today = DateOnly(year: 2026, month: 10, day: 19)

    private func tasks(_ body: String) -> [TaskItem] {
        Note(relativePath: "Projects/Boat.md", kind: .project,
             text: "---\ntitle: Boat\ntype: project\n---\n" + body).tasks
    }

    func testEachFinishedTaskLandsInItsCalendarWeek() {
        let weekly = WeeklyFinished(tasks: tasks("""
            - [x] Today @done(2026-10-19 08:00)
            - [x] Last Sunday @done(2026-10-18 20:00)
                - [x] A subtask @done(2026-10-13 10:00)
            - [x] Seven weeks back @done(2026-08-31 09:00)
            - [x] Eight weeks back, off the bars @done(2026-08-24 09:00)
            - [x] Ticked with no stamp
            - [-] Called off @done(2026-10-19 09:00)
            - [ ] Still open

            """), today: today)
        XCTAssertEqual(weekly.counts, [1, 0, 0, 0, 0, 0, 2, 1],
                       "Oldest first; Sunday is last week, Monday is this week; a subtask counts; no stamp and called off do not")
        XCTAssertEqual(weekly.total, 4)
        XCTAssertEqual(weekly.thisWeek, 1)
        XCTAssertEqual(weekly.lastFinished, today)
        XCTAssertEqual(weekly.biggest, 2)
        XCTAssertFalse(weekly.isEmpty)
    }

    func testTheCaptionSaysHowMuchOrSinceWhen() {
        let moving = WeeklyFinished(tasks: tasks("- [x] A @done(2026-10-15 08:00)\n- [x] B @done(2026-09-30 08:00)\n"),
                                    today: today)
        XCTAssertEqual(moving.caption(today: today), "2 finished in 8 weeks")

        let quiet = WeeklyFinished(tasks: tasks("- [x] A @done(2026-08-31 09:00)\n"), today: today)
        XCTAssertEqual(quiet.caption(today: today), "last task finished about 2 months ago")

        let long = WeeklyFinished(tasks: tasks("- [x] A @done(2025-06-01 09:00)\n"), today: today)
        XCTAssertEqual(long.counts, Array(repeating: 0, count: 8))
        XCTAssertFalse(long.isEmpty, "Something was finished once, so the box can say since when")
        XCTAssertEqual(long.caption(today: today), "last task finished about a year ago")
    }

    func testNothingDatedMeansNothingToDraw() {
        let none = WeeklyFinished(tasks: tasks("- [x] Ticked with no stamp\n- [ ] Open\n"), today: today)
        XCTAssertTrue(none.isEmpty)
        XCTAssertNil(none.caption(today: today))
        XCTAssertNil(none.bandText, "No band saying 0: the file cannot say, which is not the same as nothing done")
        XCTAssertEqual(none.biggest, 1, "Never divides by nothing")
    }

    func testTheBandAddsTheProjectsUp() {
        let a = WeeklyFinished(tasks: tasks("- [x] A @done(2026-10-19 08:00)\n- [x] B @done(2026-10-01 08:00)\n"), today: today)
        let b = WeeklyFinished(tasks: tasks("- [x] C @done(2026-10-20 08:00)\n"), today: today)
        let all = WeeklyFinished.combined([a, b, WeeklyFinished(tasks: [], today: today)])
        XCTAssertEqual(all.total, 3)
        XCTAssertEqual(all.thisWeek, 2)
        XCTAssertEqual(all.lastFinished, DateOnly(year: 2026, month: 10, day: 20))
        XCTAssertEqual(all.bandText, "3 tasks finished in 8 weeks · 2 this week")
        XCTAssertEqual(WeeklyFinished.combined([b]).bandText, "1 task finished in 8 weeks · 1 this week")
        XCTAssertTrue(WeeklyFinished.combined([]).isEmpty)
    }

    func testTheWords() {
        XCTAssertEqual(WeeklyFinished.agoText(days: 0), "today")
        XCTAssertEqual(WeeklyFinished.agoText(days: 1), "yesterday")
        XCTAssertEqual(WeeklyFinished.agoText(days: 5), "5 days ago")
        XCTAssertEqual(WeeklyFinished.agoText(days: 31), "about a month ago")
        XCTAssertEqual(WeeklyFinished.agoText(days: 400), "about a year ago")
        XCTAssertEqual(WeeklyFinished.agoText(days: 800), "about 2 years ago")
        XCTAssertEqual(WeeklyFinished.lookText(1), "1 needs a look")
        XCTAssertEqual(WeeklyFinished.lookText(3), "3 need a look")
    }

    func testEachBoxCarriesItsOwnBars() {
        let boat = Note(relativePath: "Projects/Boat.md", kind: .project,
                        text: "---\ntitle: Boat\ntype: project\n---\n- [x] Sand it @done(2026-10-19 08:00)\n- [ ] Paint it\n")
        let groups = NoteIndex(notes: [boat]).projectGroups([boat], today: today)
        XCTAssertEqual(groups.first?.lines.first?.weekly.thisWeek, 1)
        XCTAssertEqual(ProjectGroup.weekly(of: groups).total, 1)
        XCTAssertEqual(ProjectGroup.needsALookCount(of: groups), 0)
    }
}
