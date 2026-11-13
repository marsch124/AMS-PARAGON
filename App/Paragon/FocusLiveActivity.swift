import Foundation
import ParagonCore
#if os(iOS)
import ActivityKit

/// The focus timer on the Lock Screen and in the Dynamic Island (build 317).
///
/// **One rule: the Live Activity is made to match the app's timer, never the other way round.**
/// `sync` is called on every change to `AppModel.focus`, at launch, and when the stop question
/// opens or closes. It ends every activity that is not the session now running — one left
/// behind by a crash, by a stop while the phone was off, by another vault — and starts or
/// updates the one that is. So there is never an activity with no timer behind it, and never
/// two.
///
/// While the clock runs nothing is sent: the system counts the time itself from
/// `FocusGlance.countsFrom`. An update is sent only when the glance differs (pause, go on, stop).
@MainActor
enum FocusLiveActivity {
    /// Each sync waits for the one before it, so a pause and a go-on in quick succession
    /// arrive in order and never start two activities.
    private static var last: Task<Void, Never>?

    static func sync(_ session: FocusSession?, awaitingAnswer: Bool) {
        #if DEBUG
        // A test run never puts anything on the Lock Screen — unless it asks to, with
        // `-paragon-live-activity`, which is how the pictures of it are taken.
        if TestVault.isWanted, !ProcessInfo.processInfo.arguments.contains("-paragon-live-activity") { return }
        #endif
        let previous = last
        last = Task { @MainActor in
            await previous?.value
            await apply(session, awaitingAnswer: awaitingAnswer)
        }
    }

    private static func apply(_ session: FocusSession?, awaitingAnswer: Bool) async {
        var wanted: (attributes: FocusActivityAttributes, state: FocusGlance)?
        if let session, let started = session.startedAt {
            wanted = (FocusActivityAttributes(title: session.title, startedAt: started),
                      FocusGlance(session: session, at: Date(), awaitingAnswer: awaitingAnswer))
        }
        var kept: Activity<FocusActivityAttributes>?
        for activity in Activity<FocusActivityAttributes>.activities {
            let live = activity.activityState == .active || activity.activityState == .stale
            if let wanted, kept == nil, live,
               activity.attributes.title == wanted.attributes.title,
               activity.attributes.startedAt == wanted.attributes.startedAt {
                kept = activity
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        guard let wanted else { return }
        // No stale date: the clock is true for as long as the session is, and the app's own
        // twelve-hour rule (`FocusSession.forgottenAfter`) is asked when he stops it.
        let content = ActivityContent(state: wanted.state, staleDate: nil)
        if let kept {
            if kept.content.state != wanted.state { await kept.update(content) }
            return
        }
        // Switched off in the iPhone's Settings › PARAGON › Live Activities: the bar in the
        // app is still there, and nothing is asked.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Can only be started while PARAGON is in front. A clock is started there; if this is
        // a button's background launch and the activity is gone, the next time PARAGON comes
        // to the front starts it again (`ContentView` calls `syncFocusActivity` there).
        _ = try? Activity.request(attributes: wanted.attributes, content: content, pushType: nil)
    }
}
#endif

extension AppModel {
    /// Makes the Live Activity match the timer. Nothing on the Mac.
    func syncFocusActivity() {
        #if os(iOS)
        FocusLiveActivity.sync(focus, awaitingAnswer: focusQuestionPending)
        #endif
    }

    /// Hands the Live Activity's buttons to the real timer. Called once, when the model is made.
    func listenToFocusActivity() {
        #if os(iOS)
        FocusActivityBridge.handler = { [weak self] action in
            guard let self else { return }
            switch action {
            case .pause: self.pauseFocus()
            case .resume: self.resumeFocus()
            case .stop: self.stopFocus()
            }
            // The stop question opens a turn later, and Pause is refused while it is open:
            // say what is true now either way.
            self.afterUpdate { self.afterUpdate { self.syncFocusActivity() } }
        }
        #endif
    }
}
