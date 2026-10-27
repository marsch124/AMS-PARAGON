import XCTest
@testable import ParagonCore

/// Build 272: the **Serves…** menu lists what the Goals and Aspirations screens list.
final class GoalChoicesTests: XCTestCase {
    private func goal(_ title: String, horizon: String, target: String? = nil, status: String? = nil,
                      kind: ParaKind = .goal, folder: String = "Goals") -> Note {
        var lines = ["title: \(title)", "type: goal", "horizon: \(horizon)"]
        if let target { lines.append("target: \(target)") }
        if let status { lines.append("status: \(status)") }
        return Note(relativePath: "\(folder)/\(title).md", kind: kind,
                    text: "---\n" + lines.joined(separator: "\n") + "\n---\n")
    }

    private func titles(_ notes: [Note]) -> [String] { notes.map(\.title) }

    private var vaultNotes: [Note] {
        [
            goal("Zeta life", horizon: "life"),
            goal("Alpha life", horizon: "life"),
            goal("Later goal", horizon: "year", target: "2031-01-01"),
            goal("Sooner goal", horizon: "year", target: "2027-05-01"),
            goal("No date goal", horizon: "year"),
            goal("Reached goal", horizon: "year", target: "2026-01-01", status: "done"),
            goal("Dropped life", horizon: "life", status: "dropped"),
            goal("Missed goal", horizon: "long", target: "2026-02-01", status: "missed"),
            // Archived goals sit in the Archive folder, so their kind is .archive.
            goal("Put away goal", horizon: "year", kind: .archive, folder: "Archive/Goals"),
        ]
    }

    func testAProjectGetsDatedGoalsFirstThenAspirations() {
        let project = Note(relativePath: "Projects/Boots.md", kind: .project,
                           text: "---\ntitle: Boots\ntype: project\n---\n")
        let index = NoteIndex(notes: vaultNotes + [project])
        let choices = index.goalChoices(for: project)
        // Soonest target first, a goal without a date last, as on the Goals screen.
        XCTAssertEqual(titles(choices.first), ["Sooner goal", "Later goal", "No date goal"])
        // By name, as on the Aspirations screen.
        XCTAssertEqual(titles(choices.second), ["Alpha life", "Zeta life"])
        // The same lists the screens use.
        XCTAssertEqual(choices.first, index.datedGoals())
        XCTAssertEqual(choices.second, index.aspirations())
    }

    func testAnAreaGetsAspirationsFirstThenDatedGoals() {
        let area = Note(relativePath: "Areas/Health.md", kind: .area, text: "---\ntitle: Health\ntype: area\n---\n")
        let choices = NoteIndex(notes: vaultNotes + [area]).goalChoices(for: area)
        XCTAssertEqual(titles(choices.first), ["Alpha life", "Zeta life"])
        XCTAssertEqual(titles(choices.second), ["Sooner goal", "Later goal", "No date goal"])
    }

    func testAnArchivedProjectStillGetsDatedGoalsFirst() {
        // Archiving moves the file, so `kind` is .archive; `type:` remembers it is a project.
        let project = Note(relativePath: "Archive/Projects/Boots.md", kind: .archive,
                           text: "---\ntitle: Boots\ntype: project\nstatus: done\n---\n")
        let choices = NoteIndex(notes: vaultNotes + [project]).goalChoices(for: project)
        XCTAssertEqual(titles(choices.first), ["Sooner goal", "Later goal", "No date goal"])
    }

    func testGoalsThatHaveEndedOrBeenPutAwayAreNotOffered() {
        let project = Note(relativePath: "Projects/Boots.md", kind: .project, text: "---\ntitle: Boots\ntype: project\n---\n")
        let choices = NoteIndex(notes: vaultNotes + [project]).goalChoices(for: project)
        let offered = Set(titles(choices.first + choices.second))
        XCTAssertFalse(offered.contains("Reached goal"))
        XCTAssertFalse(offered.contains("Dropped life"))
        XCTAssertFalse(offered.contains("Missed goal"))
        XCTAssertFalse(offered.contains("Put away goal"))
    }

    func testTheNoteItselfIsNeverOffered() {
        let own = goal("Sooner goal", horizon: "year", target: "2027-05-01")
        let others = vaultNotes.filter { $0.title != "Sooner goal" }
        let choices = NoteIndex(notes: others + [own]).goalChoices(for: own)
        // A goal's menu leads with aspirations; neither list holds the goal itself.
        XCTAssertEqual(titles(choices.first), ["Alpha life", "Zeta life"])
        XCTAssertEqual(titles(choices.second), ["Later goal", "No date goal"])

        let aspiration = goal("Alpha life", horizon: "life")
        let choicesForAspiration = NoteIndex(notes: vaultNotes.filter { $0.title != "Alpha life" } + [aspiration])
            .goalChoices(for: aspiration)
        XCTAssertEqual(titles(choicesForAspiration.first), ["Zeta life"])
    }

    func testAnEndedGoalTheNoteAlreadyNamesStaysInTheList() {
        let project = Note(relativePath: "Projects/Boots.md", kind: .project,
                           text: "---\ntitle: Boots\ntype: project\ngoal: Reached goal\n---\n")
        let choices = NoteIndex(notes: vaultNotes + [project]).goalChoices(for: project)
        // In its place by date: its target is the earliest of them all.
        XCTAssertEqual(titles(choices.first), ["Reached goal", "Sooner goal", "Later goal", "No date goal"])
        XCTAssertEqual(titles(choices.second), ["Alpha life", "Zeta life"])
    }

    func testAnEndedAspirationTheNoteAlreadyNamesStaysInTheList() {
        let area = Note(relativePath: "Areas/Health.md", kind: .area,
                        text: "---\ntitle: Health\ntype: area\ngoal: Dropped life\n---\n")
        let choices = NoteIndex(notes: vaultNotes + [area]).goalChoices(for: area)
        XCTAssertEqual(titles(choices.first), ["Alpha life", "Dropped life", "Zeta life"])
        XCTAssertEqual(titles(choices.second), ["Sooner goal", "Later goal", "No date goal"])
    }

    func testALiveGoalTheNoteNamesIsNotListedTwice() {
        let project = Note(relativePath: "Projects/Boots.md", kind: .project,
                           text: "---\ntitle: Boots\ntype: project\ngoal: Sooner goal\n---\n")
        let choices = NoteIndex(notes: vaultNotes + [project]).goalChoices(for: project)
        XCTAssertEqual(titles(choices.first), ["Sooner goal", "Later goal", "No date goal"])
    }

    func testANoteThatNamesItselfDoesNotGetItselfBack() {
        // A hand-typed `goal:` pointing at the note's own title.
        let own = Note(relativePath: "Goals/Loop.md", kind: .goal,
                       text: "---\ntitle: Loop\ntype: goal\nhorizon: year\ngoal: Loop\n---\n")
        let choices = NoteIndex(notes: vaultNotes + [own]).goalChoices(for: own)
        XCTAssertFalse(titles(choices.first + choices.second).contains("Loop"))
    }

    func testAVaultWithNoGoalsGivesTwoEmptyLists() {
        let project = Note(relativePath: "Projects/Boots.md", kind: .project, text: "---\ntitle: Boots\ntype: project\n---\n")
        let choices = NoteIndex(notes: [project]).goalChoices(for: project)
        XCTAssertTrue(choices.first.isEmpty)
        XCTAssertTrue(choices.second.isEmpty)
    }
}
