import Foundation
import ParagonCore
#if os(iOS)
import ActivityKit
import AppIntents

// Build 317: the focus timer as a Live Activity. **This file is in two targets**, the app and
// the widgets (`App/Shared` in project.yml): the app starts, updates and ends the activity, the
// widget extension draws it, and both must know the same types. The Mac has no Live
// Activities, so everything here is the iPhone's and the iPad's.

/// What a focus timer's Live Activity is: the words that never change while it runs, and
/// `FocusGlance` (Core, tested) for what does.
struct FocusActivityAttributes: ActivityAttributes {
    typealias ContentState = FocusGlance

    /// The task or block the clock runs on, as the bar in the app shows it.
    var title: String
    /// When the clock was first started: with the title, what tells this session from another.
    var startedAt: Date
}

/// What a button on the Live Activity asks for.
enum FocusActivityAction: String, Sendable {
    case pause, resume, stop
}

/// The way from a button on the Lock Screen to the app's own focus timer.
///
/// **A `LiveActivityIntent` runs inside the app**, never inside the widget extension: the
/// system starts PARAGON in the background if it has to. So the buttons act on the one real
/// timer (`AppModel.pauseFocus`, `resumeFocus`, `stopFocus`) and there is no second copy of its
/// state to keep in step. The app hands its handler in when its model is made; started cold,
/// that can be a moment after the button's code runs, so `run` waits for it briefly.
@MainActor
enum FocusActivityBridge {
    static var handler: ((FocusActivityAction) -> Void)?

    static func run(_ action: FocusActivityAction) async {
        var waited = 0
        while handler == nil, waited < 40 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        handler?(action)
    }
}

/// **Pause** on the Live Activity.
struct PauseFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause the focus timer"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        await FocusActivityBridge.run(.pause)
        return .result()
    }
}

/// **Go on** on the Live Activity.
struct ResumeFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Go on with the focus timer"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        await FocusActivityBridge.run(.resume)
        return .result()
    }
}

/// **Stop** on the Live Activity. The clock stops at once; PARAGON then opens on its one
/// question (**Done, tick it off** / **Save the time**), exactly as **Stop** in the app does.
struct StopFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop the focus timer"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await FocusActivityBridge.run(.stop)
        return .result()
    }
}
#endif
