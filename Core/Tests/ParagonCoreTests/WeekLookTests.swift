import XCTest
@testable import ParagonCore

/// Build 263: step 7 of the Weekly review, **Look back at the week**, and the one day record
/// it is built from.
final class WeekLookTests: XCTestCase {
    /// Week 42 of 2026: Monday 12 to Sunday 18 October.
    private let week = WeekRef(year: 2026, week: 42)

    private func day(_ d: Int) -> DateOnly { DateOnly(year: 2026, month: 10, day: d) }

    private func daily(_ d: Int, _ body: String) -> Note {
        let name = String(format: "202610%02d", d)
        return Note(relativePath: "Calendar/\(name).md", kind: .daily,
                    text: "---\ntitle: \(name)\n---\n\(body)")
    }

    private func project(_ title: String, _ frontmatter: String = "", body: String) -> Note {
        Note(relativePath: "Projects/\(title).md", kind: .project,
             text: "---\ntitle: \(title)\ntype: project\n\(frontmatter)---\n# \(title)\n\n\(body)")
    }

    func testTheWeekIsMondayToSunday() {
        XCTAssertEqual(week.monday, day(12))
        XCTAssertEqual(week.sunday, day(18))
    }

    // MARK: Finished tasks

    func testFinishedTasksCountOnTheDayOfTheirStamp() {
        let shed = project("Shed", body: """
        - [x] Pour the base @done(2026-10-12 09:10)
        - [x] Raise the walls @done(2026-10-15 16:00)
          - [x] Nail the corners @done(2026-10-15 15:00)
        - [x] Before the week @done(2026-10-11 20:00)
        - [x] After the week @done(2026-10-19 08:00)
        - [x] Ticked with no stamp
        - [-] Cancelled @done(2026-10-13 10:00)
        - [ ] Still open
        """)
        let look = NoteIndex(notes: [shed]).weekLook(for: week)
        XCTAssertEqual(look.days.map(\.day), week.days)
        XCTAssertEqual(look.days.map(\.finished.count), [1, 0, 0, 2, 0, 0, 0])
        XCTAssertEqual(look.finished.count, 3)
        XCTAssertEqual(look.biggest, 2)
        XCTAssertEqual(look.finishedText, "3 tasks finished")
    }

    /// The week's count and the seven daily counts are one rule.
    func testTheWeekAgreesWithTheDayByDayCount() {
        let shed = project("Shed", body: "- [x] A @done(2026-10-12 09:10)\n- [x] B @done(2026-10-14)\n- [x] C @done(2026-10-14 12:00)\n")
        let index = NoteIndex(notes: [shed])
        let look = index.weekLook(for: week)
        for record in look.days {
            XCTAssertEqual(record.finished.map(\.id), index.tasksCompleted(on: record.day).map(\.id), "\(record.day)")
        }
    }

    func testNothingFinishedIsNotAZero() {
        let look = NoteIndex(notes: []).weekLook(for: week)
        XCTAssertNil(look.finishedText)
        XCTAssertEqual(look.biggest, 1)
        XCTAssertEqual(NoteIndex(notes: [project("Shed", body: "- [x] One @done(2026-10-13)\n")])
                        .weekLook(for: week).finishedText, "1 task finished")
    }

    // MARK: Evenings and the timer

    func testTheEveningLineComesFromLookingBack() {
        let monday = daily(12, "## Tasks\n\n## Looking back\n\nGood start. The saddle can wait.\n")
        let tuesday = daily(13, "## Tasks\n")
        let look = NoteIndex(notes: [monday, tuesday]).weekLook(for: week)
        XCTAssertEqual(look.days[0].lookingBack, "Good start. The saddle can wait.")
        XCTAssertEqual(look.days[0].dailyNotePath, "Calendar/20261012.md")
        XCTAssertEqual(look.days[1].lookingBack, "")
        XCTAssertEqual(look.days[1].dailyNotePath, "Calendar/20261013.md")
        XCTAssertNil(look.days[2].dailyNotePath)
        XCTAssertEqual(look.evenings.map(\.day), [day(12)])
    }

    func testWorkedMinutesAddUpAndAreNilWhenTheTimerWasNotUsed() {
        let monday = daily(12, "## Worked\n\n- 08:00-08:45 Write the offer\n\n- 09:00-09:20 Call the bank\n")
        let wednesday = daily(14, "## Worked\n\n- 10:00-11:15 Garden\n")
        let thursday = daily(15, "## Tasks\n")
        let look = NoteIndex(notes: [monday, wednesday, thursday]).weekLook(for: week)
        XCTAssertEqual(look.days.map(\.workedMinutes), [65, nil, 75, nil, nil, nil, nil])
        XCTAssertEqual(look.workedMinutes, 140)
        XCTAssertEqual(look.workedText, "2 h 20 min on the focus timer")

        let quiet = NoteIndex(notes: [thursday]).weekLook(for: week)
        XCTAssertNil(quiet.workedMinutes)
        XCTAssertNil(quiet.workedText)
    }

    // MARK: The goal and the endings

    func testTheGoalComesFromTheWeeklyNote() {
        let weekly = Note(relativePath: "Calendar/2026-W42.md", kind: .daily,
                          text: "---\nfocus: The garden before winter\n---\n# Week 42\n")
        XCTAssertEqual(NoteIndex(notes: [weekly]).weekLook(for: week).goal, "The garden before winter")
        XCTAssertNil(NoteIndex(notes: []).weekLook(for: week).goal)
    }

    func testProjectsThatEndedInTheWeek() {
        let bike = project("Fix the bike", "status: done\nended: 2026-10-16\n", body: "")
        let fence = project("Paint the fence", "status: dropped\nended: 2026-10-13\n", body: "")
        let earlier = project("Old one", "status: done\nended: 2026-10-01\n", body: "")
        let undated = project("No day", "status: done\n", body: "")
        let running = project("Running", "ended: 2026-10-14\n", body: "")
        let look = NoteIndex(notes: [bike, fence, earlier, undated, running]).weekLook(for: week)
        XCTAssertEqual(look.endedProjects.map(\.title), ["Paint the fence", "Fix the bike"])
        XCTAssertEqual(look.endedProjects.map(\.status), [.dropped, .done])
    }

    // MARK: Which week

    func testMondayAndTuesdayLookAtTheWeekJustEnded() {
        let last = WeekRef(year: 2026, week: 42)
        let this = WeekRef(year: 2026, week: 43)
        XCTAssertEqual(WeekLook.weekToShow(today: DateOnly(year: 2026, month: 10, day: 19)), last) // Monday
        XCTAssertEqual(WeekLook.weekToShow(today: DateOnly(year: 2026, month: 10, day: 20)), last) // Tuesday
        XCTAssertEqual(WeekLook.weekToShow(today: DateOnly(year: 2026, month: 10, day: 21)), this) // Wednesday
        XCTAssertEqual(WeekLook.weekToShow(today: DateOnly(year: 2026, month: 10, day: 25)), this) // Sunday
    }

    /// The first week of a year still steps back into the old one.
    func testTheWeekBeforeTheFirstWeekOfTheYear() {
        let monday = DateOnly(year: 2027, month: 1, day: 4) // Week 1 of 2027
        XCTAssertEqual(WeekRef(containing: monday), WeekRef(year: 2027, week: 1))
        XCTAssertEqual(WeekLook.weekToShow(today: monday), WeekRef(year: 2026, week: 53))
    }

    // MARK: What it served

    /// A week of tasks ticked in the days' own notes is one row, not seven rows of dates, so the
    /// goals are not pushed out of the six the step shows (review of 263).
    func testTheDaysOwnNotesAreOneRow() {
        let counts = [
            ServedCount(title: "Monday 12 October 2026", kind: .note(.daily), count: 1),
            ServedCount(title: "Walk the Kungsleden", kind: .goal, count: 2),
            ServedCount(title: "Wednesday 14 October 2026", kind: .note(.daily), count: 2),
            ServedCount(title: "Health", kind: .area, count: 1),
        ]
        let merged = ServedCount.mergingDailyNotes(counts)
        XCTAssertEqual(merged.map(\.title), ["Daily notes", "Walk the Kungsleden", "Health"])
        XCTAssertEqual(merged.map(\.count), [3, 2, 1])
        XCTAssertEqual(merged.first?.kind, ServedCount.Kind.note(.daily))
    }

    /// One day's note keeps its own date: nothing is gained by renaming it.
    func testOneDailyNoteKeepsItsDate() {
        let counts = [ServedCount(title: "Health", kind: .area, count: 2),
                      ServedCount(title: "Monday 12 October 2026", kind: .note(.daily), count: 1)]
        XCTAssertEqual(ServedCount.mergingDailyNotes(counts), counts)
    }

    func testDoneDayReadsOnlyDoneTasks() {
        XCTAssertEqual(TaskItem(status: .done, title: "A", doneStamp: "2026-10-12 09:10").doneDay, day(12))
        XCTAssertEqual(TaskItem(status: .done, title: "A", doneStamp: "2026-10-12").doneDay, day(12))
        XCTAssertNil(TaskItem(status: .done, title: "A").doneDay)
        XCTAssertNil(TaskItem(status: .cancelled, title: "A", doneStamp: "2026-10-12").doneDay)
    }
}
