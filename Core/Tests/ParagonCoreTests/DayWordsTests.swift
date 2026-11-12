import XCTest
@testable import ParagonCore

/// The one date style (review round 3): `2026-11-12`, `Thursday 2026-11-12`, `2026-11`,
/// `Week 46`, `14:30` — English and Gregorian whatever the device is set to.
final class DayWordsTests: XCTestCase {
    func testTheOneDateStyle() {
        let day = DateOnly(year: 2026, month: 11, day: 12)
        XCTAssertEqual(DayWords.plain(day), "2026-11-12")
        XCTAssertEqual(DayWords.withWeekday(day), "Thursday 2026-11-12")
        XCTAssertEqual(DayWords.shortWeekday(day), "Thu")
        XCTAssertEqual(DayWords.withWeekday(DateOnly(year: 2027, month: 8, day: 15)), "Sunday 2027-08-15")
        XCTAssertEqual(DayWords.withWeekday(DateOnly(year: 2028, month: 2, day: 29)), "Tuesday 2028-02-29")
        XCTAssertEqual(DayWords.month(day), "2026-11")
        XCTAssertEqual(DayWords.month(MonthRef(year: 2027, month: 3)), "2027-03")
        XCTAssertEqual(DayWords.week(day), "Week 46")
        XCTAssertEqual(DayWords.weekAndYear(WeekRef(year: 2026, week: 46)), "Week 46 \u{00B7} 2026")
        XCTAssertEqual(DayWords.weekSpan(WeekRef(year: 2026, week: 46)), "Week 46 \u{00B7} 2026-11-09 \u{2013} 2026-11-15")

        // A moment: read in the calendar handed in, never in the device's own region.
        var stockholm = Calendar(identifier: .gregorian)
        stockholm.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let moment = stockholm.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 14, minute: 30, second: 5))!
        XCTAssertEqual(DayWords.plain(moment, calendar: stockholm), "2026-11-12")
        XCTAssertEqual(DayWords.withWeekday(moment, calendar: stockholm), "Thursday 2026-11-12")
        XCTAssertEqual(DayWords.time(moment, calendar: stockholm), "14:30")
        XCTAssertEqual(DayWords.time(moment, seconds: true, calendar: stockholm), "14:30:05")
        XCTAssertEqual(DayWords.plainWithTime(moment, calendar: stockholm), "2026-11-12 14:30")

        // A daily and a weekly note are named the same way.
        XCTAssertEqual(Note.dailyTitle(for: day), "Thursday 2026-11-12")
    }
}
