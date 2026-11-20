import XCTest
@testable import ParagonCore

final class SmallStepsTests: XCTestCase {
    func testTheShareOfTickedDirectSubtasksIgnoresCancelledAndDeeperOnes() {
        let text = """
        - [ ] Plan the trip
          - [x] Book the train
          - [ ] Book the hotel
            - [x] Compare prices
          - [-] Rent a car
          - [x] Buy a map
        - [ ] Other task
        """
        let tasks = TaskParser.parse(text: text)
        let parent = tasks[0]
        let steps = SmallSteps.of(parent, in: tasks)
        XCTAssertEqual(steps.done, 2)
        XCTAssertEqual(steps.total, 3)
        XCTAssertEqual(steps.text, "2/3")
        XCTAssertEqual(steps.fraction ?? 0, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertFalse(steps.isComplete)
        XCTAssertNil(SmallSteps.of(tasks.last!, in: tasks).fraction)
        XCTAssertNil(SmallSteps.of(tasks.last!, in: tasks).text)
    }
}
