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

/// The question itself, one `confirmationDialog` at the window's root beside the "Something went
/// wrong" alert (build 271). A `ViewModifier`, so `ContentView`'s long chain gets one line.
///
/// **The buttons are built by a plain function**, and each press is handed the question, never
/// reading it back from the model: the dialog clears `whatNext` as it closes, and which of the
/// button's action and the binding's setter runs first is not something to rely on. The same
/// shape as the Delete question in `NoteListView`.
///
/// **Untested from here**: that the dialog really appears on the iPhone a turn after a Menu
/// closes. CI compiles it but never presses the status Menu (its items carry no identifier, build
/// 191), so his field test is the first look.
struct WhatNextDialog: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: presented, titleVisibility: Visibility.visible,
                                presenting: model.whatNext) { question in
                buttons(for: question)
            } message: { question in
                Text(question.line)
            }
    }

    private var title: String {
        model.whatNext?.title ?? "What is next for this goal?"
    }

    /// The setter clears the question a turn later, like `errorPresented`: it runs inside
    /// SwiftUI's own update.
    private var presented: Binding<Bool> {
        Binding(get: { model.whatNext != nil },
                set: { shown in
                    if !shown { model.afterUpdate { model.whatNext = nil } }
                })
    }

    @ViewBuilder
    private func buttons(for question: WhatNextQuestion) -> some View {
        Button(question.addTitle) { model.addWorkForWhatNext(question) }
        if question.offersDone {
            Button(WhatNextQuestion.doneTitle) { model.markGoalDone(question) }
        }
        Button(WhatNextQuestion.notNowTitle, role: .cancel) { }
    }
}
