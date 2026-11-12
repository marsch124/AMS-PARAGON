import Foundation

/// **A version of a note that iCloud has put aside** (review round 2, hardening-09).
///
/// When the same note is changed on two devices before either has heard from the other, iCloud
/// keeps one as the file and parks the other out of sight. Nothing in the app ever asked for the
/// parked one, so what was typed on the losing device was simply gone from view. Now, after each
/// re-read, the notes that changed are asked about, and every parked version is written beside
/// its note as "<name> (conflict yyyy-MM-dd HHmm).md" — the same copy the editor makes for its
/// own conflicts — and only then taken off iCloud's list.
public struct ParkedVersion: Equatable, Sendable {
    public var text: String
    /// When that version was written, which is what the copy is named after.
    public var modifiedAt: Date?
    /// The device it was written on, as iCloud names it.
    public var device: String?

    public init(text: String, modifiedAt: Date? = nil, device: String? = nil) {
        self.text = text
        self.modifiedAt = modifiedAt
        self.device = device
    }
}

/// What one look for parked versions did.
public struct ParkedVersionsFound: Equatable, Sendable {
    public struct Kept: Equatable, Sendable {
        /// The note the version belongs to, and what it is called.
        public var note: String
        public var noteTitle: String
        /// The copy written beside it.
        public var copy: String
        public var copyTitle: String
    }
    public var kept: [Kept] = []
    /// Notes with a parked version that could not be read yet. They are asked about again.
    public var notYet: [String] = []

    public init() {}

    /// What the app tells him, in the editor's own words for a conflict. Nil when nothing was kept.
    public var message: String? {
        guard let first = kept.first else { return nil }
        let notes = Set(kept.map(\.note))
        if kept.count == 1 {
            return "\"\(first.noteTitle)\" was changed on two devices at the same time. "
                + "The other version is saved as \"\(first.copyTitle)\" next to it."
        }
        if notes.count == 1 {
            return "\"\(first.noteTitle)\" was changed on several devices at the same time. "
                + "The \(kept.count) other versions are saved next to it, with \"(conflict …)\" in their names."
        }
        return "\(notes.count) notes were changed on two devices at the same time. "
            + "The other versions are saved next to them, with \"(conflict …)\" in their names."
    }
}

public extension Vault {
    /// Writes each parked version beside its note as a conflict copy and returns the copies.
    ///
    /// The rules, apart from iCloud so they can be tested:
    /// - a version that says exactly what the note says is not a second version: no copy;
    /// - nor is one that says what an earlier one in the same batch said;
    /// - a copy is named after the time its version was written, and **never written over
    ///   another copy**: a name already taken by different words gets " 2", " 3" …;
    /// - a name already taken by the very same words is that copy, kept on an earlier try that
    ///   was cut short before iCloud's list was cleared. It is counted, not written twice.
    @discardableResult
    func keepParkedCopies(of relativePath: String, versions: [ParkedVersion], now: Date = Date()) throws -> [Note] {
        let note = try loadNote(relativePath: relativePath)
        var seen: [String] = [note.text]
        var copies: [Note] = []
        for version in versions {
            var other = note
            other.text = version.text
            guard !seen.contains(other.text) else { continue }
            seen.append(other.text)
            let date = version.modifiedAt ?? now
            var number = 1
            while true {
                let path = Self.conflictCopyPath(for: relativePath, at: date, number: number)
                if !CloudFiles.exists(url(for: path)) {
                    var copy = other
                    copy.relativePath = path
                    copy.modifiedAt = nil
                    copies.append(try save(copy, force: true))
                    break
                }
                if let there = try? loadNote(relativePath: path), there.text == other.text {
                    copies.append(there)
                    break
                }
                number += 1
            }
        }
        return copies
    }

    /// The name `saveConflictCopy` gives, with a number after the time from the second one on.
    static func conflictCopyPath(for relativePath: String, at date: Date, number: Int = 1) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        let base = relativePath.hasSuffix(".md") ? String(relativePath.dropLast(3)) : relativePath
        let suffix = number > 1 ? " \(number)" : ""
        return "\(base) (conflict \(formatter.string(from: date))\(suffix)).md"
    }

    /// Asks iCloud whether it has parked versions of these notes, keeps each as a conflict copy,
    /// and only then marks it settled and removes it from iCloud's list.
    ///
    /// **Blocks the calling thread** — a parked version may have to be fetched first — so the app
    /// calls it on a background thread, on a `Vault` of its own. A version that cannot be read is
    /// left exactly as it was and its note is named in `notYet`.
    func settleParkedVersions(of relativePaths: [String]) -> ParkedVersionsFound {
        var found = ParkedVersionsFound()
        for path in relativePaths {
            let fileURL = url(for: path)
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let parked = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL), !parked.isEmpty else { continue }
            // The note itself has to be here and current: a copy is "the other version", and
            // which one is the other is only known once the winning one has arrived.
            guard CloudFiles.presence(of: fileURL) == .here, let note = try? loadNote(relativePath: path) else {
                found.notYet.append(path)
                continue
            }
            var readable: [(NSFileVersion, ParkedVersion)] = []
            for version in parked {
                guard let data = try? CloudFiles.read(version.url, waitingUpTo: CloudFiles.longestWait),
                      let text = Self.decodeText(data) else { continue }
                readable.append((version, ParkedVersion(text: text, modifiedAt: version.modificationDate,
                                                        device: version.localizedNameOfSavingComputer)))
            }
            if readable.count < parked.count { found.notYet.append(path) }
            guard !readable.isEmpty,
                  let copies = try? keepParkedCopies(of: path, versions: readable.map(\.1)) else {
                if !found.notYet.contains(path) { found.notYet.append(path) }
                continue
            }
            for copy in copies {
                found.kept.append(.init(note: path, noteTitle: note.displayTitle,
                                        copy: copy.relativePath, copyTitle: copy.fileName))
            }
            // Only now, with every readable version safely in a file of its own.
            for (version, _) in readable {
                version.isResolved = true
                try? version.remove()
            }
        }
        return found
    }
}
