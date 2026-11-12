import Foundation

/// Build 299: the notes captured into the Inbox ("A note" in Capture). They are written as
/// plain `- ` lines under the Inbox note's **Notes** heading (`Vault.capture`), and the Inbox
/// screen lists them under the tasks so they are no longer out of sight.
public enum InboxNotes {
    /// One captured note: its line in the note's full text (0-based), and its words.
    public struct Line: Equatable, Hashable {
        public let index: Int
        public let text: String
        public init(index: Int, text: String) { self.index = index; self.text = text }
    }

    /// The plain `- ` lines under the Notes heading (any level), up to the next heading of the
    /// same or a higher level. Task lines (`- [ ]`) are not notes.
    public static func lines(in text: String) -> [Line] {
        let all = text.components(separatedBy: "\n")
        guard let heading = all.firstIndex(where: { Note.isHeading($0, titled: "Notes") }) else { return [] }
        let level = Note.headingLevel(all[heading])
        var result: [Line] = []
        var i = heading + 1
        while i < all.count {
            let l = Note.headingLevel(all[i])
            if l > 0 && l <= level { break }
            if let words = noteWords(all[i]) { result.append(Line(index: i, text: words)) }
            i += 1
        }
        return result
    }

    /// Make task: the note's line becomes an open task, which the Inbox then lists to sort.
    /// The text stays as it was when the line is not the note it was.
    public static func makingTask(_ text: String, line: Line) -> String {
        var all = text.components(separatedBy: "\n")
        guard line.index < all.count, noteWords(all[line.index]) == line.text else { return text }
        all[line.index] = "- [ ] " + line.text
        return all.joined(separator: "\n")
    }

    /// Delete: the note's line taken out. The text stays as it was when the line is not the note.
    public static func removing(_ text: String, line: Line) -> String {
        var all = text.components(separatedBy: "\n")
        guard line.index < all.count, noteWords(all[line.index]) == line.text else { return text }
        all.remove(at: line.index)
        return all.joined(separator: "\n")
    }

    /// The words of a `- ` or `* ` line that is not a task; nil for anything else.
    static func noteWords(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("- ") || t.hasPrefix("* ") else { return nil }
        let words = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty, !words.hasPrefix("[ ]"), !words.hasPrefix("[x]"), !words.hasPrefix("[X]"),
              !words.hasPrefix("[-]") else { return nil }
        return words
    }
}
