import Foundation

/// One saved copy of the vault, kept in `.ams-para/Backups/<yyyy-MM-dd HHmm>`.
/// Plain folders, not archives, so a single note can be dragged back in Finder.
public struct VaultBackup: Identifiable, Equatable, Sendable {
    public var folderName: String
    public var date: Date
    public var noteCount: Int
    /// What triggered it: "sync", "daily", "rename", "before restore" or "manual".
    public var reason: String
    /// Outside copies only (build 316): the vault's own sub-folder of "PARAGON Backups" the
    /// copy is in. Nil for a copy inside the vault, and for an outside copy in the old place,
    /// straight in "PARAGON Backups", where every copy went up to build 315.
    public var subfolder: String? = nil

    public var id: String { subfolder.map { "\($0)/\(folderName)" } ?? folderName }

    public static let folderFormat = "yyyy-MM-dd HHmm"

    /// The date in a folder name. A second backup in the same minute is named "… 2~reason";
    /// without the trailing number it would not parse, and such a backup was invisible in the
    /// list and therefore never cleared out either.
    static func date(fromFolderPart part: String) -> Date? {
        if let date = formatter.date(from: part) { return date }
        guard let space = part.lastIndex(of: " "), Int(part[part.index(after: space)...]) != nil else { return nil }
        return formatter.date(from: String(part[part.startIndex..<space]))
    }

    /// How many before-sync copies are kept, newest first.
    public static let keptSyncCopies = 5
    /// One copy per day is kept for this many days (today included).
    public static let keptDays = 14
    /// One copy per week is kept for this many days back.
    public static let keptWeeksSpan = 61

    /// The copies to clear out (build 307, hardening-06). Until then the ten newest of any kind
    /// were kept, so with automatic sync a few hours of before-sync copies pushed the daily ones
    /// out the same day. Kept now: the newest copy of all; the 5 newest before-sync copies; every
    /// other copy of today and yesterday; the newest copy of each of the last 14 days; the newest copy of each week of the last two
    /// months; and anything named in `protecting`. Everything else goes.
    public static func toRemove(from backups: [VaultBackup], now: Date,
                                calendar: Calendar = .current,
                                protecting: Set<String> = []) -> [VaultBackup] {
        let newestFirst = backups.sorted { $0.date > $1.date }
        var keep = protecting
        if let newest = newestFirst.first { keep.insert(newest.folderName) }
        for copy in newestFirst.filter({ $0.reason == "sync" }).prefix(keptSyncCopies) {
            keep.insert(copy.folderName)
        }
        let today = calendar.startOfDay(for: now)
        let dayLimit = calendar.date(byAdding: .day, value: -(keptDays - 1), to: today) ?? today
        let weekLimit = calendar.date(byAdding: .day, value: -keptWeeksSpan, to: today) ?? today
        // Every copy of the last two days that is not a before-sync copy stays: the copy made
        // before a restore or a rename is the way back, and must not be pushed out by the next
        // one the same day.
        let recentLimit = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        for copy in newestFirst where copy.reason != "sync" && copy.date >= recentLimit {
            keep.insert(copy.folderName)
        }
        var seenDays: Set<Date> = []
        var seenWeeks: Set<String> = []
        // The day's and the week's copy is one that is not a before-sync copy when there is one:
        // those have their own five places and must not stand in for the daily copy.
        let ordered = newestFirst.filter { $0.reason != "sync" } + newestFirst.filter { $0.reason == "sync" }
        for copy in ordered {
            let day = calendar.startOfDay(for: copy.date)
            if day >= dayLimit, seenDays.insert(day).inserted { keep.insert(copy.folderName) }
            if day >= weekLimit {
                let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: copy.date)
                let week = "\(parts.yearForWeekOfYear ?? 0)-\(parts.weekOfYear ?? 0)"
                if seenWeeks.insert(week).inserted { keep.insert(copy.folderName) }
            }
        }
        return newestFirst.filter { !keep.contains($0.folderName) }
    }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = folderFormat
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

/// What a restore managed to put back. `failed` names the files that could not be written,
/// which are the ones still holding whatever was in the vault before.
public struct RestoreResult: Equatable, Sendable {
    public let written: Int
    public let failed: [String]
    /// How many of the written files are notes (build 316), for "Restored 15 notes".
    public let notes: Int

    public var isComplete: Bool { failed.isEmpty }

    public init(written: Int, failed: [String], notes: Int = 0) {
        self.written = written
        self.failed = failed
        self.notes = notes
    }

    /// The one line that says what a restore did (build 316), for the message and for the
    /// line that stays in Settings: "Restored 15 notes from 2026-11-13 08:57". `stamp` is the
    /// day and time of the copy. "from", the day and the time are joined so that they never
    /// part at a line's end (round 9: the line broke as "2026-11-13 / 16:14"); on a narrow
    /// screen the second line is "from 2026-11-13 16:14", whole.
    public func line(stamp: String) -> String {
        func count(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
        let from = "from\u{00A0}" + stamp.replacingOccurrences(of: " ", with: "\u{00A0}")
        guard isComplete else {
            return "Restored \(written) of \(count(written + failed.count, "file")) \(from). "
                + "\(failed.count) could not be written."
        }
        if written == 0 { return "Nothing was put back \(from). Your notes are as they were." }
        let others = written - notes
        if notes == 0 { return "Restored \(count(written, "file")) \(from)" }
        if others == 0 { return "Restored \(count(notes, "note")) \(from)" }
        return "Restored \(count(notes, "note")) and \(count(others, "other file")) \(from)"
    }

    /// True for a line that says everything was put back: Settings draws a green tick before
    /// it. A line about files that could not be written, or about nothing put back, has none.
    public static func lineSaysAllWentWell(_ line: String) -> Bool {
        line.hasPrefix("Restored ") && !line.contains("could not be written")
    }
}

/// A vault's name and its lasting identity (review round 8): written into every outside copy,
/// so a copy of another vault is never offered for a restore into this one.
public struct VaultIdentity: Codable, Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// An outside copy that may be put back into this vault (review round 8).
public struct OutsideCopy: Identifiable, Equatable, Sendable {
    public var backup: VaultBackup
    /// Nil for a copy marked as made of this vault. For a copy with no mark (made before build
    /// 315) the names of its top folders, so he can tell which vault it is of.
    public var unmarkedFolders: [String]?

    public var id: String { backup.id }
    public var isMarked: Bool { unmarkedFolders == nil }
    /// Saved by a restore, just before it put another copy back.
    public var isBeforeRestore: Bool { backup.reason == "before restore" }

    public init(backup: VaultBackup, unmarkedFolders: [String]?) {
        self.backup = backup
        self.unmarkedFolders = unmarkedFolders
    }

}

public extension Vault {
    var backupsURL: URL { stateFolderURL.appendingPathComponent("Backups", isDirectory: true) }

    /// The folder inside a place the user chose (or the device's own storage) that holds the
    /// outside copies. A folder of its own, so clearing out old copies can never touch anything
    /// else he keeps in the place he chose.
    static let outsideFolderName = "PARAGON Backups"

    /// Where the outside copies of this vault go inside `place` (build 308, hardening-13).
    static func outsideBackupsURL(in place: URL) -> URL {
        place.appendingPathComponent(outsideFolderName, isDirectory: true)
    }

    /// Saved copies, newest first. `folder` is where to look: the vault's own Backups folder
    /// when nil, otherwise a folder of outside copies — and there only a folder that holds a
    /// finished copy's `signature.txt` counts, so nothing else in it is ever listed or cleared.
    func backups(in folder: URL? = nil) -> [VaultBackup] {
        copies(in: folder, subfolder: nil)
    }

    /// The copies straight inside one folder. `subfolder` is only written into each result.
    private func copies(in folder: URL?, subfolder: String?) -> [VaultBackup] {
        let fm = FileManager.default
        let home = folder ?? backupsURL
        guard let entries = try? fm.contentsOfDirectory(at: home, includingPropertiesForKeys: nil) else { return [] }
        return entries.compactMap { url -> VaultBackup? in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            if folder != nil, !fm.fileExists(atPath: url.appendingPathComponent("signature.txt").path) { return nil }
            let name = url.lastPathComponent
            let parts = name.split(separator: "~", maxSplits: 1).map(String.init)
            guard let date = VaultBackup.date(fromFolderPart: parts[0]) else { return nil }
            let count = (fm.enumerator(at: url, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension.lowercased() == "md" }
                .count) ?? 0
            return VaultBackup(folderName: name, date: date, noteCount: count,
                               reason: parts.count > 1 ? parts[1] : "manual", subfolder: subfolder)
        }
        .sorted { $0.date > $1.date }
    }

    /// Copies every note and the vault's settings into a new backup folder. Returns nil when
    /// nothing changed since the last backup, so repeated syncs do not pile up copies.
    @discardableResult
    ///
    /// `prune: false` keeps every older copy (a restore clears out old ones only once it is done,
    /// so the copy being restored can never be the one that makes room — build 307).
    func makeBackup(reason: String = "manual", prune: Bool = true, now: Date = Date()) throws -> VaultBackup? {
        try makeCopy(outsideIn: nil, reason: reason, prune: prune, now: now)
    }

    /// A second copy **outside the vault** (build 308, hardening-13): in `place` — a folder the
    /// user chose once, or the device's own storage — under "PARAGON Backups". Until then every
    /// copy sat in `.ams-para/Backups` inside the vault, so losing the vault folder (deleted,
    /// an iCloud mishap) lost the notes and every backup of them together.
    ///
    /// Unlike the copies inside the vault, these hold the **pictures and sketches** too. A
    /// picture that has not changed since the last outside copy is taken from that copy, which
    /// on an Apple disk costs no extra room; the same tiers decide which copies are kept.
    /// Returns nil when nothing changed since the last outside copy.
    @discardableResult
    func makeOutsideCopy(in place: URL, reason: String = "daily", now: Date = Date()) throws -> VaultBackup? {
        try makeCopy(outsideIn: place, reason: reason, prune: true, now: now)
    }

    /// The outside copies in `place` that can be this vault's, newest first (build 316): the
    /// ones in this vault's own sub-folders, and every copy in the old place, straight in
    /// "PARAGON Backups" (whose copy each of those is, its mark says). Another vault's
    /// sub-folder is never looked into.
    func outsideCopies(in place: URL) -> [VaultBackup] {
        let home = Self.outsideBackupsURL(in: place)
        var found = copies(in: home, subfolder: nil)
        for name in outsideSubfolders(in: place, of: knownIdentities().all) {
            found += copies(in: home.appendingPathComponent(name, isDirectory: true), subfolder: name)
        }
        return found.sorted { $0.date > $1.date }
    }

    /// Where one outside copy is.
    func outsideCopyURL(_ backup: VaultBackup, in place: URL) -> URL {
        var home = Self.outsideBackupsURL(in: place)
        if let sub = backup.subfolder { home.appendPathComponent(sub, isDirectory: true) }
        return home.appendingPathComponent(backup.folderName, isDirectory: true)
    }

    // MARK: One sub-folder per vault (round 9, build 316)

    /// The name of a new sub-folder for a vault's copies: the vault's name, then its identity.
    /// The identity is what counts; the name is there for a person looking in Finder.
    static func outsideSubfolderName(for identity: VaultIdentity) -> String {
        "\(identity.name) \(identity.id)"
    }

    /// The sub-folders of "PARAGON Backups" that belong to one of `ids`: named exactly as the
    /// identity, or ending in a space and the identity (the vault may have been renamed since).
    func outsideSubfolders(in place: URL, of ids: Set<String>) -> [String] {
        let ids = ids.filter(VaultIDs.isWellFormed)
        guard !ids.isEmpty else { return [] }
        let home = Self.outsideBackupsURL(in: place)
        let entries = (try? FileManager.default.contentsOfDirectory(at: home, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .filter { name in ids.contains { name == $0 || name.hasSuffix(" \($0)") } }
            .sorted()
    }

    /// The outside copies that are **surely this vault's**: marked, the mark readable here,
    /// and naming one of the vault's identities. Only these are ever cleared out, and only
    /// these decide whether the vault changed since the last copy.
    func ownMarkedOutsideCopies(in place: URL) -> [VaultBackup] {
        let ids = knownIdentities().all
        guard !ids.isEmpty else { return [] }
        return outsideCopies(in: place).filter { backup in
            let mark = outsideCopyURL(backup, in: place).appendingPathComponent(Self.ownerFileName)
            guard FileManager.default.fileExists(atPath: mark.path), CloudFiles.presence(of: mark) != .away,
                  !CloudFiles.isDataless(mark),
                  let data = try? Data(contentsOf: mark),
                  let owner = try? JSONDecoder().decode(VaultIdentity.self, from: data) else { return false }
            return ids.contains(owner.id)
        }
    }

    /// Clears out old outside copies by the same tiers as inside the vault — **this vault's
    /// own marked copies only** (build 316). A copy of another vault, a copy with no mark, a
    /// copy whose mark cannot be read here, and anything else in the folder are never touched.
    /// Until build 315 the tiers ran over every copy in the folder, so two vaults sharing one
    /// folder thinned out each other's.
    func pruneOutsideCopies(in place: URL, now: Date = Date(), protecting: Set<String> = []) {
        let own = ownMarkedOutsideCopies(in: place)
        // The tiers go by folder name. Two copies of the same name in two places both stay.
        for old in VaultBackup.toRemove(from: own, now: now, protecting: protecting) {
            try? FileManager.default.removeItem(at: outsideCopyURL(old, in: place))
        }
    }

    // MARK: Whose copy it is (review round 8)

    /// The file in an outside copy that names the vault it was made of.
    static let ownerFileName = "paragon-copy-of.json"

    /// Where the vault keeps its own identity: one line, made once, travelling with the vault.
    var identityURL: URL { stateFolderURL.appendingPathComponent("vault-id.txt") }

    /// The folder with one small file per identity this vault has had (`VaultIDs`).
    var identityRecordsURL: URL { stateFolderURL.appendingPathComponent(VaultIDs.folderName, isDirectory: true) }

    /// The identities noted in `.ams-para/vault-ids`. Only the file names are read, so a
    /// record that is still in iCloud counts as well.
    func identityRecords() -> [VaultIDRecord] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: identityRecordsURL.path)) ?? []
        return names.compactMap { VaultIDs.record(fromFileName: CloudFiles.realName(ofPlaceholder: $0) ?? $0) }
    }

    /// What `vault-id.txt` says. `.unknown` when it cannot be read here (still in iCloud).
    private enum IdentityFile { case none, unknown, id(String) }

    private func identityFile() -> IdentityFile {
        let fm = FileManager.default
        let url = identityURL
        if fm.fileExists(atPath: CloudFiles.placeholderURL(for: url).path) { return .unknown }
        guard fm.fileExists(atPath: url.path) else { return .none }
        guard CloudFiles.presence(of: url) != .away,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return .unknown }
        let id = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? .unknown : .id(id)
    }

    /// The vault's identity and every identity it has had (build 316): the one in
    /// `vault-id.txt` and the ones noted in `.ams-para/vault-ids`. `current` is the oldest of
    /// them (`VaultIDs.winner`); nil while `vault-id.txt` cannot be read. Reads only.
    func knownIdentities() -> (current: String?, all: Set<String>) {
        var records = identityRecords()
        var all = Set(records.map(\.id))
        switch identityFile() {
        case .unknown:
            return (nil, all)
        case .none:
            return (VaultIDs.winner(of: records), all)
        case .id(let id):
            all.insert(id)
            if !records.contains(where: { $0.id == id }) {
                records.append(VaultIDRecord(id: id, created: VaultIDs.unrecordedCreated))
            }
            // An identity that is not shaped like PARAGON's own was put there by hand: it is
            // kept as it is, and no other one replaces it.
            guard VaultIDs.isWellFormed(id) else { return (id, all) }
            return (VaultIDs.winner(of: records) ?? id, all)
        }
    }

    /// Notes one identity in `.ams-para/vault-ids`, unless it is noted already.
    private func noteIdentity(_ id: String, created: Date) {
        guard VaultIDs.isWellFormed(id), !identityRecords().contains(where: { $0.id == id }) else { return }
        let fm = FileManager.default
        let url = identityRecordsURL.appendingPathComponent(VaultIDs.fileName(for: VaultIDRecord(id: id, created: created)))
        try? fm.createDirectory(at: identityRecordsURL, withIntermediateDirectories: true)
        try? VaultIDs.fileText.write(to: url, atomically: true, encoding: .utf8)
    }

    /// This vault's name (its folder's) and its lasting identity. `creating` writes a new
    /// identity when the vault has none yet. Nil when there is none and none may be made, or
    /// when the file is still in iCloud: a second identity must never be made beside it.
    ///
    /// **Build 316: two identities become one.** When two devices each made one before iCloud
    /// had brought the file across, the vault keeps the older (`VaultIDs.winner`). With
    /// `creating`, every identity seen is noted in `.ams-para/vault-ids` — the one in
    /// `vault-id.txt`, and the ones in versions of that file iCloud set aside — and
    /// `vault-id.txt` is rewritten when it holds a younger one. Without `creating` nothing is
    /// written, and the answer is the same.
    func identity(creating: Bool = false) -> VaultIdentity? {
        let fm = FileManager.default
        let name = rootURL.lastPathComponent
        let file = identityFile()
        if case .unknown = file { return nil }
        guard creating else {
            return knownIdentities().current.map { VaultIdentity(id: $0, name: name) }
        }
        if case .id(let id) = file {
            noteIdentity(id, created: VaultIDs.unrecordedCreated)
            guard VaultIDs.isWellFormed(id) else { return VaultIdentity(id: id, name: name) }
            // The other device's identity, when iCloud kept its file as a set-aside version.
            // Read only; the version itself is left as it is.
            for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: identityURL) ?? []
            where version.hasLocalContents {
                if let text = try? String(contentsOf: version.url, encoding: .utf8) {
                    noteIdentity(text.trimmingCharacters(in: .whitespacesAndNewlines), created: VaultIDs.unrecordedCreated)
                }
            }
        }
        if let winner = knownIdentities().current {
            if case .id(let id) = file, id == winner { return VaultIdentity(id: winner, name: name) }
            // No file, or a younger identity in it: the older one is written. A failed write
            // changes nothing about the answer; the next copy tries again.
            try? fm.createDirectory(at: stateFolderURL, withIntermediateDirectories: true)
            try? winner.write(to: identityURL, atomically: true, encoding: .utf8)
            return VaultIdentity(id: winner, name: name)
        }
        let id = UUID().uuidString
        do {
            try fm.createDirectory(at: stateFolderURL, withIntermediateDirectories: true)
            try id.write(to: identityURL, atomically: true, encoding: .utf8)
        } catch { return nil }
        noteIdentity(id, created: Date())
        return VaultIdentity(id: id, name: name)
    }

    /// The outside copies in `place` that may be put back into **this** vault, newest first:
    /// the ones marked as made of it, and the ones with no mark at all (made before build 315),
    /// which come with their top folders' names so he can tell what they are. A copy marked
    /// as another vault's is never offered.
    func outsideCopiesForRestore(in place: URL) -> [OutsideCopy] {
        let fm = FileManager.default
        let own = knownIdentities().all
        return outsideCopies(in: place).compactMap { backup -> OutsideCopy? in
            let folder = outsideCopyURL(backup, in: place)
            let mark = folder.appendingPathComponent(Self.ownerFileName)
            if fm.fileExists(atPath: mark.path) || fm.fileExists(atPath: CloudFiles.placeholderURL(for: mark).path) {
                // Marked: offered only when the mark can be read and names this vault.
                // Build 316: an older identity of this vault counts as well.
                guard CloudFiles.presence(of: mark) != .away,
                      let data = try? Data(contentsOf: mark),
                      let owner = try? JSONDecoder().decode(VaultIdentity.self, from: data),
                      own.contains(owner.id) else { return nil }
                return OutsideCopy(backup: backup, unmarkedFolders: nil)
            }
            let folders = ((try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                                        options: [.skipsHiddenFiles])) ?? [])
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .map(\.lastPathComponent)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            return OutsideCopy(backup: backup, unmarkedFolders: folders)
        }
    }

    /// One copy, inside the vault (`place` nil: notes and settings) or outside it (`place`
    /// given: pictures and sketches as well).
    ///
    /// **Build 316: an outside copy goes into the vault's own sub-folder** of "PARAGON
    /// Backups", so two vaults that share one folder keep their copies apart. A vault with no
    /// identity that can be used (it cannot be read or written just now) still gets its copy:
    /// in the old place, with no mark, and nothing is cleared out that time.
    private func makeCopy(outsideIn place: URL?, reason: String, prune: Bool, now: Date) throws -> VaultBackup? {
        let fm = FileManager.default
        let withPictures = place != nil
        // Before the signature is taken: a vault given its identity here must not look changed
        // to the next copy because of it.
        let owner = withPictures ? identity(creating: true) : nil
        var subfolder: String?
        var home = backupsURL
        if let place {
            home = Self.outsideBackupsURL(in: place)
            if let owner, VaultIDs.isWellFormed(owner.id) {
                let name = outsideSubfolders(in: place, of: [owner.id]).first ?? Self.outsideSubfolderName(for: owner)
                subfolder = name
                home.appendPathComponent(name, isDirectory: true)
            }
        }
        let signature = try contentSignature(withPictures: withPictures)
        // The newest copy that is surely of this vault, wherever it is: in the sub-folder, or
        // in the old place with this vault's mark.
        let last: (backup: VaultBackup, url: URL)?
        if let place {
            let own = owner != nil ? ownMarkedOutsideCopies(in: place) : copies(in: home, subfolder: nil)
            last = own.first.map { ($0, outsideCopyURL($0, in: place)) }
        } else {
            last = backups().first.map { ($0, home.appendingPathComponent($0.folderName, isDirectory: true)) }
        }
        if let last,
           let lastSignature = try? String(contentsOf: last.url.appendingPathComponent("signature.txt"), encoding: .utf8),
           lastSignature == signature {
            return nil
        }
        // The last copy's folder, to take unchanged pictures from (outside copies only).
        let previous = withPictures ? last?.url : nil

        var name = "\(VaultBackup.formatter.string(from: now))~\(reason)"
        var target = home.appendingPathComponent(name, isDirectory: true)
        var n = 2
        while fm.fileExists(atPath: target.path) {
            name = "\(VaultBackup.formatter.string(from: now)) \(n)~\(reason)"
            target = home.appendingPathComponent(name, isDirectory: true)
            n += 1
        }
        try fm.createDirectory(at: target, withIntermediateDirectories: true)

        var copied = 0
        var skipped: [String] = []
        let wanted = try backedUpPaths(withPictures: withPictures)
        for relativePath in wanted {
            let source = url(for: relativePath)
            // A picture the last outside copy already holds unchanged (same size, same date) is
            // taken from there: no wait for iCloud, and no second helping of disk room.
            if let previous, Self.isPicture(relativePath),
               Self.sameFile(source, previous.appendingPathComponent(relativePath)) {
                let destination = target.appendingPathComponent(relativePath)
                try? fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if (try? fm.copyItem(at: previous.appendingPathComponent(relativePath), to: destination)) != nil { continue }
            }
            // Never waits for iCloud (build 261): copying a file whose contents are not on this
            // device would wait until they came, on the main thread. It is left out and named in
            // skipped.txt; the signature marks it, so the next backup runs once it has arrived.
            if CloudFiles.presence(of: source) == .away {
                skipped.append(relativePath)
                continue
            }
            let destination = target.appendingPathComponent(relativePath)
            do {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: destination)
                try fm.copyItem(at: source, to: destination)
            } catch {
                // A file that has just been deleted, or that this device cannot read, must not
                // cost every other note its backup.
                skipped.append(relativePath)
                continue
            }
            if relativePath.lowercased().hasSuffix(".md") { copied += 1 }
        }
        // A backup of nothing is not a backup; better to fail loudly than to leave an empty
        // folder looking like a safe copy.
        if copied == 0, wanted.contains(where: { $0.lowercased().hasSuffix(".md") }) {
            try? fm.removeItem(at: target)
            throw VaultError.backupFailed(skipped.count)
        }
        try signature.write(to: target.appendingPathComponent("signature.txt"), atomically: true, encoding: .utf8)
        if let owner, let data = try? JSONEncoder().encode(owner) {
            // Which vault this outside copy is of (round 8): a place can hold the copies of
            // more than one vault, and only this vault's are offered for a restore.
            try? data.write(to: target.appendingPathComponent(Self.ownerFileName), options: .atomic)
        }
        if !skipped.isEmpty {
            // Written beside the notes so it is plain, later, what this copy does not hold.
            try? skipped.joined(separator: "\n").write(to: target.appendingPathComponent("skipped.txt"),
                                                       atomically: true, encoding: .utf8)
        }

        if prune {
            if let place {
                // Only with an identity: without one there is no telling whose the copies are.
                if owner != nil { pruneOutsideCopies(in: place, now: now, protecting: [name]) }
            } else {
                pruneBackups(now: now)
            }
        }
        return VaultBackup(folderName: name, date: now, noteCount: copied, reason: reason, subfolder: subfolder)
    }

    /// Puts the notes from a backup back into the vault, after saving the current state as a
    /// backup of its own. Notes created since the backup are left where they are.
    @discardableResult
    func restore(_ backup: VaultBackup, now: Date = Date()) throws -> RestoreResult {
        try restore(backup, outsideIn: nil, now: now)
    }

    /// Puts an **outside copy** back into the vault (build 315): its notes, settings, pictures
    /// and sketches. Two fresh copies of what is in the vault now are made first, and without
    /// them nothing is restored: one inside the vault ("before restore", so it is in the list
    /// in Settings) and one outside, beside the copy being restored, because only an outside
    /// copy holds the pictures. Nothing is deleted: files made since the copy stay where they
    /// are, and neither the copy restored from nor the two fresh ones are cleared out.
    @discardableResult
    func restoreOutsideCopy(_ backup: VaultBackup, in place: URL, now: Date = Date()) throws -> RestoreResult {
        try restore(backup, outsideIn: place, now: now)
    }

    /// One restore, from the vault's own Backups folder (`folder` nil) or from a folder of
    /// outside copies.
    private func restore(_ backup: VaultBackup, outsideIn place: URL?, now: Date) throws -> RestoreResult {
        let fm = FileManager.default
        let source = place.map { outsideCopyURL(backup, in: $0) }
            ?? backupsURL.appendingPathComponent(backup.folderName, isDirectory: true)
        guard fm.fileExists(atPath: source.path) else { throw VaultError.noteNotFound(backup.folderName) }
        // Not cleared out here: with a full list, making room would delete the very copy being
        // restored before a single file was read from it (build 307, hardening-02).
        try makeBackup(reason: "before restore", prune: false, now: now)
        // An inside copy being restored is kept whatever its age; the outside copies are not
        // cleared out here at all (the next daily copy does that, by the same tiers).
        defer { pruneBackups(now: now, protecting: place == nil ? [backup.folderName] : []) }
        if let place {
            // The pictures are only in an outside copy, so the way back needs one too. Nil
            // means the newest outside copy already is the vault as it stands.
            _ = try makeCopy(outsideIn: place, reason: "before restore", prune: false, now: now)
        }

        var written = 0
        var notes = 0
        var failed: [String] = []
        let sourceComponents = source.standardizedFileURL.pathComponents
        guard let walker = fm.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return RestoreResult(written: 0, failed: [])
        }
        for case let fileURL as URL in walker {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            // From path components, so a symlinked or oddly spelled path cannot turn into a
            // relative path that escapes the vault.
            let components = fileURL.standardizedFileURL.pathComponents
            guard components.count > sourceComponents.count,
                  Array(components.prefix(sourceComponents.count)) == sourceComponents else { continue }
            let relative = components.dropFirst(sourceComponents.count).joined(separator: "/")
            guard relative != "signature.txt", relative != "skipped.txt", relative != Self.ownerFileName,
                  !relative.isEmpty else { continue }
            // What is left of a restore that was cut off: never a file of the vault.
            guard !fileURL.lastPathComponent.hasPrefix(Self.restoreTempPrefix) else { continue }
            // A file of the backup that is itself only an iCloud stub here — a backup made on the
            // other device — cannot be restored from this one; copied, it would put a stub into
            // the vault (build 261).
            if let real = CloudFiles.realName(ofPlaceholder: fileURL.lastPathComponent) {
                let folder = (relative as NSString).deletingLastPathComponent
                failed.append(folder.isEmpty ? real : "\(folder)/\(real)")
                continue
            }
            // A file of the copy whose contents are not on this device (the copy is in iCloud
            // or Dropbox and was not brought down, or the Mac is offline) cannot be read here:
            // it counts as not written, before anything in the vault is touched (round 8).
            if CloudFiles.presence(of: fileURL) == .away || CloudFiles.isDataless(fileURL) {
                failed.append(relative)
                continue
            }
            let destination = url(for: relative)
            // Never written over: a vault file whose contents are not on this device. The
            // before-restore backup leaves such a file out (it never waits for iCloud), so its
            // current version would be lost with no copy anywhere; and writing beside a stub
            // would leave iCloud two versions to choose between (build 261's review).
            if CloudFiles.presence(of: destination) == .away
                || fm.fileExists(atPath: CloudFiles.placeholderURL(for: destination).path) {
                failed.append(relative)
                continue
            }
            // A picture the vault already holds exactly as the copy does is left as it is
            // (outside copies; build 315): nothing to put back, and no second write of it.
            if place != nil, Self.isPicture(relative), Self.sameFile(fileURL, destination) { continue }
            // Never taken out first (review round 8): the copy is written beside the vault file
            // under another name, and only a finished copy takes the file's place. A copy that
            // fails — the disk is full, the source went away — leaves the vault file as it was.
            if Self.putBack(fileURL, over: destination) {
                written += 1
                if relative.lowercased().hasSuffix(".md") { notes += 1 }
            } else {
                // Half a restore is worse than a reported one: keep going and name the rest.
                failed.append(relative)
            }
        }
        reloadConfig()
        return RestoreResult(written: written, failed: failed, notes: notes)
    }

    /// The start of the name a file carries while a restore writes it beside its place.
    static let restoreTempPrefix = ".paragon-restore-"

    /// Writes `source` to `destination` without ever leaving the place empty: copied beside it
    /// under another name first, then moved into place in one step (`replaceItemAt`). False
    /// when the copy could not be made; the file at `destination` is then exactly as it was.
    static func putBack(_ source: URL, over destination: URL) -> Bool {
        let fm = FileManager.default
        let folder = destination.deletingLastPathComponent()
        let temporary = folder.appendingPathComponent("\(restoreTempPrefix)\(UUID().uuidString).tmp")
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: temporary)
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fm.moveItem(at: temporary, to: destination)
            }
            return true
        } catch {
            try? fm.removeItem(at: temporary)
            return false
        }
    }

    /// Clears out the copies `VaultBackup.toRemove` no longer wants. `protecting` names folders
    /// that stay whatever their age (the copy just restored from).
    func pruneBackups(in folder: URL? = nil, now: Date = Date(), protecting: Set<String> = []) {
        let home = folder ?? backupsURL
        for old in VaultBackup.toRemove(from: backups(in: folder), now: now, protecting: protecting) {
            try? FileManager.default.removeItem(at: home.appendingPathComponent(old.folderName))
        }
    }

    /// Pictures and sketches: what an outside copy holds on top of the notes. Build 318: PDFs
    /// too (the `Attachments` folder), kept the same way.
    static let pictureExtensions: Set<String> = Pictures.extensions.union(["drawing", "pdf"])

    static func isPicture(_ relativePath: String) -> Bool {
        pictureExtensions.contains((relativePath as NSString).pathExtension.lowercased())
    }

    /// Same size and same modification date: the copy already holds this file as it is now.
    private static func sameFile(_ a: URL, _ b: URL) -> Bool {
        guard let va = try? a.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let vb = try? b.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let da = va.contentModificationDate, let db = vb.contentModificationDate,
              let sa = va.fileSize, let sb = vb.fileSize else { return false }
        return sa == sb && abs(da.timeIntervalSince(db)) < 1
    }

    /// Copies the vault into an empty folder elsewhere, for the sync preview.
    func copyContents(to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for relativePath in try backedUpPaths() {
            let source = url(for: relativePath)
            // A rehearsal never waits for iCloud (build 261). A **note** not on this device would
            // make it rehearse part of the vault, so it refuses; any other file (an old deleted
            // note, the other device's sync state) is left out, as a backup leaves it out.
            if CloudFiles.presence(of: source) == .away {
                if relativePath.lowercased().hasSuffix(".md"), kind(forRelativePath: relativePath) != nil {
                    throw VaultError.notDownloadedYet(relativePath)
                }
                continue
            }
            let target = destination.appendingPathComponent(relativePath)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: target)
            try fm.copyItem(at: source, to: target)
        }
    }

    /// Every file worth copying: the notes, the config and the sync state. Backups are skipped.
    /// `withPictures` adds the pictures and sketches (outside copies).
    private func backedUpPaths(withPictures: Bool = false) throws -> [String] {
        let fm = FileManager.default
        var paths: [String] = []
        guard let walker = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants]) else { return [] }
        for case let fileURL as URL in walker {
            let standardized = fileURL.standardizedFileURL.path
            if standardized.hasPrefix(backupsURL.standardizedFileURL.path) {
                walker.skipDescendants()
                continue
            }
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let relative = relativePath(for: fileURL) else { continue }
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "md" || ext == "json" || ext == "txt"
                    || (withPictures && Self.pictureExtensions.contains(ext)) else { continue }
            paths.append(relative)
        }
        return paths.sorted()
    }

    /// Path and modification date of everything that would be backed up, so an unchanged
    /// vault is not copied twice.
    /// A file whose contents are not on this device is marked (build 261): it is left out of the
    /// backup, and bringing it down leaves its date alone (build 102), so without the mark the
    /// next backup would match this one and never be made.
    private func contentSignature(withPictures: Bool = false) throws -> String {
        try backedUpPaths(withPictures: withPictures).map { path in
            let source = url(for: path)
            let values = try? source.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let stamp = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            let size = values?.fileSize ?? 0
            let away = CloudFiles.presence(of: source) == .away ? "@away" : ""
            return "\(path)@\(stamp)@\(size)\(away)"
        }.joined(separator: "\n")
    }
}
