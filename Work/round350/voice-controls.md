# Round 350, lane voice-controls (picks 6, 7, 10, 11, 12, 24, 25)

Nothing was compiled or run (no Swift compiler here). All rules are in Core and covered by one
test file, `Core/Tests/ParagonCoreTests/VoiceControlsTests.swift` (3 tests).

## 6 Pause on the Lock Screen
- Buttons on the Live Activity (banner and expanded Dynamic Island): **Pause** / **Go on**
  (`VoicePauseButton`, `PauseVoiceIntent`). Heading becomes "Paused · Inbox" (or "Paused · Today's note"),
  the dot is pale (not red), the clock stops and shows the length so far.
- `VoiceRecorder.pause()` = `engine.pause()` (speech session stays open), `resume()` = `engine.start()`;
  paused seconds are added to `pausedTotal`, the saved length excludes them. `ContentState` got
  `paused`, `pausedSeconds`, `marks`; the running clock counts from `startedAt + pausedSeconds`.
- If the microphone will not start again: stays paused, card says "Could not go on. Press Stop to keep what you said."
- Bridge: `VoiceActivityBridge.pause` / `.mark`, set in `ReminderAppDelegate` (EveningReminder.swift).
- Note: the 30-minute limit counts wall time, pauses included.

## 7 Mark an important moment
- Button **Mark** (words only, `VoiceMarkButton`, `MarkVoiceIntent`). Lock Screen line gets "N marked" (joined with "N tasks heard" by " · ").
- Rule in Core: `VoiceMarks` (sentence ranges, `markedSentences`, `marked`). A mark stores the length of the cleaned
  transcript at that moment (`VoiceThought.marks`); the sentence holding the last of those characters is wrapped in
  `**…**` in **Full text** and listed under a new `## Marked` part (after Full text on purpose, so `enriched`'s
  "tasks above Full text" insert keeps working).
- Offsets are in characters of `VoiceThought.clean(transcript)`; if lane voice-words changes `clean`, the marks follow it.

## 10 Check before filing
- Settings › Voice › **Check before filing** (`settings.voiceCheckFirst`), ON by default; footer text explains it.
- Design chosen (simplest safe): the thought is filed AT ONCE as before, nothing can be lost. The card
  (`AppSheet.voiceCheck`, `VoiceCheckView`) opens when PARAGON is in front (after a stop while in front, or the next
  time it becomes active; via `openWhenFree`, so it waits for another sheet). It edits the filed thought.
- Card: "Check the thought"; line "Recorded 0:42 · saved to the Inbox" (or "today’s note"); title field
  (`voice.check.title`); summary; "Tasks" with one switch per task (`voice.check.task.<task>`, off = take it out of the
  Inbox/daily note and the note's Tasks part) and the hint "Switch off a task you do not want. It is taken out of the Inbox.";
  **Throw it away** (`voice.check.throwAway`); **Cancel** (keeps as filed, counts as checked) and **Save**
  (`voice.check.save`; renames the note through `renameNote` so links follow). Empty: "Nothing is waiting to be checked."
- The list of filed thoughts is `VoiceHistoryStore` (UserDefaults `voiceFiledHistory`, newest 10, per device), Core type `VoiceFiled`.
- Wording note: the setting says "before filing" (his words) but the thought is already filed when the card shows.

## 11 Throw away the last thought
- Core `Vault.discardVoiceThought`: note to Deleted (restorable 30 days, not the Undo machinery), open tasks it filed
  and its `- [[Title]] — voice note, 0:42` line leave the Inbox/daily note; ticked/changed tasks stay and are counted.
  Message: "Thrown away. The note is in Deleted for 30 days." (+ " One task was already ticked off, so it stays.").
- Offered on the Voice notes page ("The last thought" row, button **Throw it away**, `voice.throwLast`, with a confirmation
  "Throw away this thought?" / **Throw away** `voice.throw.confirm` / Cancel) and in the check card (`voice.check.throwAway`).
  Only the newest recording of this device, while its note still exists.
- Not done: Reminders for thrown-away tasks go at the next sync (the 120 s grace of build 331), not at once (these Vault-level writes do not go through `rememberRemovedHere`).

## 12 Voice notes page
- New `SidebarSection.voiceNotes`, title "Voice notes", mark `voice` (new drawn microphone in Marks.swift, `Marks.voicePath`),
  tint InboxTint. In "Look back" on the Mac (after Recent) and in Browse › Plan on the phone (after Map). Core `SidebarGroups` row added
  (WindowColumnsTests count 19 → 20). Touched switches: AppModel (title, markName, all, notes(in:), count), PhoneRootView (band text, isSearchable,
  groups), ContentView (middle column, empty detail, tint).
- `VoiceNotesView`: notes tagged `voice` newest first (`VoiceNoteList`, sorted by the note's "Voice note · date time · length" line),
  search field "Find a voice note", row = title, "2026-11-20 14:03 · 0:42", first ~110 letters of the summary (of what was said when there is no summary).
  Press opens the note (stays in the section). Per row **More** menu (`voice.more.<path>`) and context menu: **Read aloud**, **Write it up again** (iOS), **Throw it away** (newest only).
  Empty: "No voice notes yet" + "Record a thought with the Action Button or Siri. It lands here as a note, with a summary and its tasks."
  (`voice.empty`). "No voice note has these words." (`voice.none`). Identifiers: `voice.row.<path>`.
- Screen test `testTheVoiceNotesPageOpensAndSaysItIsEmpty` (test notes hold no voice note; rules covered in Core).

## 24 Write it up again
- `AppModel.writeVoiceNoteAgain(path:)` (iOS; iOS 26 inside): reads **Full text**, calls `VoiceRecorder.writeUp(_:locale:within:)` (the other lane's
  function, signature used as it is in HEAD), then Core `Vault.rewriteVoiceNote`: summary replaced, tasks the note's Tasks part
  does not list yet are added there and to the Inbox, nothing is taken out; the title is replaced through `renameNote`.
- Messages: "Writing it up again…", "Written up again. One new task is in the Inbox.", "Apple Intelligence took too long. Try again in a moment.",
  "Apple Intelligence is not available here, so nothing was changed.", "This note has no full text to write up.", "Writing it up again needs iOS 26 or newer."
- Not on the Mac (the recorder is iOS only); not in the note header, only in the voice page row menu.

## 25 Read the summary aloud
- Settings › Voice › **Read the summary aloud** (`settings.voiceReadAloud`), off by default. After filing, `AVSpeechSynthesizer` says
  "<title>. <summary> N tasks." in the recording's language (Core `VoiceNoteText.spoken`, words for en/de/sv). **Read aloud** on a row
  speaks the note (second press stops). Message if empty: "There is nothing to read aloud in this note yet."

## Files
Core: `Vault/VoiceControls.swift` (new), `Vault/VoiceThought.swift` (marks + Marked part), `Model/WindowColumns.swift`.
App: `VoiceControlsApp.swift`, `VoiceRecorderControls.swift`, `Views/VoiceViews.swift` (new); `VoiceRecorder.swift` (state, pause/resume/mark, one call `afterFiling`; write-up code untouched),
`Shared/VoiceActivityShared.swift`, `ParagonWidgets/VoiceLiveActivityWidget.swift`, `EveningReminder.swift`, `AppModel.swift`, `Views/{ContentView,PhoneRootView,SettingsView,Marks}.swift`.
Tests: `VoiceControlsTests.swift`, `WindowColumnsTests.swift`, `ScreenTests.swift`.

## Unsure / risky (cannot be compiled here)
- `VoiceRecorder.swift` `pause()`/`resume()`: `AVAudioEngine.pause()` then `start()` while the tap stays installed (documented to work); not tried on a device.
- `VoiceLiveActivityWidget.swift` `Text(timerInterval: startedAt.addingTimeInterval(pausedSeconds)...Date.distantFuture)`: the paused clock is a static text, running clock restarts that much later.
- `VoiceViews.swift`: `.menuStyle(.borderlessButton)` on a `Menu` inside a List row; a `Menu` and a Button side by side in one row.
- `VoiceControlsApp.swift` `writeUpAgain`: `@available(iOS 26.0, *)` private method called from `if #available` inside a Task.
- `VoiceControls.swift` (Core) is pure Swift; tests assume `inboxNote()` text keeps "## Notes" lines and that `allNotes()` returns Resources notes.
- The lock-screen card is now taller (two button rows); not seen.
- A thought filed while the vault is closed (outbox) has no history entry, so no card and no throw-away.
- Merge: lane voice-words also edits `VoiceThought.noteText` / `VoiceRecorder.swift`; my edits there are small (`marks`, the Full text/Marked lines, state properties, one `afterFiling` call).
