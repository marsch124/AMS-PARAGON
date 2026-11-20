import XCTest
@testable import ParagonCore

/// Build 329: the start screen waits for a tap, and steps aside for everything sent by name.
final class StartScreenRuleTests: XCTestCase {
    func testOnlyAStartByHandShowsIt() {
        for opening in StartScreenRule.Opening.allCases {
            XCTAssertEqual(StartScreenRule.shows(opening), opening == .byHand, "\(opening)")
        }
    }

    func testTheLinesSayTheDayAndWhatIsWaiting() {
        XCTAssertEqual(StartScreenRule.dayLine(DateOnly(year: 2026, month: 11, day: 16)), "Monday 2026-11-16")
        // Build 346: day and date on their own lines, due and Inbox on their own lines.
        let friday = DateOnly(year: 2026, month: 11, day: 20)
        XCTAssertEqual(StartScreenRule.weekdayLine(friday), "Friday")
        XCTAssertEqual(StartScreenRule.dateLine(friday), "2026-11-20")
        XCTAssertEqual(StartScreenRule.dueLine(3), "3 due today")
        XCTAssertEqual(StartScreenRule.dueLine(0), "Nothing due today")
        XCTAssertEqual(StartScreenRule.inboxLine(1), "1 in the Inbox")
        XCTAssertEqual(StartScreenRule.inboxLine(0), "Inbox empty")
        XCTAssertEqual(StartScreenRule.versionLine(version: "1.0", build: 329), "1.0 (329)")
    }
}
