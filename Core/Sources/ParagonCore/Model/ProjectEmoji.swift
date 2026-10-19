import Foundation

/// A project's own emoji (build 254), kept in its settings block as `emoji: 🎒` so it travels
/// with the note to the other device. The Projects list draws it in the box's tile; the note
/// header's **Emoji…** button writes it.
///
/// In Core, with tests, because it decides what is stored: one emoji and nothing else. A word
/// typed into the field, a digit, or a second emoji after the first never reaches the file.
public enum ProjectEmoji {
    /// The settings key.
    public static let key = "emoji"

    /// One heading and its row of choices in the **Emoji…** list.
    public struct Group: Identifiable, Equatable, Sendable {
        public let title: String
        public let emoji: [String]
        public var id: String { title }
    }

    /// The choices offered first, from the drawing he approved. Spelled as escapes so the
    /// variation selector that makes a text symbol (🖨, ⌨, 🗂, ✈) draw as an emoji is visible
    /// in the source and cannot be lost by an editor; a test checks every one is a single emoji.
    public static let groups: [Group] = [
        Group(title: "Make and build",
              emoji: ["\u{1F5A8}\u{FE0F}", "\u{1F527}", "\u{1FA9A}", "\u{1F4A1}", "\u{1F9F0}", "\u{2328}\u{FE0F}"]),
        Group(title: "Apps and screens",
              emoji: ["\u{1F4F1}", "\u{1F392}", "\u{1F4BB}", "\u{1F9ED}", "\u{1F916}", "\u{1F5C2}\u{FE0F}"]),
        Group(title: "Body and sport",
              emoji: ["\u{1F3CA}", "\u{1F6B4}", "\u{1F3C3}", "\u{1FAC1}", "\u{1F6BF}", "\u{1F9D8}"]),
        Group(title: "Home, boat and travel",
              emoji: ["\u{1F3E1}", "\u{26F5}", "\u{1F331}", "\u{2708}\u{FE0F}", "\u{1F6B2}", "\u{1F9FE}"]),
    ]

    /// The first emoji in the text, or nil when there is none. What the field accepts and what
    /// is read back from a note, so a hand-written `emoji: boat 🚤` still shows 🚤.
    public static func cleaned(_ text: String) -> String? {
        for character in text where isEmoji(character) {
            return String(character)
        }
        return nil
    }

    /// Something Unicode calls an emoji, other than a bare digit, `#` or `*`. Unicode counts
    /// those as emoji because they start a keycap (1️⃣), so alone they are only accepted with
    /// something after them.
    public static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first else { return false }
        if first.properties.isEmojiPresentation { return true }
        guard first.properties.isEmoji else { return false }
        return first.isASCII ? scalars.count > 1 : true
    }
}

public extension Note {
    /// The project's own emoji, read through `ProjectEmoji.cleaned`. Nil when there is none.
    var emoji: String? {
        frontmatter.string(ProjectEmoji.key).flatMap(ProjectEmoji.cleaned)
    }
}
