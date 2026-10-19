import XCTest
@testable import ParagonCore

/// The grouped Projects list (build 253). What these pin is what he reads: which group a project
/// lands in, what its box says it needs, and that dragging inside one group leaves every other
/// project exactly where it was.
final class ProjectGroupsTests: XCTestCase {
    let today = DateOnly(year: 2026, month: 10, day: 19)

    private func goal(_ title: String, life: Bool = false, serves: String? = nil,
                      target: String? = nil, status: String? = nil) -> Note {
        var lines = ["title: \(title)", "type: goal", "horizon: \(life ? "life" : "year")"]
        if let serves { lines.append("goal: \(serves)") }
        if let target { lines.append("target: \(target)") }
        if let status { lines.append("status: \(status)") }
        return Note(relativePath: "Goals/\(title).md", kind: .goal,
                    text: "---\n" + lines.joined(separator: "\n") + "\n---\n")
    }

    private func project(_ title: String, goal: String? = nil, status: String? = nil,
                         due: String? = nil, body: String = "") -> Note {
        var lines = ["title: \(title)", "type: project"]
        if let goal { lines.append("goal: \(goal)") }
        if let status { lines.append("status: \(status)") }
        if let due { lines.append("due: \(due)") }
        return Note(relativePath: "Projects/\(title).md", kind: .project,
                    text: "---\n" + lines.joined(separator: "\n") + "\n---\n" + body)
    }

    func testEachProjectLandsUnderWhatItWorksTowards() {
        let living = goal("Keep living a healthy, active life", life: true)
        let making = goal("Keep learning and making things", life: true)
        let train = goal("Train for and do IM 70.3", serves: living.title, target: "2027-09-01")
        let print = goal("3D print useful things", serves: making.title, target: "2027-01-01")
        let connected = goal("Connected home", target: "2027-03-01")
        let projects = [
            project("Perform IM Jönköping 2027", goal: train.title),
            project("AMS Apnea app", goal: living.title),
            project("3D Fjölhållare till Granden", goal: print.title),
            project("ColdShower app", goal: connected.title),
            project("Lost link", goal: "A goal nobody wrote"),
            project("Fix Anna's light on Falcon"),
            project("Print a keyboard", goal: print.title, status: "done"),
            project("Old idea", status: "dropped"),
            project("Late race", status: "missed"),
        ]
        let index = NoteIndex(notes: [living, making, train, print, connected] + projects)
        let groups = index.projectGroups(projects, today: today)

        XCTAssertEqual(groups.map(\.title), [
            "Keep learning and making things",
            "Keep living a healthy, active life",
            "Not linked to an aspiration",
            "Projects with no goal",
            "Done", "Missed", "Dropped",
        ], "Aspirations in the Aspirations room's order (by title), then the two loose groups, then one group per ending")
        XCTAssertEqual(groups[1].lines.map(\.note.title), ["Perform IM Jönköping 2027", "AMS Apnea app"],
                       "Through a goal with a date, or straight at the aspiration: both land under it, in the order given")
        XCTAssertEqual(groups[0].lines.map(\.note.title), ["3D Fjölhållare till Granden"])
        XCTAssertEqual(groups[2].lines.map(\.note.title), ["ColdShower app", "Lost link"])
        XCTAssertFalse(groups[2].lines[0].goalIsMissing, "Connected home exists; it just has no aspiration")
        XCTAssertTrue(groups[2].lines[1].goalIsMissing, "A goal: line that names nothing is drawn as not connected")
        XCTAssertEqual(groups[3].lines.map(\.note.title), ["Fix Anna's light on Falcon"])
        XCTAssertEqual(groups[4].lines.map(\.note.title), ["Print a keyboard"])
        XCTAssertTrue(groups[4].isEnded)
        XCTAssertEqual(Set(groups.flatMap(\.lines).map(\.id)).count, projects.count,
                       "Every project is in exactly one group, so no list can draw it twice")
    }

    func testAnEndedAspirationStillHoldsItsLiveProjects() {
        let old = goal("Sail around Gotland", life: true, status: "done")
        let current = goal("A calm home", life: true)
        let projects = [project("Sell the boat", goal: old.title), project("Paint the hall", goal: current.title)]
        let groups = NoteIndex(notes: [old, current] + projects).projectGroups(projects, today: today)
        XCTAssertEqual(groups.map(\.title), ["A calm home", "Sail around Gotland"],
                       "Live aspirations first; an ended one still shows the work under it rather than hiding it")
    }

    func testEmptyGroupsAreLeftOut() {
        let projects = [project("Fix the gate")]
        let groups = NoteIndex(notes: projects).projectGroups(projects, today: today)
        XCTAssertEqual(groups.map(\.title), ["Projects with no goal"])
        XCTAssertTrue(NoteIndex(notes: []).projectGroups([], today: today).isEmpty)
    }

    func testTheBoxSaysWhatTheProjectNeeds() {
        let tagged = project("Paint the boat house",
                             body: "- [x] Choose the colour\n- [ ] Sand the walls\n- [ ] Buy the paint #next\n- [ ] Paint\n")
        let firstOpen = project("Tax return", body: "- [x] Find the papers\n- [ ] Send the papers\n")
        let finished = project("AMS Packing app", body: "- [x] One\n- [x] Two\n- [-] Dropped idea\n")
        let empty = project("Summer house roof")
        let cancelledOnly = project("Never mind", body: "- [-] Called off\n")
        let index = NoteIndex(notes: [tagged, firstOpen, finished, empty, cancelledOnly])

        let lines = index.projectGroups([tagged, firstOpen, finished, empty, cancelledOnly], today: today)
            .flatMap(\.lines)
        func line(_ title: String) -> ProjectLine { lines.first { $0.note.title == title }! }

        guard case .next(let next) = line("Paint the boat house").need else { return XCTFail("open tasks mean a next task") }
        XCTAssertTrue(next.title.hasPrefix("Buy the paint"), "#next wins over the first open task, as everywhere else")
        XCTAssertEqual(line("Paint the boat house").nextTitle, "Buy the paint",
                       "The box shows the task because of #next, so the tag itself is left out")
        XCTAssertEqual(line("Paint the boat house").done, 1)
        XCTAssertEqual(line("Paint the boat house").total, 4)
        XCTAssertEqual(line("Paint the boat house").openCount, 3)

        guard case .next(let first) = line("Tax return").need else { return XCTFail() }
        XCTAssertEqual(first.title, "Send the papers")

        XCTAssertEqual(line("AMS Packing app").need, .allFinished(count: 2),
                       "Every task finished, a cancelled one left out of the count")
        XCTAssertEqual(line("Summer house roof").need, .noTasks)
        XCTAssertEqual(line("Never mind").need, .noTasks, "Nothing left but a cancelled task is no tasks, never 0 of 0")
    }

    /// Build 254, from the review of 253: a ticked task with an open subtask under it is not
    /// "all finished". The box names the subtask, and its overdue count agrees with it.
    func testAnOpenSubtaskIsStillTheNextThing() {
        let roof = project("Fix the roof", body: "- [x] Order the tiles\n    - [ ] Pay the invoice >2026-10-10\n")
        let lines = NoteIndex(notes: [roof]).projectGroups([roof], today: today).flatMap(\.lines)
        guard case .next(let next) = lines.first?.need else {
            return XCTFail("An open subtask must be the next thing, not 'all finished'")
        }
        XCTAssertTrue(next.title.hasPrefix("Pay the invoice"))
        XCTAssertEqual(lines.first?.overdueCount, 1)
        XCTAssertEqual(lines.first?.done, 1, "The counts stay top-level, as Note.progress has them")
        XCTAssertEqual(lines.first?.total, 1)
    }

    func testOnlyLateThingsAskForALook() {
        let dated = goal("Walk the Kungsleden", target: "2027-08-15")
        let overdue = project("Overdue task", goal: dated.title, body: "- [ ] Call the bank >2026-10-10\n")
        let pastDeadline = project("Past deadline", goal: dated.title, due: "2026-10-01", body: "- [ ] Next\n")
        let afterGoal = project("After the goal", goal: dated.title, due: "2027-12-01", body: "- [ ] Next\n")
        let idle = project("All finished", goal: dated.title, body: "- [x] Done\n")
        let paused = project("Paused", goal: dated.title, status: "on-hold", due: "2026-01-01")
        let index = NoteIndex(notes: [dated, overdue, pastDeadline, afterGoal, idle, paused])
        let lines = index.projectGroups([overdue, pastDeadline, afterGoal, idle, paused], today: today)
            .flatMap(\.lines)
        func line(_ title: String) -> ProjectLine { lines.first { $0.note.title == title }! }

        XCTAssertEqual(line("Overdue task").overdueCount, 1)
        XCTAssertTrue(line("Overdue task").needsALook)
        XCTAssertTrue(line("Past deadline").deadlinePassed)
        XCTAssertTrue(line("Past deadline").needsALook)
        XCTAssertTrue(line("After the goal").dueAfterGoal)
        XCTAssertTrue(line("After the goal").needsALook)
        XCTAssertFalse(line("All finished").needsALook,
                       "No next action is calm: it is true of most projects, and orange for it would be a telling-off")
        XCTAssertFalse(line("Paused").needsALook, "On hold is a decision already made")
        XCTAssertEqual(index.projectGroups([overdue, pastDeadline, idle], today: today).first?.needsALookCount, 2)
    }

    func testTheWordsOnTheBox() {
        XCTAssertEqual(ProjectLine.finishedText(count: 1), "Its one task is finished")
        XCTAssertEqual(ProjectLine.finishedText(count: 15), "All 15 finished")
        XCTAssertEqual(ProjectLine.progressText(done: 5, total: 8), "5 of 8 finished")
        XCTAssertEqual(ProjectLine.overdueText(2), "2 overdue")
        XCTAssertEqual(ProjectLine.deadlineText(today, today: today), "Deadline today")
        XCTAssertEqual(ProjectLine.deadlineText(today.adding(days: 1), today: today), "Deadline tomorrow")
        XCTAssertEqual(ProjectLine.deadlineText(today.adding(days: 11), today: today), "Deadline in 11 days")
        XCTAssertEqual(ProjectLine.deadlineText(today.adding(days: -12), today: today), "Deadline 12 days over")
        XCTAssertEqual(ProjectGroup.notLinkedTitle, "Not linked to an aspiration")
        XCTAssertEqual(ProjectGroup.noGoalTitle, "Projects with no goal", "The review's own words (build 140)")
    }

    func testMovedMeansWhatSwiftUIsMoveMeans() {
        let notes = ["a", "b", "c", "d"].map { project($0) }
        func titles(_ list: [Note]) -> [String] { list.map(\.title) }
        XCTAssertEqual(titles(ProjectOrder.moved(notes, from: IndexSet(integer: 0), to: 3)), ["b", "c", "a", "d"])
        XCTAssertEqual(titles(ProjectOrder.moved(notes, from: IndexSet(integer: 3), to: 0)), ["d", "a", "b", "c"])
        XCTAssertEqual(titles(ProjectOrder.moved(notes, from: IndexSet(integer: 1), to: 4)), ["a", "c", "d", "b"])
        XCTAssertEqual(titles(ProjectOrder.moved(notes, from: IndexSet(integer: 2), to: 2)), ["a", "b", "c", "d"])
        XCTAssertEqual(titles(ProjectOrder.moved(notes, from: IndexSet(), to: 0)), ["a", "b", "c", "d"])
    }

    func testADragInsideAGroupLeavesEveryOtherProjectInItsPlace() {
        let whole = ["a", "b", "c", "d", "e"].map { project($0) }
        let group = [whole[1], whole[3], whole[4]]           // b, d, e
        let arranged = ProjectOrder.moving(group, within: whole, from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(arranged.map(\.title), ["a", "d", "c", "b", "e"],
                       "d moves above b; a and c, in other groups, keep their slots")
    }
}
