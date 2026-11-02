import SwiftUI
import ParagonCore

/// **Undo for the one-press changes (build 277).** Two things happen in one press, with no
/// question first, and neither could be put right by hand:
///
/// - the two buttons over Today's **Overdue** list give every overdue task the same new date.
///   Build 221 said "every task is still there and can be moved again". Each task had its own
///   old date and nobody remembers them, so that was not true;
/// - **Delete** in the Inbox. He chose not to be asked first (2 November 2026), so the answer
///   to a slip has to come afterwards.
///
/// The message at the foot of the window gets an **Undo** button for about eight seconds. What
/// Undo may write is decided in Core (`TaskUndo.swift`, tested): only what is still exactly as
/// the press left it. This file keeps the record a press leaves behind, hands it back, and says
/// what happened.

/// What an Undo would undo.
enum UndoableChange {
    /// Tasks given a new date, each with the date it had.
    case dates([MovedTask])
    /// A task line deleted, with what was around it.
    case deletion(RemovedTask)
}

/// The Undo on offer under the message at the foot of the window.
struct UndoOffer {
    /// Counts up with every offer, so the overlay can tell a second offer from the first even
    /// when the words are the same.
    let id: Int
    let change: UndoableChange
}

extension AppModel {
    /// Puts back what the message on screen says was done. **The offer is cleared first**, so a
    /// second press — a double tap, or a click while the first is still being written — finds
    /// nothing and does nothing. The answer is an ordinary message with no Undo of its own.
    func undo() {
        guard let offer = undoOffer else { return }
        undoOffer = nil
        flushPendingEdits()
        guard vault != nil else { return }
        switch offer.change {
        case .dates(let moves):
            putDatesBack(moves)
        case .deletion(let removed):
            putLineBack(removed)
        }
    }

    /// Every note that was written is read again by `saveEach` if it changed on disk meanwhile,
    /// and the undo is worked out against what is there then (`Note.undoingDateMoves`). A task
    /// that is not provably as the move left it is named in the answer, with the reason.
    private func putDatesBack(_ moves: [MovedTask]) {
        guard let vault else { return }
        var byNote: [String: [MovedTask]] = [:]
        for move in moves where move.changedTheDate { byNote[move.notePath, default: []].append(move) }
        let total = byNote.values.reduce(0) { $0 + $1.count }

        var touched: [Note] = []
        var skipped: [SkippedTask] = []
        for path in byNote.keys.sorted() {
            let list = byNote[path] ?? []
            let found = note(at: path)
            if let found, !notesBeingUpdated.contains(path) {
                touched.append(found)
            } else {
                // The note is not in the list any more, or a newer copy of it is on its way from
                // iCloud and this one cannot prove anything.
                let reason: UndoSkip = found == nil ? .gone : .changed
                for move in list { skipped.append(SkippedTask(title: move.title, reason: reason)) }
            }
        }

        var restoredByNote: [String: [MovedTask]] = [:]
        var skippedByNote: [String: [SkippedTask]] = [:]
        let result = vault.saveEach(touched) { note in
            let attempt = note.undoingDateMoves(byNote[note.relativePath] ?? [])
            // Overwritten if the write is tried again on a fresh copy.
            restoredByNote[note.relativePath] = attempt.restored
            skippedByNote[note.relativePath] = attempt.skipped
            return attempt.restored.isEmpty ? nil : attempt.note
        }
        reload()

        var restoredCount = 0
        for note in touched {
            let path = note.relativePath
            skipped += skippedByNote[path] ?? []
            let restored = restoredByNote[path] ?? []
            if result.failed.contains(path) {
                for move in restored { skipped.append(SkippedTask(title: move.title, reason: .notWritten)) }
            } else {
                restoredCount += restored.count
            }
        }
        if !result.isComplete { log("could not put dates back: \(result.failed)") }
        log("undo: \(restoredCount) of \(total) dates put back")
        flash(UndoWording.datesPutBack(total: total, restored: restoredCount, skipped: skipped))
    }

    /// A deleted line is put back by **adding** it (`Note.putBack`), so a capture that arrived
    /// since, or an edit from another device, is never written over.
    private func putLineBack(_ removed: RemovedTask) {
        guard let vault else { return }
        guard let current = note(at: removed.notePath) else {
            flash(UndoWording.noteMissing(title: removed.title))
            return
        }
        var outcome: TaskPutBack = .alreadyThere
        let result = vault.saveEach([current]) { fresh in
            var updated = fresh
            outcome = updated.putBack(removed)
            return outcome == .alreadyThere ? nil : updated
        }
        reload()
        if !result.isComplete {
            log("could not put \"\(removed.title)\" back: \(result.failed)")
            flash(UndoWording.notWritten(title: removed.title))
            return
        }
        log("undo: \"\(removed.title)\" \(outcome)")
        flash(UndoWording.deletionUndone(title: removed.title, outcome))
    }
}

/// The message at the foot of the window, with an **Undo** button when the message carries one.
///
/// **Without an offer it is exactly what it was** — one `Text` in a material capsule — so the
/// ordinary messages look as they always did. With an offer the capsule gets the button after
/// the words, and a taller tap area on the phone, where a thumb needs more than a line of text.
/// The timing is the overlay's (`ContentView`), not this view's: its wait is a `.task`, the same
/// one that has always cleared the message.
struct FlashCapsule: View {
    let message: String
    let offersUndo: Bool
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.callout)
                .accessibilityIdentifier("flash.message")
            if offersUndo {
                Button(action: undo) {
                    Text("Undo")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 6)
                        .frame(minHeight: undoHeight)
                        // The tap area is the label, so the room goes inside it (build 186).
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("flash.undo")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, offersUndo ? 2 : 8)
        .background(.regularMaterial, in: Capsule())
    }

    /// A finger needs about 40 points; a pointer needs far less.
    private var undoHeight: CGFloat {
        #if os(iOS)
        return 40
        #else
        return 24
        #endif
    }
}
