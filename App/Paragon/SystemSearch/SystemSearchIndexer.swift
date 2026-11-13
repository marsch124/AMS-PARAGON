import Foundation
import Combine
import CoreSpotlight
import UniformTypeIdentifiers
import ParagonCore

// Build 317 (features-21): notes found from the system search — Spotlight on the iPhone, the
// iPad and the Mac.
//
// **Three rules.**
// 1. **It never touches the vault.** It is given the notes the app already holds in memory and
//    hands their titles and first words to Apple's on-device index. Its one file of its own is
//    a small list of marks in the app's Caches folder, never in the notes folder.
// 2. **The work is off the main thread.** The main thread only takes a copy of the list (a
//    reference, no reading) two seconds after the last change; an actor does the rest.
// 3. **Only what changed is handed over** (`SystemSearchRule.changes`, tested in Core). A new
//    build, another vault or **Build the list again** starts from nothing.

/// The part on the main thread: watches the notes, reads the setting, tells Settings how it is going.
@MainActor
final class SystemSearchIndexer: ObservableObject {
    static let shared = SystemSearchIndexer()

    /// Apple's name for the group these items are in, so only PARAGON's notes are ever removed.
    nonisolated static let domain = "com.schabbauer.amspara.notes"
    nonisolated static let identifierPrefix = "note:"

    /// How many notes the system search holds, or nil before the first pass has finished.
    @Published private(set) var count: Int?
    @Published private(set) var isWorking = false

    private let store = SystemSearchStore()
    private var watch: AnyCancellable?
    private weak var model: AppModel?
    /// A vault was open in this run. Closing it empties the index; a start with no vault (a
    /// folder iCloud has not brought yet) leaves it alone.
    private var hadVault = false

    var isOn: Bool {
        UserDefaults.standard.object(forKey: SystemSearchRule.settingKey) as? Bool ?? true
    }

    /// The screen tests' and pictures' made-up notes never go into the search of the machine
    /// they run on. A debug build can ask for it by name, to look at the results in a simulator.
    private var isAllowedHere: Bool {
        #if DEBUG
        if TestVault.isWanted { return ProcessInfo.processInfo.environment["PARAGON_SYSTEM_SEARCH_TEST"] == "1" }
        #endif
        return true
    }

    /// Starts watching the notes. Asking twice is harmless.
    func start(model: AppModel) {
        guard watch == nil, CSSearchableIndex.isIndexingAvailable(), isAllowedHere else { return }
        self.model = model
        watch = model.$notes
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.pass() }
            }
        pass()
    }

    /// The switch in Settings was moved.
    func settingChanged() {
        if isOn {
            pass(fromNothing: true)
        } else {
            isWorking = true
            Task {
                await store.removeEverything()
                self.count = 0
                self.isWorking = false
            }
        }
    }

    /// **Build the list again** in Settings.
    func rebuild() {
        pass(fromNothing: true)
    }

    private func pass(fromNothing: Bool = false) {
        guard let model, watch != nil else { return }
        guard isOn else { return }
        guard let vault = model.vault else {
            if hadVault {
                hadVault = false
                Task {
                    await store.removeEverything()
                    self.count = 0
                }
            }
            return
        }
        hadVault = true
        let job = SystemSearchStore.Job(
            notes: model.notes,
            workFolder: vault.config.workFolder,
            vaultKey: vault.rootURL.standardizedFileURL.path,
            stamp: "\(SystemSearchRule.shapeVersion).\(BuildStamp.number)",
            // Notes still coming from iCloud are missing from the list, not deleted: nothing
            // is taken out of the search until the vault is all here.
            mayRemove: model.notesWaitingForCloud.isEmpty,
            fromNothing: fromNothing,
            thumbnails: SystemSearchThumbnails.all())
        isWorking = true
        Task {
            let held = await store.run(job)
            // The setting may have been switched off, or the vault closed, while this ran.
            if self.isOn, self.model?.vault != nil { self.count = held }
            self.isWorking = false
        }
    }
}

/// The part off the main thread: works out what changed and hands it to Apple's index.
actor SystemSearchStore {
    struct Job: Sendable {
        var notes: [Note]
        var workFolder: String
        var vaultKey: String
        var stamp: String
        var mayRemove: Bool
        var fromNothing: Bool
        var thumbnails: [SystemSearchEntry.Part: Data]
    }

    /// What is remembered between starts: which build and vault the index was made for, and the
    /// mark of every note in it (path → fingerprint).
    private struct Memory: Codable {
        var stamp: String
        var vault: String
        var marks: [String: String]
    }

    private var memory: Memory?
    private var loaded = false
    /// The entry made for a note the last time, reused while the note is unchanged, so a pass
    /// after one saved note reads one note's text and not the whole vault's.
    private var made: [String: (note: Note, entry: SystemSearchEntry)] = [:]
    private var waiting: Job?
    private var running = false
    /// Counted up each time everything is taken out (review of build 317). An actor lets
    /// `removeEverything` in while a pass waits for Apple's index, and that pass would then
    /// go on handing notes over **after the switch was turned off**. A pass that finds the
    /// number changed stops, and takes out what it put in meanwhile.
    private var emptied = 0

    private static var memoryURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("paragon-system-search.json")
    }

    private var index: CSSearchableIndex { CSSearchableIndex.default() }

    /// Runs the job, or leaves it for the pass already running to pick up when it is done — two
    /// passes never run side by side. Answers how many notes the index holds afterwards.
    func run(_ job: Job) async -> Int {
        if running {
            // A newer list replaces an older one that has not started; "from nothing" is kept.
            var next = job
            next.fromNothing = job.fromNothing || (waiting?.fromNothing ?? false)
            waiting = next
            return memory?.marks.count ?? 0
        }
        running = true
        var current: Job? = job
        while let next = current {
            await work(next)
            current = waiting
            waiting = nil
        }
        running = false
        return memory?.marks.count ?? 0
    }

    /// Takes every PARAGON note out of the system search and forgets the marks.
    func removeEverything() async {
        emptied += 1
        // A list waiting for its turn was made before this, so it is not handed over either.
        waiting = nil
        // Forgotten before the wait below, so a pass that starts during it builds from nothing.
        memory = nil
        loaded = true
        made = [:]
        try? FileManager.default.removeItem(at: Self.memoryURL)
        try? await index.deleteSearchableItems(withDomainIdentifiers: [SystemSearchIndexer.domain])
    }

    private func work(_ job: Job) async {
        let startedAt = emptied
        if !loaded {
            loaded = true
            if let data = try? Data(contentsOf: Self.memoryURL) {
                memory = try? JSONDecoder().decode(Memory.self, from: data)
            }
        }
        // Another build, another vault, no memory, or asked: start from nothing.
        if job.fromNothing || memory == nil || memory?.stamp != job.stamp || memory?.vault != job.vaultKey {
            try? await index.deleteSearchableItems(withDomainIdentifiers: [SystemSearchIndexer.domain])
            guard emptied == startedAt else { return }
            memory = Memory(stamp: job.stamp, vault: job.vaultKey, marks: [:])
        }
        guard var memory else { return }

        var entries: [SystemSearchEntry] = []
        var kept: [String: (note: Note, entry: SystemSearchEntry)] = [:]
        entries.reserveCapacity(job.notes.count)
        for note in job.notes {
            if let before = made[note.relativePath], before.note == note {
                entries.append(before.entry)
                kept[note.relativePath] = before
            } else if let entry = SystemSearchRule.entry(for: note, workFolder: job.workFolder) {
                entries.append(entry)
                kept[note.relativePath] = (note, entry)
            }
        }
        made = kept

        let change = SystemSearchRule.changes(from: memory.marks, to: entries)
        // In batches, so a first pass over a large vault is many small hand-overs and the marks
        // of what is already in are kept if the app is closed half-way.
        var start = 0
        while start < change.index.count {
            let batch = Array(change.index[start..<min(start + 200, change.index.count)])
            start += batch.count
            let items = batch.map { Self.item(for: $0, thumbnail: job.thumbnails[$0.part]) }
            do {
                try await index.indexSearchableItems(items)
                for entry in batch { memory.marks[entry.path] = entry.fingerprint }
            } catch {
                // Not marked as in: the next pass tries these again.
            }
            // Everything was taken out while this batch was on its way (the switch turned
            // off, the vault closed): the batch goes out again and nothing is remembered.
            guard emptied == startedAt else {
                try? await index.deleteSearchableItems(withDomainIdentifiers: [SystemSearchIndexer.domain])
                return
            }
        }
        if job.mayRemove, !change.remove.isEmpty {
            let gone = change.remove.map { SystemSearchIndexer.identifierPrefix + $0 }
            if (try? await index.deleteSearchableItems(withIdentifiers: gone)) != nil {
                for path in change.remove { memory.marks[path] = nil }
            }
        }
        guard emptied == startedAt else { return }
        self.memory = memory
        if !change.index.isEmpty || !change.remove.isEmpty || !FileManager.default.fileExists(atPath: Self.memoryURL.path) {
            if let data = try? JSONEncoder().encode(memory) {
                try? data.write(to: Self.memoryURL, options: .atomic)
            }
        }
    }

    private static func item(for entry: SystemSearchEntry, thumbnail: Data?) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = entry.title
        attributes.displayName = entry.title
        attributes.contentDescription = entry.resultLine
        attributes.kind = entry.partWord
        attributes.keywords = entry.tags + [entry.partWord, "PARAGON"]
        attributes.contentModificationDate = entry.modifiedAt
        attributes.thumbnailData = thumbnail
        let item = CSSearchableItem(uniqueIdentifier: SystemSearchIndexer.identifierPrefix + entry.path,
                                    domainIdentifier: SystemSearchIndexer.domain,
                                    attributeSet: attributes)
        // Apple forgets an item after a month unless told otherwise; a note is there until it
        // is deleted.
        item.expirationDate = .distantFuture
        return item
    }
}
