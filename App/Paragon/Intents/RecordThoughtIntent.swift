import AppIntents
import ParagonCore

#if os(iOS)
/// Build 348: **Record a Thought** — for the Action Button, Siri and Shortcuts.
///
/// One action, two presses: the first starts recording (the Lock Screen shows the words as they
/// are said), the second stops it and files the thought (`VoiceRecorder`). Since build 355 it opens
/// the app (iOS refuses the Lock Screen card from the background). iPhone and iPad only, iOS 26 or newer: Apple's on-phone speech-to-text came then.
struct RecordThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Thought"
    static let description = IntentDescription(
        "Press once to start recording, press again to stop. PARAGON writes down what you said, makes a title, a short summary and the tasks it heard, and puts them in your Inbox. Everything happens on the phone.",
        categoryName: "Capture")
    // Build 355: iOS will not show the Lock Screen card for an app in the background ("Target
    // is not foreground", seen in his log on 21 November), and without the card it stops the
    // recording. So a press brings PARAGON to the front; the recording goes on after he leaves.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await Self.pressed(into: .inbox)
    }

    /// One press of either action: start when nothing records, else stop. A second press of
    /// **Record into Today's Note** files into today's note, of **Record a Thought** where the
    /// recording was meant to go.
    @MainActor
    static func pressed(into place: CaptureTarget) async throws -> some IntentResult & ProvidesDialog {
        guard #available(iOS 26.0, *) else { throw VoiceProblem.tooOld }
        // Build 355: the press opens PARAGON, so the start screen steps aside (build 329).
        AppModel.shared.arrived(by: .shortcut)
        let recorder = VoiceRecorder.shared
        if recorder.isRecording {
            let outcome = await recorder.stopAndFile(into: place == .today ? .today : nil)
            VoiceLog.note("Stop finished: \(VoiceLog.words(for: outcome)).")
            switch outcome {
            case .saved(let title, let tasks):
                let found = tasks == 0 ? "" : tasks == 1 ? " One task found." : " \(tasks) tasks found."
                let where_ = recorder.place == .today ? "today's note" : "Inbox"
                return .result(dialog: IntentDialog(stringLiteral: "Saved to \(where_): \(title).\(found)"))
            case .kept:
                return .result(dialog: "Saved. It is filed the next time PARAGON opens your notes.")
            case .nothingHeard:
                return .result(dialog: "Nothing heard, so nothing was saved.")
            case .notRecording:
                return .result(dialog: "Nothing was recording.")
            }
        }
        do {
            try await recorder.start(into: place)
        } catch {
            VoiceLog.note("The press ended with: \(error.localizedDescription)")
            throw VoiceProblem.cannotStart(error.localizedDescription)
        }
        VoiceLog.note("The press returned. Recording goes on.")
        // No spoken answer here: it would be recorded.
        return .result(dialog: "")
    }
}

/// Apple lets an action record in the background only when it says it records, and then it must
/// show a Live Activity while it does (`VoiceRecorder.showActivity`).
@available(iOS 18.0, *)
extension RecordThoughtIntent: AudioRecordingIntent {}

/// Build 349: **Record into Today's Note** — the same recorder, but the tasks and the line go
/// into today's daily note instead of the Inbox. The Action Button can hold this one instead
/// (Apple's Action Button has no long press of its own).
struct RecordThoughtIntoTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Record into Today's Note"
    static let description = IntentDescription(
        "Press once to start recording, press again to stop. Like Record a Thought, but the tasks and a line to the note go into today's note instead of the Inbox.",
        categoryName: "Capture")
    // Build 355: iOS will not show the Lock Screen card for an app in the background ("Target
    // is not foreground", seen in his log on 21 November), and without the card it stops the
    // recording. So a press brings PARAGON to the front; the recording goes on after he leaves.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await RecordThoughtIntent.pressed(into: .today)
    }
}

@available(iOS 18.0, *)
extension RecordThoughtIntoTodayIntent: AudioRecordingIntent {}

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
