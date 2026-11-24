import XCTest
@testable import ParagonCore

/// Build 368: the link between a PARAGON project and a Steward event. One small test per rule.
final class StewardLinkTests: XCTestCase {
    private func project(_ title: String, status: String? = nil, event: String? = nil, due: String? = nil, asked: Bool = false) -> Note {
        var lines = ["title: \(title)", "type: project"]
        if let status { lines.append("status: \(status)") }
        if let event { lines.append("steward-event: \(event)") }
        if let due { lines.append("due: \(due)") }
        if asked { lines.append("steward-asked: done") }
        return Note(relativePath: "Projects/\(title).md", kind: .project,
                    text: "---\n" + lines.joined(separator: "\n") + "\n---\n# \(title)\n\n## Tasks\n")
    }
    private func edited(_ o: StewardLink.Outcome) -> [Note] { if case .edit(let n) = o { return n }; return [] }

    // The contract, copied from Steward.
    func testContractRules() {
        XCTAssertTrue(EventBridge.namesFit("Lisbon Marathon", "Lisbon Marathon 2027"))
        XCTAssertFalse(EventBridge.namesFit("Run", "Run fast"))
        XCTAssertEqual(EventBridge.kronor(980_000), "9\u{00A0}800\u{00A0}kr")
        let p = EventBridge.Project(path: "Projects/Lisbon Marathon.md", title: "Lisbon Marathon", due: "2027-03-12")
        XCTAssertEqual(EventBridge.suggestion(name: "Lisbon Marathon 2027", from: "2027-03-12", to: "2027-03-14", among: [p])?.path, p.path)
        let e = EventBridge.Event(id: "a", name: "A", type: "race", from: "2026-12-01", to: "2026-12-02")
        XCTAssertEqual(EventBridge.ahead([e], today: "2026-11-24").count, 1)
        XCTAssertTrue(EventBridge.ahead([e], today: "2026-09-01").isEmpty)
    }

    func testListHoldsLiveAndLinkedProjects() {
        let list = StewardLink.projectList(from: [
            project("A live"), project("On hold", status: "on-hold"), project("Done plain", status: "done"),
            project("Done linked", status: "done", event: "e1", due: "2027-01-02")])
        XCTAssertEqual(list.map(\.title), ["A live", "Done linked", "On hold"])
        XCTAssertEqual(list[1].due, "2027-01-02"); XCTAssertEqual(list[1].event, "e1"); XCTAssertEqual(list[1].status, "done")
    }

    func testMakeProjectLinksAnExactTitleOrMakesOne() {
        let m = EventBridge.Message(.makeProject, event: "e1", title: "Lisbon Marathon", day: "2027-03-12")
        XCTAssertEqual(edited(StewardLink.apply(m, to: [project("lisbon marathon")])).first?.stewardEvent, "e1")
        XCTAssertEqual(StewardLink.apply(m, to: []), .make(title: "Lisbon Marathon", due: "2027-03-12", event: "e1"))
        XCTAssertEqual(StewardLink.apply(m, to: [project("Other", event: "e1")]), .discard)
    }

    func testLinkTakesTheEventOffAnyOtherProject() {
        let m = EventBridge.Message(.link, event: "e1", path: "Projects/New.md")
        let out = edited(StewardLink.apply(m, to: [project("Old", event: "e1"), project("New")]))
        XCTAssertEqual(Set(out.map(\.relativePath)), ["Projects/Old.md", "Projects/New.md"])
        XCTAssertNil(out.first { $0.title == "Old" }?.stewardEvent)
        XCTAssertEqual(out.first { $0.title == "New" }?.stewardEvent, "e1")
    }

    func testUnlinkAndMissingProjectAreQuiet() {
        let un = EventBridge.Message(.unlink, event: "e1")
        XCTAssertNil(edited(StewardLink.apply(un, to: [project("A", event: "e1")])).first?.stewardEvent)
        XCTAssertEqual(StewardLink.apply(EventBridge.Message(.setDue, event: "zz", day: "2027-01-01"), to: [project("A")]), .discard)
        XCTAssertEqual(StewardLink.apply(EventBridge.Message(.addTask, event: "zz", title: "x"), to: [project("A")]), .discard)
    }

    func testSetDueAndAddTask() {
        let notes = [project("A", event: "e1", due: "2027-01-01")]
        XCTAssertEqual(edited(StewardLink.apply(EventBridge.Message(.setDue, event: "e1", day: "2027-02-02"), to: notes)).first?.dueDate?.description, "2027-02-02")
        let added = edited(StewardLink.apply(EventBridge.Message(.addTask, event: "e1", title: "Talk about it: Shop, 2026-11-12"), to: notes))
        XCTAssertTrue(added.first?.body.contains("- [ ] Talk about it: Shop, 2026-11-12") == true)
    }

    func testUnknownKindIsLeft() {
        var m = EventBridge.Message(.unlink, event: "e1"); m.kind = "somethingNew"
        XCTAssertEqual(StewardLink.apply(m, to: []), .leave)
    }

    func testDoneQuestionOnlyForLiveLinkedFinishedNotAsked() {
        let fin = EventBridge.Event(id: "e1", name: "Lisbon", type: "race", from: "2027-03-12", to: "2027-03-14", finished: "2027-03-14")
        XCTAssertEqual(StewardLink.doneQuestion(notes: [project("A", event: "e1")], events: [fin])?.note.title, "A")
        XCTAssertNil(StewardLink.doneQuestion(notes: [project("A", event: "e1", asked: true)], events: [fin]))
        XCTAssertNil(StewardLink.doneQuestion(notes: [project("A", status: "done", event: "e1")], events: [fin]))
        XCTAssertNil(StewardLink.doneQuestion(notes: [project("A")], events: [fin]))
    }

    func testMoveQuestionOnlyWhenTheDayDiffers() {
        let ev = EventBridge.Event(id: "e1", name: "L", type: "race", from: "2027-03-12", to: "2027-03-14")
        let p = project("A", event: "e1")
        XCTAssertNotNil(StewardLink.shouldAskToMoveEvent(project: p, newDue: DateOnly("2027-03-20"), events: [ev]))
        XCTAssertNil(StewardLink.shouldAskToMoveEvent(project: p, newDue: DateOnly("2027-03-12"), events: [ev]))
        XCTAssertNil(StewardLink.shouldAskToMoveEvent(project: project("B"), newDue: DateOnly("2027-03-20"), events: [ev]))
    }

    func testWhenWords() {
        let e = EventBridge.Event(id: "e", name: "L", type: "race", from: "2026-12-19", to: "2026-12-21")
        XCTAssertEqual(StewardLink.whenWords(e, today: "2026-11-24"), "Starts in 25 days")
        XCTAssertEqual(StewardLink.whenWords(e, today: "2026-12-18"), "Starts tomorrow")
        XCTAssertEqual(StewardLink.whenWords(e, today: "2026-12-20"), "On now, until 2026-12-21")
    }

    func testStewardLinks() {
        XCTAssertEqual(StewardLink.stewardURL(for: project("A", event: "e1"))?.absoluteString, "amsfinancialsteward://event/e1")
        XCTAssertTrue(StewardLink.stewardURL(for: project("A b", due: "2027-03-12"))?.absoluteString.hasPrefix("amsfinancialsteward://new-event?project=") == true)
    }
}
