#if os(iOS)
import SwiftUI
import ParagonCore

/// Round 350 (voice-words): Settings › Voice › **Words it mishears**.
///
/// A short list of words the speech-to-text gets wrong: the word as it should be written, and
/// optionally what it is heard as. The written words are also given to the speech analyzer to
/// listen for; "heard as" spellings are put right in the text after recording. **Cancel** leaves
/// without saving, **Save** keeps the list (stored in the setting `voiceWords`).
struct VoiceWordsPage: View {
    @AppStorage("voiceWords") private var stored = ""
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [VoiceReplacement] = []
    @State private var loaded = false

    var body: some View {
        List {
            Section {
                ForEach($rows) { $row in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Word as it should be written", text: $row.word)
                            .font(Txt.value)
                            .accessibilityIdentifier("voiceWords.word")
                        TextField("Heard as (optional, separate with commas)", text: $row.heardAs)
                            .font(Txt.label)
                            .foregroundStyle(.soft)
                            .accessibilityIdentifier("voiceWords.heard")
                    }
                }
                .onDelete { offsets in
                    rows.remove(atOffsets: offsets)
                }
                Button {
                    rows.append(VoiceReplacement(word: ""))
                } label: {
                    MarkLabel("Add a word", "plus")
                }
                .accessibilityIdentifier("voiceWords.add")
            } header: {
                Text("Words")
            } footer: {
                Text("Names and odd words you say. PARAGON listens for them, and puts them right when the speech-to-text writes them wrong. Swipe a row to remove it.")
            }
        }
        .navigationTitle("Words it mishears")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("voiceWords.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .accessibilityIdentifier("voiceWords.save")
            }
        }
        .onAppear {
            if !loaded {
                rows = VoiceReplacement.decode(stored)
                loaded = true
            }
        }
    }

    private func save() {
        let kept: [VoiceReplacement] = rows.filter { !$0.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        stored = VoiceReplacement.encode(kept)
        dismiss()
    }
}
#endif
