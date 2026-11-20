import Foundation

/// One person and everything linked to them (round 350).
///
/// A task is linked with `@person(Anna Svensson)` on its line, a note with a `people:` line in
/// its settings block. Both are written by the **Person…** button; typing them by hand works
/// the same. The page **People** (inside the Tags screen) lists each person with all of it.
public struct PersonEntry: Identifiable {
    /// The spelling used most often.
    public let name: String
    /// Open tasks, the earliest day first, then the ones with no day.
    public let open: [TaskRef]
    /// Tasks that are done or cancelled.
    public let finishedCount: Int
    /// Notes whose `people:` line names the person.
    public let notes: [Note]

    public var id: String { PersonName.key(name) }
    public var total: Int { open.count + finishedCount + notes.count }

    public init(name: String, open: [TaskRef], finishedCount: Int, notes: [Note]) {
        self.name = name
        self.open = open
        self.finishedCount = finishedCount
        self.notes = notes
    }

    /// "2 open · 1 done · 1 note". Nothing is said about a zero.
    public var summary: String {
        var parts: [String] = []
        if !open.isEmpty { parts.append("\(open.count) open") }
        if finishedCount > 0 { parts.append("\(finishedCount) done") }
        if !notes.isEmpty { parts.append("\(notes.count) \(notes.count == 1 ? "note" : "notes")") }
        return parts.isEmpty ? "nothing yet" : parts.joined(separator: " \u{00b7} ")
    }
}

public extension Note {
    /// The people named on the note's `people:` line.
    var people: [String] { frontmatter.list("people") }

    /// The note with this `people:` line. Names are cleaned and a name written twice (whatever
    /// its capitals) is kept once. An empty list writes `people:` and keeps the key, as `tags:`
    /// does.
    func settingPeople(_ names: [String]) -> Note {
        var seen = Set<String>()
        var cleaned: [String] = []
        for raw in names {
            guard let name = PersonName.clean(raw) else { continue }
            if seen.insert(PersonName.key(name)).inserted { cleaned.append(name) }
        }
        var updated = self
        updated.frontmatter.set("people", list: cleaned)
        return updated
    }
}

public extension NoteIndex {
    /// Every person named on a task or a note, A to Z. One pass over the notes.
    func people() -> [PersonEntry] {
        var openFor: [String: [TaskRef]] = [:]
        var finishedFor: [String: Int] = [:]
        var notesFor: [String: [Note]] = [:]
        var spellings: [String: [String: Int]] = [:]

        func remember(_ name: String) -> String {
            let key = PersonName.key(name)
            spellings[key, default: [:]][name, default: 0] += 1
            return key
        }

        for note in notes where !note.isArchived {
            var named = Set<String>()
            for raw in note.people {
                guard let name = PersonName.clean(raw) else { continue }
                let key = remember(name)
                if named.insert(key).inserted { notesFor[key, default: []].append(note) }
            }
            for task in note.tasks {
                guard let raw = task.person, let name = PersonName.clean(raw) else { continue }
                let key = remember(name)
                if task.isDone {
                    finishedFor[key, default: 0] += 1
                } else {
                    openFor[key, default: []].append(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
                }
            }
        }

        var entries: [PersonEntry] = []
        for (key, counts) in spellings {
            // Most used spelling; on a tie the one that sorts first, so the answer is steady.
            let best = counts.sorted { a, b in
                a.value != b.value ? a.value > b.value : a.key < b.key
            }.first?.key ?? key
            let open = (openFor[key] ?? []).sorted { a, b in
                switch (a.task.pressingDay, b.task.pressingDay) {
                case let (x?, y?): return x != y ? x < y : a.task.title < b.task.title
                case (nil, _?): return false
                case (_?, nil): return true
                default: return a.task.title < b.task.title
                }
            }
            entries.append(PersonEntry(name: best, open: open, finishedCount: finishedFor[key] ?? 0,
                                       notes: (notesFor[key] ?? []).sorted { $0.displayTitle < $1.displayTitle }))
        }
        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The people already used, for the chooser: most used first.
    func peopleNames() -> [String] {
        people().sorted { a, b in
            a.total != b.total ? a.total > b.total : a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }.map { $0.name }
    }
}
