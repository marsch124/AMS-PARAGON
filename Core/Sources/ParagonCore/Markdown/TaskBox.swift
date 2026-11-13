import Foundation

/// The box at the start of a task line, ticked right in the note's text (build 286).
///
/// A tap (a click on the Mac) on `[ ]` ticks the task exactly as a task row does — done, with
/// its `@done(…)` stamp, and a repeating task gets its next copy on the line below — so the
/// Reminders sync and the Done list cannot tell where it was ticked. A ticked or cancelled box
/// opens again. Everything works on the text of one line, so it needs no note around it.
public enum TaskBox {
    /// The three characters `[ ]` of the task line holding `offset` (UTF-16), when `offset`
    /// is on them. Nil anywhere else: a tap elsewhere in the line only places the cursor.
    public static func boxRange(in text: String, near offset: Int) -> NSRange? {
        let ns = text as NSString
        guard offset >= 0, offset <= ns.length, ns.length > 0 else { return nil }
        let line = ns.lineRange(for: NSRange(location: min(offset, ns.length - 1), length: 0))
        let content = ns.substring(with: line).trimmingCharacters(in: .newlines)
        let cs = content as NSString
        guard let m = TaskParser.lineRegex.firstMatch(in: content, range: NSRange(location: 0, length: cs.length)) else { return nil }
        // The status character is group 3; the box is it with its two brackets.
        let box = NSRange(location: line.location + m.range(at: 3).location - 1, length: 3)
        return NSLocationInRange(offset, NSRange(location: box.location, length: box.length + 1)) ? box : nil
    }

    /// The text with the task on `offset`'s line ticked (or opened again), or nil when that
    /// line is not a task.
    public static func toggled(_ text: String, at offset: Int, date: Date = Date(),
                               calendar: Calendar = .current) -> String? {
        let ns = text as NSString
        guard ns.length > 0, offset >= 0, offset <= ns.length else { return nil }
        let line = ns.lineRange(for: NSRange(location: min(offset, ns.length - 1), length: 0))
        let raw = ns.substring(with: line)
        let content = raw.trimmingCharacters(in: .newlines)
        let ending = String(raw.dropFirst(content.count))
        guard var task = TaskParser.parse(line: content) else { return nil }
        var replacement: String
        if task.isDone {
            task.markOpen()
            replacement = task.serialized
        } else {
            task.markDone(at: date)
            replacement = task.serialized
            if let next = task.nextOccurrence(completedOn: DateOnly(date, calendar: calendar), calendar: calendar) {
                // Build 316: the next copy of a repeat build 315 cannot read carries its id.
                let taken = Set(TaskParser.parse(text: text).compactMap(\.id))
                replacement += "\n" + next.withIDForNewRepeat(avoiding: taken).serialized
            }
        }
        return ns.replacingCharacters(in: line, with: replacement + ending)
    }

    /// The checkbox button above the keyboard: turns the line holding `offset` into a task
    /// (`- [ ] `), or a task back into an ordinary line. The cursor moves with the text.
    public static func switchingTask(_ text: String, at offset: Int) -> (text: String, cursor: Int) {
        let ns = text as NSString
        let safe = min(max(offset, 0), ns.length)
        let line = ns.lineRange(for: NSRange(location: safe, length: 0))
        let raw = ns.substring(with: line)
        let content = raw.trimmingCharacters(in: .newlines)
        let ending = String(raw.dropFirst(content.count))
        let indent = String(content.prefix { $0 == " " || $0 == "\t" })
        let rest = String(content.dropFirst(indent.count))
        let new: String
        if let m = TaskParser.lineRegex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)) {
            let title = m.range(at: 4).location == NSNotFound ? "" : (content as NSString).substring(with: m.range(at: 4))
            new = indent + title
        } else if rest.hasPrefix("- ") || rest.hasPrefix("* ") || rest.hasPrefix("+ ") {
            new = indent + rest.prefix(2) + "[ ] " + rest.dropFirst(2)
        } else {
            new = indent + "- [ ] " + rest
        }
        let delta = (new as NSString).length - (content as NSString).length
        let result = ns.replacingCharacters(in: line, with: new + ending)
        let cursor = min(max(safe + delta, line.location), line.location + (new as NSString).length)
        return (result, cursor)
    }

    /// Every box in the text, so the editor can draw them in the note's colour.
    public static func boxRanges(in text: String) -> [NSRange] {
        let ns = text as NSString
        var found: [NSRange] = []
        var location = 0
        while location < ns.length {
            let line = ns.lineRange(for: NSRange(location: location, length: 0))
            let content = ns.substring(with: line).trimmingCharacters(in: .newlines)
            if let m = TaskParser.lineRegex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)) {
                found.append(NSRange(location: line.location + m.range(at: 3).location - 1, length: 3))
            }
            location = NSMaxRange(line)
        }
        return found
    }

    /// The smallest change that turns `old` into `new`: the part in between their common
    /// start and end. The editor writes only that, so undo and the cursor stay sensible.
    public static func edit(from old: String, to new: String) -> (range: NSRange, replacement: String) {
        let a = Array(old.utf16), b = Array(new.utf16)
        var start = 0
        while start < a.count, start < b.count, a[start] == b[start] { start += 1 }
        var endA = a.count, endB = b.count
        while endA > start, endB > start, a[endA - 1] == b[endB - 1] { endA -= 1; endB -= 1 }
        let replacement = String(utf16CodeUnits: Array(b[start..<endB]), count: endB - start)
        return (NSRange(location: start, length: endA - start), replacement)
    }
}
