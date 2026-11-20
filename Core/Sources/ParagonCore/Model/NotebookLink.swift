import Foundation

/// **Notebook** on a Resource (build 343): a link from a note to a Google notebook (NotebookLM,
/// or a notebook in the Gemini app — the two show the same notebooks), written as
/// `notebook:` in the note's settings block.
///
/// Google offers no way for another app to read a notebook, ask it a question or add a source
/// to it, so PARAGON does the two things it can: it opens the linked notebook, and it hands the
/// note over so he can add it there as a source.
public enum NotebookLink {
    /// The line in the settings block.
    public static let key = "notebook"

    /// The places a notebook lives. Any other address is refused, so the link can only ever
    /// open a Google notebook page.
    public static let hosts = ["notebooklm.google.com", "gemini.google.com"]

    /// Where **Send to notebook** goes when the note has no link yet: the list of his notebooks.
    public static let home = URL(string: "https://notebooklm.google.com/")!

    /// The address he pasted or typed, cleaned: spaces trimmed, `https://` added when missing.
    /// Nil when it is not a page on one of `hosts` (or a part of one, like
    /// `www.notebooklm.google.com`), or not on https.
    public static func cleaned(_ text: String) -> URL? {
        var words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty, !words.contains(" ") else { return nil }
        if !words.lowercased().hasPrefix("http://"), !words.lowercased().hasPrefix("https://") {
            words = "https://" + words
        }
        guard let url = URL(string: words),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else { return nil }
        return url
    }

    /// The note's notebook, or nil when it has none or the line holds something that is not a
    /// notebook address.
    public static func link(of note: Note) -> URL? {
        note.frontmatter.string(key).flatMap(cleaned)
    }

    /// Whether the note's menu offers **Notebook**: every Resource, and any other note that
    /// already has a link (a Resource moved to the Archive keeps its way to the notebook).
    public static func isOffered(for note: Note) -> Bool {
        note.kind == .resource || link(of: note) != nil
    }

    /// The note with its link set, or the line removed when `url` is nil. Every other line and
    /// the body are untouched, and the same link again returns the note as it was, so nothing
    /// is saved for nothing.
    public static func setting(_ url: URL?, on note: Note) -> Note {
        var updated = note
        if let url {
            updated.frontmatter.set(key, url.absoluteString)
        } else {
            updated.frontmatter.remove(key)
        }
        return updated.frontmatter == note.frontmatter ? note : updated
    }
}
