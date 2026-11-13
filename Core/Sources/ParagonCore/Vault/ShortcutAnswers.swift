import Foundation

// Build 317 (features-07): the rules behind PARAGON's actions in Shortcuts and Siri. The
// actions themselves are in the app (`App/Paragon/Intents`); what they say, which task a clock
// starts on and what a spoken capture becomes is decided here, where it is tested.

/// The answer to **"What is due today?"**: one sentence Siri speaks, and the short list shown
/// under it.
///
/// **The same tasks as Today's "Due today" and "Overdue" parts**: open tasks, not in the
/// Archive, dated today (or before today), in Today's own order — `NoteIndex.openTasks`.
public struct DueTodayAnswer: Equatable, Sendable {
    public struct Line: Equatable, Identifiable, Sendable {
        public var id: String
        /// The task's words, without `#tags`.
        public var title: String
        /// "14:00" when the task has a time.
        public var time: String?
        /// The note it is in.
        public var noteTitle: String
        public var priority: Int
    }

    /// How many lines the list shows and how many names the sentence speaks.
    public static let shownLimit = 5
    public static let spokenLimit = 3

    public var day: DateOnly
    /// Everything due today, in Today's order.
    public var due: [Line]
    public var overdueCount: Int

    public init(index: NoteIndex, today: DateOnly) {
        let dated = index.openTasks(dueOnOrBefore: today)
        self.day = today
        self.due = dated.filter { $0.task.dueDate == today }.map(Self.line)
        self.overdueCount = dated.filter { ($0.task.dueDate ?? today) < today }.count
    }

    public init(day: DateOnly, due: [Line], overdueCount: Int) {
        self.day = day
        self.due = due
        self.overdueCount = overdueCount
    }

    static func line(_ ref: TaskRef) -> Line {
        Line(id: ref.id, title: Self.spokenTitle(ref.task), time: ref.task.dueTime.map(DayWords.time),
             noteTitle: ref.noteTitle, priority: ref.task.priority)
    }

    /// A task's words as they are read out: no `#tags`, and never empty.
    public static func spokenTitle(_ task: TaskItem) -> String {
        let plain = CaptureReading.line(task.title, settingTags: [])
        return plain.isEmpty ? task.title : plain
    }

    /// The lines the list shows: the first five.
    public var shown: [Line] { Array(due.prefix(Self.shownLimit)) }
    /// How many are due today beyond the ones shown.
    public var moreCount: Int { max(0, due.count - Self.shownLimit) }

    /// The words under the list, or nil: "and 2 more", "3 overdue", "and 2 more · 3 overdue".
    public var footnote: String? {
        var parts: [String] = []
        if moreCount > 0 { parts.append("and \(moreCount) more") }
        if overdueCount > 0 { parts.append("\(overdueCount) overdue") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    /// The sentence Siri speaks.
    ///
    /// - Nothing: "Nothing is due today."
    /// - One: "One thing is due today: Call the bank at 14:00."
    /// - Two or three: "3 things are due today: A, B and C."
    /// - More: the first three by name, then "and 4 more".
    /// - Overdue tasks add a second sentence: "2 more are overdue." / "One more is overdue."
    public var spoken: String {
        var text: String
        let names = due.prefix(Self.spokenLimit).map { line in
            line.time.map { "\(line.title) at \($0)" } ?? line.title
        }
        switch due.count {
        case 0:
            text = "Nothing is due today."
        case 1:
            text = "One thing is due today: \(names[0])."
        case 2...Self.spokenLimit:
            text = "\(due.count) things are due today: \(Self.list(names))."
        default:
            text = "\(due.count) things are due today: \(names.joined(separator: ", ")), and \(due.count - Self.spokenLimit) more."
        }
        if overdueCount == 1 {
            text += due.isEmpty ? " One thing is overdue." : " One more is overdue."
        } else if overdueCount > 1 {
            text += due.isEmpty ? " \(overdueCount) things are overdue." : " \(overdueCount) more are overdue."
        }
        return text
    }

    /// "A", "A and B", "A, B and C".
    static func list(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
}

/// What **Start focus** starts the clock on when no task was named.
///
/// In this order: the block of today's plan that is **running now**; else the **first task due
/// today** (Today's order); else the **next block** still to come today; else nothing — and the
/// action says so instead of starting a clock on nothing.
public enum FocusPick: Equatable, Sendable {
    case block(PlanBlock)
    case task(TaskRef)
    case nothing

    public static func pick(plan: NowAndNext, dueToday: [TaskRef]) -> FocusPick {
        if let now = plan.now { return .block(now) }
        if let first = dueToday.first { return .task(first) }
        if let next = plan.next { return .block(next) }
        return .nothing
    }
}

/// What the **Add to Inbox** action makes of the words it was given.
public enum ShortcutCapture {
    /// One task for the Inbox, or nil when there are no words.
    ///
    /// Line breaks become spaces (a capture is one line). A day chosen in the action is added as
    /// `>2026-11-14` **unless the words already carry a date**, which then wins — the rule of
    /// **Start the day**'s **+** (`CaptureReading.line(_:datedIfUndated:)`).
    public static func item(text: String, day: DateOnly? = nil, createdAt: Date = Date()) -> CaptureItem? {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        var line = TaskParser.collapseWhitespace(flat).trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return nil }
        if let day { line = CaptureReading.line(line, datedIfUndated: day) }
        return CaptureItem(text: line, target: .inbox, asTask: true, createdAt: createdAt)
    }

    /// What the action answers: "Added to your Inbox." or, with a date, "Added to your Inbox,
    /// for 2026-11-14." `filed` false: the words are kept and go into the Inbox when PARAGON
    /// can reach the vault.
    public static func answer(for item: CaptureItem, filed: Bool) -> String {
        let reading = item.reading
        var when = ""
        if let due = reading.dueDate {
            when = ", for " + DayWords.plain(due) + (reading.dueTime.map { " " + DayWords.time($0) } ?? "")
        }
        return filed
            ? "Added to your Inbox\(when)."
            : "Saved\(when). It goes into your Inbox the next time PARAGON opens your notes."
    }
}
