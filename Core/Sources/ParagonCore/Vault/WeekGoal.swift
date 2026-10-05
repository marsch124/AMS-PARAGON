import Foundation

/// One line that says what a week is about (build 251), written in that week's note as
/// `focus: The garden before winter`.
///
/// **In the weekly note, not in the app's own files**: it is his to read in any editor, and
/// it travels with the vault. One line, so a goal typed with a line break is joined into one.
/// An empty goal removes the line rather than writing `focus:` — the same reasoning as
/// `setStatus(.active)` removing its line (build 165): a note that says nothing has no goal.
public enum WeekGoal {
    public static let key = "focus"

    /// The goal a weekly note carries, or nil.
    public static func read(from note: Note?) -> String? {
        guard let text = note?.frontmatter.string(key) else { return nil }
        let cleaned = cleaned(text)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// What will be stored: trimmed, with line breaks and runs of spaces made single spaces.
    public static func cleaned(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The note with the goal set, or with the line removed when the text is empty.
    public static func setting(_ text: String, on note: Note) -> Note {
        var updated = note
        let value = cleaned(text)
        if value.isEmpty {
            updated.frontmatter.remove(key)
        } else {
            updated.frontmatter.set(key, value)
        }
        return updated
    }
}

public extension NoteIndex {
    /// The goal written in a week's note, or nil when there is no note or no goal.
    func weekGoal(for week: WeekRef) -> String? {
        WeekGoal.read(from: weeklyNote(for: week))
    }
}

public extension DayOverview {
    /// The task times of the day's open tasks added up (build 251), for the week strip.
    /// Only times that are written count: a task with none adds nothing rather than a guessed
    /// hour, so the number never claims more than the notes say.
    var plannedMinutes: Int {
        due.reduce(0) { $0 + ($1.task.minutes ?? 0) }
    }
}
