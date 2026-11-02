import Foundation

/// A calendar event, or anything with a start and an end, **cut to one day** (build 276).
///
/// **One rule for every day view.** Build 273 wrote the cut inside the app's
/// `timedEventSpans(on:)`: an event that began yesterday starts at 0 and one that ends tomorrow
/// ends at midnight. The Plan screen's Calendar lane and the Calendar section's day never made
/// it. They read the clock time of an event's start and end, so a meeting that began at 23:00
/// yesterday was drawn at 23:00 *today*, and one that ends tomorrow ran off the bottom of the
/// grid (the Plan screen drew it half an hour long). This is the cut, in one place, for the
/// Plan lane, the Calendar section, the widget and the planning sum (build 168).
///
/// - **Minutes are the clock's own** (`startMinute`, `endMinute`): the hour and minute on the
///   wall, never seconds since midnight divided by 60. On the two days a year the clocks change
///   those differ by an hour after 03:00 and a block would land on top of a meeting (build 238).
/// - **0 to 1440.** An event that began on an earlier day starts at 0. One that ends at or
///   after the next midnight ends at 1440, which is **24:00**: an event that ends exactly at
///   midnight is not an event of the next day.
/// - **`start` and `end` are the same cut as dates**, for a view that lays out with dates (the
///   Calendar section). `end` is never before `start`.
/// - **Nothing is dropped.** An event the day was asked to draw is always drawn: one that does
///   not touch the day at all is held to its nearest edge, as a span of no length, and the
///   caller's minimum length makes it visible. Hiding it would be an absence that looks like
///   free time (build 100).
/// - **The real times stay the view's to say.** "23:00–02:00" is true of the event and the
///   subtitle may keep saying it; only where it is drawn is cut.
public struct EventDaySpan: Equatable, Sendable {
    /// Minutes since midnight on the day, 0 to 1440.
    public let startMinute: Int
    /// Minutes since midnight on the day, `startMinute` to 1440. 1440 is the next midnight.
    public let endMinute: Int
    /// The start, not before the day's first moment.
    public let start: Date
    /// The end, not before `start` and not after the next day's first moment.
    public let end: Date
    /// The event began on an earlier day.
    public let beginsEarlier: Bool
    /// The event goes on after the day's end (it does not merely end at midnight).
    public let endsLater: Bool

    /// The minutes in a day, as the grid counts them.
    public static let minutesInDay = 24 * 60

    public init(start: Date, end: Date, on day: DateOnly, calendar: Calendar = .current) {
        let first = day.date(calendar: calendar) ?? calendar.startOfDay(for: start)
        // `byAdding: .day`, not 24 hours: the day of a clock change is 23 or 25 hours long.
        let next = calendar.date(byAdding: .day, value: 1, to: first) ?? first.addingTimeInterval(86_400)

        let begins = start < first
        let cutStart = min(max(start, first), next)
        let cutEnd = min(max(end, cutStart), next)

        self.beginsEarlier = begins
        self.endsLater = end > next
        self.start = cutStart
        self.end = cutEnd
        self.startMinute = begins ? 0 : Self.minute(of: cutStart, from: first, until: next, calendar: calendar)
        self.endMinute = Self.minute(of: cutEnd, from: first, until: next, calendar: calendar)
    }

    /// The clock's minute for a moment on the day; 1440 for the next midnight itself.
    private static func minute(of date: Date, from first: Date, until next: Date,
                               calendar: Calendar) -> Int {
        if date >= next { return minutesInDay }
        if date <= first { return 0 }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
