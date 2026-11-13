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
        var waiting: [WidgetTick] = []
        var done: [String] = []
        let stillArriving = !notesWaitingForCloud.isEmpty
        for tick in ticks {
            // Read again for each one: the tick before it may have changed the same note.
            let note = note(at: tick.notePath)
            switch tick.outcome(in: note, notesStillArriving: stillArriving) {
            case .tick(let task):
                guard let note else { continue }
                toggle(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
                done.append(WidgetSnapshot.widgetTitle(task.title))
            case .wait:
                waiting.append(tick)
            case .gone:
                log("widget tick dropped, task not found open: \(tick.notePath)")
            }
        }
        queue.requeue(waiting)
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
