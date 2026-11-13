import Foundation

/// The day the Weekly review was last finished (round 8, build 315), written by its
/// **Review done** button into the note of the week it was pressed in, as
/// `review-done: 2026-11-13`.
///
/// **In the weekly note, not in the app's own settings** — `WeekGoal`'s reasoning: it travels
/// with the vault, so the iPhone knows about a review done on the Mac, and it is his to read in
/// any editor. The per-note `reviewed:` line ("Looked at") is another thing: that is one note,
/// this is the whole walk.
public enum WeeklyReviewDone {
    public static let key = "review-done"

    /// A review is late when the last one is **more than** this many days old.
    public static let lateAfterDays = 7

    /// The day a weekly note says the review was done, or nil.
    public static func read(from note: Note?) -> DateOnly? {
        note?.frontmatter.string(key).flatMap { DateOnly($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// The note with the day written in.
    public static func setting(_ day: DateOnly, on note: Note) -> Note {
        var updated = note
        updated.frontmatter.set(key, day.description)
        return updated
    }

    /// Whole days from the last review to today, or nil when none was ever recorded. A day in
    /// the future (a clock set wrong on the other device) counts as today.
    public static func daysSince(last: DateOnly?, today: DateOnly, calendar: Calendar = .current) -> Int? {
        guard let last else { return nil }
        return max(0, today.days(since: last, calendar: calendar))
    }

    /// **The rule for the line on Today.** Late only when a review was recorded and it is more
    /// than seven days old: exactly a week ago is still on time, so a review every Sunday never
    /// shows the line. **Never recorded is not late** — there is nothing to measure from, and a
    /// new vault must not open with a complaint. The reminder in Settings is what starts the habit.
    public static func isLate(last: DateOnly?, today: DateOnly, calendar: Calendar = .current) -> Bool {
        guard let days = daysSince(last: last, today: today, calendar: calendar) else { return false }
        return days > lateAfterDays
    }

    /// The words of the line on Today.
    public static func lateLine(last: DateOnly, today: DateOnly, calendar: Calendar = .current) -> String {
        let days = daysSince(last: last, today: today, calendar: calendar) ?? 0
        return "Last weekly review: \(days) days ago"
    }
}

public extension NoteIndex {
    /// The newest **Review done** day in any weekly note, or nil.
    func lastWeeklyReview() -> DateOnly? {
        notes.lazy
            .filter { $0.kind == .daily && $0.weekRef != nil }
            .compactMap { WeeklyReviewDone.read(from: $0) }
            .max()
    }
}
