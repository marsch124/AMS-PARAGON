import XCTest
@testable import ParagonCore

/// Build 276: an event cut to one day. The Plan screen's Calendar lane, the Calendar section's
/// day, the planning sum and the Today's plan widget all read an event through this, so a
/// meeting that began at 23:00 yesterday starts at 0 on every one of them, and one that ends
/// tomorrow ends at 24:00.
final class EventDaySpanTests: XCTestCase {
    private func stockholm() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Stockholm"))
        return calendar
    }

    private func at(_ calendar: Calendar, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0,
                    year: Int = 2026) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                         hour: hour, minute: minute)))
    }

    private func span(_ calendar: Calendar, from: Date, to: Date, onMonth month: Int, day: Int,
                      year: Int = 2026) -> EventDaySpan {
        EventDaySpan(start: from, end: to, on: DateOnly(year: year, month: month, day: day), calendar: calendar)
    }

    func testAnEventInsideTheDayIsNotCut() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 11, 4, 9), to: try at(calendar, 11, 4, 10, 30),
                          onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 9 * 60)
        XCTAssertEqual(result.endMinute, 10 * 60 + 30)
        XCTAssertFalse(result.beginsEarlier)
        XCTAssertFalse(result.endsLater)
        let nine = try at(calendar, 11, 4, 9)
        let halfPastTen = try at(calendar, 11, 4, 10, 30)
        XCTAssertEqual(result.start, nine)
        XCTAssertEqual(result.end, halfPastTen)
    }

    /// The fault: it began at 23:00 yesterday and ends at 01:00 today. Today it is 00:00 to 01:00,
    /// not a half hour at 23:00.
    func testAnEventFromYesterdayStartsAtMidnight() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 11, 3, 23), to: try at(calendar, 11, 4, 1),
                          onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 0)
        XCTAssertEqual(result.endMinute, 60)
        XCTAssertTrue(result.beginsEarlier)
        XCTAssertFalse(result.endsLater)
        let midnight = try at(calendar, 11, 4, 0)
        let one = try at(calendar, 11, 4, 1)
        XCTAssertEqual(result.start, midnight)
        XCTAssertEqual(result.end, one)
    }

    /// And the other way: it begins at 23:00 and ends at 02:00 tomorrow. Today it is 23:00 to
    /// 24:00, and it does not run off the bottom of the grid.
    func testAnEventIntoTomorrowEndsAtMidnight() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 11, 4, 23), to: try at(calendar, 11, 5, 2),
                          onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 23 * 60)
        XCTAssertEqual(result.endMinute, EventDaySpan.minutesInDay)
        XCTAssertFalse(result.beginsEarlier)
        XCTAssertTrue(result.endsLater)
        let nextMidnight = try at(calendar, 11, 5, 0)
        XCTAssertEqual(result.end, nextMidnight)
    }

    func testAnEventThatCoversTheWholeDayFillsIt() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 11, 3, 20), to: try at(calendar, 11, 5, 8),
                          onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 0)
        XCTAssertEqual(result.endMinute, 1440)
        XCTAssertTrue(result.beginsEarlier)
        XCTAssertTrue(result.endsLater)
    }

    /// Exactly 00:00 is the start of this day, not an event from the day before.
    func testAnEventThatStartsExactlyAtMidnightBelongsToTheDay() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 11, 4, 0), to: try at(calendar, 11, 4, 2),
                          onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 0)
        XCTAssertEqual(result.endMinute, 120)
        XCTAssertFalse(result.beginsEarlier)
    }

    /// Ending exactly at the next midnight is 24:00, and the event does not go on after the day.
    func testAnEventThatEndsExactlyAtMidnightEndsAt2400() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 11, 4, 22), to: try at(calendar, 11, 5, 0),
                          onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 22 * 60)
        XCTAssertEqual(result.endMinute, 1440)
        XCTAssertFalse(result.endsLater)
    }

    /// An event with no length keeps its place; the caller decides how short is too short.
    func testAnEventWithNoLengthKeepsItsStart() throws {
        let calendar = try stockholm()
        let noon = try at(calendar, 11, 4, 12)
        let result = span(calendar, from: noon, to: noon, onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 720)
        XCTAssertEqual(result.endMinute, 720)
    }

    /// An end before the start never gives a negative length.
    func testTheEndIsNeverBeforeTheStart() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 11, 4, 15), to: try at(calendar, 11, 4, 14),
                          onMonth: 11, day: 4)
        XCTAssertEqual(result.startMinute, 15 * 60)
        XCTAssertGreaterThanOrEqual(result.endMinute, result.startMinute)
        XCTAssertGreaterThanOrEqual(result.end, result.start)
    }

    /// An event the day was asked to draw is always drawn: one that does not touch the day is
    /// held to the nearest edge as a span of no length, never dropped and never negative.
    func testAnEventOutsideTheDayIsHeldToTheNearestEdge() throws {
        let calendar = try stockholm()
        let before = span(calendar, from: try at(calendar, 11, 3, 10), to: try at(calendar, 11, 3, 11),
                          onMonth: 11, day: 4)
        XCTAssertEqual(before.startMinute, 0)
        XCTAssertEqual(before.endMinute, 0)
        let after = span(calendar, from: try at(calendar, 11, 5, 10), to: try at(calendar, 11, 5, 11),
                         onMonth: 11, day: 4)
        XCTAssertEqual(after.startMinute, 1440)
        XCTAssertEqual(after.endMinute, 1440)
    }

    // MARK: The days the clocks change

    /// 29 March 2026: 02:00 became 03:00. Minutes are the wall clock's, so 04:00 is 240 even
    /// though only three hours have passed since midnight (build 238).
    func testTheMinutesAreTheWallClockOnTheDayTheClocksGoForward() throws {
        let calendar = try stockholm()
        let from = try at(calendar, 3, 29, 1)
        let to = try at(calendar, 3, 29, 4)
        let result = span(calendar, from: from, to: to, onMonth: 3, day: 29)
        XCTAssertEqual(result.startMinute, 60)
        XCTAssertEqual(result.endMinute, 240)
        XCTAssertEqual(to.timeIntervalSince(from), 2 * 3600, "The clocks did not change, so this proves nothing.")
    }

    /// An event from the evening before, ending after the change: still 0 to the wall clock.
    func testAnEventFromTheNightBeforeTheClocksChangeStartsAtMidnight() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 3, 28, 23), to: try at(calendar, 3, 29, 5),
                          onMonth: 3, day: 29)
        XCTAssertEqual(result.startMinute, 0)
        XCTAssertEqual(result.endMinute, 300)
    }

    /// 25 October 2026: 03:00 became 02:00 and the day has 25 hours. Midnight to midnight is
    /// still 0 to 1440, and an event that runs into the next day ends at the next midnight.
    func testTheDayWithTheExtraHourStillEndsAt2400() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 10, 25, 22), to: try at(calendar, 10, 26, 3),
                          onMonth: 10, day: 25)
        XCTAssertEqual(result.startMinute, 22 * 60)
        XCTAssertEqual(result.endMinute, 1440)
        XCTAssertTrue(result.endsLater)
        let midnight = try at(calendar, 10, 26, 0)
        XCTAssertEqual(result.end, midnight)
        let first = try at(calendar, 10, 25, 0)
        XCTAssertEqual(midnight.timeIntervalSince(first), 25 * 3600, "The day did not have its extra hour.")
    }

    func testAnEventFromTheNightBeforeTheExtraHourStartsAtMidnight() throws {
        let calendar = try stockholm()
        let result = span(calendar, from: try at(calendar, 10, 24, 23), to: try at(calendar, 10, 25, 1),
                          onMonth: 10, day: 25)
        XCTAssertEqual(result.startMinute, 0)
        XCTAssertEqual(result.endMinute, 60)
        XCTAssertTrue(result.beginsEarlier)
    }
}
