import XCTest
@testable import ParagonCore

/// Build 286: tick a task right in the note's text, and the checkbox button above the keyboard.
final class TaskBoxTests: XCTestCase {
    func testTickingTheBoxInTheText() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let day = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 9))!
        let text = "# Shed\n- [ ] Buy wood\nPlain line\n"
        // On the box: found; elsewhere in the line or on a plain line: not.
        XCTAssertEqual(TaskBox.boxRange(in: text, near: 9), NSRange(location: 9, length: 3))
        XCTAssertNil(TaskBox.boxRange(in: text, near: 15))
        XCTAssertNil(TaskBox.boxRange(in: text, near: 23))
        // Ticked with its done stamp; ticked again opens it; the other lines stay.
        let done = TaskBox.toggled(text, at: 10, date: day, calendar: cal)!
        XCTAssertTrue(done.hasPrefix("# Shed\n- [x] Buy wood @done("), done)
        XCTAssertTrue(done.hasSuffix("\nPlain line\n"))
        XCTAssertEqual(TaskBox.toggled(done, at: 10, date: day, calendar: cal), text)
        XCTAssertNil(TaskBox.toggled(text, at: 2, date: day, calendar: cal))
        // A repeating task gets its next copy below.
        let rep = TaskBox.toggled("- [ ] Water plants >2026-11-11 @repeat(1d)\n", at: 3, date: day, calendar: cal)!
        XCTAssertEqual(rep.components(separatedBy: "\n").filter { !$0.isEmpty }.count, 2, rep)
        XCTAssertTrue(rep.contains("- [ ] Water plants >2026-11-12"), rep)
        // The keyboard button: plain → task → plain; a bullet becomes a task.
        let made = TaskBox.switchingTask("Call Anna\n", at: 4)
        XCTAssertEqual(made.text, "- [ ] Call Anna\n")
        XCTAssertEqual(made.cursor, 10)
        XCTAssertEqual(TaskBox.switchingTask(made.text, at: 10).text, "Call Anna\n")
        XCTAssertEqual(TaskBox.switchingTask("  - Milk", at: 5).text, "  - [ ] Milk")
        XCTAssertEqual(TaskBox.boxRanges(in: text), [NSRange(location: 9, length: 3)])
        let edit = TaskBox.edit(from: text, to: done)
        XCTAssertEqual((text as NSString).replacingCharacters(in: edit.range, with: edit.replacement), done)
    }
}
