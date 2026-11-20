import XCTest
@testable import ParagonCore

final class LeadingEmojiTests: XCTestCase {
    func testAnEmojiAtTheStartStandsApart() {
        let split = LeadingEmoji.split("🌳 Keep living (curious, interested)")
        XCTAssertEqual(split.emoji, "🌳")
        XCTAssertEqual(split.rest, "Keep living (curious, interested)")
        XCTAssertEqual(LeadingEmoji.split("🥾Be able to hike").emoji, "🥾")
    }

    func testOrdinaryNamesStayWhole() {
        XCTAssertNil(LeadingEmoji.split("Projects with no goal").emoji)
        XCTAssertNil(LeadingEmoji.split("3D Fjölhållare").emoji)
        XCTAssertNil(LeadingEmoji.split("#tag first").emoji)
        XCTAssertEqual(LeadingEmoji.split("🌳").rest, "🌳")
    }
}
