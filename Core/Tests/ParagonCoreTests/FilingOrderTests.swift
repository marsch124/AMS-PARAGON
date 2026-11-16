import XCTest
@testable import ParagonCore

/// Build 331: the places **File it** offers first.
final class FilingOrderTests: XCTestCase {
    private func place(_ title: String) -> FilingOrder.Place {
        FilingOrder.Place(path: "Projects/\(title).md", title: title)
    }

    private var places: [FilingOrder.Place] {
        ["Plan the Kungsleden trip", "Fix the bike", "Sell the old boat", "Paint the fence",
         "Health", "Home", "Money", "Boat"].map(place)
    }

    func testSuggestedByTellingWordsThenRecentThenNothingTwice() {
        let recent = ["Money", "Boat", "Gone long ago", "Health", "Home"].map { place($0).path }
        let offer = FilingOrder.offer(for: "Book the ferry for the Kungsleden trip #next",
                                      places: places, recentPaths: recent)
        // "the" and "for" are little words: only the trip shares telling words.
        XCTAssertEqual(offer.suggested.map(\.title), ["Plan the Kungsleden trip"])
        // Newest first, at most three, and a place that no longer exists is passed over.
        XCTAssertEqual(offer.recent.map(\.title), ["Money", "Boat", "Health"])

        // Most shared words first, a plural counts as its word, at most two — and a
        // suggested place is not shown again under Recent.
        let boats = FilingOrder.offer(for: "Sell both old boats", places: places,
                                      recentPaths: [place("Boat").path, place("Money").path])
        XCTAssertEqual(boats.suggested.map(\.title), ["Sell the old boat", "Boat"])
        XCTAssertEqual(boats.recent.map(\.title), ["Money"])
    }

    func testAShortListGetsNoGroupsAndTheMemoryStaysShort() {
        let few = Array(places.prefix(FilingOrder.shortList))
        let offer = FilingOrder.offer(for: "Fix the bike bell", places: few,
                                      recentPaths: [few[0].path])
        XCTAssertTrue(offer.isEmpty, "Six places or fewer: the list is its own shortcut.")

        var remembered: [String] = []
        for n in 0..<12 { remembered = FilingOrder.remembering("p\(n)", in: remembered) }
        remembered = FilingOrder.remembering("p7", in: remembered)
        XCTAssertEqual(remembered.count, FilingOrder.rememberedLimit)
        XCTAssertEqual(remembered.first, "p7")
        XCTAssertEqual(remembered.filter { $0 == "p7" }.count, 1)
    }
}
