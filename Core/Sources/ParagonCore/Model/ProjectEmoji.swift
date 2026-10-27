import Foundation

/// A project's own emoji (build 254), kept in its settings block as `emoji: 🎒`.
///
/// **Since build 284 nothing in the app writes this line any more.** A project or an area now
/// chooses an icon from the AMS-Icons package (`NoteIcon.swift`), and an icon replaces an
/// emoji. This type stays for **reading**: a note that already has an `emoji:` line and no icon
/// keeps showing that emoji in its tile exactly as before, and no file is rewritten until an
/// icon is chosen on that note (`Note.settingIcon` then removes the old line). The 24 choices
/// the old **Emoji…** list offered went with it.
///
/// In Core, with tests, because it decides what is read: one emoji and nothing else. A word
/// written on the line, a digit, or a second emoji after the first is never shown.
public enum ProjectEmoji {
    /// The settings key.
    public static let key = "emoji"

    /// The first emoji in the text, or nil when there is none. What is read back from a note,
    /// so a hand-written `emoji: boat 🚤` still shows 🚤.
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
    /// The project's old emoji, read through `ProjectEmoji.cleaned`. Nil when there is none.
    var emoji: String? {
        frontmatter.string(ProjectEmoji.key).flatMap(ProjectEmoji.cleaned)
    }
}
