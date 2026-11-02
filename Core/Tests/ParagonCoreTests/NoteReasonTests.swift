import XCTest
@testable import ParagonCore

/// A goal's Reason (build 277): `## Why` in the goal note, read without the template's own
/// question, written without touching the rest of the note. It shares its rules with an area's
/// Standard through `SectionText`, so these tests are the Standard's, asked of the Why.
final class NoteReasonTests: XCTestCase {
    private let day = DateOnly(year: 2026, month: 11, day: 2)

    /// An aspiration made the way `Vault.createNote` makes one: from the shipped template, with
    /// `horizon: life` put in.
    private func shippedAspiration(_ title: String = "Stay fit for the mountains") -> Note {
        let text = Templates.fill(Templates.goal, title: title, date: day)
            .replacingOccurrences(of: "horizon: year", with: "horizon: life")
        return Note(relativePath: "Goals/\(title).md", kind: .goal, text: text)
    }

    private func goal(_ body: String, title: String = "Stay fit for the mountains") -> Note {
        Note(relativePath: "Goals/\(title).md", kind: .goal,
             text: "---\ntitle: \(title)\ntype: goal\nhorizon: life\ncreated: 2026-11-02\n---\n" + body)
    }

    private let shippedQuestion = "What changes in my life when this is true?"

    // MARK: Reading

    func testTheShippedQuestionIsNotAReason() {
        let note = shippedAspiration()
        XCTAssertTrue(note.body.contains("## Why"), "The template still has the heading")
        XCTAssertTrue(note.body.contains(shippedQuestion), "...and the question under it")
        XCTAssertNil(NoteReason.text(in: note), "The question under the heading is not an answer")
    }

    func testTheShippedPlaceholderIsReadOutOfTheTemplateItself() {
        XCTAssertEqual(NoteReason.shippedPlaceholders, [shippedQuestion])
    }

    func testANoteWithNoHeadingHasNoReasonEither() {
        XCTAssertNil(NoteReason.text(in: goal("# Stay fit\n\n## Notes\n\nSomething.\n")))
    }

    func testAHeadingWithNothingUnderItHasNoReason() {
        XCTAssertNil(NoteReason.text(in: goal("# Stay fit\n\n## Why\n\n## What done looks like\n")))
    }

    func testARealReasonIsRead() {
        let note = goal("""
        # Stay fit

        ## Why

        Still walking long days in the fells at 80, with the people I love.

        ## What done looks like

        """)
        XCTAssertEqual(NoteReason.text(in: note),
                       "Still walking long days in the fells at 80, with the people I love.")
    }

    /// He may have reworded the question in his own Goal template, with curly marks, capitals
    /// and double spaces on the way into a note.
    func testHisRewordedTemplateQuestionIsNotAReasonEither() {
        let template = "---\ntitle: {{title}}\ntype: goal\n---\n# {{title}}\n\n## Why\n\nWhat\u{2019}s different in my life when this is true?\n\n## Notes\n"
        let lines = NoteReason.placeholders(inTemplate: template)
        XCTAssertEqual(lines, ["What\u{2019}s different in my life when this is true?"])

        let note = goal("# Stay fit\n\n## Why\n\nwhat's  DIFFERENT in my life when this is true?\n\n## Notes\n")
        XCTAssertNotNil(NoteReason.text(in: note),
                        "Without his template's lines it cannot be told from a reason")
        XCTAssertNil(NoteReason.text(in: note, placeholders: lines),
                     "With his template's line known, case, curly marks and spaces do not matter")
    }

    /// A template line that holds `{{title}}` has had the goal's name put into it by the time
    /// the note exists, so the raw line would never match.
    func testAQuestionThatHoldsTheTitleIsStillAQuestion() {
        let template = "# {{title}}\n\n## Why\n\nWhat does {{title}} change in my life?\n"
        let lines = NoteReason.placeholders(inTemplate: template)
        let note = goal("# Calm\n\n## Why\n\nWhat does Calm change in my life?\n", title: "Calm")
        XCTAssertNil(NoteReason.text(in: note, placeholders: lines))
    }

    func testTheQuestionAboveHisOwnWordsGivesHisWords() {
        let note = goal("""
        # Stay fit

        ## Why

        What changes in my life when this is true?

        I stay independent.

        ## What done looks like

        """)
        XCTAssertEqual(NoteReason.text(in: note), "I stay independent.")
    }

    func testSeveralLinesAndABulletListAreKeptWhole() {
        let note = goal("# Stay fit\n\n## Why\n\nI stay independent.\n\n- Long days in the fells\n- Time with the people I love\n\n## Notes\n")
        XCTAssertEqual(NoteReason.text(in: note),
                       "I stay independent.\n\n- Long days in the fells\n- Time with the people I love")
    }

    func testAnotherHeadingEndsTheSection() {
        let note = goal("# Stay fit\n\n## Why\n\nI stay independent.\n\n## What done looks like\n\nNot part of it.\n")
        XCTAssertEqual(NoteReason.text(in: note), "I stay independent.")
    }

    func testTheHeadingCanBeTypedInAnyCase() {
        let note = goal("# Stay fit\n\n## WHY\n\nI stay independent.\n")
        XCTAssertEqual(NoteReason.text(in: note), "I stay independent.")
    }

    /// A goal with a date has the same section; nothing here asks which kind of goal it is.
    func testAGoalWithADateReadsTheSameWay() {
        let note = Note(relativePath: "Goals/Walk.md", kind: .goal,
                        text: "---\ntitle: Walk\ntype: goal\nhorizon: year\ntarget: 2027-08-15\n---\n# Walk\n\n## Why\n\nBecause I want to.\n")
        XCTAssertEqual(NoteReason.text(in: note), "Because I want to.")
    }

    // MARK: Writing

    func testWritingReplacesTheQuestion() {
        let written = NoteReason.note(shippedAspiration(), settingText: "I stay independent.")
        XCTAssertEqual(NoteReason.text(in: written), "I stay independent.")
        XCTAssertFalse(written.body.contains("What changes"), "The question is gone: \(written.body)")
        XCTAssertEqual(written.body.components(separatedBy: NoteReason.heading).count - 1, 1)
        XCTAssertTrue(written.body.contains("## Why\n\nI stay independent.\n\n## What done looks like"),
                      "A blank line each side of the text, and the next section follows: \(written.body)")
    }

    func testTheRestOfTheNoteIsUntouched() {
        let note = goal("""
        # Stay fit

        Some prose about the idea.

        ## Why

        Old words.

        ## What done looks like

        There is no done.

        ## Notes

        Keep the boots by the door.

        """)
        let written = NoteReason.note(note, settingText: "New words.")
        XCTAssertEqual(written.frontmatter, note.frontmatter)
        XCTAssertTrue(written.body.hasPrefix("# Stay fit\n\nSome prose about the idea.\n\n## Why\n\nNew words.\n\n## What done looks like\n"))
        XCTAssertTrue(written.body.hasSuffix("There is no done.\n\n## Notes\n\nKeep the boots by the door.\n"))
    }

    func testAMissingSectionIsMadeAboveTheFirstSection() {
        let written = NoteReason.note(goal("# Stay fit\n\n## Notes\n\nSomething.\n"), settingText: "I stay independent.")
        XCTAssertEqual(written.body, "# Stay fit\n\n## Why\n\nI stay independent.\n\n## Notes\n\nSomething.\n")
        XCTAssertEqual(NoteReason.text(in: written), "I stay independent.")
    }

    /// Prose under the title belongs to the note, not to the reason: the section goes below it,
    /// or reading the reason back would pick the prose up.
    func testProseUnderTheTitleStaysAboveTheNewSection() {
        let written = NoteReason.note(goal("# Stay fit\n\nSome prose about the idea.\n\n## Notes\n"),
                                      settingText: "I stay independent.")
        XCTAssertEqual(NoteReason.text(in: written), "I stay independent.")
        XCTAssertTrue(written.body.hasPrefix("# Stay fit\n\nSome prose about the idea.\n\n## Why\n"))
    }

    func testAMissingSectionInANoteWithNoSectionsGoesAtTheEnd() {
        let written = NoteReason.note(goal("# Stay fit\n\nJust prose.\n"), settingText: "I stay independent.")
        XCTAssertEqual(written.body, "# Stay fit\n\nJust prose.\n\n## Why\n\nI stay independent.\n")
        XCTAssertEqual(NoteReason.text(in: written), "I stay independent.")
    }

    func testSeveralLinesAreKept() {
        let written = NoteReason.note(shippedAspiration(), settingText: "- Long days in the fells\n- Time with the people I love\n")
        XCTAssertEqual(NoteReason.text(in: written), "- Long days in the fells\n- Time with the people I love")
    }

    func testAnEmptyBoxTakesTheSectionOutWhenThereWasAReason() {
        let shipped = shippedAspiration()
        let written = NoteReason.note(shipped, settingText: "I stay independent.")
        let cleared = NoteReason.note(written, settingText: "  \n ")
        XCTAssertNil(NoteReason.text(in: cleared))
        XCTAssertFalse(cleared.body.contains(NoteReason.heading),
                       "A heading with nothing under it is a promise the note does not keep: \(cleared.body)")
        let withoutWhy = shipped.body.replacingOccurrences(of: "## Why\n\n\(shippedQuestion)\n\n", with: "")
        XCTAssertEqual(cleared.body, withoutWhy, "Everything else in the note is as the template made it")
    }

    /// Pressing Save on an empty box must not delete the template's question.
    func testAnEmptyBoxLeavesTheTemplatesQuestionAlone() {
        let note = shippedAspiration()
        XCTAssertEqual(NoteReason.note(note, settingText: ""), note)
        XCTAssertEqual(NoteReason.note(note, settingText: "   \n"), note)
    }

    func testEmptyTextAndNoSectionChangesNothing() {
        let note = goal("# Stay fit\n\n## Notes\n")
        XCTAssertEqual(NoteReason.note(note, settingText: ""), note)
    }

    func testASecondSaveChangesNothing() {
        let once = NoteReason.note(shippedAspiration(), settingText: "I stay independent.")
        XCTAssertEqual(NoteReason.note(once, settingText: "I stay independent."), once)
        XCTAssertEqual(NoteReason.note(once, settingText: "  I stay independent.\n"), once,
                       "Space at either end is not a change")
        let changed = NoteReason.note(once, settingText: "I stay independent and curious.")
        XCTAssertEqual(NoteReason.text(in: changed), "I stay independent and curious.")
        XCTAssertEqual(changed.body.components(separatedBy: NoteReason.heading).count - 1, 1)
    }

    func testWritingAndReadingBackRoundTrips() {
        let words = "I stay independent.\n\nLong days in the fells.\n\n- With the people I love\n- Without it being a struggle"
        let written = NoteReason.note(shippedAspiration(), settingText: words)
        XCTAssertEqual(NoteReason.text(in: written), words)
        // And through the file's text, which is what the vault stores.
        let reread = Note(relativePath: written.relativePath, kind: .goal, text: written.text)
        XCTAssertEqual(NoteReason.text(in: reread), words)
    }

    /// Words he wrote under the question are kept as his when the question is still there and
    /// he saves them again unchanged.
    func testHisWordsBesideTheQuestionAreNotRewrittenWhenUnchanged() {
        let note = goal("# Stay fit\n\n## Why\n\n\(shippedQuestion)\n\nI stay independent.\n\n## Notes\n")
        XCTAssertEqual(NoteReason.note(note, settingText: "I stay independent."), note)
    }

    func testLineEndingsAreMadePlain() {
        XCTAssertEqual(NoteReason.cleaned("  one\r\ntwo \n"), "one\ntwo")
        let written = NoteReason.note(shippedAspiration(), settingText: "one\r\ntwo")
        XCTAssertFalse(written.body.contains("\r"), "No carriage return in the file: \(written.body)")
        XCTAssertEqual(NoteReason.text(in: written), "one\ntwo")
    }

    /// The Standard and the Reason are different sections and never read each other's words.
    func testTheReasonDoesNotReadAnAreasStandard() {
        let area = Note(relativePath: "Areas/Health.md", kind: .area,
                        text: "---\ntitle: Health\ntype: area\n---\n# Health\n\n## Standard\n\nThree walks a week.\n")
        XCTAssertNil(NoteReason.text(in: area))
        XCTAssertNil(AreaStandard.text(in: goal("# Stay fit\n\n## Why\n\nI stay independent.\n")))
    }

    // MARK: Through the vault

    /// A goal as the vault itself makes it, written, saved and read back from the file.
    func testAGoalMadeByTheVaultHasNoReasonUntilOneIsWritten() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let made = try vault.createNote(kind: .goal, title: "Stay fit for the mountains",
                                        extraFrontmatter: [("horizon", "life")])
        XCTAssertTrue(made.body.contains(shippedQuestion), "The vault used the shipped Goal template")
        XCTAssertNil(NoteReason.text(in: made), "The template's question is not his reason")

        let saved = try vault.save(NoteReason.note(made, settingText: "I stay independent."))
        let reread = try vault.loadNote(relativePath: saved.relativePath)
        XCTAssertEqual(NoteReason.text(in: reread), "I stay independent.")
        XCTAssertEqual(reread.frontmatter.string("horizon"), "life", "The settings block is untouched")
    }

    func testTheWhyLinesOfEveryGoalTemplateAreFound() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        try vault.saveTemplate(named: "Goal (long)", text: "---\ntitle: {{title}}\ntype: goal\n---\n# {{title}}\n\n## Why\n\nWhat is different when this is true?\n\n## Notes\n")
        // An area template with a Why section is not a goal template.
        try vault.saveTemplate(named: "Area (odd)", text: "---\ntype: area\n---\n# {{title}}\n\n## Why\n\nShould not be found\n")

        let lines = vault.goalReasonPlaceholders(among: vault.templates())
        XCTAssertTrue(lines.contains(shippedQuestion), "The shipped Goal template is one of them: \(lines)")
        XCTAssertTrue(lines.contains("What is different when this is true?"), "His own: \(lines)")
        XCTAssertFalse(lines.contains("Should not be found"), "Only goal templates are read: \(lines)")
        XCTAssertEqual(lines.count, Set(lines).count, "Each line once")

        // The Standard's reader still reads area templates and only those.
        let standardLines = vault.areaStandardPlaceholders(among: vault.templates())
        XCTAssertTrue(standardLines.contains("What does \"good\" look like in this area?"))
        XCTAssertFalse(standardLines.contains(shippedQuestion), "A goal template's lines are not the Standard's: \(standardLines)")
    }
}
