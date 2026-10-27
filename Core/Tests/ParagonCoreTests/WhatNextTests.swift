import XCTest
@testable import ParagonCore

/// **What is next for this goal?** (build 271). The rule is pinned in both directions: it
/// must ask when a goal has just been left with nothing working on it, and it must stay quiet
/// whenever something still is. A question that comes too often is ignored; one that never comes
/// is the fault the build is for.
final class WhatNextTests: XCTestCase {
    private let aspirationName = "Be strong and steady at seventy"
    private let goalName = "Walk the Kungsleden in one go"

    private func aspiration(_ title: String? = nil, status: String? = nil) -> Note {
        let name = title ?? aspirationName
        return Note(relativePath: "Goals/\(name).md", kind: .goal,
                    text: "---\ntitle: \(name)\ntype: goal\nhorizon: life\n\(statusLine(status))---\n# \(name)\n")
    }

    private func datedGoal(_ title: String? = nil, under parent: String? = nil, status: String? = nil) -> Note {
        let name = title ?? goalName
        let up = parent.map { "goal: \($0)\n" } ?? ""
        return Note(relativePath: "Goals/\(name).md", kind: .goal,
                    text: "---\ntitle: \(name)\ntype: goal\nhorizon: year\ntarget: 2027-08-15\n\(up)\(statusLine(status))---\n# \(name)\n")
    }

    private func project(_ title: String, goal: String?, status: String? = nil) -> Note {
        let up = goal.map { "goal: \($0)\n" } ?? ""
        return Note(relativePath: "Projects/\(title).md", kind: .project,
                    text: "---\ntitle: \(title)\ntype: project\n\(up)\(statusLine(status))---\n# \(title)\n- [ ] A first step\n")
    }

    private func area(_ title: String, goal: String) -> Note {
        Note(relativePath: "Areas/\(title).md", kind: .area,
             text: "---\ntitle: \(title)\ntype: area\ngoal: \(goal)\n---\n# \(title)\n")
    }

    private func statusLine(_ status: String?) -> String {
        status.map { "status: \($0)\n" } ?? ""
    }

    private func left(after project: Note, among notes: [Note]) -> Note? {
        NoteIndex(notes: notes).goalLeftWithoutWork(after: project)
    }

    // MARK: Asks

    func testTheLastProjectEndingLeavesTheGoalWithNothing() {
        let goal = datedGoal()
        let maps = project("Buy the maps", goal: goalName, status: "done")
        XCTAssertEqual(left(after: maps, among: [goal, maps])?.relativePath, goal.relativePath)
    }

    /// Missed and Dropped end a project just as Done does.
    func testEveryEndingAsks() {
        let goal = datedGoal()
        for status in ["done", "missed", "dropped"] {
            let ended = project("Buy the maps", goal: goalName, status: status)
            XCTAssertEqual(left(after: ended, among: [goal, ended])?.relativePath, goal.relativePath, status)
        }
    }

    /// A project that ended earlier is not "working on" the goal, so it does not keep the
    /// question away when the next one ends.
    func testProjectsThatEndedEarlierDoNotCount() {
        let goal = datedGoal()
        let before = project("Book the huts", goal: goalName, status: "dropped")
        let now = project("Buy the maps", goal: goalName, status: "done")
        XCTAssertEqual(left(after: now, among: [goal, before, now])?.relativePath, goal.relativePath)
    }

    /// An area keeps a standard and does not deliver a goal.
    func testAnAreaDoesNotCountAsWork() {
        let goal = datedGoal()
        let health = area("Health", goal: goalName)
        let maps = project("Buy the maps", goal: goalName, status: "done")
        XCTAssertEqual(left(after: maps, among: [goal, health, maps])?.relativePath, goal.relativePath)
    }

    /// The answer does not depend on the index having caught up with the ending: the project is
    /// left out by its path.
    func testAnIndexOneSaveBehindGivesTheSameAnswer() {
        let goal = datedGoal()
        let stillActive = project("Buy the maps", goal: goalName)
        let ended = project("Buy the maps", goal: goalName, status: "done")
        XCTAssertEqual(left(after: ended, among: [goal, stillActive])?.relativePath, goal.relativePath)
    }

    func testAnAspirationWithNothingElseWorkingOnItAsks() {
        let wish = aspiration()
        let direct = project("Buy the maps", goal: aspirationName, status: "done")
        XCTAssertEqual(left(after: direct, among: [wish, direct])?.relativePath, wish.relativePath)
    }

    // MARK: Stays quiet

    func testAnotherLiveProjectKeepsTheGoalWorking() {
        let goal = datedGoal()
        let maps = project("Buy the maps", goal: goalName, status: "done")
        let huts = project("Book the huts", goal: goalName)
        XCTAssertNil(left(after: maps, among: [goal, maps, huts]))
    }

    /// On hold is not over. The project is still the goal's, and a question would be noise.
    func testAProjectOnHoldKeepsTheGoalWorking() {
        let goal = datedGoal()
        let maps = project("Buy the maps", goal: goalName, status: "done")
        let huts = project("Book the huts", goal: goalName, status: "on-hold")
        XCTAssertNil(left(after: maps, among: [goal, maps, huts]))
    }

    func testAnEndedGoalIsNotAsked() {
        let goal = datedGoal(status: "done")
        let maps = project("Buy the maps", goal: goalName, status: "done")
        XCTAssertNil(left(after: maps, among: [goal, maps]))
    }

    func testAnArchivedGoalIsNotAsked() {
        let goal = datedGoal(status: "archived")
        let maps = project("Buy the maps", goal: goalName, status: "done")
        XCTAssertNil(left(after: maps, among: [goal, maps]))
    }

    func testAGoalThatIsNotThereIsNotAsked() {
        let maps = project("Buy the maps", goal: "A goal nobody wrote", status: "done")
        XCTAssertNil(left(after: maps, among: [maps]))
        let loose = project("Buy the maps", goal: nil, status: "done")
        XCTAssertNil(left(after: loose, among: [loose]))
    }

    /// An aspiration with a live goal with a date under it still has work: the goal carries the
    /// projects. Once that goal ends too, the aspiration is left with nothing.
    func testAnAspirationWithALiveGoalIsNotAsked() {
        let wish = aspiration()
        let walk = datedGoal(under: aspirationName)
        let direct = project("Buy the maps", goal: aspirationName, status: "done")
        XCTAssertNil(left(after: direct, among: [wish, walk, direct]))

        let walked = datedGoal(under: aspirationName, status: "done")
        XCTAssertEqual(left(after: direct, among: [wish, walked, direct])?.relativePath, wish.relativePath)
    }

    func testOnlyAnEndedProjectAsks() {
        let goal = datedGoal()
        let running = project("Buy the maps", goal: goalName)
        XCTAssertNil(left(after: running, among: [goal, running]))
        let held = project("Buy the maps", goal: goalName, status: "on-hold")
        XCTAssertNil(left(after: held, among: [goal, held]))
        let archived = project("Buy the maps", goal: goalName, status: "archived")
        XCTAssertNil(left(after: archived, among: [goal, archived]))
    }

    /// A goal marked done does not start a second question about its aspiration: the question
    /// is about projects.
    func testAGoalEndingDoesNotAsk() {
        let wish = aspiration()
        let walked = datedGoal(under: aspirationName, status: "done")
        XCTAssertNil(left(after: walked, among: [wish, walked]))
    }

    // MARK: The words

    func testTheWordsForAGoalWithADate() {
        let question = WhatNextQuestion(goal: datedGoal(), projectWasDone: true)
        XCTAssertEqual(question.goalPath, "Goals/Walk the Kungsleden in one go.md")
        XCTAssertEqual(question.title, "What is next for this goal?")
        XCTAssertEqual(question.line, "Nothing is working on \u{201C}Walk the Kungsleden in one go\u{201D} now.")
        XCTAssertEqual(question.addTitle, "Add a project\u{2026}")
        XCTAssertTrue(question.offersDone)
        XCTAssertEqual(question.doneMessage, "\u{201C}Walk the Kungsleden in one go\u{201D} is marked done.")
        XCTAssertEqual(WhatNextQuestion.doneTitle, "Mark the goal done")
        XCTAssertEqual(WhatNextQuestion.notNowTitle, "Not now")
    }

    /// **Mark the goal done** only after Done: a project that was missed or dropped says little
    /// about whether the goal was reached.
    func testMarkTheGoalDoneIsOfferedOnlyAfterDone() {
        let goal = datedGoal()
        XCTAssertTrue(WhatNextQuestion(goal: goal, projectWasDone: true).offersDone)
        XCTAssertFalse(WhatNextQuestion(goal: goal, projectWasDone: false).offersDone)
    }

    /// You never finish an aspiration, and nothing is made straight under one.
    func testTheWordsForAnAspiration() {
        let question = WhatNextQuestion(goal: aspiration(), projectWasDone: true)
        XCTAssertTrue(question.isAspiration)
        XCTAssertEqual(question.title, "What is next for this aspiration?")
        XCTAssertEqual(question.addTitle, "Add a goal\u{2026}")
        XCTAssertFalse(question.offersDone)
    }
}
