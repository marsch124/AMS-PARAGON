import Foundation
import ParagonCore

extension AppModel {
    /// Writes the tasks ticked on a widget into their notes (build 317).
    ///
    /// **The widget only leaves a line in the shared folder** (`WidgetTickQueue`); the tick
    /// itself is made here, by `toggle`, the one path every tick in the app takes — it writes
    /// what is being typed first, makes a repeating task's next copy, meets the "changed on
    /// disk" check and reaches Reminders at the next sync. Called at launch, when PARAGON comes
    /// to the front, and by the ten-second look while it is open (the Mac's widget is used
    /// with the app open).
    ///
    /// **A tick only ever lands on the task it was made on** (`WidgetTick.outcome`): a task
    /// that is gone or already done is skipped, and a tick whose note is still coming from
    /// iCloud goes back into the file and waits.
    func applyWidgetTicks() {
        guard vault != nil, let container = Self.widgetContainerURL else { return }
        let queue = WidgetTickQueue(container: container)
        let ticks = queue.drain()
        guard !ticks.isEmpty else { return }
        // Review of build 317: what is being typed is written before a task is looked for. He
        // may have ticked the same task in the editor a moment ago; found "open" in the copy
        // from before that, a repeating task would get a second next copy.
        flushPendingEdits()
        var waiting: [WidgetTick] = []
        var done: [String] = []
        var dropped = 0
        let stillArriving = !notesWaitingForCloud.isEmpty
        let hadProblem = errorMessage != nil
        /// What to do with the tick now, as the notes are now.
        func outcome(of tick: WidgetTick) -> (note: Note?, outcome: WidgetTick.Outcome) {
            let note = note(at: tick.notePath)
            return (note, tick.outcome(in: note, notesStillArriving: stillArriving,
                                       noteBeingUpdated: notesBeingUpdated.contains(tick.notePath)))
        }
        for tick in ticks {
            // Read again for each one: the tick before it may have changed the same note.
            let first = outcome(of: tick)
            switch first.outcome {
            case .tick(let task):
                guard let note = first.note else { continue }
                toggle(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
                // Review of build 317: a tick is only reported when it is in the note. The save
                // is refused when the file changed on disk since the last look (this runs before
                // the ten-second look reads it); the notes are fresh then, so it is tried once
                // more on the task as the file has it — and dropped if that fails too.
                var second = outcome(of: tick)
                if case .tick(let again) = second.outcome, let fresh = second.note {
                    toggle(TaskRef(notePath: fresh.relativePath, noteTitle: fresh.displayTitle, task: again))
                    second = outcome(of: tick)
                    // "Please make your change again" is not said for a change that was made again.
                    if case .gone = second.outcome, !hadProblem { errorMessage = nil }
                }
                switch second.outcome {
                case .gone:
                    // No longer open in its note: the tick is in.
                    done.append(WidgetSnapshot.widgetTitle(task.title))
                case .wait:
                    // The re-read found a newer copy on its way from iCloud.
                    waiting.append(tick)
                case .tick:
                    dropped += 1
                    log("widget tick dropped, the note could not be saved: \(tick.notePath)")
                }
            case .wait:
                waiting.append(tick)
            case .gone:
                dropped += 1
                log("widget tick dropped, task not found open: \(tick.notePath)")
            }
        }
        queue.requeue(waiting)
        // Only waiting ticks: nothing changed, so the widgets are not redrawn every ten seconds.
        guard !done.isEmpty || dropped > 0 else { return }
        if done.count == 1 {
            flash("Ticked on the widget: \(done[0])")
        } else if done.count > 1 {
            flash("\(done.count) tasks ticked on the widget.")
        }
        // At once, not in two seconds: the widget is drawing these lines ticked from the file
        // just emptied, and the new summary is what takes them off.
        writeWidgetSnapshot(force: true)
    }
}
