import XCTest
import CoreGraphics
@testable import ParagonCore

/// Build 327: the card keeps its fill while a ticked row leaves.
final class LeavingRowRuleTests: XCTestCase {
    private func row(_ y: CGFloat, x: CGFloat = 16, noted: TimeInterval = 0) -> LeavingRowRule.Row {
        LeavingRowRule.Row(frame: CGRect(x: x, y: y, width: 370, height: 48), noted: Date(timeIntervalSince1970: noted))
    }

    func testAMiddleRowIsCoveredAndTheFirstRowGetsRoundCorners() {
        let card = [row(100), row(148), row(196)]
        let middle = LeavingRowRule.cover(at: CGPoint(x: 200, y: 170), rows: card)
        XCTAssertEqual(middle?.index, 1)
        XCTAssertEqual(middle?.frame, card[1].frame)
        XCTAssertEqual(middle?.roundsTop, false)
        XCTAssertEqual(LeavingRowRule.cover(at: CGPoint(x: 200, y: 120), rows: card)?.roundsTop, true)
    }

    func testTheLastRowOfACardIsNotCovered() {
        // The card under it starts 30 points lower: another card, so nothing touches below.
        let rows = [row(100), row(148), row(226)]
        XCTAssertNil(LeavingRowRule.cover(at: CGPoint(x: 200, y: 170), rows: rows))
        XCTAssertNil(LeavingRowRule.cover(at: CGPoint(x: 200, y: 240), rows: rows), "a card of one row")
        XCTAssertNil(LeavingRowRule.cover(at: CGPoint(x: 200, y: 600), rows: rows), "no row there")
    }

    func testTheRowNotedLastWinsAndALeftoverIsKnown() {
        let stale = row(140, noted: 1)
        let rows = [row(100, noted: 5), stale, row(148, noted: 5), row(196, noted: 5)]
        XCTAssertEqual(LeavingRowRule.cover(at: CGPoint(x: 200, y: 170), rows: rows)?.index, 2)
        XCTAssertTrue(LeavingRowRule.isLeftover(stale.frame, under: rows[2].frame))
        XCTAssertFalse(LeavingRowRule.isLeftover(rows[0].frame, under: rows[2].frame), "neighbours only touch")
    }
}
