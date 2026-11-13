import Foundation

/// **Which part of the Weekly review opens by itself** (build 312). The review used to open as
/// nine folded lines. Now the first part that still has something to do is open when the review
/// opens, and a part with nothing left carries a tick in its heading.
public enum ReviewOpening {
    /// One part and how many things in it still want doing. `nil` for a part that lists nothing
    /// to work through (steps 7 and 8, and **Projects with no goal**): it never opens by itself
    /// and never carries a tick.
    public struct Part: Equatable, Sendable {
        public var id: String
        public var toDo: Int?

        public init(_ id: String, toDo: Int?) {
            self.id = id
            self.toDo = toDo
        }
    }

    /// The first part, in the order drawn, with something left to do. Nil when none has.
    public static func firstToDo(_ parts: [Part]) -> String? {
        parts.first { ($0.toDo ?? 0) > 0 }?.id
    }

    /// The parts that are open. At the start of a visit: the first part with something to do,
    /// and nothing else. Once the visit has started, what he opened and closed by hand
    /// (`byHand`) is the answer and the rule keeps out of it.
    public static func open(parts: [Part], byHand: Set<String>, visitStarted: Bool) -> Set<String> {
        if visitStarted { return byHand }
        return firstToDo(parts).map { [$0] } ?? []
    }

    /// A tick in the heading: the part counts things to do, and none is left.
    public static func isTicked(toDo: Int?) -> Bool {
        toDo == 0
    }

    /// The words of a part's heading (round 9, build 316): its count after a dot, or — when
    /// the heading carries the tick — the title alone. Never a count and a tick together
    /// ("3. Read the aspirations again · 1 ✓").
    public static func heading(_ title: String, count: Int, toDo: Int?) -> String {
        count > 0 && !isTicked(toDo: toDo) ? "\(title) \u{00B7} \(count)" : title
    }
}

/// **An explanation that steps back once it is known** (build 312). Start the day and Close the
/// day showed their instructions every single day. They now show by themselves the first three
/// times the sheet is opened; after that they wait behind a small info button.
public enum HintRule {
    /// How many openings show the explanation by itself.
    public static let timesShown = 3

    /// The counter after one more opening. It stops one past the limit, so it never grows on.
    public static func counting(_ opensSoFar: Int) -> Int {
        min(max(opensSoFar, 0) + 1, timesShown + 1)
    }

    /// `opens` counts this opening too: 1, 2 and 3 show the explanation, 4 and later fold it.
    public static func showsByItself(opens: Int) -> Bool {
        opens <= timesShown
    }
}

/// A list row's one second line, which may take two lines (round 9, build 316). When all its
/// facts fit they stand on one line, joined with dots. When they do not, the row breaks
/// between the leading facts and the rest — so the lower line starts with words, under the
/// upper one, and never with a dot.
public enum SecondLine {
    public static let dot = " \u{00B7} "

    public static func split(first: [String], rest: [String]) -> (one: String, upper: String, lower: String?) {
        let upper = first.joined(separator: dot)
        let lower = rest.isEmpty ? nil : rest.joined(separator: dot)
        return ((first + rest).joined(separator: dot), upper, lower)
    }
}
