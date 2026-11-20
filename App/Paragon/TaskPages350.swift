import Foundation
import SwiftUI
import ParagonCore

/// Round 350, lane tasks-pages: the writers for the energy tags (pick 44) and for a task that
/// has been moved often (pick 48). Every writer reads the live note first (build 144) and writes
/// nothing when nothing changes (build 254's rule).
extension AppModel {
    /// Pick 44: puts `#easy`, `#medium` or `#hard` on a task, replacing any other of the three;
    /// nil takes them off.
    func setEnergy(_ ref: TaskRef, _ energy: TaskEnergy?) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath) else { return }
        let task = ref.task.settingEnergy(energy)
        guard task != ref.task, note.replace(task: task, previousTitle: ref.task.title) else { return }
        _ = save(note)
    }

    /// Pick 48, **Do it now**: the task is due today, and the count starts again.
    func doItNowAfterMoves(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath) else { return }
        let task = ref.task.forgettingMoves().settingDueDate(DateOnly.today())
        guard task != ref.task, note.replace(task: task) else { return }
        _ = save(note)
        flash("Due today. The count of moves starts again.")
    }

    /// Pick 48, **Split it**: opens the note the task is in, and the count starts again so the
    /// question is not asked a second time while he is splitting it.
    func splitAfterMoves(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath) else { return }
        let task = ref.task.forgettingMoves()
        if task != ref.task, note.replace(task: task) {
            _ = save(note)
        }
        if let opened = self.note(at: ref.notePath) {
            show(opened)
        }
    }
}
