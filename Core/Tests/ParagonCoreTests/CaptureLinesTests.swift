import XCTest
@testable import ParagonCore

/// Round 350 (capture-inbox): pasted and scanned lists, the same line twice, the place name,
/// and a snoozed Inbox line.
final class CaptureLinesTests: XCTestCase {
    func testAPastedListBecomesOneTaskPerLineWithoutMarks() {
        let pasted = "- Buy milk\n* [ ] Call Anna\n1. Book the train\n\n☐ Pay the rent\n  \n• Water the plants"
        XCTAssertEqual(CaptureLines.split(pasted),
                       ["Buy milk", "Call Anna", "Book the train", "Pay the rent", "Water the plants"])
        XCTAssertTrue(CaptureLines.isMany(pasted))
        XCTAssertFalse(CaptureLines.isMany("One single line"))
        XCTAssertEqual(CaptureLines.question(count: 5), "Make 5 tasks?")
        XCTAssertEqual(CaptureLines.addTitle(count: 1), "Add 1 task")
        XCTAssertEqual(CaptureLines.question(count: 3, asTask: false), "Make 3 notes?")
        // Only one change that adds two lines or more is a paste.
        XCTAssertTrue(CaptureLines.pastedMany(from: "", to: "A\nB"))
        XCTAssertFalse(CaptureLines.pastedMany(from: "A", to: "A\nB"))
        XCTAssertFalse(CaptureLines.pastedMany(from: "A\nB", to: "A\nB c"))
    }

    func testAScanDropsSmudgesButKeepsRealLines() {
        XCTAssertEqual(CaptureLines.scanned(["Eggs", "—", "x", "Bread  and   butter", ""]), ["Eggs", "Bread and butter"])
    }

    func testTheSameLineTwiceIsFoundWhateverTheCapitalsAndMarks() {
        let inbox = ["Call the bank !! >2026-11-20", "Order the saddle #next"]
        XCTAssertTrue(CaptureLines.isInInbox("  call  THE bank", among: inbox))
        XCTAssertTrue(CaptureLines.isInInbox("Order the saddle #next", among: inbox))
        XCTAssertFalse(CaptureLines.isInInbox("Call the dentist", among: inbox))
        XCTAssertFalse(CaptureLines.isInInbox("   ", among: inbox))
    }

    func testThePlaceNameIsAddedOnceAndNeverEmpty() {
        XCTAssertEqual(CaptureLines.placed("Buy milk", at: "Home"), "Buy milk \u{2014} at Home")
        XCTAssertEqual(CaptureLines.placed("Buy milk \u{2014} at Home", at: "Home"), "Buy milk \u{2014} at Home")
        XCTAssertEqual(CaptureLines.placed("Buy milk", at: nil), "Buy milk")
        XCTAssertEqual(CaptureLines.placed("Buy milk", at: "  "), "Buy milk")
    }

    func testASnoozedLineRoundTripsAndComesBackOnItsDay() {
        let day = DateOnly(year: 2026, month: 11, day: 23)
        let line = "- [ ] Think about the roof @snooze(2026-11-23)"
        let task = TaskParser.parse(line: line)
        XCTAssertEqual(task?.snooze, day)
        XCTAssertEqual(task?.title, "Think about the roof")
        XCTAssertEqual(task?.serialized, line)
        XCTAssertTrue(task?.isSnoozed(on: DateOnly(year: 2026, month: 11, day: 22)) ?? false)
        XCTAssertFalse(task?.isSnoozed(on: day) ?? true)
        // Before the done stamp, as written everywhere else.
        let done = TaskParser.parse(line: "- [x] A @snooze(2026-11-23) @done(2026-11-20 09:00)")
        XCTAssertEqual(done?.serialized, "- [x] A @snooze(2026-11-23) @done(2026-11-20 09:00)")
    }

    func testTheNextMondayIsAlwaysLater() {
        // 2026-11-20 is a Friday; 2026-11-23 a Monday.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        XCTAssertEqual(InboxSnooze.nextMonday(after: DateOnly(year: 2026, month: 11, day: 20), calendar: calendar),
                       DateOnly(year: 2026, month: 11, day: 23))
        XCTAssertEqual(InboxSnooze.nextMonday(after: DateOnly(year: 2026, month: 11, day: 23), calendar: calendar),
                       DateOnly(year: 2026, month: 11, day: 30))
    }

    // Round 352: the Inbox when every line is snoozed.
    func testTheInboxSaysWhenSnoozedLinesComeBack() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        let today = DateOnly(year: 2026, month: 11, day: 21)
        let tasks: [TaskItem] = [
            TaskItem(title: "Later", snooze: DateOnly(year: 2026, month: 11, day: 30)),
            TaskItem(title: "Sooner", snooze: DateOnly(year: 2026, month: 11, day: 23)),
            TaskItem(title: "Back already", snooze: DateOnly(year: 2026, month: 11, day: 21)),
            TaskItem(title: "Not snoozed"),
        ]
        let first = try XCTUnwrap(InboxSnooze.firstBack(tasks, on: today))
        XCTAssertEqual(first, DateOnly(year: 2026, month: 11, day: 23))
        XCTAssertNil(InboxSnooze.firstBack([TaskItem(title: "Plain")], on: today))
        let words = try XCTUnwrap(InboxSnooze.dayWords(first, calendar: calendar))
        XCTAssertEqual(InboxSnooze.allSnoozedText(count: 1, firstBack: first, calendar: calendar),
                       "1 line comes back on \(words).")
        XCTAssertEqual(InboxSnooze.allSnoozedText(count: 2, firstBack: first, calendar: calendar),
                       "2 lines are snoozed. The first comes back on \(words).")
        XCTAssertEqual(InboxSnooze.allSnoozedText(count: 2, firstBack: nil, calendar: calendar),
                       "2 lines are snoozed. They come back later.")
    }
}
