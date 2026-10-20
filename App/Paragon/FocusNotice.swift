import Foundation
import UserNotifications
import ParagonCore

/// The one notice when the planned time is up (build 257), from the drawing he loved
/// (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX): *"When the 45 minutes are up you get one
/// quiet notice. The clock keeps running if the app is closed."*
///
/// **The same system as the evening reminder** (build 234): a local notification the phone or
/// the Mac keeps itself, so it comes on time whether or not PARAGON is running.
/// `EveningReminder` is the delegate for both, which is what lets this one show while PARAGON is
/// in front; pressing it only brings PARAGON forward.
///
/// **Planted again on every change to the clock**, from the clock's own dates
/// (`FocusSession.secondsUntilPlanned`): a pause takes it away, **Go on** puts it back at the
/// moment the planned time will really be reached, and once that moment has passed nothing is
/// planted again. It comes once. When the clock stops, a notice still lying in Notification
/// Center is taken away too: it would be about a clock that no longer runs.
@MainActor
enum FocusNotice {
    static let requestID = "paragon.focus.timeUp"

    /// Counts the calls, so an answer from the system that arrives after a newer change (a
    /// pause pressed while the permission question was still open, say) plants nothing.
    private static var generation = 0

    /// Whether this launch has already said that notices are off. Once is information; on every
    /// start it would be nagging, and he may have turned them off on purpose.
    private static var toldNoticesAreOff = false

    /// `tell` is how a reason reaches the screen: when notices are off for PARAGON, nothing would
    /// come and nothing would say why (build 100's rule), so it says so once.
    static func plan(for session: FocusSession?, now: Date = Date(), tell: @escaping @MainActor (String) -> Void) {
        generation += 1
        let mine = generation
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        guard let session else {
            center.removeDeliveredNotifications(withIdentifiers: [requestID])
            return
        }
        guard let planned = session.plannedMinutes, let left = session.secondsUntilPlanned(at: now) else { return }
        let title = session.title
        let fireAt = now.addingTimeInterval(left)
        let ask = mayAsk
        center.getNotificationSettings { settings in
            let status = settings.authorizationStatus
            let silent = settings.alertSetting == .disabled || settings.alertStyle == UNAlertStyle.none
            Task { @MainActor in
                if status == .denied || (status != .notDetermined && silent) {
                    tellOnce(tell)
                }
                switch status {
                case .notDetermined:
                    guard ask else { return }
                    // Asked here, the first time a clock with a planned time starts: the moment
                    // the question makes sense. The answer is shared with the evening reminder.
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        Task { @MainActor in
                            EveningReminder.shared.refreshPermission()
                            if granted { add(title: title, planned: planned, at: fireAt, generation: mine) }
                        }
                    }
                case .denied:
                    return
                default:
                    add(title: title, planned: planned, at: fireAt, generation: mine)
                }
            }
        }
    }

    private static func add(title: String, planned: Int, at fireAt: Date, generation mine: Int) {
        // A later change to the clock has planted (or removed) its own notice since.
        guard mine == generation else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "The time you planned, \(TaskTime.label(planned)), is up. The clock keeps running until you press Stop."
        content.sound = .default
        // Worked out again here: the permission question may have taken a while to answer.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireAt.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
    }

    private static func tellOnce(_ tell: @MainActor (String) -> Void) {
        guard !toldNoticesAreOff else { return }
        toldNoticesAreOff = true
        #if os(macOS)
        let place = "System Settings \u{203A} Notifications \u{203A} PARAGON"
        #else
        let place = "the iPhone\u{2019}s Settings \u{203A} Notifications \u{203A} PARAGON"
        #endif
        tell("No notice will come when the planned time is up: notifications for PARAGON are off. Turn them on in \(place).")
    }

    /// The screen tests run with nobody to answer a permission question, and on the phone the
    /// question covers the screen (build 190: a test may not fail for its own reasons).
    private static var mayAsk: Bool {
        #if DEBUG
        return !TestVault.isWanted
        #else
        return true
        #endif
    }
}
