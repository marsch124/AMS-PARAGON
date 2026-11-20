import Foundation

/// One workout kind and the minutes spent on it today (round 350).
public struct HealthWorkout: Equatable, Sendable {
    public var name: String
    public var minutes: Int

    public init(name: String, minutes: Int) {
        self.name = name
        self.minutes = minutes
    }
}

/// The one line about today's body in the daily note, under `## Health` (round 350):
///
///     ## Health
///
///     Steps 8,412 · Walk 35 min · Strength 40 min
///
/// PARAGON writes it from Apple Health when **Health line in the daily note** is on (iPhone
/// only, read only). **The app owns the section**: it is written again each time, so a line
/// changed by hand is replaced. Nothing else in the note is touched. Like `DayLog`, it is
/// plain markdown that any editor reads.
public enum HealthLine {
    public static let heading = "## Health"

    /// The words, or nil when there is nothing to say (no steps and no workout): an empty line
    /// would say "you did nothing", and Health may simply not have the data.
    ///
    /// Workouts of one kind are added together and keep the order they first appeared in. A
    /// workout under a minute counts as one minute, so it is never shown as "0 min".
    public static func wording(steps: Int?, workouts: [HealthWorkout]) -> String? {
        var parts: [String] = []
        if let steps, steps > 0 {
            parts.append("Steps \(number(steps))")
        }
        var order: [String] = []
        var minutes: [String: Int] = [:]
        for workout in workouts {
            if minutes[workout.name] == nil { order.append(workout.name) }
            minutes[workout.name, default: 0] += max(workout.minutes, 1)
        }
        for name in order {
            parts.append("\(name) \(minutes[name] ?? 1) min")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00b7} ")
    }

    /// 8412 becomes "8,412", the same on every device whatever its language.
    static func number(_ value: Int) -> String {
        let digits = String(value)
        var out = ""
        for (index, ch) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return String(out.reversed())
    }

    /// What the section holds now, or an empty string.
    public static func text(in note: Note) -> String {
        var lines = MarkdownSection.find(heading, in: note.body).lines
        while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// The note with that line in place and nothing else touched. A nil or empty line takes the
    /// whole section out, heading and all (a heading with nothing under it keeps no promise);
    /// a missing section is added at the end.
    public static func note(_ note: Note, settingLine line: String?) -> Note {
        var updated = note
        let clean = (line ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = note.body.components(separatedBy: "\n")
        let found = MarkdownSection.find(heading, in: note.body)
        // Review of build 350: a Health part he wrote himself is never touched. Only an empty
        // part, or one holding nothing but a line PARAGON wrote, is replaced.
        if found.range != nil, !isOwn(text(in: note)) { return note }
        if let range = found.range {
            let headingLine = max(range.lowerBound - 1, 0)
            if clean.isEmpty {
                lines.removeSubrange(headingLine..<range.upperBound)
            } else {
                lines.replaceSubrange(range, with: ["", clean, ""])
            }
        } else {
            guard !clean.isEmpty else { return note }
            while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
            lines.append("")
            lines.append(heading)
            lines.append("")
            lines.append(clean)
            lines.append("")
        }
        updated.body = lines.joined(separator: "\n")
        return updated
    }

    /// Whether the part holds nothing, or only one line in PARAGON's own wording ("Steps …" or
    /// workouts joined by " · ").
    public static func isOwn(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.isEmpty { return true }
        guard lines.count == 1 else { return false }
        let parts = String(lines[0]).components(separatedBy: " \u{00b7} ")
        let stepsPart = try? NSRegularExpression(pattern: #"^Steps [0-9][0-9,.\x{00A0}\x{202F}]*$"#)
        let workoutPart = try? NSRegularExpression(pattern: #"^\S.* [0-9]+ min$"#)
        for (index, part) in parts.enumerated() {
            let range = NSRange(location: 0, length: (part as NSString).length)
            if index == 0, stepsPart?.firstMatch(in: part, range: range) != nil { continue }
            if workoutPart?.firstMatch(in: part, range: range) != nil { continue }
            return false
        }
        return true
    }

    /// How often the app asks Health again while it is open: at most once in this many seconds.
    public static let refreshSeconds: TimeInterval = 30 * 60

    /// Whether enough time has passed since the last reading.
    public static func isDue(lastRead: Date?, now: Date) -> Bool {
        guard let lastRead else { return true }
        return now.timeIntervalSince(lastRead) >= refreshSeconds
    }
}

public extension Note {
    /// The health line of this day, or an empty string.
    var healthLine: String { HealthLine.text(in: self) }
}
