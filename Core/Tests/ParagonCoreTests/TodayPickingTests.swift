import XCTest
@testable import ParagonCore

/// Build 335: **Start turns Today into picking.**
final class TodayPickingTests: XCTestCase {
    private struct Row { let path: String; let title: String }
    private func key(_ row: Row) -> String { TodayPicking.key(notePath: row.path, title: row.title) }

    func testPickingEndsWhenTheDayChanges() {
        let monday = DateOnly(year: 2026, month: 11, day: 16)
        let tuesday = DateOnly(year: 2026, month: 11, day: 17)
        XCTAssertFalse(TodayPicking.isOn(since: nil, today: tuesday))
        XCTAssertTrue(TodayPicking.isOn(since: tuesday, today: tuesday))
        XCTAssertFalse(TodayPicking.isOn(since: monday, today: tuesday),
                       "Picks made yesterday are not today's picks.")
    }

    func testThePickedOnesComeInTheListsOrderEachOnceAndOnlyWhileShown() {
        let bank = Row(path: "Areas/Money.md", title: "Call the bank")
        let train = Row(path: "Projects/Trip.md", title: "Book the night train")
        let tyres = Row(path: "Areas/Car.md", title: "Order new tyres")
        let gone = TodayPicking.key(notePath: "Areas/Car.md", title: "Ticked meanwhile")
        let picks: Set<String> = [key(tyres), key(bank), gone]
        // The bank is on the list twice (say under Next actions and under Overdue).
        let chosen = TodayPicking.chosen(picks, in: [bank, train, tyres, bank], key: key)
        XCTAssertEqual(chosen.map(\.title), ["Call the bank", "Order new tyres"])
    }

    func testTheButtonSaysHowManyAndIsNotThereWithNothingPicked() {
        XCTAssertNil(TodayPicking.planTitle(picked: 0))
        XCTAssertEqual(TodayPicking.planTitle(picked: 1), "Plan 1 action")
        XCTAssertEqual(TodayPicking.planTitle(picked: 3), "Plan 3 actions")
    }

    func testATaskMarkedFirstIsNotDrawnASecondTimeBelow() {
        let bank = Row(path: "Areas/Money.md", title: "Call the bank")
        let train = Row(path: "Projects/Trip.md", title: "Book the night train")
        let rest = TodayPicking.withoutMarked([bank, train], marked: [train], key: key)
        XCTAssertEqual(rest.map(\.title), ["Call the bank"])
    }
}
