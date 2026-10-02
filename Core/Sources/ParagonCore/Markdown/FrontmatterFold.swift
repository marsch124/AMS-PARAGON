import Foundation

/// Folds the settings block at the top of a note out of the editor and puts it back on save
/// (build 246). The file is untouched either way; only what the editor shows changes.
///
/// The block is what `MarkdownHighlight` dims: a first line of `---` and the next line of
/// `---`, both lines included, plus the line break after the second so the body starts on a
/// line of its own. `head(of:)` and `body(of:)` always add up to the whole text, which is
/// what lets `joined(head:body:)` restore it exactly.
public enum FrontmatterFold {
    /// The settings block, or nil when the note does not start with one.
    public static func head(of text: String) -> String? {
        guard let end = headEnd(of: text) else { return nil }
        return String(text[..<end])
    }

    /// The text without its settings block.
    public static func body(of text: String) -> String {
        guard let end = headEnd(of: text) else { return text }
        return String(text[end...])
    }

    /// The whole text again. `head` is what `head(of:)` gave for the text the body came from.
    public static func joined(head: String?, body: String) -> String {
        (head ?? "") + body
    }

    /// Where the body starts: just after the line break that ends the closing `---`, or the
    /// end of the text when the closing line is the last one.
    private static func headEnd(of text: String) -> String.Index? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        guard let closing = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else { return nil }
        let closingLine = lines[closing]
        let lineEnd = closingLine.endIndex
        return lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
    }
}
