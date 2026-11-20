import XCTest
@testable import ParagonCore

/// Build 344: the board's columns, what a drop does, and the List's "needs a look first" order.
final class ProjectViewsTests: XCTestCase {
    let today = DateOnly(year: 2026, month: 11, day: 20)

    private func project(_ title: String, status: String? = nil, due: String? = nil,
                         ended: String? = nil, body: String = "") -> Note {
        var lines = ["title: \(title)", "type: project"]
        if let status { lines.append("status: \(status)") }
        if let due { lines.append("due: \(due)") }
        if let ended { lines.append("ended: \(ended)") }
        return Note(relativePath: "Projects/\(title).md", kind: .project,
                    text: "---\n" + lines.joined(separator: "\n") + "\n---\n" + body)
    }

    private var groups: [ProjectGroup] {
        let projects = [
            project("Finished work", body: "- [x] One\n"),
            project("Has a next", due: "2027-03-01", body: "- [ ] Do it\n"),
            project("Late", due: "2026-11-16", body: "- [x] One\n"),
            project("Paused", status: "on-hold", body: "- [ ] Later\n"),
            project("Soon", due: "2026-12-01", body: "- [ ] Now\n"),
            project("Shipped", status: "done", ended: "2026-11-01"),
            project("Gave up", status: "dropped"),
        ]
        return NoteIndex(notes: projects).projectGroups(projects, today: today)
    }

    func testTheBoardPutsEachProjectInOneColumnAndOnlyStatesCanBeDroppedOn() {
        let board = ProjectOverview.board(of: groups)
        XCTAssertEqual(board.map(\.column), [.needsALook, .running, .onHold, .done], "Always all four, empty or not")
        let titles = Dictionary(uniqueKeysWithValues: board.map { ($0.column, $0.lines.map(\.note.title).sorted()) })
        XCTAssertEqual(titles[.needsALook], ["Late"], "Only a late date sends a running project there")
        XCTAssertEqual(titles[.running], ["Finished work", "Has a next", "Soon"])
        XCTAssertEqual(titles[.onHold], ["Paused"])
        XCTAssertEqual(titles[.done], ["Shipped"], "Dropped and missed stay off the board")
        XCTAssertNil(BoardColumn.needsALook.dropStatus, "A drag cannot make a date late")
        XCTAssertEqual(BoardColumn.allCases.compactMap(\.dropStatus), [.active, .onHold, .done])
    }

    func testTheListOpensWithTheProjectsThatNeedALookFirst() {
        let live = ProjectOverview.lines(of: groups, includeEnded: false)
        XCTAssertEqual(Set(live.map(\.note.title)), ["Finished work", "Has a next", "Late", "Paused", "Soon"])
        let order = ProjectOverview.sorted(live, by: .attention).map(\.note.title)
        XCTAssertEqual(order, ["Late", "Finished work", "Soon", "Has a next", "Paused"],
                       "Late date, then no next action, then with a next (soonest deadline first), then on hold")
        let byDeadline = ProjectOverview.sorted(live, by: .deadline, ascending: false).map(\.note.title)
        XCTAssertEqual(Array(byDeadline.prefix(3)), ["Has a next", "Soon", "Late"], "Turned round, latest first")
        XCTAssertEqual(Set(byDeadline.suffix(2)), ["Finished work", "Paused"], "No deadline goes last either way")
        XCTAssertEqual(ProjectsLayout.allCases.map(\.title), ["By goal", "List", "Board", "Cards"])
    }
}
