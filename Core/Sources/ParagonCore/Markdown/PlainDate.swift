import Foundation

/// A date written in plain English words in a capture: "tomorrow 14:00", "next Friday",
/// "in 3 days", "13 Dec 9:00" (build 316, premium review features-03).
///
/// **It only reads; the file keeps its one date mark.** The words are turned into the task
/// line's own `>2026-11-14` or `>2026-11-14T14:00` at the moment of saving
/// (`PlainDate.line(_:understoodOn:ignoring:)`), and the capture screens show what was read as
/// a chip first, which one press takes away again so the words stay plain text.
///
/// **What is never guessed:**
/// - a line that already carries a `>date` mark: the written mark wins and no words are read;
/// - words inside quotation marks, a link, a `[[note link]]` or `code`;
/// - a bare weekday in the middle of a sentence ("Prepare Friday meeting"). A weekday alone
///   counts only as the last words of the line; with "on", "by", "due", "this", "next" or a
///   time after it, it counts anywhere;
/// - a short weekday alone ("sun", "sat", "wed" are also words);
/// - a time without a day ("at 14:00"), and numbers such as 13/12 that read two ways.
public struct PlainDate: Equatable, Sendable {
    public var date: DateOnly
    public var time: TimeOfDay?
    /// The words that were read, exactly as typed ("next Friday 14:00").
    public var words: String
    /// Where the words are in the line (UTF-16, as `NSString` counts).
    public var location: Int
    public var length: Int

    /// The task line's own mark for this date: `>2026-11-14` or `>2026-11-14T14:00`.
    public var marker: String {
        ">" + date.description + (time.map { "T" + $0.description } ?? "")
    }

    // MARK: Reading

    /// The first date written in words in `line`, or nil. `today` is the day the words are
    /// counted from. Weeks start on Monday.
    public static func read(_ line: String, today: DateOnly, calendar: Calendar = WeekRef.calendar) -> PlainDate? {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        // A written date mark wins: nothing is read beside it.
        if TaskParser.dueRegex.firstMatch(in: line, range: full) != nil { return nil }
        let shut = shutOut.matches(in: line, range: full).map(\.range)

        var best: PlainDate?
        for pattern in patterns {
            for m in pattern.regex.matches(in: line, range: full) {
                if shut.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) { continue }
                func group(_ name: String) -> String? {
                    let r = m.range(withName: name)
                    return r.location == NSNotFound ? nil : ns.substring(with: r).lowercased()
                }
                let timed = readTime(group)
                if timed.invalid { continue }
                let lead = group("lead")
                let rest = ns.substring(from: NSMaxRange(m.range))
                let atEnd = onlyMarks.firstMatch(in: rest, range: NSRange(location: 0, length: (rest as NSString).length)) != nil
                guard let date = pattern.date(group, lead, timed.time != nil, atEnd, today, calendar) else { continue }
                let found = PlainDate(date: date, time: timed.time, words: ns.substring(with: m.range),
                                      location: m.range.location, length: m.range.length)
                if let now = best {
                    if found.location < now.location || (found.location == now.location && found.length > now.length) {
                        best = found
                    }
                } else {
                    best = found
                }
            }
        }
        return best
    }

    /// The line as it will be saved: the date words replaced by the date mark. Unchanged when
    /// no date is read, or when the words read are the ones he took away (`ignoring`, the chip's
    /// **x**: the words then stay plain text).
    public static func line(_ line: String, understoodOn today: DateOnly, ignoring: String? = nil,
                            calendar: Calendar = WeekRef.calendar) -> String {
        guard let found = read(line, today: today, calendar: calendar), !found.isIgnored(by: ignoring) else { return line }
        let ns = line as NSString
        let replaced = ns.replacingCharacters(in: NSRange(location: found.location, length: found.length),
                                              with: " " + found.marker + " ")
        return TaskParser.collapseWhitespace(replaced)
    }

    /// True when these are the words he took away with the chip's **x**.
    public func isIgnored(by ignored: String?) -> Bool {
        guard let ignored else { return false }
        return ignored.lowercased() == words.lowercased()
    }

    // MARK: The patterns

    private struct Pattern: @unchecked Sendable {
        let regex: NSRegularExpression
        /// (group reader, leading word, has a time, is at the end of the line, today, calendar)
        let date: @Sendable ((String) -> String?, String?, Bool, Bool, DateOnly, Calendar) -> DateOnly?
    }

    private static let weekdayNames: [String: Int] = [
        "monday": 1, "tuesday": 2, "wednesday": 3, "thursday": 4, "friday": 5, "saturday": 6, "sunday": 7,
        "mon": 1, "tue": 2, "tues": 2, "wed": 3, "thu": 4, "thur": 4, "thurs": 4, "fri": 5, "sat": 6, "sun": 7,
    ]

    private static let monthNames: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "sept": 9,
        "oct": 10, "nov": 11, "dec": 12,
    ]

    private static let numberWords: [String: Int] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
    ]

    /// Longest names first, so "thurs" is not read as "thu" + "rs".
    private static func alternatives(_ names: [String: Int]) -> String {
        names.keys.sorted { $0.count > $1.count || ($0.count == $1.count && $0 < $1) }.joined(separator: "|")
    }

    /// Not glued to a word, a number or one of the task line's own marks.
    private static let before = #"(?<![\p{L}\p{N}>#@^~/\-_])"#
    private static let after = #"(?![\p{L}\p{N}_'\x{2019}])"#
    /// "on", "by" or "due" in front belongs to the date and goes with it.
    private static let lead = #"(?:(?<lead>on|by|due)\s+)?"#
    /// An optional time of day after the date: 14:00, 14.00, 2pm, 2:30 pm, noon, at 14.
    private static let time = #"(?:\s+(?:at\s+)?(?:(?<h1>\d{1,2})[:.](?<m1>\d{2})(?:\s?(?<ap1>am|pm))?|(?<h2>\d{1,2})\s?(?<ap2>am|pm)|(?<noon>noon))|\s+at\s+(?<h3>\d{1,2}))?"#

    private static func make(_ body: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: before + body + time + after, options: [.caseInsensitive])
    }

    private static let patterns: [Pattern] = [
        // today, tomorrow, day after tomorrow
        Pattern(regex: make(lead + #"(?<word>the\s+day\s+after\s+tomorrow|day\s+after\s+tomorrow|today|tomorrow)"#)) { g, _, _, _, today, cal in
            let word = g("word") ?? ""
            if word.hasSuffix("after tomorrow") || word.contains("after") { return today.adding(days: 2, calendar: cal) }
            return word == "tomorrow" ? today.adding(days: 1, calendar: cal) : today
        },
        // Friday, on Friday, this Friday, next Friday
        Pattern(regex: make(#"(?:(?<lead>on|by|due|this|next)\s+)?(?<wd>"# + alternatives(weekdayNames) + ")")) { g, lead, timed, atEnd, today, cal in
            guard let name = g("wd"), let target = weekdayNames[name] else { return nil }
            let isShort = !name.hasSuffix("day")
            if lead == nil && !timed {
                // A weekday alone: only as the last words of the line, and never a short one.
                if isShort || !atEnd { return nil }
            }
            let now = isoWeekday(today, cal)
            if lead == "next" {
                // The one in the week after this one (weeks start on Monday).
                let nextMonday = today.adding(days: 8 - now, calendar: cal)
                return nextMonday.adding(days: target - 1, calendar: cal)
            }
            var ahead = (target - now + 7) % 7
            if ahead == 0 { ahead = 7 }
            return today.adding(days: ahead, calendar: cal)
        },
        // in 3 days, in two weeks, in a month
        Pattern(regex: make(#"in\s+(?<n>\d{1,3}|"# + alternatives(numberWords) + #")\s+(?<unit>days?|weeks?|months?|years?)"#)) { g, _, _, _, today, cal in
            guard let raw = g("n"), let n = Int(raw) ?? numberWords[raw], n > 0, let unit = g("unit") else { return nil }
            if unit.hasPrefix("day") { return today.adding(days: n, calendar: cal) }
            if unit.hasPrefix("week") { return today.adding(days: 7 * n, calendar: cal) }
            guard let base = today.date(calendar: cal),
                  let moved = cal.date(byAdding: unit.hasPrefix("month") ? .month : .year, value: n, to: base) else { return nil }
            return DateOnly(moved, calendar: cal)
        },
        // next week (its Monday), next month (its first day)
        Pattern(regex: make(#"next\s+(?<span>week|month)"#)) { g, _, _, _, today, cal in
            if g("span") == "week" { return today.adding(days: 8 - isoWeekday(today, cal), calendar: cal) }
            let month = today.month == 12 ? 1 : today.month + 1
            return DateOnly(year: today.month == 12 ? today.year + 1 : today.year, month: month, day: 1)
        },
        // 13 Dec, 13th December 2026
        Pattern(regex: make(lead + #"(?<day>\d{1,2})(?:st|nd|rd|th)?\.?\s+(?<month>"# + alternatives(monthNames) + #")\.?(?:,?\s+(?<year>20\d{2}))?"#)) { g, _, _, _, today, cal in
            dayAndMonth(g, today, cal)
        },
        // Dec 13, December 13th, 2026
        Pattern(regex: make(lead + #"(?<month>"# + alternatives(monthNames) + #")\.?\s+(?<day>\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(?<year>20\d{2}))?"#)) { g, _, _, _, today, cal in
            dayAndMonth(g, today, cal)
        },
        // 2026-12-13, written without the > mark
        Pattern(regex: make(lead + #"(?<iso>\d{4}-\d{2}-\d{2})"#)) { g, _, _, _, _, cal in
            guard let iso = g("iso"), let day = DateOnly(iso) else { return nil }
            return isReal(day, cal) ? day : nil
        },
    ]

    /// Quotation marks, links, note links and code: words in there are his words, not a date.
    private static let shutOut = try! NSRegularExpression(
        pattern: #"\[\[[^\]]*\]\]|\[[^\]]*\]\([^)]*\)|\S*://\S*|`[^`]*`|"[^"]*"|\x{201C}[^\x{201D}]*\x{201D}"#)

    /// What may follow a date that is "the last words of the line": only the task line's own
    /// marks (#tag, !, ~45m, @repeat(…), ^id) and one closing full stop.
    private static let onlyMarks = try! NSRegularExpression(
        pattern: #"^(?:\s*(?:#\S+|!{1,3}|~\S+|@\w+\([^)]*\)|\^t[0-9a-f]+))*\s*[.!?]?\s*$"#)

    // MARK: Small rules

    private static func readTime(_ g: (String) -> String?) -> (time: TimeOfDay?, invalid: Bool) {
        var hour: Int?
        var minute = 0
        var half: String?
        if let h = g("h1"), let m = g("m1") {
            hour = Int(h); minute = Int(m) ?? 0; half = g("ap1")
        } else if let h = g("h2") {
            hour = Int(h); half = g("ap2")
        } else if g("noon") != nil {
            hour = 12
        } else if let h = g("h3") {
            hour = Int(h)
        }
        guard var h = hour else { return (nil, false) }
        if let half {
            guard (1...12).contains(h) else { return (nil, true) }
            if half == "pm" && h < 12 { h += 12 }
            if half == "am" && h == 12 { h = 0 }
        }
        guard (0...23).contains(h), (0...59).contains(minute) else { return (nil, true) }
        return (TimeOfDay(hour: h, minute: minute), false)
    }

    /// 1 = Monday … 7 = Sunday.
    static func isoWeekday(_ day: DateOnly, _ calendar: Calendar) -> Int {
        guard let date = day.date(calendar: calendar) else { return 1 }
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    private static func isReal(_ day: DateOnly, _ calendar: Calendar) -> Bool {
        guard let date = day.date(calendar: calendar) else { return false }
        return DateOnly(date, calendar: calendar) == day
    }

    /// A day and a month: with a year, that day; without, the next time it comes (today counts).
    private static func dayAndMonth(_ g: (String) -> String?, _ today: DateOnly, _ calendar: Calendar) -> DateOnly? {
        guard let d = g("day").flatMap(Int.init), let name = g("month"), let m = monthNames[name] else { return nil }
        if let y = g("year").flatMap(Int.init) {
            let day = DateOnly(year: y, month: m, day: d)
            return isReal(day, calendar) ? day : nil
        }
        // Up to eight years on, so 29 February is found.
        for year in today.year...(today.year + 8) {
            let day = DateOnly(year: year, month: m, day: d)
            if isReal(day, calendar), day >= today { return day }
        }
        return nil
    }
}
