import Foundation

/// One block that **Start the day** wants to put into the plan (build 277): how long it is, and,
/// when the task has a time of day, the minute it is due.
public struct PlanWish: Equatable, Sendable {
    public var length: Int
    /// Minutes since midnight of the task's own time on that day, or nil when it has none.
    public var at: Int?

    public init(length: Int, at: Int? = nil) {
        self.length = length
        self.at = at
    }
}

public extension DayPlan {
    /// Where each wish goes, in the order they were asked for: a start, or nil when that block
    /// found no room before `until`.
    ///
    /// **A task with a time of day is placed at that time when the time is free**, because that
    /// is when it is due; every other block, and a timed one whose hour is taken or already
    /// past, goes into the first free gap as `freeStarts(lengths:…)` has always placed it. The
    /// timed ones are settled first and count as taken for the rest, so a block without a time
    /// never lands on top of a call that is due later in the day.
    ///
    /// "Free" means clear of everything in `busy` **and** of the timed blocks already placed. A
    /// timed wish earlier than `from` (the day has moved past it) is not put in the past: it
    /// takes the first gap from now on, as any other block would. The caller leaves a picked
    /// task's own hour out of `busy`; otherwise the task would be in its own way.
    static func starts(for wishes: [PlanWish], from: Int, until: Int,
                       busy: [Range<Int>]) -> [Int?] {
        var taken = busy.filter { !$0.isEmpty }
        var result = [Int?](repeating: nil, count: wishes.count)
        for index in wishes.indices {
            let wish = wishes[index]
            guard wish.length > 0, let at = wish.at, at >= from, at + wish.length <= until else { continue }
            let slot = at..<(at + wish.length)
            guard !taken.contains(where: { $0.overlaps(slot) }) else { continue }
            result[index] = at
            taken.append(slot)
        }
        let rest = wishes.indices.filter { result[$0] == nil }
        let found = freeStarts(lengths: rest.map { wishes[$0].length }, from: from, until: until, busy: taken)
        for (position, index) in rest.enumerated() {
            result[index] = found[position]
        }
        return result
    }
}
