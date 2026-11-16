import Foundation

/// What one day looks like across the whole vault.
public struct DayOverview: Identifiable, Equatable, Sendable {
    public var date: DateOnly
    public var dailyNotePath: String?
    /// Open tasks due on this day, anywhere in the vault.
    public var due: [TaskRef]
    /// Tasks completed on this day (by their `@done` stamp).
    public var completed: [TaskRef]
    /// Open tasks written in the daily note without a date.
    public var undated: [TaskRef]

    public var id: DateOnly { date }
    public var overdueCount: Int { due.filter { $0.task.isOverdue(on: .today()) }.count }
    public var isEmpty: Bool { dailyNotePath == nil && due.isEmpty && completed.isEmpty && undated.isEmpty }
}

public struct WeekOverview: Equatable, Sendable {
    public var week: WeekRef
    public var weeklyNotePath: String?
    public var days: [DayOverview]

    public var dueCount: Int { days.reduce(0) { $0 + $1.due.count } }
    public var completedCount: Int { days.reduce(0) { $0 + $1.completed.count } }
}

public struct MonthOverview: Equatable, Sendable {
    public var month: MonthRef
    public var days: [DayOverview]

    public var dueCount: Int { days.reduce(0) { $0 + $1.due.count } }
    public var completedCount: Int { days.reduce(0) { $0 + $1.completed.count } }
}

public extension NoteIndex {
    func dayOverview(for date: DateOnly) -> DayOverview {
        let daily = dailyNote(for: date)
        var undated: [TaskRef] = []
        if let daily {
            undated = daily.openTasks.filter { $0.dueDate == nil }
                .map { TaskRef(notePath: daily.relativePath, noteTitle: daily.displayTitle, task: $0) }
        }
        return DayOverview(date: date,
                           dailyNotePath: daily?.relativePath,
                           due: openTasks(dueOn: date),
                           completed: tasksCompleted(on: date),
                           undated: undated)
    }

    /// Build 330 (the advisors' speed finding): the month grid asked `dayOverview` once for each
    /// of its 35 to 42 days, and every one of those walked every task in every note. This gives
    /// the same answers for many days from ONE walk: the open tasks are listed and sorted once
    /// and shared out by their day, and so are the finished ones.
    func dayOverviews(for dates: [DateOnly]) -> [DateOnly: DayOverview] {
        let wanted = Set(dates)
        guard !wanted.isEmpty else { return [:] }
        var due: [DateOnly: [TaskRef]] = [:]
        for ref in openTasks() {
            guard let day = ref.task.dueDate, wanted.contains(day) else { continue }
            due[day, default: []].append(ref)
        }
        var completed: [DateOnly: [TaskRef]] = [:]
        var dailies: [DateOnly: Note] = [:]
        for note in notes {
            if note.kind == .daily, let day = note.dailyDate, wanted.contains(day), dailies[day] == nil {
                dailies[day] = note
            }
            for task in note.tasks {
                guard let day = task.doneDay, wanted.contains(day) else { continue }
                completed[day, default: []].append(
                    TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
        }
        var result: [DateOnly: DayOverview] = [:]
        for date in wanted {
            let daily = dailies[date]
            let undated = daily.map { note in
                note.openTasks.filter { $0.dueDate == nil }
                    .map { TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: $0) }
            } ?? []
            result[date] = DayOverview(date: date, dailyNotePath: daily?.relativePath,
                                       due: due[date] ?? [], completed: completed[date] ?? [],
                                       undated: undated)
        }
        return result
    }

    func weekOverview(for week: WeekRef) -> WeekOverview {
        WeekOverview(week: week, weeklyNotePath: weeklyNote(for: week)?.relativePath, days: week.days.map(dayOverview(for:)))
    }

    func monthOverview(for month: MonthRef) -> MonthOverview {
        MonthOverview(month: month, days: month.days.map(dayOverview(for:)))
    }

    /// Tasks whose `@done` stamp falls on a day. Through `TaskItem.doneDay` (build 263), the
    /// same reading the Weekly review's step 7 uses, so the two can never count differently.
    func tasksCompleted(on date: DateOnly) -> [TaskRef] {
        var refs: [TaskRef] = []
        for note in notes {
            for task in note.tasks where task.doneDay == date {
                refs.append(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
        }
        return refs
    }

    func weeklyNote(for week: WeekRef) -> Note? {
        notes.first { $0.kind == .daily && $0.weekRef == week }
    }
}
