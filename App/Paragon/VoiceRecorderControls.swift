import Foundation
import ParagonCore

// Round 350 (voice-controls): what the recorder does once a thought is filed — it is kept in
// the list of the newest thoughts (so it can be checked, or thrown away), and read aloud when
// Settings › Voice says so.
@available(iOS 26.0, macOS 26.0, *)
extension VoiceRecorder {
    func afterFiling(path: String, title: String, thought: VoiceThought, day: DateOnly, locale: String) {
        let model = AppModel.shared
        let waitsForCheck = VoiceSettings.checksFirst
        let filed = VoiceFiled(path: path, title: title, toToday: place == .today, day: day.description,
                               tasks: thought.finalTasks, duration: thought.duration, locale: locale,
                               madeAt: Date(), checked: !waitsForCheck)
        VoiceHistoryStore.remember(filed)
        model.voiceHistoryStamp += 1
        // The thought is already filed, so nothing is lost if he never opens the card. It shows
        // when PARAGON is in front (now, or the next time it opens).
        if waitsForCheck { model.presentVoiceCheckIfWaiting() }
        if VoiceSettings.readsAloud,
           let words = VoiceNoteText.spoken(from: thought.noteText(today: day), language: locale) {
            VoiceReader.shared.speak(words, language: locale)
        }
    }
}
