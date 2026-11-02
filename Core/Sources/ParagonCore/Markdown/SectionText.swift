import Foundation

/// One `## Heading` section of a note that holds **a few words of his own**, and the rules for
/// reading and writing them (build 277).
///
/// **Why this is its own type.** An area's **Standard** (build 271) was the first section of
/// this kind: a question sits under the heading in the shipped template, and what he writes
/// replaces it. A goal's **Why** is the second. Reading, writing and "is this line only the
/// template's question?" are the same three decisions in both, so they are decided in one
/// place — two copies of this would be how two parts of the app come to disagree about one
/// file (build 168). `AreaStandard` and `NoteReason` are thin: each names its heading and its
/// template, and keeps what only it needs.
///
/// **The template's question is not an answer.** "What changes in my life when this is true?"
/// is there to be answered, so reading it back as his reason would make every new goal claim a
/// reason it does not have (build 100's rule: an absence must never look like a presence).
/// Lines that are only a **placeholder** are left out when the section is read: the shipped
/// template's lines always, and the lines of his own templates of that kind, which he may have
/// reworded. They are compared with case, curly and straight quotes, and runs of spaces folded.
///
/// Section finding is `MarkdownSection.find` (build 223), never a second parser.
struct SectionText: Sendable {
    /// The heading, with its `## `, exactly as the shipped template spells it.
    let heading: String
    /// The non-empty lines the shipped template puts under that heading, read out of the
    /// template itself so the two can never disagree.
    let shippedPlaceholders: [String]

    init(heading: String, template: String) {
        self.heading = heading
        self.shippedPlaceholders = SectionText.placeholderLines(under: heading, inTemplate: template)
    }

    // MARK: Reading

    /// What is written under the heading, or nil when nothing is.
    ///
    /// **Nil covers two cases on purpose**: the heading is missing, and the heading is there with
    /// nothing under it but the template's question. For him both are "nothing written yet".
    /// `extra` are the placeholder lines of his own templates of that kind.
    func text(in note: Note, placeholders extra: [String]) -> String? {
        let found = MarkdownSection.find(heading, in: note.body)
        guard found.range != nil else { return nil }
        let known = knownPlaceholders(for: note, extra: extra)
        let kept = found.lines.filter { !known.contains(SectionText.folded($0)) }
        let clean = SectionText.cleaned(kept.joined(separator: "\n"))
        return clean.isEmpty ? nil : clean
    }

    /// The non-empty lines under the heading in a template's text: what that template asks the
    /// writer to answer.
    func placeholders(inTemplate text: String) -> [String] {
        SectionText.placeholderLines(under: heading, inTemplate: text)
    }

    static func placeholderLines(under heading: String, inTemplate text: String) -> [String] {
        MarkdownSection.find(heading, in: Frontmatter.parse(text).body).lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: Writing

    /// The note with `text` under the heading, and nothing else in the note touched.
    ///
    /// - **The section is replaced**, the template's question with it: what he sees in the box
    ///   is his words without the question, and what he saves is the whole section.
    /// - **A missing section is made above the first `## ` heading**, so any prose under the
    ///   title stays above it and never becomes part of what is read back. With no `## `
    ///   heading at all it goes at the end.
    /// - **Empty text takes the section out, heading and all**, when something was written — the
    ///   rule of `DayLog` (build 223): a heading with nothing under it is a promise the note
    ///   does not keep. When nothing was written, empty text changes nothing: pressing Save on
    ///   an empty box must not delete the template's question.
    /// - **The same text again changes nothing**, so a second save does not touch the file.
    func note(_ note: Note, settingText text: String, placeholders extra: [String]) -> Note {
        let clean = SectionText.cleaned(text)
        let current = self.text(in: note, placeholders: extra)
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
    /// removed. The one rule, so what a box compares and what the note holds cannot differ.
    static func cleaned(_ text: String) -> String {
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
    private func knownPlaceholders(for note: Note, extra: [String]) -> Set<String> {
        let day = note.createdDate ?? DateOnly.today()
        var known = Set<String>()
        for line in shippedPlaceholders + extra {
            known.insert(SectionText.folded(line))
            known.insert(SectionText.folded(Templates.fill(line, title: note.title, date: day)))
        }
        known.remove("")
        return known
    }
}

extension Vault {
    /// The lines the templates of one kind put under a section's heading: what his own templates
    /// ask there. Only templates that make that `kind` are read, and only the ones in the list
    /// handed in (which `templates()` has already sorted by kind), so this adds a file read or
    /// two to a refresh that already reads every template (build 261's rule: nothing here waits
    /// for iCloud any longer than the existing read does). Each line once, in the order found.
    func placeholderLines(of section: SectionText, kind: ParaKind, among templates: [TemplateFile]) -> [String] {
        var lines: [String] = []
        for file in templates where file.kind == kind {
            guard let text = templateText(named: file.name) else { continue }
            for line in section.placeholders(inTemplate: text) where !lines.contains(line) {
                lines.append(line)
            }
        }
        return lines
    }
}
