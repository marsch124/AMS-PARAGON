import AppIntents
import ParagonCore

#if os(iOS)
/// Build 348: **Record a Thought** — for the Action Button, Siri and Shortcuts.
///
/// One action, two presses: the first starts recording (the Lock Screen shows the words as they
/// are said), the second stops it and files the thought (`VoiceRecorder`). It never opens the
/// app. iPhone and iPad only, iOS 26 or newer: Apple's on-phone speech-to-text came then.
struct RecordThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Thought"
    static let description = IntentDescription(
        "Press once to start recording, press again to stop. PARAGON writes down what you said, makes a title, a short summary and the tasks it heard, and puts them in your Inbox. Everything happens on the phone.",
        categoryName: "Capture")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard #available(iOS 26.0, *) else { throw VoiceProblem.tooOld }
        let recorder = VoiceRecorder.shared
        if recorder.isRecording {
            switch await recorder.stopAndFile() {
            case .saved(let title, let tasks):
                let found = tasks == 0 ? "" : tasks == 1 ? " One task found." : " \(tasks) tasks found."
                return .result(dialog: IntentDialog(stringLiteral: "Saved to Inbox: \(title).\(found)"))
            case .kept:
                return .result(dialog: "Saved. It goes into the Inbox the next time PARAGON opens your notes.")
            case .nothingHeard:
                return .result(dialog: "Nothing heard, so nothing was saved.")
            case .notRecording:
                return .result(dialog: "Nothing was recording.")
            }
        }
        do {
            try await recorder.start()
        } catch {
            throw VoiceProblem.cannotStart(error.localizedDescription)
        }
        // No spoken answer here: it would be recorded.
        return .result(dialog: "")
    }
}

/// Apple lets an action record in the background only when it says it records, and then it must
/// show a Live Activity while it does (`VoiceRecorder.showActivity`).
@available(iOS 18.0, *)
extension RecordThoughtIntent: AudioRecordingIntent {}

enum VoiceProblem: Error, CustomLocalizedStringResourceConvertible {
    case tooOld
    case cannotStart(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .tooOld: return "Record a thought needs iOS 26 or newer."
        case .cannotStart(let why): return "\(why)"
        }
    }
}
#endif
