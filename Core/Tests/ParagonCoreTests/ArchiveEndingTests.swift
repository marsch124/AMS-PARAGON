import XCTest
@testable import ParagonCore

/// Build 272: archiving puts a note away and does not undo how it ended.
///
/// Before this, `Vault.archive` replaced `status: done` with `status: archived`. A finished
/// project then dropped out of its goal's per cent and, since build 262, lost the day it ended.
/// The tests below archive through the real `Vault` and read the files back, because the fault
/// was in what was written, not in what the readers do with a note that has the right words.
final class ArchiveEndingTests: XCTestCase {
    var vault: Vault!
    let endedDay = DateOnly(year: 2026, month: 8, day: 2)
    let today = DateOnly(year: 2026, month: 9, day: 6)

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    /// A goal with one project under it, ended the way the test asks.
    private func goalWithProject(ending: NoteStatus?) throws -> (goal: Note, project: Note) {
        let goal = try vault.createNote(kind: .goal, title: "Walk the Kungsleden",
                                        extraFrontmatter: [("horizon", "year"), ("target", "2028-08-15")])
        var project = try vault.createNote(kind: .project, title: "Buy the boots",
                                           extraFrontmatter: [("goal", "Walk the Kungsleden")])
        project.body = "- [x] Try them on @done(2026-08-01 08:00)\n- [ ] Pick the laces\n"
        if let ending {
            project = project.settingStatus(ending, today: endedDay)
        }
        project = try vault.save(project)
        return (goal, project)
    }

    func testAnArchivedDoneProjectKeepsItsStatusAndItsDay() throws {
        let (_, project) = try goalWithProject(ending: .done)
        let archived = try vault.archive(project)

        XCTAssertEqual(archived.relativePath, "Archive/Projects/Buy the boots.md")
        XCTAssertEqual(archived.kind, .archive)
        XCTAssertTrue(archived.isArchived)
        XCTAssertEqual(archived.noteStatus, .done)
        XCTAssertEqual(archived.endedDate, endedDay)

        // Read back from the file, which is what every screen sees.
        let reread = try vault.loadNote(relativePath: archived.relativePath)
        XCTAssertEqual(reread.status, "done")
        XCTAssertEqual(reread.endedDate, endedDay)
        XCTAssertNotNil(reread.frontmatter.string("archived"))
        XCTAssertEqual(reread.frontmatter.bool("sync"), false)
        // The folder layout and the `type:` line are as they were: `declaredKind` still says project.
        XCTAssertEqual(reread.frontmatter.string("type"), "project")
        XCTAssertEqual(reread.declaredKind, .project)
        XCTAssertTrue(reread.isFinishedProject)
    }

    func testAnArchivedDoneProjectStillCountsForItsGoal() throws {
        let (goal, project) = try goalWithProject(ending: .done)
        let before = NoteIndex(notes: try vault.allNotes()).progress(of: goal)
        XCTAssertEqual(before.projectsDone, 1)
        XCTAssertEqual(before.projectsTotal, 1)
        XCTAssertEqual(before.percent, 100)

        _ = try vault.archive(project)

        let index = NoteIndex(notes: try vault.allNotes())
        let after = index.progress(of: goal)
        XCTAssertEqual(after, before)

        // It is still drawn under its goal, as finished work, and is counted as finished.
        let chain = index.chainGoal(of: goal, today: today)
        XCTAssertEqual(chain.finishedProjects.map(\.note.title), ["Buy the boots"])
        XCTAssertTrue(chain.projects.isEmpty)
        XCTAssertEqual(chain.activity.projectsFinished, 1)
        let health = index.goalHealth(of: goal, today: today)
        XCTAssertFalse(health.flags.contains(.nothingServing))
    }

    func testAnArchivedDoneProjectIsStillInTheWeekItEnded() throws {
        let (_, project) = try goalWithProject(ending: .done)
        _ = try vault.archive(project)
        let index = NoteIndex(notes: try vault.allNotes())
        let look = index.weekLook(for: WeekRef(containing: endedDay))
        XCTAssertEqual(look.endedProjects.map(\.title), ["Buy the boots"])
        XCTAssertEqual(look.endedProjects.map(\.ended), [endedDay])
    }

    func testAnArchivedActiveProjectIsWrittenAsArchivedAsBefore() throws {
        let (goal, project) = try goalWithProject(ending: nil)
        let archived = try vault.archive(project)

        XCTAssertEqual(archived.status, "archived")
        XCTAssertEqual(archived.noteStatus, .archived)
        XCTAssertNil(archived.endedDate)
        XCTAssertTrue(archived.isArchived)

        // Never finished and put away: it was dropped, not left undone, so the goal ignores it.
        let progress = NoteIndex(notes: try vault.allNotes()).progress(of: goal)
        XCTAssertEqual(progress.projectsTotal, 0)
        XCTAssertNil(progress.fraction)
    }

    func testAnArchivedOnHoldProjectIsWrittenAsArchived() throws {
        let (_, project) = try goalWithProject(ending: .onHold)
        XCTAssertEqual(project.noteStatus, .onHold)
        let archived = try vault.archive(project)
        XCTAssertEqual(archived.status, "archived")
    }

    func testAnArchivedMissedProjectStaysMissed() throws {
        let (goal, project) = try goalWithProject(ending: .missed)
        let archived = try vault.archive(project)

        XCTAssertEqual(archived.noteStatus, .missed)
        XCTAssertEqual(archived.endedDate, endedDay)
        XCTAssertTrue(archived.isArchived)

        // A missed project did not deliver, so it is left out of the per cent, archived or not.
        let index = NoteIndex(notes: try vault.allNotes())
        let progress = index.progress(of: goal)
        XCTAssertEqual(progress.projectsTotal, 0)
        XCTAssertEqual(progress.projectsDone, 0)
        XCTAssertNil(progress.fraction)
        // It is still visible under the goal, as missed (build 100's rule), and not as finished.
        let chain = index.chainGoal(of: goal, today: today)
        XCTAssertEqual(chain.finishedProjects.map(\.note.title), ["Buy the boots"])
        XCTAssertEqual(chain.activity.projectsFinished, 0)
    }

    func testAnArchivedDroppedProjectStaysDropped() throws {
        let (_, project) = try goalWithProject(ending: .dropped)
        let archived = try vault.archive(project)
        XCTAssertEqual(archived.noteStatus, .dropped)
        XCTAssertEqual(archived.endedDate, endedDay)
    }

    func testAnOlderSpellingOfDoneIsKeptAsWritten() throws {
        var project = try vault.createNote(kind: .project, title: "Old push",
                                           extraFrontmatter: [("status", "achieved"), ("ended", "2026-01-05")])
        project.body = "- [x] One @done(2026-01-04 08:00)\n"
        project = try vault.save(project)
        let archived = try vault.archive(project)
        XCTAssertEqual(archived.status, "achieved")
        XCTAssertEqual(archived.noteStatus, .done)
        XCTAssertEqual(archived.endedDate, DateOnly(year: 2026, month: 1, day: 5))
    }

    func testAnAreaWithNoEndingIsStillWrittenAsArchived() throws {
        let area = try vault.createNote(kind: .area, title: "Garden")
        let archived = try vault.archive(area)
        XCTAssertEqual(archived.status, "archived")
    }

    func testArchivingAnAlreadyArchivedNoteChangesNothing() throws {
        let (_, project) = try goalWithProject(ending: .done)
        let archived = try vault.archive(project)
        let again = try vault.archive(archived)
        XCTAssertEqual(again.relativePath, archived.relativePath)
        XCTAssertEqual(again.text, archived.text)
    }

    func testTheArchivedBoxStillFindsAnArchivedDoneProject() throws {
        let (_, project) = try goalWithProject(ending: .done)
        let archived = try vault.archive(project)
        let live = try vault.createNote(kind: .project, title: "Buy the socks")
        let index = NoteIndex(notes: [archived, live])

        // Found as the ending it has and as archived: the Archived box must not lose it.
        XCTAssertEqual(index.search(text: "status:done", today: today).map(\.note.title), ["Buy the boots"])
        XCTAssertEqual(index.search(text: "status:archived", today: today).map(\.note.title), ["Buy the boots"])
        XCTAssertEqual(index.search(text: "status:missed", today: today).map(\.note.title), [])
    }
}
