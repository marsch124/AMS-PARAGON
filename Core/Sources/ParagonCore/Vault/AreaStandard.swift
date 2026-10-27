import Foundation

/// An area's **Standard** (build 271, idea 4 "Areas come alive"): what "good" looks like in
/// that area, written by him under `## Standard` in the area note. For example "Three runs a
/// week, one rest day, a yearly check-up."
///
/// **Where it lives.** In the note's own text, as a section — the shape `DayPlan` (`## Plan`)
/// and `DayLog` (`## Looking back`) have. The Area template has shipped the section since the
/// first build, with one question under it, so every area he ever made already has the heading
/// and nothing under it that is his.
///
/// **The template's question is not a standard.** "What does "good" look like in this area?" is
/// there to be answered, so reading it back as the standard would make every new area claim a
/// standard it does not have, and the review would show a question as an answer (build 100's
/// rule: an absence must never look like a presence). Lines that are only a **placeholder** are
/// left out when the section is read: the shipped line always, and the Standard lines of every
/// area template in his vault, since he may have reworded his. They are compared with case,
/// curly and straight quotes, and runs of spaces folded.
///
/// **In Core, with tests, because it decides a stored value and the words on two screens**: the
/// area's page and step 6 of the Weekly review. Section finding is `MarkdownSection.find` (build
/// 223), never a second parser.
public enum AreaStandard {
    public static let heading = "## Standard"

    /// The lines the shipped **Area** template puts under its `## Standard` heading, read out of
    /// `Templates.area` itself so the two can never disagree.
    public static let shippedPlaceholders: [String] = placeholders(inTemplate: Templates.area)

    // MARK: Reading

    /// What is written under `## Standard`, or nil when nothing is.
    ///
    /// **Nil covers two cases on purpose**: the heading is missing, and the heading is there with
    /// nothing under it but the template's question. For him both are "no standard written yet".
    /// `extra` are the placeholder lines of the area templates in his vault.
    public static func text(in note: Note, placeholders extra: [String] = []) -> String? {
        let found = MarkdownSection.find(heading, in: note.body)
        guard found.range != nil else { return nil }
        let known = knownPlaceholders(for: note, extra: extra)
        let kept = found.lines.filter { !known.contains(folded($0)) }
        let clean = cleaned(kept.joined(separator: "\n"))
        return clean.isEmpty ? nil : clean
    }

    /// The non-empty lines under `## Standard` in a template's text: what that template asks
    /// the writer to answer.
    public static func placeholders(inTemplate text: String) -> [String] {
        MarkdownSection.find(heading, in: Frontmatter.parse(text).body).lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The first sentence of a standard, for a place with room for one line or two.
    ///
    /// - The first line that has words in it, with a leading `- `, `* ` or `1. ` removed.
    /// - Cut after the first `.`, `!` or `?` that ends a word (followed by a space, a closing
    ///   quote or bracket, or the end of the line), so "3.5 km" is not cut in two.
    /// - **A "…" only when something was cut off**: the rest of that line, or any later line.
    ///   After a full stop it stands apart ("Three walks a week. …"); after a line with no stop
    ///   it follows the word ("Three walks a week…").
    public static func firstSentence(of text: String) -> String {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let at = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return ""
        }
        let first = withoutListMarker(lines[at].trimmingCharacters(in: .whitespaces))
        let laterLines = lines[(at + 1)...].contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let characters = Array(first)
        var stop: Int?
        for position in characters.indices where sentenceMarks.contains(characters[position]) {
            let next = position + 1
            if next >= characters.count || characters[next].isWhitespace || closers.contains(characters[next]) {
                stop = position
                break
            }
        }
        guard let stop else {
            return laterLines ? first + "\u{2026}" : first
        }
        var end = stop + 1
        while end < characters.count, closers.contains(characters[end]) { end += 1 }
        let sentence = String(characters[0..<end])
        let rest = String(characters[end...]).trimmingCharacters(in: .whitespaces)
        return (!rest.isEmpty || laterLines) ? sentence + " \u{2026}" : sentence
    }

    // MARK: Writing

    /// The note with `text` as its standard, and nothing else in the note touched.
    ///
    /// - **The section is replaced**, the template's question with it: what he sees in the box
    ///   is the standard without the question, and what he saves is the whole section.
    /// - **A missing section is made above the first `## ` heading** (above `## Tasks` in a note
    ///   from the template), so any prose under the title stays above it and never becomes part
    ///   of the standard. With no `## ` heading at all it goes at the end.
    /// - **Empty text takes the section out, heading and all**, when there was a standard — the
    ///   rule of `DayLog` (build 223): a heading with nothing under it is a promise the note
    ///   does not keep. When nothing was written, empty text changes nothing: pressing Save on an
    ///   empty box must not delete the template's question.
    /// - **The same text again changes nothing**, so a second save does not touch the file.
    public static func note(_ note: Note, settingText text: String, placeholders extra: [String] = []) -> Note {
        let clean = cleaned(text)
        let current = Self.text(in: note, placeholders: extra)
        if clean.isEmpty {
            guard current != nil else { return note }
        } else if clean == current {
            return note
        }

        var updated = note
        var lines = note.body.components(separatedBy: "\n")
        let found = MarkdownSection.find(heading, in: note.body)
        let textLines = clean.components(separatedBy: "\n")

        if let range = found.range {
            let headingLine = max(range.lowerBound - 1, 0)
            if clean.isEmpty {
                lines.removeSubrange(headingLine..<range.upperBound)
                // Two blank lines can meet where the section was. That one seam is closed and
                // nothing else (DayLog's rule): collapsing every run of blank lines in the note
                // would be rewriting his own prose.
                if headingLine > 0, headingLine < lines.count,
                   lines[headingLine - 1].trimmingCharacters(in: .whitespaces).isEmpty,
                   lines[headingLine].trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.remove(at: headingLine)
                }
            } else {
                // A blank line under the heading and one after the text, so the section still
                // reads as markdown.
                lines.replaceSubrange(range, with: [""] + textLines + [""])
            }
        } else if let above = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("## ") }) {
            var piece = [heading, ""] + textLines + [""]
            if above > 0, !lines[above - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                piece.insert("", at: 0)
            }
            lines.insert(contentsOf: piece, at: above)
        } else {
            while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
            lines.append("")
            lines.append(heading)
            lines.append("")
            lines.append(contentsOf: textLines)
            lines.append("")
        }
        updated.body = lines.joined(separator: "\n")
        return updated
    }

    /// What would be stored for these words: line endings made plain, blank space at either end
    /// removed. The one rule, so what the box compares and what the note holds cannot differ.
    public static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Placeholders

    /// A line made comparable: lower case, curly quotes made straight, runs of spaces (of any
    /// kind) made one.
    static func folded(_ line: String) -> String {
        var text = line.lowercased()
        for curly in ["\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}"] {
            text = text.replacingOccurrences(of: curly, with: "\"")
        }
        for curly in ["\u{2018}", "\u{2019}", "\u{201A}", "\u{201B}"] {
            text = text.replacingOccurrences(of: curly, with: "'")
        }
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The placeholder lines for one note, folded. A template line may hold `{{title}}` or
    /// `{{date}}`, which the note has already had filled in, so each line is also compared in
    /// its filled-in form.
    private static func knownPlaceholders(for note: Note, extra: [String]) -> Set<String> {
        let day = note.createdDate ?? DateOnly.today()
        var known = Set<String>()
        for line in shippedPlaceholders + extra {
            known.insert(folded(line))
            known.insert(folded(Templates.fill(line, title: note.title, date: day)))
        }
        known.remove("")
        return known
    }

    // MARK: Small pieces

    private static let sentenceMarks: Set<Character> = [".", "!", "?"]
    /// What may close a sentence after its stop: `Does it feel "good."`, `(see below.)`.
    private static let closers: Set<Character> = ["\"", "\u{201D}", "\u{2019}", "'", ")", "]"]

    /// `- `, `* ` or `1. ` (or `1) `) at the start of a line removed.
    private static func withoutListMarker(_ line: String) -> String {
        for marker in ["- ", "* "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        let digits = line.prefix(while: { $0.isNumber })
        if !digits.isEmpty {
            let rest = line.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return line
    }
}

public extension Vault {
    /// The Standard lines of every **area** template in the Templates folder: what his own
    /// templates ask under `## Standard`. Only area templates are read, and only the ones in the
    /// list handed in (which `templates()` has already sorted by kind), so this adds a file read
    /// or two to a refresh that already reads every template (build 261's rule: nothing here
    /// waits for iCloud any longer than the existing read does).
    func areaStandardPlaceholders(among templates: [TemplateFile]) -> [String] {
        var lines: [String] = []
        for file in templates where file.kind == .area {
            guard let text = templateText(named: file.name) else { continue }
            for line in AreaStandard.placeholders(inTemplate: text) where !lines.contains(line) {
                lines.append(line)
            }
        }
        return lines
    }
}
