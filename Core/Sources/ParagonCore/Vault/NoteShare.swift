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

    /// **Send as PDF, for a project** (round 350, pick 40): one line of facts under the title, the
    /// way the page says it on screen: "Active · Serves Build a home · In area Health · Deadline
    /// 2026-12-01 · 3 of 8 tasks done". Nil for every other kind of note, and for a project with
    /// nothing to say. Cancelled tasks are not counted, as in the progress bars.
    public static func factsLine(of note: Note) -> String? {
        guard note.declaredKind == .project else { return nil }
        var parts: [String] = [note.noteStatus.label]
        if let goal = note.goal, !goal.isEmpty { parts.append("Serves " + goal) }
        if let area = note.area, !area.isEmpty { parts.append("In area " + area) }
        if let due = note.dueDate { parts.append("Deadline " + due.description) }
        let all = note.tasks.filter { $0.status != .cancelled }
        if !all.isEmpty {
            let done = all.filter { $0.status == .done }.count
            parts.append("\(done) of \(all.count) tasks done")
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// The note as plain text: what he wrote, without the settings block at the top and
    /// without the hidden `^t` sync markers. Nothing is changed in the file.
    public static func plainText(of text: String) -> String {
        let body = FrontmatterFold.body(of: TaskIDMasking.hidden(in: text))
        return body.trimmingCharacters(in: .newlines) + "\n"
    }
}
