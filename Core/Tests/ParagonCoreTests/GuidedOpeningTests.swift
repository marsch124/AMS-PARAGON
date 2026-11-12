import XCTest
@testable import ParagonCore

/// Build 312: which part of the Weekly review opens by itself, and how often an explanation
/// shows before it folds away.
final class GuidedOpeningTests: XCTestCase {
    func testTheFirstPartWithSomethingToDoOpensAndHisOwnChoicesWin() {
        let parts = [ReviewOpening.Part("due", toDo: 0), .init("1", toDo: 0), .init("2", toDo: 3),
                     .init("5", toDo: 1), .init("7", toDo: nil)]
        XCTAssertEqual(ReviewOpening.open(parts: parts, byHand: ["6"], visitStarted: false), ["2"])
        // Nothing left anywhere: every part stays folded.
        let empty = [ReviewOpening.Part("due", toDo: 0), .init("1", toDo: 0), .init("7", toDo: nil)]
        XCTAssertEqual(ReviewOpening.open(parts: empty, byHand: ["6"], visitStarted: false), [])
        // During the visit his own opening and closing is respected, also "all closed".
        XCTAssertEqual(ReviewOpening.open(parts: parts, byHand: ["6"], visitStarted: true), ["6"])
        XCTAssertEqual(ReviewOpening.open(parts: parts, byHand: [], visitStarted: true), [])
        // The tick: only a part that counts things, with none left.
        XCTAssertTrue(ReviewOpening.isTicked(toDo: 0))
        XCTAssertFalse(ReviewOpening.isTicked(toDo: 2))
        XCTAssertFalse(ReviewOpening.isTicked(toDo: nil))
    }

    func testAnExplanationShowsThreeTimesThenFolds() {
        var opens = 0
        var shown: [Bool] = []
        for _ in 0..<5 {
            opens = HintRule.counting(opens)
            shown.append(HintRule.showsByItself(opens: opens))
        }
        XCTAssertEqual(shown, [true, true, true, false, false])
        XCTAssertEqual(opens, 4, "The counter stops one past the limit.")
    }
}
