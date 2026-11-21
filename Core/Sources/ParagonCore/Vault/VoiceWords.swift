import Foundation

/// Round 350 (voice-words): what he says out loud that means more than words.
///
/// "Call the bank on Friday" is a task with a day. "Remind me at 3 to call Anna" is a task with a
/// time. "Tag garden" is a tag. "Idea …" is an idea. "Title …" is the title. "Stop recording"
/// ends the recording. Everything here is plain text work, so it can be tested without a
/// microphone: English, German and Swedish.

/// One task he said out loud, with the day and the time he named (if any).
public struct SpokenTask: Equatable, Sendable {
    public var title: String
    public var date: DateOnly?
    public var time: TimeOfDay?

    public init(title: String, date: DateOnly? = nil, time: TimeOfDay? = nil) {
        self.title = title
        self.date = date
        self.time = time
    }
}

/// A word the speech-to-text gets wrong: how it should be written, and how it is heard.
public struct VoiceReplacement: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    /// How the word is written.
    public var word: String
    /// What the speech-to-text writes instead, separated by commas. Empty: only the spelling
    /// (letter case) is put right.
    public var heardAs: String

    public init(id: UUID = UUID(), word: String, heardAs: String = "") {
        self.id = id
        self.word = word
        self.heardAs = heardAs
    }

    /// The list as it is stored in one setting.
    public static func encode(_ list: [VoiceReplacement]) -> String {
        guard let data = try? JSONEncoder().encode(list), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    /// The stored list; empty for a missing or unreadable value.
    public static func decode(_ stored: String) -> [VoiceReplacement] {
        guard let data = stored.data(using: .utf8),
              let list = try? JSONDecoder().decode([VoiceReplacement].self, from: data) else { return [] }
        return list
    }
}

/// A part of a long thought, under its own small heading.
public struct VoiceChapter: Equatable, Sendable {
    public var heading: String
    public var text: String

    public init(heading: String, text: String) {
        self.heading = heading
        self.text = text
    }
}

public enum VoiceWords {
    // MARK: Words that mean something

    public static let tagWords = ["tagga", "tag"]
    public static let ideaWords = ["idea", "idee", "idé"]
    public static let titleWords = ["title", "titel"]
    public static let remindWords = ["remind me", "erinnere mich", "påminn mig"]
    public static let stopPhrases = ["stop recording", "stopp inspelningen", "stopp inspelning", "stoppa inspelningen",
                                     "stoppa inspelning", "aufnahme beenden", "aufnahme stoppen"]
    /// A title said out loud is cut after this many words.
    public static let longestSpokenTitle = 8
    public static let longestIdea = 40
    public static let mostIdeas = 10

    /// What `read` found in the words.
    public struct Reading: Equatable, Sendable {
        /// The words that are kept: without the title phrase, the tag phrases and "stop recording".
        public var text: String
        public var title: String?
        public var tags: [String]
        public var ideas: [String]
    }

    /// Reads the transcript: the replacements, the end phrase, the title, the tags and the ideas.
    public static func read(_ transcript: String, replacements: [VoiceReplacement] = []) -> Reading {
        var text = VoiceThought.clean(prepared(transcript))
        text = applyingReplacements(text, replacements)
        if let stripped = removingStopPhrase(from: text) { text = stripped }
        var sentences = VoiceThought.sentencesOf(text)

        // The title: the very start, "title …".
        var title: String?
        if let first = sentences.first, let after = VoiceThought.afterWord(first, titleWords) {
            if let h = headWords(after, limit: longestSpokenTitle) {
                title = capital(h.head)
                sentences.removeFirst()
                if !h.rest.isEmpty { sentences.insert(capital(h.rest), at: 0) }
            } else if sentences.count > 1, let h = headWords(sentences[1], limit: longestSpokenTitle) {
                title = capital(h.head)
                sentences.removeFirst(2)
                if !h.rest.isEmpty { sentences.insert(capital(h.rest), at: 0) }
            }
        }

        // The tags: a sentence that starts with "tag", and the one word after it.
        var tags: [String] = []
        var kept: [String] = []
        for sentence in sentences {
            if let after = VoiceThought.afterWord(sentence, tagWords), let h = headWords(after, limit: 1) {
                if let tag = TagName.clean(h.head) { tags.append(tag) }
                if !h.rest.isEmpty { kept.append(capital(h.rest)) }
                continue
            }
            kept.append(sentence)
        }

        // The ideas: a sentence that starts with "idea" (or the one after a lone "idea").
        var ideas: [String] = []
        var seen = Set<String>()
        var takeNext = false
        for sentence in kept {
            if let after = VoiceThought.afterWord(sentence, ideaWords) {
                if let idea = VoiceThought.taskText(after, limit: longestIdea) {
                    if seen.insert(VoiceThought.looseKey(idea)).inserted { ideas.append(idea) }
                    takeNext = false
                } else {
                    takeNext = true
                }
                continue
            }
            if takeNext, let idea = VoiceThought.taskText(sentence, limit: longestIdea),
               seen.insert(VoiceThought.looseKey(idea)).inserted {
                ideas.append(idea)
            }
            takeNext = false
        }

        return Reading(text: kept.joined(separator: " "), title: title,
                       tags: TagName.cleaned(tags), ideas: Array(ideas.prefix(mostIdeas)))
    }

    /// The first `limit` words of a sentence (no closing punctuation) and what is left of it.
    static func headWords(_ raw: String, limit: Int) -> (head: String, rest: String)? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while let f = t.first, ":,;-–—.".contains(f) || f.isWhitespace { t.removeFirst() }
        let words = t.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return nil }
        var head = words.prefix(limit).joined(separator: " ")
        while let l = head.last, ".!?,;:".contains(l) { head.removeLast() }
        guard VoiceThought.hasWords(head) else { return nil }
        let rest = words.dropFirst(limit).joined(separator: " ")
        return (head, VoiceThought.hasWords(rest) ? rest : "")
    }

    static func capital(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// "3 p.m." and "kl. 15" lose their dots, or the sentence would end there.
    static func prepared(_ text: String) -> String {
        var t = replacing(text, "(?<![\\p{L}\\p{N}])([ap])\\.m\\.", "$1m")
        t = replacing(t, "(?<![\\p{L}\\p{N}])kl\\.\\s*(?=\\d)", "klockan ")
        return t
    }

    static func replacing(_ text: String, _ pattern: String, _ template: String, caseInsensitive: Bool = true) -> String {
        guard let r = try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []) else { return text }
        return r.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length),
                                          withTemplate: template)
    }

    // MARK: Stop recording

    /// The words without "stop recording" when they end with it; nil otherwise.
    public static func removingStopPhrase(from text: String) -> String? {
        var end = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let l = end.last, ".!?,;:".contains(l) || l.isWhitespace { end.removeLast() }
        for phrase in stopPhrases {
            guard let r = end.range(of: phrase, options: [.caseInsensitive, .backwards]),
                  r.upperBound == end.endIndex else { continue }
            if r.lowerBound > end.startIndex {
                let before = end[end.index(before: r.lowerBound)]
                if before.isLetter || before.isNumber { continue }
            }
            var kept = String(end[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            while let l = kept.last, ",;:-–—".contains(l) { kept.removeLast() }
            return kept.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    // MARK: Words it mishears

    /// The words put right: each "heard as" spelling becomes the written word (whole words only,
    /// letter case ignored). A word with nothing in "heard as" gets its own spelling everywhere.
    public static func applyingReplacements(_ text: String, _ list: [VoiceReplacement]) -> String {
        var result = text
        for item in list {
            let word = item.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }
            var targets = item.heardAs.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if targets.isEmpty { targets = [word] }
            for target in targets {
                let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: target) + "(?![\\p{L}\\p{N}])"
                result = replacing(result, pattern, NSRegularExpression.escapedTemplate(for: word))
            }
        }
        return result
    }

    /// The written words, for the speech analyzer to listen for.
    public static func contextualWords(_ list: [VoiceReplacement]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in list {
            let word = item.word.trimmingCharacters(in: .whitespacesAndNewlines)
            if !word.isEmpty, seen.insert(word.lowercased()).inserted { out.append(word) }
        }
        return out
    }

    // MARK: Summary in English

    /// The switch **Summary in English** is offered when he speaks Swedish: the voice language
    /// is Svenska, or it is the phone's language and the phone is in Swedish.
    public static func offersEnglishSummary(voiceLanguage: String, phoneLanguageCode: String?) -> Bool {
        if voiceLanguage.isEmpty { return phoneLanguageCode == "sv" }
        return voiceLanguage.hasPrefix("sv")
    }

    // MARK: Names turn into links

    /// The words with `[[Title]]` round the first mention of each note title (whole words, letter
    /// case ignored, at least four letters). A mention in other letter case becomes
    /// `[[Title|as said]]`. Words already inside `[[ ]]` are left alone.
    public static func linking(_ text: String, titles: [String]) -> String {
        var seen = Set<String>()
        var usable: [String] = []
        for raw in titles {
            let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let letters = title.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
            guard letters >= 4, seen.insert(title.lowercased()).inserted else { continue }
            if title.contains("[") || title.contains("]") || title.contains("|") || title.contains("#") || title.contains("^") { continue }
            usable.append(title)
        }
        usable.sort { $0.count == $1.count ? $0 < $1 : $0.count > $1.count }

        var result = text
        for title in usable {
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: title) + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = result as NSString
            let linked = linkedRanges(in: result)
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                var inside = false
                for r in linked where NSIntersectionRange(r, m.range).length > 0 { inside = true }
                if inside { continue }
                let mention = ns.substring(with: m.range)
                let link = mention == title ? "[[\(title)]]" : "[[\(title)|\(mention)]]"
                result = ns.replacingCharacters(in: m.range, with: link)
                break
            }
        }
        return result
    }

    static func linkedRanges(in text: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: "\\[\\[.*?\\]\\]", options: []) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map { $0.range }
    }
}

// MARK: Days and times

/// Spoken days and times: "tomorrow", "on Friday", "the 25th", "at 3", "um 15 Uhr", "klockan 15".
enum SpokenWhen {
    static let weekdays: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
        "sonntag": 1, "montag": 2, "dienstag": 3, "mittwoch": 4, "donnerstag": 5, "freitag": 6, "samstag": 7,
        "söndag": 1, "måndag": 2, "tisdag": 3, "onsdag": 4, "torsdag": 5, "fredag": 6, "lördag": 7,
    ]

    struct Clock {
        var hour: Int
        var minute: Int
        var marker: String?
    }

    /// Round 352: true for a German voice language ("de-DE", "de_AT", "de").
    static func isGerman(_ language: String) -> Bool {
        language.lowercased().hasPrefix("de")
    }

    /// The text without the day and time words, and what they said. `german` adds the German
    /// "am 25." (the 25th); it is off for every other language, so "I am 25." stays words.
    static func extract(from raw: String, now: Date, calendar: Calendar,
                        german: Bool = false) -> (text: String, date: DateOnly?, time: TimeOfDay?) {
        var text = raw
        let today = DateOnly(now, calendar: calendar)
        var date: DateOnly?
        if let found = findDate(in: text, today: today, calendar: calendar, german: german) {
            date = found.date
            text = (text as NSString).replacingCharacters(in: found.range, with: " ")
        }
        var time: TimeOfDay?
        if let found = findTime(in: text) {
            let parts = calendar.dateComponents([.hour, .minute], from: now)
            let nowMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let resolved = resolveTime(found.clock, explicitDate: date, today: today, nowMinutes: nowMinutes)
            time = resolved.time
            text = (text as NSString).replacingCharacters(in: found.range, with: " ")
            if date == nil { date = resolved.plusDay ? adding(1, to: today, calendar: calendar) : today }
        }
        return (text, date, time)
    }

    static func adding(_ days: Int, to day: DateOnly, calendar: Calendar) -> DateOnly {
        guard let base = calendar.date(from: day.dateComponents),
              let moved = calendar.date(byAdding: .day, value: days, to: base) else { return day }
        return DateOnly(moved, calendar: calendar)
    }

    static func findDate(in text: String, today: DateOnly, calendar: Calendar,
                         german: Bool = false) -> (range: NSRange, date: DateOnly)? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let edge = "(?<![\\p{L}\\p{N}])"
        let end = "(?![\\p{L}\\p{N}])"

        let relative = edge + "(day after tomorrow|übermorgen|i övermorgon|övermorgon|tomorrow|morgen|imorgon|i morgon|today|heute|idag|i dag)" + end
        if let r = try? NSRegularExpression(pattern: relative, options: [.caseInsensitive]),
           let m = r.firstMatch(in: text, range: full) {
            let word = ns.substring(with: m.range(at: 1)).lowercased()
            var offset = 0
            if ["day after tomorrow", "übermorgen", "i övermorgon", "övermorgon"].contains(word) {
                offset = 2
            } else if ["tomorrow", "morgen", "imorgon", "i morgon"].contains(word) {
                offset = 1
            }
            return (m.range, adding(offset, to: today, calendar: calendar))
        }

        // A weekday needs a word before it ("on Friday", "next Monday", "am Freitag", "på måndag"),
        // so that "about Saturday" stays words.
        let names = weekdays.keys.sorted().joined(separator: "|")
        let weekday = edge + "(?:on|next|this|by|am|nächsten|nächste|kommenden|på|nästa|till|bis)\\s+(" + names + ")" + end
        if let r = try? NSRegularExpression(pattern: weekday, options: [.caseInsensitive]),
           let m = r.firstMatch(in: text, range: full),
           let target = weekdays[ns.substring(with: m.range(at: 1)).lowercased()],
           let base = calendar.date(from: today.dateComponents) {
            let now = calendar.component(.weekday, from: base)
            var delta = (target - now + 7) % 7
            if delta == 0 { delta = 7 }
            return (m.range, adding(delta, to: today, calendar: calendar))
        }

        var ordinals: [String] = [
            edge + "(?:(?:on|by|until)\\s+)?(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)" + end,
            edge + "(?:(?:på|till)\\s+)?(?:den\\s+)?(\\d{1,2}):e" + end,
            edge + "(?:am\\s+)?(\\d{1,2})(?:ten|sten)" + end,
        ]
        // Round 352: German writes the 25th as "25." — only after "am" or "bis zum", and never
        // before a digit ("am 25.11" is not read), and only when German is spoken: in English
        // "I am 25." is an age.
        if german {
            ordinals.append(edge + "(?:am|bis\\s+zum|zum)\\s+(\\d{1,2})\\." + "(?!\\p{N})")
        }
        for pattern in ordinals {
            guard let r = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let m = r.firstMatch(in: text, range: full),
                  let d = Int(ns.substring(with: m.range(at: 1))), (1...31).contains(d),
                  let day = nextDayOfMonth(d, from: today, calendar: calendar) else { continue }
            return (m.range, day)
        }
        return nil
    }

    /// The first date from today on (today included) that is the `d`th of a month.
    static func nextDayOfMonth(_ d: Int, from today: DateOnly, calendar: Calendar) -> DateOnly? {
        var year = today.year
        var month = today.month
        for _ in 0..<13 {
            if let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
               let days = calendar.range(of: .day, in: .month, for: first)?.count, d <= days {
                let candidate = DateOnly(year: year, month: month, day: d)
                if candidate >= today { return candidate }
            }
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
        }
        return nil
    }

    static func findTime(in text: String) -> (range: NSRange, clock: Clock)? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let edge = "(?<![\\p{L}\\p{N}])"
        let end = "(?![\\p{L}\\p{N}]|:)"  // never "[:" in ICU: it starts a [:Property:] class
        let patterns: [String] = [
            edge + "(?:klockan|kl)\\s+(\\d{1,2})(?:(?:\\.|:)(\\d{2}))?" + end,
            edge + "at\\s+(\\d{1,2})(?::(\\d{2}))?(?:\\s*(am|pm))?" + end,
            edge + "um\\s+(\\d{1,2})(?:(?:\\.|:)(\\d{2}))?(?:\\s*uhr)?" + end,
        ]
        for pattern in patterns {
            guard let r = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let m = r.firstMatch(in: text, range: full),
                  let hour = Int(ns.substring(with: m.range(at: 1))), hour <= 23 else { continue }
            var minute = 0
            if m.numberOfRanges > 2, m.range(at: 2).location != NSNotFound {
                minute = Int(ns.substring(with: m.range(at: 2))) ?? 0
            }
            guard minute <= 59 else { continue }
            var marker: String?
            if m.numberOfRanges > 3, m.range(at: 3).location != NSNotFound {
                marker = ns.substring(with: m.range(at: 3)).lowercased()
            }
            return (m.range, Clock(hour: hour, minute: minute, marker: marker))
        }
        return nil
    }

    /// The time on the clock. With no am or pm, "at 3" is the next 3:00 or 15:00 after now
    /// (tomorrow 3:00 when both have passed); with a day ahead it is 15:00 for 1 to 6 and
    /// morning for 7 to 11. `plusDay` is true when the time falls on tomorrow.
    static func resolveTime(_ clock: Clock, explicitDate: DateOnly?, today: DateOnly, nowMinutes: Int) -> (time: TimeOfDay, plusDay: Bool) {
        let h = clock.hour
        let m = clock.minute
        let candidates: [Int]
        if let marker = clock.marker {
            var hh = h
            if marker == "pm" {
                if h < 12 { hh = h + 12 }
            } else if h == 12 {
                hh = 0
            }
            candidates = [hh]
        } else if h == 0 || h >= 12 {
            candidates = [h]
        } else if let d = explicitDate, d != today {
            candidates = [h <= 6 ? h + 12 : h]
        } else {
            candidates = [h, h + 12]
        }
        if let d = explicitDate, d != today { return (TimeOfDay(hour: candidates[0], minute: m), false) }
        for hh in candidates where hh * 60 + m > nowMinutes {
            return (TimeOfDay(hour: hh, minute: m), false)
        }
        if explicitDate == today { return (TimeOfDay(hour: candidates[candidates.count - 1], minute: m), false) }
        return (TimeOfDay(hour: candidates[0], minute: m), true)
    }

    /// What is left of a task sentence once the day and time words are out: no dangling "on",
    /// "at", "to", no space before a comma.
    static func tidy(_ text: String) -> String {
        var t = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        t = VoiceWords.replacing(t, "\\s+([,;:.!?])", "$1")
        t = VoiceWords.replacing(t, "^(?:to|that|att|daran|dran|zu|dass)(?![\\p{L}\\p{N}])[,:]?\\s*", "")
        var before = ""
        while before != t {
            before = t
            t = VoiceWords.replacing(t, "\\s+(?:on|at|by|um|am|på|till|bis|klockan|kl|next|this|nächsten)\\s*[,.]?$", "")
        }
        while let f = t.first, ",;:-–— ".contains(f) { t.removeFirst() }
        while let l = t.last, ",;:-–— ".contains(l) { t.removeLast() }
        return t
    }
}

// MARK: Tasks with a day and a time

extension VoiceThought {
    /// Build 350: the tasks he said out loud, with the day and the time he named. A sentence
    /// that starts with "task" (or "new task", "Aufgabe", "uppgift") is one; so is a sentence
    /// that starts with "remind me" ("erinnere mich", "påminn mig"), also without the word
    /// "task". "Call the bank on Friday" is "Call the bank" on the next Friday; "remind me at 3
    /// to call Anna" is "Call Anna" at 15:00 today (tomorrow 03:00 when both 3:00 and 15:00 have
    /// passed). The day and time words are taken out of the title.
    public static func spokenTaskItems(in transcript: String, now: Date = Date(),
                                       calendar: Calendar = .current, german: Bool = false) -> [SpokenTask] {
        let sentences = sentencesOf(clean(VoiceWords.prepared(transcript)))
        var out: [SpokenTask] = []
        var takeNext = false
        for sentence in sentences {
            if let rest = afterWord(sentence, taskWords) {
                if let item = spokenTask(rest, now: now, calendar: calendar, german: german) {
                    out.append(item)
                    takeNext = false
                } else {
                    takeNext = true
                }
                continue
            }
            if afterWord(sentence, VoiceWords.remindWords) != nil {
                if let item = spokenTask(sentence, now: now, calendar: calendar, german: german) { out.append(item) }
                takeNext = false
                continue
            }
            if takeNext, let item = spokenTask(sentence, now: now, calendar: calendar, german: german) { out.append(item) }
            takeNext = false
        }
        return out
    }

    static func spokenTask(_ raw: String, now: Date, calendar: Calendar, german: Bool = false) -> SpokenTask? {
        let found = SpokenWhen.extract(from: raw, now: now, calendar: calendar, german: german)
        var text = found.text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let f = text.first, ":,;-–—.".contains(f) || f.isWhitespace { text.removeFirst() }
        if let after = afterWord(text, VoiceWords.remindWords) { text = after }
        text = SpokenWhen.tidy(text)
        guard let title = taskText(text) else { return nil }
        return SpokenTask(title: title, date: found.date, time: found.time)
    }

    /// The tasks that go to the Inbox, as task lines: the day and time he said are on the line.
    public func finalTaskItems(calendar: Calendar = .current) -> [TaskItem] {
        let spoken = Self.spokenTaskItems(in: transcript, now: recordedAt.addingTimeInterval(duration), calendar: calendar,
                                          german: speaksGerman)
        return finalTasks.map { title in
            let key = Self.looseKey(title)
            var item = TaskItem(title: title)
            if let said = spoken.first(where: { Self.looseKey($0.title) == key }) {
                item = TaskItem(title: title, dueDate: said.date, dueTime: said.time)
            }
            return TaskParser.normalized(item)
        }
    }

    /// Reads the words he said out loud (`VoiceWords.read`): the transcript becomes the words
    /// that are kept; the title, tags and ideas are put in their own places.
    public mutating func readWords(replacements: [VoiceReplacement] = [], linkTitles: [String] = []) {
        let reading = VoiceWords.read(transcript, replacements: replacements)
        transcript = reading.text
        spokenTitle = reading.title
        extraTags = reading.tags
        ideas = reading.ideas
        self.linkTitles = linkTitles
    }

    /// " (due 2026-11-27 15:00)" as the note shows a task's day; empty when it has none.
    static func dueWords(_ item: TaskItem) -> String {
        guard let date = item.dueDate else { return "" }
        if let time = item.dueTime { return " (due \(date.description) \(time.description))" }
        return " (due \(date.description))"
    }
}

// MARK: Headings in a long thought

public enum VoiceChapters {
    /// From this length on, a thought gets headings: four minutes, or more than 600 words.
    public static let longSeconds: TimeInterval = 4 * 60
    public static let longWords = 600
    public static let mostChapters = 8

    public static func isLong(duration: TimeInterval, transcript: String) -> Bool {
        if duration >= longSeconds { return true }
        return transcript.split(whereSeparator: { $0.isWhitespace }).count > longWords
    }

    /// The text cut into parts at sentence ends, at most `mostChapters`, each at least about
    /// 1,200 letters (the last one too, or it joins the one before). Together they are the whole text.
    /// Empty when the text is too short for two parts.
    public static func chunks(of text: String) -> [String] {
        let clean = VoiceThought.clean(text)
        let size = max(1200, clean.count / mostChapters + 1)
        var parts: [String] = []
        var current = ""
        for sentence in VoiceThought.sentencesOf(clean) {
            current = current.isEmpty ? sentence : current + " " + sentence
            if current.count >= size {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            if current.count < size / 2, !parts.isEmpty {
                parts[parts.count - 1] += " " + current
            } else {
                parts.append(current)
            }
        }
        return parts.count >= 2 ? parts : []
    }

    /// The parts with their headings. A part with no usable heading joins the part before it
    /// (the first one is called "Beginning"). Fewer than two parts: none, and the plain text stays.
    public static func chapters(chunks: [String], headings: [String?]) -> [VoiceChapter] {
        var out: [VoiceChapter] = []
        for (i, chunk) in chunks.enumerated() {
            let raw: String = i < headings.count ? (headings[i] ?? "") : ""
            let heading = VoiceThought.cleanTitle(raw)
            if heading.isEmpty, !out.isEmpty {
                out[out.count - 1].text += " " + chunk
            } else {
                out.append(VoiceChapter(heading: heading.isEmpty ? "Beginning" : heading, text: chunk))
            }
        }
        return out.count >= 2 ? out : []
    }

    /// The full text with a small heading above each part.
    public static func markdown(_ chapters: [VoiceChapter], linking titles: [String]) -> String {
        chapters.map { "### \($0.heading)\n\n" + VoiceWords.linking($0.text, titles: titles) }.joined(separator: "\n\n")
    }
}
