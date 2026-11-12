import SwiftUI
import ParagonCore

/// The Deleted section: notes you removed, newest first, with a way back.
/// They sit in a hidden folder inside the vault, so this works the same on the Mac
/// and on the phone, and nothing here is synced to Reminders.
struct DeletedView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmEmpty = false

    private var listed: [DeletedNote] { model.deletedNotes }

    var body: some View {
        Group {
            if listed.isEmpty {
                EmptyStateView(title: "Nothing deleted",
                               markName: "trash",
                               message: "Notes you delete wait here for \(AppModel.deletedKeptForDays) days, so a mistake is never final. Tasks are not kept here — only whole notes.")
            } else {
                List {
                    Section {
                        ForEach(listed) { deleted in
                            DeletedRow(deleted: deleted)
                        }
                    } footer: {
                        Text("Kept for \(AppModel.deletedKeptForDays) days, then cleared out.")
                            .font(Txt.label)
                    }
                }
            }
        }
        .navigationTitle("Deleted")
        .toolbar {
            if !listed.isEmpty {
                ToolbarItem {
                    Button("Empty") { confirmEmpty = true }
                        .help("Delete everything here for good")
                }
            }
        }
        .confirmationDialog("Delete all \(listed.count) for good?", isPresented: $confirmEmpty) {
            Button("Delete for good", role: .destructive) { model.emptyDeleted() }
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear { model.refreshDeleted() }
    }
}

struct DeletedRow: View {
    @EnvironmentObject private var model: AppModel
    let deleted: DeletedNote

    private var when: String {
        guard deleted.deletedAt != .distantPast else { return "Deleted" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "en")   // the app is English on every device
        return "Deleted \(formatter.localizedString(for: deleted.deletedAt, relativeTo: Date()))"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Build 310: Deleted mixes every part, so the row shows the part's icon, not a dot.
            PartMark(markName: SidebarSection.kind(deleted.kind).markName, color: deleted.kind.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(deleted.title)
                    .font(Txt.listTitle)
                    .lineLimit(1)
                Text("\(deleted.kind.displayName) · \(when)")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            }
            Spacer(minLength: 6)
            Button("Put back") { model.putBack(deleted) }
                .help("Return it to \(deleted.originalPath.isEmpty ? "its folder" : deleted.originalPath)")
            Button {
                model.deleteForGood(deleted)
            } label: {
                MarkImage("trash")
            }
            .help("Delete this one for good")
            .accessibilityLabel("Delete this one for good")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Put back") { model.putBack(deleted) }
            Button("Delete for good", role: .destructive) { model.deleteForGood(deleted) }
        }
    }
}
