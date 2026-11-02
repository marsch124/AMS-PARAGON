import XCTest
@testable import ParagonCore

/// A note's own icon (build 274): `icon:` and `icon-colour:` in the settings block. Core stores
/// the icon package's one-string spelling as it is and never draws anything, so these tests pin
/// only what reaches the file and what is read back — and that an icon **replaces** an emoji
/// while a note nobody touches keeps its emoji.
final class NoteIconTests: XCTestCase {
    private func project(_ lines: String = "") -> Note {
        Note(relativePath: "Projects/Boat.md", kind: .project,
             text: "---\ntitle: Boat\ntype: project\n\(lines)---\n# Boat\n\nSome words.\n")
    }

    private func reread(_ note: Note) -> Note {
        Note(relativePath: note.relativePath, kind: note.kind, text: note.text)
    }

    // The other kinds that take an icon since build 276. Plain titles on purpose: a test that
    // looks for the word "icon" in a note must not find it in the note's own name.

    private func area(_ lines: String = "") -> Note {
        Note(relativePath: "Areas/Health.md", kind: .area,
             text: "---\ntitle: Health\ntype: area\n\(lines)---\n# Health\n\nSome words.\n")
    }

    /// A goal with a date.
    private func goal(_ lines: String = "") -> Note {
        Note(relativePath: "Goals/Walk the Kungsleden.md", kind: .goal,
             text: "---\ntitle: Walk the Kungsleden\ntype: goal\nhorizon: year\ntarget: 2031-08-01\n"
                + "measure: Fifteen days on the trail\n\(lines)---\n# Walk the Kungsleden\n\nSome words.\n")
    }

    /// An aspiration: a goal note whose horizon is `life`.
    private func aspiration(_ lines: String = "") -> Note {
        Note(relativePath: "Goals/Be strong and calm.md", kind: .goal,
             text: "---\ntitle: Be strong and calm\ntype: goal\nhorizon: life\n\(lines)---\n# Be strong and calm\n\nSome words.\n")
    }

    private func resource(_ lines: String = "") -> Note {
        Note(relativePath: "Resources/Packing list.md", kind: .resource,
             text: "---\ntitle: Packing list\ntype: resource\ntags: [travel]\n\(lines)---\n# Packing list\n\nSome words.\n")
    }

    /// The whole way an icon goes on one note, whatever its kind: set, change only the colour,
    /// the same choice again, a lone colour, and **No icon**. `settingIcon` knows nothing about
    /// kinds, so this is the same code for a project, an area, a goal, an aspiration and a
    /// resource; what differs is only which kinds the App lets through (`takesIcon`).
    private func walkThroughTheChoices(_ note: Note, file: StaticString = #filePath, line: UInt = #line) {
        // Set an icon with Automatic: one line, nothing else touched.
        let set = note.settingIcon("hand:bike", colour: nil)
        XCTAssertEqual(set.iconStored, "hand:bike", file: file, line: line)
        XCTAssertNil(set.frontmatter.string(NoteIconFields.colourKey), "Automatic writes no colour line",
                     file: file, line: line)
        XCTAssertEqual(set.ownIcon, .icon("hand:bike", colour: nil), file: file, line: line)
        XCTAssertTrue(set.ownIcon.isIconOrColour, file: file, line: line)
        XCTAssertEqual(set.body, note.body, file: file, line: line)
        XCTAssertEqual(set.frontmatter.keys, note.frontmatter.keys + [NoteIconFields.iconKey],
                       "Every key stays where it was; the new one goes last", file: file, line: line)
        for key in note.frontmatter.keys {
            XCTAssertEqual(set.frontmatter[key], note.frontmatter[key], "\(key) was changed", file: file, line: line)
        }
        XCTAssertEqual(reread(set).iconStored, "hand:bike", "It survives the file", file: file, line: line)

        // Change only the colour: the icon is passed back as it stands.
        let blue = set.settingIcon(set.iconStored, colour: "blue")
        XCTAssertEqual(blue.iconStored, "hand:bike", file: file, line: line)
        XCTAssertEqual(blue.iconColourKey, "blue", file: file, line: line)
        XCTAssertEqual(blue.ownIcon, .icon("hand:bike", colour: "blue"), file: file, line: line)
        XCTAssertEqual(reread(blue).iconColourKey, "blue", file: file, line: line)

        // The same choice again writes nothing.
        XCTAssertEqual(blue.settingIcon("hand:bike", colour: "blue"), blue, file: file, line: line)
        XCTAssertEqual(note.settingIcon(nil, colour: nil), note,
                       "Nothing chosen on a note with nothing writes nothing", file: file, line: line)

        // **No icon** with the colour kept: the colour alone is shown.
        let colourOnly = blue.settingIcon(nil, colour: blue.iconColourKey)
        XCTAssertNil(colourOnly.iconStored, file: file, line: line)
        XCTAssertEqual(colourOnly.ownIcon, .colour("blue"), file: file, line: line)
        XCTAssertTrue(colourOnly.ownIcon.isIconOrColour, file: file, line: line)

        // **No icon** with Automatic: both lines go, and the keys are what they were.
        let cleared = blue.settingIcon(nil, colour: nil)
        XCTAssertEqual(cleared.ownIcon, .unset, file: file, line: line)
        XCTAssertFalse(cleared.text.contains("icon"), "Neither line is left behind, not even an empty one",
                       file: file, line: line)
        XCTAssertEqual(cleared.frontmatter.keys, note.frontmatter.keys, file: file, line: line)
        XCTAssertEqual(cleared.body, note.body, file: file, line: line)

        // A colour on its own, from a note with nothing.
        XCTAssertEqual(note.settingIcon(nil, colour: "green").ownIcon, .colour("green"), file: file, line: line)
    }

    // MARK: Reading

    func testANoteWithNoLinesHasNoIcon() {
        let note = project()
        XCTAssertNil(note.iconStored)
        XCTAssertNil(note.iconColourKey)
        XCTAssertEqual(note.ownIcon, .unset)
        XCTAssertFalse(note.ownIcon.isIconOrColour)
    }

    func testAnEmptyLineReadsAsNothing() {
        // The shape the templates use for a line to fill in, as for `measure:`.
        let note = project("icon:\nicon-colour:\n")
        XCTAssertNil(note.iconStored)
        XCTAssertNil(note.iconColourKey)
        XCTAssertEqual(note.ownIcon, .unset)
    }

    func testAnIconAndItsColourAreReadAsWritten() {
        let note = project("icon: symbol:figure.run\nicon-colour: blue\n")
        XCTAssertEqual(note.iconStored, "symbol:figure.run")
        XCTAssertEqual(note.iconColourKey, "blue")
        XCTAssertEqual(note.ownIcon, .icon("symbol:figure.run", colour: "blue"))
        XCTAssertTrue(note.ownIcon.isIconOrColour)
    }

    func testAHandTypedLineWithSpacesIsTrimmedAndKept() {
        let padded = project("icon:     hand:bike    \nicon-colour:   Blue  \n")
        XCTAssertEqual(padded.iconStored, "hand:bike", "Spaces round the value do not count")
        XCTAssertEqual(padded.iconColourKey, "blue", "A colour key is read in small letters")

        let inside = project("icon: hand: bike\n")
        XCTAssertEqual(inside.iconStored, "hand: bike",
                       "A space inside is the package's to read; Core keeps the words")
        let quoted = project("icon: \"symbol:book\"\n")
        XCTAssertEqual(quoted.iconStored, "symbol:book", "Quotes round the value are the settings block's")
    }

    func testAutomaticIsNoColourWhetherSaidOrLeftOut() {
        XCTAssertNil(project("icon: hand:bike\nicon-colour: auto\n").iconColourKey)
        XCTAssertNil(project("icon: hand:bike\nicon-colour: AUTO\n").iconColourKey)
        XCTAssertNil(project("icon: hand:bike\n").iconColourKey)
    }

    func testAnUnknownPrefixIsKeptAsWrittenAndStillCountsAsAnIcon() {
        // Core cannot tell a newer icon from a mistake, so it keeps the words and says an icon
        // is set; the App draws the dashed circle (build 100: never draw an absence).
        let note = project("icon: emoji:boat\n")
        XCTAssertEqual(note.iconStored, "emoji:boat")
        XCTAssertEqual(note.ownIcon, .icon("emoji:boat", colour: nil))

        let bare = project("icon: bike\n")
        XCTAssertEqual(bare.ownIcon, .icon("bike", colour: nil))
    }

    // MARK: What is shown

    func testAnOldEmojiKeepsShowingWhenNoIconIsSet() {
        let note = project("emoji: \u{26F5}\n")
        XCTAssertEqual(note.ownIcon, .emoji("\u{26F5}"))
        XCTAssertFalse(note.ownIcon.isIconOrColour, "An emoji is not drawn by the icon package")
    }

    func testAnIconWinsOverAnEmojiOnTheSameNote() {
        let note = project("emoji: \u{26F5}\nicon: hand:ferry\n")
        XCTAssertEqual(note.ownIcon, .icon("hand:ferry", colour: nil))
        XCTAssertEqual(note.emoji, "\u{26F5}", "Reading never removes the old line")
    }

    func testALoneColourShowsAsAColourUnlessAnEmojiIsThere() {
        XCTAssertEqual(project("icon-colour: green\n").ownIcon, .colour("green"))
        XCTAssertEqual(project("icon-colour: green\nemoji: \u{26F5}\n").ownIcon, .emoji("\u{26F5}"),
                       "An emoji already chosen keeps showing until it is replaced")
    }

    func testReadingNeverChangesTheNote() {
        let note = project("emoji: \u{26F5}\n")
        let before = note.text
        _ = note.ownIcon
        _ = note.iconStored
        _ = note.iconColourKey
        XCTAssertEqual(note.text, before)
    }

    // MARK: Writing

    func testChoosingAnIconWritesOneLineAndLeavesTheRestAlone() {
        let note = project("area: Home\ntags: [sea, summer]\n")
        let set = note.settingIcon("hand:bike", colour: nil)
        XCTAssertEqual(set.iconStored, "hand:bike")
        XCTAssertNil(set.frontmatter.string(NoteIconFields.colourKey), "Automatic writes no colour line")
        XCTAssertEqual(set.body, note.body)
        XCTAssertEqual(set.frontmatter.keys, note.frontmatter.keys + [NoteIconFields.iconKey],
                       "Every key stays where it was; the new one goes last")
        XCTAssertTrue(set.text.contains("icon: hand:bike\n"))
        XCTAssertEqual(reread(set).iconStored, "hand:bike")
    }

    func testAnAppleSymbolSurvivesTheSettingsBlock() {
        let set = project().settingIcon("symbol:figure.run", colour: "navy")
        let again = reread(set)
        XCTAssertEqual(again.iconStored, "symbol:figure.run")
        XCTAssertEqual(again.iconColourKey, "navy")
        XCTAssertTrue(set.text.contains("icon: symbol:figure.run\n"), "No quotes are needed round it")
        XCTAssertTrue(set.text.contains("icon-colour: navy\n"))
    }

    func testChangingOnlyTheColourKeepsTheIcon() {
        let note = project("icon: hand:bike\nicon-colour: blue\n")
        let red = note.settingIcon(note.iconStored, colour: "red")
        XCTAssertEqual(red.iconStored, "hand:bike")
        XCTAssertEqual(red.iconColourKey, "red")
        XCTAssertEqual(red.frontmatter.keys, note.frontmatter.keys, "The line is changed in its place")
    }

    func testAutomaticTakesTheColourLineAway() {
        let note = project("icon: hand:bike\nicon-colour: blue\n")
        let automatic = note.settingIcon("hand:bike", colour: nil)
        XCTAssertNil(automatic.frontmatter[NoteIconFields.colourKey])
        XCTAssertEqual(automatic.iconStored, "hand:bike")
        let said = note.settingIcon("hand:bike", colour: "auto")
        XCTAssertNil(said.frontmatter[NoteIconFields.colourKey], "auto is never written")
    }

    func testNoIconRemovesTheLineAndNeverWritesAnEmptyOne() {
        let note = project("icon: hand:bike\nicon-colour: blue\n")
        let cleared = note.settingIcon(nil, colour: nil)
        XCTAssertNil(cleared.frontmatter[NoteIconFields.iconKey])
        XCTAssertNil(cleared.frontmatter[NoteIconFields.colourKey])
        XCTAssertFalse(cleared.text.contains("icon"), "Neither line is left behind, not even an empty one")
        XCTAssertEqual(cleared.ownIcon, .unset)

        let emptyText = note.settingIcon("   ", colour: "")
        XCTAssertFalse(emptyText.text.contains("icon"), "Spaces are no icon")
    }

    func testNoIconKeepsTheColourWhenTheCallerKeepsIt() {
        // **No icon** in the picker calls with the colour the note already has: the tile then
        // shows the first letter on that colour.
        let note = project("icon: hand:bike\nicon-colour: blue\n")
        let cleared = note.settingIcon(nil, colour: note.iconColourKey)
        XCTAssertNil(cleared.iconStored)
        XCTAssertEqual(cleared.ownIcon, .colour("blue"))
    }

    func testChoosingAnIconReplacesTheOldEmoji() {
        let note = project("emoji: \u{26F5}\n")
        let set = note.settingIcon("hand:ferry", colour: nil)
        XCTAssertNil(set.frontmatter[ProjectEmoji.key], "The emoji is replaced, not kept beside the icon")
        XCTAssertNil(set.emoji)
        XCTAssertEqual(set.ownIcon, .icon("hand:ferry", colour: nil))
        XCTAssertFalse(set.text.contains("emoji"))
    }

    func testNoIconAlsoTakesTheOldEmojiAway() {
        let note = project("emoji: \u{26F5}\n")
        let cleared = note.settingIcon(nil, colour: nil)
        XCTAssertNil(cleared.emoji)
        XCTAssertEqual(cleared.ownIcon, .unset)
        XCTAssertNotEqual(cleared, note, "Taking the emoji away is a change and is written")
    }

    func testAColourPickedOnAnEmojiNoteReplacesTheEmojiToo() {
        // The picker showed a letter on a plain tile; pressing a colour is a choice in it.
        let note = project("emoji: \u{26F5}\n")
        let set = note.settingIcon(nil, colour: "green")
        XCTAssertNil(set.emoji)
        XCTAssertEqual(set.ownIcon, .colour("green"))
    }

    func testTheSameChoiceAgainWritesNothing() {
        let note = project("icon: hand:bike\nicon-colour: blue\n")
        XCTAssertEqual(note.settingIcon("hand:bike", colour: "blue"), note)
        XCTAssertEqual(note.settingIcon(" hand:bike ", colour: "Blue"), note,
                       "Spaces and capitals are not a change")

        let nothing = project()
        XCTAssertEqual(nothing.settingIcon(nil, colour: nil), nothing,
                       "Nothing chosen on a note with nothing writes nothing")
    }

    func testAnUnknownPrefixIsKeptUntilSomethingIsChosen() {
        let note = project("icon: emoji:boat\n")
        XCTAssertEqual(note.settingIcon("emoji:boat", colour: nil), note,
                       "Setting what is already there is not a change")
        // Changing only the colour passes the stored text back as it was read.
        let coloured = note.settingIcon(note.iconStored, colour: "red")
        XCTAssertEqual(coloured.iconStored, "emoji:boat")
        XCTAssertEqual(coloured.iconColourKey, "red")
        XCTAssertNil(note.settingIcon(nil, colour: nil).iconStored, "No icon takes it away")
    }

    func testAValueThatNeedsQuotesSurvivesTheSettingsBlock() {
        let note = project().settingIcon("hand: bike", colour: nil)
        XCTAssertEqual(reread(note).iconStored, "hand: bike")
        XCTAssertTrue(note.text.contains("icon: \"hand: bike\"\n"))
    }

    func testALineBreakIsJoinedIntoOneLine() {
        let set = project().settingIcon("hand:bike\nhand:car", colour: nil)
        XCTAssertEqual(set.iconStored, "hand:bike hand:car")
        XCTAssertEqual(reread(set).iconStored, "hand:bike hand:car", "A settings line cannot hold two")
    }

    func testTheOtherLinesAndTheBodyAreNeverTouched() {
        let note = project("area: Home\ngoal: Sail\nemoji: \u{26F5}\ntags: [sea]\n")
        let set = note.settingIcon("hand:ferry", colour: "teal-not-in-palette")
        // Core does not know the palette: a key is stored as given (the picker only offers real ones).
        XCTAssertEqual(set.iconColourKey, "teal-not-in-palette")
        for key in ["title", "type", "area", "goal", "tags"] {
            XCTAssertEqual(set.frontmatter[key], note.frontmatter[key], "\(key) was changed")
        }
        XCTAssertEqual(set.body, note.body)
        XCTAssertEqual(set.relativePath, note.relativePath)
    }

    // MARK: Goals, aspirations and resources (build 276)

    func testTheKindsThatTakeAnIconAreProjectsAreasGoalsAndResources() {
        let taking = ParaKind.allCases.filter { $0.takesIcon }
        XCTAssertEqual(Set(taking), Set([ParaKind.project, .area, .goal, .resource]))
        for kind in [ParaKind.inbox, .archive, .daily] {
            XCTAssertFalse(kind.takesIcon, "\(kind) is not a note you choose a picture for")
        }
    }

    func testAGoalWithADateTakesAnIconTheWholeWay() {
        walkThroughTheChoices(goal())
    }

    func testAnAspirationTakesAnIconTheWholeWay() {
        walkThroughTheChoices(aspiration())
    }

    func testAResourceTakesAnIconTheWholeWay() {
        walkThroughTheChoices(resource())
    }

    func testAnAreaAndAProjectStillTakeAnIconTheWholeWay() {
        walkThroughTheChoices(area())
        walkThroughTheChoices(project())
    }

    func testAnIconOnAGoalLeavesWhatTheGoalScreensReadAlone() {
        // The Goals list, the chain and the review read these; an icon line must not move them.
        let note = goal("area: Health\n")
        let set = note.settingIcon("symbol:target", colour: "gold")
        XCTAssertEqual(set.horizon, note.horizon)
        XCTAssertEqual(set.targetDate, note.targetDate)
        XCTAssertEqual(set.measure, "Fifteen days on the trail")
        XCTAssertEqual(set.area, "Health")
        XCTAssertEqual(set.title, note.title)

        let wish = aspiration().settingIcon("hand:ferry", colour: nil)
        XCTAssertEqual(wish.horizon, GoalHorizon.life, "It is still an aspiration")
    }

    func testOnlyAProjectOrAnAreaReadsAnOldEmoji() {
        let line = "emoji: \u{26F5}\n"
        XCTAssertEqual(project(line).ownIcon, .emoji("\u{26F5}"))
        XCTAssertEqual(area(line).ownIcon, .emoji("\u{26F5}"))
        XCTAssertEqual(goal(line).ownIcon, .unset, "A goal never had an emoji and does not start reading one")
        XCTAssertEqual(aspiration(line).ownIcon, .unset)
        XCTAssertEqual(resource(line).ownIcon, .unset)

        // An icon or a colour is read on every kind, with the stray line beside it.
        XCTAssertEqual(goal(line + "icon: hand:ferry\n").ownIcon, .icon("hand:ferry", colour: nil))
        XCTAssertEqual(resource(line + "icon-colour: green\n").ownIcon, .colour("green"))
    }

    func testChoosingAnIconOnAGoalTakesAStrayEmojiLineAwayToo() {
        // `settingIcon` removes `emoji:` whatever the kind, so the rule has one spelling. Nothing
        // in the app wrote the line on a goal; a hand-typed one goes when an icon is chosen.
        let note = goal("emoji: \u{26F5}\n")
        let set = note.settingIcon("hand:ferry", colour: nil)
        XCTAssertNil(set.frontmatter[ProjectEmoji.key])
        XCTAssertEqual(set.ownIcon, .icon("hand:ferry", colour: nil))
    }

    func testAnArchivedNoteKeepsItsIconAndIsStillReadAsItsKind() {
        // Archiving moves the file and keeps the settings block. The note's `kind` is then
        // `.archive`, which takes no icon button, but its own `type:` still says what it is, so
        // a list that draws it can keep its icon.
        let note = Note(relativePath: "Archive/Goals/Sail.md", kind: .archive,
                        text: "---\ntitle: Sail\ntype: goal\nhorizon: year\nstatus: archived\n"
                            + "icon: hand:ferry\nicon-colour: blue\n---\n# Sail\n")
        XCTAssertFalse(note.kind.takesIcon, "No button is offered on a note in the Archive")
        XCTAssertEqual(note.declaredKind, .goal)
        XCTAssertTrue(note.declaredKind.takesIcon)
        XCTAssertEqual(note.ownIcon, .icon("hand:ferry", colour: "blue"))
    }
}
