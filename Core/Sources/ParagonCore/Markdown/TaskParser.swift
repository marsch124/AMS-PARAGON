import Foundation

/// One task line in a markdown note, NotePlan style:
/// `- [ ] Call the bank #finance !! >2026-09-10T14:30 @done(2026-09-05 10:00) ^t3fa2c1`
/// Indented task lines below another task are its subtasks.
public struct TaskItem: Equatable, Sendable {
    public enum Status: String, CaseIterable, Sendable {
        case open = " "
        case done = "x"
        case cancelled = "-"
        case scheduled = ">"
    }

    public var status: Status
    /// Task text with markers removed. `#tags` stay in the title on purpose so they round-trip.
    public var title: String
    public var dueDate: DateOnly?
    /// Optional time on the due date (`>2026-09-10T14:30`).
    public var dueTime: TimeOfDay?
    /// 0 = none, 1 = `!`, 2 = `!!`, 3 = `!!!`.
    public var priority: Int
    /// The raw content of `@done(...)`, e.g. `2026-09-05 10:00`.
    public var doneStamp: String?
    /// Tags found in the title, without `#`.
    public var tags: [String]
    /// `@repeat(weekly)`: when the task is completed, a new open copy is created for the next date.
    public var repeatRule: RepeatRule?
    /// `~45m`: how long the task takes, in minutes (build 248). Nil when no time is written.
    public var minutes: Int?
    /// `@since(2026-11-01)`: the day a waiting line started waiting (build 279). Nil when none is
    /// written. A task line has no creation date, so this is the only way to know "waited five
    /// days", and a guess would be a lie.
    public var since: DateOnly?
    /// `@deadline(2026-11-20)`: the day it must be finished by, besides the day he plans to do
    /// it (`dueDate`) (build 316). Moving the do-day never moves it. Not sent to Reminders.
    public var deadline: DateOnly?
    /// Stable id without the caret, e.g. `t3fa2c1`. Assigned on first sync.
    public var id: String?
    public var indent: String
    public var bullet: String
    /// Index of the line inside the note body (0-based).
    public var lineIndex: Int
    /// Line index of the parent task when this line is indented below another task.
    public var parentLineIndex: Int?

    public init(status: Status = .open,
                title: String,
                dueDate: DateOnly? = nil,
                dueTime: TimeOfDay? = nil,
                priority: Int = 0,
                doneStamp: String? = nil,
                tags: [String] = [],
                repeatRule: RepeatRule? = nil,
                minutes: Int? = nil,
                id: String? = nil,
                indent: String = "",
                bullet: String = "-",
                lineIndex: Int = -1,
                parentLineIndex: Int? = nil,
                since: DateOnly? = nil,
                deadline: DateOnly? = nil) {
        self.status = status
        self.title = title
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.priority = min(max(priority, 0), 3)
        self.doneStamp = doneStamp
        self.tags = tags
        self.repeatRule = repeatRule
        self.minutes = minutes.flatMap { $0 > 0 ? $0 : nil }
        self.id = id
        self.indent = indent
        self.bullet = bullet
        self.lineIndex = lineIndex
        self.parentLineIndex = parentLineIndex
        self.since = since
        self.deadline = deadline
    }

    public var isDone: Bool { status == .done || status == .cancelled }

    public var isSubtask: Bool { parentLineIndex != nil }

    /// Nesting depth from the indentation: two spaces (or a tab, counted as four) per level.
    public var indentLevel: Int {
        var width = 0
        for ch in indent { width += ch == "\t" ? 4 : 1 }
        return width / 2
    }

    /// The due moment as a Date, when a date is set.
    public func dueMoment(calendar: Calendar = .current) -> Date? {
        dueDate?.date(at: dueTime, calendar: calendar)
    }

    public var doneDate: Date? {
        guard let doneStamp else { return nil }
        return DoneStamp.date(from: doneStamp)
    }

    public mutating func markDone(at date: Date = Date()) {
        status = .done
        doneStamp = DoneStamp.string(from: date)
    }

    public mutating func markOpen() {
        status = .open
        doneStamp = nil
    }

    public mutating func markCancelled() {
        status = .cancelled
        doneStamp = nil
    }

    /// For a repeating task that was just completed: the next open copy, without an id, due on
    /// the next date after the old due date (or after the completion day when it had none).
    ///
    /// Build 316: a rule that **counts from the day it is finished** starts at the completion
    /// day, whatever date the task had. A **deadline** keeps its distance to the do-day (do on
    /// Tuesday, in by Friday stays so); a task with a deadline and no do-day gets the next
    /// deadline and still no do-day.
    public func nextOccurrence(completedOn day: DateOnly, calendar: Calendar = .current) -> TaskItem? {
        guard let rule = repeatRule else { return nil }
        func following(_ start: DateOnly) -> DateOnly {
            var next = rule.next(after: start, calendar: calendar)
            var guardCount = 0
            while next <= day && guardCount < 400 {
                next = rule.next(after: next, calendar: calendar)
                guardCount += 1
            }
            return next
        }
        var copy = self
        copy.status = .open
        copy.doneStamp = nil
        copy.id = nil
        if let deadline, dueDate == nil {
            copy.deadline = following(rule.afterDone ? day : deadline)
        } else {
            let next = following(rule.afterDone ? day : (dueDate ?? day))
            copy.dueDate = next
            if let deadline, let dueDate {
                copy.deadline = next.adding(days: max(0, dueDate.days(until: deadline, calendar: calendar)), calendar: calendar)
            }
        }
        // A new copy has not started waiting (build 279).
        copy.since = nil
        copy.lineIndex = -1
        return copy
    }

    /// The canonical markdown line for this task.
    public var serialized: String {
        var parts: [String] = [title.trimmingCharacters(in: .whitespaces)]
        if priority > 0 { parts.append(String(repeating: "!", count: priority)) }
        if let minutes, let token = TaskTime.token(minutes) { parts.append(token) }
        if let dueDate { parts.append(">\(dueDate)" + (dueTime.map { "T\($0)" } ?? "")) }
        if let repeatRule { parts.append("@repeat(\(repeatRule))") }
        if let since { parts.append("@since(\(since))") }
        if let deadline { parts.append("@deadline(\(deadline))") }
        if let doneStamp { parts.append("@done(\(doneStamp))") }
        if let id { parts.append("^\(id)") }
        return "\(indent)\(bullet) [\(status.rawValue)] \(parts.joined(separator: " "))"
    }

    public static func makeID() -> String {
        let hex = "0123456789abcdef"
        var out = "t"
        for _ in 0..<6 { out.append(hex.randomElement()!) }
        return out
    }
}

/// How often a task comes back: every N days, weeks, months or years — and, since build 316,
/// on chosen weekdays, on the last day of the month, or counted from the day it is finished.
///
/// In the file it is one word in `@repeat(…)`:
/// `daily`, `weekly`, `2w`, `3m` (as before), `mon,wed,fri`, `weekdays` (Monday to Friday),
/// `monthend`, and `10d after done` for a rule that counts from the day the task is ticked.
public struct RepeatRule: Equatable, Sendable, CustomStringConvertible {
    public enum Unit: String, Sendable, CaseIterable {
        case day = "d", week = "w", month = "m", year = "y"
    }

    public var count: Int
    public var unit: Unit
    /// The chosen weekdays, 1 = Monday … 7 = Sunday, in order. Empty for every other rule.
    /// With days chosen, `count` is 1 and `unit` is `.week`.
    public private(set) var weekdays: [Int] = []
    /// True for "the last day of the month". `count` is 1 and `unit` is `.month`.
    public private(set) var monthEnd = false
    /// "Count from the day I finish it": the next date is counted from the day the task was
    /// ticked, not from the date it had. Only for the every-N rules.
    public var afterDone = false {
        didSet { if !weekdays.isEmpty || monthEnd { afterDone = false } }
    }

    public init(count: Int = 1, unit: Unit, afterDone: Bool = false) {
        self.count = max(1, count)
        self.unit = unit
        self.afterDone = afterDone
    }

    /// On these weekdays (1 = Monday … 7 = Sunday). Nil when none is valid. All seven is
    /// simply every day.
    public init?(weekdays: [Int]) {
        let days = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
        guard !days.isEmpty else { return nil }
        if days.count == 7 {
            self.init(unit: .day)
        } else {
            self.init(unit: .week)
            self.weekdays = days
        }
    }

    /// The last day of every month.
    public static var lastDayOfMonth: RepeatRule {
        var rule = RepeatRule(unit: .month)
        rule.monthEnd = true
        return rule
    }

    /// Monday to Friday.
    public static var workingDays: RepeatRule { RepeatRule(weekdays: [1, 2, 3, 4, 5])! }

    /// True for the every-N rules, the only ones that can count from the day of finishing.
    public var canCountFromDone: Bool { weekdays.isEmpty && !monthEnd }

    static let dayNames = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    /// "Mon" … "Sun", for buttons; index 0 is Monday.
    public static let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let dayWords: [String: Int] = [
        "mon": 1, "monday": 1, "tue": 2, "tues": 2, "tuesday": 2, "wed": 3, "wednesday": 3,
        "thu": 4, "thur": 4, "thurs": 4, "thursday": 4, "fri": 5, "friday": 5,
        "sat": 6, "saturday": 6, "sun": 7, "sunday": 7,
    ]

    /// Accepts `daily`, `weekly`, `monthly`, `yearly`, `2w`, `3 months`, `every 2 weeks` (as
    /// always), and `mon,wed,fri`, `weekdays`, `monthend`, each every-N form followed by
    /// ` after done`.
    public init?(_ text: String) {
        var t = text.lowercased().trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("every ") { t = String(t.dropFirst(6)) }
        var afterDone = false
        for suffix in [" after done", " after-done", " afterdone"] where t.hasSuffix(suffix) {
            t = String(t.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            afterDone = true
        }
        switch t {
        case "daily", "day", "days": self.init(unit: .day, afterDone: afterDone); return
        case "weekly", "week", "weeks": self.init(unit: .week, afterDone: afterDone); return
        case "monthly", "month", "months": self.init(unit: .month, afterDone: afterDone); return
        case "yearly", "annually", "year", "years": self.init(unit: .year, afterDone: afterDone); return
        default: break
        }
        if !afterDone {
            switch t {
            case "weekdays", "workdays", "working days":
                self = .workingDays; return
            case "monthend", "month-end", "month end", "last day of month", "last day of the month", "eom":
                self = .lastDayOfMonth; return
            default: break
            }
            let words = t.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "+" }).map(String.init)
            let days = words.compactMap { Self.dayWords[$0] }
            if !words.isEmpty, days.count == words.count, let rule = RepeatRule(weekdays: days) {
                self = rule; return
            }
        }
        let digits = t.prefix { $0.isNumber }
        let rest = t.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        guard let n = Int(digits), n > 0 else { return nil }
        let unit: Unit?
        switch rest {
        case "d", "day", "days": unit = .day
        case "w", "wk", "week", "weeks": unit = .week
        case "m", "mo", "month", "months": unit = .month
        case "y", "yr", "year", "years": unit = .year
        default: unit = nil
        }
        guard let unit else { return nil }
        self.init(count: n, unit: unit, afterDone: afterDone)
    }

    public var description: String {
        if monthEnd { return "monthend" }
        if weekdays == [1, 2, 3, 4, 5] { return "weekdays" }
        if !weekdays.isEmpty { return weekdays.map { Self.dayNames[$0 - 1] }.joined(separator: ",") }
        var base = "\(count)\(unit.rawValue)"
        if count == 1 {
            switch unit {
            case .day: base = "daily"
            case .week: base = "weekly"
            case .month: base = "monthly"
            case .year: base = "yearly"
            }
        }
        return afterDone ? base + " after done" : base
    }

    /// "Every 2 weeks", for menus.
    public var label: String {
        if monthEnd { return "Last day of the month" }
        if weekdays == [1, 2, 3, 4, 5] { return "Every working day" }
        if !weekdays.isEmpty { return "Every " + weekdays.map { Self.dayLabels[$0 - 1] }.joined(separator: ", ") }
        if afterDone {
            let word: String
            switch unit {
            case .day: word = "day"
            case .week: word = "week"
            case .month: word = "month"
            case .year: word = "year"
            }
            return "\(count) \(word)\(count == 1 ? "" : "s") after it is done"
        }
        switch (count, unit) {
        case (1, .day): return "Every day"
        case (1, .week): return "Every week"
        case (1, .month): return "Every month"
        case (1, .year): return "Every year"
        case (let n, .day): return "Every \(n) days"
        case (let n, .week): return "Every \(n) weeks"
        case (let n, .month): return "Every \(n) months"
        case (let n, .year): return "Every \(n) years"
        }
    }

    public func next(after date: DateOnly, calendar: Calendar = .current) -> DateOnly {
        if !weekdays.isEmpty {
            // The next chosen weekday strictly after the date.
            var day = date
            for _ in 0..<7 {
                day = day.adding(days: 1, calendar: calendar)
                if weekdays.contains(PlainDate.isoWeekday(day, calendar)) { return day }
            }
            return day
        }
        if monthEnd {
            // The end of this month when the date is before it, else the end of the next.
            let thisEnd = Self.lastDay(year: date.year, month: date.month, calendar: calendar)
            if date < thisEnd { return thisEnd }
            let month = date.month == 12 ? 1 : date.month + 1
            return Self.lastDay(year: date.month == 12 ? date.year + 1 : date.year, month: month, calendar: calendar)
        }
        let component: Calendar.Component
        switch unit {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        guard let base = date.date(calendar: calendar),
              let shifted = calendar.date(byAdding: component, value: count, to: base) else { return date }
        return DateOnly(shifted, calendar: calendar)
    }

    private static func lastDay(year: Int, month: Int, calendar: Calendar) -> DateOnly {
        let first = DateOnly(year: year, month: month, day: 1)
        guard let date = first.date(calendar: calendar),
              let range = calendar.range(of: .day, in: .month, for: date) else { return first }
        return DateOnly(year: year, month: month, day: range.count)
    }
}

/// A task's deadline in words (build 316): how far away it is from a day.
public enum TaskDeadline {
    /// Days from `today` to the deadline: 0 on the day, negative when it has passed.
    public static func daysLeft(until deadline: DateOnly, from today: DateOnly, calendar: Calendar = .current) -> Int {
        today.days(until: deadline, calendar: calendar)
    }

    /// "3 days left", "1 day left", "Due today", "1 day late", "4 days late".
    public static func words(until deadline: DateOnly, from today: DateOnly, calendar: Calendar = .current) -> String {
        let left = daysLeft(until: deadline, from: today, calendar: calendar)
        if left == 0 { return "Due today" }
        let n = abs(left)
        return "\(n) day\(n == 1 ? "" : "s") \(left > 0 ? "left" : "late")"
    }

    /// True on the deadline's own day and after it: the words turn red.
    public static func isPressing(_ deadline: DateOnly, on today: DateOnly) -> Bool { deadline <= today }
}

public extension TaskItem {
    /// This task with another deadline, or none. The do-day and everything else stay.
    func settingDeadline(_ day: DateOnly?) -> TaskItem {
        var copy = self
        copy.deadline = day
        return copy
    }
}

public extension DateOnly {
    /// Whole days from this date to `other`; negative when `other` is earlier.
    func days(until other: DateOnly, calendar: Calendar = .current) -> Int {
        guard let a = date(calendar: calendar), let b = other.date(calendar: calendar) else { return 0 }
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }
}

public enum TaskParser {
    static let lineRegex = try! NSRegularExpression(pattern: #"^(\s*)([-*+])\s+\[([ xX>\-])\](?:\s+(.*))?$"#)
    static let idRegex = try! NSRegularExpression(pattern: #"(?<!\S)\^(t[0-9a-f]{4,12})(?!\S)"#)
    static let doneRegex = try! NSRegularExpression(pattern: #"(?<!\S)@done\(([^)]*)\)"#)
    static let dueRegex = try! NSRegularExpression(pattern: #"(?<!\S)>(\d{4}-\d{2}-\d{2})(?:T(\d{1,2}:\d{2}))?(?!\S)"#)
    static let priorityRegex = try! NSRegularExpression(pattern: #"(?<!\S)(!{1,3})(?!\S)"#)
    static let repeatRegex = try! NSRegularExpression(pattern: #"(?<!\S)@repeat\(([^)]*)\)"#)
    /// `@since(2026-11-01)` (build 279), written like `@done(...)`.
    static let sinceRegex = try! NSRegularExpression(pattern: #"(?<!\S)@since\((\d{4}-\d{2}-\d{2})\)"#)
    /// `@deadline(2026-11-20)` (build 316), written like `@since(...)`.
    static let deadlineRegex = try! NSRegularExpression(pattern: #"(?<!\S)@deadline\((\d{4}-\d{2}-\d{2})\)"#)
    static let tagRegex = try! NSRegularExpression(pattern: #"(?<!\S)#([\p{L}\p{N}_/\-]+)"#)

    /// Parses a single line. Returns nil when the line is not a task.
    public static func parse(line: String, lineIndex: Int = -1) -> TaskItem? {
        let ns = line as NSString
        guard let m = lineRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let indent = ns.substring(with: m.range(at: 1))
        let bullet = ns.substring(with: m.range(at: 2))
        let mark = ns.substring(with: m.range(at: 3)).lowercased()
        var rest = m.range(at: 4).location == NSNotFound ? "" : ns.substring(with: m.range(at: 4))
        let status = TaskItem.Status(rawValue: mark) ?? .open

        var id: String?
        var doneStamp: String?
        var dueDate: DateOnly?
        var dueTime: TimeOfDay?
        var priority = 0
        var repeatRule: RepeatRule?
        var minutes: Int?
        var since: DateOnly?
        var deadline: DateOnly?

        rest = extract(idRegex, from: rest) { id = $0 }
        rest = extract(doneRegex, from: rest) { doneStamp = $0.trimmingCharacters(in: .whitespaces) }
        rest = extract(repeatRegex, from: rest) { repeatRule = RepeatRule($0) }
        rest = extract(sinceRegex, from: rest) { since = DateOnly($0) }
        rest = extract(deadlineRegex, from: rest) { deadline = DateOnly($0) ?? deadline }
        let restNS = rest as NSString
        if let due = dueRegex.firstMatch(in: rest, range: NSRange(location: 0, length: restNS.length)) {
            dueDate = DateOnly(restNS.substring(with: due.range(at: 1)))
            if due.range(at: 2).location != NSNotFound {
                dueTime = TimeOfDay(restNS.substring(with: due.range(at: 2)))
            }
            rest = restNS.replacingCharacters(in: due.range, with: " ")
        }
        rest = extract(priorityRegex, from: rest) { priority = max(priority, $0.count) }
        rest = extractTime(from: rest) { minutes = minutes ?? $0 }

        let title = collapseWhitespace(rest)
        let tags = allCaptures(tagRegex, in: title)
        return TaskItem(status: status, title: title, dueDate: dueDate, dueTime: dueTime, priority: priority,
                        doneStamp: doneStamp, tags: tags, repeatRule: repeatRule, minutes: minutes, id: id,
                        indent: indent, bullet: bullet, lineIndex: lineIndex, since: since, deadline: deadline)
    }

    /// Parses every task line in a body, ignoring fenced code blocks. Indented tasks below another
    /// task get that task as `parentLineIndex`; a heading ends the nesting.
    public static func parse(text: String) -> [TaskItem] {
        var result: [TaskItem] = []
        var inFence = false
        var stack: [(level: Int, lineIndex: Int)] = []
        for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if trimmed.hasPrefix("#") {
                stack.removeAll()
                continue
            }
            guard var task = parse(line: String(line), lineIndex: i) else { continue }
            let level = task.indentLevel
            while let top = stack.last, top.level >= level { stack.removeLast() }
            task.parentLineIndex = stack.last?.lineIndex
            stack.append((level, i))
            result.append(task)
        }
        return result
    }

    /// Re-parses a serialized task so derived fields (tags, title) are consistent.
    public static func normalized(_ task: TaskItem) -> TaskItem {
        parse(line: task.serialized, lineIndex: task.lineIndex) ?? task
    }

    // MARK: Helpers

    private static func extract(_ regex: NSRegularExpression, from text: String, _ found: (String) -> Void) -> String {
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }
        var out = ns
        for m in matches.reversed() {
            found(ns.substring(with: m.range(at: 1)))
            out = out.replacingCharacters(in: m.range, with: " ") as NSString
        }
        return out as String
    }

    /// Lifts every `~45m` out of the text. The first one counts; a second is dropped rather
    /// than left in the title, the way a second date would be. A bare `~` is left alone.
    private static func extractTime(from text: String, _ found: (Int) -> Void) -> String {
        let ns = text as NSString
        let matches = TaskTime.regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var out = ns
        var values: [Int] = []
        for m in matches.reversed() {
            guard let value = TaskTime.minutes(inMatch: m, of: ns) else { continue }
            values.append(value)
            out = out.replacingCharacters(in: m.range, with: " ") as NSString
        }
        if let first = values.last { found(first) }
        return out as String
    }

    private static func allCaptures(_ regex: NSRegularExpression, in text: String) -> [String] {
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }

    static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }
}
