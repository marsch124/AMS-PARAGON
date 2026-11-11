import Foundation

/// Apple Pencil sketches (build 288). A sketch is a PNG in the vault's `Sketches` folder, with a
/// `.drawing` file of the same name beside it so it can be drawn on again. The note holds an
/// ordinary markdown image line, `![Sketch](../Sketches/Sketch%202026-11-11%20114005.png)`,
/// relative to the note, so Obsidian and other markdown apps show the picture too.
public enum Sketches {
    /// The vault folder the sketches live in.
    public static let folder = "Sketches"

    /// `![alt](path)` — the path may be wrapped in `<…>` and may carry `%20`.
    static let imageRegex = try! NSRegularExpression(pattern: #"!\[[^\]\n]*\]\(<?([^)>\n]+?)>?\)"#)

    /// The sketches a note links to, as paths from the vault's root (`Sketches/Sketch ….png`),
    /// in the order they appear, each once. Only pictures in the Sketches folder count.
    public static func links(in text: String, notePath: String) -> [String] {
        let ns = text as NSString
        var seen = Set<String>()
        var result: [String] = []
        for m in imageRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let raw = ns.substring(with: m.range(at: 1))
            let decoded = raw.removingPercentEncoding ?? raw
            guard let path = resolve(decoded, from: notePath),
                  path.hasPrefix(folder + "/"), path.lowercased().hasSuffix(".png"),
                  seen.insert(path).inserted else { continue }
            result.append(path)
        }
        return result
    }

    /// A new file name, from the moment it is made: `Sketch 2026-11-11 114005.png`.
    public static func newFileName(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "Sketch %04d-%02d-%02d %02d%02d%02d.png",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    /// Where the drawing that can be edited again sits: the picture's name with `.drawing`.
    public static func drawingPath(for picturePath: String) -> String {
        (picturePath as NSString).deletingPathExtension + ".drawing"
    }

    /// The markdown line for a picture in the Sketches folder (or `folder`), as seen from
    /// the note.
    public static func link(toFile fileName: String, fromNote notePath: String,
                            folder: String = Sketches.folder, alt: String = "Sketch") -> String {
        let depth = notePath.split(separator: "/").count - 1
        let up = String(repeating: "../", count: max(depth, 0))
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        return "![\(alt)](\(up)\(folder)/\(encoded))"
    }

    /// The link on a line of its own where the cursor is. Returns the text and where the
    /// cursor goes (the start of the line after the link).
    public static func inserting(link: String, into text: String, at offset: Int) -> (text: String, cursor: Int) {
        let ns = text as NSString
        let at = min(max(offset, 0), ns.length)
        let needsBreakBefore = at > 0 && ns.character(at: at - 1) != 10
        let needsBreakAfter = at < ns.length && ns.character(at: at) != 10
        let insert = (needsBreakBefore ? "\n" : "") + link + "\n" + (needsBreakAfter ? "" : "")
        let result = ns.replacingCharacters(in: NSRange(location: at, length: 0), with: insert)
        return (result, at + (insert as NSString).length)
    }

    /// A path relative to the note, made relative to the vault's root. Nil when it leaves
    /// the vault or is a web address.
    static func resolve(_ path: String, from notePath: String) -> String? {
        guard !path.contains("://"), !path.hasPrefix("/") else { return nil }
        var parts = notePath.split(separator: "/").map(String.init).dropLast()
        for piece in path.split(separator: "/").map(String.init) {
            switch piece {
            case ".", "": continue
            case "..":
                guard !parts.isEmpty else { return nil }
                parts.removeLast()
            default: parts.append(piece)
            }
        }
        return parts.joined(separator: "/")
    }
}

/// Pictures inside the text (build 289): every `![…](path)` to a picture file in the vault —
/// sketches, photos, pictures added in Obsidian — with where it is and the file it means.
public enum Pictures {
    public static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "gif"]

    public struct Match: Equatable, Sendable {
        /// The whole `![…](…)` in the text.
        public var range: NSRange
        /// The file, from the vault's root.
        public var path: String
    }

    /// Every picture link in `text`, in order.
    public static func matches(in text: String, notePath: String) -> [Match] {
        let ns = text as NSString
        return Sketches.imageRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let raw = ns.substring(with: m.range(at: 1))
            let decoded = raw.removingPercentEncoding ?? raw
            guard let path = Sketches.resolve(decoded, from: notePath), isPicture(path) else { return nil }
            return Match(range: m.range, path: path)
        }
    }

    public static func isPicture(_ path: String) -> Bool {
        extensions.contains((path as NSString).pathExtension.lowercased())
    }

    /// A sketch can be drawn on again: it is in the Sketches folder.
    public static func isSketch(_ path: String) -> Bool { path.hasPrefix(Sketches.folder + "/") }

    /// Photos (build 289): the folder, and a name from the moment it is taken.
    public static let photoFolder = "Photos"
    public static func newPhotoName(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let sketch = Sketches.newFileName(at: date, calendar: calendar)
        return "Photo" + sketch.dropFirst("Sketch".count).dropLast(".png".count) + ".jpg"
    }
}

/// Build 290: captions and pictures dropped in from Finder.
public extension Pictures {
    /// The words a picture gets by itself; they are not shown as a caption.
    static let plainWords: Set<String> = ["", "sketch", "photo", "picture", "image"]

    /// The caption of a `![…](…)` link: its alt text, unless that is one of the plain words.
    static func caption(ofLink link: String) -> String? {
        guard link.hasPrefix("!["), let close = link.range(of: "](") else { return nil }
        let alt = link[link.index(link.startIndex, offsetBy: 2)..<close.lowerBound]
            .trimmingCharacters(in: .whitespaces)
        return plainWords.contains(alt.lowercased()) ? nil : alt
    }

    /// The link with a new caption. An empty caption gives the plain word "Picture" back;
    /// `]`, `[` and line breaks are left out, since they would break the link.
    static func settingCaption(_ caption: String, inLink link: String) -> String {
        guard link.hasPrefix("!["), let close = link.range(of: "](") else { return link }
        let cleaned = caption.components(separatedBy: CharacterSet(charactersIn: "[]\n\r")).joined()
            .trimmingCharacters(in: .whitespaces)
        return "![" + (cleaned.isEmpty ? "Picture" : cleaned) + link[close.lowerBound...]
    }

    /// Pictures dragged in from Finder are copied here.
    static let droppedFolder = "Pictures"

    /// `name` if it is free, else `name 2.ext`, `name 3.ext` …
    static func freeName(for name: String, taken: Set<String>) -> String {
        guard taken.contains(name) else { return name }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            if !taken.contains(candidate) { return candidate }
            n += 1
        }
    }
}

/// Build 293: pictures pasted with ⌘V, and the gallery of a note's pictures.
public extension Pictures {
    /// A pasted picture's name, from the moment it is pasted: `Pasted 2026-11-11 201405.png`.
    /// Build 294: the iPhone and iPad paste a JPEG (`ext` "jpg").
    static func pastedName(at date: Date = Date(), calendar: Calendar = .current, ext: String = "png") -> String {
        "Pasted" + Sketches.newFileName(at: date, calendar: calendar).dropFirst("Sketch".count).dropLast("png".count) + ext
    }

    /// Build 294: the gallery's order changed by a drag — `moving` takes `onto`'s place and the
    /// pictures between shift along. Each picture's first line moves into another picture's
    /// slot; the words around them stay where they were. Unknown paths change nothing.
    static func reordering(_ text: String, notePath: String, moving: String, onto: String) -> String {
        guard moving != onto else { return text }
        var seen = Set<String>()
        let firsts = matches(in: text, notePath: notePath).filter { seen.insert($0.path).inserted }
        guard let from = firsts.firstIndex(where: { $0.path == moving }),
              let to = firsts.firstIndex(where: { $0.path == onto }) else { return text }
        let ns = text as NSString
        var links = firsts.map { ns.substring(with: $0.range) }
        links.insert(links.remove(at: from), at: to)
        let out = NSMutableString(string: text)
        for (slot, link) in zip(firsts, links).reversed() {
            out.replaceCharacters(in: slot.range, with: link)
        }
        return out as String
    }

    /// The pictures for a note's gallery: each file once, in the order they appear. Empty
    /// below two — one picture is already in plain sight in the text.
    static func galleryPaths(in text: String, notePath: String) -> [String] {
        var seen = Set<String>()
        let paths = matches(in: text, notePath: notePath).map(\.path).filter { seen.insert($0).inserted }
        return paths.count >= 2 ? paths : []
    }
}

/// Build 290: how far a day is from today, in words, for a daily note's band.
public enum DayDistance {
    public static func words(from day: DateOnly, to today: DateOnly, calendar: Calendar = .current) -> String {
        guard let a = day.date(calendar: calendar), let b = today.date(calendar: calendar) else { return "" }
        let n = calendar.dateComponents([.day], from: b, to: a).day ?? 0
        switch n {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case let n where n > 1: return "In \(n) days"
        default: return "\(-n) days ago"
        }
    }
}
