import Foundation
#if os(iOS)
import ActivityKit
import AppIntents

// Build 348: **Record a thought** on the Lock Screen and in the Dynamic Island. Like
// `FocusActivityShared.swift` this file is in two targets: the app starts and updates the
// activity, the widget extension draws it, and both must know the same types.

/// One recording's Live Activity.
struct VoiceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        enum Stage: String, Codable, Hashable, Sendable {
            /// The speech model is being fetched (first recording in a language).
            case preparing
            /// Recording: the clock runs from `startedAt`, `words` are the last words heard.
            case listening
            /// Stopped; the on-device model is writing the title, summary and tasks.
            case writing
            /// In the Inbox: `title` and `tasksFound` say what was saved.
            case saved
            /// Nothing was heard, or something went wrong: `words` says what.
            case nothing
        }

        var stage: Stage
        var words: String
        var title: String
        /// Saved: the tasks filed. Listening (build 349): the tasks he marked by saying "task".
        var tasksFound: Int
        /// How long it ran, once stopped ("0:42").
        var length: String
        /// Build 349: the thought is meant for today's daily note, not the Inbox.
        var intoToday = false

        static func listening(_ words: String, intoToday: Bool = false, heard: Int = 0) -> Self {
            Self(stage: .listening, words: words, title: "", tasksFound: heard, length: "", intoToday: intoToday)
        }
    }

    /// When recording began: the Lock Screen's clock counts from here by itself.
    var startedAt: Date
}

/// The way from **Stop** on the Lock Screen to the app's one recorder. A `LiveActivityIntent`
/// runs inside the app, never in the widget extension, so it stops the real recording.
@MainActor
enum VoiceActivityBridge {
    /// Build 349: "" files where the recording was meant to go, "today" or "inbox" there.
    static var stop: (@MainActor (String) async -> Void)?
    /// Makes the app's model, which hands `stop` in. Set by the app's delegate at launch.
    static var wake: (@MainActor () -> Void)?

    static func runStop(_ place: String = "") async {
        if stop == nil { wake?() }
        var waited = 0
        while stop == nil, waited < 40 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        await stop?(place)
    }
}

/// **Stop** on the Lock Screen and in the Dynamic Island, and (build 349) the second button
/// beside it that stops and files into the other place: **Today** or **Inbox**.
struct StopVoiceIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop recording the thought"
    static var isDiscoverable: Bool = false

    /// "" = where the recording was meant to go; "today" or "inbox".
    @Parameter(title: "Place")
    var place: String

    init() { place = "" }
    init(place: String) { self.place = place }

    func perform() async throws -> some IntentResult {
        await VoiceActivityBridge.runStop(place)
        return .result()
    }
}
#endif
