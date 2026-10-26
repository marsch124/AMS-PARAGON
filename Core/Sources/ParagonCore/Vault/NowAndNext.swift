import Foundation

/// **Now and Then** at the top of **Today** (build 266): the block of the day's plan you are in,
/// and the one that comes after it. His words for the two lines are **Now** and **Then** —
/// "Next" was offered and refused, because **Today** already has a heading **Next actions**
/// that means something else, and one word with two meanings on one screen is what made
/// Aspiration and Goal hard to tell apart (build 176).
///
/// In Core, so the rule is tested, and so the Mac widget (build 280) can name **the same
/// block** as Today. Plan blocks only: calendar events stay in the Calendar section.
///
/// The rules:
/// - A block is **now** from its start minute up to, but not including, its end minute.
/// - When blocks overlap, the one that **started last** is now — a short block inside a long
///   one wins while it runs, and the long one is now again once the short one ends. Two
///   blocks with the same start: the one first in the plan.
/// - **Then** is the earliest block that starts after this minute; two with the same start:
///   the one first in the plan. Never the block that is now.
/// - After the last block, and on a day with no plan, both are nil and nothing is drawn.
public struct NowAndNext: Equatable, Sendable {
    /// The block running at this minute, or nil.
    public var now: PlanBlock?
    /// The next block to start after this minute, or nil.
    public var next: PlanBlock?

    /// `minute` is minutes since midnight on the plan's own day — `minute(of:)` gives it.
    public init(blocks: [PlanBlock], minute: Int) {
        var running: PlanBlock?
        var coming: PlanBlock?
        for block in blocks {
            if block.start <= minute && minute < block.start + block.minutes {
                if let found = running {
                    // A later start wins; on the same start, the lower index.
                    if block.start > found.start
                        || (block.start == found.start && block.index < found.index) {
                        running = block
                    }
                } else {
                    running = block
                }
            } else if block.start > minute {
                if let found = coming {
                    // An earlier start wins; on the same start, the lower index.
                    if block.start < found.start
                        || (block.start == found.start && block.index < found.index) {
                        coming = block
                    }
                } else {
                    coming = block
                }
            }
        }
        // A full tie (same start, same index) keeps the block met first in the list.
        now = running
        next = coming
    }

    /// Nothing is running and nothing is still to come today.
    public var isEmpty: Bool { now == nil && next == nil }

    /// Minutes since midnight, read from the clock's own hour and minute.
    ///
    /// **Never seconds since midnight divided by 60** (build 238): on the two days a year the
    /// clocks change, those differ by an hour after 03:00, and the wrong block would be now.
    public static func minute(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Whether two names are the same block's name: case and runs of spaces are ignored, as
    /// **Planned and worked** matches a block to its work (build 259) — one rule, one place.
    /// A different tag is a different name. Nil or empty is never the same as anything.
    public static func sameName(_ one: String?, _ other: String?) -> Bool {
        guard let one, let other else { return false }
        let key = PlannedAndWorked.key(one)
        return !key.isEmpty && key == PlannedAndWorked.key(other)
    }
}
