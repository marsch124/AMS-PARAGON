import XCTest
@testable import ParagonCore

final class WeeklyReviewDoneTests: XCTestCase {
    private func weeklyNote(_ week: Int, _ text: String) -> Note {
        Note(relativePath: "Calendar/\(WeekRef(year: 2026, week: week)).md", kind: .daily, text: text)
    }

    func testLateOnlyWhenTheLastReviewIsMoreThanSevenDaysOld() {
        let today = DateOnly(year: 2026, month: 11, day: 13)
        // Exactly a week ago is on time; eight days is late; never recorded is not late.
        XCTAssertFalse(WeeklyReviewDone.isLate(last: DateOnly(year: 2026, month: 11, day: 6), today: today))
        XCTAssertTrue(WeeklyReviewDone.isLate(last: DateOnly(year: 2026, month: 11, day: 5), today: today))
        XCTAssertFalse(WeeklyReviewDone.isLate(last: nil, today: today))
        XCTAssertFalse(WeeklyReviewDone.isLate(last: DateOnly(year: 2026, month: 11, day: 20), today: today))
        XCTAssertEqual(WeeklyReviewDone.lateLine(last: DateOnly(year: 2026, month: 11, day: 4), today: today),
                       "Last weekly review: 9 days ago")
    }

    func testTheNewestDayInAnyWeeklyNoteIsTheLastReview() {
        let older = weeklyNote(44, "---\nreview-done: 2026-11-01\n---\n# Week 44\n")
        let plain = weeklyNote(45, "# Week 45\n")
        let newer = WeeklyReviewDone.setting(DateOnly(year: 2026, month: 11, day: 13), on: weeklyNote(46, "---\nfocus: Garden\n---\n# Week 46\n"))
        XCTAssertEqual(newer.frontmatter.string("focus"), "Garden")
        XCTAssertEqual(NoteIndex(notes: [older, plain, newer]).lastWeeklyReview(), DateOnly(year: 2026, month: 11, day: 13))
        XCTAssertNil(NoteIndex(notes: [plain]).lastWeeklyReview())
    }
}
