import XCTest
@testable import ParagonCore

/// A note's own icon (build 284): `icon:` and `icon-colour:` in the settings block. Core stores
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
}
