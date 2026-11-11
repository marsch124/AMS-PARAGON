import XCTest
@testable import ParagonCore

/// Build 287: bold, italic and headings while writing; Return carries a list on; the box's
/// long-press menu.
final class RichTextTests: XCTestCase {
    func testRichTextListsAndTheBoxMenu() {
        // Bold on the word at the cursor, and off again; italic inside bold.
        let b = RichText.toggling("Buy wood now", selection: NSRange(location: 6, length: 0), marker: "**")
        XCTAssertEqual(b.text, "Buy **wood** now")
        XCTAssertEqual(b.selection, NSRange(location: 8, length: 0))
        XCTAssertEqual(RichText.toggling(b.text, selection: b.selection, marker: "**").text, "Buy wood now")
        // At the word's end the cursor goes past the closing stars; a selection stays selected.
        XCTAssertEqual(RichText.toggling("Strong", selection: NSRange(location: 6, length: 0), marker: "**").selection.location, 10)
        let bi = RichText.toggling(b.text, selection: NSRange(location: 6, length: 4), marker: "*")
        XCTAssertEqual(bi.text, "Buy ***wood*** now")
        XCTAssertEqual(RichText.toggling(bi.text, selection: bi.selection, marker: "*").text, b.text)
        let empty = RichText.toggling("A ", selection: NSRange(location: 2, length: 0), marker: "*")
        XCTAssertEqual(empty.text, "A **")
        XCTAssertEqual(empty.selection.location, 3)
        // Heading: plain → # → ## → ### → plain.
        var h = RichText.cyclingHeading("Plan\n", at: 2)
        XCTAssertEqual(h.text, "# Plan\n")
        h = RichText.cyclingHeading(h.text, at: h.cursor); h = RichText.cyclingHeading(h.text, at: h.cursor)
        XCTAssertEqual(h.text, "### Plan\n")
        XCTAssertEqual(RichText.cyclingHeading(h.text, at: h.cursor).text, "Plan\n")
        // Return on a task makes the next one; on an empty one ends the list; bullets too.
        let next = RichText.continuingList("  - [x] Milk\n", at: 12)!
        XCTAssertEqual(next.text, "  - [x] Milk\n  - [ ] \n")
        XCTAssertEqual(next.cursor, 21)
        let ended = RichText.continuingList(next.text, at: next.cursor)!
        XCTAssertEqual(ended.text, "  - [x] Milk\n\n")
        XCTAssertEqual(RichText.continuingList("* Eggs", at: 6)!.text, "* Eggs\n* ")
        XCTAssertNil(RichText.continuingList("Plain", at: 5))
        XCTAssertNil(RichText.continuingList("- [ ] Milk", at: 0))
        // Markers hide everywhere but the cursor's line.
        let text = "# Shed\nSome **wood** here"
        XCTAssertEqual(MarkdownHighlight.hiddenMarkers(in: text, cursor: nil).count, 3)
        XCTAssertEqual(MarkdownHighlight.hiddenMarkers(in: text, cursor: 2), [NSRange(location: 12, length: 2), NSRange(location: 18, length: 2)])
        XCTAssertEqual(MarkdownHighlight.hiddenMarkers(in: text, cursor: 10), [NSRange(location: 0, length: 2)])
        // Bold in a task line too.
        XCTAssertEqual(MarkdownHighlight.hiddenMarkers(in: "- [ ] **Call** Anna", cursor: nil).count, 2)
        // The box menu: cancel, and tomorrow keeping the time.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let day = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 9))!
        XCTAssertEqual(TaskBox.cancelled("- [ ] Call Anna\n", at: 3), "- [-] Call Anna\n")
        let moved = TaskBox.movedToTomorrow("- [ ] Call Anna >2026-11-11 14:00\n", at: 3, today: day, calendar: cal)!
        XCTAssertTrue(moved.contains(">2026-11-12"), moved)
        XCTAssertTrue(moved.contains("14:00"), moved)
        XCTAssertNil(TaskBox.cancelled("Plain\n", at: 1))
    }
}
