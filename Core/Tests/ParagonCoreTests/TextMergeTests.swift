import XCTest
@testable import ParagonCore

/// Premium review, hardening-03: typing here while the note changed on the other device.
final class TextMergeTests: XCTestCase {
    private let base = "# Shed\n- [ ] Buy wood\nNotes here\n- [ ] Paint\n"

    func testChangesToDifferentLinesAreBothKept() {
        let mine = "# Shed\n- [ ] Buy wood\nNotes here, and more\n- [ ] Paint\n"
        let theirs = "# Shed\n- [x] Buy wood\nNotes here\n- [ ] Paint\n- [ ] Call Anna\n"
        // The phone ticked line 2 and added a task at the end; I typed on line 3.
        XCTAssertEqual(TextMerge.threeWay(base: base, mine: mine, theirs: theirs),
                       .merged("# Shed\n- [x] Buy wood\nNotes here, and more\n- [ ] Paint\n- [ ] Call Anna\n"))
        // Only one side changed, or both made the same change: that text, untouched.
        XCTAssertEqual(TextMerge.threeWay(base: base, mine: mine, theirs: base), .merged(mine))
        XCTAssertEqual(TextMerge.threeWay(base: base, mine: base, theirs: theirs), .merged(theirs))
        XCTAssertEqual(TextMerge.threeWay(base: base, mine: mine, theirs: mine), .merged(mine))
        // A line added here at the top, a line removed there at the bottom.
        XCTAssertEqual(TextMerge.threeWay(base: "a\nb\nc\nd", mine: "new\na\nb\nc\nd", theirs: "a\nb\nc"),
                       .merged("new\na\nb\nc"))
    }

    func testChangesToTheSameLineAreNotMerged() {
        let mine = "# Shed\n- [ ] Buy wood and nails\nNotes here\n- [ ] Paint\n"
        let theirs = "# Shed\n- [x] Buy wood\nNotes here\n- [ ] Paint\n"
        XCTAssertEqual(TextMerge.threeWay(base: base, mine: mine, theirs: theirs), .conflict)
        // Different new lines in the same place are not put in an order nobody chose.
        XCTAssertEqual(TextMerge.threeWay(base: "a\nb", mine: "a\nmine\nb", theirs: "a\ntheirs\nb"), .conflict)
        // I typed on a line the other side deleted.
        XCTAssertEqual(TextMerge.threeWay(base: "a\nb\nc", mine: "a\nb!\nc", theirs: "a\nc"), .conflict)
    }

    func testALongNoteStillMerges() {
        let lines = (0..<20_000).map { "Line \($0)" }
        var mine = lines, theirs = lines
        mine[10] = "Mine"
        theirs[19_000] = "Theirs"
        var both = mine
        both[19_000] = "Theirs"
        XCTAssertEqual(TextMerge.threeWay(base: lines.joined(separator: "\n"), mine: mine.joined(separator: "\n"),
                                          theirs: theirs.joined(separator: "\n")),
                       .merged(both.joined(separator: "\n")))
    }
}
