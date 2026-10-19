import Foundation

/// Tasks finished in each of the last eight weeks (build 255): the small bars on a project's box
/// in the Projects list, and the band at the top of that list. From the drawing he approved
/// (https://claude.ai/artifact/4ByhCcS4cA5kYYNH41b6ap): *"small bars for the tasks you finished
/// each week"*, newest on the right.
///
/// **Calendar weeks, Monday to Sunday** — the same ISO weeks as the weekly notes (`WeekRef`), so
/// "this week" here is the week his weekly note is about, never "the last seven days".
///
/// **Only what the file can prove is counted.** A task is finished on the day of its
/// `@done(…)` stamp; a ticked task with no stamp has no day and is left out rather than
/// guessed. Subtasks count: a finished subtask is finished work. Cancelled tasks do not.
///
/// In Core, with tests, because it decides numbers he reads.
public struct WeeklyFinished: Equatable, Sendable {
    /// How many weeks the bars cover.
    public static let weeks = 8

    /// Tasks finished in each week, oldest first; the last one is this week.
    public var counts: [Int]
    /// The day the most recent task was finished, whenever that was. Nil when no finished
    /// task carries a date at all.
    public var lastFinished: DateOnly?

    public var total: Int { counts.reduce(0, +) }
    public var thisWeek: Int { counts.last ?? 0 }
    /// The biggest week, for drawing the bars to scale. At least 1, so an empty set of bars
    /// never divides by nothing.
    public var biggest: Int { max(counts.max() ?? 0, 1) }
    /// Nothing to draw: no finished task has ever carried a date. A row of empty bars would
    /// then read as "you did nothing", when the truth is "the file cannot say" (build 141).
    public var isEmpty: Bool { lastFinished == nil }

    public init(counts: [Int], lastFinished: DateOnly?) {
        self.counts = counts
        self.lastFinished = lastFinished
    }

    /// Counts the finished tasks among `tasks`.
    public init(tasks: [TaskItem], today: DateOnly) {
        var counts = Array(repeating: 0, count: Self.weeks)
        var last: DateOnly?
        let thisMonday = WeekRef(containing: today).monday
        for task in tasks where task.status == .done {
            guard let stamp = task.doneStamp, let day = DateOnly(String(stamp.prefix(10))) else { continue }
            if last.map({ day > $0 }) ?? true { last = day }
            let monday = WeekRef(containing: day).monday
            let back = thisMonday.days(since: monday, calendar: WeekRef.calendar) / 7
            guard back >= 0, back < Self.weeks else { continue }
            counts[Self.weeks - 1 - back] += 1
        }
        self.init(counts: counts, lastFinished: last)
    }

    /// Several projects added together, for the band at the top of the list.
    public static func combined(_ parts: [WeeklyFinished]) -> WeeklyFinished {
        var counts = Array(repeating: 0, count: weeks)
        var last: DateOnly?
        for part in parts {
            for (index, count) in part.counts.enumerated() where index < weeks {
                counts[index] += count
            }
            if let day = part.lastFinished, last.map({ day > $0 }) ?? true { last = day }
        }
        return WeeklyFinished(counts: counts, lastFinished: last)
    }

    // MARK: Wording

    /// The line beside a box's bars, or nil when there is nothing to say.
    ///
    /// While the project is moving — something finished in the last two weeks — it says how
    /// much: "6 finished in 8 weeks". Once it has gone quiet it says since when: "last task
    /// finished about a month ago". Both from the drawing; the two-week line between them is
    /// what decides which of the two is the more useful fact.
    public func caption(today: DateOnly) -> String? {
        guard let last = lastFinished else { return nil }
        let days = today.days(since: last)
        if days <= 13, total > 0 {
            return "\(total) finished in \(Self.weeks) weeks"
        }
        return "last task finished " + Self.agoText(days: days)
    }

    /// The band at the top of the Projects list: "14 tasks finished in 8 weeks · 2 this week".
    /// Nil when no finished task carries a date at all.
    public var bandText: String? {
        guard let head = bandHead else { return nil }
        return head + " · " + bandWeek
    }

    /// The band's first half, drawn in bold: "14 tasks finished in 8 weeks".
    public var bandHead: String? {
        guard !isEmpty else { return nil }
        return total == 1 ? "1 task finished in \(Self.weeks) weeks"
                          : "\(total) tasks finished in \(Self.weeks) weeks"
    }

    /// The band's second half: "2 this week".
    public var bandWeek: String { "\(thisWeek) this week" }

    /// What the bars say to someone who cannot see them, oldest week first.
    public var spoken: String {
        "Tasks finished each week for \(Self.weeks) weeks, this week last: "
            + counts.map(String.init).joined(separator: ", ")
    }

    /// "⚠ 1 needs a look" on the band, without the sign.
    public static func lookText(_ count: Int) -> String {
        count == 1 ? "1 needs a look" : "\(count) need a look"
    }

    /// "today", "yesterday", "3 days ago", "about a month ago", "about 2 years ago". The same
    /// steps as `DateOnly.timeLeftText(from:)` and `ReviewWording.lookedAt(daysAgo:)`, so the
    /// three never disagree about where days become months.
    public static func agoText(days: Int) -> String {
        if days <= 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 31 { return "\(days) days ago" }
        let months = Int((Double(days) / 30.44).rounded())
        if months < 12 { return months == 1 ? "about a month ago" : "about \(months) months ago" }
        let years = Double(days) / 365.25
        if years < 1.75 { return "about a year ago" }
        return "about \(Int(years.rounded())) years ago"
    }
}
