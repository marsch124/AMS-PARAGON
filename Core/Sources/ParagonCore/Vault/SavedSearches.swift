import Foundation

/// A search you gave a name to.
///
/// **Build 173.** It was the one thing left on the roadmap he stopped in build 157 — "Saved
/// searches. Roadmap stopped there on his request."
///
/// **Why it is a file of its own and not a note.** A saved search has no text, no tasks and
/// nothing to link to, so a note for it would turn up in Today, the Map, the review and
/// Reminders and be wrong in all of them. It lives in `.ams-para/searches.json`, beside
/// `tags.json`, which nothing scans and nothing syncs — the same decision build 145 made for
/// a tag that is not used yet.
///
/// **What is stored is the query text, not the results.** The text is already the single
/// source of truth for the Search screen (build 157), so a saved search is a string and
/// nothing else: it re-runs against the vault as it is today, and a box ticked on the screen
/// and a box ticked in a saved search cannot mean different things.
public struct SavedSearch: Codable, Identifiable, Equatable, Sendable {
    /// Minted once and never reused, so renaming one does not break anything pointing at it.
    public var id: String
    public var name: String
    /// Exactly what would be in `AppModel.queryText`: words and `key:value` tokens together.
    public var query: String

    public init(id: String = UUID().uuidString, name: String, query: String) {
        self.id = id
        self.name = name
        self.query = query
    }
}

public extension Vault {
    private var savedSearchesURL: URL { stateFolderURL.appendingPathComponent("searches.json") }

    /// The saved searches, in the order they were saved. **An unreadable file reads as none**,
    /// the same as `knownTags()`: a missing list is not worth refusing to open the vault for.
    func savedSearches() -> [SavedSearch] {
        guard let data = try? Data(contentsOf: savedSearchesURL) else { return [] }
        return (try? JSONDecoder().decode([SavedSearch].self, from: data)) ?? []
    }

    func save(searches: [SavedSearch]) throws {
        try FileManager.default.createDirectory(at: stateFolderURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(searches).write(to: savedSearchesURL, options: .atomic)
    }

    /// Adds one, or replaces the one with the same **name**.
    ///
    /// By name rather than by id, because that is the question a person is asking: saving
    /// "Overdue at work" twice means changing it, not keeping two rows with one name. Names
    /// are compared ignoring case and stray spaces, for the same reason.
    @discardableResult
    func addSavedSearch(name: String, query: String) throws -> [SavedSearch] {
        let clean = SavedSearch.cleanName(name)
        guard !clean.isEmpty else { throw VaultError.invalidName }
        var all = savedSearches()
        if let index = all.firstIndex(where: { SavedSearch.sameName($0.name, clean) }) {
            all[index].name = clean
            all[index].query = query
        } else {
            all.append(SavedSearch(name: clean, query: query))
        }
        try save(searches: all)
        return all
    }

    @discardableResult
    func renameSavedSearch(id: String, to name: String) throws -> [SavedSearch] {
        let clean = SavedSearch.cleanName(name)
        guard !clean.isEmpty else { throw VaultError.invalidName }
        var all = savedSearches()
        guard let index = all.firstIndex(where: { $0.id == id }) else { return all }
        // A name another saved search already uses is refused, the way a note's name is
        // (build 77). Two rows reading the same thing is not a list you can work with.
        if all.contains(where: { $0.id != id && SavedSearch.sameName($0.name, clean) }) {
            throw VaultError.nameInUse(clean)
        }
        all[index].name = clean
        try save(searches: all)
        return all
    }

    @discardableResult
    func deleteSavedSearch(id: String) throws -> [SavedSearch] {
        let all = savedSearches().filter { $0.id != id }
        try save(searches: all)
        return all
    }
}

public extension SavedSearch {
    /// Trimmed, and never empty. The one place a name is tidied, so the list and the check for
    /// a name already in use can never disagree.
    static func cleanName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sameName(_ a: String, _ b: String) -> Bool {
        cleanName(a).localizedCaseInsensitiveCompare(cleanName(b)) == .orderedSame
    }

    /// A name to offer when saving: the query in plain words, cut to something that fits a
    /// row. `SearchQuery.summary` is already the one place the query is put into words
    /// (build 157), so the offered name and the line under the tick boxes always agree.
    static func suggestedName(for query: SearchQuery) -> String {
        // **`query.isEmpty`, not an empty summary.** `summary` is never empty — with nothing
        // asked for it says "Nothing searched for yet…", which would be a terrible name and
        // would look to the caller like a real one.
        guard !query.isEmpty else { return "" }
        let summary = query.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = summary.prefix(60)
        return capped.count < summary.count ? String(capped) + "\u{2026}" : String(capped)
    }
}
