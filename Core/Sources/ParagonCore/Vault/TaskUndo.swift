import Foundation

// Undo for the two one-press changes (build 277): moving every overdue task to one date, and
// deleting a line in the Inbox.
//
// **Both rules live here, over plain notes, so they can be tested.** The App only keeps the
// record that a press leaves behind and hands it back. The rule is the same in both:
//
//     Undo writes only what it can prove is still as the press left it.
//
// Between a press and the Undo there can be an edit from another device that iCloud has
// brought in, or the user's own typing, and an Undo that wrote over it would be worse than no
// Undo. So a date is put back only on a task that still has the date the press gave it, and a
// deleted line is put back only by *adding* it, never by replacing anything.

// MARK: A date move

/// One task that a one-press move gave a new date, with the date it had before.
///
/// Build 221 said of the move buttons over **Overdue**: *"every task is still there and can be
/// moved again."* That was true and it was not enough. Each task had **its own** old date and
/// the press gave all of them the same new one, so nobody could put the old dates back by
/// hand. This record is what makes that possible.
public struct MovedTask: Equatable, Sendable {
    public var notePath: String
    /// The `^t` id without the caret, when the line had one.
    public var id: String?
    public var title: String
    /// Where the line was when it was pressed. Used first, so two tasks with one name are not
    /// mixed up while the lines have not moved.
    public var lineIndex: Int
    public var oldDate: DateOnly?
    public var newDate: DateOnly

    public init(notePath: String, id: String?, title: String, lineIndex: Int,
                oldDate: DateOnly?, newDate: DateOnly) {
        self.notePath = notePath
        self.id = id
        self.title = title
        self.lineIndex = lineIndex
        self.oldDate = oldDate
        self.newDate = newDate
    }

    /// The task as the screen handed it to the move, and the date it was moved to.
    public init(ref: TaskRef, to newDate: DateOnly) {
        self.init(notePath: ref.notePath, id: ref.task.id, title: ref.task.title,
                  lineIndex: ref.task.lineIndex, oldDate: ref.task.dueDate, newDate: newDate)
    }

    /// False for a task that already had the new date: there is nothing to put back.
    public var changedTheDate: Bool { oldDate != newDate }
}

/// Why a task was left as it is when its date was put back.
public enum UndoSkip: Equatable, Hashable, Sendable {
    /// Ticked off (or cancelled) after the move.
    case done
    /// Still there, but its date is no longer the one the move gave it.
    case changed
    /// Not in its note any more, or its note is not there.
    case gone
    /// More than one task has this name, and nothing says which was which.
    case unclear
    /// Its note could not be written.
    case notWritten
}

public struct SkippedTask: Equatable, Sendable {
    public var title: String
    public var reason: UndoSkip

    public init(title: String, reason: UndoSkip) {
        self.title = title
        self.reason = reason
    }
}

/// What putting the dates back did to one note.
public struct DateUndo: Equatable, Sendable {
    /// The note with the dates put back. Equal to the note it came from when nothing could be.
    public var note: Note
    public var restored: [MovedTask]
    public var skipped: [SkippedTask]
}

public extension Note {
    /// Gives each moved task its old date back — but only a task that is still open and still
    /// has exactly the date the move gave it. Anything else is left alone and named in
    /// `skipped` with the reason.
    ///
    /// **A task is found the way `replace(task:)` finds one**: by its `^t` id, else by its
    /// exact title, trying the line it was on first. Because a title is not an identity, a
    /// match by title alone is trusted only while the pairing is clear: only one moved task
    /// has that name, or every moved task with that name had the same old date, or every one
    /// of them is still on the line it was pressed on. Otherwise the task is skipped as
    /// `.unclear` — a wrong date written on the wrong task is the one mistake an Undo may not
    /// make. The same goes for a task with no id when another task with its name already had
    /// the new date before the press: the two cannot be told apart by their dates.
    ///
    /// Only the date is written. The due time was never touched by the move, so it is not
    /// touched here either. Running this twice does nothing the second time: the dates are no
    /// longer the new ones.
    func undoingDateMoves(_ moves: [MovedTask]) -> DateUndo {
        let mine = moves.filter { $0.notePath == relativePath && $0.changedTheDate }
        var updated = self
        var restored: [MovedTask] = []
        var skipped: [SkippedTask] = []
        var taken = Set<Int>()
        let all = tasks

        func sameIdentity(_ task: TaskItem, _ move: MovedTask) -> Bool {
            if let id = move.id { return task.id == id }
            return task.title == move.title
        }

        for move in mine {
            let found = all.filter { sameIdentity($0, move) && !taken.contains($0.lineIndex) }
            if found.isEmpty {
                skipped.append(SkippedTask(title: move.title, reason: .gone))
                continue
            }
            let fitting = found.filter { !$0.isDone && $0.dueDate == move.newDate }
            if fitting.isEmpty {
                let nearest = found.first { $0.lineIndex == move.lineIndex } ?? found[0]
                skipped.append(SkippedTask(title: move.title, reason: nearest.isDone ? .done : .changed))
                continue
            }
            let sharing = mine.filter { other in
                if let id = move.id { return other.id == id }
                return other.id == nil && other.title == move.title
            }
            let pick: TaskItem
            if sharing.count > 1 && Set(sharing.map { $0.oldDate }).count > 1 {
                // Several moved tasks with one name and different old dates: the only proof of
                // which is which is that every one of them is still on the line it was pressed
                // on. A line that moved by one place could otherwise be given its neighbour's
                // date.
                let allStayed = sharing.allSatisfy { other in
                    all.contains { $0.lineIndex == other.lineIndex && sameIdentity($0, other) }
                }
                guard allStayed, let onItsLine = fitting.first(where: { $0.lineIndex == move.lineIndex }) else {
                    skipped.append(SkippedTask(title: move.title, reason: .unclear))
                    continue
                }
                pick = onItsLine
            } else {
                if move.id == nil {
                    // A task with this name and the new date that was not moved by the press (it
                    // had the date already) looks just like a moved one. When more tasks carry
                    // the new date than were moved, line numbers cannot prove which is which, and
                    // a line added above would make the unmoved one take the old date.
                    let onTheNewDate = all.filter { sameIdentity($0, move) && !$0.isDone && $0.dueDate == move.newDate }.count
                    if onTheNewDate > sharing.count {
                        skipped.append(SkippedTask(title: move.title, reason: .unclear))
                        continue
                    }
                }
                pick = fitting.first(where: { $0.lineIndex == move.lineIndex }) ?? fitting[0]
            }
            var back = pick
            back.dueDate = move.oldDate
            if updated.replace(task: back) {
                taken.insert(pick.lineIndex)
                restored.append(move)
            } else {
                skipped.append(SkippedTask(title: move.title, reason: .gone))
            }
        }
        return DateUndo(note: updated, restored: restored, skipped: skipped)
    }
}

// MARK: A deleted line

/// A task line that was deleted, with its subtasks and enough of what was around it to put it
/// back where it was.
public struct RemovedTask: Equatable, Sendable {
    public var notePath: String
    /// The `^t` id without the caret, when the line had one.
    public var id: String?
    public var title: String
    /// The removed lines exactly as they were, the task first, then its subtasks, with their
    /// indentation. The id is on the first of them.
    public var lines: [String]
    /// Where the first of them was, as an index into the note's lines.
    public var index: Int
    /// The line just before the gap, nil when the task was the first line.
    public var before: String?
    /// The line just after the gap, nil when the task was the last line.
    public var after: String?

    public init(notePath: String, id: String?, title: String, lines: [String], index: Int,
                before: String?, after: String?) {
        self.notePath = notePath
        self.id = id
        self.title = title
        self.lines = lines
        self.index = index
        self.before = before
        self.after = after
    }
}

/// A note with a task taken out, and the record that puts it back.
public struct TaskRemoval: Sendable {
    public let note: Note
    public let record: RemovedTask
}

/// Where a deleted task went back to.
public enum TaskPutBack: Equatable, Sendable {
    /// The lines on both sides were still where they had been: exactly its old place.
    case sameSpot
    /// Its old place had changed; it went straight after the line that used to come before it.
    case afterPrevious
    /// The same, but the line before was gone too; it went straight before the line that used
    /// to come after it.
    case beforeNext
    /// Neither neighbour was there any more: the end of the note's `## Tasks`.
    case endOfTasks
    /// The task is in the note already, so nothing was written.
    case alreadyThere
}

public extension Note {
    /// The same as `removeTaskBlock(for:)`, but not changing this note, and keeping the record
    /// that `putBack(_:)` needs. The removed lines are kept as they stand, with their
    /// indentation, unlike `taskBlock(for:)` which moves them to indent zero.
    func removingTaskBlock(for task: TaskItem) -> TaskRemoval? {
        guard let block = taskBlock(for: task) else { return nil }
        let before = lines
        let start = task.lineIndex
        guard start >= 0, start < before.count else { return nil }
        let end = min(start + block.count, before.count)
        let removedLines = Array(before[start..<end])
        var updated = self
        guard updated.removeTaskBlock(for: task) != nil else { return nil }
        let record = RemovedTask(notePath: relativePath,
                                 id: task.id,
                                 title: task.title,
                                 lines: removedLines,
                                 index: start,
                                 before: start > 0 ? before[start - 1] : nil,
                                 after: end < before.count ? before[end] : nil)
        return TaskRemoval(note: updated, record: record)
    }

    /// Puts a deleted task back. **It only ever adds lines**, so an edit made meanwhile — or a
    /// new capture, which the Inbox often gains within seconds — is never written over.
    ///
    /// In this order:
    /// 1. The task is in the note already (its `^t` id, or with no id the same title on the
    ///    same line text): nothing is written. That is also what makes a second Undo harmless.
    /// 2. The lines on both sides of the gap are still where they were: the old place.
    /// 3. The line that came before is still there: straight after it, past any subtasks of
    ///    the task it belongs to, so a task is never put between a parent and its children.
    /// 4. Only the line that came after is still there: straight before it.
    /// 5. The end of the `## Tasks` section, at the top level.
    @discardableResult
    mutating func putBack(_ removed: RemovedTask) -> TaskPutBack {
        guard let first = removed.lines.first else { return .alreadyThere }
        if holds(removed, firstLine: first) { return .alreadyThere }
        var current = lines

        if Self.neighboursStillThere(removed, in: current) {
            current.insert(contentsOf: removed.lines, at: removed.index)
            lines = current
            return .sameSpot
        }

        let level = TaskParser.parse(line: first)?.indentLevel ?? 0
        if let before = removed.before, Self.isWorthMatching(before),
           let at = Self.nearest(to: removed.index - 1, holding: before, in: current) {
            var place = at + 1
            // After a task, past its own subtasks: the children belong to it, and our line
            // would otherwise take them over.
            if let beforeTask = TaskParser.parse(line: before), beforeTask.indentLevel >= level {
                while place < current.count,
                      let next = TaskParser.parse(line: current[place]), next.indentLevel > level {
                    place += 1
                }
            }
            current.insert(contentsOf: removed.lines, at: place)
            lines = current
            return .afterPrevious
        }

        if let after = removed.after, Self.isWorthMatching(after),
           let at = Self.nearest(to: removed.index, holding: after, in: current) {
            current.insert(contentsOf: removed.lines, at: at)
            lines = current
            return .beforeNext
        }

        // Nothing to hold on to. Back at the top level: an indented line with no parent above
        // it would be a subtask of whatever happens to come before.
        let indent = String(first.prefix { $0 == " " || $0 == "\t" })
        let flat = removed.lines.map { $0.hasPrefix(indent) ? String($0.dropFirst(indent.count)) : $0 }
        appendTaskBlock(flat)
        return .endOfTasks
    }

    private func holds(_ removed: RemovedTask, firstLine: String) -> Bool {
        let current = lines
        for task in tasks {
            if let id = removed.id {
                if task.id == id { return true }
            } else if task.title == removed.title, task.lineIndex < current.count,
                      current[task.lineIndex] == firstLine {
                return true
            }
        }
        return false
    }

    private static func neighboursStillThere(_ removed: RemovedTask, in current: [String]) -> Bool {
        let index = removed.index
        guard index >= 0, index <= current.count else { return false }
        if let before = removed.before {
            guard index >= 1, current[index - 1] == before else { return false }
        } else if index != 0 {
            return false
        }
        if let after = removed.after {
            guard index < current.count, current[index] == after else { return false }
        } else if index != current.count {
            return false
        }
        return true
    }

    /// A blank line is the same line in a hundred places, so it can say nothing about where
    /// a task was.
    private static func isWorthMatching(_ line: String) -> Bool {
        !line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The index of the line equal to `text` that lies closest to `target`.
    private static func nearest(to target: Int, holding text: String, in current: [String]) -> Int? {
        var best: Int?
        for (i, line) in current.enumerated() where line == text {
            if let b = best, abs(b - target) <= abs(i - target) { continue }
            best = i
        }
        return best
    }
}

// MARK: Words

/// The sentences Undo says, in Core so a test can pin each one. All plain and short, with the
/// task's name in curly quotes as the rest of the app writes it.
public enum UndoWording {
    /// How long the **Undo** button stays on offer, in seconds. A message without it stays
    /// for two and a half; this is the time to see it, read it and decide.
    public static let offerSeconds: Double = 8

    /// How long a message stays at the foot of the window. A message with an **Undo** stays the
    /// full `offerSeconds`. Every other message stays two and a half seconds, as it always did:
    /// this build changes the time of the messages that carry an Undo and of no other.
    public static func secondsOnScreen(offersUndo: Bool) -> Double {
        offersUndo ? offerSeconds : 2.5
    }

    private static func quoted(_ title: String) -> String { "\u{201C}\(title)\u{201D}" }

    /// What was said after dates were put back: how many, and for the others which and why.
    public static func datesPutBack(total: Int, restored: Int, skipped: [SkippedTask]) -> String {
        let head: String
        if skipped.isEmpty {
            switch restored {
            case 0: head = "Nothing was put back."
            case 1: head = "1 task put back."
            default: head = "\(restored) tasks put back."
            }
        } else if restored == 0 {
            head = "Nothing was put back."
        } else {
            head = "\(restored) of \(total) tasks put back."
        }
        guard !skipped.isEmpty else { return head }
        return head + " " + leftAsTheyAre(skipped)
    }

    private static func leftAsTheyAre(_ skipped: [SkippedTask]) -> String {
        if skipped.count == 1, let only = skipped.first {
            return "\(quoted(only.title)) \(reason(only.reason, many: false)), so it was left as it is."
        }
        let shown = skipped.prefix(3).map { quoted($0.title) }.joined(separator: ", ")
        let more = skipped.count > 3 ? " and \(skipped.count - 3) more" : ""
        let reasons = Set(skipped.map { $0.reason })
        if reasons.count == 1, let one = reasons.first {
            return "\(skipped.count) \(reason(one, many: true)), so they were left as they are: \(shown)\(more)."
        }
        return "\(skipped.count) tasks were left as they are, because they were ticked off or changed after the move, are not there any more, have the same name as another task, or could not be written: \(shown)\(more)."
    }

    private static func reason(_ reason: UndoSkip, many: Bool) -> String {
        switch reason {
        case .done: return many ? "were ticked off after the move" : "was ticked off after the move"
        case .changed: return many ? "were changed after the move" : "was changed after the move"
        case .gone: return many ? "are not in their notes any more" : "is not in its note any more"
        case .unclear: return many ? "have the same names as other tasks" : "has the same name as another task"
        case .notWritten: return "could not be written"
        }
    }

    /// What was said after a deleted line was put back.
    public static func deletionUndone(title: String, _ outcome: TaskPutBack) -> String {
        switch outcome {
        case .sameSpot: return "\(quoted(title)) put back."
        case .afterPrevious, .beforeNext: return "\(quoted(title)) put back, near where it was."
        case .endOfTasks: return "\(quoted(title)) put back at the end of the tasks, because its old place had changed."
        case .alreadyThere: return "\(quoted(title)) is already there, so nothing was put back."
        }
    }

    /// The note the line was deleted from is not there to put it back into.
    public static func noteMissing(title: String) -> String {
        "\(quoted(title)) could not be put back, because its note is not there."
    }

    /// The note was there but could not be written.
    public static func notWritten(title: String) -> String {
        "\(quoted(title)) could not be put back, because its note could not be written."
    }
}
