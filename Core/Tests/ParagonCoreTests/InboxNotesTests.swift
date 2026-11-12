import XCTest
@testable import ParagonCore

final class InboxNotesTests: XCTestCase {
    func testCapturedNotesAreListedMadeTasksAndDeleted() {
        let text = "# Inbox\n\n- [ ] Call Anna\n\n## Notes\n- Idea for the boat\n- [ ] Not a note\n* Second idea\n\n## Later\n- Not in Notes\n"
        let notes = InboxNotes.lines(in: text)
        XCTAssertEqual(notes, [InboxNotes.Line(index: 5, text: "Idea for the boat"), InboxNotes.Line(index: 7, text: "Second idea")])
        XCTAssertEqual(InboxNotes.makingTask(text, line: notes[0]),
                       text.replacingOccurrences(of: "- Idea for the boat", with: "- [ ] Idea for the boat"))
        XCTAssertEqual(InboxNotes.removing(text, line: notes[1]), text.replacingOccurrences(of: "* Second idea\n", with: ""))
        // A line that moved is left alone.
        XCTAssertEqual(InboxNotes.removing(text, line: InboxNotes.Line(index: 6, text: "Idea for the boat")), text)
        XCTAssertEqual(InboxNotes.lines(in: "# Inbox\n- plain\n"), [])
    }
}
