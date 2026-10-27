import XCTest
@testable import ParagonCore

/// An area's Standard (build 271): `## Standard` in the area note, read without the
/// template's own question, written without touching the rest of the note.
final class AreaStandardTests: XCTestCase {
    private let day = DateOnly(year: 2026, month: 10, day: 19)

    /// An area made the way `Vault.createNote` makes one: from the shipped template.
    private func shippedArea(_ title: String = "Health") -> Note {
        Note(relativePath: "Areas/\(title).md", kind: .area,
             text: Templates.fill(Templates.area, title: title, date: day))
    }

    private func area(_ body: String, title: String = "Health") -> Note {
        Note(relativePath: "Areas/\(title).md", kind: .area,
             text: "---\ntitle: \(title)\ntype: area\ncreated: 2026-10-19\n---\n" + body)
    }

    // MARK: Reading

    func testTheShippedQuestionIsNotAStandard() {
        let note = shippedArea()
        XCTAssertTrue(note.body.contains("## Standard"), "The template still has the heading")
        XCTAssertNil(AreaStandard.text(in: note),
                     "The question under the heading is not an answer")
    }

    func testTheShippedPlaceholderIsReadOutOfTheTemplateItself() {
        XCTAssertEqual(AreaStandard.shippedPlaceholders, ["What does \"good\" look like in this area?"])
    }

    func testANoteWithNoHeadingHasNoStandardEither() {
        XCTAssertNil(AreaStandard.text(in: area("# Health\n\n## Tasks\n\n- [ ] Walk\n")))
    }

    func testAHeadingWithNothingUnderItHasNoStandard() {
        XCTAssertNil(AreaStandard.text(in: area("# Health\n\n## Standard\n\n## Tasks\n")))
    }

    func testARealStandardIsRead() {
        let note = area("""
        # Health

        ## Standard

        Three runs a week, one rest day, a yearly check-up.

        ## Tasks

        """)
        XCTAssertEqual(AreaStandard.text(in: note), "Three runs a week, one rest day, a yearly check-up.")
    }

    /// He may have reworded the question in his own Area template. That line is a question too,
    /// however he spelled it — with curly quotes, capitals and double spaces here.
    func testHisRewordedTemplateQuestionIsNotAStandardEither() {
        let template = "---\ntitle: {{title}}\ntype: area\n---\n# {{title}}\n\n## Standard\n\nWhat is \"enough\" in this area?\n\n## Tasks\n"
        let lines = AreaStandard.placeholders(inTemplate: template)
        XCTAssertEqual(lines, ["What is \"enough\" in this area?"])

        let note = area("# Health\n\n## Standard\n\nwhat is  \u{201C}ENOUGH\u{201D} in this area?\n\n## Tasks\n")
        XCTAssertNotNil(AreaStandard.text(in: note),
                        "Without his template's lines it cannot be told from a standard")
        XCTAssertNil(AreaStandard.text(in: note, placeholders: lines),
                     "With his template's line known, case, curly quotes and spaces do not matter")
    }

    /// A template line that holds `{{title}}` has had the area's name put into it by the time
    /// the note exists, so the raw line would never match.
    func testAQuestionThatHoldsTheTitleIsStillAQuestion() {
        let template = "# {{title}}\n\n## Standard\n\nWhat does good look like for {{title}}?\n"
        let lines = AreaStandard.placeholders(inTemplate: template)
        let note = area("# Garden\n\n## Standard\n\nWhat does good look like for Garden?\n", title: "Garden")
        XCTAssertNil(AreaStandard.text(in: note, placeholders: lines))
    }

    func testTheQuestionAboveHisOwnWordsGivesHisWords() {
        let note = area("""
        # Health

        ## Standard

        What does "good" look like in this area?

        Three walks a week.

        ## Tasks

        """)
        XCTAssertEqual(AreaStandard.text(in: note), "Three walks a week.")
    }

    func testABulletListIsKeptWhole() {
        let note = area("# Health\n\n## Standard\n\n- Three walks a week\n- One rest day\n\n## Tasks\n")
        XCTAssertEqual(AreaStandard.text(in: note), "- Three walks a week\n- One rest day")
    }

    func testAnotherHeadingEndsTheSection() {
        let note = area("# Health\n\n## Standard\n\nThree walks a week.\n\n## Notes\n\nNot part of it.\n")
        XCTAssertEqual(AreaStandard.text(in: note), "Three walks a week.")
    }

    func testTheHeadingCanBeTypedInAnyCase() {
        let note = area("# Health\n\n## STANDARD\n\nThree walks a week.\n")
        XCTAssertEqual(AreaStandard.text(in: note), "Three walks a week.")
    }

    // MARK: The first sentence

    func testOneSentenceIsShownWhole() {
        XCTAssertEqual(AreaStandard.firstSentence(of: "Three runs a week, one rest day, a yearly check-up."),
                       "Three runs a week, one rest day, a yearly check-up.")
    }

    func testTheFirstSentenceIsCutAndSaysSo() {
        XCTAssertEqual(AreaStandard.firstSentence(of: "Three walks a week. One rest day. A check-up."),
                       "Three walks a week. \u{2026}")
        XCTAssertEqual(AreaStandard.firstSentence(of: "Is it enough? Then stop."), "Is it enough? \u{2026}")
        XCTAssertEqual(AreaStandard.firstSentence(of: "Keep it up! Always."), "Keep it up! \u{2026}")
    }

    func testALaterLineCountsAsSomethingCut() {
        XCTAssertEqual(AreaStandard.firstSentence(of: "Three walks a week.\n\nAnd a rest day."),
                       "Three walks a week. \u{2026}")
        XCTAssertEqual(AreaStandard.firstSentence(of: "Three walks a week\nAnd a rest day"),
                       "Three walks a week\u{2026}")
    }

    func testNothingIsAddedWhenNothingWasCut() {
        XCTAssertEqual(AreaStandard.firstSentence(of: "Three walks a week"), "Three walks a week")
        XCTAssertEqual(AreaStandard.firstSentence(of: "Three walks a week.\n\n"), "Three walks a week.")
    }

    func testAStopInsideAWordDoesNotCut() {
        XCTAssertEqual(AreaStandard.firstSentence(of: "At least 3.5 km a day, version 1.2 of the plan."),
                       "At least 3.5 km a day, version 1.2 of the plan.")
    }

    func testAClosingQuoteStaysWithItsSentence() {
        XCTAssertEqual(AreaStandard.firstSentence(of: "It feels \"good.\" Then more."),
                       "It feels \"good.\" \u{2026}")
    }

    func testAListMarkerIsNotPartOfTheSentence() {
        XCTAssertEqual(AreaStandard.firstSentence(of: "- Three walks a week\n- One rest day"),
                       "Three walks a week\u{2026}")
        XCTAssertEqual(AreaStandard.firstSentence(of: "* Three walks a week."), "Three walks a week.")
        XCTAssertEqual(AreaStandard.firstSentence(of: "1. Three walks a week.\n2. A rest day."),
                       "Three walks a week. \u{2026}")
        XCTAssertEqual(AreaStandard.firstSentence(of: "2026 is the year of a walk a day."),
                       "2026 is the year of a walk a day.", "A number that is not a list marker stays")
    }

    func testNoWordsGiveNothing() {
        XCTAssertEqual(AreaStandard.firstSentence(of: ""), "")
        XCTAssertEqual(AreaStandard.firstSentence(of: "\n  \n"), "")
    }

    // MARK: Writing

    func testWritingReplacesTheQuestion() {
        let written = AreaStandard.note(shippedArea(), settingText: "Three walks a week.")
        XCTAssertEqual(AreaStandard.text(in: written), "Three walks a week.")
        XCTAssertFalse(written.body.contains("What does"), "The question is gone: \(written.body)")
        XCTAssertEqual(written.body.components(separatedBy: AreaStandard.heading).count - 1, 1)
        XCTAssertTrue(written.body.contains("## Standard\n\nThree walks a week.\n\n## Tasks"),
                      "A blank line each side of the text, and the next section follows: \(written.body)")
    }

    func testTheRestOfTheNoteIsUntouched() {
        let note = area("""
        # Health

        Some prose about why.

        ## Standard

        Old words.

        ## Tasks

        - [ ] Walk >2026-10-20

        ## Notes

        Keep the shoes by the door.

        """)
        let written = AreaStandard.note(note, settingText: "New words.")
        XCTAssertEqual(written.frontmatter, note.frontmatter)
        XCTAssertTrue(written.body.hasPrefix("# Health\n\nSome prose about why.\n\n## Standard\n\nNew words.\n\n## Tasks\n"))
        XCTAssertTrue(written.body.hasSuffix("- [ ] Walk >2026-10-20\n\n## Notes\n\nKeep the shoes by the door.\n"))
    }

    func testAMissingSectionIsMadeAboveTheFirstSection() {
        let written = AreaStandard.note(area("# Health\n\n## Tasks\n\n- [ ] Walk\n"), settingText: "Three walks a week.")
        XCTAssertEqual(written.body, "# Health\n\n## Standard\n\nThree walks a week.\n\n## Tasks\n\n- [ ] Walk\n")
        XCTAssertEqual(AreaStandard.text(in: written), "Three walks a week.")
    }

    /// Prose under the title belongs to the note, not to the standard: the section goes below
    /// it, or reading the standard back would pick the prose up.
    func testProseUnderTheTitleStaysAboveTheNewSection() {
        let written = AreaStandard.note(area("# Health\n\nWhy this matters to me.\n\n## Tasks\n"),
                                        settingText: "Three walks a week.")
        XCTAssertEqual(AreaStandard.text(in: written), "Three walks a week.")
        XCTAssertTrue(written.body.hasPrefix("# Health\n\nWhy this matters to me.\n\n## Standard\n"))
    }

    func testAMissingSectionInANoteWithNoSectionsGoesAtTheEnd() {
        let written = AreaStandard.note(area("# Health\n\nJust prose.\n"), settingText: "Three walks a week.")
        XCTAssertEqual(written.body, "# Health\n\nJust prose.\n\n## Standard\n\nThree walks a week.\n")
        XCTAssertEqual(AreaStandard.text(in: written), "Three walks a week.")
    }

    func testAHeadingRightAboveTheNextOneGetsABlankLine() {
        let written = AreaStandard.note(area("# Health\n## Tasks\n"), settingText: "Three walks a week.")
        XCTAssertEqual(written.body, "# Health\n\n## Standard\n\nThree walks a week.\n\n## Tasks\n")
    }

    func testSeveralLinesAreKept() {
        let written = AreaStandard.note(shippedArea(), settingText: "- Three walks a week\n- One rest day\n")
        XCTAssertEqual(AreaStandard.text(in: written), "- Three walks a week\n- One rest day")
    }

    func testAnEmptyBoxTakesTheSectionOutWhenThereWasAStandard() {
        let written = AreaStandard.note(shippedArea(), settingText: "Three walks a week.")
        let cleared = AreaStandard.note(written, settingText: "  \n ")
        XCTAssertNil(AreaStandard.text(in: cleared))
        XCTAssertFalse(cleared.body.contains(AreaStandard.heading),
                       "A heading with nothing under it is a promise the note does not keep: \(cleared.body)")
        XCTAssertEqual(cleared.body, "# Health\n\n## Tasks\n\n## Notes\n")
    }

    /// Pressing Save on an empty box must not delete the template's question.
    func testAnEmptyBoxLeavesTheTemplatesQuestionAlone() {
        let note = shippedArea()
        XCTAssertEqual(AreaStandard.note(note, settingText: ""), note)
        XCTAssertEqual(AreaStandard.note(note, settingText: "   \n"), note)
    }

    func testEmptyTextAndNoSectionChangesNothing() {
        let note = area("# Health\n\n## Tasks\n")
        XCTAssertEqual(AreaStandard.note(note, settingText: ""), note)
    }

    func testASecondSaveChangesNothing() {
        let once = AreaStandard.note(shippedArea(), settingText: "Three walks a week.")
        XCTAssertEqual(AreaStandard.note(once, settingText: "Three walks a week."), once)
        XCTAssertEqual(AreaStandard.note(once, settingText: "  Three walks a week.\n"), once,
                       "Space at either end is not a change")
        let changed = AreaStandard.note(once, settingText: "Four walks a week.")
        XCTAssertEqual(AreaStandard.text(in: changed), "Four walks a week.")
        XCTAssertEqual(changed.body.components(separatedBy: AreaStandard.heading).count - 1, 1)
    }

    func testWritingAndReadingBackRoundTrips() {
        let words = "Three runs a week, one rest day, a yearly check-up.\n\n- Sleep before midnight\n- No sugar on weekdays"
        let written = AreaStandard.note(shippedArea(), settingText: words)
        XCTAssertEqual(AreaStandard.text(in: written), words)
        // And through the file's text, which is what the vault stores.
        let reread = Note(relativePath: written.relativePath, kind: .area, text: written.text)
        XCTAssertEqual(AreaStandard.text(in: reread), words)
    }

    /// Words he wrote under the question are kept as his when the question is still there and
    /// he saves them again unchanged.
    func testHisWordsBesideTheQuestionAreNotRewrittenWhenUnchanged() {
        let note = area("# Health\n\n## Standard\n\nWhat does \"good\" look like in this area?\n\nThree walks a week.\n\n## Tasks\n")
        XCTAssertEqual(AreaStandard.note(note, settingText: "Three walks a week."), note)
    }

    // MARK: His own templates

    func testTheStandardLinesOfEveryAreaTemplateAreFound() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        try vault.saveTemplate(named: "Area (long)", text: "---\ntitle: {{title}}\ntype: area\n---\n# {{title}}\n\n## Standard\n\nWhat is \"enough\" here?\n\n## Tasks\n")
        // A project template with a Standard section is not an area template.
        try vault.saveTemplate(named: "Project (odd)", text: "---\ntype: project\n---\n# {{title}}\n\n## Standard\n\nShould not be found\n")

        let lines = vault.areaStandardPlaceholders(among: vault.templates())
        XCTAssertTrue(lines.contains("What does \"good\" look like in this area?"), "The shipped Area template is one of them: \(lines)")
        XCTAssertTrue(lines.contains("What is \"enough\" here?"), "His own: \(lines)")
        XCTAssertFalse(lines.contains("Should not be found"), "Only area templates are read: \(lines)")
        XCTAssertEqual(lines.count, Set(lines).count, "Each line once")
    }
}
