import XCTest
@testable import ParagonCore

/// The Goals screen he chose (build 162) reads the whole chain in one go, so the chain itself
/// is what these tests pin: who is an aspiration, what hangs under one, and — just as much —
/// what must not disappear because it hangs under nothing.
final class AspirationChainTests: XCTestCase {
    var vault: Vault!
    let today = DateOnly(year: 2026, month: 9, day: 13)

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    private func index() throws -> NoteIndex {
        NoteIndex(notes: try vault.allNotes())
    }

    func testAspirationsAreTheGoalsWithNoDate() throws {
        _ = try vault.createNote(kind: .goal, title: "A calm, well-run home",
                                 extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01"),
                                                    ("goal", "A calm, well-run home")])
        let aspirations = try index().aspirations()
        XCTAssertEqual(aspirations.map(\.title), ["A calm, well-run home"])
    }

    func testTheChainReachesFromTheAspirationToTheNextAction() throws {
        _ = try vault.createNote(kind: .goal, title: "A calm, well-run home",
                                 extraFrontmatter: [("horizon", "life"), ("area", "Home")])
        _ = try vault.createNote(kind: .area, title: "Home")
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01"),
                                                    ("goal", "A calm, well-run home")])
        var project = try vault.createNote(kind: .project, title: "Worktops and sink",
                                           extraFrontmatter: [("goal", "Finish the kitchen")])
        // The body is replaced, not added to: the project template already ships one task
        // ("Define the outcome and the first step"), which CI caught me counting.
        project.body = "## Tasks\n\n- [ ] Measure the run\n- [ ] Ring the stone yard #next\n"
        _ = try vault.save(project)

        let chain = try index().chain(of: XCTUnwrap(try index().aspirations().first), today: today)
        XCTAssertEqual(chain.area?.title, "Home")
        XCTAssertEqual(chain.goals.map(\.note.title), ["Finish the kitchen"])
        let goal = try XCTUnwrap(chain.goals.first)
        XCTAssertEqual(goal.projects.map(\.note.title), ["Worktops and sink"])
        // The `#next` task wins over the first open one: that is the whole point of the tag.
        XCTAssertEqual(goal.projects.first?.nextAction?.title, "Ring the stone yard #next")
        XCTAssertEqual(goal.projects.first?.openTaskCount, 2)
        XCTAssertFalse(chain.isBare)
    }

    func testAProjectWithNoOpenTaskSaysSo() throws {
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01")])
        var project = try vault.createNote(kind: .project, title: "Paint the ceiling",
                                           extraFrontmatter: [("goal", "Finish the kitchen")])
        // Emptied on purpose: a project the template just made already has one task.
        project.body = "## Tasks\n"
        _ = try vault.save(project)
        let index = try index()
        let goal = index.chainGoal(of: try XCTUnwrap(index.notes(kind: .goal).first), today: today)
        let project2 = try XCTUnwrap(goal.projects.first)
        XCTAssertNil(project2.nextAction)
        XCTAssertTrue(project2.hasNothingToDo)
        XCTAssertFalse(project2.isFinished)
    }

    func testAnAspirationWithNothingUnderItIsBareRatherThanMissing() throws {
        _ = try vault.createNote(kind: .goal, title: "Write more often",
                                 extraFrontmatter: [("horizon", "life")])
        let index = try index()
        let chain = index.chain(of: try XCTUnwrap(index.aspirations().first), today: today)
        XCTAssertTrue(chain.isBare)
        XCTAssertTrue(chain.flags.contains(.nothingServing))
    }

    /// Build 100's rule in a new place: picking an aspiration must not be a way for a goal to
    /// vanish from the screen.
    func testADatedGoalWithNoAspirationIsStillListed() throws {
        _ = try vault.createNote(kind: .goal, title: "A calm, well-run home",
                                 extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .goal, title: "Sort the photo archive",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-10-31")])
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01"),
                                                    ("goal", "A calm, well-run home")])
        let loose = try index().goalsOutsideAnyAspiration()
        XCTAssertEqual(loose.map(\.title), ["Sort the photo archive"])
    }

    func testGoalsUnderAnAspirationComeInTargetDateOrder() throws {
        _ = try vault.createNote(kind: .goal, title: "A calm, well-run home",
                                 extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .goal, title: "Paperwork under control",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2027-06-30"),
                                                    ("goal", "A calm, well-run home")])
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01"),
                                                    ("goal", "A calm, well-run home")])
        let index = try index()
        let chain = index.chain(of: try XCTUnwrap(index.aspirations().first), today: today)
        XCTAssertEqual(chain.goals.map(\.note.title), ["Finish the kitchen", "Paperwork under control"])
    }

    /// A finished project still belongs to its goal — it is what the goal has already got
    /// done (build 141) — but it is kept apart from the live work.
    func testFinishedProjectsAreKeptApart() throws {
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01")])
        _ = try vault.createNote(kind: .project, title: "Electrics",
                                 extraFrontmatter: [("goal", "Finish the kitchen"), ("status", "done")])
        _ = try vault.createNote(kind: .project, title: "Worktops and sink",
                                 extraFrontmatter: [("goal", "Finish the kitchen")])
        let index = try index()
        let goal = index.chainGoal(of: try XCTUnwrap(index.notes(kind: .goal).first), today: today)
        XCTAssertEqual(goal.projects.map(\.note.title), ["Worktops and sink"])
        XCTAssertEqual(goal.finishedProjects.map(\.note.title), ["Electrics"])
        XCTAssertTrue(goal.finishedProjects.first?.isFinished == true)
    }
}
