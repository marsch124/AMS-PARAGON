import Foundation

/// Round 350 (capture-inbox): the text rules of the capture screen, in one place so each can be
/// tested — pasted lists, scanned paper lists, the same line twice, and the place name.
public enum CaptureLines {
    /// Marks a list item may start with: bullets, numbers and tick boxes, in the shapes a paste
    /// from Notes, a mail or a scan gives.
    private static let leadRegex = try! NSRegularExpression(
        pattern: #"^\s*(?:[-*+•–—·▪◦■□☐☑✓✔]|\d{1,3}[.)])\s+"#)
    private static let boxRegex = try! NSRegularExpression(pattern: #"^\s*\[[ xX]\]\s*"#)
    private static let boxSignRegex = try! NSRegularExpression(pattern: #"^\s*[□☐☑✓✔]\s*"#)

    /// One line without its list mark, with runs of spaces made one. Nil when nothing readable is
    /// left (no letter and no number), or when it is shorter than `minimumLength`.
    public static func cleaned(line: String, minimumLength: Int = 1) -> String? {
        var text = line.trimmingCharacters(in: .whitespaces)
        for _ in 0..<3 {
            var changed = false
            for regex in [leadRegex, boxRegex, boxSignRegex] {
                let ns = text as NSString
                if let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), m.range.length > 0 {
                    text = ns.substring(from: m.range.length)
                    changed = true
                }
            }
            if !changed { break }
        }
        let words = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        guard words.count >= minimumLength else { return nil }
        guard words.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else { return nil }
        return words
    }

    /// Every non-empty line of a text, one task each, without bullets and tick boxes.
    public static func split(_ text: String, minimumLength: Int = 1) -> [String] {
        text.components(separatedBy: .newlines)
            .compactMap { cleaned(line: $0, minimumLength: minimumLength) }
    }

    /// The text a scan of a paper list gives: one string per line read. A line of a single
    /// character is noise (a smudge, a margin mark) and is left out.
    public static func scanned(_ pieces: [String]) -> [String] {
        split(pieces.joined(separator: "\n"), minimumLength: 2)
    }

    /// True when a paste or a dictation holds more than one line, so **Make N tasks?** is asked.
    public static func isMany(_ text: String) -> Bool { split(text).count >= 2 }

    /// What is asked about a paste: "Make 5 tasks?" (or notes, when the capture is a note).
    public static func question(count: Int, asTask: Bool = true) -> String {
        "Make \(count) \(asTask ? "tasks" : "notes")?"
    }

    /// True when one change to the field added two lines or more at once — a paste. Typing a
    /// second line, or a word more, is never a paste.
    public static func pastedMany(from old: String, to new: String) -> Bool {
        split(new).count - split(old).count >= 2
    }

    /// The button that adds the scanned lines: "Add 1 task" / "Add 5 tasks".
    public static func addTitle(count: Int) -> String { count == 1 ? "Add 1 task" : "Add \(count) tasks" }

    // MARK: The same line twice

    /// A line as it is compared: capitals, accents and runs of spaces do not count, and the
    /// date, priority and length marks are left out (the task parser's own reading).
    public static func key(_ text: String) -> String {
        let line = "- [ ] " + text.replacingOccurrences(of: "\n", with: " ")
        let title = TaskParser.parse(line: line)?.title ?? text
        let folded = title.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return folded.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }

    /// True when `text` matches one of the open Inbox lines. Empty text never matches.
    public static func isInInbox(_ text: String, among titles: [String]) -> Bool {
        let wanted = key(text)
        guard !wanted.isEmpty else { return false }
        return titles.contains { key($0) == wanted }
    }

    // MARK: The place name

    /// ` — at Home` after the words. Nothing is added for an empty place, and a line that
    /// already ends so is left as it is.
    public static func placed(_ text: String, at place: String?) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (place ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !name.isEmpty else { return trimmed }
        let tail = " \u{2014} at \(name)"
        if trimmed.hasSuffix(tail) { return trimmed }
        return trimmed + tail
    }
}

// MARK: - Snooze

/// Round 350: an Inbox line put aside until a day (`@snooze(YYYY-MM-DD)`). It leaves the Inbox
/// list and every Inbox count, and comes back on that day.
public enum InboxSnooze {
    /// The next Monday after `day`; on a Monday it is the Monday a week later.
    public static func nextMonday(after day: DateOnly, calendar: Calendar = .current) -> DateOnly {
        guard let date = day.date(calendar: calendar) else { return day.adding(days: 7, calendar: calendar) }
        var step = 1
        while step <= 7 {
            if let next = calendar.date(byAdding: .day, value: step, to: date),
               calendar.component(.weekday, from: next) == 2 {
                return DateOnly(next, calendar: calendar)
            }
            step += 1
        }
        return day.adding(days: 7, calendar: calendar)
    }

    /// The confirmation: "Back in the Inbox on Monday 23 November."
    public static func message(until day: DateOnly, calendar: Calendar = .current) -> String {
        guard let words = dayWords(day, calendar: calendar) else { return "Snoozed until \(day)." }
        return "Back in the Inbox on \(words)."
    }

    /// "Monday 23 November", or nil when the day cannot be made into a date.
    static func dayWords(_ day: DateOnly, calendar: Calendar) -> String? {
        guard let date = day.date(calendar: calendar) else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }

    /// Round 352: the day the first snoozed line comes back, among a note's tasks. Only open,
    /// top-level lines count, as in the Inbox list.
    public static func firstBack(_ tasks: [TaskItem], on day: DateOnly) -> DateOnly? {
        tasks.filter { !$0.isDone && !$0.isSubtask && $0.isSnoozed(on: day) }
            .compactMap(\.snooze)
            .min()
    }

    /// Round 352: what the Inbox says when every line is snoozed (it is not "Inbox zero").
    /// "1 line comes back on Monday 23 November." / "3 lines are snoozed. The first comes back
    /// on Monday 23 November."
    public static func allSnoozedText(count: Int, firstBack: DateOnly?, calendar: Calendar = .current) -> String {
        let words: String? = firstBack.flatMap { dayWords($0, calendar: calendar) }
        if count == 1 {
            if let words { return "1 line comes back on \(words)." }
            return "1 line comes back later."
        }
        if let words { return "\(count) lines are snoozed. The first comes back on \(words)." }
        return "\(count) lines are snoozed. They come back later."
    }
}

public extension TaskItem {
    /// True while the line is put aside: it comes back on its snooze day itself.
    func isSnoozed(on day: DateOnly) -> Bool {
        guard let snooze else { return false }
        return snooze > day
    }

    /// The line with its snooze day set (nil takes it away).
    func settingSnooze(_ day: DateOnly?) -> TaskItem {
        var copy = self
        copy.snooze = day
        return copy
    }
}

public extension Note {
    /// The open lines that count as waiting today: the open tasks without the snoozed ones.
    /// The Inbox list, the Inbox count, the widget and the review all ask this.
    func awaitingTasks(on day: DateOnly = .today()) -> [TaskItem] {
        openTasks.filter { !$0.isSnoozed(on: day) }
    }
}
