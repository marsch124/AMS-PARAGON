import XCTest
@testable import ParagonCore

final class WeekGoalTests: XCTestCase {
    private let week = WeekRef(year: 2026, week: 41)

    private func weeklyNote(_ text: String) -> Note {
        Note(relativePath: "Calendar/\(week).md", kind: .daily, text: text)
    }

    func testReadsTheGoalFromTheWeeklyNote() {
        let note = weeklyNote("---\nfocus: The garden before winter\n---\n# Week 41\n")
        XCTAssertEqual(WeekGoal.read(from: note), "The garden before winter")
        XCTAssertEqual(NoteIndex(notes: [note]).weekGoal(for: week), "The garden before winter")
    }

    func testNoNoteOrAnEmptyLineIsNoGoal() {
        XCTAssertNil(NoteIndex(notes: []).weekGoal(for: week))
        XCTAssertNil(WeekGoal.read(from: weeklyNote("---\nfocus:\n---\n# Week 41\n")))
        XCTAssertNil(WeekGoal.read(from: weeklyNote("# Week 41\n\n## Focus\n")))
    }

    func testSettingWritesOneLineAndEmptyRemovesIt() {
        let note = weeklyNote("# Week 41\n\n## Tasks\n")
        let set = WeekGoal.setting("  The garden\nbefore   winter ", on: note)
        XCTAssertEqual(set.frontmatter.string("focus"), "The garden before winter")
        XCTAssertTrue(set.body.contains("## Tasks"))
        let cleared = WeekGoal.setting("   ", on: set)
        XCTAssertNil(cleared.frontmatter.string("focus"))
        XCTAssertFalse(cleared.frontmatter.keys.contains("focus"))
    }

    func testTheGoalSurvivesARoundTripThroughTheFile() {
        let set = WeekGoal.setting("Rest, and the garden", on: weeklyNote("# Week 41\n"))
        let reread = Note(relativePath: set.relativePath, kind: .daily, text: set.text)
        XCTAssertEqual(WeekGoal.read(from: reread), "Rest, and the garden")
    }

    func testPlannedMinutesAddUpOnlyWrittenTimes() {
        let path = "Projects/Shed.md"
        let refs = [
            TaskRef(notePath: path, noteTitle: "Shed", task: TaskItem(title: "A", minutes: 45, lineIndex: 0)),
            TaskRef(notePath: path, noteTitle: "Shed", task: TaskItem(title: "B", lineIndex: 1)),
            TaskRef(notePath: path, noteTitle: "Shed", task: TaskItem(title: "C", minutes: 90, lineIndex: 2)),
        ]
        let day = DayOverview(date: DateOnly(year: 2026, month: 10, day: 6), dailyNotePath: nil,
                              due: refs, completed: [], undated: [])
        XCTAssertEqual(day.plannedMinutes, 135)
    }
}
