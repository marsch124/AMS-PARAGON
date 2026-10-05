import XCTest
@testable import ParagonCore

final class TaskTimeTests: XCTestCase {
    func testReadsTheTimeAndTakesItOutOfTheTitle() throws {
        let task = try XCTUnwrap(TaskParser.parse(line: "- [ ] Write the offer ~45m >2026-10-06 #shed"))
        XCTAssertEqual(task.minutes, 45)
        XCTAssertEqual(task.title, "Write the offer #shed")
        XCTAssertEqual(task.dueDate, DateOnly("2026-10-06"))
    }

    func testReadsHoursAndHoursWithMinutes() throws {
        XCTAssertEqual(TaskParser.parse(line: "- [ ] Garden ~1h")?.minutes, 60)
        XCTAssertEqual(TaskParser.parse(line: "- [ ] Garden ~1h30m")?.minutes, 90)
        XCTAssertEqual(TaskParser.parse(line: "- [ ] Garden ~90m")?.minutes, 90)
        XCTAssertEqual(TaskParser.parse(line: "- [ ] Garden ~10m")?.minutes, 10)
    }

    func testLeavesOrdinaryTildesAlone() throws {
        let bare = try XCTUnwrap(TaskParser.parse(line: "- [ ] Invite ~ 5 people"))
        XCTAssertNil(bare.minutes)
        XCTAssertEqual(bare.title, "Invite ~ 5 people")
        let number = try XCTUnwrap(TaskParser.parse(line: "- [ ] Invite ~5 people"))
        XCTAssertNil(number.minutes)
        XCTAssertEqual(number.title, "Invite ~5 people")
        let zero = try XCTUnwrap(TaskParser.parse(line: "- [ ] Nothing ~0m"))
        XCTAssertNil(zero.minutes)
    }

    func testTheFirstTimeCountsAndASecondIsDropped() throws {
        let task = try XCTUnwrap(TaskParser.parse(line: "- [ ] Twice ~15m ~2h"))
        XCTAssertEqual(task.minutes, 15)
        XCTAssertEqual(task.title, "Twice")
    }

    func testWritesTheTimeAfterThePriorityAndBeforeTheDate() {
        var task = TaskItem(title: "Call the bank", dueDate: DateOnly("2026-10-06"), priority: 1, id: "t1a2b3c")
        task.minutes = 15
        XCTAssertEqual(task.serialized, "- [ ] Call the bank ! ~15m >2026-10-06 ^t1a2b3c")
        task.minutes = 90
        XCTAssertEqual(task.serialized, "- [ ] Call the bank ! ~1h30m >2026-10-06 ^t1a2b3c")
        task.minutes = nil
        XCTAssertEqual(task.serialized, "- [ ] Call the bank ! >2026-10-06 ^t1a2b3c")
    }

    func testRoundTripsEveryChoice() throws {
        for value in TaskTime.choices {
            let line = TaskItem(title: "Task", minutes: value).serialized
            XCTAssertEqual(TaskParser.parse(line: line)?.minutes, value, line)
            XCTAssertEqual(TaskTime.minutes(in: try XCTUnwrap(TaskTime.token(value))), value)
        }
    }

    func testWords() {
        XCTAssertEqual(TaskTime.label(10), "10 min")
        XCTAssertEqual(TaskTime.label(60), "1 h")
        XCTAssertEqual(TaskTime.label(90), "1 h 30")
        XCTAssertEqual(TaskTime.total(45), "45 min")
        XCTAssertEqual(TaskTime.total(120), "2 h")
        XCTAssertEqual(TaskTime.total(150), "2 h 30 min")
    }

    func testANoteKeepsTheTimeWhenTheTaskIsReplaced() throws {
        var note = Note(relativePath: "Projects/Shed.md", kind: .project,
                        body: "- [ ] Write the offer ^t000001\n")
        var task = try XCTUnwrap(note.tasks.first)
        task.minutes = 45
        XCTAssertTrue(note.replace(task: task))
        XCTAssertTrue(note.body.contains("- [ ] Write the offer ~45m ^t000001"))
        XCTAssertEqual(note.tasks.first?.minutes, 45)
    }

    func testTheTimeIsDimmedInTheEditorLikeADate() {
        let spans = MarkdownHighlight.spans(in: "- [ ] Write the offer ~45m")
        XCTAssertTrue(spans.contains { $0.style == .dueDate && $0.range == NSRange(location: 22, length: 4) })
    }
}
