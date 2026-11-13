import Foundation

/// Build 318: pictures and PDFs shared into PARAGON from other apps (Share › PARAGON), and PDFs
/// in a note.
///
/// **Where a shared file is kept.** A picture goes where every picture dropped or pasted into a
/// note already goes, the vault's `Pictures` folder. A PDF goes into `Attachments`. The note
/// gets an ordinary markdown line — `- ![Picture](Pictures/IMG_0412.heic)` for a picture,
/// `- [Invoice.pdf](Attachments/Invoice.pdf)` for a PDF — with the path as seen from the note,
/// so Obsidian and every other markdown app show it too.
///
/// **How it gets there.** The share extension never writes into the vault: only the app holds
/// the permission for that folder. It copies each file, by file and never through memory, into
/// the App Group's `capture-files/<item id>/<n>/<name>` and appends one `CaptureItem` naming
/// them to the outbox. The app files the item the next time it is in front: each file is copied
/// into the vault under a name nothing there has, the lines are written, the note is saved, and
/// only then are the waiting copies removed.
public enum SharedFiles {
    /// The vault folder for PDFs.
    public static let attachmentsFolder = "Attachments"
    /// The folder beside the outbox the share extension copies into.
    public static let stagingFolder = "capture-files"
    /// The most files one share takes.
    public static let maxItems = 20
    /// A waiting copy nothing in the outbox names is cleared away once it is this old.
    public static let orphanAge: TimeInterval = 24 * 60 * 60

    public static func isPDF(_ path: String) -> Bool {
        (path as NSString).pathExtension.lowercased() == "pdf"
    }

    /// Pictures the app can show (png, jpg, jpeg, heic, gif) and PDFs.
    public static func accepts(_ name: String) -> Bool { Pictures.isPicture(name) || isPDF(name) }

    /// `Pictures` for a picture, `Attachments` for a PDF.
    public static func folder(for name: String) -> String {
        isPDF(name) ? attachmentsFolder : Pictures.droppedFolder
    }

    // MARK: Names

    /// What may not be in a file's name: the characters a folder path, a markdown link or an
    /// Obsidian link would trip over.
    private static let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|[]()#^%").union(.controlCharacters).union(.newlines)
    private static let uuidName = try! NSRegularExpression(
        pattern: #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"#)

    /// A name that is safe as a file and inside a markdown link: the last path component, the
    /// unsafe characters out, no dot or space at either end, at most 80 characters before the
    /// extension, the extension in small letters. A name with nothing left — or one that is
    /// only a random identifier — becomes `Shared 2026-11-13 101500`.
    public static func safeName(_ name: String, at date: Date = Date(), calendar: Calendar = .current) -> String {
        let last = (name.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
        let rawExt = (last as NSString).pathExtension
        let ext = String(rawExt.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.prefix(8))
        var base = rawExt.isEmpty ? last : (last as NSString).deletingPathExtension
        base = base.components(separatedBy: unsafe).joined(separator: " ")
        base = base.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        base = base.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if base.count > 80 { base = String(base.prefix(80)).trimmingCharacters(in: CharacterSet(charactersIn: ". ")) }
        let ns = base as NSString
        if base.isEmpty || uuidName.firstMatch(in: base, range: NSRange(location: 0, length: ns.length)) != nil {
            let stamp = Sketches.newFileName(at: date, calendar: calendar).dropFirst("Sketch".count).dropLast(".png".count)
            base = "Shared" + stamp
        }
        return ext.isEmpty ? base : base + "." + ext
    }

    /// The names a folder holds, from its listing. A file iCloud has not sent to this device is
    /// listed as `.Name.png.icloud`: its name is taken all the same.
    public static func takenNames(in listing: [String]) -> Set<String> {
        Set(listing.map { entry in
            guard entry.hasPrefix("."), entry.hasSuffix(".icloud"), entry.count > 8 else { return entry }
            return String(entry.dropFirst().dropLast(".icloud".count))
        })
    }

    /// `name` when nothing has it, else `name 2.ext`, `name 3.ext` … Small and capital letters
    /// count as the same name, as they do for the iPhone's and the Mac's folders.
    public static func freeName(for name: String, taken: Set<String>) -> String {
        func key(_ s: String) -> String { s.precomposedStringWithCanonicalMapping.lowercased() }
        let keys = Set(taken.map(key))
        guard keys.contains(key(name)) else { return name }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            if !keys.contains(key(candidate)) { return candidate }
            n += 1
        }
    }

    // MARK: The line in the note

    /// Words as they may stand between `[` and `]`: one line, no brackets.
    static func label(_ words: String) -> String {
        words.components(separatedBy: CharacterSet(charactersIn: "[]\n\r")).joined(separator: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The markdown link to a file kept in its folder, as seen from the note. A picture:
    /// `![words](../Pictures/name.png)`, with `Picture` when there are no words. A PDF:
    /// `[words](../Attachments/name.pdf)`, with the file's name when there are no words.
    public static func link(toFile fileName: String, fromNote notePath: String, words: String = "") -> String {
        let label = label(words)
        if isPDF(fileName) {
            let depth = notePath.split(separator: "/").count - 1
            let up = String(repeating: "../", count: max(depth, 0))
            let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
            return "[\(label.isEmpty ? fileName : label)](\(up)\(attachmentsFolder)/\(encoded))"
        }
        return Sketches.link(toFile: fileName, fromNote: notePath, folder: Pictures.droppedFolder,
                             alt: label.isEmpty ? "Picture" : label)
    }

    // MARK: Waiting copies (the App Group)

    /// Copies one shared file to wait for the app: `root/<item id>/<n>/<safe name>`. By file,
    /// never through memory. Returns the path from `root`, which is what the outbox item names.
    public static func stage(_ source: URL, named name: String, itemID: UUID, index: Int, root: URL,
                             at date: Date = Date()) throws -> String {
        let relative = "\(itemID.uuidString)/\(index)/\(safeName(name, at: date))"
        let target = root.appendingPathComponent(relative)
        let fm = FileManager.default
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: target)
        return relative
    }

    /// Where a waiting copy is. Nil for a path that would leave `root`.
    public static func stagedURL(_ relative: String, root: URL) -> URL? {
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !relative.isEmpty, !relative.hasPrefix("/"), !parts.contains(".."), !parts.contains("") else { return nil }
        return root.appendingPathComponent(relative)
    }

    /// Clears waiting copies nothing in the outbox names any more (a share that was closed
    /// half-way), once they are a day old. `keeping` = the ids of the items still waiting.
    public static func sweep(root: URL, keeping: Set<UUID>, now: Date = Date()) {
        let fm = FileManager.default
        let keep = Set(keeping.map(\.uuidString))
        let folders = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for folder in folders where !keep.contains(folder.lastPathComponent) {
            guard let changed = try? folder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  now.timeIntervalSince(changed) > orphanAge else { continue }
            try? fm.removeItem(at: folder)
        }
    }

    // MARK: Reading a note

    /// A picture or PDF a line points at.
    public struct Attachment: Equatable, Sendable {
        /// The file, from the vault's root.
        public var path: String
        /// The words between the brackets; empty for a picture's plain `Picture`.
        public var label: String
        public var isPicture: Bool
        public var fileName: String { (path as NSString).lastPathComponent }
    }

    static let linkRegex = try! NSRegularExpression(pattern: #"!?\[([^\]\n]*)\]\(<?([^)>\n]+?)>?\)"#)

    /// The picture or PDF a line is: the line holds one markdown link to a picture or a PDF in
    /// the vault and nothing else (a leading `- ` aside). Nil for every other line.
    public static func attachment(inLine line: String, notePath: String) -> Attachment? {
        var words = line.trimmingCharacters(in: .whitespaces)
        if words.hasPrefix("- ") || words.hasPrefix("* ") { words = String(words.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        let ns = words as NSString
        guard let m = linkRegex.firstMatch(in: words, range: NSRange(location: 0, length: ns.length)),
              m.range.location == 0, m.range.length == ns.length else { return nil }
        let raw = ns.substring(with: m.range(at: 2))
        guard let path = Sketches.resolve(raw.removingPercentEncoding ?? raw, from: notePath) else { return nil }
        let isImageLink = words.hasPrefix("!")
        let label = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        if Pictures.isPicture(path), isImageLink {
            return Attachment(path: path, label: Pictures.plainWords.contains(label.lowercased()) ? "" : label, isPicture: true)
        }
        if isPDF(path) { return Attachment(path: path, label: label, isPicture: false) }
        return nil
    }

    /// One PDF link in a note's text.
    public struct PDFMatch: Equatable, Sendable {
        /// The whole `[…](…)` in the text.
        public var range: NSRange
        /// The file, from the vault's root.
        public var path: String
        public var label: String
    }

    /// Every link to a PDF inside the vault, in order: `[words](Attachments/x.pdf)`, and the
    /// `![…](…)` spelling as well.
    public static func pdfMatches(in text: String, notePath: String) -> [PDFMatch] {
        let ns = text as NSString
        return linkRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let raw = ns.substring(with: m.range(at: 2))
            guard let path = Sketches.resolve(raw.removingPercentEncoding ?? raw, from: notePath), isPDF(path) else { return nil }
            return PDFMatch(range: m.range, path: path, label: ns.substring(with: m.range(at: 1)))
        }
    }

    /// `3 pages`, `1 page`; nothing when the count is not known.
    public static func pagesWords(_ count: Int?) -> String {
        guard let count, count > 0 else { return "PDF" }
        return count == 1 ? "PDF · 1 page" : "PDF · \(count) pages"
    }
}

public extension CaptureOutbox {
    /// The folder beside the outbox where shared files wait.
    var filesURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent(SharedFiles.stagingFolder, isDirectory: true)
    }
}

public extension CaptureItem {
    /// The lines a share with files writes under **Notes**, for the files that were put into
    /// the vault (`placed` = their names there, in order).
    ///
    /// Each file is a `- ` line of its own, so the Inbox lists it. The words he added become
    /// the caption of the first picture, or the name shown for the first PDF. When a web link
    /// came along as well, the words and the link are a line of their own first, exactly as a
    /// shared link is written, and the files follow plain.
    func fileLines(placed: [String], notePath: String) -> [String] {
        let words = SharedFiles.label(text)
        var lines: [String] = []
        var caption = words
        if url != nil || placed.isEmpty {
            if !lineText.isEmpty { lines.append("- " + lineText) }
            caption = ""
        }
        for (i, name) in placed.enumerated() {
            lines.append("- " + SharedFiles.link(toFile: name, fromNote: notePath, words: i == 0 ? caption : ""))
        }
        return lines
    }
}

extension Vault {
    /// Files a share that carries files into `note`: every waiting copy is copied into the
    /// vault under a name nothing there has — **never over a file that is there** — the lines
    /// are written under Notes and the note is saved. Only after that are the waiting copies
    /// removed. When the note cannot be saved, the copies just made are taken out again and
    /// the error is thrown, so the item stays in the outbox whole and a later try starts clean.
    /// A file that is no longer waiting, or is neither a picture nor a PDF, is left out.
    func fileShared(_ item: CaptureItem, into note: Note, filesRoot: URL?) throws -> Note {
        let fm = FileManager.default
        var note = note
        var placedNames: [String] = []
        var placedURLs: [URL] = []
        let sources: [URL] = (item.files ?? []).compactMap { relative in
            guard let filesRoot, SharedFiles.accepts(relative),
                  let source = SharedFiles.stagedURL(relative, root: filesRoot),
                  fm.fileExists(atPath: source.path) else { return nil }
            return source
        }
        do {
            for source in sources {
                let folder = SharedFiles.folder(for: source.lastPathComponent)
                let folderURL = rootURL.appendingPathComponent(folder, isDirectory: true)
                try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
                var taken = SharedFiles.takenNames(in: (try? fm.contentsOfDirectory(atPath: folderURL.path)) ?? [])
                var copied = false
                var lastError: Error = CocoaError(.fileWriteFileExists)
                // `copyItem` refuses a name that is taken, so a file that appeared since the
                // listing (iCloud, the other device) is never written over: the next name is tried.
                for _ in 0..<5 where !copied {
                    let name = SharedFiles.freeName(for: SharedFiles.safeName(source.lastPathComponent, at: item.createdAt), taken: taken)
                    let target = folderURL.appendingPathComponent(name)
                    do {
                        try fm.copyItem(at: source, to: target)
                        placedNames.append(name)
                        placedURLs.append(target)
                        copied = true
                    } catch {
                        lastError = error
                        guard fm.fileExists(atPath: target.path) else { throw error }
                        taken.insert(name)
                    }
                }
                if !copied { throw lastError }
            }
            let lines = item.fileLines(placed: placedNames, notePath: note.relativePath)
            guard !lines.isEmpty else { return note }
            for line in lines { note.appendLine(line, under: "Notes") }
            try save(note)
        } catch {
            for url in placedURLs { try? fm.removeItem(at: url) }
            throw error
        }
        if let filesRoot {
            try? fm.removeItem(at: filesRoot.appendingPathComponent(item.id.uuidString, isDirectory: true))
        }
        return note
    }
}
