import Foundation

/// Build 332: the ONE task to show when he asks "what now?".
///
/// Why a rule of its own: the Today screen shows a list, and a list asks him to choose. This
/// picks for him, and it must never disagree with Today, so it uses the very same day that
/// Today uses (`TaskItem.pressingDay`: the do-day or the deadline, whichever is earlier).
///
/// The order, first to last:
/// 1. **Overdue**: the one waiting longest first. Same day: a task with a time before one
///    without, then the earlier time, then the order the tasks came in.
/// 2. **Due today**: tasks with a time first (earliest first), then those without, in order.
/// 3. **Next actions**: `#next` tasks that are not dated in the future, in order.
///
/// Never offered: done or cancelled, someday, waiting-for, and anything dated in the future.
public enum OneNextThing {
    public enum Reason: Equatable, Sendable { case overdue(days: Int), dueToday, nextAction }

    public struct Pick: Equatable, Sendable {
        public let ref: TaskRef
        public let reason: Reason
    }

    /// A key that stays the same when lines are added above the task (the line number does not).
    /// The task's `^t` id when it has one, else the note path and the title.
    public static func key(for ref: TaskRef) -> String {
        if let id = ref.task.id, !id.isEmpty { return id }
        return ref.notePath + "#" + ref.task.title
    }

    /// Every candidate, in the order they would be shown one after another.
    public static func queue(from refs: [TaskRef], today: DateOnly) -> [Pick] {
        let usable = refs.enumerated().filter { _, ref in
            let t = ref.task
            guard !t.isDone, !t.isSomeday, !t.isWaiting else { return false }
            if let day = t.pressingDay, day > today { return false }
            return true
        }

        let overdue = usable.filter { $0.element.task.isOverdue(on: today) }.sorted { a, b in
            let (x, y) = (a.element.task, b.element.task)
            if x.pressingDay != y.pressingDay { return (x.pressingDay ?? today) < (y.pressingDay ?? today) }
            return timedFirst(x, y) ?? (a.offset < b.offset)
        }
        let dueToday = usable.filter { $0.element.task.isDue(on: today) }.sorted { a, b in
            timedFirst(a.element.task, b.element.task) ?? (a.offset < b.offset)
        }
        let nextActions = usable.filter { item in
            let t = item.element.task
            return t.pressingDay == nil
                && t.tags.contains { NoteIndex.normalized($0) == Note.nextActionTag }
        }

        return overdue.map { Pick(ref: $0.element, reason: .overdue(days: days(from: $0.element.task.pressingDay, to: today))) }
            + dueToday.map { Pick(ref: $0.element, reason: .dueToday) }
            + nextActions.map { Pick(ref: $0.element, reason: .nextAction) }
    }

    /// The one to show now: the first of the queue that is not set aside. nil = nothing left.
    public static func pick(from refs: [TaskRef], today: DateOnly, setAside: Set<String> = []) -> Pick? {
        queue(from: refs, today: today).first { !setAside.contains(key(for: $0.ref)) }
    }

    /// true = `x` first, false = `y` first, nil = no difference (keep the incoming order).
    private static func timedFirst(_ x: TaskItem, _ y: TaskItem) -> Bool? {
        switch (x.dueTime, y.dueTime) {
        case let (a?, b?): return a == b ? nil : a < b
        case (_?, nil): return true
        case (nil, _?): return false
        default: return nil
        }
    }

    private static func days(from day: DateOnly?, to today: DateOnly) -> Int {
        guard let day else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        guard let a = cal.date(from: DateComponents(year: day.year, month: day.month, day: day.day)),
              let b = cal.date(from: DateComponents(year: today.year, month: today.month, day: today.day))
        else { return 0 }
        return max(0, cal.dateComponents([.day], from: a, to: b).day ?? 0)
    }
}
