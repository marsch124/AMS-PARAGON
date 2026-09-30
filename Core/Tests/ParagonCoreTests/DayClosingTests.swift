import XCTest
@testable import ParagonCore

/// Build 236: what **Close the day** counts, and the **First** marks it leaves for the morning.
final class DayClosingTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 9, day: 30)
    private let tomorrow = DateOnly(year: 2026, month: 10, day: 1)

    private func note(_ name: String, kind: ParaKind, folder: String, lines: [String], body: String) -> Note {
        let front = "---\ntitle: \(name)\ntype: \(kind.rawValue)\n" + lines.map { $0 + "\n" }.joined() + "---\n"
        return Note(relativePath: "\(folder)/\(name).md", kind: kind, text: front + body)
    }

    private func refs(_ note: Note) -> [TaskRef] {
        note.tasks.map { TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: $0) }
    }

    // MARK: What the day served

    func testFinishedTasksAreCountedByWhatTheyServed() {
        let health = note("Health", kind: .area, folder: "Areas", lines: ["goal: Healthy body"], body: """
        - [x] Swim 40 minutes @done(2026-09-30)
        - [x] Stretch @done(2026-09-30)
        """)
        let bath = note("Bathroom renovation", kind: .project, folder: "Projects", lines: ["area: Home"], body: """
        - [x] Order the tiles @done(2026-09-30)
        """)
        let loose = note("Kungsleden", kind: .project, folder: "Projects", lines: [], body: """
        - [x] Book the night train @done(2026-09-30)
        """)
        let index = NoteIndex(notes: [health, bath, loose])
        let counts = index.servedCounts(of: refs(health) + refs(bath) + refs(loose))
        XCTAssertEqual(counts.map(\.title), ["Healthy body", "Home", "Kungsleden"])
        XCTAssertEqual(counts.map(\.count), [2, 1, 1])
        XCTAssertEqual(counts.first?.kind, .goal)
        XCTAssertEqual(counts[1].kind, .area)
        // Serving nothing counts towards the task's own note, never towards "nothing".
        XCTAssertEqual(counts[2].kind, .note(.project))
    }

    func testNothingFinishedCountsNothing() {
        XCTAssertEqual(NoteIndex(notes: []).servedCounts(of: []), [])
    }

    // MARK: First for tomorrow

    func testAMarkIsPerDayAndTogglesOff() {
        let project = note("Car", kind: .project, folder: "Projects", lines: [], body: "- [ ] Pay the car tax\n")
        let ref = refs(project)[0]
        var picks = FirstPicks()
        picks.toggle(ref, on: tomorrow)
        XCTAssertTrue(picks.isFirst(ref, on: tomorrow))
        XCTAssertFalse(picks.isFirst(ref, on: today))
        picks.toggle(ref, on: tomorrow)
        XCTAssertFalse(picks.isFirst(ref, on: tomorrow))
        XCTAssertTrue(picks.byDay.isEmpty, "An emptied day leaves no key behind.")
    }

    /// The mark is by title, so a line that moved overnight is still found.
    func testAMarkSurvivesTheLineMoving() {
        let before = note("Car", kind: .project, folder: "Projects", lines: [], body: "- [ ] Pay the car tax\n")
        var picks = FirstPicks()
        picks.toggle(refs(before)[0], on: tomorrow)
        let after = note("Car", kind: .project, folder: "Projects", lines: [],
                         body: "- [ ] Something new on top\n- [ ] Pay the car tax\n")
        let moved = refs(after)[1]
        XCTAssertNotEqual(refs(before)[0].id, moved.id)
        XCTAssertTrue(picks.isFirst(moved, on: tomorrow))
    }

    func testSplitPutsTheMarkedFirstInTheOrderTheyWereMarked() {
        let project = note("Home", kind: .project, folder: "Projects", lines: [], body: """
        - [ ] A
        - [ ] B
        - [ ] C
        """)
        let all = refs(project)
        var picks = FirstPicks()
        picks.toggle(all[2], on: tomorrow)
        picks.toggle(all[0], on: tomorrow)
        let split = picks.split(all, on: tomorrow)
        XCTAssertEqual(split.first.map(\.task.title), ["C", "A"])
        XCTAssertEqual(split.rest.map(\.task.title), ["B"])
    }

    func testOldDaysAreDropped() {
        let project = note("Home", kind: .project, folder: "Projects", lines: [], body: "- [ ] A\n")
        var picks = FirstPicks()
        picks.toggle(refs(project)[0], on: today)
        picks.toggle(refs(project)[0], on: tomorrow)
        picks.dropDays(before: tomorrow)
        XCTAssertEqual(Array(picks.byDay.keys), [tomorrow.description])
    }

    func testMarksAreKeptInTheVault() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        XCTAssertEqual(vault.firstPicks(), FirstPicks(), "No file yet reads as no marks.")
        let project = note("Home", kind: .project, folder: "Projects", lines: [], body: "- [ ] A\n")
        var picks = FirstPicks()
        picks.toggle(refs(project)[0], on: tomorrow)
        try vault.saveFirstPicks(picks)
        XCTAssertEqual(vault.firstPicks(), picks)
    }
}
