import Foundation

/// Rich text while writing (build 287): bold, italic and headings put in and taken off by a
/// button or a key, and Return that carries a task list on. The note stays plain markdown —
/// every rule here only changes characters in the text.
public enum RichText {
    /// Bold (`**`) or italic (`*`) on the selection, or on the word the cursor is in. Pressed
    /// on text that already has it, it comes off. The stars around the word are counted: an
    /// odd number means italic is on, two or more mean bold is on, so `***both***` works too.
    /// Returns the new text and what is selected afterwards (the same words).
    public static func toggling(_ text: String, selection: NSRange, marker: String) -> (text: String, selection: NSRange) {
        let ns = text as NSString
        var sel = NSRange(location: min(max(selection.location, 0), ns.length), length: 0)
        sel.length = min(max(selection.length, 0), ns.length - sel.location)
        // `~~` (strikethrough, build 288) is a pair like bold, counted in tildes.
        let isStrike = marker.hasPrefix("~")
        let star: unichar = isStrike ? 126 : 42
        let starChar: Character = isStrike ? "~" : "*"
        let isBold = marker.count >= 2
        let width = isBold ? 2 : 1

        // A selection that includes its own stars: look inside them.
        if sel.length > 0 {
            let inner = ns.substring(with: sel)
            let lead = inner.prefix { $0 == starChar }.count
            let trail = String(inner.reversed()).prefix { $0 == starChar }.count
            if lead == trail, lead > 0, lead * 2 < inner.count {
                sel = NSRange(location: sel.location + lead, length: sel.length - 2 * lead)
            }
        }
        // No selection: the word the cursor is in. The cursor stays where it was in the word,
        // and at the word's end it goes past the closing stars, ready to type on.
        let caret: Int? = sel.length == 0 ? sel.location : nil
        if sel.length == 0 {
            var start = sel.location, end = sel.location
            while start > 0, isWordChar(ns.character(at: start - 1)) { start -= 1 }
            while end < ns.length, isWordChar(ns.character(at: end)) { end += 1 }
            if start == end {
                let pair = String(repeating: String(starChar), count: width * 2)
                let result = ns.replacingCharacters(in: sel, with: pair)
                return (result, NSRange(location: sel.location + width, length: 0))
            }
            sel = NSRange(location: start, length: end - start)
        }
        var before = 0
        while before < sel.location, ns.character(at: sel.location - 1 - before) == star { before += 1 }
        var after = 0
        while NSMaxRange(sel) + after < ns.length, ns.character(at: NSMaxRange(sel) + after) == star { after += 1 }
        let stars = min(before, after)
        let on = isBold ? stars >= 2 : stars % 2 == 1
        let stripes = String(repeating: String(starChar), count: width)
        let middle = ns.substring(with: sel)
        if on {
            let whole = NSRange(location: sel.location - width, length: sel.length + 2 * width)
            let result = ns.replacingCharacters(in: whole, with: middle)
            if let caret {
                let atEnd = caret == NSMaxRange(sel)
                return (result, NSRange(location: atEnd ? NSMaxRange(sel) - width : caret - width, length: 0))
            }
            return (result, NSRange(location: sel.location - width, length: sel.length))
        }
        let result = ns.replacingCharacters(in: sel, with: stripes + middle + stripes)
        if let caret {
            let atEnd = caret == NSMaxRange(sel)
            return (result, NSRange(location: atEnd ? NSMaxRange(sel) + 2 * width : caret + width, length: 0))
        }
        return (result, NSRange(location: sel.location + width, length: sel.length))
    }

    /// The H button (⌥⌘H on the Mac): plain → `# ` → `## ` → `### ` → plain.
    public static func cyclingHeading(_ text: String, at offset: Int) -> (text: String, cursor: Int) {
        let ns = text as NSString
        let safe = min(max(offset, 0), ns.length)
        let line = ns.lineRange(for: NSRange(location: safe, length: 0))
        let raw = ns.substring(with: line)
        let content = raw.trimmingCharacters(in: .newlines)
        let ending = String(raw.dropFirst(content.count))
        let hashes = content.prefix { $0 == "#" }.count
        let afterHashes = content.dropFirst(hashes)
        let isHeading = hashes > 0 && (afterHashes.isEmpty || afterHashes.first == " ")
        let body = isHeading ? String(afterHashes.drop { $0 == " " }) : content
        let level = isHeading ? hashes : 0
        let new = level >= 3 ? body : String(repeating: "#", count: level + 1) + " " + body
        let delta = (new as NSString).length - (content as NSString).length
        let result = ns.replacingCharacters(in: line, with: new + ending)
        let cursor = min(max(safe + delta, line.location), line.location + (new as NSString).length)
        return (result, cursor)
    }

    static let taskStart = try! NSRegularExpression(pattern: #"^(\s*)([-*+])\s+\[[ xX>\-]\]\s?"#)
    static let bulletStart = try! NSRegularExpression(pattern: #"^(\s*)([-*+])\s(?!\[)"#)
    /// `1. ` or `1) ` (build 288).
    static let numberStart = try! NSRegularExpression(pattern: #"^(\s*)(\d{1,9})([.)])\s"#)

    /// Return on a task, bullet or numbered line (`1. ` → `2. `, build 288), like Apple Notes: a new empty task (`- [ ] `) or
    /// bullet below with the same indent, the words after the cursor going with it. Return on
    /// an empty one ends the list: its box goes and the line is empty. Nil when Return should
    /// do its ordinary job (not a list line, or the cursor before the box).
    public static func continuingList(_ text: String, at offset: Int) -> (text: String, cursor: Int)? {
        let ns = text as NSString
        guard offset >= 0, offset <= ns.length else { return nil }
        let line = ns.lineRange(for: NSRange(location: offset, length: 0))
        let content = ns.substring(with: line).trimmingCharacters(in: .newlines)
        let cs = content as NSString
        let full = NSRange(location: 0, length: cs.length)
        let match: NSTextCheckingResult
        let isTask: Bool
        var numbered = false
        if let m = taskStart.firstMatch(in: content, range: full) {
            match = m; isTask = true
        } else if let m = bulletStart.firstMatch(in: content, range: full) {
            match = m; isTask = false
        } else if let m = numberStart.firstMatch(in: content, range: full) {
            match = m; isTask = false; numbered = true
        } else { return nil }
        let prefixEnd = line.location + match.range.length
        guard offset >= prefixEnd else { return nil }
        let indent = cs.substring(with: match.range(at: 1))
        let bullet = cs.substring(with: match.range(at: 2))
        let rest = cs.substring(from: match.range.length)
        if rest.trimmingCharacters(in: .whitespaces).isEmpty {
            let contentRange = NSRange(location: line.location, length: cs.length)
            return (ns.replacingCharacters(in: contentRange, with: ""), line.location)
        }
        let start: String
        if numbered {
            let next = (Int(bullet) ?? 0) + 1
            start = indent + String(next) + cs.substring(with: match.range(at: 3)) + " "
        } else {
            start = indent + bullet + (isTask ? " [ ] " : " ")
        }
        let insert = "\n" + start
        let result = ns.replacingCharacters(in: NSRange(location: offset, length: 0), with: insert)
        return (result, offset + (insert as NSString).length)
    }

    private static func isWordChar(_ c: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(c) else { return true } // half of a pair: part of the word
        return CharacterSet.alphanumerics.contains(scalar) || c == 39 || c == 0x2019 || c == 45
    }
}

extension MarkdownHighlight {
    /// The `**`, `*`, `~~` and heading `# ` to hide while writing (build 287): every one, except on
    /// the line holding `cursor`, where they stay so they can be edited. Nil cursor hides all.
    public static func hiddenMarkers(in text: String, cursor: Int?) -> [NSRange] {
        hiddenMarkers(in: text, spans: spans(in: text), cursor: cursor)
    }

    /// The same, from spans already worked out, so the editor reads the note once, not twice.
    public static func hiddenMarkers(in text: String, spans: [MarkdownSpan], cursor: Int?) -> [NSRange] {
        let ns = text as NSString
        var cursorLine: NSRange?
        if let cursor, cursor >= 0, cursor <= ns.length {
            cursorLine = ns.lineRange(for: NSRange(location: cursor, length: 0))
        }
        func onCursorLine(_ r: NSRange) -> Bool {
            guard let c = cursorLine else { return false }
            // A cursor at the very end of a line without a newline still counts as on it.
            return NSIntersectionRange(r, c).length > 0 || (r.location >= c.location && r.location <= NSMaxRange(c))
        }
        var hidden: [NSRange] = []
        for span in spans {
            switch span.style {
            case .heading(let level):
                var length = level
                while span.range.location + length < NSMaxRange(span.range),
                      ns.character(at: span.range.location + length) == 32 { length += 1 }
                let r = NSRange(location: span.range.location, length: length)
                if !onCursorLine(r) { hidden.append(r) }
            case .bold, .italic, .strike:
                let width = span.style == .italic ? 1 : 2
                guard span.range.length > 2 * width else { continue }
                let open = NSRange(location: span.range.location, length: width)
                guard !onCursorLine(open) else { continue }
                hidden.append(open)
                hidden.append(NSRange(location: NSMaxRange(span.range) - width, length: width))
            default:
                continue
            }
        }
        return hidden
    }
}

extension TaskBox {
    /// Long press on the box, **Cancel task**: `[-]`, as the app's own Cancel does.
    public static func cancelled(_ text: String, at offset: Int) -> String? {
        changingTask(text, at: offset) { task in
            task.markCancelled()
            return task
        }
    }

    /// Long press on the box, **Move to tomorrow**: due tomorrow, keeping its time of day
    /// (`TaskItem.settingDueDate`, the Reschedule rule).
    public static func movedToTomorrow(_ text: String, at offset: Int, today: Date = Date(),
                                       calendar: Calendar = .current) -> String? {
        guard let next = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        let day = DateOnly(next, calendar: calendar)
        return changingTask(text, at: offset) { $0.settingDueDate(day) }
    }

    private static func changingTask(_ text: String, at offset: Int, _ change: (inout TaskItem) -> TaskItem) -> String? {
        let ns = text as NSString
        guard ns.length > 0, offset >= 0, offset <= ns.length else { return nil }
        let line = ns.lineRange(for: NSRange(location: min(offset, ns.length - 1), length: 0))
        let raw = ns.substring(with: line)
        let content = raw.trimmingCharacters(in: .newlines)
        let ending = String(raw.dropFirst(content.count))
        guard var task = TaskParser.parse(line: content) else { return nil }
        let changed = change(&task)
        return ns.replacingCharacters(in: line, with: changed.serialized + ending)
    }
}
