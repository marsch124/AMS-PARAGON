import Foundation

/// Build 334: the owner's own **Reason** of the aspiration a task leads to, for the page
/// **One thing**. One quiet line under "Due today · Kungsleden trip".
///
/// The chain is the one the Map, Goals and Aspirations already walk: a note's `goal:` field,
/// resolved by `NoteIndex.goal(matching:)`. Task -> its note (project or area) -> `goal:` goal
/// -> that goal's own `goal:` -> aspiration (a goal with `horizon: life`). A task whose note is
/// itself a goal or an aspiration starts there. A cap and a seen-set keep a loop in the
/// owner's frontmatter from ever spinning.
public enum OneThingWhy {
    /// The trimmed reason, or nil: no note, no chain, no aspiration, or an empty reason.
    public static func reason(forNotePath path: String, in index: NoteIndex,
                              placeholders: [String] = []) -> String? {
        guard var note = index.note(path: path) else { return nil }
        var seen: Set<String> = [note.relativePath]
        for _ in 0..<6 {
            if note.kind == .goal, note.horizon == .life {
                let text = NoteReason.text(in: note, placeholders: placeholders)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (text?.isEmpty ?? true) ? nil : text
            }
            guard let reference = note.goal, let next = index.goal(matching: reference),
                  seen.insert(next.relativePath).inserted else { return nil }
            note = next
        }
        return nil
    }
}
