import Foundation

/// Build 361, **shared projects** (his ask, 22 Nov 2026: work on projects together with Anna).
///
/// A project whose Reminders list is shared in Apple Reminders carries `shared-with: [Anna]`.
/// Each person has their own notes folder and their own PARAGON; the shared Reminders list is
/// what carries the tasks between them. Two things make that work:
///
/// - **Who does it.** `@who(Anna)` on the task line, `Who: Anna` as the first line of the
///   reminder's notes. It names who is responsible for the task (his words: "not who shared it
///   or who created it"). Apple's own "Assign" is out of reach for apps, so this line is it.
/// - **Whose task it is.** `ams-para-from: Martin` in the reminder's notes, written by the
///   PARAGON that owns the task. Before 361 a reminder carrying a PARAGON mark that no note of
///   this folder knows was always skipped (a fresh device before its notes arrive must never
///   take in or delete its own tasks). In a shared note, a mark from SOMEONE ELSE's folder is
///   now taken in, under the same task id, so both folders hold the same line.
public enum SharedTasks {
    public static let whoPrefix = "Who:"
    public static let fromPrefix = "ams-para-from:"

    /// A name as it may be written: one line, no brackets (they would end `@who(…)`), no
    /// commas (they separate names), trimmed. Nil when nothing is left.
    public static func cleanName(_ raw: String) -> String? {
        let cleaned = raw
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        let words = cleaned.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        return words.isEmpty ? nil : String(words.prefix(40))
    }

    /// Names typed into one field, separated by commas or "and".
    public static func names(from typed: String) -> [String] {
        let parts = typed
            .replacingOccurrences(of: " and ", with: ",")
            .replacingOccurrences(of: " & ", with: ",")
            .split(separator: ",")
            .compactMap { cleanName(String($0)) }
        var seen = Set<String>()
        return parts.filter { seen.insert($0.lowercased()).inserted }
    }

    /// The choices for **Who does it**: the owner first, then the people the note is shared
    /// with, then a name already on the task that is neither (so it can be seen and kept).
    public static func people(me: String, sharedWith: [String], current: String? = nil) -> [String] {
        var out: [String] = []
        for name in [me] + sharedWith + [current ?? ""] {
            guard let clean = cleanName(name), !out.contains(where: { $0.lowercased() == clean.lowercased() }) else { continue }
            out.append(clean)
        }
        return out
    }

    /// "Shared with Anna", "Shared with Anna and Erik", "Shared with Anna, Erik and Lisa".
    public static func sharedWords(_ names: [String]) -> String {
        guard let last = names.last else { return "Not shared" }
        if names.count == 1 { return "Shared with \(last)" }
        return "Shared with " + names.dropLast().joined(separator: ", ") + " and " + last
    }

    // MARK: Lines in a reminder's notes

    private static func value(after prefix: String, in notes: String?) -> String? {
        guard let notes else { return nil }
        for line in notes.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix(prefix.lowercased()) {
                return cleanName(String(trimmed.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    /// The name on the `Who:` line, or nil.
    public static func who(inNotes notes: String?) -> String? { value(after: whoPrefix, in: notes) }

    /// The name on the `ams-para-from:` line, or nil.
    public static func from(inNotes notes: String?) -> String? { value(after: fromPrefix, in: notes) }

    private static func setting(_ prefix: String, _ name: String?, in notes: String?, first: Bool) -> String {
        var lines = (notes ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix(prefix.lowercased()) }
        while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        if let name = name.flatMap(cleanName) {
            if first { lines.insert("\(prefix) \(name)", at: 0) } else { lines.append("\(prefix) \(name)") }
        }
        return lines.joined(separator: "\n")
    }

    /// The notes with the `Who:` line set to `name` (first line), or taken out when nil.
    /// Everything else in the notes stays as it was.
    public static func notes(_ notes: String?, who name: String?) -> String {
        setting(whoPrefix, name, in: notes, first: true)
    }

    /// The notes with an `ams-para-from:` line for `name` at the end.
    public static func notes(_ notes: String?, from name: String) -> String {
        setting(fromPrefix, name, in: notes, first: false)
    }

    /// Whether a reminder that carries a PARAGON mark no note of this folder knows is someone
    /// else's task, to be taken in: only in a shared note, only when the reminder says whose it
    /// is and that is not this folder's owner. Every other unknown mark is still left alone,
    /// as before 361 (a fresh device before its notes arrive).
    public static func takesIn(markID: String, knownIDs: Set<String>, noteShared: Bool,
                               from: String?, me: String) -> Bool {
        guard noteShared, !knownIDs.contains(markID), let from, let mine = cleanName(me) else { return false }
        return from.lowercased() != mine.lowercased()
    }
}
