import Foundation
import ParagonCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// **PARAGON's own iCloud folder** (build 319): what the pages and rows about it show.
/// The rules are Core's (`VaultMove`); this file only asks them and switches folders.
struct OwnFolderState: Equatable {
    /// A complete vault found in PARAGON's own folder while no vault is open.
    struct Found: Equatable {
        var notes: Int
        var lastChanged: Date?
        var movedOn: Date?
        var movedBy: String?
        var caution: String?
    }

    struct Offer: Equatable {
        var notes: Int
        var oldName: String
        var devices: [VaultDevices.Line]
        /// PARAGON's folder in iCloud Drive can be reached on this device.
        var reachable: Bool
        /// Another device started a move in the last day and has not finished it.
        var otherMove: String?
    }

    /// The notes left the folder this device has open.
    struct Moved: Equatable {
        var stamp: MoveStamp
        var reachable: Bool
        var ready: Bool
        var here: Int
        var expected: Int
        var missing: [String]
    }

    struct OldChanges: Equatable {
        var notes: [String]
        var deleted: [String]
        var oldName: String
    }

    struct GoBack: Equatable {
        var oldName: String
        var movedOn: Date?
    }

    enum Page: Equatable {
        case offer(Offer)
        case working(String)
        case failed(String, String)
        case done(String, [String])
        case moved(Moved)
        case oldChanges(OldChanges)
        case goBack(GoBack)
    }

    enum Banner: Equatable {
        case moved(Moved)
        case beingFilled(MoveStamp)
        case oldChanges(OldChanges)
    }

    /// At launch: PARAGON is finding its folder. The welcome screen is not shown meanwhile.
    var opening = false
    var found: Found?
    /// Notes are in PARAGON's folder but cannot be opened yet, and why.
    var foundNote: String?
    var page: Page?
    /// The page was asked for in Settings, which shows it itself (on the Mac it is a window of
    /// its own); otherwise the main window shows it.
    var pageFromSettings = false
    var progress: MoveProgress?
    var banner: Banner?
    /// No Reminders sync from the open folder: the notes have left it, or are being moved.
    var holdsSync = false
    /// The open vault is PARAGON's own folder.
    var isOwn = false
    /// The folder the notes were in before the move, while PARAGON still knows it.
    var previousName: String?
    var canGoBack = false
    var movedOn: Date?
    /// PARAGON's folder in iCloud Drive can be reached on this device. While it cannot (iCloud
    /// off, or a build without the iCloud right), Settings does not offer the move at all.
    var reachable = false
}

/// A stop flag a move reads from its own thread.
final class MoveCancel: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    func cancel() { lock.lock(); flag = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
}

@MainActor private var runningMoveCancel: MoveCancel?
@MainActor private var lastOldFolderCheck: Date?
@MainActor private var looksWithTheSameMissing = 0
#if DEBUG
@MainActor private var debugStepDone = false
#endif

private enum MoveResult: Sendable {
    case moved(MoveOutcome, [String])
    case failed(String)
}

private enum FollowResult: Sendable {
    case brought(BroughtOver)
    case notYet(String)
}

private struct OwnFolderSeen: Sendable {
    var standing: FolderStanding = .plain
    var known: Set<String> = []
    var ownLook: PlaceLook?
    var previousLook: PlaceLook?
    var previousReachable = false
    var oldChanges: OldFolderChanges?
    var oldChecked = false
}

private struct WelcomeLook: Sendable {
    var look: PlaceLook
    var halfMade: MoveStamp?
    var notes: Int
    var lastChanged: Date?
    var isVaultHere: Bool
}

extension AppModel {
    // MARK: Finding the folder

    /// PARAGON's own folder in iCloud Drive (the `Documents` folder of the app's iCloud
    /// container), or nil when iCloud Drive is off or the app may not use it. **Can take a
    /// moment the first time, so never on the main thread.**
    nonisolated static func findOwnFolder() -> URL? {
        let fm = FileManager.default
        #if DEBUG
        // For trying the whole move without iCloud: `-paragon-own-folder <path>`. Debug builds only.
        if let path = UserDefaults.standard.string(forKey: "paragon-own-folder"), !path.isEmpty {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        #endif
        guard fm.ubiquityIdentityToken != nil,
              let container = fm.url(forUbiquityContainerIdentifier: VaultMove.containerID) else { return nil }
        let documents = container.appendingPathComponent("Documents", isDirectory: true)
        try? fm.createDirectory(at: documents, withIntermediateDirectories: true)
        return documents
    }

    func ownFolderURL() async -> URL? {
        if let ownFolderCache { return ownFolderCache }
        let url: URL? = await AppModel.away { AppModel.findOwnFolder() }
        ownFolderCache = url
        return url
    }

    /// May PARAGON's folder be opened as the vault on a device that already uses it? Only when
    /// a move finished there and the vault's own marks are listed. An empty or half-listed
    /// folder (a restored device, iCloud still catching up) is never set up afresh.
    nonisolated static func ownFolderIsVaultHere(_ url: URL) -> Bool {
        switch VaultMove.standing(of: url) {
        case .vault, .movedAway: break
        case .plain, .halfMade, .unclear: return false
        }
        let state = url.appendingPathComponent(Vault.stateFolderName, isDirectory: true)
        return CloudFiles.exists(state.appendingPathComponent("config.json")) && FolderLook.look(at: url).isVault
    }

    static var deviceOwnKind: String {
        #if os(macOS)
        return "Mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }

    nonisolated static func deviceOwnName(kind: String) -> String {
        #if os(macOS)
        return Host.current().localizedName ?? kind
        #else
        return kind
        #endif
    }

    // MARK: Launch, and no vault

    /// This device keeps its notes in PARAGON's own folder: find it and open it, off the main
    /// thread. Nothing is ever created there at launch.
    func openOwnFolderAtLaunch() {
        ownFolder.opening = true
        Task { [weak self] in
            guard let self else { return }
            self.ownFolderCache = nil
            let url = await self.ownFolderURL()
            guard self.vault == nil else {
                self.ownFolder.opening = false
                return
            }
            guard let url else {
                self.ownFolder.opening = false
                self.vaultProblem = "PARAGON cannot reach its folder in iCloud Drive on \(AppModel.thisDevice). Check that you are signed in to iCloud and that iCloud Drive is on for PARAGON."
                self.log("own folder not reachable")
                return
            }
            let isHere: Bool = await AppModel.away { AppModel.ownFolderIsVaultHere(url) }
            self.ownFolder.opening = false
            guard self.vault == nil else { return }
            if isHere {
                self.openVault(at: url, ownFolder: true)
            } else {
                self.vaultProblem = "Your notes are in \(VaultMove.ownFolderWords), and iCloud has not brought them to \(AppModel.thisDevice) yet. PARAGON is waiting and opens them when they are here."
                self.log("own folder not here yet")
                self.lookInOwnFolder()
            }
        }
    }

    /// No vault is open: looks in PARAGON's own folder every few seconds and says what is
    /// there. Writes nothing. Stops when a vault opens.
    func lookInOwnFolder() {
        ownFolderLookTask?.cancel()
        looksWithTheSameMissing = 0
        ownFolderLookTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.vault == nil else { return }
                if let url = await self.ownFolderURL() {
                    let seen: WelcomeLook = await AppModel.away {
                        let look = VaultMove.look(at: url)
                        var half: MoveStamp?
                        if case .halfMade(let stamp) = look.standing { half = stamp }
                        let complete = look.isComplete || look.isAllButMissing
                        return WelcomeLook(look: look, halfMade: half,
                                           notes: complete ? FolderLook.look(at: url).noteCount : 0,
                                           lastChanged: complete ? VaultMove.newestNoteChange(in: url) : nil,
                                           isVaultHere: AppModel.ownFolderIsVaultHere(url))
                    }
                    guard !Task.isCancelled, self.vault == nil else { return }
                    self.welcomeLooked(seen, at: url)
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func welcomeLooked(_ seen: WelcomeLook, at url: URL) {
        // A device that already uses the folder opens it by itself as soon as it is here.
        if settingsStore.bool(forKey: ownFolderKey), seen.isVaultHere {
            vaultProblem = nil
            openVault(at: url, ownFolder: true)
            return
        }
        let look = seen.look
        if look.mayOpenDespiteMissing { looksWithTheSameMissing += 1 } else { looksWithTheSameMissing = 0 }
        // Listed files that are not here: offered only after a minute of looks that agree and
        // with the vault's own settings file listed, and then with the caution below.
        if let stamp = look.stamp, look.isComplete || (looksWithTheSameMissing >= 12 && seen.isVaultHere) {
            var found = OwnFolderState.Found(notes: seen.notes, lastChanged: seen.lastChanged,
                                             movedOn: stamp.at, movedBy: stamp.deviceName)
            if !look.missing.isEmpty {
                let n = look.missing.count
                found.caution = "\(n) file\(n == 1 ? "" : "s") from the list made at the move \(n == 1 ? "is" : "are") not here. \(n == 1 ? "It" : "They") may have been deleted or renamed since."
            }
            ownFolder.found = found
            ownFolder.foundNote = nil
        } else if look.stamp != nil {
            ownFolder.found = nil
            ownFolder.foundNote = look.listHere
                ? "Your notes are in \(VaultMove.ownFolderWords) and are still arriving on \(AppModel.thisDevice): \(look.here) of \(look.expected) files are here."
                : "Your notes are in \(VaultMove.ownFolderWords) and are still arriving on \(AppModel.thisDevice)."
        } else if let half = seen.halfMade {
            ownFolder.found = nil
            ownFolder.foundNote = "A move into \(VaultMove.ownFolderWords) was started on \(VaultMove.day(half.at)) by \(half.deviceName) and has not finished. Finish it on that device; the notes are still in their old folder."
        } else {
            ownFolder.found = nil
            ownFolder.foundNote = nil
        }
    }

    /// His yes to "I found your notes here — use them?".
    func useFoundNotes() {
        guard let url = ownFolderCache else { return }
        vaultProblem = nil
        openVault(at: url, ownFolder: true)
    }

    /// Review of build 319: a device that keeps its notes in PARAGON's folder opens them a
    /// moment AFTER launch (the folder is found off the main thread). Siri, Shortcuts and the
    /// widgets can start the app in the background and ask at once; they wait here, ten
    /// seconds at most, instead of answering "no vault".
    func vaultOnceOpen() async {
        var tries = 0
        while vault == nil, ownFolder.opening, tries < 40 {
            try? await Task.sleep(for: .milliseconds(250))
            tries += 1
        }
    }

    // MARK: A vault is open

    /// Called whenever a vault has been opened: notes this device in the vault, and starts
    /// the quiet watch for a move.
    func vaultOpenedForOwnFolder() {
        ownFolderLookTask?.cancel()
        ownFolderLookTask = nil
        ownFolder.opening = false
        ownFolder.found = nil
        ownFolder.foundNote = nil
        ownFolder.banner = nil
        ownFolder.holdsSync = false
        ownFolder.reachable = false
        ownFolder.isOwn = settingsStore.bool(forKey: ownFolderKey)
        ownFolder.previousName = settingsStore.data(forKey: previousVaultBookmarkKey) != nil
            ? settingsStore.string(forKey: previousVaultNameKey) : nil
        ownFolder.canGoBack = false
        lastOldFolderCheck = nil
        noteThisDevice()
        #if DEBUG
        runDebugStepOnce()
        #endif
        ownFolderWatch?.cancel()
        ownFolderWatch = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshOwnFolder()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    #if DEBUG
    /// Debug builds only, for trying the pages without pressing anything:
    /// `-paragon-own-step offer | move | back`, once per start.
    private func runDebugStepOnce() {
        guard !debugStepDone, let step = UserDefaults.standard.string(forKey: "paragon-own-step") else { return }
        debugStepDone = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            _ = await self.ownFolderURL()
            switch step {
            case "offer": self.showMoveOffer(fromSettings: false)
            case "move":
                self.showOwnFolderPage(.working("Moving your notes"), fromSettings: false)
                self.startMove(toOwn: true)
            case "back":
                self.showOwnFolderPage(.working("Going back to the old folder"), fromSettings: false)
                self.startMove(toOwn: false)
            default: break
            }
        }
    }
    #endif

    /// One small file per device in `.ams-para/devices`, so the offer to move can tell whether
    /// every device has opened a PARAGON that understands a moved vault.
    private func noteThisDevice() {
        guard let vault else { return }
        let root: URL = vault.rootURL
        let config: VaultConfig = vault.config
        let id = deviceID
        let kind = AppModel.deviceOwnKind
        let build = BuildStamp.number
        Task {
            await AppModel.away {
                guard let own = try? Vault(rootURL: root, config: config) else { return }
                own.noteDevice(VaultDevice(deviceID: id, name: AppModel.deviceOwnName(kind: kind), build: build, kind: kind, seenAt: Date()))
            }
        }
    }

    /// Looks at the markers of the open folder (three small files), and now and then at the
    /// folder the notes left. Decides whether the sync rests and which bar is shown.
    func refreshOwnFolder(lookAtOldFolderNow: Bool = false) async {
        guard let vault, !isSyncing else { return }
        let root: URL = vault.rootURL
        let config: VaultConfig = vault.config
        let isOwn = settingsStore.bool(forKey: ownFolderKey)
        let id = deviceID
        let own = await ownFolderURL()
        let previous = previousVaultFolder()
        let dueForOld = lookAtOldFolderNow || lastOldFolderCheck.map { Date().timeIntervalSince($0) > 3600 } ?? true
        let seen: OwnFolderSeen = await AppModel.away {
            var seen = OwnFolderSeen()
            seen.standing = VaultMove.standing(of: root)
            seen.known = (try? Vault(rootURL: root, config: config))?.knownIdentities().all ?? []
            if !isOwn, let own { seen.ownLook = VaultMove.look(at: own) }
            if isOwn, let previous {
                let scoped = previous.startAccessingSecurityScopedResource()
                defer { if scoped { previous.stopAccessingSecurityScopedResource() } }
                seen.previousReachable = FileManager.default.fileExists(atPath: previous.path)
                if case .movedAway = seen.standing { seen.previousLook = VaultMove.look(at: previous) }
                if dueForOld, seen.previousReachable, let baseline = VaultMove.baseline(for: id, in: root) {
                    // Never waits for iCloud here; a file that is not down yet is asked for and
                    // the look is tried again later.
                    if let found = try? VaultMove.changes(in: previous, since: baseline, waitingUpTo: 0) {
                        seen.oldChanges = found.changes
                        seen.oldChecked = true
                    }
                }
            }
            return seen
        }
        guard self.vault?.rootURL == root, !isSyncing else { return }
        if seen.oldChecked { lastOldFolderCheck = Date() }
        applyOwnFolder(seen, isOwn: isOwn, ownReachable: own != nil)
    }

    private func applyOwnFolder(_ seen: OwnFolderSeen, isOwn: Bool, ownReachable: Bool) {
        func moved(_ stamp: MoveStamp, _ look: PlaceLook?, reachable: Bool) -> OwnFolderState.Moved {
            let same = look?.stamp?.moveID == stamp.moveID || (look?.stamp?.generation ?? 0) > stamp.generation
            let usable = same ? look : nil
            if usable?.mayOpenDespiteMissing == true { looksWithTheSameMissing += 1 } else { looksWithTheSameMissing = 0 }
            let ready = usable?.isComplete == true || (usable?.mayOpenDespiteMissing == true && looksWithTheSameMissing >= 4)
            return OwnFolderState.Moved(stamp: stamp, reachable: reachable, ready: ready,
                                        here: usable?.here ?? 0, expected: usable?.expected ?? (stamp.fileCount ?? 0),
                                        missing: usable?.missing ?? [])
        }
        var banner: OwnFolderState.Banner?
        var holds = false
        var canGoBack = false
        // The vault is complete in PARAGON's folder under a later move number than anything
        // this folder says: the notes are there, whatever this folder's own markers say (the
        // "moved" file has not arrived, was taken away, cannot be read yet, or a move back
        // into this folder was started and never finished).
        var here = 0
        if case .vault(let stamp) = seen.standing { here = stamp.generation }
        if case .movedAway(let stamp) = seen.standing { here = stamp.generation }
        var ownSays: MoveStamp?
        if !isOwn, let stamp = seen.ownLook?.stamp, stamp.toOwnFolder, seen.known.contains(stamp.vaultID),
           stamp.generation > here {
            ownSays = stamp
        }
        switch seen.standing {
        case .movedAway(let stamp):
            holds = true
            banner = stamp.toOwnFolder
                ? .moved(moved(stamp, seen.ownLook, reachable: ownReachable))
                : .moved(moved(stamp, seen.previousLook, reachable: seen.previousReachable))
        case .halfMade(let stamp):
            holds = true
            banner = ownSays.map { .moved(moved($0, seen.ownLook, reachable: true)) } ?? .beingFilled(stamp)
        case .unclear:
            // Review of build 319: a marker is in this folder and cannot be read yet. It may
            // say "the notes have moved", so the sync rests until it can be read (seconds).
            holds = true
            banner = ownSays.map { .moved(moved($0, seen.ownLook, reachable: true)) } ?? ownFolder.banner
        case .plain, .vault:
            if let stamp = ownSays {
                holds = true
                banner = .moved(moved(stamp, seen.ownLook, reachable: true))
            } else if isOwn {
                canGoBack = seen.previousReachable
                if let changes = seen.oldChanges, !changes.notes.isEmpty,
                   settingsStore.string(forKey: "oldFolderChangesSeen") != changes.notes.joined(separator: "\n") {
                    banner = .oldChanges(OwnFolderState.OldChanges(notes: changes.notes, deleted: changes.deleted,
                                                                   oldName: ownFolder.previousName ?? "the old folder"))
                } else if case .oldChanges = ownFolder.banner, seen.oldChanges == nil {
                    banner = ownFolder.banner
                }
            }
        }
        ownFolder.reachable = ownReachable
        if holds, !ownFolder.holdsSync { log("sync rests: the notes left this folder") }
        ownFolder.holdsSync = holds
        ownFolder.banner = banner
        ownFolder.canGoBack = canGoBack
        ownFolder.isOwn = isOwn
        if case .vault(let stamp) = seen.standing, isOwn { ownFolder.movedOn = stamp.at } else { ownFolder.movedOn = nil }
        // A page that shows the waiting count follows it.
        if case .moved = ownFolder.page, case .moved(let fresh)? = banner { ownFolder.page = .moved(fresh) }
    }

    // MARK: Pages

    func showOwnFolderPage(_ page: OwnFolderState.Page, fromSettings: Bool) {
        ownFolder.pageFromSettings = fromSettings
        ownFolder.page = page
        if !fromSettings { activeSheet = .ownFolder }
    }

    func closeOwnFolderPage() {
        if case .working = ownFolder.page { return }
        ownFolder.page = nil
        ownFolder.progress = nil
        if activeSheet == .ownFolder { activeSheet = nil }
    }

    /// The offer: what a move does, where the notes will be, that the old folder stays, and
    /// which devices use the vault. Nothing happens until **Move my notes**.
    func showMoveOffer(fromSettings: Bool) {
        guard let vault else { return }
        let root: URL = vault.rootURL
        let config: VaultConfig = vault.config
        let id = deviceID
        let notes = notes.count
        let kind = AppModel.deviceOwnKind
        let build = BuildStamp.number
        Task { [weak self] in
            guard let self else { return }
            self.ownFolderCache = nil
            let own = await self.ownFolderURL()
            let info: (lines: [VaultDevices.Line], other: String?) = await AppModel.away {
                let this = VaultDevice(deviceID: id, name: AppModel.deviceOwnName(kind: kind), build: build, kind: kind, seenAt: Date())
                let lines = (try? Vault(rootURL: root, config: config))?.deviceLines(this: this) ?? []
                var other: String?
                if let own, case .halfMade(let stamp) = VaultMove.standing(of: own), stamp.deviceID != id,
                   Date().timeIntervalSince(stamp.at) < 86_400 {
                    other = "\(stamp.deviceName) started a move on \(VaultMove.day(stamp.at)) and has not finished it. Finish it there, or wait a day."
                }
                return (lines, other)
            }
            self.showOwnFolderPage(.offer(OwnFolderState.Offer(notes: notes, oldName: root.lastPathComponent, devices: info.lines,
                                                               reachable: own != nil, otherMove: info.other)),
                                   fromSettings: fromSettings)
        }
    }

    func showGoBack(fromSettings: Bool) {
        showOwnFolderPage(.goBack(OwnFolderState.GoBack(oldName: ownFolder.previousName ?? "the old folder",
                                                        movedOn: ownFolder.movedOn)), fromSettings: fromSettings)
    }

    func cancelMove() {
        runningMoveCancel?.cancel()
    }

    // MARK: The move, and the move back

    /// **Move my notes** (`toOwn`) and **Go back** (the same move the other way). Backup first
    /// and checked; then copy, verify, wait for iCloud, markers — all in `VaultMove.run`. The
    /// app switches folders only when that has returned without an error.
    func startMove(toOwn: Bool) {
        guard let vault, !isSyncing else {
            errorMessage = "A sync is running. Try again when it has finished."
            return
        }
        let fromSettings = ownFolder.pageFromSettings
        let previous = toOwn ? nil : previousVaultFolder()
        guard let destination = toOwn ? ownFolderCache : previous else {
            showOwnFolderPage(.failed("Nothing was moved",
                                      toOwn ? "PARAGON cannot reach its folder in iCloud Drive on \(AppModel.thisDevice)."
                                            : "PARAGON cannot reach the old folder on \(AppModel.thisDevice)."), fromSettings: fromSettings)
            return
        }
        flushPendingEdits()
        let cancel = MoveCancel()
        runningMoveCancel = cancel
        holdForMove(true)
        ownFolder.progress = nil
        ownFolder.page = .working(toOwn ? "Moving your notes" : "Going back to the old folder")
        let root: URL = vault.rootURL
        let config: VaultConfig = vault.config
        let id = deviceID
        let kind = AppModel.deviceOwnKind
        let build = BuildStamp.number
        let backup = backupPlaceForMove()
        let placeName = toOwn ? VaultMove.ownFolderWords : (ownFolder.previousName ?? destination.lastPathComponent)
        let report: @Sendable (MoveProgress) -> Void = { progress in
            Task { @MainActor [weak self] in
                if case .working = self?.ownFolder.page { self?.ownFolder.progress = progress }
            }
        }
        Task { [weak self] in
            let result: MoveResult = await AppModel.away {
                let scopedBackup = backup?.chosen?.startAccessingSecurityScopedResource() ?? false
                let scopedOld = previous?.startAccessingSecurityScopedResource() ?? false
                defer {
                    if scopedBackup { backup?.chosen?.stopAccessingSecurityScopedResource() }
                    if scopedOld { previous?.stopAccessingSecurityScopedResource() }
                }
                do {
                    let own = try Vault(rootURL: root, config: config)
                    var notes: [String] = []
                    // Review of build 319: no move while a device that uses these notes has not
                    // opened a PARAGON that understands a move. Asked again here, where the move
                    // starts, whatever the page showed. There is no "Move anyway".
                    if toOwn {
                        let this = VaultDevice(deviceID: id, name: AppModel.deviceOwnName(kind: kind), build: build, kind: kind, seenAt: Date())
                        guard VaultDevices.allReady(own.deviceLines(this: this)) else {
                            return .failed("One of your devices has not opened PARAGON \(VaultMove.firstBuild) or newer yet. It would go on writing into the old folder, so nothing was moved. Open PARAGON once on every device, then try again.")
                        }
                    }
                    // Going back: what waits in the old folder comes over first, so the move
                    // back cannot set a newer note aside.
                    if !toOwn {
                        let brought = try VaultMove.bringOver(from: destination, to: root, deviceID: id)
                        guard brought.failed.isEmpty else {
                            return .failed("Some files changed in the old folder could not be read, so PARAGON did not go back: \(brought.failed.prefix(5).joined(separator: ", ")). Nothing has changed.")
                        }
                        notes = brought.lines
                    }
                    // Everything down from iCloud, and iCloud's set-aside versions kept as copies.
                    report(MoveProgress(step: .reading, done: 0, total: 0))
                    let all = try VaultMove.manifest(of: root, progress: { report(MoveProgress(step: .reading, done: $0, total: 0)) },
                                                     cancelled: { cancel.isCancelled })
                    _ = own.settleParkedVersions(of: all.files.map(\.path).filter(VaultMove.isNote))
                    // The backup, made with the usual code, and then checked file by file.
                    guard let backup else { return .failed("PARAGON found no place for the backup copy, so nothing was moved.") }
                    _ = try own.makeOutsideCopy(in: backup.place, reason: "before move")
                    let check = own.checkNewestOutsideCopy(in: backup.place)
                    guard check.isGood else {
                        return .failed("The backup copy could not be confirmed, so nothing was moved. \(check.problem ?? "")")
                    }
                    guard let identity = own.identity(creating: true) else {
                        return .failed("The vault\u{2019}s id is still coming from iCloud, so nothing was moved. Try again in a minute.")
                    }
                    var hooks = MoveHooks()
                    hooks.progress = report
                    hooks.cancelled = { cancel.isCancelled }
                    let request = MoveRequest(source: root, destination: destination, vaultID: identity.id,
                                              knownVaultIDs: own.knownIdentities().all,
                                              deviceName: AppModel.deviceOwnName(kind: kind), deviceID: id,
                                              toOwnFolder: toOwn, placeName: placeName, build: build)
                    let outcome = try VaultMove.run(request, hooks: hooks)
                    return .moved(outcome, notes)
                } catch {
                    return .failed(error.localizedDescription)
                }
            }
            guard let self else { return }
            runningMoveCancel = nil
            self.holdForMove(false)
            self.ownFolder.progress = nil
            switch result {
            case .failed(let why):
                self.log("move not done: \(why)")
                self.ownFolder.page = .failed(toOwn ? "Your notes were not moved" : "PARAGON did not go back", why)
            case .moved(let outcome, let notes):
                self.log("move \(outcome.stamp.generation) done: \(outcome.manifest.fileCount) files, \(outcome.copied) copied")
                if toOwn { self.rememberVaultAsPrevious() }
                self.openVault(at: destination, ownFolder: toOwn)
                guard self.vault?.rootURL.path == destination.standardizedFileURL.resolvingSymlinksInPath().path else {
                    self.ownFolder.page = .failed("The copy is complete, but PARAGON could not switch yet",
                                                  "Every file was copied and checked. PARAGON shows a bar with a button to open the new place.")
                    return
                }
                if !toOwn {
                    self.settingsStore.removeObject(forKey: self.previousVaultBookmarkKey)
                    self.settingsStore.removeObject(forKey: self.previousVaultNameKey)
                    self.ownFolder.previousName = nil
                }
                let files = outcome.manifest.fileCount
                var lines = ["\(outcome.manifest.noteCount) notes, \(files) files in all (\(MoveError.megabytes(outcome.manifest.byteCount))): every one copied and checked."]
                if toOwn {
                    lines.append("They are now in \(VaultMove.ownFolderWords). PARAGON opens that folder by itself on every device.")
                    lines.append("Your old folder \u{201C}\(root.lastPathComponent)\u{201D} is as it was, plus one text file that says where the notes went. Keep it until you are sure.")
                    lines.append("On your other devices PARAGON shows \u{201C}Your notes have moved\u{201D} and waits until iCloud has brought everything.")
                } else {
                    lines.append("They are in the folder \u{201C}\(placeName)\u{201D} again.")
                    if outcome.setAside > 0 {
                        lines.append("\(outcome.setAside) older file\(outcome.setAside == 1 ? "" : "s") in that folder were set aside, not deleted: .ams-para \u{203A} Set aside by a move.")
                    }
                }
                lines.append(contentsOf: notes)
                lines.append("Reminders sync goes on as before.")
                self.ownFolder.page = .done(toOwn ? "Your notes are in PARAGON\u{2019}s own folder" : "PARAGON is back in the old folder", lines)
            }
        }
    }

    // MARK: Another device moved the notes

    /// **Open the new folder**: only when the vault is complete there on this device. What this
    /// device changed in the folder it leaves comes along first; then the app switches. Nothing
    /// is copied twice and nothing is created in the new place.
    func followMove() {
        guard case .moved(let moved)? = ownFolder.banner, let vault, !isSyncing else { return }
        let stamp = moved.stamp
        let fromSettings = ownFolder.pageFromSettings
        let previous = stamp.toOwnFolder ? nil : previousVaultFolder()
        guard moved.ready, let destination = stamp.toOwnFolder ? ownFolderCache : previous else { return }
        flushPendingEdits()
        holdForMove(true)
        let root: URL = vault.rootURL
        let id = deviceID
        let allowMissing = !moved.missing.isEmpty
        showOwnFolderPage(.working("Opening your notes in their new place"), fromSettings: fromSettings)
        Task { [weak self] in
            let result: FollowResult = await AppModel.away {
                let scoped = previous?.startAccessingSecurityScopedResource() ?? false
                defer { if scoped { previous?.stopAccessingSecurityScopedResource() } }
                let look = VaultMove.look(at: destination)
                guard let there = look.stamp, there.generation >= stamp.generation, look.listHere, look.arriving.isEmpty,
                      look.missing.isEmpty || (allowMissing && look.mayOpenDespiteMissing) else {
                    return .notYet("The notes are not complete in the new place on this device yet. Nothing has changed.")
                }
                do {
                    let brought = try VaultMove.bringOver(from: root, to: destination, deviceID: id)
                    guard brought.failed.isEmpty else { return .brought(brought) }
                    // The folder this device leaves says where the notes went, if it did not yet.
                    try? VaultMove.writeMoved(there, in: root)
                    return .brought(brought)
                } catch {
                    return .notYet(error.localizedDescription)
                }
            }
            guard let self else { return }
            self.holdForMove(false)
            switch result {
            case .notYet(let why):
                self.ownFolder.page = .failed("Not yet", why)
            case .brought(let brought) where !brought.failed.isEmpty:
                self.ownFolder.page = .failed("Not yet", brought.lines.last ?? "Some files could not be brought over. Nothing has changed.")
            case .brought(let brought):
                if stamp.toOwnFolder { self.rememberVaultAsPrevious() }
                self.openVault(at: destination, ownFolder: stamp.toOwnFolder)
                guard self.vault?.rootURL.path == destination.standardizedFileURL.resolvingSymlinksInPath().path else {
                    self.ownFolder.page = .failed("Not yet", "PARAGON could not switch folders just now. Try again in a moment.")
                    return
                }
                if !stamp.toOwnFolder {
                    self.settingsStore.removeObject(forKey: self.previousVaultBookmarkKey)
                    self.settingsStore.removeObject(forKey: self.previousVaultNameKey)
                }
                var lines = ["PARAGON now uses \(stamp.toOwnFolder ? VaultMove.ownFolderWords : "the folder \u{201C}\(stamp.placeName)\u{201D}") on \(AppModel.thisDevice), as on \(stamp.deviceName)."]
                lines.append(contentsOf: brought.lines)
                if !brought.changedSomething { lines.append("Nothing had changed on \(AppModel.thisDevice) since the move.") }
                lines.append("Reminders sync goes on as before.")
                self.ownFolder.page = .done("Your notes are open in their new place", lines)
            }
        }
    }

    // MARK: Changes in the old folder after the move

    func notNowForOldChanges() {
        if case .oldChanges(let changes)? = ownFolder.banner {
            settingsStore.set(changes.notes.joined(separator: "\n"), forKey: "oldFolderChangesSeen")
            ownFolder.banner = nil
        }
        closeOwnFolderPage()
    }

    /// **Bring them over**: Core's rule, file by file; then the notes are read again.
    func bringOldChangesOver() {
        guard let vault, !isSyncing, let previous = previousVaultFolder() else { return }
        flushPendingEdits()
        holdForMove(true)
        let root: URL = vault.rootURL
        let id = deviceID
        ownFolder.page = .working("Bringing the changes over")
        Task { [weak self] in
            let result: FollowResult = await AppModel.away {
                let scoped = previous.startAccessingSecurityScopedResource()
                defer { if scoped { previous.stopAccessingSecurityScopedResource() } }
                do { return .brought(try VaultMove.bringOver(from: previous, to: root, deviceID: id)) }
                catch { return .notYet(error.localizedDescription) }
            }
            guard let self else { return }
            self.holdForMove(false)
            self.ownFolder.banner = nil
            self.reload()
            switch result {
            case .notYet(let why):
                self.ownFolder.page = .failed("Nothing was brought over", why)
            case .brought(let brought):
                self.log("old folder: \(brought.copied.count) copied, \(brought.replaced.count) replaced, \(brought.keptBoth.count) kept twice, \(brought.failed.count) failed")
                var lines = brought.lines
                if lines.isEmpty { lines = ["Everything was here already."] }
                lines.append("The old folder was only read. If a device with an older PARAGON still writes there, update PARAGON on it.")
                self.ownFolder.page = .done("The changes are here", lines)
            }
            await self.refreshOwnFolder(lookAtOldFolderNow: true)
        }
    }

    // MARK: Showing the folder

    /// "Show in Files" on the iPhone and iPad; "Show in Finder" on the Mac.
    func showVaultFolder() {
        guard let vault else { return }
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([vault.rootURL])
        #else
        var parts = URLComponents(url: vault.rootURL, resolvingAgainstBaseURL: false)
        parts?.scheme = "shareddocuments"
        if let url = parts?.url { UIApplication.shared.open(url) }
        #endif
    }
}
