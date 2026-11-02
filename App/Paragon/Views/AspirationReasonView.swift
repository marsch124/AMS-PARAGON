import SwiftUI
import ParagonCore

// An aspiration's Reason (build 277, his answers A1 "Yes, build it" and A2 "No, only on the
// Aspirations page"): why this matters, in his own words, at the top of the aspiration's page.
//
// **It was always written and never shown.** Every goal note is made from the Goal template,
// which has a `## Why` heading with the question "What changes in my life when this is true?"
// under it. He answers it once, in the note, and no screen read the answer again. An aspiration
// is "the top, most important things in my life" (his words, build 199); this puts his own
// sentence where he looks at it.
//
// **What decides it is Core.** `NoteReason` (tested) reads and writes the `## Why` section and
// leaves out the template's own question, so an aspiration nobody has answered says "No reason
// written yet" instead of showing a question as if it were his answer (build 100). This file
// only asks and draws. The shape is `AreaStandardBox` (build 271), and so are the rules.
//
// **Only an aspiration's page, and not Start the day or the review** (his answer A2). The box
// asks nothing about the kind of goal, so a goal with a date's page could take it in one line.
//
// **A file of its own**, like `AreaStandardView.swift`: `AppModel.swift`, `GoalsView.swift` and
// `ScreenTests.swift` are changed by other builds at the same time, so what is new lives here.

extension AppModel {
    /// What came of a try to write a reason.
    enum ReasonWrite: Equatable {
        /// Written, or there was nothing to write because the words had not changed.
        case written
        /// The reason on file is no longer the one the box opened on (changed on the other
        /// device, or a newer copy came from iCloud while the box stood open). Nothing was
        /// written. `onFile` is what it says now; nil means it was taken away.
        case changedMeanwhile(onFile: String?)
        /// Could not be written. An alert says why; the box keeps his words (build 261).
        case notWritten
    }

    /// The reason written in a goal note, or nil when there is none — the template's own
    /// question does not count. The template lines come from `refreshSnippets()`.
    func reason(of note: Note) -> String? {
        NoteReason.text(in: note, placeholders: reasonPlaceholders)
    }

    /// Writes the words as the goal's reason. **Empty words take the reason away**, and do
    /// nothing at all when there was none (Core decides, `NoteReason.note`).
    ///
    /// **`startedFrom` is the reason the box showed when it opened.** When the note now holds
    /// another one, nothing is written and the answer says what it holds; a second press then
    /// replaces it on purpose. Words he never saw are never replaced unseen — the rule of
    /// `setWeekGoal` (build 264), `setMeasure` (build 268) and `setStandard` (build 271).
    ///
    /// **Refused while iCloud is bringing a newer copy** (`notesBeingUpdated`, build 261): the
    /// note on this device is the older one, and `Vault.save` compares against that copy's date,
    /// so a write would go over the newer version without being caught.
    ///
    /// The editor's own unsaved text is written first, and the note is read back out of the
    /// model: a chip on the same page may have just saved it (build 144).
    @discardableResult
    func setReason(_ text: String, on note: Note, startedFrom: String?) -> ReasonWrite {
        flushPendingEdits()
        guard let live = self.note(at: note.relativePath) else {
            errorMessage = "\u{201C}\(note.displayTitle)\u{201D} is not in the vault any more, so its reason was not saved."
            return .notWritten
        }
        // A work note has no aspiration page, so this cannot be reached from the screen; the
        // check is here so the rule (build 112) does not depend on where the box is drawn.
        guard !isWorkNote(live) else {
            errorMessage = "\u{201C}\(live.displayTitle)\u{201D} is a work note, so no reason was saved."
            return .notWritten
        }
        guard !notesBeingUpdated.contains(live.relativePath) else {
            errorMessage = "\u{201C}\(live.displayTitle)\u{201D} is being updated from iCloud, so its reason was not saved. Try again in a moment."
            return .notWritten
        }
        let clean = NoteReason.cleaned(text)
        let wanted: String? = clean.isEmpty ? nil : clean
        let onFile: String? = reason(of: live)
        if onFile != startedFrom && onFile != wanted {
            return .changedMeanwhile(onFile: onFile)
        }
        let updated = NoteReason.note(live, settingText: text, placeholders: reasonPlaceholders)
        // The same words again write nothing (`setIcon`'s rule, build 254): a save would stamp
        // the file and send it round iCloud for nothing.
        guard updated != live else { return .written }
        guard save(updated) else { return .notWritten }
        reload()
        return .written
    }
}

/// The block under an aspiration's name: a **REASON** label, **Reason…**, and what he wrote in
/// the aspiration's own deeper gold, four lines at most — or a dashed grey **No reason written
/// yet.** and **Write the reason…**. Pressing the button opens the text in place, as **Standard**
/// does on an area's page (build 271): a field with **Save** and **Cancel**, and no sheet and no
/// popover.
///
/// **In place, because** the window has one `.sheet` (build 44), and a popover with a text field
/// on the phone has to be checked with the keyboard up (builds 160, 231). **The buttons sit
/// above the field**, so the keyboard cannot cover **Save**. The field shows all of what he
/// wrote; the page only the first four lines, so a long reason cannot push the chain off the
/// screen.
///
/// **On the phone this sits in the folded-open chain, which is one list row**, so the buttons
/// are `.borderless` or one press would press them all (builds 266, 272). **Return does not
/// save**: what Return does in a vertical-axis field is not known from here (build 272), so the
/// manual says "press **Save**".
struct AspirationReasonBox: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    @State private var editing = false
    @State private var draft = ""
    /// The reason the box showed when typing began; `setReason` refuses to write over a
    /// different one unseen.
    @State private var startedFrom: String? = nil
    /// Why the last **Save** wrote nothing. Said inside the box, never in an alert over it.
    @State private var notice: String? = nil
    @FocusState private var focused: Bool

    /// Written out: a struct with `private @State` properties does not offer its memberwise
    /// initializer to other files (build 229).
    init(note: Note) {
        self.note = note
    }

    /// The note as the model holds it now, not the copy this view was handed (build 144).
    private var live: Note { model.note(at: note.relativePath) ?? note }
    private var reason: String? { model.reason(of: live) }
    /// True while iCloud is bringing a newer copy of this note (build 261). The words on screen
    /// are then the older copy's.
    private var updating: Bool { model.notesBeingUpdated.contains(note.relativePath) }
    private var tint: Color { ChainTint.aspiration }

    /// A plain function's answer, not a ternary of literals inside the `Label` (no compiler
    /// here to settle which initializer it means).
    private var buttonTitle: String {
        reason == nil ? "Write the reason\u{2026}" : "Reason\u{2026}"
    }

    /// The template's own question, as the field's hint — it is what the field answers.
    private var hint: String {
        NoteReason.shippedPlaceholders.first ?? "Why does this matter to you?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SectionLabel(title: "Reason")
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
        .accessibilityIdentifier("aspiration.reason")
    }

    // MARK: The buttons

    /// **Reason…** while one is written, **Write the reason…** while none is, and **Cancel** /
    /// **Save** while typing. `.fixedSize()` so the label beside them, which ends in a spacer,
    /// takes what is left and a short button never stands in a gap (build 247).
    @ViewBuilder
    private var controls: some View {
        if editing {
            HStack(spacing: 8) {
                Button("Cancel") {
                    editing = false
                    notice = nil
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("aspiration.reason.cancel")
                Button("Save", action: save)
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("aspiration.reason.save")
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
            // Greyed while the note is being updated: a write now would go over the newer copy.
            .disabled(updating)
            // Set outright, so both platforms and a screen reader hear the same words, and the
            // screen test reads what the button offers (the measure chip does the same).
            .accessibilityLabel(buttonTitle)
            .accessibilityIdentifier("aspiration.reason.edit")
        }
    }

    // MARK: What is shown

    @ViewBuilder
    private var shown: some View {
        if let reason {
            Text(reason)
                .font(.callout)
                .foregroundStyle(tint)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("aspiration.reason.text")
        } else if updating {
            // An older copy with no reason in it says nothing about the newer one: not "no
            // reason written", which would be an absence drawn for a note that cannot be read
            // yet (builds 100, 261). Orange with the cloud, as Start the day draws the same state.
            Label("Being updated from iCloud. The reason may show here in a moment.", systemImage: "icloud")
                .font(.caption)
                .foregroundStyle(Color.orange)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("aspiration.reason.waiting")
        } else {
            // Dashed and grey: something missing rather than something there, as everywhere in
            // PARAGON (build 142). One element with one sentence, so a test and a screen reader
            // hear the same words on both platforms (builds 196, 253).
            ProjectPill(fact: ProjectFact(id: "noReason", text: "No reason written yet.",
                                          systemImage: "circle.dashed", dashed: true))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("No reason written yet.")
                .accessibilityIdentifier("aspiration.reason.missing")
        }
    }

    // MARK: Typing

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(hint, text: $draft, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .accessibilityIdentifier("aspiration.reason.field")
            if let notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("aspiration.reason.notice")
            }
        }
    }

    private func begin() {
        let now = reason
        draft = now ?? ""
        startedFrom = now
        notice = nil
        editing = true
        // Focus does not always take in the turn the field appears (build 119).
        DispatchQueue.main.async { focused = true }
    }

    /// The box closes when the words are written. When they could not be, it stays open with
    /// them in it (build 261), and when the reason changed meanwhile it says what it is now: he
    /// has just been told, so a second **Save** replaces it on purpose.
    private func save() {
        switch model.setReason(draft, on: note, startedFrom: startedFrom) {
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
            return "The reason was taken away on your other device. Your words are still in the box. Press Save again to use them."
        }
        return "The reason was changed on your other device to \u{201C}\(quote(onFile))\u{201D}. Your words are still in the box. Press Save again to use yours instead."
    }

    /// The first sentence of what is on file, and never more than 120 characters of it: a long
    /// reason would otherwise fill the notice. The sentence rule is Core's and is shared.
    private static func quote(_ text: String) -> String {
        let sentence = AreaStandard.firstSentence(of: text)
        guard sentence.count > 120 else { return sentence }
        return String(sentence.prefix(120)) + "\u{2026}"
    }
}
