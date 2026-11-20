# Round 350, lane tasks-pages

Nothing was compiled or run (no Swift here). Every rule is in Core with one XCTest.

## 36 Small steps inside a task
- **Rule** `Core/Sources/ParagonCore/Vault/SmallSteps.swift` (`SmallSteps.of(_:in:)`, `Note.smallSteps(of:)`): share of ticked **direct** subtasks; cancelled subtasks count neither way; deeper levels belong to their own parent. Nil fraction/text with no steps. Test `SmallStepsTests`.
- **View** `TaskRow` (NoteEditorView.swift, `smallSteps`): the tick circle (`TickMark` in Motion.swift, new `progress:`/`progressTint:`, new `PieWedge` shape) shows a pie wedge inside the ring; text "2/4" after the title (`Txt.listSecond`, grey). Identifier `task.steps.<title>`, VoiceOver "2 of 4 small steps done".
- **Sign check**: a wedge inside an open ring = "some small steps done". Only the filled disc with the tick = "done". The wedge never carries the tick and is not drawn at 0 steps done, on a done or cancelled task. The circle still ticks the whole task (press unchanged). The wedge uses the note's colour (tint), as a shape (kept on a selected row, like `KindBadge`).
- Not done: ticking all steps does not tick the task by itself (only `isComplete` is exposed in Core).

## 37 Waiting for someone
Already complete since build 279, nothing added (CLAUDE.md says he chose no new Browse row). Exists: task menu **Waiting for…** (who, asked-on date `@since`, follow-up date), **Not waiting any more**, and **All actions** > switch (hourglass, `actions.waiting`) = list by person with "waited N days"; the **Actions** tab on the iPhone reaches it. Also a pointer line "N waiting for other people" in All actions when the switch is off.

## 38 Your year in one page
- **Rule** `Vault/YearReview.swift`: `NoteIndex.yearReview(for:)`, `yearRange(today:)`, struct `YearReview` (goals with a date marked Done with `ended:` in the year, projects Done with `ended:` in the year, tasks by `@done` month, busiest month, texts). Aspirations excluded. Items without `ended:` / `@done` day are left out (cannot be proved). Test `YearReviewTests`.
- **View** `Views/YourYearView.swift`: `YourYearView` (takes the place of the diary inside `DoneView` until Close; `DoneView` has `@State showingYear`, body split into `body` + `diaryBody`), `YearReviewCard` (shared by screen and PDF), `YearPDF`.
- **Words on screen**: button "Your year" (Done, `done.year`); page: "Close" (`year.close`, Escape on Mac), "Share as PDF" (`year.share`), ‹ (`year.previous`, "Earlier year") / year number (`year.title`) / › (`year.next`, "Later year"); card `year.card`: "Your year 2026", "N goals done", "N projects finished", "N tasks done", "Busiest month: March, with 34 tasks", 12 bars Jan..Dec with counts, lists "Goals done" / "Projects finished" (max 40 each, then "and N more"); empty: "Nothing dated in 2026 yet. A task you tick off, or a goal or project you mark Done, shows up here on the day it happened."; iCloud line "Some notes are still coming from iCloud, so the year may be missing some of its days." PDF: `YearPDF.file(for:)` = one page 596 wide, as tall as needed, light, in temp folder "PARAGON share/PARAGON year 2026.pdf"; Mac `NoteSharing.present`, iOS `SharedFile` + `SharesNoteFile`.
- Screen test `testYourYearOpensFromDoneAndCloses` (end of ScreenTests, new MARK).
- Not done: "Looking back" words (optional); offering the page on Today in December (kept to the Done button). The PDF is a single tall page, not A4-paginated.

## 40 Send a project as a PDF
Already exists since build 315: Share… > **As PDF** (`note.share.pdf`; NotePDF renders title, text and tasks as boxes with ticks). Did not add a second `note.sharePDF`. Added only: for a **project**, one grey line of facts under the title (`NoteShare.factsLine(of:)` in Core, test `NoteShareFactsTests`): "Active · Serves <goal> · In area <area> · Deadline 2026-12-01 · 3 of 8 tasks done" (`NotePrint.pieces` in NoteSharing.swift). Linked notes are not included.

## 43 An old note comes back
- **Rule** `Vault/OldNoteComesBack.swift`: Resources (declaredKind), not archived, file date known and >= 30 days old, sorted by path; slot = day number (days since 2020-01-01) mod count -> stable all day and on all devices; `firstLine(of:)` (heading marks/bullets/task box removed, 140 chars). Test `OldNoteComesBackTests`.
- **View** `Views/OldNoteCard.swift` `OldNoteSection(day:)` = a Section in Today's list (one line added in `TodayView`, after "Important, no date", not while picking). Header "From your Resources"; card: title, first line, **Open** (`today.oldNote.open`), **Not today** (`today.oldNote.notToday`; stores today's date in UserDefaults `oldNoteHiddenDay`, per device). Card id `today.oldNote`.
- **Setting** Settings > Tasks: "Show an older Resource on Today" (`settings.showOldNote`, UserDefaults `showOldNote`, default on) + a grey sentence.
- No screen test: the test notes have no Resource older than 30 days (fixture left alone).

## 44 Energy tags
- **Rule** `Vault/TaskEnergy.swift`: `TaskEnergy` (easy/medium/hard, labels Easy/Medium/Hard), `TaskItem.energy`, `settingEnergy(_:)` (one at a time, same choice = no change, nil = None); `ActionFilter.energies` (or inside the row, and with the others; in `summary`; `tagChoices` no longer offers the three as tags). Test `TaskEnergyTests`.
- **UI** task menu: **Energy** submenu (mark `chart.line`) with ticked Easy/Medium/Hard/None (`TaskActions.swift`); `AppModel.setEnergy` (new file `App/Paragon/TaskPages350.swift`); All actions: new row **Energy** with boxes `actions.box.energy.easy|medium|hard` (AllActionsView.swift).
- **Guard** `AppModel.changeTag` (AppModel.swift) refuses rename/remove of #easy/#medium/#hard: "#hard is one of the three effort tags (easy, medium, hard). Renaming or removing it would break the Energy boxes in All actions."

## 48 A task moved often
- **Marker** `@moved(N)` on the line: `TaskItem.moved` (last init parameter, default nil), parsed (`TaskParser.movedRegex`), serialized after `@deadline`, before `@done`; dimmed in the editor; never in a reminder title; `nextOccurrence` resets it.
- **Counting** one place: `TaskItem.settingDue(date:time:)` (TaskDue.swift) adds 1 when an existing do-day moves to a strictly later day (earlier, same day, a first date, taking it off, time-only change count nothing). `setDueDate`, `setDue`, swipe-to-tomorrow and Overdue buttons all go through it; `AppModel.moveTasks` now calls `settingDueDate` instead of `task.dueDate = date`. Undo of a move (`TaskUndo`) takes one off again. The Waiting-for "Follow up next week" is not counted.
- **Prompt** at `TaskMoved.askAt` = 5 (`Vault/TaskMoved.swift`): row fact "Moved 5 times" (mark `chevron.right`, attention colour, `task.moved.<title>`) and the task menu starts with "Moved 5 times" then **Do it now** (due today, count starts again), **Split it** (opens the note, count starts again), **Drop it** (cancels the task, as the review's drop). Functions in `TaskPages350.swift`. Test `TaskMovedTests`.
- Not done: no separate popover on the row, the question lives in the menu (long press / right-click).

## Edits outside "new files"
AppModel.swift: the `changeTag` guard and the `moveTasks` line only (no stored properties added). TodayView.swift one `if !picking { OldNoteSection }` block. DoneView.swift body split. SettingsView.swift one @AppStorage + one Toggle.

## Uncertain to compile
- `Motion.swift` `PieWedge.path` `addArc(... clockwise: false)` (fine either way, a pie).
- `DoneView`: `@ViewBuilder private var diaryBody` starting with `let today = ...`.
- `YourYearView.swift`: `.buttonStyle(.filled(tint))`, `ForEach(1...12, id: \.self)`, `.frame(maxWidth: .infinity, alignment: .bottom)`.
- `OldNoteCard.swift`: `Section` as the body of a custom view inside Today's `List`.
- `TaskEnergy.swift` / `OldNoteComesBack.swift`: `String.removeFirst(_:)`, `Substring.hasPrefix`.
- `ActionFilter` is `Equatable`: new `energies` set of an Equatable/Hashable enum is fine.
