import Foundation

/// How long a task takes, written on the task line as `~45m`, `~1h` or `~1h30m` (build 248).
///
/// The same shape as a date (`>2026-10-06`): a marker the parser lifts out of the title, so the
/// title stays clean in every list, in Reminders and in a plan block. **One place decides the
/// wording**, so the button on a row, the menu and the totals in **Start the day** cannot drift.
public enum TaskTime {
    /// The times offered on screen, in minutes. He asked for 10 to be added to the drawn set.
    public static let choices: [Int] = [10, 15, 30, 45, 60, 90, 120, 180]

    /// `(?<!\S)~(1h)?(30m)?(?!\S)`. Both groups are optional in the pattern, so a bare `~` also
    /// matches it — `minutes(inMatch:of:)` refuses that, and so does every caller.
    static let regex = try! NSRegularExpression(pattern: #"(?<!\S)~(?:(\d{1,2})h)?(?:(\d{1,3})m)?(?!\S)"#)

    /// The marker for a number of minutes: `~10m`, `~1h`, `~1h30m`. Nil for nothing or less.
    public static func token(_ minutes: Int) -> String? {
        guard minutes > 0 else { return nil }
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "~\(m)m"
        case (_, 0): return "~\(h)h"
        default: return "~\(h)h\(m)m"
        }
    }

    /// Reads one marker on its own, `~45m` or `~1h30m`. Nil when it is not one.
    public static func minutes(in token: String) -> Int? {
        let ns = token as NSString
        guard let m = regex.firstMatch(in: token, range: NSRange(location: 0, length: ns.length)),
              m.range.length == ns.length else { return nil }
        return minutes(inMatch: m, of: ns)
    }

    static func minutes(inMatch m: NSTextCheckingResult, of ns: NSString) -> Int? {
        let hours = m.range(at: 1).location == NSNotFound ? nil : Int(ns.substring(with: m.range(at: 1)))
        let mins = m.range(at: 2).location == NSNotFound ? nil : Int(ns.substring(with: m.range(at: 2)))
        guard hours != nil || mins != nil else { return nil }
        let total = (hours ?? 0) * 60 + (mins ?? 0)
        return total > 0 ? total : nil
    }

    /// The words on a task's button: "10 min", "45 min", "1 h", "1 h 30", "2 h".
    public static func label(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) h"
        default: return "\(h) h \(m)"
        }
    }

    /// A sum of times, where the unit must be spelled out: "45 min", "1 h", "2 h 30 min".
    public static func total(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60, m = max(0, minutes) % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) h"
        default: return "\(h) h \(m) min"
        }
    }
}
