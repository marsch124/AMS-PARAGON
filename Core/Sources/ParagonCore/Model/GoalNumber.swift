import Foundation

/// A goal with a number to track (build 318): "weigh 82 kg", "save 100 000 kr", "walk 440 km".
///
/// A goal's `measure:` is one line of words, and its per cent comes from the ticked tasks of
/// its projects. Many goals are a number instead, and ticked tasks say he was busy, not that
/// he is closer. So a goal may carry five more settings lines, all optional, all plain:
///
/// ```
/// number_start: 90
/// number_target: 82
/// number_current: 86.5
/// number_unit: kg
/// number_history: [2026-10-01 90, 2026-11-01 88, 2026-11-13 86.5]
/// ```
///
/// The rules, in Core with tests because they decide what is stored and what is shown:
/// - **A goal has a number when `number_target:` holds one.** Without a start the first value
///   of the history is the start, and 0 when there is no history; without a current value the
///   newest history value is it, and the start when there is none.
/// - **Down works as well as up.** How far = (current − start) ÷ (target − start), so
///   90 → 82 with 86 now is 50 %. A start equal to the target has no distance to go: it is
///   100 % once the current value is the target, and no figure otherwise.
/// - **The history is one settings line**, a list of `YYYY-MM-DD value` items, oldest first,
///   one per day: a second update on the same day replaces that day's value. At most
///   `historyLimit` days are kept; the oldest go first, the first one (where he started) stays.
/// - **Numbers in the file are plain**: a dot for decimals, no spaces, at most two decimals,
///   no trailing zeros. What he types may use a comma or a dot, and spaces between thousands.
/// - **Older builds keep all five lines**: `Frontmatter` stores every `key: value` and
///   `key: [a, b]` line it reads and writes it back in place (tested).
/// - **Nothing that changes nothing is written** (the rule of `GoalFields`).
public struct GoalNumber: Equatable, Sendable {
    public static let startKey = "number_start"
    public static let targetKey = "number_target"
    public static let currentKey = "number_current"
    public static let unitKey = "number_unit"
    public static let historyKey = "number_history"
    /// How many days of history one goal keeps.
    public static let historyLimit = 120

    /// One update: the day it was made and the value that day.
    public struct Entry: Equatable, Sendable {
        public var day: DateOnly
        public var value: Double
        public init(day: DateOnly, value: Double) {
            self.day = day
            self.value = value
        }
    }

    public var start: Double
    public var target: Double
    public var current: Double
    /// His own word: km, kg, kr, pages. May be empty.
    public var unit: String
    /// Oldest first, one per day.
    public var history: [Entry]

    public init(start: Double, target: Double, current: Double, unit: String = "", history: [Entry] = []) {
        self.start = start
        self.target = target
        self.current = current
        self.unit = unit
        self.history = history
    }

    // MARK: Reading

    /// The number a goal note carries, or nil when it has no `number_target:` that reads as one.
    public init?(note: Note) {
        guard let target = note.frontmatter.string(Self.targetKey).flatMap(Self.parse) else { return nil }
        let history = Self.history(from: note.frontmatter.list(Self.historyKey))
        let start = note.frontmatter.string(Self.startKey).flatMap(Self.parse) ?? history.first?.value ?? 0
        let current = note.frontmatter.string(Self.currentKey).flatMap(Self.parse) ?? history.last?.value ?? start
        self.init(start: start, target: target, current: current,
                  unit: Self.cleanedUnit(note.frontmatter.string(Self.unitKey) ?? ""), history: history)
    }

    /// The history items that read as `YYYY-MM-DD value`, sorted by day, the last one of a day
    /// winning. An item that does not read is left out of the curve, never out of the file
    /// until the next update rewrites the line.
    static func history(from items: [String]) -> [Entry] {
        var byDay: [DateOnly: Double] = [:]
        for item in items {
            let parts = item.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let day = DateOnly(String(parts[0])), let value = parse(String(parts[1])) else { continue }
            byDay[day] = value
        }
        return byDay.keys.sorted().map { Entry(day: $0, value: byDay[$0] ?? 0) }
    }

    // MARK: How far

    /// True when the target lies below the start: a weight to lose, a debt to pay off.
    public var goesDown: Bool { target < start }

    /// How far from start to target, 0 at the start and 1 at the target. More than 1 when he
    /// went past it, less than 0 when he moved the wrong way. Nil when start and target are
    /// the same and the target is not met: there is no distance to measure against.
    public var fraction: Double? {
        let distance = target - start
        guard distance != 0 else { return current == target ? 1 : nil }
        return (current - start) / distance
    }

    /// What the bar fills: the fraction held between 0 and 1.
    public var barFraction: Double {
        min(1, max(0, fraction ?? 0))
    }

    /// The target is met or passed, in the direction the goal runs.
    public var isReached: Bool {
        if start == target { return current == target }
        return goesDown ? current <= target : current >= target
    }

    /// Whole per cent for the label. Never below 0; above 100 it says so ("112 %"). Never 100
    /// before the target is met, and never 0 once something has moved the right way — both
    /// are read as an answer, not as a rounding (the rule of `GoalProgress.percent`).
    public var percent: Int? {
        guard let fraction else { return nil }
        if fraction <= 0 { return 0 }
        let rounded = Int((fraction * 100).rounded())
        if rounded >= 100, !isReached { return 99 }
        if rounded <= 0 { return 1 }
        return rounded
    }

    /// The points the small curve draws, oldest first: the history, with the start put in
    /// front when the history does not begin there, and the current value at the end when it
    /// was changed by hand in the file. Fewer than two points draw no curve.
    public var curve: [Double] {
        var points = history.map(\.value)
        if points.first != start { points.insert(start, at: 0) }
        if points.last != current { points.append(current) }
        return points
    }

    // MARK: Words

    /// "86.5 of 82 kg".
    public func words(locale: Locale = .current) -> String {
        let pair = "\(Self.shown(current, locale: locale)) of \(Self.shown(target, locale: locale))"
        return unit.isEmpty ? pair : "\(pair) \(unit)"
    }

    /// "86.5 of 82 kg · 44 %", or without the per cent when there is none.
    public func wordsWithPercent(locale: Locale = .current) -> String {
        guard let percent else { return words(locale: locale) }
        return "\(words(locale: locale)) \u{00B7} \(percent) %"
    }

    /// "86.5 kg".
    public func valueWords(_ value: Double, locale: Locale = .current) -> String {
        unit.isEmpty ? Self.shown(value, locale: locale) : "\(Self.shown(value, locale: locale)) \(unit)"
    }

    // MARK: Numbers as text

    /// A number as it stands in the file: a dot, at most two decimals, no trailing zeros.
    public static func plain(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded(), abs(rounded) < 1e15 {
            return String(Int64(rounded))
        }
        var text = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// A number as he reads it: his own decimal sign and a space or point between thousands.
    public static func shown(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? plain(value)
    }

    /// What he typed, as a number: "86,5", "86.5", "100 000", "1 250,75" and "-3" all read.
    /// Nil for anything else, and for an empty field. A comma and a dot together read with the
    /// last of the two as the decimal sign ("1.250,75" and "1,250.75").
    public static func parse(_ typed: String) -> Double? {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\u{2212}", with: "-")
        for space in [" ", "\u{00A0}", "\u{202F}", "\u{2009}", "'"] {
            text = text.replacingOccurrences(of: space, with: "")
        }
        guard !text.isEmpty else { return nil }
        if let comma = text.lastIndex(of: ","), let dot = text.lastIndex(of: ".") {
            let thousands: Character = comma > dot ? "." : ","
            text.removeAll { $0 == thousands }
        }
        text = text.replacingOccurrences(of: ",", with: ".")
        guard text.filter({ $0 == "." }).count <= 1,
              text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == "-") }),
              !text.dropFirst().contains("-"),
              let value = Double(text), value.isFinite else { return nil }
        return value
    }

    /// The unit as stored: one line, trimmed, at most 16 characters.
    public static func cleanedUnit(_ typed: String) -> String {
        String(WeekGoal.cleaned(typed).prefix(16)).trimmingCharacters(in: .whitespaces)
    }

    // MARK: Writing

    /// The note with a new current value, dated `day`: `number_current:` is set and the
    /// history gets the day's value (a second update the same day replaces the first). A note
    /// without a number, or the same value on a day already holding it, comes back unchanged.
    public static func updating(_ value: Double, on note: Note, day: DateOnly) -> Note {
        guard let number = GoalNumber(note: note) else { return note }
        var history = number.history
        // The first update of a goal set up by hand: keep where he stood before as a point.
        history.removeAll { $0.day == day }
        history.append(Entry(day: day, value: value))
        history.sort { $0.day < $1.day }
        return writing(start: number.start, target: number.target, current: value, unit: number.unit,
                       history: history, on: note)
    }

    /// The note with its number set up or changed: start, target, current and unit. The
    /// history is kept; a current value that differs from the one on file is dated `day` in
    /// it, and a goal that had no number gets its first history entry.
    public static func setting(start: Double, target: Double, current: Double, unit: String,
                               on note: Note, day: DateOnly) -> Note {
        let before = GoalNumber(note: note)
        var history = before?.history ?? []
        if before == nil || before?.current != current || history.isEmpty {
            history.removeAll { $0.day == day }
            history.append(Entry(day: day, value: current))
            history.sort { $0.day < $1.day }
        }
        return writing(start: start, target: target, current: current, unit: cleanedUnit(unit),
                       history: history, on: note)
    }

    /// The note without its number: all five lines taken out. Unchanged when it has none.
    public static func removing(from note: Note) -> Note {
        var updated = note
        for key in [startKey, targetKey, currentKey, unitKey, historyKey] where note.frontmatter[key] != nil {
            updated.frontmatter.remove(key)
        }
        return updated
    }

    private static func writing(start: Double, target: Double, current: Double, unit: String,
                                history: [Entry], on note: Note) -> Note {
        var kept = history
        if kept.count > historyLimit {
            // The oldest go first, but the first entry — where he started — stays.
            kept = [kept[0]] + kept.suffix(historyLimit - 1)
        }
        var updated = note
        set(startKey, plain(start), on: &updated)
        set(targetKey, plain(target), on: &updated)
        set(currentKey, plain(current), on: &updated)
        if unit.isEmpty {
            if updated.frontmatter[unitKey] != nil { updated.frontmatter.remove(unitKey) }
        } else {
            set(unitKey, unit, on: &updated)
        }
        let items = kept.map { "\($0.day.description) \(plain($0.value))" }
        if updated.frontmatter[historyKey] != FrontmatterValue.list(items) {
            updated.frontmatter.set(historyKey, list: items)
        }
        return updated
    }

    /// Sets one line only when it says something else, so an unchanged note stays equal.
    private static func set(_ key: String, _ value: String, on note: inout Note) {
        guard note.frontmatter[key] != FrontmatterValue.string(value) else { return }
        note.frontmatter.set(key, value)
    }
}

public extension Note {
    /// The number this goal tracks, or nil when it has none.
    var goalNumber: GoalNumber? { GoalNumber(note: self) }
}
