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
///
/// **Since build 277 the reading and writing live in `SectionText`**, which a goal's **Why**
/// (`NoteReason`) shares: this type names the heading and the template and keeps
/// `firstSentence`, which only a place with room for one line needs. Every test of build 271
/// still passes through here unchanged.
public enum AreaStandard {
    public static let heading = "## Standard"

    /// The heading, the Area template and the rules, in one value (`SectionText`).
    static let section = SectionText(heading: AreaStandard.heading, template: Templates.area)

    /// The lines the shipped **Area** template puts under its `## Standard` heading, read out of
    /// `Templates.area` itself so the two can never disagree.
    public static let shippedPlaceholders: [String] = AreaStandard.section.shippedPlaceholders

    // MARK: Reading

    /// What is written under `## Standard`, or nil when nothing is.
    ///
    /// **Nil covers two cases on purpose**: the heading is missing, and the heading is there with
    /// nothing under it but the template's question. For him both are "no standard written yet".
    /// `extra` are the placeholder lines of the area templates in his vault.
    public static func text(in note: Note, placeholders extra: [String] = []) -> String? {
        AreaStandard.section.text(in: note, placeholders: extra)
    }

    /// The non-empty lines under `## Standard` in a template's text: what that template asks
    /// the writer to answer.
    public static func placeholders(inTemplate text: String) -> [String] {
        AreaStandard.section.placeholders(inTemplate: text)
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
        AreaStandard.section.note(note, settingText: text, placeholders: extra)
    }

    /// What would be stored for these words: line endings made plain, blank space at either end
    /// removed. The one rule, so what the box compares and what the note holds cannot differ.
    public static func cleaned(_ text: String) -> String {
        SectionText.cleaned(text)
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
        placeholderLines(of: AreaStandard.section, kind: .area, among: templates)
    }
}
