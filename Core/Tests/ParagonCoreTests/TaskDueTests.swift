import XCTest
@testable import ParagonCore

/// The rules behind the **At** line in a task's date window (build 277).
final class TaskDueTests: XCTestCase {
    private let day = DateOnly(year: 2026, month: 11, day: 4)
    private let tomorrow = DateOnly(year: 2026, month: 11, day: 5)

    private func task(_ line: String) throws -> TaskItem {
        try XCTUnwrap(TaskParser.parse(line: line))
    }

    // MARK: Reading what was typed

    func testTypedTimeReadsHourAndMinutes() {
        XCTAssertEqual(TimeOfDay.typed("14:00"), .time(TimeOfDay(hour: 14, minute: 0)))
        XCTAssertEqual(TimeOfDay.typed("9:30"), .time(TimeOfDay(hour: 9, minute: 30)))
        XCTAssertEqual(TimeOfDay.typed("09:05"), .time(TimeOfDay(hour: 9, minute: 5)))
        XCTAssertEqual(TimeOfDay.typed("0:00"), .time(TimeOfDay(hour: 0, minute: 0)))
        XCTAssertEqual(TimeOfDay.typed("23:59"), .time(TimeOfDay(hour: 23, minute: 59)))
    }

    func testTypedTimeIgnoresSpacesAroundIt() {
        XCTAssertEqual(TimeOfDay.typed("  14:00 "), .time(TimeOfDay(hour: 14, minute: 0)))
    }

    /// Nothing typed is an answer of its own: a date with no time of day.
    func testNothingTypedIsEmptyNotInvalid() {
        XCTAssertEqual(TimeOfDay.typed(""), .empty)
        XCTAssertEqual(TimeOfDay.typed("   "), .empty)
    }

    /// A reading that guessed would write something he did not mean, so these are refused.
    func testTypedTimeRefusesWhatIsNotATime() {
        for text in ["24:00", "14:60", "1400", "14.00", "14:0", "14:", ":30", "abc", "14:00:00",
                     "-1:30", "+9:30", "9:3x", "123:00", "\u{0661}\u{0664}:00"] {
            XCTAssertEqual(TimeOfDay.typed(text), .invalid, "\(text) should not be a time")
        }
    }

    /// The quick times are pinned, in order, and every one is a time the typed reading accepts.
    func testTheQuickTimesAreNineTwelveTwoFour() {
        XCTAssertEqual(TimeOfDay.quickChoices.map(\.description), ["09:00", "12:00", "14:00", "16:00"])
        for quick in TimeOfDay.quickChoices {
            XCTAssertEqual(TimeOfDay.typed(quick.description), .time(quick))
        }
    }

    func testMinutesSinceMidnight() {
        XCTAssertEqual(TimeOfDay(hour: 0, minute: 0).minutesSinceMidnight, 0)
        XCTAssertEqual(TimeOfDay(hour: 14, minute: 30).minutesSinceMidnight, 870)
        XCTAssertEqual(TimeOfDay(hour: 23, minute: 59).minutesSinceMidnight, 1439)
    }

    // MARK: Writing a date and a time together

    func testASetDateAndTimeIsWrittenOnTheLine() throws {
        let plain = try task("- [ ] Call the bank #finance !")
        let timed = plain.settingDue(date: day, time: TimeOfDay(hour: 14, minute: 0))
        XCTAssertEqual(timed.serialized, "- [ ] Call the bank #finance ! >2026-11-04T14:00")
        XCTAssertEqual(timed.dueDate, day)
        XCTAssertEqual(timed.dueTime, TimeOfDay(hour: 14, minute: 0))
    }

    /// What is written reads back as the same task, and the title is not touched.
    func testTheLineRoundTripsThroughTheParser() throws {
        let timed = try task("- [ ] Call the bank ~15m").settingDue(date: day, time: TimeOfDay(hour: 9, minute: 5))
        let again = try task(timed.serialized)
        XCTAssertEqual(again.title, "Call the bank")
        XCTAssertEqual(again.dueDate, day)
        XCTAssertEqual(again.dueTime, TimeOfDay(hour: 9, minute: 5))
        XCTAssertEqual(again.minutes, 15)
    }

    func testNoTimeTakesTheTimeOffAndKeepsTheDate() throws {
        let timed = try task("- [ ] Dentist >2026-11-04T14:00")
        let plain = timed.settingDue(date: timed.dueDate, time: nil)
        XCTAssertEqual(plain.serialized, "- [ ] Dentist >2026-11-04")
        XCTAssertEqual(plain.dueDate, day)
        XCTAssertNil(plain.dueTime)
    }

    /// A time needs a date: with no date there is no time either, whatever was handed in.
    func testATimeWithoutADateIsDropped() throws {
        let result = try task("- [ ] Dentist >2026-11-04T14:00").settingDue(date: nil, time: TimeOfDay(hour: 9, minute: 0))
        XCTAssertNil(result.dueDate)
        XCTAssertNil(result.dueTime)
        XCTAssertEqual(result.serialized, "- [ ] Dentist")
    }

    func testTheSameDateAndTimeChangesNothing() throws {
        let timed = try task("- [ ] Dentist >2026-11-04T14:00")
        XCTAssertEqual(timed.settingDue(date: day, time: TimeOfDay(hour: 14, minute: 0)), timed)
    }

    func testRepeatsPrioritiesAndIdsSurviveTheChange() throws {
        let line = "- [ ] Water the plants !! @repeat(weekly) ^t3fa2c1"
        let changed = try task(line).settingDue(date: day, time: TimeOfDay(hour: 12, minute: 0))
        XCTAssertEqual(changed.serialized, "- [ ] Water the plants !! >2026-11-04T12:00 @repeat(weekly) ^t3fa2c1")
        XCTAssertEqual(changed.id, "t3fa2c1")
    }

    // MARK: Changing only the date

    /// **Reschedule keeps the time of day**: a call at 14:00 moved to tomorrow is a call at 14:00
    /// tomorrow. The Overdue buttons and the Inbox keys follow the same rule.
    func testMovingTheDateKeepsTheTime() throws {
        let timed = try task("- [ ] Dentist >2026-11-04T14:00")
        let moved = timed.settingDueDate(tomorrow)
        XCTAssertEqual(moved.dueDate, tomorrow)
        XCTAssertEqual(moved.dueTime, TimeOfDay(hour: 14, minute: 0))
        XCTAssertEqual(moved.serialized, "- [ ] Dentist >2026-11-05T14:00")
    }

    func testRemovingTheDateTakesTheTimeToo() throws {
        let removed = try task("- [ ] Dentist >2026-11-04T14:00").settingDueDate(nil)
        XCTAssertNil(removed.dueDate)
        XCTAssertNil(removed.dueTime)
    }

    func testGivingADateToATaskWithNoTimeLeavesItWithNoTime() throws {
        let dated = try task("- [ ] Dentist").settingDueDate(day)
        XCTAssertEqual(dated.serialized, "- [ ] Dentist >2026-11-04")
    }

    // MARK: How a row says it

    func testDueTextCarriesTheTimeWhenThereIsOne() throws {
        let timed = try task("- [ ] Dentist >2026-11-04T14:00")
        let dated = try task("- [ ] Dentist >2026-11-04")
        let undated = try task("- [ ] Dentist")
        XCTAssertEqual(timed.dueText, "2026-11-04 14:00")
        XCTAssertEqual(dated.dueText, "2026-11-04")
        XCTAssertNil(undated.dueText)
    }
}
