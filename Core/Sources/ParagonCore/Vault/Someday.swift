import Foundation

/// **Someday, and the loose tasks** (build 330, from the advisors' round of 16 Nov 2026).
///
/// About 360 tasks were open and nothing in the week ever looked at the ones without a date:
/// the Weekly review went through the Inbox, the overdue ones, the goals and each project's
/// next action, and a task that was none of these could sit for a year. Two things answer it.
///
/// **Someday** is one task put aside on purpose: "not now, but not given up" — what **On hold**
/// is for a whole project. It is the tag `#someday` on the task's own line, exactly as `#next`
/// marks the next action and `#waiting` a line he waits on, so an older build keeps it, the
/// Reminders sync carries it in the title, and he can write it by hand. A someday task has no
/// date (putting it aside takes the date off), is never a project's next action, and is left
/// out of **All actions** until the **Someday** box is ticked.
///
/// **Loose tasks** are the open ones nothing else looks at: no date, no deadline, not waiting,
/// not someday, not the next action of their project, not in the Inbox (step 1 has those).
/// The review's step 9 shows a few at a time, from the notes left alone longest.
public enum Someday {
    public static let tag = "someday"
    /// How many loose tasks the weekly review shows at a time. A list of 200 is a wall; ten is
    /// a few minutes, and the count beside the heading says how many are left.
    public static let shownAtOnce = 10
}

public extension TaskItem {
    /// Put aside with `#someday`.
    var isSomeday: Bool { tags.contains { NoteIndex.normalized($0) == Someday.tag } }

    /// The task put aside, or taken back. Putting aside takes the date and the time off and the
    /// `#next` mark too: "someday" and "on Thursday" cannot both be true. The deadline stays —
    /// it is a fact about the task, not a plan. Taking back only removes the mark.
    func settingSomeday(_ on: Bool) -> TaskItem {
        var task = self
        if on {
            guard !isSomeday else { return self }
            task = task.settingDueDate(nil)
            task.title = Note.removingTag(Note.nextActionTag, from: task.title) + " #" + Someday.tag
        } else {
            guard isSomeday else { return self }
            task.title = task.title.split(separator: " ")
                .filter { $0.lowercased() != "#" + Someday.tag }.joined(separator: " ")
        }
        return TaskParser.normalized(task)
    }
}

public extension NoteIndex {
    /// The open tasks nothing else in the week looks at, from the notes left alone longest.
    func looseTasks(inboxPath: String? = nil) -> [TaskRef] {
        var found: [(ref: TaskRef, touched: Date)] = []
        for note in notes {
            guard !note.isArchived, !note.isEnded, !note.noteStatus.isOnHold,
                  note.relativePath != inboxPath else { continue }
            let next = note.kind == .project ? note.nextThing?.lineIndex : nil
            for task in note.openTasks {
                guard task.dueDate == nil, task.deadline == nil, !task.isSubtask,
                      !task.isWaiting, !task.isSomeday, task.lineIndex != next,
                      !task.tags.contains(where: { NoteIndex.normalized($0) == Note.nextActionTag })
                else { continue }
                found.append((TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task),
                              note.modifiedAt ?? .distantFuture))
            }
        }
        return found.sorted { a, b in
            if a.touched != b.touched { return a.touched < b.touched }
            if a.ref.notePath != b.ref.notePath { return a.ref.notePath < b.ref.notePath }
            return a.ref.task.lineIndex < b.ref.task.lineIndex
        }.map(\.ref)
    }
}
