import XCTest
@testable import ParagonCore

/// Build 332: the search field in **File it**.
final class FilingSearchTests: XCTestCase {
    private func place(_ title: String) -> FilingOrder.Place {
        FilingOrder.Place(path: "Projects/\(title).md", title: title)
    }

    private var places: [FilingOrder.Place] {
        ["Plan the Kungsleden trip", "Norrköping flat", "Boat", "Sell the old boat", "Home"].map(place)
    }

    func testEmptyQueryKeepsEverythingInOrder() {
        XCTAssertEqual(FilingOrder.matching(places, ""), places)
        XCTAssertEqual(FilingOrder.matching(places, "   "), places)
    }

    func testEveryWordMustMatch() {
        XCTAssertEqual(FilingOrder.matching(places, "old boat").map(\.title), ["Sell the old boat"])
        XCTAssertTrue(FilingOrder.matching(places, "old house").isEmpty)
    }

    func testCapitalsAndAccentsAreIgnored() {
        XCTAssertEqual(FilingOrder.matching(places, "NORRKOP").map(\.title), ["Norrköping flat"])
        XCTAssertEqual(FilingOrder.matching(places, "kungsleden TRIP").count, 1)
    }

    func testAWordThatBeginsWithTheQueryComesFirst() {
        let list = ["Sell the old boat", "Boat"].map(place)
        XCTAssertEqual(FilingOrder.matching(list, "boa").map(\.title), ["Sell the old boat", "Boat"])
        let mixed = ["Sailboat", "Boat club"].map(place)
        XCTAssertEqual(FilingOrder.matching(mixed, "boat").map(\.title), ["Boat club", "Sailboat"])
    }

    func testOfferFiltersBothGroups() {
        let offer = FilingOrder.Offer(suggested: [place("Boat"), place("Home")],
                                      recent: [place("Sell the old boat"), place("Home")])
        let found = offer.matching("boat")
        XCTAssertEqual(found.suggested.map(\.title), ["Boat"])
        XCTAssertEqual(found.recent.map(\.title), ["Sell the old boat"])
        XCTAssertEqual(offer.matching(" "), offer)
    }
}
