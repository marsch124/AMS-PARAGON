import XCTest
@testable import ParagonCore

/// Build 347: the two-tile card says what each tile does.
final class WhatNextCardWordsTests: XCTestCase {
    func testTheTilesSayWhatTheyDo() {
        let goal = Note(relativePath: "Goals/Walk.md", kind: .goal, text: "---\ntitle: Walk\ntype: goal\nhorizon: year\n---\n# Walk\n")
        let question = WhatNextQuestion(goal: goal, projectWasDone: true)
        XCTAssertEqual(WhatNextQuestion.cardTitle, "What is next?")
        XCTAssertEqual(question.addTileTitle, "New project")
        XCTAssertEqual(WhatNextQuestion.doneTileTitle, "Goal reached")
        XCTAssertTrue(question.offersDone)

        let life = Note(relativePath: "Goals/Life.md", kind: .goal, text: "---\ntitle: Life\ntype: goal\nhorizon: life\n---\n# Life\n")
        let asked = WhatNextQuestion(goal: life, projectWasDone: true)
        XCTAssertEqual(asked.addTileTitle, "New goal")
        XCTAssertFalse(asked.offersDone)
    }
}
