import Foundation

/// The **Every…** line of a task's Repeat page (round 9, build 316): "Every [2] [weeks]" —
/// a number with a stepper and the unit in a menu.
public enum RepeatEvery {
    /// What the stepper can reach.
    public static let range = 1...999

    /// The units in the menu's order.
    public static let units: [RepeatRule.Unit] = [.day, .week, .month, .year]

    /// A count kept inside what the stepper can reach.
    public static func clamped(_ count: Int) -> Int {
        min(max(count, range.lowerBound), range.upperBound)
    }

    /// The unit's word after the number: "day" after 1, "days" after any other number.
    public static func word(_ unit: RepeatRule.Unit, count: Int) -> String {
        let one: String
        switch unit {
        case .day: one = "day"
        case .week: one = "week"
        case .month: one = "month"
        case .year: one = "year"
        }
        return count == 1 ? one : one + "s"
    }
}
