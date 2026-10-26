import Foundation

// Build 263: **Look back at the week**, step 7 of the Weekly review. He chose it from the plan
// page (https://claude.ai/artifact/RyZxairjYDdB7KoxiuGZ3S) with "Love them", and answered:
// on Monday and Tuesday it shows the week that has just ended, from Wednesday this week.
//
// Every part of it was already in his notes and drawn nowhere together: the evening line he
// writes in Close the day was saved and never shown again, the week's goal was written once
// and never asked about, and the review only ever looked forward.

/// One day as it was lived: what was ticked off, the time the focus timer measured, the line
/// written in **Close the day**, and the daily note they all came from.
///
/// **One record for every screen that looks back at days** — the Weekly review's step 7 takes
/// seven of them, the Done diary (build 267) takes twelve weeks of them. Two screens that
/// each walked the vault their own way is how two lists of "today's actions" came to disagree
/// before build 174.
public struct DayRecord: Identifiable, Equatable, Sendable {
    public var day: DateOnly
    /// Tasks whose `@done` stamp falls on this day, subtasks included — the rule
    /// `tasksCompleted(on:)` has always had. A ticked task with no stamp has no day.
    public var finished: [TaskRef]
    /// What the focus timer wrote under `## Worked`, added up. **Nil when the day has no worked
    /// line at all**, never 0: "the timer was not used" and "0 minutes" are different answers.
    public var workedMinutes: Int?
    /// The line under `## Looking back`, or "" when none was written.
    public var lookingBack: String
    /// The day's note, when there is one.
    public var dailyNotePath: String?

    public var id: DateOnly { day }

    public init(day: DateOnly, finished: [TaskRef] = [], workedMinutes: Int? = nil,
                lookingBack: String = "", dailyNotePath: String? = nil) {
        self.day = day
        self.finished = finished
        self.workedMinutes = workedMinutes
        self.lookingBack = lookingBack
        self.dailyNotePath = dailyNotePath
    }
}

public extension TaskItem {
    /// The day this task was ticked off, read from its `@done(…)` stamp: the one place a stamp
    /// becomes a day (build 263). `tasksCompleted(on:)` and `(since:)`, a project's health, a
    /// goal's activity and the Projects list's weekly bars all go through it. Nil when the task
    /// is not done or carries no stamp.
    var doneDay: DateOnly? {
        guard status == .done, let stamp = doneStamp else { return nil }
        return DateOnly(String(stamp.prefix(10)))
    }
}

public extension NoteIndex {
    /// Every day from `first` through `last`, oldest first, worked out in **one pass** over the
    /// notes rather than one pass per day.
    func dayRecords(from first: DateOnly, through last: DateOnly) -> [DayRecord] {
        dayRecordsInOnePass(from: first, through: last, earliestUpTo: last).records
    }
}

extension NoteIndex {
    /// `dayRecords(from:through:)`, and in the same pass the earliest day any task in the whole
    /// vault was ticked off, up to `cutoff`. The Done diary (build 267) needs both, and
    /// `Note.tasks` parses the body on every call, so asking for the second in a pass of its own
    /// would parse the whole vault twice.
    func dayRecordsInOnePass(from first: DateOnly, through last: DateOnly,
                             earliestUpTo cutoff: DateOnly) -> (records: [DayRecord], earliest: DateOnly?) {
        var finished: [DateOnly: [TaskRef]] = [:]
        var daily: [DateOnly: Note] = [:]
        var earliest: DateOnly?
        for note in notes {
            if let date = note.dailyDate, date >= first, date <= last {
                daily[date] = note
            }
            for task in note.tasks {
                guard let day = task.doneDay else { continue }
                // A stamp later than the cutoff (typed by hand, or from a device whose clock is
                // ahead) is no one's first finish: WeeklyFinished's rule (review of 255).
                if day <= cutoff, earliest.map({ day < $0 }) ?? true { earliest = day }
                guard day >= first, day <= last else { continue }
                finished[day, default: []].append(
                    TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
        }
        guard first <= last else { return ([], earliest) }
        var records: [DayRecord] = []
        var day = first
        while day <= last {
            let note = daily[day]
            // A line typed by hand that ends before it starts says nothing (PlannedAndWorked's
            // rule, build 259).
            let minutes = (note?.workedSpans ?? []).map(\.minutes).filter { $0 > 0 }
            records.append(DayRecord(day: day,
                                     finished: finished[day] ?? [],
                                     workedMinutes: minutes.isEmpty ? nil : minutes.reduce(0, +),
                                     lookingBack: note?.lookingBack ?? "",
                                     dailyNotePath: note?.relativePath))
            let next = day.adding(days: 1)
            guard next > day else { break }
            day = next
        }
        return (records, earliest)
    }
}

/// A project that ended in the week, for the line "Ended this week: Fix the bike · Done".
public struct EndedProject: Identifiable, Equatable, Sendable {
    public var path: String
    public var title: String
    public var status: NoteStatus
    public var ended: DateOnly

    public var id: String { path }

    public init(path: String, title: String, status: NoteStatus, ended: DateOnly) {
        self.path = path
        self.title = title
        self.status = status
        self.ended = ended
    }
}

/// Step 7 of the Weekly review: one week, looked back at.
public struct WeekLook: Equatable, Sendable {
    public var week: WeekRef
    /// The goal written for that week (`focus:` in the weekly note), or nil.
    public var goal: String?
    /// Monday to Sunday.
    public var days: [DayRecord]
    /// Projects whose `ended:` day falls in the week (build 262), oldest first. Only those that
    /// say how they ended: an archived project has lost that word.
    public var endedProjects: [EndedProject]

    public init(week: WeekRef, goal: String?, days: [DayRecord], endedProjects: [EndedProject]) {
        self.week = week
        self.goal = goal
        self.days = days
        self.endedProjects = endedProjects
    }

    /// Every task ticked off in the week.
    public var finished: [TaskRef] { days.flatMap(\.finished) }

    /// The days with a line from **Close the day**.
    public var evenings: [DayRecord] {
        days.filter { !$0.lookingBack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The busiest day's count, at least 1, so the bars have a scale.
    public var biggest: Int { max(1, days.map(\.finished.count).max() ?? 0) }

    /// The focus timer's minutes added up, or nil when it was not used on any day.
    public var workedMinutes: Int? {
        let known = days.compactMap(\.workedMinutes)
        return known.isEmpty ? nil : known.reduce(0, +)
    }

    /// "1 task finished", "16 tasks finished", or nil for none — the view then says so in a
    /// sentence of its own rather than drawing a zero (build 141).
    public var finishedText: String? {
        switch finished.count {
        case 0: return nil
        case 1: return "1 task finished"
        default: return "\(finished.count) tasks finished"
        }
    }

    /// "6 h 20 min on the focus timer", or nil when it was not used.
    public var workedText: String? {
        guard let minutes = workedMinutes, minutes > 0 else { return nil }
        return "\(TaskTime.total(minutes)) on the focus timer"
    }

    /// The week step 7 opens on: on **Monday and Tuesday** the week that has just ended, from
    /// Wednesday this week. His answer on the plan page: a review is usually done on a Sunday or
    /// a Monday, and both then see a whole week.
    public static func weekToShow(today: DateOnly) -> WeekRef {
        let current = WeekRef(containing: today)
        let intoWeek = today.days(since: current.monday, calendar: WeekRef.calendar)
        return intoWeek < 2 ? current.adding(weeks: -1) : current
    }

    /// The week step 8 asks the goal for (build 264): the one after the week step 7 looks back
    /// at, so the review always ends on the week you are about to work in. On Monday and
    /// Tuesday that is the week you are in; from Wednesday it is next week.
    public static func goalWeek(today: DateOnly) -> WeekRef {
        weekToShow(today: today).adding(weeks: 1)
    }

    /// How a sentence names a week: "this week", "next week", "last week", or "week 45" — and
    /// "week 1 of 2028" when it is in another year. The one place it is decided, so the goal
    /// box on **Calendar › Week** and step 8 can never call one week by two names.
    public static func weekName(_ week: WeekRef, today: DateOnly) -> String {
        let current = WeekRef(containing: today)
        if week == current { return "this week" }
        if week == current.adding(weeks: 1) { return "next week" }
        if week == current.adding(weeks: -1) { return "last week" }
        if week.year != current.year { return "week \(week.week) of \(week.year)" }
        return "week \(week.week)"
    }

    /// The words above a week's goal: "Goal for this week", "Goal for next week", "Goal for
    /// week 45". Before build 264 the box said "Goal for this week" whatever week it showed.
    public static func goalTitle(for week: WeekRef, today: DateOnly) -> String {
        "Goal for " + weekName(week, today: today)
    }
}

public extension NoteIndex {
    /// Step 7's week, worked out from the notes.
    func weekLook(for week: WeekRef) -> WeekLook {
        let days = dayRecords(from: week.monday, through: week.sunday)
        var ended: [EndedProject] = []
        for note in notes where note.declaredKind == .project && note.isEnded {
            guard let day = note.endedDate, week.contains(day) else { continue }
            ended.append(EndedProject(path: note.relativePath, title: note.displayTitle,
                                      status: note.noteStatus, ended: day))
        }
        // Two arrays put together would do, but every project has a day here, so the sort has
        // no ties left but the title — written out so it never depends on the order of `notes`.
        ended.sort { $0.ended != $1.ended ? $0.ended < $1.ended
                                          : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return WeekLook(week: week, goal: weekGoal(for: week), days: days, endedProjects: ended)
    }
}
