import XCTest
@testable import ParagonCore

/// Build 312: the two "quiet by default" rules of review round 6.
final class QuietRulesTests: XCTestCase {
    /// flow-19: the dashed question only in Start the day and Plan the day; a set time shows
    /// everywhere; nothing at all with task times switched off.
    func testTheTimeQuestionIsAskedOnlyWhereTheDayIsPlanned() {
        XCTAssertEqual(TaskTimePill.shown(in: .startDay, minutes: nil, usesTaskTimes: true), .question)
        XCTAssertEqual(TaskTimePill.shown(in: .plan, minutes: nil, usesTaskTimes: true), .question)
        XCTAssertEqual(TaskTimePill.shown(in: .list, minutes: nil, usesTaskTimes: true), .nothing)
        XCTAssertEqual(TaskTimePill.shown(in: .list, minutes: 45, usesTaskTimes: true), .time(45))
        XCTAssertEqual(TaskTimePill.shown(in: .startDay, minutes: 45, usesTaskTimes: true), .time(45))
        XCTAssertEqual(TaskTimePill.shown(in: .startDay, minutes: nil, usesTaskTimes: false), .nothing)
        XCTAssertEqual(TaskTimePill.shown(in: .list, minutes: 45, usesTaskTimes: false), .nothing)
    }

    /// flow-02: folded on a fresh install and once on the first start of build 312, whatever
    /// was stored; after that his own choice holds.
    func testTheSettingsBlockIsFoldedUnlessHeOpenedItAfterTheFlip() {
        XCTAssertTrue(SettingsBlockFold.isFolded(stored: nil, flipped: false))
        XCTAssertTrue(SettingsBlockFold.isFolded(stored: false, flipped: false))
        XCTAssertTrue(SettingsBlockFold.isFolded(stored: nil, flipped: true))
        XCTAssertFalse(SettingsBlockFold.isFolded(stored: false, flipped: true))
        XCTAssertTrue(SettingsBlockFold.isFolded(stored: true, flipped: true))
    }
}
