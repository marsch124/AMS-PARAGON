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

    // Build 364: key points in the note.
    func testKeyPointsStandInTheNoteUntilTheSummaryArrives() {
        var late = VoiceThought(transcript: "the drawer needs screws and anna is to be called", recordedAt: Date(), duration: 30)
        late.summaryPending = true
        late.keyPoints = ["- Order screws for drawer.", "Call Anna about Saturday"]
        let note = late.noteText(today: .today())
        let block = "## Summary\n\nKey points while you spoke:\n- Order screws for drawer\n- Call Anna about Saturday\n\n" + VoiceThought.pendingLine + "\n\n## Full text"
        XCTAssertTrue(note.contains(block))
        XCTAssertEqual(VoiceThought.keyPoints(in: note), ["Order screws for drawer", "Call Anna about Saturday"])
        // Read back in short: the points in one line.
        XCTAssertEqual(VoiceNoteText.summary(of: note), "Order screws for drawer \u{00B7} Call Anna about Saturday")

        // The summary arrives: the points give way to it.
        let done = VoiceThought.enriched(note, summary: "The drawer needs screws.", tasks: ["Call Anna"])
        XCTAssertEqual(done?.contains("## Summary\n\nThe drawer needs screws.\n\n## Tasks\n\n- Call Anna\n\n## Full text"), true)
        XCTAssertEqual(done?.contains(VoiceThought.keyPointsLine), false)
        XCTAssertEqual(VoiceNoteText.summary(of: done ?? ""), "The drawer needs screws.")

        // No summary could be made: the points stay, the waiting line goes.
        let kept = VoiceThought.enriched(note, summary: "No summary: Apple Intelligence was not available on this phone.", tasks: [])
        XCTAssertEqual(kept?.contains("## Summary\n\nKey points while you spoke:\n- Order screws for drawer\n- Call Anna about Saturday\n\n## Full text"), true)
        XCTAssertEqual(kept?.contains("No summary"), false)

        // Points but no summary at Stop: the points are the summary. No points: as before.
        late.summaryPending = false
        let only = late.noteText(today: .today())
        XCTAssertTrue(only.contains("Key points while you spoke:\n- Order screws for drawer\n- Call Anna about Saturday\n\n## Full text"))
        XCTAssertFalse(only.contains("No summary"))
        late.keyPoints = []
        XCTAssertTrue(late.noteText(today: .today()).contains("No summary: Apple Intelligence"))
        late.summaryPending = true
        let plain = late.noteText(today: .today())
        XCTAssertTrue(plain.contains("## Summary\n\n" + VoiceThought.pendingLine + "\n\n## Full text"))
        XCTAssertEqual(VoiceThought.enriched(plain, summary: "", tasks: [])?.contains("No summary was made."), true)
    }
}
