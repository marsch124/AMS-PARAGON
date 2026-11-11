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

    /// The markdown line for a picture in the Sketches folder, as seen from the note.
    public static func link(toFile fileName: String, fromNote notePath: String) -> String {
        let depth = notePath.split(separator: "/").count - 1
        let up = String(repeating: "../", count: max(depth, 0))
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        return "![Sketch](\(up)\(folder)/\(encoded))"
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
