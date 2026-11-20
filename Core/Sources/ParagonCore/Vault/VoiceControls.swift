import Foundation

// Round 350 (voice-controls): everything the voice recorder's new buttons and pages decide,
// in Core so it can be tested without a microphone. Marking a moment, the voice notes list,
// editing and taking back a filed thought, writing a note up again, and the words read aloud.

public extension VoiceThought {
    /// A typed title as a note's title can carry it (see `cleanTitle`): one line, none of
    /// `[ ] | # ^ / \ :`, no closing dot, at most 80 letters. Empty when no words are left.
    static func tidyTitle(_ raw: String) -> String { cleanTitle(raw) }
}

// MARK: Marking a moment

/// **Mark** on the Lock Screen: the sentence being said at that moment is kept in bold.
public enum VoiceMarks {
    /// The character ranges of every sentence of `text` (a sentence ends with . ! or ? followed by
    /// a space or the end; a dot inside "3.5" does not end one). Counted in characters.
    public static func sentenceRanges(in text: String) -> [Range<Int>] {
        let chars = Array(text)
        var out: [Range<Int>] = []
        var start = 0
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let ends = c == "." || c == "!" || c == "?"
            if ends, i + 1 == chars.count || chars[i + 1].isWhitespace {
                out.append(start..<(i + 1))
                var next = i + 1
                while next < chars.count, chars[next].isWhitespace { next += 1 }
                start = next
                i = next
                continue
            }
            i += 1
        }
        if start < chars.count { out.append(start..<chars.count) }
        return out
    }

    /// The sentences a mark belongs to. An offset is how many characters of the cleaned
    /// transcript were there when the button was pressed, so the sentence being said is the
    /// one holding the last of them. An offset in the gap after a full stop belongs to the
    /// sentence before; one beyond the end, to the last sentence. Sorted, each once.
    public static func markedSentences(in text: String, offsets: [Int]) -> [Int] {
        let ranges = sentenceRanges(in: text)
        guard let last = ranges.last else { return [] }
        var found = Set<Int>()
        for offset in offsets {
            let at = min(max(offset - 1, 0), last.upperBound - 1)
            if let index = ranges.firstIndex(where: { $0.contains(at) }) {
                found.insert(index)
            } else if let before = ranges.lastIndex(where: { $0.upperBound <= at }) {
                found.insert(before)
            } else {
                found.insert(0)
            }
        }
        return found.sorted()
    }

    /// The text with each marked sentence in `**bold**`, and the marked sentences themselves.
    /// Nothing marked: the text unchanged and an empty list.
    public static func marked(_ text: String, offsets: [Int]) -> (text: String, sentences: [String]) {
        let wanted = Set(markedSentences(in: text, offsets: offsets))
        guard !wanted.isEmpty else { return (text, []) }
        let chars = Array(text)
        var parts: [String] = []
        var list: [String] = []
        for (index, range) in sentenceRanges(in: text).enumerated() {
            let sentence = String(chars[range]).replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespaces)
            if wanted.contains(index) {
                parts.append("**" + sentence + "**")
                list.append(sentence)
            } else {
                parts.append(sentence)
            }
        }
        return (parts.joined(separator: " "), list)
    }
}

// MARK: Reading a voice note's text

/// The parts of a voice note's text (`VoiceThought.noteText`) that the new buttons read and
/// change. Everything works on the whole text, so a note he has edited by hand keeps what he
/// wrote: a part that is no longer there is simply not touched.
public enum VoiceNoteText {
    /// The lines of the part under `## heading`, as a range of line numbers; nil when the note
    /// has no such part. The part ends at the next heading.
    static func part(_ heading: String, in lines: [String]) -> Range<Int>? {
        guard let at = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## " + heading }) else { return nil }
        var end = at + 1
        while end < lines.count, !(lines[end].hasPrefix("## ") || lines[end].hasPrefix("# ")) { end += 1 }
        return (at + 1)..<end
    }

    static func lines(of text: String) -> [String] {
        text.components(separatedBy: "\n")
    }

    /// What was said, as written under **Full text**, without the bold of marked sentences.
    public static func fullText(of text: String) -> String? {
        let all = lines(of: text)
        guard let range = part("Full text", in: all) else { return nil }
        let joined = all[range].joined(separator: " ").replacingOccurrences(of: "**", with: "")
        let clean = joined.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return clean.isEmpty ? nil : clean
    }

    /// The summary as written, nil for none or for the two stand-in lines.
    public static func summary(of text: String) -> String? {
        let all = lines(of: text)
        guard let range = part("Summary", in: all) else { return nil }
        let joined = all[range].joined(separator: " ")
        let clean = joined.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if clean.isEmpty || clean == VoiceThought.pendingLine || clean.hasPrefix("No summary") { return nil }
        return clean
    }

    /// The tasks listed under **Tasks**, without the dash.
    public static func tasksListed(in text: String) -> [String] {
        let all = lines(of: text)
        guard let range = part("Tasks", in: all) else { return [] }
        var out: [String] = []
        for line in all[range] {
            var t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("- ") else { continue }
            t = String(t.dropFirst(2))
            if t.hasPrefix("[ ] ") { t = String(t.dropFirst(4)) }
            t = t.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { out.append(t) }
        }
        return out
    }

    /// The text with a new summary. Nil when the note has no **Summary** part (he took it out).
    public static func settingSummary(_ summary: String, in text: String) -> String? {
        var all = lines(of: text)
        guard let range = part("Summary", in: all) else { return nil }
        let clean = summary.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !clean.isEmpty else { return nil }
        all.replaceSubrange(range, with: ["", clean, ""])
        return all.joined(separator: "\n")
    }

    /// Tasks added to the **Tasks** part (made above **Full text** when missing). Only the ones
    /// not there already, by the same rule as `VoiceThought.merged` (letter case aside, a task
    /// that says the same or less is left out). Returns the new text and what was added.
    public static func addingTasks(_ new: [String], to text: String) -> (text: String, added: [String]) {
        let existing = tasksListed(in: text)
        let base = VoiceThought.merged(existing, [])
        let added = Array(VoiceThought.merged(existing, new).dropFirst(base.count))
        guard !added.isEmpty else { return (text, []) }
        var all = lines(of: text)
        if let range = part("Tasks", in: all) {
            var at = range.upperBound
            while at > range.lowerBound, all[at - 1].trimmingCharacters(in: .whitespaces).isEmpty { at -= 1 }
            all.insert(contentsOf: added.map { "- " + $0 }, at: at)
        } else {
            let block = ["## Tasks", ""] + added.map { "- " + $0 } + [""]
            if let full = all.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## Full text" }) {
                all.insert(contentsOf: block, at: full)
            } else {
                while let last = all.last, last.trimmingCharacters(in: .whitespaces).isEmpty { all.removeLast() }
                all.append("")
                all.append(contentsOf: block)
            }
        }
        return (all.joined(separator: "\n"), added)
    }

    /// The text without those tasks in its **Tasks** part. A part left with no task goes too.
    public static func removingTasks(_ titles: [String], from text: String) -> String {
        var all = lines(of: text)
        guard let range = part("Tasks", in: all) else { return text }
        let wanted = Set(titles.map { $0.trimmingCharacters(in: .whitespaces) })
        var kept: [String] = []
        var left = 0
        for line in all[range] {
            var t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("- ") {
                t = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if wanted.contains(t) { continue }
                left += 1
            }
            kept.append(line)
        }
        if left == 0 {
            all.removeSubrange((range.lowerBound - 1)..<range.upperBound)
        } else {
            all.replaceSubrange(range, with: kept)
        }
        return all.joined(separator: "\n")
    }

    /// What is read aloud for a voice note: its title, its summary and how many tasks it holds.
    /// `language` is the start of a language code ("en", "de", "sv"), for the word "tasks".
    public static func spoken(from text: String, language: String = "en") -> String? {
        let all = lines(of: text)
        var title = ""
        if let heading = all.first(where: { $0.hasPrefix("# ") }) {
            title = String(heading.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        var parts: [String] = []
        if !title.isEmpty { parts.append(title + ".") }
        if let said = summary(of: text) { parts.append(said) }
        let count = tasksListed(in: text).count
        if count > 0 { parts.append(taskCount(count, language: language)) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func taskCount(_ count: Int, language: String) -> String {
        switch String(language.lowercased().prefix(2)) {
        case "de": return count == 1 ? "Eine Aufgabe." : "\(count) Aufgaben."
        case "sv": return count == 1 ? "En uppgift." : "\(count) uppgifter."
        default: return count == 1 ? "One task." : "\(count) tasks."
        }
    }
}

// MARK: The voice notes page

/// One line of the voice notes page.
public struct VoiceNoteRow: Equatable, Sendable, Identifiable {
    public var path: String
    public var title: String
    /// "2026-11-20 14:03", as the note's own line says; "" when it has none.
    public var when: String
    /// "0:42"; "" when the note has no such line.
    public var length: String
    /// The start of the summary, or of what was said when there is no summary.
    public var firstWords: String
    /// Title, summary and full text, for the search field.
    var haystack: String

    public var id: String { path }
}

public enum VoiceNoteList {
    /// The rows for notes carrying the `voice` tag, newest first.
    public static func rows(from notes: [Note]) -> [VoiceNoteRow] {
        var rows: [VoiceNoteRow] = []
        for note in notes {
            guard note.tags.contains(where: { $0.lowercased() == VoiceThought.tag }) else { continue }
            let text = note.text
            let found = stamp(in: text)
            rows.append(VoiceNoteRow(path: note.relativePath, title: note.displayTitle, when: found.when,
                                     length: found.length, firstWords: firstWords(of: text),
                                     haystack: note.displayTitle + " " + note.body))
        }
        return rows.sorted { a, b in
            if a.when != b.when { return a.when > b.when }
            return a.path < b.path
        }
    }

    /// Every typed word must be in the title, the summary or what was said (letter case and
    /// accents aside). An empty query keeps every row.
    public static func matching(_ rows: [VoiceNoteRow], _ query: String) -> [VoiceNoteRow] {
        let words = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return rows }
        return rows.filter { row in
            words.allSatisfy { row.haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// "Voice note · 2026-11-20 14:03 · 0:42" gives the time and the length.
    static func stamp(in text: String) -> (when: String, length: String) {
        let dot = " \u{00B7} "
        for line in text.components(separatedBy: "\n") where line.hasPrefix("Voice note" + dot) {
            let parts = line.components(separatedBy: dot)
            let when = parts.count > 1 ? parts[1] : ""
            let length = parts.count > 2 ? parts[2] : ""
            return (when, length)
        }
        return ("", "")
    }

    /// About 110 letters of the summary, cut between words with "…"; of what was said when the
    /// note has no real summary.
    static func firstWords(of text: String, limit: Int = 110) -> String {
        let source = VoiceNoteText.summary(of: text) ?? VoiceNoteText.fullText(of: text) ?? ""
        guard source.count > limit else { return source }
        var cut = String(source.prefix(limit))
        if let space = cut.lastIndex(where: { $0.isWhitespace }) { cut = String(cut[..<space]) }
        return cut + "\u{2026}"
    }
}

// MARK: A thought that was filed

/// What the recorder filed for one thought: enough to take it back, to let him check it, and
/// to name its note. Kept per device (a short list of the newest).
public struct VoiceFiled: Codable, Equatable, Sendable {
    public var path: String
    public var title: String
    /// Filed into today's daily note (the day below), not the Inbox.
    public var toToday: Bool
    /// "2026-11-20": the day whose daily note took it.
    public var day: String
    /// The tasks filed, as worded in the Inbox or the daily note.
    public var tasks: [String]
    public var duration: TimeInterval
    public var locale: String
    public var madeAt: Date
    /// He has seen the check card for it (or the check is switched off).
    public var checked: Bool

    public init(path: String, title: String, toToday: Bool, day: String, tasks: [String],
                duration: TimeInterval, locale: String, madeAt: Date, checked: Bool) {
        self.path = path
        self.title = title
        self.toToday = toToday
        self.day = day
        self.tasks = tasks
        self.duration = duration
        self.locale = locale
        self.madeAt = madeAt
        self.checked = checked
    }
}

public enum VoiceHistory {
    public static let longest = 10

    /// The list with this one first (an older entry for the same note goes), at most `longest`.
    public static func adding(_ filed: VoiceFiled, to list: [VoiceFiled]) -> [VoiceFiled] {
        Array(([filed] + list.filter { $0.path != filed.path }).prefix(longest))
    }

    public static func removing(path: String, from list: [VoiceFiled]) -> [VoiceFiled] {
        list.filter { $0.path != path }
    }

    /// The newest thought that still waits for its check.
    public static func nextToCheck(in list: [VoiceFiled]) -> VoiceFiled? {
        list.first { !$0.checked }
    }
}

public struct VoiceDiscard: Equatable, Sendable {
    /// Tasks taken out of the Inbox or the daily note.
    public var removedTasks: Int
    /// Tasks left because he had already ticked them off or changed them.
    public var keptTasks: Int
    public var noteRemoved: Bool

    /// The words for the message after throwing a thought away.
    public var words: String {
        var text = noteRemoved ? "Thrown away. The note is in Deleted for 30 days." : "Thrown away."
        if keptTasks > 0 {
            text += keptTasks == 1 ? " One task was already ticked off, so it stays." : " \(keptTasks) tasks were already ticked off, so they stay."
        }
        return text
    }
}

public extension Vault {
    /// The note a filed thought's tasks and line went into.
    private func voiceTarget(_ filed: VoiceFiled) throws -> Note {
        if filed.toToday { return try dailyNote(for: DateOnly(filed.day) ?? DateOnly.today()) }
        return try inboxNote()
    }

    /// Takes the open tasks out of where they were filed. Each title goes once, the last line
    /// carrying it (the filed ones are at the end). A ticked or changed task is left, and counted.
    /// `andLine` also takes out the line that leads to the voice note.
    private func removeFiledLines(_ filed: VoiceFiled, titles: [String], andLine: Bool) throws -> (removed: Int, kept: Int) {
        var target = try voiceTarget(filed)
        var lines = target.lines
        var removed = 0
        var kept = 0
        for title in titles {
            let open: Int? = lines.lastIndex(where: { (line: String) -> Bool in
                guard let task = TaskParser.parse(line: line) else { return false }
                return task.title == title && !task.isDone
            })
            if let open {
                lines.remove(at: open)
                removed += 1
            } else if lines.contains(where: { TaskParser.parse(line: $0)?.title == title }) {
                kept += 1
            }
        }
        if andLine {
            let wanted = VoiceThought.inboxNoteLine(title: filed.title, duration: filed.duration)
            if let at = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespaces) == wanted }) { lines.remove(at: at) }
        }
        if lines != target.lines {
            target.lines = lines
            try save(target)
        }
        return (removed, kept)
    }

    /// **Throw away**: the note goes to Deleted (it can be put back for 30 days) and its open
    /// tasks and its line leave the Inbox or the daily note.
    @discardableResult
    func discardVoiceThought(_ filed: VoiceFiled) throws -> VoiceDiscard {
        var noteRemoved = false
        if CloudFiles.exists(url(for: filed.path)) {
            let note = try loadNote(relativePath: filed.path)
            try trash(note)
            noteRemoved = true
        }
        let result = try removeFiledLines(filed, titles: filed.tasks, andLine: true)
        return VoiceDiscard(removedTasks: result.removed, keptTasks: result.kept, noteRemoved: noteRemoved)
    }

    /// The check card's **Save**: the tasks he did not want leave the Inbox or the daily note and
    /// the note's own **Tasks** part. Returns how many left the Inbox or the daily note.
    @discardableResult
    func dropVoiceTasks(_ filed: VoiceFiled, titles: [String]) throws -> Int {
        guard !titles.isEmpty else { return 0 }
        if CloudFiles.exists(url(for: filed.path)) {
            var note = try loadNote(relativePath: filed.path)
            let text = VoiceNoteText.removingTasks(titles, from: note.text)
            if text != note.text {
                note.text = text
                try save(note)
            }
        }
        return try removeFiledLines(filed, titles: titles, andLine: false).removed
    }

    /// **Write it up again**: the model's new summary goes into the note, and the tasks it found
    /// that the note does not list yet are added to its **Tasks** part and to the Inbox. Nothing
    /// is taken out. Returns the tasks added; nil when the note is gone.
    func rewriteVoiceNote(path: String, summary: String, tasks: [String]) throws -> [String]? {
        guard CloudFiles.exists(url(for: path)) else { return nil }
        var note = try loadNote(relativePath: path)
        var text = VoiceNoteText.settingSummary(summary, in: note.text) ?? note.text
        let result = VoiceNoteText.addingTasks(tasks, to: text)
        text = result.text
        if text != note.text {
            note.text = text
            try save(note)
        }
        if !result.added.isEmpty {
            var inbox = try inboxNote()
            for task in result.added { inbox.append(task: TaskParser.normalized(TaskItem(title: task))) }
            try save(inbox)
        }
        return result.added
    }
}
