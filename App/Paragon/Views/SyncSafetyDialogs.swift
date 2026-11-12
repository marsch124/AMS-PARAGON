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

struct SyncSafetyDialogs: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            .alert("Sync stopped to ask you", isPresented: massPresented, presenting: model.massChangeQuestion) { _ in
                Button("Do it", role: .destructive) {
                    Task { await model.syncNow(allowMassChanges: true) }
                }
                .accessibilityIdentifier("sync.mass.doIt")
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
