import Foundation

/// What leaves the app when a note is shared (review round 8, build 315).
public enum NoteShare {
    /// The three things **Share…** offers.
    public enum Form: String, CaseIterable, Sendable {
        case pdf, text, file
    }

    /// The name of the shared copy: the note's title with the characters a file name cannot
    /// carry (`/`, `:`, `\`) turned into `-`. An empty title is "Note".
    public static func fileName(title: String, ext: String) -> String {
        var name = title
        for bad in ["/", ":", "\\"] { name = name.replacingOccurrences(of: bad, with: "-") }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.allSatisfy({ $0 == "." }) { name = "Note" }
        return "\(name).\(ext)"
    }

    /// The note as plain text: what he wrote, without the settings block at the top and
    /// without the hidden `^t` sync markers. Nothing is changed in the file.
    public static func plainText(of text: String) -> String {
        let body = FrontmatterFold.body(of: TaskIDMasking.hidden(in: text))
        return body.trimmingCharacters(in: .newlines) + "\n"
    }
}
