import Foundation

/// One note as the system search (Spotlight) is given it (build 317, features-21).
///
/// **The rule lives here, where it can be tested; the app only hands it on.** What a result
/// shows — the title, a few words of the text, the part of PARAGON the note is in — and which
/// notes are in the index at all is decided in this file. The app's indexer turns an entry
/// into Apple's own item and never reads a note itself.
///
/// **Nothing here writes.** An entry is made from notes the app already holds in memory.
public struct SystemSearchEntry: Equatable, Sendable {
    /// The colour and the mark of the result: the part of PARAGON the note is in.
    public enum Part: String, CaseIterable, Sendable {
        case project, area, resource, goal, aspiration, daily, inbox, archive

        /// The word under the title of a result: "Project", "Daily note".
        public var word: String {
            switch self {
            case .project: return "Project"
            case .area: return "Area"
            case .resource: return "Resource"
            case .goal: return "Goal"
            case .aspiration: return "Aspiration"
            case .daily: return "Daily note"
            case .inbox: return "Inbox"
            case .archive: return "Archive"
            }
        }
    }

    /// The note's path in the vault. It is the result's identity: pressing a result hands this
    /// back, and the app opens the note at that path.
    public var path: String
    public var title: String
    public var part: Part
    /// "Project", or "Weekly note" for a week's note: the word shown with the result.
    public var partWord: String
    /// The first words of the note, without headings, task boxes or hidden task marks.
    public var snippet: String
    /// The note's tags, so a note is found by its tag as well.
    public var tags: [String]
    public var modifiedAt: Date?

    public init(path: String, title: String, part: Part, partWord: String, snippet: String,
                tags: [String], modifiedAt: Date?) {
        self.path = path
        self.title = title
        self.part = part
        self.partWord = partWord
        self.snippet = snippet
        self.tags = tags
        self.modifiedAt = modifiedAt
    }

    /// The line under the title: "Project · Call the bank about the ferry".
    public var resultLine: String {
        snippet.isEmpty ? partWord : partWord + " \u{00B7} " + snippet
    }

    /// Changes exactly when something a result shows has changed. The indexer keeps the last
    /// one it handed over for each note and skips a note whose mark is the same, so saving a
    /// note does not hand the whole vault to the system again.
    public var fingerprint: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for part in [title, partWord, part.rawValue, snippet, tags.joined(separator: ",")] {
            for byte in part.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01B3
            }
            hash ^= 0xFF
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(hash, radix: 16)
    }
}

public enum SystemSearchRule {
    /// Bumped when the shape of an entry changes, so every device builds its index again.
    /// The app joins it to its own build number: a new build is a full rebuild as well.
    public static let shapeVersion = 1

    /// The setting's key, shared by the switch in Settings and the indexer. On when never set.
    public static let settingKey = "showNotesInSystemSearch"

    /// How much of a note's text a result carries.
    public static let snippetLimit = 300

    /// Every note the system search may show.
    ///
    /// - **Work notes are never in it.** They are not in the list this is built from
    ///   (`Vault.allNotes()` never walks the Work folder), and the path is checked again here,
    ///   so a hidden note cannot appear on the lock screen's search.
    /// - **A conflict copy is not in it**: it carries the title of the note it was made from,
    ///   and two results with one name would be a guess.
    /// - **Archived notes are in it**, as they are in PARAGON's own Search, and say "Archive".
    public static func entries(for notes: [Note], workFolder: String = "Work") -> [SystemSearchEntry] {
        notes.compactMap { entry(for: $0, workFolder: workFolder) }
    }

    public static func entry(for note: Note, workFolder: String = "Work") -> SystemSearchEntry? {
        guard !note.isConflictCopy else { return nil }
        let folder = workFolder.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        if !folder.isEmpty, note.relativePath.lowercased().hasPrefix(folder + "/") { return nil }
        let title = note.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let part = part(of: note)
        return SystemSearchEntry(path: note.relativePath, title: title, part: part,
                                 partWord: note.isWeeklyNote ? "Weekly note" : part.word,
                                 snippet: snippet(of: note), tags: note.tags, modifiedAt: note.modifiedAt)
    }

    /// The part a note is shown under. An archived note says Archive whatever it was before;
    /// a goal with no end ("life" horizon) is an aspiration, as in the app's own lists.
    public static func part(of note: Note) -> SystemSearchEntry.Part {
        if note.isArchived { return .archive }
        switch note.kind {
        case .project: return .project
        case .area: return .area
        case .resource: return .resource
        case .archive: return .archive
        case .daily: return .daily
        case .inbox: return .inbox
        case .goal: return (note.horizon ?? .year) == .life ? .aspiration : .goal
        }
    }

    /// The first words of the text: no headings, no empty lines, no task boxes, no hidden task
    /// marks (`^t…`), no picture lines; lines joined by " · ", cut at `snippetLimit` on a word.
    public static func snippet(of note: Note) -> String {
        var parts: [String] = []
        var length = 0
        for raw in TaskIDMasking.hidden(in: note.body).components(separatedBy: "\n") {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("!["),
                  !trimmed.hasPrefix("```"), !trimmed.hasPrefix("---"), !trimmed.hasPrefix("<!--") else { continue }
            let clean = plain(SearchHit.snippetText(trimmed))
            guard !clean.isEmpty else { continue }
            parts.append(clean)
            length += clean.count + 3
            if length >= snippetLimit { break }
        }
        let joined = parts.joined(separator: " \u{00B7} ")
        guard joined.count > snippetLimit else { return joined }
        let cut = String(joined.prefix(snippetLimit))
        let atWord = cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? cut
        return atWord.trimmingCharacters(in: CharacterSet(charactersIn: " \u{00B7}")) + "\u{2026}"
    }

    /// A line without the signs markdown writes around words: `[[Health]]` reads "Health",
    /// `[the bank](https://…)` reads "the bank", and `**`, `__`, `==`, backticks are dropped.
    static func plain(_ line: String) -> String {
        var text = line
        text = text.replacingOccurrences(of: #"\[\[([^\]|]+)\|([^\]]+)\]\]"#, with: "$2", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\[\[([^\]]+)\]\]"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        for sign in ["**", "__", "==", "`"] { text = text.replacingOccurrences(of: sign, with: "") }
        return TaskParser.collapseWhitespace(text).trimmingCharacters(in: .whitespaces)
    }

    /// What has to be handed to the system and what has to be taken out of it, given the marks
    /// of what it already holds (path → fingerprint).
    public static func changes(from known: [String: String],
                               to entries: [SystemSearchEntry]) -> (index: [SystemSearchEntry], remove: [String]) {
        var seen = Set<String>()
        var changed: [SystemSearchEntry] = []
        for entry in entries {
            seen.insert(entry.path)
            if known[entry.path] != entry.fingerprint { changed.append(entry) }
        }
        let gone = known.keys.filter { !seen.contains($0) }.sorted()
        return (changed, gone)
    }
}
