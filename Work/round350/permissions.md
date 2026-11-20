# Round 350, lane "permissions" (picks 42, 47, 49)

Nothing here was compiled (no Swift compiler in the container). Every permission is asked only when its feature is first used: Health when the switch is turned on, Contacts when **Search Contacts** is pressed on the Mac (the iPhone/iPad picker needs none), places need none. Nothing at launch, nothing in screen tests.

## project.yml / config (only this lane)
- Info keys (project.yml AND the committed `App/Config/Paragon/Info.plist`, same words):
  - `NSLocationWhenInUseUsageDescription`: "PARAGON uses your location only to find places for reminders and, if you switch it on, to add the place name to things you capture." Reminders watches the geofence itself, so pick 42 does NOT need this key; it is there because the capture lane needs it.
  - `NSHealthShareUsageDescription`: "PARAGON reads your steps and workouts to write one line in your daily note. It never writes to Health."
  - `NSContactsUsageDescription`: "PARAGON lets you choose a person from Contacts to link tasks and notes to them."
- Mac entitlement `com.apple.security.personal-information.addressbook` added to `Paragon-macOS.entitlements` and `Paragon-macOS-Debug.entitlements` (CNContactStore in the sandbox). Not on iOS.
- HealthKit entitlement `com.apple.developer.healthkit: true` (project.yml iOS properties + `App/Config/Paragon/Paragon.entitlements`) is its OWN commit "Round 350 permissions: HealthKit entitlement (drop this commit if signing fails)". The Mac uses its own entitlements file, so the Mac is unaffected. If Apple refuses signing (App ID needs HealthKit enabled in the developer portal), drop that commit: the code still compiles, but the Health switch will not get data.

## Pick 42: Remind me at a place
- Task menu: **Remind me at a place…** (id `task.menu.place`) opens a popover/sheet "Remind me at a place": segmented Arriving / Leaving (`place.arriving`, `place.leaving`), field "Search a place" (`place.field`), **Search** (`place.search`), results (`place.result.<name>`), **Cancel** (`place.cancel`), **Save** (`place.save`), when one is set "Now: Arriving at Home" (`place.current`) and **Take place off** (`place.remove`). Footer: "Apple Reminders watches the place and rings when you arrive/leave. The task needs to be in a note that syncs with Reminders." Messages: "No place found. Try other words." / "PARAGON could not search for places now. Check the connection and try again."
- Flash after Save: "Arriving at Home. It rings once the task has synced with Reminders." / "Leaving X. ..." / "Place taken off."
- Task line marker: `@place(Home|59.32940,18.06860|arrive)` (or `|leave`), after `@deadline`, before `@person` and `@done`. Parsed in `TaskParser` like `@since`; `TaskItem.place` and `TaskItem.person` are the LAST init parameters (defaults nil). A `@place(...)` that cannot be read is kept as written (`unreadPlace`, like unread repeats). Name cleaned of `( ) | ` and line breaks. Dimmed in the editor like a date. Never in a reminder's title.
- Core: `Markdown/TaskMarkers.swift` (`ReminderPlace`, `PersonName`); `ReminderRecord.place` (last init param).
- Sync: `SyncEngine.apply(task:to:)` sets `reminder.place = task.place` (note is the truth); `apply(reminder:to:)` adopts a place set in Apple Reminders (never clears the note's); fingerprint appends `|@<place>` ONLY when a place exists, so every existing link keeps its stored fingerprint. `EventKitRemindersStore`: new `applyPlace` writes an `EKAlarm` with `EKStructuredLocation` (title, `CLLocation`, radius 150 m) and `proximity` .enter / .leave; time-alarm code now ignores location alarms (before it removed ALL alarms when a task had no date); `record(from:)` reads a place back. Apple Reminders does the geofence, so no CoreLocation permission is used.
- Row: small fact with the pin mark and the place name (`RowFact(place.name, "mappin")`).
- New marks (Marks.swift, `.drawn` paths): `mappin`, `person.linked`. Merge note: they sit right after the `"one.thing"` entry and before `deadlinePath`.
- NOT done: "Home" / "Work" from the user's contacts card (needs geocoding; not simple). Search is MKLocalSearch only.
- Uncertain to compile / behave: `EKAlarm.proximity` / `.enter` / `.leave` and `EKStructuredLocation.geoLocation` in `EventKitRemindersStore.swift` (applyPlace, place(from:)); `item.placemark` in `PlaceAndPerson.swift` (PlaceHit.init; deprecated on iOS 26 but valid on 17); whether MKLocalSearch works in the sandboxed Mac app without `com.apple.security.network.client` (not added; it is not in the Mac entitlements today).
- Tests: Core `PlacePeopleTests` (round trip, unreadable kept, name cleaning, fingerprint only when a place exists).

## Pick 47: Health line in the daily note
- Settings (iPhone/iPad only, after Voice): section "Health", switch **Health line in the daily note** (`settings.healthLine`), off by default. Footer: "Writes one line under Health in today's daily note, for example Steps 8,412 · Walk 35 min. PARAGON only reads your steps and workouts. It never writes to Health." Turning it on asks Health (read steps + workouts), then writes at once. Refused: "Health did not allow it. You can change this in Settings > Health > Data Access."
- Written under `## Health` as one line, e.g. `Steps 8,412 · Walk 35 min · Strength 40 min`; same kind of workouts add up; under a minute counts as 1 min; nothing is written when there are no steps and no workout (and an earlier line is never removed). Updated when the app comes to the front (ContentView scenePhase `.active` → `model.updateHealthLine()`), at most once per 30 minutes. Never written while notes are coming from iCloud.
- Core: `Vault/HealthLine.swift` (`HealthLine.wording`, `note(_:settingLine:)`, `text(in:)`, `isDue`, `HealthWorkout`); test `HealthLineTests`.
- App: `App/Paragon/HealthLineWriter.swift` (HealthKit under `#if canImport(HealthKit) && os(iOS)`; `AppModel.writeHealthLine`, `updateHealthLine`).
- No screen test (a Settings switch, not a screen; HealthKit cannot run in CI).
- Uncertain to compile: `HKHealthStore.requestAuthorization(toShare:read:) async` with `toShare: []`; closures resuming `CheckedContinuation` from HKStatisticsQuery / HKSampleQuery (HealthLineWriter.swift).

## Pick 49: Everything about one person
- Task menu: **Person…** (`task.menu.person`): popover "Who is it about?" with a Name field (`task.person.field`) + Add, the people already used as chips (`task.person.choice.<name>`), **Choose from Contacts…** (iPhone/iPad: Apple's contact picker in a sheet, no permission) or **Search Contacts** (Mac: asks Contacts, shows up to 8 names `task.person.found.<name>`), **Cancel**/**Save** (`task.person.cancel` / `.save`). Save with nobody chosen takes the link away. Texts: "Chosen", "People you already use", "Nobody chosen and Save takes the link away.", "Contacts did not allow it. You can type the name instead, or allow PARAGON in System Settings.", "Nobody in Contacts has that name."
- Note header: **Person…** chip (`note.people`, shows the names when set) opens "People in this note" (same view, several allowed; ids `note.people.choose.*`); writes `people: [Anna Svensson]` into the settings block via `AppModel.setNotePeople`. On a task: `@person(Anna Svensson)`; one person per task.
- Row shows the person with the `person.linked` mark.
- Page **People**: inside the Tags screen (smaller change than a new sidebar section; no exhaustive switch touched). A segmented **Tags | People** switch (`tags.people.switch`) is at the top of the Tags screen (in the make-tag bar) and of the People page. People page: one folding header per person A to Z (`people.person.<name>`) with "1 open · 1 done · 1 note", opened: the notes (buttons) and open tasks (TaskRow). Empty page: "No people yet" (`people.empty`) + "Choose Person… on a task's menu or in a note's header to link it to someone in your Contacts. Everything linked to one person is then here." Reach it: Browse/sidebar › Tags › People.
- Core: `Vault/People.swift` (`NoteIndex.people()`, `peopleNames()`, `PersonEntry`, `Note.people`, `Note.settingPeople`).
- Screen test (iPhone only, the Mac's Tools group folds): `testThePeoplePageIsBehindASwitchOnTheTagsScreen`; ScreenTests got `Place.tags` (`sidebar.Tags` / `browse.Tags`) in both `way(to:)` switches.
- Uncertain: `CNContactStore.requestAccess(for:) async`, `unifiedContacts(matching:keysToFetch:)` (PlaceAndPerson.swift, ContactNames.search); the iPhone phone Browse row id is assumed to be `browse.Tags`.

## Files touched
Core: Markdown/TaskMarkers.swift (new), Markdown/TaskParser.swift, Markdown/MarkdownHighlight.swift, Sync/RemindersStore.swift, Sync/SyncEngine.swift, Vault/People.swift (new), Vault/HealthLine.swift (new); tests PlacePeopleTests, HealthLineTests.
App: Views/PlaceAndPerson.swift (new), HealthLineWriter.swift (new), EventKitRemindersStore.swift, Views/Marks.swift, Views/TaskActions.swift, Views/NoteEditorView.swift (TaskRow state + popover on the Spacer + facts + NotePeopleChip in NoteHeader), Views/TagsView.swift, Views/SettingsView.swift (one line), Views/ContentView.swift (one line).
Config: project.yml, App/Config/Paragon/Info.plist, Paragon-macOS(.Debug).entitlements; HealthKit entitlement in its own commit.
Tests/ParagonUITests/ScreenTests.swift (Place.tags + one test at the end of the class).

## Not done
Home/Work places from the contacts card; in-app picture of any of this (nothing was run).
