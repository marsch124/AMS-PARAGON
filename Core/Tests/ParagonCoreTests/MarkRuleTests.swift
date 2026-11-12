import XCTest
@testable import ParagonCore

final class MarkRuleTests: XCTestCase {
    func testTheSizeBesideEachTextStyle() {
        let table: [MarkRule.TextStyle: Double] = [
            .largeTitle: 32, .title: 26, .title2: 21, .title3: 19, .headline: 16, .body: 16,
            .callout: 15, .subheadline: 14, .footnote: 12, .caption: 12, .caption2: 11,
        ]
        XCTAssertEqual(table.count, MarkRule.TextStyle.allCases.count)
        for style in MarkRule.TextStyle.allCases {
            XCTAssertEqual(MarkRule.size(for: style), table[style], "\(style)")
        }
    }

    func testSixteenPointsAndUpKeepTheLine() {
        for size in [16.0, 17, 18, 24, 32, 60] {
            XCTAssertEqual(MarkRule.lineWidth(forSize: size), 1.9, "\(size)")
        }
    }

    func testASmallMarkIsNeverThinnerThanTheFloor() {
        for size in [8.0, 9, 10, 11, 12, 13, 14, 15, 15.5] {
            let onScreen = MarkRule.lineWidth(forSize: size) * size / 24
            XCTAssertGreaterThanOrEqual(onScreen, 1.3 - 1e-9, "\(size)")
            XCTAssertLessThanOrEqual(onScreen, 1.3 + 1e-9, "\(size)")
        }
        XCTAssertEqual(MarkRule.lineWidth(forSize: 9) * 9 / 24, 1.3, accuracy: 1e-9)
        XCTAssertEqual(MarkRule.lineWidth(forSize: 0), 1.9)
    }
}
