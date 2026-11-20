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
}
