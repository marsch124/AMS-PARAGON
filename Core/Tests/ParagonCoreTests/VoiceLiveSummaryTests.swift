import XCTest
@testable import ParagonCore

/// Build 363: key points while you speak — when the model is asked, and what the card shows.
final class VoiceLiveSummaryTests: XCTestCase {
    func testTheFirstAskWaitsForThirtyWordsAndTheNextForMoreWordsAndTime() {
        // Before the first ask: only the words count.
        XCTAssertFalse(VoiceLiveSummary.isDue(words: 29, askedAtWords: nil, sinceAsk: nil, busy: false))
        XCTAssertTrue(VoiceLiveSummary.isDue(words: 30, askedAtWords: nil, sinceAsk: nil, busy: false))
        // Afterwards: 25 more words AND 20 seconds.
        XCTAssertFalse(VoiceLiveSummary.isDue(words: 54, askedAtWords: 30, sinceAsk: 60, busy: false))
        XCTAssertFalse(VoiceLiveSummary.isDue(words: 80, askedAtWords: 30, sinceAsk: 19, busy: false))
        XCTAssertTrue(VoiceLiveSummary.isDue(words: 55, askedAtWords: 30, sinceAsk: 20, busy: false))
        // One ask at a time, and none after three in a row without an answer.
        XCTAssertFalse(VoiceLiveSummary.isDue(words: 200, askedAtWords: 30, sinceAsk: 60, busy: true))
        XCTAssertFalse(VoiceLiveSummary.isDue(words: 200, askedAtWords: 30, sinceAsk: 60, busy: false, failures: 3))
        XCTAssertTrue(VoiceLiveSummary.isDue(words: 200, askedAtWords: 30, sinceAsk: 60, busy: false, failures: 2))
        XCTAssertEqual(VoiceLiveSummary.wordCount("  The drawer\nneeds   new screws. "), 5)
    }

    func testTheAnswerIsTidiedForTheCard() {
        let raw = ["- Hall drawer needs new screws.", "2. Call Anna about Saturday", "", "• call anna about saturday",
                   "Decide between the lake and staying home this weekend because the weather may turn", "A fourth point"]
        let points = VoiceLiveSummary.points(raw)
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0], "Hall drawer needs new screws")
        XCTAssertEqual(points[1], "Call Anna about Saturday")
        // The long one is cut at a whole word and fits one line.
        XCTAssertTrue(points[2].hasSuffix("…"))
        XCTAssertLessThanOrEqual(points[2].count, VoiceLiveSummary.longestPoint)
        XCTAssertTrue(points[2].hasPrefix("Decide between the lake"))
        XCTAssertEqual(VoiceLiveSummary.points(["", "  ", "-"]), [])
        // A year at the start is not a list number.
        XCTAssertEqual(VoiceLiveSummary.points(["2027 budget is open"]), ["2027 budget is open"])
    }

    func testALongRecordingIsSummedUpFromItsNewestPartAndTheCardSummaryIsOneParagraph() {
        let long = String(repeating: "word ", count: 2000) + "the end"
        let given = VoiceLiveSummary.textToSumUp(long)
        XCTAssertLessThanOrEqual(given.count, VoiceLiveSummary.mostLetters)
        XCTAssertTrue(given.hasSuffix("the end"))
        XCTAssertTrue(given.hasPrefix("word"))
        XCTAssertEqual(VoiceLiveSummary.textToSumUp("  Short  note. "), "Short note.")

        XCTAssertEqual(VoiceLiveSummary.cardSummary(nil), "")
        XCTAssertEqual(VoiceLiveSummary.cardSummary("The drawer needs screws.\nAnna is to be called."), "The drawer needs screws. Anna is to be called.")
        let cut = VoiceLiveSummary.cardSummary(String(repeating: "many words ", count: 60))
        XCTAssertLessThanOrEqual(cut.count, VoiceLiveSummary.longestCardSummary)
        XCTAssertTrue(cut.hasSuffix("…"))
        XCTAssertEqual(VoiceLiveSummary.cardStays, 14_400)
    }
}
