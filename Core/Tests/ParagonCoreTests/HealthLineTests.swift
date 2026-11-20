import XCTest
@testable import ParagonCore

/// Round 350: the one health line in the daily note.
final class HealthLineTests: XCTestCase {
    func testTheWordsAddUpWorkoutsOfOneKindAndNeverSayZero() {
        let line = HealthLine.wording(steps: 8412, workouts: [
            HealthWorkout(name: "Walk", minutes: 20),
            HealthWorkout(name: "Strength", minutes: 40),
            HealthWorkout(name: "Walk", minutes: 15),
            HealthWorkout(name: "Yoga", minutes: 0),
        ])
        XCTAssertEqual(line, "Steps 8,412 \u{00b7} Walk 35 min \u{00b7} Strength 40 min \u{00b7} Yoga 1 min")
        XCTAssertEqual(HealthLine.wording(steps: 950, workouts: []), "Steps 950")
        XCTAssertNil(HealthLine.wording(steps: 0, workouts: []))
        XCTAssertNil(HealthLine.wording(steps: nil, workouts: []))
        XCTAssertEqual(HealthLine.wording(steps: 1234567, workouts: []), "Steps 1,234,567")
    }

    func testTheSectionIsMadeReplacedAndRemovedWithTheRestKept() {
        let note = Note(relativePath: "Calendar/2026-11-20.md", kind: .daily, text: "# 2026-11-20\n\n## Tasks\n- [ ] One\n")
        let first = HealthLine.note(note, settingLine: "Steps 100")
        XCTAssertEqual(HealthLine.text(in: first), "Steps 100")
        XCTAssertTrue(first.body.contains("- [ ] One"))
        let second = HealthLine.note(first, settingLine: "Steps 200 \u{00b7} Walk 10 min")
        XCTAssertEqual(second.healthLine, "Steps 200 \u{00b7} Walk 10 min")
        XCTAssertEqual(second.body.components(separatedBy: "## Health").count, 2, "one heading only")
        let gone = HealthLine.note(second, settingLine: nil)
        XCTAssertEqual(gone.healthLine, "")
        XCTAssertFalse(gone.body.contains("## Health"))
        XCTAssertTrue(gone.body.contains("- [ ] One"))
        XCTAssertEqual(HealthLine.note(note, settingLine: nil), note, "nothing to write, no section made")
    }

    func testTheNoteIsAskedAgainOnlyAfterHalfAnHour() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(HealthLine.isDue(lastRead: nil, now: now))
        XCTAssertFalse(HealthLine.isDue(lastRead: now.addingTimeInterval(-600), now: now))
        XCTAssertTrue(HealthLine.isDue(lastRead: now.addingTimeInterval(-1800), now: now))
    }
}
