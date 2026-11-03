import Foundation

/// **Waiting for** (build 279): the lines he has handed to somebody else.
///
/// His week is mostly waiting for people. A line such as "Waiting for Anna: the quote" is not
/// something he can do, so it must not look like his next step, and it must not be forgotten
/// either. This file is the whole rule, in Core where it can be tested, because three screens
/// read it: the **All actions** list grouped by person, the task menu's **Waiting for…**, and
/// `Note.nextThing`, which leaves these lines out of "next".
///
/// ## What a waiting line is
///
/// An **open** task whose tags hold `waiting`, **or** whose title begins with `Waiting for `
/// (capitals do not matter). The second rule finds the lines he wrote by hand before this
/// build, with no tag. A line that is ticked or cancelled is never waiting.
///
/// ```
/// - [ ] Waiting for Anna: the quote >2026-11-06 #waiting @since(2026-11-01)
/// ```
///
/// - The **person** is the words between `Waiting for ` and the first `:`. The **what** is the
///   words after it. With no colon there is no person, and the what is everything after
///   `Waiting for ` (or the whole title, less the tag, when only the tag is there).
/// - The **follow-up date** is the line's ordinary `>date`: the day to ask again.
/// - `@since(2026-11-01)` is **the day the waiting started**. It is the only way to know "waited
///   five days", because a task line has no creation date. **A line with no `@since` never says
///   "waited"**: a guess would be a lie, and a zero would read as an answer (builds 100, 141).
public enum WaitingFor {
    /// The tag a waiting line carries, without the `#`.
    public static let tag = "waiting"
    /// What a hand-written waiting line begins with.
    public static let opening = "Waiting for "

    /// What the rule found in one line.
    public struct Parsed: Equatable, Sendable {
        /// Nil when the line names nobody.
        public var person: String?
        /// The thing waited for, without the person and without `#waiting`.
        public var what: String

        public init(person: String?, what: String) {
            self.person = person
            self.what = what
        }
    }

    /// The person and the thing, or nil when the task is not a waiting line.
    public static func parse(_ task: TaskItem) -> Parsed? {
        guard !task.isDone else { return nil }
        let tagged = task.tags.contains { $0.lowercased() == tag }
        // The cheap check first: this runs for every task of every note, whenever a screen asks
        // for the next thing, and nearly all of them are neither tagged nor worded this way.
        let worded = task.title.range(of: opening, options: [.caseInsensitive, .anchored]) != nil
        guard tagged || worded else { return nil }
        let parts = analyse(title: task.title)
        return Parsed(person: parts.person, what: parts.what)
    }

    // MARK: Reading a title

    /// What a title says, whether or not it is a waiting line. `hasOpening` is true only when it
    /// begins with `Waiting for `; `person` and `what` are read from there. Without the prefix
    /// the what is the whole title less the `#waiting` tag, which is what the tag-only case and
    /// `notWaiting` need.
    struct Analysis {
        var hasOpening: Bool
        var person: String?
        var what: String
    }

    static func analyse(title: String) -> Analysis {
        let bare = TaskParser.collapseWhitespace(removingTag(from: title))
        guard let range = bare.range(of: opening, options: [.caseInsensitive, .anchored]) else {
            return Analysis(hasOpening: false, person: nil, what: bare)
        }
        let rest = String(bare[range.upperBound...])
        let chars = Array(rest)
        var colon: Int?
        for (index, character) in chars.enumerated() where character == ":" {
            // A colon between two digits is a time of day ("the 12:30 train"), not the end of
            // a name.
            let before: Character? = index > 0 ? chars[index - 1] : nil
            let after: Character? = index + 1 < chars.count ? chars[index + 1] : nil
            if let before, let after, before.isNumber, after.isNumber { continue }
            colon = index
            break
        }
        guard let colon else {
            return Analysis(hasOpening: true, person: nil, what: TaskParser.collapseWhitespace(rest))
        }
        let name = TaskParser.collapseWhitespace(String(chars[..<colon]))
        let what = TaskParser.collapseWhitespace(String(chars[(colon + 1)...]))
        return Analysis(hasOpening: true, person: name.isEmpty ? nil : name, what: what)
    }

    /// `#waiting` as the task parser reads a tag: not glued to the word before it, and not a
    /// longer tag that starts with the same letters (`#waitingroom`).
    private static let tagRegex: NSRegularExpression = {
        let pattern = #"(?<!\S)#"# + NSRegularExpression.escapedPattern(for: WaitingFor.tag) + #"(?![\p{L}\p{N}_/\-])"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// The title with every `#waiting` taken out and the gap closed.
    static func removingTag(from title: String) -> String {
        let ns = title as NSString
        let cleaned = tagRegex.stringByReplacingMatches(in: title, range: NSRange(location: 0, length: ns.length),
                                                        withTemplate: " ")
        return TaskParser.collapseWhitespace(cleaned)
    }

    // MARK: Names

    /// Two spellings of one person ("anna", "Anna", "Anna  ") fold to one key.
    public static func key(of person: String) -> String {
        TaskParser.collapseWhitespace(person).lowercased()
    }

    /// A name fit to be written in a title: line breaks and the characters the task line gives
    /// a meaning to (`:` ends the name, `#` starts a tag, `>` a date, `^` an id, `@` a stamp,
    /// `~` a time) turn into spaces, then the gaps close. Nil when nothing is left.
    public static func cleanPerson(_ text: String?) -> String? {
        guard let text else { return nil }
        let forbidden: Set<Character> = [":", "#", ">", "^", "@", "~", "\n", "\r", "\t"]
        let spaced = String(text.map { forbidden.contains($0) ? " " : $0 })
        let cleaned = TaskParser.collapseWhitespace(spaced)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// The title of a line that is waiting for `person`. The tag goes last.
    static func title(person: String, what: String) -> String {
        var title = "\(opening)\(person):"
        if !what.isEmpty { title += " " + what }
        return title + " #\(tag)"
    }

    // MARK: Follow-up date

    /// Follow up a week on: from the later of the follow-up date and today (an overdue one starts
    /// again from today, not from the day it was missed), plus seven days. With no date it is
    /// today plus seven.
    public static func followUpNextWeek(from followUp: DateOnly?, today: DateOnly,
                                        calendar: Calendar = .current) -> DateOnly {
        var base = today
        if let followUp, followUp > today { base = followUp }
        return base.adding(days: 7, calendar: calendar)
    }

    // MARK: Words

    /// "Fri 6 Nov", and "Sat 6 Feb 2027" when the year is not this year's.
    ///
    /// The weekday and the month are the locale's own words; the order is always day first. They
    /// are formatted one by one, because a ready-made pattern for "weekday, day, month" differs
    /// between English locales (a comma, an order) and the wording here is pinned by tests.
    public static func dayText(_ day: DateOnly, today: DateOnly,
                               calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let date = day.date(calendar: calendar) else { return day.description }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        let weekday = formatter.string(from: date)
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        let month = formatter.string(from: date)
        var text = "\(weekday) \(day.day) \(month)"
        if day.year != today.year { text += " \(day.year)" }
        return text
    }

    /// The person chooser in the task menu's window: every distinct name already used, most
    /// used first, so Anna is never written two ways. Alphabetical among equals.
    public static func people(in list: WaitingList) -> [String] {
        let named = list.groups.filter { $0.name != nil }
        let ordered = named.sorted { a, b in
            if a.lines.count != b.lines.count { return a.lines.count > b.lines.count }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        return ordered.map { $0.title }
    }

    /// The one line under the "Who?" field: what pressing **Add** will write. Nil while no name
    /// is typed.
    public static func writesText(for task: TaskItem, person: String) -> String? {
        guard let name = cleanPerson(person) else { return nil }
        let what = analyse(title: task.title).what
        var shown = "\(opening)\(name):"
        if !what.isEmpty { shown += " " + what }
        let ending = task.dueDate == nil
            ? "with a follow-up date in a week."
            : "and keeps its date as the follow-up date."
        return "Writes \u{201C}\(shown)\u{201D} \(ending)"
    }
}

// MARK: - The task

public extension TaskItem {
    /// True for an open line that is waiting for somebody (see `WaitingFor`).
    var isWaiting: Bool { WaitingFor.parse(self) != nil }

    /// The same task, now waiting for `person`.
    ///
    /// - The title becomes `Waiting for <person>: <what>` and the tag `#waiting` goes last.
    ///   *What* is the old title **without** an earlier `Waiting for …:` prefix and without
    ///   `#waiting`, so asking again who it is changes the name and never stacks prefixes.
    /// - `since` is today **only if the line had none**: changing the person must not reset the
    ///   wait.
    /// - A task with no date gets today plus seven days (the snippet's "a week out"); one that
    ///   has a date **keeps it**, because that is his follow-up.
    /// - A blank person is refused and the task comes back unchanged. The window keeps **Add**
    ///   grey, so this is a safety net.
    func makingWaiting(for person: String?, today: DateOnly, calendar: Calendar = .current) -> TaskItem {
        guard let name = WaitingFor.cleanPerson(person) else { return self }
        var made = self
        made.title = WaitingFor.title(person: name, what: WaitingFor.analyse(title: title).what)
        made.since = since ?? today
        if dueDate == nil {
            made.dueDate = WaitingFor.followUpNextWeek(from: nil, today: today, calendar: calendar)
        }
        return made.reparsed()
    }

    /// The same task, no longer waiting: the `Waiting for X:` prefix, the `#waiting` tag and
    /// `since` are taken away. Date, priority, time, tags of his own and id stay. A line with no
    /// words after the name keeps the name as its words. Only a line with no words and no name
    /// at all ("Waiting for :") stays waiting; `AppModel.stopWaiting` says so.
    func notWaiting() -> TaskItem {
        let parts = WaitingFor.analyse(title: title)
        var plain = self
        // Never leave a task with no words at all. "Waiting for Anna:" with nothing after the
        // colon keeps the name as its words ("Anna"): the title it was left with before still
        // began with "Waiting for", so it stayed a waiting line and the item did nothing.
        let words = parts.what.isEmpty ? (parts.person ?? "") : parts.what
        plain.title = words.isEmpty ? title : words
        plain.since = nil
        return plain.reparsed()
    }

    /// Through the task parser again, so `tags` and `title` agree with the line that will be
    /// written. The parser knows nothing of nesting, so the parent is put back.
    fileprivate func reparsed() -> TaskItem {
        var again = TaskParser.normalized(self)
        again.parentLineIndex = parentLineIndex
        return again
    }
}

// MARK: - Finding and rewriting a task in its note

public extension Note {
    /// True when an open line in this note is one he is waiting on somebody else for. Such a
    /// line is never the next thing, but it is not nothing either: the note has work in
    /// flight, and the review and the Goals screens must not call it idle (build 279).
    var hasWaitingLine: Bool { tasks.contains { $0.isWaiting } }

    /// The task as the note holds it **now**, found the way `replace(task:)` finds a line: by
    /// its line when that line still holds it, else by its `^t` id, else by its words when it
    /// has no id. A writer that changes the title cannot use `replace(task:)`, which matches on
    /// the title it is given — and a screen's copy of a task may be a little out of date, so
    /// the change is made to the live one.
    func liveTask(for task: TaskItem) -> TaskItem? {
        let all = tasks
        func same(_ candidate: TaskItem) -> Bool {
            if let wanted = task.id, let existing = candidate.id { return wanted == existing }
            return candidate.title == task.title
        }
        if let atLine = all.first(where: { $0.lineIndex == task.lineIndex }), same(atLine) { return atLine }
        if let id = task.id, let byID = all.first(where: { $0.id == id }) { return byID }
        return all.first { $0.id == nil && $0.title == task.title }
    }

    /// Writes `new` over the line `old` came from, even when the title changed. Returns false
    /// when the task is no longer in the note.
    @discardableResult
    mutating func rewrite(task old: TaskItem, with new: TaskItem) -> Bool {
        guard let live = liveTask(for: old) else { return false }
        var current = lines
        guard live.lineIndex >= 0, live.lineIndex < current.count else { return false }
        let line = new.serialized
        guard current[live.lineIndex] != line else { return true }
        current[live.lineIndex] = line
        lines = current
        return true
    }
}

// MARK: - The list

/// One waiting line, with the facts a row needs.
public struct WaitingLine: Identifiable, Equatable, Sendable {
    public var ref: TaskRef
    /// As written on this line. Nil when it names nobody.
    public var person: String?
    public var what: String
    /// The line's ordinary date.
    public var followUp: DateOnly?
    /// `@since(...)`. Nil when it was never written.
    public var since: DateOnly?

    public var id: String { ref.id }

    /// Nil when the task is not a waiting line.
    public init?(ref: TaskRef) {
        guard let parsed = WaitingFor.parse(ref.task) else { return nil }
        self.ref = ref
        self.person = parsed.person
        self.what = parsed.what
        self.followUp = ref.task.dueDate
        self.since = ref.task.since
    }

    public enum FollowUpState: Equatable, Sendable {
        case overdue, today, later, noDate
    }

    /// Whole days since the wait began. Nil without `@since` — and for a `@since` in the future,
    /// which is a typing mistake and not a wait. Never negative.
    public func waitedDays(today: DateOnly, calendar: Calendar = .current) -> Int? {
        guard let since else { return nil }
        let days = today.days(since: since, calendar: calendar)
        return days < 0 ? nil : days
    }

    public func followUpState(today: DateOnly) -> FollowUpState {
        guard let followUp else { return .noDate }
        if followUp < today { return .overdue }
        return followUp == today ? .today : .later
    }

    /// "asked today", "waited 1 day", "waited 5 days", or nil when the start is not known.
    public func waitedText(today: DateOnly, calendar: Calendar = .current) -> String? {
        guard let days = waitedDays(today: today, calendar: calendar) else { return nil }
        if days == 0 { return "asked today" }
        return days == 1 ? "waited 1 day" : "waited \(days) days"
    }

    /// "Follow up today", "Follow up Fri 6 Nov", "Follow up was 3 days ago" (or "was yesterday"),
    /// and "No follow-up date".
    public func followUpText(today: DateOnly, calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let followUp else { return "No follow-up date" }
        switch followUpState(today: today) {
        case .noDate:
            return "No follow-up date"
        case .today:
            return "Follow up today"
        case .overdue:
            return "Follow up was " + WeeklyFinished.agoText(days: today.days(since: followUp, calendar: calendar))
        case .later:
            return "Follow up " + WaitingFor.dayText(followUp, today: today, calendar: calendar, locale: locale)
        }
    }

    /// The caption under a row: "Follow up Fri 6 Nov · waited 5 days". Each part only when it
    /// is known; the follow-up part always says something, even if only that there is no date.
    public func captionText(today: DateOnly, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var parts = [followUpText(today: today, calendar: calendar, locale: locale)]
        if let waited = waitedText(today: today, calendar: calendar) { parts.append(waited) }
        return parts.joined(separator: " \u{00B7} ")
    }
}

/// The lines waiting for one person — or, when `name` is nil, for nobody named.
public struct WaitingGroup: Identifiable, Equatable, Sendable {
    /// The spelling used most; the first seen on a tie. Nil is **Someone**.
    public var name: String?
    public var lines: [WaitingLine]

    /// Never empty for a named group, so the group for nobody (an empty key) cannot clash.
    public var id: String { name.map { WaitingFor.key(of: $0) } ?? "" }
    public var title: String { name ?? "Someone" }
    /// Said under the heading **Someone**, so an empty name reads as a fact and not as a fault.
    public var note: String? { name == nil ? "No name given" : nil }
}

/// Every open waiting line, grouped by person.
public struct WaitingList: Equatable, Sendable {
    /// Named people first, alphabetical; **Someone** last.
    public var groups: [WaitingGroup]

    /// Builds the list from open tasks. Lines inside a group go by follow-up date (none last),
    /// then the longest wait (unknown last), then title.
    public init(refs: [TaskRef], today: DateOnly, calendar: Calendar = .current) {
        var keys: [String] = []
        var byKey: [String: [WaitingLine]] = [:]
        var spellings: [String: [String]] = [:]
        var uses: [String: [String: Int]] = [:]
        for ref in refs {
            guard let line = WaitingLine(ref: ref) else { continue }
            var key = ""
            if let person = line.person { key = WaitingFor.key(of: person) }
            if byKey[key] == nil { keys.append(key) }
            byKey[key, default: []].append(line)
            if let person = line.person {
                if uses[key]?[person] == nil { spellings[key, default: []].append(person) }
                uses[key, default: [:]][person, default: 0] += 1
            }
        }

        var built: [WaitingGroup] = []
        for key in keys {
            let lines = (byKey[key] ?? []).sorted { Self.before($0, $1, today: today, calendar: calendar) }
            var name: String?
            if !key.isEmpty {
                // The spelling used most; on a tie the one seen first.
                var best = 0
                for spelling in spellings[key] ?? [] {
                    let count = uses[key]?[spelling] ?? 0
                    if count > best {
                        best = count
                        name = spelling
                    }
                }
            }
            built.append(WaitingGroup(name: name, lines: lines))
        }
        groups = built.sorted { a, b in
            switch (a.name, b.name) {
            case let (x?, y?):
                let order = x.localizedCaseInsensitiveCompare(y)
                return order == .orderedSame ? a.id < b.id : order == .orderedAscending
            case (_?, nil): return true
            case (nil, _?): return false
            default: return false
            }
        }
    }

    private static func before(_ a: WaitingLine, _ b: WaitingLine, today: DateOnly, calendar: Calendar) -> Bool {
        switch (a.followUp, b.followUp) {
        case let (x?, y?):
            if x != y { return x < y }
        case (nil, _?): return false
        case (_?, nil): return true
        default: break
        }
        switch (a.waitedDays(today: today, calendar: calendar), b.waitedDays(today: today, calendar: calendar)) {
        case let (x?, y?):
            if x != y { return x > y }
        case (nil, _?): return false
        case (_?, nil): return true
        default: break
        }
        let order = a.ref.task.title.localizedCaseInsensitiveCompare(b.ref.task.title)
        if order != .orderedSame { return order == .orderedAscending }
        return a.id < b.id
    }

    public var isEmpty: Bool { groups.isEmpty }

    /// Every waiting line.
    public var count: Int { groups.reduce(0) { $0 + $1.lines.count } }

    /// The people with a name, not counting **Someone**.
    public var peopleCount: Int { groups.filter { $0.name != nil }.count }

    /// "4 things · 2 people", "1 thing · 1 person", "3 things · nobody named".
    public var summary: String {
        if isEmpty { return "Nothing is waiting" }
        let things = count == 1 ? "1 thing" : "\(count) things"
        let who: String
        switch peopleCount {
        case 0: who = "nobody named"
        case 1: who = "1 person"
        default: who = "\(peopleCount) people"
        }
        return "\(things) \u{00B7} \(who)"
    }

    /// The pointer on the All actions list, which says the lines exist and are one press away
    /// (build 74: an action nobody finds). Nil when there is nothing to point at.
    public var pointerText: String? {
        if isEmpty { return nil }
        return count == 1 ? "1 waiting for another person" : "\(count) waiting for other people"
    }
}

public extension NoteIndex {
    /// The waiting lines among `refs`. Notes that have ended (Done, Missed, Dropped) are left
    /// out: what a finished project was waiting for is no longer something to chase. Archived
    /// notes are already out of `openTasks()`; work notes are not in the index at all.
    func waitingFor(among refs: [TaskRef], today: DateOnly, calendar: Calendar = .current) -> WaitingList {
        let live = refs.filter { ref in
            guard let owner = note(path: ref.notePath) else { return true }
            return !owner.isEnded && !owner.isArchived
        }
        return WaitingList(refs: live, today: today, calendar: calendar)
    }

    /// Every open waiting line in the vault.
    func waitingFor(today: DateOnly, calendar: Calendar = .current) -> WaitingList {
        waitingFor(among: openTasks(), today: today, calendar: calendar)
    }
}
