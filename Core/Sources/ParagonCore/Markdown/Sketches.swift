import Foundation
import CoreGraphics

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

/// Build 295: Copy words on a picture, and how far a picture opened big can zoom.
public extension Pictures {
    /// What Copy words puts on the clipboard: the words read in the picture, without blank
    /// lines at either end; nil when nothing was read (the picture has no words).
    static func wordsToCopy(_ read: String?) -> String? {
        guard let read else { return nil }
        let words = read.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? nil : words
    }

    /// The most a picture opened big can be enlarged, and where a double-tap takes it.
    static let maxZoom: Double = 5
    static let doubleTapZoom: Double = 2.5

    /// A pinch's zoom kept between normal size and `maxZoom`.
    static func zoom(_ scale: Double) -> Double { min(max(scale, 1), maxZoom) }

    /// Build 297: the gallery's search — the pictures whose words hold every word typed,
    /// in their order. An empty search keeps them all.
    static func filtered(_ paths: [String], by search: String, pictureText: [String: String]) -> [String] {
        let terms = search.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return paths }
        return paths.filter { path in
            guard let words = pictureText[path]?.lowercased() else { return false }
            return terms.allSatisfy { words.contains($0) }
        }
    }

    /// Build 297: a box dragged over a picture shown to fit in `frame`, as the part of the
    /// picture it covers — 0…1 with the origin at the bottom left, as Apple's text reading
    /// wants it. nil when the box misses the picture or is too small to hold a word.
    static func region(of box: CGRect, imageSize: CGSize, frame: CGSize) -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0, frame.width > 0, frame.height > 0 else { return nil }
        let fit: CGFloat = min(frame.width / imageSize.width, frame.height / imageSize.height)
        let w: CGFloat = imageSize.width * fit
        let h: CGFloat = imageSize.height * fit
        let shown = CGRect(x: (frame.width - w) / 2, y: (frame.height - h) / 2, width: w, height: h)
        let part = box.standardized.intersection(shown)
        guard !part.isNull, part.width >= 8, part.height >= 8 else { return nil }
        return CGRect(x: (part.minX - shown.minX) / shown.width,
                      y: 1 - (part.maxY - shown.minY) / shown.height,
                      width: part.width / shown.width,
                      height: part.height / shown.height)
    }

    /// Build 296: Show words — a picture's words written into the note as a quote, on the
    /// lines straight after the line that holds the picture (`linkAt` = where its link starts,
    /// in the markdown). Blank lines inside the words are left out.
    static func showingWords(_ words: String, in text: String, linkAt: Int) -> String {
        let ns = text as NSString
        guard linkAt >= 0, linkAt <= ns.length else { return text }
        let lineEnd = ns.lineRange(for: NSRange(location: linkAt, length: 0))
        var end = NSMaxRange(lineEnd)
        let quote = words.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "> " + $0 }
            .joined(separator: "\n")
        guard !quote.isEmpty else { return text }
        var insert = quote + "\n"
        // The last line of the note has no line break yet: give it one first.
        if end == ns.length, !text.hasSuffix("\n") { insert = "\n" + insert }
        if end > ns.length { end = ns.length }
        return ns.replacingCharacters(in: NSRange(location: end, length: 0), with: insert)
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
