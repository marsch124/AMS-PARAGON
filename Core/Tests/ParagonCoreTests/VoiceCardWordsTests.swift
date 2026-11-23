import XCTest
@testable import ParagonCore

/// Build 365: the Mac's recording card says what the iPhone's Lock Screen card says.
final class VoiceCardWordsTests: XCTestCase {
    func testTheMacCardSaysWhereItListensAndWhenItGoes() {
        XCTAssertEqual(VoiceCardWords.heading(.listening), "Listening · Inbox")
        XCTAssertEqual(VoiceCardWords.heading(.listening, paused: true, intoToday: true), "Paused · Today's note")
        XCTAssertEqual(VoiceCardWords.heading(.saved, intoToday: true), "Saved to today's note")
        XCTAssertEqual(VoiceCardWords.heading(.nothing), "Nothing saved")
        XCTAssertEqual(VoiceCardWords.heard(tasks: 1, marks: 2), "1 task heard · 2 marked")
        XCTAssertEqual(VoiceCardWords.heard(tasks: 0, marks: 0), "")
        XCTAssertEqual(VoiceCardWords.savedLine(title: "Hall drawer", tasks: 2), "Hall drawer · 2 tasks found")
        // The second stop button names the other place, and says that it stops.
        XCTAssertEqual(VoiceCardWords.otherPlaceButton(intoToday: false), "Stop to Today")
        XCTAssertEqual(VoiceCardWords.otherPlaceButton(intoToday: true), "Stop to Inbox")
        XCTAssertEqual(VoiceCardWords.menuTitle(recording: true), "Stop Recording")
        // It stays while it works, five minutes once saved, half a minute after nothing.
        XCTAssertNil(VoiceCardWords.stays(.listening))
        XCTAssertNil(VoiceCardWords.stays(.writing))
        XCTAssertEqual(VoiceCardWords.stays(.saved), 300)
        XCTAssertEqual(VoiceCardWords.stays(.nothing), 30)
        XCTAssertTrue(VoiceCardWords.isRunning(.preparing))
        XCTAssertFalse(VoiceCardWords.isRunning(.saved))
    }
}
