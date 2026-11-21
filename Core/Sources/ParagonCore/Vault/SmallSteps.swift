import Foundation

/// **Small steps inside a task** (round 350, pick 36). A task's indented lines are its checklist.
/// This is the one rule for how far along it is: the share of its **direct** subtasks that are
/// ticked. A cancelled subtask is not a step any more, so it counts neither way. Deeper levels
/// belong to the subtask they sit under, so they are not counted twice.
public struct SmallSteps: Equatable, Sendable {
    public var done: Int
    public var total: Int

    public init(done: Int, total: Int) {
        self.done = max(0, done)
        self.total = max(0, total)
    }

    /// Nil when the task has no steps at all: nothing to measure is not "0 of 0" (build 141).
    public var fraction: Double? {
        guard total > 0 else { return nil }
        return min(1, Double(done) / Double(total))
    }

    /// "2/4", or nil with no steps.
    public var text: String? {
        guard total > 0 else { return nil }
        return "\(done)/\(total)"
    }

    /// True when every step is ticked, so the task itself can be ticked off.
    public var isComplete: Bool { total > 0 && done >= total }

    /// A sentence for VoiceOver and the screen tests: "2 of 4 small steps done".
    public var spoken: String? {
        guard total > 0 else { return nil }
        return "\(done) of \(total) small steps done"
    }

    /// The steps of `task`, counted from the subtasks the note holds for it.
    public static func of(_ task: TaskItem, in tasks: [TaskItem]) -> SmallSteps {
        var done = 0
        var total = 0
        for sub in tasks where sub.parentLineIndex == task.lineIndex && sub.lineIndex != task.lineIndex {
            if sub.status == .cancelled { continue }
            total += 1
            if sub.status == .done { done += 1 }
        }
        return SmallSteps(done: done, total: total)
    }
}

public extension Note {
    /// How far along a task is, by its small steps.
    func smallSteps(of task: TaskItem) -> SmallSteps {
        SmallSteps.of(task, in: tasks)
    }

    /// **Round 352: ticking the last small step ticks the task.** Call this right after `step`
    /// was ticked done in this note. When it is a small step, its parent is still open, and
    /// every step under the parent is now done or cancelled (`SmallSteps.isComplete`), the
    /// parent is ticked too — through `complete(task:)`, the same path as any tick, so it gets
    /// its `@done(…)` stamp and a repeating parent gets its next time. It goes on upwards while
    /// the same is true one level higher. Returns the tasks ticked this way (as they were,
    /// innermost first), or an empty list. Unticking a step never unticks a parent: nothing
    /// here is called for that.
    @discardableResult
    mutating func tickParentsWhenStepsDone(afterTicking step: TaskItem, at date: Date = Date(),
                                           calendar: Calendar = .current) -> [TaskItem] {
        var ticked: [TaskItem] = []
        var current = step
        for _ in 0..<20 {
            guard let found = Self.doneLine(of: current, in: tasks),
                  let parentLine = found.parentLineIndex,
                  let parent = tasks.first(where: { $0.lineIndex == parentLine }),
                  parent.status == .open,
                  smallSteps(of: parent).isComplete else { break }
            complete(task: parent, at: date, calendar: calendar)
            ticked.append(parent)
            current = parent
        }
        return ticked
    }

    /// The ticked line that `task` now is: by its id, else by its line and words, else the
    /// first ticked task with its words. Nil when it is not ticked in the note.
    private static func doneLine(of task: TaskItem, in all: [TaskItem]) -> TaskItem? {
        if let id = task.id {
            return all.first { $0.id == id && $0.status == .done }
        }
        return all.first { $0.lineIndex == task.lineIndex && $0.title == task.title && $0.status == .done }
            ?? all.first { $0.title == task.title && $0.status == .done }
    }
}

public extension SmallSteps {
    /// The short message after a tick that also ticked the task above it:
    /// "All steps done, so “Pack the car” is done too." Nil when nothing else was ticked.
    static func parentsDoneMessage(_ titles: [String]) -> String? {
        guard let first = titles.first else { return nil }
        if titles.count == 1 { return "All steps done, so “\(first)” is done too." }
        let quoted = titles.map { "“\($0)”" }
        let names = quoted.dropLast().joined(separator: ", ") + " and " + quoted[quoted.count - 1]
        return "All steps done, so \(names) are done too."
    }
}
