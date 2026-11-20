import Foundation

/// **Your year in one page** (round 350, pick 38): what was finished in one calendar year, read
/// from what the notes already say and nothing else.
///
/// - **Goals** done: a goal with a date (an aspiration is never finished) whose status is Done
///   and whose `ended:` day falls in the year.
/// - **Projects** finished: the same for projects.
/// - **Tasks** done: tasks whose `@done(…)` stamp falls in the year, counted by month.
///
/// **Only what the file can prove** (build 255's rule): a goal or project marked Done with no
/// `ended:` day has no year and is left out; a ticked task with no stamp has no month and is
/// left out. A year with nothing dated in it is `isEmpty`, and the page says so in a sentence
/// instead of drawing twelve empty bars and zeroes (build 141).
public struct YearReview: Equatable, Sendable {
    public var year: Int
    /// Goals with a date that were marked Done in the year, oldest first.
    public var goals: [EndedProject]
    /// Projects marked Done in the year, oldest first.
    public var projects: [EndedProject]
    /// Tasks ticked off, January to December: always twelve numbers.
    public var tasksByMonth: [Int]

    public init(year: Int, goals: [EndedProject] = [], projects: [EndedProject] = [],
                tasksByMonth: [Int] = []) {
        self.year = year
        self.goals = goals
        self.projects = projects
        var months = tasksByMonth
        if months.count < 12 { months += Array(repeating: 0, count: 12 - months.count) }
        self.tasksByMonth = Array(months.prefix(12))
    }

    public static let monthNames: [String] = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    /// "Jan", "Feb" … for the foot of a bar.
    public static func shortMonth(_ month: Int) -> String {
        guard (1...12).contains(month) else { return "" }
        return String(monthNames[month - 1].prefix(3))
    }

    public var tasksDone: Int { tasksByMonth.reduce(0, +) }

    /// The busiest month's task count, at least 1, so the bars have a scale.
    public var biggest: Int { max(1, tasksByMonth.max() ?? 0) }

    /// The month (1 to 12) with the most tasks done; the earlier month when two are level. Nil
    /// when no task was ticked off in the year.
    public var busiestMonth: Int? {
        guard tasksDone > 0, let top = tasksByMonth.max() else { return nil }
        return (tasksByMonth.firstIndex(of: top) ?? 0) + 1
    }

    public var isEmpty: Bool { goals.isEmpty && projects.isEmpty && tasksDone == 0 }

    /// "1 task done", "212 tasks done", or nil for none.
    public var tasksText: String? {
        switch tasksDone {
        case 0: return nil
        case 1: return "1 task done"
        default: return "\(tasksDone) tasks done"
        }
    }

    /// "March, with 34 tasks", or nil when no task was done.
    public var busiestText: String? {
        guard let month = busiestMonth else { return nil }
        let count = tasksByMonth[month - 1]
        let noun = count == 1 ? "1 task" : "\(count) tasks"
        return "\(YearReview.monthNames[month - 1]), with \(noun)"
    }

    /// "3 goals done", "1 goal done", or nil for none.
    public var goalsText: String? {
        switch goals.count {
        case 0: return nil
        case 1: return "1 goal done"
        default: return "\(goals.count) goals done"
        }
    }

    /// "5 projects finished", "1 project finished", or nil for none.
    public var projectsText: String? {
        switch projects.count {
        case 0: return nil
        case 1: return "1 project finished"
        default: return "\(projects.count) projects finished"
        }
    }

    /// A sentence for VoiceOver and the screen test: one line with every fact the page has.
    public var spoken: String {
        var parts: [String] = []
        if let text = goalsText { parts.append(text) }
        if let text = projectsText { parts.append(text) }
        if let text = tasksText { parts.append(text) }
        if let text = busiestText { parts.append("busiest month " + text) }
        return parts.isEmpty ? "\(year): nothing dated yet" : "\(year): " + parts.joined(separator: ", ")
    }
}

public extension NoteIndex {
    /// One calendar year, worked out in one pass over the notes.
    func yearReview(for year: Int) -> YearReview {
        var goals: [EndedProject] = []
        var projects: [EndedProject] = []
        var months = Array(repeating: 0, count: 12)
        for note in notes {
            let kind = note.declaredKind
            if (kind == .goal || kind == .project), note.noteStatus == .done,
               let day = note.endedDate, day.year == year {
                let item = EndedProject(path: note.relativePath, title: note.displayTitle,
                                        status: note.noteStatus, ended: day)
                if kind == .project {
                    projects.append(item)
                } else if note.frontmatter.string("horizon")?.lowercased() != GoalHorizon.life.rawValue {
                    // Read from the line itself: an archived goal's `kind` is `.archive`, which
                    // makes `horizon` nil. An aspiration is never finished and is left out.
                    goals.append(item)
                }
            }
            for task in note.tasks {
                guard let day = task.doneDay, day.year == year, (1...12).contains(day.month) else { continue }
                months[day.month - 1] += 1
            }
        }
        let order: (EndedProject, EndedProject) -> Bool = { a, b in
            a.ended != b.ended ? a.ended < b.ended
                : a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        return YearReview(year: year, goals: goals.sorted(by: order), projects: projects.sorted(by: order),
                          tasksByMonth: months)
    }

    /// The first and the last year the page can show: from the earliest year that has anything
    /// dated (a ticked task or a finished goal or project) to this year. With nothing dated
    /// at all, this year alone.
    func yearRange(today: DateOnly) -> ClosedRange<Int> {
        var first = today.year
        for note in notes {
            if note.noteStatus == .done, let day = note.endedDate, day.year <= today.year {
                first = min(first, day.year)
            }
            for task in note.tasks {
                if let day = task.doneDay, day.year <= today.year { first = min(first, day.year) }
            }
        }
        return first...today.year
    }
}
