import SwiftUI
import ParagonCore

/// What the New Note sheet should start with when something already knows (build 271): the
/// button and the goal it should serve. Only **Add a project…** in "What is next for this goal?"
/// sets one today.
///
/// It is handed over through `AppModel.newNotePreset`, a plain variable, and the sheet takes it
/// once in `onAppear` (`AppModel.takeNewNotePreset()`). **`thing` is set before `servesGoal`**:
/// `NewNoteSheet.pick(_:)` clears the goal whenever the kind changes, so the other order would
/// lose it. (`onAppear` assigns `thing` directly and never calls `pick`, but the order is the
/// safe one.)
struct NewNotePreset {
    var thing: NewThing
    /// The goal's **title**: that is what the sheet's Serves… list uses as its value, and what a
    /// `goal:` line carries.
    var servesGoal: String
}

extension AppModel {
    /// Called by `setStatus` after a project has been saved as ended (build 271). If that
    /// leaves its goal with nothing working on it, the question comes up.
    ///
    /// **A turn later, and only when nothing else is on screen.** The status was changed from a
    /// menu that is still closing, and a dialog opened in the same update as a sheet, an alert
    /// or the focus clock's question is two presentations at once (builds 238, 246 and 257).
    /// Status is never set from inside a sheet today, so the check is a guard, not a feature. It
    /// is also why the question is never set together with `errorMessage`: that is only set
    /// when a save failed, and a failed save never reaches this far.
    ///
    /// **The rule is asked again inside the turn**, against the note as it is then, so a project
    /// put back to Active in between asks nothing.
    ///
    /// **Not asked while notes are coming from iCloud, or being updated by it.** "Nothing is
    /// working on this goal" is a claim about the whole vault, and a note that has not arrived is
    /// not in the index; an older copy of one that is arriving may still read as ended. Saying it
    /// then could offer **Mark the goal done** over a goal that still has live work (build 100's
    /// rule, as in `partVaultReason`). The question is optional, so skipping it costs nothing.
    func askWhatNext(afterEnding project: Note) {
        let path = project.relativePath
        afterUpdate {
            guard self.vault != nil, self.whatNext == nil, self.activeSheet == nil,
                  !self.focusQuestionPending, self.errorMessage == nil,
                  self.notesWaitingForCloud.isEmpty, self.notesBeingUpdated.isEmpty else { return }
            guard let ended = self.note(at: path),
                  let goal = self.index.goalLeftWithoutWork(after: ended) else { return }
            self.whatNext = WhatNextQuestion(goal: goal, projectWasDone: ended.noteStatus == NoteStatus.done)
        }
    }

    /// **Add a project…** (or **Add a goal…** under an aspiration): opens the New Note screen
    /// already on that kind, with **Serves…** already set to the goal.
    ///
    /// New Note, not the small box of build 269: a dialog cannot hold a text field, and a name is
    /// needed. The question is closed in the same turn, and the screen opens only when nothing
    /// else is open; if something is, the press is dropped (the goal's own page still has
    /// **Add a project…**).
    func addWorkForWhatNext(_ question: WhatNextQuestion) {
        guard let goal = note(at: question.goalPath) else { return }
        var thing = NewThing.project
        if question.isAspiration { thing = NewThing.goal }
        let preset = NewNotePreset(thing: thing, servesGoal: goal.title)
        afterUpdate {
            self.whatNext = nil
            guard self.activeSheet == nil, !self.focusQuestionPending else { return }
            // Set in the same breath as the sheet is asked for, so a preset can never wait for
            // some later New Note screen.
            self.newNotePreset = preset
            self.activeSheet = .newNote
        }
    }

    /// **Mark the goal done**: the goal gets Done and its own `ended:` day through `setStatus`,
    /// the one writer of how a note stands. A goal is not a project, so this starts no second
    /// question about the aspiration above it.
    func markGoalDone(_ question: WhatNextQuestion) {
        guard let goal = note(at: question.goalPath), !goal.isEnded else { return }
        setStatus(NoteStatus.done, for: goal)
        if note(at: question.goalPath)?.noteStatus == NoteStatus.done {
            flash(question.doneMessage)
        }
    }

    /// The New Note sheet's one read of the preset: it is handed over and forgotten.
    func takeNewNotePreset() -> NewNotePreset? {
        let preset = newNotePreset
        newNotePreset = nil
        return preset
    }
}

/// The question itself (build 271), since build 347 PARAGON's own card — his pick "option 3,
/// two big tiles" from four drawn options. Apple's `confirmationDialog` floated on the iPhone as
/// a small bubble with grey buttons and the goal's name in small grey words; it cannot be
/// styled. The card lies over the whole window on a dimmed page, on every device.
///
/// **Each press is handed the question**, never reading it back from the model, and the card
/// clears `whatNext` a turn later (`afterUpdate`), as the dialog did: the same rules as before,
/// only the look is new. Not now, a tap on the dimmed page and Escape on the Mac close it.
struct WhatNextDialog: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            .overlay {
                if let question = model.whatNext {
                    WhatNextCard(question: question,
                                 add: { model.addWorkForWhatNext(question) },
                                 done: {
                                     model.afterUpdate { model.whatNext = nil }
                                     model.markGoalDone(question)
                                 },
                                 notNow: { model.afterUpdate { model.whatNext = nil } })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(Motion.isReduced ? nil : .easeOut(duration: 0.2), value: model.whatNext)
    }
}

/// The card: "What is next?", the goal's name in gold, two big tiles and **Not now**.
struct WhatNextCard: View {
    let question: WhatNextQuestion
    let add: () -> Void
    let done: () -> Void
    let notNow: () -> Void

    /// The goal's gold; a deeper gold for an aspiration, as on the Goals page.
    private var goalTint: Color {
        question.isAspiration ? ChainTint.aspiration : ChainTint.datedGoal
    }

    /// New work for a goal is a project (green flag); for an aspiration it is a goal (gold target).
    private var addTint: Color { question.isAspiration ? ChainTint.datedGoal : ParaKind.project.tint }
    private var addMark: String { question.isAspiration ? ChainSymbol.datedGoal : ChainSymbol.project }

    var body: some View {
        ZStack {
            Color.black.opacity(dim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: notNow)
                .accessibilityHidden(true)
            card
        }
    }

    private var dim: Double {
        #if os(macOS)
        0.25
        #else
        0.35
        #endif
    }

    private var card: some View {
        VStack(spacing: 0) {
            Text(WhatNextQuestion.cardTitle)
                .font(Txt.sectionTitle)
                .foregroundStyle(.primary)
            (Text(WhatNextQuestion.forWord + " ").foregroundColor(.secondary)
             + Text(question.goalName).fontWeight(.semibold).foregroundColor(goalTint.ink))
                .font(Txt.value)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
                .accessibilityIdentifier("whatnext.goal")
            HStack(spacing: 8) {
                tile(title: question.addTileTitle, hint: WhatNextQuestion.addTileHint,
                     mark: addMark, tint: addTint, id: "whatnext.add", action: add)
                if question.offersDone {
                    tile(title: WhatNextQuestion.doneTileTitle, hint: WhatNextQuestion.doneTileHint,
                         mark: ChainSymbol.datedGoal, tint: ChainTint.datedGoal, id: "whatnext.done", action: done)
                }
            }
            .padding(.top, 14)
            Button(WhatNextQuestion.notNowTitle, action: notNow)
                .buttonStyle(.plain)
                .font(Txt.value)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 2)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("whatnext.notNow")
        }
        .padding(16)
        .frame(maxWidth: 340)
        .background(Color(PlatformColor.systemBackgroundColour), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("whatnext.card")
    }

    /// One big tile: the mark white in a full-colour circle, the title in the tint's ink, and
    /// what pressing it does in small words under it — the screen says what the tap does.
    private func tile(title: String, hint: String, mark: String, tint: Color, id: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MarkImage(mark, size: 18)
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(tint.deep, in: Circle())
                Text(title)
                    .font(Txt.listTitle)
                    .foregroundStyle(tint.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(hint)
                    .font(Txt.listSecond)
                    .foregroundStyle(tint.ink.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(hint)")
        .accessibilityIdentifier(id)
    }
}
