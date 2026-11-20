import XCTest
@testable import ParagonCore

final class TaskEnergyTests: XCTestCase {
    func testOneEnergyAtATimeAndTheFilterAndTheGuard() {
        let task = TaskParser.parse(line: "- [ ] Write the report #easy #travel")!
        XCTAssertEqual(task.energy, .easy)

        let hard = task.settingEnergy(.hard)
        XCTAssertEqual(hard.energy, .hard)
        XCTAssertTrue(hard.tags.contains("travel"))
        XCTAssertFalse(hard.tags.contains("easy"))
        XCTAssertEqual(hard.title, "Write the report #travel #hard")

        // The same choice again changes nothing; None takes it off.
        XCTAssertEqual(hard.settingEnergy(.hard), hard)
        XCTAssertNil(hard.settingEnergy(nil).energy)
        XCTAssertEqual(hard.settingEnergy(nil).title, "Write the report #travel")

        let refs = [
            TaskRef(notePath: "A.md", noteTitle: "A", task: task),
            TaskRef(notePath: "A.md", noteTitle: "A", task: hard),
            TaskRef(notePath: "A.md", noteTitle: "A", task: TaskParser.parse(line: "- [ ] Plain")!),
        ]
        let today = DateOnly("2026-11-20")!
        XCTAssertEqual(ActionFilter(energies: [.hard]).apply(to: refs, today: today).count, 1)
        XCTAssertEqual(ActionFilter(energies: [.easy, .hard]).apply(to: refs, today: today).count, 2)
        XCTAssertEqual(ActionFilter().apply(to: refs, today: today).count, 3)
        XCTAssertFalse(ActionFilter(energies: [.easy]).isEmpty)

        // The three have a box of their own, so they are not offered as tags too.
        XCTAssertEqual(ActionFilter.tagChoices(among: refs), ["travel"])
        XCTAssertTrue(TaskEnergy.isEnergyTag("#Hard"))
        XCTAssertFalse(TaskEnergy.isEnergyTag("travel"))
    }
}
