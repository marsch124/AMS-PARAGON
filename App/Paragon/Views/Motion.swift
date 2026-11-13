import SwiftUI
import ParagonCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// **The app's one set of movements (build 318, premium review polish-23).** His pick was
/// "Quick and quiet": 0.2 s for folding; the ticked task fades and the list closes up.
///
/// **Movement explains, it never decorates.** A row that leaves shows where it went, a group
/// that folds shows what it took with it, a bar that fills shows how far. Nothing bounces,
/// glows or celebrates.
///
/// **Every view uses a name from here** — `withAnimation(Motion.fold)`,
/// `.animation(Motion.fill, value: …)` — and never a duration of its own, so the whole app
/// moves the same way. The seconds are in Core (`MotionTiming`), where `MotionRulesTests` holds
/// them between 0.15 and 0.35 s and fails any view that writes its own
/// `.animation(.easeInOut(duration: …` again.
///
/// **Reduce Motion is honoured here, once.** With it on, every name that moves something is
/// `nil` — SwiftUI then changes the screen at once, as it did before build 318 — and the two
/// that only fade (`toast`, `fade`) stay, with transitions that fade instead of slide.
///
/// **A movement never holds a change back.** The model writes first, at once; the movement only
/// draws what has already happened. So a tap never waits, and the file is never behind the screen.
enum Motion {
    /// True while **Reduce Motion** is on in the device's Accessibility settings.
    static var isReduced: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    private static func easeOut(_ seconds: Double) -> Animation? {
        isReduced ? nil : .easeOut(duration: seconds)
    }

    /// A task's circle filling when it is ticked, and the words going grey.
    static var tick: Animation? { easeOut(MotionTiming.tick) }
    /// A row leaving or arriving while the list closes up or makes room: a spring with no bounce.
    static var settle: Animation? { isReduced ? nil : .smooth(duration: MotionTiming.settle) }
    /// A group opening or closing under its heading.
    static var fold: Animation? { easeOut(MotionTiming.fold) }
    /// Something new coming onto the screen: the focus timer's bar, the confirmation in Quick capture.
    static var arrive: Animation? { easeOut(MotionTiming.arrive) }
    /// One page of a window giving way to the next.
    static var page: Animation? { easeOut(MotionTiming.page) }
    /// A progress bar or the sync ring filling to its new value.
    static var fill: Animation? { easeOut(MotionTiming.fill) }
    /// A small control answering a press.
    static var press: Animation? { isReduced ? nil : .snappy(duration: MotionTiming.press) }
    /// A list scrolling to a place for him (the Done squares, Settings' sync part).
    static var scroll: Animation? { easeOut(MotionTiming.arrive) }
    /// The sync ring turning while a sync runs: one turn a second, and still with Reduce Motion.
    static var spin: Animation? {
        isReduced ? nil : .linear(duration: MotionTiming.spin).repeatForever(autoreverses: false)
    }

    /// The message at the foot of the screen. Kept with Reduce Motion, where it only fades.
    static var toast: Animation { .easeOut(duration: MotionTiming.toast) }
    /// A plain cross-fade. Kept with Reduce Motion.
    static var fade: Animation { .easeOut(duration: MotionTiming.fade) }

    /// Coming up from the foot of the screen and going back down; a fade with Reduce Motion.
    static var rise: AnyTransition {
        isReduced ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
    /// A small mark growing into place; a fade with Reduce Motion.
    static var grow: AnyTransition {
        isReduced ? .opacity : .scale(scale: 0.6).combined(with: .opacity)
    }
}

/// **The circle in front of a task, and its filling when the task is ticked (build 318).**
///
/// Both drawings are always there, one over the other, and only their strength changes: the
/// open ring fades out while the filled circle fades in and grows the last bit into place
/// (`Motion.tick`, 0.2 s). Swapping one picture for the other, as before, cannot be followed
/// by the eye. A cancelled task keeps its crossed ring and does not move.
///
/// The size, the 22-point box that takes the press and the colour stay with the caller, so the
/// row is laid out exactly as before.
struct TickMark: View {
    let isDone: Bool
    var isCancelled = false
    var size: CGFloat = 15

    private var filled: Bool { isDone && !isCancelled }

    var body: some View {
        ZStack {
            MarkImage(isCancelled ? "xmark.circle" : "circle", size: size)
                .opacity(filled ? 0 : 1)
            MarkImage("checkmark.circle.fill", size: size)
                .opacity(filled ? 1 : 0)
                .scaleEffect(filled ? 1 : 0.6)
        }
        .animation(Motion.tick, value: filled)
    }
}
