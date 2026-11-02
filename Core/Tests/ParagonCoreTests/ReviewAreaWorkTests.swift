import XCTest
@testable import ParagonCore

/// Build 276: the weekly review says **No next action** about an area only when nothing is
/// waiting anywhere in its reach. An area's work normally lives in its projects, so judging the
/// area by its own note flagged nearly every area, in orange — a check that is true of most of
/// the notes is not an alarm (build 132). A project is judged as it always was.
final class ReviewAreaWorkTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 9, day: 5)
    private let config = VaultConfig()

    private func area(_ title: String, body: String = "", parent: String? = nil) -> Note {
        var fm = Frontmatter()
        fm.set("title", title)
        fm.set("type", "area")
        if let parent { fm.set("parent", parent) }
        // Looked at yesterday and changed today, so only the flag under test can appear.
        fm.set("reviewed", "2026-09-04")
        return Note(relativePath: "Areas/\(title).md", kind: .area, frontmatter: fm, body: body,
                    modifiedAt: today.date())
    }

    private func project(_ title: String, in areaTitle: String?, body: String,
                         status: String? = nil) -> Note {
        var fm = Frontmatter()
        fm.set("title", title)
        fm.set("type", "project")
        fm.set("goal", "Some goal")
        if let areaTitle { fm.set("area", areaTitle) }
        if let status { fm.set("status", status) }
        fm.set("reviewed", "2026-09-04")
        return Note(relativePath: "Projects/\(title).md", kind: .project, frontmatter: fm, body: body,
                    modifiedAt: today.date())
    }

    private func flags(of note: Note, among notes: [Note]) -> [ProjectHealth.Flag] {
        NoteIndex(notes: notes).health(of: note, today: today, config: config).flags
    }

    // MARK: The fault: the work is in the projects

    func testAnAreaWhoseWorkIsInItsProjectsIsNotFlagged() {
        let health = area("Health")
        let run = project("Run a 10k", in: "Health", body: "- [ ] Buy shoes\n")
        let result = flags(of: health, among: [health, run])
        XCTAssertFalse(result.contains(.noNextAction), "\(result)")
        XCTAssertEqual(result, [])
        // And the screen's own question follows: nothing in orange for this area.
        let report = NoteIndex(notes: [health, run]).review(today: today, config: config)
        XCTAssertEqual(report.areas.map(\.note.title), ["Health"])
        XCTAssertFalse(report.areas[0].needsAttention)
    }

    func testAnAreaWithNothingAnywhereIsFlagged() {
        let health = area("Health")
        XCTAssertEqual(flags(of: health, among: [health]), [.noNextAction])
        // A project in it with every task ticked has nothing to do either.
        let finished = project("Run a 10k", in: "Health", body: "- [x] Buy shoes\n- [x] Run it\n")
        XCTAssertEqual(flags(of: health, among: [health, finished]), [.noNextAction])
        let report = NoteIndex(notes: [health, finished]).review(today: today, config: config)
        XCTAssertTrue(report.areas[0].needsAttention)
    }

    func testAnAreasOwnTasksStillCount() {
        let health = area("Health", body: "- [ ] Renew the gym card\n")
        XCTAssertEqual(flags(of: health, among: [health]), [])
    }

    /// A project on hold is still the area's: its tasks are waiting, not gone.
    func testAnOnHoldProjectStillCounts() {
        let health = area("Health")
        let paused = project("Marathon", in: "Health", body: "- [ ] Book the hotel\n", status: "on-hold")
        XCTAssertFalse(flags(of: health, among: [health, paused]).contains(.noNextAction))
    }

    /// A project that is over is not work: done, missed, dropped and archived all leave the
    /// area with nothing to do, however many open tasks the old note still holds.
    func testAProjectThatIsOverDoesNotCount() {
        let health = area("Health")
        for status in ["done", "missed", "dropped", "archived"] {
            let over = project("Old plan", in: "Health", body: "- [ ] A task nobody will do\n", status: status)
            XCTAssertTrue(flags(of: health, among: [health, over]).contains(.noNextAction),
                          "a \(status) project should not count")
        }
    }

    /// Only the `area:` line puts a project in an area (build 269).
    func testAProjectInAnotherAreaDoesNotCount() {
        let health = area("Health")
        let money = area("Money")
        let budget = project("Make a budget", in: "Money", body: "- [ ] Pull twelve months\n")
        let unplaced = project("Learn Swedish", in: nil, body: "- [ ] Buy a book\n")
        let result = flags(of: health, among: [health, money, budget, unplaced])
        XCTAssertEqual(result, [.noNextAction])
        XCTAssertFalse(flags(of: money, among: [health, money, budget, unplaced]).contains(.noNextAction))
    }

    // MARK: The rule for a next thing is the one every screen uses (build 254)

    func testAnOpenSubtaskUnderATickedTaskIsSomethingToDo() {
        let health = area("Health")
        let work = project("Run a 10k", in: "Health", body: "- [x] Plan the training\n  - [ ] Book the race\n")
        XCTAssertFalse(flags(of: health, among: [health, work]).contains(.noNextAction))
    }

    func testAnOpenSubtaskUnderACancelledTaskIsNot() {
        let health = area("Health")
        let work = project("Run a 10k", in: "Health", body: "- [-] Plan the training\n  - [ ] Book the race\n")
        XCTAssertTrue(flags(of: health, among: [health, work]).contains(.noNextAction))
    }

    // MARK: Sub-areas

    /// A parent area's work is in its sub-areas, which its page lists as rows (build 270). A
    /// sub-area with work of its own is not a reason to flag the parent.
    func testAParentAreaCountsTheWorkInItsSubAreas() {
        let health = area("Health")
        let yoga = area("Yoga", parent: "Health")
        let retreat = project("Yoga retreat", in: "Yoga", body: "- [ ] Book the flights\n")
        let notes = [health, yoga, retreat]
        XCTAssertFalse(flags(of: health, among: notes).contains(.noNextAction))
        XCTAssertFalse(flags(of: yoga, among: notes).contains(.noNextAction))
    }

    /// And a sub-area with nothing is flagged on its own, while its parent is not.
    func testASubAreaWithNothingIsFlaggedOnItsOwn() {
        let health = area("Health")
        let yoga = area("Yoga", parent: "Health")
        let swimming = area("Swimming", parent: "Health")
        let retreat = project("Yoga retreat", in: "Yoga", body: "- [ ] Book the flights\n")
        let notes = [health, yoga, swimming, retreat]
        XCTAssertFalse(flags(of: health, among: notes).contains(.noNextAction))
        XCTAssertTrue(flags(of: swimming, among: notes).contains(.noNextAction))
    }

    /// A parent with nothing anywhere in the family is flagged.
    func testAParentWithNothingInTheWholeFamilyIsFlagged() {
        let health = area("Health")
        let yoga = area("Yoga", parent: "Health")
        XCTAssertTrue(flags(of: health, among: [health, yoga]).contains(.noNextAction))
    }

    // MARK: A project is judged as it always was

    func testAProjectKeepsItsOwnRule() {
        let health = area("Health")
        let busy = project("Run a 10k", in: "Health", body: "- [ ] Buy shoes\n")
        let finished = project("Stretch daily", in: "Health", body: "- [x] Learn the routine\n")
        let notes = [health, busy, finished]
        // Another project in the same area having work does not rescue this one.
        XCTAssertEqual(flags(of: finished, among: notes), [.noNextAction])
        XCTAssertEqual(flags(of: busy, among: notes), [])
    }

    /// On hold is still a decision already made, and nothing else is asked of the area.
    func testAnAreaOnHoldIsStillNotJudged() {
        var fm = Frontmatter()
        fm.set("title", "Garden")
        fm.set("type", "area")
        fm.set("status", "on-hold")
        let garden = Note(relativePath: "Areas/Garden.md", kind: .area, frontmatter: fm, body: "",
                          modifiedAt: today.date())
        XCTAssertEqual(flags(of: garden, among: [garden]), [.onHold])
    }
}
