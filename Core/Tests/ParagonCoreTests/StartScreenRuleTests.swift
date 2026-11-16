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
        XCTAssertEqual(StartScreenRule.waitingLine(due: 3, inbox: 1), "3 due today  \u{00B7}  1 in the Inbox")
        XCTAssertEqual(StartScreenRule.waitingLine(due: 0, inbox: 0), "Nothing due today  \u{00B7}  Inbox empty")
        XCTAssertEqual(StartScreenRule.hint(mac: false), "Tap to start")
        XCTAssertEqual(StartScreenRule.hint(mac: true), "Click or press a key to start")
        XCTAssertEqual(StartScreenRule.versionLine(version: "1.0", build: 329), "1.0 (329)")
    }
}
