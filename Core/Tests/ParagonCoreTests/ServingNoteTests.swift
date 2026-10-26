import XCTest
@testable import ParagonCore

/// **Add a project…** on a goal and **Add a goal…** on an aspiration (build 269). What these
/// pin is that the line the button writes is the line the chain reads: a project made this way
/// is among its goal's projects, and a goal made this way is in its aspiration's chain, as a
/// goal with a date.
final class ServingNoteTests: XCTestCase {
    var vault: Vault!
    let today = DateOnly(year: 2026, month: 10, day: 26)

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    private func index() throws -> NoteIndex {
        NoteIndex(notes: try vault.allNotes())
    }

    private func make(_ title: String, under parent: Note, link: ServingLink = .goal) throws -> Note {
        let plan = ServingNote(under: parent, link: link)
        return try vault.createNote(kind: plan.kind, title: title, extraFrontmatter: plan.frontmatter)
    }

    func testAProjectMadeFromAGoalIsAmongItsProjects() throws {
        _ = try vault.createNote(kind: .goal, title: "Be strong and steady at seventy",
                                 extraFrontmatter: [("horizon", "life")])
        let goal = try vault.createNote(kind: .goal, title: "Walk the Kungsleden in one go",
                                        extraFrontmatter: [("horizon", "year"), ("target", "2027-08-15"),
                                                           ("goal", "Be strong and steady at seventy")])
        let plan = ServingNote(under: goal, link: .goal)
        XCTAssertEqual(plan.kind, .project)
        XCTAssertFalse(plan.makesAGoal)
        XCTAssertEqual(plan.lines, [ServingNote.Line(key: "goal", value: "Walk the Kungsleden in one go")])

        let made = try make("Buy the maps", under: goal)
        XCTAssertEqual(made.kind, .project)
        let index = try index()
        let chain = index.chainGoal(of: try XCTUnwrap(index.note(path: goal.relativePath)), today: today)
        XCTAssertEqual(chain.projects.map(\.note.relativePath), [made.relativePath])
    }

    func testAGoalMadeFromAnAspirationIsAGoalWithADateInItsChain() throws {
        let aspiration = try vault.createNote(kind: .goal, title: "Be strong and steady at seventy",
                                              extraFrontmatter: [("horizon", "life")])
        let plan = ServingNote(under: aspiration, link: .goal)
        XCTAssertEqual(plan.kind, .goal)
        XCTAssertTrue(plan.makesAGoal)
        XCTAssertEqual(plan.lines, [ServingNote.Line(key: "horizon", value: "year"),
                                    ServingNote.Line(key: "goal", value: "Be strong and steady at seventy")])

        let made = try make("Swim a kilometre", under: aspiration)
        let index = try index()
        let fresh = try XCTUnwrap(index.note(path: made.relativePath))
        XCTAssertEqual(fresh.horizon, .year)
        // No date yet: the goal's own Set a target date… is where it gets one (build 268).
        XCTAssertNil(fresh.targetDate)
        XCTAssertEqual(index.datedGoals().map(\.relativePath), [made.relativePath])
        XCTAssertTrue(index.goalsOutsideAnyAspiration().isEmpty)
        let chain = index.chain(of: try XCTUnwrap(index.aspirations().first), today: today)
        XCTAssertEqual(chain.goals.map(\.note.relativePath), [made.relativePath])
        XCTAssertFalse(chain.isBare)
    }

    /// A title the settings block has to put in quotes still links: `: ` and `, ` both need
    /// them, and a quoted line is read back without them.
    func testATitleThatNeedsQuotesStillLinks() throws {
        let goal = try vault.createNote(kind: .goal, title: "Run: 440 km, in 30 days",
                                        extraFrontmatter: [("horizon", "year")])
        let made = try make("Buy new shoes", under: goal)
        let index = try index()
        let chain = index.chainGoal(of: try XCTUnwrap(index.note(path: goal.relativePath)), today: today)
        XCTAssertEqual(chain.projects.map(\.note.relativePath), [made.relativePath])
    }

    /// The same button on an area (the area page, a later build) writes `area:` and makes a project.
    func testAProjectMadeFromAnAreaIsKeptInThatArea() throws {
        let area = try vault.createNote(kind: .area, title: "Health")
        let plan = ServingNote(under: area, link: .area)
        XCTAssertEqual(plan.kind, .project)
        XCTAssertEqual(plan.lines, [ServingNote.Line(key: "area", value: "Health")])
        let made = try make("Book a check-up", under: area, link: .area)
        let fresh = try XCTUnwrap(try index().note(path: made.relativePath))
        XCTAssertEqual(fresh.area, "Health")
        XCTAssertNil(fresh.goal)
    }

    func testANameAlreadyInUseIsFoundBeforeAnythingIsWritten() throws {
        let goal = try vault.createNote(kind: .goal, title: "Walk the Kungsleden in one go",
                                        extraFrontmatter: [("horizon", "year")])
        _ = try make("Buy the maps", under: goal)
        let notes = try vault.allNotes()
        // Capitals and spaces at the ends do not make it a different name.
        XCTAssertEqual(ServingNote.existing(named: "  buy the MAPS ", kind: .project, among: notes)?.title,
                       "Buy the maps")
        // A name that becomes the same file name is the same name too.
        XCTAssertNotNil(ServingNote.existing(named: "Buy the maps.", kind: .project, among: notes))
        // Another kind of note may carry the same name.
        XCTAssertNil(ServingNote.existing(named: "Buy the maps", kind: .goal, among: notes))
        XCTAssertNil(ServingNote.existing(named: "Pack the bag", kind: .project, among: notes))
        XCTAssertNil(ServingNote.existing(named: "   ", kind: .project, among: notes))
    }
}
