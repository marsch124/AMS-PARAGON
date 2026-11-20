import WidgetKit
import SwiftUI
import ParagonCore

#if os(iOS)
import ActivityKit
import AppIntents

/// Build 348: **Record a thought** on the Lock Screen and in the Dynamic Island.
///
/// While recording: a red dot, "Listening", the clock (counted by the system from `startedAt`)
/// and the last words heard, with a red **Stop**. Then "Writing it up…", then "Saved to Inbox"
/// with the title and how many tasks were found. Same dark look as the focus timer's banner,
/// so it reads on any wallpaper by day and by night.
struct VoiceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoiceActivityAttributes.self) { context in
            VoiceBanner(startedAt: context.attributes.startedAt, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.62))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VoiceDot(stage: context.state.stage, size: 11)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VoiceClock(startedAt: context.attributes.startedAt, state: context.state, trailing: true)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .frame(maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(VoiceLook.heading(context.state))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(VoiceLook.body(context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if context.state.stage == .listening || context.state.stage == .preparing {
                            VoiceStopButton()
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                VoiceDot(stage: context.state.stage, size: 9)
                    .padding(.leading, 2)
            } compactTrailing: {
                VoiceClock(startedAt: context.attributes.startedAt, state: context.state, trailing: true)
                    .font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                VoiceDot(stage: context.state.stage, size: 9)
            }
            .keylineTint(VoiceLook.red)
        }
    }
}

enum VoiceLook {
    /// Recording.
    static let red = Color(red: 0.886, green: 0.294, blue: 0.290)
    /// The Inbox's own green (its night shade: the card is always dark), for "Saved to Inbox".
    static let inbox = Color(lightHex: 0xB4D25A, darkHex: 0xB4D25A)

    static func heading(_ s: VoiceActivityAttributes.ContentState) -> String {
        switch s.stage {
        case .preparing: return "Getting ready"
        case .listening: return "Listening"
        case .writing: return "Writing it up…"
        case .saved: return "Saved to Inbox"
        case .nothing: return "Nothing saved"
        }
    }

    static func body(_ s: VoiceActivityAttributes.ContentState) -> String {
        switch s.stage {
        case .saved:
            let tasks = s.tasksFound == 0 ? "no tasks found" : s.tasksFound == 1 ? "1 task found" : "\(s.tasksFound) tasks found"
            return "\(s.title) · \(tasks)"
        default:
            return s.words
        }
    }
}

struct VoiceBanner: View {
    let startedAt: Date
    let state: VoiceActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VoiceDot(stage: state.stage, size: 9)
                Text(VoiceLook.heading(state))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state.stage == .listening ? VoiceLook.red : .white)
                VoiceClock(startedAt: startedAt, state: state)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .opacity(0.8)
                Spacer(minLength: 4)
                if state.stage == .listening || state.stage == .preparing {
                    VoiceStopButton()
                }
            }
            Text(VoiceLook.body(state))
                .font(.subheadline)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// Red dot while it records, the Inbox tray once saved, a pale dot while it works or after nothing.
struct VoiceDot: View {
    let stage: VoiceActivityAttributes.ContentState.Stage
    var size: CGFloat

    var body: some View {
        if stage == .saved {
            // Saved: the Inbox's own tray mark in its green, not a dot — a green dot already
            // means "a project without an icon" in PARAGON.
            WidgetMark(name: "tray", size: size + 5)
                .foregroundStyle(VoiceLook.inbox)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(stage == .listening ? VoiceLook.red : Color.white.opacity(0.45))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// The running time while recording (the system counts it); the length once stopped.
struct VoiceClock: View {
    let startedAt: Date
    let state: VoiceActivityAttributes.ContentState
    /// In the Dynamic Island the time stands at the right edge; on the Lock Screen right after
    /// "Listening".
    var trailing = false

    var body: some View {
        if state.stage == .listening {
            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                .multilineTextAlignment(trailing ? .trailing : .leading)
                .frame(maxWidth: 52, alignment: trailing ? .trailing : .leading)
        } else {
            Text(state.length)
        }
    }
}

/// **Stop**: the main button, full red, with its word.
struct VoiceStopButton: View {
    var body: some View {
        Button(intent: StopVoiceIntent()) {
            HStack(spacing: 5) {
                FocusMarkView(d: FocusMark.stop, size: 13)
                Text("Stop")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(VoiceLook.red, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop recording")
    }
}
#endif
