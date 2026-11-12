import Foundation

/// **The one way the app writes a date** (review round 3, his decision — he is Swedish and reads
/// the ISO form fastest).
///
/// - Plain, everywhere: `2026-11-12`.
/// - Where the weekday helps (a task's due day, Today, a daily note's name, a reminder, Start
///   and Close the day, a day heading in the calendar): `Thursday 2026-11-12` — the full English
///   weekday, a space, the plain date, no comma.
/// - A month alone: `2026-11`. A week: `Week 46`. A time of day: `14:30`, always 24 hours.
///
/// The app is English, so the weekday is always English, the calendar always Gregorian, and
/// none of it follows the device's region. This is **display only**: file names and what is
/// written into a note keep their own forms (`20261112.md`, `>2026-11-12`).
public enum DayWords {
    /// The Gregorian calendar in this device's time zone: the year is 2026 even on a device
    /// set to another calendar.
    public static var here: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// A fixed Gregorian calendar in UTC, used only to ask which weekday a year-month-day is.
    private static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return c
    }()

    // MARK: A day

    /// `2026-11-12`
    public static func plain(_ day: DateOnly) -> String { day.description }

    /// `2026-11-12`, the day this moment falls on in the given calendar's time zone.
    public static func plain(_ date: Date, calendar: Calendar = DayWords.here) -> String {
        plain(DateOnly(date, calendar: calendar))
    }

    /// `Thursday`
    public static func weekday(_ day: DateOnly) -> String {
        guard let date = gregorian.date(from: day.dateComponents) else { return "" }
        return weekdays[(gregorian.component(.weekday, from: date) - 1 + 7) % 7]
    }

    /// `Thu`, for a column head or a cell too narrow for the whole word.
    public static func shortWeekday(_ day: DateOnly) -> String { String(weekday(day).prefix(3)) }

    /// `Thursday 2026-11-12`
    public static func withWeekday(_ day: DateOnly) -> String {
        let name = weekday(day)
        return name.isEmpty ? plain(day) : "\(name) \(plain(day))"
    }

    /// `Thursday 2026-11-12`, the day this moment falls on in the given calendar's time zone.
    public static func withWeekday(_ date: Date, calendar: Calendar = DayWords.here) -> String {
        withWeekday(DateOnly(date, calendar: calendar))
    }

    // MARK: A month, a week

    /// `2026-11`
    public static func month(year: Int, month: Int) -> String { String(format: "%04d-%02d", year, month) }

    /// `2026-11`
    public static func month(_ month: MonthRef) -> String { Self.month(year: month.year, month: month.month) }

    /// `2026-11`, the month a day is in.
    public static func month(_ day: DateOnly) -> String { month(year: day.year, month: day.month) }

    /// `Week 46`
    public static func week(_ week: WeekRef) -> String { "Week \(week.week)" }

    /// `Week 46`, the week a day is in.
    public static func week(_ day: DateOnly) -> String { week(WeekRef(containing: day)) }

    /// `Week 46 · 2026`, the name of a weekly note.
    public static func weekAndYear(_ week: WeekRef) -> String { "Week \(week.week) \u{00B7} \(week.year)" }

    /// `Week 46 · 2026-11-09 – 2026-11-15`, the heading over a week's seven days.
    public static func weekSpan(_ week: WeekRef) -> String {
        "Week \(week.week) \u{00B7} \(plain(week.monday)) \u{2013} \(plain(week.sunday))"
    }

    // MARK: A time of day

    /// `14:30`
    public static func time(_ time: TimeOfDay) -> String { time.description }

    /// `14:30`, or `14:30:05` with seconds.
    public static func time(_ date: Date, seconds: Bool = false, calendar: Calendar = DayWords.here) -> String {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let clock = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        return seconds ? clock + String(format: ":%02d", c.second ?? 0) : clock
    }

    /// `2026-11-12 14:30`
    public static func plainWithTime(_ date: Date, calendar: Calendar = DayWords.here) -> String {
        "\(plain(date, calendar: calendar)) \(time(date, calendar: calendar))"
    }
}
