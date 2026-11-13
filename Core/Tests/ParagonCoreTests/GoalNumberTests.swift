import XCTest
@testable import ParagonCore

/// Build 318: a goal with a number to track — start, target, current, unit and a dated history,
/// five plain settings lines. One small test per rule.
final class GoalNumberTests: XCTestCase {
    private func goal(_ frontmatter: String) -> Note {
        Note(relativePath: "Goals/Weigh 82.md", kind: .goal,
             text: "---\ntitle: Weigh 82\ntype: goal\nhorizon: year\nmeasure: Weigh 82 kg\n\(frontmatter)---\n# Weigh 82\n\nSome words.\n")
    }

    private func reread(_ note: Note) -> Note {
        Note(relativePath: note.relativePath, kind: note.kind, text: note.text)
    }

    private func day(_ text: String) -> DateOnly { DateOnly(text)! }

    /// What is written is read back the same, in plain lines Obsidian shows as properties.
    func testTheNumberSurvivesTheFile() {
        let set = GoalNumber.setting(start: 90, target: 82, current: 88.5, unit: "kg", on: goal(""), day: day("2026-11-01"))
        let updated = GoalNumber.updating(86.25, on: set, day: day("2026-11-13"))
        XCTAssertTrue(updated.text.contains("number_start: 90\nnumber_target: 82\nnumber_current: 86.25\nnumber_unit: kg\nnumber_history: [2026-11-01 88.5, 2026-11-13 86.25]\n"), updated.text)
        let number = reread(updated).goalNumber
        XCTAssertEqual(number, GoalNumber(start: 90, target: 82, current: 86.25, unit: "kg", history: [
            .init(day: day("2026-11-01"), value: 88.5), .init(day: day("2026-11-13"), value: 86.25),
        ]))
        // The measure, the other lines and the note's words are untouched.
        XCTAssertEqual(reread(updated).measure, "Weigh 82 kg")
        XCTAssertEqual(updated.body, goal("").body)
        // A unit the settings block has to put in quotes still reads back.
        let percent = GoalNumber.setting(start: 0, target: 15, current: 4, unit: "% fat", on: goal(""), day: day("2026-11-01"))
        XCTAssertEqual(reread(percent).goalNumber?.unit, "% fat")
    }

    /// An older build knows none of the five keys. When it rewrites the note — here by setting
    /// the measure, the way build 317 does — every one of them is still there, unchanged and
    /// in place.
    func testAnOlderBuildKeepsTheNumberLinesWhenItRewritesTheNote() {
        let lines = "number_start: 90\nnumber_target: 82\nnumber_current: 86.5\nnumber_unit: kg\nnumber_history: [2026-10-01 90, 2026-11-13 86.5]\n"
        let note = goal(lines)
        let rewritten = reread(GoalFields.settingMeasure("Weigh 82 kg by summer", on: note))
        XCTAssertTrue(rewritten.text.contains(lines), rewritten.text)
        XCTAssertEqual(rewritten.goalNumber, note.goalNumber)
        // A history written as a block list by another editor reads the same.
        let block = goal("number_target: 82\nnumber_history:\n  - 2026-10-01 90\n  - 2026-11-13 86.5\n")
        XCTAssertEqual(block.goalNumber?.start, 90)
        XCTAssertEqual(block.goalNumber?.current, 86.5)
        XCTAssertEqual(reread(GoalFields.settingMeasure("x", on: block)).goalNumber, block.goalNumber)
    }

    /// Per cent for a target that goes up and one that goes down, past the target and the
    /// wrong way, and the rounding that never says 100 early or 0 after a move.
    func testPercentForUpAndDownTargets() {
        XCTAssertEqual(GoalNumber(start: 0, target: 440, current: 110).percent, 25)
        let down = GoalNumber(start: 90, target: 82, current: 86)
        XCTAssertTrue(down.goesDown)
        XCTAssertEqual(down.percent, 50)
        XCTAssertFalse(down.isReached)
        // Past the target: the label says so, the bar is full.
        let past = GoalNumber(start: 90, target: 82, current: 81)
        XCTAssertEqual(past.percent, 113)
        XCTAssertEqual(past.barFraction, 1)
        XCTAssertTrue(past.isReached)
        // The wrong way: 0 %, an empty bar, never a negative figure.
        let worse = GoalNumber(start: 90, target: 82, current: 92)
        XCTAssertEqual(worse.percent, 0)
        XCTAssertEqual(worse.barFraction, 0)
        // Never 100 before it is reached, never 0 once something moved.
        XCTAssertEqual(GoalNumber(start: 0, target: 100_000, current: 99_900).percent, 99)
        XCTAssertEqual(GoalNumber(start: 0, target: 100_000, current: 100).percent, 1)
        XCTAssertEqual(GoalNumber(start: 0, target: 100, current: 100).percent, 100)
        // No distance between start and target: no figure, unless it is met.
        XCTAssertNil(GoalNumber(start: 5, target: 5, current: 4).percent)
        XCTAssertEqual(GoalNumber(start: 5, target: 5, current: 5).percent, 100)
    }

    /// The history: one line, oldest first, one value per day, and nothing written twice.
    func testTheHistoryLineKeepsOneValuePerDay() {
        let set = GoalNumber.setting(start: 0, target: 440, current: 0, unit: "km", on: goal(""), day: day("2026-11-01"))
        XCTAssertEqual(set.frontmatter.list(GoalNumber.historyKey), ["2026-11-01 0"])
        var note = GoalNumber.updating(40, on: set, day: day("2026-11-05"))
        note = GoalNumber.updating(55.5, on: note, day: day("2026-11-05"))
        XCTAssertEqual(note.frontmatter.list(GoalNumber.historyKey), ["2026-11-01 0", "2026-11-05 55.5"])
        XCTAssertEqual(note.goalNumber?.current, 55.5)
        XCTAssertEqual(note.goalNumber?.curve, [0, 55.5])
        // The same value on the same day changes nothing, so nothing is saved.
        XCTAssertEqual(GoalNumber.updating(55.5, on: note, day: day("2026-11-05")), note)
        // Changing only the target keeps the history as it is.
        let retargeted = GoalNumber.setting(start: 0, target: 500, current: 55.5, unit: "km", on: note, day: day("2026-11-09"))
        XCTAssertEqual(retargeted.frontmatter.list(GoalNumber.historyKey), ["2026-11-01 0", "2026-11-05 55.5"])
        // A goal without a number is not given one by an update.
        XCTAssertEqual(GoalNumber.updating(3, on: goal(""), day: day("2026-11-05")), goal(""))
        // Over the limit the oldest days go, but never the first one.
        var long = set
        for offset in 1...(GoalNumber.historyLimit + 5) {
            let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 11, day: 1).date!)!
            long = GoalNumber.updating(Double(offset), on: long, day: DateOnly(date, calendar: Calendar(identifier: .gregorian)))
        }
        let kept = long.goalNumber?.history ?? []
        XCTAssertEqual(kept.count, GoalNumber.historyLimit)
        XCTAssertEqual(kept.first?.day, day("2026-11-01"))
        XCTAssertEqual(kept.last?.value, Double(GoalNumber.historyLimit + 5))
    }

    /// Removing takes all five lines and nothing else.
    func testRemovingTakesTheFiveLinesOnly() {
        let set = GoalNumber.setting(start: 90, target: 82, current: 88, unit: "kg", on: goal(""), day: day("2026-11-01"))
        XCTAssertEqual(GoalNumber.removing(from: set), goal(""))
        XCTAssertEqual(GoalNumber.removing(from: goal("")), goal(""))
    }

    /// What he types reads as a number with a comma or a dot and spaces between thousands;
    /// the file always holds a dot and no trailing zeros; the words are "86.5 of 82 kg".
    func testNumbersAsTypedStoredAndShown() {
        XCTAssertEqual(GoalNumber.parse("86,5"), 86.5)
        XCTAssertEqual(GoalNumber.parse(" 100 000 "), 100_000)
        XCTAssertEqual(GoalNumber.parse("1.250,75"), 1250.75)
        XCTAssertEqual(GoalNumber.parse("1,250.75"), 1250.75)
        XCTAssertEqual(GoalNumber.parse("-3"), -3)
        XCTAssertNil(GoalNumber.parse(""))
        XCTAssertNil(GoalNumber.parse("about 80"))
        XCTAssertNil(GoalNumber.parse("1.2.3"))
        XCTAssertEqual(GoalNumber.plain(86.50), "86.5")
        XCTAssertEqual(GoalNumber.plain(100_000), "100000")
        XCTAssertEqual(GoalNumber.plain(0.125), "0.13")
        let number = GoalNumber(start: 90, target: 82, current: 86.5, unit: "kg")
        let english = Locale(identifier: "en_GB")
        XCTAssertEqual(number.words(locale: english), "86.5 of 82 kg")
        XCTAssertEqual(number.wordsWithPercent(locale: english), "86.5 of 82 kg \u{00B7} 44 %")
        XCTAssertEqual(GoalNumber(start: 0, target: 10, current: 2).words(locale: english), "2 of 10")
    }
}
