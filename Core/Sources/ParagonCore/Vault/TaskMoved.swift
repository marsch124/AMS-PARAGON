import Foundation

/// **A task that is moved again and again** (round 350, pick 48). Every time the do-day of a
/// task is moved to a later day, the line counts it in `@moved(N)` (`TaskItem.settingDue`, the
/// one place a date is written). When it has been moved five times, the row says so and the task
/// menu leads with three honest answers: do it now, split it, or drop it.
public enum TaskMoved {
    /// How many moves make the question worth asking.
    public static let askAt = 5

    /// "Moved 5 times".
    public static func text(for count: Int) -> String {
        count == 1 ? "Moved once" : "Moved \(count) times"
    }
}

public extension TaskItem {
    /// True once the do-day has been moved to a later day `TaskMoved.askAt` times, and while the
    /// task is still open.
    var movedOften: Bool { !isDone && (moved ?? 0) >= TaskMoved.askAt }

    /// "Moved 5 times", or nil when it has never been moved.
    var movedText: String? {
        guard let moved = moved, moved > 0 else { return nil }
        return TaskMoved.text(for: moved)
    }

    /// The task with the count forgotten. Asked after he has answered the question, so it is
    /// not asked again at once; it starts counting from zero.
    func forgettingMoves() -> TaskItem {
        var copy = self
        copy.moved = nil
        return copy
    }
}
