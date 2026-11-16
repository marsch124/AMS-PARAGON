# iOS 27 launch freeze (checked 16 Nov 2026, HEAD 3171687, build 321)

Result: STILL HANGS on a fresh iOS 27.0 simulator (iPhone 18 Pro, new device). White screen. First launch and second launch: same.
CPU 0%, so it is a block, not a busy loop (the TimelineView/repeatForever idea is ruled out).

## Cause
Main thread is stuck inside AppDelegate launch, waiting for a synchronous reply from the notification service:

ReminderAppDelegate.application(_:didFinishLaunchingWithOptions:)  EveningReminder.swift:461
 -> EveningReminder.start()  EveningReminder.swift:267   (center.removePendingNotificationRequests(withIdentifiers:), the "switch is off" branch, so it runs on every fresh install)
 -> -[UNUserNotificationCenter removePendingNotificationRequestsWithIdentifiers:]
 -> dispatch_sync -> NSXPCConnection synchronous send (xpc_connection_send_message_with_reply_sync) -> mach_msg, never returns.

On iOS 27 this "remove" call waits for usernotificationsd. In the log usernotificationsd opens the connection but never answers. Samples taken 24 s and 40 s after launch: same stack. SwiftUI never gets to build a window, so the screen is white.
Evidence: /private/tmp/claude-501/ios27/sample.txt (sample of the first launch), log lines "Removing 1 pending notification requests".

Same synchronous call elsewhere (same risk): EveningReminder.swift:276, 296; FocusNotice.swift:42.

## Not verified
I did not edit code, so the fix is not tested. I do not know if a real iPhone on iOS 27 behaves like the simulator (usernotificationsd in the simulator may be the broken part), but the block on the main thread at launch is a bug either way.

## Proposed fix
1. Do not touch UNUserNotificationCenter in didFinishLaunching. In EveningReminder.start(): keep only `center.delegate = self` (needed before launch ends); move the for-loop and refreshPermission()/refreshSchedule() into `Task.detached` / `DispatchQueue.global().async`, or start them from the first scene .task / scenePhase == .active.
2. Same for the 3 other remove/add calls: never on the main thread at launch.
3. Test: fresh iOS 27 simulator, launch, app must show the vault screen in under 5 s.
