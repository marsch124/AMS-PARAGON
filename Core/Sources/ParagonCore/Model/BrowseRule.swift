import Foundation

/// What the iPhone's Browse screen opens with (premium review round 6, build 312).
public enum BrowseRule {
    /// The most notes the strip of recently opened notes shows.
    public static let recentMost = 5

    /// The notes on the strip at the top of Browse: the ones opened last, newest first, five
    /// at most. With none opened yet the answer is empty, and Browse draws no strip at all.
    /// The full list of forty stays what it was; this is only the part Browse shows.
    public static func recentStrip<Item>(_ opened: [Item]) -> [Item] {
        Array(opened.prefix(recentMost))
    }
}
