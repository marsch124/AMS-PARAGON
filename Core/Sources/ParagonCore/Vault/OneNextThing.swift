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
    ///
    /// `nextActions` are the lines Today lists under **Next actions** (`NoteIndex.nextActions()`:
    /// one per project, the `#next` line or else the project's first open line). When they are
    /// handed in, group 3 is exactly those, so this page and Today never name different next
    /// actions; without them, group 3 is every line that carries `#next`.
    public static func queue(from refs: [TaskRef], nextActions given: [TaskRef]? = nil, today: DateOnly) -> [Pick] {
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
        let nextActions: [TaskRef]
        if let given {
            let shown = Set((overdue + dueToday).map { key(for: $0.element) })
            nextActions = given.filter { ref in
                let t = ref.task
                return !t.isDone && !t.isSomeday && !t.isWaiting && t.pressingDay == nil
                    && !shown.contains(key(for: ref))
            }
        } else {
            nextActions = usable.map(\.element).filter { ref in
                ref.task.pressingDay == nil
                    && ref.task.tags.contains { NoteIndex.normalized($0) == Note.nextActionTag }
            }
        }

        return overdue.map { Pick(ref: $0.element, reason: .overdue(days: days(from: $0.element.task.pressingDay, to: today))) }
            + dueToday.map { Pick(ref: $0.element, reason: .dueToday) }
            + nextActions.map { Pick(ref: $0, reason: .nextAction) }
    }

    /// The queue over all notes, with Today's own next actions.
    public static func queue(in index: NoteIndex, today: DateOnly) -> [Pick] {
        queue(from: index.openTasks(), nextActions: index.nextActions(), today: today)
    }

    /// The one to show now: the first of the queue that is not set aside. nil = nothing left.
    public static func pick(from refs: [TaskRef], nextActions: [TaskRef]? = nil, today: DateOnly,
                            setAside: Set<String> = []) -> Pick? {
        queue(from: refs, nextActions: nextActions, today: today).first { !setAside.contains(key(for: $0.ref)) }
    }

    /// The one small line under the task that says why it is the one.
    /// "Overdue since yesterday", "Overdue since Friday" (up to six days), "Overdue since
    /// 2026-11-03" (a week or more), "Due today at 14:00", "Due today", "Next action".
    public static func words(for pick: Pick, today: DateOnly) -> String {
        switch pick.reason {
        case .overdue(let days):
            guard let day = pick.ref.task.pressingDay else { return "Overdue" }
            if days <= 1 { return "Overdue since yesterday" }
            if days < 7 { return "Overdue since \(DayWords.weekday(day))" }
            return "Overdue since \(DayWords.plain(day))"
        case .dueToday:
            if let time = pick.ref.task.dueTime { return "Due today at \(time)" }
            return "Due today"
        case .nextAction:
            return "Next action"
        }
    }

    /// What was set aside with **Not now** counts for one day only: a list written on another
    /// day is empty today.
    public static func setAside(_ keys: [String], writtenOn day: String?, today: DateOnly) -> Set<String> {
        day == today.description ? Set(keys) : []
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
