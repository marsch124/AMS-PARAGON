import Foundation

/// Build 348: **Record a thought** — a spoken thought, written up and filed.
///
/// The iPhone records (Action Button, Siri or Shortcuts), Apple's speech-to-text writes the
/// words, and Apple's on-device model may add a title, a short summary and the tasks it heard.
/// Everything the app then does with that is decided here, so it can be tested without a
/// microphone: the words on the lock screen while recording, the note in Resources, and the
/// lines in the Inbox.
public struct VoiceThought: Equatable, Sendable {
    /// Everything that was said, as the speech-to-text wrote it.
    public var transcript: String
    /// From the on-device model; nil when it could not be asked (`fallbackTitle` is used).
    public var title: String?
    /// Two or three sentences from the on-device model; nil when there is none.
    public var summary: String?
    /// The tasks the on-device model heard, as it worded them.
    public var tasks: [String]
    public var recordedAt: Date
    /// Seconds from start to stop.
    public var duration: TimeInterval
    /// The on-device model did not finish in time: the note says the summary follows, and
    /// `VoiceThought.enriched` puts it in later.
    public var summaryPending = false

    public init(transcript: String, title: String? = nil, summary: String? = nil, tasks: [String] = [],
                recordedAt: Date, duration: TimeInterval) {
        self.transcript = transcript
        self.title = title
        self.summary = summary
        self.tasks = tasks
        self.recordedAt = recordedAt
        self.duration = duration
    }

    /// The longest recording: it stops and saves by itself after this.
    public static let longest: TimeInterval = 30 * 60
    /// At most this many tasks from one thought go to the Inbox.
    public static let mostTasks = 10
    /// The tag every voice note carries.
    public static let tag = "voice"

    /// Nothing worth saving was heard: no letters or digits at all.
    public var isEmpty: Bool { Self.clean(transcript).isEmpty }

    // MARK: Words

    /// The title the note gets: the model's, cleaned, or else the first words said.
    public var finalTitle: String {
        let given = Self.cleanTitle(title ?? "")
        if !given.isEmpty { return given }
        return Self.fallbackTitle(from: transcript)
    }

    /// The tasks that go to the Inbox: trimmed, without a leading "- [ ]" or bullet, no empty
    /// ones, no two the same (letter case aside), at most `mostTasks`.
    public var finalTasks: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in tasks {
            var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            for prefix in ["- [ ] ", "- [ ]", "[ ] ", "- ", "* ", "• "] where t.hasPrefix(prefix) {
                t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
            t = t.replacingOccurrences(of: "\n", with: " ")
            while t.hasSuffix(".") { t.removeLast() }
            guard !t.isEmpty, Self.hasWords(t) else { continue }
            let key = t.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(t)
            if out.count == Self.mostTasks { break }
        }
        return out
    }

    /// "0:42", "12:05", "1:02:03".
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.down)))
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// The first words said, as a title: up to six words, at most 60 letters, no closing dot.
    public static func fallbackTitle(from transcript: String) -> String {
        let words = clean(transcript).split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return "Voice note" }
        var title = words.prefix(6).joined(separator: " ")
        if title.count > 60 { title = String(title.prefix(60)).trimmingCharacters(in: .whitespaces) }
        title = cleanTitle(title)
        guard let first = title.first else { return "Voice note" }
        return first.uppercased() + title.dropFirst()
    }

    /// The end of what is being said, for the lock screen: the last `limit` letters, starting
    /// at a whole word, with "…" in front when something was left out.
    public static func liveTail(_ transcript: String, limit: Int = 110) -> String {
        let text = clean(transcript)
        guard text.count > limit else { return text }
        let tail = String(text.suffix(limit))
        if let space = tail.firstIndex(where: { $0.isWhitespace }) {
            return "…" + tail[tail.index(after: space)...]
        }
        return "…" + tail
    }

    // MARK: What is written

    /// The new note in Resources, whole: frontmatter, summary, tasks, full text.
    public func noteText(today: DateOnly, timeZone: TimeZone = .current) -> String {
        let title = finalTitle
        var f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        let time = f.string(from: recordedAt)
        f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        let day = f.string(from: recordedAt)
        var lines: [String] = [
            "---",
            "title: \(title)",
            "type: resource",
            "created: \(today.description)",
            "source: voice",
            "tags: [\(Self.tag)]",
            "---",
            "# \(title)",
            "",
            "Voice note · \(day) \(time) · \(Self.clock(duration))",
            "",
            "## Summary",
            "",
        ]
        if let summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            lines.append(summary)
        } else if summaryPending {
            lines.append(Self.pendingLine)
        } else {
            lines.append("No summary: Apple Intelligence was not available on this phone.")
        }
        let tasks = finalTasks
        if !tasks.isEmpty {
            lines += ["", "## Tasks", ""]
            lines += tasks.map { "- " + $0 }
        }
        lines += ["", "## Full text", "", Self.clean(transcript), ""]
        return lines.joined(separator: "\n")
    }

    /// Stands in the note while the summary is still to come.
    public static let pendingLine = "The summary is still being written. PARAGON adds it the next time it opens."

    /// A voice note whose summary came late: the waiting line becomes the summary, and the
    /// tasks go in their own part above the full text. Nil when the note no longer has the
    /// waiting line (he changed it meanwhile): then nothing is touched.
    public static func enriched(_ noteText: String, summary: String, tasks: [String]) -> String? {
        guard noteText.contains(pendingLine) else { return nil }
        let clean = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = noteText.replacingOccurrences(of: pendingLine,
                                                 with: clean.isEmpty ? "No summary was made." : clean)
        let list = VoiceThought(transcript: "x", tasks: tasks, recordedAt: Date(), duration: 0).finalTasks
        if !list.isEmpty, !text.contains("\n## Tasks\n"), let full = text.range(of: "\n## Full text\n") {
            text.insert(contentsOf: "\n## Tasks\n\n" + list.map { "- " + $0 }.joined(separator: "\n") + "\n",
                        at: full.lowerBound)
        }
        return text
    }

    /// The Inbox's line under Notes that leads to the new note.
    public static func inboxNoteLine(title: String, duration: TimeInterval) -> String {
        "- [[\(title)]] — voice note, \(clock(duration))"
    }

    /// The note an Inbox line leads to when it starts with `[[Title]]` (a voice note's line),
    /// and the words after it. Nil for every other line.
    public static func link(inInboxLine line: String) -> (title: String, rest: String)? {
        guard line.hasPrefix("[["), let end = line.range(of: "]]") else { return nil }
        let title = String(line[line.index(line.startIndex, offsetBy: 2)..<end.lowerBound])
        guard !title.isEmpty, !title.contains("[") else { return nil }
        let rest = line[end.upperBound...].trimmingCharacters(in: .whitespaces)
        return (title, rest.hasPrefix("— ") ? String(rest.dropFirst(2)) : rest)
    }

    // MARK: Helpers

    public static func clean(_ text: String) -> String {
        let one = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return hasWords(one) ? one : ""
    }

    static func hasWords(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    /// A title as a file and a `[[link]]` can carry it: one line, no `[ ] | # ^ / \ :`, no
    /// closing dot, at most 80 letters.
    static func cleanTitle(_ raw: String) -> String {
        var t = raw.replacingOccurrences(of: "\n", with: " ")
        for bad in ["[", "]", "|", "#", "^", "/", "\\", ":", "\"", "*"] { t = t.replacingOccurrences(of: bad, with: "") }
        t = t.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        while t.hasSuffix(".") || t.hasSuffix(",") { t.removeLast() }
        if t.count > 80 { t = String(t.prefix(80)).trimmingCharacters(in: .whitespaces) }
        return hasWords(t) ? t : ""
    }
}

public extension Vault {
    /// Files a recorded thought: a new note in Resources, every task as an open Inbox task, and
    /// one Inbox line under Notes leading to the note. Returns the new note's title.
    ///
    /// Nothing is written for a thought with no words (`VoiceThought.isEmpty`): it throws.
    @discardableResult
    func fileVoiceThought(_ thought: VoiceThought, today: DateOnly = .today()) throws -> String {
        try fileVoiceThoughtNote(thought, today: today).title
    }

    /// As `fileVoiceThought`, and where the note went.
    func fileVoiceThoughtNote(_ thought: VoiceThought, today: DateOnly = .today()) throws -> (title: String, path: String) {
        guard !thought.isEmpty else { throw VaultError.invalidTitle }
        guard let folder = config.folder(for: .resource) else { throw VaultError.invalidTitle }
        let title = thought.finalTitle
        let fileName = try freeFileName(forTitle: title, inFolder: folder)
        let note = Note(relativePath: "\(folder)/\(fileName).md", kind: .resource,
                        text: thought.noteText(today: today), modifiedAt: Date())
        try save(note)

        var inbox = try inboxNote()
        for task in thought.finalTasks {
            inbox.append(task: TaskParser.normalized(TaskItem(title: task)))
        }
        inbox.appendLine(VoiceThought.inboxNoteLine(title: title, duration: thought.duration), under: "Notes")
        try save(inbox)
        return (title, note.relativePath)
    }

    /// The late summary of a voice note (`VoiceThought.enriched`), and its tasks into the Inbox.
    /// False when the note is gone or no longer waits for one: nothing is written then.
    @discardableResult
    func addLateVoiceSummary(path: String, summary: String, tasks: [String]) throws -> Bool {
        guard CloudFiles.exists(url(for: path)) else { return false }
        var note = try loadNote(relativePath: path)
        guard let text = VoiceThought.enriched(note.text, summary: summary, tasks: tasks) else { return false }
        note.text = text
        try save(note)
        let list = VoiceThought(transcript: "x", tasks: tasks, recordedAt: Date(), duration: 0).finalTasks
        if !list.isEmpty {
            var inbox = try inboxNote()
            for task in list { inbox.append(task: TaskParser.normalized(TaskItem(title: task))) }
            try save(inbox)
        }
        return true
    }
}
