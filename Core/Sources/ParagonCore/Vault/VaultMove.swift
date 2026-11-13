import Foundation
import CryptoKit

// MARK: - The list of every file

/// One file as a move saw it: where it is, how big, and the SHA-256 fingerprint of its bytes.
public struct MoveFile: Codable, Equatable, Sendable {
    public var path: String
    public var size: Int
    public var hash: String

    public init(path: String, size: Int, hash: String) {
        self.path = path
        self.size = size
        self.hash = hash
    }
}

/// Every file in a vault folder (build 319): what a move copies, what it checks the copy
/// against, and what the other devices wait for. The move's own marker files, the files a move
/// set aside and Finder's `.DS_Store` are never in it.
public struct MoveManifest: Codable, Equatable, Sendable {
    /// Sorted by path.
    public var files: [MoveFile]
    public var folders: [String]

    public init(files: [MoveFile] = [], folders: [String] = []) {
        self.files = files.sorted { $0.path < $1.path }
        self.folders = folders.sorted()
    }

    public var fileCount: Int { files.count }
    public var byteCount: Int { files.reduce(0) { $0 + $1.size } }
    /// Markdown files outside the hidden state folder.
    public var noteCount: Int { files.filter { VaultMove.isNote($0.path) }.count }
    public var hashes: [String: String] { Dictionary(files.map { ($0.path, $0.hash) }, uniquingKeysWith: { a, _ in a }) }

    /// One fingerprint of the whole list: path, size and fingerprint of every file.
    public var digest: String {
        VaultMove.fingerprint(Data(files.map { "\($0.path)\t\($0.size)\t\($0.hash)\n" }.joined().utf8))
    }

    /// The paths that are not the same in both lists: missing on either side, or other bytes.
    public func differences(from other: MoveManifest) -> [String] {
        let mine = hashes, theirs = other.hashes
        return Set(mine.keys).union(theirs.keys).filter { mine[$0] != theirs[$0] }.sorted()
    }
}

// MARK: - The markers

/// What every marker of a move says (build 319). The same stamp is written three times: as
/// "being filled" and as "complete" in the folder the notes go to, and as "moved" in the folder
/// they leave.
public struct MoveStamp: Codable, Equatable, Sendable {
    public var format = 1
    /// This move's own id.
    public var moveID: String
    /// 1 for a vault's first move, 2 for the next (a move back), and so on. **The marker with
    /// the highest number says what a folder is.**
    public var generation: Int
    public var vaultID: String
    public var at: Date
    public var deviceName: String
    public var deviceID: String
    /// True when the notes go into PARAGON's own iCloud folder; false for a move back out.
    public var toOwnFolder: Bool
    /// Where the notes go, in plain words: "iCloud Drive › PARAGON", or the old folder's name.
    public var placeName: String
    public var build: Int
    // The complete marker only:
    public var fileCount: Int?
    public var byteCount: Int?
    public var noteCount: Int?
    public var manifestDigest: String?

    public init(moveID: String, generation: Int, vaultID: String, at: Date, deviceName: String,
                deviceID: String, toOwnFolder: Bool, placeName: String, build: Int) {
        self.moveID = moveID
        self.generation = generation
        self.vaultID = vaultID
        self.at = at
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.toOwnFolder = toOwnFolder
        self.placeName = placeName
        self.build = build
    }
}

/// What a folder is, going by the move markers in it.
public enum FolderStanding: Equatable, Sendable {
    /// No marker: a folder no move has touched. His folder today.
    case plain
    /// The vault lives here: a move finished here and nothing newer says otherwise.
    case vault(MoveStamp)
    /// A copy was started here and is not finished. **Never opened as a vault.**
    case halfMade(MoveStamp)
    /// The notes left this folder; the stamp says where they went.
    case movedAway(MoveStamp)
    /// A marker is here that cannot be read yet (still in iCloud). Wait; decide nothing.
    case unclear
}

public enum UploadState: Equatable, Sendable {
    case sent
    case waiting
    /// iCloud has no room for this file.
    case full
    case failed(String)
}

public struct MoveProgress: Equatable, Sendable {
    public enum Step: String, Sendable { case reading, copying, checking, sending, finishing }
    public var step: Step
    public var done: Int
    public var total: Int

    public init(step: Step, done: Int, total: Int) {
        self.step = step
        self.done = done
        self.total = total
    }

    /// "Copying 87 of 412 files…"
    public var words: String {
        switch step {
        case .reading: return done == 0 ? "Reading your notes…" : "Reading your notes: \(done) file\(done == 1 ? "" : "s")…"
        case .copying: return "Copying \(done) of \(total) files…"
        case .checking: return "Comparing copies and originals: \(done) of \(total) files…"
        case .sending: return "Sending to iCloud: \(done) of \(total) files…"
        case .finishing: return "Finishing…"
        }
    }
}

public enum MoveError: Error, LocalizedError, Equatable {
    case cancelled
    case cannotRead(String)
    /// Files whose contents are not on this device and did not come in time.
    case notHere([String])
    /// Things a move does not know how to copy (a link to somewhere else, a device file).
    case unsupported([String])
    case destinationHoldsOtherThings(Int)
    case destinationUnclear
    case notEnoughRoom(needed: Int, free: Int)
    case copyFailed(String, String)
    case keptChanging([String])
    case cloudFull
    case uploadFailed(String, String)
    case uploadSlow(Int)
    case markerFailed(String)
    case noList
    /// The place the notes should go to is a vault in use: another device moved them already.
    case alreadyMoved(String)
    /// Another device is making the same move right now.
    case otherDeviceMoving(String)

    public static func megabytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_000_000
        return mb < 10 ? String(format: "%.1f MB", max(mb, 0.1)) : "\(Int(mb.rounded())) MB"
    }

    private static func some(_ paths: [String]) -> String {
        let names = paths.prefix(5).map { "\u{201C}\($0)\u{201D}" }.joined(separator: ", ")
        return paths.count > 5 ? "\(names) and \(paths.count - 5) more" : names
    }

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The move was stopped. Your notes are where they were."
        case .cannotRead(let name):
            return "PARAGON could not read the folder \u{201C}\(name)\u{201D}."
        case .notHere(let paths):
            return "\(paths.count) file\(paths.count == 1 ? " is" : "s are") still in iCloud and not on this device: \(Self.some(paths)). Wait until iCloud has brought everything, then try again."
        case .unsupported(let paths):
            return "The folder holds something PARAGON cannot copy safely: \(Self.some(paths)). Nothing was moved."
        case .destinationHoldsOtherThings(let count):
            return "The new place already holds \(count) file\(count == 1 ? "" : "s") that PARAGON did not put there. Look at the folder first; nothing was moved."
        case .destinationUnclear:
            return "iCloud has not finished listing the new place. Try again in a minute."
        case .notEnoughRoom(let needed, let free):
            return "Not enough room on this device: the copy needs \(Self.megabytes(needed)) and \(Self.megabytes(free)) are free. Nothing was moved."
        case .copyFailed(let path, let why):
            return "\u{201C}\(path)\u{201D} could not be copied: \(why) Nothing has changed: your notes are where they were."
        case .keptChanging(let paths):
            return "The copy could not be checked because these files kept changing: \(Self.some(paths)). Nothing has changed. Try again when the other devices are quiet."
        case .cloudFull:
            return "iCloud is full, so the copy could not be sent to your other devices. Nothing has changed: your notes are where they were. Free some room in iCloud, then try again."
        case .uploadFailed(let path, let why):
            return "iCloud would not take \u{201C}\(path)\u{201D}: \(why) Nothing has changed: your notes are where they were."
        case .uploadSlow(let left):
            return "iCloud has not taken \(left) file\(left == 1 ? "" : "s") yet (no connection, or iCloud is busy). Nothing has changed: your notes are where they were. Try again later; the copy made so far is kept and not made twice."
        case .markerFailed(let why):
            return "The move could not be finished: \(why) Nothing has changed: your notes are where they were."
        case .noList:
            return "The list of files made at the move is not on this device yet."
        case .alreadyMoved(let name):
            return "Your notes are already in that place: \(name) moved them. Nothing was changed. PARAGON will soon show \u{201C}Your notes have moved\u{201D} on this device."
        case .otherDeviceMoving(let name):
            return "\(name) is moving your notes too. Two devices must not move them at the same time, so this move stopped. Nothing has changed: your notes are where they were. Let that device finish, or try again tomorrow."
        }
    }
}

/// What a move is asked to do.
public struct MoveRequest: Sendable {
    public var source: URL
    public var destination: URL
    public var vaultID: String
    /// Every id this vault has had (`Vault.knownIdentities().all`).
    public var knownVaultIDs: Set<String>
    public var deviceName: String
    public var deviceID: String
    public var toOwnFolder: Bool
    public var placeName: String
    public var build: Int

    public init(source: URL, destination: URL, vaultID: String, knownVaultIDs: Set<String>, deviceName: String,
                deviceID: String, toOwnFolder: Bool, placeName: String, build: Int) {
        self.source = source
        self.destination = destination
        self.vaultID = vaultID
        self.knownVaultIDs = knownVaultIDs.union([vaultID])
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.toOwnFolder = toOwnFolder
        self.placeName = placeName
        self.build = build
    }
}

/// What the app (or a test) gives a move: where progress goes, how to stop it, and the two
/// things only a real device knows — free room and what iCloud has taken.
public struct MoveHooks {
    public var progress: (MoveProgress) -> Void = { _ in }
    public var cancelled: () -> Bool = { false }
    public var now: () -> Date = { Date() }
    public var freeBytes: (URL) -> Int? = VaultMove.freeBytes
    public var uploadState: (URL) -> UploadState = VaultMove.uploadState
    public var pause: (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    /// How long to wait for iCloud to take the copy before giving up (nothing changed then).
    public var uploadPatience: TimeInterval = 20 * 60
    /// How long one file may take to come down from iCloud.
    public var readWait: TimeInterval = CloudFiles.longestWait

    public init() {}
}

public struct MoveOutcome: Equatable, Sendable {
    public var stamp: MoveStamp
    public var manifest: MoveManifest
    public var copied: Int
    public var alreadyThere: Int
    public var setAside: Int
}

/// What a look at a folder the notes were moved to found (build 319). A device opens it as the
/// vault only when `isComplete`.
public struct PlaceLook: Equatable, Sendable {
    public var standing: FolderStanding = .plain
    /// The list of files made at the move is here and is the one the complete marker names.
    public var listHere = false
    /// Files the list names, leaving out in-vault backups and deleted notes.
    public var expected = 0
    public var here = 0
    /// Named in the list, known to iCloud, contents not on this device yet.
    public var arriving: [String] = []
    /// Named in the list and not here at all: not listed yet, or deleted or renamed since.
    public var missing: [String] = []

    public init() {}

    public var stamp: MoveStamp? {
        if case .vault(let stamp) = standing { return stamp }
        return nil
    }

    /// Complete marker, its list, and every file of the list here and downloaded.
    public var isComplete: Bool { stamp != nil && listHere && arriving.isEmpty && missing.isEmpty }
    /// Everything iCloud knows of has arrived, but some listed files are not there. Only after
    /// several looks agree may the app ask him whether they were deleted or renamed since.
    public var isAllButMissing: Bool { stamp != nil && listHere && arriving.isEmpty && !missing.isEmpty }
    /// Review of build 319: "deleted or renamed since" is only believed of a few files. With
    /// more than a tenth of the list not there, iCloud has not finished listing the folder —
    /// opened like that, the notes that are still to come would look deleted to the Reminders sync.
    public var mayOpenDespiteMissing: Bool { isAllButMissing && missing.count * 10 <= expected }
}

/// What changed in the folder the notes left, since a list was made.
public struct OldFolderChanges: Equatable, Sendable {
    public var added: [String] = []
    public var changed: [String] = []
    public var deleted: [String] = []

    public init(added: [String] = [], changed: [String] = [], deleted: [String] = []) {
        self.added = added
        self.changed = changed
        self.deleted = deleted
    }

    /// His own files (notes, pictures) that are new or changed: what he is asked about.
    public var notes: [String] { (added + changed).filter { !$0.hasPrefix(Vault.stateFolderName + "/") }.sorted() }
    public var isEmpty: Bool { added.isEmpty && changed.isEmpty && deleted.isEmpty }
}

/// What bringing changes over did, file by file.
public struct BroughtOver: Equatable, Sendable {
    /// New in the old folder, not in the new: copied.
    public var copied: [String] = []
    /// Changed in the old folder, untouched in the new: the new one now holds the change.
    public var replaced: [String] = []
    /// Changed in both: the old folder's version was written beside the note under this name.
    public var keptBoth: [String] = []
    /// Deleted in the old folder after the move. Still in the new folder; nothing was deleted.
    public var deletedInOld: [String] = []
    /// PARAGON's own state files changed in both places: the new folder's stays.
    public var leftAlone: [String] = []
    public var failed: [String] = []

    public init() {}

    public var changedSomething: Bool { !copied.isEmpty || !replaced.isEmpty || !keptBoth.isEmpty }

    private static func files(_ n: Int) -> String { "\(n) file\(n == 1 ? "" : "s")" }

    /// One plain sentence per thing that happened.
    public var lines: [String] {
        var lines: [String] = []
        if !copied.isEmpty { lines.append("\(Self.files(copied.count)) new in the old folder: copied.") }
        if !replaced.isEmpty { lines.append("\(Self.files(replaced.count)) changed in the old folder: brought over.") }
        if !keptBoth.isEmpty { lines.append("\(Self.files(keptBoth.count)) changed in both places: both versions kept, the old folder\u{2019}s with \u{201C}(conflict \u{2026})\u{201D} in its name.") }
        if !deletedInOld.isEmpty { lines.append("\(Self.files(deletedInOld.count)) deleted in the old folder: still here, nothing was deleted.") }
        if !failed.isEmpty { lines.append("\(Self.files(failed.count)) could not be brought over. \(failed.count == 1 ? "It is" : "They are") still in the old folder: \(failed.prefix(5).joined(separator: ", ")).") }
        return lines
    }
}

// MARK: - The move

/// **Moving a vault from one folder to another so that nothing can be lost** (build 319).
///
/// The rules, all of them tested on temporary folders:
/// - It is a copy. The folder the notes leave is never changed, except for one small text file
///   written at the very end.
/// - Every file is copied — the hidden state folder with the Reminders memory, the ids, the
///   settings, the in-vault backups and the deleted notes included — and then both folders are
///   listed again and must agree: same files, same sizes, same SHA-256 fingerprints.
/// - Three markers say what a folder is (`FolderStanding`); a half-made copy is recognisable
///   and is never a vault.
/// - Stopped at any point, it can be run again: files already copied and equal are kept.
/// - A file in the destination that the move replaces or that is not in the vault is set aside
///   in `.ams-para/Set aside by a move`, never deleted.
public enum VaultMove {
    /// The app's iCloud container. Its `Documents` folder is what Files and Finder show as
    /// "PARAGON" in iCloud Drive.
    public static let containerID = "iCloud.com.schabbauer.AMSPara"
    public static let ownFolderWords = "iCloud Drive \u{203A} PARAGON"
    /// The first build that knows about moved vaults.
    public static let firstBuild = 319

    /// Inside `.ams-para`: the markers and the list.
    public static let folderName = "move"
    public static let arrivingName = "arriving.json"
    public static let completeName = "complete.json"
    public static let manifestName = "manifest.json"
    public static let setAsideFolderName = "Set aside by a move"
    /// In the folder the notes left, where he can see it.
    public static let movedFileName = "PARAGON has moved these notes.txt"
    private static let movedFileStem = "PARAGON has moved these notes"

    static let statePrefix = Vault.stateFolderName + "/"
    static let backupsPrefix = Vault.stateFolderName + "/Backups/"
    static let deletedPrefix = Vault.stateFolderName + "/Deleted/"

    public static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func isNote(_ path: String) -> Bool {
        path.lowercased().hasSuffix(".md") && !path.hasPrefix(statePrefix)
    }

    /// Files that belong to a move itself or to Finder, never to the vault.
    public static func isMoveOwn(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        if name == ".DS_Store" || name.hasPrefix("._") || name == "Icon\r" { return true }
        if path == statePrefix + folderName || path.hasPrefix(statePrefix + folderName + "/") { return true }
        if path == statePrefix + setAsideFolderName || path.hasPrefix(statePrefix + setAsideFolderName + "/") { return true }
        if !path.contains("/") {
            let real = CloudFiles.realName(ofPlaceholder: name) ?? name
            if real.hasPrefix(movedFileStem), real.hasSuffix(".txt") { return true }
        }
        return false
    }

    static func moveFolder(in root: URL) -> URL {
        root.appendingPathComponent(Vault.stateFolderName, isDirectory: true).appendingPathComponent(folderName, isDirectory: true)
    }

    static func base(_ url: URL) -> URL { url.standardizedFileURL.resolvingSymlinksInPath() }

    // MARK: Listing a folder

    /// Lists every file under `root` with its size and fingerprint. A file whose contents are
    /// not on this device is waited for (`wait` seconds each); what still is not here makes the
    /// whole listing fail with `MoveError.notHere` — a list with holes is never returned.
    /// **Blocks the calling thread; never called on the main one.**
    public static func manifest(of root: URL, waitingUpTo wait: TimeInterval = CloudFiles.longestWait,
                                skippingBackups: Bool = false,
                                presence: (URL) -> CloudFiles.Presence = VaultMove.freshPresence,
                                progress: ((Int) -> Void)? = nil,
                                cancelled: () -> Bool = { false }) throws -> MoveManifest {
        let fm = FileManager.default
        let root = base(root)
        guard let walker = fm.enumerator(atPath: root.path) else { throw MoveError.cannotRead(root.lastPathComponent) }
        var files: [MoveFile] = []
        var folders: [String] = []
        var notHere: [String] = []
        var strange: [String] = []
        while let raw = walker.nextObject() as? String {
            let path = raw.precomposedStringWithCanonicalMapping
            let type = walker.fileAttributes?[.type] as? FileAttributeType
            if isMoveOwn(path) || (skippingBackups && (path + "/").hasPrefix(backupsPrefix)) {
                if type == .typeDirectory { walker.skipDescendants() }
                continue
            }
            if type == .typeDirectory {
                folders.append(path)
                continue
            }
            let name = (path as NSString).lastPathComponent
            if let real = CloudFiles.realName(ofPlaceholder: name) {
                let folder = (path as NSString).deletingLastPathComponent
                let realPath = folder.isEmpty ? real : "\(folder)/\(real)"
                CloudFiles.startDownload(root.appendingPathComponent(realPath))
                notHere.append(realPath)
                continue
            }
            guard type == .typeRegular else {
                strange.append(path)
                continue
            }
            if cancelled() { throw MoveError.cancelled }
            guard let data = try? currentData(root.appendingPathComponent(raw), waitingUpTo: wait, presence: presence) else {
                notHere.append(path)
                continue
            }
            files.append(MoveFile(path: path, size: data.count, hash: fingerprint(data)))
            progress?(files.count)
        }
        if !strange.isEmpty { throw MoveError.unsupported(strange.sorted()) }
        if !notHere.isEmpty { throw MoveError.notHere(notHere.sorted()) }
        return MoveManifest(files: files, folders: folders)
    }

    /// iCloud's mark for a file, asked afresh (a URL remembers the answer it got first).
    public static func freshPresence(of url: URL) -> CloudFiles.Presence {
        var fresh = URL(fileURLWithPath: url.path)
        fresh.removeAllCachedResourceValues()
        return CloudFiles.presence(of: fresh)
    }

    /// The bytes of a file **as iCloud has it now** (review of build 319). A file of which this
    /// device holds an older copy while iCloud has a newer one reads at once — as the older
    /// text. Listed like that, a device that was offline would take its old copy for a change
    /// made after the move and put it over the newer note. Such a file is asked for and waited
    /// for; if the newer copy does not come in time, the read fails and nothing is decided.
    static func currentData(_ url: URL, waitingUpTo wait: TimeInterval,
                            presence: (URL) -> CloudFiles.Presence = VaultMove.freshPresence) throws -> Data {
        if presence(url) == .stale {
            CloudFiles.startDownload(url)
            let end = Date().addingTimeInterval(wait)
            while presence(url) == .stale {
                guard Date() < end else { throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: url.path]) }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        return try CloudFiles.read(url, waitingUpTo: wait)
    }

    // MARK: Reading and writing the markers

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public static func day(_ date: Date) -> String { dayFormatter.string(from: date) }

    private enum Marker { case none, unclear, stamp(MoveStamp) }

    /// The bytes of a small file, without ever waiting for iCloud. Nil = not there; `.some(nil)`
    /// = there, but its contents are not on this device (asked for).
    private static func smallFile(_ url: URL) -> Data?? {
        let fm = FileManager.default
        if fm.fileExists(atPath: CloudFiles.placeholderURL(for: url).path) {
            CloudFiles.startDownload(url)
            return .some(nil)
        }
        guard fm.fileExists(atPath: url.path) else { return nil }
        guard let data = try? CloudFiles.read(url, waitingUpTo: 0) else { return .some(nil) }
        return data
    }

    private static func marker(at url: URL) -> Marker {
        guard let found = smallFile(url) else { return .none }
        guard let data = found, let stamp = try? decoder.decode(MoveStamp.self, from: data) else { return .unclear }
        return .stamp(stamp)
    }

    /// The words and the data of the "moved" file.
    public static func movedText(_ stamp: MoveStamp) -> String {
        let place = stamp.toOwnFolder ? "PARAGON\u{2019}s own folder (\(stamp.placeName))" : "the folder \u{201C}\(stamp.placeName)\u{201D}"
        let json = (try? encoder.encode(stamp)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        PARAGON moved these notes to \(place) on \(day(stamp.at)). The move was made on the device \u{201C}\(stamp.deviceName)\u{201D}.

        This folder is the old copy. PARAGON does not use it any more and has not changed it.
        Keep it until you are sure that everything is in the new place.
        Please leave this file here: it tells PARAGON on your other devices where the notes went.
        The lines below are for PARAGON. Please do not change them.

        \(json)

        """
    }

    static func stamp(fromMovedText text: String) -> MoveStamp? {
        guard let open = text.firstIndex(of: "{"), let close = text.lastIndex(of: "}"), open < close else { return nil }
        return try? decoder.decode(MoveStamp.self, from: Data(text[open...close].utf8))
    }

    /// The "moved" files at the top of a folder: iCloud may have kept a second one as "… 2.txt".
    private static func movedFiles(in root: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        let real = Set(names.filter { isMoveOwn($0) && $0 != ".DS_Store" }.map { CloudFiles.realName(ofPlaceholder: $0) ?? $0 })
        return real.filter { $0.hasPrefix(movedFileStem) }.sorted().map { root.appendingPathComponent($0) }
    }

    private static func movedMarker(in root: URL) -> Marker {
        var best: MoveStamp?
        var unclear = false
        for url in movedFiles(in: root) {
            guard let found = smallFile(url) else { continue }
            guard let data = found, let text = String(data: data, encoding: .utf8), let stamp = stamp(fromMovedText: text) else {
                unclear = true
                continue
            }
            if best == nil || stamp.generation > best!.generation { best = stamp }
        }
        if let best { return .stamp(best) }
        return unclear ? .unclear : .none
    }

    /// **The rule that says what a folder is.** The marker with the highest move number wins.
    /// A "being filled" marker counts only while no "complete" marker of the same or a later
    /// move is beside it. A marker that is there but cannot be read makes the answer `unclear`.
    public static func standing(of folder: URL) -> FolderStanding {
        let root = base(folder)
        let state = moveFolder(in: root)
        let arriving = marker(at: state.appendingPathComponent(arrivingName))
        let complete = marker(at: state.appendingPathComponent(completeName))
        let moved = movedMarker(in: root)
        var answer: (generation: Int, standing: FolderStanding)?
        func offer(_ generation: Int, _ standing: FolderStanding) {
            if answer == nil || generation > answer!.generation { answer = (generation, standing) }
        }
        // Order matters only for equal numbers, where the first one offered stays: a complete
        // vault is never talked down by a marker of the same move number.
        var completeStamp: MoveStamp?
        switch complete {
        case .unclear: return .unclear
        case .stamp(let stamp):
            completeStamp = stamp
            offer(stamp.generation, .vault(stamp))
        case .none: break
        }
        switch moved {
        case .unclear: return .unclear
        case .stamp(let stamp): offer(stamp.generation, .movedAway(stamp))
        case .none: break
        }
        switch arriving {
        case .unclear: return .unclear
        case .stamp(let stamp):
            if completeStamp == nil || stamp.generation > completeStamp!.generation {
                // Before a "moved" marker of the same number: a copy being made into this folder.
                if answer == nil || stamp.generation >= answer!.generation { answer = (stamp.generation, .halfMade(stamp)) }
            }
        case .none: break
        }
        return answer?.standing ?? .plain
    }

    /// The highest move number any marker in the folder carries; 0 for none.
    static func highestGeneration(in folder: URL) -> Int {
        let root = base(folder)
        let state = moveFolder(in: root)
        var highest = 0
        for marker in [marker(at: state.appendingPathComponent(arrivingName)),
                       marker(at: state.appendingPathComponent(completeName)), movedMarker(in: root)] {
            if case .stamp(let stamp) = marker { highest = max(highest, stamp.generation) }
        }
        return highest
    }

    private static func write(_ stamp: MoveStamp, named name: String, in root: URL) throws {
        let folder = moveFolder(in: root)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(stamp).write(to: folder.appendingPathComponent(name), options: .atomic)
        } catch {
            throw MoveError.markerFailed(error.localizedDescription)
        }
    }

    /// The list of files made at the move, as the complete marker names it; nil when it is not
    /// on this device yet or is another list.
    public static func list(in folder: URL, matching stamp: MoveStamp? = nil) -> MoveManifest? {
        let url = moveFolder(in: base(folder)).appendingPathComponent(manifestName)
        guard let found = smallFile(url), let data = found,
              let manifest = try? decoder.decode(MoveManifest.self, from: data) else { return nil }
        if let digest = stamp?.manifestDigest, manifest.digest != digest { return nil }
        return manifest
    }

    // MARK: The two things only a device knows

    public static func freeBytes(at url: URL) -> Int? {
        var probe = url
        while !FileManager.default.fileExists(atPath: probe.path), probe.path != "/" { probe.deleteLastPathComponent() }
        let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage.map { Int($0) }
    }

    /// Whether iCloud has taken a file. A file that is not in iCloud counts as sent.
    public static func uploadState(of url: URL) -> UploadState {
        var fresh = URL(fileURLWithPath: url.path)
        fresh.removeAllCachedResourceValues()
        guard let values = try? fresh.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey,
                                                               .ubiquitousItemUploadingErrorKey]),
              values.isUbiquitousItem == true else { return .sent }
        if values.ubiquitousItemIsUploaded == true { return .sent }
        if let error = values.ubiquitousItemUploadingError, error.code == NSUbiquitousFileNotUploadedDueToQuotaError {
            return .full
        }
        return .waiting
    }

    // MARK: Running a move

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// May the notes be copied into this folder? Yes when it is empty, or when its markers say
    /// it belongs to this same vault (a move that was stopped, or the folder the vault once
    /// left). Anything else is somebody's files and is not touched.
    ///
    /// Review of build 319: **never into a vault in use.** A device that has not yet seen that
    /// another one moved the notes would otherwise copy the old folder over the new one. And
    /// not into a copy another device started less than a day ago.
    static func checkDestination(_ destination: URL, knownVaultIDs: Set<String>, deviceID: String = "",
                                 now: Date = Date()) throws {
        let fm = FileManager.default
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        switch standing(of: destination) {
        case .unclear:
            throw MoveError.destinationUnclear
        case .vault(let stamp):
            if knownVaultIDs.contains(stamp.vaultID) { throw MoveError.alreadyMoved(stamp.deviceName) }
        case .halfMade(let stamp):
            if knownVaultIDs.contains(stamp.vaultID) {
                if stamp.deviceID != deviceID, now.timeIntervalSince(stamp.at) < 86_400 {
                    throw MoveError.otherDeviceMoving(stamp.deviceName)
                }
                return
            }
        case .movedAway(let stamp):
            if knownVaultIDs.contains(stamp.vaultID) { return }
        case .plain:
            break
        }
        guard let walker = fm.enumerator(atPath: base(destination).path) else { throw MoveError.cannotRead(destination.lastPathComponent) }
        var count = 0
        while let path = walker.nextObject() as? String {
            if isMoveOwn(path) { continue }
            if (walker.fileAttributes?[.type] as? FileAttributeType) != .typeDirectory { count += 1 }
        }
        if count > 0 { throw MoveError.destinationHoldsOtherThings(count) }
    }

    /// One file, read once: the bytes that are fingerprinted are the bytes that are written.
    /// The write goes through file coordination, as iCloud wants it, and keeps the file's dates.
    private static func copyFile(_ path: String, from source: URL, to destination: URL, wait: TimeInterval) throws {
        let fm = FileManager.default
        let from = source.appendingPathComponent(path)
        let to = destination.appendingPathComponent(path)
        do {
            let data = try currentData(from, waitingUpTo: wait)
            try fm.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
            var coordinationError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: to, options: .forReplacing, error: &coordinationError) { actual in
                do { try data.write(to: actual, options: .atomic) } catch { writeError = error }
            }
            if let error = writeError ?? coordinationError { throw error }
            if let attributes = try? fm.attributesOfItem(atPath: from.path) {
                var dates: [FileAttributeKey: Any] = [:]
                if let created = attributes[.creationDate] { dates[.creationDate] = created }
                if let modified = attributes[.modificationDate] { dates[.modificationDate] = modified }
                try? fm.setAttributes(dates, ofItemAtPath: to.path)
            }
        } catch {
            throw MoveError.copyFailed(path, error.localizedDescription)
        }
    }

    /// Moves a destination file out of the way, into the set-aside folder. Never deletes.
    private static func setAside(_ path: String, in destination: URL, stamp: String) throws {
        let fm = FileManager.default
        let target = destination.appendingPathComponent(Vault.stateFolderName, isDirectory: true)
            .appendingPathComponent(setAsideFolderName, isDirectory: true)
            .appendingPathComponent(stamp, isDirectory: true).appendingPathComponent(path)
        do {
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            // A name already taken there is never written over: the next one gets " 2", " 3".
            var free = target
            var number = 2
            while fm.fileExists(atPath: free.path) {
                free = target.deletingLastPathComponent().appendingPathComponent("\(target.lastPathComponent) \(number)")
                number += 1
            }
            try fm.moveItem(at: destination.appendingPathComponent(path), to: free)
        } catch {
            throw MoveError.copyFailed(path, error.localizedDescription)
        }
    }

    /// Copies a file of `folder` into its set-aside folder before it is replaced. The file
    /// itself stays where it is.
    private static func keepCopy(of path: String, in folder: URL, stamp: String) throws {
        let fm = FileManager.default
        let target = folder.appendingPathComponent(Vault.stateFolderName, isDirectory: true)
            .appendingPathComponent(setAsideFolderName, isDirectory: true)
            .appendingPathComponent(stamp, isDirectory: true).appendingPathComponent(path)
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        var free = target
        var number = 2
        while fm.fileExists(atPath: free.path) {
            free = target.deletingLastPathComponent().appendingPathComponent("\(target.lastPathComponent) \(number)")
            number += 1
        }
        try fm.copyItem(at: folder.appendingPathComponent(path), to: free)
    }

    /// **The whole move**: check the destination, mark it "being filled", copy, verify, wait for
    /// iCloud, then write "complete" there and "moved" in the folder the notes left. Throws at
    /// the first thing that is not right; until the complete marker is written nothing has
    /// changed for any device, and running it again continues the same copy.
    /// **Blocks the calling thread.** The app holds the Reminders sync while it runs and
    /// switches folders only when it returns.
    public static func run(_ request: MoveRequest, hooks: MoveHooks = MoveHooks()) throws -> MoveOutcome {
        let fm = FileManager.default
        let source = base(request.source)
        try checkDestination(request.destination, knownVaultIDs: request.knownVaultIDs, deviceID: request.deviceID, now: hooks.now())
        let destination = base(request.destination)
        guard source.path != destination.path, !destination.path.hasPrefix(source.path + "/"),
              !source.path.hasPrefix(destination.path + "/") else {
            throw MoveError.copyFailed(destination.lastPathComponent, "The new place is inside the old one.")
        }

        hooks.progress(MoveProgress(step: .reading, done: 0, total: 0))
        var plan = try manifest(of: source, waitingUpTo: hooks.readWait,
                                progress: { hooks.progress(MoveProgress(step: .reading, done: $0, total: 0)) },
                                cancelled: hooks.cancelled)
        var there = try manifest(of: destination, waitingUpTo: hooks.readWait, cancelled: hooks.cancelled)

        let thereHashes = there.hashes
        let needed = plan.files.filter { thereHashes[$0.path] != $0.hash }.reduce(0) { $0 + $1.size }
        if let free = hooks.freeBytes(destination), free < needed + 20_000_000 {
            throw MoveError.notEnoughRoom(needed: needed, free: free)
        }

        // The move number: one more than anything either folder has seen. A copy that was
        // stopped is continued under its own number and id.
        var generation = max(highestGeneration(in: source), highestGeneration(in: destination)) + 1
        var moveID = UUID().uuidString
        if case .halfMade(let earlier) = standing(of: destination), request.knownVaultIDs.contains(earlier.vaultID),
           earlier.deviceID == request.deviceID, earlier.toOwnFolder == request.toOwnFolder {
            generation = earlier.generation
            moveID = earlier.moveID
        }
        var stamp = MoveStamp(moveID: moveID, generation: generation, vaultID: request.vaultID, at: hooks.now(),
                              deviceName: request.deviceName, deviceID: request.deviceID,
                              toOwnFolder: request.toOwnFolder, placeName: request.placeName, build: request.build)
        try write(stamp, named: arrivingName, in: destination)

        /// Waits until iCloud has taken the given files of the destination.
        func waitUntilSent(_ paths: [String], patience: TimeInterval, showing: Bool) throws {
            var left = paths
            let total = left.count
            let started = hooks.now()
            while true {
                if hooks.cancelled() { throw MoveError.cancelled }
                var still: [String] = []
                for path in left {
                    switch hooks.uploadState(destination.appendingPathComponent(path)) {
                    case .sent: break
                    case .waiting: still.append(path)
                    case .full: throw MoveError.cloudFull
                    case .failed(let why): throw MoveError.uploadFailed(path, why)
                    }
                }
                left = still
                if showing { hooks.progress(MoveProgress(step: .sending, done: total - left.count, total: total)) }
                if left.isEmpty { break }
                if hooks.now().timeIntervalSince(started) > patience { throw MoveError.uploadSlow(left.count) }
                hooks.pause(2)
            }
        }

        // Review of build 319 — **one device at a time.** The "being filled" marker goes to
        // iCloud before a single note is copied, and then this device looks whether the marker
        // is still its own. Two devices that press "Move my notes" within the same minute both
        // write one; iCloud keeps one and parks the other, and both devices see that here (and
        // once more before the copy counts) and stop. Without this both would fill the folder,
        // and iCloud would keep every note twice ("Note 2.md").
        let arrivingPath = "\(Vault.stateFolderName)/\(folderName)/\(arrivingName)"
        try waitUntilSent([arrivingPath], patience: min(hooks.uploadPatience, 120), showing: false)
        try checkOnlyOurMove(stamp, in: destination)

        let asideStamp = stampFormatter.string(from: hooks.now())
        var copied = 0, alreadyThere = 0, aside = 0
        // Files this run wrote itself: copied again when the vault changed meanwhile, and not
        // set aside — only what was in the destination before the move is worth keeping.
        var ours: Set<String> = []
        var firstRound = true
        var pass = 0
        while true {
            pass += 1
            var verified = false
            var lastDifferences: [String] = []
            for _ in 1...3 {
                let have = there.hashes
                let wanted = Set(plan.files.map(\.path))
                // What is in the destination and not in the vault is set aside first, so a file
                // that became a folder (or the other way round) cannot be in the way.
                for extra in there.files where !wanted.contains(extra.path) {
                    if ours.contains(extra.path) {
                        // Copied a moment ago and deleted from the vault since: the copy goes too.
                        try? fm.removeItem(at: destination.appendingPathComponent(extra.path))
                        ours.remove(extra.path)
                    } else {
                        try setAside(extra.path, in: destination, stamp: asideStamp)
                        aside += 1
                    }
                }
                for folder in plan.folders {
                    try? fm.createDirectory(at: destination.appendingPathComponent(folder), withIntermediateDirectories: true)
                }
                var done = 0
                for file in plan.files {
                    if hooks.cancelled() { throw MoveError.cancelled }
                    if have[file.path] == file.hash {
                        if firstRound { alreadyThere += 1 }
                    } else {
                        if have[file.path] != nil, !ours.contains(file.path) {
                            try setAside(file.path, in: destination, stamp: asideStamp)
                            aside += 1
                        }
                        try copyFile(file.path, from: source, to: destination, wait: hooks.readWait)
                        ours.insert(file.path)
                        copied += 1
                    }
                    done += 1
                    hooks.progress(MoveProgress(step: .copying, done: done, total: plan.files.count))
                }
                firstRound = false
                // Verify: both folders listed again, from the disk, and compared.
                let total = plan.files.count * 2
                let again = try manifest(of: source, waitingUpTo: hooks.readWait,
                                         progress: { hooks.progress(MoveProgress(step: .checking, done: $0, total: total)) },
                                         cancelled: hooks.cancelled)
                let made = try manifest(of: destination, waitingUpTo: hooks.readWait,
                                        progress: { hooks.progress(MoveProgress(step: .checking, done: again.fileCount + $0, total: total)) },
                                        cancelled: hooks.cancelled)
                lastDifferences = again.differences(from: made)
                plan = again
                there = made
                if lastDifferences.isEmpty, again.fileCount == made.fileCount, again.byteCount == made.byteCount {
                    verified = true
                    break
                }
            }
            guard verified else { throw MoveError.keptChanging(lastDifferences) }

            // iCloud must have taken every file before any device is told the vault is here.
            try waitUntilSent(plan.files.map(\.path), patience: hooks.uploadPatience, showing: true)
            if hooks.cancelled() { throw MoveError.cancelled }

            // Review of build 319 — the wait for iCloud can take minutes, and the vault is in
            // use meanwhile (he types in the main window, another device's change arrives, a
            // widget tick is written). So both folders are listed **once more, last of all**:
            // the copy only counts when it equals the vault as it is at this moment. Otherwise
            // what changed is copied and sent too (three passes at most).
            let last = try manifest(of: source, waitingUpTo: hooks.readWait, cancelled: hooks.cancelled)
            let lastMade = try manifest(of: destination, waitingUpTo: hooks.readWait, cancelled: hooks.cancelled)
            let late = last.differences(from: lastMade)
            plan = last
            there = lastMade
            if late.isEmpty, last.fileCount == lastMade.fileCount, last.byteCount == lastMade.byteCount { break }
            guard pass < 3 else { throw MoveError.keptChanging(late) }
        }
        try checkOnlyOurMove(stamp, in: destination)
        if hooks.cancelled() { throw MoveError.cancelled }

        // From here on the move is done and is not stopped any more.
        hooks.progress(MoveProgress(step: .finishing, done: 0, total: 0))
        stamp.at = hooks.now()
        stamp.fileCount = plan.fileCount
        stamp.byteCount = plan.byteCount
        stamp.noteCount = plan.noteCount
        stamp.manifestDigest = plan.digest
        do {
            let folder = moveFolder(in: destination)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(plan).write(to: folder.appendingPathComponent(manifestName), options: .atomic)
        } catch {
            throw MoveError.markerFailed(error.localizedDescription)
        }
        try write(stamp, named: completeName, in: destination)
        // A "moved" file the destination carries from an earlier move away from it is no longer
        // true. It is PARAGON's own marker; the move number would overrule it anyway.
        for stale in movedFiles(in: destination) { try? fm.removeItem(at: stale) }
        // Last of all, and the only thing ever written into the folder the notes left.
        // Review of build 319: not an error any more when it cannot be written. The complete
        // marker is there, so the move HAS happened; saying "nothing has changed" now would be
        // untrue. Every device also learns of the move from the new folder itself, and the
        // device that follows writes this file then (`writeMoved`).
        try? writeMoved(stamp, in: source)
        return MoveOutcome(stamp: stamp, manifest: plan, copied: copied, alreadyThere: alreadyThere, setAside: aside)
    }

    /// Throws when the copy being made into `destination` is not this move's alone: the
    /// "being filled" marker is another move's or has gone, iCloud has parked a second one
    /// beside it ("arriving 2.json"), or a complete marker of another move is there.
    static func checkOnlyOurMove(_ stamp: MoveStamp, in destination: URL) throws {
        let folder = moveFolder(in: base(destination))
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let stem = (arrivingName as NSString).deletingPathExtension
        for listed in names {
            let name = CloudFiles.realName(ofPlaceholder: listed) ?? listed
            if name.hasPrefix(stem), name != arrivingName { throw MoveError.otherDeviceMoving("Another device") }
        }
        switch marker(at: folder.appendingPathComponent(arrivingName)) {
        case .stamp(let there):
            if there.moveID != stamp.moveID { throw MoveError.otherDeviceMoving(there.deviceName) }
        case .none, .unclear:
            throw MoveError.otherDeviceMoving("Another device")
        }
        if case .stamp(let done) = marker(at: folder.appendingPathComponent(completeName)),
           done.generation >= stamp.generation, done.moveID != stamp.moveID {
            throw MoveError.alreadyMoved(done.deviceName)
        }
    }

    /// Writes the "moved" file into the folder the notes left, unless one of this move or a
    /// later one is there already. Any device that follows a move makes sure of it.
    public static func writeMoved(_ stamp: MoveStamp, in folder: URL) throws {
        let root = base(folder)
        if case .stamp(let there) = movedMarker(in: root), there.generation >= stamp.generation { return }
        do {
            try movedText(stamp).write(to: root.appendingPathComponent(movedFileName), atomically: true, encoding: .utf8)
        } catch {
            throw MoveError.markerFailed(error.localizedDescription)
        }
    }

    // MARK: Is the vault complete here?

    /// Looks at a folder the notes were moved to, on a device that did not make the copy. Asks
    /// iCloud for whatever is missing and never waits. Reads names and iCloud's marks; the only
    /// files it opens are the markers and the list.
    public static func look(at folder: URL) -> PlaceLook {
        let fm = FileManager.default
        let root = base(folder)
        var look = PlaceLook()
        look.standing = standing(of: root)
        guard let stamp = look.stamp, let list = list(in: root, matching: stamp) else { return look }
        look.listHere = true
        for file in list.files where !file.path.hasPrefix(backupsPrefix) && !file.path.hasPrefix(deletedPrefix) {
            look.expected += 1
            let url = root.appendingPathComponent(file.path)
            if fm.fileExists(atPath: url.path) {
                if CloudFiles.presence(of: url) == .here {
                    look.here += 1
                } else {
                    CloudFiles.startDownload(url)
                    look.arriving.append(file.path)
                }
            } else if fm.fileExists(atPath: CloudFiles.placeholderURL(for: url).path) {
                CloudFiles.startDownload(url)
                look.arriving.append(file.path)
            } else {
                look.missing.append(file.path)
            }
        }
        return look
    }

    /// When the newest note in a folder was last changed. Dates only; no file is opened.
    public static func newestNoteChange(in folder: URL) -> Date? {
        let root = base(folder)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else { return nil }
        var newest: Date?
        while let path = walker.nextObject() as? String {
            if path == Vault.stateFolderName { walker.skipDescendants(); continue }
            guard isNote(path), let date = walker.fileAttributes?[.modificationDate] as? Date else { continue }
            if newest == nil || date > newest! { newest = date }
        }
        return newest
    }

    // MARK: Changes made in the old folder after the move

    static func seenName(deviceID: String) -> String { "seen-\(Vault.sanitizeFileName(deviceID)).json" }

    /// What this device compares the old folder with: what it last saw there, or — the first
    /// time — the list made at the move.
    public static func baseline(for deviceID: String, in newFolder: URL) -> MoveManifest? {
        let url = moveFolder(in: base(newFolder)).appendingPathComponent(seenName(deviceID: deviceID))
        if let found = smallFile(url), let data = found, let seen = try? decoder.decode(MoveManifest.self, from: data) {
            return seen
        }
        return list(in: newFolder)
    }

    /// What is new, changed or gone in the old folder since `baseline`. In-vault backups are
    /// not looked at: an older PARAGON makes one there every day. Also returns the old folder
    /// as it is now.
    public static func changes(in oldFolder: URL, since baseline: MoveManifest,
                               waitingUpTo wait: TimeInterval = CloudFiles.longestWait) throws -> (changes: OldFolderChanges, now: MoveManifest) {
        let now = try manifest(of: oldFolder, waitingUpTo: wait, skippingBackups: true)
        let before = baseline.hashes
        let current = now.hashes
        var changes = OldFolderChanges()
        for file in now.files {
            guard let was = before[file.path] else {
                changes.added.append(file.path)
                continue
            }
            if was != file.hash { changes.changed.append(file.path) }
        }
        changes.deleted = before.keys.filter { current[$0] == nil && !$0.hasPrefix(backupsPrefix) && !isMoveOwn($0) }.sorted()
        return (changes, now)
    }

    /// "<name> (conflict 2026-11-13 1412).md" — the name the app's own conflict copies carry, so
    /// the Reminders sync leaves the copy out. Other files keep their own ending.
    static func conflictPath(for path: String, at date: Date, number: Int) -> String {
        if path.lowercased().hasSuffix(".md") { return Vault.conflictCopyPath(for: path, at: date, number: number) }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        let ext = (path as NSString).pathExtension
        let stem = ext.isEmpty ? path : String(path.dropLast(ext.count + 1))
        let suffix = number > 1 ? " \(number)" : ""
        return "\(stem) (conflict \(formatter.string(from: date))\(suffix))" + (ext.isEmpty ? "" : ".\(ext)")
    }

    /// **Brings over what changed in the old folder after the move**, file by file:
    /// new there → copied; changed there and untouched here → replaced; changed in both → both
    /// kept, the old folder's version beside the note as a conflict copy; deleted there →
    /// nothing is deleted here. PARAGON's own state files changed in both places stay as the
    /// new folder has them. Afterwards this device remembers what it saw, so nothing is
    /// brought twice. The old folder is only read.
    public static func bringOver(from oldFolder: URL, to newFolder: URL, deviceID: String, now: Date = Date(),
                                 waitingUpTo wait: TimeInterval = CloudFiles.longestWait) throws -> BroughtOver {
        let fm = FileManager.default
        let old = base(oldFolder), new = base(newFolder)
        guard let baseline = baseline(for: deviceID, in: new) else { throw MoveError.noList }
        let (changes, seen) = try changes(in: old, since: baseline, waitingUpTo: wait)
        let before = baseline.hashes
        let oldHashes = seen.hashes
        var result = BroughtOver()
        // Review of build 319. "Changed in the old folder, untouched here" may only replace the
        // note here when the change was really made after the move: the old file's date is later
        // than the move. A device that was offline, or a version iCloud delivered late, shows a
        // text that differs from the list too, but is OLDER than the note here; that one is kept
        // beside the note as a conflict copy, never put over it. And whatever is replaced is
        // first copied to "Set aside by a move", so no text is ever gone.
        var movedAt: Date?
        if case .vault(let stamp) = standing(of: new) { movedAt = stamp.at }
        let asideStamp = stampFormatter.string(from: now)
        func changedAfterTheMove(_ path: String) -> Bool {
            guard let movedAt, let date = (try? fm.attributesOfItem(atPath: old.appendingPathComponent(path).path))?[.modificationDate] as? Date else { return false }
            return date > movedAt
        }
        result.deletedInOld = changes.deleted.filter { CloudFiles.exists(new.appendingPathComponent($0)) }
        for path in changes.added + changes.changed {
            let target = new.appendingPathComponent(path)
            var here: String?
            if CloudFiles.exists(target) {
                guard let data = try? currentData(target, waitingUpTo: wait) else {
                    result.failed.append(path)
                    continue
                }
                here = fingerprint(data)
            }
            do {
                if here == oldHashes[path] { continue }
                if here == nil {
                    try copyFile(path, from: old, to: new, wait: wait)
                    result.copied.append(path)
                } else if let was = before[path], here == was, path.hasPrefix(statePrefix) || changedAfterTheMove(path) {
                    try keepCopy(of: path, in: new, stamp: asideStamp)
                    try copyFile(path, from: old, to: new, wait: wait)
                    result.replaced.append(path)
                } else if path.hasPrefix(statePrefix) {
                    result.leftAlone.append(path)
                } else {
                    let data = try currentData(old.appendingPathComponent(path), waitingUpTo: wait)
                    var number = 1
                    while true {
                        let copyPath = conflictPath(for: path, at: now, number: number)
                        let copyURL = new.appendingPathComponent(copyPath)
                        if !CloudFiles.exists(copyURL) {
                            try data.write(to: copyURL, options: .atomic)
                            result.keptBoth.append(copyPath)
                            break
                        }
                        if let there = try? Data(contentsOf: copyURL), there == data { break }
                        number += 1
                    }
                }
            } catch {
                result.failed.append(path)
            }
        }
        // Remembered only when everything went over: a file that failed is offered again.
        if result.failed.isEmpty {
            let folder = moveFolder(in: new)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try? encoder.encode(seen).write(to: folder.appendingPathComponent(seenName(deviceID: deviceID)), options: .atomic)
        }
        return result
    }
}

// MARK: - The backup made before a move, checked

/// What a check of the newest outside copy found (build 319).
public struct BackupCheck: Equatable, Sendable {
    public var folderName: String?
    public var notes = 0
    public var expectedNotes = 0
    /// Files in the copy that are not the same as in the vault.
    public var different: [String] = []
    /// Files the copy says it left out.
    public var skipped = 0

    public var isGood: Bool {
        folderName != nil && different.isEmpty && skipped == 0 && notes == expectedNotes
    }

    public var problem: String? {
        if isGood { return nil }
        if folderName == nil { return "No backup copy was found." }
        if skipped > 0 { return "The backup copy left out \(skipped) file\(skipped == 1 ? "" : "s") that iCloud had not sent yet." }
        if notes != expectedNotes { return "The backup copy holds \(notes) notes; the vault has \(expectedNotes)." }
        return "\(different.count) file\(different.count == 1 ? "" : "s") in the backup copy differ from the vault: \(different.prefix(3).joined(separator: ", "))."
    }
}

public extension Vault {
    /// Checks the newest outside copy of this vault against the vault itself: every file in the
    /// copy must have the same bytes as the vault's, the copy must have left nothing out, and
    /// it must hold as many notes as the vault. **Blocks; never on the main thread.**
    func checkNewestOutsideCopy(in place: URL, waitingUpTo wait: TimeInterval = CloudFiles.longestWait) -> BackupCheck {
        let fm = FileManager.default
        var check = BackupCheck()
        let backupsPath = Vault.stateFolderName + "/Backups"
        if let walker = fm.enumerator(atPath: rootURL.path) {
            while let path = walker.nextObject() as? String {
                if path == backupsPath || VaultMove.isMoveOwn(path) {
                    if (walker.fileAttributes?[.type] as? FileAttributeType) == .typeDirectory { walker.skipDescendants() }
                    continue
                }
                let name = CloudFiles.realName(ofPlaceholder: (path as NSString).lastPathComponent) ?? path
                if name.lowercased().hasSuffix(".md") { check.expectedNotes += 1 }
            }
        }
        guard let newest = ownMarkedOutsideCopies(in: place).first else { return check }
        let folder = outsideCopyURL(newest, in: place)
        check.folderName = newest.folderName
        let own: Set<String> = ["signature.txt", "skipped.txt", Vault.ownerFileName]
        if let skipped = try? String(contentsOf: folder.appendingPathComponent("skipped.txt"), encoding: .utf8) {
            check.skipped = skipped.split(separator: "\n").count
        }
        guard let walker = fm.enumerator(atPath: folder.path) else { return check }
        while let path = walker.nextObject() as? String {
            guard (walker.fileAttributes?[.type] as? FileAttributeType) == .typeRegular else { continue }
            if !path.contains("/"), own.contains(path) { continue }
            if (path as NSString).lastPathComponent == ".DS_Store" { continue }
            if path.lowercased().hasSuffix(".md") { check.notes += 1 }
            guard let copy = try? Data(contentsOf: folder.appendingPathComponent(path)),
                  let original = try? CloudFiles.read(url(for: path), waitingUpTo: wait),
                  copy == original else {
                check.different.append(path)
                continue
            }
        }
        check.different.sort()
        return check
    }
}
