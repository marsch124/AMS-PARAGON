import Foundation

/// The goals a note's **Serves…** menu offers, and the order they come in (build 272).
///
/// The menu (`NoteGoalOptions` in the app) used to filter every note in the vault itself, so it
/// offered goals that were already Done, Missed or Dropped, and it drew them in vault order.
/// The **Serves a goal** and **Serves an aspiration** lists on the New note screen went to
/// `NoteIndex` in build 204 and got this right; the menu was the one that was missed. Now both
/// ask the index, so the two cannot disagree about what is live (build 162's rule).
public struct GoalChoices: Equatable, Sendable {
    /// The list that leads for this kind of note: a project delivers a goal with a date, so
    /// those come first for one; everything else serves an aspiration, so those come first.
    public var first: [Note]
    /// The other list. Both are always offered: the review already knows what to say about a
    /// dated goal that only an area serves (build 140).
    public var second: [Note]

    public init(first: [Note], second: [Note]) {
        self.first = first
        self.second = second
    }
}

public extension NoteIndex {
    /// What the menu on `note` lists.
    ///
    /// - Only live goals: `datedGoals()` and `aspirations()` leave out what has ended or been
    ///   archived, in the order the Goals and Aspirations screens use.
    /// - **Never the note itself.** A goal cannot serve itself, and `setLink` refuses that
    ///   without a word, so offering it would be a line in the menu that does nothing.
    /// - **A goal the note already names stays in the list, even when it has ended**, in its
    ///   place by date or by name. The menu ticks the goal that is chosen; one that vanished
    ///   from the list would leave nothing ticked, and no way to see what the note serves
    ///   (build 175's rule). Without it the only sign would be the "Open …" line above.
    func goalChoices(for note: Note) -> GoalChoices {
        var dated = datedGoals().filter { $0.relativePath != note.relativePath }
        var aspirationList = aspirations().filter { $0.relativePath != note.relativePath }

        let current = note.goal.flatMap { goal(matching: $0) }
        if let current, current.relativePath != note.relativePath {
            let isAspiration = (current.horizon ?? .year) == .life
            if isAspiration {
                if !aspirationList.contains(where: { $0.relativePath == current.relativePath }) {
                    aspirationList.append(current)
                    aspirationList.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                }
            } else if !dated.contains(where: { $0.relativePath == current.relativePath }) {
                dated.append(current)
                dated.sort(by: NoteIndex.byTargetThenTitle)
            }
        }

        // `declaredKind`, not `kind`: an archived project still delivers a goal.
        if note.declaredKind == .project {
            return GoalChoices(first: dated, second: aspirationList)
        }
        return GoalChoices(first: aspirationList, second: dated)
    }
}
