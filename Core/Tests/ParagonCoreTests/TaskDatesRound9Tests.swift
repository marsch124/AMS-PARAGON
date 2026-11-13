import XCTest
@testable import ParagonCore

/// Build 316: dates in plain words, a deadline besides the do-day, and the new repeats.
final class TaskDatesRound9Tests: XCTestCase {
    /// Friday 13 November 2026.
    private let today = DateOnly(year: 2026, month: 11, day: 13)
    private let cal = WeekRef.calendar

    private func read(_ line: String) -> String? {
        PlainDate.read(line, today: today, calendar: cal)?.marker
    }

    // MARK: Plain words

    func testPlainWordsBecomeTheDateMark() {
        XCTAssertEqual(read("Call the bank tomorrow 14:00"), ">2026-11-14T14:00")
        XCTAssertEqual(read("Call the bank tomorrow at 9"), ">2026-11-14T09:00")
        XCTAssertEqual(read("today call Anna"), ">2026-11-13")
        XCTAssertEqual(read("Send the report next Friday"), ">2026-11-20")
        XCTAssertEqual(read("Send the report on Monday 2pm"), ">2026-11-16T14:00")
        XCTAssertEqual(read("Water the plants in 3 days"), ">2026-11-16")
        XCTAssertEqual(read("Check the roof in two weeks"), ">2026-11-27")
        XCTAssertEqual(read("Plan the trip next week"), ">2026-11-16")
        XCTAssertEqual(read("Buy presents 13 Dec 9:00"), ">2026-12-13T09:00")
        XCTAssertEqual(read("Buy presents December 13th"), ">2026-12-13")
        XCTAssertEqual(read("Taxes 2 Feb"), ">2027-02-02")
        XCTAssertEqual(read("Pay the bill Friday"), ">2026-11-20")
        XCTAssertEqual(read("Pay the bill Friday #home !!"), ">2026-11-20")
        XCTAssertEqual(read("Renew passport 2026-12-01"), ">2026-12-01")
    }

    func testNothingIsGuessed() {
        XCTAssertNil(read("Prepare Friday meeting"))
        XCTAssertNil(read("Enjoy the sun"))
        XCTAssertNil(read("Read \"Tomorrow never dies\""))
        XCTAssertNil(read("Fix tomorrow's agenda"))
        XCTAssertNil(read("Call at 14:00"))
        XCTAssertNil(read("Pay 31 Feb"))
        XCTAssertNil(read("Call the bank tomorrow >2026-11-20"))
        XCTAssertNil(read("See [[Tomorrow]] and https://example.com/today"))
    }

    func testTheSavedLineAndTheWordsHeTookAway() {
        XCTAssertEqual(PlainDate.line("Call the bank tomorrow 14:00 about the loan", understoodOn: today, calendar: cal),
                       "Call the bank >2026-11-14T14:00 about the loan")
        let task = TaskParser.parse(line: "- [ ] " + PlainDate.line("Call the bank by Friday", understoodOn: today, calendar: cal))
        XCTAssertEqual(task?.title, "Call the bank")
        XCTAssertEqual(task?.dueDate, DateOnly(year: 2026, month: 11, day: 20))
        // The chip's x: the words stay plain text.
        XCTAssertEqual(PlainDate.line("Watch Tomorrow", understoodOn: today, ignoring: "tomorrow", calendar: cal), "Watch Tomorrow")
    }

    // MARK: Deadline

    func testADeadlineIsWrittenReadAndKeptApartFromTheDoDay() {
        let line = "- [ ] Send the form >2026-11-17 @deadline(2026-11-20) ^t3fa2c1"
        let task = TaskParser.parse(line: line)!
        XCTAssertEqual(task.title, "Send the form")
        XCTAssertEqual(task.deadline, DateOnly(year: 2026, month: 11, day: 20))
        XCTAssertEqual(task.serialized, line)
        // Moving the do-day leaves the deadline where it is.
        XCTAssertEqual(task.settingDueDate(today.adding(days: 1)).deadline, task.deadline)
        XCTAssertNil(task.settingDeadline(nil).serialized.range(of: "@deadline"))
        // Reminders never sees it: it is not part of what the two sides share.
        XCTAssertEqual(SyncEngine.fingerprint(task), SyncEngine.fingerprint(task.settingDeadline(nil)))
    }

    func testDeadlineWords() {
        let day = DateOnly(year: 2026, month: 11, day: 20)
        XCTAssertEqual(TaskDeadline.words(until: day, from: today, calendar: cal), "7 days left")
        XCTAssertEqual(TaskDeadline.words(until: day, from: day.adding(days: -1), calendar: cal), "1 day left")
        XCTAssertEqual(TaskDeadline.words(until: day, from: day, calendar: cal), "Due today")
        XCTAssertEqual(TaskDeadline.words(until: day, from: day.adding(days: 3), calendar: cal), "3 days late")
        XCTAssertFalse(TaskDeadline.isPressing(day, on: today))
        XCTAssertTrue(TaskDeadline.isPressing(day, on: day))
    }

    func testARepeatedTaskKeepsItsDeadlineDistance() {
        var task = TaskParser.parse(line: "- [ ] Report >2026-11-10 @repeat(weekly) @deadline(2026-11-13)")!
        task.markDone()
        let next = task.nextOccurrence(completedOn: today, calendar: cal)!
        XCTAssertEqual(next.dueDate, DateOnly(year: 2026, month: 11, day: 17))
        XCTAssertEqual(next.deadline, DateOnly(year: 2026, month: 11, day: 20))
    }

    // MARK: Repeats

    func testOldRepeatWordsReadAndWriteAsBefore() {
        for word in ["daily", "weekly", "monthly", "yearly", "2w", "3m", "10d"] {
            XCTAssertEqual(RepeatRule(word)?.description, word)
        }
        XCTAssertEqual(RepeatRule("every 2 weeks"), RepeatRule(count: 2, unit: .week))
        XCTAssertEqual(RepeatRule(unit: .week).next(after: today, calendar: cal), DateOnly(year: 2026, month: 11, day: 20))
    }

    func testChosenWeekdays() {
        let rule = RepeatRule("mon,wed,fri")!
        XCTAssertEqual(rule.weekdays, [1, 3, 5])
        XCTAssertEqual(rule.description, "mon,wed,fri")
        XCTAssertEqual(rule.label, "Every Mon, Wed, Fri")
        XCTAssertEqual(rule.next(after: today, calendar: cal), DateOnly(year: 2026, month: 11, day: 16))
        XCTAssertEqual(rule.next(after: today.adding(days: 3), calendar: cal), DateOnly(year: 2026, month: 11, day: 18))
        XCTAssertEqual(RepeatRule("weekdays"), RepeatRule.workingDays)
        XCTAssertEqual(RepeatRule.workingDays.description, "weekdays")
        XCTAssertEqual(RepeatRule(weekdays: [1, 2, 3, 4, 5, 6, 7]), RepeatRule(unit: .day))
        let line = "- [ ] Train >2026-11-13 @repeat(mon,wed,fri)"
        XCTAssertEqual(TaskParser.parse(line: line)?.serialized, line)
    }

    func testLastDayOfTheMonth() {
        let rule = RepeatRule("monthend")!
        XCTAssertEqual(rule, .lastDayOfMonth)
        XCTAssertEqual(rule.next(after: today, calendar: cal), DateOnly(year: 2026, month: 11, day: 30))
        XCTAssertEqual(rule.next(after: DateOnly(year: 2026, month: 11, day: 30), calendar: cal), DateOnly(year: 2026, month: 12, day: 31))
        XCTAssertEqual(rule.next(after: DateOnly(year: 2027, month: 1, day: 31), calendar: cal), DateOnly(year: 2027, month: 2, day: 28))
    }

    func testCountFromTheDayItIsFinished() {
        let rule = RepeatRule("10d after done")!
        XCTAssertTrue(rule.afterDone)
        XCTAssertEqual(rule.description, "10d after done")
        XCTAssertEqual(rule.label, "10 days after it is done")
        // Planned for the 1st, done on the 13th: the next one is ten days after the 13th.
        var task = TaskParser.parse(line: "- [ ] Water the plants >2026-11-01 @repeat(10d after done)")!
        task.markDone()
        XCTAssertEqual(task.nextOccurrence(completedOn: today, calendar: cal)?.dueDate, DateOnly(year: 2026, month: 11, day: 23))
        // The same rule counted from its date would have given the 21st.
        var dated = TaskParser.parse(line: "- [ ] Water the plants >2026-11-01 @repeat(10d)")!
        dated.markDone()
        XCTAssertEqual(dated.nextOccurrence(completedOn: today, calendar: cal)?.dueDate, DateOnly(year: 2026, month: 11, day: 21))
        // Weekdays and month end cannot count from done.
        var days = RepeatRule.workingDays
        days.afterDone = true
        XCTAssertFalse(days.afterDone)
    }
}
