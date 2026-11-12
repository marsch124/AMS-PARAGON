import XCTest
@testable import ParagonCore

final class BrowseRuleTests: XCTestCase {
    /// The strip on Browse shows the five notes opened last, in their order; fewer when
    /// fewer were opened, and none at all (so no strip) when nothing was.
    func testTheRecentStripShowsFiveAtMostAndNothingWhenEmpty() {
        XCTAssertEqual(BrowseRule.recentStrip(["a", "b", "c", "d", "e", "f", "g"]), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(BrowseRule.recentStrip(["a", "b"]), ["a", "b"])
        XCTAssertTrue(BrowseRule.recentStrip([String]()).isEmpty)
    }
}
