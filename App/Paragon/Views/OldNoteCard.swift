import SwiftUI
import ParagonCore

/// The two settings of **From your Resources** (round 350, pick 43). Both are per device.
enum OldNoteSetting {
    /// Settings › Today: the switch.
    static let key = "showOldNote"
    /// The day (`2026-11-20`) on which **Not today** was pressed; the card stays away that day.
    static let hiddenKey = "oldNoteHiddenDay"
}

/// A small panel on Today: one Resource that has lain untouched for 30 days or more, chosen by
/// the day (Core's `OldNoteComesBack`), with its title, its first line, **Open** and **Not
/// today**. Nothing is drawn when no Resource is old enough, when the switch is off, or after
/// **Not today**. Never drawn while picking: that screen is for choosing the day's work.
struct OldNoteSection: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(OldNoteSetting.key) private var isOn = true
    @AppStorage(OldNoteSetting.hiddenKey) private var hiddenDay = ""
    let day: DateOnly

    var body: some View {
        if isOn, hiddenDay != day.description, let note = OldNoteComesBack.pick(in: model.index, today: day) {
            Section {
                card(note)
            } header: {
                SectionLabel(title: "From your Resources", tint: ParaKind.resource.tint)
            }
        }
    }

    private func card(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: note.displayTitle)
                .font(Txt.listTitle)
                .lineLimit(2)
            if let line = OldNoteComesBack.firstLine(of: note) {
                Text(verbatim: line)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .lineLimit(2)
            }
            HStack(spacing: 12) {
                Button { model.show(note) } label: {
                    Text("Open")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("today.oldNote.open")
                Button { hiddenDay = day.description } label: {
                    Text("Not today")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.soft)
                .accessibilityIdentifier("today.oldNote.notToday")
            }
            .font(Txt.value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.oldNote")
    }
}
