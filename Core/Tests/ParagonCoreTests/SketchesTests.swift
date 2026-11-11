import XCTest
@testable import ParagonCore

/// Build 288: numbered lists go on, strikethrough comes and goes, sketches are linked.
final class SketchesTests: XCTestCase {
    func testNumberedListsStrikethroughAndSketchLinks() {
        // Return on "1. Milk" makes "2. "; on an empty "2. " ends the list; "1)" style too.
        let next = RichText.continuingList("1. Milk", at: 7)!
        XCTAssertEqual(next.text, "1. Milk\n2. ")
        XCTAssertEqual(next.cursor, 11)
        XCTAssertEqual(RichText.continuingList(next.text, at: next.cursor)!.text, "1. Milk\n")
        XCTAssertEqual(RichText.continuingList("  9) Tea", at: 8)!.text, "  9) Tea\n  10) ")
        XCTAssertNil(RichText.continuingList("2026 was good", at: 13))
        // Strikethrough on the word at the cursor and off again; styled and hidden like bold.
        let s = RichText.toggling("Buy wood now", selection: NSRange(location: 6, length: 0), marker: "~~")
        XCTAssertEqual(s.text, "Buy ~~wood~~ now")
        XCTAssertEqual(RichText.toggling(s.text, selection: s.selection, marker: "~~").text, "Buy wood now")
        XCTAssertTrue(MarkdownHighlight.spans(in: s.text).contains { $0.style == .strike })
        XCTAssertEqual(MarkdownHighlight.hiddenMarkers(in: s.text, cursor: nil).count, 2)
        // A sketch link from a note two folders deep, found again from the note's text.
        let name = Sketches.newFileName(at: Date(timeIntervalSince1970: 0), calendar: Calendar(identifier: .gregorian))
        XCTAssertTrue(name.hasPrefix("Sketch 19"))
        let link = Sketches.link(toFile: "Sketch 2026-11-11 114005.png", fromNote: "Projects/Garden.md")
        XCTAssertEqual(link, "![Sketch](../Sketches/Sketch%202026-11-11%20114005.png)")
        let put = Sketches.inserting(link: link, into: "Plan\nMore", at: 4)
        XCTAssertEqual(put.text, "Plan\n" + link + "\n\nMore")
        XCTAssertEqual(Sketches.links(in: put.text + "\n![x](https://a.b/c.png)", notePath: "Projects/Garden.md"),
                       ["Sketches/Sketch 2026-11-11 114005.png"])
        XCTAssertEqual(Sketches.drawingPath(for: "Sketches/A.png"), "Sketches/A.drawing")
    }
}
