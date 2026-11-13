import XCTest
@testable import ParagonCore

/// Round 9, part B (build 316), the polish sweep: one small test for each new rule.
final class Round9BTests: XCTestCase {
    /// The 13 day shades of the parts, as written in the colour sets.
    private let dayShades: [UInt32] = [0x5E7D12, 0x2E7D5B, 0xC2417C, 0x2C6FB5, 0x8F6E10, 0xC05E0C, 0x1E7F84,
                                       0x6B4EA8, 0x4B7F9E, 0xD4640A, 0x6E3A86, 0x8A5A12, 0x6E6E73]

    func testADateInAHelpHeadingIsWrittenAsEverywhereElse() {
        XCTAssertEqual(HelpDates.plain("Build 315 · 13 November 2026"), "Build 315 · 2026-11-13")
        XCTAssertEqual(HelpDates.plain("Builds 123 to 126 · 5 September 2026"), "Builds 123 to 126 · 2026-09-05")
        XCTAssertEqual(HelpDates.plain("Builds 63 to 65 · 7-8 September 2026"),
                       "Builds 63 to 65 · 2026-09-07 to 2026-09-08")
        XCTAssertEqual(HelpDates.plain("Looking back"), "Looking back")
    }

    func testTheVaultFolderIsNamedInPlainWords() {
        XCTAssertEqual(VaultPlaceWords.line(path: "/Users/m/Library/Mobile Documents/com~apple~CloudDocs/My Vault",
                                            device: "this Mac"), "My Vault · in iCloud Drive")
        XCTAssertEqual(VaultPlaceWords.line(path: "/Users/m/Dropbox/Notes", device: "this Mac"), "Notes · in Dropbox")
        XCTAssertEqual(VaultPlaceWords.line(path: "/Users/m/Documents/Vault", device: "this Mac"), "Vault · on this Mac")
    }

    func testWhiteWordsReadAlongTheWholeDayBand() {
        for hex in dayShades {
            let day = Shade(hex: hex)
            XCTAssertGreaterThanOrEqual(ShadeRule.bandDayStart(day: day).contrast(with: .white), 4.5, String(hex, radix: 16))
            XCTAssertGreaterThan(ShadeRule.bandDayEnd(day: day).contrast(with: .white),
                                 ShadeRule.bandDayStart(day: day).contrast(with: .white))
        }
        // A shade that already reads well is not touched.
        XCTAssertEqual(ShadeRule.bandDayStart(day: Shade(hex: 0x6B4EA8)).hex, 0x6B4EA8)
    }

    func testAttentionWordsReadOnWhiteAndOnThePage() {
        let ink = ShadeRule.ink(day: Shade(hex: 0xD4640A))
        XCTAssertGreaterThanOrEqual(ink.contrast(with: .white), 4.5)
        XCTAssertGreaterThanOrEqual(ink.contrast(with: Shade(hex: 0xF3F5F8)), 4.5)
    }

    func testAnIPhoneCardIsStrongerByDayOnly() {
        XCTAssertEqual(ShadeRule.tintShare(night: false, phone: true), 0.12)
        XCTAssertEqual(ShadeRule.tintShare(night: false, phone: false), 0.07)
        XCTAssertEqual(ShadeRule.tintShare(night: true, phone: true), 0.13)
        // The settings card: #F5F3F9 before, #EDEAF5 now, on the page #F3F5F8.
        let card = Shade(hex: 0x6B4EA8).over(.white, strength: ShadeRule.tintShare(night: false, phone: true))
        XCTAssertEqual(card.hex, 0xEDEAF5)
    }

    func testAnActionWithABlockIsPlanned() {
        XCTAssertTrue(NowAndNext.isPlanned("Book the night train", among: ["Lunch", "book the  night train"]))
        XCTAssertFalse(NowAndNext.isPlanned("Book the night train", among: ["Lunch"]))
        XCTAssertFalse(NowAndNext.isPlanned("", among: [""]))
    }
}
