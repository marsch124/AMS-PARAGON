import SwiftUI
import ParagonCore
#if os(iOS)
import UIKit
#endif

/// False where no `FocusBar` is drawn: the **Start the day** and **Close the day** sheets and the
/// Mac's separate **Plan the day** window. **Focus on this** is left out there, because a clock
/// started where its bar cannot be seen would run unseen (build 256's review). Read where the
/// rows are built and handed down, never inside a context menu.
private struct FocusBarShownKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var focusBarShown: Bool {
        get { self[FocusBarShownKey.self] }
        set { self[FocusBarShownKey.self] = newValue }
    }
}

/// The bar that shows while the focus timer runs (build 256): the task, the clock against the
/// time planned, **Pause** and **Stop**. Drawn from the page he loved
/// (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX): a dark rounded bar with an orange dot,
/// above the tabs on the phone and at the foot of the window on the Mac.
///
/// **The clock is worked out from dates every second**, never counted (`FocusSession`), so it is
/// right after the app was closed or the Mac slept. `TimelineView` redraws it; nothing in the
/// model ticks.
struct FocusBar: View {
    @EnvironmentObject private var model: AppModel
    /// On the phone the bar would ride up on top of the keyboard and take another 60 points
    /// from every screen with a text field, so it steps aside while the keyboard is up.
    @State private var keyboardUp = false

    var body: some View {
        VStack(spacing: 0) {
            if let session = model.focus, !keyboardUp {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    bar(session, now: context.date)
                }
            }
        }
        .modifier(KeyboardWatch(up: $keyboardUp))
    }

    private func bar(_ session: FocusSession, now: Date) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.isPaused ? Color.secondary : Theme.planBlockTint)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.subheadline)
                    .lineLimit(1)
                clockLine(session, now: now)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button {
                if session.isPaused { model.resumeFocus() } else { model.pauseFocus() }
            } label: {
                round(session.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.isPaused ? "Go on" : "Pause")
            .accessibilityIdentifier("focus.pause")
            .help(session.isPaused ? "Go on with the clock" : "Pause the clock")
            Button {
                model.stopFocus()
            } label: {
                round("stop.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop")
            .accessibilityIdentifier("focus.stop")
            .help("Stop, and write the time into today's note under Worked")
        }
        // The bar is the page's ink with the page's own colour on it, so it is dark in light
        // mode and light in dark mode, as the drawing has it.
        .foregroundStyle(.background)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        // One element holding the others, so the name lands on the bar and the two buttons
        // keep their own (build 191's shape for a row).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.bar")
    }

    @ViewBuilder
    private func clockLine(_ session: FocusSession, now: Date) -> some View {
        let clock = FocusSession.clock(session.workedSeconds(at: now))
        HStack(spacing: 4) {
            Text(clock)
                .font(.subheadline.weight(.bold).monospacedDigit())
            if let planned = session.plannedMinutes {
                Text("of " + TaskTime.label(planned))
                    .font(.caption)
            }
            if session.isPaused {
                Text("\u{00B7} paused")
                    .font(.caption)
            }
        }
        .accessibilityIdentifier("focus.clock")
    }

    private func round(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .frame(width: 28, height: 28)
            .background(.background.opacity(0.18), in: Circle())
            .contentShape(Circle())
    }
}

/// Whether the phone's keyboard is up. A `ViewModifier`, so no `#if` sits in the middle of a
/// modifier chain (build 148); the Mac has no keyboard to step aside for.
private struct KeyboardWatch: ViewModifier {
    @Binding var up: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                up = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                up = false
            }
        #else
        content
        #endif
    }
}

/// The one question after **Stop** (build 256): was the task done? The time goes under
/// `## Worked` either way; **Done, tick it off** also ticks the task in its note.
struct FocusStopView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let session = model.focus {
            content(session)
        } else {
            // The sheet can outlive the session for a moment as it closes.
            Color.clear.frame(width: 1, height: 1)
        }
    }

    private func content(_ session: FocusSession) -> some View {
        let spans = WorkLog.spans(from: session.runs, title: session.title)
        let minutes = spans.reduce(0) { $0 + $1.span.minutes }
        let range = Self.range(of: spans)
        // A `String` first: a ternary of two literals handed straight to `Text` leaves Swift
        // choosing between two initialisers, and there is no compiler here to settle it.
        let headline: String = minutes == 1 ? "You worked 1 minute" : "You worked \(minutes) minutes"
        let quietAnswer: String = session.notePath == nil ? "Save the time" : "Not done yet"
        let days = Set(spans.map(\.day)).count
        let whereTo: String = days > 1 ? "the daily notes of those \(days) days" : "today's note"
        let forgotten = session.workedSeconds(at: Date()) > FocusSession.forgottenAfter
        return VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.title3.weight(.bold))
            Text(Self.sentence(session))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let problem = model.focusProblem {
                // Why the last answer could not be written, here in the sheet rather than in an
                // alert behind it (builds 238, 246).
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if session.notePath != nil {
                Button {
                    model.finishFocus(done: true)
                } label: {
                    Text("Done, tick it off")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(ParaKind.project.tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("focus.done")
            }
            Button {
                model.finishFocus(done: false)
            } label: {
                Text(quietAnswer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("focus.notDone")
            Text("Either way, \(range) goes into \(whereTo) under Worked.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if forgotten {
                // A clock left running overnight would write whole days of 00:00–24:00 lines.
                Text("The clock ran for over 12 hours. If it was left running by mistake, choose Don\u{2019}t save the time.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The third answer (build 256's review): the time was not real, so nothing is
            // written. Quiet, below the two that write.
            Button {
                model.discardFocus()
            } label: {
                Text("Don\u{2019}t save the time")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("focus.discard")
        }
        .padding(20)
        .frame(minWidth: 300, idealWidth: 340)
        // Medium to start with, and pulled up to full height when the warning lines make it
        // taller than half a small iPhone.
        .presentationDetents([.medium, .large])
    }

    /// "on Write the offer for the shed. You planned 45 min."
    private static func sentence(_ session: FocusSession) -> String {
        let on = "on \(session.title)."
        guard let planned = session.plannedMinutes else { return on }
        return on + " You planned \(TaskTime.label(planned))."
    }

    /// "08:02–08:54": the first start to the last end.
    private static func range(of spans: [DatedSpan]) -> String {
        guard let first = spans.first?.span, let last = spans.last?.span else { return "the time" }
        let from = PlanBlock.clock(first.start)
        let to = PlanBlock.clock(last.end == 1440 ? 0 : last.end)
        return "\(from)\u{2013}\(to)"
    }
}
