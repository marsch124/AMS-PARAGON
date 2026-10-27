import SwiftUI
import ParagonCore

// An area's Standard (build 271, idea 4 "Areas come alive"): what "good" looks like in this
// area, in one sentence at the top of the area's page and under the area's name in step 6 of
// the Weekly review.
//
// **What decides it is Core.** `AreaStandard` (tested) reads and writes the `## Standard`
// section of the note and leaves out the template's own question, so a new area says "No
// standard written yet" rather than showing a question as if it were an answer. This file only
// asks and draws.
//
// **A file of its own**, like `ProjectArea.swift` (build 269): `ContentView.swift`, `AppModel.swift`
// and `ReviewView.swift` are changed by other builds at the same time, so what is new lives here.

extension AppModel {
    /// What came of a try to write an area's standard.
    enum StandardWrite: Equatable {
        /// Written, or there was nothing to write because the words had not changed.
        case written
        /// The standard on file is no longer the one the box opened on (changed on the other
        /// device, or a newer copy came from iCloud while the box stood open). Nothing was
        /// written. `onFile` is what it says now; nil means it was taken away.
        case changedMeanwhile(onFile: String?)
        /// Could not be written. An alert says why; the box keeps his words (build 261).
        case notWritten
    }

    /// The standard written in an area note, or nil when there is none — the template's own
    /// question does not count. The template lines come from `refreshSnippets()`.
    func standard(of note: Note) -> String? {
        AreaStandard.text(in: note, placeholders: standardPlaceholders)
    }

    /// Writes the words as the area's standard. **Empty words take the standard away**, and do
    /// nothing at all when there was none (Core decides, `AreaStandard.note`).
    ///
    /// **`startedFrom` is the standard the box showed when it opened.** When the note now holds
    /// another one, nothing is written and the answer says what it holds; a second press then
    /// replaces it on purpose. A line he never saw is never replaced unseen — the rule of
    /// `setWeekGoal` (build 264) and `setMeasure` (build 268), whose reviews both found this
    /// fault after the first push.
    ///
    /// The editor's own unsaved text is written first, and the note is read back out of the
    /// model: a chip on the same page may have just saved it (build 144).
    @discardableResult
    func setStandard(_ text: String, on note: Note, startedFrom: String?) -> StandardWrite {
        flushPendingEdits()
        guard let live = self.note(at: note.relativePath) else {
            errorMessage = "\u{201C}\(note.displayTitle)\u{201D} is not in the vault any more, so its standard was not saved."
            return .notWritten
        }
        let clean = AreaStandard.cleaned(text)
        let wanted: String? = clean.isEmpty ? nil : clean
        let onFile: String? = standard(of: live)
        if onFile != startedFrom && onFile != wanted {
            return .changedMeanwhile(onFile: onFile)
        }
        let updated = AreaStandard.note(live, settingText: text, placeholders: standardPlaceholders)
        // The same words again write nothing (`setIcon`'s rule, build 254): a save would stamp
        // the file and send it round iCloud for nothing.
        guard updated != live else { return .written }
        guard save(updated) else { return .notWritten }
        reload()
        return .written
    }
}

/// The block at the top of an area's page: a **STANDARD** label, **Standard…**, and the first
/// sentence of what is written — or a dashed grey **No standard written yet** and **Write the
/// standard…**. Pressing the button opens the text in place, as **Goal for this week** does
/// (build 251): a field with **Save** and **Cancel**, and no sheet and no popover.
///
/// **In place, because** the window has one `.sheet` (build 44), and a popover with a text
/// field on the phone has to be checked with the keyboard up (builds 160, 231). **The buttons
/// sit above the field**, so the keyboard cannot cover **Save**.
///
/// **The button and its words are not inside one tappable row**: the button is a button, the
/// sentence is text. One press has one meaning (builds 71–74).
struct AreaStandardBox: View {
    @EnvironmentObject private var model: AppModel
    let area: Note
    @State private var editing = false
    @State private var draft = ""
    /// The standard the box showed when typing began; `setStandard` refuses to write over a
    /// different one unseen.
    @State private var startedFrom: String? = nil
    /// Why the last **Save** wrote nothing. Said inside the box, never in an alert over it.
    @State private var notice: String? = nil
    @FocusState private var focused: Bool

    /// Written out: a struct with `private @State` properties does not offer its memberwise
    /// initializer to other files (build 229).
    init(area: Note) {
        self.area = area
    }

    private var standard: String? { model.standard(of: area) }
    private var tint: Color { ParaKind.area.tint }
    /// A plain function's answer, not a ternary of literals inside the `Label` (no compiler
    /// here to settle which initializer it means).
    private var buttonTitle: String {
        standard == nil ? "Write the standard\u{2026}" : "Standard\u{2026}"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SectionLabel(title: "Standard")
                controls
            }
            if editing {
                editor
            } else {
                shown
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("area.standard")
    }

    // MARK: The buttons

    /// **Standard…** while one is written, **Write the standard…** while none is, and
    /// **Cancel** / **Save** while typing. `.fixedSize()` so the label beside them, which ends in
    /// a spacer, takes what is left and a short button never stands in a gap (build 247).
    @ViewBuilder
    private var controls: some View {
        if editing {
            HStack(spacing: 8) {
                Button("Cancel") {
                    editing = false
                    notice = nil
                }
                .accessibilityIdentifier("area.standard.cancel")
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("area.standard.save")
            }
            .fixedSize()
        } else {
            Button(action: begin) {
                Label(buttonTitle, systemImage: "square.and.pencil")
                    .font(.callout)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityIdentifier("area.standard.edit")
        }
    }

    // MARK: What is shown

    @ViewBuilder
    private var shown: some View {
        if let standard {
            Text(AreaStandard.firstSentence(of: standard))
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("area.standard.text")
        } else {
            // Dashed and grey: something missing rather than something there, as everywhere in
            // PARAGON (build 142). One element with one sentence, so a test and a screen reader
            // hear the same words on both platforms (builds 196, 253).
            ProjectPill(fact: ProjectFact(id: "noStandard", text: "No standard written yet",
                                          systemImage: "circle.dashed", dashed: true))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("No standard written yet")
                .accessibilityIdentifier("area.standard.missing")
        }
    }

    // MARK: Typing

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("What does \"good\" look like in this area?", text: $draft, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .accessibilityIdentifier("area.standard.field")
            if let notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("area.standard.notice")
            }
        }
    }

    private func begin() {
        let now = standard
        draft = now ?? ""
        startedFrom = now
        notice = nil
        editing = true
        // Focus does not always take in the turn the field appears (build 119).
        DispatchQueue.main.async { focused = true }
    }

    /// The box closes when the words are written. When they could not be, it stays open with
    /// them in it (build 261), and when the standard changed meanwhile it says what it is now:
    /// he has just been told, so a second **Save** replaces it on purpose.
    private func save() {
        switch model.setStandard(draft, on: area, startedFrom: startedFrom) {
        case .written:
            editing = false
            notice = nil
        case .changedMeanwhile(let onFile):
            startedFrom = onFile
            notice = Self.message(onFile: onFile)
        case .notWritten:
            break
        }
    }

    private static func message(onFile: String?) -> String {
        guard let onFile else {
            return "The standard was taken away on your other device. Your words are still in the box. Press Save again to use them."
        }
        let now = AreaStandard.firstSentence(of: onFile)
        return "The standard was changed on your other device to \u{201C}\(now)\u{201D}. Your words are still in the box. Press Save again to use yours instead."
    }
}
