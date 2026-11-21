# Round 352, lane "tasks"

Nothing here was compiled or seen on a screen. There is no Swift compiler in this container;
GitHub CI is the first check. Six items, one commit each.

## Item 2 — ticking the last small step ticks the task

**Built.**
- Core rule `Note.tickParentsWhenStepsDone(afterTicking:at:calendar:) -> [TaskItem]`
  (`Core/Sources/ParagonCore/Vault/SmallSteps.swift`). Call it right after a step was ticked
  done. When the step has a parent that is still open (`status == .open`) and every direct step
  under the parent is now done or cancelled (`SmallSteps.isComplete`, so at least one done),
  the parent is ticked through `Note.complete(task:)` — the same path as any tick: `@done(…)`
  stamp, and a repeating parent gets its next time. It goes on one level up while the same is
  true (at most 20 levels). Returns the ticked parents, innermost first. Unticking never calls
  it, so a parent is never opened again.
- `SmallSteps.parentsDoneMessage(_ titles:) -> String?`: "All steps done, so “X” is done too."
  For two or more: "All steps done, so “A”, “B” and “C” are done too." Nil for none.
- Box in the note text: `TaskBox.tick(_:at:date:calendar:) -> TaskBox.Tick?` (new; `Tick` has
  `text` and `parentsDone`). `TaskBox.toggled` now returns `tick(...)?.text`, so its behaviour is
  the same plus the parent rule. The text is wrapped in a throwaway `Note` (body = the editor
  text) to run the one rule.
- App: `AppModel.toggle` (any task row) calls the rule after `note.complete(task:)` and flashes
  the message; when the step was also a repeating task, both messages are joined ("Done. Next
  time: … All steps done, so …"). The editor (`MarkdownSyntaxEditor.swift`, Mac `boxClicked`,
  iOS `boxTapped`) uses `TaskBox.tick` and calls a new hook `PictureHooks.stepsDone(String)`,
  which `NoteEditorView.pictureHooks` wires to `model.flash`. (`PictureHooks` is the one bundle
  of closures the note screen hands the editor; the hook is not about pictures, the comment says
  so.)
- Also `Vault.tickSeedboardDone` (Core, `Capture.swift`, the tick that comes from AMS Seedboard):
  same rule, no message. Added so a tick from outside the app behaves like one in it.
- Tests: `SmallStepsTests` (5 new): last step ticks the parent and only then, unticking never
  opens it, an already-ticked parent and a task with no parent are left alone, it goes up a
  level, a repeating parent gets its next time, a box in the text ticks the parent too and says
  so (`TaskBox.tick`), and the message words.

**Undo and Reminders sync.** The parent is ticked like a normal tick, in the same save as the
step, so the sync sees an ordinary `[x]` with `@done`. In the editor the parent's line is part of
the same text replacement, so one ⌘Z (Mac) undoes the step and the parent together. A task-row
tick has no Undo offer (it never had). Unticking the step afterwards leaves the parent ticked —
by the rule asked for; he must untick the parent himself.

**Not done.** Ticks from Apple Reminders (the sync's reconcile path, when a step is completed in
Reminders) do not tick the parent. The Siri/Shortcuts and widget "done" paths that go through
`AppModel.toggle` do; any that tick by another way do not (not checked one by one).

**Uncertain.**
- A repeating parent: `Note.complete` inserts its next open copy right below the parent's line,
  so the ticked steps then sit under the new copy (this is how ticking a repeating task with
  steps already behaved). The new copy shows "3/3" until its steps are opened again by hand.
- On the iPhone the haptic check counts "[x]" before and after, so it still fires once.
- The flash appears over the note screen; on the iPhone a flash under a sheet is not seen
  (build 238) — the note editor is not a sheet, so it should show.

**For Docs/HowItWorks.md** (section about tasks, line ~771 "Small steps", and remove "Ticking
all small steps does not tick the task." from the round 350 **Not done** line ~3156):
- **Small steps.** … The circle still ticks the whole task. When you tick the last open step,
  the task is ticked too, and PARAGON says "All steps done, so “X” is done too." This works on a
  task row and on a box in the note's text. A cancelled step counts as finished. If the task
  repeats, its next time is added, as with any tick. Unticking a step does not untick the task.

## Item 5 — "Check after filing"

**Built.** Words only, no behaviour change. Settings › Voice switch is now **Check after filing**
(identifier unchanged: `settings.voiceCheckFirst`; storage key unchanged: `voiceCheckFirst`).
The footer now says: "With Check after filing, the thought is filed first; then a card lets you
change the title, take out a task or throw the thought away." Comments in
`VoiceControlsApp.swift`, `AppModel.swift`, `VoiceViews.swift` follow. The card's heading is
**Check the thought** and never said "before", so it is unchanged. File:
`App/Paragon/Views/SettingsView.swift`.

**Docs that still say "Check before filing" (lead edits):**
- `Docs/HowItWorks.md` line ~2166 (`- **Check before filing** (Settings › Voice, on at start)…`)
  and line ~3149 (the round 350 list of new Settings rows).
- `Docs/Guide.md` line ~297.
- `Docs/Words.md` line ~166 (the word entry; rename it to **Check after filing**).
- `Docs/VersionHistory.md` lines 39–40 are history (build 350); leave them, or add one line in
  the 352 section: "Settings › Voice › Check before filing is now called Check after filing.
  The thought was always filed first; the name now says so."

**Uncertain.** No screen test uses the words. None.

**For Docs/HowItWorks.md** (Voice section, ~2166): replace the bullet's name with **Check after
filing** and start it: "The thought is filed first. When PARAGON is in front, the card **Check
the thought** opens…" (rest unchanged).

## Item 6a — German "am 25."

**Built.** `VoiceThought.language` (new, `""` by default; e.g. "de-DE") and
`VoiceThought.speaksGerman`. `VoiceRecorder` sets `thought.language = locale.identifier` right
after making the thought. The German flag is passed down: `spokenTasks(in:german:)`,
`spokenTaskItems(in:now:calendar:german:)`, `spokenTask`, `SpokenWhen.extract(…german:)`,
`SpokenWhen.findDate(…german:)` (all default `false`, so every old caller is unchanged).
`finalTasks` and `finalTaskItems` use the thought's own language, so the title (date words
taken out) and the date stay in step. `SpokenWhen.isGerman(_:)` = language starts with "de".
Only when German: `(?:am|bis zum|zum) 25.` is the 25th — the next such date, today included,
the same rule as "the 25th". Not before a digit, so "am 25.11" is not read (the month is not
understood). Never a regex class starting with a colon. Files:
`Core/Sources/ParagonCore/Vault/VoiceWords.swift`, `VoiceThought.swift`,
`App/Paragon/VoiceRecorder.swift`. Test: `VoiceWordsTests.testTheGermanDayWithADotIsADateOnlyInGerman`
(German finds it, a past day goes to next month, "am 25.11" not read, English "I am 25." and a
non-German thought give no date, the thought's language decides through `finalTaskItems`).

**Not done.** "am 25. November" (a month name after the dot): `sentencesOf` ends a sentence at
"25. ", so "November" lands in the next sentence and is lost. Live counts on the Lock Screen
(`VoiceRecorder` lines ~321 and ~404) and `lateTasks` still read without the German flag: only
a title may then keep "am 25" (counts are unaffected). The phone's language ("" in Settings) is
resolved to the recorder's locale, so it is covered when that locale is German.

**Uncertain.** Whether Apple's speech-to-text writes "am 25." with the dot at all (it may write
"am 25" or "am 25ten"; those are not changed here).

**For Docs/HowItWorks.md** (Voice, ~2152 and ~2159): add to the **Dates** bullet: "In German
also "am 25." (the 25th), but only when the voice language is German; "am 25.11" is not read."
Remove "German "am 25." (the dot ends a sentence)," from the **Not understood yet** line.

## Item 14 — Next free time and the working day

**Built.** Core `DayPlan.nextFreeSlot(length:from:workdayEnds:busy:) -> DayPlan.FreeSlot?`
(`FreeSlot` has `start` and `endsAfterWorkday`) and
`DayPlan.nextFreeMessage(_:workdayEnds:) -> String` in `Core/Sources/ParagonCore/Vault/DayPlan.swift`.
It looks until Settings › **Working day ends** first; when it is already past that, or nothing
fits before it, it looks until midnight as before.

**Important, honest finding:** the search only moves forward from now, so limiting it to the
working day and then falling back to midnight **always gives the same start** as before (a slot
that fits inside the working day is the earliest slot either way). A test pins that the start
never differs. What does change: the message. When the block runs past the working day it says
"Added to your plan at 17:00. That is after your working day, which ends at 16:00." Otherwise
the words are unchanged: "Added to your plan at 10:00." / "No free time left on this day. Pick
a time instead." The block is still placed (the working day is a measure, not a wall, build
249). If Martin meant something else (for example: never place after the working day, or ask
first), that is a different rule — please ask him.

**Callers, all changed:**
- `AppModel.planAtNextFreeTime` (returns `DayPlan.FreeSlot?` now, was `Int?`; one caller) —
  used by **Next free time** in the small menu on an action tile in **Plan** (iPhone and iPad
  tray tiles, `plan.tile.nextFree`).
- `PlannerView.placeAtNextFreeTime` — the flash words now come from Core.
- `PlannerView` **Pick a time…** — the start filled into the **New block** sheet uses the same
  search (same start as before).
- Not changed: picking on Today (`planActions` / `DayPlan.freeStarts(lengths:…)`), which
  already measures against the working day with its own "It fits" lines.

Test: `DayPlanTests.testNextFreeTimeLooksInsideTheWorkingDayFirst`.

**For Docs/HowItWorks.md** (Plan, the paragraph about tapping a tile, ~1278–1282): replace "It
looks for room until midnight." with: "It looks for room before your working day ends
(Settings › Tasks › **Working day ends**) first, then until midnight. When the block ends after
your working day, the message says so: "Added to your plan at 17:00. That is after your working
day, which ends at 16:00.""

## Item 15 — the Weekly review remembers what you left open

**Built.** Core `ReviewOpening.openAtStartOfVisit(parts:leftOpen:chosenByHand:)` in
`Core/Sources/ParagonCore/Vault/GuidedOpening.swift`: when he has ever opened or folded a part
himself, the visit starts with exactly the parts he left open (also none, when he folded them
all); only while nothing is remembered does the first part with something to do open by itself.
App `ReviewView`: two new `@AppStorage` flags, `reviewOpenPartsByHand` (Mac and iPad) and
`reviewOpenPartsByHandPhone`, set true by any heading's fold button (including steps 3, 8 and 9,
which use the same `openBinding`) and by **Open all** / **Close all**. The open parts are still
stored in `reviewOpenParts` / `reviewOpenPartsPhone`, as before. Test:
`GuidedOpeningTests.testTheReviewStartsWithThePartsHeLeftOpen`.

**Uncertain.**
- On a device that already used the review, the flag starts false, so the first visit after the
  update still opens the first part with something to do; from his first press on, it remembers.
- Screen tests start with wiped settings, so `testTheReviewFoldsStepByStep` ("folded at first")
  should still pass. A test that leaves the review and comes back in the same launch would now
  find what it left open (none found by grep, not checked line by line).
- A remembered part that is not drawn (**Projects with no goal** when there are none) stays in
  the stored set; harmless.

**For Docs/HowItWorks.md** (Weekly review, ~1495): replace "Since build 312, each time you come
in, only the first part that has something to do is open. … It no longer remembers them for the
next visit (before build 312 it did, and the first time every part was folded)." with: "Since
build 352 the review remembers which parts you left open, and the next visit starts with those.
Until you have opened or folded a part yourself, only the first part that has something to do
is open (as since build 312). When nothing is left to do and nothing is remembered, no part is
open." The sentence "Steps 7, 8 and 9 … never open by themselves" stays true.

## Item 9 — texts that were cut

**Built.**
- `ProjectRow` (`App/Paragon/Views/ProjectsView.swift`): "Next: …" may take two lines also when
  other facts follow on the line below (`lines: 2` always; the one-line `ViewThatFits` choice is
  unchanged).
- `AspirationRow` and `DatedGoalRow` (`App/Paragon/Views/GoalsView.swift`): the second line is
  `.lineLimit(2)` with `.fixedSize(horizontal: false, vertical: true)`, so it wraps instead of
  being cut.

**Uncertain.** Not seen. Rows become taller when the line wraps; in a `List(selection:)` this is
only a height change. No screen test reads these heights.

**For Docs/HowItWorks.md:** nothing needed (no rule a reader relies on). VersionHistory line:
"Long "Next: …" lines on project rows, and the second line of aspiration and goal rows, now
wrap to two lines instead of being cut."

## Screen tests

None added. Items 2, 14 and 15 are pure rules tested in Core; item 2's editor path needs a box
tap at a measured point and a flash read within 2.5 s, which is not certain on a slow runner.
