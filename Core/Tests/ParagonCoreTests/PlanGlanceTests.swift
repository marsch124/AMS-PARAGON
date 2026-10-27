import XCTest
@testable import ParagonCore

/// Build 273: what the **Today's plan** widget says. The widget itself cannot be drawn here,
/// but every word and every choice it makes is decided in `PlanGlance`, and that is what these
/// tests are about: the widget must name the same block as **Today**'s **Now** and **Then**
/// lines, and say it in the same few words at every minute of the day.
final class PlanGlanceTests: XCTestCase {
    private let stockholm: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }()

    private let today = DateOnly(year: 2026, month: 10, day: 26)

    private func minutes(_ clock: String) -> Int {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }

    private func span(_ start: String, _ end: String, _ title: String) -> WidgetSnapshot.Span {
        WidgetSnapshot.Span(title: title, start: minutes(start), end: minutes(end))
    }

    private func snapshot(day: DateOnly? = nil, plan: [WidgetSnapshot.Span]?,
                          events: [WidgetSnapshot.Span]? = nil) -> WidgetSnapshot {
        WidgetSnapshot(day: day ?? today, written: Date(timeIntervalSince1970: 0), dueToday: 0,
                       overdue: 0, inboxCount: 0, dueForReview: 0, items: [],
                       plan: plan, events: events)
    }

    /// 26 October 2026 at the given clock time, in Stockholm.
    private func moment(_ clock: String, day: Int = 26, month: Int = 10) -> Date {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        let components = DateComponents(year: 2026, month: month, day: day,
                                        hour: parts[0], minute: parts[1])
        return stockholm.date(from: components)!
    }

    private func glance(_ snapshot: WidgetSnapshot, at clock: String) -> PlanGlance {
        PlanGlance(snapshot: snapshot, at: moment(clock), calendar: stockholm)
    }

    private var day: WidgetSnapshot {
        snapshot(plan: [span("09:30", "10:15", "Swim"),
                        span("11:00", "12:00", "Write the report")])
    }

    // MARK: The five states

    func testAFileWithNoPlanInItIsFromAnOlderApp() {
        XCTAssertEqual(glance(snapshot(plan: nil), at: "10:00").state, .olderApp)
    }

    func testAFileFromAnotherDayIsNotToday() {
        let yesterdays = snapshot(day: DateOnly(year: 2026, month: 10, day: 25),
                                  plan: [span("09:30", "10:15", "Swim")])
        XCTAssertEqual(glance(yesterdays, at: "10:00").state, .notToday)
        XCTAssertNil(glance(yesterdays, at: "10:00").headline)
    }

    func testNotTodayUsesTheDateOfTheEntryAndNotTheDayItIsDrawn() {
        // A widget's entries are made ahead of time. The entry for 00:00 the next day must say
        // the file is old even though the timeline was made the evening before.
        XCTAssertEqual(glance(day, at: "23:59").state, .allDone)
        let afterMidnight = PlanGlance(snapshot: day, at: moment("00:00", day: 27), calendar: stockholm)
        XCTAssertEqual(afterMidnight.state, .notToday)
    }

    func testADayWithNoBlocksSaysSo() {
        let reading = glance(snapshot(plan: []), at: "10:00")
        XCTAssertEqual(reading.state, .nothingPlanned)
        XCTAssertNil(reading.headline)
        XCTAssertNil(reading.whenText)
        XCTAssertNil(reading.thenText)
    }

    func testAfterTheLastBlockNothingMoreIsPlanned() {
        XCTAssertEqual(glance(day, at: "12:00").state, .allDone)
        XCTAssertEqual(glance(day, at: "18:30").state, .allDone)
        XCTAssertNil(glance(day, at: "18:30").headline)
    }

    func testBeforeAndInsideTheDayIsPlanned() {
        XCTAssertEqual(glance(day, at: "06:00").state, .planned)
        XCTAssertEqual(glance(day, at: "10:00").state, .planned)
    }

    // MARK: The headline and the line under it

    func testBeforeTheFirstBlockTheHeadlineIsComingAndThenIsTheOneAfter() {
        let reading = glance(day, at: "09:05")
        XCTAssertEqual(reading.headline?.title, "Swim")
        XCTAssertFalse(reading.isNow)
        XCTAssertEqual(reading.whenText, "in 25 min")
        XCTAssertEqual(reading.rangeText, "09:30 \u{2013} 10:15")
        XCTAssertEqual(reading.then?.title, "Write the report")
        XCTAssertEqual(reading.thenText, "Then 11:00 Write the report")
    }

    func testInsideABlockTheHeadlineIsNowAndThenIsTheNextToStart() {
        let reading = glance(day, at: "09:55")
        XCTAssertEqual(reading.headline?.title, "Swim")
        XCTAssertTrue(reading.isNow)
        XCTAssertEqual(reading.whenText, "Now \u{00B7} 20 min left")
        XCTAssertEqual(reading.rangeText, "09:30 \u{2013} 10:15")
        XCTAssertEqual(reading.thenText, "Then 11:00 Write the report")
    }

    func testTheLastBlockHasNothingAfterIt() {
        let reading = glance(day, at: "11:30")
        XCTAssertEqual(reading.headline?.title, "Write the report")
        XCTAssertTrue(reading.isNow)
        XCTAssertNil(reading.then)
        XCTAssertNil(reading.thenText)
    }

    func testBetweenTwoBlocksTheHeadlineIsTheNextAndThenIsTheOneAfterIt() {
        let three = snapshot(plan: [span("09:30", "10:00", "A"), span("11:00", "11:30", "B"),
                                    span("14:00", "15:00", "C")])
        let reading = glance(three, at: "10:30")
        XCTAssertEqual(reading.headline?.title, "B")
        XCTAssertEqual(reading.then?.title, "C")
    }

    // MARK: The words at the edges

    func testAnHourAwayIsAClockTimeAndFiftyNineMinutesIsNot() {
        let block = snapshot(plan: [span("14:00", "15:00", "Call")])
        XCTAssertEqual(glance(block, at: "13:01").whenText, "in 59 min")
        XCTAssertEqual(glance(block, at: "13:01").rangeText, "14:00 \u{2013} 15:00")
        XCTAssertEqual(glance(block, at: "13:00").whenText, "at 14:00")
        // The clock time already said the start, so the range is not said again.
        XCTAssertNil(glance(block, at: "13:00").rangeText)
        XCTAssertEqual(glance(block, at: "13:59").whenText, "in 1 min")
    }

    func testAnHourLeftNamesTheEndAndFiftyNineMinutesCountsDown() {
        let block = snapshot(plan: [span("10:00", "12:00", "Deep work")])
        XCTAssertEqual(glance(block, at: "10:00").whenText, "Now \u{00B7} until 12:00")
        XCTAssertNil(glance(block, at: "10:00").rangeText)
        XCTAssertEqual(glance(block, at: "11:00").whenText, "Now \u{00B7} until 12:00")
        XCTAssertEqual(glance(block, at: "11:01").whenText, "Now \u{00B7} 59 min left")
        XCTAssertEqual(glance(block, at: "11:59").whenText, "Now \u{00B7} 1 min left")
    }

    func testAtTheEndMinuteTheBlockIsOver() {
        let block = snapshot(plan: [span("10:00", "11:00", "Deep work")])
        XCTAssertTrue(glance(block, at: "10:59").isNow)
        let atEnd = glance(block, at: "11:00")
        XCTAssertEqual(atEnd.state, .allDone)
        XCTAssertNil(atEnd.headline)

        // With a block starting the minute the first one ends, the new one takes over at once.
        let touching = snapshot(plan: [span("10:00", "11:00", "A"), span("11:00", "11:30", "B")])
        XCTAssertEqual(glance(touching, at: "11:00").headline?.title, "B")
        XCTAssertTrue(glance(touching, at: "11:00").isNow)
    }

    func testABlockWithNoLengthStillHasAMinuteToRun() {
        // `PlanBlock.minutes` is never below one. At its own minute it is now, and says so.
        let point = snapshot(plan: [span("10:00", "10:00", "Reminder")])
        let reading = glance(point, at: "10:00")
        XCTAssertTrue(reading.isNow)
        XCTAssertEqual(reading.whenText, "Now \u{00B7} 1 min left")
    }

    // MARK: Today and the widget name the same block

    func testTheWidgetNamesTheBlockThatTodayNames() {
        // The rules of build 266, checked through both doors: a short block inside a long one
        // is now while it runs, and the long one is now again after it.
        let spans = [span("08:00", "17:00", "Office day"), span("09:30", "11:00", "Write the offer"),
                     span("13:00", "13:30", "Call Anna")]
        let file = snapshot(plan: spans)
        let blocks = spans.enumerated().map { pair in
            PlanBlock(start: pair.element.start, end: pair.element.end,
                      title: pair.element.title, index: pair.offset)
        }
        for clock in ["07:00", "08:00", "09:29", "09:30", "10:59", "11:00", "12:59", "13:00",
                      "13:29", "13:30", "17:00", "20:00"] {
            let onToday = NowAndNext(blocks: blocks, minute: minutes(clock))
            let widget = glance(file, at: clock)
            XCTAssertEqual(widget.headline?.title, (onToday.now ?? onToday.next)?.title,
                           "At \(clock) the widget and Today name different blocks.")
            XCTAssertEqual(widget.isNow, onToday.now != nil, "At \(clock), now differs.")
        }
    }

    func testTwoBlocksOnTheSameStartAreSettledLikeToday() {
        // Same start: the one first in the plan. The file keeps the plan's order.
        let file = snapshot(plan: [span("10:00", "10:30", "First"), span("10:00", "11:00", "Second")])
        XCTAssertEqual(glance(file, at: "10:15").headline?.title, "First")
    }

    func testTheMinuteIsTheClocksOwnOnTheNightTheClocksChange() {
        // 25 October 2026 is the night Sweden goes back to winter time (build 238). 10:00 on
        // the wall is minute 600, not 660, which seconds since midnight divided by sixty gives.
        let reading = PlanGlance(snapshot: day, at: moment("10:00", day: 25), calendar: stockholm)
        XCTAssertEqual(reading.nowMinute, 600)
    }

    // MARK: The ruler's window

    func testTheWindowStartsAtTheHourOfNow() {
        XCTAssertEqual(PlanGlance.window(at: minutes("09:05"), hours: 3), minutes("09:00")..<minutes("12:00"))
        XCTAssertEqual(PlanGlance.window(at: minutes("00:00"), hours: 3), 0..<180)
    }

    func testTheWindowNeverRunsPastMidnight() {
        XCTAssertEqual(PlanGlance.window(at: minutes("22:40"), hours: 3), minutes("21:00")..<1440)
        XCTAssertEqual(PlanGlance.window(at: minutes("23:59"), hours: 3), minutes("21:00")..<1440)
        XCTAssertEqual(PlanGlance.window(at: minutes("21:00"), hours: 3), minutes("21:00")..<1440)
        // A window longer than the day is the whole day.
        XCTAssertEqual(PlanGlance.window(at: minutes("12:00"), hours: 30), 0..<1440)
    }

    // MARK: The timeline

    func testEntryDatesAreSortedUniqueAndNeverAfterMidnight() {
        let start = moment("10:00")
        let midnight = moment("00:00", day: 27)
        let dates = PlanGlance.entryDates(from: start, snapshot: day, calendar: stockholm)
        XCTAssertEqual(dates.first, start)
        XCTAssertEqual(dates.last, midnight)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
        XCTAssertTrue(dates.allSatisfy { $0 <= midnight })
    }

    func testEveryMinuteOfTheNextHourHasAnEntryAndThenTheQuarterHours() {
        let dates = PlanGlance.entryDates(from: moment("10:00"), snapshot: nil, calendar: stockholm)
        let minutesOfDay = dates.map { NowAndNext.minute(of: $0, calendar: stockholm) }
        for offset in 0...60 {
            XCTAssertTrue(minutesOfDay.contains(600 + offset), "No entry at minute \(600 + offset).")
        }
        // After the first hour only the quarter hours.
        XCTAssertFalse(minutesOfDay.contains(minutes("11:01")))
        XCTAssertTrue(minutesOfDay.contains(minutes("11:15")))
        XCTAssertTrue(minutesOfDay.contains(minutes("23:45")))
    }

    func testABlocksStartAndEndGetAnEntryOfTheirOwn() {
        let file = snapshot(plan: [span("14:07", "14:52", "Odd times")],
                            events: [span("16:20", "17:10", "Meeting")])
        let dates = PlanGlance.entryDates(from: moment("10:00"), snapshot: file, calendar: stockholm)
        let minutesOfDay = dates.map { NowAndNext.minute(of: $0, calendar: stockholm) }
        for clock in ["14:07", "14:52", "16:20", "17:10"] {
            XCTAssertTrue(minutesOfDay.contains(minutes(clock)), "No entry at \(clock).")
        }
    }

    func testAStartInTheMiddleOfAMinuteGetsTheNextWholeMinuteNext() {
        let start = moment("10:00").addingTimeInterval(30)
        let dates = PlanGlance.entryDates(from: start, snapshot: nil, calendar: stockholm)
        XCTAssertEqual(dates.first, start)
        XCTAssertEqual(dates[1], moment("10:01"))
    }

    func testAnEntryAtMidnightSaysTheFileIsOld() {
        // The last entry of the day is midnight itself, so the widget stops claiming it is
        // still the evening of the day before.
        let dates = PlanGlance.entryDates(from: moment("23:30"), snapshot: day, calendar: stockholm)
        let last = PlanGlance(snapshot: day, at: dates.last!, calendar: stockholm)
        XCTAssertEqual(last.state, .notToday)
    }
}
