import Foundation

/// A name that starts with an emoji, split into the emoji and the words (build 346).
///
/// A heading such as "🌳 Keep living (curious, interested)" that wraps put its second line
/// under the emoji, not under "Keep". The screen draws the emoji on its own and the words
/// beside it, so a second line starts under the first word.
public enum LeadingEmoji {
    public static func split(_ name: String) -> (emoji: String?, rest: String) {
        guard let first = name.first, isEmoji(first) else { return (nil, name) }
        let rest = name.dropFirst().trimmingCharacters(in: .whitespaces)
        // An emoji alone is the whole name: keep it as the words.
        guard !rest.isEmpty else { return (nil, name) }
        return (String(first), rest)
    }

    /// A picture character: one drawn as an emoji, not a digit, "#" or "*" that only can be.
    static func isEmoji(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first else { return false }
        if c.unicodeScalars.count > 1 { return scalar.properties.isEmoji && !scalar.isASCII }
        return scalar.properties.isEmojiPresentation
    }
}
