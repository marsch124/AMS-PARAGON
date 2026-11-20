import Foundation

/// **An old note comes back** (round 350, pick 43). Once a day Today shows one older Resource,
/// so a note written long ago meets his eyes again.
///
/// The choice is **stable through the day**: the day number picks a place in the sorted list, so
/// every redraw, every device with the same notes and every restart show the same note, and
/// tomorrow shows the next. Nothing is random. Only a Resource that has **not been changed for
/// 30 days or more** counts; a note whose age is not known (no file date) is left out, because
/// "old" must be provable (build 255's rule). Work notes are never in the index, and archived
/// notes are not offered.
public enum OldNoteComesBack {
    /// How many days a note must have lain untouched.
    public static let minimumAgeDays = 30

    /// The first line shown under the title is cut at this many characters.
    public static let lineLength = 140

    /// The notes that may come back, in a fixed order (path, A to Z).
    public static func candidates(in index: NoteIndex, today: DateOnly,
                                  calendar: Calendar = .current) -> [Note] {
        index.notes.filter { note in
            guard note.declaredKind == .resource, !note.isArchived, let changed = note.modifiedAt else { return false }
            let days = today.days(since: DateOnly(changed, calendar: calendar), calendar: calendar)
            return days >= minimumAgeDays
        }
        .sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }

    /// The day's number, counted from a fixed day, so it grows by one each day and is the same
    /// on every device.
    public static func dayNumber(_ day: DateOnly, calendar: Calendar = .current) -> Int {
        DateOnly(year: 2020, month: 1, day: 1).days(until: day, calendar: calendar)
    }

    /// Today's note, or nil when no Resource is old enough.
    public static func pick(in index: NoteIndex, today: DateOnly, calendar: Calendar = .current) -> Note? {
        let list = candidates(in: index, today: today, calendar: calendar)
        guard !list.isEmpty else { return nil }
        let number = dayNumber(today, calendar: calendar)
        let slot = ((number % list.count) + list.count) % list.count
        return list[slot]
    }

    /// The note's first line of text, without its `#` heading marks, list bullet or task box.
    /// Nil when the note has no words. A heading that only repeats
    /// the note's own title is skipped.
    public static func firstLine(of note: Note) -> String? {
        let title = note.displayTitle.trimmingCharacters(in: .whitespaces).lowercased()
        for raw in note.body.split(separator: "\n", omittingEmptySubsequences: true) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("```") || line.hasPrefix("---") { continue }
            while line.hasPrefix("#") { line.removeFirst() }
            for lead in ["- [ ] ", "- [x] ", "- ", "* ", "> "] where line.hasPrefix(lead) {
                line.removeFirst(lead.count)
                break
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.lowercased() == title { continue }
            if line.count > lineLength {
                return String(line.prefix(lineLength)).trimmingCharacters(in: .whitespaces) + "\u{2026}"
            }
            return line
        }
        return nil
    }
}
