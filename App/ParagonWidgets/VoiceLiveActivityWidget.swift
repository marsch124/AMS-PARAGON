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
                    VoiceDot(stage: context.state.stage, size: 11, intoToday: context.state.intoToday, paused: context.state.paused)
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
                    VStack(alignment: .leading, spacing: 6) {
                        VoiceCardBody(state: context.state, island: true)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                VoiceDot(stage: context.state.stage, size: 9, paused: context.state.paused)
                    .padding(.leading, 2)
            } compactTrailing: {
                VoiceClock(startedAt: context.attributes.startedAt, state: context.state, trailing: true)
                    .font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                VoiceDot(stage: context.state.stage, size: 9, paused: context.state.paused)
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
    /// Build 349: Today's own purple (its night shade), for today's note.
    static let today = Color(lightHex: 0xA98FE0, darkHex: 0xA98FE0)

    /// Still recording (or about to): the buttons show.
    static func isRunning(_ s: VoiceActivityAttributes.ContentState) -> Bool {
        s.stage == .listening || s.stage == .preparing
    }

    /// Where it goes, in the words the rest of PARAGON uses.
    static func place(_ s: VoiceActivityAttributes.ContentState) -> String {
        s.intoToday ? "Today's note" : "Inbox"
    }

    static func heading(_ s: VoiceActivityAttributes.ContentState) -> String {
        switch s.stage {
        case .preparing: return "Getting ready"
        case .listening: return s.paused ? "Paused · \(place(s))" : "Listening · \(place(s))"
        case .writing: return "Writing it up…"
        case .saved: return s.intoToday ? "Saved to today's note" : "Saved to Inbox"
        case .nothing: return "Nothing saved"
        }
    }

    /// Build 349: "1 task heard" once he said "task" for one; empty before.
    static func heard(_ s: VoiceActivityAttributes.ContentState) -> String {
        guard s.stage == .listening else { return "" }
        var parts: [String] = []
        if s.tasksFound > 0 { parts.append(s.tasksFound == 1 ? "1 task heard" : "\(s.tasksFound) tasks heard") }
        // Round 350: the moments he marked.
        if s.marks > 0 { parts.append(s.marks == 1 ? "1 marked" : "\(s.marks) marked") }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// Build 363: the key points the card lists (`VoiceLiveSummary`): while recording, paused
    /// and during the write-up; on the saved card only when no summary came.
    static func points(_ s: VoiceActivityAttributes.ContentState) -> [String] {
        switch s.stage {
        case .listening, .preparing, .writing: return Array(s.points.prefix(3))
        case .saved: return s.summary.isEmpty ? Array(s.points.prefix(3)) : []
        case .nothing: return []
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
                VoiceDot(stage: state.stage, size: 9, intoToday: state.intoToday, paused: state.paused)
                Text(VoiceLook.heading(state))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state.stage == .listening && !state.paused ? VoiceLook.red : .white)
                    .lineLimit(1)
                VoiceClock(startedAt: startedAt, state: state)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .opacity(0.8)
                Spacer(minLength: 4)
            }
            VoiceCardBody(state: state)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        // Build 363: with key points the card holds more lines; iOS cuts a card off at 160 points.
        .padding(.vertical, VoiceLook.points(state).isEmpty ? 13 : 10)
    }
}

/// Build 363: what stands under the heading, on the Lock Screen and in the opened Dynamic
/// Island.
/// - No key points yet (or none wanted): as before — two lines of live words, two rows of buttons.
/// - With key points: the points, one line of the last words, and the four buttons in one row.
/// - Saved: the title and the tasks found, then the summary (the last key points when it came late).
struct VoiceCardBody: View {
    let state: VoiceActivityAttributes.ContentState
    var island = false

    var body: some View {
        let points = VoiceLook.points(state)
        if state.stage == .saved {
            Text(VoiceLook.body(state))
                .font(island ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(points.isEmpty && state.summary.isEmpty ? 3 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !state.summary.isEmpty {
                Text(state.summary)
                    .font(island ? .caption : .footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !points.isEmpty {
                VoicePointList(points: points, island: island)
            }
        } else if points.isEmpty {
            Text(VoiceLook.body(state))
                .font(island ? .caption : .subheadline)
                .foregroundStyle(island ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
                .lineLimit(VoiceLook.isRunning(state) ? 2 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if VoiceLook.isRunning(state) {
                VoiceButtonRow(state: state)
            }
        } else {
            VoicePointList(points: points, island: island)
            if VoiceLook.isRunning(state) {
                VoiceLastWords(state: state)
                VoiceButtonRow(state: state, oneRow: true)
            }
        }
    }
}

/// Build 363: the key points, one line each behind a small bullet.
struct VoicePointList: View {
    let points: [String]
    var island = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\u{2022}")
                        .foregroundStyle(.white.opacity(0.6))
                    Text(point)
                        .lineLimit(1)
                }
            }
        }
        .font(island ? .caption : .footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key points so far: " + points.joined(separator: "; "))
    }
}

/// Build 363: under the key points — "1 task heard · 1 marked", then the last words said, on
/// one line. A long line loses its start, so the newest words stay in sight.
struct VoiceLastWords: View {
    let state: VoiceActivityAttributes.ContentState

    var body: some View {
        let heard = VoiceLook.heard(state)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if !heard.isEmpty {
                Text(heard)
                    .fontWeight(.semibold)
                    .fixedSize()
            }
            Text(state.words)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.75))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Red dot while it records, the Inbox tray once saved, a pale dot while it works or after nothing.
struct VoiceDot: View {
    let stage: VoiceActivityAttributes.ContentState.Stage
    var size: CGFloat
    var intoToday = false
    /// Round 350: recording is paused, so the dot is not red.
    var paused = false

    var body: some View {
        if stage == .saved {
            // Saved: the Inbox's own tray mark in its green, not a dot — a green dot already
            // means "a project without an icon" in PARAGON. Build 349: today's note = Today's sun.
            WidgetMark(name: intoToday ? "sun.max" : "tray", size: size + 5)
                .foregroundStyle(intoToday ? VoiceLook.today : VoiceLook.inbox)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(stage == .listening && !paused ? VoiceLook.red : Color.white.opacity(0.45))
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
        if state.stage == .listening && !state.paused {
            // Round 350: the time spent paused is not counted, so the clock starts that much later.
            Text(timerInterval: startedAt.addingTimeInterval(state.pausedSeconds)...Date.distantFuture, countsDown: false)
                .multilineTextAlignment(trailing ? .trailing : .leading)
                .frame(maxWidth: 52, alignment: trailing ? .trailing : .leading)
        } else {
            Text(state.length)
        }
    }
}

/// Build 349: under the words while recording — "N tasks heard" at the left, then the
/// second button (stops and files in the other place) and the red **Stop**.
struct VoiceButtonRow: View {
    let state: VoiceActivityAttributes.ContentState
    /// Build 363: with key points on the card the four buttons share one row, in the same
    /// order; "N tasks heard" stands with the last words then.
    var oneRow = false

    var body: some View {
        if oneRow {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                VoiceMarkButton(pad: 10)
                VoicePauseButton(paused: state.paused, pad: 10)
                VoiceOtherPlaceButton(intoToday: state.intoToday, pad: 10)
                VoiceStopButton(pad: 10)
            }
        } else {
            twoRows
        }
    }

    private var twoRows: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(VoiceLook.heard(state))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                Spacer(minLength: 4)
                VoiceMarkButton()
                VoicePauseButton(paused: state.paused)
            }
            HStack(spacing: 8) {
                Spacer(minLength: 4)
                VoiceOtherPlaceButton(intoToday: state.intoToday)
                VoiceStopButton()
            }
        }
    }
}

/// Round 350: **Mark** keeps the sentence being said in bold in the note. Words only: a flag
/// already means a project in PARAGON.
struct VoiceMarkButton: View {
    var pad: CGFloat = 12

    var body: some View {
        Button(intent: MarkVoiceIntent()) {
            Text("Mark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, pad)
                .frame(height: 30)
                .background(Color.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark this moment")
    }
}

/// Round 350: **Pause** rests the microphone and stops the clock; **Go on** continues into the
/// same note.
struct VoicePauseButton: View {
    let paused: Bool
    var pad: CGFloat = 12

    var body: some View {
        Button(intent: PauseVoiceIntent()) {
            HStack(spacing: 5) {
                FocusMarkView(d: paused ? FocusMark.play : FocusMark.pause, size: 13)
                Text(paused ? "Go on" : "Pause")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, pad)
            .frame(height: 30)
            .background(Color.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(paused ? "Go on recording" : "Pause recording")
    }
}

/// Build 349: stops and files into the place the recording was NOT meant for: **Today**
/// (today's note, Today's sun in Today's purple) or **Inbox** (the tray in the Inbox's green).
struct VoiceOtherPlaceButton: View {
    let intoToday: Bool
    var pad: CGFloat = 12

    var body: some View {
        Button(intent: StopVoiceIntent(place: intoToday ? "inbox" : "today")) {
            HStack(spacing: 5) {
                WidgetMark(name: intoToday ? "tray" : "sun.max", size: 14)
                    .foregroundStyle(intoToday ? VoiceLook.inbox : VoiceLook.today)
                Text(intoToday ? "Inbox" : "Today")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, pad)
            .frame(height: 30)
            .background(Color.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(intoToday ? "Stop and save to the Inbox" : "Stop and save to today's note")
    }
}

/// **Stop**: the main button, full red, with its word.
struct VoiceStopButton: View {
    var pad: CGFloat = 12

    var body: some View {
        Button(intent: StopVoiceIntent()) {
            HStack(spacing: 5) {
                FocusMarkView(d: FocusMark.stop, size: 13)
                Text("Stop")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, pad)
            .frame(height: 30)
            .background(VoiceLook.red, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop recording")
    }
}
#endif
