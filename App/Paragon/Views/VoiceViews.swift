import SwiftUI
import ParagonCore

// Round 350 (voice-controls): the page of every voice note, and the card that lets him check
// a thought before it stays. What they decide is in Core (`VoiceControls.swift`).

/// The Voice notes page's own "Find a voice note" field, everywhere except the iPhone, where
/// `PhoneSectionScreen` adds the one field every list there has (build 324).
private struct OwnVoiceSearch: ViewModifier {
    @Binding var filter: String
    @Environment(\.phoneLook) private var phoneLook

    func body(content: Content) -> some View {
        if phoneLook { content } else { content.searchable(text: $filter, prompt: "Find a voice note") }
    }
}

/// **Voice notes**: every note a recorded thought made, newest first, with a search field and
/// the first words of each summary. A press opens the note; the row's **More** menu reads it
/// aloud, writes it up again, and (for the newest) throws it away.
struct VoiceNotesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.phoneListQuery) private var phoneQuery
    @Environment(\.phoneLook) private var phoneLook
    @State private var filter = ""
    @State private var throwing: VoiceFiled?

    private var tint: Color { SidebarSection.voiceNotes.tint }

    var body: some View {
        // The page draws again when `voiceHistoryStamp` changes: it is @Published on the model.
        let all = VoiceNoteList.rows(from: model.index.notesTagged(VoiceThought.tag))
        let rows = VoiceNoteList.matching(all, phoneLook ? phoneQuery : filter)
        let newest = newestThought()
        Group {
            if all.isEmpty {
                EmptyStateView(title: "No voice notes yet",
                               markName: SidebarSection.voiceNotes.markName,
                               message: "Record a thought with the Action Button or Siri. It lands here as a note, with a summary and its tasks.",
                               tint: tint,
                               hint: "Say \u{201C}Record a Thought\u{201D} to Siri")
                    .accessibilityIdentifier("voice.empty")
            } else {
                List {
                    Group {
                        if let newest {
                            lastThought(newest)
                        }
                        Section {
                            if rows.isEmpty {
                                Text("No voice note has these words.")
                                    .font(Txt.label)
                                    .foregroundStyle(.soft)
                                    .accessibilityIdentifier("voice.none")
                            }
                            ForEach(rows) { row in
                                self.row(row)
                            }
                        }
                    }
                    .phoneCard(tint)
                }
                .modifier(OwnVoiceSearch(filter: $filter))
            }
        }
        .navigationTitle("Voice notes")
        .confirmationDialog("Throw away this thought?",
                            isPresented: Binding(get: { throwing != nil }, set: { if !$0 { throwing = nil } })) {
            Button("Throw away", role: .destructive) {
                if let throwing { model.throwAwayVoice(throwing) }
                throwing = nil
            }
            .accessibilityIdentifier("voice.throw.confirm")
            Button("Cancel", role: .cancel) { throwing = nil }
        } message: {
            Text("The note goes to Deleted, where it stays for 30 days. Its tasks and its line leave the Inbox.")
        }
    }

    /// The newest thought this device recorded, while its note is still there.
    private func newestThought() -> VoiceFiled? {
        guard let first = VoiceHistoryStore.load().first, model.note(at: first.path) != nil else { return nil }
        return first
    }

    @ViewBuilder
    private func lastThought(_ filed: VoiceFiled) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("The last thought")
                    .font(Txt.listSecond)
                    .foregroundStyle(.soft)
                Text(filed.title)
                    .font(Txt.listTitle)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            Button("Throw it away", role: .destructive) { throwing = filed }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("voice.throwLast")
        }
    }

    private func row(_ row: VoiceNoteRow) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                // Stay in this section: on the Mac the note opens in the third column with the
                // list still beside it, on the phone the back arrow comes straight back here.
                model.show(section: .voiceNotes, notePath: row.path)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(Txt.listTitle)
                        .lineLimit(2)
                    Text(secondLine(row))
                        .font(Txt.listSecond)
                        .foregroundStyle(.soft)
                    if !row.firstWords.isEmpty {
                        Text(row.firstWords)
                            .font(Txt.listSecond)
                            .foregroundStyle(.soft)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice.row.\(row.path)")
            Menu {
                actions(for: row)
            } label: {
                Text("More")
                    .font(Txt.label)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityIdentifier("voice.more.\(row.path)")
        }
        .contextMenu { actions(for: row) }
    }

    private func secondLine(_ row: VoiceNoteRow) -> String {
        [row.when, row.length].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    @ViewBuilder
    private func actions(for row: VoiceNoteRow) -> some View {
        Button("Read aloud") { model.readVoiceNoteAloud(path: row.path) }
            .accessibilityIdentifier("voice.readAloud")
        #if os(iOS)
        Button("Write it up again") { model.writeVoiceNoteAgain(path: row.path) }
            .accessibilityIdentifier("voice.writeAgain")
        #endif
        if let entry = VoiceHistoryStore.entry(path: row.path), entry.path == VoiceHistoryStore.load().first?.path {
            Button("Throw it away", role: .destructive) { throwing = entry }
        }
    }
}

/// **Check the thought**: the card after a recording (Settings › Voice › Check after
/// filing). The thought is already filed; **Save** keeps it with the changes made here,
/// **Cancel** keeps it as it is, **Throw it away** takes it back out (the note goes to Deleted).
struct VoiceCheckView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var filed: VoiceFiled?
    @State private var title = ""
    @State private var removed: Set<String> = []

    private var tint: Color { SidebarSection.voiceNotes.tint }

    private var isPhone: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let filed {
                Text(whereWords(filed))
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .accessibilityIdentifier("voice.check.where")
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("voice.check.title")
                if let summary = summaryText(filed) {
                    Text(summary)
                        .font(Txt.value)
                        .lineLimit(5)
                        .accessibilityIdentifier("voice.check.summary")
                }
                if filed.tasks.isEmpty {
                    Text("No tasks were found.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                } else {
                    Text("Tasks")
                        .font(Txt.listTitle)
                        .foregroundStyle(tint.ink)
                    ForEach(filed.tasks, id: \.self) { task in
                        Toggle(isOn: keeping(task)) {
                            Text(task)
                                .font(Txt.value)
                        }
                        .accessibilityIdentifier("voice.check.task.\(task)")
                    }
                    Text("Switch off a task you do not want. It is taken out of the Inbox.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                }
                Divider()
                Button("Throw it away", role: .destructive) {
                    model.throwAwayVoice(filed)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("voice.check.throwAway")
            } else {
                Text("Nothing is waiting to be checked.")
                    .font(Txt.value)
                    .foregroundStyle(.soft)
                    .accessibilityIdentifier("voice.check.nothing")
            }
        }
        .padding(isPhone ? 14 : 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
        .sheetChrome(title: "Check the thought", tint: tint, actionTitle: "Save",
                     canAct: filed != nil, actionIdentifier: "voice.check.save",
                     cancel: cancel, act: save)
        .onAppear(perform: load)
    }

    private func load() {
        guard filed == nil, let next = VoiceHistory.nextToCheck(in: VoiceHistoryStore.load()) else { return }
        filed = next
        title = next.title
        removed = []
    }

    private func keeping(_ task: String) -> Binding<Bool> {
        Binding(get: { !removed.contains(task) },
                set: { keep in
                    if keep { removed.remove(task) } else { removed.insert(task) }
                })
    }

    private func whereWords(_ filed: VoiceFiled) -> String {
        let place = filed.toToday ? "today\u{2019}s note" : "the Inbox"
        return "Recorded \(VoiceThought.clock(filed.duration)) \u{00B7} saved to \(place)"
    }

    private func summaryText(_ filed: VoiceFiled) -> String? {
        guard let note = model.note(at: filed.path) else { return nil }
        return VoiceNoteText.summary(of: note.text)
    }

    private func cancel() {
        if let filed { model.leaveVoiceCheck(filed) }
        dismiss()
    }

    private func save() {
        if let filed {
            model.saveVoiceCheck(filed, title: title, remove: filed.tasks.filter { removed.contains($0) })
        }
        dismiss()
    }
}
