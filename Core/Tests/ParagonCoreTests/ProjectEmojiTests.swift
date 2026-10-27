import XCTest
@testable import ParagonCore

/// A project's old emoji (build 254). Since build 284 it is only read, never written (an icon
/// replaces it: see `NoteIconTests`). What these pin is what is shown: one emoji, and nothing
/// that is not one.
final class ProjectEmojiTests: XCTestCase {
    func testOnlyAnEmojiIsKept() {
        XCTAssertEqual(ProjectEmoji.cleaned("\u{1F392}"), "\u{1F392}")
        XCTAssertEqual(ProjectEmoji.cleaned("  boat \u{1F6A4} and more \u{26F5}"), "\u{1F6A4}",
                       "The first emoji in a sentence, and nothing else")
        XCTAssertNil(ProjectEmoji.cleaned("boat"))
        XCTAssertNil(ProjectEmoji.cleaned(""))
        XCTAssertNil(ProjectEmoji.cleaned("7"), "A bare digit is an emoji to Unicode only as the start of a keycap")
        XCTAssertNil(ProjectEmoji.cleaned("#"))
        XCTAssertEqual(ProjectEmoji.cleaned("1\u{FE0F}\u{20E3}"), "1\u{FE0F}\u{20E3}", "A keycap is one emoji")
        XCTAssertEqual(ProjectEmoji.cleaned("\u{1F468}\u{200D}\u{1F527}"), "\u{1F468}\u{200D}\u{1F527}",
                       "A joined emoji is one character and is kept whole")
    }

    func testANoteReadsItsEmojiFromTheSettingsBlock() {
        let note = Note(relativePath: "Projects/Boat.md", kind: .project,
                        text: "---\ntitle: Boat\ntype: project\nemoji: \u{26F5}\n---\n")
        XCTAssertEqual(note.emoji, "\u{26F5}")
        let none = Note(relativePath: "Projects/Roof.md", kind: .project,
                        text: "---\ntitle: Roof\ntype: project\nemoji: roof\n---\n")
        XCTAssertNil(none.emoji, "A word on the line is not an emoji")
    }

    func testAKeycapSurvivesTheSettingsBlock() {
        // `#` and `*` start a value the settings block has to quote; the round trip is what
        // decides whether such an emoji can be stored at all.
        var note = Note(relativePath: "Projects/Hash.md", kind: .project,
                        text: "---\ntitle: Hash\ntype: project\n---\n")
        note.frontmatter.set(ProjectEmoji.key, "#\u{FE0F}\u{20E3}")
        let reread = Note(relativePath: note.relativePath, kind: .project, text: note.text)
        XCTAssertEqual(reread.emoji, "#\u{FE0F}\u{20E3}")
    }
}
