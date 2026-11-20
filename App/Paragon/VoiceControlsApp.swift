import Foundation
import AVFoundation
import ParagonCore

// Round 350 (voice-controls): the app's side of the recorder's new buttons and pages.
// What is decided (marks, the voice notes list, taking a thought back, the words read aloud)
// is in Core, `VoiceControls.swift`. This file keeps the short list of thoughts just filed,
// reads a summary aloud, and puts the actions on `AppModel`.

/// The two switches in Settings › Voice.
enum VoiceSettings {
    static let checkKey = "voiceCheckFirst"
    static let readKey = "voiceReadAloud"
    static let languageKey = "voiceLanguage"

    /// **Check before filing**: on unless he turned it off.
    static var checksFirst: Bool {
        UserDefaults.standard.object(forKey: checkKey) as? Bool ?? true
    }

    /// **Read the summary aloud**: off unless he turned it on.
    static var readsAloud: Bool {
        UserDefaults.standard.bool(forKey: readKey)
    }

    /// The language to speak in: the voice language chosen in Settings, else the phone's.
    static var speechLanguage: String {
        let chosen = UserDefaults.standard.string(forKey: languageKey) ?? ""
        if !chosen.isEmpty { return chosen }
        return Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }
}

/// The newest thoughts the recorder filed, kept on this device (`VoiceFiled`).
enum VoiceHistoryStore {
    static let key = "voiceFiledHistory"

    static func load() -> [VoiceFiled] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([VoiceFiled].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [VoiceFiled]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
    }

    static func remember(_ filed: VoiceFiled) {
        save(VoiceHistory.adding(filed, to: load()))
    }

    static func forget(path: String) {
        save(VoiceHistory.removing(path: path, from: load()))
    }

    /// Replaces the entry for `oldPath` (a rename moved the note), keeping its place.
    static func replace(oldPath: String, with filed: VoiceFiled) {
        var list = load()
        if let at = list.firstIndex(where: { $0.path == oldPath }) {
            list[at] = filed
            save(list)
        }
    }

    static func entry(path: String) -> VoiceFiled? {
        load().first { $0.path == path }
    }
}

/// Reads a summary aloud. One speaker for the whole app, so a second press stops the first.
@MainActor
final class VoiceReader {
    static let shared = VoiceReader()
    private let speaker = AVSpeechSynthesizer()

    var isSpeaking: Bool { speaker.isSpeaking }

    func speak(_ text: String, language: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        }
        speaker.speak(utterance)
    }

    func stop() {
        if speaker.isSpeaking { _ = speaker.stopSpeaking(at: .immediate) }
    }
}

extension AppModel {
    /// Where the check card shows: a thought waits for it. Called when PARAGON comes to the
    /// front and when a recording ends while it is in front. A card already up, or another
    /// sheet, makes it wait its turn (`openWhenFree`).
    func presentVoiceCheckIfWaiting() {
        guard vault != nil, VoiceHistory.nextToCheck(in: VoiceHistoryStore.load()) != nil else { return }
        if activeSheet == .voiceCheck { return }
        openWhenFree(.voiceCheck)
    }

    /// The check card's **Save**: the tasks he took away leave, a new title renames the note,
    /// and the thought counts as checked.
    func saveVoiceCheck(_ filed: VoiceFiled, title: String, remove: [String]) {
        flushPendingEdits()
        guard let vault else { return }
        var current = filed
        current.checked = true
        if !remove.isEmpty {
            do {
                _ = try vault.dropVoiceTasks(filed, titles: remove)
                current.tasks = current.tasks.filter { !remove.contains($0) }
                reload()
            } catch VaultError.modifiedOnDisk {
                errorMessage = "The Inbox was changed on another device a moment ago, so the tasks were not taken out. Open the thought again to try once more."
                return
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        VoiceHistoryStore.replace(oldPath: filed.path, with: current)
        voiceHistoryStamp += 1
        let clean = VoiceThought.tidyTitle(title)
        if !clean.isEmpty, clean != filed.title {
            renameVoiceNote(path: filed.path, to: clean)
        }
    }

    /// Gives a voice note a new title (the note follows through `renameNote`, so every link to
    /// it is pointed at the new name) and keeps the list of filed thoughts in step.
    func renameVoiceNote(path: String, to title: String) {
        guard let note = self.note(at: path) else { return }
        renameNote(note, to: title)
        let moved: Note? = index.notesTagged(VoiceThought.tag).first { $0.displayTitle == title }
        guard let moved, var entry = VoiceHistoryStore.entry(path: path) else { return }
        entry.path = moved.relativePath
        entry.title = moved.displayTitle
        VoiceHistoryStore.replace(oldPath: path, with: entry)
        voiceHistoryStamp += 1
    }

    /// **Throw away**: the note goes to Deleted (30 days to put it back) and its open tasks and
    /// its line leave the Inbox or the daily note.
    func throwAwayVoice(_ filed: VoiceFiled) {
        flushPendingEdits()
        guard let vault else { return }
        do {
            let result = try vault.discardVoiceThought(filed)
            VoiceHistoryStore.forget(path: filed.path)
            voiceHistoryStamp += 1
            if selectedNotePath == filed.path { selectedNotePath = nil }
            reload()
            flash(result.words, seconds: 5)
        } catch VaultError.modifiedOnDisk {
            errorMessage = "A note was changed on another device a moment ago, so nothing was thrown away. Try again in a moment."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Marks the thought as seen without changing anything (the card's **Cancel**).
    func leaveVoiceCheck(_ filed: VoiceFiled) {
        var current = filed
        current.checked = true
        VoiceHistoryStore.replace(oldPath: filed.path, with: current)
        voiceHistoryStamp += 1
    }

    /// **Read aloud** on a voice note; a second press stops it.
    func readVoiceNoteAloud(path: String) {
        if VoiceReader.shared.isSpeaking {
            VoiceReader.shared.stop()
            return
        }
        let language = VoiceSettings.speechLanguage
        guard let note = self.note(at: path),
              let words = VoiceNoteText.spoken(from: note.text, language: language) else {
            flash("There is nothing to read aloud in this note yet.")
            return
        }
        VoiceReader.shared.speak(words, language: language)
    }
}

#if os(iOS)
extension AppModel {
    /// **Write it up again** on a voice note: Apple's on-device model reads what was said once
    /// more and writes a new title, summary and tasks. Tasks the note does not list yet are
    /// added; nothing is taken out.
    func writeVoiceNoteAgain(path: String) {
        if #available(iOS 26.0, *) {
            Task { await self.writeUpAgain(path: path) }
        } else {
            flash("Writing it up again needs iOS 26 or newer.")
        }
    }

    @available(iOS 26.0, *)
    private func writeUpAgain(path: String) async {
        guard let note = self.note(at: path), let said = VoiceNoteText.fullText(of: note.text) else {
            flash("This note has no full text to write up.")
            return
        }
        flash("Writing it up again\u{2026}", seconds: 8)
        let chosen = UserDefaults.standard.string(forKey: VoiceSettings.languageKey) ?? ""
        let locale = chosen.isEmpty ? Locale.current : Locale(identifier: chosen)
        let answer = await VoiceRecorder.writeUp(said, locale: locale, within: 60)
        switch answer {
        case .done(let title, let summary, let tasks):
            flushPendingEdits()
            guard let vault else { return }
            do {
                let added = try vault.rewriteVoiceNote(path: path, summary: summary, tasks: tasks) ?? []
                reload()
                let clean = VoiceThought.tidyTitle(title)
                if !clean.isEmpty, let current = self.note(at: path), clean != current.displayTitle {
                    renameVoiceNote(path: path, to: clean)
                }
                let more = added.isEmpty ? "" : added.count == 1 ? " One new task is in the Inbox." : " \(added.count) new tasks are in the Inbox."
                flash("Written up again." + more, seconds: 5)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .late:
            flash("Apple Intelligence took too long. Try again in a moment.")
        case .none:
            flash("Apple Intelligence is not available here, so nothing was changed.")
        }
    }
}
#endif
