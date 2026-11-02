import Foundation

/// A goal's **Reason** (build 277, his answer A1 "Yes, build it"): why this matters, in his own
/// words, written under `## Why` in the goal note. For an aspiration it is the sentence he reads
/// at the top of the aspiration's page — "Still walking long days in the fells at 80, with the
/// people I love."
///
/// **It was always written and never shown.** Every goal note is made from the Goal template,
/// which has a `## Why` heading with one question under it: "What changes in my life when this
/// is true?". He answers it once, in the note, and no screen read the answer again — although an
/// aspiration is "the top, most important things in my life" (his words, build 199). This type is
/// the reader, and the writer that goes with it (the rule of builds 132 to 144: a screen that
/// shows a field needs the control that writes it, and the control needs the screen).
///
/// **The shape is an area's Standard** (build 271), and the rules are `SectionText`'s, shared with
/// it: the template's question is not an answer, so a goal nobody has answered reads as having no
/// reason; writing replaces the section, question and all; empty words take it out only when
/// something was written; the same words again change nothing. **The word on screen is
/// "Reason"**, the heading in the file is `## Why`: the template asks a question and the page
/// shows what answers it.
///
/// **Only an aspiration's page shows it so far.** Nothing here asks which kind of goal a note is,
/// so the same box could be put on a goal with a date's page in one line.
///
/// **In Core, with tests, because it decides a stored value and the words on screen.** Section
/// finding is `MarkdownSection.find` (build 223), never a second parser.
public enum NoteReason {
    public static let heading = "## Why"

    /// The heading, the Goal template and the rules, in one value (`SectionText`).
    static let section = SectionText(heading: NoteReason.heading, template: Templates.goal)

    /// The lines the shipped **Goal** template puts under its `## Why` heading, read out of
    /// `Templates.goal` itself so the two can never disagree.
    public static let shippedPlaceholders: [String] = NoteReason.section.shippedPlaceholders

    // MARK: Reading

    /// What is written under `## Why`, or nil when nothing is.
    ///
    /// **Nil covers two cases on purpose**: the heading is missing, and the heading is there with
    /// nothing under it but the template's question. For him both are "no reason written yet".
    /// `extra` are the placeholder lines of the goal templates in his vault.
    public static func text(in note: Note, placeholders extra: [String] = []) -> String? {
        NoteReason.section.text(in: note, placeholders: extra)
    }

    /// The non-empty lines under `## Why` in a template's text: what that template asks the
    /// writer to answer.
    public static func placeholders(inTemplate text: String) -> [String] {
        NoteReason.section.placeholders(inTemplate: text)
    }

    // MARK: Writing

    /// The note with `text` as its reason, and nothing else in the note touched.
    ///
    /// - **The section is replaced**, the template's question with it.
    /// - **A missing section is made above the first other `## ` heading**, so prose under the
    ///   title stays above it; with no `## ` heading at all it goes at the end.
    /// - **Empty text takes the section out, heading and all**, but only when a reason was
    ///   written: Save on an empty box must not delete the template's question.
    /// - **The same text again changes nothing**, so a second save does not touch the file.
    public static func note(_ note: Note, settingText text: String, placeholders extra: [String] = []) -> Note {
        NoteReason.section.note(note, settingText: text, placeholders: extra)
    }

    /// What would be stored for these words: line endings made plain, blank space at either end
    /// removed. The one rule, so what the box compares and what the note holds cannot differ.
    public static func cleaned(_ text: String) -> String {
        SectionText.cleaned(text)
    }
}

public extension Vault {
    /// The Why lines of every **goal** template in the Templates folder: what his own templates
    /// ask under `## Why`. Aspirations and goals with a date are both `type: goal`, so both are
    /// read. Only goal templates are looked at (`templates()` has already sorted them by kind),
    /// so this adds a file read or two to a refresh that already reads every template.
    func goalReasonPlaceholders(among templates: [TemplateFile]) -> [String] {
        placeholderLines(of: NoteReason.section, kind: .goal, among: templates)
    }
}
