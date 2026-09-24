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
}
