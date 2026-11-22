import AppIntents
import ParagonCore

#if os(iOS)
import UIKit

/// Build 348: **Record a Thought** — for the Action Button, Siri and Shortcuts.
///
/// One action, two presses: the first starts recording (the Lock Screen shows the words as they
/// are said), the second stops it and files the thought (`VoiceRecorder`). PARAGON is not opened
/// (build 358). iPhone and iPad only, iOS 26 or newer: Apple's on-phone speech-to-text came then.
struct RecordThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Thought"
    static let description = IntentDescription(
        "Press once to start recording, press again to stop. PARAGON writes down what you said, makes a title, a short summary and the tasks it heard, and puts them in your Inbox. Everything happens on the phone.",
        categoryName: "Capture")
    // Build 358: a press does not open PARAGON (builds 355 to 357 did, which is not the design).
    // Build 360: the Lock Screen card is allowed from the background because the action is also
    // a `LiveActivityIntent` (below).
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try await Self.pressed(into: .inbox)
    }

    /// One press of either action: start when nothing records, else stop. A second press of
    /// **Record into Today's Note** files into today's note, of **Record a Thought** where the
    /// recording was meant to go.
    ///
    /// Build 357: no answer card. An empty answer was drawn as a white card holding only
    /// **Done**, which looked as if nothing was recording. The Lock Screen card says what
    /// happens; when PARAGON is on screen (the in-app record link, or the press came while it
    /// was open), a short message at the foot of the screen says it too.
    @MainActor
    static func pressed(into place: CaptureTarget) async throws -> some IntentResult {
        guard #available(iOS 26.0, *) else { throw VoiceProblem.tooOld }
        let recorder = VoiceRecorder.shared
        if recorder.isRecording {
            let outcome = await recorder.stopAndFile(into: place == .today ? .today : nil)
            VoiceLog.note("Stop finished: \(VoiceLog.words(for: outcome)).")
            switch outcome {
            case .saved(let title, let tasks):
                let found = tasks == 0 ? "" : tasks == 1 ? " One task found." : " \(tasks) tasks found."
                let where_ = recorder.place == .today ? "today's note" : "the Inbox"
                sayOnScreen("Saved to \(where_): \(title).\(found)", seconds: 5)
            case .kept:
                sayOnScreen("Saved. It is filed the next time PARAGON opens your notes.", seconds: 5)
            case .nothingHeard:
                sayOnScreen("Nothing heard, so nothing was saved.", seconds: 5)
            case .notRecording:
                sayOnScreen("Nothing was recording.")
            }
            return .result()
        }
        do {
            try await recorder.start(into: place)
        } catch {
            VoiceLog.note("The press ended with: \(error.localizedDescription)")
            throw VoiceProblem.cannotStart(error.localizedDescription)
        }
        VoiceLog.note("The press returned. Recording goes on.")
        sayOnScreen("Recording. Press again to stop.", seconds: 5)
        return .result()
    }

    /// A message at the foot of PARAGON, only when it is on screen: shown later, in an app
    /// opened by hand, it would talk about a press long past.
    @MainActor
    private static func sayOnScreen(_ message: String, seconds: Double = 2.5) {
        guard UIApplication.shared.applicationState == .active else { return }
        AppModel.shared.flash(message, seconds: seconds)
    }
}

/// Apple lets an action record in the background only when it says it records, and then it must
/// show a Live Activity while it does (`VoiceRecorder.showActivity`).
@available(iOS 18.0, *)
extension RecordThoughtIntent: AudioRecordingIntent {}

/// Build 360: and only an action that says it starts a Live Activity may start one with PARAGON
/// in the background. Without this iOS refused the Lock Screen card ("Target is not foreground",
/// builds 354 and 358), and iOS 27 then stopped the app, because a recording action may not end
/// with the microphone on and no card. The focus timer's start has done the same since build 317.
extension RecordThoughtIntent: LiveActivityIntent {}

/// Build 349: **Record into Today's Note** — the same recorder, but the tasks and the line go
/// into today's daily note instead of the Inbox. The Action Button can hold this one instead
/// (Apple's Action Button has no long press of its own).
struct RecordThoughtIntoTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Record into Today's Note"
    static let description = IntentDescription(
        "Press once to start recording, press again to stop. Like Record a Thought, but the tasks and a line to the note go into today's note instead of the Inbox.",
        categoryName: "Capture")
    // Build 358: a press does not open PARAGON (builds 355 to 357 did, which is not the design).
    // Build 360: the Lock Screen card is allowed from the background because the action is also
    // a `LiveActivityIntent` (below).
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try await RecordThoughtIntent.pressed(into: .today)
    }
}

@available(iOS 18.0, *)
extension RecordThoughtIntoTodayIntent: AudioRecordingIntent {}

/// Build 360: see `RecordThoughtIntent: LiveActivityIntent`.
extension RecordThoughtIntoTodayIntent: LiveActivityIntent {}

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
