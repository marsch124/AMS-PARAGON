import XCTest
@testable import ParagonCore

final class TaskMovedTests: XCTestCase {
    func testALaterDayIsCountedAndTheMarkRoundTrips() {
        var task = TaskParser.parse(line: "- [ ] Call the bank >2026-11-20 @moved(2)")!
        XCTAssertEqual(task.moved, 2)
        XCTAssertEqual(task.title, "Call the bank")
        XCTAssertEqual(task.serialized, "- [ ] Call the bank >2026-11-20 @moved(2)")

        let later = DateOnly("2026-11-21")!
        task = task.settingDueDate(later)
        XCTAssertEqual(task.moved, 3)
        // The same day, an earlier day and a change of the time alone count nothing.
        XCTAssertEqual(task.settingDueDate(later).moved, 3)
        XCTAssertEqual(task.settingDueDate(DateOnly("2026-11-19")!).moved, 3)
        XCTAssertEqual(task.settingDue(date: later, time: TimeOfDay(hour: 9, minute: 0)).moved, 3)

        // A first date and a task with no date count nothing.
        let fresh = TaskParser.parse(line: "- [ ] New")!
        XCTAssertNil(fresh.settingDueDate(later).moved)

        // Five moves ask the question; answering it starts again.
        var often = TaskParser.parse(line: "- [ ] Tax >2026-11-20 @moved(4)")!
        XCTAssertFalse(often.movedOften)
        often = often.settingDueDate(later)
        XCTAssertTrue(often.movedOften)
        XCTAssertEqual(often.movedText, "Moved 5 times")
        XCTAssertNil(often.forgettingMoves().moved)
        XCTAssertFalse(often.forgettingMoves().movedOften)

        // The next copy of a repeating task has not been moved.
        let repeating = TaskParser.parse(line: "- [ ] Water >2026-11-20 @repeat(weekly) @moved(3)")!
        XCTAssertNil(repeating.nextOccurrence(completedOn: DateOnly("2026-11-20")!)?.moved)
    }
}
