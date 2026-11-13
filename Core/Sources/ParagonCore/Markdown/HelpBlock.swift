import Foundation

/// One block of a bundled help document (`Docs/*.md`): a title, a heading, a paragraph, a list
/// of bullets or a code block. Help draws these; **this file decides what they are**, so the
/// rule can be tested (build 272). It used to sit in `HelpView.swift`, where a hard-wrapped
/// bullet could not be tested at all.
public enum HelpBlock: Equatable, Sendable {
    case title(String)
    case heading(String)
    case subheading(String)
    case paragraph(String)
    case bullets([String])
    case code(String)

    /// Splits a document into blocks. It knows `#`, `##` and `###` headings, bullets that start
    /// with `- `, paragraphs and fenced code, which is all the documents use.
    ///
    /// **A bullet goes on over the lines that follow it when they are indented to where its
    /// words start** (build 272). The documents are hard-wrapped at about 95 columns, so a long
    /// bullet is written over several lines with the later ones indented two spaces — and the
    /// parser used to end the bullet at the first line break and draw the rest as a plain
    /// paragraph under it. That is why the newest bullets in the manual were written one line
    /// each. Now the lines are joined with a space, as a paragraph's are.
    ///
    /// - Where a bullet's words start is its own indent plus two for the `- `. A line indented
    ///   less than that is **not** a continuation of it: after a sub-bullet, a line at the
    ///   parent's indent ("**Done** saves the line…" in the Close the day part of the manual)
    ///   stays a paragraph, as it always was, and is not glued onto the sub-bullet.
    /// - A line with no indent after a bullet ends the bullets and starts a paragraph, as
    ///   before. The documents have none today; it is the old behaviour and the safe one.
    /// - A blank line ends a bullet, so an indented paragraph after a blank line is a paragraph.
    /// - A line starting with `- ` is a new bullet whatever its indent: the lists are drawn
    ///   flat, a sub-bullet being one more bullet.
    public static func parse(_ text: String) -> [HelpBlock] {
        var blocks: [HelpBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        /// The column the last bullet's words start in. Only meaningful while `bullets` is not empty.
        var bulletWordsColumn = 0
        var code: [String]?

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let open = code {
                if line.hasPrefix("```") { blocks.append(.code(open.joined(separator: "\n"))); code = nil }
                else { code?.append(rawLine) }
                continue
            }
            if line.hasPrefix("```") { flush(); code = []; continue }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("# ") { flush(); blocks.append(.title(String(line.dropFirst(2)))); continue }
            if line.hasPrefix("### ") { flush(); blocks.append(.subheading(String(line.dropFirst(4)))); continue }
            if line.hasPrefix("## ") { flush(); blocks.append(.heading(String(line.dropFirst(3)))); continue }
            if line.hasPrefix("- ") {
                if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
                bullets.append(String(line.dropFirst(2)))
                bulletWordsColumn = indent(of: rawLine) + 2
                continue
            }
            if !bullets.isEmpty {
                if indent(of: rawLine) >= bulletWordsColumn {
                    // The bullet goes on. The last item is the one this line belongs to.
                    bullets[bullets.count - 1] += " " + line
                    continue
                }
                blocks.append(.bullets(bullets))
                bullets = []
            }
            paragraph.append(line)
        }
        if let open = code { blocks.append(.code(open.joined(separator: "\n"))) }
        flush()
        return blocks
    }

    /// How far a line is indented, counted in columns. A tab counts as four, which is what an
    /// editor shows; the documents use spaces.
    private static func indent(of rawLine: String) -> Int {
        var columns = 0
        for character in rawLine {
            if character == " " {
                columns += 1
            } else if character == "\t" {
                columns += 4
            } else {
                break
            }
        }
        return columns
    }

    /// The words in this block, for searching.
    public var text: String {
        switch self {
        case .title(let text), .heading(let text), .subheading(let text),
             .paragraph(let text), .code(let text):
            return text
        case .bullets(let items):
            return items.joined(separator: "\n")
        }
    }
}

/// **Dates in a help heading, written as everywhere else in the app** (round 9, build 316).
/// The list of versions is written by hand with headings like "Build 315 · 13 November 2026";
/// on screen that reads "Build 315 · 2026-11-13". The file is not changed, only how the
/// heading is shown. "7-8 September 2026" becomes "2026-09-07 to 2026-09-08".
public enum HelpDates {
    private static let months = ["January", "February", "March", "April", "May", "June", "July",
                                 "August", "September", "October", "November", "December"]

    public static func plain(_ heading: String) -> String {
        let pattern = "(?:\\b(\\d{1,2})\\s?[-\u{2013}]\\s?)?\\b(\\d{1,2}) (" + months.joined(separator: "|") + ") (\\d{4})\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return heading }
        let whole = heading as NSString
        var result = heading
        // From the end, so the places found earlier in the line stay where they are.
        for match in regex.matches(in: heading, range: NSRange(location: 0, length: whole.length)).reversed() {
            guard let day = Int(whole.substring(with: match.range(at: 2))),
                  let month = months.firstIndex(of: whole.substring(with: match.range(at: 3))),
                  let year = Int(whole.substring(with: match.range(at: 4))),
                  (1...31).contains(day) else { continue }
            func written(_ day: Int) -> String { String(format: "%04d-%02d-%02d", year, month + 1, day) }
            var words = written(day)
            if match.range(at: 1).location != NSNotFound, let first = Int(whole.substring(with: match.range(at: 1))),
               (1...31).contains(first) {
                words = written(first) + " to " + words
            }
            result = (result as NSString).replacingCharacters(in: match.range, with: words)
        }
        return result
    }
}
