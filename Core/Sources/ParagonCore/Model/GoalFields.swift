import Foundation

/// The two lines a goal is judged by (build 268): `target:`, the day it should be reached by,
/// and `measure:`, one line that says how you will know it is reached.
///
/// **The most repeated fault in this project, once more.** Every screen about goals reads both
/// lines — the Goals list, the chain, the weekly review's "Past its target date" and "Due after
/// its goal" — and until this build nothing in the app wrote `measure:` at all, and `target:`
/// only when a goal was made. That is the fault of `due:` (132), an area's `goal:` (134), a
/// project's `goal:` (140), `tags:` (144) and `status:` (165) in a sixth place. The goal's
/// header now carries **Set a target date…** and **Set a measure…**, and this is what they write.
///
/// In Core, with tests, because it decides what is stored. The rules:
/// - **One line.** A measure typed with a line break is joined into one, the same as a week's
///   goal (`WeekGoal.cleaned`): a settings line cannot hold two.
/// - **An empty value keeps the line and empties it** — `measure:`, the shape the goal template
///   ships — rather than removing it or writing `measure: ""`. The template invites the line to
///   be filled in by hand, and a cleared measure should look exactly like a new goal's.
/// - **Nothing that changes nothing is written.** The same measure or the same day again
///   returns the note as it was, so pressing **Set** twice never moves the file's date or sends
///   it round iCloud (build 254's rule for `emoji:`).
public enum GoalFields {
    /// The settings key for the measure.
    public static let measureKey = "measure"
    /// The settings key for the target date.
    public static let targetKey = "target"

    /// What will be stored as a measure: trimmed, with line breaks and runs of spaces made
    /// single spaces. Empty means "no measure".
    public static func cleaned(_ text: String) -> String {
        WeekGoal.cleaned(text)
    }

    /// The note with its measure set, or emptied when the text is empty or only spaces.
    public static func settingMeasure(_ text: String, on note: Note) -> Note {
        let value = cleaned(text)
        var updated = note
        if value.isEmpty {
            // Nothing to clear: no line, or an empty one already.
            guard note.frontmatter.string(measureKey) != nil else { return note }
            updated.frontmatter.set(measureKey, list: [])
        } else {
            guard note.frontmatter[measureKey] != FrontmatterValue.string(value) else { return note }
            updated.frontmatter.set(measureKey, value)
        }
        return updated
    }

    /// The note with its target date set as `YYYY-MM-DD`, or emptied when the day is nil.
    public static func settingTarget(_ day: DateOnly?, on note: Note) -> Note {
        var updated = note
        if let day {
            guard note.frontmatter[targetKey] != FrontmatterValue.string(day.description) else { return note }
            updated.frontmatter.set(targetKey, day.description)
        } else {
            // A line PARAGON cannot read as a date still counts as something to clear: it is
            // in the file, and **Clear** has to take it away (build 100: what the file holds
            // is never hidden or left behind).
            guard note.frontmatter.string(targetKey) != nil else { return note }
            updated.frontmatter.set(targetKey, list: [])
        }
        return updated
    }
}
