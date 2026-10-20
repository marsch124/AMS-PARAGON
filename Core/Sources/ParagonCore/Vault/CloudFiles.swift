import Foundation

/// iCloud keeps a file it has not needed yet as a placeholder: nothing but a stub named
/// ".Note.md.icloud" beside where the file belongs. The stub is hidden and does not end in
/// ".md", so every listing in this package walks straight past it and the file looks as if it
/// never arrived. Asking for it is the only way it is ever fetched.
public enum CloudFiles {
    /// The real name behind a placeholder (".Note.md.icloud" → "Note.md"), or nil for an
    /// ordinary file.
    public static func realName(ofPlaceholder name: String) -> String? {
        let suffix = ".icloud"
        guard name.hasPrefix("."), name.hasSuffix(suffix), name.count > suffix.count + 1 else { return nil }
        return String(name.dropFirst().dropLast(suffix.count))
    }

    /// The stub iCloud leaves where a file belongs until it is fetched.
    public static func placeholderURL(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
    }

    /// True when the file is there, even if its contents have not arrived: a placeholder beside
    /// it counts. Everything that decides whether to write a file asks this, or a note or
    /// template that exists but is still on its way would be written over with a fresh one and
    /// the two would collide in iCloud.
    public static func exists(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) || fm.fileExists(atPath: placeholderURL(for: url).path)
    }

    /// True when the file belongs to iCloud and this device does not have its contents.
    public static func isMissing(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true,
              let status = values.ubiquitousItemDownloadingStatus else { return false }
        return status != .current
    }

    /// Asks iCloud to fetch the file. Does nothing for a file that is not in iCloud, and
    /// returns without waiting: the download lands some seconds later and the app's own
    /// change check notices it.
    public static func startDownload(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    // MARK: Where a file's contents are (build 261)

    /// Whether a file's contents are on this device.
    public enum Presence: Equatable, Sendable {
        /// On this device and current, or not an iCloud file at all. Read it.
        case here
        /// An older copy is here and iCloud has a newer one. Readable at once, but it may be out
        /// of date: the app shows it and refuses whole-vault writes until it is current.
        case stale
        /// Not on this device. Reading it means waiting for iCloud.
        case away
    }

    /// The decision, apart from the file system so it can be tested.
    public static func presence(isUbiquitous: Bool?, status: URLUbiquitousItemDownloadingStatus?) -> Presence {
        guard isUbiquitous == true, let status else { return .here }
        if status == .current { return .here }
        if status == .downloaded { return .stale }
        return .away
    }

    /// Asks the file system. Metadata only: never waits for a download. A path that does not
    /// exist at all reads as `.here` — whether a file is there is `exists(_:)`'s question.
    public static func presence(of url: URL) -> Presence {
        let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        return presence(isUbiquitous: values?.isUbiquitousItem, status: values?.ubiquitousItemDownloadingStatus)
    }

    /// The longest one read may wait for iCloud to send one file.
    public static let longestWait: TimeInterval = 20
    /// The longest one background pass may spend waiting, all files together.
    public static let passLength: TimeInterval = 60

    /// Reads a file, waiting up to `wait` seconds for iCloud when its contents are not here.
    ///
    /// **There is no default**, so every caller says how long it may wait (build 261: a launch
    /// that waited for iCloud on the main thread was killed by iOS before its first frame).
    /// **Zero never waits**: a file whose contents are not here throws at once, after asking
    /// iCloud for it. Above zero this blocks the calling thread through a coordinated read — the
    /// only thing that makes iCloud bring a file down (build 101) — so it is never given a wait
    /// on the main thread.
    public static func read(_ url: URL, waitingUpTo wait: TimeInterval) throws -> Data {
        if presence(of: url) == .away {
            startDownload(url)
            // Where a system keeps such a file under its own name, a plain read of it is itself
            // a wait with no end, so it is never tried.
            guard wait > 0 else { throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: url.path]) }
            return try coordinatedRead(url, waitingUpTo: wait, otherwise: nil)
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            startDownload(url)
            guard wait > 0 else { throw error }
            return try coordinatedRead(url, waitingUpTo: wait, otherwise: error)
        }
    }

    /// A read that waits for iCloud, given up after `wait` seconds by cancelling the coordinator
    /// from another thread.
    private static func coordinatedRead(_ url: URL, waitingUpTo wait: TimeInterval, otherwise first: Error?) throws -> Data {
        let coordinator = NSFileCoordinator()
        let giveUp = DispatchWorkItem { coordinator.cancel() }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + wait, execute: giveUp)
        defer { giveUp.cancel() }
        var data: Data?
        var readError: Error?
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { actual in
            do { data = try Data(contentsOf: actual) } catch { readError = error }
        }
        if let data { return data }
        if let readError { throw readError }
        if let coordinationError { throw coordinationError }
        if let first { throw first }
        throw CocoaError(.fileReadUnknown)
    }

    /// Waits for iCloud to send the given files, one after another, until `seconds` have gone
    /// (build 261). Every try costs time whether or not the file comes, so a file iCloud cannot
    /// deliver holds up the ones after it for `longestWait` at most; a try with less than a
    /// second left is not started. Returns what arrived.
    ///
    /// **Blocks the calling thread; the app calls it on a GCD thread, never the main one.**
    /// `now` and `waitFor` are for the tests: there is no iCloud in a test.
    public static func fetch(_ urls: [URL], within seconds: TimeInterval,
                             now: () -> Date = { Date() },
                             waitFor: (URL, TimeInterval) -> Bool = { url, wait in
                                 (try? CloudFiles.read(url, waitingUpTo: wait)) != nil
                             }) -> [URL] {
        let start = now()
        var arrived: [URL] = []
        for url in urls {
            let left = seconds - now().timeIntervalSince(start)
            guard left >= 1 else { break }
            if waitFor(url, min(longestWait, left)) { arrived.append(url) }
        }
        return arrived
    }

    /// Every file under `root` that iCloud has not sent to this device, asked for as it goes.
    /// Free of `Vault` on purpose: the walk touches every file and must be runnable off the
    /// main thread, where an app cannot carry a non-Sendable object (build 101).
    public static func downloadMissing(under root: URL, skipping skipped: String) -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root,
                                         includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
                                         options: [.skipsPackageDescendants]) else { return [] }
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        var asked: [String] = []
        func relative(_ url: URL) -> String? {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            guard path.hasPrefix(prefix) else { return nil }
            return String(path.dropFirst(prefix.count))
        }
        for case let fileURL as URL in walker {
            let name = fileURL.lastPathComponent
            if name == skipped {
                walker.skipDescendants()
                continue
            }
            if let real = realName(ofPlaceholder: name) {
                let parent = fileURL.deletingLastPathComponent()
                startDownload(parent.appendingPathComponent(real))
                startDownload(fileURL)
                let folder = relative(parent) ?? ""
                asked.append(folder.isEmpty ? real : "\(folder)/\(real)")
            } else if isMissing(fileURL) {
                startDownload(fileURL)
                asked.append(relative(fileURL) ?? name)
            }
        }
        return asked.sorted()
    }
}

public extension Vault {
    /// Asks iCloud for every vault file this device does not have yet — notes and templates
    /// alike — and returns their relative paths. Called at launch, when a vault is opened and
    /// every now and then afterwards, because a file written on the Mac reaches the iPhone as
    /// a placeholder and nothing else would ever open it.
    @discardableResult
    func downloadCloudFiles() -> [String] {
        // Backups and deleted notes are none of this device's business, so the state folder
        // is skipped.
        CloudFiles.downloadMissing(under: rootURL, skipping: Vault.stateFolderName)
    }
}
