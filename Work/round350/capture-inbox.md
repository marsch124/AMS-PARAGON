# Round 350, lane capture-inbox

Nothing was compiled or run (no Swift compiler here). Core tests: `CaptureLinesTests` (6 cases). Screen test: `testSelectingInboxLinesCountsThePickedOnes` (end of `ScreenTests`).

## Things the lead MUST do (not in my lane)

- **`project.yml` Info keys**: add `NSLocationWhenInUseUsageDescription` (text suggestion: "PARAGON looks up the place name once when you save a capture, if you switch that on in Settings. It keeps no track of where you go."). For the Mac the sandbox also needs the entitlement `com.apple.security.personal-information.location` in `App/Config/Paragon/Paragon-macOS.entitlements`, and `NSLocationUsageDescription` is the Mac's older name for the same words.
- **Mac dictation** needs `com.apple.security.device.audio-input` in `Paragon-macOS.entitlements` (the Mac file has no microphone entitlement today). `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` already exist in project.yml (iOS section lines 78-79; check that they are in the Mac's Info too: it is one `info:` block, so they should be).
- Camera key `NSCameraUsageDescription` already exists (scan a list).
- Merge note: I edited three shared files in single, additive places: `AppModel.swift` (one block `// Round 350 (capture-inbox)` of three @Published properties after `filingSearch`; one line in `handle(url:)`; two Inbox count lines now call `awaitingTasks()`), `Marks.swift` (two entries `mic`, `scan.list` after `photo`), `SettingsView.swift` (one line `CapturePlaceSection()`), `ParagonWidgets.swift` (an `if #available(iOS 18.0, *)` block at the end of the iPhone bundle body), `TaskParser.swift` / `MarkdownHighlight.swift` (the `snooze` field).

## Pick 26 Dictate into the capture field
- Built: a **Dictate** chip in the row under the field (phone and Mac, `addRow`). Press: PARAGON asks for speech and microphone permission once, then the spoken words appear in the field as they are said; the chip turns to **Stop** (Inbox colour, filled); press again to stop. Words already in the field stay, spoken words come after them. Apple `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`; a language that cannot run on the device is refused (nothing is sent to a server). Language from the same Settings › Voice choice (`voiceLanguage`, iOS only setting; Mac uses the Mac's language).
- Words on screen: "Dictate", "Stop"; problems (orange): "PARAGON may not turn speech into text. Turn it on in Settings, under PARAGON, Speech Recognition." / "PARAGON may not use the microphone. Turn it on in Settings, under PARAGON, Microphone." / "Speech to text is not available right now." / "This device cannot turn speech into text on the device in this language." / "The microphone could not be started."
- Identifiers: `capture.dictate`, `capture.dictate.problem`.
- Files: `App/Paragon/CaptureDictation.swift`, `App/Paragon/Views/CaptureExtras.swift` (`DictateChip`, `CaptureToolFace`), `QuickCaptureView.swift` (`addRow`, `savedCount`), mark `mic` in `CaptureMarks.swift` + `Marks.swift`.
- Dictation stops when Save is pressed (`stopWhen`) and when the screen goes.
- Not done: no screen test (needs permission dialogs). Uncertain: `AVAudioApplication.requestRecordPermission()` async on macOS 14; `AVAudioSession` is iOS only (guarded).

## Pick 27 Scan a paper list (iPhone/iPad)
- Built: **Scan a list** chip in the same row (drawn only when `VNDocumentCameraViewController.isSupported`, so not in the simulator and not on the Mac). VisionKit document camera, then Vision `VNRecognizeTextRequest` (accurate, language correction) on each page off the main thread. Then a sheet **Scanned list** with every line read, a small x to take away a wrong line, **Cancel** and **Add N tasks** (`Add 1 task` for one). Lines go through `CaptureLines.scanned` (Core, tested): bullets/boxes removed, lines under 2 characters or with no letter/number dropped. Each line is saved as its own capture with the same target / task-or-note choice and place name as a typed one.
- Words: "Scan a list", "Reading…", "Scanned list", "Each line becomes a task in the Inbox. Take away the ones that are wrong.", "No writing was found. Try again with more light, and the page flat.", "Add N tasks".
- Identifiers: `capture.scan`, `scan.lines`, `scan.remove`, `scan.add`, `scan.none` (+ `sheet.cancel`).
- Files: `CaptureExtras.swift`. Mark `scan.list`.
- Not done: no screen test (no camera on a runner). Uncertain: fullScreenCover then sheet on the same button (a 350 ms pause is built in); `VNRecognizeTextRequest.results` typed as `[Any]` to compile either way.

## Pick 28 Paste many lines as tasks
- Built: when one change to the capture field adds two lines or more (`CaptureLines.pastedMany`, Core, tested), a dialog asks **Make 5 tasks?** (or "notes" when A note is chosen) with **One task each** and **Keep as one**. One task each: every line (bullets, numbers, tick boxes removed by `CaptureLines.split`) is saved as its own capture, date words read per line; message "Saved 5 tasks". Keep as one: nothing changes (the lines are joined into one line when saved, as before).
- Identifiers: `capture.many.each`, `capture.many.one`.
- Files: `CaptureExtras.swift` (`ManyLinesDialog`), `QuickCaptureView.swift`.
- Uncertain: a vertical-axis `TextField` on the Mac: Return submits, so pasting is the way to get lines there. Typing a second line on the phone is NOT a paste (only one change of 2+ lines asks).

## Pick 29 Warn about the same line twice
- Built: under the field, a small note "Already in the Inbox" (tray mark, Inbox colour) while the typed words match an open Inbox line (capitals, accents, spaces ignored; date, priority, length marks left out via the task parser's own reading). Only for task captures into the Inbox. Save still works.
- Identifier: `capture.duplicate`. Files: `CaptureLines.swift` (`key`, `isInInbox`), `QuickCaptureView.swift` (`duplicateNote`).
- Known limit: date words in plain text ("tomorrow") are turned into the date mark before comparing, so "Call Anna tomorrow" matches "Call Anna >date" only when the dates are the same.

## Pick 30 Snooze an Inbox line
- Storage: `@snooze(YYYY-MM-DD)` on the task line, parsed like `@since`: `TaskItem.snooze` (last init parameter, default nil), written after `@deadline` and before `@done`, cleared on a repeat's next copy, dimmed in the editor, never in a reminder's title. An older build keeps the mark as plain words in the title.
- Rule (Core, tested): a line is snoozed while its day is after today; it comes back on the day itself. `Note.awaitingTasks(on:)` is the open tasks without snoozed ones. Used by: the Inbox list (`InboxItems.waiting`), the sidebar/tab count and Start screen (`AppModel.count(for: .inbox)`), the widget snapshot's inbox count, the Weekly review's inbox number (`Review.swift`).
- UI: line menu (right-click on the Mac, long press on the phone; also the Mac's File it button): **Snooze until…** > **Tomorrow**, **Next Monday**, **Pick a day…** (date window titled "Snooze until", button **Snooze**; a day that is not after today says "Pick a day after today."). Message: "Back in the Inbox on Monday 23 November.". The last row of the Inbox list: "N lines are snoozed" with **Bring back** (all at once). The empty Inbox says "N snoozed lines come back later."
- Identifiers: `inbox.snooze`, `inbox.snooze.tomorrow`, `inbox.snooze.monday`, `inbox.snooze.pick`, `inbox.snoozed`, `inbox.snoozed.bringBack`.
- Files: `TaskParser.swift`, `MarkdownHighlight.swift`, `CaptureLines.swift` (`InboxSnooze`), `App/Paragon/InboxRound350.swift` (`snooze`, `bringSnoozedBack`, `InboxSnoozeMenu`, `SnoozeSheetHost`), `InboxView.swift`.
- Not done / uncertain: the phone's File it quadrant has no Snooze button (long press has it). When EVERY line is snoozed the Inbox shows "Inbox zero" (with the sentence about snoozed lines) and no Bring back button. A snoozed line still shows in All actions / Calendar if it has a date. The counts update when the screen next redraws, not at midnight by themselves. No screen test (menus are not opened by any test).

## Pick 31 Pick several lines, file once
- Built: **Select** (right, above the list, only with two lines or more). While selecting: each line's round button picks it (the done circle is replaced by a pick circle: empty / ticked), the bar shows **Cancel**, "Pick lines" / "1 picked" / "N picked", **All** / **None**, and a full-colour **File N lines** menu ("File lines" with none): Recent places, then all projects and areas. Filing moves each line (each found again in the note as it is now), then ends select mode and says "Moved 3 lines to Health." or, on a failure, an alert "N of M lines were moved. The others stayed where they were; look at the Inbox and try again." Leaving the Inbox ends select mode. The tick is its own Button (builds 71-74).
- Identifiers: `inbox.select`, `inbox.select.cancel`, `inbox.select.count`, `inbox.select.all`, `inbox.select.file`, `inbox.pick.<line title>`, `inbox.select.recent.<place>`, `inbox.select.place.<place>`.
- Files: `InboxRound350.swift` (`InboxSelectBar`, `InboxPickButton`, `FilingPlacesMany`, `fileInboxLines`), `InboxView.swift` (bar above the list, row button), AppModel block (`inboxSelecting`, `inboxPickedIDs`).
- Screen test: `testSelectingInboxLinesCountsThePickedOnes` (Select, pick one, "1 picked", Cancel).
- Not done: the Search… page of build 332 is not offered for many lines; the places filed to are not added to "Recent" (the recent list's writer is private in AppModel).

## Pick 32 Remember where you captured it
- Built: Settings › **Place name** section: switch **Add the place name** (off by default; footer: "When this is on, a line saved from Quick capture ends with the place where you are, like “Buy milk — at Malmö”. PARAGON looks once, when you save, and keeps no track of where you go."). Turning it on asks for location permission once; if refused an orange line says "PARAGON may not use the location. Turn it on in Settings, under PARAGON, Location.". On Save (typed, pasted or scanned lines in Quick capture) the position is looked up once (at most 3.5 s), turned into a name by the geocoder (spot name, else town) and the line ends " — at <place>". No permission, no answer in time, or no name: saved exactly as typed. Save waits for it only when the switch is on.
- Identifiers: `settings.capturePlace`, `settings.capturePlace.refused`.
- Files: `App/Paragon/CapturePlace.swift`, `SettingsView.swift` (one line), `QuickCaptureView.swift` (`commit`), `CaptureLines.placed` (Core, tested).
- Not covered: the Inbox's own capture field, Siri, the share sheet and the widget do not add a place. Info.plist key and Mac entitlement: see the top. `CLGeocoder.reverseGeocodeLocation` async is deprecated in iOS 26 (warning only). On the Mac whenInUse does not exist, so `requestAlwaysAuthorization()` is used (`#if os(iOS)` split in `CapturePlace.swift`).

## Picks 21 and 33 Control Center / Lock Screen buttons (iOS 18+)
- Built: two controls, `CaptureControl` ("Capture") and `RecordThoughtControl` ("Record a Thought"), in the widget extension (`App/ParagonWidgets/ControlButtons.swift`), registered in the iPhone bundle body inside `if #available(iOS 18.0, *)`. Each runs a tiny intent that returns `OpenURLIntent` to `amspara://capture` or `amspara://record`. Icons: two SVG image sets (`ControlCapture`, `ControlRecord`, hand-drawn in the same 24-grid line) in the widget's asset catalogue, template rendering.
- The app: `AppModel.handleCaptureControlLink` (in `InboxRound350.swift`), called by the first line of `handle(url:)`. `amspara://capture` with no words opens Quick capture (the New screen with Capture chosen on the phone, as the round +; the Quick capture sheet on the Mac). `amspara://record` calls `RecordThoughtIntent.pressed(into: .inbox)` (first press starts, a press when recording stops and files).
- **Apple's rule: opening PARAGON from a control needs the phone unlocked** (Face ID or the passcode is asked first). A button that must work from the locked phone cannot open an app; the Action Button's Record a Thought (build 348) is the one that records without opening PARAGON.
- Uncertain (cannot be checked here): (1) `if #available(iOS 18.0, *) { CaptureControl(); RecordThoughtControl() }` inside the `WidgetBundle` result builder (widgets/ControlWidget mixing; Apple's samples do this, but check `ParagonWidgets.swift` near the end). (2) `OpenURLIntent` as the `.result(opensIntent:)` of a control's intent. If either does not compile, the fallback is an `openAppWhenRun` intent in `App/Shared` that writes the route to the shared folder, and the app reading it when it comes to the front. (3) SVG image sets with `template-rendering-intent`.
- No screen test (a runner has no Control Center).

## Riskiest lines to look at first when CI compiles
- `App/ParagonWidgets/ParagonWidgets.swift` end of the iPhone bundle body (`if #available`).
- `App/ParagonWidgets/ControlButtons.swift` (`OpenURLIntent`, `OpensIntent`).
- `App/Paragon/CaptureDictation.swift` (`AVAudioApplication.requestRecordPermission()` on macOS, `recognitionTask` handler).
- `App/Paragon/CapturePlace.swift` (nonisolated delegate methods on a `@MainActor` class).
- `App/Paragon/Views/CaptureExtras.swift` (`Task.detached` with `VNImageRequestHandler`).
