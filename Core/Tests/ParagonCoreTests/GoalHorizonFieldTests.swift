import XCTest
@testable import ParagonCore

/// Build 276: a goal with a date can change its horizon — **This year** or **Long term** — from
/// its header. Only a goal with a date has the choice; an aspiration, a project and every other
/// kind of note are never changed, and the line is never removed.
final class GoalHorizonFieldTests: XCTestCase {
    private func goal(_ horizonLine: String, kind: ParaKind = .goal) -> Note {
        Note(relativePath: "Goals/Kungsleden.md", kind: kind,
             text: "---\ntitle: Walk the Kungsleden\ntype: goal\n\(horizonLine)target: 2027-08-15\nmeasure:\n---\n# Walk the Kungsleden\n")
    }

    /// The same note read back from its own text, the way the vault reads it after a save.
    private func reread(_ note: Note) -> Note {
        Note(relativePath: note.relativePath, kind: note.kind, text: note.text)
    }

    func testAGoalWithADateCanBeMovedToLongTerm() {
        let set = goal("horizon: year\n").settingHorizon(.long)
        XCTAssertEqual(set.horizon, .long)
        XCTAssertTrue(set.text.contains("\nhorizon: long\n"), set.text)
        XCTAssertEqual(reread(set).horizon, .long)
    }

    func testAndBackToThisYear() {
        let long = goal("horizon: long\n")
        XCTAssertEqual(long.horizon, .long)
        let set = long.settingHorizon(.year)
        XCTAssertEqual(set.horizon, .year)
        XCTAssertTrue(set.text.contains("\nhorizon: year\n"), set.text)
        XCTAssertEqual(reread(set).horizon, .year)
    }

    /// The same value again returns the note as it was, so pressing the choice already made
    /// never moves the file's date or sends it round iCloud (build 254's rule).
    func testTheSameHorizonTwiceChangesNothing() {
        let year = goal("horizon: year\n")
        XCTAssertEqual(year.settingHorizon(.year), year)
        let long = goal("horizon: long\n")
        XCTAssertEqual(long.settingHorizon(.long), long)
        // Written in capitals by hand: it already says the value, so it is left as written.
        let shouted = goal("horizon: Long\n")
        XCTAssertEqual(shouted.settingHorizon(.long), shouted)
        XCTAssertTrue(shouted.settingHorizon(.long).text.contains("horizon: Long"))
    }

    /// A goal with no `horizon:` line reads as **This year**, so the button shows it ticked.
    /// Choosing **This year** on it writes the line all the same (the file then says what the
    /// screen says), and choosing **Long term** writes `long`.
    func testAGoalWithNoLineGetsTheLineWhenAChoiceIsMade() {
        let bare = goal("")
        XCTAssertEqual(bare.horizon, .year)
        XCTAssertFalse(bare.frontmatter.keys.contains(GoalFields.horizonKey))

        let year = bare.settingHorizon(.year)
        XCTAssertTrue(year.frontmatter.keys.contains(GoalFields.horizonKey))
        XCTAssertEqual(year.frontmatter.string(GoalFields.horizonKey), "year")
        XCTAssertEqual(year.horizon, .year)
        XCTAssertEqual(reread(year).frontmatter.string(GoalFields.horizonKey), "year")

        let long = bare.settingHorizon(.long)
        XCTAssertEqual(long.frontmatter.string(GoalFields.horizonKey), "long")
        XCTAssertEqual(reread(long).horizon, .long)
    }

    /// A line the app cannot read reads as **This year** too, and a choice replaces it.
    func testAnUnreadableLineIsReplacedByTheChoice() {
        let odd = goal("horizon: someday\n")
        XCTAssertEqual(odd.horizon, .year)
        XCTAssertEqual(odd.settingHorizon(.year).frontmatter.string(GoalFields.horizonKey), "year")
        XCTAssertEqual(odd.settingHorizon(.long).frontmatter.string(GoalFields.horizonKey), "long")
    }

    /// An aspiration is a different thing and lives in the other room. Switching it would move
    /// it between **Aspirations** and **Goals** behind his back, so nothing changes.
    func testAnAspirationIsNeverChanged() {
        let aspiration = goal("horizon: life\n")
        XCTAssertEqual(aspiration.horizon, .life)
        XCTAssertEqual(aspiration.settingHorizon(.long), aspiration)
        XCTAssertEqual(aspiration.settingHorizon(.year), aspiration)
        // Also when it is written in capitals.
        let shouted = goal("horizon: Life\n")
        XCTAssertEqual(shouted.settingHorizon(.long), shouted)
    }

    /// `.life` can never be written from here: it is not a longer horizon, it is another thing.
    func testLifeIsNeverWritten() {
        let year = goal("horizon: year\n")
        XCTAssertEqual(year.settingHorizon(.life), year)
        let long = goal("horizon: long\n")
        XCTAssertEqual(long.settingHorizon(.life), long)
        let bare = goal("")
        XCTAssertEqual(bare.settingHorizon(.life), bare)
    }

    /// Only a goal note has a horizon. A project, an area or an archived goal is left alone,
    /// and no `horizon:` line appears on it.
    func testNoteOfAnotherKindIsNeverChanged() {
        for kind in [ParaKind.project, .area, .resource, .archive, .inbox, .daily] {
            let note = goal("", kind: kind)
            XCTAssertNil(note.horizon, "\(kind) should have no horizon")
            XCTAssertEqual(note.settingHorizon(.long), note, "\(kind) was changed")
            XCTAssertEqual(note.settingHorizon(.year), note, "\(kind) was changed")
        }
    }

    /// The line is never removed, and nothing else in the settings block moves.
    func testTheOtherLinesStayWhereTheyWere() {
        let note = goal("horizon: year\n")
        let set = note.settingHorizon(.long)
        XCTAssertEqual(set.frontmatter.keys, note.frontmatter.keys)
        XCTAssertEqual(set.targetDate, note.targetDate)
        XCTAssertEqual(set.body, note.body)
        // Going there and back leaves the same text as before.
        XCTAssertEqual(set.settingHorizon(.year).text, note.text)
    }

    func testTheTwoChoicesAreThisYearAndLongTerm() {
        XCTAssertEqual(GoalFields.datedHorizons, [.year, .long])
        XCTAssertEqual(GoalFields.datedHorizons.map(\.label), ["This year", "Long term"])
    }
}
