# The look of PARAGON

Decided on 6 November 2026 with look B, "coloured panels with meaning". Built in build 280 (version 1.0 (280)); small changes in build 281 (version 1.0 (281)); the colour band at the top of every screen in build 282 (version 1.0 (291), look A, section 15); calmer screens in build 291 (version 1.0 (291), sections 6 and 10); the quiet sync pill in build 292 (version 1.0 (292), section 8); the sync button's clock ring on the iPhone in build 300 (version 1.0 (300), section 8); the same ring on the Mac and iPad sidebar and the small filter chips in build 301 (version 1.0 (301), sections 8 and 12); the same chips in Search in build 302 (version 1.0 (302), section 12); the sync ring in the Mac menu bar in build 303 (version 1.0 (303), section 8). Every function stays as it is; this document is only about how PARAGON looks and feels. Read it before you change any screen.

The look follows the one in the Subscriptions app (version 1.0): one place for text sizes, one place for part colours, one heading, one main button, one panel. The code is in `App/Paragon/Views/Look.swift` (the scale `Txt`, `Heading`, `Pill`, `PanelStyle`, `SheetChrome`, `AppVersion`) and `Marks.swift` (the icons).

## 1. Text sizes

There is one scale, kept in one place in the code (`Txt` in Look.swift). No screen picks its own size. A rule test in Core (`LookRulesTests`) reads the sources and fails on any text size named outside the scale.

### Mac

| Name | Points | Weight | Colour | Used for |
|------|--------|--------|--------|----------|
| Band number | 34 | bold | white | The one big number in a band (section 15). `Txt.bandNumber`. |
| Page title | 26 | bold | black by day, white at night | The open note's title and the title of a screen that fills a column. |
| Section heading | 17 | semibold | the colour of the part | Every heading (`SectionLabel`, `Heading`) and the title in an edit window's bar. |
| Value | 15 | regular | black or white | Note text, facts, fields, and the words in panels. |
| Label | 12 | regular | soft grey | The small word above a value, footers. (Counts in headings are capsules since build 291.) |
| List | 13 | regular | black or white | Sidebar rows, menus, pop-ups. |
| List title | 13 | semibold | black or white | The title of a row. |
| List second line | 11 | regular | grey | The one second line of a row, numbers, badges. |
| Button | 13 | semibold | white on the part's colour | The main button. |
| Code | 14 | regular, monospaced | grey | Code, and the settings block. |
| Capsule | 11 | medium | the part's colour on a 14 % tint | A status, or a count beside a heading (since build 291), that cannot be changed. |

The Map draws its box titles at 12.5 points and its labels at 11 points at normal zoom, and scales them with its zoom. The widgets keep Apple's small widget styles. The share sheet uses Apple's text styles.

### The note editor on the Mac

Edit and Read use the same numbers (`Txt.Editor`), so the note does not move when you switch.

| Element | Points |
|---------|--------|
| Text | 15, with 6 points between lines and 8 points between paragraphs |
| Heading with # | 22, semibold |
| Heading with ## | 18, semibold |
| Heading with ### | 15, semibold |
| Code and the settings block | 14, Apple's monospaced font |

### iPhone

The iPhone uses only Apple's own text styles, so the text grows and shrinks with the text size set on the iPhone.

| Mac name | iPhone style | Normal size in points |
|----------|--------------|-----------------------|
| Band number | Large title, bold | 34 |
| Page title | Large title, bold. It shrinks to a small title when you scroll. | 34, then 17 |
| Section heading | Headline | 17 |
| Value, List | Body | 17 |
| Label, second line | Footnote | 13 |
| Capsule | Caption, medium | 12 |
| Editor text | Body, 5 points between lines | 17 |
| Editor headings #, ##, ### | Title 2, Title 3, Headline; semibold | 22, 20, 17 |
| Editor code | Callout | 16 |

## 2. Colour

Every part has one colour. It is the same everywhere the part shows: the icon in the sidebar, the section heading, the main button, the dot in a list, the tint of a panel, and the links in a note of that part. Each colour has a day shade and a night shade, kept in the colour sets of the app. Widgets use the same values.

| Part | Colour | Day | Night |
|------|--------|-----|-------|
| Projects, All actions | green | #2E7D5B | #5FBF92 |
| Areas, Tags | pink | #C2417C | #F07FB2 |
| Resources, Recent, Templates, Search | blue | #2C6FB5 | #6FAEE8 |
| Archive, Deleted, Work | grey | #6E6E73 | #9A9AA2 |
| Goals, Map | gold | #8F6E10 (before #A7811A) | #E5BE55 |
| Aspirations | deeper gold | #8A5A12 | #E0A83E |
| Inbox, Snippets, Quick capture | amber | #B0631A (before #C2701B) | #E8A053 |
| Calendar, Today, Time Blocks, daily and weekly notes | purple | #6B4EA8 | #A98FE0 |
| Weekly review, Done | teal | #1E7F84 | #5FC2C7 |
| Blocks in Plan the day | orange | #C05E0C | #F2A45C |
| Start the day | orange | #D4640A (before #E06C00) | #FFA23A |
| Close the day | dark lilac | #6E3A86 | #C79AE0 |
| The now-line | slate blue | #4B7F9E | #8FC0DC |
| Look at this (`Theme.attention`) | orange | #D4640A | #FFA23A |
| Overdue and danger | red | Apple's red | Apple's red |

The three day shades marked "before" were darkened so that 17-point headings read on white.

Neutral colours (`Theme` in Look.swift):

| Name | Day | Night | Used for |
|------|-----|-------|----------|
| Surface | #FFFFFF | #1E2228 | Panels |
| Soft text | #5C6470 | #A9B1BC | Labels and quiet text |
| Line | #E2E6EB | #2E333A | The night border round a panel |

How a colour is worn:

- Sidebar icon: the part's hand-drawn icon, in the part's colour. The word stays black or white.
- Section heading: 17 points, semibold, in the part's colour.
- Main button: filled in the part's colour. When it cannot act yet it is the same colour, paler (40 % on `MainButtonStyle`). Never grey.
- Mark in a list: a filled dot, 8 points, at the left of the row. When the note has its own icon, that icon is shown instead. There is no stripe.
- Panel: the surface colour with the part's colour laid over it, 7 % by day and 13 % at night. Corners 10 points round, 12 points of room inside. No border by day. A 1-point line at night.
- Links and tags in a note: the colour of the part the note is in.
- Selection in a list is Apple's own.
- The colour wash over the whole note column (`ModeAccent`) is gone. Colour sits on panels, never over the words you read.

## 3. A row in a list

```
[dot, 8 pt, part colour]  Title, 13 pt semibold (Mac) or Body (iPhone), one line      [status capsule]
                          One quiet second line, 11 pt (Mac) or Footnote (iPhone), grey
```

- The height is the height of its words.
- There is at most one second line, for example "0 of 2 · Due in 12 d". It depends on the kind of note: a project shows its progress and what it needs; a goal shows its progress and its target date or horizon; an area shows its open tasks ("3 open"); a resource shows its links ("4 linked"); a daily note shows its date; any other note shows open tasks and a due date. When there is nothing to show, a project shows its area and another note its goal. Everything else is in the facts panel at the top of the note.
- A date that has passed turns the row's second line red; "Due after its goal" turns a project's line orange. All else is grey.
- A status such as Paused, Someday or Ended is a small capsule at the right edge (11 points, the part's colour on a 14 % tint).
- A group heading in a list is the 17-point heading in the colour of what the group is (an aspiration's gold, grey for "No goal"), with the count beside it. No band behind it. In a narrow column (the Projects list is about 280 points) the group's name wraps onto a second line. It is never cut off with "…" (`ProjectGroupHeader`, build 281).
- Every list uses this row, the **Projects** list included. A project's second line is its progress and what it needs: "0 of 2 · Next: Define the outcome and the first step", "All 3 finished · No next action", "No tasks yet", or for an ended project "Ended 20 October · 2 tasks finished". Its weekly bars sit at the right of the row when something has been finished; On hold, Done, Missed and Dropped are the status capsule. No card, no frame, no tile, no progress bar and no chips in a row. The goal, the deadline and the tags are in the facts panel. After that, when there is room: its deadline, an overdue count, "Due after its goal" and the goal it serves when the heading does not already name it.
- The goal rows and the aspiration rows are the same: "0 % · 2027-08-15 · in about 9 months", "1 goal · Not reviewed yet · Health". A goal with no aspiration keeps its **Give it an aspiration** button at the right; a warning is an orange capsule there.

## 4. The top of a note

Since build 282 the top of a note is the band (section 15); what follows is what sits under it. The title is white on the band.

The title is 26 points, bold; pressing it renames the note where that is allowed. A daily or weekly note's title is a date. It keeps one line and shrinks down to 70 % when the column is narrow; every other title wraps to two lines (build 281). Under it is the facts panel, in the note's colour. Its heading is the kind of note, for example "Project", with the note's icon beside it. Inside, the facts sit in a row that wraps. Each is a small grey label (12 points) with its value (15 points) under it: Status, In area (or Part of), Serves, Horizon, Target, Measure, Looked at, Deadline, Tags, List and Icon. Only the ones that fit the kind of note are shown. A fact you can change is a bordered pop-up or button, not coloured words. A fact you cannot change is plain words. Tasks and Linked notes are tinted panels too.

The goal's page in **Goals** and the aspiration's page in **Aspirations** (Mac and iPad) use this same header: the title at 26 points and the facts panel, headed **Goal with a date** or **Aspiration** with the **Icon…** button beside it. Its facts are Status, Serves, Horizon (a labelled pop-up: This year / Long term), Target, Progress (the per cent), Measure, Looked at, Tags and List; only the ones that fit are shown. A notice such as "Target date passed" is a small orange capsule in the panel. Under the panel comes the aspiration's Reason box, then the projects (or the goals) in a panel in the project tint, headed **Projects**, with **Add a project…** at its foot. No rail or stripe beside them.

When the note column is short (Mac), the editor keeps at least 60 points of height and the sections above it, the header, Tasks and Linked notes, scroll instead. The editor never shrinks to nothing.

## 5. Edit windows

This is for New note, Make this note (from a link), Close the day, Start the day, and Quick capture on the Mac. All use one shape, `SheetChrome` in Look.swift.

Mac: a bar at the top with the title (17 points, semibold, in the part's colour) at the left, and **Cancel** and the doing button (**Create**, **Done** or **Save**) side by side at the right, then one thin line, then the form.

- The doing button is filled in the part's colour and has the large control size.
- **Escape** is Cancel. **Return** and **⌘S** do the doing button (the second shortcut sits on a hidden button, because one button carries one shortcut).
- **Tab** moves between text fields as macOS does. The choice chips are buttons, not fields; do not promise that Tab reaches every chip.
- Quick capture inside the New note sheet has no bar of its own; it keeps its one **Save**.
- The first field has the keyboard focus when the sheet opens on the Mac: Start the day's **Add an action for today**, Close the day's **One line, if you feel like it**. The focus ring never starts on Cancel.

iPhone: a navigation bar with the title small in the middle, **Cancel** on the left and the doing button on the right, in the part's colour and bold. The iPhone's own Quick capture screen keeps its full-width **Save** button; that button is the part's colour, paler when it cannot act.

The Date window keeps its field and calendar. **Set** is a filled button.

## 6. Empty screens

Since build 291: the part's icon sits in a soft circle of the part's colour, above one calm title (15 points, grey), and, where there was a button, a quiet bordered one in the part's colour. The explaining sentence is gone. "No note open" shows only the icon and the **New Entry...** button (since build 301; before, **New note...**). A warning (for example "Still coming from iCloud") keeps its sentence. Before build 291 the icon stood alone at 60 % with a line of small grey explanation under the title (`CalmEmptyView`).

Counts beside headings (for example "Calendar 1", "Projects 7") are small capsules in the heading's colour (the capsule size, section 1), not loose grey numbers. A group in a list or on **Today** that can fold shows a chevron by its heading, and the app remembers which are folded. A round button on a row (for example "open in Calendar") is tinted in the row's own colour.

## 7. Icons

- Every icon in the app, the widgets and the share sheet is a hand-drawn mark from the AMS-Icons package, drawn on a grid of 24 points with one line of 1.9 points, round ends and no fill. `Marks.swift` turns a name into a mark (the app); `WidgetMarks.swift` does it for the widgets.
- A new icon is drawn in the same style in the AMS Icon Library (source `TemplateIcons.swift`), and the library is built again.
- No stock icons and no emoji. `LookRulesTests` fails on `systemImage:`, `Image(systemName:)` or an emoji in the source.
- The one exception is a user's own note icon chosen from Apple's symbols in the icon picker. That is his choice, not the app's icon.

## 8. Reading width and the window

- On the Mac the note's header, the panels and the text stop at 680 points (`Theme.readingWidth`) and sit centred in the column. On a wide window the rest is calm margin.
- The sidebar column is at least 180 points wide, normally 200. The list column is 220 to 280 points; the Map list is 420 to 720.
- Window toolbar: Search and Quick capture. Sync is not there since build 292. Since build 301 it is the clock ring at the foot of the sidebar (before, a pill with a coloured dot and "Synced at 15:05"): `SyncRingMark` (in PhoneRootView.swift, shared with the iPhone's `PhoneSyncButton`) is 22 points wide, with the hand-drawn sync mark in the middle; the ring is full just after a sync and empties over 2 hours; green under 1 hour, yellow after that or while waiting for iCloud, full red when the last sync had conflicts, grey empty before any sync; the mark turns while syncing. The short word beside it uses the sidebar's small text size and is the time ("10:55"), "Yesterday", a date, "Syncing", "iCloud", "Not yet" or "N conflicts"; one press syncs, right-click or press and hold has the menu. The iPhone, since build 300, has the same ring on the sync button at the top right of every screen (and since build 301 a soft tap you can feel when a sync ends, a warning buzz after conflicts) (full just after a sync, emptying over two hours, green the first hour then yellow, full red for conflicts, grey empty when never synced) with a small word under it ("10:05", "Yesterday", "9 Nov", "Syncing", "iCloud", "Not yet", "2 conflicts"); press syncs, press and hold has the menu. On the Mac a page's own actions live in the window toolbar too, on two pages: **Time Blocks** (the day arrows with Today, + Block, Week, the calendar-blocks button) and the **Calendar**'s right-hand column (+ Block time, the Note / Schedule switch). The page keeps the day's name and summary. The iPhone and the iPad keep these buttons in the page. The **+** New note button stays over the list column. **Start the day** and **Close the day** stay in Today's date row, and **Show all** stays in the Goals header. They are placed where the owner put them.

- **Menu bar ring (build 303).** A second `MenuBarExtra` (`.menu` style) in the Mac menu bar, beside the quick-capture item. Its label, `MenuBarSyncLabel`, draws `SyncRingGlyph` (the model-free ring shared by the sidebar, the iPhone button and the menu bar) into an `NSImage` with `ImageRenderer`, redrawn every minute: 16 points, hand-drawn sync mark in the middle, same colours and rules as the sidebar ring (green under 1 hour, yellow after that or while waiting for iCloud, full red ring on conflicts, grey empty before any sync; it empties over 2 hours), with the short word beside it ("10:55", "Yesterday", "Syncing…") in the menu bar's own text. The menu, `MenuBarSyncMenu`: the sync line ("Synced at 10:55"), Sync now, Show me what would change…, Last sync report…, Sync settings…, Show PARAGON. Shown unless the switch "Show the sync ring in the menu bar" (Settings › Reminders sync, `@AppStorage showSyncMenuBarItem`, on by default) is off.
- **Menu bar ring, build 304.** The label text is `SyncRing.menuBarTitle(dueToday:word:)`, which puts `SyncRing.dueTodayBadge` in front of the word: nil for 0 (nothing shown), the number up to 99, "99+" over 99, for example "3 · 11:20". Test `testTheMenuBarShowsTodaysCountBesideTheRing`. The ring pictures are cached per mood and fill step (1/24), and the label refreshes with a 60-second `Timer` instead of `TimelineView`: a `TimelineView` (or a freshly rendered `NSImage`) in a `MenuBarExtra` label looped forever and the Mac app never opened in build 303.
- **Swipe to tick, build 304.** Task rows have `.swipeActions(edge: .leading, allowsFullSwipe: true)` with id `task.swipeDone.<title>`: a green "Done" with the hand-drawn `checkmark.circle.fill` mark, or, on a ticked task, a grey "Not done" with the `circle` mark. Both call the same toggle as the circle (so `Haptics.done()` on iPhone and iPad when ticking). Cancelled tasks have none.
- **Swipe to tomorrow, build 305 (iPhone and iPad).** Task rows in `List` rows have `.swipeActions(edge: .trailing, allowsFullSwipe: true)` with accessibility id `task.swipeTomorrow.<title>`. Since build 306 it calls `AppModel.moveTasks([ref], to: DateOnly.today().adding(days: 1), offersUndo: true, message: "Moved to tomorrow.")` (before: `setDueDate` and a plain flash), so the bottom banner carries an Undo button (see Swipe to tomorrow on Inbox lines, build 306). Not shown when the task is done or cancelled. Only in `List` rows (not in other layouts). The time of day and the repeat rule are kept by `setDueDate`. The Mac right-click date options are unchanged.
- **Swipe to tomorrow on Inbox lines, build 306.** Inbox lines have `.swipeActions(edge: .trailing, allowsFullSwipe: true)` with accessibility id `inbox.swipeTomorrow.<title>`: a "Tomorrow" button with the hand-drawn sunrise mark (the same mark as the Tomorrow button and the sunrise over Overdue), tinted with the evening colour (the same tint as `task.swipeTomorrow.<title>`). A full swipe runs it at once. Shown only on open lines (not ticked, not cancelled). It keeps the line's time of day.
- **Undo after a swipe to tomorrow, build 306.** `AppModel.moveTasks(_:to:offersUndo:message:)` gained an optional `message`; both swipes (`task.swipeTomorrow.<title>` and `inbox.swipeTomorrow.<title>`) call it with `offersUndo: true` and message "Moved to tomorrow.". The bottom flash banner shows the message with the Undo button, id `flash.undo`, the same Undo the Overdue "Move to today/tomorrow" buttons have used since build 277 (about eight seconds). Undo restores the task's old date, or no date if it had none; the time of day is never changed by the move, so Undo does not touch it. Undo writes back only if the task still has the date the swipe gave it (the same rule as Overdue undo); otherwise the task is left as it is.
- **Launch check, build 305.** `Tools/launch-check.sh` builds Debug for the iOS Simulator and for macOS, launches each with `-paragon-test-vault`, and after 20 s samples the CPU with `ps`. It fails if the process is gone or the CPU is above 30 %. The ship script runs it first, so a hanging build is never uploaded. Screen test `LaunchCheck.testTheAppSettlesAfterLaunch` launches the app, waits for the Today screen, then checks the app is still running after 10 s (runs on Apple's and GitHub's test runs).
- **Tap on ticking (build 303, iPhone and iPad only).** `Haptics.done()` (Theme.swift), a soft impact when a task is ticked done, never when unticked and never on the Mac.

## 9. iPhone

Browse has a large title that shrinks when you scroll. The long press that reveals Work is on the version line at the foot of Browse (on the Mac it is on the PARA heading in the sidebar). The tab bar icons are the hand-drawn marks. Swipe actions on rows are as before. On the iPad the three columns are used.

The picture opened big marks the words you searched for with tinted boxes (build 298): each box is the tint of the part the picture is in, a soft fill with a thin outline of the same colour, drawn over the words and moving with zoom. With no search there are no boxes.

## 10. The version

The version shows as "PARAGON 1.0 (303)" at the foot of the Mac sidebar and at the foot of Browse on the iPhone. It is not in Settings. `AppVersion.text` builds it.

## 11. Day and night

Each colour in section 2 has a day shade and a night shade. By day a panel is white with a light tint and no border. At night a panel is #1E2228 with a stronger tint (13 %) and a 1-point line. Both were drawn and checked.

## 12. Filters in Search

Since build 302 the filter boxes in Search are the same chips as on All actions (`FilterBox(chip: true)`) on the Mac, the iPad and the iPhone, in rows under the field, and the rows end above the results bar. Before build 302 the Mac used its own checkbox control (`Toggle` with the `.checkbox` style), look 1.0. On the iPhone each group is one row (build 281): the group's name at the left (Tasks, Kind of note, How the note stands, Tags) and its chips in a row that slides sideways. All four groups fit in the pane, which is up to 240 points tall (before 200, with wrapping chips and the last groups hidden). A result's line shows the words of a task, never the "- [ ] " marker.

The When / Mark / Tags filter on All actions (build 301, `FilterBox(chip: true)`, same on Mac and iPhone) is smaller: the row names are small grey capitals ("WHEN", "MARK", "TAGS"), not large green headings; each choice is a rounded chip, off = soft grey fill, ticked = filled in the screen's colour (green) with white words and a small tick. The box area no longer has a fixed 260-point height: it is only as tall as its boxes. Since build 302 Search uses the same chips: ticked = filled in the group's own colour, group names small grey capitals (`groupName(_:)` in SearchView), 5 points between chips on every device.

## 13. Two-state buttons and the Icon… button

- A two-state button is one that is on or off: Edit (the pencil), Note / Schedule, Month, Arrange, Hide finished, All of them, The Waiting for list. The off state is a thin solid grey line. The on state is filled with a tint of the part's colour and has a stronger line. No dashed line (`StateToggle.border`; the Core test `testTheTwoStateButtonIsNotDashed` fails if `dash:` returns).
- The one dashed shape is the **Icon…** button while nothing is chosen: a dashed grey capsule, a placeholder that means to look like one.
- Once something is chosen, the **Icon…** button is the tile itself, 24 points, with a 1-point ring in the note's colour, 2 points outside it. Before it was a 22-point tile in a capsule with gaps at the round ends.
- On an aspiration or a goal with a date, a colour alone draws the goal's own mark (the star or the target) on the colour. Other notes draw the first letter of the name.

## 14. Checks for every new screen

- The text sizes come from the scale in section 1. No new size.
- The part's colour comes from section 2. No new colour.
- A panel, a row, an edit window and an empty screen follow sections 3 to 6. A row is one title and one second line, never a card.
- An edit sheet's first field has the focus when it opens on the Mac (section 5).
- The main button is in colour.
- Icons are marks, never stock symbols or emoji.
- The screen looks right on the iPhone and the Mac, by day and by night, at a normal iPhone size.

## 15. The band

Since build 282 (look A, chosen on 9 November 2026 from `Work/look-1.1/design/premium.png`, column A of `premium.html`). Every screen opens with a band in its part's colour. It is the shared view `Band` in `App/Paragon/Views/Look.swift`, the same on the Mac and the iPhone, by day and by night.

- **Fill.** A gradient from the part's colour (section 2, day or night shade) to the same colour 80 % of the way towards the bottom right. No new colour.
- **Title.** The page title in white, at the page-title size (section 1).
- **Small words.** The date or the facts, at the label size (12 points on the Mac), white at 85 % opacity.
- **Big number.** One per band: 34 points, bold, white (`Txt.bandNumber`; on the iPhone Apple's large title, bold). Today (since build 291) has no big number, only small round white buttons (build 304: the calendar button for today's note, then Start the day and Close the day). A project, area or resource note: "2 open tasks · 0 of 2 done". A goal's page: "40 %" with "of the way · Target 15 Aug 2027" under it.
- **Buttons.** **Start the day** and **Close the day** keep their place, in the band's top row, drawn as white circles. Since build 304 `today.note` is an icon-only `HeaderActionButton` (`markName` "calendar", `onBand`), first in `dayButtons`, before `today.startDay` and `today.closeDay`: three same-size round buttons in one row beside the date. It used to be a worded button on its own second row; the band is one row shorter. Its help text says "Today's note" or "Create today's note".
- **Sidebar (Mac).** The chosen row is filled in the part's colour, with white words.
- **Under the band.** Everything is as in builds 280 and 281: tinted panels, 17-point coloured headings, 8-point dots, pop-ups, text sizes, icons. Nothing moves, no function changes, and the part colours are unchanged.
- **For a new screen.** Open with a `Band`; never draw a title bar of your own and never pick a size or colour for it.
