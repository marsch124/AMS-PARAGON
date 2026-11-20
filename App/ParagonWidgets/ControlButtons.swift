import AppIntents
import SwiftUI
import WidgetKit

#if os(iOS)
// Round 350 (capture-inbox, picks 21 and 33): two buttons for Control Center and the Lock
// Screen (iOS 18 and newer) — **Capture** opens PARAGON straight in Quick capture, **Record a
// Thought** opens PARAGON and starts recording. Two separate buttons (his choice).
//
// **Apple's rule: opening an app needs the phone unlocked.** A press on the Lock Screen first
// asks for Face ID or the passcode, then PARAGON opens. A button that must work without
// unlocking cannot open an app; the Action Button (Record a Thought, build 348) is the one that
// records without opening PARAGON at all.
//
// The buttons only open a link (`amspara://capture`, `amspara://record`); the app answers it in
// `AppModel.handleCaptureControlLink`. The widget never touches the notes.

/// Opens PARAGON on a link. One intent per button, because a button's intent is fixed when the
/// control is drawn.
@available(iOS 18.0, *)
struct OpenCaptureControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture"
    static var isDiscoverable: Bool = false
    static let description = IntentDescription("Opens PARAGON straight in Quick capture.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "amspara://capture")!))
    }
}

@available(iOS 18.0, *)
struct OpenRecordControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Thought"
    static var isDiscoverable: Bool = false
    static let description = IntentDescription("Opens PARAGON and starts recording a thought. Press again in PARAGON, or on the Lock Screen, to stop.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "amspara://record")!))
    }
}

@available(iOS 18.0, *)
struct CaptureControl: ControlWidget {
    static let kind = "com.schabbauer.AMSPara.control.capture"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenCaptureControlIntent()) {
                Label("Capture", image: "ControlCapture")
            }
        }
        .displayName("Capture")
        .description("Opens PARAGON straight in Quick capture.")
    }
}

@available(iOS 18.0, *)
struct RecordThoughtControl: ControlWidget {
    static let kind = "com.schabbauer.AMSPara.control.record"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenRecordControlIntent()) {
                Label("Record a Thought", image: "ControlRecord")
            }
        }
        .displayName("Record a Thought")
        .description("Opens PARAGON and starts recording a thought.")
    }
}
#endif
