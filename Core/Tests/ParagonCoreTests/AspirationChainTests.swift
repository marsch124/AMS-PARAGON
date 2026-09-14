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

    // MARK: The five small extras (build 163)

    func testTimeLeftIsSaidInPlainWords() {
        let today = DateOnly(year: 2026, month: 9, day: 14)
        XCTAssertEqual(DateOnly(year: 2026, month: 9, day: 14).timeLeftText(from: today), "today")
        XCTAssertEqual(DateOnly(year: 2026, month: 9, day: 15).timeLeftText(from: today), "tomorrow")
        XCTAssertEqual(DateOnly(year: 2026, month: 9, day: 25).timeLeftText(from: today), "in 11 days")
        XCTAssertEqual(DateOnly(year: 2026, month: 12, day: 14).timeLeftText(from: today), "in about 3 months")
        XCTAssertEqual(DateOnly(year: 2031, month: 9, day: 14).timeLeftText(from: today), "in about 5 years")
        // Past the date it says how far past, which is the half that matters.
        XCTAssertEqual(DateOnly(year: 2026, month: 9, day: 13).timeLeftText(from: today), "1 day over")
        XCTAssertEqual(DateOnly(year: 2026, month: 9, day: 3).timeLeftText(from: today), "11 days over")
    }

    func testActivitySaysNothingWhenThereIsNothingToSay() {
        let quiet = ChainActivity(tasksFinished: 0, daysSinceActivity: nil,
                                  projectsFinished: 0, projectsTotal: 0)
        XCTAssertNil(quiet.summary)
        let busy = ChainActivity(tasksFinished: 12, daysSinceActivity: 3,
                                 projectsFinished: 1, projectsTotal: 4)
        XCTAssertEqual(busy.summary,
                       "12 tasks finished in 30 days \u{00B7} 1 of 4 projects finished \u{00B7} last activity 3 days ago")
        let today = ChainActivity(tasksFinished: 1, daysSinceActivity: 0,
                                  projectsFinished: 0, projectsTotal: 2)
        XCTAssertEqual(today.summary, "1 task finished in 30 days \u{00B7} something moved today")
    }

    func testAReachedGoalLeavesTheLiveChainAndGathersAtTheFoot() throws {
        _ = try vault.createNote(kind: .goal, title: "A calm, well-run home",
                                 extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01"),
                                                    ("goal", "A calm, well-run home"), ("status", "achieved")])
        _ = try vault.createNote(kind: .goal, title: "Paperwork under control",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2027-06-30"),
                                                    ("goal", "A calm, well-run home")])
        let index = try index()
        let chain = index.chain(of: try XCTUnwrap(index.aspirations().first), today: today)
        XCTAssertEqual(chain.goals.map(\.note.title), ["Paperwork under control"])
        XCTAssertEqual(chain.endedGoals.map(\.note.title), ["Finish the kitchen"])
        // And it is not lost: the whole-vault list has it, and the live lists do not.
        XCTAssertEqual(index.endedGoals().map(\.status), [.done])
        XCTAssertEqual(index.endedGoals().first?.notes.map(\.title), ["Finish the kitchen"])
        XCTAssertFalse(index.goalsOutsideAnyAspiration().contains { $0.title == "Finish the kitchen" })
        XCTAssertFalse(chain.isBare)
    }

    func testAReachedAspirationLeavesTheLiveListToo() throws {
        _ = try vault.createNote(kind: .goal, title: "Learn to sail",
                                 extraFrontmatter: [("horizon", "life"), ("status", "achieved")])
        let index = try index()
        XCTAssertTrue(index.aspirations().isEmpty)
        XCTAssertEqual(index.endedGoals().first?.notes.map(\.title), ["Learn to sail"])
    }

    // MARK: Done, missed, dropped (build 165)

    func testTheThreeEndingsAreToldApartAndGroupedByName() throws {
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01"), ("status", "done")])
        _ = try vault.createNote(kind: .goal, title: "Run a half marathon",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-05-01"), ("status", "missed")])
        _ = try vault.createNote(kind: .goal, title: "Learn the tuba",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-06-01"), ("status", "dropped")])
        _ = try vault.createNote(kind: .goal, title: "Sort the photo archive",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-10-31")])
        let index = try index()
        // Only the live one is still work.
        XCTAssertEqual(index.goalsOutsideAnyAspiration().map(\.title), ["Sort the photo archive"])
        // One group per ending, in the order the menu offers them, each named for its ending.
        let groups = index.endedGoals()
        XCTAssertEqual(groups.map(\.status), [.done, .missed, .dropped])
        XCTAssertEqual(groups.map { $0.notes.map(\.title) },
                       [["Finish the kitchen"], ["Run a half marathon"], ["Learn the tuba"]])
    }

    /// The point of the build: only **done** delivered. A goal marked missed or dropped is
    /// over, and the roll-up must neither count it as a whole project nor hold the goal at
    /// zero for ever.
    func testMissedAndDroppedProjectsAreLeftOutOfTheRollUp() throws {
        _ = try vault.createNote(kind: .goal, title: "Finish the kitchen",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2026-12-01")])
        for (title, status) in [("Electrics", "done"), ("Underfloor heating", "dropped"), ("Skylight", "missed")] {
            _ = try vault.createNote(kind: .project, title: title,
                                     extraFrontmatter: [("goal", "Finish the kitchen"), ("status", status)])
        }
        let index = try index()
        let goal = index.chainGoal(of: try XCTUnwrap(index.notes(kind: .goal).first), today: today)
        // None of the three is live work any more — and all three are still visible under the
        // goal, so a project you dropped does not vanish (build 100's rule).
        XCTAssertTrue(goal.projects.isEmpty)
        XCTAssertEqual(Set(goal.finishedProjects.map(\.note.title)),
                       ["Electrics", "Underfloor heating", "Skylight"])
        // But only the one that delivered is counted. One of one, so the goal reads as full.
        XCTAssertEqual(goal.progress.projectsTotal, 1)
        XCTAssertEqual(goal.progress.projectsDone, 1)
        XCTAssertEqual(goal.progress.fraction, 1)
        // And the line beside the bar says the same thing, never "1 of 3".
        XCTAssertEqual(goal.activity.projectsFinished, 1)
        XCTAssertEqual(goal.activity.projectsTotal, 1)
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
