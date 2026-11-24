import XCTest
@testable import ParagonCore

/// Build 367: the Inbox shows the newest line first, and the picked line whole.
final class InboxOrderTests: XCTestCase {
    func testTheLineCapturedLastComesFirst() {
        // A capture is written at the end, so the last line of the file is the newest.
        var note = Note(relativePath: "Inbox.md", kind: .inbox,
                        text: "# Inbox\n\n## Tasks\n- [ ] First thing\n- [ ] Second thing\n- [x] Done thing\n- [ ] Third thing\n")
        XCTAssertEqual(InboxOrder.newestFirst(note.awaitingTasks()).map(\.title),
                       ["Third thing", "Second thing", "First thing"])
        // The file keeps its own order: only the list on screen is turned round.
        XCTAssertEqual(note.awaitingTasks().map(\.title), ["First thing", "Second thing", "Third thing"])
        // A new capture lands at the end of the file and so at the top of the list.
        note.appendTaskBlock(["- [ ] Newest thing"])
        XCTAssertEqual(InboxOrder.newestFirst(note.awaitingTasks()).first?.title, "Newest thing")
    }

    func testTheNotesPartIsTurnedRoundTheSameWay() {
        let text = "# Inbox\n\n- [ ] Call Anna\n\n## Notes\n- Idea for the boat\n- Second idea\n"
        XCTAssertEqual(InboxOrder.newestFirst(InboxNotes.lines(in: text)).map(\.text),
                       ["Second idea", "Idea for the boat"])
        XCTAssertEqual(InboxOrder.newestFirst([Int]()), [])
        XCTAssertEqual(InboxOrder.newestFirst([7]), [7])
    }

    func testAPickedLineShowsAllItsWords() {
        XCTAssertEqual(InboxOrder.titleLines(picked: false), 2)
        XCTAssertNil(InboxOrder.titleLines(picked: true))
    }
}
