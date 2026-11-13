import WidgetKit
import SwiftUI
import AMSIcons
import ParagonCore

#if os(iOS)
import ActivityKit
import AppIntents

/// The focus timer as a Live Activity (build 317): a banner on the Lock Screen and the Dynamic
/// Island, with the task, the running clock, the bar against the planned time, and **Pause** /
/// **Go on** / **Stop**.
///
/// **Nothing here ticks.** While the clock runs the system draws the time and the bar itself
/// from two dates (`Text(timerInterval:)`, `ProgressView(timerInterval:)`), so it is right
/// every second with PARAGON closed. The app speaks only when something changes. The buttons
/// are `LiveActivityIntent`s (`App/Shared`), which run in the app, on the one real timer.
///
/// **The look is the bar in the app** — dark, the orange dot of a time block, white words — so
/// it reads on any wallpaper, by day and by night.
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusBanner(title: context.attributes.title, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.62))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FocusDot(state: context.state, size: 11)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusClock(state: context.state, trailing: true)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .frame(maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        FocusProgress(state: context.state)
                        if context.state.awaitingAnswer {
                            Text(FocusGlance.answerHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 8) {
                                if let note = context.state.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                FocusButtons(state: context.state, worded: true)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                FocusSmallMark(state: context.state)
                    .padding(.leading, 2)
            } compactTrailing: {
                FocusClock(state: context.state, trailing: true)
                    .font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                FocusMinimal(state: context.state)
            }
            .keylineTint(PlanLook.plan)
        }
    }
}

// MARK: - The Lock Screen banner

struct FocusBanner: View {
    let title: String
    let state: FocusGlance

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                FocusDot(state: state, size: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        FocusClock(state: state)
                            .font(.title2.weight(.bold).monospacedDigit())
                        if let note = state.note {
                            Text(note)
                                .font(.footnote)
                                .opacity(0.72)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                if !state.awaitingAnswer {
                    FocusButtons(state: state, worded: false)
                }
            }
            FocusProgress(state: state)
            if state.awaitingAnswer {
                Text(FocusGlance.answerHint)
                    .font(.footnote)
                    .opacity(0.72)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - The parts

/// The orange dot of a time block while the clock runs; pale while it stands still.
struct FocusDot: View {
    let state: FocusGlance
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(state.isPaused ? Color.white.opacity(0.45) : PlanLook.plan)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The time worked. Running, the system counts it from `countsFrom`; paused or stopped, it is
/// the fixed figure the bar in the app shows.
///
/// **A counting text asks for all the width there is**, so it is drawn on top of a hidden
/// figure of the right length ("00:00", or "0:00:00" from an hour on) and is exactly that wide.
/// The words after it then sit beside it. A clock that passes the hour with no update in
/// between is drawn a little smaller rather than cut.
struct FocusClock: View {
    let state: FocusGlance
    var trailing = false

    private var template: String {
        let long = state.workedSeconds >= 3600 || (state.plannedSeconds ?? 0) > 3600
        return long ? "0:00:00" : "00:00"
    }

    var body: some View {
        // Paused, the fixed figure sits in the same box as the counting one, so the words
        // after it ("of 50 min") do not jump sideways on Pause and Go on (designer, 317).
        Text(template)
            .lineLimit(1)
            .hidden()
            .overlay(alignment: trailing ? .trailing : .leading) {
                if state.isPaused {
                    Text(state.clock)
                        .lineLimit(1)
                        .fixedSize()
                } else {
                    // A day is far more than a clock ever runs: the app asks about one left
                    // running for over twelve hours.
                    Text(timerInterval: state.countsFrom...state.countsFrom.addingTimeInterval(24 * 3600),
                         countsDown: false)
                        .multilineTextAlignment(trailing ? .trailing : .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
    }
}

/// The bar against the planned time. Nothing at all when no time was planned.
struct FocusProgress: View {
    let state: FocusGlance

    var body: some View {
        if let end = state.plannedEnd, !state.isPaused {
            ProgressView(timerInterval: state.countsFrom...end, countsDown: false,
                         label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.linear)
                .tint(PlanLook.plan)
        } else if let fraction = state.fraction {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(Color.white.opacity(0.6))
        }
    }
}

/// **Pause** or **Go on**, and **Stop**. Round on the Lock Screen, like the bar in the app;
/// with their words in the open Dynamic Island, where there is room.
struct FocusButtons: View {
    let state: FocusGlance
    var worded: Bool

    var body: some View {
        HStack(spacing: 8) {
            if state.isPaused {
                Button(intent: ResumeFocusIntent()) {
                    face(mark: FocusMark.play, word: "Go on", main: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go on")
            } else {
                Button(intent: PauseFocusIntent()) {
                    face(mark: FocusMark.pause, word: "Pause", main: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause")
            }
            Button(intent: StopFocusIntent()) {
                face(mark: FocusMark.stop, word: "Stop", main: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop")
        }
    }

    /// The main button is full colour (orange, with dark ink); **Stop** is the quiet one.
    @ViewBuilder
    private func face(mark: String, word: String, main: Bool) -> some View {
        if worded {
            HStack(spacing: 5) {
                FocusMarkView(d: mark, size: 15)
                Text(word)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(main ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(main ? AnyShapeStyle(PlanLook.plan) : AnyShapeStyle(Color.white.opacity(0.2)),
                        in: Capsule())
            .contentShape(Capsule())
        } else {
            FocusMarkView(d: mark, size: 18)
                .foregroundStyle(main ? Color.black : Color.white)
                .frame(width: 38, height: 38)
                .background(main ? AnyShapeStyle(PlanLook.plan) : AnyShapeStyle(Color.white.opacity(0.2)),
                            in: Circle())
                .contentShape(Circle())
        }
    }
}

/// The three hand-drawn marks of the buttons, on the icon library's 24-point grid with its one
/// round 1.9 line. Play and pause are the library's own drawings (`ControlMark`); it has no
/// stop mark, so the square is drawn here in the same hand.
enum FocusMark {
    static let play = ControlMark.play.path
    static let pause = ControlMark.pause.path
    static let stop = "M7 7h10v10h-10Z"
}

struct FocusMarkView: View {
    let d: String
    var size: CGFloat

    var body: some View {
        GridShape(d: d)
            .stroke(style: StrokeStyle(lineWidth: max(1.5, 1.9 * size / 24), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The left of the closed Dynamic Island: the timer's mark in orange, or the pause mark.
struct FocusSmallMark: View {
    let state: FocusGlance

    var body: some View {
        if state.isPaused {
            FocusMarkView(d: FocusMark.pause, size: 16)
                .foregroundStyle(Color.white.opacity(0.7))
        } else {
            AppMarkView(.timer, size: 17, lineWidth: 2.2)
                .foregroundStyle(PlanLook.plan)
        }
    }
}

/// The smallest form, when another app shares the Dynamic Island: a ring filling up to the
/// planned time, or the timer's mark when nothing was planned.
struct FocusMinimal: View {
    let state: FocusGlance

    var body: some View {
        if let end = state.plannedEnd, !state.isPaused {
            ProgressView(timerInterval: state.countsFrom...end, countsDown: false,
                         label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.circular)
                .tint(PlanLook.plan)
        } else {
            FocusSmallMark(state: state)
        }
    }
}
#endif
