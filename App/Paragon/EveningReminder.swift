import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The evening reminder (build 234): one notification a day, at a time he chooses in
/// **Settings › Evening reminder**, and pressing it opens **Close the day**.
///
/// **A plain local notification, repeating daily.** Nothing leaves the device and there is no
/// server: iOS and macOS keep the schedule themselves, so it fires whether or not PARAGON is
/// running. Turning it off removes it.
///
/// **Its own object, not part of `AppModel`,** because a press on the notification can start the
/// app from cold, and Apple asks for the notification delegate to be in place before launch has
/// finished — earlier than SwiftUI makes the model. `ReminderAppDelegate` sets it at launch, and
/// the press is kept as a **count** (`openRequests`) that `ContentView` reads when it is ready.
/// A count, never a latch: build 122's lesson, where a Bool only ever set to true fired once.
final class EveningReminder: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = EveningReminder()

    /// The keys Settings writes. One place, so Settings and the launch-time check agree.
    static let onKey = "eveningReminderOn"
    static let minutesKey = "eveningReminderMinutes"
    /// 21:00 unless he picks another time.
    static let defaultMinutes = 21 * 60

    private static let requestID = "paragon.closeTheDay"

    /// How many times a reminder has been pressed since launch.
    @Published private(set) var openRequests = 0
    /// How many of those have been answered. **Kept here, not in a view** (build 238): a view's
    /// `@State` starts again at 0 in every new window, so closing the Mac window and clicking the
    /// Dock icon replayed the last press and opened **Close the day** by itself.
    private var answered = 0

    /// True once for each press, whichever window asks first.
    ///
    /// **The count is handed in, never read from `openRequests`** (build 242). `$openRequests`
    /// sends the new value in `willSet`, while the stored property still holds the old one, so
    /// reading it here saw no new press — a reminder pressed while PARAGON was running opened
    /// nothing, and the next press opened the screen for the one before.
    func takeOpenRequest(upTo count: Int) -> Bool {
        guard answered < count else { return false }
        answered = count
        return true
    }
    /// Nil until asked. False when he has said no to notifications for PARAGON, which only
    /// **System Settings** (Mac) or **Settings** (iPhone) can change — so Settings says so.
    @Published private(set) var allowed: Bool?

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    /// Called once at launch.
    func start() {
        center.delegate = self
        refreshPermission()
        let defaults = UserDefaults.standard
        let minutes = defaults.object(forKey: Self.minutesKey) as? Int ?? Self.defaultMinutes
        // Re-plant what Settings says, so a reminder and the switch can never disagree after
        // an update or a restore. Asking for permission is left to the switch being turned on.
        if defaults.bool(forKey: Self.onKey) {
            plant(minutes: minutes)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        }
    }

    /// What the switch and the time picker call.
    func update(on: Bool, minutes: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        guard on else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.allowed = granted
                // The answer can arrive after the switch was turned off again, or after the time
                // was changed once more; plant only what Settings says now (build 238).
                let defaults = UserDefaults.standard
                guard granted, defaults.bool(forKey: Self.onKey) else { return }
                let now = defaults.object(forKey: Self.minutesKey) as? Int ?? minutes
                self.center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
                self.plant(minutes: now)
            }
        }
    }

    func refreshPermission() {
        center.getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                switch status {
                case .notDetermined: self.allowed = nil
                case .denied: self.allowed = false
                default: self.allowed = true
                }
            }
        }
    }

    private func plant(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Close the day"
        content.body = "What did you finish today, and what moves to tomorrow?"
        content.sound = .default
        var when = DateComponents()
        when.hour = minutes / 60
        when.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: Self.requestID, content: content, trigger: trigger))
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Shown even while PARAGON is open in front, or the reminder would vanish exactly when he
    /// is already in the app.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == Self.requestID {
            DispatchQueue.main.async { self.openRequests += 1 }
        }
        completionHandler()
    }
}

/// Only here so the reminder's delegate is set before launch finishes (see above).
#if os(iOS)
final class ReminderAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        EveningReminder.shared.start()
        return true
    }
}
#else
final class ReminderAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        EveningReminder.shared.start()
    }
}
#endif
