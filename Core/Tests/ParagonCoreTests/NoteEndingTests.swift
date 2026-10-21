import XCTest
@testable import ParagonCore

/// Build 262: the day a project ends, written as `ended:` and kept in step with `status:`, and
/// the line "Done on 20 October · after 41 days · 17 tasks finished" read back from it.
final class NoteEndingTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 10, day: 20)
    private let english = Locale(identifier: "en_GB")

    private func project(_ frontmatter: String, body: String = "# Shed\n") -> Note {
        Note(relativePath: "Projects/Shed.md", kind: .project,
             text: "---\ntitle: Shed\ntype: project\n\(frontmatter)---\n\(body)")
    }

    // MARK: Writing the day

    func testEndingWritesToday() {
        let ended = project("created: 2026-09-09\n").settingStatus(.done, today: today)
        XCTAssertEqual(ended.noteStatus, .done)
        XCTAssertEqual(ended.endedDate, today)
        XCTAssertEqual(ended.frontmatter.string("ended"), "2026-10-20")
    }

    func testEveryEndingWritesTheDay() {
        for ending in NoteStatus.endings {
            XCTAssertEqual(project("").settingStatus(ending, today: today).endedDate, today, "\(ending)")
        }
    }

    /// Done → Missed changes the word for how it ended, not the day it ended.
    func testChangingTheEndingKeepsTheDay() {
        let first = project("").settingStatus(.done, today: today)
        let later = first.settingStatus(.missed, today: DateOnly(year: 2026, month: 11, day: 3))
        XCTAssertEqual(later.noteStatus, .missed)
        XCTAssertEqual(later.endedDate, today)
    }

    /// A project that ended before build 262 has no day, and none is made up for it.
    func testAnOldEndingIsNeverGivenADay() {
        let old = project("status: done\n")
        XCTAssertNil(old.endedDate)
        XCTAssertNil(old.settingStatus(.dropped, today: today).endedDate)
    }

    /// Archiving keeps `ended:` but writes `status: archived`. Marking such a note Done again
    /// keeps the day it really ended; one that never had a day gets today (review of 262).
    func testAnArchivedNoteKeepsTheDayItEnded() {
        let archived = project("status: archived\nended: 2026-09-15\n")
        let again = archived.settingStatus(.done, today: today)
        XCTAssertEqual(again.noteStatus, .done)
        XCTAssertEqual(again.endedDate, DateOnly(year: 2026, month: 9, day: 15))

        let noDay = project("status: archived\n").settingStatus(.done, today: today)
        XCTAssertEqual(noDay.endedDate, today)
    }

    func testActiveRemovesBothLines() {
        let ended = project("").settingStatus(.done, today: today)
        let again = ended.settingStatus(.active, today: today)
        XCTAssertNil(again.frontmatter.string("status"))
        XCTAssertNil(again.frontmatter.string("ended"))
        XCTAssertEqual(again.noteStatus, .active)
    }

    func testOnHoldRemovesTheDay() {
        let ended = project("").settingStatus(.missed, today: today)
        let held = ended.settingStatus(.onHold, today: today)
        XCTAssertEqual(held.noteStatus, .onHold)
        XCTAssertNil(held.endedDate)
    }

    /// The status it already has changes nothing, so pressing it again never moves the file.
    func testTheSameStatusChangesNothing() {
        let ended = project("status: done\nended: 2026-10-01\n")
        XCTAssertEqual(ended.settingStatus(.done, today: today), ended)
        // An older spelling of done is still done.
        let achieved = project("status: achieved\n")
        XCTAssertEqual(achieved.settingStatus(.done, today: today), achieved)
        let fresh = project("")
        XCTAssertEqual(fresh.settingStatus(.active, today: today), fresh)
    }

    func testTheDayCanBeChanged() {
        let ended = project("status: done\n")
        let set = ended.settingEndedDate(DateOnly(year: 2026, month: 3, day: 3))
        XCTAssertEqual(set.endedDate, DateOnly(year: 2026, month: 3, day: 3))
        XCTAssertEqual(set.settingEndedDate(DateOnly(year: 2026, month: 3, day: 3)), set)
        XCTAssertNil(set.settingEndedDate(nil).endedDate)
        XCTAssertEqual(ended.settingEndedDate(nil), ended)
    }

    /// The line survives a round trip through the file.
    func testTheDayReadsBackFromTheFile() {
        let ended = project("created: 2026-09-09\n").settingStatus(.done, today: today)
        let reread = Note(relativePath: ended.relativePath, kind: .project, text: ended.text)
        XCTAssertEqual(reread.endedDate, today)
        XCTAssertEqual(reread.createdDate, DateOnly(year: 2026, month: 9, day: 9))
    }

    // MARK: The line

    func testTheWholeLine() {
        let body = "# Shed\n\n- [x] Pour the base\n- [x] Raise the walls\n  - [x] A subtask is not counted\n- [-] Paint it\n- [ ] Still open\n"
        let note = project("status: done\ncreated: 2026-09-09\nended: 2026-10-20\n", body: body)
        let line = ProjectEnding(note: note)?.line(today: today, locale: english)
        XCTAssertEqual(line, "Done on 20 October · after 41 days · 2 tasks finished")
    }

    func testTheYearIsAddedWhenItIsNotThisYear() {
        let note = project("status: dropped\nended: 2025-03-03\n")
        let line = ProjectEnding(note: note)?.line(today: today, locale: english) ?? ""
        XCTAssertTrue(line.hasPrefix("Dropped on 3 March 2025"), line)
    }

    func testAPartTheNoteCannotProveIsLeftOut() {
        let note = project("status: missed\nended: 2026-10-20\n")
        XCTAssertEqual(ProjectEnding(note: note)?.line(today: today, locale: english), "Missed on 20 October")
    }

    func testNoDayMeansNoLine() {
        let note = project("status: done\ncreated: 2026-01-01\n")
        XCTAssertNotNil(ProjectEnding(note: note))
        XCTAssertNil(ProjectEnding(note: note)?.line(today: today, locale: english))
    }

    func testAProjectThatHasNotEndedHasNoEnding() {
        XCTAssertNil(ProjectEnding(note: project("")))
        XCTAssertNil(ProjectEnding(note: project("status: on-hold\n")))
    }

    func testHowLongItTook() {
        func duration(_ created: String, _ ended: String) -> String? {
            ProjectEnding(status: .done, ended: DateOnly(ended), created: DateOnly(created), finishedTasks: 0)
                .durationText()
        }
        XCTAssertEqual(duration("2026-10-19", "2026-10-20"), "after 1 day")
        XCTAssertEqual(duration("2026-09-09", "2026-10-20"), "after 41 days")
        XCTAssertEqual(duration("2026-08-22", "2026-10-20"), "after 59 days")
        XCTAssertEqual(duration("2026-08-21", "2026-10-20"), "after about 2 months")
        XCTAssertEqual(duration("2026-01-20", "2026-10-20"), "after about 9 months")
        XCTAssertEqual(duration("2023-10-20", "2026-10-20"), "after about 3 years")
        // Made and ended on one day, or the dates the wrong way round: nothing to say.
        XCTAssertNil(duration("2026-10-20", "2026-10-20"))
        XCTAssertNil(duration("2026-11-01", "2026-10-20"))
    }

    func testTasksAreNeverZero() {
        func tasks(_ n: Int) -> String? {
            ProjectEnding(status: .done, ended: nil, created: nil, finishedTasks: n).tasksText
        }
        XCTAssertNil(tasks(0))
        XCTAssertEqual(tasks(1), "1 task finished")
        XCTAssertEqual(tasks(17), "17 tasks finished")
    }
}
