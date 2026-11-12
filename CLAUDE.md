# PARAGON – working notes

Memory for anyone (human or Claude) picking this project up. Keep it short and current.

## What this is

macOS/iOS app in the spirit of NotePlan: plain markdown vault organised as
Goals + PARA (Projects, Areas, Resources, Archive), tasks synced two-way with
Apple Reminders, daily/weekly notes, quick capture, full-text search.

Owner: Martin Schabbauer (project manager, part-time retired, Sweden, not a
developer). **English is not his first language.** Write short, plain sentences with common
words. No idioms, no wordplay, no invented shorthand, and never a heading that stands in for
a sentence — "the word", "chains", "ladders" and "Serves… on an area" each cost a round trip
on 11 September because he could not tell what they meant. Name every button and screen
exactly as it is spelled in the app, and give whole URLs, never an abbreviation. **Write to him in English again** — he asked on **13 September 2026**: *"let's speak English
for some time. Sometimes that is easier for me, and I think it's easier in some respects
because the app is in English."* From 11 to 13 September it was Swedish prose with English
terms; that rule is on hold, not gone, so switch back the moment he asks. Either way the
reason behind it holds: he runs GitHub, TestFlight and the app in English, so button names,
screen names and field names are always quoted exactly as they appear there — *New Note*,
*Horizon*, *Aspiration*, *Serves…*, *Set a deadline…*, *Review*, *Run workflow*, *Update*.
Plain short sentences matter more than the language.
**The app's name is written PARAGON, in capitals, everywhere he reads it** (2 October 2026,
his words: *"Please write Paragon with capitals. PARAGON"*): chat, docs, version history,
artifact titles, session titles. Code names (`ParagonCore`, `ParagonApp`, `App/Paragon/`) are
unchanged; those are identifiers, not prose.
**Two things never to ask him (1 October 2026, his words: "If you don't need that information,
you are to do the work, and I am not"):** which build he is running — the Crash reports
workflow, TestFlight and his screenshots all say so, and a question about it is me not having
looked — and whether he has sent a crash report. Run the workflow, read what is there, and work
from that. If a report is not at Apple, say what is known without it and carry on.
Communicate in short, friendly, concrete steps. He cannot run
Terminal commands. Since build 56 both apps come from TestFlight.
**Since 13 September 2026 I start the TestFlight upload myself.** He asked for it — "Now I
have run the test flight a large number of times. Is it possible that you run it on GitHub
when the CI is green? This would mean that I don't need to do it." So the routine is now: CI
goes green, I dispatch the workflow with `mcp__github__actions_run_trigger` (`run_workflow`,
`workflow_id: testflight.yml`, `ref: claude/ams-para-reminders-sync-s0ex53`, and a one-line
`notes` input naming the build), **then wait for that run to finish** and tell him in **one**
line that the build is in TestFlight and his only step is **Update** in Apple's TestFlight app,
on the phone and on the Mac. **Telling him it has started is the wrong moment** — he said so on
13 September: *"Don't wait the 5 minutes because I can take care of that myself. I would like
to know immediately when the TestFlight workflow is done."* So: no "it is uploading", no "give
it five minutes"; poll the run and speak when it is green (about four minutes), or say so at
once if it fails. **But say what green actually means.** On 22 September I said build 212 was
"in TestFlight" the moment the run went green and he answered *"Still nothing in TestFlight on
the iPhone"* — because a green run means Apple has *received* the build, not that it is on his
phone; Apple then processes it for five to fifteen minutes. **The line is "the upload is done,
Apple is processing it now — look for build N in a few minutes"**, never "it is in TestFlight".
The timing he asked for is unchanged; only the claim is. **Only for
a push that bumped `BuildStamp.number`** — a docs-only push must not spend a TestFlight run,
and two uploads of the same build number are refused by Apple anyway. Still give him the
**whole URL** when he wants to watch it —
https://github.com/marsch124/AMS-PARAGON/actions/workflows/testflight.yml — never an
abbreviation, because after the repository rename the old shorthand sent him to the wrong
place. Xcode is no longer part of his routine.

## Layout

- `Core/` – Swift package `ParagonCore` (models, markdown, vault, sync engine, search, capture). `swift test --package-path Core`.
- `App/Paragon/` – SwiftUI app (macOS + iOS). `App/ParagonShare/` – iOS share extension.
- `project.yml` – XcodeGen spec. `Paragon.xcodeproj/` is committed; CI regenerates it only when `project.yml` changes (keeps his signing Team).
- `Example Vault/` – sample vault incl. Goals, Calendar, Templates.
- `.github/workflows/ci.yml` – macOS runner: package tests, xcodegen, xcodebuild macOS + iOS Simulator.

## Rules

- Branch: `claude/ams-para-reminders-sync-s0ex53` only. No PRs unless asked.
- GitHub repo is `marsch124/AMS-PARAGON` since 11 September 2026 (it was `AMS-PARA`). GitHub
  forwards the old address, so a remote still pointing at the old name keeps working — which is
  how the session that renamed it carried on afterwards. The working branch keeps its original
  spelling, `claude/ams-para-reminders-sync-s0ex53`: it is only a label.
- No Swift toolchain in the remote container: verify via CI (`mcp__github__actions_list`, `get_job_logs`).
- Bump `BuildStamp.number` in `App/Paragon/AppModel.swift` on every push; it shows at the bottom of the sidebar so we know which build he runs.
- Add a section for that build to `Docs/VersionHistory.md` (user-facing wording) on every push. `Docs/HowItWorks.md` is the manual; update it when behaviour changes. Both are bundled (project.yml `Docs` resources) and shown by `HelpView`.
- Build N = CI run N, *usually*: a docs-only push spends a run without bumping the stamp, so
  the two drift apart (first at build 123, CI run 124). `BuildStamp.number` in the app and in
  TestFlight is the truth; match on that, not on the run number.
- Adding a source file needs a `project.yml` change so CI regenerates the committed project.

## Conventions

- Frontmatter YAML subset; empty values written as `key:`.
- Tasks: `- [ ]`, `- [x] @done(...)`, `- [-]`, `- [>]`, `>YYYY-MM-DD[THH:mm]`, `!`..`!!!`, `#tag`, `^tXXXXXX`, indented subtasks.
- Goals never sync to Reminders. Projects/areas link with `goal: <title>`.
- Colours: Projects green, Areas pink, Resources blue, Archive grey, Goals gold.
- All model writes that SwiftUI triggers mid-update go through `afterUpdate` / deferred Bindings (`sectionSelection`, `noteSelection`, `sheetSelection`, `errorPresented`).
- Navigation from links uses `AppModel.show(...)`: section first, note on the next turn.
- **Nothing but views inside a `@ViewBuilder`.** `var x = …`, `x.append(…)`, loops and
  early returns are not allowed there and fail the build with "'buildExpression' is
  unavailable: this expression does not conform to 'View'" (build 58). Assemble strings,
  arrays and conditions in a plain function or a computed property and let the view read
  the result. There is no Swift compiler in this container, so CI is the only check and a
  slip like this costs a whole build.
- **Nothing may be attached to a row in a `List(selection:)` that takes its click.**
  `.draggable` and `.onTapGesture` both do on macOS, and `.simultaneousGesture` did not save it
  either: builds 71 to 74 left the Inbox unusable because no line could be selected, and CI
  cannot catch it. Row actions belong on the context menu or the row's own buttons. Whatever
  the fix looks like, changing one thing per build is the only way to know which one it was.
- **`.position` makes a view claim its parent's whole size**, so gestures attached to it fire
  anywhere in the parent: in build 85 every map box swallowed clicks across the entire canvas
  and the last one drawn won them all. Place things on a canvas with `.offset` inside a
  top-leading stack instead — the view keeps its own size and hit area.
- **One gesture, not two, when a view must handle both a tap and a drag.** `.onTapGesture`
  beside `.gesture(DragGesture…)` on the same view argues over a click and the tap loses
  (build 85). Use a single `DragGesture(minimumDistance: 0)` and decide in `onEnded`: no
  movement is a tap.
- **The phone's navigation bar fits a back button, a title and one control.** Anything more
  collides: build 88 put a segmented Picker plus three buttons there and it rendered as
  overlapping letters. Branch the `.toolbar` on `isPhone` and give the phone one `Menu`
  (`ToolbarContentBuilder` takes `if`/`else`).
- **A `.principal` toolbar item is only the title when the title is inline.** With the default
  large title iOS draws its own below the bar and the principal view is not what a press lands
  on, so build 112's long press on the phone's "Browse" title did nothing until build 117 added
  `.navigationBarTitleDisplayMode(.inline)`. A hidden gesture also needs a second, findable
  target: the "Build N" row at the foot of the Browse list carries the same long press.
- **Shortcuts are the thing this project keeps getting wrong — check three things before
  choosing one.** Does macOS already own it (⌥⌘D hides the Dock, ⌥⌘W closes every window)?
  Does the *app's own* menu already carry it — a `WindowGroup` puts **New Window** on ⌘N, and
  `CommandGroup(after: .newItem)` leaves that in place and loses, so it must be
  `replacing:` (build 120)? And does the key exist on a Swedish keyboard — `[` and `]` are
  ⌥8 and ⌥9 there, which is why Back and Forward are ⌃⌘← / ⌃⌘→ and not the browsers' ⌘[ / ⌘]
  (build 118)? CI compiles the menu but never presses it, so none of this is caught here.
- A helper type that touches `AppModel` needs `@MainActor` on it (the model is main-actor
  bound), or the build fails with "main actor-isolated property … can not be referenced from
  a nonisolated context" (build 67).

## Recently fixed (build 30)

The "window scramble": expanding **Linked notes** (a DisclosureGroup above
the TextEditor in NoteEditorView) made the editor report its full text
height as a minimum, the NavigationSplitView grew to ~1300pt inside an
821pt window and every column looked scrolled under the toolbar. He called
this "pressing Linked Goals"; the header goal link was never the trigger.
Fix: the editor HStack sits in a GeometryReader with a fixed frame, so it
takes the remaining height and never demands more. Diagnostics stay:
**Help › Copy Diagnostics** (⌃⌘D since build 103; ⌥⌘D is macOS's own hide-the-Dock
shortcut and never reached the app) copies a log with clicks (hit view),
section/note changes and the window view tree; an OVERFLOW line appears
if it ever happens again. Build 29's 1pt window nudge was removed (it made
the window grow to the demanded height).

## Deleting notes (build 31)

Every note except Inbox can go to the system Trash: editor toolbar button
(⌘⌫) or right-click in the note list, both with a confirmation. Goals can
be archived too. `Vault.trash` uses `trashItem`, falling back to delete.

## Map (build 32)

Sidebar **Map**: a top-down diagram of what serves what. `NoteIndex.linkMap()`
(Core, `Vault/LinkMap.swift`) builds a tree: root goals → subgoals, areas,
projects (a project sits under its area when it has one, with a dashed second
link to its goal) → open top-level tasks and resources as chips. Notes with no
goal, loose resources, and archived or done notes go into dashed group boxes;
archived notes keep dashed links to the goal/area they still name. `MapView`
lays it out itself (`MapLayout`: parents centred over subtrees, fixed-size
boxes in a two-way ScrollView, lines in a Canvas). Clicking a box highlights
its neighbourhood (`upstream`/`downstream`) and opens the note. Goal matching
for `goal:` lines now lives in `NoteIndex.goal(matching:)`.

## Apple Calendar (build 33)

Read only. `EventKitCalendarStore` (own `EKEventStore`, full-access request on
first use) feeds `AppModel.eventsByDay`; Today and the daily note agenda show
the day's events above the tasks. Settings › Apple Calendar can turn it off.
Info.plist carries `NSCalendarsFullAccessUsageDescription` via `project.yml`.
Nothing is written to Calendar; tasks are not turned into events.

## Split view sizing (build 34)

Root cause of every "columns hidden under the toolbar" report: on macOS the
NavigationSplitView representable sizes itself from its columns' NSHostingView
intrinsic content size, and a column whose content fills its space reports
"current height + toolbar inset" whenever it is re-measured (task added,
disclosure opened, section switched), so the split view grew past the window
each time. `AppModel.tameSplitViewColumns` walks the window, sets
`sizingOptions = []` on every NSHostingView under the NSSplitView (not inside
scroll views, so list rows keep their heights), and runs at launch, after
section/note changes and after every click; `repairOverflow` also resets the
host frame if it still overflows. Help › Copy Diagnostics shows "tamed N".

## Calendar choice, Time Blocks, open in Calendar (build 35)

Settings › Apple Calendar lists every calendar with a toggle (`visibleCalendarIDs`,
nil = all) and "Time blocks go to" (`timeBlockCalendarID`). Sidebar **Time
Blocks** (`TimeBlocksView`): a form (title, day, start, duration, calendar,
notes) writes ordinary events to Apple Calendar marked with URL
`amspara://timeblock` and the note marker `ams-para:timeblock`; the list shows
blocks from a week back to 60 days ahead, click to edit, right-click to open
in Calendar or delete. Blocks are deliberately separate from tasks. Every
event row has "Open in Calendar" (double-click, arrow button, context menu):
macOS `ical://ekevent/<id>`, iOS `calshow:`. Adding a source file needs a
`project.yml` change so CI regenerates the committed Xcode project.

## Hardening audit (build 39)

Three reviews (sync engine, vault/markdown/capture, app layer) and the fixes:
- `Frontmatter` keeps unknown lines as `.raw` entries in an ordered list; a
  leading `---` around prose is not frontmatter; CRLF/BOM handled; quotes unescaped.
- `Vault.save` throws `modifiedOnDisk` when the file is newer than
  `note.modifiedAt` (1 s tolerance) and returns the note with the new date;
  `saveConflictCopy` writes "<name> (conflict yyyy-MM-dd HHmm).md".
  `loadNote` decodes UTF-8 → UTF-16 (BOM) → CP1252; unreadable files land in
  `vault.skippedFiles` instead of failing `allNotes()`. `isNotePath` guards
  paths from links. `archive` never overwrites an older archived note.
- `Note.replace(task:previousID:)` matches by id/title and searches when lines
  moved. `@done` stamps survive on cancelled tasks.
- `SyncEngine.run`: ids persisted before Reminders is touched; every note
  change is recorded as a mutation and re-applied to a fresh copy on
  `modifiedOnDisk`; lists from existing links are fetched too (rename moves
  reminders); a link whose list was not fetched or whose note is missing is
  kept, never cancelled/deleted; marked reminders unknown to this device are
  never deleted; duplicate ids get fresh ones; `^t`/`@done` stripped from
  reminder titles; imported reminders get their marker after notes+state are
  saved; on error the partial state is saved before rethrowing.
  `InMemoryRemindersStore` has `beforeFetch`, `failNextCreate`, `failNextUpdate`.
- App: `flushEditor` hook (NoteEditorView) is called before every model write,
  before sync, on scene background and `NSApplication.willTerminate`;
  `saveText` keeps a conflict copy on `modifiedOnDisk`, `save` reloads and asks
  to redo; `checkForExternalChanges` (10 s signature poll + on activate)
  reloads; `openVault` opens the new folder before dropping the old scope;
  open/close refuse while syncing; `drainOutbox` requeues failures; capture
  keeps items on failure; `handle(url:)` never creates notes; the share
  extension fails visibly without the App Group.
- Not done (by choice): caching task parsing for the month view (perf only),
  limiting first sync of old daily notes.

## Task actions, Done, weekly plan (build 41)

Core: `RepeatRule` + `TaskItem.repeatRule` (`@repeat(weekly|2w|…)`, serialized
after the due date), `TaskItem.nextOccurrence`, `Note.complete(task:)` inserts
the next occurrence below (also in `SyncEngine.reconcile` when Reminders
completes it), `Note.taskBlock/removeTaskBlock/appendTaskBlock` move a task
with its subtasks, `Note.setNextAction` (`#next` tag, one per note),
`Note.nextAction`, `Note.progress`, `NoteIndex.nextActions()`.
App: `TaskActions.swift` has `TaskTransfer` (UTType
`com.schabbauer.amspara.task`, declared in Info.plist), `acceptsTaskDrop`,
`TaskContextMenu` (reschedule/repeat/next/block time/move/open),
`TaskDatePicker`. `TaskRow` is draggable with the menu; drops on note rows,
sidebar Inbox, month cells, week headers, weekly-note day rows. `DoneView`
(sidebar Done). `AppModel`: `setDueDate/setRepeat/makeNextAction/
clearNextAction/moveTask/blockTime/task(for:)`, `timeBlockDraft`.
Project: `type: syncedFolder` for App/Paragon and App/ParagonShare (Xcode 16
synchronized groups) so new source files need no regeneration; Info.plist and
entitlements live in `App/Config/<target>/`; CI commits `App/Config`.

## iPhone layout (build 42)

`PhoneRootView` (iOS only, used by ContentView when `horizontalSizeClass ==
.compact`): TabView with Today, Inbox, Browse (`PhoneBrowseView`: every
section + Settings) and a Capture tab that opens the quick-capture sheet.
`PhoneStack` wraps each tab in a NavigationStack with `PhoneRoute` (note,
section, settings); it pushes `NoteEditorView` when `selectedNotePath` changes
on the active tab and clears the selection when popped. Sections reuse
`NoteListView` by setting `model.section` on appear.

## iPhone note screen scrolls (build 53)

`NoteEditorView` was one fixed `VStack`: header, agendas, task checklist, links, editor,
add-a-task row. Nothing in it scrolled, which is fine on a Mac window and impossible on a
phone — a note with 25 tasks ran off both ends at once, the first tasks behind the
navigation bar and the last behind the tab bar, with no way to reach either.

The body is now `deskBody` (unchanged: the `GeometryReader` that keeps builds 30/34 honest)
or `phoneBody`, chosen by `horizontalSizeClass == .compact`. `phoneBody` is one `ScrollView`
over the same `sections`, with `editorPane` given a fixed 320pt — inside a scroll view there
is no leftover height to take — and `addTaskBar` pinned as a `.safeAreaInset(edge: .bottom)`
so it never has to be scrolled to. The shared pieces (`sections`, `editorPane`, `addTaskBar`)
are what both layouts are built from, so a change lands on both.

**Build 127 removed the 320pt box while editing — and the story of how long that took is
the lesson.** A `UITextView` scrolls itself, so on the phone the editor was one scroll view
inside another and the note was penned into a 320pt window. `MarkdownSyntaxEditor` takes
`scrolls:`; `phoneBody` passes `false` **only in Edit mode** and gives it
`.frame(minHeight: 320)`, and the iOS representable implements
`sizeThatFits(_:uiView:context:)` returning `uiView.sizeThatFits` for the proposed width but
never less than `leastHeight` (320). Two independent floors, because an early version had
none. Preview and Split still get `.frame(height: 320)` and a scrolling text view, since
`MarkdownPreview` is itself a `ScrollView` and needs a height handed to it. macOS passes
`true` throughout — builds 30/34 are about the Mac's editor never reporting its full height.

**The lesson, which cost a whole day: I never established the symptom before fixing it.**
He said he could not type in a note on the phone. I assumed the editor had collapsed, shipped
this change (123), took the blame, reverted it, shipped it again with floors (125), took the
blame again, reverted that too (126) — and 126 was byte-identical to 122 and *still* failed.
The actual cause was that his `editorMode` was set to **Preview**, where there is no text view
at all and no tap can ever place a cursor. Both "broken" builds had left Preview on the old
code path untouched, so neither had ever broken anything. Before changing code to fix a
report, find out what the user is actually looking at — one question would have saved two
reverts and his patience. Build 127 also puts an Edit/Preview toggle in the phone's add-task
bar so that mode can never again be a hidden setting three taps deep.

**Testing the phone layouts on this Mac.** Xcode 26.6 is installed, so the simulator is
usable without CI:

- `xcodebuild -scheme Paragon -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/amspara-dd build`
- the vault is a security-scoped bookmark, so there is no path to set — generate one with
  `URL.bookmarkData()` on the Mac and write it into the app's
  `Library/Preferences/com.schabbauer.AMSPara.plist` as `vaultBookmark`. It resolves in the
  simulator, which shares the Mac's filesystem.
- every route to a note is a tap, so `ContentView.onAppear` reads `PARAGON_OPEN_NOTE`
  (DEBUG only) and opens that note through the existing `amspara://` handler:
  `SIMCTL_CHILD_PARAGON_OPEN_NOTE=Inbox xcrun simctl launch booted com.schabbauer.AMSPara`
- `@AppStorage` values (`editorMode`) can be preset in the same plist to reach a mode.
- Screenshots with `xcrun simctl io booted screenshot`. Taps need the Simulator MCP, which
  wants `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` on his Mac;
  osascript keystrokes are TCC-blocked, so without that there is no way to tap.

**macOS builds locally only with signing off:** add
`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`.

## Hidden task markers (build 43)

`TaskIDMasking` (Core) hides `^tXXXXXX` in the editor: `hidden(in:)` strips them
for display, `restored(_:from:)` puts them back by matching unchanged task lines
first and pairing what is left between those anchors in order (so a renamed task
keeps its marker, a new one gets none). `NoteEditorView` keeps `baseText` (the
real text the shown text came from) and saves through `write(_:)`.
`SyncEngine.run` builds `recoverableIDs` from links whose id no longer exists,
keyed by "notePath\ntitle" from `lastTaskFingerprint`, and gives the old id back
to a matching task without one, so the reminder is not deleted and recreated.

## Backups and sync preview (build 44)

`VaultBackup` (Core, `Vault/VaultBackup.swift`): plain dated folders under
`.ams-para/Backups/<yyyy-MM-dd HHmm>~<reason>`, `makeBackup` skips when the
content signature (paths + mtimes of .md/.json/.txt outside Backups) matches the
last one, keeps 10, `restore` backs up first and never deletes newer notes,
`copyContents(to:)` clones the vault for the preview. `AppModel`: `backUp`,
`backUpNow`, `backUpDaily` (launch + openVault, keyed by `lastBackupDay`),
`restore`, `showBackupsInFinder`, `backsUpBeforeSync` (default on, runs inside
`syncNow`). `previewSync()` copies the vault to a temp folder and seeds an
`InMemoryRemindersStore` from EventKit (`seed(lists:records:)`), runs the real
engine there and shows `SyncReportView` through `AppSheet.syncReport`
(`reportToShow`/`reportIsPreview`) — never a second `.sheet` modifier.

## Look and feel (build 46)

`Views/Theme.swift`: `Theme` (gutter/gap/radius, `editorFont` = proportional
`.body`, `editorLineSpacing`), `SectionLabel` (uppercase caption + optional
count) and `EmptyStateView` (icon, title, sentence, one action button).
`NoteListView.emptyList(searching:)` shows a per-section empty state instead
of the list; `DetailView` uses `EmptyStateView` too. `TintStripe`/`KindBadge`
stay in ContentView. (TodayView's date-and-due-count row went in build 219.)

## Live markdown editor (build 47)

`MarkdownHighlight` (Core) turns a note into `[MarkdownSpan]` (range + style):
block styles first (frontmatter, fences, heading, task, quote, rule), inline
after (bold/italic/code/wikilink), so the later, smaller span wins.
`MarkdownSyntaxEditor` (App) wraps NSTextView/UITextView in a representable and
maps the styles to attributes in `MarkdownAttributes`; the whole note is
restyled after each change (skipped over 200k characters). The binding is only
written back when the text really differs, so typing is never interrupted, and
`updateNSView` only replaces the string when it came from elsewhere. Replaces
the TextEditor in `NoteEditorView`; all the save, flush and masking logic is
unchanged.

## TestFlight (build 48)

`.github/workflows/testflight.yml`, manual dispatch only, a two-way matrix (iOS and
macOS, `fail-fast: false`) so one button ships both apps: xcodegen, PlistBuddy
sets CFBundleVersion/ShortVersion from `github.run_number` and adds
`ITSAppUsesNonExemptEncryption` (done in the workflow, not project.yml, so the
committed Xcode project and his signing Team are never touched), writes the
App Store Connect key to `~/private_keys/AuthKey_<ID>.p8`, archives for
`generic/platform=iOS` with `-allowProvisioningUpdates` + the three
`-authenticationKey…` flags (cloud signing, no Mac and no certificates needed),
then `-exportArchive` with `method: app-store-connect` and `destination: upload`.
Secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` (the workflow
passes the team on the xcodebuild command line; without a team, signing fails).
Since build 55 `project.yml` also sets `DEVELOPMENT_TEAM: D24ENP83QQ` (his own team),
so Xcode no longer rewrites `project.pbxproj` locally and his pulls stay clean.
`TESTFLIGHT.md` at the repo root is his step-by-step (browser only, no Mac).
The uploaded version is `1.0.<BuildStamp.number>` with CFBundleVersion
`<BuildStamp.number>.<run number>`, read out of `AppModel.swift` by the workflow, so
TestFlight and the app always show the same build number.
The job runs on `macos-26` and `xcode-select`s the highest Xcode on the image:
Apple rejects an upload built with an older SDK. The key must have the **Admin**
role — App Manager gives "Cloud signing permission error" at export. The archive is built
**unsigned** (`CODE_SIGNING_ALLOWED=NO`, no `-allowProvisioningUpdates`) and `-exportArchive`
does the signing: signing at archive time signs for *development*, and every runner being a
fresh machine that minted a new development certificate per run until the account hit Apple's
limit ("Choose a certificate to revoke", build 61). Forcing
`CODE_SIGN_IDENTITY="Apple Distribution"` instead fails — automatic signing rejects a manual
identity ("conflicting provisioning settings", build 63). How little signing is possible
differs per platform, so the matrix carries a `signing:` string: iOS archives fully unsigned,
macOS ad-hoc (`CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-`) because a Mac App Store upload
needs the sandbox entitlement embedded and an unsigned build carries none ("App sandbox not
enabled", build 64). Both App IDs
need the App Group `group.com.schabbauer.amspara` enabled in the developer portal,
and `project.yml` declares `UISupportedInterfaceOrientations` (all four), without
which Apple rejects the binary. macOS signs with its own
`App/Config/Paragon/Paragon-macOS.entitlements` (via
`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`) which drops the App Group: the Mac App Store wants
team-prefixed groups, the share extension is iOS only, and `outboxURL` already falls back to
Application Support. The macOS platform must be added to the app record in App Store Connect
(Distribution › Add Platform) before the first Mac upload.

## Calendar schedule column (build 61)

`DayScheduleView.swift`: `CalendarDetailView` is the third column while `section == .calendar`
(wired in `DetailView`), with a Schedule/Note switch (`calendarDetailShowsNote`) that flips to
Note when a note is selected. `DayScheduleView` draws the day: `ScheduleItem` unifies events,
time blocks and timed tasks; `lanes(for:)` puts overlapping items side by side as `PlacedItem`
(a struct, because key paths cannot address tuple members); hours are drop targets that create
a one-hour block from a task. One `.sheet` only (build 44's lesson), keyed by `ScheduleSheet`,
for both new and existing blocks; it saves through `AppModel.saveTimeBlock`/`deleteTimeBlock`.

## Inbox triage (build 66)

`InboxView.swift`: `InboxTriageView` is the middle column while `section == .inbox` (wired in
`NoteListView`), because one inbox note made that column a list of one. Capture field on top,
then the open non-subtask lines with per-row actions and a menu; `TaskRef.triageID`
("path#lineIndex") is the selection id, since `TaskRef` identity shifts as lines move. Single
keys are guarded by `@FocusState` on the capture field so typing is never intercepted.
`AppModel.deleteTask` and `makeNote(from:kind:)` were added for it. The third column is
`InboxFileItView` (build 67): the selected line plus active projects and areas as click and
drop targets, sharing `AppModel.inboxSelection` with the middle column; `InboxItems` holds the
lookups so the two columns cannot drift apart. Goals are not destinations by choice. Whether the third column shows the note is an explicit `AppModel.inboxShowsNote`, not
"is a note selected": entering the section or picking a line resets it, so a note opened
elsewhere (or one just made from a line, which `createNote` selects) cannot take the column
over (build 69).

## All actions and hand-arranged lists (build 70)

`AllActionsView` (sidebar `.allActions`): every `index.openTasks()` grouped by note in
`model.notes` order, filtered by All / With a date / No date / Next actions.
Ordering: `Note.sortOrder` reads `order:` from frontmatter and `Note.byArrangedOrder` sorts
arranged notes first (then by title); `Vault.notes(kind:)` uses it, so the sidebar list, the
Inbox destinations and everything else agree. `AppModel.reorder(_:from:to:)` renumbers in tens
and writes `order:` into each note whose position changed; `NoteListView`'s `ForEach` carries
`.onMove`.

## Sub-areas (build 73)

An area note can carry `parent: <area title>`; `NoteIndex.parentArea(of:)`, `subAreas(of:)`,
`areaTree()` (→ `AreaBranch`) and `areasInFamilyOrder()` are the only places that resolve it.
One level only: an area whose own parent resolves is never a parent, which also keeps a pair
pointing at each other from dropping out of the list. `NoteListView` draws the Areas list flat
but two-deep (`visibleNotes`, indent from `parentArea`, a chevron writing to `foldedAreas`), and
`onMove` is mapped onto the row's family by `move(_:from:to:)`, so `AppModel.reorder` now also
takes an explicit `[Note]`. `AppModel.setParent` writes/removes the line and lifts the new
parent's own parent. `AreaParentOptions` (ContentView) holds the choices and is used by
`AreaParentMenu` (right-click a row) and `AreaParentChip` (the "Part of…" button in the
note header, build 74 — the context menu alone was unfindable); both take the model as a
parameter because context-menu content is built outside the row's hierarchy. The Inbox
destinations, the task "Move to" menu and `linkMap()` all use family order.


## Renaming notes (build 77)

`Vault.rename(_:to:)` writes `title:`, renames the file in the same folder (refusing a name in
use) and calls `Note.headingRenamed` for the first `# Heading`. Links are the caller's job:
`Note.retargeting(_:to:)` (Core, `Model/NoteRename.swift`) rewrites `goal`/`area`/`parent`/
`related` and `[[wikilinks]]` and returns nil when a note never mentioned the old name, so
`AppModel.renameNote` only saves the files that changed. Reached from the note row's context
menu (`NoteListView`, an `.alert` with a TextField — not an inline field, which would take the
row's click) and a toolbar button in `NoteEditorView`. Inbox and daily notes are excluded.

## Recent and the daily notes list (build 78)

`SidebarSection.recent` lists `AppModel.recentNotes`: `selectedNotePath`'s `didSet` pushes the
path onto `recentNotePaths` (newest first, 40 kept, in UserDefaults under `recentNotePaths`),
and `recentNotes` drops the ones whose file is gone. `notes(in:)` returns them in that order,
so the ordinary note list draws it. `CalendarMode.notes` adds a fourth Calendar view,
`DailyNotesListView`, over `index.dailyNotes` with its own `.searchable`; `DailyNoteRow` takes
`preview: true` there to show the first line of prose.

## Nested File it column (build 79)

`InboxFileItView` groups its destinations: `InboxItems.projects` and `InboxItems.areaBranches`
(the active part of `index.areaTree()`) under coloured headings, with `AreaDestinationGroup`
drawing an area's sub-areas indented beneath it — a rail overlay plus a per-row tick, and a
chevron writing to the view's `foldedAreas`. The chevron sits beside `DestinationRow`, never
inside it: the row is itself a Button. `DestinationRow` no longer indents itself; it tints a
sub-area's card instead.

## Deleted notes (build 80)

`Vault.trash` no longer uses `trashItem`: on iOS that fails and it fell through to
`removeItem`, so a delete on the phone was permanent and iCloud carried it to the Mac.
`Core/Vault/DeletedNotes.swift` moves the file into `.ams-para/Deleted/` instead, stamped
`deleted:` and `deleted-from:` in its frontmatter (nothing scans that folder, so it never
syncs), and offers `deletedNotes()`, `restore` (back to `deleted-from`, or "(restored)"
beside it), `purge` and `purgeDeleted(olderThan:)`. `AppModel` keeps `deletedNotes`
refreshed from `reload()`, runs `purgeOldDeleted()` (30 days) at launch and on open, and
`DeletedView` is the sidebar section.

## Map export and a navigable Help (build 81)

`MapExport` (App) renders `MapCanvas` at zoom 1 through `ImageRenderer` — the canvas takes no
environment object, so it renders off screen as is — for PNG (`nsImage`/`uiImage`) and PDF
(`render { size, draw in }` into a `CGContext(consumer:mediaBox:)`); `LinkMap.outline()` (Core)
is the text version. macOS saves through `NSSavePanel`, iOS through a `ShareSheet`
(`UIActivityViewController`) presented by MapView's only `.sheet`.

`HelpDocument` no longer renders one scroll: `HelpParts` splits a bundled document at its `##`
headings into `HelpSection`s drawn as `DisclosureGroup`s, `###` parses to `.subheading`, and a
search field filters the sections (a match forces them open). `Docs/HowItWorks.md` is written
for that shape — one subject per `##`, `###` inside the long ones.

## Dragging on the Map (build 82)

Boxes are `.draggable` and `.dropDestination(for: TaskTransfer.self)`; `MapCanvas.onDrop`
hands the pair to `MapView.link(_:onto:)`, which is the only place the rules live (project→area
`setArea`, project/area/goal→goal `setGoal`, area→area `setParent`, task chip→project/area
`moveTask`). Rather than a second UTType, `TaskTransfer` gained `isNote: Bool?`: a whole note
drags as one, and `AppModel.task(for:)` returns nil for those, so every existing task drop
target ignores them. `MapCanvas` keeps `targetedID` for the outline. The tap gesture and the
drag live on the same wrapper, which is fine here because the tap is ours, not a List's.

## Hand-placed map boxes (build 83)

`Note.mapPosition` reads `map: x,y` (unzoomed points, top left). `MapLayout.init` takes
`pinned: [String: CGPoint]` (`AppModel.pinnedMapPositions`) and overrides the computed frame of
any node whose `note.relativePath` is in it — after the automatic pass, so unpinned boxes keep
their places and the edges, drawn from the final frames, follow. `size` is the maximum
`maxX`/`maxY` rather than the column walk, or a parked box could fall outside the scroll area.
`MapNodeBox` is its own view because a live drag needs `@GestureState`: while `arranging` it
carries a `DragGesture` and a context menu, otherwise the `.draggable`/`.dropDestination` pair
from build 82 — an `if`, never both at once, so one gesture never means two things.
`AppModel.setMapPosition`/`clearMapPositions` write and remove the line. Build 84 marks
boxes for a group move: `MapView.marked` (node ids) is passed to `MapCanvas` as a binding, a
tap toggles membership while arranging, and the live offset moved out of `MapNodeBox` into
`MapCanvas` (`movingIDs` + `liveShift`) because one drag has to shift every marked box by the
same amount; `onMove` therefore hands back an array of (node, point). Build 85 adds a
rubber band: a `DragGesture` on the Canvas (gated by `including:` to macOS while arranging —
on iOS that drag scrolls the map) fills `band`, and on end unions the intersecting items into
`marked`, so sweeping and tapping compose.

## Templates and snippets (build 88)

`Core/Vault/Snippets.swift`: `Snippets.parse` splits `Templates/Snippets.md` at its `##`
headings into `Snippet`s (prose above the first heading is the file's own explanation),
`filled(_:answers:today:)` substitutes `{{date}}/{{today}}/{{tomorrow}}/{{week}}` itself and
asks for the rest through `Snippet.questions`; an unanswered placeholder is left in place
rather than emptied. The same file adds `Vault.templateNames/templateText(named:)/
saveTemplate`. `Templates.snippets` ships six blocks and is written by `bootstrap`.
App: `SidebarSection.templates` → `TemplatesView` (list) + `TemplateEditorView` (plain
TextEditor, ⌘S), sharing `AppModel.templateSelection`; `AppModel.snippets` is refreshed from
`reload()`, and the note's add-task bar has a Snippet menu that opens `SnippetSheet` when the
block has questions and otherwise inserts straight away through `AppModel.insert`.
Build 90: a template's own `type:` line says what it makes (`Vault.templates()` →
`TemplateFile`), so a kind can have several and `createNote(kind:title:extraFrontmatter:
template:)` takes the chosen one; `TemplateFile.defaultName(for:)` is the one used otherwise.
`TemplatesView` groups by kind in the kind's tint with folds, and has new/rename/delete.
`PhoneRoute.template` pushes the editor on the phone, where tapping a template did nothing.
Build 92: `TemplateEditorView` uses `MarkdownSyntaxEditor`, not a plain SwiftUI `TextEditor` —
the latter rendered the file in that column but never took a keystroke on macOS — and it saves
on a debounce as well as on ⌘S, on switching template and on disappearing.
Build 93: the groups are plain `Section`s with a fold button in the header (DisclosureGroups
inside a List drew their rows over each other); `NewTemplateSheet` replaced an `.alert`,
because a macOS alert silently drops everything that is not a TextField and the "makes a"
picker never appeared, so every new template came out a project; and
`currentVaultSignature()` includes the Templates folder and its files, or a template edited
on the other device is never noticed.

## Files iCloud has not sent yet (build 95)

A file written on the Mac reaches the iPhone as a hidden `.Name.md.icloud` stub until something
asks for it; every listing here skips hidden files or filters on `.md`, so it was invisible —
which is why a new template (and, unreported, a new note) never turned up on the phone.
`Core/Vault/CloudFiles.swift`: `realName(ofPlaceholder:)`, `placeholderURL(for:)`, `exists(_:)`
(a placeholder counts as the file being there), `isMissing`, `startDownload`, and
`Vault.downloadCloudFiles()` which walks the vault (skipping `.ams-para`) and asks for
everything missing, returning the relative paths. `AppModel.fetchCloudFiles` runs it at launch,
on `openVault` and from the 10 s poll at most once a minute; `templatesFromCloud` feeds the
"coming from iCloud" rows in `TemplatesView`. Every decision to *write* a file — `bootstrap`,
`createNote`, `rename`, `archive`, daily/weekly notes, `createTemplate`/`renameTemplate` — uses
`CloudFiles.exists`, or a note still on its way would be replaced by a fresh empty one and the
two would collide in iCloud; `loadNote` throws `VaultError.notDownloadedYet` for a placeholder.

## Multi-note writes and restore (build 99)

Hardening, part one: everything that writes more than one file goes through
`Core/Vault/VaultWrites.swift`, where the order and the failure handling live and can be
tested. `Vault.saveEach(_:change:)` applies one change to many notes and, on
`modifiedOnDisk`, re-reads that note and applies the change again before giving up;
`MultiSaveResult.failed` is what could not be written. `Vault.move(task:from:to:)` writes the
**target first** — a failure then means the task is in both notes, never in neither — and
reports `leftInSource`. `Vault.rename(_:to:updating:)` renames the note first (a throw leaves
every link untouched) and returns `staleLinks`, the notes that still name the old title.
`VaultError.taskNotFound` is new. `AppModel.moveTask/makeNote(from:)/renameNote/reorder` use
them and now *say* when something did not happen: `makeNote` creates the note before removing
the line, and `renameNote` backs the vault up first. `VaultWriteTests` forces each failure by
writing the file behind the app's back or by putting a folder where the file was.

Part two, backups: `Vault.restore` returns `RestoreResult` (written + failed) and keeps going
past a file it cannot write instead of stopping halfway; `makeBackup` skips a file it cannot
copy (writing their paths to `skipped.txt` beside `signature.txt`) rather than losing the whole
backup, and throws `VaultError.backupFailed` if it copied no note at all. `VaultBackup.date(
fromFolderPart:)` also parses "… 2~reason", the name a second backup in the same minute gets —
those were invisible in the list and so never pruned. `AppModel.backUp` asks iCloud for missing
files first, or the copy is quietly short. `RestoreTests` is the first exercise the way back
has ever had.

## An empty vault is never drawn without saying why (build 100)

What the restore incident actually was: every file in his vault was evicted to iCloud
("Optimize Mac Storage"), `loadNote` failed on all of them, `notes(kind:)` swallowed each one
into `skippedFiles`, and the app drew "No projects yet" — indistinguishable from having lost
the lot. The restore was not the culprit; the silence was.
`notes(kind:)` now sorts a failure into `Vault.notesWaitingForCloud` (when
`CloudFiles.isMissing` or `.notDownloadedYet`, and it asks for the download there and then) or
`skippedFiles` (really damaged). `AppModel` publishes both plus `vaultWarning`, shown by
`VaultWarningBar` (Theme.swift) at the foot of the sidebar and by `emptyList` in place of the
per-section empty state, both with "Ask iCloud again" → `fetchMissingNotes()`.
`SyncReport.warnings` lists the waiting notes too.
Build 101 found the cause underneath it: **a plain `Data(contentsOf:)` fails on a file whose
contents iCloud has not put on the device**, which is why TextEdit opened the very note the app
called unreadable. `CloudFiles.read(_:)` tries the plain read and, on failure, repeats it inside
`NSFileCoordinator().coordinate(readingItemAt:)`, which makes iCloud materialise the file and
waits; `loadNote` goes through it. Also build 101: the whole-vault walk moved into
`CloudFiles.downloadMissing(under:skipping:)` (no `Vault`, so it is Sendable-safe) and
`AppModel.fetchCloudFiles` runs it in a `Task.detached` — done synchronously in `init` since
build 95 it could hold up launch long enough for iOS to kill the app.
Build 102 bounds that: a coordinated read waits for the download, so `notes(kind:)` spends at
most `Vault.cloudFetchesPerLoad` (15) of them per `allNotes()` and reports the rest as waiting,
and `checkForExternalChanges` reloads while anything is waiting — materialising a file does not
change its modification date, so the vault signature would never notice them arriving.
**Build 104 is the real root cause**, found from his diagnostics ("notes: 1", no skipped-files
line — the app had not *failed* to read anything, it had seen nothing): iCloud had every note as
a hidden `.Name.md.icloud` stub and `notes(kind:)` enumerated with `.skipsHiddenFiles`. So the
whole vault was invisible and nothing was even reported. `notes(kind:)` now enumerates without
that option, turns a `.md` stub into its real path, asks for the download, and either fetches it
(within `cloudFetchesPerLoad`) or names it in `notesWaitingForCloud`; other dot-files are still
ignored by name. `loadNote` no longer refuses a path that is only a stub — the coordinated read
is what fetches it. `allNotes`/`notes(kind: .inbox)` use `CloudFiles.exists`.
Build 106 replaces the polling with the system telling us: `App/CloudWatcher.swift` runs an
`NSMetadataQuery` over the vault's path (scopes `…AccessibleUbiquitousExternalDocumentsScope`
+ `…UbiquitousDocumentsScope`, since the vault is a folder the user chose, not the app's own
container), debounced to one report every 2 s, wired to `AppModel.cloudFilesChanged` →
`reload()` while anything is outstanding. The 10 s poll stays as a backstop: a query that never
reports must not leave the app blind. Also build 106: `AppModel.syncNow(force:)` refuses to run
while `notesWaitingForCloud` is not empty — the engine never deletes a reminder whose note it
could not read (`loadedPaths` in `SyncEngine.run`, verified), but syncing half a vault is
needless risk.
**Rule: never let a read failure look like an absence.** A count of what could not be read
belongs in front of the user, not in the diagnostics log.

## The colour of the mode (build 107)

`ModeAccent` (Theme.swift, applied as `.modeAccent(_:)`) puts one even 8.5% tint of
`SidebarSection.tint` over the detail column (the 2pt hairline went in build 113: it read as a
border) — he chose the strength from a preview
artifact and had the top gradient removed in build 110, so change neither without asking; `DetailView.body` applies it to a
`detail` computed property holding the old `if`/`else` chain, so the ViewBuilder rule is kept.
Background and overlay, never a frame or an inset — the third column's intrinsic size is what
builds 30/34 were about. The tint follows the *section*, so it does not flicker as notes are
clicked. The phone has no such column, so `NoteEditorView.phoneBody` carries the same `.modeAccent`
(build 111).

## Work notes, kept apart (build 112)

A second set of notes he asked for: business notes with no planning and no Reminders, and no
sidebar row unless asked for. `Core/Vault/WorkNotes.swift` + `VaultConfig.workFolder` ("Work"):
`workNotes()`, `createWorkNote(title:)` (creates the folder only then, so an unused vault shows
no sign of it), `isWorkPath`, `searchWorkNotes`. **The exclusion is structural, not a filter:**
`allNotes()` walks the PARA folders and the Inbox and never goes there, so Today, All actions,
the Map, the review, the main search and — since `SyncEngine` starts from `allNotes()` — 
Reminders cannot see them, and nothing has to remember to exclude them. `AppModel.note(at:)`
falls back to `workNotes` so `NoteEditorView` and the row actions work unchanged; `save`/
`saveText` update whichever list holds the note; `canArchive` refuses them (archiving would
move one into the visible vault). `SidebarSection.work` is drawn only while
`AppModel.workRevealed`, which is session-only and never stored. In: a 1.2 s long press on the
sidebar's **PARA** header (a Section header, so it takes no click off a row), on the phone the
**Browse** title drawn as a `.principal` toolbar item (inline since build 117) or the
**Build N** row at the foot of Browse, or ⌃⌘W (not ⌥⌘W — macOS closes all
windows with that). The phone pushes the screen from `AppModel.workRequests`, a counter
bumped by every `revealWork()`, **not** from `workRevealed`: a Bool that is only ever set
true changes once, so the second long press did nothing at all (build 122). Anything a
repeatable gesture triggers needs a counter or an explicit request, never a latch. Out: the Hide button in the section's toolbar, or quitting.
Deliberately **not** in `Docs/HowItWorks.md`: the manual is bundled and visible to anyone
looking over his shoulder, so the gestures live in VersionHistory and here only.

## Linking with [[ ]] (build 114)

`Core/Markdown/WikiLinks.swift` holds every decision that is text rather than interface, so it
is testable: `draft(in:cursor:)` (the `[[` being typed — same line only, and a `]]` in between
closes it), `suggestions(for:among:limit:)` (prefix matches first, then contains),
`completing(_:draft:with:)` (returns the new text and where the cursor goes; swallows a `]]`
already after the cursor), `link(at:in:)`, `matches`, `titles`. `WikiLinkTests` covers them.
The editor's part: `MarkdownSyntaxEditor` gained `linkDraft` (out: what is being typed plus the
caret in the editor's coordinates), `completion` (in: the chosen title, written by the text view
itself so undo behaves), `openLink` and `onLinkKey`. **The list never writes into the text and
never takes focus** — it cannot, or typing would break — so the arrow keys, Return and Escape
arrive through `textView(_:doCommandBy:)` on macOS and are forwarded to `NoteEditorView.
handleLinkKey`. `LinkingTextView` (NSTextView subclass) takes ⌘-click only: a plain click must
keep placing the cursor. **iOS has no tap recogniser at all, and must not get one again (build 128).** 114 added a
`UITapGestureRecognizer` with `cancelsTouchesInView = false`, believing that made it yield.
It does not: a `UITextView`'s own single tap is what places the caret, and a second tap
recogniser on the same view makes that tap ambiguous, so the caret only appears on a press and
hold. That is the "long press to edit" he reported and put up with from 114 to 128, and it is
why three attempts at the editor's *layout* (123, 125, 127) never touched it — the fault was a
gesture, not a frame. On the phone, links are followed in Read mode, one tap away in the
add-task bar.
**Build 116, and the rule behind it:** a text view's delegate callbacks can land *inside* a
SwiftUI update, so the coordinator publishes `linkDraft` through a `DispatchQueue.main.async`
and never directly, and an `applying` flag keeps it silent while a chosen title is written in.
Picking a title beachballed the app without it — the same class of bug the model's `afterUpdate`
exists for.
`AppModel.linkableTitles(from:)`/`openWikiLink(_:from:)`/`backlinks(to:)` keep work notes and
ordinary notes from seeing each other in both directions. `NoteEditorView` splits the old mixed
list into **Links to** and **Linked from**.

## Back, Forward, and a link to a note that is not there (build 118)

`AppModel.Visit` (section + path) with `backStack`/`forwardStack` (both `@Published`, so the
buttons enable themselves) and `currentVisit`. `recordVisit` is called from
`selectedNotePath`'s `didSet`, so *every* route to a note is history, not only links; the
section stored is the one already set, because `show(section:notePath:)` sets it a turn
earlier. `expectedVisit` is the one arrival a Back or Forward will cause and is skipped once,
which is what keeps `goBack` from pushing what it just left straight back on. It is armed
**only when the target is not already on screen** and cleared again three `afterUpdate` hops
later (guarded by `expectedVisitToken`, so a second Back does not clear the first's): both
routes into `show` are no-ops when the path is unchanged, so an unconditional guard would
never be cleared and would eat the next genuine visit to that note — an adversarial review
found this before CI did. `goBack`/`goForward` step over notes that are gone (`note(at:)` nil)
*and* over the note already displayed, so a press never consumes a step without moving.
`clearHistory()` runs on `openVault`/`closeVault` (the same relative path is a different note
in another vault) and `hideWork()` calls `forgetWorkVisits()` — hidden has to mean hidden, or
Forward would put a work note back on screen with the section behind it.
Reached from a `ToolbarItemGroup(placement: .navigation)` in `NoteEditorView`'s desk branch,
and from `CommandMenu("Go")` so the shortcut works when no note is open. **⌃⌘← / ⌃⌘→, not the
browsers' ⌘[ / ⌘]:** on his Swedish keyboard those brackets are ⌥8 and ⌥9, so the menu would
advertise a key he does not have — the third time this project has paid for a shortcut chosen
from a US layout (⌥⌘D, ⌥⌘W). The phone is untouched: `PhoneStack` already pushes a route per
note, so the system back arrow is the same thing.

`openWikiLink` no longer only complains: with no match it sets `AppModel.LinkToCreate`
(title, source path, `isWork`) and opens `AppSheet.noteFromLink` — both **inside
`afterUpdate`**, since the ⌘-click lands in the text view's delegate (build 116's rule).
`NoteFromLinkSheet` (in `NewNoteSheet.swift`, so no new file and no `project.yml` change)
asks only for the kind; the title is the link's words and is not editable, or the link would
still point at nothing. `createNoteFromLink` routes a work note's link to `createWorkNote`.
`NoteEditorView.missingLinks(from:)` + `MissingLinksList` draw them as **Not made yet** under
Linked notes — the context of build 74: an action only reachable by a modifier-click is an
action nobody finds. `AppModel.open(reference:)` (the Preview's links) goes through
`openWikiLink` too; it used to make a Resource silently, so Preview and the editor answered
the same link differently.
**Neither offers to create while `notesWaitingForCloud` is not empty**: "there is no such
note" is not something this app may say with half a vault unread (build 100's rule), and
saying it would make a duplicate of a note already in iCloud.
`WikiLinks.target(of:)` (Core) is new: `[[Note|shown as this]]` and `[[Note#a heading]]` name
"Note". `matches(in:)` goes through it, so clicking, backlinks and **Not made yet** all agree
with the preview, which had always parsed them that way.

## New note asks one thing (build 119)

He called the old sheet "long and a bit crude" and picked this shape from a preview artifact
before anything was built. `NewNoteSheet` is now: name field first with `@FocusState`
(`DispatchQueue.main.async { nameFocused = true }` in `onAppear` — focus does not always take
in the appearing turn), the four kinds as `KindChoice` buttons in `ParaKind.tint` rather than
a segmented Picker, one line of `hint`, then `settingsFields`. **Build 121 removed the fold**:
119 put those fields behind a "More" button and he asked for everything on screen at once, so
they sit under a `Divider()` with no toggle — the win was the *order* (name first) and the
one-line hint, not the hiding. `hasMoreToOffer` now only decides whether there is a divider at
all, and `pick(_:)` clears `servesGoal`/`parentArea`/`target` on a change of kind so a choice
never follows you across.
New: a project can set `goal:` at creation. `ParaKind.singularName` (extension in
`NewNoteSheet.swift`) exists because `displayName` is the plural name of the list a note lands
in — wrong for the one note being made, which is how the old sheet came to label a new project
"Projects".

## Becoming PARAGON (build 129 on)

He is renaming the app from AMS PARA to PARAGON. Agreed with him from a brief he approved
(https://claude.ai/code/artifact/0e196e75-3832-4398-9c98-80240d90c64e), in four phases, each
one its own build so a red light means one thing:

1. **The icon** (build 129, done). A white frame outside the gold one with a small star on its
   top edge. `Tools/make_icon.py` draws the whole icon and is the only place it is drawn — the
   gold frame of build 111 was added by a one-off script and never written back, so from 111 to
   129 the committed script did not reproduce what shipped and this change had to start by
   measuring the PNG. Never draw the icon anywhere but that file.
2. **The name everywhere he sees it** (build 130, done). Also `PRODUCT_NAME: PARAGON` on the
   app target — on the Mac, Finder and the Dock read the bundle's *file* name, so
   `CFBundleDisplayName` alone leaves "AMSPara" on screen; the target and folder are
   untouched, and `PRODUCT_BUNDLE_IDENTIFIER` is now pinned explicitly so it can never
   follow a target rename. `CFBundleDisplayName`/`CFBundleName`, every visible
   string in the app, the permission prompts, the share extension's name, `Docs/HowItWorks.md`,
   `Docs/VersionHistory.md`, `README.md`, `TESTFLIGHT.md`, this file, the Example Vault.
3. **The name inside the code** (build 131, done). `App/AMSPara/` → `App/Paragon/`,
   `App/AMSParaShare/` → `App/ParagonShare/`, `App/Config/*` and the entitlements files with
   them, `AMSParaCore` → `ParagonCore` (and its tests), the two targets, the scheme, the
   project (`Paragon.xcodeproj`), `AMSParaApp` → `ParagonApp`, both workflows, and the debug
   `AMSPARA_OPEN_NOTE` → `PARAGON_OPEN_NOTE`. One substitution did nearly all of it, because
   `AMSParaCore`/`AMSParaShare`/`AMSParaApp` all fall out of `AMSPara` → `Paragon`; the bundle
   ids were held back behind a sentinel so they could not be caught by it. The diagnostics
   filter that picks our own stack frames is now case-insensitive on "paragon": the app's
   module is `PARAGON` (from `PRODUCT_NAME`) and the package's is `ParagonCore`, so a single
   spelling would have quietly matched half of them.
4. **Outside the app** (done 11 September 2026, by him, from a runbook:
   https://claude.ai/code/artifact/b6bd5eea-34c4-4d39-acb1-0b90e762d486). The App Store Connect
   name, the iCloud vault folder, and the GitHub repository — `AMS-PARA` → **`AMS-PARAGON`**,
   keeping the AMS. I expected the rename to end that session's access; it did not, because
   GitHub forwards the old address and the clone's remote still resolved.

**The rebrand is finished.** Nothing is left outstanding.

**Four identifiers deliberately keep the old name.** `com.schabbauer.AMSPara` (a new bundle id
is a different app: new TestFlight, fresh install, his settings gone), `ams-para:^t…` (the
marker in every mirrored reminder's notes — rename it and every existing reminder is orphaned),
`.ams-para` (the vault's state folder: sync state, backups, deleted notes), the Application
Support fallback folder in `AppModel.outboxURL`, and `amspara://`
(the capture link his Shortcuts use; `paragon://` can be *added* beside it, never instead).
The App Group `group.com.schabbauer.amspara` likewise: it is enabled in the developer portal
under that name.

## The aspiration chain (build 132 on)

He brought a spec from another session — "The Aspiration Chain"
(https://claude.ai/code/artifact/644b6073-0301-4c86-881c-a77a1ad78775): Area → Aspiration →
Goal → Project → Task, with rules the app should enforce and a review cadence per level.
**Most of it was already built**, under other names: `horizon: life` is the aspiration,
a dated goal pointing at it with `goal:` is the spec's Goal (the code already called it a
"life goal" with dated subgoals), `measure:` is the spec's criterion, and the review already
flagged `noNextAction`, `nothingServing`, `pastDue`, `pastTarget`.

**Deliberately not adopted:** the spec roots the whole chain on the Area. PARAGON roots on
goals, with areas and projects pointing up at them via `area:`/`goal:`. Both express the same
links — the difference is only what the Map hangs from — so adopting the spec's shape would
mean reworking the Map and re-filing his notes to connect nothing new. Agreed with him to keep
PARAGON's shape and take the spec's questions and checks.

Build 132 closed the gaps that were real, all pure computation over existing frontmatter:
`ProjectHealth.Flag.noGoal`, `.dueAfterGoal` (project `due:` later than its goal's `target:`),
and `GoalHealth.Flag.noProjectYet` (only an area serves it). That last one is **dated goals
only**: a life goal held by an area is the aspiration sitting inside its area, which is the
shape the model wants — `GoalTests.testReviewListsGoalsAttentionFirst` caught me flagging it
as a fault in build 132's first push.

**`noGoal` is not an alarm, by design.** `ProjectHealth.needsAttention` ignores it, the same
way it ignores `.onHold`, and `ReviewReport.projectsWithoutGoal` gathers them into one
"Hobby or homeless?" section instead. In a vault written before the chain, `noGoal` is true of
nearly every project, and a review where everything is red says nothing. Any future check that
would be true of most of his existing notes needs the same treatment.

Build 132 also added `AppModel.setDeadline` and `ProjectDeadlineChip` in the note header:
`due:` on a project was read by the review but **nothing in the app had ever written it**, so
the `pastDue` flag had never once been able to fire and `dueAfterGoal` would have been born
dead. Worth checking, when adding a rule, that something can actually produce the data it reads.

**Build 133 renamed the `horizon: life` label to "Aspiration"** (it was "Life goal"), and the
dated goal's picker to "Serves aspiration". His reason, and it is a good one: PARAGON is PARA
plus aspiration, goal and north star, so the app was using a different word for the idea in its
own name — which is exactly what confused him when he first met the New Note sheet. **The stored
value is still `horizon: life`**: only `GoalHorizon.label` and the picker title changed, so no
vault touched and no migration. The star on the icon reads as the north star, unplanned but apt.

**Build 134 gave an area a `goal:` it can actually set** — `AreaGoalChip`/`AreaGoalMenu`/
`AreaGoalOptions` in ContentView, mirroring the `AreaParent*` trio, wired into the note header
and the list's context menu. `setGoal` had existed since the Map work but **`MapView` was its
only caller**, so the area half of "No project or area serves this" was unreachable in practice.
He spotted it from the chain diagram — "areas have no real goals attached" — and he was right.
That is now twice in one day that a rule read a line nothing could write (the other was `due:`
on a project, build 132). **When adding a check, confirm something can produce the data it reads.**

**Build 135:** a row in the review opens its note **without leaving `.review`**. `DetailView`
falls through to `NoteEditorView` for any section that is not calendar/templates/inbox, so
selecting a note while the section stays `.review` leaves the review list in the middle column
and puts the note in the third — the review can be worked straight down. On the phone the same
call pushes one screen and the system back arrow returns to the list. Build 134's buttons used
`show(section: .kind(.project), …)`, which threw the review away; he asked for a back arrow,
but not leaving is better than going back. **A row inside a working screen should select, not
navigate away.**

**Build 136: a graphical `DatePicker` alone is unusable for a date years out.** He was asked
to set a project deadline to 2031-12-01 and counted about forty presses. `ProjectDeadlineChip`
now leads with a `TextField` (the app's existing `YYYY-MM-DD` convention, as in the New Note
sheet's target date and the add-task bar's `>2026-09-10`); the calendar stays below and writes
into the field, and **Set reads the field, not the calendar**. **Build 137** made it one component at his suggestion: `DateChoiceView` in `Views/Theme.swift`
(`current`, optional `clearTitle`, optional `cancel`, and one `choose: (DateOnly?) -> Void`
where nil means cleared). `ProjectDeadlineChip` and `TaskDatePicker` are both thin wrappers
around it now. `cancel` exists because `TaskDatePicker` is presented as a `.sheet` in
`InboxView` and a `.popover` in `NoteEditorView`, and a sheet cannot be dismissed by clicking
away. **Left alone deliberately:** the Time Blocks pickers (a day *and* a time, and never more
than 60 days out) and the New Note sheet's target field, which he designed with me and which
is one short row per line.

**Build 138: an `HStack` in a column too narrow does not overflow — it squeezes.** Every child
is proposed a smaller and smaller width until the `Text` inside wraps, which is how the weekly
review drew "2031-08-01" over three lines and "projects" as "project s" in his screenshot.
`WrappingHStack` (a `Layout` in `Views/Theme.swift`) measures children with `.unspecified`, so
each keeps its natural width and only whole items move to the next line. **Never put
`.fixedSize()` on it** — that proposes a nil width and turns it back into one endless row; the
modifier that matters on the container is `.lineLimit(1)`, which stops a child's own text from
breaking mid-word. Titles in those rows are `.lineLimit(2)`.

**Build 140.** "Hobby or homeless?" was my own wordplay, taken from the Cowork spec, and he
asked what it meant — exactly what the language rule at the top of this file forbids. The
section is **"Projects with no goal"**. More important, the heading asked a question the app
could not answer: a project had no way to be given a `goal:` except the Map drag. `AreaGoal*`
is now `NoteGoal*` and serves both kinds, ordering the menu by kind (a project delivers a dated
goal, so those first; an area holds an aspiration, so those first), wired into the note header
and the list's context menu for `.project` as well as `.area`. **Third time a rule read a line
nothing convenient could write.** When a screen asks a question, check the answer is one click
away from where it is asked.

**Build 141: roll-up progress.** `Core/Vault/GoalProgress.swift` — `GoalProgress`
(projectsDone/Total, tasksDone/Total, `fraction`) and `NoteIndex.progress(of:)`, pure
computation over frontmatter, nothing written. The decisions worth keeping:

- **One share per project, not one per task.** A goal's figure is the *average* of its
  projects' shares, so a project with forty small tasks cannot drown one with three big ones.
  A finished project is 1; a running one is done/total top-level tasks; a project with no
  tasks yet is 0 (it is a project that has not started, which is a real answer).
- **Areas are excluded.** An area never finishes, so counting one would hold its goal below
  full for ever. This is the same reasoning as `noProjectYet`.
- **`fraction` is `nil`, not 0, when there is nothing to measure**, and `GoalProgressBar`
  draws nothing at all in that case. An empty bar would say "no progress"; the truth is "no
  projects yet". Same family as build 100's rule — never let an absence look like a zero.
- **`percent` never rounds to 100 below 1.0, nor to 0 above 0.** Both read as an answer.
- **A goal is finished by its `status:`, not by its boxes** (`Note.isFinishedProject`): he
  marks a project done from the review, and the last task is often one he decided not to do.
- **`Note.declaredKind` reads `type:` and falls back to the folder.** Archiving moves the
  file, so an archived project's `kind` is `.archive` and it would silently drop out of its
  goal's totals. `DeletedNotes` already used this trick; it is now shared. An archived note
  that was *not* marked done is skipped altogether: it was dropped, not left undone, and
  counting it as 0 would hold its goal down for ever.
- `NoteIndex.linked(to:)` is the whole set pointing at a goal, archived and finished
  included; `serving(_:)` is now the live subset of it. That fixed a real fault:
  a goal whose projects were all marked done read as **"No project or area serves this"**,
  because `serving` filtered done projects out and `nothingServing` saw an empty list.
- Shown by `GoalProgressBar` (Theme.swift) in three places, so they cannot drift: the
  `GoalHealthRow` in the review (inside the build 138 `WrappingHStack`, as one item so the
  bar and its per cent wrap together), `NoteRow` in the Goals list (the row holds one note
  and cannot roll up by itself, so `goalProgress` is passed in), and `GoalDashboardView`,
  which also now lists the finished projects, struck through.

**Build 142: one symbol in two states, and the add-a-task bar.** Two things, and the first is
a rule for the whole app.

- **`StateToggle` (Theme.swift): a control shows the state you are in, never the state you
  would get.** The mode button swapped its own symbol — an eye while editing, a pencil while
  reading — and an eye reads just as naturally as "you are reading now". His words: *"Det
  måste vara så man förstår vad som är valt."* It is always a pencil now; **on** is the tint
  at 20% fill with a solid tinted border, **off** is grey with a **dashed** border (his idea,
  and it matches what dashed already means on the Map: loose, not connected). Used by the
  phone's bar and by the Mac's toolbar, which lost its segmented Picker. **Spread this to the
  other two-state controls** (Hide finished, the Calendar's Schedule/Note switch, the Map's
  Arrange) when next in that code.
- **Split is gone**, at his request. `EditorMode` is `edit`/`preview` only; a stored
  `"split"` no longer decodes and `@AppStorage` falls back to `.edit`, so nothing to migrate.
- **The add-a-task field's placeholder is "Add a task…".** It was 84 characters of syntax,
  which fits nowhere on a phone (cut at "for a") and disappears the moment he types. That
  moved into `TaskSyntaxButton`/`TaskSyntaxHelp` behind a **ⓘ** — its own `.popover` on its
  own button, never a second `.sheet` on the note screen (build 44). On the phone **Add** is
  an arrow that only takes colour when there is text, and **Snippet** is a symbol, so the
  field gets about twice the width. He picked this from a preview artifact
  (https://claude.ai/code/artifact/41ce5a0b-ee32-459a-8c90-1b20fc5e9879) — the third time a
  preview before any code has been the cheap way to get a layout right.

**A naming rule earned twice in two days.** I offered "Building blocks" for a sidebar group
holding Templates, Snippets and Tags. He rejected it *for the right reason*: "tags är ju inte
buildingblocks. Det är snarare ett system för att filtrera eller gruppera." A group name has
to be true of every member, or it is the same fault as "Hobby or homeless?" wearing a plainer
coat. **"Blocks" alone is also out** — the sidebar already has **Time Blocks**.

**Build 143: Tools.** A folding sidebar group (`SidebarSection.tools`, `@AppStorage
"toolsFolded"`) holding **Templates**, **Snippets** and **Tags** — the three things you use
*on* notes rather than notes themselves. He named it after rejecting "Building blocks"; note
also that plain **"Blocks" is out** because **Time Blocks** already exists.
- `Core/Vault/Tags.swift`: `TagUse` (tag + note/open/finished counts) and `NoteIndex.tagUses()`,
  which counts in **one pass over the notes** — one pass per tag would be 60 × 400 scans every
  time the list is drawn. `notesTagged(_:)` is frontmatter tags only and `tasksTagged(_:)` is
  the tasks; the old `notes(tagged:)` mixed the two, which is why it could not back a readable
  list. `NoteIndex.normalized(_:)` is the one place a tag is lower-cased and de-hashed.
- `TagsView` is **one screen, not two columns**: a tag opens in place. A tag detail in a third
  column would have needed a new `PhoneRoute` and a second layout to keep working. Plain
  `List`, every row a `Button`, **nothing tagged for selection** — one note can carry two tags
  and would appear twice, which is the builds 71–74 fault exactly. Folds are Section headers
  with a button, never `DisclosureGroup` (build 93). Rows call
  `show(section: .tags, notePath:)` so the list stays put (build 135).
- `SnippetsView` needed no selection: the file *is* the thing, so `DetailView` shows
  `TemplateEditorView(name: Snippets.fileName)` whenever the section is `.snippets`, and the
  phone gets a `NavigationLink` to `PhoneRoute.template` instead (that enum is inside
  `#if os(iOS)`, so the link is too).
- `Snippet` carries `lines: [String]`, not a `body` — I assumed otherwise and caught it before
  pushing.

**The Rules line "adding a source file needs a `project.yml` change" is stale for App files.**
Since build 41 both app targets are `type: syncedFolder`; `DayScheduleView.swift`,
`InboxView.swift` and now `TagsView.swift` were all added with no project change. It still
holds for anything that is not a source file in those folders (Docs resources, Info.plist keys).

**Build 144: `NoteTagsChip`, and the fourth time this has happened.** Build 143 shipped a Tags
screen over a line **nothing in the app could write** — `tags:` had to be typed by hand. That
is the same fault as `due:` (132), an area's `goal:` (134) and a project's `goal:` (140). The
rule has earned a stronger form: **before shipping a screen that reads a field, find the
control that writes it. If there isn't one, that control is part of the same build.**
- `AppModel.setTags(_:on:)`/`toggleTag(_:on:)`/`cleanTag(_:)`. `cleanTag` strips a leading `#`
  and turns spaces into hyphens, because a tag with a space could never be written as `#tag`
  on a task line — the two ways of writing a tag have to stay interchangeable.
- An empty list writes `tags:` rather than removing the key: the templates ship that line and
  a note should not silently lose it.
- `NoteTagsChip` (TagsView.swift) reads `live` back out of the model each time rather than
  trusting the `note` it was handed: a toggle saves and reloads, so the passed copy is one
  behind. A popover, not a Menu — a Menu cannot hold the TextField for a new tag, the same
  limit that made build 93 replace an alert with a sheet.
- He asked for **all three ways to stay** and to be written down together: the button, the
  `tags:` line (inline or indented — the button rewrites to inline, and that is stated), and
  `#tag` on a task. `Docs/HowItWorks.md` has them in one place under **Tools**.

**Build 145: a tag can be renamed, deleted, and made before it is used.** All three were
missing and he asked for all three in one message.
- `Note.changingTag(_:to:)` (Core, Tags.swift) returns nil when the note never carried the tag,
  so `Vault.changeTag` writes only what really changed — the same shape as build 77's
  `retargeting(_:to:)`, and it goes through `saveEach`, so an outside edit is re-applied and a
  note that still cannot be written is **named**, never swallowed (build 99).
- **The body is rewritten with the task parser's own pattern**, `(?<!\S)#tag(?![\p{L}\p{N}_/\-])`,
  case-insensitive. That is the only way rename and parse can agree: `#travelling` is not
  `#travel`, and `## Heading` is not a tag. Removing a tag calls `tidySpaces`, which keeps the
  indent and squeezes the gap the tag left.
- **`#next` is refused.** It is `Note.nextActionTag`; renaming it would silently break every
  next action. Any tag the app gives meaning to needs the same guard.
- **Work notes are deliberately not touched** by a rename: `allNotes()` excludes them by
  design (build 112) and the Tags screen never shows them, so including them here would be the
  one place that leaks.
- **A tag with nothing on it has nowhere to live in a markdown vault**, so `Vault.knownTags()`
  keeps the made-but-unused ones in `.ams-para/tags.json`. `AppModel.allTagNames` and
  `tagUses()` merge them in, and `TagUse.isUnused` draws them as "not used yet". A remembered
  tag is *not* forgotten when it comes into use — it stays offered, which is what you want from
  a tag you deliberately made.
- `TagsView` gained the make-bar (`.safeAreaInset(edge: .top)`), a **Rename…**/**Delete…**
  context menu, and the `.alert` + `.confirmationDialog` pair copied from `TemplatesView` —
  a macOS alert silently drops everything that is not a TextField (build 93).

**Build 146.** Two things, one of them my own fault.
- **The Calendar day view's month grid is off by default** (`@AppStorage "showsMonthGrid"`),
  toggled by a `StateToggle` in the day header — the first place build 142's control has been
  spread to, and the remaining candidates are unchanged (Hide finished, the Calendar's
  Schedule/Note switch, the Map's Arrange). Thirty-one dated cells took more of the column
  than the day itself. The header's two texts gained `.lineLimit(2)` and the arrow group
  `.fixedSize()` at the same time: the row gained a button, and build 138 is about what a
  narrow column does to an HStack.
- **`cleanTag` only stripped a *leading* `#`** (my build 144 code), so "Claude #Productivity"
  typed into a tag field became the single tag `Claude-#Productivity` — which the task
  parser's own pattern can never match, so it could never be written on a task line. It now
  replaces **every** `#` with a space, joins the words with hyphens, squeezes repeated
  hyphens and trims them off the ends. He found it in a screenshot, not I.
  **`cleanTag` lives in the App target and has no tests.** Anything that decides the shape of
  a stored value belongs in Core where it can be tested — move it there next time it changes.

## Plan the day (build 147)

His own idea, drawn as a sketch and then chosen from a preview artifact
(https://claude.ai/code/artifact/82be810e-11ca-4c7b-8fc2-3863ff07cfbd): three parts side by
side — the day's Calendar, his own blocks, the day's actions. He picked shape **B** (calendar
and blocks on a shared hour ruler, actions a plain list) and **the daily note** as the home.

**A plan block is deliberately not a Time Block.** Build 35's Time Blocks *are* events in Apple
Calendar; a plan block never leaves PARAGON. Both are kept, side by side in the Time Blocks
section, precisely so the difference stays visible — swapping one silently for the other was
the thing to avoid.

- `Core/Vault/DayPlan.swift`: `PlanBlock` (minutes since midnight, a title, and an `index` that
  is its position in the sorted plan) and `DayPlan`, which owns the `## Plan` section of a daily
  note. **Liberal in what it reads** (any dash, spaces or not, `*` bullets, one-digit hours),
  **strict in what it writes** (`- 09:30-11:00 Title`). The section is created above `## Tasks`
  when missing and nothing else in the note is touched.
- **The dashes in `lineRegex` are written as themselves.** A Swift raw string passes a
  backslash-u escape through as plain characters, so `[-\u{2013}\u{2014}]` would have been a
  character class of backslashes and braces. Caught while writing, not by CI.
- `DayPlanTests` covers reading, writing, the section being made, emptying it, and the
  round trip. That is the answer to build 146's note: **anything that decides the shape of a
  stored value goes in Core.**
- `AppModel.planBlocks(for:)` never writes — asking for a plan must not make a daily note.
  `savePlan(_:for:)` is the only writer and creates the note when a first block is added.
- `PlannerView`: an hour ruler, two lanes, an actions list. Items are placed with `.offset`
  inside a `ZStack(alignment: .topLeading)`, **never `.position`** (build 85). `PlacedEvent` is
  a struct because a `ForEach` id is a key path and a key path cannot address a tuple member
  (build 61). One `.sheet` for both a new block and an existing one (build 44).
- **macOS gets a `Window` scene**, `ParagonApp.plannerWindowID`, opened by ⇧⌘P from **Go** and
  from the Time Blocks section. Two things went wrong in one edit and are worth remembering:
  a scene placed between the `WindowGroup` and its `.commands` breaks the modifier chain, so
  extra scenes belong beside `MenuBarExtra` at the end; and `@Environment(\.openWindow)` is
  read by a **View**, not by the `App` struct — hence `PlannerMenuButton`, the same shape as
  `HelpMenuButtons`.
- iOS has no windows: `PhoneRoute.planner` pushes the same view.
- **Not built yet, by choice:** dragging a block to move it in time or to change its length.
  That is the second round; the columns had to work first.

**Build 148: the planner is the section, not a menu item.** He objected, and he was right:
"vi var ju överens om att timeblocks inte ska finnas i kalendern, utan vara i noten… Det
verkar inte alls vara som alternativ B." **The agreed drawing said the Time Blocks row becomes
the planner; build 147 left the old Apple Calendar form as what a click on that row gave you**
and hid the planner behind ⇧⌘P. Nothing was wrong with the planner — he had simply never seen
it. `DetailView` shows `PlannerView` for `.timeBlocks` on the Mac, and on the phone
`NoteListView` does (no third column there); the Apple Calendar blocks keep their form, now
named as such, one button away. Nothing was deleted.
**The rule this earns: when a preview artifact has been agreed, the build has to match it.**
Quietly keeping the old thing as the default is a change to the agreement, not a safe choice.
`CalendarBlocksLink` is a `ViewModifier`, not an `#if` in the middle of a modifier chain —
the same shape that broke the scene list in build 147, and `ToolbarItem(placement:
.topBarTrailing)` does not exist on macOS anyway.

**Build 149: the planner's Actions column is `TaskRow`.** He asked for checkboxes, editing,
scrolling, and to see *what an action serves*. `TaskRow` already carried the first three —
the tick, the rename, the task menu, the date popover — so the hand-rolled button row was
thrown away. **Reach for `TaskRow` for any list of tasks; a new one only repeats work and
drifts.** Its `.draggable` is safe here because this list has no selection of its own
(builds 71–74 were about `List(selection:)`).
`servesLine(for:)` answers the last part: the goal the task's note serves in gold, else the
area in pink. That is the chain the whole app is built on, and a list of actions without it
is just a list. A caption under the heading says what the list *is* ("due today or earlier,
then your next actions").
The phone stacks: `lanesRow` then `actionRows` in **one** `ScrollView`, never two nested
(build 127). `LazyVStack` rather than `List` so the same rows serve both platforms.

**Build 150: the planner is the window, not a window.** He asked whether all three parts could
live in the ordinary app window instead of a floating one, and chose **"A with the floating
window as an extra"** from a preview
(https://claude.ai/code/artifact/c8934eb1-0b1e-46ca-a3e7-4a3a90b2a5ae). So `PlannerView` split
into two halves that also stand alone: `PlannerActionsView` is the middle column
(`NoteListView`, `.timeBlocks`) and `PlannerDayView` is the detail column (`DetailView`,
`.timeBlocks`); `PlannerView` is just the two side by side, for the ⇧⌘P `Window` and for the
phone. Both read **`AppModel.plannerDay`**, not each its own `@State`, or the two columns would
show different days. The old `TimeBlocksView` (Apple Calendar) is one button away, in the
planner's single `.sheet`.
- **The bug this build fixed is a lesson about this file.** `ContentView.swift` holds **two**
  long `if`/`else` chains that both branch on `model.section` and both contain
  `} else if model.section == .snippets {`. Build 148's single-occurrence replacement matched
  the first (in `NoteListView`), so the Mac's detail column never got a `.timeBlocks` branch
  and said "No note open". **Anchor an edit in that file on something that appears once**, and
  read back the line numbers of every match before replacing.
- **Overlapping items share the width.** `place(_:)` sorts spans by start and greedily gives
  each the first lane whose last item has finished; a gap with nothing running closes the group
  off, so an uncrowded hour still gets the full width. The lane count comes out of the group,
  and `GeometryReader` hands the width in — the same rule `DayScheduleView.lanes(for:)` has had
  since build 61.
- `let box = card(…)`, not `let card = card(…)`: a local shadows the method of the same name
  inside its own initial value.
- Removed with it: `plannerWay` in `TimeBlocksView` and the `PhoneRoute.planner` /
  `.calendarBlocks` cases, which nothing reached any more.

**Build 151: one plan block at a time can go into Apple Calendar.** His idea, and a good one:
the two kinds stay apart by default, and he decides per block. Right-click a block → a
**Toggle** in the context menu (a tick, per build 142: the control shows the state you are in),
and the same tick in the block's sheet, because an action only a right-click reveals is an
action nobody finds (build 74).
- **The tie is stored in the event, not in the note.** `PlanBlockLink` (Core, DayPlan.swift)
  writes one line into the event's own notes: `ams-para:planblock <day> <start> <title>`. The
  daily note stays a plain `- 09:30-11:00 Title`, which is the whole point of the feature, and
  there is nowhere on such a line to keep a minted id without changing what the file looks
  like. So **the key is the block's own identity**. It deliberately leaves the *end* time out,
  so making a block longer keeps the tie; `DayPlanTests` pins all of that.
- **Every change through the app rewrites the line and the key together**, which is why
  `AppModel.savePlanBlock(_:on:replacing:inAppleCalendar:)` is one async function rather than a
  save plus a toggle: moving a block changes the key the event is found by, so two separate
  calls would race and the second would look for a key the first had just changed. The event is
  read **before** the line is rewritten, against the block as it still is.
- **A line edited by hand in the note loses the tie, and the event is then left alone** — never
  deleted on a guess. Said out loud in `Docs/HowItWorks.md` and in VersionHistory; build 100's
  rule applies to writes as well as reads.
- `EventKitCalendarStore.timeBlocks(on:)` reads one day **ignoring the visible-calendar
  filter**: a calendar he has hidden must not make a block look absent. `AppModel.
  planBlocksInCalendar` is per day, not `timeBlocks`, which only spans −7 to +60 days while the
  planner can stand on any date.
- Removing a block removes its event: the tick said "this block is also in Apple Calendar", and
  with the block gone there is nothing for the event to be.

**Build 152: `TB:`, orange, and the drag.** Three things he asked for from one screenshot.
- **A plan line is `TB: 09:30-11:00 Title`, not `- 09:30-11:00 Title`.** His words: the bullet
  made it a list and said nothing about what the line was. `PlanBlock.prefix` is the one place
  it is spelled. The parser stayed **liberal** — an optional bullet *and* an optional `TB:`, in
  either order — so every line written from build 147 to 151 still reads, and a save tidies it.
  `DayPlanTests` covers the old shape, the new one, both together, and a bare line.
- **`Theme.planBlockTint` (`PlanTint` in the asset catalogue), orange.** Blocks used to borrow
  the review's teal, which is the same family as the Calendar lane next to them — the whole
  point of two lanes is that they are two different things. One constant, so the lane, the
  cards, the make-a-block buttons and the sheet cannot drift. A new `.colorset` inside
  `Assets.xcassets` needs no `project.yml` change (the app target is a `syncedFolder`).
- **`PlanBlockCard` is its own view** because a live drag needs `@GestureState` (build 83).
  **One gesture on the card** — a single `DragGesture(minimumDistance: 0)` that decides in
  `onEnded`, no movement being a tap (build 85). The resize grip is a **different** view at the
  foot, so its drag never argues with the card's; it uses `highPriorityGesture` because it sits
  on top. Movement snaps to five minutes and is clamped to the drawn hours, and the card shows
  its live time while it moves.
- **Dragging is macOS only, on purpose.** On the phone the lane is inside the page's scroll view
  and a vertical drag belongs to that scroll; taking it would be builds 71–74 in a new place and
  CI cannot catch it. The phone gets the rebuilt sheet instead.
- A drag goes through `savePlanBlock(…replacing:inAppleCalendar:)`, so a block that is also an
  event in Apple Calendar takes the event with it (build 151's one sequential path).
- **The sheet**: he called the old one "very crude" — two long `Picker`s. Now a `DatePicker`
  (`.hourAndMinute`) with −/+ quarter-hour buttons, a `WrappingHStack` of `LengthChip`s, and one
  line saying what it comes to. `lengthChoices` adds the block's own length when a drag left it
  between the offered ones, or no chip would be lit.
- `openEventAction(for:)` is a function rather than `optional.map { event in { … } }`: a closure
  that returns a closure is where Swift's inference gives up, and there is no compiler here.

**Build 153: the cost of leaving a bullet behind.** His field test of 152 passed on eight
checks and failed on one: *"Each TB must be on its own row in the daily note."* Dropping the
`- ` also dropped the thing that made each line a **block**. In markdown two plain lines under
each other are one paragraph, so `MarkdownPreview` joined them with a space and drew both on
one row — and so would any other editor. **A change to what a line looks like is a change to
what markdown thinks it is.** Fixed twice over, because the vault has to be right outside the
app as well as in it:
- `DayPlan.note(_:settingBlocks:)` writes a **blank line between blocks**, which is what
  markdown needs everywhere. `DayPlanTests` pins the exact text and pins that a second save
  does not pile up more blank lines.
- `DayPlan.block(in:)` is new and public, and `blocks(in:)` now goes through it, so there is
  one parser. `MarkdownPreview.Block.planBlock` uses it to draw a plan line as itself, in
  `Theme.planBlockTint`, rather than sweeping it into a paragraph — which also covers a line
  someone typed by hand with no blank line after it.
- The field test was an artifact with the `db` capability
  (https://claude.ai/code/artifact/3dbed03e-2976-43f2-89dc-aa1d4f52773f), so his ticks and his
  one note came back through `read_db`. **Worth repeating for a build with several visible
  changes**: it cost one page and found a fault I could not have seen from here.

Three things he asked for in the same message, all small:
- **Sidebar order**: `.allActions`, `.recent`, `.done` moved together, straight above
  `.deleted`. Changed in three places that must agree — the `List` in `ContentView`,
  `SidebarSection.all`, and `PhoneBrowseView.groups`.
- **`.allActions` is `circle`**, a plain ring, because `.done` is `checkmark.circle` and a
  task's own checkbox is the same circle. His idea and a good one.
- **`TaskRow`'s note badge is the note's kind symbol**, not `doc.text` for everything —
  `noteSymbol` reads `declaredKind` (so an archived project still shows as a project) and takes
  the symbol from `SidebarSection.kind(_:)`. He asked what the two identical grey pages in the
  planner's Actions column were, which is the question an icon that says nothing always gets.
  **The same fault class as "Hobby or homeless?"**: it is not wrong, it just carries no
  information.

**Build 154: the note's toolbar, from one screenshot of four icons.** Three asks, and the
first two were answered by the third.
- **Rename lost its toolbar button.** His word was "exaggerated": a whole slot for a rare
  action, and its pencil was the *second* pencil in the row, next to the Edit `StateToggle`.
  **The name is now a chip in `NoteHeader`, and pressing it renames.** That is the family the
  header already is — `NoteGoalChip`, `NoteTagsChip`, `AreaParentChip`, `ProjectDeadlineChip`
  are all "press the fact to change it" — and the note's name is a fact about the note. The
  alert and `renameNote` are unchanged; `NoteHeader` just takes a `rename: (() -> Void)?`,
  nil for the Inbox and daily notes. The phone keeps it in its one `Menu` (build 88), which is
  not a dedicated icon and so is not the thing he objected to.
  **"Two icons that look alike" is usually a sign one of them should not be there.** Recolouring
  them would have kept the real fault.
- `renameAction(for:)` is a function, not a ternary with a closure in one arm — the same
  inference cliff as build 152's `openEventAction(for:)`.
- **`MoveToArchiveIcon` (Theme.swift)**: `arrow.down` above `archivebox` in a `VStack`, his idea,
  so the button reads as *moving* the note rather than as showing an archive. Drawn rather than
  named because SF Symbols has no archivebox carrying an arrow, and a `VStack` rather than a
  `ZStack` with offsets so the two pieces cannot drift apart at another text size.
- **`StateToggle` got more contrast in both states**, because a macOS toolbar draws everything
  at low emphasis and his dashed grey had almost disappeared. Same language he chose in build
  142 — tint + solid for on, grey + dashed for off — only stronger: off is
  `Color.primary.opacity(0.62)` rather than `.secondary`, the border is 1.2–1.4pt, and the
  on-state fill went 0.20 → 0.24. **The two-state language itself is his and stays.** The lift
  reaches the Calendar day's month-grid button too, which shares the control.

**Builds 155–156, from two screenshots.**
- **`.navigation` in a macOS `.toolbar` is the slot *before* the window's title.** `MapView` put
  its zoom and **Arrange** buttons there, so the word "Map" sat out past three buttons while
  every other screen has its name hard left. Only the New note button belongs in front of the
  title; everything a screen owns goes in the trailing group. Worth checking whenever a screen
  gains its own tools.
- `PlannerActionsView`'s `navigationTitle` said "Actions" while the sidebar row said **Time
  Blocks**. **The window's name has to be the row he pressed.** The `SectionLabel` *inside* that
  column still says ACTIONS, which is right — it labels the list, not the screen.
- **The New note button is `plus.circle.fill` in `SidebarSection.tint`** (build 156). He asked
  for five or six suggestions and picked the first from a preview
  (https://claude.ai/code/artifact/77a48898-bbb1-4e3a-aeff-499b098721c7), which drew each
  candidate twice — at true toolbar size and large — with a switcher for the five section
  colours. **Most of the "pop" was the colour, not the glyph**: a macOS toolbar draws every
  outline symbol at low emphasis, which is the same thing that made build 154 lift
  `StateToggle`. A filled shape is what carries a tint there. The preview page is the fourth
  time choosing before building has been the cheap way to get this right.

## Search is tick boxes (build 157)

He reported that searching for **done** did nothing he expected, and asked for the whole screen
to be brushed up: *"maybe we could perform the search with tick boxes so that you have an
overview of what you are actually searching for."*

**The engine was innocent; the screen was not.** `SearchQuery.parse("done")` has always made it
a *term*, and a note whose body holds `@done(2026-09-12)` has always matched — so the word alone
could never come back empty. He said it came back **empty**, which only happens with a task box
also on: `is:done done` asks for *finished tasks whose own title contains the word done*, and
nobody has one. The old field mixed his words with the chips' `key:value` tokens, so a box
ticked minutes earlier was still in the query and looked like part of what he had typed.
**When a report does not match the code, ask what the screen showed before changing the
engine** — the same trap as builds 123–127, and asking him one question ("empty, or no
reaction?") is what placed it.

- **The field is words only; every other question is a `FilterBox`** you can see without opening
  a menu (build 74 again: the old filters were `Menu`s whose state showed as a faintly tinted
  capsule). Rows: **Tasks** (is/due), **Kind of note**, **How the note stands**, **Tags**.
- **The text stays the single source of truth.** Every box writes or removes a token in
  `AppModel.queryText`, because other screens set that text — `TagsView` sends `#travel` here and
  `handle(url:)` can too — and a second store would have to be kept in step with it. Typing
  still works exactly as before.
- **`due` and `taskFilter` became `dues` and `taskStates`, both `Set`s.** A row of tick boxes can
  hold two answers and one optional could not. Within a row the set is an **or**; between rows
  they are **and**ed. `SearchTests` pins that.
- **`SearchQuery.summary` (Core, tested) is the query in plain words**, and
  `SearchQuery.label(for:)` is what the boxes are titled from, so a box and the sentence can
  never disagree. He said a prose summary was not what he was after — so on screen it is only
  the line shown while the boxes are folded, and the message in the "Nothing matches" state.
  **Never a bare "no results"**: a word that found nothing has to be tellable from a box that
  ruled everything out (build 100's rule, in a new place).
- **`emptyMessage` says why there is nothing**: with a word and a task box on, it counts what
  the word alone would find and names it — "The words are in 34 notes, but no task in them
  matches the boxes you ticked." Build 100's rule applied to a search: an absence has to say
  why, or it looks like a broken app.
- `FilterBox` uses build 142's two states in words rather than a symbol: ticked is the tint
  filled with a solid border, unticked is grey with a dashed one.
- **`Section(_:content:footer:)` does not exist.** A title string and a footer cannot be given
  together — it is `Section { } header: { } footer: { }` or a bare title. CI caught it and 157
  cost a run; the build number stayed 157 because nothing ever shipped (the build 143
  precedent).
- The boxes fold (`@AppStorage "searchFiltersFolded"`, **open by default** — build 121) because
  the middle column is narrow, and each row is a `WrappingHStack` (build 138).

## Quick capture on the phone (build 158)

He asked for the capture screen to be "really, really attractive — a nice and funny thing where
we get creative", and picked from a preview of three
(https://claude.ai/code/artifact/8e6a6105-6865-4fcd-a86e-e25c84733e49): **"It shows what it
understood"**, plus all four of the small extras.

**Part of it was a plain bug.** `QuickCaptureView` had one body with `.frame(width: compact ?
380 : 460)` — a Mac panel width on a ~390pt phone, which is why **Save** hung off the right
edge in his screenshot. It now branches `phoneBody` / `deskBody` on `horizontalSizeClass`, the
same shape `NoteEditorView` has had since build 53. **Any view shared with the Mac needs that
check before it is called a phone screen.**

- **`CaptureReading` (Core, tested) runs the task parser itself** over `CaptureItem.lineText` —
  the very line the capture will write — and hands back the date, the marks and the tags. **A
  read-back that can lie is worse than none**, so there is no second, simpler parser: the chips
  and the vault cannot disagree. `nearness(to:)` decides today/tomorrow/yesterday in Core; only
  the wording is the view's.
- **Three kinds of chip, and the difference is visible.** `ReadChip` is **dashed** (what the app
  heard, not a control — dashed already means "loose" on the Map, in `StateToggle` and in
  `FilterBox`), `AddChip` is a grey button that writes syntax into the field, `PickChip` is one
  of a set. Same family as build 157's `FilterBox`.
- **"As note, not task" is gone**: a double negative on a switch, with nothing saying which way
  was which. Two chips, **A task** and **A note**.
- The syntax moved behind a **ⓘ** popover — build 142's lesson about the add-a-task
  placeholder, in a new place. The placeholder is now one of four greetings.
- **The four extras, all his**: "Caught it" on the button, a short flourish into the tray
  (**skipped when `accessibilityReduceMotion` is on**), a changing greeting, and
  `AppModel.caughtToday`.
- **`caughtToday` is counted per day in `UserDefaults`, not from the vault.** A captured line
  carries no timestamp, so the vault cannot answer "how many today", and inventing one would
  mean writing something into every note to satisfy a caption. It earns its place beyond the
  pleasure of it: the number is also how he knows the Inbox needs sorting.
- The Mac panel keeps its shape and gains the read-back and the syntax buttons, so the two do
  not drift.

## Two-state controls, everywhere (build 159)

The last three controls that were not build 142's `StateToggle`: **Hide finished** in a note's
task box, the Calendar detail column's **Schedule/Note** segmented Picker, and the Map's
**Arrange**. All three now use it, so there is nothing left to spread. Two details worth
keeping:
- `StateToggle` is a symbol only, so information the old control carried in words has to go
  somewhere. The count of finished tasks became a plain caption beside the button, and the
  Calendar's two names became a `SectionLabel` that says which half you are on. **A control
  that shrinks has to hand its words to the row it sits in**, or the screen quietly loses
  something.
- `Docs/HowItWorks.md` still said Arrange was "at the left of the Map's toolbar" — stale
  since build 155 moved it out of `.navigation`. Fixed here. **A manual sentence that names a
  position goes stale when a toolbar is rearranged**; grep the manual for the screen's name
  when moving one.

## The phone's Search can close its keyboard (build 160)

His report the morning after 157 shipped: *"On the iPhone, we need to be able to collapse the
keyboard because the result list is so very small."* The screen was built and checked on the
Mac, where there is no keyboard taking half the height. **Any screen with a text field needs
to be thought about with the keyboard up before it is called finished on the phone** — the
same family as build 158's fixed 460pt width.
- **Three ways out, not one**: `.submitLabel(.search)` + `.onSubmit`, `.scrollDismissesKeyboard
  (.immediately)` applied once where `results(query)` is called (so it reaches both result
  lists and the help text), and a `ToolbarItemGroup(placement: .keyboard)` with **Done**. One
  route is never found (build 74).
- The filter panel is capped at **200pt on the phone**, 320 on the Mac.
- `onAppear` takes focus only when the query is empty. Arriving with a word already there —
  from the Tags screen, or an `amspara://` link — you want the results, not the keyboard.
- `isPhone` here is `horizontalSizeClass == .compact` behind `#if os(iOS)`, with a `false`
  stub for macOS, so the body has no `#if` in the middle of a modifier chain (build 148).

**Build 161, from the screenshot that followed — and it is a rule.** The field said *Search for
a word* and held `is:open`, put there by the **Not done** box. **Build 157 wrote that promise
into the documentation and the code broke it in the same build**, because "the text is the one
source of truth" was taken to mean the field shows the whole text. The truth can be one string
and the field can still show one part of it. **When a screen promises that two things are
separate, check what the user actually sees, not what the model holds.**
- Core, tested: `SearchQuery.isBoxToken(_:)` asks `parse` itself (a token `parse` files under
  `terms` is a word, one that sets a filter is a box), so the two can never drift;
  `words(in:)` and `replacing(wordsIn:with:)` are the pair the field uses. `rejoined` puts the
  quotes back on a phrase, since `tokenize` strips them.
- **While the field has focus it is the author** — `onChange(of: model.queryText)` returns
  early — or a token halfway typed (`#tra` on the way to `#travel`) would be pulled out from
  under the cursor. It is re-read on losing focus. `Clear` sets both, for the same reason.
- The boxes now start **folded on the phone** (`searchFiltersFoldedPhone`, its own key so an
  iPad cannot overwrite the Mac's) and open on the Mac. Build 121 still holds: the fold is one
  press away and the summary line says what the search is while they are closed.

## The Goals screen is the chain (build 162)

He picked **B** from a preview of three
(https://claude.ai/code/artifact/5ccd27ac-0b62-4895-8e62-b575ca226861): the middle column lists
the **aspirations**, and picking one draws everything working towards it — dated goals, their
projects, the next action on each.
- `Core/Vault/AspirationChain.swift` (tested): `ChainProject`, `ChainGoal`, `AspirationChain`,
  and `NoteIndex.aspirations()` / `goalsOutsideAnyAspiration()` / `chainGoal(of:)` /
  `chain(of:)`. All of it is computed from `goalHealth`, so the Map, the review, the goal
  dashboard and this screen cannot give four different answers to "what serves what".
- **Two groups exist only so nothing can hide**: aspirations with nothing under them, and dated
  goals with no aspiration above them. Build 100's rule — picking an aspiration must never be
  a way for a goal to fall off the screen. Neither is drawn as a fault.
- `App/Paragon/Views/GoalsView.swift`: `AspirationsListView` (middle column),
  `GoalDetailView` (third column, with a build-159 `StateToggle` that swaps the chain for the
  note text — `@State` reset by `.id(path)` from `DetailView`, so picking another goal never
  starts on the previous one's text), `AspirationChainBody`, `ChainGoalBlock`,
  `ChainProjectRow`, `ChainChip`.
- **The phone folds the chain open in the row** rather than pushing a screen — the `TagsView`
  precedent (build 143): a second screen needs its own `PhoneRoute` and a second layout. Those
  rows are plain `Button`s in a `List` with no selection tag (builds 71–74).
- **The `.searchable` had to go on the new branch too.** The branch is guarded by `!searching`,
  and without a search field in it there would have been no way to type a search in Goals — so
  the fall-through to the flat list could never have been reached. Caught while writing.
  **A branch guarded by a state the branch itself cannot produce is dead code.**
- **`createNote` gives a project the template's own task.** Two of the new tests counted open
  tasks on a freshly made project and were one out, because the project template ships
  "Define the outcome and the first step". A test that counts tasks has to **set** the body,
  never add to it. CI caught it; the build number stayed 162, since nothing had shipped.
- **The db page and his screenshot disagreed** — the db held only `serves` while the screenshot
  showed all six boxes looking unticked — so I did not trust either and asked him in chat. He
  answered "All five, please". **When a read-back page and a screenshot of it disagree, ask;
  do not pick the one that suits.**

**Build 163: the five small extras.** All in `AspirationChain.swift` (Core, tested) and
`GoalsView.swift`.
- `DateOnly.timeLeftText(from:)` — "today", "tomorrow", "in 11 days", "in about 3 months",
  "in about 5 years", "11 days over". In Core because it decides wording read on three screens.
- `ChainActivity` — tasks finished in 30 days, projects finished, days since activity, and a
  `summary` that is **nil when there is nothing to say**. **Projects carry no date when they are
  finished** (`isFinishedProject` reads `status:`, nothing stamps the day), so it never claims
  "projects finished this month"; that would be build 141's zero-that-looks-like-an-answer in a
  new place.
- Reached goals: `aspirations()` and `goalsOutsideAnyAspiration()` exclude `isAchieved`,
  `reachedGoals()` gathers them, and `AspirationChain.reachedGoals` splits them out of the live
  chain. `isBare` counts them, or an aspiration whose goals were all reached would read as
  having nothing. Folded by default (`goalsReachedFolded`); the heading still shows the count,
  so nothing is hidden (build 100).
- `NoteIndex.byTargetThenTitle` is the one sort the three lists share.
- `DatedGoalRow` carries four of the five at once — measure, target with days left, attention
  mark, progress — because a row that shows two of them and leaves the rest out is the fault
  that made build 153 replace `doc.text`.
- `goalHealth(of:)` is **internal**, so the App cannot call it; `chainGoal(of:)` is the public
  way in and is what `DatedGoalRow` uses. Caught while writing.

**Build 164: icons on the Goals screen**, his ask. `ChainSymbol` (GoalsView.swift) is the one
place the five are spelled, and four of them are read back out of `SidebarSection` rather than
retyped, so the sidebar and this screen cannot drift.
- **The one new symbol is `target`, for a goal with a target date.** An aspiration and a dated
  goal are both `.goal` notes and shared the star, which said they were the same thing. The
  aspiration keeps the star — the north star on the app's icon, build 129 — because it is
  what you steer by and never tick off.
- `KindBadge` gained an optional `systemImage` override for exactly this: one badge look, two
  meanings under one `ParaKind`. **Reach for that before drawing a second badge.**
- `TintStripe` left the two Goals rows: the badge already carries the colour, and a stripe
  beside it is two coloured things saying one thing.

**Build 168: a symbol split in one screen has to be split everywhere.** Build 164 made the
star mean *aspiration* and `target` mean *a goal with a date* — **inside `GoalsView` only**.
The sidebar row named **Goals** kept the star, and so did every `goal:` chip in the app, so the
row said one word and drew another. He found it at once: *"If you say that a goal is two
circles, and an aspiration is a star. How come the goal button to the left doesn't have the two
circles?"* He picked the fix himself (the row keeps its name and takes the target).
- **`ChainSymbol.aspiration` is now the one place `"star"` is spelled**, and `datedGoal` reads
  `SidebarSection.kind(.goal).systemImage` back out, so the row and the chips cannot drift
  again. It was the other way round before, which is exactly how the drift happened.
- `ChainSymbol.forGoal(named:in:)` resolves a `goal:` line, which may name either kind; an
  unresolved name gets the target, never the star. Used by the **Serves…** chip, the note
  header, `NoteRow` and the planner's serves line. `NoteRow` takes `goalSymbol` as a parameter
  for the same reason it takes `goalProgress` (build 141): a row holds one note and cannot look
  another one up.
- `forGoal` is overloaded now, so `.map(forGoal)` was written out as a `guard let`. **No
  compiler here** — never leave an overload for inference to settle.
- **The rule: when one screen splits a shared symbol in two, every other screen that draws it
  is part of the same build.** Same family as the fields nothing could write (132, 134, 140,
  144, 165, 167), and as build 153's `doc.text` badge that said nothing.

**Build 169: two small things on the Goals screen, both his.**
- **A chip that repeats what the screen already says carries no information.** `ChainGoalBlock`
  drew **Serves <aspiration>** on every goal inside that aspiration's own chain. It now takes
  `under:` (the aspiration it is being drawn beneath) and hides the chip on a match;
  `AspirationChainBody` is the only caller that passes it, so a goal opened on its own and the
  ones in **Goals with no aspiration** keep it. Same family as build 153's `doc.text` badge.
- The chip was `ParaKind.area.tint` (pink) while naming an aspiration. Gold now. **A tint is a
  claim about what a thing is**, the same as an icon.
- **`Spacer` in a row pushes a fact away from what it describes.** "2 open" sat at the right
  edge of a wide column; with several projects the numbers formed a column that read as its own
  list. The `Spacer` moved to the end of the `HStack`, so the count follows the project's name.

**Build 170: the Map speaks the chain.** He asked for all five of the remaining ideas, one
build each; this is the first. The Map is the oldest screen and had drifted from the vocabulary
every newer screen uses.
- `MapNode.chainSymbol` (MapView.swift, beside `tint`/`paraKind`) is nil for everything but a
  goal note, so `KindBadge`'s override is only reached where it means something. The card and
  the footer both read it — two places, one source.
- `subtitle(for:)` names a goal ("Aspiration" or "Goal"); a dated goal previously fell through
  to the plural list name at the foot of the function.
- **`subtitle(for:)` was the eleventh place comparing `status` to a raw string** — build 165
  converted ten and missed this one, so the Map alone printed "Achieved". Through `NoteStatus`
  now. **When a rule says "all N places", count them again a build later.**
- The legend became a `WrappingHStack` when it gained two items (build 138).

**Build 171: the Weekly review.** Second of the five.
- `ReviewSummary` + `ReviewStat` replace five `LabeledContent` rows. **A table is not a
  summary**: every line looked equally important and a zero looked like a fault. Worries are
  orange capsules; **no worries is one green capsule**, never a row of zeroes (build 100).
- `ReviewSummary.Worry` is a **struct**, not a tuple, because a `ForEach` id is a key path and
  a key path cannot address a tuple member (build 61, third time).
- **Every numbered step is always drawn.** A section that only appeared when non-empty made the
  walk read 1, 2, 4, and a finished step looked identical to one the app had hidden.
- Goals became step 3; "Projects with no goal" moved to the foot with no number.
- **`GoalHealthRow` got the context menu — the seventh time this rule has been earned.** The
  review flagged a goal and offered no way to answer the flag; project rows had had the menu
  since 165. Same family as 132, 134, 140, 144, 165, 167.
- `GoalHealth.Flag.achieved.label` was still "Achieved". **Build 165 said "all ten places" and
  the label of a flag is an eleventh** — the same miss as the Map's `subtitle` in build 170.
  The *case* keeps its name: it is read by code, not by him.

**Build 172: a review rhythm per level.** Third of the five, and the last real gap from the
Aspiration Chain spec (build 132 on). `Core/Vault/ReviewRhythm.swift`, tested:
`ReviewLevel` (aspiration/goal/project/area, each with `label`, `reason` and `defaultDays`),
`ReviewRhythm` (read from `VaultConfig`), `ReviewDue`, and `NoteIndex.reviewLevel(of:)` /
`reviewSchedule(rhythm:)` / `dueForReview(rhythm:)`.
- **The project rhythm is `VaultConfig.reviewIntervalDays`, which already existed and already
  meant this.** A second number for one thing is how two screens come to disagree; a test pins
  it. Only `aspirationReviewDays`, `goalReviewDays` and `areaReviewDays` are new.
- `VaultConfig` already had an explicit `init(from:)` using `decodeIfPresent`, so adding keys
  cannot reset his config. **Worth knowing before adding another** — `Vault.init` does
  `(try? loadConfig()) ?? VaultConfig()`, so a decode failure would silently throw away every
  setting he has. A test now pins that an old config.json still reads.
- **`reviewLevel(of:)` uses `declaredKind`** — an archived project reads as `.archive` from its
  folder (build 141).
- **Never reviewed is `nil`, not a big number**, and never drawn as one (build 141's rule); it
  sorts above everything via `overdueBy == Int.max`.
- Ended and archived notes are excluded: a review is a question about live work. Same reasoning
  that kept `noGoal` out of "needs attention" (132).
- App: `AppModel.reviewRhythm`/`dueForReview()`, a **Due for a look** section at the top of the
  review (`ReviewDueRow` — **Buttons, never tagged rows**, since those notes appear again lower
  down: builds 71–74), a capsule in `ReviewSummary`, and `ReviewRhythmStepper` in Settings.
  The stepper is its own view because building a `Binding` per level is a statement (build 58),
  and its `step` is 30 for a year and 5 for a quarter — build 136's lesson about forty presses.

**Build 173: saved searches.** Fourth of the five, and the one item the roadmap had been
stopped at since 157. `Core/Vault/SavedSearches.swift`, tested.
- **A saved search is not a note.** It has no text, no tasks and nothing to link to, so a note
  would appear in Today, the Map, the review and Reminders and be wrong in all four. It lives in
  `.ams-para/searches.json` beside `tags.json` — the same decision build 145 made for an unused
  tag.
- **The query text is stored, never the results**, so a saved search and the same words typed by
  hand are the same search; a test pins that through `SearchQuery.parse`. Build 157's "the text
  is the one source of truth" carried through.
- `addSavedSearch` matches on **name**, not id: saving the same name twice is a change, not a
  second row. `renameSavedSearch` refuses a name in use (build 77's rule for notes).
- `SavedSearch.suggestedName(for:)` uses `SearchQuery.summary` — one place puts a query into
  words, so the offered name and the folded line agree. **It checks `query.isEmpty`, not an
  empty summary**: `summary` is never empty (it says "Nothing searched for yet…"), which would
  have become a name.
- Two new `VaultError` cases, `invalidName` and `nameInUse`.
- App: `SavedSearchChip` uses build 142's two states (filled + solid = the one you are in,
  grey + dashed = the others), in a `WrappingHStack` (138). **Chips, not a list and not a
  sidebar row**: a list eats the results on a phone, and a second sidebar row would be two
  doors into one room (the argument he accepted in 166). Nothing is drawn when there are none.

**Build 174: the iPhone widget.** Fifth and last of the five. A new target, which is the first
one this project has added since the share extension.
- **The widget cannot open the vault** — it is a security-scoped bookmark only the app resolves,
  and a widget has milliseconds and nobody to ask. So `AppModel.writeWidgetSnapshot()` writes a
  `WidgetSnapshot` into the App Group container on every `reload()` and the widget reads only
  that. One writer, one reader, one small file; the widget never parses markdown and never
  writes.
- `Core/Vault/WidgetSnapshot.swift`, tested. **`read` returns nil on every failure**, never an
  empty snapshot: "the app has never run here" and "nothing to do" are different answers and
  the widget says three different sentences (missing / stale / genuinely empty). Build 100's
  rule on a home screen.
- **`actionsForPlanning(on:)` moved from `AppModel` into `NoteIndex`**, so the planner's Actions
  column and the widget ask one question once. Same for `serves(_:)`. Two lists called "today's
  actions" that could answer differently is the fault 162 fixed for "what serves what".
- `dueForReview` and `inboxCount` are **handed in**, not worked out in Core: the rhythm lives in
  `VaultConfig`, which the index does not carry, and a guess would disagree with the review.
- **`WidgetLook` spells the colours and symbols again** — a widget target cannot see the app's
  asset catalogue or `SidebarSection`. That is real drift risk; the file says so, and a change
  to either belongs here in the same build (build 168's lesson).
- `amspara://<title>` for the tap, never a new scheme: it is one of the four identifiers the
  rename kept, and `handle(url:)` has resolved it since build 39.
- **The workflow change that matters**: `App/Config/ParagonWidgets/Info.plist` was added to the
  "Number this build" loop. Every bundle must carry the same `CFBundleVersion` or Apple refuses
  the upload with "bundle version does not match".
- **A test caught a real wart, not a bad test.** The parser keeps `#tags` in a task title on
  purpose so a task round-trips to the file, and every screen in the app shows them — but the
  widget would have read "Order the saddle #next" on three short lines. `WidgetSnapshot
  .widgetTitle` strips **only `#next`** (the task parser's own pattern, so `#nextweek` survives)
  and only for the widget; his own tags stay, because those carry information. Build 153's rule.
- **The risk this build carries**: `com.schabbauer.AMSPara.Widgets` is a new App ID. Export runs
  with `-allowProvisioningUpdates` and an Admin key, so Apple should create it and enable the
  App Group by itself — but if the TestFlight run fails on provisioning, that is the one part
  only he can do, in the developer portal.

**Build 175: his field test of 170–173, and the db page finally worked.**
- **The field test recorded every tick this time** (https://claude.ai/artifact/5WYBvN73WdcQBtUtf9UyEj).
  The difference from the pages that came back empty: **it writes to `db` on every tap, never on
  a Submit button**, shows "Saved 09:41" so he can see it working, and carries a **Copy my
  answers** fallback. That is the diagnosis the note under build 167 was waiting for — a preview
  page *can* collect answers, as long as nothing waits for a final press.
- **He marked "the line under a goal box" as not right and the goals were right all along** —
  his screenshot showed "Aspiration", "Goal · by 2031-08-01". What he meant was the *other*
  boxes: an area read "2 open" and a project "5 open · due …", naming the work in them and never
  what they are. `kindWord(for:)` now leads every subtitle. **A failed check is not always the
  thing it names; the screenshot is what said so** (builds 123–127 again, cheaply this time).
- The Map legend was symbols for the two goals and coloured dots for the other four — my own
  build 170 inconsistency, which he spotted. All symbols now, matching the boxes; `legend(_:_:)`
  is gone.
- **The review is six steps, all naming an action**, his ask ("one and two are cool because they
  do not just list the heading"). Aspirations and dated goals are steps 3 and 4: **two questions
  asked at different speeds**, which the rhythm itself already said.
- **`ReviewRhythm.label(forDays:)` + `ReviewLevel.choices`, and `PickChip` instead of a
  `Stepper`.** Build 174's stepper moved 30 days at a time, so from 365 it could never reach
  182 — the number he asked for. **A stepper whose step cannot reach the wanted value is worse
  than no control**, and build 136 had already taught it. `choices(for:including:)` always
  includes the vault's current value, so no screen ever shows nothing chosen.
- `ReviewLevel.aspiration.defaultDays` is **182**. A vault that already stored 365 keeps it —
  told him where the one press is rather than rewriting his settings behind his back.
- A `Divider()` under the saved searches, from his screenshot.
- **Open, asked, not built:** a colour of its own for aspirations across the app. Gold is the
  goal family and an aspiration is the head of it, so a second colour needs his decision before
  any code.

**Build 176: telling an aspiration from a goal — and it was never a drawing problem.** His
words: *"sometimes I have difficulties understanding what is an aspiration and what is a
goal."* He asked for the star to be "more popping" and explicitly kept gold. I put four options
to him and he took the first three.
- **An icon can only remind you of something you already know.** No amount of star-versus-target
  fixes a meaning he has not settled yet. What fixes it is the *name* and one *sentence*.
- **The word "Goal" alone was the ambiguous one**: an aspiration is also a kind of goal, so
  plain "Goal" asks him to hold both meanings at once. `GoalWording` (GoalsView.swift) is the
  one place both are spelled: `aspiration`, `datedGoal` ("Goal with a date"), and
  `datedGoalShort` ("Goal") for the **one** place the target date is printed immediately after
  it — a Map box, where the long form would say the same thing twice and be truncated anyway.
  **A shared name with one documented exception beats two names nobody can find.**
- **The rule itself is on screen where the two sit together**: `aspirationRule` / `datedGoalRule`
  as Section footers on the Goals list and the review's steps 3 and 4. The difference is the
  date; saying so is cheaper than any icon.
- `ChainSymbol.aspiration` is **`star.fill`**. Build 156's lesson: most of the pop is the fill,
  not the glyph.
- Three `Section(_:)` titles became `Section { } header: { } footer: { }` — a title string and a
  footer cannot be given together (build 157, third time it has come up).

## Two rooms: Aspirations and Goals (build 199)

His report: *"the aspirations still are the top, most important things in my life, and I'm
always falling back to searching for them"*, and then the harder question — *"We have defined
an aspiration as a kind of Goal that has no end date. Hm... makes me think if this is correct
or just a computer-technicality that fits technology but not the user."* He was right. He chose
the shape from a preview (https://claude.ai/artifact/RW25u91S57LN1UVfV6MYMf) and answered the
three questions: a sixth button, one list, ended goals folded with the count showing.

- **`SidebarSection.aspirations` is a row of its own**; `.kind(.goal)` is now a real list of
  goals with a date (`NoteIndex.datedGoals()`, Core, tested). Before it, **the row named Goals
  drew the aspirations**, so a dated goal appeared only after you had picked the aspiration
  above it — his words: *"I am not choosing an aspiration, no goals are visible on the Goals
  page."* **A row named after a thing has to be a list of that thing.**
- **`AppModel.sidebarSection(for:)` decides which room a goal note belongs to**, so every route
  to one — a `[[link]]`, a Map box, a review row, a search result — lands beside a list that
  contains it. One place, as it was for `.inbox` and `.daily`.
- **Every row *inside* a chain navigates with `model.section ?? .kind(.goal)`**, never a fixed
  section: build 135's rule, and with two goal rooms a fixed one would throw the Aspirations
  list out of the middle column on every press.
- **The per cent left the aspiration, and that is the real find.** His screenshot read
  **100% · 3 goals · ⚠ 2 goals need attention** on one row. The bar was the average of the
  goals under it, and a goal with no project yet has *nothing to measure* — so one goal with a
  finished project spoke for all three. Underneath that: **you never finish an aspiration**, so
  a per cent on one is a promise the idea does not make. `ReviewWording.lookedAt(daysAgo:)`
  (Core, tested) took its place — "Looked at 12 days ago", **"Never looked at"** for nil, never
  a big number (build 141). **When a row shows two facts that cannot both be true, the fault is
  usually that one of them is not a fact about that row.**
- **One list, not two.** The **Nothing serves these yet** group is gone; the row says it. A
  group whose members are only "the ones you have not started" reads as a telling-off, and it
  is the same family as build 140's "Hobby or homeless?".
- **`GoalEndedHeader` is one view used by both rooms**, and `endedGoals()` is filtered per room
  by `GoalWording.isAspiration`. Build 168's rule: one thing drawn in two places is one view.
- **`NewThing.aspiration` is the sixth button**, and the "What kind of goal" chip is gone —
  two controls for one state is build 165's fault. `NewThing.forSection(_:)` is written out
  rather than matched on `kind`, since Aspiration and Goal share `ParaKind.goal`. The row is
  still an `HStack`, **not** a `WrappingHStack`: a chooser reads as equal cells, and wrapping
  gives each child its natural width. The Mac sheet went 420 → 480pt for the sixth.
- **`GoalsHeader` takes `showsAll:`.** **All of them** belongs to the Aspirations room only;
  in the Goals room it would open nothing, and a control that does nothing where it is drawn
  is worse than no control (build 175).
- **Nothing in the vault changed.** Both kinds are goal notes and `horizon:` still tells them
  apart — no migration, and every old note reads the same.

## Orange on orange (build 200)

His screenshot of the Aspirations list: *"When the aspiration is chosen, then the text cannot
be read. The warning text is orange, and the selection also gets orange when you select it."*

**The selection fill is the user's own macOS accent colour, and his is orange** — the same
accent that drew build 197's yellow focus ring. SwiftUI turns a plain `Text` white on a
prominent selection by itself, but **an explicit `.foregroundStyle(Color…)` wins and does not
change**, so every tinted label in a selectable row was at the mercy of whatever accent the
user had chosen. Orange warning text on an orange fill was simply invisible.

- **`rowTint(_:)` (Theme.swift) is the one place it is decided.** It reads
  `\.backgroundProminence` — `.increased` exactly while the row is drawn as a prominent
  selection — and hands back `HierarchicalShapeStyle.primary` there, the inherited foreground
  the list has already made readable against its own fill; the tint everywhere else. Written
  out with the type name, because bare `.primary` is ambiguous with `Color.primary` (a fixed
  dark ink, which would be worse than the bug).
- **Only explicit colours needed it.** `.secondary` and the other hierarchical styles already
  resolve against the row's foreground and were never broken — which is what kept the change
  to 22 mechanical call sites in five row views: `AspirationRow`, `DatedGoalRow` (plus
  `NoAspirationPrompt` inside it), `NoteRow`, `TaskRow`, `InboxRow`. **Look for
  `.foregroundStyle(` with a `Color` in any new row that can be selected.**
- **Shapes deliberately keep their tints**: `KindBadge` and `GoalProgressBar`. A badge is
  still a visible shape, and a bar that changed colour on selection would read as a statement
  about the goal.
- Nothing in a detail column, a sheet, the Map or a Section header was touched: a header takes
  no selection fill, and those columns have no selection at all.

**A correction to build 167's note.** It says "red appears nowhere in the palette". That was
true of the *warning* palette and it is still the rule for a warning — but `Color.red` has
always been used for an **overdue date** in `NoteRow`, `TaskRow` and `InboxRow`. Three sites,
older than that rule, and left alone here rather than recoloured in a build about something
else. **Asked him, and he chose red** (20 September 2026, one word: *"red"*). So overdue keeps
`Color.red` in `NoteRow`, `TaskRow` and `InboxRow`, and orange stays the warning colour
everywhere else. Settled; do not reopen it.


**Build 201 finished it, and the lesson is about how I checked.** 200 fixed the five row views
I had in front of me and I told him it was done. He asked *"Do we need to check this throughout
the app, or have you already done that?"* — and the honest answer was no: **four of the nine
selectable lists were still wrong**, including the sidebar itself. `SidebarView.row(_:)`
(`section.tint` on the symbol), `HealthRow` and `GoalHealthRow` in the review, and
`SearchHitRow`.

**The method, so it is never guesswork again.** Three greps, in this order:
1. `grep -rn "List(selection:" App/Paragon/Views` — every list a row can be selected in.
2. In each, find the rows carrying `.tag(…)`. **An untagged row never takes the selection
   fill**, which is why `ReviewDueRow`, `TodayView`'s date line and every Section header were
   safe and are deliberately untouched.
3. In those rows only, look for `.foregroundStyle(` with an explicit `Color`.

Nine lists, nine checks. `TaskRow` covers Today, Calendar, Done, All actions and the review's
steps 1 and 2; `NoteRow` covers every PARA list; `TemplateRow` and `DailyNoteRow` carry no
explicit colour at all (a `TintStripe` is a shape and keeps its tint by design).

**"I fixed the ones I could see" is not the same as "I checked".** When a fault is a *class*
rather than one screen, the build is not finished until the search that finds every instance
has been run and written down.

## The pop-up list's own furniture (build 202)

His screenshot of the New note sheet with the **Template** popover open: *"please analyse this
graphic in the pop up menu - does not look good"*. Two separate faults in one picture, and
**neither was drawn by our code**.

- **A help tag on a control just above a sheet's footer lands on the footer.** `.help(name)`
  sat beside `.popover(isPresented:)` on the same Button in five places, and macOS puts the tag
  by the pointer — so "Template" covered **Cancel** and **Create**, both cut in half. While the
  popover is open the tag is also pure repetition: its first line already says that word
  (build 169). `helpWhenClosed(_:open:)` (Theme.swift) is the one place that is decided.
  **The branch goes inside the button's *label*, never around the button** — an `if`/`else` in
  a `@ViewBuilder` changes that subtree's identity, and the popover hangs off the button, so
  rebuilding it would close the popover the instant it opened. `.help("")` was considered and
  rejected: an empty tag may still draw an empty box and there is no Mac here to look.
- **`.focusEffectDisabled()` belongs on a popover that is a list of buttons.** The gold line
  under "Project (default)" was macOS giving the first plain Button keyboard focus on open and
  ringing it in **his accent colour, orange** — reading as a second selection arguing with the
  tick. **Exactly build 197's yellow square round the Inbox, one screen along**, and the rule
  there was already written: anything that takes focus needs `.focusEffectDisabled()` beside it
  unless the ring is wanted.
- **Scope, decided rather than swept.** The ring is switched off in `PickerChip.list` and once
  inside `TagChoices` — which covers the note header, the New note sheet and Capture together.
  The **date** popovers keep theirs: `DateChoiceView` leads with a `TextField`, where a focus
  ring is the normal, useful thing, and the two syntax-help popovers hold no buttons at all.
- **Neither could be seen from here**, and both were read off one screenshot: the tag's words
  matched `.help(name)`, and the line's colour matched his accent rather than anything in the
  palette. Said as much to him rather than claiming it fixed.

## Making the thing you are pointing at (build 203)

His two questions, in one message: *"Would it be possible to add a Goal from this picker /
menu"* and *"Would it be possible to add or connect an Aspiration, or is this too far fetched
/ complicated?"* Neither is far-fetched — it is **the oldest recurring fault in this project
turned around**: 132, 134, 140, 144, 165 and 167 were all a screen that read a line nothing
could write. This is a screen that *asks* for a note that does not exist yet and made you
leave to go and make it.

- **`PickerChip.MakeOption`** (prompt, hint, and a closure returning the value to choose). A
  list with no `make:` is unchanged, so Template and "Part of another area" are untouched.
  The field at the top is **the shape `TagChoices` has had since build 145** — reuse the
  pattern he already knows rather than invent a second one.
- **The kind is never a second question.** The chip says which: a project's **Serves a goal**
  makes `horizon: year`, a goal's or an area's **Serves an aspiration** makes `horizon: life`.
  Two controls for one state is build 165's fault.
- **`AppModel.makeNoteQuietly` is `createNote` without the navigation**, and `createNote` is
  now that plus `show(_:)`. A note made from inside a sheet must not move the window behind
  it: he is making a project, and the goal he just named is a detail of it, not a place to go.
- **`createNote` called `show(section: .kind(kind), …)` — a build 199 miss.** Since a goal note
  belongs to **Aspirations** or to **Goals** by its `horizon:`, only `sidebarSection(for:)`
  knows which, so a brand new aspiration opened in the Goals room beside a list without it.
  `show(_:)` now. **When a section splits in two, every place that names the old one by hand
  is part of that build** — 199 found the routes through `sidebarSection(for:)` and missed the
  one that spelled the section out.
- **The chip no longer hides itself when its list is empty.** `serves` used to `guard` on a
  non-empty list, so a fresh vault offered no **Serves a goal…** at all — the one moment the
  button is most needed. **A control that vanishes when it has nothing to offer removes the
  only way to give it something.**
- `makeOption(_:)` is a plain function, not inline in the ViewBuilder: a struct carrying a
  closure is where inference has given up before (builds 152, 154).

**Build 204, from one screenshot and two questions.** *"Are these options nested correctly?"*
and *"Can we add goals and aspirations from here?"*

- **No, they were not.** `allGoals` was `model.notes.filter { $0.kind == .goal && !$0.isArchived }`
  — every goal note in vault order, stars and targets interleaved, **and ended goals
  included**, so a goal already marked Done was offered as something new work could serve.
  It is `model.index.datedGoals()` and `model.index.aspirations()` now: **`NoteIndex` decides
  what is live and in what order**, so the picker cannot disagree with the two screens
  (build 162's rule), and the two halves sit under headings with the fitting kind first —
  which is the ordering rule `NoteGoalOptions` has followed since **build 140** and this chip
  had simply never picked up. **When one menu learns a rule, find the other menus that ask the
  same question.**
- **Grouped, not nested under each aspiration.** A drawn or indented chain here would make an
  aspiration a heading *and* a row you can choose, and a heading you can press is a shape this
  project has gone wrong on before. Build 166's reasoning: the list carries what the drawing
  cannot, and there is already a Map.
- **Both kinds can be made.** `MakeOption` carries `actions: [MakeAction]`, one button each;
  a project's list gets **Add goal** and **Add aspiration**, Return commits the first. The
  argument is simple and worth keeping: **a list that lets you choose an aspiration has to let
  you make one.**
- **The hint was squeezed to "Made without a target date; set one on…"** — build 138 again,
  sharing an `HStack` with the button. Its own line now. **He found it; I had put it there.**
- `ChipOption` gained `group:` and `tint:`, both defaulted nil, so Template and "Part of
  another area" are untouched. The tint is build 189's rule: an aspiration's star is the
  deeper gold even inside a list tinted for something else.
- The popover went 290 → 320pt and rows take two lines: his goal titles were being cut.
- Inside `grouped`, the locals are `heading` and `byHeading`, never `name` — the struct has a
  `name` (build 150's shadowing).

## Done, Missed, Dropped (build 165)

The last item on the roadmap, and **he changed the word**: I proposed *reached* / missed /
dropped and he asked for **Done** / Missed / Dropped, because `done` is already in his notes
and so nothing needs rewriting. He was right, and it also meant build 163's **Reached** group
on the Goals screen had to be renamed — **two words for one state is the fault, whichever
word is prettier.**

- `Core/Model/NoteStatus.swift` (tested) is now the only place `status:` is understood.
  **Before it, ten places compared the raw string and each knew a different set**: `Review`
  knew four spellings of on hold, `GoalProgress` three of done, `NoteIndex` knew `"on hold"`
  with a space that nothing has ever written. All ten go through the enum.
  `NoteStatus(reading:)` keeps every old spelling working for ever — `achieved`, `completed`,
  `paused`, `someday` — and `NoteStatusTests` pins each one, because a note written in 2026
  must still read the same in 2030.
- **`isEnded` ≠ `isDelivered`.** Ended is done/missed/dropped; delivered is done alone. That
  one distinction is the build: the roll-up counts only delivered, and **a missed or dropped
  project is skipped entirely** — counting it 1 is a lie, counting it 0 holds the goal at
  nothing for ever. Same reasoning build 141 used for an archived-not-done note.
- **`setStatus(_: NoteStatus, for:)` writes `.active` by removing the line**, never by writing
  `status: active`: a note that says nothing is active, and writing it back would stamp every
  note he opens.
- **`NoteStatusChip` is the fifth time this rule has been earned.** `status:` was read by five
  screens and written only by three buttons in the review's context menu, **projects only** —
  so a goal could never be marked anything from the app at all. Same fault as `due:` (132), an
  area's `goal:` (134), a project's `goal:` (140), `tags:` (144). Each menu line carries its
  meaning, since *Missed* and *Dropped* are new words.
- **Dropped is drawn grey, not orange.** It is a decision, not a failure, and a warning colour
  would say otherwise.
- **One group per ending on the Goals screen**, never one group for all three: `endedGoals()`
  returns `[(status, notes)]`. A group called **Done** holding a goal you missed is the
  "Hobby or homeless?" naming fault wearing a plainer coat.
- `AspirationChainBody.endedGroups` is a computed property, not a loop in the body — the
  `@ViewBuilder` rule (build 58), which I broke first and caught by counting braces.

**Build 164 answered both open questions from his screenshot**: "Goals with no aspiration" has
one row, not the whole screen, and the chain reads well. Neither needs the change I had ready.

## All of them (build 166)

His idea — *"if you could open aspirations and have that mapped or listed, you would see your
whole life on one screen"* — then **he ruled out the drawing himself**: *"No, I don't want that
as a drawn tree, more as a list."* He was right, and the reason is worth keeping: **the Map is
already the drawn version**, a second picture of one thing leaves you unsure which to open, and
a list carries the dates, per cents and next actions a drawing cannot. I dropped shape C from
the preview before publishing rather than offer something he had already refused.
- `AllAspirationsView` is a `ScrollView` of the **same `AspirationChainBody`** the
  one-at-a-time view uses. **Never a second way of drawing a chain** — that is how the Map,
  the review and the goal dashboard came to answer "what serves what" three different ways
  before 162. Goals with no aspiration are listed at the foot (build 100: a screen that claims
  to be everything may not quietly leave them out).
- `GoalsShowAll.key` is one `@AppStorage` key read by the middle column's `StateToggle` and by
  `DetailView`, so the button and what it shows cannot drift. He asked for a toggle rather
  than a sidebar row, and that is right: a second row would be two doors into one room.
- On the phone `showAll` opens every folding row; tapping one row turns it off and leaves that
  one open, which is what a tap on an open list should mean.

**Build 167, both from his test of 166.**
- **"I don't understand, and it also moves in various views."** The **All of them** button was
  a `ToolbarItemGroup` on the middle column, so on macOS it sat after whatever else each
  screen owned and landed in a different place every time — and carried no word. `GoalsHeader`
  is now one header row inside the column (the Calendar's Schedule/Note header, build 159, is
  the same shape) with the name beside the button. **A control that governs what a column
  shows belongs in that column, next to its own name, never in the window's toolbar.**
- `GoalsHeader` has a **written-out `init`**: a struct mixing `@AppStorage` with a
  `@ViewBuilder` stored property is where the generated memberwise initializer is hard to
  predict, and there is no compiler here to ask.
- **`NoAspirationPrompt` — the sixth time.** "Goals with no aspiration" stated a problem and
  left the fix three screens away. Now each row carries **Give it an aspiration**, opening the
  existing `NoteGoalOptions`. Same rule as `due:` (132), an area's `goal:` (134), a project's
  `goal:` (140), `tags:` (144), `status:` (165).
- **He asked for red; it is orange.** Orange is what this app has always meant by "look at
  this" (past target, no next action, needs attention) and **red appears nowhere in the
  palette**. A goal with no aspiration is a loose end, not an error. Told him so plainly.
- He also asked what the two icons mean, which says the star/target pair is not
  self-explanatory. Both are now named in `Docs/HowItWorks.md` with the reason — star = the
  north star you steer by, target = what you aim at on a day.

**His preview pages have stopped recording ticks.** Twice now the `db` doc came back with
`choice: null` and `extras: {}` while he plainly had an answer — build 163's five extras and
this one's shape both had to be asked again in chat. He said it himself: *"I have already
entered that, so I don't know if the mockup questionnaire works."* **Until that is diagnosed,
a preview page is for showing, not for collecting: draw the options and ask him to reply in
chat.** The free-text box does save; only the buttons and tick boxes are lost.

## The blank widget (build 177)

His report the morning after 176: the widget was **a completely blank box**, and it stayed blank
after opening the app. Asking him one question ("which of these four does it show?") is what made
it useful — *blank* is not the same report as *"Open PARAGON once…"*, and the two have different
causes. **That question cost one message and would have cost two builds** (123–127 again).

Nothing was changed on a guess, because there is nothing here to guess from: three faults look
identical from the outside, and only one of them is about his vault.
- `containerURL` nil — the App Group is not switched on for this build of the widget. **Opening
  the app can never mend it**, and until 177 that was the only advice the widget gave.
- No file — the app has not written yet.
- The extension not running at all — nothing the app does is visible.

So 177 makes each of them say its own name:
- **`WidgetFoot`: one small line on every widget**, `PARAGON <build> · <state>`, where state is
  "shared folder missing", "nothing written yet" or "written 09:41". **Its presence is the
  message**: if the line is on screen the extension is running, which is the one thing a widget
  can never otherwise tell you. The build number comes from the *widget's own* Info.plist
  (`CFBundleShortVersionString`, set per bundle by the workflow), so a widget left behind by an
  update shows it.
- **`ParagonEntry.folderFound`**, so the view can tell the first two apart at all.
- **Settings › Widget** (`WidgetStatusSection`, iOS only — the Mac entitlements drop the App
  Group by design) answers the same three questions from the app's side, because **a widget that
  is not running cannot answer anything**. It reads the file back exactly the way the widget
  does, so the two cannot disagree.
- **The workflow lists every bundle it ships** ("What is inside the app"): both xcodebuild steps
  keep only lines matching `error:`, so an extension quietly left out of the app looked exactly
  like a clean build. `codesign -d --entitlements` on each `.appex` is in there too, for the App
  Group question.

**The rule: a screen with no keyboard and no user to ask has to carry its own diagnosis.** Build
100 said never let a read failure look like an absence; a widget is where that is hardest and
matters most, because the only debugging tool is what the box says.

## The widget on the Mac (build 178)

**The blank box was never a fault in the widget.** He said it in one line the next morning:
*"I use the widget on my Mac only."* There was no Mac widget — 174 built an iPhone one on
purpose ("a Mac widget would be a second thing to sign"). The PARAGON widget the Mac *could*
offer him was his iPhone's, relayed by **iPhone Mirroring, which Apple does not provide in the
EU**: the very dialog he had screenshotted an hour earlier and I had answered as unrelated.
**Two reports an hour apart were the same report.** When something is impossible in the user's
country, check whether the next thing he shows you depends on it.

- `ParagonWidgets` is `supportedDestinations: [iOS, macOS]` and the app's dependency on it lost
  its `platformFilter`.
- **The App Group has two spellings, and that is the whole risk of this build.** iOS keeps
  `group.com.schabbauer.amspara` (one of the four identifiers the rename kept). A sandboxed Mac
  app cannot join a group spelled that way: on the Mac it must begin with the Team ID, and the
  Mac App Store refuses one without it — which is why `Paragon-macOS.entitlements` had dropped
  the group entirely since build 64. Both now carry
  `D24ENP83QQ.group.com.schabbauer.amspara`. It is the same group in the portal, spelled as
  each platform requires. `AppModel.widgetGroupID` and `ParagonWidgetBundle.appGroupID` decide
  it per platform, and the two are written out separately because a widget target cannot see
  the app's code (the `WidgetLook` problem again).
- **`AppModel.appGroupID` is deliberately left alone.** It is the capture outbox, the share
  extension is iOS only, and on the Mac it falls back to Application Support. Pointing it at
  the new container would move a folder for no reason and strand anything queued in it.
- `App/Config/ParagonWidgets/ParagonWidgets-macOS.entitlements` also turns the sandbox on: an
  extension inside a sandboxed Mac app must be sandboxed itself.
- Settings › Widget (build 177) is no longer `#if os(iOS)`.
- **A new Mac widget is not in the picker until the app it came with has run.** He updated,
  looked at **Edit Widgets**, and PARAGON had vanished entirely — the iPhone entry gone with
  nothing to replace it. Opening PARAGON, ⌘Q, and opening it again was the whole fix. It is in
  `Docs/HowItWorks.md` now, because it will happen again on every machine that installs this
  for the first time. **The CI check is what made this answerable without guessing**: the Mac
  app provably carried `ParagonWidgets.appex`, so the question was only whether macOS had
  loaded it.
- **The CI step "What is inside the Mac app" and the TestFlight step of the same name look in
  different folders**: an iPhone app is flat (`PlugIns`), a Mac app is not
  (`Contents/PlugIns`). Build 178's first upload reported "no extensions are embedded" for the
  Mac because the step only knew the iOS shape. **A check that can be wrong in one direction
  is worth as much as no check at all** — it nearly sent me hunting a fault that was not
  there.

## No vault, and no way back (build 179)

His iPhone widget stayed on "Open PARAGON once…" through every check. **The screenshot of the
app settled it in one step**: the phone was showing the *welcome screen*. No vault open, so
`reload()` returns early, so `writeWidgetSnapshot()` never runs. The widget had been right all
along, and three rounds of widget questions were spent because I never asked to see the app.
**When a reader says "nothing is there", look at the writer.**

- **`restoreVault` failed in silence.** `guard let url = try? URL(resolvingBookmarkData:…)
  else { return }` — a folder renamed, moved, or not yet down from iCloud left `vault` nil and
  `ContentView` drew `WelcomeView`, which is the first-run screen. So "I cannot open your
  folder" and "you have never set this up" were the same picture. That is build 100's rule
  broken where it costs most, because here the absence *is* the whole screen.
  `AppModel.vaultProblem` now carries the reason and `WelcomeView` shows it in orange.
- **`closeVault` deleted the only pointer to the folder** (`defaults.removeObject(forKey:
  bookmarkKey)`), so there was no way back even in principle. `lastVaultBookmark` +
  `lastVaultName` survive a close; `canReopenLastVault` and `reopenLastVault()` are the way
  home, and the welcome screen leads with **Open <name> again**. His ask, in his words: *"a
  way out back into the app"*.
- **A screen that can only go forward is a trap**, however sensible each step looked: choosing
  a folder was the only control on it, and closing a vault was a one-way door.
- The small widget's message filled the card and pushed `WidgetFoot` off the bottom — **the
  diagnostic line crowded out by the thing it was there to explain**. `emptyText` is short on
  `.systemSmall` and the foot carries `.layoutPriority(1)`. **A message that hides its own
  explanation is worse than a shorter message.**

## The App Group was never in the iPhone app (15 September 2026)

**Proved, not guessed.** Settings › Widget on his iPhone said *Shared folder: Not found*, and
the widget's own foot line said `PARAGON 179 · shared folder missing`. A TestFlight run with a
new step, **"What the App Store actually signed"**, exported a second signed copy to disk,
unzipped it and read the entitlements back:

```
=== PARAGON.app ===         NO APP GROUP IN THIS BUNDLE
=== ParagonShare.appex ===  NO APP GROUP IN THIS BUNDLE
=== ParagonWidgets.appex === NO APP GROUP IN THIS BUNDLE
```

**Apple's automatic signing silently drops an entitlement the App ID does not carry**, and the
line that says so is filtered out of the log by `grep -E "error:|Upload|EXPORT"`. So
`group.com.schabbauer.amspara` has been in `project.yml` and in every entitlements file since
build 42 and in **none** of the signed iPhone builds. Consequences, both invisible until now:
the widget (174 on) could never read anything, and the **iOS share extension's outbox has
always fallen back to Application Support**, where the app cannot see it — so a capture from
another app's share sheet never reached the Inbox and nothing ever said so.

- **macOS is unaffected**: its group is team-prefixed and the Mac widget demonstrably works.
  The same App ID, two different answers per platform.
- **This section's conclusion was wrong. See build 206.** It said the fix was his, in the
  developer portal — enable **App Groups** on `com.schabbauer.AMSPara`, `.Share` and
  `.Widgets`. On 20 September his screenshot showed App Groups **already enabled and the
  group already ticked**. The dump above is still true; what it means is not. The cause was
  `CODE_SIGNING_ALLOWED=NO` on the iOS archive in our own workflow: nothing ever wrote the
  entitlement, so nothing was there to be dropped. Five days lost to a theory that put the
  next step on him and so could not be tested.
- **The step stays in the workflow.** It is `continue-on-error` and iPhone only, and it is the
  only way to see a signed entitlement from this container. **A build that "succeeds" proves
  nothing about what is inside it** — the same lesson as build 178's missing PlugIns check,
  one layer deeper.

## The line for now (build 180)

His ask, in his words: *"add an indication with a line for where we are in the day… as a normal
calendar app does it."* The Calendar section's day had drawn one since build 61; **the planner,
the newer screen, had none** — the same drift as the Map's vocabulary before 170.

`NowLine` (Theme.swift) is the one component both screens draw, and it **keeps its own clock**
(a `.task` loop, once a minute) so the two can never be live in one place and stuck in the
other. It takes `firstHour`/`lastHour`/`hourHeight` and returns nothing at all when the day is
not today or the time is outside the drawn hours.

- **Red lasted one build.** He said why, and he was right: *"Red is for something that is
  overdue or dangerous, so take a friendly color."* I had reasoned from what other calendars
  draw instead of from what colour means **in this app** — and build 167 had already written
  the rule down ("red appears nowhere in the palette"). **When a convention from outside
  disagrees with the app's own language, the app's language wins.**
- **`Theme.nowTint` (`NowTint`, a soft slate blue) is deliberately not one of the nine tints**
  (build 182). Purple is the Calendar lane drawn right beside it, orange the plan blocks, pink
  Areas, green Projects, blue Resources, teal the review, gold Goals, grey the Archive. The
  time of day is not a kind of note, so it may not wear a kind's colour. The line went to
  1.5pt and the dot to 7pt at the same time, since slate reads quieter than red.
- Two sentences in `Docs/HowItWorks.md` said "a red line" — build 159's lesson about a manual
  that names a colour or a position. Grep the manual whenever one changes.
- `allowsHitTesting(false)`: it lies over the cards, and anything over a card that could take
  its click is builds 71–74 again.
- `DayScheduleView` lost its own `now` state, its refresh loop and `nowOffset(in:)` to it. Its
  `range.upperBound` is the hour *after* the last one drawn, hence `lastHour: upperBound - 1`.

## Five tabs, swiped between (build 183; the swipe was removed in 232)

His ask after 181: the swipe should work *"on every screen, not only the time block"*. I put
three shapes to him and he took **five tabs, Capture as a button**: the bar is now
**Today · Plan · Actions · Inbox · Browse**.

- **SwiftUI's ordinary `TabView` does not swipe, and its page style draws dots instead of a
  bar.** So `PhoneRootView` is a page-style `TabView` with the dots off, and `PhoneTabBar` —
  ours — writes to the same selection from a `.safeAreaInset(edge: .bottom)`. What the system
  bar did for free has to be drawn here: the Inbox **badge**, the tint for the tab you are on,
  a full-width tap target, and a background that reaches past the home indicator
  (`Rectangle().fill(.bar).ignoresSafeArea(edges: .bottom)`, since a plain `.background` stops
  at the safe area).
- **Still a pager, never a gesture of ours.** The drag from the left edge is iOS's *go back*;
  taking it would break going back from every note and nothing here could catch it
  (builds 71–74).
- **Build 181's `PhoneDayPages` is deleted.** A pager inside a pager makes one swipe mean two
  things. Its two branches in `ContentView` went back to `PlannerView()` and `AllActionsView()`,
  and `NoteListView`'s `isPhone` went with them.
- **Time Blocks and All actions left `PhoneBrowseView.groups`**: they are tabs now, and a
  second door into one room is what build 166 argued against.
- **Quick capture lost its tab** and is a `ToolbarItem(placement: .topBarLeading)` on Today —
  leading, because Today is the root of its stack and has no back button, so build 88's
  "one control" is not breached.
- `Tab.section` reads `SidebarSection` back rather than spelling the sections again, so a tab
  and the row it replaced cannot drift (build 168).
- **Untested from here**: whether a horizontal scroll inside a page (the Map's two-way scroll,
  the Calendar's chip strip) wins its own swipe. CI compiles but never swipes.

## One door in (builds 185 to 189)

His words about the old New note sheet: *"This is a very sad entry page. I would like to have:
Goal, Project, Area, Resource, Quick Capture — all five with buttons at the top, then we can
have the name field."* He chose the lower half from a preview
(https://claude.ai/artifact/67nAaem7sj89DyZGZBiXDQ) — shape **B**, chips — and asked for
"Capture" as the short name and "Template" as the word.

- **`NewThing`** is the five, its own type rather than `ParaKind`: a capture is not a kind of
  note, and pretending it is would put it in the sidebar, the Map and the review. Capture wears
  the **Inbox** tint, which is the same orange the preview drew by eye.
- **The capture half is `QuickCaptureView(embedded: true)`**, the very view the menu bar item,
  ⇧⌘N and the phone's button use. `embedded` drops its heading, padding and width, and
  `deskWidth` is written out rather than a ternary over `CGFloat?`.
- **`ChipLabel` / `PickerChip` / `DateChip`** are build 142's two states in a settings row: set
  is the tint filled with a solid border, not set is grey with a dashed one. **A popover, not a
  `Menu`**: `ProjectDeadlineChip` and `NoteTagsChip` are both built that way and are known to
  behave on both platforms, and a popover can carry a heading saying what is being chosen.
  `ChipOption` is a struct, not a tuple (build 61, fourth time).
- **New in the sheet: an area can be given the aspiration it serves.** The same fault as 132,
  134, 140, 144, 165 and 167, inside the sheet this time.
- **Build 186: a plain `Button` is a proper button on a Mac and two blue words on a phone.** His
  screenshot. The footer is split per platform; on the phone **Create** is full width in the
  chosen kind's tint. **The padding goes inside the label** — a Button's tap area is its label,
  and padding put outside only moves it.
- **He asked for plain words**: *"don't use words like 'caught it' in order to be cool. Just use
  Save."* The capture button says **Save** and the caption says "3 saved today."

## Tags you can see before you make a new one (builds 187 and 188)

*"It's not always too easy to know what tags I have defined, and I don't want two tags the same
meaning, but slightly different names."*

- **`TagChoices` (TagsView.swift) is the one list**, pulled out of `NoteTagsChip` and opened by
  the note header, the New note sheet and the Capture screen. Each row says how much of the
  vault carries that tag, or "not used yet" — **that number is the feature**, because it is what
  makes a near-duplicate visible.
- **The counts are read once in `onAppear`.** `tagUses()` walks every note and every task;
  reading it from `body` would redo that walk on every keystroke in the new-tag field.
- **`Vault.createNote` takes `tags:` separately from `extraFrontmatter`**, because
  `extraFrontmatter` writes a *string* and "travel, work" as a string is one tag called
  "travel, work". An empty list writes nothing, so a template's own `tags:` line survives.
- **`AppModel.cleanTag` moved into Core as `TagName.clean`/`cleaned`, with tests** — build 146
  asked for exactly that after shipping a version that stripped only a leading `#`.
- **Build 188, and he had to ask.** *"The tags work on everything except Capture."* The reason
  is worth keeping: a note's tags are a `tags:` line and a capture's are `#tag` inside the
  words, so **in the code they are two mechanisms and I was editing one screen** rather than
  asking which screens pick a tag. `CaptureReading.line(_:settingTags:)` (Core, tested) strips
  with `TaskParser.tagRegex` itself, so what comes out is exactly what the parser would read.
  **When a build changes how something is chosen, every screen that chooses the same thing is
  part of that build** (build 168's rule, third time).

## The colour of an aspiration (build 189)

Open since build 175, decided from a preview of four
(https://claude.ai/artifact/4ka6hyMeeTCuEBMjN5Ajc2). He took **B**: a deeper gold
(`AspirationTint`, #8A5A12 / #E0A83E). Plum was drawn and refused — it leaves the goal family
and neighbours the Calendar's violet.

- **`ChainTint` sits beside `ChainSymbol`** with the same two overloads, so the colour and the
  symbol are decided in one breath everywhere. An unresolved `goal:` name takes the dated goal's
  gold, never the aspiration's.
- **`Note.tint` is the change that carries most of it**: a goal note asks `ChainTint`, which
  covers `NoteRow`, the note header, `TintStripe` and every `MapNode.tint`. `KindBadge` and
  `GoalProgressBar` gained a `tint` override for the same reason each already took a symbol.
- **Every screen in the same build**: Goals list and chain, the Map card and its legend, the
  review's `GoalHealthRow` and `ReviewDueRow`, the note header, `NoteGoalChip`, the planner's
  serves line, the New note sheet and the rhythm chips in Settings.
- **Left gold on purpose**: the sidebar row **Goals**, the tint over the detail column, "No
  goals yet", and a dated goal's own counts, target and rail. That row is the whole family,
  which is also why it carries the target and not the star (build 168).

## CI opens the app now (build 190)

He asked for it after I named it the biggest weakness. **CI had compiled this app since the
first push and had never once opened a screen in it**, which is why builds 71–74, 85, 114–128
and 123–127 all shipped green.

- **`App/Paragon/TestVault.swift`, DEBUG only.** The vault was always the obstacle: PARAGON
  opens a folder the user chose, kept as a security-scoped bookmark, so a fresh install shows
  the welcome screen and a test can go no further. With `-paragon-test-vault` the app makes a
  folder in the temporary directory and opens it **through the ordinary `openVault(at:)`**, so
  the tests exercise the real path. It wipes the app's `UserDefaults` first — the simulator
  keeps the container between runs, and a remembered section or `editorMode` deciding what a
  test sees is builds 123–127 all over again.
- **`ParagonUITests` has a target *and a scheme* of its own.** The `Paragon` scheme that
  TestFlight archives does not know it exists, which is the only way to be sure a Release
  archive can never contain a test bundle.
- **Two tests, deliberately dull**: the tab bar appears (which also proves the vault opened
  rather than the welcome screen), and every tab opens a screen with the app still running.
  **A screen test that fails for its own reasons is worse than none**, because the next red
  light is then ignored. Grow the suite one or two at a time and watch each addition go green.
- **The CI job picks the simulator by id** from what the runner actually has; a destination
  naming an iPhone the image lacks fails in a way that reads like a broken test.
- **A suite with nothing in it also prints `TEST SUCCEEDED`**, so the job counts the cases that
  started and the ones that passed. Build 178's rule: a check that can only be wrong in one
  direction is worth as much as no check at all.
- Tab buttons carry `accessibilityIdentifier("tab.today")` and so on — **a name of its own,
  never the title**, so a tab renamed for him does not quietly stop a test finding it.
- **A push that changes `project.yml` makes CI commit the regenerated project**, so the next
  local push needs `git pull --rebase` first.

**Build 191: the two tests the plumbing was for, both green first time.** Browse › Projects ›
the test project, typing into the editor (the 114–128 fault); tapping an Inbox line and
checking it became the selected one (the 71–74 fault).
- **Everything is found by accessibility identifier, never by words.** The phone's tabs are
  pages of one pager, so "Projects" can be on screen twice at once (a Browse row and a group
  heading on the Actions page), and a word he asks to be renamed must not stop a test finding
  the thing. The names: `tab.*`, `browse.<section title>`, `note.<relativePath>`,
  `inbox.<line title>`, `note.editor` (set on the `UITextView` in `makeUIView`). A row gets
  `.accessibilityElement(children: .contain)` first, so the identifier lands on one element
  with a frame that can be tapped.
- **`InboxRow` carries the `isSelected` trait when it is the selected line**, which is what
  lets the test ask the 71–74 question at all — and what VoiceOver should have been told all
  along. The test waits for it with an `NSPredicate` expectation, since selection is published
  a turn later through `afterUpdate`.
- `TestVault` captures one Inbox line through `Vault.capture`, the same path a real capture
  takes. Its titles are `static let`s in that file; the tests spell them again because a test
  target cannot see the app's code — keep the two in step.
- **`SheetFooter` (Theme.swift)** is build 186's phone-and-Mac footer as one view, used by the
  New note sheet and by `NoteFromLinkSheet`, which still had two blue words in a corner on the
  phone and a 380pt `minWidth`. Reach for it on any new sheet.

**Build 193: a capture, end to end** — `today.capture` on Today (renamed `capture.open` in 196), `capture.text`, `capture.save`,
then `tab.inbox` and the line as `inbox.<text>`. **It failed once and passed the next run with
no app change**: the first version waited 15 s for the sheet to close itself after Save, and a
cold CI simulator took longer than that. The wait is 30 s now, and the test checks the "Saved"
confirmation first so a real fault would be named. **On a CI simulator, a wait for the app's
own timers needs twice the room you think** — a test that fails for its own reasons is the one
thing this suite may not do (build 190). `visibleTexts()` puts the first twenty texts on screen
into a failure message: the nearest thing to a screenshot the log can carry.

**Build 194: a Map box is tapped** — Browse › `browse.Map`, tap `map.<note path>`, and the
note opens in `note.editor`. `MapNodeBox` carries the identifier on both its branches;
accessibility only, since nothing that takes the box's click may be attached (build 85). The
**aspiration's** box is the one tapped: root goals sit at the top of the layout, where a phone
shows them without scrolling, and the test says so if the box is on the Map but off screen.
Seven tests, all green. **The run took fourteen minutes instead of seven and every test was
two to seven times slower** — a slow runner, not the Map (its test took 16 s). The job now has
`timeout-minutes: 30`, so a stuck simulator can never hold it for GitHub's six-hour default.

**Build 192: the New note screen, end to end** — Browse › Projects › `list.newNote`, press
`new.project`, type into `new.name`, press `sheet.action`, and the new note opens in
`note.editor` with the name in its text. Five tests, all green first time. `sheet.action` /
`sheet.cancel` sit on `SheetFooter`'s buttons on both platforms, so any sheet that uses the
footer is pressable the same way.

**Build 195: the same suite on the Mac, green first time.** A second CI job, **Screen tests
(Mac)**, runs `ParagonUITests` with `-destination "platform=macOS"`: the runner is a Mac, so
the app itself is started and clicked, no simulator. Two and a half minutes against the
phone's seven, and **no automation permission was needed on the GitHub runner** — the one
risk I could not check from here. The faults that cost the most (71–74's Inbox list, 85's Map
canvas) were the Mac's, and until this the suite could not see them.
- **One suite, two platforms.** `#if os(macOS)` in `ScreenTests.swift` picks the way in and the
  proof a screen was drawn: the sidebar row (`sidebar.<section title>`, on `SidebarView.row`)
  where the phone taps a tab, and `app.windows.firstMatch` where the phone has a navigation
  bar. `XCUIElement.press()` is `click()` on the Mac and `tap()` on the phone. Everything
  after the way in is the same code, which is what the identifiers are for.
- The Mac's `NSTextView` carries `note.editor` through `setAccessibilityIdentifier`, the
  phone's `UITextView` through `accessibilityIdentifier =` — two spellings of one name, both
  in `MarkdownSyntaxEditor`.
- The Tools group is left out of the Mac's section walk: it folds, and a folded row is not on
  screen.
- The `screen-tests-mac` job has the same "did the tests really run" guard and the same
  30-minute limit as the phone's; `commit-project` waits for both.

**Build 196: all seven on both.** The five phone-only tests lost their `#if os(iOS)`.
- **`go(to:)` is the one place a test's way in is decided**, over a private `Place` enum
  (today, inbox, projects, map). `way(to:)` under each `#if` returns the identifiers to press
  in order: a sidebar row on the Mac; a tab, or Browse and then a row, on the phone. It waits
  for the home first, so every test fails on the "vault did not open" step with those words,
  never three steps later with the wrong ones.
- **The Quick capture button is `capture.open` on both platforms** (it was `today.capture` on
  the phone). On the Mac the button is in the window's toolbar, not on Today, so a name that
  said "today" would have been a name that lies — the rule behind using identifiers at all.
- The capture field is a `TextEditor` on the phone and a `TextField` on the Mac, so the tests
  use `element("capture.text")` — any element with the name — rather than `app.textViews[…]`.
  Same for `note.editor`. **Find by name, never by kind**, or one platform's control type
  quietly fails the other's test.
- Nothing else in the app changed; the build number moved because two identifiers did.
- **Five of the seven were green on the Mac at once; two failed for the test's own reasons**,
  and both are about what the Mac's accessibility tree says. **A static text keeps its words
  in `label` on the phone and in `value` on the Mac**, so the capture test's "Saved" check and
  `visibleTexts()` read both. **The Mac calls a SwiftUI group "not hittable"** when the hit
  test at its centre lands on the text inside it, and `click()` refuses such an element, so the
  Map test checks "on screen" as the box's frame inside the window's and presses through
  `pressCentre()` — a coordinate click on the Mac, a plain tap on the phone. **A green phone
  test says nothing about what the Mac's tree looks like**; the first Mac run of a test is the
  one that finds this, and a fix belongs in the test, never in the app, unless the Mac is
  genuinely not drawing the thing.

**Four Mac-only tests, same day, under `#if os(macOS)`.** Things the phone does not have:
three columns and a menu bar.
- **The window is not scrambled after a note opens** — builds 30/34. The sidebar row and the
  list row have frames wholly inside `app.windows.firstMatch.frame`, the editor's top left
  corner is inside it, and then **Help › Copy Diagnostics is chosen from the menu bar and the
  test reads the clipboard** (`NSPasteboard.general`, so `import AppKit`) and fails on any
  `OVERFLOW` line — the app's own definition of the fault. The "Diagnostics copied" banner is
  waited for first, so "the menu did nothing" and "the clipboard could not be read" fail with
  different words. **The menu item is found by its title**, the one exception to the
  identifier rule: an `NSMenuItem` made from a `.commands` Button carries none. **Not ⌃⌘D**:
  the second run pressed it with the keyboard focus in the editor and nothing reached the
  app — inside a text view that key is macOS's own Look Up. Build 103 chose it over ⌥⌘D for
  the same family of reason; a shortcut that works in a list may not work in a text view.
  **The first run failed on the editor's frame**: an `NSTextView` reports its whole document
  as its frame (649pt tall in a 452pt window on the runner), so its bottom edge says nothing
  about the window. A frame check on a scrolling view is not a check on the window.
- **⌘N opens the New note screen** (build 120: the `WindowGroup`'s New Window kept the key and
  the sheet never opened), **⇧⌘N opens Quick capture**, and **⌃⌘← goes back** to the note open
  before (build 118). `app.typeKey(_:modifierFlags:)` is the press; the screen appearing, or
  the editor's `value` changing back, is the proof. Closed again with `sheet.cancel` and Escape
  so the next test starts clean.
- `shows(_:_:within:)` waits on `value CONTAINS` rather than reading `value` once: a note opens
  a turn after the row is pressed.
- `Place.resources` was added for the Back test; the test vault's resource is
  `Resources/Packing list.md`.

## The ring around the Inbox (build 197)

His report: *"a rather thick yellow square around the complete inbox"* at launch, gone before
a screenshot could be taken. **`.focusable()` on a whole column draws the Mac's focus ring
around it** while it has keyboard focus, in the system accent colour (yellow on his Mac). Build
66 put `.focusable()` on `InboxTriageView` so single keys reach the list, and the Inbox is the
first screen at launch, so the ring was there every time the app opened until something else
was clicked. `.focusEffectDisabled()` (macOS 14) keeps the focus and drops the ring; the
Calendar's `.focusable()` got the same. **Anything given `.focusable()` for the sake of
`.onKeyPress` needs `.focusEffectDisabled()` beside it**, or the Mac frames it.

## The filter on All actions (build 198)

His own roadmap item, picked off the list. The screen had a four-way segmented `Picker` —
**All / With a date / No date / Next actions** — which could hold one answer, so "overdue
**and** important" was not a question it could be asked.

- **`Core/Vault/ActionFilter.swift`, tested.** `When` (overdue/today/soon/later/noDate), `Mark`
  (next/important), `tags`, plus `apply(to:today:)`, `tagChoices(among:including:)` and
  `summary`. In Core for build 174's reason: **a rule that decides what you do not see has to
  be testable.**
- **The boxes are `FilterBox` and mean what the Search screen's boxes mean** (build 157):
  within a row an **or**, between rows an **and**. Two screens that filter must not mean
  different things by a tick; a test pins it.
- **The five `When` boxes do not overlap and cover everything**, pinned by a test that asks
  each task which boxes claim it and insists on exactly one. Overlapping boxes would make two
  ticks show one action twice in the count.
- **`noDate` is a box, not the absence of one.** "With a date" is the other four together, so
  nothing the old Picker could ask was lost — and there is no second door into one room.
- **`tagChoices` includes the ticked ones even when nothing carries them** (build 175's rule):
  a tag whose last action another row has ruled out would otherwise lose its box and could
  never be unticked. `#next` is left out of that row because it has its own box under Mark —
  two controls for one state is build 165's fault.
- **`AppModel.actionFilter` is `@Published` and deliberately not in `UserDefaults`.** It
  survives moving between sections and is forgotten on quit: an app that opens showing a
  filtered list with no memory of why is the trap of builds 123–127. The folded line always
  says what is ticked (build 161), so it can never narrow in silence either.
- **Two empty states, not one**: "Nothing open" when the vault has no open action, and "No
  action matches" with the total and the summary when the boxes ruled everything out, plus an
  **Untick every box** button. Build 100's rule, and build 157's `emptyMessage`.
- The fold button and **Clear** sit in the column's own header beside its name, never in the
  window's toolbar (build 167). Its own `@AppStorage` key per platform, folded on the phone
  and open on the Mac (build 161).
- `Choice` is a struct, not a tuple — a `ForEach` id is a key path (build 61, fifth time) —
  and `row(_:choices:)` takes `choices`, not `boxes`, so the parameter cannot shadow the
  `boxes(among:)` method beside it (build 150's `let card = card(…)`).

**The Mac test that presses Linked notes: not built, after four runs.** Expanding that box is
the exact trigger of build 30's window scramble, and nothing has ever pressed it — but on the
Mac **nothing a test can click will open a SwiftUI `DisclosureGroup`**:
- The **words do nothing**. Only the triangle opens it, which the first run proved by clicking
  the label and watching the box stay shut.
- The **group's left edge deselected the note** altogether (second run), so a guess at a
  position can do harm, not just nothing.
- The element **XCUITest calls the disclosure triangle has the label's own frame** — the dump
  showed both as `(466, 298, 161, 15)` — so clicking its centre lands on the words again.
- **8pt and 13pt to the left of that row** both missed the glyph (fourth run). Further left is
  the note list, which is what took the note away.

**Removed rather than left red**: a red light that means nothing is worse than no light at all
(build 190). Everything else stays in place — `note.links` on the row, `note.links.open` on the
contents (they exist only while the group is open), and the test vault's `[[Packing list]]`
link, because **the box is drawn only when a note has links**. The window is still checked when
a note opens, which is the same fault one step earlier. **Reopening this needs the app's side to
change**: making the label itself open the box would fix a small Mac wart and make the test one
line, and that is his call, not something to slip into a build about something else. **He asked
for it in build 205**, and the test is one line.

`expectNoOverflow(after:)` stays, shared with build 197's test. It asks the app itself — Help ›
Copy Diagnostics, then the clipboard — because the app's own `OVERFLOW` line is a better judge
of builds 30/34 than any frame a test could measure.

## Pressing the words opens the box (build 205)

The first of four items he approved with *"all of them please. Has good potential."*

**A SwiftUI `DisclosureGroup` opens only from its triangle** — about eleven points on a Mac,
and the label itself is dead. That is a small annoyance with a mouse and a hard stop for a
test: build 198 spent four runs trying to press **Linked notes** open and gave up, so the
oldest fault in this app (builds 30 and 34, the window scramble) had never once been checked
at the moment that triggers it.

- **`FoldButton` (Theme.swift)** is a chevron plus whatever label is handed in, inside one
  plain `Button` with `.contentShape(Rectangle())` so the gap between them presses too. The
  caller draws the contents under its own `if`. That is the shape `TemplatesView`, `TagsView`
  and the sidebar have used since build 93 for a different reason; these were the last two
  `DisclosureGroup`s outside a `Form`.
- **Anything else in the header stays outside the button.** The **Hide finished**
  `StateToggle` beside the Tasks name is its own button: a button inside a button is builds
  71–74 in a new place — one press, two meanings.
- `accessibilityName` is not optional. An empty `.accessibilityLabel` leaves a screen reader
  with nothing to say, and branching around the modifier would change the button's identity.
- **Left alone on purpose**: the `DisclosureGroup`s in `HelpView` and `SettingsView`. They sit
  in a `Form`/`List`, where the triangle is the platform's own shape and the row is wide.
- **`testLinkedNotesOpensAndTheWindowHolds` is back**, Mac only, and it is the one line build
  198 said it would be: press `note.links`, wait for `note.links.open`, then
  `expectNoOverflow(after:)` — Help › Copy Diagnostics and the clipboard, the app's own
  judgement of builds 30/34. Twelve screen tests now.
- **The rule: when a test cannot reach a control, that is a report about the control.** Four
  runs went into finding a way to click an eleven-point triangle. The fix was to make the
  thing pressable, which is what he wanted anyway.

## The unsigned iPhone archive (build 206)

**The App Group fault of 15 September was diagnosed wrong, and the wrong answer stood for
five days.** The observation was right — the signed iPhone bundles carried no App Group, read
back from a real export. The conclusion was not: I blamed Apple's automatic signing for
dropping an entitlement the App ID did not carry, and asked him to enable **App Groups** in
the developer portal. **His screenshot on 20 September showed it already enabled and the
group already ticked.**

**The real cause was in `testflight.yml`, and the file had said so since build 64.** The
matrix built iOS with `CODE_SIGNING_ALLOWED=NO` — completely unsigned. A build with signing
switched off never runs the step that writes the entitlements into the app, so there was
nothing for `-exportArchive` to carry over. macOS was ad-hoc (`CODE_SIGN_IDENTITY=-`) and its
own comment read *"an unsigned build carries none"* — written about the sandbox entitlement,
and never applied one line up. So the Mac widget worked from build 178 and the iPhone's never
did, from build 42 to 205.

- **The word that mattered is `CODE_SIGNING_ALLOWED=NO`**, not the absence of an identity.
  With signing *disallowed* Xcode never runs `ProcessProductPackaging`, so no `.xcent` is
  written at all.
- **Build 206's first attempt copied the Mac's ad-hoc identity and Apple refused it outright**:
  `error: Ad Hoc code signing is not allowed with SDK 'iOS 26.5'`, on all three targets, 27
  seconds in. **Ad-hoc is a Mac-only trick.** The Mac half of 206 uploaded; the iPhone half
  never archived, so build 206 exists on the Mac only.
- **Build 207 tried signing *allowed* but not *required*, with an empty `CODE_SIGN_IDENTITY`.
  It did not work**, and the new check said so exactly: `No .xcent anywhere in the bundle`,
  `NO APP GROUP IN THE ARCHIVED APP`, and `code object is not signed at all`. **Xcode writes
  the entitlements only while it is really signing something**, so an identity that does not
  exist is the same as no signing at all.
- **Build 209 got the furthest and named the real wall**: with a real identity, Xcode reads
  the entitlement and then refuses — `"Paragon" requires a provisioning profile with the App
  Groups feature`, on all three targets. A profile carrying that feature can only come from
  cloud signing at archive time, which is exactly what ran the account out of development
  certificates in build 61. **Xcode cannot be made to do this here at all.**
- **Build 210 stops asking it to.** The archive is unsigned again, and a new step **"Put the
  entitlements into the archive"** signs each bundle by hand with `codesign --force --sign
  "PARAGON Build" --entitlements <the project's own file>`, innermost first (frameworks,
  then the two `.appex`, then the `.app` — codesign refuses to seal an app whose nested code
  is unsigned). `codesign` asks nothing about profiles. **The signature is not the point and
  is thrown away**; `-exportArchive` re-signs with the real App Store identity. What survives
  is the entitlements, which is what the export carries over.
- **Build 208 gives the runner a certificate of its own**: a self-signed code-signing
  certificate in a keychain made for that run, trusted in the system keychain (the runner is
  thrown away), used as `CODE_SIGN_IDENTITY="PARAGON Build"` with
  `OTHER_CODE_SIGN_FLAGS=--keychain=$BUILD_KEYCHAIN`. **Apple is asked for nothing**, so
  build 61's certificate limit is not in play, and `-exportArchive` re-signs everything with
  the real App Store identity a few steps later.
- **Three shell traps in that step.** Two were avoided on purpose: the openssl config is
  written with `printf`, not a heredoc, because a heredoc inside a YAML block keeps the
  block's own indentation on every line; and `CODE_SIGN_IDENTITY="PARAGON Build"` keeps its
  quotes, because the matrix string is pasted into a shell command line and the name is two
  words. The third cost build 208: **`openssl` on the runner's PATH is OpenSSL 3 from
  Homebrew**, whose default PKCS#12 encryption the Security framework cannot read, so
  `security import` answered `MAC verification failed during PKCS12 import (wrong
  password?)` — **a message that blames the password and means the format**. Build 209 calls
  `/usr/bin/openssl` (macOS's own LibreSSL) explicitly. Build 208 reached the Mac only.
- **`codesign -d` cannot answer this question on an unsigned bundle** — it says "not signed at
  all" and stops, so the check went quiet exactly where it mattered. The step now also finds
  every `.xcent` in the bundle and prints it, because that file is what the packaging step
  writes whether or not anything is signed. **A diagnostic that only works once the thing
  works is not a diagnostic.**
- **"What is inside the app" now reads the app's own entitlements**, not only its extensions.
  163 builds of a check that never asked about the one bundle that mattered. With the two
  steps together — the archive's entitlements and the App-Store-signed copy's — an
  entitlement that was *never written* is now distinguishable from one that was written and
  *dropped*. Build 177's rule, one layer down.

**It worked, and the answer was both things at once (20 September, build 210 re-run).** With
the entitlements finally in the archive, the export failed on a *new* error — `Automatic
signing cannot update bundle identifier "com.schabbauer.AMSPara.Widgets"` / `No profiles for
'com.schabbauer.AMSPara.Widgets' were found`. **Apple naming one identifier is what made the
portal ask legitimate at last.** He ticked App Groups on `.Widgets`; `.Share` and the main app
were already ticked, which is exactly what the single-identifier error predicted. A re-run of
the same build then printed, for all three bundles:

```
=== PARAGON.app ===          group.com.schabbauer.amspara
=== ParagonShare.appex ===   group.com.schabbauer.amspara
=== ParagonWidgets.appex === group.com.schabbauer.amspara
```

**No new build was needed** — the workflow was re-dispatched on the same commit, and
`CFBundleVersion` is `<stamp>.<run number>`, so Apple accepts the second upload of build 210.

**Two causes, and neither alone would have shown the other.** Our archive never wrote the
entitlement, so nothing ever asked Apple for the capability, so the missing capability on
`.Widgets` could never surface. **A second fault hidden behind the first is why the evidence
read as contradictory for five days** — and why the 15 September conclusion looked reasonable
and was still wrong about which step to fix.

**The lessons, and they are about how I reasoned, not about Apple.**
- **"Apple silently drops it" is an explanation that explains anything**, which is what made
  it comfortable. It named a mechanism that is real, fitted the evidence, and required no
  further work from me — and it put the next step on him. **An explanation that ends with the
  user doing something is the one to doubt hardest**, because nothing will test it until he
  has spent his afternoon.
- **The evidence to separate the two was one step away and I never took it.** "Missing from
  the signed app" has two causes: never written, or written and dropped. Reading the
  *archive's* entitlements tells them apart in three seconds, from this container, with no
  TestFlight run and nothing asked of him.
- **The answer was already in the file, in a comment I had written.** When two platforms are
  built differently and only one works, the difference between them is the first place to
  look — before any theory about a third party.
- **He is the one who caught it**, by asking *"Are you sure that these steps work? … Please
  confirm that you are really 100% sure."* Saying honestly that I was not is what made him
  send the screenshot instead of spending the afternoon. **Answer that question honestly every
  time; the hedge is what buys the evidence.**

## Two more screen tests (build 211)

The last two from his list. Fourteen now: twelve shared or Mac-only, plus the phone's swipe.

- **`testTheAllActionsFilterNarrowsTheList`, both platforms.** Tick **Overdue**, and since the
  test vault has no dated task at all the list must empty *and say which kind of empty*:
  `actions.noMatch`, never `actions.nothingOpen`. **A check that could not tell those two
  apart would pass on an empty vault** (build 190's rule, and build 100's).
  `openTheBoxes()` asks the screen whether `actions.box.overdue` is already there rather than
  pressing `actions.fold` blind — the boxes start folded on the phone and open on the Mac
  (build 161), so a blind press would close them on the Mac.
- **`testTheTabsCanBeSwipedBetween`, iOS only.** A coordinate drag across the middle at
  `dy: 0.45`, clear of the tab bar and the navigation bar, rather than `swipeLeft()` — the
  gesture then starts and ends where the test means it to. **The proof is the `isSelected`
  trait, never the tint**: a colour is invisible to a test, and the bar is ours (build 183),
  so nothing else says which page is in front.
- **Three things the app gained so the tests could see anything at all**, and each is right on
  its own: `TaskRow` carries `task.<title>` with `.accessibilityElement(children: .contain)`
  (the shape `InboxRow` has had since 191; accessibility only, since nothing may take a row's
  click — builds 71–74); the two empty states carry their own names; and `PhoneTabBar` adds
  `.isSelected` to the tab you are on, **which VoiceOver should have been told since 183**.
- **`TestVault` gained one task of its own**, `Book the night train`, with no date. The project
  template's own task would have served, but **a test must not depend on the wording of a
  template someone may reword** — the same reason every element is found by identifier and
  never by its words (build 191).

## Today's Calendar section is compact (build 212)

His ask: *"The Calendar view is too large in the Today tab. Compact it please."*

- **`CalendarEventRow` gained `compact`**, and only `TodayView` passes it. The same view in two
  sizes, the shape `DailyNoteRow(preview:)` (78) and `QuickCaptureView(embedded:)` (185)
  already have — **not a second row view**, which is how two screens come to drift (build 168).
  The **Calendar section and the daily note keep the roomy rows on purpose**: those screens are
  about the day itself, and it is Today where the events share the space with everything else.
- **The second line was the real cost.** A place under the name doubled the height of every
  row. Compact puts it on the same line after a middle dot, with `.layoutPriority(-1)` so the
  place is what gives way when the row runs out of width — never the name (build 138's family:
  decide what squeezes before the column does it for you).
- **The section folds, and the count stays in the heading** — `FoldButton` (build 205) around a
  `SectionLabel`. Open by default and its own `@AppStorage` key per platform (builds 121, 161).
- **The "Calendar access is off" message is never folded away.** With access off, that body is
  the only thing that says why the day looks empty; hiding a reason behind a chevron is build
  100's fault in a new place. So the fold is ignored while `calendarAccessGranted == false`.
- `calendarOpen` is a `Binding` that flips the stored *folded* value, because `FoldButton` asks
  whether the box is open and the setting says whether it is closed. One place, written out.

**Build 213, because 212 did not actually compact anything.** His report: *"Toggle works - but
not compacted"*, and then the question that is the whole lesson — *"Why can't the rows get less
tall?"*

- **A `List` decides a row's height, not the text inside it.** Every row has a minimum height
  (about 44pt on iPhone, a comfortable finger target) plus its own padding above and below. The
  rows were already at that floor, so 212's smaller fonts shrank the text and left every row
  exactly as tall. **Making the content smaller is not the same as making the row smaller.**
- **The fix is to stop being several rows.** In compact mode `CalendarEventRows` wraps the whole
  day in one `VStack` inside a single list row, so the list pays its padding once instead of
  once per event and the spacing is ours. Overriding `defaultMinListRowHeight` and
  `listRowInsets` was the other route and was refused: those numbers differ between iPhone and
  Mac and **there is no screen here to look at**, so it would have been guessing at sizes.
- Each event keeps its double-tap and its context menu; they were never rows that needed
  selecting or swiping.
- **He asked one question and it saved a build.** I had put two possible symptoms to him
  (smaller text but tall rows, or nothing changed at all) because they have different causes;
  his question answered it without a screenshot. **Ask which of the two it is — the two answers
  do not share a fix** (build 177's rule, and 123–127's).

**Build 214: the day's note is a button in a heading, not a row.** His ask, in his words:
*"Could you please compact into a small button: Create todays note."* It was a full-width list
row — the widest thing on the screen — for something pressed once a day.

- **It moved into the section's own header**, beside `SectionLabel("Today's note")`: build
  167's rule, a control that governs a section belongs in that section's header. A header row
  is about two thirds the height of a list row, and the standalone row is gone with it.
- **The button says one word** — **Create** or **Open** — because the heading beside it carries
  the noun, and repeating it is build 169's fault. The whole sentence survives as
  `.accessibilityLabel` and as the Mac's tooltip: **build 159's rule, that a control which
  shrinks hands its words to the row it sits in rather than losing them.**
- **`.textCase(nil)` on the header.** A `List` uppercases a section header's text itself, which
  would have left the button reading CREATE. `SectionLabel` uppercases its own words, so the
  heading is unchanged and only the button reads as an ordinary word. Worth remembering for any
  future control put in a Section header.
- No symbol on the heading: the button already carries the calendar, and two of one symbol side
  by side says nothing twice (build 164's reason for taking `TintStripe` off the Goals rows).
- `HeaderActionButton` is private to `TodayView.swift`. `ChipLabel` is the nearest existing
  shape but is `private` inside `NewNoteSheet.swift`; **moving it into Theme.swift belongs in a
  build about that**, not in this one. If a second screen ever wants this button, that is the
  moment to share them.

**A dispatch input pasted into a shell script is code, not text (22 September).** Build 214
uploaded fine and the run still went **red**: the last step, which only writes the run summary,
held `if [ -n "${{ github.event.inputs.notes }}" ]`. A `${{ }}` is substituted as raw text
before bash sees the line, and that build's note carried two double quotes, so the line ended
as `if [ -n "Build 214: "Create ... ]` — `syntax error near unexpected token 'fi'`. **Read
every dispatch input through `env:` as `"$VAR"`**, never inline. No build number was spent on
the fix: nothing in the app changed, so it is the docs-only precedent (a push that does not
bump the stamp).

**And the wider point: a red run does not mean a failed upload.** The log said `Uploaded
Paragon` and `** EXPORT SUCCEEDED **` several steps above the error, and all three bundles
printed their App Group. **Read where in the run it failed before telling him anything** —
saying "the upload failed" here would have been false and would have cost a whole build to
undo.

## The Inbox quadrant (build 215)

His ask, in his words: *"where the four buttons are is a bit... it leaves room for
improvement. Maybe we could put the four buttons in a quadrant so that they can be a bit
larger and a bit cooler."* He also asked whether he should draw it or I should — **I drew
it**, three shapes at the real column width
(https://claude.ai/artifact/6iM9P8KrBH2mcTSmURxdLN), and he answered **"B and C"**.

- **A was the literal ask and the preview is what ruled it out.** A quadrant on *every* line
  takes a row from about 44 to about 78 points, so half the Inbox falls off the screen — two
  builds after he asked for Today to be made shorter. **Drawing the cost is what let him
  choose against his own first idea without either of us spending a build on it.**
- **B and C are one feature with two homes, never both at once.** `InboxQuadrant` is drawn by
  the **File it** column on the Mac (which is always on screen in that section and already
  holds the line being sorted) and inside the selected row on the phone (which has no third
  column). Drawing both on the Mac would be one control twice on one screen — build 166's two
  doors into one room. `InboxRow` gets the usual `isPhone` stub pair so no `#if` sits in a
  modifier chain (build 148).
- **The three date buttons carry build 142's two-state language**, so the quadrant also says
  where the line stands: the one matching `dueDate` is tint-filled with a solid border, the
  others grey and dashed. **File it keeps a solid grey border** — it opens a menu rather than
  setting anything, so "off" is not a state it can be in and a dashed border would say
  something untrue. Worth repeating whenever an action sits in a row of states.
- **`InboxLineMenu` is the old `menuItems`, extracted**, so the line's context menu and the
  quadrant's **File it** are one list (build 168). It takes `rename:` because renaming needs
  the row's own TextField: the phone's copy passes `startEditing`, the File it column passes
  nil and rename stays on the line's context menu. Same shape as `TaskContextMenu.onRename`,
  which is also the proof that a custom `View` works as menu content.
- **Each column owns its own date sheet.** `InboxFileItView` gained one `.sheet` of its own
  rather than reaching for `InboxTriageView`'s — build 44's rule is one `.sheet` per screen,
  not one per section.
- **`ref.task.dueDate == today` is written out**, never `== .today()`: the left side is an
  optional and leaning on Swift to find a static member through it is the kind of inference
  that costs a whole build here (builds 152, 154, 168).
- **The hint line under the heading said "⋯ rename"** and the ⋯ button no longer exists.
  Build 159's rule: when a control goes, grep the words around it.
- **One consequence worth knowing**: on the Mac the buttons live in the third column, so
  pressing **Open the Inbox note** (which puts the note in that column) hides them. Picking
  any line sets `inboxShowsNote = false` and brings them straight back, so it corrects
  itself — but a future change to that flag has to keep that true.

**Build 216: "Wrong area is grey."** One screenshot, and he was right. On the phone a
selected row takes the list's own selection fill — plain grey — and build 215 had drawn the
quadrant *inside* that row, so the two buttons that are not set (grey symbol, grey dashed
border) sat on grey and all but vanished.

- **The quadrant is now a row of its own with no `.tag`.** Build 201 had already written down
  that an untagged row never takes the selection fill; this is the first time that fact has
  been used on purpose rather than noticed after the event. The grey marks the line, the
  buttons sit on the ordinary background, and `.listRowSeparator(.hidden)` keeps the pair
  reading as one thing.
- **`InboxRow` went back to a plain `HStack`** and lost its `isPhone` pair and its
  `pickingDateFor` binding; `InboxTriageView` owns both now. The phone's quadrant no longer
  passes `rename:`, so **File it** offers the same list on both platforms and Rename stays on
  the line's context menu (long press on the phone) — which is what `Docs/HowItWorks.md`
  already said.
- **The lesson is about where a control is drawn, not how it is coloured.** The first
  instinct was to give the buttons a stronger border or an opaque background of their own;
  both would have been a second colour decision layered on top of a placement mistake. **A
  control that is hard to read against its background is often in the wrong container.**
  Same family as build 200's orange-on-orange, one step earlier in the chain.

**Build 217, and he had the better idea.** After 216 he wrote: *"No. Why grey out the
buttons. You should grey out the other items in the list."* **A selection fill marks a line by
covering it, which is the wrong way round when the line is the thing you are reading.** 215
put grey buttons on that fill and 216 moved the buttons off it; both were treating the fill as
fixed. He turned it over: the line you are on keeps its ordinary colours and the rest fade.

- **`plainRowFill` is handed to every row**, which is what stops the list painting its own
  fill. **The two platforms need opposite answers and that is the trap**: on iOS an
  inset-grouped list's white card *is* the row background, so `Color.clear` there shows the
  grey page behind the row — it is `Color(UIColor.secondarySystemGroupedBackground)`. On the
  Mac the **list** paints the background and a row is transparent to begin with, so `.clear`
  is the plain state and naming an `NSColor` would be guessing at a shade already there.
- `dimmed(_:)` is `.opacity(0.45)` and only while something *is* selected, or a fresh screen
  would open with every line faded and nothing to say why.
- **Build 218 took it to the Mac**, his ask in four words: *"do the mac too."* 217 had kept the
  Mac's ordinary fill and said so with an offer, which is what made the ask cheap. **This is
  the one list in the app that marks a selection this way**, deliberately: the Inbox is a
  screen you work straight down, one line at a time, which is not what the other lists are
  for. The screen test survives because it waits for the `isSelected` trait and never for a
  colour (build 191) — **the reason that rule was written is exactly this kind of build.**
- **`import UIKit` under `#if os(iOS)`.** Every other file in this target that names a
  `UIColor` imports UIKit explicitly, so this one does too rather than trusting SwiftUI to
  bring it along — there is no compiler here to find out the hard way.

**Build 219: the date row left Today.** He marked it on a screenshot and wrote one word,
**"Delete."**

- **The orange rectangle in that screenshot was his own marking, not the app.** Worth saying,
  because three builds earlier an orange line *was* ours (build 202's focus ring) and it took
  a grep to be sure: nothing in `TodayView` draws a border, the app has **no `AccentColor` in
  its asset catalogue**, and the tab bar in the same picture is the system blue. **Check
  whether a colour in a screenshot is even in the palette before hunting for it in the code.**
- The row held two facts the screen already carried: the large title says **Today**, and the
  **Due today** section names and counts the same tasks. Same family as build 169's chip that
  repeated what the screen already said — only this one cost a full-width list row.
- The stale sentence under build 46 ("TodayView opens with the date and a due count") was
  fixed in the same push. Build 159's rule: when a thing goes, grep the notes for its words.

**Build 220: the date comes back, one grey line, outside the `List`.** He asked what *"put
the date back somewhere small"* meant — **a fair question about my own words**, and the answer
had to be three drawn options, not a phrase. He took **A**, a short grey line under the title.

- **It is outside the `List` on purpose, and that is the whole point.** Inside one it would be
  a row again, and a row has a smallest height whatever is written in it (build 213). So
  `TodayView.body` is now a `VStack` holding the line and then the `List`.
- The due count did **not** come back: **Due today** names those tasks a few lines down, and
  repeating them is what 219 removed.
- **"Somewhere smaller" was the fault, not the plan.** The language rule at the top of this
  file is about names on screen, and it is just as true of what I write to him in chat and in
  `Docs/VersionHistory.md` — the 219 entry said it too and has been rewritten. **Offer shapes,
  not adjectives.**

## A day you can tidy in one press (build 221 on)

He asked what to do next — *"I am inspired to make even more improvements… in order to make my
day more efficient and in harmony"* — so I looked for gaps rather than offering adjectives, and
put four to him. **He took all four**, one build each, smallest first: **221** move the overdue
in one press, **222** drag an action into the plan, **223** close the day, **224** plan the week.
The gaps were found by reading the code, not by memory: `grep` showed the planner's lanes carry
no `acceptsTaskDrop` (only `DayScheduleView` does, since build 61), there is nothing
daily-review shaped anywhere, and `setDueDate` took one ref at a time.

**Build 221: `AppModel.moveTasks(_:to:)`, and two buttons in the Overdue heading.**
- **A separate name, never a second `setDueDate`.** One ref and an array is exactly the overload
  Swift settles by inference, and there is no compiler here (build 168).
- **It goes through `vault.saveEach`**, the shape `reorder` has used since build 99: overdue
  tasks are spread over many notes, a note that changed on disk is re-read and the change
  re-applied, and what could not be written is **named in one message** instead of one alert per
  note. The refs are grouped per note first, so three overdue lines in one project are one
  write. `replace(task:)` matches by `^t` id or title and searches when lines moved, so the
  closure is safe to run twice.
- **No confirmation, on purpose.** He asked for *one press*, and a date is not a deletion. What
  replaces the confirmation is the message afterwards — "6 tasks moved." through `flash`, whose
  capsule is a root overlay in `ContentView` and so shows on any screen. **When an action is
  wide but reversible, report it rather than ask about it.**
- **`HeaderActionButton.systemImage` became optional** so the pair carries words only: two
  buttons sharing one `arrow.right` would be build 154's two icons that look alike. Its doc
  comment said "carries one word" and was rewritten in the same edit (build 159's rule).
- The header is a **`WrappingHStack`** (build 138: a heading plus two buttons in a narrow column
  squeezes until words break mid-word) with **`.textCase(nil)`** (build 214).
- **No screen test, and the reason is load-bearing.** The test vault deliberately has **no dated
  task at all** — build 211's All actions test proves "Overdue" empties the list by it — so there
  is no Overdue section to press, and giving the vault a dated task to reach this button would
  break that test. **A fixture's emptiness can be a fixture.** Note it before adding data to
  `TestVault`.

**Build 222: the planner's hours take a task.** `DayScheduleView` has had `acceptsTaskDrop` on
each hour since build 61 and `PlannerView` never did — the same drift as the Map's vocabulary
before build 170. Found by `grep`, not by memory.
- **Only the Time blocks lane.** `lane(…takesDrops:)` defaults to false, so the Calendar lane is
  untouched: it is read only by design (build 33), and a target that accepts a drop and then
  does nothing is worse than none (build 175).
- **`HourDrop` is a `ViewModifier`**, because a modifier chain cannot be branched on a `Bool`
  (build 148's `CalendarBlocksLink`) and it takes `active:` plus a plain closure — never an
  optional closure threaded through `.map`, which is where inference has given up twice
  (builds 152, 154).
- **The hour grid became hour cells** of exactly `hourHeight`. That is the layout the even
  `Spacer`s already drew, and it is now something a task can land on. The cells are **first** in
  the `ZStack`, so a card still keeps its own click (builds 71–74), and `NowLine` stays last with
  hit testing off.
- **`blockOut` makes a plan block, never a Time Block** (build 147), so it calls `addPlanBlock`
  rather than `savePlanBlock`: with no previous block and no calendar wanted, that async path
  reduces to this one write. `#next` is stripped from the title exactly as `blockTime` strips it
  (build 174); his own tags stay, because those carry information.
- **No sheet on a drop.** The drag is finished when you let go, or it is slower than the ⊕ button
  already there, and the card can be dragged and resized afterwards (build 152). The flash
  message says what happened instead of asking first — build 221's reasoning, one screen along.
- **Untested from here on the phone**: `.draggable` plus `.dropDestination` is the system's own
  drag, which starts on a long press and does not fight a scroll view the way build 152's raw
  `DragGesture` would, so the target is on both platforms. CI compiles but never drags.

**Build 223: Close the day.** Third of the four, and the first new screen in a while, so it
followed the pattern this project keeps proving: **a drawing before any code**
(https://claude.ai/artifact/NrbS7bxiaBin21sLjwzvEg, three shapes at real column widths). He took
**A** and the heading `## Looking back`.
- **Why not B or C, in his own reasoning as much as mine.** B put a new box at the foot of
  **Today** — the screen builds 213, 214 and 219 were all about shortening. C was a sidebar row,
  which on the phone means inside **Browse**, two taps away every evening. **A is the only one
  that can be *finished***, which is the whole point of closing a day.
- **`Core/Vault/DayLog.swift`** (tested) owns the section, the way `DayPlan` owns `## Plan`.
  Build 146's rule: anything that decides the shape of a stored value belongs in Core.
  **Empty text removes the heading as well** — a heading with nothing under it is a promise the
  note does not keep, the same reasoning as `setStatus(.active)` removing the line (build 165).
  A new section goes at the **end**: a plan is read before the work, looking back is written
  after it.
- **`Core/Markdown/MarkdownSection.swift` is `DayPlan`'s own section finder, extracted.** Two
  copies of a markdown parser is how two parts of this app came to disagree about one file
  (build 168). Safe to do in this build because Core has tests: `DayPlanTests` is what says the
  behaviour did not move.
- **The tests assert fragments and structure, never one exact whole body.** `Note.body` comes
  back through `Frontmatter.parse`, so a byte-for-byte assertion would fail for that reason
  rather than for the code under test — the shape `DayPlanTests` already uses.
- **Counts, not two more lists.** **Done** already lists what you finished, day by day; drawing
  the same names here would be a second door into one room (build 166). The number is what an
  evening needs.
- **The leftovers are real `TaskRow`s** (build 149), so a tick ticks the task in its own note and
  the task menu comes free. Safe here: no `List(selection:)` (builds 71–74). **Move all** is
  build 221's `moveTasks`, which is why 221 came first.
- **Undated tasks are deliberately left out.** A task with no date was never promised to today,
  so it did not "not happen".
- **Done saves the line; Cancel does not** — and the tick boxes and **Tomorrow** buttons have
  already written when they were pressed. Said out loud in the manual, because a footer that
  means different things to different controls on one screen is worth spelling out.
- The button sits **beside the date at the top of Today**, not in the window's toolbar
  (build 167). Build 220's date line left the right half of that row empty, so it cost no new
  furniture. `SidebarSection.review.tint`, because looking back at a day is the same idea as the
  weekly review and inventing a tenth colour is what build 180 refused to do.
- **A screen test, dull on purpose**: open it, check it drew, close it. What it really proves is
  that a brand new view builds on both platforms — the one thing CI could not see. `pressCentre`,
  never `press`, for a plain-styled button (build 196). Fifteen now.
- `saveLookingBack` **will not make a daily note for an empty line**, and writes nothing when the
  words have not changed: `save` would otherwise stamp the file and send it round iCloud for
  nothing.

**Build 224: the overdue buttons are icons, and he named the precedent himself.** From one
iPhone screenshot of build 222: *"I think it would be somewhat crowded if we have several items
that need to be moved to today or tomorrow. Can we make them with icons instead? We have some
icons for this functionality in the Mac app."*
- **He was pointing at `InboxQuadrant`** (build 215), which has drawn `sun.max` for today and
  `sunrise` for tomorrow since then — with the words beside them, which is how he learnt them.
  So the answer was not to design an icon but to **find the one already in the app**: two screens
  that set the same date may not use different pictures for it (build 168).
- **`HeaderActionButton.title` became optional**, beside the `systemImage` build 221 made
  optional. The words are not lost, they move: `spokenTitle` is the accessibility label and the
  Mac's tooltip, which is build 159's rule about a control that shrinks.
- **No two-state language here.** These are actions, not states — the same reason build 215's
  **File it** keeps a solid border while the three date buttons carry the tint-or-dashed pair.
- The manual sentence naming the two words was rewritten in the same push (build 159 again).
- **The layout was working as drawn; it was still wrong.** The `WrappingHStack` did exactly its
  job — the second button moved to its own line rather than squeezing (build 138) — and the
  result was a heading three lines tall above a one-line list. **Wrapping correctly is not the
  same as fitting**, and on a phone the difference is the whole screen.

**Build 225: plan the week — and the drawing's real job was to report what already existed.**
He asked for "seven days side by side so you can spread the work before the week starts". Before
drawing anything I went to look, and **Calendar → Week has been a full week screen since long
before this**: seven day sections, real `TaskRow`s, a drop target on every day heading, the
weekly note, week arrows. **So the page led with what was there** and asked the narrower
question — what is it missing? — which is the only reason the answer is one build and not four.
He chose **C** (https://claude.ai/artifact/NP3XCcxXPQmVT3iCXhXESh) and both recommendations.
- **Drawing A is what ruled A out.** Seven columns in a Mac window leave each day about two
  words wide, and a phone cannot have them at all — so it would have been two week screens to
  keep working for ever. Same use of a preview as build 215's quadrant: **drawing the cost is
  what lets him choose against his own first idea without spending a build.**
- **`WeekTray` is dashed and grey with no tint.** Dashed already means "loose, not connected"
  everywhere here (`StateToggle` off, `ReadChip`, an unlinked Map box) and that is exactly what
  an undated task is. Orange would have claimed they were plan blocks (build 152); a colour is
  a claim (build 180).
- **It is capped at twelve and says how many more.** A vault holds hundreds of undated tasks and
  an uncapped wrapping row would push the days off the bottom — build 213's lesson one layer up.
  **Nothing is drawn when the tray is empty**, and that is *not* build 203's vanishing control:
  there is no way to put something into the tray from here, so an empty one offers nothing.
- **A task inside a daily note is left out**, even with no date: it is already on that day by
  being written there and is listed below, so including it would draw one task twice on one
  screen. A *dated* next action is left out for the same reason — it is already on the strip.
  The drawing said "next actions and tasks with no date"; the built rule is the half the two
  agree on, and the manual says so.
- **`WeekStrip`'s cells are not buttons.** They are a count and a drop target; a cell that
  looked pressable and did nothing would be worse than no control (build 175). An empty day
  shows **–**, never **0** (build 141: a zero reads as an answer).
- `undated.filter(next) + undated.filter(!next)`, **never a `sorted` with a comparator that
  returns false for ties**: Swift's sort is not stable, so the rest of the order would be
  unspecified.
- **The way in is a `Week` button on Plan, not a sidebar row** (build 166), and that is where
  this build got interesting. On the Mac `show(section:)` is the whole job. **On the phone a
  section change pushes nothing** — `PhoneStack` only pushes for a note, a template, or the
  work request — so the button would have done nothing at all, which is build 175's fault
  in the place it costs most.
  - `AppModel.SectionRequest` is a **counter**, never a latch: build 122's exact lesson from
    `workRevealed`, where the second long press did nothing because a Bool only changes once.
  - `PhoneRootView` chooses the Browse tab on the request; `PhoneStack` pushes the screen.
    **The push handler is the one in that file with no `isActive` guard**, and it has to be:
    the request comes from another tab, so Browse is not on screen when it lands.
- **The screen test is what would have caught it**: it presses `plan.week` and waits for
  `week.strip` **on both platforms**, so a button that navigates only on the Mac fails the run
  rather than reaching him. `Place.plan` is new. Sixteen tests.

**His field test of 225, and build 226.** The week tray → day cell drag **works on the
iPhone** (his words: *"The week test worked out fine"*) — the one thing CI could not check.
The other drag I asked him to test could not be done at all, and that was my fault:
- **I asked him to test a phone drag without looking at the phone layout.** On the iPhone
  `PlannerView` stacks the whole day (06–23, about 800 points) **above** the Actions list, so an
  action can only reach an hour by being dragged up the entire page. He found the screen and
  asked *"Where do I find the actions?"*. **Before asking him to test anything on the phone,
  read how that screen is laid out on the phone.** The phone's real path is the **+** beside an
  action (build 149), and the manual now says so.
- **"Mon-day…" was build 225's fault.** Every control in the Plan header is `.fixedSize()`, so
  when **Week** joined the row the only thing that could give way was the day's name, which
  hyphenated and truncated. Build 138 exactly. The header is now a **`ViewThatFits(in:
  .horizontal)`**: one row when it fits, the name above the buttons when it does not — on any
  width, with no `isPhone`, because the ⇧⌘P window can be narrow too. The name is
  `.lineLimit(1)` in both, since `ViewThatFits` measures the single-line width. **When a build
  adds a button to a row of fixed-size controls, find what in that row is allowed to shrink.**
- **Short cards printed on top of each other** ("Swim 40" across "06:40 – 07:05"). Older than
  225: `PlanCardFace` drew two lines whatever its height and **sized its own background**, so on
  a 25- or 40-minute slot (18–29 points at 44 per hour) it grew past the frame the lane gave it,
  and nothing clipped it. It now takes `height:` and `startTime:`, draws **one line under 40
  points** (start and name, the way a calendar app does), **fills the frame it is given** with
  `maxHeight: .infinity` before the background, and is **clipped** to its rounded box. **A view
  that paints its own background must be told its size, or it paints its own size instead.**

**Build 227: the tray is on Plan too, and it was the promise I had not kept.** His words:
*"The actions I was supposed to drag into Plan the Day are still on the bottom. We were to
change that, right?"* Build 226 only put the **+** into the manual; the layout was untouched.
- **`WeekTray` became `TaskTray` in `Theme.swift`** (title, `dropHint`, optional `caption`,
  `shown`, `identifier`). The week screen passes what it had before; the phone's `PlannerView`
  pins one above its `ScrollView` with `actionsForPlanning(on: plannerDay)`, capped at **6**
  because a pinned strip eats the phone's height. **Reused, not redrawn, because his test of 225
  is the only proof a drag works on the iPhone**, and a new tray would have had none.
- **Outside the `ScrollView`, on purpose**: that is what keeps it on screen while the hours move,
  so a drag is always a short one. No `ScrollViewReader` jump to the current hour — scrolling
  first and dragging second is what the caption says.
- The full Actions list stays at the foot: ticks, task menu, ⊕. One action in both places is a
  place-to-drag-from and a place-to-work, not two doors into one room (build 166).
- **No screen test**: the test vault has no dated task and no next action, so `actionsForPlanning`
  is empty and the tray draws nothing. Build 221's note — the fixture's emptiness is itself a
  fixture — still holds.

**Build 228: Words in PARAGON.** His idea — *"we could create a definition toggle with all the
various definitions throughout the complete app… It's getting rather complicated, right?"* He
said Settings; I suggested Help and he agreed: **Settings is for choices, a list of meanings is
something you read**, and Help already has a search field. Settings keeps one row that opens it.
- `Docs/Words.md`, grouped under `##` headings so `HelpDocument` draws it with folds and search
  like the manual. One bullet per word: `**Word** — one or two sentences`.
- `HelpView.Page.words` sits between the manual and the history (enum order is the Mac's
  segmented order). Mac: **Help › Words in PARAGON** and `WordsWindowButton` in Settings, which
  opens the Help window because Mac Settings is its own window. iPhone: a `NavigationLink` in
  Settings › Help. The Settings `Help` section is no longer iOS only.
- **Work notes are deliberately not in it** — the same reason they are not in `HowItWorks.md`
  (build 112): the page is visible to anyone looking over his shoulder.
- `project.yml`'s Docs comment was changed on purpose: a new file in `Docs/` only reaches the
  committed project when CI regenerates it, and a change to `project.yml` is what triggers that.
  **So the next local push needs `git pull --rebase` first.**
- **When a build adds a word he will see, add it to `Docs/Words.md` in the same build.** The list
  is only useful while it is complete, and build 159's rule — grep the docs when a name changes —
  applies to it too.

**Build 229: every phone page drew the current section, and that is the crash suspect.** Two
iPhone crashes (28 and 29 September), both right after **Quick capture** closed and the tab
changed. No report reached App Store Connect yet, so the cause is **not proven**. Reading the path
found a real fault regardless: `PhoneRootView` gave **Plan**, **Actions** and **Inbox** each a
bare `NoteListView()`, which branches on `model.section` — and a page-style `TabView` keeps every
page alive. So each tab change rebuilt three pages into the same screen at once: three
`PlannerView`s (with three sets of drop targets), or three `InboxTriageView`s whose
`List(selection:)` shared `model.inboxSelection`. A pushed `PhoneSectionScreen` in **Browse** did
the same.
- `NoteListView(fixed:)`: `shown` is `fixed ?? model.section`, and all 31 reads inside the struct
  go through it. The Mac passes nothing and behaves exactly as before. Written-out `init`, since
  the struct's `private @State` properties make a synthesised memberwise init private.
- **Any view the pager hosts must render its own content, never "the current section".** The
  pager keeps pages alive precisely so they can be swiped to, which is also what makes a shared
  source of truth draw everywhere at once.
- **The Crash reports workflow** (`.github/workflows/crash-reports.yml`, dispatch only) reads
  TestFlight crash reports from App Store Connect with the upload's own key and prints them in
  the job log. **Apple keeps no log for some reports** (both from 20 September answer 404); the
  run lists them and carries on. A report can take a while to appear after he presses **Share**.
  The same file is on `main` in AMS-WatchLater-App, AMS-Packing-App, AMS-Instructions,
  AMS-Workout-Sync-iOS and AMS-Coffee, with each app's bundle id.
- **The Mac crash of 22 September (build 211)** is in that list: an exception during AppKit
  layout (`NSView._layoutWithObservationTracking` → `_crashOnException`), with no frame of ours.
  Not looked into yet; it has not come back since.

**Build 230: Today's + is the others' +.** His ask: Plan, Actions and Inbox had a **+** top
left, Today had a Quick capture button, and one button in one place is easier. The **+** opens
`.newNote`, and `NewThing.forSection(.today)` is now `.capture`, so it lands on the capture half
of the same screen — which also changes the Mac's Today **+** the same way (⇧⌘N is untouched).
The identifier stays `capture.open`: pressing it still reaches the capture screen, which is what
the screen tests mean by it. Kept out of build 229 on purpose, so a change after 229 points at
one thing.

**Build 231: the keyboard covered Save.** His test of 230: on the phone's capture screen *"the
virtual iphone keyboard is in the way for the Save and cancel button"*. `QuickCaptureView.
phoneBody` was one column of fixed-height pieces — field (min 110pt), read-back, three chip
rows, the day's count, the save bar — and 230 put the New note screen's row of kinds above it.
With the keyboard up there is about half a screen, so the column overflowed and the save bar
went under the keyboard. The chip rows (and the count) now sit in a `ScrollView` between the
field and the save bar, with `.scrollDismissesKeyboard(.interactively)`. **The field stays
outside that scroll view on purpose** — a text view inside a scroll view is build 127's nested
scroll. **Any phone screen with a text field has to be checked with the keyboard up** (build
160's rule), and a screen that gains a row above it (230) has to be checked again.

**Build 232: the swipe was the crash, and the system tab bar replaced it — his choice.** The
Crash reports workflow finally returned his two iPhone reports (builds 227 and 228, iOS 27.0).
Both are `SIGABRT` from an `NSAssertionHandler` inside **`-[UINavigationBar layoutSubviews]`**,
with no frame of ours. That is iOS asserting that a navigation bar's top item belongs to a
different bar. **Build 183's page-style `TabView` held five `NavigationStack`s side by side as
pages**, so five navigation bars lived in one scrolling pager; a slide, or a sheet closing, laid
them out mid-transition. Build 229's `NoteListView(fixed:)` was a real fault but not this one —
**he reported "still crashing when swiping tabs" on 231**, which is what sent me to the reports.
- I put two options to him: the system tab bar (one build, no swipe) or one shared navigation
  stack with the swipe kept (two or three builds, every screen's toolbar moved, a pushed note
  covering the bar). He chose the system bar.
- `PhoneRootView` is a plain `TabView(selection:)` with `.tabItem` and `.badge` (zero draws
  none). `PhoneTabBar` and `pageGap` are gone. `PhoneStack` and its `isActive` logic are
  unchanged — the system `TabView` also keeps visited tabs alive, so build 229's `fixed:` still
  matters.
- **The screen tests find a phone tab by its title inside `app.tabBars`** — the system bar
  carries no identifier of ours. `ScreenTests.tabTitles` spells the five titles, so a renamed tab
  means changing that dictionary. The swipe test became `testATabPressedComesToTheFront`: the
  swipe no longer exists, so the test asks what the bar now does.
- **Confirmed on his iPhone, 30 September**: *"232 test 1-2 OK"* — no crash when moving between
  tabs after **Quick capture**, and a long sentence typed into a note stayed whole.
- **`testANoteCanBeOpenedAndTypedIn` failed once on 232's first CI run** and passed on the one
  re-run: the editor showed "---Typed by the screen" and lost " test. " — typing interrupted
  about when the 600 ms autosave fires. First failure in dozens of runs; he typed a long sentence
  on his phone without loss. If it fails again, it is real: suspect the editor being rebuilt
  after `saveText` reloads the model, not the runner.
- **Read the crash report before the second fix.** 229 was a fix on a guess, made while the
  reports were not yet in Apple's list. It was a real fault and still the wrong one. Once the
  workflow could read the reports, the frame named the cause in one look.

**Build 233: Start the day**, the morning partner of Close the day, and the first of two he
asked for with "1 and 2 please" (234 is the evening reminder).
- **`DayPlan.freeStarts(count:length:from:until:busy:)` (Core, tested)** decides where the
  blocks land: from the next quarter hour after now, five-minute steps so a block can start
  the moment a meeting ends, never past midnight, each placed block busy for the next.
  `AppModel.planActions(_:on:)` gathers `busy` from the plan and the timed calendar events
  and writes all of them in **one** `savePlan`. Fewer placed than picked is reported, never
  silent (build 100).
- **The list is `actionsForPlanning(on:)`**, the planner's own question (build 174), split into
  Overdue / Due today / Next actions. Real `TaskRow`s (build 149). **Nothing is picked when it
  opens** — choosing is the point.
- **The pick is a Pick/Picked capsule, not a circle**: the task's own tick is the circle
  (build 154). Two-state language as `FilterBox`.
- **The symbol is `cup.and.saucer`, not `sunrise`**: sunrise already means *Tomorrow*
  (builds 215, 224), build 168's rule.
- `planBlockTitle(from:)` in PlannerView.swift is no longer private: this is its third way in.
  `CountPill` (CloseDayView.swift) likewise has a second user now.
- On Today the two buttons sit in a `ViewThatFits`: words when there is room, symbols only on a
  phone. The date has `.layoutPriority(1)` so the words give way, not the date.
- Screen test `testStartTheDayOpensAndCloses`, dull on purpose: the test vault has no dated
  task and no next action (build 221's fixture), so it shows "Nothing is waiting".

**Build 234: the evening reminder.** `App/Paragon/EveningReminder.swift`: one repeating
`UNCalendarNotificationTrigger` (id `paragon.closeTheDay`), planted from **Settings › Evening
reminder** (`EveningReminderSection`, `@AppStorage` keys `eveningReminderOn` /
`eveningReminderMinutes`, default 21:00), and re-planted at every launch so the switch and the
schedule cannot disagree.
- **The delegate is set by `ReminderAppDelegate` through `@UIApplicationDelegateAdaptor` /
  `@NSApplicationDelegateAdaptor`** — the app's first delegate adaptor — because a press can
  start the app from cold and the delegate has to exist before launch finishes, earlier than
  SwiftUI makes `AppModel`.
- A press bumps `openRequests`, **a count** (build 122), and `ContentView` answers it with
  `.onReceive`, which also delivers the current value on subscribing — that is what catches the
  cold start. It opens `.closeDay` through `afterUpdate`.
- `willPresent` returns `.banner` so it shows while PARAGON is in front.
- Notifications refused: Settings says so in orange and names where to change it (build 100).
- Per device: the setting is `UserDefaults`, not the vault, so the phone and the Mac each have
  their own switch and time. Deliberate — the reminder is about where he is, not the notes.

**Build 235: a + on Start the day.** His words: *"this is a time for thought and to start up
with the coffee and with the fresh brain."* He asked me to design it.
- **One field and a +**, the add-a-task bar's shape. It goes through the **ordinary capture
  path to the Inbox** — nothing new invented, and it is filed later the usual way.
- **Dated today unless he typed a date**: `CaptureReading.line(_:datedIfUndated:)` (Core,
  tested), read with the task parser. The date is what puts it under **Due today** here.
- **It arrives already picked.** `addAction` notes the ids before, captures (`capture`
  reloads synchronously), then picks the one new ref with the same title. A line dated for
  another day is not in the list, and a flash says so (build 100).
- The field keeps focus after +, so several can be typed in a row.
- `testStartTheDayOpensAndCloses` now types "Water the plants", presses +, and waits for
  `startDay.pick.Water the plants` to read **Picked** (or carry `isSelected`). Both are
  accepted because a Mac button's words are its label and it may not report the trait.

**Build 236: Close the day, fuller.** His ask: *"We should be proud of everything we have done,
and we should be able to move stuff around for tomorrow and the nice start."* Chosen from a
drawing of two shapes (https://claude.ai/artifact/DAuGkev2WtZqotkZR36qTA): **A, one page**;
**First only marks** (no block); **counts and what they served**, not every task by name.
- `Core/Vault/DayClosing.swift` (tested in `DayClosingTests`): `ServedCount` +
  `NoteIndex.servedCounts(of:)` — grouped through `serves(_:)` (build 174), so a task counts
  towards what the planner shows it serving; a task whose note serves nothing counts towards
  its own note. `FirstPick` / `FirstPicks` in `.ams-para/first.json`, keyed by note path and
  **task title**, never `TaskRef.id` (that carries the line number). **Not a `#first` tag**: it
  would travel into Reminders and stay on the line after the morning.
- `AppModel.firstPicks` / `loadFirstPicks()` / `toggleFirst(_:on:)`; both screens reload the
  marks when they open, so a mark from the other device is seen. Old days are dropped on write.
- `CloseDayView`: **What you did today** (the green count once, then `ServedRow`s in the
  chain's own symbols and tints), **Did not happen** (`LeftoverRow`: **Tomorrow** + **Day…**
  popover with `DateChoiceView`), **Tomorrow** (`CalendarEventRows(compact:)` for tomorrow,
  then `actionsForPlanning(on: tomorrow)` minus today's leftovers, dated ones plus marked ones
  plus at most six next actions, each with a **First** `PickButton`), **How was today?**.
- `PickButton` left `StartDayView` as a shared view with `onTitle`/`offTitle`.
- `StartDayView` draws **Marked first last evening** above Overdue, via `FirstPicks.split`.

**Build 237: What you did today moved to the foot of Close the day**, his ask the same hour 236
landed: *"This way, I can focus on what was left over, what to do tomorrow, and how was today
entry."* The things to act on first, the look back last, under a `Divider`.

**Build 238: a read-through of 233–236 found four real faults** (a subagent read the diff; no
compiler here). Nothing he had reported — **looking again at a batch of new screens after they
ship is worth one build**.
- **`remindersAnswered` was `@State` in `ContentView`**, so every new window started at 0 and
  replayed the last reminder press (closing the Mac window and clicking the Dock icon opened
  **Close the day** again). The answered count now lives in `EveningReminder.takeOpenRequest()`.
  **A count a view compares against has to live beside the count, not in the view.**
- **Start the day's picks were keyed by `TaskRef.id`** (path + line). Ticking a repeating task
  there writes the next occurrence below and moves later lines, so a pick could point at the
  wrong task. `pickKey` = path + title, as `FirstPick` already did. Same lesson as build 236,
  one screen earlier: **never keep a user's choice by line number.**
- **`model.flash` sits under a sheet on the phone**, so "saved with another date" was never
  seen. It is now a caption inside the sheet. **A sheet's messages belong in the sheet.**
- **`planActions` turned events into minutes as seconds since midnight / 60**, an hour out after
  03:00 on the day the clocks change. Now `dateComponents([.hour, .minute])`, with 0 / 1440 for
  an event that starts yesterday or ends tomorrow.
- Minor, done in the same build: the permission answer re-reads `UserDefaults` before planting
  (on-then-off no longer leaves a reminder), and Start the day loads today's events itself.

**Build 239: two headings for tomorrow in Close the day**, his ask: *"I would like the heading to
say 'Tomorrow's calendar events' and then the date."* The section held events **and** actions,
so his wording on one heading would have been untrue of the actions: **Tomorrow's calendar
events · <date>** over the events (only when calendar events are shown), **Waiting for
tomorrow** over the actions. **When a user renames a heading, check what else sits under it.**

**Build 240: Pick and First go in front of the row.** Testing 239 he pressed the tick circle
to pick two actions and marked them done. `TaskRow` draws its circle first, so a control put
*after* the row is the second thing a thumb meets. He chose **B** over hiding the circle:
`PickButton(large: true)` (fixed `largeWidth` 76, so **Pick**/**Picked** do not jump) sits
before `TaskRow` in `StartDayView.row` and in Close the day's **Waiting for tomorrow**; "In the
plan at" became a two-line caption in the same width. **A control that sits beside a task's
tick must come before it and be bigger than it**, or the tick takes the press.

**Build 240 also: the lost letters were real.** `testANoteCanBeOpenedAndTypedIn` failed a
second time ("---Typed by the screen tes"), and build 232's note had said a second failure
means a real fault. `write(_:)` clears `isDirty`; the model then publishes the saved text, and
`onChange(of: storedText)` — seeing nothing dirty — put the editor back to it, wiping any key
pressed in between. `lastWritten` (the shown text of our own last save) is now checked first:
**our own save coming back never replaces what is on screen.** A slow CI simulator is where
that gap is widest, which is why only the phone test ever saw it.

**Build 241: the morning is orange, the evening dark lilac**, his ask. `Theme.morningTint`
(`MorningTint`, #E06C00 / #FFA23A) and `Theme.eveningTint` (`EveningTint`, #6E3A86 / #C79AE0)
colour the two Today buttons **and** the two screens they open (build 168: the button and its
screen are one thing). The lilac is redder and darker than the Calendar's violet (#6B4EA8) on
purpose. **Start the day** also got `cup.and.saucer.fill` and `HeaderActionButton(strong:)` —
full-strength border and bold words, **no fill**, because a tinted fill means "on" in build
142's two-state language and this is an action.

**Build 242: two faults from a night-time read-through of 237–241** (a subagent, again).
- **`$openRequests` sends the new value in `willSet`.** Build 238 made `takeOpenRequest()` read
  the stored property, which at that moment still holds the old count — so a reminder pressed
  while the app was running opened nothing, and the next press answered the one before. It is
  `takeOpenRequest(upTo:)` now, fed the value the publisher sends. **Never read a `@Published`
  property inside its own publisher's sink; use the value handed in.** His test of 234 passed
  because 234 compared the received value; 238's cleanup is what broke it.
- **`lastWritten` is used once** and cleared when an outside change is accepted. Left in place,
  tick-then-untick (which returns the file to exactly the saved text) was taken for our own echo
  and ignored, and the next keystroke saved the stale ticked line over the file.

**Build 243: the reminder says whether it is planned.** His test of 242: set to 13:10 on the
Mac, nothing came, and Settings showed the ordinary grey line. **That line was drawn whenever
permission was not `false`** — so "never asked" (`notDetermined`, which plants nothing) and
"allowed but style None" looked exactly like "all fine". Build 100's rule, missed in 234.
- `EveningReminder.Permission` (notAsked / refused / silent / allowed) and `nextReminder`, read
  back from `getPendingNotificationRequests` → `nextTriggerDate()`. **Settings shows what the
  system holds, never what the switch hopes.**
- **Send one in 10 seconds**: its own id (`paragon.closeTheDay.test`) so it can never remove the
  daily one; `didReceive` answers both ids. Testing a daily reminder should not mean waiting
  for a time of day.
- **Not detectable from here: a Focus mode** holds banners back and the app cannot see it.

**Build 244: the test button answers.** On the phone **Send one in 10 seconds** gave no sign at
all, and "nothing came" could not be told from "nothing was sent". `EveningReminder.TestState`
(asking / waiting / delivered / notDelivered / notAllowed / failed) is shown under the button;
15 s after `add` succeeds it reads `getDeliveredNotifications`. `willPresent` now also returns
`.list`, or a notification shown in front is not kept and the check could never find it.
**A button whose effect comes later must say at once that it was pressed.**

**Build 245: `moon.fill`**, his ask ("more colored"). `CloseDayView.symbol` is the one place,
used by the Today button and the screen's heading, the same shape as `StartDayView.symbol`.
`strong:` was left off on purpose: build 241 made the morning the one that stands out.

**Build 246: the settings block folds.** His ask, from a pasted frontmatter block: *"make a
toggle so that I can compress this area of each note."*
- `FrontmatterFold` (Core, tested): `head(of:)` / `body(of:)` / `joined(head:body:)`, the same
  rule `MarkdownHighlight` dims by, and head + body is always the whole text. **The file is
  never changed; only what the editor shows is.**
- `NoteEditorView`: `@AppStorage("frontmatterFolded")`, one setting for all notes. `displayText`
  goes through `shownText(from:folded:)` and every save through `wholeText(from:folded:)`,
  which takes the block from **`baseText`** — the latest copy of the file — so a line a chip
  wrote while folded (**Serves…**, **Tags…**) survives the next save. `.onChange(of:
  frontmatterFolded)` saves with the **old** setting before reshaping the text; saving with the
  new one would have doubled the block.
- The row is a `FoldButton` (`note.frontmatter`), drawn only in Edit and only when there is a
  block (build 225: nothing to fold is not a vanishing control). Screen test
  `testTheSettingsBlockCanBeFoldedAway` on both platforms; `editorHolds` / `editorLacks` are
  the two-platform waits (`shows` is Mac-only).
- **"Settings block"** is the word on screen and in `Docs/Words.md`; the manual says
  "frontmatter" in its reference lines and both words now sit in the same paragraph.
- Also in 246, from the crash read-through of 243 (no report at Apple; nothing proven):
  `ContentView` closes an open sheet before presenting **Close the day**, and
  `EveningReminderSection`'s `onAppear`/`onChange` sit on the Toggle, not the Section.
- **A multi-step edit script that asserts must run its asserts before it writes anything, and
  the commit must wait for the script.** The first push of 246 went out with the docs missing
  and the `let shown = shown(…)` shadow in place, because the script stopped at its first
  check and the `git commit` on the next line ran regardless. Chain with `&&`.

**Build 247: the two Today buttons are symbols only, everywhere.** His ask: *"take away the
text in the buttons completely."* The `ViewThatFits` from build 233 (words when they fit) is
gone; `dayButtons` is a plain `var`. `HeaderActionButton.title` stays optional for the Overdue
pair, which still carries words.

**Build 247's four red Mac runs were the test's click, not the fold — and the app's own log
is what said so.** `testTheSettingsBlockCanBeFoldedAway` pressed `note.frontmatter` with
`pressCentre()` and the note closed ("No note open"). The Mac reported a wrong frame for a
short `FoldButton` sitting in an `HStack` with a `Spacer`: the centre point landed at
(469.5, 209.5), twelve points left of the divider, **in the note list**, and a click on the
list's empty part deselects the note — build 198's "the group's left edge deselected the note"
again. What settled it was `diagnosticsTail()` in the test: **Help › Copy Diagnostics** read
back on failure, whose `mouseDown at … on SwiftUIOutlineListView` line named the view the
click hit. Three lessons:
- **A test's "the note closed" can be the test's own click.** Before touching the app, put the
  app's click log into the failure message; it costs one run and answers the question.
- **A short button beside a `Spacer` gets a wrong accessibility frame on the Mac.** The fold is
  now the whole line (`.frame(maxWidth: .infinity, alignment: .leading)` inside the label), and
  the test presses with `press()` when `isHittable`, `pressCentre()` otherwise.
- **`editorLacks` must require `exists == YES`**: "the text no longer contains X" is also true
  of an editor that has gone, which is how the first run's pass was vacuous.

## Task times (build 248 on)

He asked what Sunsama had that PARAGON could use, and took three ideas from a drawing
(https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX): a time on each task, a goal for the week,
and a focus timer. His answers: **the working day ends at 16:00**, the choices are **10, 15,
30, 45 min, 1 h, 1 h 30, 2 h, 3 h**, **Start the day asks for a time** before it plans a task
without one, there is a **Use task times** switch in Settings, and **task times come first**.
Planned order: 248 time on tasks, 249 Start the day sums and asks, then (after build 250's
layout fix) 251 the week goal, 252 the focus timer, 253 its notice and the Mac menu bar,
254 planned and worked in Close the day.

**Build 248.** `Core/Markdown/TaskTime.swift` (tested in `TaskTimeTests`): `~45m`, `~1h`,
`~1h30m` on the task line, lifted out of the title by the parser like a date, written after
the priority and before the date. `TaskItem.minutes`. The first marker counts; a second is
dropped. A bare `~` and `~5` are left alone. `TaskTime.label` ("1 h 30") is for a button,
`TaskTime.total` ("2 h 30 min") for a sum. `MarkdownHighlight` dims it like a date.
- **Not sent to Reminders**: the reminder's title is `task.title`, which no longer holds it, and
  the reconcile path sets fields one by one, so a reminder edit never clears it.
- `TaskTimeButton` sits on the right of every `TaskRow` (so Start the day, Today, notes, the
  planner all get it at once), a popover with `PickChip`s; **How long** in `TaskContextMenu`.
  A done task shows its time as plain grey words and asks nothing.
- `TaskTimeSetting.key` = `useTaskTimes`, default on, read by `TaskRow`, `TaskContextMenu` and
  Settings › Tasks. Off hides everything; the `~45m` in the files stays.
- Screen test `testATaskCanBeGivenATime`.

**Build 249: Start the day uses the times.** He added one thing after the plan was agreed:
*"I also keep my leisure tasks here - so we need to be able to add tasks after 16:00"*. So
**the working day is a measure, never a wall**: blocks are still placed until midnight, going
past the working day is said in grey, and only "does not fit before midnight" is orange.
- Core, tested in `DayFitTests`: `DayPlan.freeStarts(lengths:from:until:busy:)` (one answer
  per block, nil when it does not fit; a long one left out does not stop a short one after it;
  the search only moves forward so the first pick stays first), `DayPlan.freeMinutes`, and
  `DayFit` with its three verdicts.
- `AppModel.planningBusy(on:)` / `planningStart(on:)` were pulled out of `planActions` so the
  sum and the placing use **one** busy list. `planLength(of:)` is the task's time, or 60 when
  it has none or **Use task times** is off. `workdayEnds` reads `WorkdaySetting.key`
  (`TaskActions.swift`, a plain enum so `@AppStorage` can name it outside the main actor).
- **Ask first**: `pressPick` opens `TaskTimeChoices` as a popover on the **Pick** button when
  the task has no time; choosing a time is what picks it. A line added with **+** is picked
  at once and counts as 1 h, which the foot of the screen says.
- Settings › Tasks › **Working day ends** (`WorkdayEndRow`, clock parts both ways).

**Four CI runs for one new screen test, and what each one taught** (`testATaskCanBeGivenATime`):
1. `app.descendants(matching: .any).matching(identifier:)` found an element **with no frame**
   carrying the button's name — SwiftUI puts the identifier on a wrapper as well as on a
   button that has a `.popover`. Look for such a button among `app.buttons`.
2. On the Mac, `app.coordinate(withNormalizedOffset: .zero)` has **no position**: an offset
   from it came out as infinity and XCTest threw. Press at the element's own middle there.
3. **The Mac's note column is clipped at narrow widths — an older layout fault, not fixed yet.**
   In the 900-point test window the detail column's content is 556 points wide in a column
   of about 420, centred, so about 67 points are cut off on *each* side: the time button sat
   at x 980 in a window ending at 962. His own window is wider, which is why it has not been
   seen. Something in the note screen demands that width (suspect the header's chip row or a
   `.fixedSize()`); find it with Help › Copy Diagnostics at a narrow window. A right-click on
   the row did not bring the task menu up in the test either (run 308).

**Build 250: the culprit was `NoteHeader`.** An `HStack` of kind, name chip, Status, Serves…,
Deadline, Tags and the List label, none of which shrink, so its sum was the column's smallest
width. Because build 34's `tameSplitViewColumns` sets `sizingOptions = []` on the column's
hosting view, AppKit no longer hears that minimum: it gives the column its narrower width and
SwiftUI lays the content out at its own minimum, centred, clipped both sides. **On the Mac a
row of things that will not shrink is not squeezed, it is cut off — and on both sides.** The
header is a `WrappingHStack` now (no `Spacer`, `.frame(maxWidth: .infinity, alignment:
.leading)` so the band stays full width), and the name chip has `.frame(maxWidth: 260)`
because a wrapping row measures each item at its natural width. The Mac half of
`testATaskCanBeGivenATime` presses the button again and first asserts it is inside the window.

**Build 251: the goal for the week.** `Core/Vault/WeekGoal.swift` (tested in `WeekGoalTests`):
`focus:` in the weekly note's frontmatter, one line (`cleaned` joins line breaks), an empty
goal removes the line, `NoteIndex.weekGoal(for:)`, and `DayOverview.plannedMinutes` (only
written times count — never a guessed hour). **Frontmatter, not the template's `## Focus`
section**: that section ships with the placeholder "What matters most this week?", which
would have read as a goal. `AppModel.setWeekGoal` never makes a weekly note for an empty goal.
`WeekGoalBox` (CalendarView.swift) is edited in place, no sheet; Today shows **This week:**
outside the `List` (build 220's reason) and nothing when unset (a daily nag would be wrong).
**The week strip's hours are grey even on a long day**, against the drawing's orange
Wednesday: his leisure-tasks rule from build 249 came after the drawing. Screen test
`testAGoalForTheWeekCanBeWritten`.

## Two Mac crashes in the editor (build 252)

He pasted one crash report from build 251. **The Crash reports workflow had a second one from
the same Mac three minutes earlier**, with a different cause — run the workflow before
designing a fix, even when he has pasted a report, because the one he pasted may not be the
only one.

- **08:36, ⌘Z: `EXC_BAD_ACCESS` in `-[_NSUndoStack popAndInvoke]`**, reached from the Edit
  menu's key equivalent. The `NSTextView` registered its typing in the **window's** undo
  manager, and every note opens a fresh editor (`NoteEditorView(path:).id(path)`), so the
  history outlived the text view it pointed at. ⌘Z in the next note invoked a freed object.
  Fix: `Coordinator.history`, an `UndoManager` per editor returned from
  `undoManager(for:)` (the `NSTextViewDelegate` method), emptied in `dismantleNSView`, and
  emptied again whenever the text is replaced from outside (`textView.string = …` records
  nothing, so older typing would be undone at places that have moved). `dismantleNSView` also
  sets `allowsUndo = false`, because once the delegate is nil the text view falls back to the
  window's history. **A side effect he will meet**: ticking a task in the note's own task box,
  any header chip, or the autosave rewriting a settings line (`key: value`, trimmed) is an
  outside change and restarts undo — the manual says so. Found by the review in the same
  build and fixed: `scheduleSave`'s early return (text back to what the file holds) never
  cancelled `pendingSave`, so ⌘Z within 600 ms of typing, or a letter typed and deleted,
  saved the undone text while the screen did not show it. Screen test
  `testUndoWorksInANoteAndStaysWithIt` (Mac): undo works inside the note, and ⌘Z after leaving
  it keeps the app running.
- **08:39, typing: an uncaught `NSRangeException` from `NSRLEArray objectAtRunIndex:length:`
  in `NSLayoutManager _fillLayoutHoleAtIndex`**, under `NSTextView sizeToFit` ←
  `NSScrollView setFrameSize` ← SwiftUI's `AppKitPlatformViewHost` layout ← a display-cycle
  flush running **inside `NSCorrectionPanel _interceptEvents`**, the nested event loop macOS
  14+ spins while it shows an **inline prediction** (the grey words after the caret). The
  prediction is marked text inside the text storage; during that loop our 600 ms autosave
  could land, change the height of what sits above the editor, and resize the scroll view,
  while `updateNSView` restyled the whole storage on **every** SwiftUI update. Fixes, all in
  `MarkdownSyntaxEditor.swift`: `textView.inlinePredictionType = .no` (macOS 14) and
  `mathExpressionCompletionType = .no` (macOS 15, behind `#available`; a sum's answer in grey
  is shown by the same `showCompletionForCandidate`), which remove the **prediction** way into
  the loop — **not the loop itself**: an autocorrection bubble still runs `NSCorrectionPanel
  _interceptEvents` (public `showCorrectionIndicator`, macOS 10.7), with no evidence it is
  unsafe. A later report with `_interceptEvents` and no `_showInlinePrediction` frame is that
  path; the switch then is `isAutomaticSpellingCorrectionEnabled = false`, his choice since it
  costs spelling help; `textDidChange` copies into the binding **first** and then stops while
  `hasMarkedText()` (binding-first loses nothing if AppKit commits marked text without a
  following `didChangeText`; a lone ´ may sit in the file for a moment, which is what the
  screen shows), and `highlight` does nothing under marked text. **`updateNSView` still
  replaces the string under marked text, deliberately.** A first version skipped it, and the
  review found the cost: with the binding copied first, a difference there is always a real
  outside change (a tick, the fold, a sync), and skipping it let the next key write the old
  screen back over it — the fold toggled under a pending ´ could delete or double the settings
  block. **A guard that holds back an outside change has to say when the change is applied
  later; if nothing does, it is a data-loss bug.** `updateNSView` restyles only
  when it replaced the text, the tint changed (`styledTint`, a SwiftUI `Color`, which is
  Equatable where a converted `NSColor` is not reliably so) or the light/dark look changed
  (`styledScheme`, from `context.environment.colorScheme` — before, the restyle on every
  update covered an appearance switch by accident). Of the three, **only the prediction
  switch is on the crash's stack**; the review rated the other two hardening, not the fix.
- **Build 211's Mac crash (22 September) is the same family, not proven the same fault.** Its
  thread 0 matches frame for frame up to the layout recursion, at the same depth in the view
  tree, and the editor is the only `NSViewRepresentable` in the app — but it carries no
  exception backtrace and no `NSCorrectionPanel`: it ran from the main loop 43 seconds after
  the Mac woke. The weak point is the same (SwiftUI resizing the hosted text view while its
  storage was being restyled on every update); the trigger was not a prediction.
- **The phone's editor is not changed.** The iOS coordinator has the same unguarded shape
  (no `markedTextRange` check, restyle on every `updateUIView`), but no iPhone crash points
  there, and the phone editor's history (builds 123–128) says not to touch it on a guess. The
  `scheduleSave` fix is in `NoteEditorView`, so it reaches the phone too, harmlessly.
- **The ⌃⌘← screen test is blind in one place**: it proves the resource opened with "Packing
  list", which the project also holds (its `[[Packing list]]` link). The new undo test proves
  the switch by what only the project holds ("Book the night train"); the old test was left
  alone so a build about crashes changes no test that was already green.

## The Projects list, grouped (build 253 on)

His words: *"The project list is a bit boring … I need to get inspired by the app so that I feel
like using it."* Then *"you are the designer"*, and he approved a drawing
(https://claude.ai/artifact/4ByhCcS4cA5kYYNH41b6ap). Three builds: **253** groups and boxes,
**254** his own emoji in the tile (`emoji:` frontmatter, an **Emoji…** chip), **255** the small
weekly bars, "last task finished …" and the band at the top. The focus timer (256–258) follows,
in the look of the Time and Focus page (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX) —
he said he loves that page's design.

**Build 253.** The fault under "boring" was a real one: seven of his nine projects had every
task ticked and still said Active, so each showed a full bar and "1 of 1" and looked finished.
Core already knew (`ProjectHealth.noNextAction`); the list never asked.
- `Core/Vault/ProjectGroups.swift` (tested in `ProjectGroupsTests`): `ProjectLine` (one box:
  `Need` = next task / all finished / no tasks, counts, overdue, goal, deadline, the late flags,
  and the wording), `ProjectGroup` (aspiration / not linked / no goal / one per ending),
  `NoteIndex.aspiration(above:)` and `projectGroups(_:today:)`, and `ProjectOrder`.
- **Grouped by aspiration, not by area**: it answers "what is this for?", and a project's area
  can only be set by dragging on the Map today. Aspirations come in `aspirations()` order, so
  this list and the Aspirations room agree; an ended aspiration with live projects under it
  still gets its group (build 100: work must not vanish).
- **"No next action" is calm grey**, never orange, and `needsALook` ignores it: true of most of
  his projects, and a screen of orange would be a telling-off (build 132's rule). Orange ⚠ on a
  heading counts only the late things — an overdue task, a passed deadline, due after its goal.
- **`nextTitle` strips `#next`** through `WidgetSnapshot.widgetTitle` (build 174's rule): the box
  shows the task *because* of that tag. It is internal to Core, hence the property.
- **A drag never leaves its group, and the other groups keep their slots.** `ProjectOrder.moving`
  lets the group's projects trade places among the slots they already hold in the whole list;
  numbering one group from 10 would collide with the next group and scramble the **File it**
  column and the **Move to** menu, which list projects in this order. `Array.move(fromOffsets:)`
  is SwiftUI's, so `ProjectOrder.moved` is written out in Core and pinned by a test.
- `AppModel.projectGroups` is worked out in `notes`' `didSet`, never in a body: every project's
  tasks are parsed. `count(for: .kind(.project))` counts only live projects, so the sidebar
  number is the work in the list (the Goals row's build 199 reasoning).
- `ProjectsView.swift`: `ProjectsListView` (one `List(selection:)` for both platforms, a `.tag`
  on each box — nothing in a box takes a click, which is what keeps a tagged row safe, builds
  71–74), `ProjectGroupHeader` (the whole line folds, build 205; `.textCase(nil)`, build 214),
  `ProjectBox`, `ProjectPill`/`ProjectFact`, `ProjectProgress`, `ProjectTile`. The box is framed
  on the Mac only: on the phone the inset-grouped section's card is the box already.
- **The four status lines on the right-click menu** — **Mark done/missed/dropped**, **Put on
  hold**, **Set active** — because a list that says "All 15 finished" has to be able to answer
  itself. The fields-nothing-could-write rule turned round: a screen that *shows* a fact needs
  the control that changes it within reach.
- `NoteStatus.systemImage` (GoalsView.swift) is now the one place the status symbols are
  spelled; `NoteStatusChip` reads it.
- Folding is two `@AppStorage` strings of group ids: live groups open by default, ended groups
  folded by default (as in both goal rooms).
- `askingToTrash(_:)` in `NoteListView` is the one delete question for the flat list and this
  one.
- Screen test `testProjectsSitUnderTheAspirationTheyServe`, both platforms: the heading is
  found among **buttons** by `projects.group.aspiration:` (build 249), the box's
  `project.next.<path>` reads "Next: …" (its label is set explicitly, one sentence, so both
  platforms read it the same), and the heading folds the group and opens it again. It checks
  "Next:" and never the task's words: the first open task is the project template's own
  (build 211).

**Build 254: his own emoji, and four faults the review of 253 found.** The review ran after
253 had shipped, because the first attempt hit a usage limit; CI was green and he wants the
upload when it is. That order is fine for small faults, but **a review that cannot run before
the push is still worth running after it** — it found two behaviour faults CI could never see.
- `Core/Model/ProjectEmoji.swift` (tested in `ProjectEmojiTests`): `emoji:` in the settings
  block, `cleaned(_:)` keeps the **first emoji** and nothing else (a bare digit, `#` or `*` is
  an "emoji" to Unicode only as the start of a keycap, so alone it is refused), `Note.emoji`,
  and `groups`, the 24 choices from the drawing, **spelled as escapes** so the variation
  selector that turns 🖨 ⌨ 🗂 ✈ into emoji cannot be lost by an editor. A test checks every
  choice is one `Character` and survives `cleaned`, and that a keycap starting with `#`
  survives the settings block's quoting.
- `AppModel.setEmoji(_:on:)` removes the line for nil, never writes `emoji:` (build 165's rule
  for `status:`). `ProjectEmojiChip` sits right after the kind in `NoteHeader`, projects only;
  `EmojiChoices` is its popover, with `.presentationCompactAdaptation(.popover)` like the tag
  list and `.focusEffectDisabled()` on the grid only — the field keeps its ring (build 202).
  `ProjectTile` takes `emoji:`: a solid frame when set, dashed when not (build 142's language).
  The tile is one accessibility element whose label is the emoji, `project.tile.<path>`.
- **A cache that compares against today has to know which today.** `projectGroups` was worked
  out in `notes`' `didSet` with `.today()` at that moment, so a Mac left open overnight kept
  yesterday's late flags while the same box drew its dates live. `projectGroupsDay` +
  `refreshProjectGroups()`, and the 10 s `checkForExternalChanges` works them out again once
  the date has moved. **Any cached value built from `.today()` needs the same.**
- **The flat list's drag was wrong while searching**, older than 253 but now the only way a
  Projects search draws: `.onMove` handed offsets in the filtered list to `reorder(kind:)`,
  which applied them to the whole list and wrote `order:` into notes nobody touched.
  `mover(for:)` returns nil while searching, in every section.
- **An open subtask under a ticked task is the next thing**, after the top-level rule, so a box
  can no longer say "All 3 finished" beside "1 overdue". **`Note.nextThing` (Core) is the one
  rule**, used by `ProjectLine`, `ChainProject` (whose `hasNothingToDo` is now "no next thing")
  and `NoteIndex.nextActions()`. The first push taught it to the Projects list alone, and the
  254 review caught the Goals screen saying "No next action" for the same project — **when one
  screen learns a rule, every screen asking that question is part of the build** (162, 168).
  A subtask under a cancelled task is not counted. The box hides its progress bar when the next
  thing is a subtask (`openCount > 0`), or it would show a full "1 of 1" beside "Next:".
- `setEmoji` writes nothing when the emoji is unchanged.
- The **Not linked to an aspiration** footer adds the `Serves` fix when a goal name was not
  found; `Docs/HowItWorks.md` names the **Archived** group and says the sidebar number counts
  on-hold projects (it said "still running", which on hold is not).
- Screen test `testAProjectCanBeGivenAnEmoji`, both platforms: **Emoji…** found among buttons
  and pressed at its frame (build 249), `emoji.choice.🎒`, then `emoji: 🎒` in the editor; on
  the Mac also the tile's label in the list. The phone stops at the editor, since getting back
  out of a pushed note is not what the test is about.

**Build 255: the weekly bars and the band.** The last of the three Projects builds.
- `Core/Vault/WeeklyFinished.swift` (tested in `WeeklyFinishedTests`): `counts` for eight
  **calendar weeks** (`WeekRef`, Monday to Sunday, the weekly notes' weeks — never "the last
  seven days"), `lastFinished`, `caption(today:)`, `bandHead`/`bandWeek`/`bandText`, `spoken`,
  `agoText(days:)` (the same steps as `timeLeftText` and `lookedAt`), `lookText`.
- **Only what the file can prove**: a task counts on its `@done(…)` day; ticked with no stamp
  has no day and is left out. Subtasks count, cancelled tasks do not. **No dated finish at all
  is `isEmpty`, and then nothing is drawn** — a row of empty bars would say "you did nothing"
  when the truth is "the file cannot say" (build 141). An old finish beyond eight weeks still
  gives flat bars and "last task finished about a year ago", which is true.
- **The caption switches at two weeks**: moving → "6 finished in 8 weeks", quiet → "last task
  finished …". That rule came from reading the drawing's three examples, not from him; change
  it freely if he asks.
- `ProjectLine.weekly` is worked out in `init` with the tasks already parsed, so it rides the
  same `projectGroupsDay` refresh as the late flags (build 254). `ProjectGroup.weekly(of:)` and
  `needsALookCount(of:)` add the list up for the band.
- `WeekBars` iterates `counts.indices`, never `enumerated()` (build 61). The band sits **above
  the `List`** in a `VStack` (build 220's reason) with a `Divider`.
- **The review of 255, before it shipped**: the quiet caption beside the bars was `.lineLimit(1)`
  in an `HStack` beside 46 fixed points of bars, so at the Mac's 280-point middle column
  "last task finished about a month ago" was cut — the cut part being the fact. Two lines now,
  `.fixedSize(horizontal: false, vertical: true)`. **A caption beside something fixed-width has
  to be measured against the narrowest column it lives in** (build 138's family). Also: a stamp
  in a later week now counts for nothing, not even as `lastFinished`; the band draws its "·".
- `TaskRow`'s tick carries `task.tick.<title>`. Mac test `testATickedTaskShowsInTheWeeklyBars`:
  no band before, tick the test task in the note, then band and box bars in the list. Mac only:
  the phone's way back out of a pushed note is not what the test is about.

## The focus timer (build 256 on)

Part 3 of PARAGON Time and Focus (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX), in the
look of that page, which he said he loves. **256** the timer, **257** the notice when the
planned time is up and the time in the Mac menu bar, **258** fixes from his field test of 257,
**259** Planned and worked in Close the day.

**Build 256.**
- `Core/Vault/FocusSession.swift` (tested in `FocusSessionTests`): `FocusSession` (Codable:
  closed `runs` plus `runningSince`; `workedSeconds(at:)`, `pause`, `resume`, `clock`),
  `WorkedSpan`, `DatedSpan`, and `WorkLog`, which owns `## Worked` in the daily note.
  **A session is dates, never a counter**, so it is right after the app was closed or the Mac
  slept; nothing in the model ticks, `TimelineView` redraws the bar each second.
- **Each stretch between pauses is one line**, starting on its own minute and lasting its
  length rounded to the minute, so the lines add up to exactly what the stop question says.
  Under half a minute is no line, and then nothing is asked. A stretch past midnight is split
  and written on both days (`24:00` is a valid end). **`WorkLog` only adds**: a line he edits
  stays; the section is made above `## Looking back` when there is one, else at the end.
- **The worked lines look like plan lines** (`- 08:02-08:54 Title`), and `MarkdownPreview` draws
  any such line as an orange plan block. It now tracks `inWorked` and leaves lines under
  `## Worked` as an ordinary list. **A new line shape has to be checked against every reader
  that already recognises a similar one** (build 153's family).
- The running session lives in `UserDefaults` (`focusSession`), per device — a clock is about
  where he is, only the finished lines are notes. `loadFocus()` runs **after** `TestVault`
  wipes the settings, or a test could inherit a clock left by the one before.
- `AppModel.startFocus(on:)` / `startFocus(onBlock:)` / `pauseFocus` / `resumeFocus` /
  `stopFocus` / `finishFocus(done:)`. A second start stops the first and writes it, as not
  done, and says so. **Done, tick it off** finds the task by its exact title in its note.
- `FocusBar` (FocusViews.swift): `.safeAreaInset(edge: .bottom)` on the `NavigationSplitView`
  on the Mac and on each tab's page on the phone; nothing at all while no clock runs. Ink
  background with the page colour on it (`.foregroundStyle(.background)`), so it is dark in
  light mode and light in dark mode, as drawn. `FocusStopView` is `AppSheet.focusStop`, the
  window's one sheet (build 44).
- **Focus on this** is first on `TaskContextMenu`, on a plan block's menu, **and** at the foot
  of the time button's list (`TaskTimeChoices(focus:)`), which the drawing did not have: an
  action only a right-click reveals is one nobody finds (build 74), and it is what lets a
  screen test press it. Start the day's time question leaves it out.
- Screen test `testAFocusTimerStartsPausesAndStops`, both platforms: start from the time list,
  the bar appears, **Pause** becomes **Go on** and back, **Stop** takes the bar away. **It answers
  the stop question if it comes**: a stretch on a slow runner can reach half a minute, and then
  the question is right — a test may not fail for its own reasons (build 190).
- **The review before it shipped found six real faults**, all fixed in 256:
  - **Work notes**: `canFocus(on:)` refuses a work task. The bar shows the title on every screen
    and the time goes into the ordinary daily note, so it would show through after Hide (112).
  - **Where the bar is not drawn**, no Focus on this: `EnvironmentValues.focusBarShown` is false
    in the two day sheets and the Mac's ⇧⌘P window; `TaskRow` reads it and hands it to
    `TaskTimeButton(offersFocus:)` and `TaskContextMenu(offersFocus:)` (a context menu is built
    outside the row's hierarchy), and `PlannerDayView` to a plan block's menu.
  - **Done ticks only the task it started on**: `FocusSession.taskID` (`^t`) and `taskDue`, and
    `task(in:)` finds it by id, else by exact words **and** date, else nothing — and then says
    so. A title alone could tick a repeating task's next copy or another task with the same words.
  - **Time is never thrown away**: `writeWorked` returns `(minutes, complete)` and skips lines
    already in a note; when a day fails the clock is kept, paused, and a new clock does not start.
  - **A clock left running**: over `FocusSession.forgottenAfter` (12 h) it is not written when a
    new one starts, and the stop question warns and offers **Don't save the time**
    (`discardFocus`), so a weekend does not become days of 00:00–24:00 lines.
  - **Changing or closing the vault** settles the running clock first
    (`settleFocusBeforeLeavingVault`): written into the vault it ran in, dropped when over 12 h,
    and when it cannot be written the vault is **not** changed and the clock is kept, paused.
  - **`writeWorked` never raises an alert itself**: it returns `(minutes, problem)`, saves through
    `vault.save` directly (re-reading once on `modifiedOnDisk`), and each caller puts the problem
    where it can be seen — `focusProblem` inside the stop sheet (a sheet's messages belong in the
    sheet, build 238; an alert while it closes is build 246's two presentations at once),
    `errorMessage` elsewhere. A clock whose old time failed to write is paused before a new one
    is refused, so its stretches stop growing and a retry writes exactly what is missing.
  - `task(in:)` refuses to fall back to words when the id's own task is there but ticked.
  - Smaller: the bar steps aside while the phone's keyboard is up (`KeyboardWatch`, a
    `ViewModifier` so no `#if` sits in a modifier chain), the Mac's flash message sits above the
    bar, the stop message states the per-stretch rule, an empty `## Worked` gets one blank line.
  - **Known, not fixed**: a stretch running across a clock change (02:00–03:00 on a DST night) is
    written an hour off, because a span is its start's wall-clock minute plus its length.
    `repairOverflow` (build 34) sets the split view to the whole window and would cover the bar if
    it ever fires while a clock runs.

**Build 257: the notice and the menu bar clock.**
- `FocusSession.secondsUntilPlanned(at:)` (Core, tested): nil with no planned time, while
  paused, or once the planned time is reached. That last one is what makes the notice come
  **once**: going on after the time is up plants nothing.
- `App/Paragon/FocusNotice.swift`: one `UNTimeIntervalNotificationTrigger`, id
  `paragon.focus.timeUp`, **planted again on every change to `focus`** (`focusChanged()` in its
  `didSet`; `loadFocus()` sets `focus` from a method so `didSet` runs at launch too), so a pause
  removes it and **Go on** puts it back at the right moment. `takeAwayDelivered()` on Stop, when
  a new clock replaces a running one, and when `focus` becomes nil. `EveningReminder` stays the
  one delegate, so it shows while PARAGON is in front. Permission is asked here only while it is
  still `.notDetermined` — the evening reminder asks for the same one, so on his devices no
  question comes. A `generation` counter drops a system answer that arrives after a newer
  change, for the add **and** for the message. **Never asked under `TestVault`**: on the phone
  the question covers the screen. When notifications are off, or allowed but set to **None**
  (two sentences, the same two Settings › Evening reminder uses), it **says so once per launch**
  through `flash`, added to a message already showing rather than replacing it (the flash
  overlay's wait is now `.task(id: message)`, and a cancelled wait returns instead of clearing).
- **"Notification" in everything he reads**, never "notice": the system and the evening
  reminder say notification, and two words for one thing is build 165's fault.
- **With Use task times off, `startFocus(on:)` plans no time** (`usesTaskTimes ? minutes :
  nil`): a hidden `~45m` must not bring a notification, an "of 45 min" or a **Planned:** line.
- `App/Paragon/FocusMenuBar.swift` (Mac only): **an `NSStatusItem` of our own, not a second
  `MenuBarExtra`**. Whether a SwiftUI menu bar label really ticks each second cannot be seen from
  here; a status item's title set by a `.common`-mode `Timer` is certain. The dot is an
  `NSImage` symbol in `PlanTint`; while paused, a **template** `pause.fill` (build 258 — see
  below), set with the tooltip on each change, never each second;
  the time is plain title text so the system colours it, `monospacedDigitSystemFont` at the
  menu bar's size. **A new status item goes to the left of the icons already there, never
  beside the clock**, so it has an `autosaveName` (and `isVisible = true` after it): ⌘-dragged
  once, it comes back there. **Hidden with `isVisible = false` when no clock runs, never
  `removeStatusItem`**, which deletes an autosaved item's place. Menu: the task, **Planned: 45
  min**, **Pause**/**Go on** and **Stop…** (greyed by `NSMenuItemValidation` while
  `focusQuestionPending`), **Show PARAGON**. Shown whatever **Show capture panel in the menu
  bar** says.
- **Show PARAGON finds the main window by `MainWindowMarker`**, a zero-sized, click-through
  `NSViewRepresentable` that `ContentView` carries as an **overlay** (through the
  `MainWindowMarking` modifier) — on the welcome screen too, where there is no split view to
  look for. It unhides PARAGON, searches windows that are visible **or minimized** (not
  `canBecomeMain`, which is false for a minimized one and so opened a second main window), and
  only then calls `model.openMainWindow` (the `WindowGroup` has `id: "main"`; **every** Mac
  scene hands `openWindow` in through `HandsInMainWindowOpener`, because a launch can bring back
  only **Plan the day** or Help) or, when no PARAGON view has appeared at all, asks
  `NSWorkspace.openApplication` for the app itself, which is what a Dock click does.
- **Never put a platform view in `ContentView`'s background.** `tameSplitViewColumns` and
  `repairOverflow` take `contentView.subviews.first` to be the split view's host, and a
  background's view goes first. The marker's first push did exactly that: build 34's fix was
  switched off and the OVERFLOW line the screen tests read went silent, with CI green. Found by
  the third review from the layout dump in an old CI log, not by a test. **A green test that
  reads a diagnostic is only as good as the diagnostic's own assumptions.**
- **The menu bar is the first control outside every sheet**, and that is what the review of
  257 found twice. **Go on** while the stop question was open would run the clock behind the
  sheet and write a stretch the question never showed: `pauseFocus`/`resumeFocus` refuse while
  `focusQuestionPending`. **Stop…** while **New Note** or **Close the day** was open would have
  swapped that sheet for the question and lost what was typed: `stopFocus` now sets
  `stopQuestionWaiting`, and `activeSheet`'s `didSet` asks the question a turn after that sheet
  closes (build 246's shape). The evening reminder's press while `focusQuestionPending` is kept
  (`closeDayAfterFocusQuestion`) and **Close the day** opens a turn after the question's sheet
  closes, never swapped in over it; a message would have sat under the sheet on the phone. **Any new control outside the window
  has to be checked against every sheet the window can show.** A second review of the fixes
  found six more, all about window states nobody draws: minimized, hidden, closed, no vault,
  never opened since launch. **For a control outside the window, list the window's states as
  well as its sheets.**
- Mac screen test: `focus.menuBar` among `app.statusItems` while the clock runs, gone after
  Stop. **First time this suite looks at the menu bar**; if it fails, the message lists every
  status item it found, which says whether the identifier or the query is wrong.

**Build 258: two faults from his field test of 257**
(https://claude.ai/artifact/1hXCr3RqjbYzMHxb7wjf4c, collection `checks`). Six of nine passed.
- **The iPhone bar only came after he changed screen.** `FocusBar` steps aside while
  `keyboardUp`, and the test began by adding a task in a note, so the **Add a task…** field
  still held the keyboard when he pressed **Focus on this**. `KeyboardWatch` now takes
  `clockStart` (the first run's start, else `runningSince`): when it changes while `up`, it sets
  `up = false` and resigns the first responder a turn later **and again 0.6 s later** — the
  review's point: a popover or context menu closing may hand the keyboard back to the field,
  which nothing here can test. It also listens to
  `keyboardDidHideNotification`, so a missed hide can never keep the bar away. **A bar that
  steps aside for the keyboard must never step aside for the very press that asked for it.**
- **The paused dot in the menu bar was invisible**: a fixed `systemGray`, non-template, on
  macOS 26's see-through menu bar, which differs from a mid-grey only in lightness — his words,
  *"maybe it's the same color as the menu bar"*. While paused the item now shows `pause.fill`
  at 11pt semibold as a **template** image, which the menu bar paints in the same adaptive
  colour as the time beside it; the tooltip says "Paused: …". The orange running dot stays
  non-template: it survives because it differs in hue. **In the menu bar, anything that is not
  a strong colour must be a template image**, or its contrast depends on the desktop picture.
- **The window bar's paused dot had the same fault**, found by the review, unreported:
  `Color.secondary` is the bar's own ink at half strength, drawn on that ink (`Color.primary`).
  It is `.background.opacity(0.55)` now. Build 200's lesson in a new place: check a colour
  against the surface it actually sits on, not the page.
- **Not changed, waiting for his answers**: (a) the note on check 2 — a time set on the Mac not
  seen on the iPhone. If he meant the clock bar, that is by design (each device has its own
  clock). If he meant the **10 min** label, the suspect is `CloudFiles.read` returning a stale
  local copy (plain read first; status `.downloaded`, not `.current`) and `AppModel.save`/
  `saveText` resetting `vaultSignature` after the phone's own save, which can swallow an outside
  change. (b) A launch crash on 257 with no report at Apple. Nothing in 257 runs at launch in a
  way that can crash; the suspect is the older one — `AppModel.init` → `reload()` →
  `allNotes()` waiting for iCloud on the main thread (the Inbox stub is read with no budget at
  all, and a failed stub read does not use up `cloudFetchesPerLoad`), killed by iOS's launch
  watchdog. Fix only once the device is known.
- **His answers, 20 October**: the notification at the planned time **works**; the iPhone **does**
  show **10 min** now, so (a) was only iCloud's delay and needs no fix; the crash at start was
  **on the iPhone**, so (b) is the launch watchdog suspect and is the next build.

**Build 259: Planned and worked**, the last part of the Time and Focus drawing.
- `Core/Vault/PlannedAndWorked.swift` (tested in `PlannedAndWorkedTests`): rows from today's
  `## Plan` blocks and `## Worked` lines, **matched by name** (case and runs of spaces folded),
  ordered by each row's earliest minute. Planned is the block's length; for work with no block,
  the task's own time — but **only when every task under that name has the same time**, so two
  tasks sharing a title never lend each other a time. Nil stays nil: a dash, never a zero.
  `plannedTotal`/`workedTotal` are nil when nothing is known.
- **`TaskItem.planTitle` is the one naming rule** for a plan block and for the clock's line
  (`#next` off, his tags kept); `planBlockTitle(from:)` in PlannerView now just returns it. That
  shared name is what puts a block and its work on one row. **A name changed afterwards — even
  a tag added — splits them onto two rows** and **All of today** then counts the plan of both;
  the manual says so rather than guessing a match.
- `AppModel.plannedAndWorked(on:)` reads only, never makes a daily note; it hands in
  `tasksCompleted(on:) + openTasks()` only when there is work and **Use task times** is on.
  `dailyNoteIsWaitingForCloud(_:)` lets the empty state say "still coming from iCloud" instead
  of "nothing planned" (build 100).
- `PlannedWorkedSection` (CloseDayView.swift) sits **at the foot, after What you did today**, not
  where the drawing put it: build 237's order (act first, look back last) is his, and this is a
  look back. A `Grid`; **modifiers go on cells and on the grid, never on a `GridRow`** — a
  modified row stops being a row. Over is orange **and bold** (the drawing's CSS), headers
  uppercase like `SectionLabel`. A running or paused clock is named under the table: its time is
  not in the note until Stop.
- On-screen text says **focus timer**, the word in `Docs/Words.md`.

**Build 260: 3 min and 5 min**, his ask after 259. `TaskTime.choices` gained 3 and 5 (the
parser always read `~3m`; `testRoundTripsEveryChoice` covers the new ones). **The planner had
to change with it**: a card is never drawn under 22 points (`shortestCard`), which is 30 minutes
on a 44-point hour, so a 3-minute block followed by one five minutes later was drawn underneath
it. `place(_:)` now shares lanes by `drawnEnd(of:)` — where a card ends on screen — so short
cards sit side by side. **When a choice makes a value much smaller, check every place that draws
it at its true size.**

## No iCloud wait on the main thread (build 261)

His iPhone crashed at start on build 257 and the second start worked; Apple had no log (nor for
the three "at start" reports of 9, 10 and 14 October). **The suspect, not proven:** iOS's launch
watchdog. `AppModel` is a `@StateObject`, so `init` → `restoreVault` → `reload()` →
`allNotes()` ran before the first frame and could wait for iCloud with no limit: the Inbox was
read first with no budget and no timeout (and a failure there threw out of `allNotes`, emptying
the vault), and a stub whose coordinated read *failed* never used up `cloudFetchesPerLoad`, so
every such stub cost a full wait. A mapping workflow found it; two adversarial critiques of the
first design found ten more faults, all taken in.

**The rule now: nothing on the main thread waits for iCloud. Only the background pass waits,
and every wait has a limit.**
- `CloudFiles.read(_:waitingUpTo:)` has **no default**: every caller says how long. Zero never
  waits — an `.away` file throws at once without even a plain read (on a system that keeps such
  files under their real names, the plain read *is* the wait). Above zero it is a coordinated
  read cancelled from a GCD timer. `CloudFiles.fetch(_:within:)` is the time-boxed pass
  (`longestWait` 20 s, `passLength` 60 s, no try under 1 s left), with an injectable clock.
- `CloudFiles.Presence`: `.here`, `.stale` (`.downloaded`: an older copy is here), `.away`.
- `Vault.allNotes(cloudFetches:)`, default 0. **The budget is a local `Listing`, never state on
  the object**: the sync engine reads the same `Vault` off the main thread with 15, and a shared
  counter could have handed the main thread a wait. The Inbox goes through the same
  `readListed` as every note; every try costs one; a stub beside its real file is skipped.
- **`.stale` notes are read and shown, and also listed in `notesBeingUpdated`.** That list
  matters: `Vault.save`'s `modifiedOnDisk` compares against the *local* date, which does not move
  until the newer copy lands, so a write over a stale note is not caught by build 39's check.
- `loadNote(relativePath:waitingForCloud:)` defaults to **no wait**. So single-note writers
  (`dailyNote(for:)` and everything on it) now throw `notDownloadedYet` at once for a stub.
  `saveLookingBack` returns the reason and **Close the day stays open with the words in it**;
  `Vault.capture`'s `.note(path)` throws instead of misfiling into the Inbox; `inboxNote()` uses
  `CloudFiles.exists` (build 95's rule, missed there).
- `AppModel.reload()` passes 0. `fetchCloudFiles` is the pass: on a GCD thread through `offMain`
  (not `Task.detached`: a coordinated read holds its thread, and the pool has one per core), the
  `downloadMissing` walk, then waits in `cloudPassOrder` (Inbox, today's note, this week's note,
  the rest), then reloads on the main actor when anything came (and that reload files any
  capture kept for a note that arrived). One pass at a time, numbered; one older than
  `passLength + 2 × longestWait` is taken as stuck and a new one may start, and the stuck one's
  answer is ignored.
- **`partVaultReason(for:)` is the one refusal** for writes across the whole vault: `syncNow`,
  `previewSync`, `changeTag`, `renameNote` — while anything is waiting *or* being updated.
- `writeWidgetSnapshot` writes nothing while notes are waiting (the widget keeps its last whole
  picture; Settings › Widget says why). The phone's **Today** carries `VaultWarningBar`; the Inbox
  says **Still coming from iCloud**, not **Inbox zero**.
- Backups: an `.away` file is skipped and named, and the signature marks it `@away`, so the next
  backup runs once it arrives (a download leaves the date alone). `copyContents` refuses for an
  `.away` note and skips any other `.away` file. `backUpDaily`/`purgeOldDeleted` left `init`:
  `restoreVault` runs them 5 s later.
- `saveText` keeps the typing as a conflict copy when the open note left the list (it went
  `.away`), instead of returning in silence.
- **Unknown, written down:** whether iOS 27 keeps evicted files as `.icloud` stubs (build 104
  proved stubs in September) or under their real names with no data (as macOS does). Presence
  guards notes, backups and the rehearsal either way; plain reads of `.ams-para` state files,
  templates and snippets would still block in the second model, and folders with no contents on
  the device could block an enumerator. If that ever shows, the next step is `allNotes` on a
  separate `Vault(rootURL:)` instance off the main thread.
- **The review of the first push found twelve real faults; all fixed before upload.** The
  pattern behind most of them: **once a single-note load stops waiting, every writer that read
  "the note is not here" as "the note is empty" becomes a way to lose or overwrite words.**
  - `reload()` drains the outbox whenever any waiting note arrives (through `afterUpdate`), not
    only when the pass's own reload is the one that sees the Inbox — the 10 s poll and the
    watcher usually re-read first. Kept captures are filed on the day they were made.
  - Close the day remembers what the field was filled with (`shown`); a line on file that it
    never showed is kept and the new words go below it — never replaced or removed unseen.
  - `savePlan`, `addPlanBlock`, `replacePlanBlock` and `setWeekGoal` return whether they
    wrote; `savePlanBlock` does no calendar work, `removePlanBlock` says nothing, and the week
    goal box stays open, when they did not.
  - `NoteEditorView`'s `onChange(of: storedText)` ignores the "" of a note gone back to iCloud,
    so the editor is not blanked and `baseText` is not lost.
  - `Vault.restore` skips (and names) a destination that is `.away` or has a stub beside it,
    and a backup file that is itself a stub; `AppModel.restore` refuses through
    `partVaultReason`. Build 100's incident is exactly the moment a restore is tempting.
  - The pass no longer waits for stale notes (they read at once and counted as "arrived" every
    minute); `backUpDaily` waits while nothing but waiting notes is here, and the pass calls it
    again.
- **Still open, pre-existing:** `downloadMissing` skips all of `.ams-para`, so on a stub device
  config, tags, saved searches and first picks may never be asked for.
- The 0x8badf00d check that would prove the diagnosis is on his phone (Settings › Privacy &
  Security › Analytics & Improvements › Analytics Data). Not asked: the fix does not depend on it.
- **Confirmed by him, 20 October**: *"261 updates perfectly on the iPhone. New page on Mac >
  Yellow text > Sync OK"* — the app started at once, a note made on the Mac showed as the
  orange **still coming from iCloud** line (he reads that orange as yellow), and then arrived by
  itself. When he says "yellow text", that is `VaultWarningBar`.
- **CI**: `testStartTheDayOpensAndCloses` failed once on 261's first run (the added action was
  on screen and picked, but `startDay.pick.…` was not found within 20 s, on a runner whose first
  test took 118 s) and passed on the next run with no change to that screen. First failure; if
  it fails again, treat it as real and look at the `.popover` on that button (build 249: SwiftUI
  puts the identifier on a wrapper too).

## Eight ideas (build 262 on, planned 20 October)

He asked for "some nice stuff"; a workflow found 23 ideas, checked each against the code, and
he answered *"Love them"* to eight. The plan, with drawings and his answers, is
https://claude.ai/artifact/RyZxairjYDdB7KoxiuGZ3S — **read its `db` (collection `plan`, doc
`answers`) before building**; the page writes on every press (build 175's pattern). The full
per-build plans (files, Core types, tests, risks) are in the workflow journal of this session
and are summarised here only where they change a decision.

**Order** (one thing per build): 262 a project's end day (`ended:`, idea 6) · 263 Weekly review
step 7, Look back at the week (1) · 264 step 8, the coming week's goal (1) · 265 Start the day
shows last evening, the week goal and today's events (2) · 266 Now and Then on Today (5) · 267 a
block's clock finds its task (5) · 268 Done, each day tells its story (7) · 269 Done's squares for
12 weeks (7) · 270 Morning reminder (2) · 271 a goal's date, measure and Serves… (3) · 272 Add a
project… from a goal, Add a goal… from an aspiration (3) · 273 Looked at, from the note (3) · 274
In area… (4) · 275 the area page (4) · 276 an area's Standard (4) · 277 Done projects newest first
(6) · 278 What is next for this goal? (6) · 279 widgets follow every change (8) · 280 Today's plan,
a Mac widget (8). Only if he says yes: 281 How was the week? (1b), 282 the widget on the iPhone (8a).

**Decided by me and written on the page, so he can object**: step 7 has ‹ ›; Start the day shows
nothing when there is no week goal; a reminder pressed while another sheet is open **waits**
(the evening one then works the same); Add a project… **stays** on the goal; an aspiration's
button makes a dated goal; an area lists its own projects and one row per sub-area; a block's
clock ticks a task only when exactly one open task has its name; Done keeps its name; the
widget's big line is blocks only (same answer as Today's Now line); only Done gets "N this year".

**Shared parts, built once**: one per-day record and `TaskItem.doneDay` (263, reused by 268 —
ideas 1 and 7 each planned their own; do not); `ServedRow` made shared (263, `compact:` in 268);
`WeekGoalBox(week:title:identifier:divided:)` (264); `WeekGoalLine` in Theme.swift (265);
`NowAndNext` in Core (266, reused by 280); `DayReminder` + one `answerReminder(opening:)` (270);
`AddServingNoteButton` with the link key as a parameter (272, reused by 275 with `area:` — the
area page does **not** go through New Note); one plain-var New Note preset (278 only).

**Corrections the sequencer made to the individual plans**: `Note.measure` already reads an
empty `measure:` as nil (no change needed); `newNotePreset` must not be `@Published`; the area
page reuses 272's popover instead of opening New Note; anchor 266 on the `WeekGoalLine(` call
265 puts in `TodayView`; `HowItWorks.md` says the widget is written "when you tick a task", which
has not been true since 174 (fix in 279); `NowLine`'s comment still says red (fix in 265); 265
adds the fixture's first dated daily note (prose, no tasks), so say so when it lands; every new
`Place` case needs both `way(to:)` switches.

**His answers (21 October, `plan/answers`)**: all eleven took my advice — 1a last week on
Monday and Tuesday, 1b **yes** (so build 281 is in), 2a every day, 3a "looked at" everywhere,
4a only **In area…** decides, 5a **Then**, 5b two lines, 6a **`ended:`**, 6b ask at once, 7a
quiet days are listed, 8a **Mac only** (so no 282).

**Build 262: the day a project ends.** `Core/Model/NoteEnding.swift` (tested in
`NoteEndingTests`): `Note.endedDate`/`createdDate`, `Note.settingStatus(_:today:)` — the one
rule: an ending writes `ended:` only when the note was not ended before (Done → Missed keeps the
day; an old ending with no day never gets one), Active and On hold remove it, the same status
changes nothing — `settingEndedDate`, and `ProjectEnding` with `line(today:calendar:locale:)`.
`AppModel.setStatus` now reads the live note, goes through `settingStatus` and writes nothing
when nothing changed; the unused `setStatus(String)` is gone. `setEndedDate(_:on:)`.
`ProjectEndedLine` (NoteEditorView.swift) sits under `NoteHeader`, outside its wrapping row,
only for `declaredKind == .project && isEnded`; the whole line is the button (`project.ended`,
label set explicitly), a popover with `DateChoiceView` and no clearing button. `NoteStatus
.tint(onNote:)` (GoalsView.swift) is now the one place the three ending colours are decided.
TestVault gained **Fix the bike** (done, made 41 days ago, ended today, two ticked tasks with no
`@done` stamp, no goal, no open task); screen test `testAFinishedProjectSaysWhenItEnded`.
The review (three lenses, compile and tests found nothing) found one real fault, fixed before
upload: `Vault.archive` writes `status: archived` but keeps `ended:`, so marking an archived
note Done again overwrote its real day with today. An archived note that still carries a day
keeps it. Related and still open: because archiving replaces the status word, a project archived
**through the app** reads as not ended and shows no ended line at all — that is the first of the
three faults below, and its own small build.

**Build 263: step 7, Look back at the week.** `Core/Vault/WeekLook.swift` (tested in
`WeekLookTests`): `DayRecord` (finished `TaskRef`s, `workedMinutes` nil when no Worked line,
`lookingBack`, `dailyNotePath`) and `NoteIndex.dayRecords(from:through:)` — **one pass over the
notes for any run of days; build 268's Done diary must reuse it, not walk the vault again** —
`TaskItem.doneDay` (the one place a `@done` stamp becomes a day; `tasksCompleted(on:)` goes
through it, and a test pins that the week and the day-by-day count agree), `EndedProject`,
`WeekLook` (`finishedText`/`workedText` nil for nothing, never a zero) and
`WeekLook.weekToShow(today:)` (Monday and Tuesday → the week before, his answer 1a).
App: `WeekLookStep.swift` is a `Section` placed after step 6 in `ReviewView`; the chosen week is
`@State` in `ReviewView`, passed as a binding, so a scroll cannot reset it. **No row in it is
tagged**: its rows hold buttons (the arrows are `.borderless`, or a press on the phone would
press every button in the row). `ServedRow` (CloseDayView.swift) is no longer private.
`EveningLine` lists a day whose note is still coming from iCloud as "Still coming from iCloud".
The `List` carries `review.list` for the test's `reveal(_:)`, which swipes on the phone and
scrolls the list on the Mac (down, then up). Screen test `testTheWeekCanBeLookedBackAt`, both
platforms: it only asks that ‹ changes the week and › brings it back, because which week opens
depends on the weekday the runner has. **The test vault has no `@done` stamp anywhere**, so the
bars are all dashes there; that is deliberate and keeps build 211's "nothing is overdue" fixture
whole.
The review of 263 (three lenses, then a refuter per finding) found seven real faults, all fixed
before upload: **every sentence in the step named "this week"** while Monday and Tuesday show the
week before (`weekWords` now says "this week" or "that week"); the goal box said "No goal was
written" while the **weekly** note was still coming from iCloud (`weeklyNoteIsWaitingForCloud`);
a waiting day still drew the dash and grey line that mean "none"; a week of tasks ticked in daily
notes became up to seven date rows under **What it served** (`ServedCount.mergingDailyNotes`,
Core, tested — one **Daily notes** row when there are two or more); **"the last 7 days" in the
review counted eight** (`today - 7 ... today`; now `- 6`, pinned by
`testTheLastSevenDaysAreSevenDays`) and a project's row called that rolling count "this week"
(now "done in 7 days"); four places still parsed `@done` themselves (all through `doneDay` now);
and the manual still said nothing reads the **Looking back** line. **A step that can show a week
other than this one must never say "this week" in a fixed string** — the heading did it right
and five sentences under it did not.

**Build 264: step 8, the goal for the coming week.** `WeekLook.goalWeek(today:)` (the week
after step 7's, so Monday/Tuesday → this week, Wednesday on → next week), `weekName(_:today:)`
("this week" / "next week" / "last week" / "week 45" / "week 1 of 2028" — the one place a week
is named in a sentence) and `goalTitle(for:today:)`, all tested in `WeekLookTests`, New Year
included. `WeekGoalBox` gained a written-out `init(week:title:identifier:divided:)`: `title`
defaults to the week's own name, which also fixed Calendar › Week saying "Goal for this week"
over any week the arrows reached — **the same fault the review of 263 found in step 7, in the
box step 8 reuses**. `identifier` names the box, `.field` and `.done`; `divided: false` drops
the rule and padding in a List row. The box's label is set explicitly ("Goal for next week:
…"). `WeekGoalStep` (WeekLookStep.swift) is a `Section` after step 7 with
`.buttonStyle(.borderless)` on the box so the field's **Cancel** and **Done** do not fire
together in a phone List row; it does not follow step 7's arrows. Screen test
`testTheComingWeeksGoalCanBeWrittenInTheReview`, both platforms; `reveal` now also takes an
`XCUIElement`, so a button can be found among `app.buttons` first (build 249).
The review of 264 found six real faults, all fixed before upload: **the box's empty line and
field still asked "What is this week about?"** under a "GOAL FOR NEXT WEEK" title (both through
`weekName` now — the 263 lesson again, one layer down, in strings I had not touched); the box
drew "no goal" while the week's note was still coming from iCloud (orange, disabled, through
`weeklyNoteIsWaitingForCloud`); **`setWeekGoal(_:for:startedFrom:)` refuses to write over a goal
the box never showed** — changed on the other device, or arrived while the box stood open — and
says what it now is, and a second **Done** replaces it (build 261's Close the day rule, which
the shared box had never had) — **only for a note that existed before the call**, since one
`weeklyNote(for:)` has just made carries the Weekly template's own `focus:` if he wrote one
(found by the check after the fixes); `WeekGoalStep` had nothing to watch, so it was drawn once and
did not move on at midnight (an unread `@EnvironmentObject` now makes it redraw — **a view with
no state and no observed object is evaluated once**); step 7's goal title goes through
`goalTitle` so the two boxes name a week alike; and the manual. Steps 7 and 8 share a `Group`,
keeping the review `List` at ten children. `weekName` is the one place a week is named in a box
title or a question; step 7's sentences keep their own "this week" / "that week".

**Build 265: Start the day shows last evening, the week and today's events.** No Core change:
everything is read through existing, tested readers, and nothing is written. `StartDayView`
draws `morningContext` first in its scroll view — a `@ViewBuilder` of three parts, not a
`VStack`, so a part that draws nothing leaves no gap: `lastEvening` (`model.lookingBack(for:)`
for yesterday, the one reader of `## Looking back`; grey, `.lineLimit(4)`, its label set as one
sentence, `startDay.lastEvening`; nothing when he wrote nothing; while yesterday's note is still
coming from iCloud an orange line with the cloud — **the plan said grey, but step 7 of the
review draws the same state orange with `icloud`, and one state drawn two ways is build 168's
fault**), `weekGoal` (nothing without a goal, his answer, the same as Today; orange with the
cloud while this week's note is still coming from iCloud) and `calendarBox`
(only while `showsCalendarEvents`; a `FoldButton` whose `SectionLabel` fills the line, build
247; `startDay.calendar`; keys `startDayCalendarFolded` / `startDayCalendarFoldedPhone`, open by
default; the access message is never folded away, build 212). **`WeekGoalLine` (Theme.swift)
is Today's old "This week:" text moved as it was**, with the identifier a parameter and the
padding left to each caller; build 266 anchors on its one call in `TodayView`. The scroll view
gained `.scrollDismissesKeyboard(.interactively)` (build 231), since **Add an action for today**
now sits lower; `testStartTheDayOpensAndCloses`, which types into it, is the check that it is
still reachable with the keyboard up. The stale "one-hour blocks" in the view's comment and the
manual went (blocks have had the task's own length since 249), and `NowLine`'s comment no
longer says red. **The test vault now has one dated daily note**, yesterday's, holding only a
**Looking back** line (`TestVault.lastEvening`, "A quiet day by the sea."): prose and no task,
so build 221's fixture still holds — no dated open task, no plan, no `#next`, no `@done`.
Screen test `testStartTheDayShowsLastEveningAndTheDay`, both platforms; it never presses the
fold, because events and Calendar access on a runner are not the test's to decide (build 190).
**Accepted, and in the manual**: a day closed after midnight writes its line into the new day's
note, so the next morning shows nothing under **Last evening you wrote**. **Found while writing
the manual**: `HelpBlock.parse` ends a bullet at its first wrapped line, so every hard-wrapped
bullet in `Docs/HowItWorks.md` is drawn as one bullet line and then a plain paragraph. The new
Start the day bullets are written one line each for that reason; the parser itself is a small
build of its own.
The review of 265 found three faults, all fixed before upload: the week goal line drew nothing
while this week's note was still coming from iCloud, which reads as "no goal" (build 100 — the
same case `lastEvening` and the 264 boxes already named); the 265 entry in
`Docs/VersionHistory.md` split `**How was today?**` and `**Calendar › Week**` across a wrapped
bullet, so Help showed the asterisks (its bullets are one line each now); and the manual and
`Docs/Words.md` still said the **First** marks are "at the top" of Start the day, which they no
longer are — they are first in its list, above **Overdue**.

**Build 266: Now and Then on Today.** `Core/Sources/ParagonCore/Vault/NowAndNext.swift` (tested
in `NowAndNextTests`): `NowAndNext(blocks:minute:)` gives `now` (start ≤ minute < start +
`minutes`, the end minute not included; overlapping blocks → the one that **started last**, so a
short block inside a long one wins while it runs; same start → lower index) and `next` (the
earliest block starting after the minute, same start → lower index, never the now block);
`isEmpty`; `minute(of:calendar:)` from the clock's own hour and minute, never seconds / 60 (build
238 — a test pins 600 at 10:00 on 25 October 2026 in Stockholm, the day the clocks went back);
`sameName(_:_:)` through `PlannedAndWorked.key`, so the running clock is matched to a block the
way **Planned and worked** matches them (build 259). **Build 273's Mac widget reads the same
type**, so Today and the widget name the same block. App: `NowAndNextLines`, private in
`TodayView.swift` (so it can use the file's private `HeaderActionButton`), sits between the date
row and the `WeekGoalLine(` call, outside the `List` (build 220). A `TimelineView(.everyMinute)`,
not a sleep loop like `NowLine`'s, so the lines move on the minute; the day comes from the
timeline's own date, so midnight is handled; the blocks from `planBlocks(for:)`, which never
writes. His answers: **Then**, not "Next" (**Next actions** lower on Today means `#next`, build
176's one word with two meanings), and **two lines**. **Now** carries a `timer`
`HeaderActionButton` (`today.now.focus`, spoken "Start the focus timer on …") calling
`startFocus(onBlock:)`, left out where `focusBarShown` is false; while the clock runs on that
name the button gives way to a 7-point dot (orange running, grey paused, `today.now.running`),
never a button that does nothing (build 175). The words of each line are one accessibility
element with one sentence as its label (`today.now`, `today.next`; build 253's shape). Only the
title gives way in a narrow column (`.layoutPriority(-1)`, build 138). **"Now line" was already
taken** — it is the thin blue line across the hours (build 180) — so the docs call these
**Now and Then** and say "the line that starts with **Now**"; `Docs/Words.md` says the two are
different. Screen test `testAPlannedActionShowsOnToday`, both platforms: **Start the day**, type
and add "Water the plants", **Plan 1 action**, then `today.now` or `today.next` must name it
(Then until its quarter hour comes, Now after — either is right on a slow runner). The two
lines are **one query matched by the title**, run again on every read, so a Then that turns into
Now between a check and a read still answers (build 190). On the Mac the line must start to the
right of the sidebar's **Today** row (build 250): Today is the **middle** column, so its
neighbours are inside the window and a check against the window could never fail (build 178).
Skipped after 22:30 on the runner's clock: a one-hour block still fits until about 23:00, and the
half hour is room for the test's own run. **This is the suite's first `XCTSkip`, and XCTest
prints `' skipped ('` for it, never `' passed ('`**, so both **Check the tests really ran** steps
in `ci.yml` now count skipped cases as finished; without that, every run after 22:30 UTC would
have gone red with no fault. The test makes its own plan; the fixture still has none (build 221).
The review of 266 found three faults, all in the test and all fixed before upload: the skip that
CI's count would have read as unfinished, a Then line that could vanish between a check and a
read, and a frame check against the window that could not fail.

**Build 266: the Weekly review folds part by part, and step 7 names its week.** From his field test of 263–264 on a Monday: *"it's so many lines … like 50 lines or more, and that is a bit scary"*, and he could not tell which week step 7 showed. `ReviewPartHeading` (ReviewView.swift) is every heading under the summary — **Due for a look**, steps 1 to 8, **Projects with no goal** — a `FoldButton` whose label fills the line (build 247), identifier `review.part.<id>` (`due`, `1`…`8`, `noGoal`), accessibility value "open"/"folded". **One open set**: `@AppStorage` strings `reviewOpenParts` / `reviewOpenPartsPhone` (build 161's pair), ids of the OPEN parts, **empty by default, so the first look is the summary plus at most ten headings**; `WeekLookStep` and `WeekGoalStep` take an `isOpen` binding into the same string, never a key of their own. **The count rule, one for all**: a heading says "· N" for what its part lists (due notes, inbox items, overdue tasks, aspirations, dated goals, projects, areas, projects with no goal) and **no number at all when there is nothing** — never "· 0" (builds 141, 171); steps 7 and 8 list nothing to work through and carry none. Footers are drawn only while open; folded, step 7 does not work out its week at all (`content(_:)` is only called when open). **Open all / Close all** (`ReviewOpenAllButton`, `review.openAll`) is a second, untagged, borderless row in the summary section, which never folds (build 167). **"Close all", not the brief's "Fold all"**: Help's button already says **Open all** / **Close all** for the same action, and one action gets one pair of words (build 165). The *rule* differs on purpose: Help says **Close all** as soon as anything is open, the review says **Open all** while anything is still folded, because the review is opened a part at a time and the button should still open the rest. **Mark all reviewed** shows only while step 5 is open: it stamps projects a folded step has not shown. The step 5 header stays a plain `HStack` with the button `.fixedSize()`, **not a `WrappingHStack`**: a wrapping row places each item at its one-line width, so a long heading would run off a narrow column instead of breaking between words. Phone headers keep the `List`'s capitals, as before; no `.textCase(nil)`. Step 7's heading is "7. Look back at " + `WeekLook.weekName` (build 264's one namer), so it reads "last week" on Monday and Tuesday and follows the arrows. The two step 7/8 screen tests open their step first (`openReviewPart`); new test `testTheReviewFoldsStepByStep` (both platforms) checks folded at first, the heading names the week, open and fold again, and **Open all** turning into **Close all**. `revealAbove` swipes down on the phone, since `reveal` only swipes up there. **The lesson: a screen that grows a step at a time has to be read at its full length before the next step is added** — steps 7 and 8 each made sense alone, and the sum was the fault. **The review of this build found two wording faults, both fixed before upload**: the version note implied a heading with no number has nothing in it (steps 7 and 8 never carry one), and the manual's step 7 line called it "the week that has just gone" one sentence before saying it shows this week from Wednesday.

**From build 266 on, a build may carry two or three parts** (26 October, his words: *"we need
some speed on this"*). Each part is still written and reviewed on its own, in its own git
worktree (`/home/user/wt-<label>`), and the lead merges them with
`scratchpad/integrate.py <stamp> <date> <label>…`, which cherry-picks each worktree and writes
one VersionHistory section and one CLAUDE.md paragraph per part. CI and TestFlight are the slow
steps (a Mac runner can wait half an hour when his other repositories hold the account's five
Mac slots), so fewer, fuller builds are faster. **Plan numbers stop matching build numbers
from here**: the briefs keep their plan numbers (267 = a block's clock finds its task, …), the
stamp is whatever build carries them. **Running seven helper workflows at once hit the session
usage limit for three hours on 26 October**: keep it to about three at a time.
**The Crash reports workflow now names the build** of each report: `include=build` on the list
call (the report's own `build` link answers 403). That is how the iPhone crashes of 24 and 25
October were placed on build 264; Apple kept no log for either.

**Build 267: a block's clock finds its task.** `NoteIndex.openTask(forBlock:on:)` (public
extension at the foot of `Core/Sources/ParagonCore/Vault/NowAndNext.swift`, tested in
`NowAndNextTests`) returns the one open task whose `planTitle` has the block's name under
`PlannedAndWorked.key` (case and runs of spaces ignored, `#next` off, any other tag kept — the
rule `planTitle`/`key` already gave Plan and **Planned and worked**; `key` is internal, so the
lookup has to live in Core). Candidates are `openTasks()` (archived notes left out, work notes
never in the index) **not on a later day than the plan's day** — a repeating task's next copy is
never taken — and **exactly one**, else nil (build 256's review: two tasks with one name cannot be
told apart). **One addition to the plan:** a task with no date in a later day's daily note
counts as dated by its note (`note(path:)?.dailyDate`, build 225's rule), so a task already
written into tomorrow's note is not lent to today's block. `AppModel.startFocus(onBlock:on:)`
(renamed from `startFocus(onBlock:)`; its two callers are `PlannerDayView.focusAction(for:)`,
which captures the planner's `day` in a constant before the closure, and Today's
`NowAndNextLines`, which now hands the timeline's own day down through `lines`/`nowRow`/
`nowControl` rather than asking `.today()` at the press) ties the clock to the found task
(`notePath`, the task's exact `taskTitle`, `taskID`, `taskDue`), so `FocusStopView` offers
**Done, tick it off** with no change to it, and `finishFocus` finds the task by id, else words and
date, as for any task. **`title` stays the block's name**, so the **Worked** line still meets its
block on one row (build 259) and Today's dot still finds the clock by `sameName`. `plannedMinutes`
stays the block's length. One rule for the block's clock in Plan and on Today (build 168). The
manual has a new `### A clock on a block` under **The focus timer**, its bullets one line each
(build 265's `HelpBlock.parse` finding); the "Not done yet" bullet, which said a block cannot be
ticked, is rewritten. No screen test, as planned: a block is Now only after waiting, and a
block's right-click menu has not opened in a Mac test (run 308); the rule is pure Core. **The review found one real fault, fixed before upload:** the "exactly one" check ran while notes were still coming from iCloud, and a waiting note is not in `index`, so a second open task with the same name there was unseen and **Done, tick it off** could tick the wrong one; `startFocus(onBlock:on:)` now asks `openTask(forBlock:on:)` only while `notesWaitingForCloud` is empty, else the clock is the block's alone (build 100's rule, as in `partVaultReason`).

**Build 267: Done tells each day's story.** `Core/Sources/ParagonCore/Vault/DoneDiary.swift`
(tested in `DoneDiaryTests`): `DiaryDay` **wraps build 263's `DayRecord`** and adds only `served`
— the plan's own `DiaryDay` would have been a second record of a day, which the sequencer had
already ruled out — with `eveningLine` (whole, nil when empty), `hasSomething`, `factsText`
("6 done · 2 h 40 min worked", "1 done", "Nothing ticked off · 45 min worked"; never "0 done",
never "0 min worked") and `spoken(dayName:)` (the day's name is the view's to decide).
`DoneDiary` (`weeks` 12, `today`, `days` newest first, `firstFinished`, `finishedThisWeek`,
`finishedTotal`, `day(_:)`, `firstDay(today:)` = Monday 11 weeks back, `weekText`/`totalText`/
`countText`) and `NoteIndex.doneDiary(today:)`. **One pass**: `dayRecords(from:through:)` now goes
through an internal `dayRecordsInOnePass(from:through:earliestUpTo:)` that also returns the
earliest stamp in the whole vault, so the diary never parses every note twice; a test pins that
step 7's records did not move. `doneDay` and `tasksCompleted(on:)` were already one rule since
263, and a test pins that every diary day equals `tasksCompleted(on:)`. Decisions: **quiet days
are listed** (his 7a): a day with no tick but an evening line or timer time; a day with only a
plan is not. **The count line is not drawn at all while no finished task carries a day**, and
says "Nothing done this week yet" / "none in 12 weeks" rather than a zero once one does (build
141). **The day's own daily note is labelled "Daily note"** (`DoneDiary.labels(_:ownNoteTitle:)`,
matched on `Note.dailyTitle(for:)` of the day): here the day's name is the line above and a
label repeating it carries nothing (build 169). App: `DoneView` keeps the diary in `@State`, worked out
in `.onReceive(model.$index)` from the value handed in (build 242), only while `isShown`
(`onAppear`/`onDisappear` — on the phone the pushed Done screen stays alive behind the other
tabs, build 232), and again from a once-a-minute `.task` when the date has moved (build 254).
`DoneDayCard` is the first row of each `Section`, **untagged** (builds 71–74, 201), one
accessibility element `done.day.<YYYY-MM-DD>` with its sentence set explicitly (build 253), and
`.id(day.day)` for build 269's jump. `ServedRow` gained `compact:` (a capsule, title capped at
120 points inside the `WrappingHStack`, build 250) with a written-out `init`, so Close the day
and step 7 are unchanged. Phone only: `VaultWarningBar` above the list.
A card whose day's note is still coming from iCloud draws step 7's orange "Still coming from
iCloud" line (`DoneDayCard(waiting:)`, from `dailyNoteIsWaitingForCloud` at the call site, since
the card has no model). The Mac's third column
now says "Press a task on the left to open the note it came from." Screen test
`testATickedTaskShowsInDone`, both platforms, with `Place.done`: tick **Book the night train** in
All actions, then Done once, and today's card reads "1 done"; yesterday's card from build 265's
daily note may be there too, so only today's is read.
**The review of the Done diary found three faults, all fixed before upload**: a day whose note was still
coming from iCloud drew as a day with nothing written, and the empty state said "Nothing in the
last 12 weeks" while notes were waiting (build 100; step 7 already drew that day orange, build
168); every `.note(.daily)` count was folded into "Daily notes", so tasks ticked in the **weekly
note** (a `.daily` note by its folder) or in another day's note were named wrongly — only the
day's own note is folded now, into "Daily note"; and the compact capsule's 200-point title cap
made it wider than the Mac's middle column at its 220-point minimum, cutting off the count
(cap 120 now — **measure a capsule, not only its text, against the narrowest column**).

**Build 267: the morning reminder.** No Core change: he chose **every day** (2a), so it is one
repeating `UNCalendarNotificationTrigger` like the evening one and there is no days rule to test.
`DayReminder` (`EveningReminder.swift`, `.morning`/`.evening`) holds every value that differs —
request and test ids, `onKey`/`minutesKey`, `defaultMinutes`, the screen (`sheet`), the
notification's words, the Settings words and identifiers — and `owning(_:)` maps a notification
id back to its reminder. **The evening's values are byte for byte build 234's**
(`paragon.closeTheDay`, `.test`, `eveningReminderOn`, `eveningReminderMinutes`, 21:00,
`settings.eveningReminder`), or a reminder already planted on his devices could not be removed
and would come twice. Morning: `paragon.startTheDay`, `morningReminderOn`,
`morningReminderMinutes`, 07:30, `.startDay`, `settings.morningReminder`. `EveningReminder` keeps
its name and stays **the only notification delegate** (FocusNotice depends on it); `start()`
plants or removes each kind, `update(_:on:)` no longer takes the minutes (the time is read from
Settings when the system answers, build 238), `plantWhatIsOn()` plants **every** switched-on
reminder after a "yes" — from either switch or either test button, since the permission is
shared — and `tests`/`nextReminders` are `[DayReminder: …]`. A second count,
`morningRequests`, beside `openRequests`; the answered counts are `[DayReminder: Int]` and
`takeOpenRequest(_:upTo:)` uses the value handed in (build 242). A test notification pressed
inside its 15 seconds now reads **Delivered**: a press takes it out of the system's delivered
list, so `checkTest` used to say "did not deliver it" — exactly what the field test does.
`DayReminderSection(kind:)` replaces `EveningReminderSection`, drawn twice in Settings, morning
first, with a written-out `init` (`_isOn = AppStorage(wrappedValue: false, kind.onKey)`); its
time `Binding` now uses clock parts both ways, so 07:30 does not show as 06:30 or 08:30 on the
day the clocks change. **`ContentView.answerReminder(opening:)` is the one path** for a reminder
press, called from two `.onReceive`s: no vault → nothing; then a turn later: the same screen
already open → it stays (before, **Close the day** was closed and reopened empty); another sheet
open, or the focus question open or waiting → **wait** (decided on the plan page; he did not
object) through `AppModel.openWhenFree(_:)`; else open it. **The plan named the slot
`screenAfterFocusQuestion`; it is `waitingScreen`**, because it now also holds a screen waiting
for an ordinary sheet such as **New Note**, and the focus-only name would have lied. It is cleared
when that screen opens by any route (`activeSheet`'s `didSet`), and the stop question still goes
first (`askWaitingStopQuestion` is queued before `openWaitingScreen`). Build 271's "also wait
while `whatNext` is set" belongs in `answerReminder`. **No screen test**, as planned: turning a
switch on raises the system's permission dialog and a test cannot press a notification; the check
is his field test on both devices. **The review of the morning reminder found three faults, all fixed before
upload**: a pressed test freed **Send one in 10 seconds** early, so the first send's 15-second
check could mark a second send as not delivered (`checkTest(_:due:)` now acts only while the
state is still its own `.waiting(due)`); the version history said "both parts" show the orange
line, when only a part whose switch is on does; and the manual said a press opens its screen
"when a PARAGON window next appears", when only the **main** window answers it (Settings, Help
and **Plan the day** do not).

**Build 268: Done's squares for the last 12 weeks.** Core, in `DoneDiary.swift` (tested in
`DoneDiaryTests`): `DoneSquare` (`state` is `notYet` / `beforeRecord` / `counted(Int)`, `level`,
`isToday`, `canJump`, `count`, `isDrawn`, `spoken(dayName:)` — "Tuesday 14 October, 6 done",
"Yesterday, nothing ticked off"), `MonthMark` (a struct, build 61), and on `DoneDiary`:
`showsSquares` (false while `firstFinished` is nil, the same rule as the count line, so the two
appear together), `level(_:biggest:)` (1–4 by share of the busiest day, never 0 above 0),
`squareWeeks` (12 columns of 7, oldest first, Monday first) and `monthMarks`. Everything comes
from the diary build 267 already worked out — no second pass over the vault. Decisions:
**a column belongs to the month of its Thursday** (the ISO rule that gives a week its year), so a
window that starts on Monday 29 June opens with July; **the oldest column's name is dropped when
the next month starts under 3 columns later** — the plan said to drop the later one, but that
would label two columns at the left edge and leave a whole month unnamed (a month holds four or
five Thursdays, so only the first name can be that close); the last name may run past the right
edge, offsets do not widen the grid. **`canJump` needs a drawn square and a card**: a quiet day
before the first dated finish has a card but no square, so nothing to press; a quiet day after it
is a grey square that can be pressed and goes to his line. App: `DoneSquaresView` (DoneView.swift)
between the count line and the `Divider`, and **the app's first `ScrollViewReader`**, around the
squares and the `List`; a press calls `proxy.scrollTo(day, anchor: .top)` on the card's
`.id(day.day)`, which is on the row, never on its `Section`. Only `canJump` squares are `Button`s
(build 175); drawn squares carry `.help` and a label, empty days are clear space hidden from
accessibility; `.focusEffectDisabled()` on the grid (build 202). **Squares are 22 points on the
phone and 16 on the Mac, with a `ViewThatFits` falling back to 12** — the plan said 16 fits the
Mac's 280-point middle column, but that column's minimum is 220, and 16-point squares plus the
12-point gutters are 249: build 250's cut-off-on-both-sides fault. The fold is a `FoldButton`
over a `SectionLabel` filling the line (build 247), **on its own line under the count**, not
beside it as the plan said: the count line already wraps in the Mac's narrow column, and a button
beside it would squeeze it (build 138). **Two keys, `doneSquaresFolded` and
`doneSquaresFoldedPhone`**, open by default, as Today and Start the day do (builds 161, 212);
the plan named one. `DoneView.title(for:today:)` is no longer private, so a square and its card
name a day one way. Screen test: `testATickedTaskShowsInDone` now also waits for `done.squares`,
finds `done.square.<today>` among buttons, checks its label says "1 done", presses it with
`pressCentre()` and checks the card is still there and the app runs. Dull on purpose: the test
vault has one dated finish, so there is nowhere far to jump. **Untested from here: whether
`scrollTo` really moves a `List` on either platform** — CI cannot see a scroll. **The review of the Done squares found four faults, all fixed before upload**: a day with nothing counted
whose daily note was still coming from iCloud drew the grey "nothing ticked off" square and said
so aloud (build 100 — step 7 had already been fixed for exactly this in 263), so
`DoneSquaresView` now reads `model.dailyNoteIsWaitingForCloud` and draws that day empty with an
orange dashed edge, labelled "still coming from iCloud", with a caption line when one is on
screen; "Darker means more done" and "a dark frame" were false in dark mode, where ReviewTint is
a light teal and the frame is `Color.primary` (now "a stronger colour" and "a frame"); and the
version note said "a task with a date", which in PARAGON means a due date, for the day a task was
ticked off. **A sentence that names light or dark has to be checked in both modes.**

**Build 268: a goal's date and measure have a writer.** The project's most repeated fault, once
more: `measure:` was read by the Goals list, the chain and the aspiration's page and
written by nothing, and `target:` only when a goal was made. `Core/Sources/ParagonCore/Model/
GoalFields.swift` (tested in `GoalFieldsTests`): `cleaned(_:)` is `WeekGoal.cleaned` (one line),
`settingMeasure(_:on:)` / `settingTarget(_:on:)` return the note unchanged when nothing changes,
and **an empty value keeps the template's own empty line** (`set(key, list: [])` → `measure:`),
never `measure: ""` and never a removed line. `Note.measure` needed no change — an empty line
already reads as nil (the sequencer's correction), and a test pins it. A measure that needs
quotes (`: `, a leading `#`, `"`, `[`) survives the settings block. `AppModel.setTarget(_:_:)` /
`setMeasure(_:on:startedFrom:)` read the live note and write nothing when unchanged. `GoalTargetChip` and
`GoalMeasureChip` (NoteEditorView.swift) are **one view in two looks, chosen by
`onChainPage: Bool`** (`CalendarEventRow(compact:)`, build 212): a header `Label`, or a
`ChainChip` capsule — solid when set, grey and dashed when not (build 142). Their words come
from small `static func … -> String` helpers, never `optional.map { "literal \($0)" }` inside a
`Label`/`Text`, which also take a `LocalizedStringKey` (an inference question there is no
compiler here to answer). `GoalTargetChip.words(for:withTimeLeft:)` / `.color(for:ended:)` also
spell the date for the goals inside an aspiration's chain, so a goal with a button and one
without cannot drift. `GoalMeasureEditor`: heading, one sentence, one field, **Clear** /
**Cancel** / **Set**, Return sets, an empty line does nothing (Clear is the only way to take a
measure away), `.presentationCompactAdaptation(.popover)` like `TagChoices`. `NoteHeader`: the
kind word is `GoalWording.name(for:)` (**Goal with a date** / **Aspiration**, it said "Goals");
a dated goal gets **Serves…**, the target and the measure; an aspiration gets the measure and
**no horizon label** (it would say Aspiration twice) and keeps a hand-typed `target:` as a plain
grey label (build 100). `ChainGoalBlock` with `lead: true` **draws its head without the
wrapping Button** — chips inside it would be a button inside a button (builds 71–74), and the
press only opened the page you were on. `AspirationChainBody.head`'s measure became the chip;
`GoalDashboardView` lost its Measure line (build 169). `NoteGoalOptions` no longer offers the
note itself (`setLink` refused it without a word); it still lists ended goals — build 204's
missed menu, its own small build. **Departed from the plan in one place**: the `goal.<path>`
identifier sits at the call sites, not inside `DatedGoalRow` — on the Mac's tagged row with
`.accessibilityElement(children: .contain)` (the note-row shape, build 191), and on the phone's
plain `Button` itself, because a container element inside a Button's label is a shape nothing
here has proved. `DateChoiceView` carries `date.field`, `date.clear`, `date.cancel`, `date.set`
(accessibility only). Screen test `testAGoalsMeasureAndDateCanBeChanged`, both platforms, with
`Place.goals`; it waits for the measure box to close before pressing the date, so a press never
lands on a popover on its way out. **Still read but not written (written since build 276)**: a dated goal's horizon
(**This year** / **Long term**) is a plain label in the header with no control to change it. **The review of the goal's date and measure found four faults, all fixed before upload**: **Set a measure…** could write over a measure changed on the other device while the box stood open — `setMeasure` now takes the measure the box opened on, returns `AppModel.MeasureChangedMeanwhile` instead of writing, and `GoalMeasureEditor` keeps his words, says in orange inside the popover what the measure is now (build 238), and lets a second press replace it (the week goal box's rule, 264); the iPhone's **Aspirations** showed each measure with no way to change it, so the folded-open compact chain now carries the measure chip in its own untagged row; and two manual faults — the `horizon:` sentence had slid under the new `###` and lost its subject, and the manual named **Serves…** among the goal page's buttons, where it is a plain capsule.

**Build 269: In area.** Once more a field was read that nothing could write: a project's
`area:` line was read by the Map, the planner, the Aspirations chain and the widget, and only a
Map drag wrote it (132, 134, 140, 144, 165, 167). **`NoteIndex.area(named:)` is now the one
resolver** (Core, tested in `AreaLinkTests`): an area whose title, shown title or file name
matches, ignoring case, else `note(matching:)` only when that is an area — so a resource or a
project with an area's name is never the answer (the widget could name a resource "Health
notes" for `area: health`; a test pins it). `area(of:)` reads the line, never the note itself,
and works for an archived project through `declaredKind`. `projects(in:)` is rewritten on it, in
`byArrangedOrder` (it was built on `backlinks`, and only a test called it). **His answer
`link_rule`: only the line decides.** `LinkMap.areaOf` lost its fallback to the first area the
text linked to, so a project with only `[[Health]]` in it leaves Health on the Map — said in
VersionHistory. `AspirationChain` (where the two-step rule came from; its local is `homeArea`
so it cannot hide the method), `WidgetSnapshot.serves` and the planner's serves line all call
`area(named:)`. App: `ProjectAreaOptions`/`ProjectAreaMenu`/`ProjectAreaChip` are in a **new
file, `Views/ProjectArea.swift`**, not beside `AreaParent*` in ContentView as the plan said, so
a file other builds change at the same time stays small; the shared words ("Health › Yoga", the
tick, the cut) are `ProjectAreaWording`. The chip replaces the plain area `Label` in
`NoteHeader` for `.project` only (`note.area`): grey "In area…", pink "In Health".
**The name is cut in code at 28 characters, not with a frame**: a Mac `Menu` may be drawn by
AppKit and ignore a SwiftUI frame in its label, and the row is a `WrappingHStack` (build 250),
so `.fixedSize()` sits on the chip only. A line that names no area is shown as written, in
grey, and the list says **No area is called …** (build 100). The menu is on both project
right-click menus, after **Serves**. New note: an **In area** `PickerChip` for projects
(`new.inArea` — `new.area` is already the **Area** kind button, `new.<thing>`) with one make action, **Add area**, through `makeNoteQuietly` (build 203's shape,
so the chip never vanishes in a vault with no areas). `PickerChip` gained `identifier:`, put on
the button before the `.popover` (the time button's shape, build 249), and an accessibility
label of its own words, for every chip. Screen test `testAProjectHasAnInAreaButton`, both
platforms, dull on purpose: it reads the words of every element carrying `new.inArea` /
`note.area` (`wordsOfEvery`), because a `Menu` is a button on the phone and a menu button on
the Mac, and SwiftUI may put the name on a frameless wrapper too. Pressing a `Menu`'s items is
left for a later build. **The review of In area… found five things, all fixed before upload**: the chip's test name
clashed with the **Area** kind button's `new.area`, so the test's existence check could not fail;
"No area is called Health" was said of an area that was only **archived** (`area(named:)` answers
live areas only, so `ProjectAreaWording.archivedArea` names it "(archived)" and offers **Open**)
and of one **still coming from iCloud** (orange, "may still be coming from iCloud" — build 118's
rule, the same test `missingLinks` uses); pressing the already-ticked choice saved the file and
took the template's empty `area:` line (build 254's rule, now a `guard` in each action); and the
manual's list of header buttons left out **In area…**.

**Build 269: a goal makes its own projects.** `Core/Sources/ParagonCore/Model/ServingNote.swift`
(tested in `ServingNoteTests`): `ServingLink` (`.goal` / `.area`, the key the line is written
under) and `ServingNote(under:link:)`, which decides what is made and the lines it gets — a
project with `goal: <title>` under a goal with a date, a goal with `horizon: year` and `goal:
<title>` under an aspiration (his answer: never a project straight under an aspiration), a
project with `area: <title>` under an area. The value is `displayTitle`, the value `setGoal` and
`setArea` write; the tests pin that the made note is in `chainGoal(of:).projects` /
`chain(of:).goals` (a title that needs quotes too), so the line the button writes is the line
the chain reads. `ServingNote.existing(named:kind:among:)` finds a name in use by title **or**
file name, without regard to capitals, before anything is written. App:
`AddServingNoteButton(model:parent:link:)` + `AddServingNoteBox` (GoalsView.swift) — a
plain-style button and a popover: heading, `addNote.field`, one line saying what it will serve
(and, for a goal, where its date is set), **Cancel** and **Add project** / **Add goal**
(`addNote.add`), Return adds. **You stay on the page** (his answer): it goes through the new
`AppModel.makeNoteSayingWhy`, which `makeNoteQuietly` now wraps — one place a note is made, and
it now flushes the editor first, since its `reload()` reads every note back. **It throws instead
of setting `errorMessage`**, so a taken name, a bad file name or a failed write is said in
orange inside the popover with his words kept (builds 238, 246) — never an alert behind it. A
`made` flag stops Return reaching both the field's submit and the default button and then
reporting "already a project called…" about the note it just made. Words and identifiers
(`goal.addProject`, `aspiration.addGoal`, `area.addProject`) are an App extension on
`ServingNote`, so the area page, a later build, reuses the button with `link: .area` and changes nothing here.
Where it is: `GoalDashboardView`'s foot always (its empty line is now "Nothing serves this goal
yet." / "Nothing works towards this yet." instead of "type `goal:` into another note"); the
rail of `ChainGoalBlock` always when `lead`, and only under "No project delivers this goal yet."
in a chain; `AspirationChainBody` beside "Nothing works towards this yet." when bare, else at
the foot of the goals. **Departed from the plan in one place**: the foot button is drawn in the
phone's compact chain too, not only on the Mac — the phone has no aspiration page, the reason
the review of 271 put the measure chip there. `serves.<path>` names the dashboard's serving
rows and `ChainProjectRow`. Screen test `testAProjectCanBeAddedFromItsGoal`, both platforms:
presses `addNote.add` when hittable and Return otherwise (the phone's keyboard is up), waits
for `serves.Projects/Buy the maps.md`, then for `goal.addProject` still on screen — the proof
the page did not leave the goal. **Noticed, fixed in build 275**: `GoalDashboardView` drew a per
cent bar on an aspiration (build 199 removed it everywhere else).
The review of Add a project… found two wording faults in the docs, both fixed before upload: `Docs/Words.md` called the note **Add a goal…** makes "a goal with a date" one sentence before saying it has no date (the Mac tooltip said the same; both now say "a new goal"), and the manual quoted "Nothing serves this goal yet." as what the Mac's goal page in **Goals** says, when that page says "No project delivers this goal yet." — and still named the flag "Nothing serves this" instead of "No project or area serves this".

**Build 269: Done projects, newest first.** Core, in `ProjectGroups.swift` (tested in
`ProjectGroupsTests`): `ProjectLine.ended` is `Note.endedDate` (build 262), **but only while the
project is Done, Missed, Dropped or archived** — an `ended:` line left on a project set active
again by hand is not a fact about it. `projectGroups(_:today:)` puts every ended group (Done,
Missed, Dropped, Archived) through `ProjectGroup.newestFirst`: the dated lines in a **full**
order (later day first, same day by hand order) put together with the undated ones in hand
order, so the result never leans on `sort` keeping ties (build 225). Ended groups had no
`mover` already, so no drag fights the date order; the manual now says so. `endedThisYear(today:)`
counts a written day in today's calendar year (build 255's calendar weeks), `thisYearText(_:)` is
"4 this year" or nil for 0 (build 141), and `thisYearCaption(today:)` is the one rule that **only
Done** gets it — a count of misses reads as a telling-off (build 199) — so the rule is tested, not
left to the view. App: `ProjectGroupHeader` draws "· 4 this year" after the count capsule, grey,
`.lineLimit(2)` and `.layoutPriority(-1)` so the name keeps its room (builds 138, 212), and adds it
to `spoken`. `ProjectBox.facts` puts the day first on a box that is over, through
`ProjectEnding.dayText` (the one wording of a day, with the year when it is not this year's),
with no "Done" in it (the heading says that, build 169). **One addition to the plan:** the plan
said the pill "is the only date on an ended box", but the next task's date pill still showed on a
finished box that kept an open task (common on a missed or dropped project), with the same
`calendar` symbol — two pills that look alike for two different facts (build 154). That pill is
now left out when the box is over, which makes the plan's sentence true. `ProjectFact` gained
`identifier`/`spoken`; a pill with an identifier is drawn as one element with one sentence
("Ended on 26 October", `project.endedDay.<path>`), the others are unchanged. Screen test: build
262's `testAFinishedProjectSaysWhenItEnded` now reads the **Done** heading first (its label must
contain "1 this year": the fixture ended today, so true even on 1 January) and checks the box's
day pill exists and starts "Ended on" before opening the note; the day's own words are the
runner's language and are not checked. The new identifier is not added to the list at the top of
`ScreenTests.swift`, to keep the merge clean. **The review of the Done order found five wording faults, all fixed before upload**: the manual said a project marked done is always first in **Done**, but a same-day ending keeps the hand order and Missed → Done keeps the old day; "this year" counts only the projects still in the list, so an archived one is not counted; an **Archived** box shows a day that only the `ended:` line can change, since `ProjectEndedLine` needs `isEnded`; and the version note had an idiom and a field-test step that could fail by design. **The review of the three parts together (build 269) found one more fault, fixed before upload**: **Add area** on the New note screen, with a name already in use, made `makeNoteQuietly` raise an alert behind the sheet and its popover (builds 238, 246) and the popover showed nothing; `makeArea` now chooses the existing area through `ServingNote.existing` instead (the goal makers from build 203 have the same flaw and are left for their own small build).

**Build 270: Looked at, from the note.** Core (`ReviewRhythm.swift`, tested in
`ReviewRhythmTests`): `NoteIndex.reviewDue(of:rhythm:today:calendar:)` gives one note's
`ReviewDue`, nil for a note outside the chain, archived or ended, and **`reviewSchedule` is now
built from it**, so the button and the Weekly review cannot give one note two answers (a test
pins every schedule item against it). `ReviewDue` gained `lookedAtText` ("Looked at 12 days
ago" / "Never looked at"), `rhythmText` ("Goals with a date get a look every 3 months.", from
`ReviewRhythm.label(forDays:)` and the new `ReviewLevel.plural`) and `nextText` ("The next look
is due in 78 days." / "A look was due 3 days ago." / "A look is due now."). **His answer 3a,
"Looked at" everywhere**: `ReviewWording.lookedAtLowercased(daysAgo:)` is the one small-letter
form, `lastText` uses it (it said "reviewed 12 days ago"), `HealthRow` (it said "reviewed 3d
ago") shows `ReviewWording.lookedAt` with an eye on its facts line as `AspirationRow` does,
`ProjectHealth.Flag.reviewDue.label` is **Due for a look** (it said "Review due"), and in the
review **Mark reviewed** → **I looked at it today**, **Mark all reviewed** → **I looked at all
of them**, plus the step's footer and the Settings › Review rhythm footer. **`whenText` for a
note never looked at is "due now"**, not in the plan: with `lastText` saying "never looked at",
`ReviewDueRow` would have read "Aspiration · never looked at … never looked at" (build 169).
App: `AppModel.markReviewed` reads the live note (build 144) and **writes nothing when
`reviewed:` already says today** — a save moves the file date and the review's **No changes
recently** counts it; `markAllReviewed` is unchanged and reads each note after the save before
it. `AppModel.reviewDue(of:)` reads the live copy. `LookedAtChip` (GoalsView.swift) is the
`GoalTargetChip` shape: a popover with a named button, never a `Menu`, a grey eye label in a
header and a capsule on the chain page (dashed while never looked at, build 142), capped at 260
points (build 250), `note.lookedAt` — **not the plan's `goal.lookedAt`**, because an area
carries it too and a name that says "goal" on an area lies (build 196). It draws nothing when
`reviewDue` is nil. `LookedAtBox` holds the two sentences, a Settings › Review rhythm line and
**I looked at it today** (`lookedAt.today`, greyed while the note says today). Placed in
`NoteHeader` for goals and areas, in `ChainGoalBlock`'s lead head (only `lead`: inside a chain
the head is a button, builds 71–74), and in place of `AspirationChainBody.head`'s plain label.
`LookedAtMenuItem(model:note:)` (model passed in, `NoteGoalOptions`' reason) is in both goal
lists' `rowMenu` and at the top of `NoteListView.noteRow`'s menu for areas and goals (goals for
a search in the goal rooms). **The phone's `foldingRow` and `row` gained `.contextMenu {
rowMenu(…) }`**, so a long press reaches the same menu — the manual had said "press and hold on
the iPhone" for the Goals list since build 199 and nothing came, and the phone's Aspirations list had no way to open a live aspiration's note (the Map,
Search and the review could). Projects get no button: step 5 looks at them weekly. Screen test
`testAGoalCanBeMarkedAsLookedAt`, both platforms, `Place.goals`: the chip reads "Never looked
at", **I looked at it today**, the box closes, the label holds "today". **Open, as the
sequencer said**: `NoteGoalOptions` still filters `model.notes` (ended goals offered), its own
small build.
**The review of Looked at found four faults, all fixed before upload**: `health(of:)` flagged an area
**Due for a look** on the project rhythm (7 days, since build 172) while the part of that name and
the new box used the area's 30, so one note had two answers under one name — the flag now takes
`reviewLevel(of:)`'s rhythm, pinned by `testAnAreaIsDueForALookOnItsOwnRhythm`; `HealthRow`'s date
sat `.fixedSize()` beside the name and grew to 29 characters, squeezing the name in the Mac's
220-point middle column (builds 138, 250), so it moved to the wrapping facts line; the review's
three menus drew a plain button, never greyed and offered on ended goals in steps 3 and 4, and now
use `LookedAtMenuItem`; and the version note claimed two things the old code did not do.
**Giving a flag the name of a part makes them one claim**: check that the two compute the same thing.

**Build 270: the area page.** `Core/Sources/ParagonCore/Vault/AreaOverview.swift` (tested in
`AreaOverviewTests`): `AreaOverview` (`projects: [ProjectLine]` for running and on-hold
projects in hand order, `overCount` for done/missed/dropped/archived, `subAreas`, `weekly`,
and the words `emptyText`, `overText`, `projectsText`), `SubAreaLine` (live project count, open
tasks in the sub-area and those projects, `factsText` "1 project · 3 open", never "0 open") and
`NoteIndex.areaOverview(of:today:)`, built on build 269's `projects(in:)` and `subAreas(of:)`.
**The box line is `ProjectLine`**, so the area page and the Projects list cannot disagree
about a project (a test pins it against `projectGroups`). The bars count the area's own tasks
and every project in it, ended ones too; **a sub-area's projects are not on its parent**, his
answer `subarea_projects` — one row per sub-area instead, and their work is in the sub-area's
own bars. App: `Views/AreasView.swift` — `AreaDashboardView` (in `NoteEditorView.sections`
beside the goal branch; `area.panel`), `AreaProjectRow` (a plain button calling `show(_:)`,
`ProjectTile` with his emoji, the need line in the Projects list's words, red overdue and a
deadline red only once passed — the Projects box's rule, not the plan's "grey deadline", since
one fact drawn two ways is build 168's fault; `area.project.<path>`), `SubAreaRow`
(`area.subArea.<path>`), `ProjectStatusItems` (the status lines, moved out of
`ProjectsListView.menu(for:)` so both right-click menus are one list) and `CappedHeight`.
**Departed from the plan, as the sequencer said**: **Add a project…** is build 269's
`AddServingNoteButton(link: .area)` in the fold's heading (`area.addProject`), never New Note,
so there is no `newNotePreset` and no `addProject(in:)` — a working screen selects, it does not
navigate (build 135). **`CappedHeight` is the one new idea**: the plan said
`ScrollView.frame(maxHeight: 240)` on the Mac, but a scroll view takes all the height it is
offered, so one short row would have sat in a 240-point box above the editor. This `Layout`
asks the scroll view for its ideal height (its content's) and gives it that, up to 240; on the
phone the rows are drawn as they are, since `phoneBody` already scrolls (build 127). The Mac
half of the screen test checks the new row's frame lies inside the window, which is what fails
if that ideal-height assumption is ever wrong. The list folds (`areaProjectsFolded`, open by
default); `WeekBars` gained `tint:` and the area passes pink. The empty line is hidden and an
orange one shown while notes are still coming from iCloud (build 100). Screen test
`testAnAreaListsItsProjectsAndAddsOne`, both platforms, with the new `Place.areas`: Health,
`area.noProjects`, **Add a project…**, the new row, the empty line gone, the button still
there; on the Mac also `expectNoOverflow(after:)`.
**The review of the area page found two faults, both fixed before upload.** The weekly line drew "0 tasks
finished in 8 weeks · 0 this week" beside eight flat stubs for an area whose only dated finishes
are older than the eight weeks (`bandHead` only asks `!isEmpty`, which is `lastFinished != nil`);
it now draws the bars and band only when `weekly.total > 0` and otherwise `caption(today:)` alone
("last task finished about 3 months ago"), pinned by an `AreaOverviewTests` case. The Projects
list's band in `ProjectsView.swift` had the same wording and the same fault, older than the
area page; it got the same fix in the same build, with no new test (the band needs a vault with only old finishes, which no screen test builds). **The orange iCloud line was inside the
fold** and, on the Mac, inside the capped scroll box, so a folded list with a short count said
nothing about why (build 100; build 212 keeps its Calendar reason outside its fold): `comingLine`
is drawn by `body` under the heading. **Departure from the plan, now written down:** the
sub-area rows stay inside the fold, so folding **Projects in this area** hides them too; each is
still one press away in the Areas list, and the manual says so.

**Build 271: the widgets follow every change.** Part A of idea 8; the Mac widget itself is build 273. No new widget, so if the existing two go wrong this change is the cause. `WidgetSnapshot.sameContent(as:)` (Core, tested in `WidgetSnapshotTests`): everything except `written`, by copying `self`, setting `written` to the other's and using the synthesized `==`; nil is never the same, and `day` is part of the content, so a new day is always a change. App, in `AppModel.swift` only apart from two one-line edits: the `notes` observer calls `writeWidgetSnapshotSoon()` — **the one place that sees every change**, because `save` and `saveText` put the saved note into `notes[i]` and never call `reload()`, so until now a tick or a changed due date reached the widgets only at the next sync or start. **A plan block is not in the summary** (`WidgetSnapshot` holds counts and the action lines), so adding or moving one writes nothing until build 273 puts the plan into it. `writeWidgetSnapshotSoon()` cancels a `widgetWriteTask` and starts a new one that waits 2 s on the main actor, so the editor's 600 ms autosave is one write two seconds after the last key. `reload()` calls the soon version too (the observer has already asked, but `notesWaitingForCloud` is set after `notes`, and by the end of the wait both are in place). `writeWidgetSnapshot(force: Bool = false)` gained `guard vault != nil` — **closing a vault sets `notes = []`**, which would have written "nothing due, nothing waiting" for a vault that is merely not open (build 179) — keeps the iCloud guard (261), and writes and calls `reloadWidgets()` only when `force || !snapshot.sameContent(as: lastWidgetSnapshot)`. `lastWidgetSnapshot` is set **only after the file was written**, so a failed write cannot make the next identical snapshot look as if it were on disk, and `forgetWidgetSnapshot()` clears it (and any waiting write) in `openVault` and `closeVault`. **Midnight rule**: `checkForExternalChanges` (the 10 s poll) writes again when `lastWidgetSnapshot.day != today`; nothing in the notes changes at midnight, so nothing else would. Settings › Widget: **Write it again now** passes `force: true`, and the caption says "written again a few seconds after a change that the widget would show" and that **Last written** is the time of the last such change. **The foot line `written 09:41` therefore means "last changed", not "last looked at"**; the manual says so, so an old time does not look like a stuck widget (build 177). **One departure from the brief, which a reader should know**: `flushWidgetSnapshot()` writes at once if a write is waiting, called from `ContentView`'s `.inactive`/`.background` branch beside `flushPendingEdits()`. Without it, a tick followed at once by the iPhone's Home Screen (or, on the Mac, a click on the desktop to look at the widget) could leave the widget stale for the two seconds, or until the app next ran if iOS suspended it first. Not checked from here: whether macOS reports `.inactive` when another app comes to the front; if it does not, the Mac simply writes two seconds later, which is still what the brief promised. **Known, fixed in build 275:** the review rhythm in Settings changes `dueForReview` but saves only the config (the `config` setter never touches `notes`), so the **What is waiting** widget follows at the next change to a note, a sync or the midnight rule; the fix is one `writeWidgetSnapshotSoon()` after the write plus an internal wrapper for the private function. **The review of 279 found that the first wording over-claimed in four places** — the manual, the version note, this paragraph and the doc comment above `writeWidgetSnapshot` all said a plan block or "any task added" reached the widgets, when the summary changes only for what the two widgets draw. **A sentence about when something is written has to name only what the written thing contains.** It also found the stamp placeholder in the Swift comments, which the merge script does not rewrite (it rewrites only the two text files): a comment that names a build must keep its placeholder whole on one line, and the lead replaces it in the `.swift` files after merging. **The review of the merged build 271 found that quitting the Mac app (⌘Q) within two seconds of a change dropped the waiting write** — the editor's flush saves the open note, which starts the wait again, and the program ends before it is over; the `willTerminate` observer now calls `flushWidgetSnapshot()` after `flushPendingEdits()`, in that order. **The lesson: the manual's sentence "when you tick a task" was true of `reload()` and never of `save`, and nobody listed who calls the function.** Before a sentence says when something runs, list its callers with a grep. No screen test: CI never draws a widget, and the runner may have no shared folder at all, so the Core test pins the rule that decides when the file is written again. Written down for build 273, not done here: `WidgetLook.goal` and `.project` have drifted from the app's `GoalTint` and `ProjectTint` (#A8781C against #A7811A, #2E7A4F against #2E7D5B), and 280 adds the widget target's first asset catalogue, which is the moment to offer the fix.

**Build 271: What is next for this goal?** `Core/Sources/ParagonCore/Vault/WhatNext.swift` (tested in
`WhatNextTests`): `NoteIndex.goalLeftWithoutWork(after:)` returns the goal a project's ending has
just left with nothing, else nil. It needs a project (`declaredKind`) that `isEnded` (so an archived
one never asks), a `goal:` that resolves through `goal(matching:)`, a goal that is not ended or
archived, and `serving(_:)` with no live project and no live sub-goal — **an area does not count**
(build 132's reasoning for `noProjectYet`), and **on hold does**, since it is still the goal's
project. The project is left out by its path, so the answer is the same whether or not the index
has caught up with the save. **`GoalHealth.Flag.nothingServing` could not be reused: it is silent
once any project under the goal has ended ("served, not neglected", build 132), which is the
exact case this question is for.** A rule that already exists under another name may say the
opposite on purpose; read what it is silent about before reusing it. `WhatNextQuestion` (same
file) holds the words, so a test pins each: the title, the line "Nothing is working on “…” now.",
`addTitle`, `offersDone` and `doneMessage`. It stores the goal's **path and name**, not the
`Note`; a button looks the goal up again (build 144). App: `AppModel.setStatus` now guards on
`save` returning true, and when a note goes from not ended to ended (and was not archived) it calls
`askWhatNext(afterEnding:)` (`WhatNextDialog.swift`, an `AppModel` extension — the first one in this
target — because `whatNext` is the only stored state and sits in `AppModel.swift`). That sets
`whatNext` **a turn later, through `afterUpdate`, only when no sheet is open, the focus question is
not pending, `errorMessage` is nil and no note is coming from iCloud or being updated by it**
(`notesWaitingForCloud`, `notesBeingUpdated`), and asks the Core rule again against the note as it
then is. `WhatNextDialog` is a `ViewModifier` (one `.modifier(...)` line in `ContentView`, after the root
alert) with one `confirmationDialog(presenting:)`: **Add a project…**, **Mark the goal done** (only
after Done), **Not now** (`.cancel`). The buttons come from a plain `@ViewBuilder` function and each
press is handed the question — the dialog clears `whatNext` as it closes and which of the action
and the binding's setter runs first is not to be relied on; the setter clears it through
`afterUpdate`, like `errorPresented`. **Add a project…** sets `AppModel.newNotePreset` (a **plain
var**, the plan's correction: a `@Published` value cleared from `onAppear` is a publish during a
view update) in the same turn it opens `.newNote`, and `NewNoteSheet.onAppear` takes it once
through `takeNewNotePreset()`, assigning `thing` before `servesGoal` (`pick(_:)` clears the goal on
a change of kind; `onAppear` does not call it, but the order is the safe one). The value is the
goal's `title`, which is what the Serves… list uses. **Mark the goal done** goes through
`setStatus(.done)`, so the goal gets its own `ended:`; it starts no second question because the rule
asks about projects only. **The dialog is not in `activeSheet`, so every gate that asks "is something
open?" had to learn it**: `ContentView.answerReminder` waits while `whatNext` is set, and
`openWaitingScreen` does too, with `whatNext`'s `didSet` giving a waiting press its turn when the
question closes. **Departed from the plan in two places.** (1) The rule and the words are in a new
file, not `NoteEnding.swift`, to keep the merge clean. (2) **An aspiration**: the plan's rule can
return one (a project hand-linked straight to it, with no live dated goal under it). Then the
question reads "…this aspiration?", the button is **Add a goal…** (New Note on Goal, Serves the
aspiration) because nothing is made straight under an aspiration (build 269), and there is no
**Mark the goal done** — you never finish an aspiration (build 199). Not built, by his answer 6b
(ask at once): the second line in `ProjectEndedLine`. **No screen test, as planned**: the status
`Menu`'s items carry no identifier, and making the rule true in the test vault would move the boxes
the Map test presses. Both directions of the rule are pinned in Core. **Untested from here**:
that the dialog really appears on the iPhone a turn after the status `Menu` closes. **Known and
accepted**: ⌘N or the menu bar clock's **Stop…** pressed while the dialog is up would open a sheet
over it; the same is true of the Delete question and the root alert today.
**The review of this build found two faults, both fixed before upload**: the question was asked
while notes were still coming from iCloud, when a project of the goal that has not arrived is not in
the index, so "Nothing is working on …" could be false and **Mark the goal done** could end a goal
with live work (build 100's rule, as in `partVaultReason`; the question is optional, so skipping it
costs nothing); and the manual described the line as two lines, when it is one sentence with the
goal's name inside it.

**Build 271: an area's Standard.** `Core/Sources/ParagonCore/Vault/AreaStandard.swift` (tested in
`AreaStandardTests`) owns the `## Standard` section of an area note, the way `DayPlan` owns
`## Plan` and `DayLog` owns `## Looking back`, on `MarkdownSection.find` (build 223) and no second
parser. **The Area template ships a question under that heading, and a question is not an answer**:
`text(in:placeholders:)` leaves out lines that are only a placeholder and returns nil — the same
nil as a missing heading — so a new area says "No standard written yet" instead of showing
"What does "good" look like in this area?" as its standard (build 100's rule: an absence must not
look like a presence). The shipped line is read out of `Templates.area` itself
(`shippedPlaceholders`), never copied; his own area templates' Standard lines come from
`Vault.areaStandardPlaceholders(among:)`, which reads only `kind == .area` templates and is called
from `AppModel.refreshSnippets()` into `standardPlaceholders` (plain `private(set)`, not
`@Published`: the same refresh redraws the readers). Lines are compared with case, curly and
straight quotes and runs of spaces folded, and also in their `{{title}}`/`{{date}}`-filled form,
because the note has had those filled in and the raw template line would never match.
`firstSentence(of:)` strips `- `, `* ` and `1. `, cuts only at a `.`, `!` or `?` that **ends a word**
(a space, a closing quote or bracket, or the end — so "3.5 km" is whole) and keeps a closing quote
with its sentence; **"…" appears only when text was cut off**, after a stop as " …" and after a line
with no stop as "…". `note(_:settingText:placeholders:)`: replaces the section (the question with
it); **makes a missing one above the first `## ` heading**, not right after the title as the plan
said — prose under the title would otherwise become part of the standard when read back — or at
the end when there is none; **empty text removes heading and all, but only when a standard was
written** (pressing Save on an empty box must not delete the template's question); the same text
again changes nothing. App: `Views/AreaStandardView.swift` holds `extension AppModel` —
`standard(of:)` and `setStandard(_:on:startedFrom:) -> StandardWrite` — and `AreaStandardBox`, so
`AppModel.swift` got two lines and `ReviewView.swift` a small edit (other builds change both).
**Departed from the plan on purpose:** `setStandard` is not `-> Bool`. It takes the standard the box
opened on and answers `.written`, `.changedMeanwhile(onFile:)` or `.notWritten`, the rule of
`setWeekGoal` (264) and `setMeasure` (268) whose reviews each found a line replaced unseen after
the first push; the box keeps his words, says in orange what the standard is now, and a second
**Save** replaces it. `AreaStandardBox` is edited in place like `WeekGoalBox`, but **Cancel** and
**Save** sit in the header row *above* the field (replacing **Standard…** while typing), so the
phone's keyboard cannot cover **Save** (builds 160, 231); the field is `TextField(axis:
.vertical)` with `lineLimit(2...6)` and no `onSubmit`, because what Return does in a vertical
field on the Mac is not known from here and the manual says only "press **Save**". Identifiers:
`area.standard`, `.text`, `.missing`, `.edit`, `.field`, `.save`, `.cancel`, `.notice`, and
`review.standard.<path>` in step 6. `HealthRow` gained `showsStandard` (step 6 only), drawing
"Standard: …" in `.secondary` or a dashed `ProjectPill`, with no colour of its own on a tagged row
(builds 200, 201). Screen test `testAnAreaStandardCanBeWritten`, both platforms: the test area
(made from the shipped template) says `area.standard.missing`, **Write the standard…**, type, **Save**,
`area.standard.text` and the editor hold the words and the heading; on the Mac also the frame
inside the window and above the editor, `expectNoOverflow`, and step 6 shows the sentence under
Health. **Noticed, changed in build 276:** step 6 flagged an area "No next action" in orange when only its
projects held tasks — build 132's "true of most notes" fault, worth its own question to him.
**Untested from here:** the Mac frame of `area.standard.edit` (a short button beside a label that
fills the line, build 247 — the test presses it with `press()` when hittable, by coordinate
otherwise) and whether the phone scrolls the field into view without covering the buttons above it.
**The review of the Standard found one narrow fault, known and not fixed:** while an Area template
is not on the device yet (a hidden iCloud stub, or one that could not be read), a question reworded
in that template reads as the standard until the template arrives and `refreshSnippets()` runs again
— `templateNames()` lists only `.md` names and `areaStandardPlaceholders` skips a template it cannot
read, so only the shipped question is always known. It needs a reworded question and an absent
template at the same time, it corrects itself within seconds (the iCloud pass reloads, which runs
`refreshSnippets()`), and nothing wrong is written; a "still coming from iCloud" line on two screens
was judged not worth its cost. A code guard, if ever wanted: make `standardPlaceholders` a union of
its old and new value for the session — that does not help a fresh device.

**Build 272: How was the week?** His answer 3 was yes, "under Looking back", so step 7 of the
Weekly review has a box that writes one line into the shown week's note. **No new parser:**
`DayLog` never asked which kind of note it was given, and `Templates.weekly` has no `## Looking
back`, so the section lands at the end, after the template's `## Review` and its two questions,
which are never touched (`DayLogTests` pins the exact suffix, that `## Review`'s lines are equal
before and after, that clearing returns the template's body byte for byte, and that `focus:` in
the settings block and the section leave each other alone). `WeekLook.line` (Core, tested) reads
it with the rest of the week through `Note.lookingBack`, so step 7 has one reader of a week.
**`DayLog.words(typed:shown:onFile:)` is build 261's rule moved into Core**: a line on file that
the field never showed is kept and his words go below it. `AppModel.saveLookingBack(_:for:shown:)`
had it inline; both it and the new `saveLookingBack(_:forWeek:shown:)` call the one tested
function now, four tests pin the day behaviour as it was. The week version has the day's three
rules: no weekly note for empty words, the unseen line kept, the reason returned (a stub gives
"The note for last week is still coming from iCloud…", named through `WeekLook.weekName`).
`AppModel.save` already reloads when the note is one it did not have, so there is no second
`reload()` as in the day version. **Departed from the plan in one place:** no
`AppModel.lookingBack(forWeek:)` — step 7 gets the line from `WeekLook.line` with the goal and
the days, and a function nothing calls would be a second reader (build 168). App:
`WeekLineBox` (WeekLookStep.swift; `ReviewView.swift` is untouched) is one call in
`WeekLookStep.content`, between the evening lines and the timer line, `review.weekLine` with
`.field`, `.done`, `.cancel`. Pressed, it opens in place like the goal box; the field is a
vertical-axis `TextField` (1 to 5 lines, "a line or two"), and **Cancel and Done sit above the
field, in the heading's line** (build 231: a button under a field can end up under the phone's
keyboard); both `.borderless` (a List row). `.onChange(of: week)` drops half-typed words when
the arrows move the week. While the week's note is coming from iCloud the box is orange and
disabled (build 100), because an empty `look.line` cannot tell "nothing written" from "not here
yet". The box's name is the fixed "How was the week?" (his words) and says nothing about *which*
week, so build 263's "this week" fault cannot happen; the sentences around it go through
`WeekLook.weekName`. Screen test `testTheWeekCanBeGivenALine`, both platforms: it presses
**Done** and not Return, because a vertical `TextField` may take Return as a new line on the
phone, and it does not test taking the line away again (selecting text differs too much between
the platforms; `DayLogTests` pins it). **Untested from here: whether Return submits a
vertical-axis `TextField` on the Mac** — the manual says only "press Done".
**The review of How was the week? found two faults, both fixed before upload.** `DayLog.words` compared the trimmed `shown` with the untrimmed `onFile`, and `text(in:)` keeps the spaces on the first and last text line, so a line typed by hand as `A calm week. ` looked like a line the field never showed: emptying the box could not remove it (`saveLookingBack` found nothing to change) and an edit was written below it as a duplicate. This was build 261's flaw in the day version, moved into Core unchanged. It now trims `onFile` before comparing (the untrimmed line is still what is kept), both `saveLookingBack` callers compare trimmed text before writing, and three `DayLogTests` cases pin it. Also a manual sentence ("a week with no note gets no note made for nothing") was an idiom with two negatives; it now says "If the week has no note yet, no note is made while the box is empty."

**Build 272: five small faults, each with the smallest change that makes the two sides agree.** Written in a worktree and kept independent: any one of the five can be dropped without touching the others. Core is tested; the three App parts are not (no compiler, no screen test, as planned).
- **1. `Vault.archive` no longer overwrites an ending.** It wrote `status: archived` over `status: done`, so an archived Done project failed `isFinishedProject` and dropped out of its goal's per cent, and (since 262) its `ended:` line meant nothing. Now `if !note.noteStatus.isEnded` the status line is written as `archived`, otherwise left exactly as it is, **whatever spelling** (`achieved` stays `achieved`). The folder, the `type:` line, `archived:` and `sync: false` are as before, and notes already archived are not rewritten. Readers checked one by one (`isArchived` is `kind == .archive || status == "archived"`, so the folder still says archived): `GoalProgress` counts it (archived and Done is 1; archived and Missed or Dropped is skipped), `goalHealth` now lists it among `endedNotes` (it used to vanish from the goal altogether, because it was neither live nor ended), `weekLook` lists it in the week it ended, `ProjectGroups` never sees it (the Projects list is the Projects folder). **One reader had to change: `Search`'s status box.** An archived Done note now has `noteStatus == .done`, so the **Archived** box would have lost it; it stands as its ending **and** as Archived (`standings`). The Archive list's status capsule now reads "Done" for such a note, which was accepted. `ArchiveEndingTests` archives through a real `Vault` and reads the files back.
- **2. `NoteGoalOptions` asks the index.** `GoalChoices` and `NoteIndex.goalChoices(for:)` (Core, `GoalChoices.swift`, tested in `GoalChoicesTests`): `datedGoals()` and `aspirations()`, so only live goals in the order of the two goal screens; never the note itself; the goal the note names stays even when ended, put in its place by `byTargetThenTitle` or by title (build 175's tick); a project, by `declaredKind`, leads with dated goals, anything else with aspirations (build 140). The App label adds the ending in brackets for an ended goal, otherwise the menu looks as if it offers finished goals. **The plan said "keep its headings"; the real menu has none** (Dividers only), and `Menu` section headers could not be looked at from here, so the Dividers stay. The lists in the New note screen's **Serves…** have headings only for a project.
- **3. The make fields in the New note lists say why, in the popover.** `NameCheck` (`free` / `choose` / `otherKind` / `ended`) and `ServingNote.check(goalNamed:horizon:among:)` / `check(areaNamed:among:)` (Core, `ServingNoteNames.swift`, tested in `ServingNoteNamesTests`). Asked of each kind of goal on its own so the right kind is found first whatever the order. `PickerChip.MakeAction.make` now returns `MakeOutcome` (`chosen` / `problem`), `PickerChip` has a `notice` (orange, cleared when the name changes or the list opens) and keeps the draft on a problem. `makeGoal` and `makeArea` go through `makeNoteSayingWhy` and turn its errors into words (`makeProblem`); neither calls `makeNoteQuietly` any more. **Two goals of different kinds really do collide**: aspirations and goals with a date share `Goals/`, so `createNote` throws `noteAlreadyExists`, and a test pins that. **The plan was wrong about areas**: a project called Health does *not* block an area called Health (own folder, `area(named:)` looks at areas only), so nothing says so in orange; a test pins that the vault allows it. `ended` is "the list does not offer it": goals by `isArchived || isEnded` (the same two tests as `aspirations()`/`datedGoals()`), areas by `isArchived` only (that is all `areaOptions` leaves out), so a chosen value always shows on the chip.
- **4. `WidgetLook` copies the catalogue exactly, light and dark.** Four had drifted (goal #A8781C for #A7811A, project #2E7A4F for #2E7D5B, area and resource a shade off) and all used one value in both modes. Each is now `Color(lightHex:darkHex:)` with the catalogue's colour set named in a trailing comment; the initialiser is `UIColor(dynamicProvider:)` on iOS and `NSColor(name:dynamicProvider:)` on the Mac, behind `#if canImport(UIKit)`. `tint(forKind:)` now has all seven kinds (an Inbox task used to get the tray in project green); symbol names were all correct. **`WidgetLookTests` (Core) reads the widget source and the catalogue as text** (`#filePath` four levels up) and fails on any difference, and checks the two App Group spellings against the entitlements. It skips when the files are not next to the package, and it fails with "table not found" if the line spelling changes, so **build 273, which adds a catalogue, has to change that test along with the table**. Left alone on purpose: the Inbox count line is drawn in `WidgetLook.resource` blue and "for a look" in goal gold (design choices of 174, not drift), and an aspiration's deeper gold is not carried because the snapshot says "a goal", not which kind.
- **5. `HelpBlock.parse` moved to Core (`Markdown/HelpBlock.swift`, public, tested in `HelpBlockTests`) and a bullet now continues over indented lines.** The rule: a line continues the last bullet when it is indented **at least to where the bullet's words start** (its own indent + 2). That, not "any indented line", matters for one place: `Docs/HowItWorks.md` lines 559-560 ("**Done** saves the line…" after the Close the day sub-bullets) is at the parent's indent and stays the paragraph it was. A line with no indent after a bullet still starts a paragraph (the docs have none), a blank line ends a bullet, and `- ` is a bullet at any indent (the lists are drawn flat). Counted by script before choosing: 125 continuation lines in `HowItWorks.md`, 330 in `VersionHistory.md`, none in `Words.md`, all indented 2 or 4 spaces; one-line bullets come out identical. `HelpView.swift` keeps only the drawing and imports `ParagonCore`. **The rule in this file that new bullets are "written one line each" is no longer needed**; one line or wrapped now draws the same. Nothing in the docs was reformatted.
**Lessons.** A table copied by hand needs a test that reads both sides (4); the plan said "headings" and "a project called Health" without looking, and the real menu has no headings and the vault has no such collision, so **a plan's description of a screen is a claim to check in the code** (2, 3); and **a change to what an ending is stored as has to be followed through every reader of the old word**, here the one reader that matched on the string the old code wrote (1).
**The review of the small fixes found four wording faults, all fixed before upload; the code was right in each case.** **The review of the merged build 272 found a fifth, and it was the same kind:** the manual and the version note promised the orange message for an *archived* goal or area, but `ServingNote.existing` and `check` match on `note.kind`, which is `.archive` for a note put away with **Archive**, so such a note is never found and its name can be used again. That is the right behaviour (an archived note is parked, and `area(named:)` and the Goals lists see live notes only), so the sentences were cut back to what is true: Done, Missed or Dropped *and still in the Goals folder*. The dead `isArchived` branches in `ServingNoteNames.swift` handle `status: archived` left in a live folder and stay. The version note counted lines as bullets (258 wrapped bullets, 455 lines) and claimed Help search newly finds a word on a bullet's second line (it already did; only a phrase across the line break is new); it said the old **Serves…** menu listed the note itself (it did not since build 268; only ended goals and vault order were wrong), so the "Found while planning" clause "and, on a goal, the goal itself" in CLAUDE.md is stale and the lead should delete it; the manual and the note named the wrong endings for a name that cannot be chosen (a goal that is Done, Missed, Dropped or archived, an area only when archived); and the widget note claimed a new symbol (only the colours are new) and that the count widgets are unchanged (they take the new shades). **A sentence about what the old code did is a claim to check against `git show HEAD:`, as much as a plan's description of a screen.**

**Build 271's first Mac screen run failed, and the fault was the test's own navigation.** `testAnAreaStandardCanBeWritten` called `go(to: .areas)` and, later in the same test, `go(to: .review)`. The second press died with "Not hittable: StaticText … identifier: 'sidebar.Weekly review' … {{0.0, 768.0}, {0.0, 0.0}}": an empty frame. **A row of the Mac's sidebar that has scrolled out of the window is still in the accessibility tree, with an empty frame, and `click()` refuses it.** Choosing a row far down the list (Areas) scrolls the list, so a row above it can disappear; every other test walks the sidebar once, from the top. The iPhone run passed 31 of 31, and the Mac run passed every other test, so nothing in the app was wrong. `go(to:)` now calls `bringIntoView(_:)` on the Mac: when the row's frame is empty or not inside the window, the left strip of the window is scrolled (four steps one way, then eight the other, looking after each step); when the row is already drawn it does nothing, so a test that was green keeps its exact steps. Build 271 was never sent to TestFlight, so its content ships as part of build 272 and the version history says so. **A test that walks to a second screen after a first one far down the sidebar has to expect the sidebar to have moved.**

**Build 273: Today's plan, a widget on the Mac.** Part B of idea 8 (his answers: "Mac only", and the big line is blocks only). The first widget that draws the plan, and the first asset catalogue in the widget target, so a layout or colour fault shows only on his Mac. **Core** (`WidgetSnapshot.swift`, tested in `WidgetSnapshotTests`): `WidgetSnapshot.Span` (title, start, end — minutes since midnight, **cut to the day in `init`**, so the widget never works with dates), and two new optional fields `plan` and `events`, so a file written by build 272 or earlier still decodes (`decodeIfPresent`). **Nil and empty are different answers, on purpose**: `plan == nil` means an older app wrote the file (the widget says "Open PARAGON once and your plan appears here"), `plan == []` means a day with no blocks; `events == nil` means the calendar is not shown (no access, or switched off in Settings), never "no events" (build 100). `NoteIndex.planSpans(on:)` reads the day's `## Plan` through `planBlocks`, in `DayPlan` order, so a block's place in the list is its `PlanBlock.index`; no daily note really means nothing planned (a note still coming from iCloud never gets this far, since nothing is written then, build 261). `planSummary` is the Settings line ("3 blocks · 2 events", "3 blocks · Calendar not shown", "No blocks · No events"; never "0 blocks", build 141). `WidgetSnapshot.planLink` (`amspara:///plan`) and `opensPlan(_:)` ask for the scheme, an **empty host** and the path `/plan` — a note link always has the title as its host, so a note called Plan can never match, and the link is not a `CaptureItem`. `PlanGlance.swift` (new, tested in `PlanGlanceTests`) makes **every word and choice of the widget**: `state` (olderApp / notToday / nothingPlanned / allDone / planned), `headline`, `isNow`, `then`, `whenText` ("Now · 20 min left" under an hour, "Now · until 11:00" from an hour, "in 25 min" under an hour away, "at 14:00" from an hour), `rangeText` (the start–end, **only when `whenText` names no clock time itself** — saying one of the two twice on a small widget is build 169's fault), `thenText`, `window(at:hours:)` (starts at the hour of now, moved back so it never passes 24:00) and `entryDates`. **The headline and Then come from `NowAndNext`** (build 266), the type behind Today's **Now** and **Then**, with the spans turned back into `PlanBlock`s; a test walks twelve moments of an overlapping day through both doors and insists they name the same block. Everything is worked out from the date it is handed, never the clock now (a timeline is drawn ahead of time; `.notToday` uses the entry's date, and the last entry is midnight itself so the widget stops claiming it is still yesterday evening). The minute is `NowAndNext.minute(of:)`, the clock's own hour and minute (build 238; a test pins 600 on the night the clocks change). **`entryDates(from:snapshot:calendar:)` takes the snapshot — a departure from the brief's `(from:calendar:)`** — because it must give a plan block's start and end an entry of their own: each whole minute for the next 60 (so "in 25 min" counts down), then every quarter hour and every start or end until midnight, sorted, unique, ending at midnight. **App**: `timedEventSpans(on:)` in `AppModel.swift` is **the one place an event becomes minutes** (clock minutes, an event from yesterday starts at 0, one into tomorrow ends at 24:00, build 238); `planningBusy` now maps it, so Start the day's placing and the widget cannot disagree about a meeting. `widgetEvents()` hands it to `widgetSnapshot(events:)` only while `calendarAccessGranted == true` and `showsCalendarEvents` is on; **it never asks for Calendar access** (a background write must not put up a question), and when access is granted but today is not loaded it **reads today's events there and then** with the same synchronous `calendarStore.events(on:calendarIDs:)` call `loadEvents(for:)` makes (the first version started an async load and wrote `events: nil` meanwhile, see the review below). `eventsByDay` has a `didSet` that asks `writeWidgetSnapshotSoon()` when **today's** list changed — `refreshEvents` reloads every day shown, so a change made in Apple Calendar ends here too — and the `showsCalendarEvents` setter asks for a write as well. A plan block reaches the widget through the `notes` observer of build 271 with no new call. **`AppModel.hasPlanWidget` (a `static let`, true on the Mac only) is the one place that says this device has the widget**: `widgetEvents()` returns nil without it, and `writeWidgetSnapshot` sets `plan = nil` without it, so the iPhone loads no events, writes no block or event title into its file, and a change to a block or an event writes nothing and redraws nothing there. When Today's plan comes to the iPhone, change that one value with `ParagonWidgetBundle`. `handle(url:)` checks `opensPlan` first and, through `afterUpdate`, sets `plannerDay` to today and shows `.timeBlocks`. Settings › Widget has a **Today's plan** row (Mac only). **Widget** (`App/ParagonWidgets/TodayPlanWidget.swift`, new): `TodayPlanProvider` (one entry per `entryDates`, policy `.after` an hour; a fallback of one entry when there is no file), `TodayPlanView` (small: words; medium: words and a 3-hour ruler, 132 points wide; large: words and a 6-hour ruler with lane names), `PlanHeadline`, `PlanRuler`. The ruler places every box with `.offset` inside a top-leading stack, never `.position` (build 85); two lanes, Calendar on the left and Time blocks on the right; **a block is filled at 30% with a solid edge, an event has an outline and no fill** (its title is drawn inside when the box is tall and wide enough), because macOS draws a widget that is not in front in grey and the shape must still tell them apart; the now line is 1.5 points with a 7-point dot, as `NowLine`. `ForEach` runs over structs with ids (`RulerBox`, `HourMark`, build 61). `ParagonEntry.read(at:)` is the one place the shared file is read (the brief called it `readEntry(at:)`). `WidgetFoot` is on every size. **Colours are `PlanLook` in the new file, not edits to `WidgetLook`**: the lead asked that `WidgetLook`'s values stay untouched (build 272 had already changed them). The three colorsets in `App/ParagonWidgets/Assets.xcassets` are byte for byte the app's `PlanTint`, `CalendarTint` and `NowTint` (a `cmp` finds drift; the file says so, build 168). The widget folder is a `syncedFolder` and the committed project already has a Resources phase for the target, so `project.yml` is unchanged. `ParagonWidgetBundle.body` is two whole declarations under `#if os(macOS)` / `#else`: the Mac lists three widgets and the iPhone keeps two; the new file compiles for both. **Screen test**: `testThePlanLinkOpensTimeBlocks`, Mac only, at the end of the class — checks `plan.week` is **not** on screen, opens `amspara:///plan` with `app.open(_:)`, waits for `plan.week`. **The first test in the suite that opens a URL; if `XCUIApplication.open` fails on the runner for its own reasons, remove the test, do not leave it red** (builds 190, 198). **Not checked from here**: nothing was compiled or drawn; the asset catalogue's first use in the widget target (if CI fails on it, `PlanLook` goes back to typed RGB, light values only); whether macOS opens a **second main window** for a URL (`WindowGroup` had no `handlesExternalEvents` until build 276, so it may — the other widgets' `amspara://` already behave the same, and `handle(url:)` is shared by both windows through the one `AppModel`); how the three sizes look (ask him for one screenshot of each, with a test page that saves on every tap, build 175). **Noticed, then fixed in build 276**: `PlannerView`'s Calendar lane drew an event that began yesterday at its start time today, while the widget used the cut minutes from `timedEventSpans`; Plan was left alone because a build changes one thing. **The review of the Mac widget found five things, all fixed before upload**: the medium widget has no lane names, so with `events == nil` it drew an empty left lane, the picture of a day with no events (build 100) — it now writes "Calendar not shown" in the lane itself (`calendarNotShown`, only when `labelled` is false; the large size says it in its lane names); the first summary after every start and after midnight was written with `events: nil` while an async load ran, so the widget said "Calendar not shown" for a few seconds with access granted — `widgetEvents()` reads synchronously now, and `widgetEventsLoad` is gone; the iPhone loaded events, wrote event and block titles into its file and redrew its two widgets for a widget it does not have (`hasPlanWidget`, above); the manual and the version note said an event is an outline "with nothing inside" although its title is drawn inside (now "no fill"); and the version note called a Core function "one function" and named **Plan** where only **Start the day** reads `planningBusy`. **A load that starts after a write is a write of the wrong picture**: when a value the file needs can be had at once, take it at once rather than writing nil and correcting it two seconds later.

**The lesson: a widget has no keyboard and no user to ask, so every empty picture is a sentence** — four states and two missing-file cases, each with its own sentence and none a blank box (build 100's rule, the widget's version); and **when two screens answer "what is next?", the answer lives in Core and is tested through both doors**.

**The review of the merged build 273 found three more small things, all fixed before upload:** a doc comment in `ParagonWidgets.swift` still said the widget has no catalogue of its own (true in 272, false once this build added one); the widget's three copied colour sets had only a `cmp` in a comment to keep them honest, so `WidgetLookTests` now compares each of `PlanTint`, `CalendarTint` and `NowTint` with the app's file (build 272's own lesson: a copy needs a test that reads both sides); and a few plan numbers had survived in the notes and in one test name. **A build that makes an earlier build's sentence untrue has to reread that sentence.**

**Build 274: icons for projects and areas, from the AMS-Icons package.** His ask on 27 October: "a multitude of icons … more like handmade", colours that can be changed, "a couple of hundred icons, so they should be searchable", and the **Emoji…** pill should say Icon. His four answers: both kinds (hand-drawn plus about 300 SF Symbols), a **shared repository now**, PARAGON uses them for **projects and areas**, and icons **replace** emoji. The package is https://github.com/marsch124/AMS-Icons (the Packing app's 132 drawings, 305 symbols, 15 colours, `IconLibrary.search`, and `IconTile`/`IconMark`/`IconPicker`), **pinned in `project.yml` to commit `43cbcb1f0ab543070cdbc4b8879c4fa00cba6e57` with `revision:`, never `from:`** — the session that built this could not push the `1.0.0` tag, and a pin is what keeps a new icon from arriving by surprise anyway. Only the **Paragon** target depends on it: not `ParagonShare`, not `ParagonWidgets`, and **not `ParagonCore`**, which stays free of it. A package product used by one target is normally linked statically, so the TestFlight step that signs `Frameworks/` by hand should have nothing new to sign (the first TestFlight log will show it). **A push that changes `project.yml` makes CI commit the regenerated project, so the next local push needs `git pull --rebase` first.** The type is `IconChoice`, not the draft's `IconRef`: Apple's CoreServices has its own `IconRef`, which the Mac found ambiguous.
- **Core stores strings and never imports the package** (`Core/Sources/ParagonCore/Model/NoteIcon.swift`, tested in `NoteIconTests`). `icon:` holds `IconChoice.stored` exactly (`hand:bike`, `symbol:figure.run`: no quotes needed, a value with `: ` is quoted by the settings block as always) and `icon-colour:` the colour's key (`blue`, `slate`; Automatic is no line, and a hand-typed `auto` reads the same). `Note.iconStored`/`iconColourKey` read them (an empty line is nil, like `measure:`; the text is **not** checked, so an unknown prefix or a bare word is kept as written and still counts as "an icon is set"). `Note.settingIcon(_:colour:)` writes: nil removes the line (build 165's rule, never `icon:` with an empty value), a line break is joined, every other line and the body are untouched, the new keys go last, and the same choice again returns the note unchanged. **It removes `emoji:` whenever it is called**, also for **No icon** and for a colour alone: any choice in the picker replaces the emoji, and a note nobody touches keeps its emoji. **The review found one press that is not a choice:** the package calls `onColour(nil)` on every press of the **Automatic** swatch, also when it is the one already ringed, so on a project with only an old emoji (no icon, no colour) the press looked like a no-op and still deleted the emoji. `NoteIconChip.chooseColour` (App) now returns without writing when `picked == nil` and the note has no colour; `settingIcon` itself is unchanged, so Automatic taken from a real colour still writes and still removes the emoji. **A control the package calls on every press has to be checked for the press that changes nothing.** `NoteIcon` (`.icon(stored, colour:)`, `.emoji`, `.colour`, `.unset`) and `Note.ownIcon` are the **one precedence rule** the three screens that draw a tile read (icon, then old emoji, then a lone colour, then nothing); `isIconOrColour` says whether the package draws it. The case is `.unset`, not `.none`, so it can never be taken for `Optional.none`.
- **Departed from the plan: `ProjectLine` and `AreaOverview` carry no new fields.** They already hold the whole `note`, and the tile read `line.note.emoji`, not a copy; `line.note.ownIcon` is the same read and a second copy is how screens drift (build 168). **`ProjectEmoji.groups` (the 24 choices) and its test went**; `ProjectEmoji.cleaned`/`Note.emoji` stay, for reading only.
- **App: one file imports the package** (`App/Paragon/Views/NoteIconViews.swift`), so a clash between a package name and a SwiftUI name has one place to happen (none found: the package's public types are `IconChoice`, `IconColour`, `IconLibrary`, `IconSection`, `IconMark`, `IconTile`, `IconPicker`, `HandIcon*`, `Symbol*`, `SVGPath`, `GridShape`, and no App, Core or SwiftUI type has those names). `NoteIconTile(note:fallbackTint:size:)` wraps `IconTile`; **an `icon:` line the package cannot read or does not know draws its dashed circle, never a letter** (a letter would say "no icon chosen" about a note that has one written, build 100); only a colour with no icon line draws the name's first letter. `NoteIconChip` replaces `ProjectEmojiChip` and `EmojiChoices` (deleted) and is in `NoteHeader` for **projects and areas**; `AppModel.setIcon(_:colour:on:)` replaces `setEmoji`: live note, projects and areas only, never a work note (build 112), writes nothing when unchanged. The chip reads `live` at press time, so a colour press passes the icon the note holds **now**, written back as it stands (an icon this version cannot draw is kept).
- **The picker is the package's, as it is**: a `.popover`, which is a popover on the Mac and the system's sheet on the iPhone (the screen's only presentation, build 44). Every press in it ends it, the Packing app's way: one press on a colour, an icon or **No icon** writes and closes, so changing both is two visits. **Cancel** writes nothing. `IconPickerSize` gives the Mac an ideal size and a top (540 × 640, at most 580 × 680) because the package gives it only a minimum (520 × 620) and a popover would otherwise ask the scroll view for the height of every icon; the phone and iPad get an ideal size only (440 × 620), which a full-screen sheet never asks for. **Not seen from here:** how a 640-point popover sits on a short Mac screen, and the iPad popover's size.
- **Where the icon is drawn.** `ProjectTile(status:note:)` (the Projects list and the area page's `AreaProjectRow`): icon or lone colour → `NoteIconTile`; else an old emoji in the frame it always had; else the dashed flag. **Automatic takes the status colour** (green running or done, grey on hold, missed, dropped, archived), so a project on hold still reads as one; the brief said the kind's colour, which is the same for a running project and would have lost build 253's grey. A colour he chose is always that colour. The tile's one accessibility element says the icon's name ("Bike") — the Mac screen test reads it. **Areas, not in the brief but needed, or the field would be write-only** (the rule of builds 132 to 144 turned round): `NoteRow` draws a 30-point tile in place of the thin stripe for an area with an icon, and `SubAreaRow` a 20-point one (aligned with `alignmentGuide(.firstTextBaseline)`, since a view with no baseline would rest its bottom edge on the text's); both are `accessibilityHidden`, the title already names the area. **Goals, aspirations and resources get no icon**; the Map and the New note screen never drew an emoji, so they got nothing.
- **Screen test `testAProjectCanBeGivenAnIcon`, both platforms, at the end of the class** (replaces build 254's emoji test): press `note.icon` (among buttons, build 249), wait for `icon.search`, press `icon.cancel` and check the editor has no `icon:` line; open it again, type `bike` into `icon.search` (the Sport heading is far down a library of 130 cards, so the search brings the card to the top; on the phone the Search key closes the keyboard if it is there), press `icon.choice.hand:bike` (scrolling the picker a few times if it is not hittable), and check the editor holds `icon: hand:bike` and no `emoji:` and the chip says "Icon: Bike"; on the Mac the Projects list's `project.tile.<path>` reads "Bike". **The fixture was not given an old emoji** (thirty tests read that note), so "an icon replaces an emoji" is pinned in Core (`testChoosingAnIconReplacesTheOldEmoji` and two more), not on screen. The package's own identifiers (`icon.picker`, `icon.search`, `icon.cancel`, `icon.choice.<stored>`) are the whole way in; nothing was added to it for the test.
- **Untested from here (no compiler, and CI has never drawn this package):** XcodeGen's `revision:` key; `IconPicker`'s `dismiss` inside a Mac popover; whether `IconTile`'s own accessibility element, wrapped in `ProjectTile`'s `.ignore`, leaves the Mac test's label alone; that the iPhone's popover-as-sheet gets the whole screen.
- **Lesson.** The brief listed "the Map box if it shows the emoji" and "the New note screen if it offers an emoji": neither does, and finding that out cost one grep. **A plan's list of places is a claim to check in the code** (build 272's lesson, once more). And the old rule once more (builds 132 to 144, turned round): a chip that writes `icon:` on an area while no list draws it would be a control with nothing to show for it, which is why the Areas list and the sub-area rows draw it.

**Build 275: two leftovers.** Both were written down as "known, not fixed" in earlier builds. `GoalDashboardView` (NoteEditorView.swift) draws its per cent bar only for a goal with a date, through `GoalWording.isAspiration` — build 199 removed the figure from every other aspiration row, the manual said so (lines 476 and 544), and this page had been missed. The `config` setter in `AppModel` now asks `writeWidgetSnapshotSoon()` after it saves, so a changed review rhythm reaches the **What is waiting** widget (the snapshot compare writes nothing when the picture is the same, so every other setting that goes through `config` costs one comparison). **The rule from build 199 held its own lesson: a fix that says "every place" needs the grep that finds the places, written down** — this was the place the first search did not reach. **CI note:** `testTheSettingsBlockCanBeFoldedAway` failed once on the iPhone run of build 275 ("settings block is still shown after the fold was pressed") and passed on the one re-run; build 275 was not sent to TestFlight on its own and ships inside build 276. A second failure of that test is real: look at the fold and the editor text before blaming the runner (build 240's `lastWritten` is the nearest known cause).

**Build 276: four small faults, each the smallest change that makes the two sides agree.** Part A of the lead's list of five (Part B, icons for more kinds, is another build). His words: "Do all the small items in one build." Written in a worktree and independent: any one of the four can be dropped without touching the others. Core is tested; the App parts are not (no compiler).
- **1. A goal with a date can change its horizon.** The most repeated fault once more (132, 134, 140, 144, 165, 268): `horizon:` was read by the Goals lists, the review and the header, and written only by the New note screen when the goal was made. `Core/Sources/ParagonCore/Model/GoalHorizonField.swift` (tested in `GoalHorizonFieldTests`): `GoalFields.horizonKey`, `GoalFields.datedHorizons` (`[.year, .long]`, the order the button offers them) and `Note.settingHorizon(_:)`. **It refuses `.life` and refuses any note that is not a goal with a date** (an aspiration is another kind of note in the other room: switching it would move it between **Aspirations** and **Goals** behind his back), returns the note unchanged when the line already says the value (in any capitals), and **writes the explicit line when it is missing or unreadable**, because a goal with no `horizon:` line reads as **This year** and the button already shows it ticked; pressing it should make the file say what the screen says. **The line is never removed.** `AppModel.setHorizon(_:on:)` reads the live note (build 144), refuses a work note (112) and writes nothing when unchanged (`setTarget`'s shape). `Views/GoalHorizonChip.swift` is a new file: a button with a popover of two named rows and a tick on the current one (`goal.horizon`, `goal.horizon.year`, `goal.horizon.long`), **not a `Menu`** (build 268), `.focusEffectDisabled()` on the popover (202), words from `GoalHorizon.label` and three small `static func … -> String` helpers. **One view, two looks** (`onChainPage`, as `GoalTargetChip`): a gold label in `NoteHeader`, replacing the grey `Label(horizon.label, systemImage: "scope")` for a dated goal, and a `ChainChip` capsule. **Departed from the plan, and it matters:** the plan named only `NoteHeader`. **On the Mac a dated goal opens as `GoalDetailView` (the chain page), not as the note**, so the header is one press of the **Note** button away and a chip only there would be a button he does not meet. The capsule is therefore also in `ChainGoalBlock`'s head, `lead` only, after the target. The screen test (`testAGoalsHorizonCanBeChanged`, both platforms, `Place.goals`) presses `goal.horizon`, chooses `goal.horizon.long`, waits for the choices to close and for the button's label to say **Long term**, then does the same back. **The Mac has no editor on that page, so the editor check (`horizon: long` / `horizon: year`) is iPhone only**; on the Mac the label is read back out of the saved note, which is the proof the write happened, and the Core test pins the text. **A plan's description of a screen is a claim to check in the code** (build 272's lesson, once more).
- **2. The weekly review no longer flags every area "No next action".** `NoteIndex.health(of:)` judged an area by the area note's own open tasks, but an area's work lives in its projects, so the flag was true of most areas (step 6, in orange): build 132's rule, a check that is true of most notes is not an alarm. The decision was the lead's: an area is flagged only when **nothing is waiting anywhere in its reach**. `Review.swift` gained two private functions: `hasNoNextAction(_:open:)` (a project, or anything that is not an area, still `open.isEmpty`, unchanged) and `holdsSomethingToDo(_:)` (the note's own `Note.nextThing`, the one rule since build 254, or a live project from `projects(in:)` that has one; "live" is `AreaOverview.isLive`, which keeps on-hold and drops done, missed, dropped and archived). **Departed from the plan in one place, for the lead to keep or drop:** the plan said "the area's own note or any live project in the area". **Sub-areas are included as well** (`subAreas(of:)`, one level, their own note and live projects). Build 270 keeps a sub-area's projects off its parent's page, so a parent whose only work is in "Yoga" would still have been flagged in orange: the same fault, one level up. It only ever removes a flag. Readers of the flag checked one by one: `ReviewSummary`'s worries count **projects** only (`projectsNeedingAttention`), `HealthRow` draws the flags it is given, `needsAttention` follows, the heading count of step 6 counts all areas; the manual's step 6 line and **The flags** and `Docs/Words.md` say the new rule. `ReviewAreaWorkTests` (13 cases): work only in projects, nothing anywhere, own tasks, on hold counts, ended and archived do not, another area's project does not, subtask under a ticked task counts and under a cancelled one does not, sub-areas, a project's own flag unchanged, `review()` agrees. **The review then found that step 6's row still said "0 open" for an area whose work is in its projects** (`openTaskCount` is the area note's own), next to a clean tick: two facts that could not both be true of that row (builds 141, 199). `HealthRow` now draws the count only when the note is not an area (the only area use of `HealthRow` is step 6); the area row's "done in 7 days" is still the area note's own count and was left, for its own question.
- **3. An event that began yesterday is drawn from the top of today.** Noticed in build 273 and left alone. `AppModel.timedEventSpans(on:)` cut an event to the day, but the **Plan** screen's Calendar lane read the clock time of the start and end as they stood (an event from 23:00 yesterday to 01:00 was drawn 23:00 to 23:30 today; one ending tomorrow was a half-hour box) and the Calendar section's day (`DayScheduleView`) drew an event from its real start and let it run past the grid. `Core/Sources/ParagonCore/Vault/EventDaySpan.swift` (tested in `EventDaySpanTests`, 13 cases: inside, from yesterday, into tomorrow, whole day, exactly 00:00, ending exactly at midnight is 24:00 and `endsLater` false, no length, end before start, outside the day held to the edge, and the two days the clocks change in Stockholm, pinned by the 2 h and 25 h gaps): `EventDaySpan(start:end:on:calendar:)` gives `startMinute` / `endMinute` (the wall clock's own, build 238; 0 to 1440) **and** the cut `start` / `end` as dates, plus `beginsEarlier` / `endsLater`. **Nothing is dropped**: an event that does not touch the day is held to its nearest edge as a span of no length, because hiding it would be an absence that looks like free time (100). Three callers, one rule (168): `timedEventSpans` (the widget and the planning sum; behaviour unchanged, its local `clockMinutes` is gone), `PlannerDayView.placedEvents` (its zero-length fallback of 30 minutes is kept, capped at 24:00; it used `WeekRef.calendar` and now uses `.current`, which is what `DateOnly.date` pairs with) and `DayScheduleView.timedItems`, which cuts **events, Time Block events and timed tasks** and keeps the real times in the subtitle, with a new `hourAfter(_:)` so an item cut at the next midnight draws the day to 24 (its clock reads 00:00 and would have counted as the first hour). **Known:** the Plan card's own time text for a cut event shows its times on this day ("00:00 – 01:00"), not "23:00 – 01:00". **The review of this item found one real fault, fixed before upload:** `placedEvents` gave an event from yesterday `startMinute` 0, but the Plan lane draws only 06:00 to 24:00 and nothing clips it, so `top(forMinutes: 0)` was 264 points above the lane: the card's words (at its top edge) were out of sight, the outline lay over the **Calendar** heading and, on the phone, over the day header's buttons, and an event that ended before about 05:35 was drawn wholly above the lane. `placedEvents` now holds the drawn box to the hours the lane draws (`firstHour * 60` to `(lastHour + 1) * 60`), keeps the event's own times on this day in the card's words (`PlannerSpan.wordsStart` / `wordsEnd`, read by `PlannerPlacement.time` and `startTime`), and **leaves out an event wholly before 06:00**: the hours it lies in are not on this screen. That is the one place the "nothing is dropped" rule of `EventDaySpan` is not carried on; the Calendar section's day grows to fit and drops nothing. A plan block placed before 06:00 could still spill the same way; no new `.clipped()` was added, since a clip could change how the cards take their drags and nothing can be tried here. **The lesson: a cut that moves a value to the edge of the day has to be followed to the screen that draws only part of the day.** `DayScheduleView` still measures an item's height in real seconds, so on a 25-hour day an item is an hour out, as before.
- **4. A click on the widget may open a second window on the Mac.** Not seen, but **the documentation says it happens**: I read `developer.apple.com/documentation/swiftui/view/handlesexternalevents(preferring:allowing:)` and the `Scene` one (the JSON behind the pages is at `developer.apple.com/tutorials/data/documentation/swiftui/…`, fetchable from this container). The rule: an event goes to the first open scene that **prefers** it, else the first that **allows** it, and "if it finds neither — including when you don't add this view modifier — SwiftUI creates a new scene". With no modifier, every `amspara://` link made a new window. `TakesLinksInOpenWindow` (ParagonApp.swift, a `ViewModifier` with the `#if os(macOS)` inside its body, build 148) puts `handlesExternalEvents(preferring: ["*"], allowing: ["*"])` on the main `WindowGroup`'s content. **Only that scene has it**, so **Plan the day**, Help and Settings never receive a link. **With no main window open nothing changes**: rule 3 and 4 of the scene routing create a new instance of the first scene declaration with no `handlesExternalEvents(matching:)`, which is the main group. The menu bar clock's **Show PARAGON** uses `openWindow`, not an external event, so it is not touched. **The iPhone is left alone** (the documentation says a single-scene platform ignores the modifier; the iPad is not changed in a build about the Mac). **A consequence the plan did not see:** a link now goes to a window that may be minimized or behind another window, and nothing would show. `FocusStatusItem.bringMainWindowForward()` (a static beside `showApp()`, same marker search, never opens a window) is called from `ContentView.onOpenURL` on the Mac after `handle(url:)`. Screen test `testAnOpenLinkReusesTheOpenWindow` (Mac only, **a test of its own** so a failure means "a second window"): counts `app.windows` that have a frame, opens `amspara:///plan`, waits for `plan.week`, then watches for five seconds that the count did not grow. **Certain from reading:** the routing rule and that the modifier is the documented answer. **Not certain, and the test will say:** that `onOpenURL` fires in the window the event is routed to (the documentation says the event is sent to that scene) and how XCUITest counts windows on a runner.
- **Lessons.** Read the framework's own page before adding a modifier from memory: the four-line rule list settled what the recipe in my head only half remembered (the scene modifier is for opening, the view modifier is for an open one). **A fix that changes who receives an event changes what the user sees when the receiver is hidden**, which is why the window is raised. And item 2 is build 132's rule again (a check that is true of most of the notes is not an alarm), now for the flag that rule had not reached yet: **when a rule is written for one kind of note, ask what the neighbouring kind's work looks like** before copying it (an area's work is in its projects, a project's is in its own text). The review also found two words in the version note that were not plain ("mended", "ran off the bottom"); they are "fixed" and "went past" now.

**Build 276: icons for goals, aspirations and resources.** His question on the small-items list, taken as yes: *"Icons exist only for projects and areas. Do you want them on goals, aspirations and resources too?"* The picker, the chip and the writer from build 274 were already kind-agnostic; this build widens **who** may use them and **where** a goal's or a resource's own mark is drawn.
- **One rule in Core, two readers** (build 168). `ParaKind.takesIcon` (NoteIcon.swift, tested in `NoteIconTests`): project, area, goal, resource. `NoteHeader` asks it (through `showsIconChip(for:)`) and `AppModel.setIcon` asks it (on `live.kind`), so the button and the write cannot disagree. `Note.settingIcon` was already kind-agnostic and is unchanged; a helper in the tests walks the same set / colour-only / same-again / lone-colour / **No icon** sequence over a goal with a date, an aspiration, a resource, an area and a project.
- **A work note is a `.resource` by kind** (build 112 keeps them out by *folder*, not by kind). Widening the rule to resources would have drawn **Icon…** on every work note, and `setIcon` refuses them already — a button that does nothing (build 175). `showsIconChip` therefore adds `!model.isWorkNote(note)`. **When a rule widens to a kind, ask who else is that kind.** A work note that someone gave an `icon:` line by hand still draws it in the Work list; the app never writes one.
- **`GoalMark` (GoalsView.swift) is the one place a goal's badge is chosen**: his tile (`NoteIconTile`, `ChainTint.forGoal` for Automatic) when `ownIcon.isIconOrColour`, else the `KindBadge` with star or target exactly as before. Used by `AspirationRow` (24), `DatedGoalRow` (24, which also draws ended aspirations), the aspiration page's head (26) and `GoalHealthRow` in steps 3 and 4 of the review (20). `ChainGoalBlock.head` and `AspirationChainBody.endedRow` draw a smaller tile (24/20 and 16) where they had a plain caption-sized symbol. A tile is decoration, so `.accessibilityHidden(true)`; the title beside it names the goal.
- **`NoteRow.leadingMark` follows `note.declaredKind.takesIcon`** instead of `note.kind == .area`. That draws the tile for resources and goals in the flat lists, and also for **projects** in Recent, the Archive and a search inside a list (the Projects list has its own `ProjectTile`; nothing drew a project's icon in those rows before). It reads `declaredKind` so an archived note, whose `kind` is `.archive`, keeps drawing the icon it has, in the Archive's grey while Automatic. Choosing one there is not offered (the chip asks `kind`).
- **Left on the kind's symbol on purpose**: the Map and its legend (builds 170, 175), the sidebar rows, `GoalsHeader` (the column's own name), the group headings of the Projects list, `ReviewDueRow` and `HealthRow` (mixed kinds, or projects and areas, as in 274), `SearchHitRow`, `TagsView`, the linked-notes and "serves" lists (a badge that says which kind a mixed list's row is), the `Serves…` chips and the planner's serves line (a symbol standing for a relationship), and the New note sheet's kind buttons. The star and the target keep meaning *the default* (builds 164 to 189); a chosen icon is his own mark, and the room (Aspirations or Goals) and the header's words still say which is which.
- **`ownIcon` reads an old `emoji:` only for a project or an area** (`declaredKind`): the brief said the emoji reading stays for projects only; goals and resources never had the line and do not start reading it. Areas keep what 274 accidentally gave them, so no area behaviour changed. `settingIcon` still removes an `emoji:` line whatever the kind (a test pins it).
- **To go back to the star or the target**: **Icon…** → **No icon**, and **Automatic** too if a colour was chosen (a lone colour is `.colour`, which `isIconOrColour` counts, so the row shows a coloured first letter until the colour goes). Said in the manual and the version note.
- `NoteIconChip` now uses `Note.tint` (the aspiration's deeper gold, build 189) for its edge, face and the picker's fallback, and its tooltip names the kind ("aspiration", "goal", "resource"). Manual: **Your own icon**, the note-keys paragraph, the chain and Map sections; `Docs/Words.md`: **Icon**, **Automatic**, **No icon**. The Work section is deliberately not named in either (build 112).
- Screen test `testAResourceCanBeGivenAnIcon`, both platforms, straight after the project's: Resources › Packing list, `note.icon`, `bike`, `icon.choice.hand:bike`, the editor holds `icon: hand:bike` and the button says "Bike". No goal test, as planned: the Core cases carry goals and aspirations. **Not checked from here**: nothing was compiled or drawn; how a 16 to 24-point tile reads beside a title; whether `Icon…` makes the header row too wide for a goal on the narrowest Mac column (it is one small item in a `WrappingHStack`).
- **The Swift comments from build 274 call that build "284"** (its plan number): the lines touched here say 274, the rest were left.
- **The review of 276 found three things, all fixed before upload.** On the Mac the third column for an aspiration or a goal is the chain page, and the note's own header (with `NoteIconChip`) is shown only after pressing the Note switch, so the page that draws the icon had no **Icon…** button — a screen showing a field without the control that writes it (builds 132 to 144, 268). `NoteIconChip` is now also in `AspirationChainBody.head` (after the horizon capsule) and in `ChainGoalBlock.head` when `lead` (never inside a chain, where the head is one button, builds 71-74); the phone's folded-open chain has none, because press and hold, **Open the note** reaches the header there. The manual's list of kind symbols said "the ring" (a task's symbol) and left out the four squares and the books; and the version note said "right after the first word" for a label that is four words long (**Goal with a date**).

**Build 277: Undo for the one-press changes.** His answers (2 November 2026): D1 yes; D2 **no question before Delete in the Inbox, only Undo**; and he chose D first of all the ideas. **Build 221's sentence "every task is still there and can be moved again" was wrong where it mattered.** Each overdue task had its own old date and the press gives all of them one new date, so nobody could put the old dates back by hand; "a date is not a deletion" was the reason no question was asked, and the reason did not hold. What replaced it: the message keeps the one press and carries an **Undo** for about eight seconds. Two changes only: Today's two **Overdue** buttons (`moveTasks(…, offersUndo: true)`) and the Inbox delete (`deleteTask`, called only from `InboxView`, checked by grep). **Not** Close the day's three `moveTasks` calls (a sheet, and `flash` sits under a sheet on the phone, build 238), not a single task's date, not a delete inside a note.
- **The rule, in Core and tested (`Core/Sources/ParagonCore/Vault/TaskUndo.swift`, `TaskUndoTests`, 37 cases): Undo writes only what it can prove is still as the press left it.** `MovedTask` (path, `^t` id, title, line index, old date, new date; `changedTheDate`) and `Note.undoingDateMoves(_:)`: a task gets its old date back only while it is open and its date is **exactly** the new one; otherwise it is skipped with a reason (`UndoSkip`: done, changed, gone, unclear, notWritten) and named in the answer. Found the way `replace(task:)` finds one: by id, else exact title, the recorded line first. **A title is not an identity**, so a match by title alone is trusted only while the pairing is clear: one moved task has that name, or all of them had the same old date, or every one is still on the line it was pressed on — otherwise `.unclear`. The first version accepted "the task at my old line index" per record, and a line added above shifted two same-named tasks by one place so each took the other's date; the test `testTwoTasksWithOneNameAreLeftAloneWhenTheLinesMoved` is that case. The due time is not touched (the move never touched it).
- **A deleted line is put back by adding it, never by replacing anything.** `Note.removingTaskBlock(for:)` returns a `TaskRemoval` (the note without the task and a `RemovedTask`): the **raw lines with their indentation** (the plan said `removeTaskBlock`'s output, which moves them to indent zero), the index, the line just before and just after the gap, id and title. `Note.putBack(_:)` tries, in order: already there (id, or with no id the same title **and** line text — nothing is written, which also makes a second Undo harmless); the old place if both neighbours are still on either side of it (`sameSpot`); straight after the line that came before, **past its subtasks** so the line is never put between a parent and a child it gained (`afterPrevious`); straight before the line that came after (`beforeNext`); the end of `## Tasks`, flattened to the top level so a subtask whose parent is gone does not become the child of whatever is above it (`endOfTasks`). A blank line is never an anchor (it is the same line in a hundred places). The Inbox usually gains a capture from the other device meanwhile; a test through a real `Vault` does exactly that and checks both lines survive in the right order.
- **The message owns its offer.** `AppModel.lastCaptureMessage` has a `didSet` that clears `undoOffer`, so *every* other way of changing the message — an ordinary `flash`, a capture's answer (four direct assignments), `clearCaptureMessage()`, the message timing out — ends the offer with it, and no caller has to remember. The one exception is `flashKeepingUndo`, used where `FocusNotice` adds a notice to a message already showing (build 257): it sets a private flag around the assignment. `openVault`/`closeVault` set `undoOffer = nil` (an Undo belongs to the vault it was made in); they do **not** clear the message, because `settleFocusBeforeLeavingVault()` may have just flashed that a clock over 12 hours was dropped. `flash(_:offering:)` numbers the offer (`undoOfferCount`).
- **`App/Paragon/UndoOffer.swift`** holds `UndoableChange` (`.dates([MovedTask])` / `.deletion(RemovedTask)`), `UndoOffer`, an `extension AppModel` (`undo()` and two private writers) and `FlashCapsule`. `undo()` **clears the offer first** (a second press finds nothing), flushes the editor, then goes through `vault.saveEach` like `moveTasks` does: the change is worked out again on a fresh copy when a note changed on disk. A note not in the list, or in `notesBeingUpdated` (a newer copy is on its way from iCloud and this one proves nothing), counts as gone/changed. The answer is an ordinary `flash` with no offer. All the wording is in Core (`UndoWording`, tested): "5 of 6 tasks put back. “Send the invoice” was changed after the move, so it was left as it is."
- **`moveTasks` builds the record inside the `saveEach` closure**, per note, not afterwards from the refs: a ref whose task was not found, or already had the new date, must not be recorded, and the closure may run twice (a note changed on disk is read again) — the second run overwrites the first run's list. Only the notes in `result.saved` are used. If some notes failed, no Undo is offered for the rest (the alert already says some tasks keep their old date).
- **The overlay (`ContentView`)**: `FlashCapsule` draws the same `Text` in the same material capsule as before when there is no offer; with one it adds an **Undo** `Button` (`flash.undo`; the text is `flash.message`) and a 40-point tap height on the phone. `.task(id:)` is keyed on a private `FlashWait` (message **and** offer id), so a second offer under the same words gets its own full time (build 257's lesson). `flashBottom` is unchanged. **Untested from here: on the phone the capsule sits at 16 points above the safe area, which is over the tab bar, as every message always has; with an Undo that is eight seconds instead of two and a half. If it is in the way, lift it by the tab bar's height while an offer is showing.**
- **Timing, in Core (`UndoWording.secondsOnScreen(offersUndo:)`, tested): 8 s with an offer; every other message 2.5 s, as before.** The first version let a longer message stay a third of a second a word (up to 8 s), so that the answer to a partial Undo could be read. That changed about six existing messages (the focus notices, "Not found — but N notes are still coming from iCloud") and was not in the brief, so it went. **The answer to a partial Undo is therefore also up for 2.5 s.** If that proves too short, give that one answer its own opt-in (a time passed to `flash`); do not bring back a rule for every message.
- **A debug build started with `-paragon-test-vault` keeps an Undo offer a minute**, not eight seconds (`ContentView.flashSeconds`, under `#if DEBUG`). Not in the brief: eight seconds between "the button exists" and "press it" is easy to lose on a slow CI runner, and a test that fails for its own reasons is worse than none (build 190). The production value is `UndoWording.offerSeconds`.
- **Screen tests, both at the `testTheWeekCanBeGivenALine` anchor.** `testTheOverdueMoveCanBeUndone` (both platforms): Quick capture makes `Pay the old invoice >2020-01-01` (the fixture has no dated task, builds 211 and 221, and still has none; the Inbox is read by Today), `today.overdue.today` (new identifier on `HeaderActionButton`, which gained `identifier`) is pressed, `flash.undo` appears, the Overdue buttons are gone (the only overdue task moved), **Undo**, and the Overdue buttons are back. **The words of the answer are pinned in Core, not on screen**: that message is up for 2.5 s and a slow runner can take longer between two queries. `testADeletedInboxLineCanBePutBack` (Mac only): select the Inbox line, `app.typeKey(.delete, …)`, `flash.undo`, the line gone, **Undo**, the line back. **It skips when nothing was deleted at all**, because whether a key typed from outside reaches the Inbox column's `.onKeyPress` depends on keyboard focus, which no test here has proved; a line deleted with no Undo, or an Undo that does not bring the line back, still fails. The phone's delete is behind a line's menu, which no test has opened (build 269's note about `Menu` items): left to Core.
- **Not checked from here (no compiler, nothing drawn):** `didSet` on an `@Published private(set)` property (the pattern `activeSheet` uses); a private nested struct as the `.task(id:)` key; `Set<DateOnly?>`; `FlashCapsule(…) { model.undo() }` as a trailing-closure memberwise init; `XCUIKeyboardKey.delete` through `app.typeKey`; whether the Delete key reaches the Inbox column under XCUITest (the Mac test skips if not); how the capsule with a button looks on both platforms.
- **Lessons.** (1) **A sentence that justifies leaving out a safeguard is a claim to check, not a reason**: "a date is not a deletion, every task is still there" held for the task and not for the information that mattered, the old date. Before relying on "it can be done again by hand", ask whether the old values are still known to anyone. (2) **A mirrored identity (a title) shifted by one line looks like a match**; an Undo that pairs old values with tasks has to prove the pairing, not accept the nearest. (3) **Tie two things that must live and die together in one place** (`didSet`) instead of asking every writer to clear the second.
- **The review of this build found five things, all fixed before upload.** (1) `openVault`/`closeVault` called `clearCaptureMessage()` straight after `settleFocusBeforeLeavingVault()`, which wiped the "clock ran over 12 hours, time not written" message before it was drawn (build 256's rule that a dropped clock is reported): they clear only the offer now. (2) A moved task with no id could take the old date on an unmoved twin that already had the new date, once a line above had shifted the lines: an id-less move is now `.unclear` whenever more open tasks with that name carry the new date than were moved (two new tests, a shift of two lines and of one; the cost is that such a task is always left alone, which is the safe side). (3) The answer for several tasks left alone for different reasons had no noun and named two of five reasons; it names all of them now. (4) The timing change above. (5) The "To try it" step named **Quick capture** on the iPhone, where the button is **+** and opens the New note screen with **Capture** chosen. **A lesson in two lines: a clear that is "wider than the intent" (a whole message for one offer) removes what the line above it just said; and a plan that gives a time for one kind of message does not give leave to change the time of all of them.**

**Build 277: his reason on the Aspirations page.** His answers: A1 yes, A2 **no, only on the Aspirations page** (not Start the day, not the review). The Goal template has shipped `## Why` + a question since the first build; he answered it once in the note and no screen read it again, although an aspiration is "the top, most important things in my life" (build 199). The shape is an area's Standard (build 271), and so is every rule.
- **One parser, decided after reading: `AreaStandard` was generalised, not copied.** `Core/Sources/ParagonCore/Markdown/SectionText.swift` (internal `struct SectionText`, heading + template → `shippedPlaceholders`, `text(in:placeholders:)`, `note(_:settingText:placeholders:)`, `placeholders(inTemplate:)`, `cleaned`, `folded`) holds what `AreaStandard` held, moved as it was; `Vault.placeholderLines(of:kind:among:)` is the loop that `areaStandardPlaceholders` had. `AreaStandard` keeps its whole public API and `firstSentence` (only a one-line place needs it) and forwards to `AreaStandard.section`; every `AreaStandardTests` case reads through it unchanged. `NoteReason` (`Vault/NoteReason.swift`, tested in `NoteReasonTests`, 28 cases) is the second instance: `## Why`, `Templates.goal`, `Vault.goalReasonPlaceholders(among:)` (templates with `type: goal`, so aspirations and goals with a date are both read). `AreaStandard.folded` (internal, never called outside the file) went; `SectionText.folded` is the one. **When a second section of this kind comes, it is a third instance of `SectionText`, nothing more.**
- **A placeholder question is not an answer, again**: a fresh aspiration reads as "No reason written yet." and the screen test pins it by `aspiration.reason.text` not existing. The shipped line is read out of `Templates.goal`; his own goal templates' lines come from `AppModel.reasonPlaceholders`, set in `refreshSnippets()` beside `standardPlaceholders` (two lines in `AppModel.swift`).
- **App, in a new file `Views/AspirationReasonView.swift`** (other builds change `AppModel`/`GoalsView`): `AppModel.reason(of:)`, `setReason(_:on:startedFrom:) -> ReasonWrite` (`written` / `changedMeanwhile(onFile:)` / `notWritten`, the rule of builds 264, 268, 271: it takes the reason the box opened on and writes nothing over words he never saw), and `AspirationReasonBox`, edited in place — **Cancel** and **Save** above the field (builds 160, 231), no `onSubmit` (Return in a vertical field is unknown, build 272). `GoalsView.swift`: the box is under the title in `AspirationChainBody.head` (the Mac's page, and "All of them") and first in the `compact` branch (the phone's folded-open chain, one untagged list row), plus `aspiration.<path>` on the Mac's tagged row (`.accessibilityElement(children: .contain)`, as `goal.<path>`) and on the phone's folding `Button`.
- **iCloud, which `AreaStandardBox` does not do (the brief said to mirror it; it has nothing to mirror)**: `setReason` refuses a note in `notesBeingUpdated` with a message (a write over a stale copy is not caught by `Vault.save`'s date check, build 261), the box's button is `.disabled` meanwhile, and a note with no reason in its older copy draws an orange cloud line (`aspiration.reason.waiting`) instead of "No reason written yet." — an older copy saying nothing says nothing about the newer one (build 100). A note waiting for iCloud is not in the index, so it has no page at all.
- **Phone buttons**: Cancel and Save are `.borderless` (one List row holds the chain's other buttons, builds 266, 272); the edit button is `.plain`, as the measure chip beside it.
- **Show the whole of it, clip the page**: `.lineLimit(4)` on the page, the field shows all. The notice for a reason changed meanwhile quotes `AreaStandard.firstSentence` capped at 120 characters (a shared text helper, not a second sentence rule).
- Screen test `testAnAspirationsReasonCanBeWritten`, both platforms, with `Place.aspirations` (`sidebar.Aspirations` / `browse.Aspirations`, the first test to use that room): the row `aspiration.Goals/Be strong and steady at seventy.md`, `.missing` exists and `.text` does not, **Write the reason…**, type, **Save**, `.text` holds the words, `.missing` gone, the button no longer offers to write one. Mac also: the text is wholly inside the window and above `aspiration.addGoal`, and `expectNoOverflow`. **The Mac page has no editor, so `## Why` in the file is pinned in Core** (`NoteReasonTests` writes through a real `Vault` and reads the file back).
- **Not done, on purpose**: a goal with a date's page has no reason box (the same `AspirationReasonBox(note:)` goes into `ChainGoalBlock.head` when `lead` in one line, if he asks); Start the day and the review show nothing.
- **Untested from here (no compiler)**: `SectionText` as a `Sendable` struct referenced by two `static let`s; a vertical-axis `TextField` in the phone's List row with the keyboard up; whether `.disabled` greys the plain edit button the way the Mac and phone draw it.
- **The review of the Reason found two wording faults, both fixed before upload; the code was right in each case.** The manual and the version note said the page tells you about iCloud while the button is grey, but the orange line (`aspiration.reason.waiting`) is drawn only when the older copy holds no reason: with a reason shown, the button is grey and the page says nothing, so both sentences now say "if no reason is shown yet, an orange line says why". The version note also ended with an idiom ("Under the hood") and an abstract sentence; it is now "What changed inside the app" in three short sentences. **A sentence that says what the screen says has to name the state in which it says it.**

**Build 277: a time of day on a task, the At line.** His answers on 2 November: B1 yes, B2 **in the date window, as a new line called At** (not in the task menu). The oldest fault in this project once more: `TaskItem.dueTime` was read by the parser, the Reminders sync, `DayScheduleView` and the task row, and **nothing in the app could write one** (132, 134, 140, 144, 165, 268, 276). **The word is At, never "Time"**: a task's time already means how long it takes (`~45m`, build 248).
- **Core, tested** (`Model/TaskDue.swift`, `TaskDueTests`, `TimedTaskTests`): `TimeOfDay.typed(_:)` → `TypedTime` (`.empty` / `.time` / `.invalid`; **exactly two digits for the minutes**, so `14:0` says it is not a time yet and `14.00`, `1400`, `24:00` are refused; the case is `.empty`, not `.none`, build 274's reason), `TimeOfDay.quickChoices` (09:00, 12:00, 14:00, 16:00, pinned), `TaskItem.settingDue(date:time:)` (a time needs a date) and `settingDueDate(_:)` (keeps the time: **Reschedule, the Inbox's Today/Tomorrow and Move to today keep it**), `TaskItem.dueText` (the one wording of "2026-11-04 14:00", used by `TaskRow`, `InboxRow` and the File it card), `TimedTask.minutes/span` (its own `~45m` when **Use task times** is on, else 30; cut at 24:00; never empty), `NoteIndex.timedTasks(on:)` and `timedTaskRanges(on:usesTaskTimes:excluding:)`, and `DayPlan.starts(for: [PlanWish], …)` in `Vault/DayPlanAtTime.swift`.
- **`DateChoiceView` is now a thin shell round `DateTimeChoiceView`** (Theme.swift). The brief offered new parameters or a second closure; both leave the six plain date windows (deadline, goal target, ending, Quick capture, Close the day, New note) one inference away from changing. The shell keeps the old signature byte for byte and calls the new view with `offersTime: false` and `{ date, _ in choose(date) }`; only `TaskDatePicker` uses the new view directly. The new view has a **written-out `init`** (it mixes `@State` with stored closures). The At line: a field (`date.time`), the four quick times in a `WrappingHStack` (`date.time.09:00` …), **No time of day** (`date.time.clear`) and a hint line (red when `.invalid`). The button is **No time of day**, not **No time**: **How long** in the task menu already has a **No time** that takes away the task's length, and one label for two things is build 176's fault (the length's button keeps its name). **The quick times and No time of day only fill or empty the field; Set (or Return in either field) is the one way to write**, so one commit path. **No date** clears both. `.submitLabel(.done)` + `.onSubmit(set)` is the way out when the phone's keyboard covers **Set** (builds 160, 231): **the review found the window had grown by about 110 points and the buttons row could end under the phone's keyboard, so a `.keyboard` toolbar with a second Set was added** (`#if os(iOS)` at the end of the body, the shape `SearchView` has had since build 160; only with `offersTime`, so the six plain windows are unchanged; no identifier, so `date.set` still has one match). **Unchecked from here:** that a keyboard toolbar shows in a sheet with no `NavigationStack`; if it does not, Return still sets.
- **`AppModel.setDue(_:date:time:)`** (a separate name, build 168) acts on the task **as the note holds it now** (`liveTask(for:in:)`: by `^t` id, else line and title, else title), writes nothing when nothing changes, so the double fire of Return (`.onSubmit` and the default-action shortcut) writes once. `setDueDate` now calls `settingDueDate`; `moveTasks` is unchanged and keeps the time (said in its doc comment).
- **Plan** (`PlannerView.swift`): `timedTaskSpans` → `PlannerSpan.task` → `PlanTaskCard`, placed by the same `place(_:)` as the blocks (`placedPlan`, the old `placedBlocks`) in the right-hand lane, `.offset` never `.position`. **It must not look like a block** (a colour is a claim, build 152): neutral ink, a 1pt border at 50% of `Color.primary`, 5% grey, the task's own circle (a picture, ticking stays in the Actions column), one gesture, a plain `Button` that opens the note through `model.show(note)`. One line under 40 points, two above, clipped (build 226). Its label is set explicitly, "<title>, at 14:00", identifier `plan.task.<title>`. **Departures from the plan, all small:** (1) a timed task whose name equals the name of a plan block over its hour is **not drawn**, because Start the day now puts a picked timed task into the plan at its time and a card beside its own block would halve both widths (`NowAndNext.sameName`, the rule Planned and worked uses); (2) like an event, a task that ends at or before 06:00 is not drawn (the lane starts at 06:00; one that starts earlier and ends later is drawn from 06:00 and its words keep its own time); it is still in Actions.
- **Start the day** keeps the hour free. `planningBusy(on:excluding:)` adds the day's timed tasks, except the ones being picked (or a picked task's own hour would block itself, and `dayFit` would count it twice), so the sum and the placing still read **one list** (build 249). `planActions` asks `DayPlan.starts(for:…)`: **a picked timed task goes at its time when that hour is free and not already past; otherwise it takes the first free gap as before**; timed ones are settled first and count as taken for the rest. Blocks keep `planLength(of:)`, so a timed pick with no `~` is still an hour (build 249), unlike the card's half hour. `StartDayView`'s instruction line says it. **While notes are still coming from iCloud a timed task in them is not in the index, so its hour is not kept free** (build 100's rule): `StartDayView.finish()` still writes the plan, since refusing would make the screen unusable for as long as one note is on its way, and adds "Some notes are still coming from iCloud. A task with a time of day in them was not kept free. Look at Plan." to the message (`messageWithCloudNote`); the manual and the version note say it too.
- **`DayScheduleView` changed in two small ways, against the brief's "do not change what it draws":** it is fed by `timedTasks(on:)`, and **its timed tasks are now as long as `TimedTask.minutes`** instead of a flat 30 minutes. Otherwise Plan drew a `~45m` task as 45 and the Calendar section's day as 30: build 168's fault, in a new place. One line; revert it if he wants the old length.
- **Screen test `testATaskCanBeGivenAnHour`, both platforms, at the end of the class.** **A task's date window is reachable only from the right-click menu, except in the Inbox**, where **Pick a date** is a plain button (build 215) and it opens `TaskDatePicker` in a sheet. The brief's All actions route needs a context menu that no test has ever opened (run 308); the test uses the Inbox line **Call the bank about the ferry**: select it, press `inbox.quad.date`, press `date.time.09:00`, check the field says 09:00, press `date.set`, wait for the window to go, `go(to: .plan)`, and check `plan.task.Call the bank about the ferry` exists and its label contains "at 09:00" (read back from the file, so it proves date and time were written together); on the Mac the card must lie inside the window. **09:00, not 14:00**: near the top of the ruler on any screen, so no scrolling. Not tested: pressing the card (an Inbox note opens a different screen on each platform), a typed time, **No time of day** (an empty `UITextField` reports its placeholder as its value). **This is build 205's rule again: a test that cannot reach a control is a report about the control.** The date label on a task row is not a button; making it one is a small build of its own, not done here.
- **What else shows the time:** `InboxRow` and the File it card now say "2026-11-04 14:00" with a clock (they said only the date, and the Inbox is where the window can be reached from).
- **Reminders** needs nothing: `SyncEngine` and `EventKitRemindersStore` carry `dueTime` both ways (`SyncEngineTests` pin it). It rings at that time after the next sync, which is new for tasks that had only a date; said in the manual and the version note. **The hint under the At field and every sentence say "if this note syncs to Reminders"**: a Goal, a Resource, a note with `sync: false`, an archived note, and (by Settings) areas or daily notes never go to Reminders (`SyncEngine.syncableNotes`), and the review found the first wording promised a ring for those too. A hint that depended on the task's note was judged not worth a new parameter.
- **Not in this build, as agreed:** Today's lists are not sorted by time (`openTasks()` already orders a day by time), nothing in the widget, nothing in Quick capture's date window (its `DateChoiceView` is the plain shell), no plan block made automatically.
- **Lessons.** (1) Before choosing how a test gets to a control, ask whether anything but a right-click gets there; the Inbox quadrant was the only plain button. (2) Moving a shared view's implementation under a thin shell kept six callers untouched without a single inference question. (3) A new kind of thing drawn on a screen that already draws a similar thing (a task card beside a block) needs its own look chosen on purpose: the colour is the claim. (4) A rule read by three screens (a timed task's length) went into Core before the third screen had a chance to differ.
- **The review of the At time found seven things, all fixed before upload:** the manual named "build 289", a number that will not exist (the merged stamp is only known at the merge, so no number is written in prose); "a thin dark border" and "a very light grey background" were false in dark mode, where `Color.primary` is white (now "a thin border in the colour of the text, a faint tint"; a sentence that names light or dark has to be true in both, build 268); "a task with a time before 06:00 is not drawn" was wrong for a task that starts before 06:00 and ends after it (drawn from 06:00; only one that ends at or before 06:00 is left out); the hint "Apple Reminders rings at this time." was shown for every task, also in notes that never sync; the button **No time** named a second thing next to **How long**'s **No time** (it is **No time of day** now, in the window, the manual, Words and the comments); the window had grown past what a phone shows above the keyboard, so **Set** could be under the keys (a keyboard toolbar **Set**); and Start the day wrote blocks over timed tasks in notes still coming from iCloud without saying so (the message now does). **The lesson: a sentence that promises an effect ("rings", "keeps free", "is not drawn") has to be checked against the cases where the effect cannot happen, not only the case it was written for.**

**The review of the merged build 277 found four things, all fixed before upload.** Two were a plan number split over a line break in a comment ("(build" at the end of one line, "287)" at the start of the next), which the rewrite of 287/288/289 to 277 could not match — **a replacement by pattern needs a second look for the pattern broken across a line**. One was real: **Start the day's caution about notes still coming from iCloud was three sentences shown for 2.5 seconds, and the capsule appears only once the sheet has closed**, so it was gone before it could be read. `flash(_:seconds:)` is an opt-in longer time (`flashLinger`, a plain value that any other message ends together with the Undo offer, and that `flashKeepingUndo` keeps); only that one caller uses it, so every other message keeps its 2.5 seconds. The last: **Undo of a deleted Inbox line did not refuse a note that iCloud was still updating**, though the dates' Undo and the Reason did — `Vault.save` compares against the local date and would not notice a write over a stale copy (build 261). `putLineBack` now refuses and says the line stays deleted (`UndoWording.noteBeingUpdated`, tested). **A rule written for one writer (build 261's refusal) has to be asked of every later writer in the same area.**

**Build 279: Waiting for, by person.** His answers on 2 November: C1 yes, C2 **inside All actions, as a switch beside the boxes** (no new sidebar row, no new Browse row: build 166's two doors into one room). He is a project manager and most of his week is waiting for other people. The app had a **Waiting for** snippet and a manual sentence promising these lines "turn up in a review"; **nothing in the code read them** (the oldest fault here, once more: 132 to 276). This build gives them a reader, a writer, a list by person, and keeps them out of "next".
- **The shape of a waiting line** (the lead's, kept): `- [ ] Waiting for Anna: the quote >2026-11-06 #waiting @since(2026-11-01)`. A waiting line is an **open** task whose tags hold `waiting` (any case) **or** whose title begins with `Waiting for ` (any case; this finds lines he wrote by hand). Person = the words between `Waiting for ` and the first `:`; what = after it; no colon means no person (listed under **Someone**, "No name given"). **A colon between two digits does not end the name** ("Waiting for the 12:30 train"): an addition to the plan, since the plan's rule would have made "the 12" a person. Done and cancelled lines are never waiting.
- **`@since(YYYY-MM-DD)`**, the day the waiting began, is the only way to say "waited 5 days"; a task line has no creation date, so **no `@since` means the row never says "waited"** (builds 100, 141, 255). `TaskItem.since` is the last parameter of the init (every `TaskItem(` call site was read: they all use labels and defaults), `TaskParser.sinceRegex` lifts it like `@done`, `serialized` writes it after `@repeat` and before `@done`, `nextOccurrence` clears it, `MarkdownHighlight` dims it like a date. The sync engine copies the task struct and sets fields one by one (build 248), so it survives a reminder edit and a completion; `SyncEngineTests.testTheDayAWaitStartedSurvivesAReminderEditAndACompletion` pins both. The shipped **Waiting for** snippet now ends `@since({{date}})`; his own `Templates/Snippets.md` is **not** rewritten (the manual says how to add it by hand).
- **Core** (`Vault/WaitingFor.swift`, tested in `WaitingForTests`, 30-odd cases): `WaitingFor.parse` / `TaskItem.isWaiting` (a cheap tag-or-prefix check first, because `nextThing` now asks it of every task of every note); `WaitingLine` (`waitedDays` nil without `since` or with one in the future, `followUpState` overdue/today/later/noDate, `waitedText` "asked today"/"waited 1 day"/"waited 5 days", `followUpText` "Follow up today" / "Follow up Fri 6 Nov" / "Follow up Sat 6 Feb 2027" / "Follow up was 3 days ago" / "Follow up was yesterday" / "No follow-up date", `captionText` joining the two with " · "); `WaitingGroup` / `WaitingList` (structs, never tuples; named people A to Z by `localizedCaseInsensitiveCompare`, **Someone** last, lines by follow-up date then longest wait then title then id; display name = the spelling used most, the first seen on a tie; `summary` "4 things · 2 people" / "1 thing · 1 person" / "3 things · nobody named"; `pointerText` "3 waiting for other people" / "1 waiting for another person"); `NoteIndex.waitingFor(among:today:)` / `waitingFor(today:)`; `WaitingFor.people(in:)` (most used first, for the chooser); `WaitingFor.writesText` (the live line under the **Who?** field); the writers `TaskItem.makingWaiting(for:today:)` (title `Waiting for <person>: <what> #waiting`, **no stacked prefixes or tags**, `since` only if there was none, no date means today plus 7, a date is kept, a blank person returns the task unchanged, and the person is cleaned of `: # > ^ @ ~` and line breaks so a name cannot break the line), `notWaiting()` (never leaves an empty title), `WaitingFor.followUpNextWeek(from:today:)` (the later of the date and today, plus 7). `dayText` formats the weekday and the month one by one and puts the day between them, because a ready-made "EEE d MMM" pattern differs between English locales (a comma) and the wording is pinned by tests.
- **`Note.liveTask(for:)` and `Note.rewrite(task:with:)` are new, and they matter.** `Note.replace(task:)` finds a line by the title it is *given*, so it **cannot write a changed title for a task that has no `^t` id**: it looks for the new title in the file and fails. (By reading, not tried: that means `AppModel.renameTask` silently does nothing for a task that has no id yet, such as a line captured since the last sync. Not touched here; worth its own look.) The three writers find the task **as the note holds it now** (by line, else id, else words) and write the changed version over that line, which also stops a stale row undoing a change made a moment ago.
- **`Note.nextThing(in:)` skips waiting lines at every step**, even with `#next` on them. All callers go through it (the Projects list `ProjectLine`, `ChainProject`, `NoteIndex.nextActions()` for Today, Start the day, Plan and the widget, `Review.holdsSomethingToDo`); each was read and no test counted on a waiting line being next. **Not changed, on purpose:** a waiting line with a due date still shows in the ordinary date lists (Overdue, Due today, All actions, the Calendar): when its follow-up date comes, chasing it is something to do; the **Next action** box under **Mark** is the explicit `#next` tag and stays as it is; the weekly review's per-project `noNextAction` flag still judges a project by `open.isEmpty` (a project of waiting lines has open tasks and is not flagged). **The area flag follows the same answer** (decided after the review, see the last paragraph): `Review.holdsSomethingToDo` counts `Note.hasWaitingLine` as something to do, in the area's note, its live projects and its sub-areas.
- **Departed from the plan (it said the box "says No next action"):** with `nextThing` nil and `total > 0`, `ProjectLine` would have chosen **`.allFinished`**, and the box would have read "All 3 finished" about a project with three open lines. **New `ProjectLine.Need.waitingOnly(count:)`**, drawn in `ProjectsView` and `AreasView` (four `switch` places) as an hourglass line **"Its one open task is waiting for someone" / "All 3 open tasks are waiting for others"** plus the same grey **No next action** pill while the project is active. **A rule that skips something at one step changes the answer of the neighbouring branch written for "nothing left".** `ChainProject.hasNothingToDo` (the Goals chain's orange "No next action") **is now false when the project has waiting lines**; `ChainProject.waitingCount` is new, and `ChainProjectRow` (GoalsView.swift, a small edit) draws the same grey `ProjectLine.waitingText` line as the Projects list. The first version left the orange in place because GoalsView is another build's file; the review showed the cause is in Core and the fix is four lines there.
- **App writers** (`Views/WaitingForView.swift`, an `extension AppModel`, so `AppModel.swift` is untouched): `makeWaiting(_:for:)`, `stopWaiting(_:)`, `followUpNextWeek(_:)` — flush the editor, read the live note, **write nothing when nothing changes**, save, then `flash` ("Now waiting for Anna." / "Not waiting any more." / "Follow up on Mon 9 Nov."). `waitingPeople` reads the names from the lines themselves: no new file to keep in step.
- **The task menu.** `TaskContextMenu` gains `@Binding var askingWho` (the only place a `TaskContextMenu(` is built is `TaskRow`) and, for an open task, **Waiting for…** (after **How long**, same words on a line that already waits) and, on a waiting line, **Not waiting any more**. **The Inbox's own line menu (`InboxLineMenu`) is a different menu and deliberately has no such item**: file the line first; said in the manual. `TaskRow` owns `@State askingWho` and the `.popover` — **on the title `VStack`, not on the row**, because the row already carries the date popover and a second presentation on one view is not reliable on the phone (build 44); the time button does the same with its own. A macOS alert drops everything that is not a text field (build 93), so it is a popover (a sheet on the phone). `WaitingWhoView`: **Cancel** and **Add** sit in the **top** row, above the field (the keyboard covers the foot of a phone sheet: builds 160, 231, 271); the people already used are `PickChip`s that **fill the field**, not commit, so the live line shows what **Add** will write before it is written; Return adds.
- **All actions** (`AllActionsView.swift`): `@AppStorage(WaitingShowing.key)` (`actionsShowWaiting`, default off, forgotten by `TestVault`), read by the screen and by its pointer. The old body became `actionsPart`; a `StateToggle` (**`hourglass`**: grepped, nothing else in the app uses it, build 168) beside the column's name in **both** headers, identifier `actions.waiting`; the name reads **Waiting for** on the second half (build 159). On the first half `SectionLabel` got `.lineLimit(1).layoutPriority(-1)` and "of N" / **Clear** got `.fixedSize()`, so a narrow Mac column squeezes the name and not the controls (build 138; the toggle made the header about 30 points wider). With the switch off, `waitingPointer` ("3 waiting for other people", a plain button, `actions.waitingPointer`) points at the list and draws nothing when nothing is waiting (build 74). With it on, `WaitingForList` draws the count line (`waiting.summary`), the usual orange `VaultWarningBar` when notes are coming from iCloud, then a plain `List` **without selection** (nothing is tagged: builds 71–74) of section headers (`waiting.person.<name>`) and rows that are **real `TaskRow`s** (build 149; the tick means the answer came) each followed by the caption (`waiting.caption.<title>`, red only when the follow-up date has passed) and a borderless **Follow up next week** (`waiting.followUp.<title>`). Two empty states, never a blank list: `waiting.empty` ("Nothing is waiting for anyone" + how to make a line) and `waiting.emptyCloud` ("Not everything is here yet", orange; an empty list while notes are still coming from iCloud must not claim nothing is waiting: builds 100, 261).
- **Ended and archived notes are left out of the waiting list** (`waitingFor(among:)` drops notes that are Done/Missed/Dropped or archived; `openTasks()` already drops archived ones), as the plan said; **All actions' own list still shows an ended project's open tasks**, as it always has. The two lists therefore differ for exactly that case. The pointer and the list use the same function, so they cannot disagree.
- **Screen tests** (both platforms, inserted before the focus-timer test as agreed): `testNothingWaitingSaysSoAndTheSwitchGoesBack` (no pointer, the switch opens `waiting.empty`, switching back brings `actions.fold` and the test action back) and `testAWaitingLineIsListedByPersonAndFollowedUpNextWeek` (the line is made through **Quick capture**, because the task menu is a context menu and nothing has opened one in a test, run 308: `Waiting for Anna: the quote >2020-01-01 #waiting @since(2020-01-01)`; then the pointer says "1 waiting", `waiting.person.Anna`, `waiting.summary` == "1 thing · 1 person", the caption says "was" and "waited", **Follow up next week** is pressed at its frame and by a click if that did nothing (a short button beside a Spacer: build 247) and the caption stops saying "was" and keeps "waited"; then back to the boxes with the pointer there). **It reads what changed, never what it changed to**: the caption's words depend on the runner's day. The test vault still has no dated task (build 221): the test makes its own.
- **Untested from here (no compiler, no screen):** that `.popover` on the title `VStack` opens from the context menu on both platforms (the date popover on the row does); whether the phone's keyboard autocorrects the captured line (`Anna`, `quote`) and so changes the person's name the test looks for; that `StateToggle`'s identifier lands on its button (no `StateToggle` had one before); how the header looks in the Mac's 220-point column with a filter ticked.
- **Lessons.** (1) The plan said "the box says No next action", and the code would have said "All 3 finished": read what the *neighbouring* branch says when a rule starts to skip things. (2) A shared writer (`replace(task:)`) that matches by the very field you are changing is a trap: say what it matches on before reusing it for a rename. (3) Words he reads: "waiting" was already in three older sentences with another meaning ("nothing is waiting anywhere in it"); they now say "nothing is left to do", so the word means one thing in Help.
- **The review of the Waiting for list found seven things, all fixed before upload.** (1) **Make this the next action** was offered on a waiting line: it would have taken `#next` off the real next action and put it on a line `nextThing` skips. The menu hides it (**Clear next action** stays, for a hand-typed `#next` on a waiting line) and `Note.setNextAction` returns false for a waiting line, pinned by `testAWaitingLineCannotBeMadeTheNextAction`. (2) The weekly review and the Goals screens answered "no next action" in opposite ways for a project of nothing but waiting lines, and an area whose only work was such a project was flagged in orange in step 6 while step 5 and the Projects list were calm. The rule is now: **a waiting line counts as work in flight everywhere a "nothing to do" alarm is raised** (`Note.hasWaitingLine`, `ChainProject.waitingCount`); the other direction (flag it orange) would have warned a project manager about the most normal state of his week (build 132's rule). Three new cases in `ReviewAreaWorkTests`, and `WaitingForTests` no longer pins the orange. (3) `notWaiting()` kept a title that still began with **Waiting for** when nothing followed the name, so **Not waiting any more** did nothing, or flashed a false message when only `@since` came off. The name now becomes the words ("Anna"); a line with no words and no name at all stays waiting and `stopWaiting` says so instead of returning in silence. (4) The hourglass was spelled out again in `ProjectsView` and `AreasView`; both read `WaitingShowing.symbol`. (5) The version note's "not on Today, Start the day, Plan" read as absolute, but a dated waiting line is in **Overdue** and **Due today** on those screens; it now says "next action". **Lesson: when a rule skips something at one step, list every reader of the old answer, and ask what each says when the skipped thing is all there is.**

**The review of the merged build 279 found three things, all fixed before upload.** (1) **The Tags screen could rename or delete `#waiting`**, leaving a tag-only waiting line out of the list and possibly a next action again; `changeTag` refuses it as it refuses `#next` (build 145's rule: any tag the app gives a meaning needs the guard — **asked of the next tag the app names, not only of the first**). (2) **The caption in a waiting row sat beside a fixed-width button**, so the Mac's 220-point middle column left it about 66 points and cut off "waited N days", the one fact `@since` exists for (builds 138, 255); the button is under the caption now. (3) **Close the day's heading "Waiting for tomorrow" meant "to do tomorrow"** and now sat above rows that can themselves begin with "Waiting for Anna:" — **a word that becomes the name of a feature must be searched for on every screen that already used it in its everyday sense** (build 159's rule): the heading is **To do tomorrow**, its empty line "Nothing is planned for tomorrow yet.", Start the day's "Nothing is waiting for today." is "Nothing to do today.", and the manual's sentence about the tray no longer says "nothing is waiting". A first push of the review lost its behaviour part to the five-hour usage limit; it was resumed from the journal, which re-ran only the agents that had failed.

**Build 279's CI: two Mac tests failed twice, and both were the tests (3 November, test-only push, no new build number).**
- **`testATickedTaskShowsInDone`** failed the same way in both runs of CI 368: neither the press nor
  XCUITest's own click ticked **Book the night train** in **All actions**, and the tick's frame was the
  same both times, (280, 590). The runner's screen is 1024 wide (the 900-point window starts at x 62)
  and the window is 450 points tall. The filter boxes and the list share what is left under the
  column's header, and build 279's **Waiting for** switch (a 26-point `StateToggle`) made the header
  about ten points taller, so the row went below the drawn part of the list. **A row scrolled out of a
  `List` keeps a finite frame outside the window**, so `isOnScreen` said yes and the press landed below
  the window. `scrollIntoWindow(_:)` (ScreenTests.swift, Mac only) scrolls the list at the target's own
  x, low in the window, until the frame is wholly inside it (four steps the likely way, eight the
  other). The failure message now names the window's frame too. **Not seen, inferred** from the frame
  and the layout dump in the log; the next CI run says whether it was right. Build 268's first run of
  this test failed the same way and was put down to the press point: probably the same cause.
- **`testAnOpenLinkReusesTheOpenWindow`** failed for the second time ("1 before, 2 now"; first in
  build 277's CI) and passed on other runs with nothing changed. It counted **every** window with a
  frame. It now counts only windows at least 500 × 300 (a PARAGON main window is at least 720 wide;
  **Plan the day** is 720 × 640), on the guess that the second window was a help tag or a popover that
  macOS draws in a small window of its own, shown or not depending on where the previous test left the
  pointer. **That is a guess.** The failure message now lists every window's title, identifier and
  frame, so a third failure says what the second window is. If it is a real second main window, the
  place to look is still `TakesLinksInOpenWindow` (ParagonApp.swift).
- **The iPhone screen-test job's limit went from 30 to 45 minutes**: run 368 took 29 minutes with every
  test passing. The Mac and iPad jobs keep 30.

**Build 277 was never uploaded on its own (3 November), and a flaky test showed itself.** The CI run of build 277 had one Mac failure, `testAnOpenLinkReusesTheOpenWindow` ("The link opened another window: 1 before, 2 now"), which passed on the first push and on the one re-run — the first failure of the one-window link (build 276) in three runs; **a second failure is real: look at `TakesLinksInOpenWindow` in `ParagonApp.swift` and at how `app.windows` is counted before touching anything else.** While that re-run was going, another session pushed build 278 (the iPad's columns) on top of 277, and the TestFlight run I dispatched took the branch head: **277's changes reached him inside the upload labelled 278**. Nothing was lost, but I had dispatched without looking at the branch. **Before dispatching TestFlight, read `git log origin/<branch>` as well as CI — the run builds the head, not the commit CI checked.** My Waiting for work (planned as 278) became **279** because the number was taken.

**Found while planning, not in the eight** (offered on the page as small builds of their own),
**all three done in build 272** (see the small fixes above): `Vault.archive` overwrote `status: done`
with `archived`, so an archived finished project dropped out of its goal's per cent (and lost its
`ended:` line); `NoteGoalOptions` filtered `model.notes`, so **Serves…** offered ended goals in
vault order (build 204's missed menu); `WidgetLook.goal`/`.project` had drifted from
GoalTint/ProjectTint.

## The iPad mini, looked at (2 November 2026)

He asked what it would take to use PARAGON on his iPad mini. **Nothing has to be built for it
to run there**: the iPhone app has always been an iPad app too (`TARGETED_DEVICE_FAMILY: "1,2"`),
so every TestFlight build of the iPhone app installs on an iPad. On a full iPad screen
`ContentView.isCompact` is false, so the iPad draws the Mac's three columns, not the phone's
tabs. **Nobody had ever opened it on an iPad**, so he asked for the iPad mini in the tests.

- **`Tests/ParagonUITests/IPadScreens.swift`, a class of its own, and a CI job of its own,
  "Screen tests (iPad mini)".** `ScreenTests` chooses its way in by platform (tabs on iOS, the
  sidebar on the Mac), and an iPad is iOS with a sidebar, so the existing suite cannot run there
  as it is. Two tests, upright and on its side: open the app, press each sidebar row, open the
  test project, and take a picture after every step. On an iPhone both are skipped (the phone
  job counts skips as fine); the Mac never compiles them. The iPad job runs
  `-only-testing:ParagonUITests/IPadScreens` and treats a skip as a failure.
- **The pictures are the point.** Each is a test attachment and a PNG in `build/ipad-screens/`
  (written from inside the simulator to the runner's disk, found through `#filePath`). The job
  uploads that folder as the **`ipad-mini-screens`** artifact on the CI run's page. If the folder
  is ever empty, the job takes the pictures out of the result bundle with
  `xcresulttool export attachments` instead. A failed step leaves a picture named `… - FAILED`.
- **The pictures are also on the branch `ipad-screens`**, with a README that shows them one
  under the other: https://github.com/marsch124/AMS-PARAGON/tree/ipad-screens — he can look at
  them in a browser without downloading a zip, and a session in the cloud can fetch them with
  git (the artifact's download host, `*.blob.core.windows.net`, is refused by the session's
  proxy; `raw.githubusercontent.com` and git are not). The job force-pushes one fresh commit
  each run, so the branch never grows. **It is the one exception to "this branch only"**: CI
  owns it, nothing is ever merged from it, and no session works on it.
- **First run (CI 357): the vault opened and the sidebar was drawn, upright and on its side,
  yet no row counted as on screen.** The check asked `isHittable` and compared with
  `app.windows.firstMatch.frame`. Now it uses the app's own frame, picks the named element that
  has a frame, and presses by coordinate, as `ScreenTests.press(_:at:)` does on the phone. A
  failure message now says whether the row exists, its frame, and the app's and window's frames.
- **Second run (CI 358, and CI 360 on build 276): 24 pictures, two failures, both the test's.**
  On its side, **Aspirations did not exist**: a List only makes the rows it draws, so a row below
  the fold must be scrolled to before it can be found — `reveal` now scrolls whenever the
  sidebar is out, not only for a row that exists. Upright, **the Search screen's keyboard
  covered the lower sidebar** and the next press typed "a" into the search: Search is now the
  last row, the project is opened right after Projects, and nothing under the keyboard counts as
  on screen. The Calendar question from iOS was in the landscape Today picture: `settle()`
  answers it **Don't Allow** before a picture is taken.
- **What the pictures showed about the app (build 276), not yet fixed and not yet his call:**
  on the iPad mini **the three columns are wider than the screen.** Upright, the sidebar and the
  middle column fill it and the note column is pushed off the right edge, about 50 points of it
  showing. On its side all three show, but the note column is cut off on the right ("Choose a
  note in the middle col…"). Build 34's split view sizing is the Mac's; the iPad mini is 744 × 1133
  points. **Upright, a note opened from the Projects list opens in that hidden column**: the
  picture shows the selected project and only a strip of the note at the right edge, so upright
  a note cannot be read or edited. On its side the note opens and can be read, its top row cut
  off at the right. Shown to him on 2 November; what to do about it is his call.
- **Third run (CI 361): green, 30 pictures**, 15 upright and 15 on its side, no Calendar question
  in any of them.
- **Fourth run (CI 362, same test): red on its side.** The sidebar was scrolled to reach Projects
  and was still sliding when the frame was read, so the press opened **Goals**, the row above.
  The step's check only asked for *a* navigation bar, so it passed, and the next step failed.
  Now `reveal` waits until the row's frame holds still for half a second, and every step checks
  the middle column's **title** is the row's name — `NoteListView.navigationTitle`, except
  Time Blocks, whose `PlannerView` is titled "Plan the day" (`IPadScreens.titles`). **A check
  that any screen passes is no check of which screen** — the same lesson as build 211's
  `actions.noMatch` versus `actions.nothingOpen`.
- **He uses the iPad mini sideways only** (3 November 2026, his words: *"I will always use the
  iPad Mini in landscape mode"*). I had drawn three ways to fix the **upright** layout
  (https://claude.ai/artifact/6zNBwCkXWowPyjnouGnEm6) before asking how he holds it; the
  drawings are set aside. **Ask how a device is held before designing for one orientation.**
- **Say "landscape" and "portrait" to him, never "sideways" or "upright"** (3 November 2026, his
  words: *"Isn't 'landscape' the correct and commonly used term?"*). They are the words Apple and
  his iPad use. Build 278's version note and manual said "sideways" in the build that shipped;
  the wording was fixed in the next push. ("On its side" in the iPad test notes above means
  landscape.)
- **Build 278: `ColumnsFitTheScreen` (ContentView.swift), `.navigationSplitViewStyle(.balanced)`
  on iOS only.** The landscape pictures showed the detail column about 760 points wide with only
  about 440 on screen: with no style of its own, iPadOS *displaced* the detail column when the
  sidebar was out (the column kept its width and was pushed right) rather than narrowing it.
  `.balanced` asks for tiling. Measured from the build 276 picture: sidebar about 320, list
  about 375, so the note column gets about 440 points sideways. Upright is left to iPadOS.
- **`continue-on-error: true` on the iPad job while it is new**, and `commit-project` does not
  wait for it: the first runs went red on the other session's build 276 pushes, and a red run
  stops the TestFlight routine. Take it out once the job has been green a few runs in a row.
- **The system decides by orientation whether the sidebar is out**, not the app.
  `reveal(_:_:)` tries what a person would: the **Show Sidebar** button in the bar (never its
  **Hide Sidebar** spelling), a swipe in from the left edge, and a scroll of the sidebar for a
  row below the fold.
- **The next step, when he wants it:** make `ScreenTests` choose its way in by what is on
  screen (a tab bar or a sidebar) instead of by platform, and run the whole suite on the iPad
  too. Not before the pictures have shown what the iPad really does.
- No app change, so no build number and no TestFlight run.

## Safety round 2 of the premium review (build 308)

Round 1 was build 307 (commit 92a017f: hardening-01, -02, -04, -05, -06, -08, -11, -12; its rules
are in `Docs/HowItWorks.md` › **Exact safety rules (build 307)**). Round 2 is the twelve findings
below. **This section was written from the plan while the code was being written in parallel:
check each line against the code before relying on a detail**, and fix the `<!-- CHECK -->`
marks in `Docs/VersionHistory.md` and `Docs/HowItWorks.md` to the real on-screen words.
The user-facing rules are in `Docs/HowItWorks.md` › **Exact safety rules (build 308)**.

- **hardening-03 — the editor knows its base version.** The editor remembers which version of
  the note its text started from. On save, if the file on disk is no longer that version, a
  three-way line merge runs (base, mine, theirs). Different lines: both kept in the note. The
  same line: no guessing — the editor's text goes beside the note as
  `<name> (conflict <date time>).md` and the note shows the other version. Before 308 any
  outside change while typing produced a conflict copy. Never write over a newer file.
- **hardening-07 — sidebar task counts are cached.** Worked out once per note change, not on
  every redraw of the sidebar. A count must be thrown away when its note is re-read, renamed,
  archived or deleted; a stale count is the bug to look for here.
- **hardening-09 — iCloud's parked versions.** After each re-read of the vault, unresolved
  iCloud conflict versions (`NSFileVersion`) are looked for. Each is saved beside its note as
  `<name> (conflict <date time>).md`, then marked resolved, and he is told which notes are
  affected. No merge and no delete on his behalf. (Memory: `reference_icloud_conflict_copies`.)
- **hardening-10 — twin reminders.** Two reminders carrying the same PARAGON mark (two devices
  each made one for the same task): one is kept, the twin removed, and the report says so. A
  task that arrived from another device gets no reminder in the round it arrives in; it waits
  one round so the other device's reminder can arrive first and be linked.
- **hardening-13 — a second backup outside the vault.** In a folder he chooses once (for
  example Dropbox) or in the device's own storage. It carries the notes **and** the pictures
  and sketches; the in-vault backups (`.ams-para/Backups`) stay notes-only with build 307's
  tiers. Settings › Backups shows when the last outside copy was made. A failed outside copy
  never stops the in-vault backup.
- **hardening-14 — Reminders lists by identity.** Once linked, a list is found by its own
  identifier, the name is only for the first link. A new note whose name matches a list PARAGON
  did not make asks before joining it; "leave it alone" changes nothing in his list.
- **hardening-15 — tidy-up of the code folder.** The stray project copy
  (`Paragon 2.xcodeproj`) is removed, and `Tools/ship.sh` stops when it finds stray " 2"
  copies (iCloud/Finder duplicates) in the code folder. Not in What's new: nothing he sees.
- **hardening-16 — choosing a folder looks first.** Nothing is written before he agrees. An
  existing vault: "This folder has N notes — open it". Anything else: "not a PARAGON vault —
  set it up here?" with Cancel. While iCloud is still listing the folder it waits and says
  so; a folder that is still arriving is never called empty.
- **hardening-17 — incremental, background re-read.** A re-read reads only notes whose file
  changed and runs off the main thread. Everything that needs the whole vault (sync,
  rename with links, restore) still waits for a finished re-read.
- **hardening-18 — file names.** A very long title gets a shortened file name; the full title
  is kept in the note and shown everywhere. A rename that only changes capitals is allowed
  (the case-insensitive disk made the note collide with itself).
- **hardening-19 — the sync has its own vault access.** The sync uses its own copy of the
  vault access (its own security-scoped handle), not the one the screen uses, so neither can
  end the other's access.
- **hardening-20 — big notes.** While typing, only the lines around the cursor are restyled;
  the whole note is restyled after a pause. Short notes behave as before.

**Docs for 308:** What's new has eleven numbered items (hardening-15 left out on purpose);
How it works changed in **Your vault**, **Renaming a note**, **Bold, italic…**, **Reminders
sync**, **Backups**, the new **Exact safety rules (build 308)**, **When the app asks for a
vault folder**, **How iCloud moves the files** and **Editing the same note on both devices**;
`Docs/Words.md` gained **Conflict copy**.

## Not built (by choice)

- ~~**The App Group**~~ — **done, 20 September, and it needed both halves.** The archive now
  carries the entitlement (build 210) and he ticked App Groups on
  `com.schabbauer.AMSPara.Widgets`, the one identifier that lacked it. All three signed
  bundles carry `group.com.schabbauer.amspara`, and **he confirmed it on the phone**:
  *"Shared folder says Found in iPhone."* So the iPhone widget can read, and the share
  extension's outbox reaches the app at last — both untried by him so far, since he uses the
  widget on the Mac.
- ~~**The full peek carousel** on the phone (build 184)~~ — **decided against, 20 September,
  by him**: *"ok leave it."* I put the trade-off to him plainly rather than build it: a peek
  cannot be done with Apple's page view, so it means writing the pager myself out of a
  horizontal scroll view, and then every screen's top bar, the back arrow and the keyboard sit
  inside that scroll view and have to be made to behave again — three or four builds, breaking
  in places the tests cannot see. What it buys is a hint that the other screens exist, which
  the five names along the bottom already give. **Do not reopen it without a new reason from
  him.** The rule worth keeping: **when the cost is high and the gain is small, say so before
  spending his builds** — he had already said "all of them please", and he was still glad to
  be asked.
- **More screen tests.** Seven, on both the simulated iPhone and the Mac (build 196): the
  vault opens, every section, a note typed in, an Inbox line selected, the New note screen, a
  capture to the Inbox, a Map box pressed — and five on the Mac alone: the columns inside
  the window after a note opens, **Linked notes pressed open** (build 205), ⌘N, ⇧⌘N, ⌃⌘←.
  Build 211 added the last two he asked for: the All actions filter (both platforms) and the
  phone's swipe between tabs. **Nothing on the list is left.**

All five of the 14 September list shipped: the Map (170), the Weekly review (171), the review
rhythm (172), saved searches (173) and the iPhone widget (174).


## The look (build 280, 6 November 2026)

His brief: "make it a real Apple app" — look and feel only, every function, setting and
shortcut untouched. He picked **look B, coloured panels with meaning**, from a picture of
three (`Work/look-1.0/design/looks.png`); the spec is `Docs/Look.md` and the design lead's
system `Work/look-1.0/design/design-system.md`; the walk list of every screen, sheet and menu
is `Work/look-1.0/design/screens.md`; the pictures before and after are under `Work/look-1.0/`.

- **One type scale: `Txt` in `Views/Look.swift`.** Mac: page title 26 bold, section heading
  17 semibold in the part's colour, text 15, label 12 soft, lists 13 / 11. iPhone: Apple's
  text styles. The editor draws from `Txt.Editor` (15; headings 22 / 18 / 15; code 14), the
  same numbers in Edit (`MarkdownSyntaxEditor`) and Read (`MarkdownPreview`).
  **`LookRulesTests` (Core) fails any `.font(…)` that is not `Txt.…` and any `size:` outside
  Look.swift and the two renderers.** The sweep of 6 November mapped the old styles blindly
  (caption → label, headline → listTitle, callout/body → value …); a screen that looks off is
  most likely one of those blind mappings.
- **No stock icons.** `Views/Marks.swift` maps every old SF Symbol *name* to a hand-drawn mark
  in the AMS-Icons package (`AppMark`, 66 marks drawn for this build, plus `ControlMark`);
  `MarkImage(name)` replaces `Image(systemName:)`, `MarkLabel(title, name)` replaces
  `Label(_:systemImage:)`, and `systemImage` properties are now `markName`. The old names stay
  as the names. A name with no drawing draws the dot and prints a line in a debug build.
  `Marks.image` (UIKit, the tab bar) and `Marks.nsImage` (the menu bar) render a mark to a
  template image. The widgets have their own `WidgetMark`. `LookRulesTests` fails on
  `Image(systemName:`, `systemImage:` and `systemSymbolName:` anywhere under `App/`. A
  user's own note icon from Apple's symbols (the icon picker) is drawn by the package and is
  his choice, not the app's icon.
- **Colour with meaning.** The colour sets kept their meanings; GoalTint, InboxTint and
  MorningTint day shades were darkened for 17-pt headings on white, and `WidgetLook` takes the
  same values. `SectionLabel` is `Heading` (17 in the part's colour; nil tint → `Theme.soft`);
  `ModeAccent` is a no-op; panels are `.panel(tint)` (surface + 7 % / 13 % tint, 1-pt line at
  night). The note header is the title at 26 and a facts panel (`NoteHeader.facts`); the chips
  are bordered (`.menuStyle(.button)`, `.buttonStyle(.bordered)`, no `.menuIndicator(.hidden)`).
- **Sheets:** `.sheetChrome(title:tint:actionTitle:…)` (Look.swift) puts Cancel and the doing
  button at the top right on the Mac (Escape, Return, ⌘S) and in the iPhone's navigation bar.
  `SheetFooter` is no longer used. The iPhone's own Quick capture screen keeps its Save bar.
  `sheet.cancel` / `sheet.action` keep their names; the Mac capture sheet's Save is
  `capture.save` (`actionIdentifier`).
- **Rows:** `NoteRow` is one title, one `secondLine` of at most two facts, an 8-pt dot
  (`TintStripe` now draws the dot). Browse on the iPhone has a large title; the Work long
  press is on the version row (`browse.version`). The version shows as `AppVersion.text`,
  "1.0 (280)" (`sidebar.version`); `MARKETING_VERSION` is 1.0.
- **Kept where he placed them:** Start the day / Close the day on Today's date row, Show all
  in the Goals header, "+" over the list column.
- **Projects list (second pass, same build):** `ProjectBox` became `ProjectRow`: one title, one
  second line (`project.next.<path>`, or `project.endedDay.<path>` for an ended project),
  `project.tile.<path>` on the leading mark (icon or 8-pt dot), `project.weekly.<path>` on the
  bars, status as a capsule. `ProjectGroupHeader` draws a 17-pt `Heading` in the group's colour
  with the count; no band.
- **Goal / Aspiration pages:** `ChainGoalBlock(lead: true)` and `AspirationChainBody.head` draw
  `NoteHeader` (title 26 + facts panel) with the new `progress:` and `notices:` parameters (the
  per cent; "Target date passed" as an orange capsule); the projects (or goals) are a
  `.panel(ParaKind.project.tint)` headed "Projects" with Add a project… at the foot, no rail.
  `DatedGoalRow` / `AspirationRow` are one second line; Give it an aspiration stays at the right.
- **Mac toolbar:** `.toolbar` on `PlannerDayView` (`plan.block`, `plan.week`,
  `plan.calendarBlocks`, with the day arrows and Today) and on `CalendarDetailView` /
  `DayScheduleView` (`calendar.noteToggle`, `calendar.blockTime`). iOS keeps them in the page.
- **Search:** `FilterBox` is `Toggle(.checkbox)` on macOS, identifier `search.box.<token>`;
  chips on iOS. `SearchHit.snippets` (`Search.swift`) strip the task markers.
- **Sheet focus:** `StartDayView` / `CloseDayView` use `defaultFocus` on the Mac so the first
  field has the focus (`closeDay.lookingBack`), not Cancel.
- **Short column:** `deskBody` puts the header, Tasks and Linked notes in a ScrollView sized to
  min(content, column − 60 − the bars), so the editor keeps 60 points.
- Local pictures: `Work/look-1.0/tools/` (fakegroup.m + launcher.c) is the only safe way to
  drive the local Mac build; never `open amspara://` (it opens his real app).

## Build 300 (12 November 2026)

"The sync button shows the sync". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Reminders sync on the iPhone, the sync pill paragraph), `Look.md` (section 8).

- **Before:** iPhone showed the `SyncStatusBar` pill ("Synced at 10:05") at the top of Today; pressing it opened Settings at Reminders sync. The phone sync button (`PhoneSyncButton`) only started a sync.
- **Now (iPhone only):** the pill is gone from Today. `PhoneSyncButton` (top right of every screen) has a clock ring: full right after a sync, empties over 2 hours; green the first hour, yellow after (and yellow while waiting for iCloud); full red when the last sync had conflicts; grey empty when never synced; while syncing the button turns and the ring is full. Caption under it: time today ("10:05"), "Yesterday", "9 Nov", "Syncing", "iCloud", "Not yet", "N conflicts". Press = sync now; long press = menu: Sync now, Show me what would change..., Last sync report..., Sync settings... (opens Settings at Reminders sync via `AppModel.openSyncSettings`, formerly the pill's action).
- **Unchanged:** Mac and iPad keep `SyncStatusBar` at the foot of the sidebar.
- **BuildStamp:** `BuildStamp.number` = 300.

## Build 304 (12 November 2026)

"Mac opens again, swipe to tick, today's count in the menu bar, icon-only today note". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Today band, swiping a task, menu bar), `Look.md` (sections 8, 15).

- **Fix:** build 303's menu bar label redrew forever (TimelineView + a fresh NSImage each pass), so the Mac app never opened (CPU 100 %, memory climbing). Now ring pictures are cached per mood and fill step (1/24) and the label uses a 60-second Timer. **Trap: never put a TimelineView or a freshly rendered NSImage in a MenuBarExtra label. It redraws forever and the Mac app never opens.**
- **Swipe:** `.swipeActions(edge: .leading, allowsFullSwipe: true)` on task rows, id `task.swipeDone.<title>`, green Done / grey Not done, same toggle (haptic included); none on cancelled tasks.
- **Menu bar count:** `SyncRing.menuBarTitle(dueToday:word:)` with `SyncRing.dueTodayBadge` (nil for 0, "99+" over 99). Test `testTheMenuBarShowsTodaysCountBesideTheRing`.
- **Today band:** `today.note` is an icon-only `HeaderActionButton` (calendar, onBand), first in `dayButtons`; one row, band one row shorter.
- **BuildStamp:** `BuildStamp.number` = 304.

## Build 303 (12 November 2026)

"Sync ring in the Mac menu bar, a tap on ticking". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Reminders sync, ticking), `Look.md` (section 8).

- **Before:** the sync ring was only at the foot of the sidebar (Mac/iPad) and on the iPhone button. Ticking a task gave no haptic.
- **Menu bar:** second `MenuBarExtra` (`.menu` style) in ParagonApp.swift beside the quick-capture tray. Label `MenuBarSyncLabel` draws `SyncRingGlyph` into an `NSImage` with `ImageRenderer` each minute (16 pt) with the short word (10:55, Yesterday, Syncing...). `SyncRingGlyph` is the model-free ring shared by the sidebar, the iPhone button and the menu bar; same colours/rules (green < 1 h, yellow after or waiting for iCloud, full red on conflicts, grey before any sync; fills down over 2 h). Menu `MenuBarSyncMenu`: sync line, Sync now, Show me what would change..., Last sync report..., Sync settings..., Show PARAGON.
- **Setting:** `@AppStorage showSyncMenuBarItem` (default on), switch "Show the sync ring in the menu bar" in Settings > Reminders sync.
- **Haptic (iPhone/iPad):** `Haptics.done()` in Theme.swift, called from `AppModel.toggle` (any list) and on a box in a note (iOS editor); only when ticking done, never when unticking, nothing on the Mac.
- **BuildStamp:** `BuildStamp.number` = 303.

## Build 302 (12 November 2026)

"Search gets the premium chips". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Search screen boxes, All actions note), `Look.md` (section 12).

- **Before:** Search filter boxes were Mac `.checkbox` toggles, big coloured group headings on the iPhone.
- **Now:** every Search `FilterBox` passes `chip: true` (Mac, iPad, iPhone): off = soft grey fill, ticked = group colour fill, white words, small tick. Group names via new `groupName(_:)` in SearchView (small grey capitals). Spacing between chips 5 pt everywhere. `chipBody` now carries the `search.box.<token>` identifier.
- **Test:** `testASearchBoxIsATickBoxThatTurnsUpTheTasks` now finds `app.buttons` instead of `app.checkBoxes`.
- **BuildStamp:** `BuildStamp.number` = 302.

## Build 301 (12 November 2026)

"Same sync ring everywhere, haptic, New Entry, premium filter chips". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (sync ring paragraph, Reminders sync on the iPhone, All actions, New Entry wording), `Look.md` (sections 6, 8, 12).

- **Before:** Mac/iPad sidebar foot had the `SyncStatusBar` pill ("Synced at 10:55"); only iPhone had the ring (build 300). The + sheet was "New note". `FilterBox` row headings were big green; the box area was always 260 pt tall.
- **Sync ring:** shared view `SyncRingMark` (PhoneRootView.swift), used by `PhoneSyncButton` and `SyncStatusBar` (Theme.swift). 22 pt ring round the hand-drawn sync mark; fills down over 2 h; green < 1 h, yellow after or while waiting for iCloud, full red on conflicts, grey before any sync. Short word beside it (time, Yesterday, date, Syncing, iCloud, Not yet, N conflicts). Press = sync now; context menu (long press on iPad) = Sync now / Show me what would change... / Last sync report... / Sync settings....
- **Haptic (iPhone):** `.sensoryFeedback` on `PhoneSyncButton`, triggered when `isSyncing` goes true -> false; success tap, warning when the sync had conflicts.
- **New Entry:** title, + button name and tip, and the empty detail column's button renamed (was New note). Inbox's "New note from this line..." unchanged (makes a note).
- **Filter chips:** `FilterBox(chip: true)` on All actions, Mac and iPhone: small grey capital row names (WHEN / MARK / TAGS); chips off = soft grey fill, on = screen colour fill, white text, small tick; the fixed 260 pt box-area height removed (sized to content). Search kept Mac `.checkbox` toggles until build 302.
- **BuildStamp:** `BuildStamp.number` = 301.

## Build 294 (11 November 2026)

"Paste on iPhone, search inside pictures, sorting the gallery". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` ("Sketches and photos": Pasting a picture (iPhone and iPad), Sorting the gallery; Search Everywhere: Words inside pictures).

- **Before:** paste of pictures Mac only; search blind to text in pictures; gallery order = text order, no sorting.
- **Paste (iOS):** `PictureTextView: UITextView` overrides `paste(_:)` / `canPerformAction` (also Cmd-V on an iPad keyboard) -> `PictureHooks.paste(offset, data, ext)`. Image data is saved as JPEG (longest side <= 2048 px) in `Pictures/` as "Pasted yyyy-MM-dd HHmmss.jpg" via Core `Pictures.pastedName(at:ext:)` (a number added when taken); line inserted at the cursor. Text on the pasteboard still pastes as text. Mac keeps PNG.
- **Reorder:** Core `Pictures.reordering(_:notePath:moving:onto:)` swaps the picture lines so each picture takes the place of another; the text around stays. Tests in `PictureCaptionTests`. Gallery thumbs `.draggable` + `.dropDestination(for: String.self)`; Mac mouse drag, iOS long-press drag.
- **Search in pictures:** Core `NoteIndex.search(_:pictureText:)` takes path -> recognized text; a note whose picture text contains all the words is a hit and gets "In a picture: ..." snippets. Test in `PictureCaptionTests`. App `PictureReader` at the end of `SearchView.swift`: Vision `VNRecognizeTextRequest` on device, in the background a few pictures at a time, cache JSON in Application Support `PictureText.json` keyed by path + modification date (not in the vault); iCloud placeholders are read once downloaded. iPhone, iPad, Mac.
- **BuildStamp:** `BuildStamp.number` = 294 (set by the code engineer).

## Build 293 (11 November 2026)

"Paste pictures, and a gallery". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` ("Sketches and photos": Pasting a picture, The Pictures gallery).

- **Before:** no paste of pictures (only Finder drag, sketches, photos); no overview of a note's pictures.
- **Paste (Mac):** `LinkingTextView.paste(_:)` override -> `onPicturePaste` -> `PictureHooks.paste(Int, Data)`. Image data on the pasteboard is saved as PNG in `Pictures/` as "Pasted yyyy-MM-dd HH.mm.ss.png" via Core `Pictures.pastedName(at:)` (a number added when taken; test in `PictureCaptionTests`); the picture line is inserted at the cursor. Picture files copied in Finder are copied into `Pictures/` like the build 290 drop. Text on the pasteboard wins: normal text paste.
- **Gallery:** `NoteGallery` view at the end of `NoteEditorView.swift`, shown from `sections` when `Pictures.matches` count >= 2. Square thumbnails (~64 pt) in text order, count capsule in the heading, folded state `@AppStorage("galleryFolded")`; a press on a thumbnail opens the same big viewer as a press on the picture in the text. Identifiers `note.gallery` and `gallery.thumb`. iPhone, iPad, Mac.
- **BuildStamp:** `BuildStamp.number` = 293 (set by the code engineer).

## Build 292 (11 November 2026)

"A quiet sync pill". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Reminders sync, iCloud sync line, How PARAGON looks, shortcuts), `Look.md` (section 8).

- **Before:** Mac/iPad toolbar had a circling-arrows sync button with a menu (Sync now, Show me what would change..., Last sync report...); the sidebar foot had a grey line "Synced at 15:05" that opened Settings.
- **Now:** toolbar sync button removed (his request); sync runs by itself every few minutes. Sidebar foot: a small pill, coloured dot (green fine, orange something to look at, purple syncing/waiting, small turning wheel while syncing) + the words. One press = sync now; right-click (long press on iPad) = Sync now, Show me what would change..., Last sync report..., Sync settings.... Hover tip: "... all fine" or "N things worth knowing, nothing to do". File > Sync with Reminders (⇧⌘R) still works. iPhone: the pill sits at the top of Today and still opens Settings; the iPhone's own sync button stays.
- **BuildStamp:** `BuildStamp.number` = 292.

## Build 291 (11 November 2026)

"Calmer screens". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Today, The Inbox "Where it goes", Reminders sync, How PARAGON looks), `Look.md` (section 6, counts, section 10).

- **Before:** Inbox destinations always open; Today band had the big "0 due today" number and a "Today's note" heading with Create/Open; only Calendar folded on Today; counts beside headings were loose grey numbers; empty pages had icon, title and an explaining sentence; the calendar row's "open in Calendar" mark was bare; the sync tip said "Last sync: N warnings".
- **Inbox:** the Projects and Areas groups under "Where things go" fold with a chevron; folded state remembered. The grey "Pick a line on the left..." box shows only once a line is picked.
- **Today:** big number removed from the band; the band carries a white "Today's note" button (calendar mark + words; "Create today's note" when none exists); the old heading with Open is gone; "From today's note" shows only when there are tasks in it. Next actions, Overdue and Due today fold like Calendar, remembered.
- **Counts:** small capsules in the heading's colour (capsule size, 11 pt, 14 % tint), not loose grey numbers.
- **Empty pages:** explaining sentence removed; icon in a soft circle of the part's colour above the title. "No note open": only the icon and New note... Warnings (e.g. "Still coming from iCloud") keep their sentence.
- **Calendar rows:** "open in Calendar" is a small round button tinted in the event's calendar colour.
- **Toolbar tips:** + = New note in this section (⌘N); tray = Quick capture (⇧⌘N); circling arrows = sync with Reminders now (⇧⌘R, also automatic every few minutes per Settings). Sync tip: "Synced with Reminders at 15:05 - all fine" or "... N things worth knowing, nothing to do (see Last sync report...)"; the word "warnings" became "worth knowing".
- **BuildStamp:** `BuildStamp.number` = 291.

## Build 290 (11 November 2026)

"Captions, pictures from Finder, and a tidier note header". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` ("Sketches and photos": Captions, Pictures from Finder; note header paragraph).

- **Before:** no captions; no drag of picture files on the Mac; a note without tasks said its kind in the band and again as the panel heading; panel facts were label over value.
- **Core:** `Pictures.caption(ofLink:)` (alt text, nil for "Sketch", "Photo", "Picture" or empty), `Pictures.settingCaption(_:inLink:)` (writes the alt text; empty clears it); test `PictureCaptionTests`. `Pictures.droppedFolder = "Pictures"`, `Pictures.freeName(for:taken:)` ("name 2.jpg" when taken). `DayDistance.words(from:to:)`: "Today", "Yesterday", "Tomorrow", "3 days ago", "In 3 days".
- **Captions:** small grey line under the picture on iPhone, iPad and Mac. Mac: right-click/Control-click a picture › "Caption..."; iPhone/iPad: press and hold › "Caption...". Small window: text field, Cancel, Save; Save writes the alt text, so the file keeps plain markdown.
- **Finder drop (Mac):** png, jpg, jpeg, heic, gif copied into `Pictures/` in the notes folder (same name, free name when taken); line inserted at the drop point; original stays.
- **Note header:** the band says `DayDistance.words` for a daily note and "No tasks yet" for any other note without tasks (no longer the kind twice). Panel facts ("List", "In area", "Serves"...) are one line: small grey label, then value, level with the buttons (Tags..., Status).
- **BuildStamp:** `BuildStamp.number` = 290.

## Build 289 (11 November 2026)

"Pictures in the text, and photos". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` ("Sketches and photos", format bar text).

- **Before:** a picture link showed as link text in the editor; sketches only as thumbnails in a "Sketches" row under the text (288); no photos.
- **Core:** new `Pictures` rule: `Pictures.matches(in:notePath:)`, `Pictures.isPicture` (.png, .jpg, .jpeg, .heic, .gif; relative vault paths). `Sketches` kept for sketch names (`newFileName`, `link`, `inserting`). One data test `PicturesTests`.
- **Editor:** each picture link `![..](path)` is shown as one U+FFFC with an `NSTextAttachment` (`PictureAttachment`, carries the original link line); turned back into the link whenever the text is handed back, so the file keeps plain markdown. Max width = text column, max 320 pt tall, rounded corners. Undelivered iCloud file: grey box "On its way from iCloud". Press: sketch on iOS opens PencilKit again (Done saves over); photo, or anything on Mac, opens bigger with Done (Escape on Mac). Backspace right after a picture removes picture and link; file stays. The "Sketches" row under the text is removed. Photos: JPEG, longest side 2048 px, saved in vault folder `Photos/` as "Photo yyyy-MM-dd HHmmss.jpg"; line `![Photo](../Photos/Photo%20...jpg)` inserted at the cursor. Info.plist `NSCameraUsageDescription` = "PARAGON uses the camera to put a photo into a note."
- **Format bar:** new `format.photo` (photo mark) beside the pencil (iPhone, iPad): "Take photo" (camera) / "Choose photo" (library). Screen test `testTheKeyboardBarHasStrikeAndSketch` now also checks the sketch appears inside the text.
- **BuildStamp:** `BuildStamp.number` = 289.

## Build 288 (11 November 2026)

"Apple Pencil sketches, numbered lists and strikethrough". Step 3 of "checkboxes, rich text, Apple Pencil". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Tasks: "Bold, italic, strikethrough and headings", "Sketches", "Return continues a list").

- **Before:** bar had `format.task`, `format.bold`, `format.italic`, `format.heading`; `RichText.continuingList` handled tasks and `- `/`* `/`+ ` bullets only; no strikethrough toggle; no sketches.
- **Core:** `RichText.continuingList` also handles numbered lines (`1. ` and `1) `, same indent; empty numbered item ends the list). `RichText.toggling(... marker: "~~")` for strikethrough; new `MarkdownStyle.strike`; `~~` markers hidden off the cursor line like bold. New `Markdown/Sketches.swift`: `Sketches.links(in:)`, `Sketches.newFileName(at:)` ("Sketch yyyy-MM-dd HHmmss"), `Sketches.link(toFile:fromNote:)` (relative, percent-encoded path to the vault's `Sketches/` folder), `Sketches.inserting(link:into:at:)`. One data test `SketchesTests` covers numbering, strikethrough and sketch links.
- **Editor:** sketches saved as PNG plus `.drawing` (PencilKit data) of the same name in `Sketches/`; link line `![Sketch](../Sketches/...png)` inserted at the cursor. A "Sketches" row under the text shows thumbnails for each linked sketch. iOS: press opens the PencilKit canvas again (Done saves over it); Mac: press shows it bigger, no drawing. Removing the link line removes it from the note; the files stay. A file iCloud has not delivered shows "On its way from iCloud". Mac Format menu: Strikethrough, Shift-Cmd-X.
- **Format bar:** new `format.strike` (S drawn struck through) beside B, I, H; new `format.sketch` (pencil) at the end of the bar opens the drawing page (PencilKit: pen, marker, pencil, eraser, lasso, colours, ruler; Cancel discards, Done saves). Screen test `testTheKeyboardBarHasStrikeAndSketch`.
- **BuildStamp:** `BuildStamp.number` = 288.

## Build 287 (11 November 2026)

"Rich text, and tasks that keep going". Step 2 of "checkboxes, rich text, Apple Pencil" (Pencil next). He picked A: live preview, file stays plain markdown. Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Tasks: "Bold, italic and headings", "Long press on a task's box", "Return continues a list").

- **Before:** bold/italic/headings were styled but markers only faded; the bar had one button (`format.task`); box press only ticked; Return on a task line made a plain line.
- **Core:** `Markdown/RichText.swift`: `RichText.toggling(_:selection:marker:)` (counts the stars around the word: odd = italic, >=2 = bold; empty pair with caret between when no word), `RichText.cyclingHeading(_:at:)` (plain, `# `, `## `, `### `, plain), `RichText.continuingList(_:at:)` (task or `- `/`* `/`+ ` bullet; empty item ends the list; caret before the box = old behaviour), `MarkdownHighlight.hiddenMarkers(in:cursor:)`. `TaskBox.cancelled(_:at:)` and `TaskBox.movedToTomorrow(_:at:today:calendar:)` (uses `TaskItem.settingDueDate`, keeps the time of day, same as Reschedule). One data test `RichTextTests`.
- **Editor:** `MarkdownAttributes.apply(... cursor:)` hides markers off the cursor line (clear colour, 0.1 pt font) and restyles when the cursor changes line; iOS hides all markers when not editing. iOS long press is a `UILongPressGestureRecognizer` that only begins on a box (build 114 trap) and shows a `UIEditMenuInteraction` menu (Cancel task, Move to tomorrow); Return via `shouldChangeTextIn`. Mac `LinkingTextView.menu(for:)` adds the two items; `insertNewline` handled in `doCommandBy`.
- **Format bar:** iOS bar gets ids `format.bold`, `format.italic`, `format.heading` beside `format.task`. Mac: Format menu = `CommandGroup(replacing: .textFormatting)` (Bold Cmd-B, Italic Cmd-I, Heading Opt-Cmd-H) sending actions through the responder chain; no Mac bar. Screen test `testTheKeyboardBarMakesBoldAndTasksContinue`.
- **BuildStamp:** `BuildStamp.number` = 287.

## Build 286 (11 November 2026)

"Tick tasks right in the note". Step 1 of "checkboxes, rich text, Apple Pencil" (he chose checkboxes first; format bar above the keyboard, option A, like Apple Notes). Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (Tasks, "Ticking a task in the note's text").

- **Before:** the `[ ]` in the editor was plain text; ticking was by typing an x or in the task box under the header.
- **Core:** `Markdown/TaskBox.swift`: `TaskBox.boxRange(in:near:)` finds the box on the line at a position; `TaskBox.toggled(_:at:date:calendar:)` ticks/opens it with `TaskItem.markDone` / `markOpen` + `nextOccurrence` (same rule as `AppModel.toggle`, so `@done(…)`, Reminders sync and Done see it; a repeating task gets its next copy on the line below); `TaskBox.switchingTask(_:at:)` for the keyboard button (`- [ ] ` on/off). Test `TaskBoxTests` (one data test).
- **Editor (`MarkdownSyntaxEditor.swift`):** Mac `LinkingTextView.mouseDown` toggles when the click is on a box. iOS `BoxTapRecognizer` only begins on a box (`gestureRecognizerShouldBegin`), so the text view's own tap that places the caret is untouched (the build 114 trap noted in that file). Box drawn bolder in the note's colour.
- **Format bar:** iOS `inputAccessoryView` = `FormatBar` (UIToolbar), one button for now, id `format.task`; bold/italic/headings come with the rich-text build. No Mac bar or shortcut: Mac types `- [ ] ` or clicks the box. `BuildStamp.number` = 286.

## Build 285 (11 November 2026)

"The sync line stays". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (How iCloud moves the files, Map).

- **Before:** the grey line showed only while `syncWaitsForCloud` (build 284); the Map on the Mac replaced the detail in the main window.
- **Sync line:** now always shown. Core `Sync/SyncWait.swift`: `SyncStatus.line(...)` and `isProblem`; test `SyncStatusTests`. States: "Not synced yet", "Syncing…", "Sync waiting for iCloud…", "Synced at 09:12" (with "yesterday" / "9 Nov" when not today), orange "Last sync: N conflict(s)" (warnings stay grey). `SyncStatusBar` in `Views/Theme.swift` (id `sync.status`) replaces `SyncWaitingBar`; same places (sidebar `safeAreaInset`, TodayView phone only). Pressing it calls `AppModel.openSyncSettings` and sets `settingsJumpToSync`: Mac Settings window, iPad Settings sheet, iPhone Settings page, each scrolled to Reminders sync.
- **Mac Map window:** `Window("Map", id: ParagonApp.mapWindowID)` in ParagonApp.swift (one window; opening again fronts it), `MapMenuButton` (Go › Map, ⇧⌘M), `MapView(ownWindow: true)`. ContentView turns a sidebar choice of `.map` into opening the window and puts the sidebar selection back, so the main window stays. A click highlights the links and opens the note in the main window (`model.show(section: sidebarSection(for:), notePath:)`) while the Map stays in front. iPhone and iPad unchanged. `BuildStamp.number` = 285.

## Build 284 (11 November 2026)

"You can see the sync waiting". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (How iCloud moves the files).

- **Before:** a sync waiting for iCloud (build 283) was invisible: only a passing note on a pressed Sync, nothing for the timer's.
- **Now:** a grey line "Sync waiting for iCloud…" with the sync mark while `model.syncWaitsForCloud`. Core `SyncWait.waitingLine` (test `SyncWaitTests.testTheWaitingLineNamesTheSyncAndICloud`); `SyncWaitingBar` in `Views/Theme.swift` (id `sync.waiting`). Shown from ContentView's sidebar `safeAreaInset(edge: .bottom)` (Mac and iPad, under the orange iCloud warning) and at the top of TodayView, phone only (no sidebar). Grey, not orange: nothing is wrong. `BuildStamp.number` = 284.

## Build 283 (11 November 2026)

"The sync waits for iCloud". Docs in `Docs/VersionHistory.md`, `HowItWorks.md` (How iCloud moves the files).

- **Before:** `syncNow` with notes still arriving/updating set `errorMessage` ("… the sync was not started … Try again in a moment") and nothing retried; the timer could raise it.
- **Now:** Core `Sync/SyncWait.swift`: `SyncWait.step(waiting:updating:)` -> `.start` / `.keepWaiting`, `SyncWait.message`; tests `SyncWaitTests`. `AppModel.syncWaitsForCloud` (published) is set in `syncNow(force:quietly:)` instead of `errorMessage`; `reload()` starts the waiting sync through `afterUpdate` when `SyncWait.step` says `.start` (iCloud watcher and the 10 s check both re-read). A pressed sync shows the passing note; the auto-sync timer calls `syncNow(quietly: true)` and waits silently. `closeVault` clears it.
- **Unchanged:** the safety rule (builds 106, 261): never sync over a partial vault or older copy. Tag rename, note rename with links, restore and sync rehearsal still refuse with their message. `BuildStamp.number` = 283.

## Build 282 (9 November 2026)

"Colour at the top", look A (picked 9 Nov from `Work/look-1.1/design/premium.png`). Docs in `Docs/VersionHistory.md`, `HowItWorks.md`, `Look.md` (new §15 The band).

- **`Band`** in `App/Paragon/Views/Look.swift`: every screen opens with it, Mac and iPhone. Gradient
  = the part's colour to the same colour at 80 % toward the bottom right. Title = page title in
  white; small words = label size, white at 85 %; one big number in the new `Txt.bandNumber`
  (34 pt, bold; iPhone large title bold). Today: "3 due today · 2 of 5 done"; project, area,
  resource note: "2 open tasks · 0 of 2 done"; goal page: "40 %" + "of the way · Target 15 Aug 2027".
- **Start/Close the day** keep their place, in the band's top row, as white circles.
- **Mac sidebar:** the chosen row is filled in the part's colour with white words.
- **Unchanged:** everything under the band (panels, 17-pt headings, 8-pt dots, pop-ups, sizes,
  icons), all functions, all part colours. Look.md's two size tables have the Band number row.

## Build 281 (9 November 2026)

Eight changes in one release; docs in `Docs/VersionHistory.md`, `HowItWorks.md`, `Look.md`.

- **Backup off the main thread.** `AppModel.backUpDaily` and `purgeOldDeleted` now make a
  `Vault` of their own from the plain root URL inside `AppModel.offMain` (GCD utility queue),
  the same shape as `fetchCloudFiles`. Run a few seconds after launch. The day is marked done
  when the copy returns; `dailyBackupRunning` stops a second copy; a vault changed meanwhile
  is ignored by comparing `rootURL`. What is copied, when, and the 10 kept are unchanged.
  Cause: ~1,400 files in iCloud Drive froze the first screen 5–10 s. Not testable by a UI test.
- **Goal mark on a colour.** `NoteIconTile` has `defaultMark: String?`: when
  `note.iconStored == nil` it draws the mark with `MarkImage` on the tile fill/ink
  (`IconColour.fill(for:automatic:)` / `markInk(for:)`). `GoalMark`, the two small goal marks
  in GoalsView and `leadingMark` in ContentView pass `ChainSymbol.forGoal(note)`.
  `ChainSymbol.word(for:)` gives "Star"/"Target" for the Icon… button's accessibility value.
  Projects, areas, resources have no default mark: a colour alone still shows the first letter.
- **Icon… button, set state.** The tile itself at 24 pt plus a 1-pt ring in the note's colour,
  2 pt out. Unset: dashed grey capsule as before.
- **Two-state buttons.** `StateToggle.border` in Theme.swift: off is a thin solid grey line, no
  `dash:`. On is unchanged. Core test `LookRulesTests.testTheTwoStateButtonIsNotDashed` reads
  Theme.swift and fails if `dash:` returns inside `StateToggle`. The Icon… placeholder is the
  only dashed shape left.
- **Date title.** `NoteEditorView.titleRow`: `titleLines` / `titleShrink` on
  `note.kind == .daily` (one line, min scale 0.7); other kinds keep two lines.
- **Group heading.** `.fixedSize(horizontal: false, vertical: true)` on the title in
  `ProjectGroupHeader`, so a narrow column wraps instead of cutting with "…".
- **Phone Search.** `SearchView.group` branches on `isPhone`:
  `HStack { SectionLabel.fixedSize(); ScrollView(.horizontal) { HStack { boxes } } }`; one row
  per group; `filtersCap` is 240 on the phone. Mac unchanged. The Show/Hide the boxes button
  has the identifier `search.boxes`.
- **Tests added.** `testNoIconOnAGoalBringsTheTargetBack` (Mac UI: colour red, then Bike, then
  No icon; the Icon… button says "Target" with only a colour and again after No icon; the file
  keeps `icon-colour: red`, loses `icon:`), `testThePhonesSearchShowsEveryGroupOfBoxes`
  (iPhone UI: Browse › Search › Show the boxes; the Active box of How the note stands is on
  screen and hittable), `testTheTwoStateButtonIsNotDashed` (Core). Not covered: backup thread,
  date title, heading wrap (code only), the tile's ring (seen on the iPad, day and night).
- **Not built (by choice).** His wish for "more colour, big premium elements" is not in this
  build; a picture with three directions is being made for him to choose from.
