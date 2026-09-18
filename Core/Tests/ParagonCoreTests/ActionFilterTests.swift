import XCTest
@testable import ParagonCore

/// The **All actions** filter (build 198). Every answer is pinned here, because this decides
/// what a screen leaves out and a filter nobody can test is a filter that quietly hides work.
final class ActionFilterTests: XCTestCase {
    private let today = DateOnly("2026-09-18")!

    private func ref(_ title: String,
                     due: String? = nil,
                     priority: Int = 0,
                     tags: [String] = []) -> TaskRef {
        TaskRef(notePath: "Projects/Trip.md",
                noteTitle: "Trip",
                task: TaskItem(title: title,
                               dueDate: due.flatMap { DateOnly($0) },
                               priority: priority,
                               tags: tags))
    }

    // MARK: When

    func testEachWhenBoxCatchesItsOwnDays() {
        let overdue = ref("Book the ferry", due: "2026-09-01")
        let now = ref("Pack", due: "2026-09-18")
        let soon = ref("Buy maps", due: "2026-09-22")
        let later = ref("Train", due: "2026-11-01")
        let none = ref("Think about boots")

        func kept(_ when: ActionFilter.When) -> [String] {
            ActionFilter(whens: [when])
                .apply(to: [overdue, now, soon, later, none], today: today)
                .map(\.task.title)
        }
        XCTAssertEqual(kept(.overdue), ["Book the ferry"])
        XCTAssertEqual(kept(.today), ["Pack"])
        XCTAssertEqual(kept(.soon), ["Buy maps"])
        XCTAssertEqual(kept(.later), ["Train"])
        XCTAssertEqual(kept(.noDate), ["Think about boots"])
    }

    /// The five boxes may not overlap, or two ticks would show one action twice in the count
    /// and "everything" would not add up.
    func testTheWhenBoxesDoNotOverlapAndCoverEverything() {
        let all = [ref("a", due: "2026-09-01"), ref("b", due: "2026-09-18"),
                   ref("c", due: "2026-09-19"), ref("d", due: "2026-09-25"),
                   ref("e", due: "2026-09-26"), ref("f")]
        for task in all {
            let hits = ActionFilter.When.allCases.filter { $0.matches(task.task, today: today) }
            XCTAssertEqual(hits.count, 1, "\(task.task.title) matched \(hits.map(\.label))")
        }
        let everyBox = ActionFilter(whens: Set(ActionFilter.When.allCases))
        XCTAssertEqual(everyBox.apply(to: all, today: today).count, all.count)
    }

    /// The day exactly seven days out is still "Next 7 days"; the next one is "Later".
    func testTheEdgeOfTheSevenDays() {
        XCTAssertTrue(ActionFilter.When.soon.matches(ref("x", due: "2026-09-25").task, today: today))
        XCTAssertFalse(ActionFilter.When.soon.matches(ref("x", due: "2026-09-26").task, today: today))
        XCTAssertTrue(ActionFilter.When.later.matches(ref("x", due: "2026-09-26").task, today: today))
    }

    // MARK: Marks and tags

    func testNextActionAndImportant() {
        let next = ref("Ring the hut", tags: ["next"])
        let loud = ref("Renew the pass", priority: 2)
        let plain = ref("Wash the pack")
        let filter = ActionFilter(marks: [.next])
        XCTAssertEqual(filter.apply(to: [next, loud, plain], today: today).map(\.task.title), ["Ring the hut"])
        XCTAssertEqual(ActionFilter(marks: [.important]).apply(to: [next, loud, plain], today: today)
            .map(\.task.title), ["Renew the pass"])
    }

    func testATagIsComparedWithoutItsHashOrItsCase() {
        let tagged = ref("Order the maps", tags: ["Travel"])
        let other = ref("Mend the tent", tags: ["gear"])
        let filter = ActionFilter(tags: ["#TRAVEL"])
        XCTAssertEqual(filter.apply(to: [tagged, other], today: today).map(\.task.title), ["Order the maps"])
    }

    // MARK: How the rows combine

    /// Within a row an **or**, between rows an **and** — the same rule as the Search screen's
    /// boxes (build 157), so a tick cannot mean two different things in two places.
    func testWithinARowIsOrAndBetweenRowsIsAnd() {
        let a = ref("Overdue and next", due: "2026-09-01", tags: ["next"])
        let b = ref("Overdue only", due: "2026-09-02")
        let c = ref("Today and next", due: "2026-09-18", tags: ["next"])
        let d = ref("Later and next", due: "2026-11-01", tags: ["next"])
        let refs = [a, b, c, d]

        XCTAssertEqual(ActionFilter(whens: [.overdue, .today]).apply(to: refs, today: today).count, 3)
        let both = ActionFilter(whens: [.overdue, .today], marks: [.next])
        XCTAssertEqual(both.apply(to: refs, today: today).map(\.task.title),
                       ["Overdue and next", "Today and next"])
    }

    func testNothingTickedKeepsEverything() {
        let refs = [ref("a", due: "2026-09-01"), ref("b")]
        let filter = ActionFilter()
        XCTAssertTrue(filter.isEmpty)
        XCTAssertEqual(filter.apply(to: refs, today: today).count, 2)
    }

    // MARK: The boxes offered

    func testTagChoicesAreTheOnesInUseWithoutNext() {
        let refs = [ref("a", tags: ["Travel", "next"]), ref("b", tags: ["gear"]), ref("c")]
        XCTAssertEqual(ActionFilter.tagChoices(among: refs), ["gear", "travel"])
    }

    /// Build 175's rule: a control may never show nothing chosen. A ticked tag whose last
    /// action another row has ruled out must keep its box, or it cannot be unticked.
    func testATickedTagKeepsItsBoxEvenWhenNothingCarriesIt() {
        XCTAssertEqual(ActionFilter.tagChoices(among: [ref("a")], including: ["travel"]), ["travel"])
    }

    // MARK: What the folded line says

    func testTheSummaryIsNeverEmpty() {
        XCTAssertEqual(ActionFilter().summary, "Every open action")
    }

    func testTheSummaryNamesEveryRowInOrder() {
        let filter = ActionFilter(whens: [.today, .overdue], marks: [.next], tags: ["travel"])
        XCTAssertEqual(filter.summary, "Overdue or Today · Next action · #travel")
    }
}
