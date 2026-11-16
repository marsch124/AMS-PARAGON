import Foundation
import CoreGraphics

/// **Which card row is leaving, and does its card need covering?** (build 327). On the
/// iPhone a ticked row fades with its part of the card, and the page shows through as a pale
/// band until the rows below have closed up. The app draws the card's fill behind the list in
/// the leaving row's place for that moment; this rule says where, and when not to.
public enum LeavingRowRule {
    /// One card row on the screen: where it is, and when it last said so.
    public struct Row: Equatable, Sendable {
        public var frame: CGRect
        public var noted: Date

        public init(frame: CGRect, noted: Date) {
            self.frame = frame
            self.noted = noted
        }
    }

    public struct Cover: Equatable, Sendable {
        /// Which of the rows handed in is the one leaving.
        public var index: Int
        public var frame: CGRect
        /// The row is the first of its card: the cover has the card's rounded top corners.
        public var roundsTop: Bool
    }

    /// Two rows of one card touch: no more than this many points apart.
    public static let touch: CGFloat = 1.5

    /// The cover for the row that holds `point`. Nil when no row holds it, and nil for the
    /// **last row of a card**: there the card really ends higher afterwards, and the row's own
    /// fade is the right picture. When two rows claim the point, the one noted last wins (a
    /// reused row that never said goodbye is the older one).
    public static func cover(at point: CGPoint, rows: [Row]) -> Cover? {
        let holding = rows.indices.filter { rows[$0].frame.contains(point) }
        guard let index = holding.max(by: { rows[$0].noted < rows[$1].noted }) else { return nil }
        let frame = rows[index].frame
        func sameCard(_ other: CGRect) -> Bool { abs(other.minX - frame.minX) < touch }
        let hasBelow = rows.contains { abs($0.frame.minY - frame.maxY) < touch && sameCard($0.frame) }
        guard hasBelow else { return nil }
        let hasAbove = rows.contains { abs($0.frame.maxY - frame.minY) < touch && sameCard($0.frame) }
        return Cover(index: index, frame: frame, roundsTop: !hasAbove)
    }

    /// True when a row noted earlier lies under a newer one: two rows of a list never share
    /// more than a hair, so the older one is a leftover and is forgotten.
    public static func isLeftover(_ old: CGRect, under new: CGRect) -> Bool {
        let shared = old.intersection(new)
        return !shared.isNull && shared.height > 2 && shared.width > 2
    }
}
