# Round 352, lane "looks"

Worktree: /home/user/AMS-PARAGON/.claude/worktrees/agent-ae7b86afde06342c5. Nothing was compiled
and nothing was seen on a screen (no Swift compiler in the container). CI is the first check.

## 10. Warnings in the deeper orange

**Built.** `Color.orange` → `Theme.attention.ink` for words:
- `App/Paragon/Views/CaptureExtras.swift` ~62: the dictation problem line (`capture.dictate.problem`).
- `App/Paragon/CapturePlace.swift` ~115: "PARAGON may not use the location…" (`settings.capturePlace.refused`).
- `App/Paragon/Views/SyncReportView.swift` ~34: the heading **Changed in both places** in the sync report.
- `App/Paragon/Views/GoalsView.swift` ~1328: the heading **Goals with no aspiration** (a `SectionLabel`; its tint is the heading's word colour).

**Left alone, listed (not clear word-warnings):**
- `EmptyStateView(… tint: .orange …)` in `InboxView.swift` ~142, `WaitingForView.swift` ~225, `ContentView.swift` ~1128. There `.orange` is the tint of a big mark in a soft circle, and `EmptyStateView` (Theme.swift ~121/128) **compares** `tint == .orange` to decide whether to show its message or its hint. Changing the tint would change which sentence is shown. Worth a small change of its own: pass `warns: true` everywhere and drop the colour test.
- `SyncReportView.swift` ~81: the mark (not words) of the row **Tasks cancelled in notes**.
- Backgrounds at 12 to 18 % (`Color.orange.opacity(…)`): ReviewView ~965, NoteEditorView ~2463 (flag capsules), DoneView ~428 (dashed edge of a waiting day), Theme ~493, OwnFolderViews ~289 and ~542. Fills, not words.
- The widgets' `WidgetLook.attention = Color.orange` (see item 16; now unused).

**Uncertain.** Only "not seen".

**HowItWorks** (Exact details, if wanted): "Warnings written in words (the dictation problem, the location refused, **Changed in both places** in the sync report, **Goals with no aspiration**) are in the app's deeper orange, the same as every other warning."

## 12. The Add a task bar is placed again when the keyboard goes (iPhone)

**Built.** `App/Paragon/Views/NoteEditorView.swift`: the bottom inset of `phoneBody` (the bar with **Add a task…**) now carries `.modifier(ReseatsWhenKeyboardGoes())`. The new private `ReseatsWhenKeyboardGoes` (end of the file) listens to `UIResponder.keyboardDidHideNotification` and moves the bar's bottom padding by 0.5 pt and back on the next turn of the main queue. Two changes of size make SwiftUI measure the inset again. iOS only (`#if os(iOS)` inside the modifier's body, not in a chain).

I first used `.id(counter)` and changed it: a new identity would also reset the **ⓘ** syntax popover (`TaskSyntaxButton` keeps its own `@State`), and showing that popover can itself hide the keyboard, so it would close the moment it opened.

**Uncertain.** The fault was never reproduced, so it is not known whether this guard cures it. The 0.5 pt padding sits outside the bar's `.background(.bar)` for one frame. Not seen.

**HowItWorks.** Nothing to say; a guard he does not see.

## 13. Hints say what a control does

**Built.** No screen test and no Core test compares any of these strings (grep of `Tests/` and `Core/`). Old → new:

| File | Old | New |
|---|---|---|
| SettingsView ~104 | … Press Not today to hide it until tomorrow. | … Not today hides it until tomorrow. |
| CalendarView ~741 (week goal box, empty) | What is this week about? Press to write it. | What is this week about? Not written yet. |
| CalendarView ~795 (tooltip) | Press to change what the week is about | Changes what the week is about |
| CloseDayView ~188 | Press First on the left of what comes first. Start the day shows it at the top tomorrow morning. | First, on the left, marks what comes first. Tomorrow morning it is at the top of the picking list. |
| NoteEditorView ~1530 | … Press Set again to use your words. | … Set again puts your words in. |
| NoteEditorView ~1534 | … Press Clear again to take it away. | … Clear again takes it away. |
| NoteEditorView ~1536 | … Press Set again to use your words instead. | … Set again puts your words in instead. |
| NoteEditorView ~1568 (tooltip) | The day this project ended. Press to change it. | The day this project ended. A click changes it. |
| NoteEditorView ~1780 (tooltip) | Press to rename this note. The file is renamed too, and links to it follow. | Renames this note. The file is renamed too, and links to it follow. |
| AspirationReasonView ~283 | … Press Save again to use them. | … Save again puts them in. |
| AspirationReasonView ~285 | … Press Save again to use yours instead. | … Save again puts yours in instead. |
| AreaStandardView ~229 / ~232 | the same two as above | the same two as above |
| AppModel ~3592 | … Press Done again to use yours instead. | … Done again puts yours in instead. |
| AppModel ~5848 | Sync stopped: it would change N tasks. Press Sync now to look. | Sync stopped: it would change N tasks. Sync now shows them. |
| DoneView ~342 | … Press a day to go to it. | … A day's square takes you to that day in the list. |
| Theme ~1116 (StateToggle tooltip) | X is on. Press to turn it off. / X is off. Press to turn it on. | X is on. / X is off. |
| Theme ~1180 (FoldButton tooltip) | Press to close. / Press to open. | Closes this part. / Opens this part. |
| ProjectsView ~337 (group heading tooltip) | Press to close. / Press to open. | Closes this group. / Opens this group. |
| ProjectArea ~200, ~201 | … Press to choose another area, or none. | … This button chooses another area, or none. |
| ProjectArea ~204 | … Press to choose one. | … This button chooses one. |
| ContentView ~1550 (Done, empty third column) | Press a task on the left to open the note it came from. | A task on the left opens the note it came from. |
| ContentView ~1569 (Mac sync tip) | The sync with Apple Reminders. Press for Sync now and the other choices; … | The sync with Apple Reminders. A click opens Sync now and the other choices; … |
| WeekLookStep ~55 | Press a day's line to open that day's note. … | A day's line opens that day's note. … |
| WeekLookStep ~303 | Press to write a line about last week. | No line about last week yet. |
| WeekLookStep ~359 (tooltip) | Press to change the line about the week | Changes the line about the week |
| OwnFolder ~662 | … Press Open… there when iCloud has brought everything. | … Open… there switches to the new place when iCloud has brought everything. |
| OwnFolderViews ~192 | … Press Open… on each. | … Open… on each switches it to the new place. |
| StartDayView ~23 / ~25 | Press Pick on what matters today. / Press Pick on the two or three … | Pick marks what matters today. / Pick marks the two or three … |
| EveningReminder ~135 to 137 | One notification a day. Press it to open Today, ready for picking. (and the two others) | One notification a day. It opens Today, ready for picking. / … It opens Close the day. / One notification a week. It opens the Weekly review. |
| VoiceRecorder ~355 (Live Activity) | Could not go on. Press Stop to keep what you said. | Could not go on. Stop keeps what you said. |

**Kept on purpose:** SettingsView ~721/729 "Press the keys…" (the shortcut recorder, where he really presses keys); the Action Button intent descriptions in `RecordThoughtIntent.swift` ("Press once to start recording, press again to stop") and `ControlButtons.swift` ("Press again in PARAGON…"): a physical button is pressed.

**Uncertain.** "Set again" / "Save again" / "Done again" name the button and then a verb; worth one more read for plainness. The CloseDayView sentence now says "the picking list" (since build 335 there is no Start the day page).

**Docs to follow.** `Docs/HowItWorks.md` ~2360 quotes the old Mac sync tip ("Press for Sync now …"); update it to the new words. Grep the docs for any other quote of the old sentences.

## 16. Overdue is red in the widgets

**Built.** `App/ParagonWidgets/ParagonWidgets.swift`: new `WidgetLook.overdue = Color.red` (beside `attention`, which stays and is now unused). Used for: the "N over" count in the Today's actions header (~348), an overdue date on an action line (~422), the **overdue** count line (~457), and in `OneListWidget.swift` ~84 the **Overdue** list's tint. `WidgetLookTests` only reads `Color(lightHex:darkHex:) // XxxTint` lines, so a plain `Color.red` line is not compared and the test stays as it was.

**Uncertain.** Not seen in any widget.

**HowItWorks** (Widgets): "Overdue is red in the widgets too, as in the app's task rows."

## 17. iPhone sync button: a tap syncs, a long press is the menu

**Built.** `App/Paragon/Views/PhoneRootView.swift`, `PhoneSyncButton`: the `Menu` now has `primaryAction:` → `syncNow()` (nothing while a sync runs, else `Task { await model.syncNow() }`). A long press shows the same `SyncChoices` menu (**Sync now**, **Show me what would change…**, **Last sync report…**, **Sync settings…**). Identifier `sync.status` and the `.sensoryFeedback` are unchanged.

**History:** build 312 (review round 6) had on purpose made a tap open the menu. This undoes that, at his request now. The comments in the file say so.

**Uncertain.** Not seen. `Menu(content:label:primaryAction:)` is iOS 15+; the app targets 17.

**HowItWorks** (Reminders sync on the iPhone): "Tap the sync button at the top right to sync now. Press and hold it for the menu: **Sync now**, **Show me what would change…**, **Last sync report…**, **Sync settings…**." (Look.md ~288 already says "press syncs, press and hold has the menu".)

## 18. All recent notes on the iPhone's Browse

**Built.** `App/Paragon/Views/PhoneRootView.swift`, `PhoneBrowseView`: under the strip of five recent notes (only when there is a strip), a row **All recent notes** with the count at the right (`model.recentNotes.count`, up to 40), identifier `browse.recent.all`. It is a `NavigationLink(value: PhoneRoute.section(.recent))`, the route every Browse row uses, so it opens `PhoneSectionScreen(section: .recent)` → `NoteListView(fixed: .recent)`. That list already has **Clear** in its top bar (`NoteListView` toolbar, `shown == .recent`, not limited to the Mac) and the pull-down field "Search in Recent". No Core change (BrowseRule unchanged).

**Uncertain.** Not seen. The row sits in the first Section, which has zero row insets and a clear background; it has 10 pt side padding to line up with the search field. The List's own chevron sits at the row's right edge. Whether **Clear** really shows in the iPhone's top bar there was read from code, not seen.

**HowItWorks** (Browse on the iPhone): "Under the five notes you opened last, **All recent notes** opens the whole list (up to 40, newest first). **Clear** at the top right empties it."

## 19. A ring means only a task's state

**Built.**
- (a) `App/Paragon/Views/CalendarView.swift`, `MonthGridCell`: today is no longer ringed. The date is bold (as before) with a short line under it: a 12 × 2 pt capsule in `ParaKind.daily.tint` (the colour the ring had), at the foot of the 22 × 20 date frame (`.background(alignment: .bottom)`). The chosen day keeps its filled circle.
- (b) `App/Paragon/Views/OwnFolderViews.swift` ~360: a step not reached yet in the folder-copy steps is a short grey dash (9 × 2 pt capsule, `Theme.soft` at 50 %), not a ring.

Left alone as asked: the sync clock ring, the focus ring in the Dynamic Island, circled control marks.

**Uncertain.** Whether the underline is clear enough at a glance (not seen).

**HowItWorks** (Calendar): "In the month, today's date is bold with a short line under it. The day you chose has a filled circle."

## 20. A dot means only "which part" or "which calendar"

**Built.**
- (a) `App/Paragon/Views/SettingsView.swift` `safetyDot`: a 12 pt amber circle (`Theme.attention`) with a white "!" (`Txt.tiny.weight(.heavy)`) at the gear's top right; identifier `safety.dot` unchanged, accessibility label "Something needs a look". Used by the iPhone Browse gear and `ContentView` ~692 (no change needed there). I also changed `SafetyMark` (the amber dot in front of a Safety line and in the Mac's `SafetyNoticeBar`) to the same badge, so one sign has one meaning.
- (b) `App/Paragon/Views/TodayView.swift` `nowControl` (the Now line while the clock runs on that block) and `App/Paragon/Views/FocusViews.swift` (the focus bar): `MarkImage("timer", size: 13 / 14)` instead of the dot; orange running, grey paused (in the bar: the page colour at 55 %). `timer` has a drawing in Marks.swift. Mac menu bar (`App/Paragon/FocusMenuBar.swift`): the running image is the timer mark (`Marks.nsImage("timer", size: 13)`) painted in `PlanTint` (drawn, then `rect.fill(using: .sourceAtop)`), not a template; paused keeps the template pause mark.
- (c) `App/Paragon/Views/Theme.swift` `NowLine` and `App/ParagonWidgets/TodayPlanWidget.swift` `nowMarker`: the 7 pt dot is a 3 × 9 pt rounded upright notch, same colour; offsets adjusted so the line stays where it was.
- (d) `CalendarView.swift`: the month grid's three small dots (due, events, daily note) are 7 × 3 pt bars; the week grid's daily-note dot (~684) too. Colours unchanged except events (item 22).

**Not done.** The orange dot in the Focus Live Activity (`FocusLiveActivityWidget.swift` ~132 to 138) and the end point on a goal's chart (`GoalNumberViews.swift` ~136, a point on a line): not in the list. `DayScheduleView.swift` ~188 calendar-colour chips: left (calendar colour).

**Uncertain.** The "!" at 12 pt with 10 pt type may look small on the iPhone (Txt.tiny is caption2 there). The menu-bar `NSRect.fill(using:)` call is from AppKit's Swift overlay; believed right, not compiled. `SafetyMark`'s baseline guide is now `$0[.bottom] - 2`, a guess.

**Docs to follow.** HowItWorks ~121, ~2237, ~2247, ~3045 and Guide ~251 say "amber dot". Suggested text (Safety): "When Safety has something to look at, a small amber badge with **!** sits on the Settings gear (on the iPhone and the iPad), and in front of each line that needs a look." Exact details: "A 12-point amber badge with a white ! on the Settings gear …". Focus timer: "While the timer runs, the bar at the foot, the line that starts with **Now** on Today and the Mac's menu bar show the timer's mark: orange while it runs, grey while it is paused." Now line (Words ~96 is fine): "The now line starts with a short upright notch."

## 22. The Mac's accent colour is no longer a sign

**Built.**
- `MapView.swift` ~514: the area you sweep while arranging is the Map's own gold (`SidebarSection.map.tint`), fill 12 % and a 1 pt edge.
- `MapView.swift` ~668: the outline of a box a drag is over is the box's own colour (`node.tint`). (A *selected* box already used its part's colour.)
- `CalendarView.swift` month grid: the events bar is `SidebarSection.calendar.tint` (CalendarTint).

**Uncertain, please look.** In the month grid, a day's "has tasks due" bar (not overdue) is `ParaKind.daily.tint`, which is **also CalendarTint**. So the due bar and the events bar are now the same purple, side by side, and differ only by order (due first, events second, the grey note bar third). Before, events were his orange accent. A fix needs a decision, for example the due bar in the project green.

**Other `accentColor` uses, listed, not changed:**
- `MapView.swift` ~189: the background of the bar shown while arranging the Map (a mode bar, not a mark).
- `InboxView.swift` ~910: hover background of a File it place while a line is picked (drop target).
- `TaskActions.swift` ~48: `TaskDropModifier` background while a task is dragged over (drop target).
- `UndoOffer.swift` ~163: the **Undo** button's words (a button colour).
- `EventKitCalendarStore.swift` ~108/152/171: fallback when a calendar has no colour.
- Default parameter values `tint: .accentColor` (NoteEditorView ~3011, SearchView ~475, Theme ~1098, MarkdownSyntaxEditor ~21/41, Motion ~112) and the `shown?.tint ?? Color.accentColor` fallback (ContentView ~1054).

**HowItWorks** (Map / Calendar): "In the Map, the box you drag over and the area you sweep while arranging are drawn in the box's and the Map's own colours. In the month, the bar for events is the Calendar's purple."

## Possible overlaps with other lanes
- `NoteEditorView.swift`, `SettingsView.swift`, `AppModel.swift`, `Theme.swift`, `PhoneRootView.swift`, `CalendarView.swift` all got small, local edits (single strings or one block). AppModel: only two message strings (~3592, ~5848).
