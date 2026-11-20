import XCTest
@testable import ParagonCore

final class YearReviewTests: XCTestCase {
    private func note(_ kind: ParaKind, _ folder: String, _ title: String, _ front: String, _ body: String) -> Note {
        Note(relativePath: "\(folder)/\(title).md", kind: kind,
             text: "---\ntitle: \(title)\ntype: \(kind.rawValue)\n\(front)---\n# \(title)\n\n\(body)")
    }

    func testAYearCountsGoalsProjectsAndTasksByMonth() {
        let project = note(.project, "Projects", "Shed", "status: done\nended: 2026-03-14\n", """
        - [x] Pour the base @done(2026-03-02 09:10)
        - [x] Raise the walls @done(2026-03-15 16:00)
        - [x] Paint @done(2026-05-01 10:00)
        - [x] Last year @done(2025-12-31 10:00)
        - [x] Ticked with no stamp
        - [-] Cancelled @done(2026-03-20 10:00)
        """)
        let oldProject = note(.project, "Projects", "Old", "status: done\nended: 2025-06-01\n", "")
        let undated = note(.project, "Projects", "Undated", "status: done\n", "")
        let goal = note(.goal, "Goals", "Build a home", "horizon: year\nstatus: done\nended: 2026-11-01\n", "")
        let aspiration = note(.goal, "Goals", "Be strong", "horizon: life\nstatus: done\nended: 2026-11-02\n", "")
        let index = NoteIndex(notes: [project, oldProject, undated, goal, aspiration])

        let review = index.yearReview(for: 2026)
        XCTAssertEqual(review.projects.map(\.title), ["Shed"])
        XCTAssertEqual(review.goals.map(\.title), ["Build a home"])
        XCTAssertEqual(review.tasksByMonth, [0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(review.tasksDone, 3)
        XCTAssertEqual(review.busiestMonth, 3)
        XCTAssertEqual(review.busiestText, "March, with 2 tasks")
        XCTAssertEqual(review.tasksText, "3 tasks done")
        XCTAssertFalse(review.isEmpty)

        XCTAssertTrue(index.yearReview(for: 2024).isEmpty)
        XCTAssertNil(index.yearReview(for: 2024).busiestMonth)
        XCTAssertEqual(index.yearRange(today: DateOnly(year: 2026, month: 11, day: 20)), 2025...2026)
    }
}
