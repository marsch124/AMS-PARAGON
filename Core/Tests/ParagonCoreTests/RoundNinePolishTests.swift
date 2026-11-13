import XCTest
@testable import ParagonCore

/// Round 9 (build 316), the designer's list: the small rules behind the polish.
final class RoundNinePolishTests: XCTestCase {
    func testEveryLineKeepsTheCountInReachAndSaysTheUnitInWords() {
        XCTAssertEqual(RepeatEvery.clamped(0), 1)
        XCTAssertEqual(RepeatEvery.clamped(14), 14)
        XCTAssertEqual(RepeatEvery.clamped(5000), 999)
        XCTAssertEqual(RepeatEvery.word(.week, count: 1), "week")
        XCTAssertEqual(RepeatEvery.word(.week, count: 2), "weeks")
        XCTAssertEqual(RepeatEvery.units, [.day, .week, .month, .year])
    }

    func testTheRestoreLineKeepsFromDayAndTimeTogether() {
        let line = RestoreResult(written: 19, failed: [], notes: 16).line(stamp: "2026-11-13 16:14")
        XCTAssertEqual(line, "Restored 16 notes and 3 other files from\u{00A0}2026-11-13\u{00A0}16:14")
        XCTAssertTrue(RestoreResult.lineSaysAllWentWell(line))
        XCTAssertFalse(RestoreResult.lineSaysAllWentWell(RestoreResult(written: 2, failed: ["a.md"], notes: 2).line(stamp: "2026-11-13 16:14")))
        XCTAssertTrue(RestoreResult(written: 19, failed: [], notes: 16).isComplete)
    }

    func testTheSecondLineOfAProjectNeverStartsWithADot() {
        let lines = SecondLine.split(first: ["Next: Define the outcome and the first step"],
                                     rest: ["Walk the Kungsleden in one go"])
        XCTAssertEqual(lines.one, "Next: Define the outcome and the first step \u{00B7} Walk the Kungsleden in one go")
        XCTAssertEqual(lines.upper, "Next: Define the outcome and the first step")
        XCTAssertEqual(lines.lower, "Walk the Kungsleden in one go")
        XCTAssertNil(SecondLine.split(first: ["No tasks yet"], rest: []).lower)
    }

    func testAReviewHeadingShowsItsCountOrItsTickNeverBoth() {
        XCTAssertEqual(ReviewOpening.heading("3. Read the aspirations again", count: 1, toDo: 0), "3. Read the aspirations again")
        XCTAssertEqual(ReviewOpening.heading("1. Empty the inbox", count: 4, toDo: 4), "1. Empty the inbox \u{00B7} 4")
        XCTAssertEqual(ReviewOpening.heading("7. Look back", count: 0, toDo: nil), "7. Look back")
    }
}
