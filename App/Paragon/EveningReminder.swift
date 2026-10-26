import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The two daily reminders: the evening one (build 234), which opens **Close the day**, and the
/// morning one (build 267), which opens **Start the day**. Every value that differs between them
/// is here, so the system's list, Settings and the window that answers a press all read the same
/// ids, keys and words.
///
/// **The evening's ids and keys are exactly what build 234 wrote**, byte for byte. A reminder
/// already planted on his devices is found by its id: a new spelling could never remove it, and
/// it would come twice. The switch is read by its key: a new spelling would read as off.
///
/// **Every day, both of them** (his answer 2a, 21 October): one repeating calendar trigger each,
/// so there is no rule about days to decide and nothing for Core to test.
enum DayReminder: String, CaseIterable, Identifiable {
    case morning
    case evening

    var id: String { rawValue }

    /// The daily notification's id in the system's list.
    var requestID: String {
        switch self {
        case .morning: return "paragon.startTheDay"
        case .evening: return "paragon.closeTheDay"
        }
    }

    /// The one-off from **Send one in 10 seconds** (build 243). Its own id, so it can never
    /// replace or remove the daily one.
    var testID: String {
        switch self {
        case .morning: return "paragon.startTheDay.test"
        case .evening: return "paragon.closeTheDay.test"
        }
    }

    /// The keys Settings writes. One place, so Settings and the launch-time check agree.
    var onKey: String {
        switch self {
        case .morning: return "morningReminderOn"
        case .evening: return "eveningReminderOn"
        }
    }

    var minutesKey: String {
        switch self {
        case .morning: return "morningReminderMinutes"
        case .evening: return "eveningReminderMinutes"
        }
    }

    /// 07:30 and 21:00, unless he picks another time.
    var defaultMinutes: Int {
        switch self {
        case .morning: return 7 * 60 + 30
        case .evening: return 21 * 60
        }
    }

    /// The screen a press opens.
    var sheet: AppSheet {
        switch self {
        case .morning: return .startDay
        case .evening: return .closeDay
        }
    }

    /// The notification's own words.
    var notificationTitle: String {
        switch self {
        case .morning: return "Start the day"
        case .evening: return "Close the day"
        }
    }

    var notificationBody: String {
        switch self {
        case .morning: return "What matters most today? Pick it and put it in your plan."
        case .evening: return "What did you finish today, and what moves to tomorrow?"
        }
    }

    /// The words in Settings. The names of the screens are spelled as the app spells them.
    var sectionTitle: String {
        switch self {
        case .morning: return "Morning reminder"
        case .evening: return "Evening reminder"
        }
    }

    var switchTitle: String {
        switch self {
        case .morning: return "Remind me to start the day"
        case .evening: return "Remind me to close the day"
        }
    }

    var explanation: String {
        switch self {
        case .morning: return "One notification a day. Press it to open Start the day."
        case .evening: return "One notification a day. Press it to open Close the day."
        }
    }

    /// One name per control, never its words (build 191). The evening keeps the names it has
    /// had since build 234.
    var settingsIdentifier: String {
        switch self {
        case .morning: return "settings.morningReminder"
        case .evening: return "settings.eveningReminder"
        }
    }

    var testButtonIdentifier: String { settingsIdentifier + ".test" }

    /// The reminder a notification belongs to, its daily one or its test. Nil for any other
    /// notification, such as the focus timer's (build 257).
    static func owning(_ identifier: String) -> DayReminder? {
        allCases.first { $0.requestID == identifier || $0.testID == identifier }
    }

    /// The time Settings holds, or the default when he never chose one.
    func minutes(in defaults: UserDefaults) -> Int {
        defaults.object(forKey: minutesKey) as? Int ?? defaultMinutes
    }
}

/// The one notification delegate in PARAGON, and the owner of both daily reminders (`DayReminder`).
/// The name is build 234's, kept because he never reads it and the focus timer's notification
/// (`FocusNotice`) already depends on this being **the only** object that sets
/// `UNUserNotificationCenter.current().delegate`: a second one would silence that notification
/// and both reminders while PARAGON is in front.
///
/// **A plain local notification, repeating daily.** Nothing leaves the device and there is no
/// server: iOS and macOS keep the schedule themselves, so it fires whether or not PARAGON is
/// running. Turning it off removes it.
///
/// **Its own object, not part of `AppModel`,** because a press on the notification can start the
/// app from cold, and Apple asks for the notification delegate to be in place before launch has
/// finished — earlier than SwiftUI makes the model. `ReminderAppDelegate` sets it at launch, and
/// each press is kept as a **count** (`openRequests` for the evening, `morningRequests` for the
/// morning) that `ContentView` reads when it is ready. A count, never a latch: build 122's
/// lesson, where a Bool only ever set to true fired once.
final class EveningReminder: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = EveningReminder()

    /// How many times the evening reminder has been pressed since launch.
    @Published private(set) var openRequests = 0
    /// How many times the morning reminder has been pressed since launch (build 267). A count of
    /// its own, so each window can tell which screen a press asks for.
    @Published private(set) var morningRequests = 0
    /// How many presses of each have been answered. **Kept here, not in a view** (build 238): a
    /// view's `@State` starts again at 0 in every new window, so closing the Mac window and
    /// clicking the Dock icon replayed the last press and opened the screen by itself.
    private var answered: [DayReminder: Int] = [:]

    /// True once for each press, whichever window asks first.
    ///
    /// **The count is handed in, never read from the published property** (build 242).
    /// `$openRequests` sends the new value in `willSet`, while the stored property still holds
    /// the old one, so reading it here saw no new press — a reminder pressed while PARAGON was
    /// running opened nothing, and the next press opened the screen for the one before.
    func takeOpenRequest(_ kind: DayReminder, upTo count: Int) -> Bool {
        let done: Int = answered[kind] ?? 0
        guard done < count else { return false }
        answered[kind] = count
        return true
    }

    /// What the system says PARAGON may do (build 243). Before it, "never asked" and "allowed"
    /// both drew the ordinary grey line, so a switch that had planted nothing looked fine.
    /// One permission for both reminders and the focus timer's notification.
    enum Permission {
        /// The question has never been answered. Nothing is planted until it is.
        case notAsked
        /// He said no. Only **System Settings** (Mac) or **Settings** (iPhone) can change it.
        case refused
        /// Allowed, but the style is **None**, so nothing ever appears on screen.
        case silent
        case allowed
    }

    /// Nil until the system has answered.
    @Published private(set) var permission: Permission?

    /// What **Send one in 10 seconds** has done so far (build 244). Before it, the button gave
    /// no answer at all, so "nothing came" could not be told apart from "nothing was sent".
    enum TestState {
        case asking
        /// Handed to the system; it should appear at this time.
        case waiting(Date)
        /// The system says it delivered it at this time.
        case delivered(Date)
        /// Handed over, but the system never delivered it.
        case notDelivered
        case notAllowed
        case failed(String)
    }

    /// Each reminder's test, on its own: the two buttons are tried one at a time and each part
    /// of Settings says what its own button did.
    @Published private(set) var tests: [DayReminder: TestState] = [:]

    func isTesting(_ kind: DayReminder) -> Bool {
        switch tests[kind] {
        case .asking?, .waiting?: return true
        default: return false
        }
    }

    /// When each daily reminder will next come, read back from the system's own list. A kind is
    /// missing when nothing is planted for it — which is the thing Settings has to be able to say
    /// (build 243).
    @Published private(set) var nextReminders: [DayReminder: Date] = [:]

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    /// Called once at launch.
    func start() {
        center.delegate = self
        refreshPermission()
        let defaults = UserDefaults.standard
        // Re-plant what Settings says, so a reminder and its switch can never disagree after
        // an update or a restore. Asking for permission is left to a switch being turned on.
        for kind in DayReminder.allCases {
            if defaults.bool(forKey: kind.onKey) {
                plant(kind, minutes: kind.minutes(in: defaults))
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [kind.requestID])
            }
        }
        refreshSchedule()
    }

    /// What a switch and its time picker call. The time is read from Settings when the system
    /// answers, never handed in, so a time changed twice in a row plants the last one.
    func update(_ kind: DayReminder, on: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [kind.requestID])
        refreshSchedule()
        guard on else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.refreshPermission()
                guard granted else { return }
                self.plantWhatIsOn()
            }
        }
    }

    /// Plants every reminder whose switch is on, from what Settings holds **now** (build 238):
    /// the system's answer can arrive after a switch was turned off again, or after a time was
    /// changed once more. **Every one, not only the one just asked about** (build 267): the
    /// permission is shared, so a "yes" given for one switch, or for **Send one in 10 seconds**,
    /// is also the one the other switch, already on, was waiting for.
    private func plantWhatIsOn() {
        let defaults = UserDefaults.standard
        for one in DayReminder.allCases where defaults.bool(forKey: one.onKey) {
            center.removePendingNotificationRequests(withIdentifiers: [one.requestID])
            plant(one, minutes: one.minutes(in: defaults))
        }
    }

    func refreshPermission() {
        center.getNotificationSettings { settings in
            let answer: Permission
            switch settings.authorizationStatus {
            case .notDetermined: answer = .notAsked
            case .denied: answer = .refused
            default:
                answer = (settings.alertSetting == .disabled || settings.alertStyle == UNAlertStyle.none)
                    ? .silent : .allowed
            }
            DispatchQueue.main.async { self.permission = answer }
        }
        refreshSchedule()
    }

    /// Reads both planted reminders back from the system, so Settings says what is really there
    /// rather than what a switch hopes is there.
    func refreshSchedule() {
        center.getPendingNotificationRequests { requests in
            var next: [DayReminder: Date] = [:]
            for kind in DayReminder.allCases {
                let request = requests.first { $0.identifier == kind.requestID }
                let trigger = request?.trigger as? UNCalendarNotificationTrigger
                if let date = trigger?.nextTriggerDate() {
                    next[kind] = date
                }
            }
            let found = next
            DispatchQueue.main.async { self.nextReminders = found }
        }
    }

    /// **Send one in 10 seconds**: the same notification, once, so a reminder can be tried
    /// without waiting for the morning or the evening. Pressing it opens the same screen as the
    /// real one.
    ///
    /// Every step is reported in `tests`, and 15 seconds later the system's own list of delivered
    /// notifications is read, so Settings can say whether it came (build 244).
    func sendTest(_ kind: DayReminder) {
        tests[kind] = .asking
        center.removeDeliveredNotifications(withIdentifiers: [kind.testID])
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.refreshPermission()
                guard granted else {
                    self.tests[kind] = .notAllowed
                    return
                }
                // The first "yes" may come from this button: a switch already on gets its
                // reminder now, not at the next launch.
                self.plantWhatIsOn()
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                let request = UNNotificationRequest(identifier: kind.testID,
                                                    content: Self.content(for: kind), trigger: trigger)
                self.center.add(request) { error in
                    let message = error?.localizedDescription
                    DispatchQueue.main.async {
                        if let message {
                            self.tests[kind] = .failed(message)
                            return
                        }
                        let due = Date().addingTimeInterval(10)
                        self.tests[kind] = .waiting(due)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { self.checkTest(kind, due: due) }
                    }
                }
            }
        }
    }

    /// Asks the system whether the test was delivered.
    ///
    /// **A check only answers for its own send** (build 267): it acts only while the state is
    /// still the `.waiting` with this send's `due` time. Anything else is left alone. A test
    /// already pressed is `.delivered` (pressing a notification takes it out of the system's
    /// list, so a press within the 15 seconds used to read as "did not deliver it"), and a newer
    /// send has its own `.waiting` time and its own check, so this one must not mark the newer
    /// test as not delivered.
    private func checkTest(_ kind: DayReminder, due: Date) {
        let id = kind.testID
        center.getDeliveredNotifications { notes in
            let when = notes.first { $0.request.identifier == id }?.date
            DispatchQueue.main.async {
                guard case .waiting(let current)? = self.tests[kind], current == due else { return }
                if let when {
                    self.tests[kind] = .delivered(when)
                } else {
                    self.tests[kind] = .notDelivered
                }
            }
        }
    }

    private static func content(for kind: DayReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = kind.notificationTitle
        content.body = kind.notificationBody
        content.sound = .default
        return content
    }

    private func plant(_ kind: DayReminder, minutes: Int) {
        var when = DateComponents()
        when.hour = minutes / 60
        when.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: kind.requestID,
                                            content: Self.content(for: kind), trigger: trigger)
        center.add(request) { _ in
            DispatchQueue.main.async { self.refreshSchedule() }
        }
    }

    /// One more press of this reminder, for `ContentView` to answer.
    private func countPress(_ kind: DayReminder) {
        switch kind {
        case .morning: morningRequests += 1
        case .evening: openRequests += 1
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Shown even while PARAGON is open in front, or the reminder would vanish exactly when he
    /// is already in the app.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // `.list` as well (build 244): without it a notification shown while PARAGON is in front
        // is not kept in Notification Center, so the test could never find it delivered.
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        if let kind = DayReminder.owning(id) {
            let pressedTest = id == kind.testID
            let when = response.notification.date
            DispatchQueue.main.async {
                if pressedTest { self.tests[kind] = .delivered(when) }
                self.countPress(kind)
            }
        }
        completionHandler()
    }
}

/// Only here so the reminders' delegate is set before launch finishes (see above).
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
