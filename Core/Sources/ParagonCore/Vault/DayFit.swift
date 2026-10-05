import Foundation

/// Does what was picked in **Start the day** fit in the day? (build 249)
///
/// **The working day is a measure, never a wall.** He keeps leisure tasks in PARAGON as well, so
/// a block after the working day is ordinary planning, not a fault. Only a day with no room
/// left at all before midnight is a warning. In Core, with tests, because it decides which of
/// three things the screen says.
public struct DayFit: Equatable, Sendable {
    public enum Verdict: Equatable, Sendable {
        /// Everything fits before the working day ends.
        case fitsWorkday
        /// It fits today, and this many minutes go past the end of the working day.
        case runsIntoEvening(Int)
        /// More than the rest of the day holds, by this many minutes.
        case tooMuch(Int)
    }

    public var picked: Int
    /// Free minutes from now until the working day ends. Zero once it has ended.
    public var freeInWorkday: Int
    /// Free minutes from now until midnight.
    public var freeToday: Int

    public init(picked: Int, freeInWorkday: Int, freeToday: Int) {
        self.picked = max(0, picked)
        self.freeInWorkday = max(0, freeInWorkday)
        self.freeToday = max(self.freeInWorkday, freeToday)
    }

    /// Works the free time out from the plan and the calendar, the same `busy` list
    /// `freeStarts` places blocks around, so the sum and the placing cannot disagree.
    public init(picked: Int, from: Int, workdayEnds: Int, busy: [Range<Int>]) {
        self.init(picked: picked,
                  freeInWorkday: DayPlan.freeMinutes(from: from, until: workdayEnds, busy: busy),
                  freeToday: DayPlan.freeMinutes(from: from, until: 24 * 60, busy: busy))
    }

    public var verdict: Verdict {
        if picked <= freeInWorkday { return .fitsWorkday }
        if picked <= freeToday { return .runsIntoEvening(picked - freeInWorkday) }
        return .tooMuch(picked - freeToday)
    }
}
