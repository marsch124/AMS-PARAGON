import XCTest
@testable import ParagonCore

/// Build 366: the live page comes up for a running recording, keeps the screen lit while it
/// records and writes, and says where the thought went.
final class VoiceLivePageTests: XCTestCase {
    func testOnlyARunningRecordingBringsThePageUp() {
        XCTAssertTrue(VoiceLivePage.comesUp(.preparing, hidden: false))
        XCTAssertTrue(VoiceLivePage.comesUp(.listening, hidden: false))
        // Hide is respected for the rest of that recording.
        XCTAssertFalse(VoiceLivePage.comesUp(.listening, hidden: true))
        // The later states stay where the page is; they never raise it by themselves.
        XCTAssertFalse(VoiceLivePage.comesUp(.writing, hidden: false))
        XCTAssertFalse(VoiceLivePage.comesUp(.saved, hidden: false))
        XCTAssertFalse(VoiceLivePage.comesUp(.nothing, hidden: false))
    }

    func testTheScreenStaysLitWhileItRecordsAndTwoMinutesAfter() {
        XCTAssertTrue(VoiceLivePage.keepsScreenLit(.preparing, secondsSinceEnd: 0))
        XCTAssertTrue(VoiceLivePage.keepsScreenLit(.listening, secondsSinceEnd: 0))
        // A long recording: the time since the end does not matter while it runs.
        XCTAssertTrue(VoiceLivePage.keepsScreenLit(.listening, secondsSinceEnd: 5000))
        XCTAssertTrue(VoiceLivePage.keepsScreenLit(.writing, secondsSinceEnd: 5000))
        XCTAssertTrue(VoiceLivePage.keepsScreenLit(.saved, secondsSinceEnd: 0))
        XCTAssertTrue(VoiceLivePage.keepsScreenLit(.saved, secondsSinceEnd: 119))
        XCTAssertFalse(VoiceLivePage.keepsScreenLit(.saved, secondsSinceEnd: 120))
        XCTAssertFalse(VoiceLivePage.keepsScreenLit(.nothing, secondsSinceEnd: 121))
        XCTAssertEqual(VoiceLivePage.litAfterEnd, 120)
    }

    func testThePageSaysWhereTheThoughtWent() {
        XCTAssertEqual(VoiceLivePage.recordedLine(length: "1:12", intoToday: false), "Recorded 1:12 · saved to the Inbox")
        XCTAssertEqual(VoiceLivePage.recordedLine(length: "0:42", intoToday: true), "Recorded 0:42 · saved to today’s note")
        XCTAssertEqual(VoiceLivePage.recordedLine(length: "", intoToday: false), "Saved to the Inbox")
        XCTAssertEqual(VoiceLivePage.tasksHeading(0), "No tasks found")
        XCTAssertEqual(VoiceLivePage.tasksHeading(1), "1 task found")
        XCTAssertEqual(VoiceLivePage.tasksHeading(3), "3 tasks found")
        XCTAssertEqual(VoiceLivePage.tasksHint(intoToday: false), "Switch off a task you do not want. It is taken out of the Inbox.")
        XCTAssertEqual(VoiceLivePage.tasksHint(intoToday: true), "Switch off a task you do not want. It is taken out of today’s note.")
        XCTAssertTrue(VoiceLivePage.summaryStandIn(late: true).hasPrefix("The summary is still being written."))
        XCTAssertEqual(VoiceLivePage.summaryStandIn(late: false), "No summary. It needs Apple Intelligence.")
    }

    func testThePageShowsMoreWordsThanTheLockScreenCard() {
        let long = Array(repeating: "word", count: 400).joined(separator: " ")
        let card = VoiceThought.liveTail(long)
        let page = VoiceThought.liveTail(long, limit: VoiceLivePage.lettersShown)
        XCTAssertLessThanOrEqual(card.count, 111)
        XCTAssertGreaterThan(page.count, 600)
        XCTAssertLessThanOrEqual(page.count, VoiceLivePage.lettersShown + 1)
        XCTAssertTrue(page.hasPrefix("…"))
        // A short thought is shown whole.
        XCTAssertEqual(VoiceThought.liveTail("Water the plants", limit: VoiceLivePage.lettersShown), "Water the plants")
    }
}
