import SwiftUI
import EventKit
import ParagonCore

/// Build 307, the review's safety round: the two questions sync now asks before it does
/// something that cannot be taken back by a tap.

/// "This note is in Deleted. Remove its reminders too?"
struct ReminderQuestion: Identifiable, Equatable {
    let note: Note
    let count: Int
    var id: String { note.relativePath }

    var title: String { "Remove \(count == 1 ? "its reminder" : "its \(count) reminders") too?" }
    var line: String {
        "\u{201C}\(note.displayTitle)\u{201D} is in Deleted. It still has \(count) open reminder\(count == 1 ? "" : "s") in Apple Reminders. If you put the note back later, kept reminders are linked again."
    }
}

extension AppModel {
    /// After a note went to Deleted: forget its links, and ask about its open reminders when it
    /// has any. Does nothing when PARAGON has no access to Reminders — it never asks for access
    /// from here.
    func settleReminders(ofDeleted note: Note) {
        guard let vault, EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return }
        let engine = SyncEngine(vault: vault, store: remindersStore, deviceID: deviceID)
        Task { [weak self] in
            guard let self else { return }
            do {
                let open = try await engine.openLinkedReminders(of: note)
                guard self.vault === vault else { return }
                if open.isEmpty {
                    try await engine.releaseReminders(of: note, .keep)
                } else {
                    self.reminderQuestion = ReminderQuestion(note: note, count: open.count)
                }
            } catch {
                self.log("reminders of deleted note not settled: \(error.localizedDescription)")
            }
        }
    }

    func answer(_ question: ReminderQuestion, _ choice: LinkedReminderChoice) {
        guard let vault else { return }
        let engine = SyncEngine(vault: vault, store: remindersStore, deviceID: deviceID)
        Task { [weak self] in
            guard let self else { return }
            do {
                let removed = try await engine.releaseReminders(of: question.note, choice)
                self.log("deleted note \(question.note.relativePath): \(removed) reminders removed")
                if removed > 0 { self.flash("\(removed) reminder\(removed == 1 ? "" : "s") removed") }
            } catch {
                self.errorMessage = "The reminders could not be changed: \(error.localizedDescription)"
            }
        }
    }
}

extension AppModel {
    /// Build 315, **Keep them apart**: the lists the sync asked about are remembered in the
    /// vault's settings (so both devices know), and the sync runs again. It leaves those lists
    /// and their notes alone from now on and does not ask about them again. Anything else the
    /// sync stopped for is asked again by that run, on its own.
    func keepApart(_ summary: MassChangeSummary) {
        guard let vault, !summary.listsToJoin.isEmpty else { return }
        // Review round 8: added to the lists as the file holds them now, not as this device
        // read them when it opened the vault — the other device may have set one apart since.
        vault.reloadConfigIfChanged()
        var changed = config
        for join in summary.listsToJoin {
            changed.listsKeptApart = ListsKeptApart.adding(id: join.listID, name: join.listName, device: deviceID,
                                                           to: changed.listsKeptApart)
        }
        config = changed
        let names = summary.listsToJoin.map { "\u{201C}\($0.listName)\u{201D}" }.joined(separator: ", ")
        log("kept apart: \(names)")
        flash(summary.listsToJoin.count == 1 ? "The list \(names) is kept apart" : "\(summary.listsToJoin.count) lists are kept apart")
        Task { await syncNow() }
    }

    /// **Connect again** in Settings: the list is forgotten, and the next sync asks about it
    /// as it did the first time. Nothing is joined by this press.
    func connectAgain(_ list: KeptApartList) {
        vault?.reloadConfigIfChanged()
        var changed = config
        changed.listsKeptApart = ListsKeptApart.removing(list, from: changed.listsKeptApart)
        config = changed
        log("connect again: \u{201C}\(list.name)\u{201D}")
    }
}

struct SyncSafetyDialogs: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            .alert("Sync stopped to ask you", isPresented: massPresented, presenting: model.massChangeQuestion) { summary in
                Button("Do it", role: .destructive) {
                    Task { await model.syncNow(allowMassChanges: true) }
                }
                .accessibilityIdentifier("sync.mass.doIt")
                // Build 315: only when the question is (also) about a list PARAGON did not make.
                if !summary.listsToJoin.isEmpty {
                    Button("Keep them apart") { model.keepApart(summary) }
                        .accessibilityIdentifier("sync.mass.keepApart")
                }
                Button("Cancel", role: .cancel) { }
                    .accessibilityIdentifier("sync.mass.cancel")
            } message: { summary in
                Text(summary.message)
            }
            .alert(model.reminderQuestion?.title ?? "", isPresented: reminderPresented,
                   presenting: model.reminderQuestion) { question in
                Button("Remove reminders", role: .destructive) { model.answer(question, .delete) }
                    .accessibilityIdentifier("deleted.reminders.remove")
                Button("Keep reminders", role: .cancel) { model.answer(question, .keep) }
                    .accessibilityIdentifier("deleted.reminders.keep")
            } message: { question in
                Text(question.line)
            }
    }

    private var massPresented: Binding<Bool> {
        Binding(get: { model.massChangeQuestion != nil },
                set: { shown in if !shown { model.afterUpdate { model.massChangeQuestion = nil } } })
    }

    private var reminderPresented: Binding<Bool> {
        Binding(get: { model.reminderQuestion != nil },
                set: { shown in if !shown { model.afterUpdate { model.reminderQuestion = nil } } })
    }
}
