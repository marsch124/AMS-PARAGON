import XCTest
@testable import ParagonCore

/// Build 268: a goal's `measure:` and `target:` lines, written from its header. One line, an
/// empty value kept as the template's own empty line, and nothing written when nothing changed.
final class GoalFieldsTests: XCTestCase {
    private func goal(_ frontmatter: String) -> Note {
        Note(relativePath: "Goals/Kungsleden.md", kind: .goal,
             text: "---\ntitle: Walk the Kungsleden\ntype: goal\nhorizon: year\n\(frontmatter)---\n# Walk the Kungsleden\n")
    }

    /// The same note read back from its own text, the way the vault reads it after a save.
    private func reread(_ note: Note) -> Note {
        Note(relativePath: note.relativePath, kind: note.kind, text: note.text)
    }

    // MARK: Reading

    /// The goal template ships `measure:` and `target:` empty. An empty line and a missing line
    /// both read as nothing, never as "" — so no screen can print "Measure: " with nothing after.
    func testAnEmptyLineAndAMissingLineBothReadAsNothing() {
        let empty = goal("target:\nmeasure:\n")
        XCTAssertNil(empty.measure)
        XCTAssertNil(empty.targetDate)
        let missing = goal("")
        XCTAssertNil(missing.measure)
        XCTAssertNil(missing.targetDate)
    }

    // MARK: The measure

    func testAMeasureIsWrittenAndReadBack() {
        let set = GoalFields.settingMeasure("All 440 km in 30 days", on: goal("measure:\n"))
        XCTAssertEqual(set.measure, "All 440 km in 30 days")
        XCTAssertEqual(reread(set).measure, "All 440 km in 30 days")
    }

    func testLineBreaksAreJoinedIntoOneLine() {
        let set = GoalFields.settingMeasure("  All 440 km\nin   30 days \n", on: goal(""))
        XCTAssertEqual(set.measure, "All 440 km in 30 days")
        XCTAssertFalse(set.text.contains("in 30 days\n\n"))
        XCTAssertEqual(reread(set).measure, "All 440 km in 30 days")
    }

    /// A measure the settings block has to put in quotes still reads back exactly as typed.
    func testAMeasureThatNeedsQuotesSurvivesTheFile() {
        for typed in ["Time: under 4 hours", "#1 in the club race", "Run, then swim", "\"Fast\" is fine",
                      "Done when: the last hut", "[draft] all of it", "50% of the trail"] {
            let set = GoalFields.settingMeasure(typed, on: goal("measure:\n"))
            XCTAssertEqual(reread(set).measure, typed, "\(typed) did not survive: \(set.text)")
        }
    }

    /// Clearing keeps the line and empties it, the shape the template ships — never
    /// `measure: ""`, and never a removed line.
    func testClearingLeavesTheTemplatesEmptyLine() {
        let cleared = GoalFields.settingMeasure("   ", on: goal("measure: All 440 km\n"))
        XCTAssertNil(cleared.measure)
        XCTAssertTrue(cleared.text.contains("\nmeasure:\n"), cleared.text)
        XCTAssertFalse(cleared.text.contains("measure: \"\""), cleared.text)
        XCTAssertTrue(cleared.frontmatter.keys.contains(GoalFields.measureKey))
        XCTAssertNil(reread(cleared).measure)
    }

    func testTheSameMeasureTwiceChangesNothing() {
        let set = GoalFields.settingMeasure("All 440 km", on: goal("measure:\n"))
        XCTAssertEqual(GoalFields.settingMeasure("All 440 km", on: set), set)
        XCTAssertEqual(GoalFields.settingMeasure(" All 440 km \n", on: set), set)
        // Clearing what is already empty, or missing, writes nothing either.
        let empty = goal("measure:\n")
        XCTAssertEqual(GoalFields.settingMeasure("", on: empty), empty)
        let missing = goal("")
        XCTAssertEqual(GoalFields.settingMeasure("", on: missing), missing)
        XCTAssertFalse(missing.frontmatter.keys.contains(GoalFields.measureKey))
    }

    // MARK: The target date

    func testTheTargetIsWrittenAsADay() {
        let day = DateOnly(year: 2027, month: 8, day: 5)
        let set = GoalFields.settingTarget(day, on: goal("target:\n"))
        XCTAssertEqual(set.frontmatter.string(GoalFields.targetKey), "2027-08-05")
        XCTAssertTrue(set.text.contains("\ntarget: 2027-08-05\n"), set.text)
        XCTAssertEqual(reread(set).targetDate, day)
    }

    func testClearingTheTargetLeavesTheEmptyLine() {
        let cleared = GoalFields.settingTarget(nil, on: goal("target: 2027-08-15\n"))
        XCTAssertNil(cleared.targetDate)
        XCTAssertTrue(cleared.text.contains("\ntarget:\n"), cleared.text)
        // A line that is not a date is still in the file, so Clear takes it away too.
        let typo = goal("target: next summer\n")
        XCTAssertNil(typo.targetDate)
        XCTAssertNil(GoalFields.settingTarget(nil, on: typo).frontmatter.string(GoalFields.targetKey))
    }

    func testTheSameTargetTwiceChangesNothing() {
        let day = DateOnly(year: 2027, month: 8, day: 15)
        let set = goal("target: 2027-08-15\n")
        XCTAssertEqual(GoalFields.settingTarget(day, on: set), set)
        let empty = goal("target:\n")
        XCTAssertEqual(GoalFields.settingTarget(nil, on: empty), empty)
        let missing = goal("")
        XCTAssertEqual(GoalFields.settingTarget(nil, on: missing), missing)
    }

    /// Nothing else in the settings block moves when one line is written.
    func testTheOtherLinesStayWhereTheyWere() {
        let note = goal("status: active\ntarget:\nmeasure:\ngoal: Be strong\ncreated: 2026-09-01\n")
        let set = GoalFields.settingMeasure("All 440 km",
                                            on: GoalFields.settingTarget(DateOnly(year: 2027, month: 8, day: 15), on: note))
        XCTAssertEqual(set.frontmatter.keys, note.frontmatter.keys)
        XCTAssertEqual(set.goal, "Be strong")
        XCTAssertEqual(set.body, note.body)
    }
}
