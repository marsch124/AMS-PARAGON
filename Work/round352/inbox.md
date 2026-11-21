# Round 352, lane inbox

Nothing was compiled or run (no Swift compiler here). Nothing was seen on a screen. No new screen
test: the new things sit behind a context menu, a popover from a task menu, a menu in the Inbox
quadrant, a Settings search that needs the network, or a state (every line snoozed) the test notes
do not have. Core tests were added (see each item).

Files touched: `Core/Sources/ParagonCore/Vault/PlaceChoices.swift` (new),
`Core/Sources/ParagonCore/Vault/CaptureLines.swift`, `App/Paragon/Views/PlaceAndPerson.swift`,
`App/Paragon/Views/SettingsView.swift` (two lines), `App/Paragon/Views/InboxView.swift`,
`App/Paragon/InboxRound350.swift`, `App/Paragon/AppModel.swift` (one `private` taken off),
`App/Paragon/CapturePlace.swift` (footer words), tests `PlaceChoicesTests.swift` (new),
`CaptureLinesTests.swift`, `LookRulesTests.swift`.

## Item 1: ready-made places in Remind me at a place

- **Built.** Core `PlaceChoices.swift`: `KnownPlace` (name, latitude, longitude, address; `spot`,
  `id`, `reminder(arriving:)`), `SavedPlace` (`.home` / `.work`, label "Home" / "Work",
  `defaultsKey` `reminderPlace.home` / `reminderPlace.work`, stored text `address|lat,lon`,
  `read(_:)`), `PlaceChoices.chips(home:work:used:limit:)` (Home, Work, then used places; a used
  place at the very spot of Home or Work is left out; at most 8) and `NoteIndex.usedPlaces(limit:)`
  (every `@place(…)` on a task, open or done, once each: most used first, then A to Z; the
  spelling first met is kept; one place = name in any capitals/accents + position to 5 decimals).
  Tests `PlaceChoicesTests` (3).
- **The window "Remind me at a place"** (`PlaceSearchView`): above the search field a small grey
  line **Your places** and a row of chips (`PickChip`, wrapping), identifier
  `place.chip.<name>`. Pressing a chip chooses it exactly like a search answer (the chip lights
  up, **Save** is enabled). The chips are worked out once when the window opens. Nothing is
  drawn when there is no Home, no Work and no used place.
- **Settings › Home and Work** (new section, right after **Place name**), both platforms: two
  rows **Home** and **Work**, each with the saved address under it or "Not set", a button
  **Set…** / **Change…** (`settings.place.home`, `settings.place.work`), and **Remove** when set
  (`settings.place.home.remove`, …); the address line is `settings.place.home.now`. Footer: "Set
  them once. Then Remind me at a place… offers Home and Work without a search. Kept on this
  device only." **Set…** opens a window "Set Home" / "Set Work": **Cancel**, a field "Search an
  address or a place", **Search**, the answers (press one to keep it), and "Press the right answer
  to keep it as Home." Same messages as the place search ("No place found. Try other words." /
  "PARAGON could not search for places now. Check the connection and try again."). Identifiers
  `savedPlace.cancel`, `.field`, `.search`, `.message`, `.result.<name>`.
- Stored per device in `UserDefaults` (the choice in the brief: simplest). The chip is called **Home** /
  **Work**, so the task line reads `@place(Home|…)` and the row says "Arriving at Home". The
  address shown in Settings is the answer's name and address, without saying the name twice.
- No contacts are used.
- **Uncertain.** `.sheet(item:onDismiss:)` on a `Section` inside the Settings `Form` (should be
  fine; if CI dislikes it, move it onto the row's `HStack`). The window's size on the Mac
  (`minWidth 300, idealWidth 380, minHeight 280`) was not seen. The search uses `MKLocalSearch`
  exactly as round 350's window does, so the round 350 doubt about the Mac sandbox and network
  is the same here.

**For HowItWorks.md (the part about Remind me at a place / Reminders sync):** "Above the search
field, **Your places** shows places you can press at once: **Home** and **Work** if you have set
them, then the places you already used on tasks, the most used first. Press one and then
**Save**. Set Home and Work once in Settings, under **Home and Work**: press **Set…**, search the
address, and press the right answer. They are kept on this device only."

## Item 3: Snooze in the iPhone's File it menu

- **Built.** In `InboxQuadrant`, when **File it** files directly (the phone), the menu now ends
  with a line and **Snooze until…** (Tomorrow, Next Monday, Pick a day…). It is the very
  `InboxSnoozeMenu` the line's long press uses, so the words, identifiers (`inbox.snooze`,
  `inbox.snooze.tomorrow`, `.monday`, `.pick`) and the day window are the same. With no project
  or area yet the menu says "No project or area yet" and still offers Snooze. No fifth button.
  The Mac's File it menu already had Snooze (it shows the whole line menu); unchanged.
- **Uncertain.** **Pick a day…** sets `model.snoozeAsking`; the day window is hosted on the
  Inbox's capture bar (`SnoozeSheetHost`), which the phone's Inbox has, so it should open as it
  does from the long press. Not seen.

**For HowItWorks.md (The Inbox, Snooze):** "On the iPhone, **File it** under a picked line also
has **Snooze until…** at the end of its list."

## Item 4: when every line is snoozed

- **Built.** The Inbox with no open line and no captured note, but with snoozed lines, no longer
  says "Inbox zero". It shows the tray mark, the title **All lines are snoozed**, one sentence and
  a full-colour **Bring back** button (`inbox.snoozed.bringBack`, the same action as the row at
  the foot of the list: every snooze is taken off). The sentence: "1 line comes back on Monday
  23 November." or "3 lines are snoozed. The first comes back on Monday 23 November." (with no
  readable day: "… They come back later."). "Inbox zero" stays for a truly empty Inbox.
- Core: `InboxSnooze.firstBack(_:on:)`, `InboxSnooze.allSnoozedText(count:firstBack:calendar:)`,
  and `dayWords` (now shared with `message(until:)`, same format "EEEE d MMMM"). Test
  `CaptureLinesTests.testTheInboxSaysWhenSnoozedLinesComeBack`.
- The empty page's sentence is passed as `hint` (an `EmptyStateView` shows `message` only for a
  warning page). The snoozed part of `inboxZeroMessage` is now never reached; left in place.
- **Uncertain.** The day words follow the device's language (as the existing snooze message).

**For HowItWorks.md (The Inbox, Snooze):** "When every line in the Inbox is snoozed, the Inbox
says **All lines are snoozed** and when the first one comes back. **Bring back** puts them all
back at once."

## Item 7: filing several lines at once

- **Built.** `fileInboxLines` (`InboxRound350.swift`) no longer reads the whole notes folder
  after every line. It keeps the two notes each move wrote (`vault.move` returns the source and
  the target with their new dates) and finds the next line in that newest copy. The per-line
  reload was there for exactly this (the next move needs fresh notes, or `Vault.save` would see
  the file as changed on disk), so it is replaced, not just removed. Only after a line that went
  wrong (an error, or a line left in the Inbox) is everything read again, so the next line starts
  from what is on disk. One reload (animated, `Motion.settle`, like `moveTask`) at the end when
  any line moved, and the place is remembered once in **Recent** (`rememberFiledPlace`, now
  internal in `AppModel.swift`).
- **Uncertain.** That nothing between two moves needed the reloaded model: the loop only reads
  `note(at:)` (now behind the local copies), and the selection and messages are set after the
  loop. Not run.

**For HowItWorks.md (The Inbox, Select):** "Filing several lines with **File N lines** now also
puts the place on top of **Recent**, as filing one line does."

## Item 8: the Inbox's own field adds the place name

- **Built.** The Inbox's own capture field (`InboxTriageView.capture()`) takes the same look-up
  as Quick capture when Settings › Place name › **Add the place name** is on:
  `CapturePlace.shared.name()` then `CaptureLines.placed(line, at:)`. The field is emptied at once,
  before the look-up, so the next line can be typed. With the switch off nothing changes. The
  Settings footer now says "a line saved from Quick capture or from the Inbox’s own field ends
  with the place…".
- **Where the tail goes.** The line is first given its date mark (`PlainDateChip.line`), then
  " — at Malmö" is added at the end, the same order as Quick capture. `addTask` then runs
  `TaskParser.normalized`, which lifts `>date`, `!`, `~time` and the other markers out of the
  title and writes them after it, so the file reads `Buy milk — at Malmö >2026-11-22`: the place
  stays in the title. `#tags` stay in the title as always, so a line with a tag reads
  `Buy milk #shop — at Malmö`.
- **Risk.** A place name that itself looks like a marker (starts with `>`, `!`, `#`, `@`) would be
  read as one; place names from the geocoder are towns and spots, so this is unlikely. While the
  look-up runs (at most about 3.5 s) the line is not yet in the list; if the Inbox screen is left
  in that time the line is still added (the Task keeps the model).

**For HowItWorks.md (Quick capture, Place name):** "With **Add the place name** on, a line typed
into the Inbox's own field also ends with the place, like a line from Quick capture."

## Item 11: no dashed borders on the Inbox's four buttons

- **Built.** **Today**, **Tomorrow** and **Pick a date** in the Inbox quadrant draw a thin solid
  grey border when off (they were dashed); on is unchanged (tint fill, solid tint border).
  **File it** was already solid. The `dashed` parameter is gone from `face`.
- **Test.** `LookRulesTests.testTheTwoStateButtonIsNotDashed` now checks two places through one
  helper (`assertNotDashed`): `struct StateToggle` in Theme.swift as before, and
  `struct InboxQuadrant` in InboxView.swift, each up to the next top-level `struct`. It fails on
  `dash:` there. Other dashed shapes (the Icon… placeholder, the Map) are in other structs and
  files and are not read. The quadrant's doc comment sits above the struct, so its word "dashed"
  is not read either (and "dashed" does not contain "dash:" anyway).

**For HowItWorks.md / Look.md:** "In the Inbox's four buttons, the date the line has is filled in
the Inbox colour; the others have a thin grey line. Nothing is dashed."

## Merge notes

- `InboxView.swift`: three separate places (the empty-state branch + one property above `body`,
  `capture()`, and `InboxQuadrant`). `InboxRound350.swift`: only `fileInboxLines`.
  `AppModel.swift`: one line (`private func rememberFiledPlace` → `func`) plus its comment.
  `SettingsView.swift`: two lines after `CapturePlaceSection()`. `CaptureLines.swift`: inside
  `InboxSnooze` only. `CapturePlace.swift`: the footer sentence only.
