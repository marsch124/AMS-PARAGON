import XCTest
@testable import ParagonCore

/// Build 310, the colours round: which step of a part's colour is drawn where.
final class ShadeRuleTests: XCTestCase {
    /// Every part's day shade, as written in the colour sets.
    private let days: [String: UInt32] = [
        "Project": 0x2E7D5B, "Area": 0xC2417C, "Resource": 0x2C6FB5, "Archive": 0x6E6E73,
        "Goal": 0x8F6E10, "Aspiration": 0x8A5A12, "Inbox": 0x5E7D12, "Calendar": 0x6B4EA8,
        "Review": 0x1E7F84, "Plan": 0xC05E0C, "Morning": 0xD4640A, "Evening": 0x6E3A86,
        "Now": 0x4B7F9E,
    ]

    func testWhiteWordsReadOnEveryGround() {
        for (name, hex) in days {
            let ground = ShadeRule.ground(day: Shade(hex: hex))
            XCTAssertGreaterThanOrEqual(ground.contrast(with: .white), 4.0, name)
            XCTAssertGreaterThanOrEqual(ShadeRule.bandEnd(ground: ground).contrast(with: .white), 4.5, name)
        }
        // The morning orange is the one that steps deeper: #D4640A becomes #B35300.
        let morning = ShadeRule.ground(day: Shade(hex: 0xD4640A))
        XCTAssertEqual(Double(morning.hex >> 16), Double(0xB3), accuracy: 1)
        XCTAssertGreaterThanOrEqual(morning.contrast(with: .white), 4.9)
        // A shade that is already deep is left alone.
        XCTAssertEqual(ShadeRule.ground(day: Shade(hex: 0x6E3A86)).hex, 0x6E3A86)
    }

    func testColouredWordsReadOnWhiteAndInACapsule() {
        for (name, hex) in days {
            let day = Shade(hex: hex)
            XCTAssertGreaterThanOrEqual(ShadeRule.ink(day: day).contrast(with: .white), 4.5, name)
            // A capsule is a 14 % wash of the day shade on white.
            let wash = day.over(.white, strength: 0.14)
            XCTAssertGreaterThanOrEqual(ShadeRule.capsuleWords(day: day).contrast(with: wash), 4.5, name)
            // A waiting button is a 40 % fill of the ground on white.
            let fill = ShadeRule.ground(day: day).over(.white, strength: ShadeRule.waitingFillDay)
            XCTAssertGreaterThanOrEqual(ShadeRule.waitingWords(day: day).contrast(with: fill), 3.0, name)
        }
    }

    func testTheInboxIsNoLongerThePlanOrange() {
        // Leaf green by day and night; the quiet greys keep their step.
        XCTAssertGreaterThanOrEqual(Shade(hex: 0x5E7D12).contrast(with: .white), 4.5)
        XCTAssertGreaterThanOrEqual(Shade(hex: 0x737A86).contrast(with: .white), 4.2)
        XCTAssertGreaterThanOrEqual(Shade(hex: 0x5C6470).contrast(with: .white), 5.9)
        XCTAssertGreaterThanOrEqual(Shade(hex: 0x8B93A0).contrast(with: .black), 6.5)
    }
}
