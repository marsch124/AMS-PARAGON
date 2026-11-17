import Foundation

/// Build 337 (the advisors' "speed 3", the rest of it): **what a handful of files looked like
/// when they were last read** — each one's place, date and size, nothing of what is in them.
///
/// Every re-read of the notes (some sixty places ask for one, and the look for outside changes
/// asks every ten seconds) also read every template in full three times over, the snippets, the
/// made-but-unused tags and every Work note, although those change a few times a year. Now the
/// app keeps the stamp of what it read and reads again only when the stamp is another one — the
/// way build 330 did it for Deleted.
///
/// **Taken before the files are read, never after**: a file that changes between the two is
/// then newer than its stamp, the next look sees another stamp, and it is read again. The other
/// order could keep an old reading for good.
public struct FilesStamp: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        /// The whole path, so the same folder in another notes folder is another stamp.
        public let path: String
        /// Nil when the file is not there.
        public let modified: Date?
        public let size: Int

        public init(path: String, modified: Date?, size: Int) {
            self.path = path
            self.modified = modified
            self.size = size
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) { self.entries = entries }

    /// The files directly inside `folders` (not deeper, hidden ones too: an iCloud stub is a
    /// hidden file, and its arrival must change the stamp) and the single `files`. A folder or
    /// file that is not there is part of the stamp as well, so its appearing changes it.
    public static func of(folders: [URL], files: [URL] = []) -> FilesStamp {
        let fm = FileManager.default
        var entries: [Entry] = []
        for folder in folders {
            guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else {
                entries.append(Entry(path: folder.path, modified: nil, size: -1))
                continue
            }
            for name in names.sorted() {
                entries.append(entry(at: folder.appendingPathComponent(name).path, fm))
            }
        }
        for file in files { entries.append(entry(at: file.path, fm)) }
        return FilesStamp(entries: entries)
    }

    private static func entry(at path: String, _ fm: FileManager) -> Entry {
        guard let facts = try? fm.attributesOfItem(atPath: path) else {
            return Entry(path: path, modified: nil, size: -1)
        }
        return Entry(path: path,
                     modified: facts[.modificationDate] as? Date,
                     size: (facts[.size] as? NSNumber)?.intValue ?? -1)
    }
}

public extension Vault {
    /// What the templates, the snippets (they live in the Templates folder) and the
    /// made-but-unused tags are read from.
    var templatesStamp: FilesStamp { .of(folders: [templatesURL], files: [knownTagsURL]) }

    /// What the Work notes are read from.
    var workStamp: FilesStamp { .of(folders: [workURL]) }
}
