import XCTest
@testable import ParagonCore

final class DayLogTests: XCTestCase {
    private func daily(_ body: String) -> Note {
        Note(relativePath: "Calendar/20260924.md", kind: .daily,
             text: "---\ntitle: Thursday, 24 September 2026\ntype: daily\n---\n" + body)
    }

    func testANoteWithNoSectionHasNoLine() {
        XCTAssertEqual(daily("# Thursday\n\n## Tasks\n\n- [ ] Something\n").lookingBack, "")
    }

    func testReadsWhatIsUnderTheHeading() {
        let note = daily("""
        # Thursday

        ## Looking back

        Good morning, slow afternoon.

        """)
        XCTAssertEqual(note.lookingBack, "Good morning, slow afternoon.")
    }

    /// Extra blank lines around a section typed by hand must read the same as one we wrote.
    func testExtraBlankLinesAroundTheTextAreIgnored() {
        let note = daily("""
        # Thursday

        ## Looking back



        Slow afternoon.


        """)
        XCTAssertEqual(note.lookingBack, "Slow afternoon.")
    }

    func testASectionIsMadeAtTheEndOfTheNote() {
        let note = daily("""
        # Thursday

        ## Plan

        TB: 09:30-11:00 Deep work

        ## Tasks

        - [ ] Order the saddle
        """)
        let written = note.settingLookingBack("Good morning, slow afternoon.")
        XCTAssertTrue(written.body.hasSuffix("\n\n## Looking back\n\nGood morning, slow afternoon.\n"),
                      "the section belongs at the end, with a blank line each side: \(written.body)")
        XCTAssertTrue(written.body.contains("- [ ] Order the saddle\n\n## Looking back"))
        XCTAssertEqual(written.lookingBack, "Good morning, slow afternoon.")
    }

    /// The bug this guards: a second save piling up another heading, or another blank line.
    func testWritingTwiceDoesNotPileUp() {
        let once = daily("# Thursday\n\n## Tasks\n\n- [ ] Order the saddle\n")
            .settingLookingBack("First try.")
        let twice = once.settingLookingBack("First try.")
        XCTAssertEqual(twice.body, once.body)
        let changed = once.settingLookingBack("Second thought.")
        XCTAssertEqual(changed.lookingBack, "Second thought.")
        XCTAssertEqual(changed.body.components(separatedBy: DayLog.heading).count - 1, 1)
    }

    func testTheRestOfTheNoteIsUntouched() {
        let note = daily("""
        # Thursday

        ## Plan

        TB: 09:30-11:00 Deep work

        ## Tasks

        - [ ] Order the saddle

        ## Looking back

        Old words.
        """)
        let written = note.settingLookingBack("New words.")
        XCTAssertEqual(written.planBlocks.map(\.title), ["Deep work"])
        XCTAssertEqual(written.openTasks.map(\.title), ["Order the saddle"])
        XCTAssertEqual(written.lookingBack, "New words.")
    }

    /// Clearing the line takes the heading with it: a heading with nothing under it is a
    /// promise the note does not keep.
    func testEmptyTextRemovesTheSection() {
        let note = daily("""
        # Thursday

        ## Tasks

        - [ ] Order the saddle

        ## Looking back

        Old words.

        """)
        let cleared = note.settingLookingBack("")
        XCTAssertFalse(cleared.body.contains(DayLog.heading))
        XCTAssertEqual(cleared.lookingBack, "")
        XCTAssertEqual(cleared.openTasks.map(\.title), ["Order the saddle"])
        XCTAssertFalse(cleared.body.contains("\n\n\n"), "a run of blank lines was left behind")
    }

    /// Nothing to write and nowhere to write it must leave the note exactly as it was, so
    /// pressing Done without typing never changes a file.
    func testEmptyTextOnANoteWithNoSectionChangesNothing() {
        let note = daily("# Thursday\n\n## Tasks\n\n- [ ] Order the saddle\n")
        XCTAssertEqual(note.settingLookingBack("").body, note.body)
        XCTAssertEqual(note.settingLookingBack("   \n  ").body, note.body)
    }

    func testSeveralLinesSurviveTheRoundTrip() {
        let written = daily("# Thursday\n").settingLookingBack("Two things.\n\nThe saddle can wait.")
        XCTAssertEqual(written.lookingBack, "Two things.\n\nThe saddle can wait.")
    }

    /// A heading typed by hand in another case is still the section.
    func testTheHeadingIsFoundWhateverItsCase() {
        let note = daily("# Thursday\n\n## LOOKING BACK\n\nShouted.\n")
        XCTAssertEqual(note.lookingBack, "Shouted.")
        XCTAssertEqual(note.settingLookingBack("Quieter.").lookingBack, "Quieter.")
    }

    // MARK: What gets written when the file moved on (build 261's rule, tested since build 272)

    func testWhatHeTypedIsWrittenWhenTheFileIsWhatTheFieldShowed() {
        XCTAssertEqual(DayLog.words(typed: "  New words.\n", shown: "Old words.", onFile: "Old words."), "New words.")
        XCTAssertEqual(DayLog.words(typed: "First words.", shown: "", onFile: ""), "First words.")
        // Emptied on purpose: the field showed the line, he removed it, and nothing else changed.
        XCTAssertEqual(DayLog.words(typed: "  ", shown: "Old words.", onFile: "Old words."), "")
    }

    /// The field opened empty, because the note was still coming; meanwhile a line arrived.
    func testALineTheFieldNeverShowedIsKeptAndHisWordsGoBelowIt() {
        XCTAssertEqual(DayLog.words(typed: "Mine.", shown: "", onFile: "Written on the phone."),
                       "Written on the phone.\n\nMine.")
    }

    func testALineTheFieldNeverShowedIsNotRemovedByAnEmptyField() {
        XCTAssertEqual(DayLog.words(typed: "", shown: "", onFile: "Written on the phone."), "Written on the phone.")
    }

    /// He typed what is already there: nothing is added twice.
    func testWordsAlreadyOnFileAreNotAddedAgain() {
        XCTAssertEqual(DayLog.words(typed: "Written on the phone.", shown: "", onFile: "Written on the phone."),
                       "Written on the phone.")
    }

    /// A line typed by hand can end in a space (or start with one), and `text(in:)` keeps it.
    /// It is still the line the field showed: emptying the field removes it.
    func testASpaceAtTheEdgeOfTheLineOnFileIsNotADifference() {
        XCTAssertEqual(DayLog.words(typed: "", shown: "A calm week. ", onFile: "A calm week. "), "")
        XCTAssertEqual(DayLog.words(typed: "", shown: "A calm week.", onFile: "A calm week. "), "")
        XCTAssertEqual(DayLog.words(typed: "", shown: "A calm week.", onFile: " A calm week."), "")
    }

    /// The same line edited: his new words are written and the old line is not kept below them.
    func testEditingALineWithASpaceAtItsEdgeLeavesNoDuplicate() {
        XCTAssertEqual(DayLog.words(typed: "A good week", shown: "A calm week. ", onFile: "A calm week. "),
                       "A good week")
        XCTAssertEqual(DayLog.words(typed: "A good week", shown: "A calm week.", onFile: " A calm week."),
                       "A good week")
    }

    /// The whole path, through a note: a hand-typed trailing space, then the box emptied.
    func testEmptyingALineWithATrailingSpaceTakesTheSectionAway() {
        let note = daily("# Thursday\n\n## Looking back\n\nA calm week. \n")
        XCTAssertEqual(note.lookingBack, "A calm week. ")
        let words = DayLog.words(typed: "", shown: note.lookingBack, onFile: note.lookingBack)
        XCTAssertEqual(words, "")
        XCTAssertFalse(note.settingLookingBack(words).body.contains("Looking back"))
    }

    // MARK: A weekly note (build 272, "How was the week?")

    /// A weekly note the way the vault makes one: the Weekly template, filled in, with no
    /// settings block.
    private func weekly() -> Note {
        let week = WeekRef(year: 2026, week: 42)
        let text = Templates.fill(Templates.weekly, title: week.title, date: week.monday)
        return Note(relativePath: "Calendar/\(week).md", kind: .daily, text: text)
    }

    func testAFreshWeeklyNoteHasNoLine() {
        XCTAssertEqual(weekly().lookingBack, "")
    }

    /// The new section goes at the very end, below the template's own `## Review`.
    func testAWeeksLineGoesAtTheEndBelowTheReviewQuestions() {
        let note = weekly()
        let written = note.settingLookingBack("A calm week. The garden is done.")
        XCTAssertTrue(written.body.hasSuffix(
            "- What to change next week?\n\n## Looking back\n\nA calm week. The garden is done.\n"),
                      "the section belongs at the end, with a blank line each side: \(written.body)")
        XCTAssertEqual(written.lookingBack, "A calm week. The garden is done.")
        // Everything that was there is still there, in the same place.
        let original = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(written.body.hasPrefix(original))
    }

    /// The two questions are the template's, and his words are never mixed into them.
    func testTheReviewQuestionsAreUntouched() {
        let note = weekly()
        let before = MarkdownSection.find("## Review", in: note.body).lines
        XCTAssertTrue(before.contains("- What went well?"))
        XCTAssertTrue(before.contains("- What to change next week?"))

        let written = note.settingLookingBack("A calm week.")
        XCTAssertEqual(MarkdownSection.find("## Review", in: written.body).lines, before)
        let changed = written.settingLookingBack("A busy week.")
        XCTAssertEqual(MarkdownSection.find("## Review", in: changed.body).lines, before)
        XCTAssertEqual(changed.lookingBack, "A busy week.")
    }

    /// Writing again replaces the words; it never piles up a second heading.
    func testWritingAWeeksLineTwiceDoesNotPileUp() {
        let once = weekly().settingLookingBack("First try.")
        XCTAssertEqual(once.settingLookingBack("First try.").body, once.body)
        let twice = once.settingLookingBack("Second thought.")
        XCTAssertEqual(twice.body.components(separatedBy: DayLog.heading).count - 1, 1)
        XCTAssertEqual(twice.lookingBack, "Second thought.")
    }

    /// Empty words take the heading away, and the note is exactly what the template made.
    func testEmptyTextTakesAWeeksLineAwayAgain() {
        let note = weekly()
        let cleared = note.settingLookingBack("A calm week.").settingLookingBack("")
        XCTAssertFalse(cleared.body.contains(DayLog.heading))
        XCTAssertEqual(cleared.lookingBack, "")
        XCTAssertEqual(cleared.body, note.body)
    }

    /// Nothing to say and nothing written: the note is left exactly as it was.
    func testEmptyTextOnAWeeklyNoteWithNoLineChangesNothing() {
        let note = weekly()
        XCTAssertEqual(note.settingLookingBack("").body, note.body)
        XCTAssertEqual(note.settingLookingBack("  \n ").body, note.body)
    }

    /// The week's goal is a settings line and the week's words are a section. Neither touches
    /// the other.
    func testTheWeeksGoalAndTheWeeksLineLeaveEachOtherAlone() {
        let withGoal = Note(relativePath: "Calendar/2026-W42.md", kind: .daily,
                            text: "---\nfocus: The garden before winter\n---\n" + weekly().body)
        let written = withGoal.settingLookingBack("A calm week.")
        XCTAssertEqual(WeekGoal.read(from: written), "The garden before winter")
        XCTAssertEqual(written.lookingBack, "A calm week.")
        let cleared = written.settingLookingBack("")
        XCTAssertEqual(WeekGoal.read(from: cleared), "The garden before winter")
        XCTAssertEqual(cleared.lookingBack, "")
    }
}
