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

    /// Round 352: what he left open last time is what the next visit starts with; the first
    /// part with something to do opens by itself only while nothing is remembered.
    func testTheReviewStartsWithThePartsHeLeftOpen() {
        let parts = [ReviewOpening.Part("due", toDo: 0), .init("1", toDo: 0), .init("2", toDo: 3),
                     .init("5", toDo: 1), .init("8", toDo: nil)]
        // Nothing remembered yet: the first part with something to do.
        XCTAssertEqual(ReviewOpening.openAtStartOfVisit(parts: parts, leftOpen: ["6"], chosenByHand: false), ["2"])
        // He chose before: exactly what he left open, even a part with nothing to do.
        XCTAssertEqual(ReviewOpening.openAtStartOfVisit(parts: parts, leftOpen: ["5", "8"], chosenByHand: true), ["5", "8"])
        // He folded them all: all stay folded.
        XCTAssertEqual(ReviewOpening.openAtStartOfVisit(parts: parts, leftOpen: [], chosenByHand: true), [])
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

    /// Build 338: while picking on Today the explanation is behind its info mark from the first
    /// time; Close the day keeps its three showings.
    func testWhilePickingTheExplanationIsNeverShownByItself() {
        for opens in 1...5 {
            XCTAssertFalse(HintRule.showsByItself(opens: opens, place: .picking),
                           "Start number \(opens) shows the picking explanation by itself.")
        }
        XCTAssertTrue(HintRule.showsByItself(opens: 1, place: .closeDay))
        XCTAssertFalse(HintRule.showsByItself(opens: 4, place: .closeDay))
    }

    /// Build 331: the loose tasks became step 3, so a remembered old number opens the same step.
    func testRememberedOpenPartsFollowTheRenumberedSteps() {
        XCTAssertEqual(ReviewOpening.renumberedForLooseStepFirst("due\n2\n3\n8\n9\nnoGoal"),
                       "due\n2\n4\n9\n3\nnoGoal")
    }
}
