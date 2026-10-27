# How PARAGON works

PARAGON is a plain-text project and life management app. Everything you write is a markdown file in a folder you own. The app reads and writes those files; Apple Reminders and Apple Calendar stay in sync with them.

Every heading below opens and closes, so this page is a contents list you drill into rather than a wall of text. The box at the top searches it: type a word and only the parts that mention it are shown, already opened.

If a word is unclear, **Words in PARAGON** explains each of the app's own words in one or two sentences. On the Mac it is in the **Help** menu, and at the top of this window. On the iPhone it is in **Settings**, under **Help**.

Throughout: **right-click** on the Mac is **long-press** on the iPhone. Where this page says one, the other works on the other device.

## The idea

- **Goals** say what you want in life. They sit above everything else.
- **Projects** are things with an end: a race, a move, a report. Each one should serve a goal.
- **Areas** are things you keep up over time: health, home, a client. They also serve goals. An area can sit under another one as a **sub-area** — Mobility under Health, say, or Yoga, Pliability and Stretching under Mobility. Right-click an area (long-press on the phone) › **Part of** to put it under another, or to take it back out. Areas nest one level, no deeper, so the list stays a list.
- **Resources** are reference material: articles, checklists, ideas.
- **Archive** is where finished projects and closed areas go. They stay searchable.
- **Inbox** catches everything you have not sorted yet. It has a screen of its own; see **The Inbox** below.

That is PARA with a Goals layer on top. Every note answers "what does this serve?".

## Your vault

The vault is one folder. Pick it once under Settings › Vault. Inside it the app keeps:

- `Inbox.md`
- `Goals/`, `Projects/`, `Areas/`, `Resources/`, `Archive/`
- `Calendar/` for daily notes (`20260906.md`) and weekly notes (`2026-W36.md`)
- `Templates/` for the note skeletons, which you can edit
- `.ams-para/` for the app's own settings and sync bookkeeping

You can open the same folder in NotePlan, Obsidian or any text editor. If the folder lives in iCloud Drive, your iPhone can use the same vault.

## Notes

A note starts with a small block of settings between two `---` lines, then the text. The settings are plain `key: value` lines, for example:

```
---
title: Perform IM Jönköping 2027
type: project
status: active
area: Health
goal: Train for and do IM 70.3 for five years
due: 2027-08-15
tags: [sport, training]
---
```

Useful keys: `status` (active, on hold, done, missed, dropped — see **How a note stands**), `area`, `goal`, `due`, `tags`, `emoji` (a project's own emoji, see **The Projects list**), `related`, `reviewed`, `order` (where the note sits when you have arranged the list by hand), `reminders-list` to sync into a Reminders list with a different name, `sync: false` to keep a note out of Reminders.

Several of these have a button at the top of the note as well, and it writes the same line: **Serves…** for `goal`, **In area…** for `area` (projects only), **Part of…** for `parent`, **Due** for `due`, **Tags…** for `tags`, and **Emoji…** for `emoji`. On a goal, **Set a target date…** writes `target` and **Set a measure…** writes `measure`. On an aspiration, a goal or an area, **I looked at it today** writes `reviewed` (see **When you last looked at it**).

You do not have to look at the block while you write. Above the text there is a line that says **Settings block**; press it and the block folds away, and the line says **Settings block hidden**. Press it again to bring it back. The block stays in the file either way, and the buttons at the top of the note keep writing into it. The choice holds for every note until you change it.

**⌘Z** undoes your typing in the note you are in. Each note has its own undo, so after you open another note, ⌘Z does not reach back into the one you left. When anything other than your typing changes the note while it is open — your other device, **Settings block**, a tick or a new task in the task box, a button at the top of the note, or a title picked from the `[[` list — its undo starts again from that point. On the Mac, the grey word suggestions macOS can show after the cursor, and the grey answer after a sum such as "120+35=", are switched off in notes, because they made PARAGON crash. Spelling is still checked and underlined.

Links between notes use `[[Note title]]`; see **Linking notes with [[ ]]** below.

### Making one

**⌘N** opens one screen with six buttons across the top: **Aspiration**, **Goal**, **Project**, **Area**, **Resource** and **Capture**, each in its own colour. Under them is the name field with the cursor already in it, so a note is usually a name and Return, and one line says what the kind you chose is for.

Under that, everything else a note can be given as it is made, drawn as chips you press. A chip you have set is filled in its own colour with a solid line around it; one you have not set is grey with a dashed line.

- **Aspiration** — the aspiration it serves is not asked for: an aspiration is the top of the chain. Only its name and its tags.
- **Goal** — a **Target** date and the aspiration it serves. Write the date as 2031-12-01 or pick it from the calendar. The two buttons carry the two icons: the star for an aspiration, the target for a goal with a date. The measure is not asked for here. Set it later with **Set a measure…** at the top of the goal.
- **Project** — the goal it delivers, and **In area…**: the area it is part of. The list also has a field to make a new area without leaving the screen: type the name and press **Add area**. A name already in use chooses that area.
- **Area** — the area it is part of, and the aspiration it serves.
- **Tags** — the whole list of tags you already have, with a tick on the ones you pick and a number beside each saying how much of your vault carries it, so a tag that means the same as one you already use but is spelled differently stands out. A field at the top makes a tag that does not exist yet. It is the same list the tag button in a note's header opens.
- **Template** — which template to start from, when that kind has more than one.

Only the chips that apply to the kind you have chosen are shown.

Two lists have a field at the top to make a new thing: **Serves…** (a goal or an aspiration) and **In area…** (an area). They work the same way. If a thing of that kind already has the name, it is chosen and nothing new is made. If the name cannot be used, the box says why in orange and your words stay in the field. For example, an aspiration and a goal with a date cannot have the same name, because both are kept in the **Goals** folder. And a goal that is Done, Missed or Dropped, and still in the **Goals** folder, is not in the list, so it cannot be chosen: the box tells you, and you use another name. A goal or an area that you put away with **Archive** is not looked at: its name can be used again, because the archived note is parked in the **Archive** folder.

**Capture** is the last button. It turns the lower half into the quick capture screen, so the same screen takes a project and a line you must not forget. See **Quick capture** below; nothing about it changes, it is only reachable from here as well.

### Renaming a note

Press the note's **name** in the row under the toolbar, beside **Project** or **Area**. Or right-click the note in the list (long-press on the phone) › **Rename…**; on the iPhone it is also in the **…** menu at the top of the note. The file is renamed with it, and every note that pointed at the old name — `goal:`, `area:`, `parent:`, `related:` or a `[[wikilink]]` — is updated, so no link comes loose. The note's own `# Heading` follows when it still said the old name.

A name another note already uses is refused. In Apple Reminders the list follows on the next sync; the tasks keep their reminders. The Inbox and daily notes cannot be renamed.

### Archive and Deleted

- **Archive** moves a project, area, resource or goal to the Archive folder, marks it archived and stops syncing its tasks. Use it for finished work. A note that is **Done**, **Missed** or **Dropped** keeps that word and the day it ended, so an archived project that was done still counts for its goal. Any other note is marked archived.
- **Delete** (⌘⌫, or right-click the note; long-press on the phone) moves a note to the **Deleted** section in the sidebar. Nothing is lost: each entry has **Put back**, which returns it to the folder it came from (or beside it, if that name has been taken since), and **Delete for good**. **Empty** in the toolbar clears the lot.
- Deleted notes are kept for **30 days**, then cleared out on their own. They live in a hidden folder inside the vault, so the phone and the Mac behave the same way and nothing there syncs to Reminders. The Inbox note cannot be deleted.
- Only whole notes go here. A task you delete from a list is gone from the note straight away.

### Which aspiration an area serves

An area can say which aspiration it belongs to, and a project which goal it delivers: **Serves…** at the top of the note, or right-click it in the list. A project is offered the dated goals first, an area the aspirations first. The list is the same as on the **Goals** and **Aspirations** screens: only goals that are still running, in their order, and never the note itself. A goal the note already serves stays in the list even if it has ended, with its ending in brackets, such as (Done), so the tick is never lost. That is what makes Endurance the home of "an endurance athlete still racing at seventy" rather than leaving the aspiration floating on its own. An area is allowed to serve nothing — it is a standard you keep up, not a path to an outcome — so the review never asks about an area without one.

### Which area a project is in

Open a project and press **In area…** at the top. Pick an area, for example Health. The button then says **In Health**, in pink. A sub-area is listed after its own area, as **Health › Yoga**. **In no area** takes the project out again, and **Open Health** goes to the area.

- The same list is on the right-click menu of a project in the **Projects** list (press and hold on the iPhone) › **In area**.
- On the **New note** screen, a new project has the same **In area…** button. Its list also has a field to make a new area without leaving the screen: type the name and press **Add area**. A name already in use chooses that area; no second one is made.
- It is kept in the note's settings block as `area: Health`. You can also write that line yourself.
- **Only this line puts a project in an area.** A `[[Health]]` link in the project's text, or Health in its `related:` line, links the two notes, but the project is not in Health because of it.
- If the line names an area that does not exist, for example after a spelling mistake, the button shows the name in grey, and its list says **No area is called …**. Pick the right area to fix it.
- If the area it names has been archived, the button says **(archived)** after the name, and its list says the area is archived and offers to open it.
- While notes are still coming from iCloud, the button is orange, and its list says the area may still be coming from iCloud instead of **No area is called …**. Wait for it to arrive before you change anything.
- On the **Map**, the project sits under the area you chose. The **Projects** list does not change: it stays grouped by aspiration.

## The Projects list

The **Projects** list groups your projects by what they work towards.

- **Under an aspiration.** A project that serves an aspiration, or serves a goal with a date
  that serves an aspiration, sits under that aspiration's heading. The heading has a gold band
  and the star. The aspirations come in the same order as in **Aspirations**.
- **Not linked to an aspiration.** The project serves a goal, but that goal has no aspiration
  yet, or the `goal:` line names a goal that cannot be found (drawn with a dashed line). To fix
  the first, go to **Goals** and press **Give it an aspiration** under the goal. To fix the
  second, right-click the project (press and hold on the iPhone) › **Serves** and choose a goal.
- **Projects with no goal.** No `goal:` line at all. Right-click the project (press and hold
  on the iPhone) › **Serves** to give it one. This is not an error; the list only says so.
- **Done**, **Missed** and **Dropped** at the bottom, folded at first. An empty group is not
  shown. A project that says `status: archived` but is still in the Projects folder gets an
  **Archived** group at the very end.

Press a heading to fold the group or to open it again. The heading always shows how many
projects it holds.

Above the groups, one line speaks for the whole list: bars for all projects together, how many
tasks were finished in the last eight weeks and this week ("14 tasks finished in 8 weeks · 2
this week"), and "⚠ 1 needs a look" in orange when a project has a date that has passed or
a deadline after its goal's target date.

### What a box says

Each project is a box. On the Mac it has a thin green frame; on the iPhone each group is one
rounded card.

- The **tile** on the left shows the project's own emoji, in a green frame. Until you pick one
  it shows the project flag in a dashed frame. The frame is green while the project is running
  or done, and grey when it is on hold, missed, dropped or archived. See **Your own emoji**
  below.
- The **name**, on up to two lines.
- **What it needs**, in one line:
  - **Next:** and the task to do next. That is the open task marked `#next`, or else the first
    open task in the note. When every task is ticked but a subtask under one of them is still
    open, it is that subtask. The Goals and Aspirations screens and **Plan** use the same rule.
    The `#next` itself is not shown there.
  - **All 15 finished** (or **Its one task is finished**) and a grey **No next action**: every
    task is ticked, but the project still says it is active. Either mark it done, or write its
    next task. The grey is on purpose; the weekly review is where this is asked with orange.
  - **No tasks yet**.
- The **goal** it serves, in gold, with its star or target. It is left out when the project
  serves the heading's aspiration directly, because the heading already says it.
- **Weekly bars**: eight small green bars, the tasks finished in each of the last eight weeks,
  with this week on the right. A week is Monday to Sunday, as in the weekly notes. A task
  counts on the day in its `@done(…)` mark; subtasks count too. Beside the bars, while the
  project is moving, "6 finished in 8 weeks"; once nothing has been finished for two weeks,
  "last task finished about a month ago". A project where no finished task carries a date
  shows no bars.
- **Pills**: a small bar with "2 of 6 finished", the next task's time and date, **On hold**,
  the deadline ("Deadline in 11 days"), and the first two tags. A project that has ended shows
  the day it ended instead of the dates (see **Finished projects, newest first**).

**Red** is only for a date that has passed: the next task's date, the deadline, or "2 overdue"
(open tasks in the project whose date has passed). **Due after its goal** is orange: the
project's deadline is later than its goal's target date. A heading shows an orange ⚠ and a
number when a project in it has one of these. "No next action" is never orange.

### Finished projects, newest first

- In **Done**, **Missed**, **Dropped** and **Archived**, the project that ended last is at the top.
- The order comes from the `ended:` line, the day you marked the project. Two projects that ended on the same day keep your own order.
- A project that ended before build 262 has no `ended:` line. Those sit at the bottom of their group, in your own order.
- Each box in these groups shows the day it ended in a small grey pill, for example **20 October**. A day in another year also shows the year. A project with no day has no pill.
- The **Done** heading also says how many of the projects in it ended this year, for example **Done 6 · 4 this year**. "This year" means since 1 January. Only projects with an `ended:` day are counted. A project you have archived is no longer in the Projects list, so it is not counted. When none ended this year, nothing is shown.
- **Missed** and **Dropped** do not get this count. Only the order and the day.
- A finished box does not show its open task's date, so the day it ended is the only date on it.
- To change the day of a project in **Done**, **Missed** or **Dropped**, open the project and press the line under its header (see **How a note stands**). In **Archived** there is no such line: change the `ended:` line in the note's settings block.

### What you can do from the list

- **Click** a project to open it, as before.
- **Right-click** (press and hold on the iPhone): **Rename…**, **Serves**, **In area**, **Set active**,
  **Mark done**, **Mark missed**, **Mark dropped**, **Put on hold**, **Archive** and **Move to
  Trash…**. Only the lines that would change something are shown. A project you mark done
  moves into **Done** at the bottom of the list, where the projects are in the order they
  ended (see **Finished projects, newest first**).
- **Drag** a project up or down inside its group to arrange it by hand. A drag never moves a
  project into another group, and the projects in the other groups keep their places. The
  order is written into the note as `order:`, so the Mac and the iPhone agree. **Done**,
  **Missed** and **Dropped** cannot be arranged: they are in the order the projects ended.
- Drop a task from another list onto a project to move the task into it.
- **Search** in Projects shows the plain list of every project, as before. While a search is
  shown, projects cannot be dragged: the list then holds only the matches, so a new order could
  not be worked out for the rest.

The number beside **Projects** in the sidebar counts every project except those marked Done,
Missed, Dropped or archived. A project on hold is counted.

### Your own emoji

Each project can have its own emoji, shown in its tile in the list. Open the project and press
**Emoji…** at the top, right after **Projects**. A small list opens with 24 emoji in four rows:
**Make and build**, **Apps and screens**, **Body and sport**, and **Home, boat and travel**.
Press one and it is set.

- **Or type any emoji** takes any other emoji. On the Mac, Control-Command-Space shows every
  emoji there is. Only the first emoji you type is kept; words are not.
- Once an emoji is set, the button at the top of the project shows the emoji itself instead of
  **Emoji…**. Press it to pick another one, or to reach **Remove emoji**, which takes it away
  again. The tile then shows the project flag in a dashed frame.
- The emoji is kept in the note's settings block as `emoji: 🎒`, so it travels with the note to
  the iPhone and back. You can also write that line yourself.

## An area's page

Open an area, for example Health. Above its text there is a part that shows what the area holds and whether work in it is moving.

- **Standard**: at the very top, the first sentence of what "good" looks like in this area, for example "Three runs a week, one rest day, a yearly check-up." It shows two lines at most. When there is more, it ends with "…".
- Press **Standard…** and the whole text opens right there. Write it, then press **Save**. **Cancel** closes the box and writes nothing.
- When no standard is written, a dashed grey line says **No standard written yet**, and the button says **Write the standard…**.
- The question the Area template puts under **Standard**, "What does "good" look like in this area?", is not a standard. It counts as nothing written. The same goes for the question in your own Area template, if you have reworded it.
- The standard is kept in the note's text, under the heading `## Standard`. **Save** puts your words in place of the question. A note with no such heading gets one, above its first section. Writing it by hand in the note's text works as well.
- **Save** with an empty box takes the standard away, heading and all. When no standard was written, it changes nothing, so the template's question stays.
- If the standard was changed on your other device while the box was open, nothing is written. An orange line says what it is now, and your words stay in the box. Press **Save** again to use yours instead.
- **Weekly bars**: eight small pink bars, the tasks finished in each of the last eight weeks, in the area itself and in every project in it. Beside them, for example, "14 tasks finished in 8 weeks · 2 this week". A week is Monday to Sunday. When no finished task carries a date, no bars are shown. When the last finished task is older than eight weeks, the bars are left out too, and one grey line says when it was, for example "last task finished about 3 months ago".
- **Projects in this area**: every project whose **In area…** names this area, in the order you arranged them in the **Projects** list. The number beside the heading says how many.
- Each project shows its tile with its emoji, its name and what it needs, in the same words as its box in the **Projects** list: **Next:** and the task to do next, **All 3 finished** and a grey **No next action**, or **No tasks yet**.
- "2 overdue" is red: open tasks in the project whose date has passed. The deadline is red once it has passed, and grey before that. A project on hold says **On hold**.
- Projects that are done, missed, dropped or archived are not listed. One line under the list says how many there are.
- **Press a project** to open it. To come back to the area, press ⌃⌘← on the Mac, or the back arrow at the top on the iPhone.
- **Right-click** a project (press and hold on the iPhone) for **Serves**, **In area**, **Set active**, **Mark done**, **Mark missed**, **Mark dropped** and **Put on hold** — the same lines as in the **Projects** list.
- **Add a project…**, beside the heading, makes a new project that is already in this area. Write the name and press **Add project** or Return. You stay on the area, and the new project is listed at once.
- If a project with that name is already there, the box says so in orange and keeps your words. **Cancel** closes the box and makes nothing.
- **Sub-areas**: under the projects, one row for each sub-area, like "Yoga · 1 project · 3 open". The open number counts the open tasks in the sub-area and in its projects. Press the row to open the sub-area.
- The projects of a sub-area are listed on the sub-area's own page, not on its parent's, so each project is shown in one place. Their finished tasks are in the sub-area's bars too.
- Press **Projects in this area** to fold the list away, and press it again to bring it back. The choice holds for every area. **Add a project…** stays beside the heading while the list is folded. The sub-areas fold away with the list; the orange iCloud line stays.
- On the Mac the list is never taller than a short box. When there are many projects, scroll inside it; the text of the note keeps its room below.
- Only the `area:` line puts a project here. A project that only has `[[Health]]` in its text is not listed. See **Which area a project is in**.
- While notes are still coming from iCloud, an orange line under the heading says that more projects may appear. It stays on screen when the list is folded.

## Sub-areas

**Making one.** Open the area note and click **Part of…** in the top row, then pick the area it belongs to. "Not part of another area" takes it back out. The same choices sit on the right-click menu of an area in the list (long-press on the phone), and **New note › Area** has a **Part of** chip for making one from the start.

A sub-area is an ordinary area note with one extra line in its frontmatter, `parent: Health`. That means it behaves like any other area:

- Its own tasks and its own list in Apple Reminders.
- Its own box on the Map, drawn under the area it belongs to.
- A destination of its own in the Inbox "File it" column and in a task's **Move to** menu, where it reads "Health › Mobility".

In the Areas list a sub-area is indented under its area, and the chevron on the area folds its sub-areas away. Dragging to arrange works inside a family: a sub-area moves among its brothers and sisters, an area among the other areas. The note itself shows **Part of Health** at the top — click it to go there. The parent's own page lists its sub-areas under its projects, one row each; see **An area's page**.

Any area can be picked as the parent. Picking one that is already a sub-area lifts it up a level first, since areas nest one level only — asking for "Yoga under Mobility" means Mobility is the level above.

## Tasks

Tasks are ordinary list lines inside the notes:

- `- [ ] Book the hotel` is open
- `- [x] Book the hotel @done(2026-09-06)` is done
- `- [-] Cancelled` and `- [>] Moved to another day`
- `>2026-09-10` sets a date, `>2026-09-10T14:30` a date with a time
- `!`, `!!`, `!!!` set the priority
- `~45m`, `~1h` or `~1h30m` says how long the task takes. **Start the day** asks for it before it plans a task, adds up what you picked, and **Plan** makes each block that long. The small button on the right of every task row writes it for you: it shows **time?** while there is none. **Settings › Tasks › Use task times** hides all of it.
- `#tag` adds a tag
- an indented `- [ ]` under a task is a subtask
- `^t3cd432` at the end is the marker the app uses to match the task with its reminder. The editor hides it, so you will only see it in another editor. If it ever goes missing, the next sync puts it back.

While you type, the editor shows what the markdown means: headings grow, task boxes are coloured, a finished task is struck through, dates and tags stand out, and the symbols themselves fade. Nothing in the file changes; it stays plain markdown for NotePlan and every other editor.

The task box under the note header shows the same tasks as a checklist. Ticking there edits the line in the file. Its header row has a **Hide finished** switch (also in Settings › Tasks) that leaves out what is done or cancelled; a finished task with open subtasks always stays visible, and nothing is removed from the file.

Right-click any task, anywhere in the app — long-press on the phone — for the task menu:

- **Reschedule**: Today, Tomorrow, Next Monday, In a week, Pick a date, Remove date.
- **How long**: 3 min, 5 min, 10 min, 15 min, 30 min, 45 min, 1 h, 1 h 30, 2 h or 3 h, or **No time**. Only there while **Use task times** is on in Settings.
- **Repeat**: every day, week, 2 weeks, month, 3 months or year. When you tick a repeating task, the next one appears below it with the next date. In the file this is `@repeat(weekly)`.
- **Make this the next action** (in a project): the task gets a `#next` tag and a badge, and Today lists it under "Next actions". One per project.
- **Block time for this…**: opens Time Blocks with the title filled in.
- **Rename…**: turns the line into a field. Type and press Return. The date, repeat, tags and subtasks stay, and so does the reminder it is linked to.
- **Move to**: the Inbox, any active project or any active area. Subtasks move along. The reminder follows on the next sync. You can also drag the task onto another note in the middle column.

You can also **drag** a task: onto a note in the middle column or onto Inbox to move it, onto a day in the Calendar's month grid or week list to set its date, or onto a day in the weekly note.

### Adding a task at the bottom of a note

The field says **Add a task…**. Type the words and press Return, or press the arrow.

The **ⓘ** beside the field opens the list of what else you can write in it: a date, a date and a
time, a priority, a tag, a repeat. Up to build 141 that list was the grey text inside the field,
where it was too long to read on the phone and disappeared as soon as you typed.

Beside it: **Snippet**, a ready-made block of tasks from Templates › Snippets, and on the phone
the **pencil** that turns writing on and off.

## The Inbox

Everything you capture lands here, and the screen is built for emptying it.

The middle column is the list of lines waiting to be sorted, with a capture field on top. Click a line to pick it, and four buttons appear: **Today**, **Tomorrow**, **Pick a date** and **File it**. The first three set the line's date, and the button for the date it already has is filled in and outlined in orange, so the four buttons also tell you where the line stands. **File it** is a menu: move the line to a project or an area, turn it into a note, block time for it, take the date off again, or delete it. To rename a line, right-click it on the Mac or hold it on the phone — the same menu opens there, with **Rename…** on it.

On the Mac the four buttons are in the right-hand column, under the line you are sorting and above the places it can go, so everything about one line is in one place. On the phone there is no right-hand column, so the buttons appear just under the line you tapped. On both, the line you picked keeps its ordinary colours and the other lines fade, so the one you are working on stands out.

### The keys

↑ and ↓ move down the list, **T** gives a line today's date, **M** tomorrow's, **D** ticks it off and **⌫** deletes it. Typing in the capture field never triggers them.

### Where it goes

The right-hand column shows the line you are on, the four buttons, and everywhere the line can go. Click a destination and the line moves there, and the next line is selected so you can keep going.

The destinations are grouped into **Projects** and **Areas**, with sub-areas indented under the area they belong to and a chevron to fold a family away.

## Reminders sync

The sync goes both ways. Press the sync button or ⇧⌘R, or let auto sync run at the interval set in Settings.

- Inbox tasks go to the Reminders list called Inbox.
- Each project and area gets a Reminders list with the note's name.
- Tasks in daily and weekly notes go to the Daily Notes list.
- Goals are never synced. They are direction, not to-dos.
- Completing, renaming, dating or deleting on either side carries over.
- If the same task changed in both places since the last sync, the note version wins and the sync report says so.
- Subtasks become separate reminders named "Parent › Child". Tasks with a time get an alarm.

Each device keeps its own sync bookkeeping, so the Mac and the iPhone can both sync the same vault.

### Seeing what a sync will do

The sync button is a menu. **Show me what would change…** rehearses the entire sync on a copy of your vault and a copy of your reminders and shows the result. Nothing is touched. From that sheet you can press **Sync now** to do it for real. **Last sync report…** shows the same for the sync you ran.

## Aspirations and Goals

There are **two rows in the sidebar**, because there are two different things.

**Aspirations** says what you are becoming. An aspiration has no date, because you never tick one off. It is the A in PARAGON. Press **Aspiration** at the top of the New note screen to make one.

**Goals** says what you will have done, and by when. A goal has a target date, a measure of what success looks like, and the aspiration it serves, chosen in the **Serves aspiration** box. Press **Goal** at the top of the New note screen.

A project or an area serves a goal with the `goal:` line. Press **Serves…** at the top of the project or area to choose the goal, or press **Add a project…** on the goal itself (see below). A goal note shows how many projects and areas serve it, open tasks, activity in the last 30 days, and flags such as "No project or area serves this", "Past its target date" or "Done".

Both are goal notes in your vault, so nothing was moved or rewritten. The line that tells them apart is `horizon:`, and it is the same line as before.

### Changing a goal's date and measure

The top of a goal says what it is: **Goal with a date** or **Aspiration**. After the name and the status come its buttons:

- **Serves…** — the aspiration a goal with a date serves. Press it to choose another one.
- **Set a target date…** — the day the goal should be reached by. When a date is set, the button shows it instead, for example **Target 2027-08-15**. Press it to change the date, or press **Clear** to take it away. Write the date as 2027-08-15 or pick it in the calendar.
- **Set a measure…** — one line that says how you will know the goal is reached, for example "All 440 km in 30 days". When a measure is set, the button shows it. Press it to change the words, write them, and press **Set** or Return. **Clear** takes the measure away.

An aspiration has **Set a measure…** but no date button, because an aspiration has no date.

If the measure was changed on your other device while the box was open, **Set** writes nothing the first time. The box stays open with your words in it, and an orange line says what the measure is now. Press **Set** again to use your words instead. **Clear** works the same way.

A new date changes the weekly review at once: "Past its target date" and "Due after its goal" are worked out from it.

On the Mac **Set a target date…** and **Set a measure…** are also on the goal's page in **Goals**, under its name, and an aspiration's page in **Aspirations** has **Set a measure…**. There they are small capsules: grey with a dashed line while nothing is set, and solid when something is. On the iPhone, **Set a measure…** is also under an aspiration when you open it in **Aspirations**.

### Adding a project from its goal

A goal can make the projects that serve it, and an aspiration can make the goals that serve it. You stay on the page you are on.

- Open a goal. Under the projects that serve it there is **Add a project…**. Press it, write the name, and press **Add project** or Return.
- The new project appears in the list at once, and it already serves the goal: its `goal:` line names the goal. Press it to open it. Press **Add a project…** again for the next one.
- On an aspiration the button is **Add a goal…**, and the box has **Add goal**. The new goal serves the aspiration. It has no target date yet: open it and press **Set a target date…**.
- An aspiration makes a goal, never a project. The work then goes under that goal, which is the step that gives it a date.
- When nothing serves a goal yet, its note says "Nothing serves this goal yet." and shows the same button under it. On the Mac, the goal's page in **Goals** says "No project delivers this goal yet." in orange when no project serves it, and the button is at the foot of that list. An aspiration with nothing under it says "Nothing works towards this yet."
- If a project or goal with that name is already there, the box says so in orange and keeps your words. Change the name and press **Add project** or **Add goal** again.
- **Cancel** closes the box and makes nothing.

An area has **Add a project…** too, beside **Projects in this area** at the top of the area; see **An area's page**.

Where the button is: at the foot of a goal's own note, on the Mac and on the iPhone. On the Mac it is also on the goal's page in **Goals**, under its projects, and on an aspiration's page in **Aspirations**, under its goals. Inside an aspiration's chain, a goal with no project yet has **Add a project…** under the orange line that says no project delivers it. On the iPhone, **Add a goal…** is also under an aspiration when you open it in **Aspirations**.

### When you last looked at it

At the top of an aspiration, a goal with a date or an area, a grey button with an eye says when you last looked at it: **Looked at 12 days ago**, or **Never looked at**.

- Press it. A small box says how often that kind of note gets a look, and when the next look is due, for example "Goals with a date get a look every 3 months. The next look is due in 78 days."
- Press **I looked at it today** in the box. PARAGON writes `reviewed:` with today's date into the note's settings block, and the button says **Looked at today**.
- When the note already says today, **I looked at it today** is grey, because pressing it would change nothing.
- The same **I looked at it today** is on the right-click menu of a row in **Aspirations**, **Goals** and **Areas**. On the iPhone, press and hold the row.
- On the Mac the button is also on an aspiration's page in **Aspirations** and on a goal's page in **Goals**, under the name. There it is a small capsule, with a dashed line while the note has never been looked at.
- It is the same date the **Weekly review** reads, so the note leaves **Due for a look** until it is due again. How often each kind gets a look is set in **Settings › Review rhythm**.
- A goal or an area that has ended, or is archived, has no button: it no longer comes up for a look.
- Projects do not have the button. They get a look every week, in step 5 of the **Weekly review**.

### How a note stands

Press the button in a note's header to say how it stands. A project or a goal can end in three
different ways, and the difference matters:

- **Done** — finished, and it did what it was for.
- **Missed** — it is over and it did not happen. A date passed, or you decided it had not worked.
- **Dropped** — you decided not to do it. Nothing failed; you called it off.

**Only Done counts towards a goal's per cent.** A missed or dropped project is left out of the sum
altogether: counting it as finished would be untrue, and counting it as nothing done would hold the
goal below full for ever.

**The day it ended is written down.** When you mark a project or a goal Done, Missed or Dropped,
PARAGON adds `ended:` with today's date to its settings block (frontmatter). The line goes at the
end of the block. A finished project then shows one grey line under its coloured band: **Done on
21 October · after 41 days · 17 tasks finished**. "After 41 days" counts from the `created:` line,
which every new note has had from the start; "17 tasks finished" counts the ticked top-level tasks.
A part PARAGON cannot know is left out.

- **Press the line to change the day.** Type it or pick it in the calendar.
- Changing from one ending to another (Done to Missed) **keeps the day**. **Set active** or **Put
  on hold** removes it, because the project is not over any more.
- **A project marked done before build 262 has no day.** PARAGON never guesses one: the line then
  says **Set the day it ended…** in a dashed grey frame, and you can press it if you remember.

Anything that has ended leaves the working lists — the weekly **Review**, the next actions, the
**Map**, and the list of notes you can move a task into. On the **Goals** screen it drops into a
closed group at the foot named after the ending.

The other two words are **Active** (you are working on it) and **On hold** (not now, but not given
up). The weekly **Review** offers the same choices when you right-click a project.

Older words still read as they always did: `achieved` and `completed` mean Done, and `paused` and
`someday` mean On hold. Nothing in your notes was rewritten.

### What is next for this goal?

When you mark a project **Done**, **Missed** or **Dropped**, PARAGON looks at the goal the project worked for. If nothing else is working on that goal, a short question comes up on the screen you are on. It does not matter whether you marked the project in its own note, in **Projects** or in the weekly **Review**. The question reads **What is next for this goal?**. Under it, one sentence says: Nothing is working on "(the goal's name)" now. It has up to three buttons:

- **Add a project…** opens **New Note** on **Project**. The goal is already chosen in the button that otherwise says **Serves a goal…**. Write the name and press **Create**.
- **Mark the goal done** is there only after **Done**. It marks the goal itself Done, with its own day, and a short message at the bottom of the window says so.
- **Not now** closes the question and changes nothing.

When the question comes, and when it does not:

- It comes only at the moment a project goes from working to over. Changing **Done** to **Missed** does not ask again. A project in the **Archive** does not ask.
- "Nothing is working" means no project and no goal with a date is still running under that goal. A project that is **On hold** is still the goal's project, so no question comes. An area does not count: an area keeps a standard, it does not deliver a goal.
- If the goal has itself ended or been archived, nothing is asked.
- While notes are still coming from iCloud, or iCloud is updating some, nothing is asked. PARAGON cannot know yet that nothing else works on the goal, and a wrong answer could lead you to mark the goal done. The goal's own page still has **Add a project…**.
- If you mark several projects one after another in the **Review**, the question comes once for each goal that is left with nothing.
- An aspiration is never finished. If a project that serves an aspiration directly ends and nothing else works towards it, the question reads **What is next for this aspiration?** and the buttons are **Add a goal…** and **Not now**. There is no **Mark the goal done** for an aspiration.
- Marking a goal Done with **Mark the goal done** does not start a second question about the aspiration above it.
- A reminder that you press while the question is on screen opens when you have answered it.
- After **Not now**, the goal's own page still has **Add a project…** (see **Adding a project from its goal**).

### The Aspirations screen

The **Aspirations** row lists your aspirations, one after another. Choose one and everything
working towards it appears beside it, in order:

- the **goals with a target date** that serve it, soonest first;
- the **projects** under each goal — finished ones struck through;
- the **next action** on each project. **No next action** in orange means there is nothing on
  that project you could start.

**Add a goal…** under the goals makes a new goal that serves the aspiration, and **Add a project…** under a goal with no project yet makes a project for it. You stay on the aspiration.

Each row says how many goals serve it, **when you last looked at it** ("Looked at 12 days ago",
or "Never looked at"), and a mark in orange when one of its goals needs attention. An
aspiration with nothing under it yet says **Nothing serves this yet** on its own row.

Right-click a row (press and hold on the iPhone) for **Open the note** and **I looked at it today**.

**There is no per cent on an aspiration, and that is deliberate.** You never finish one, so a
figure would be a promise the idea does not make. Each goal under it keeps its own bar, where
the number is true.

### The Goals screen

The **Goals** row lists **every goal that has a target date**, whether or not an aspiration
holds it. You do not have to choose anything first. Three groups, in this order:

- **Needs a look** — the goals the weekly review has something to say about: past their target
  date, nothing serving them, no next action. It is where to start, not a fault list.
- **By date** — the rest, soonest first.
- **Done**, **Missed** and **Dropped** — closed, with the count on the heading. Press a heading
  to look back.

A goal with no aspiration above it carries a **Give it an aspiration** button. Right-click any
row (press and hold on the iPhone) for the same list, with **Open the note** and
**I looked at it today** above it.

Every link in the chain has its own icon: an **aspiration** is a **star** — the north star on
PARAGON's own app icon, what you steer by and never tick off — and a **goal with a target
date** is a **target**, what you aim at and hit on a day. A **project** is a flag, a **task**
is a ring, and an **area** is the four squares. They are the same icons the sidebar uses: the
row named **Aspirations** carries the star, the row named **Goals** carries the target, and the
star is used for one thing only in the whole app — an aspiration. A note's own header shows
which of the two it is, with the icon and in words: **Aspiration** or **Goal with a date**.

They also have their own colours: an **aspiration is a deeper gold** and a **goal with a date**
is the lighter gold the Goals list has always used.

A goal with no aspiration above it is marked in orange and carries a **Give it an aspiration**
button, which opens the list of your aspirations. Nothing is wrong with such a goal — it is a
loose end, not an error — but the chain only works when each link points at the next.

Each row shows its **measure**, its **target date with how long is left** ("in about 3 months",
or "11 days over" in orange), and a **mark when it needs attention** — the same checks the
weekly **Review** makes, so the two screens agree.

A goal that has ended leaves the live lists and gathers at the foot under the name of its
ending — **Done**, **Missed** or **Dropped** — closed, with the count beside it. Press the
heading to look back. Inside an aspiration the same groups sit below the live goals.

A goal or aspiration also shows **what changed lately**: tasks finished in the last 30 days,
how many projects are finished, and when something last moved. When nothing can be counted the
line is not shown at all.

**All of them.** The button at the top right of the **Aspirations** screen opens every
aspiration at once, as one outline: each aspiration, the goals that serve it, the projects under those, and
the next action on each. Goals with no aspiration are at the foot, so nothing is missing. Press
it again for one at a time. On the iPhone the same button opens every row; tapping one row
closes the rest.

The **Note** button at the top of the column shows the goal's own text instead of the chain.
Press it again to go back. On the iPhone there is no second column, so an aspiration folds open
where it stands. Type in the search field and the ordinary note list comes back.

### How far a goal has come

Every goal with a target date shows a bar and a per cent, on its own page, in the Goals list and on its row in **Weekly review**. The figure is worked out from the projects under the goal. You never type it in.

Every project counts the same, whatever its size, so a project with forty small tasks does not drown one with three big ones.

- A project marked **done** counts as a whole one.
- A project still running counts as the share of its tasks that are ticked. Sub-tasks and cancelled tasks are left out, and so a project with no tasks yet counts as nothing done.
- The goal's figure is the average of its projects.

**Areas are not counted.** An area is something you keep up, not something that finishes, so counting one would hold its goal below full for ever.

**An aspiration has no bar of its own.** You never finish one, so there is nothing for a per cent to mean. Each goal under it has a bar, and that is where the figure belongs.

**No bar at all means there is nothing to measure yet** — no project under the goal. That is not the same as nought per cent, so the app draws nothing rather than an empty bar.

The per cent never says 100 until everything really is finished, and never says 0 once something has moved.

## Today, Calendar, daily and weekly notes

- **Today** shows the day's calendar events, one next action per active project, overdue tasks, tasks due today, and undated tasks marked `!!` or more. The events are kept short here — one line each, with the place after the name — because they share the screen with everything else. Press the word **Calendar** in that heading to fold the events away; the number beside it still says how many there are, and pressing it again brings them back. Under the events, a short heading says **Today's note** with a small button beside it: **Create** while there is no note for today, **Open** once there is. The day's date is a small grey line at the very top, under the title. The **Overdue** heading carries two small buttons: a **sun** moves every overdue task to today, a **sunrise** moves them all to tomorrow. They are the same two pictures the Inbox uses for those dates. One press does the lot. Nothing is deleted and nothing is asked first — the tasks are all still there, and a short message says how many moved. Beside the date at the top are **Start the day** (an orange cup) and **Close the day** (a lilac moon): the morning step and the evening step. They are pictures only; on the Mac, hold the pointer over one and its name appears.

- **Now and Then** on **Today**: on a day with a plan, two short lines under the date say where you are in it. The first starts with **Now** and names the plan block you are in, for example **Now 09:30 – 11:00 Write the offer**. On its right is a small orange button with a clock. Press it and the focus timer starts on that block, and the bar appears at the bottom, as usual. If exactly one open task has the same name as the block, the timer can tick that task off when you stop it (see **The focus timer**). While the focus timer runs on that block, a small dot is shown in place of the button: orange while the clock runs, grey while it is paused. The dot also shows when the clock runs on a task with the same name as the block, such as the task the block was made from. The second line is grey and starts with **Then**: the next block and when it starts, for example **Then 11:00 Call Anna**. It has no button. The lines change by themselves when a block starts or ends. When nothing is on now, only the **Then** line is shown. When the day has no plan, or the last block is over, nothing is shown, and **Today** is as short as before. Only plan blocks are shown here; your calendar events are under **Calendar** further down. On the Mac, hold the pointer over the clock button and its name appears.

- **Start the day** shows what is overdue, what is due today, and your next actions. At the top are three things you already know this morning:
  - **Last evening you wrote**: the line you wrote yesterday in **Close the day**, under **How was today?**. If you wrote nothing, this part is not shown. If yesterday's note is still coming from iCloud, an orange line says so. The line belongs to the day on which you pressed **Done**: if you close the day after midnight, it goes into the new day's note, and the next morning nothing is shown here.
  - **This week:** and the goal for the week, the same line as on **Today**. It is not shown when no goal is written. If this week's note is still coming from iCloud, an orange line says so. You write the goal on **Calendar › Week**.
  - **Today's calendar events**, one short line each, with the number in the heading. Press the heading to fold them away, and again to open them. The iPhone and the Mac each remember this on their own. If Calendar access is off, the message that says so is never folded away. When **Show the day's events in Today and in daily notes** is off in **Settings › Apple Calendar**, this part is not shown.
- Under those three things there is a field, **Add an action for today**, with a **+** beside it. Type something that came to mind and press **+** (or Return). It goes to the Inbox, dated today, and appears in the list already picked. The field stays ready for the next one. If you type your own date, for example `>2026-10-02`, that date is kept, and the action is saved to the Inbox but not shown in today's list. On the iPhone, drag the list down to put the keyboard away.
- In **Start the day**, press **Pick** at the left of the two or three that matter most (the round circle after it marks the task as done, as everywhere else), then press the button at the bottom (it says **Plan 2 actions**, for example). Each one goes into today's plan as a block as long as the task's own time, or one hour when it has none, in the free time left today: after the time it is now, and never on top of a block you already have or a calendar event. Nothing is placed after midnight; if not all of them fit, a message says how many did. An action already in today's plan says **In the plan at** and the time in place of **Pick**. The blocks are ordinary plan blocks — move them or make them longer on **Plan**. With nothing picked, the button says **Done** and only closes.
- **Morning reminder.** In **Settings › Morning reminder**, turn on **Remind me to start the day** and choose a time (07:30 unless you change it). PARAGON then sends one notification every morning at that time: "Start the day. What matters most today? Pick it and put it in your plan." Press it and **Start the day** opens. On the iPhone the keyboard does not come up by itself, so you see the whole list first. It comes every day, at the weekend too, because your leisure tasks are in PARAGON as well. Turn the switch off and it stops.
- **Evening reminder.** In **Settings › Evening reminder**, turn on **Remind me to close the day** and choose a time (21:00 unless you change it). PARAGON then sends one notification a day at that time. Press it and **Close the day** opens. Turn the switch off and it stops.
- **Both reminders work the same way.** The first time you turn one on, the iPhone or the Mac asks whether PARAGON may send notifications. That one answer is for both reminders and for the focus timer. Under the time, Settings says when the next reminder will come, for example "Next reminder: tomorrow at 07:30". If no reminder can come, it says why in orange and where to change it. Each part has its own **Send one in 10 seconds**, which sends the same notification once, so you can try it now. Press that notification and the same screen opens as from the real one. Below the button it says what happened: when it was sent, and 15 seconds later whether the iPhone or the Mac delivered it. The iPhone and the Mac each have their own switches and times. A Focus mode, such as Do Not Disturb, can hold a notification back, and PARAGON cannot see that.
- **When you press a reminder and a screen is already open.** If it is the same screen, it stays as it is, with what you typed in it. If another screen is open, such as **New Note**, nothing is closed and nothing you typed is lost: **Start the day** or **Close the day** opens as soon as you close that screen. If the focus timer's question is open, or the question **What is next for this goal?** is on screen, it opens after you have answered it. On the Mac, if the main PARAGON window is closed, it opens when you next open the main window. The Settings, Help and **Plan the day** windows do not open it.
- **Close the day** is one page you work down and finish. From the top:
  - **Did not happen**: everything still open that was due today or earlier. Each has a
    **Tomorrow** button and a **Day…** button for another date, and **Move all to tomorrow** is
    under them. These are real tasks, so you can tick one off if you did it after all. Tasks
    with no date are not here, because a task that was never promised to today did not fail
    to happen.
  - **Tomorrow's calendar events**, with tomorrow's date, then **Waiting for tomorrow**:
    everything dated tomorrow (including what you just moved there) and a few next actions. Press **First** at the left of the
    ones that should come first. That only marks them: in the morning, **Start the day** shows
    them first in its list, above **Overdue**, under **Marked first last evening**. No block is made. Press **First** again
    to take the mark off. The marks are kept in the vault, so a mark made on the iPhone is also
    there on the Mac.
  - **How was today?**: one line, kept in that day's daily note under a heading called
    **Looking back**. It is ordinary text: nothing counts it and it never becomes a task. The
    next morning, **Start the day** shows it under **Last evening you wrote**, and step 7 of the
    **Weekly review**, which looks back at a whole week, shows it again, and so does that day's
    card in **Done**. Clear it and the heading goes too.
  - **What you did today**: how many tasks you finished, and what they went towards — an
    aspiration, a goal, an area, or the project itself — with how many for each. The names of
    the tasks are on the **Done** screen.
  - **Planned and worked**: a small table with three columns, **Task**, **Planned** and
    **Worked**, and **All of today** at the bottom. **Planned** is the length of the block in
    **Plan the day**. For a task you worked on without a block, it is the task's own time, such
    as **45 min**. **Worked** is what the focus timer wrote under **Worked** in today's note. A
    time worked that is longer than the time planned is orange and bold. A dash means there is
    nothing to show: no block and no task time, or the timer was not used on it. Blocks and work
    are put on one row by their name. A block made by **Start the day** has the same name as the
    work on that task, so they meet on one row. If you change the name of the block or of the
    task afterwards, also by adding a tag, they show on two rows, and **All of today** counts the
    planned time of both. If two tasks have the same name but different times, neither time is
    used. With **Use task times** off, a task's own time is not used here. A timer that is not
    stopped yet is not in the table: its time is added when you stop it, and a line under the
    table says so.
  **Done** saves the line; **Cancel** does not — but the tick boxes, **Tomorrow**, **Day…** and
  **First** save as soon as you press them.
- **All actions** lists every open task in the vault, grouped by its note. Tick boxes at the top narrow the list: **When** (Overdue, Today, Next 7 days, Later, No date), **Mark** (Next action, Important) and **Tags**. Boxes in the same row mean "any of these"; boxes in different rows are all required together. The heading counts what is shown, **Clear** unticks everything, and the button beside it folds the boxes away. While they are folded the line under the heading says what is ticked, so the list is never quietly narrowed.
- **Done** is a diary of the last 12 weeks: this week and the 11 weeks before it, each from Monday to Sunday. The newest day is at the top. The line at the top says how many tasks you finished this week and in the 12 weeks, for example **6 done this week · 212 in 12 weeks**. It is not shown until a finished task carries a day. Under it, **Last 12 weeks** shows one small square for each day: each column is one week, with Monday at the top and this week on the right, and the names of the months above the columns. The stronger the colour of a square, the more tasks were done that day; a grey square means nothing was ticked off. A day whose note is still coming from iCloud has an empty square with an orange dashed edge, and it says so: that day may not be empty, its note is just not here yet. The days still to come this week have no square, and nor do the days before you first ticked off a task with a day: for those the notes cannot say. Today's square has a frame around it. On the Mac, hold the pointer over a square to see its day and how many tasks were done. Press a square to go to that day in the list below; only a day that is listed can be pressed. Press **Last 12 weeks** to fold the squares away, and again to bring them back. The iPhone and the Mac each remember this on their own. Each day starts with a small card:
  - The day's name, for example **Today**, **Yesterday** or **Tuesday 14 October**.
  - A grey line with how many tasks you finished and the time on the focus timer, for example **6 done · 2 h 40 min worked**. When the timer was not used that day, no time is shown.
  - The line you wrote that evening under **How was today?** in **Close the day**, beside a lilac moon.
  - Small labels for what the work went towards: an aspiration, a goal, an area, or the project itself, each with how many tasks. Tasks ticked in that day's own daily note share one label, **Daily note**. A weekly note, or an earlier day's note, keeps its own name, for example **Week 43, 19 Oct – 25 Oct 2026**.
  - Under the card are the tasks you finished that day. Press one to open the note it came from.
  - A day when you ticked nothing, but wrote a line in **Close the day** or used the focus timer, is listed too. Its grey line says **Nothing ticked off**.
  - A task counts on the day in its `@done(…)` stamp. A task ticked with no stamp has no day, so it is not listed here.
  - If a day's own note is still coming from iCloud, its card says **Still coming from iCloud** in orange, in place of the evening line. That line and the timer time are in the note, so they show when it arrives. On the iPhone an orange line at the top of **Done** also says that notes are still coming. When nothing is listed while notes are still coming, **Done** says so instead of saying there is nothing.
- **Calendar** lets you pick a day, week or month. The day view can show a month grid with week numbers and a dot under every day that holds something — green for tasks due, red if one is overdue, blue for calendar events, grey for a day that already has a note. Under the grid is the day itself: its events, what is due, what got done, and a button to open or create the daily note. The grid is off to begin with, because the day itself is what the screen is for: press the **calendar** button in the day's top row to show it, and press it again to put it away. The button is lit while the grid is showing, and the app remembers your choice. Move with the arrows, the Today button, or the left and right arrow keys. Drop a task on a day to give it that date.
- **Calendar › Week** is where you plan a week. At the very top is **Goal for this week**:
  one line that says what the week is about. When the arrows move to another week, the box
  says so: **Goal for next week**, **Goal for last week**, **Goal for week 45**. Press the box, write the line, and press Return
  or **Done**. An empty box is grey and dashed; a written goal is gold. Save an empty line to
  remove the goal. It is kept in the week's note as `focus: …`, and **Today** shows it in one
  line under the date. Below the goal is **To place**: every open task
  with no date yet, next actions first, drawn as dashed tiles. Under it is a row of seven small
  cells, one per day, each with the number of tasks due on it — today's cell is marked. Under
  the number is the total of their task times, for example **2 h 30**; a task with no time
  adds nothing. **Drag a
  tile onto a cell** and the task gets that day. You can drag onto a day's heading further down
  as well, and you can drag a task from one day to another the same way.
  The tray shows the first twelve and says how many more there are. It is not drawn at all when
  nothing is waiting. A task written in a daily note is never in the tray: it is already on that
  day by being there.
  The quickest way in is the **Week** button at the top of the **Plan** screen.
- A daily note shows the day's events and the tasks due that day above its own text. A weekly note shows all seven days as a plan: drop tasks onto a day, tick them off there.

## Apple Calendar and Time Blocks

The app reads events from the calendars you choose in Settings › Apple Calendar. Events appear in Today and in daily notes. Double-click an event, or use its arrow button, to open it in the Calendar app.

The Calendar section shows the day's schedule in the right-hand column: hours down the side, events in place, your time blocks on top, a line for the time it is now, and a strip at the top for all-day events and tasks with no time. Press "Block time" or double-click an hour to reserve time; click a block to change or delete it; drag a task onto an hour to block that hour for it. The switch at the top of the column swaps between the schedule and the daily note.

### Plan the day

There is a second kind of block, and it is the opposite of a Time Block: it stays inside
PARAGON. It is what the **Time Blocks** section shows. **Go › Plan the Day…** (⇧⌘P) on the
Mac opens the same thing in a window of its own, which can stay up while you work in a note.

On today, a slate blue line and dot cross both lanes at the time it is now, and move as the day goes on. It is the same line the Calendar section's day view draws. The colour is its own on purpose: every other colour in PARAGON means a kind of note or a warning, and the time of day is neither.

The screen has three parts:

- **Actions** in the middle column: what is due that day, then your next actions. Each row is a
  real task: tick the circle to finish it, right-click (long-press on the iPhone) for the task
  menu, and press **+** to make a block for it. Under each one is what it serves — the goal its
  note belongs to, in gold, or the area it sits in, in pink.
- **Calendar** on the right: what is already booked that day, read from Apple Calendar.
- **Time blocks** beside it: your own blocks. They hang on the same hours as the calendar, so
  you can see whether a block lands inside something already booked. Two things at the same
  time stand side by side at half the width, so nothing is hidden behind anything else. **Drag an
  action from the Actions column onto an hour here** and it becomes a block of one hour at that
  hour, named after the task. Nothing is asked first: drag its edge to make it longer, or
  right-click it to remove it. The task keeps its own tick box in the Actions column — a block
  says when you mean to do the work, it does not do the work.

On the iPhone the parts are one page instead. At the top, above the hours, the actions are
shown again as small dashed tiles under **Actions**, and they stay there while the hours scroll
under them. **Scroll to the hour you want, hold a tile, and drag it onto that hour** in the
**Time blocks** lane. Up to six tiles are shown; the line beside the heading says how many more
there are. The full **Actions** list is still at the foot of the page, below the evening, for
ticking a task off, the task menu and the **+** button (which makes a one-hour block at the next
free hour). Tap a block to change its time. A short event or block — under about three quarters of an hour — is drawn on one line,
with its start time and its name.

The **Week** button at the top of the day opens **Calendar › Week**, where you spread work
across the seven days. The **calendar** button beside it leads to the other kind of block, the
ones that are real events in Apple Calendar.

**On the Mac you can drag a block.** Pick it up and slide it up or down to move it in time; it
snaps to five minutes and shows its new time as you go. Drag the small **grip** at the foot of a
block to make it longer or shorter. A click without moving opens the block instead. On the
iPhone a block is tapped, not dragged — the lane sits inside the page's scroll.

Opening a block gives you its name, a time field with **−** and **+** for quarter hours, and a
row of lengths to press. The line underneath says what it comes to, for example
**09:30 – 11:00 · 1 h 30 min**. Right-click a block (long-press on the iPhone) for **Remove**.
The arrows at the top of the day move a day at a time.

**A block is only for you.** It says where you mean to be, or what you mean to work on. It
never becomes a task, and nothing outside the app sees it — unless you ask for one to, which is
the next part.

**Putting one block into Apple Calendar.** Right-click a block (long-press on the iPhone) and
tick **In Apple Calendar**. The same tick is in the block's sheet, as **Also put this block in
Apple Calendar**. The event goes to the calendar under **Settings › Apple Calendar › Time
blocks go to**.

- A block that is also an event has a small **calendar** symbol beside its time.
- Change the block's name, its time or its length and the event follows it.
- Take the tick off, or remove the block, and the event is deleted.
- This is per block. Every other block stays inside PARAGON.
- If you edit a block's line **by hand** in the daily note, the app can no longer tell which
  event belonged to it. The event is left where it is rather than deleted; you can remove it
  from the **Blocks in Apple Calendar** list.

**Where the blocks are kept.** In that day's daily note, under a heading called **Plan**:

```
## Plan

TB: 09:30-11:00 Deep work on the IM plan

TB: 13:00-14:00 Pack for Granden
```

**One block per row, with a blank line between them.** In markdown, two lines written under
each other with nothing between them are one paragraph, and any reader — this app's own
**Read** mode included — draws them joined on a single row. The blank line is what keeps each
block a row of its own, here and in every other editor.

So they sync like everything else, and you can read and correct them by hand in any editor. If
the daily note does not exist yet, the first block makes it. In **Read** mode a plan line is
drawn as a block in its own orange, not as ordinary text.

Time Blocks are the one thing the app writes to Calendar. They are blocks of time you reserve, separate from tasks. Add one in the Time Blocks section: it becomes an ordinary event in the calendar chosen under "Time blocks go to", and shows on all your devices. Click a block to edit it, right-click (long-press on the phone) to open it in Calendar or delete it. Nothing else in your calendars is ever changed.

## The focus timer

A clock you start on one task while you work on it. When you stop it, the time goes into
today's daily note, so you can see later how long things really took.

### Starting it

- Press the **time?** button on a task (or its time, such as **45 min**) and choose **Focus on
  this** at the bottom of the list. Or right-click the task (press and hold on the iPhone) and
  choose **Focus on this**, the first line of the menu.
- A block in **Plan the day** has **Focus on this** on its right-click menu too. If exactly one open task has the same name as the block, the clock also belongs to that task, so you can tick it off when you stop. See **A clock on a block** below.
- On **Today**, the line that starts with **Now** has a small orange clock button. It starts the focus timer on the plan block you are in.
- **Focus on this** is not offered inside **Start the day** and **Close the day**, nor in the
  Mac's separate **Plan the day** window (⇧⌘P), because the bar cannot be seen there. Nor is it
  offered on a task in a work note.
- Only one clock runs at a time. Starting a new one stops the one running and writes its time
  down first, as not done. A clock that had run for more than 12 hours is stopped without
  writing anything: it was almost certainly left running.

### While it runs

A bar shows the task and the time: "23:14 of 45 min" when the task has a time, or just "23:14".
It is dark on a light screen and light in dark mode, with a small orange dot (faded while
the clock is paused). On the iPhone it sits above the tabs on every screen, and steps aside while
the keyboard is up. Starting a clock puts the keyboard away, so the bar shows at once. On the
Mac it sits at the foot of the window. It has two round buttons:

- The **pause** button (two bars) stops the clock; it then shows a triangle, which goes on.
  Paused time is not counted.
- The **stop** button (a square) ends it and asks one question.
- The clock keeps going when PARAGON is closed or the device sleeps. It works from the time it
  was started, not by counting, so it is right when you open the app again. Each device has its
  own clock: one started on the iPhone does not show on the Mac.

### When the planned time is up

When the task has a time, such as **45 min**, or the clock runs on a block from **Plan the
day**, one notification comes when that much work time has passed. It comes even when PARAGON
is closed, with the ordinary notification sound, once. When **Use task times** is off in
Settings, no task has a time, so no notification comes for a task.

- Paused time does not count: a pause moves the notification later. Going on after the time is
  up brings no second notification.
- The clock does not stop by itself. Press the stop button when you are done.
- It is the same permission as the morning and evening reminders. If you have already answered
  that question, nothing is asked. If PARAGON has never asked, it asks the first time a clock with a
  planned time starts.
- If notifications for PARAGON are turned off, or set to **None** (**System Settings ›
  Notifications** on the Mac, **Settings › Notifications** on the iPhone), none appears. PARAGON
  then says so at the foot of the screen, once each time you open PARAGON.
- When you press stop, or start a clock on another task, a notification still shown in
  Notification Center is taken away.

### In the Mac menu bar

While a clock runs, the Mac's menu bar shows it on the right, among the small icons there: a
small orange dot and the time, for example "● 23:14". While the clock is paused, a pause sign
(two small bars) takes the dot's place, in the same colour as the time. It is there whatever **Show capture panel in the menu bar** says; that setting is only about
quick capture. To put it next to the clock, hold ⌘ and drag it there. It stays there the next
time.

Click it for a short menu: the task, how long you planned (when the task has a time),
**Pause** (or **Go on**), **Stop…** and **Show PARAGON**.

- **Show PARAGON** brings the PARAGON window forward, also when it is in the Dock or PARAGON is
  hidden. If you have closed the window, it opens a new one.
- **Stop…** does the same, because the question is asked in that window. After **Stop…** the
  pause sign and the time stay until you answer the question. Then they go away.
- While the question is open, **Pause**, **Go on** and **Stop…** are grey and cannot be pressed.
  If a reminder is pressed then, **Start the day** or **Close the day** opens after you have
  answered the question.
- If another screen is open in PARAGON, such as **New Note** or **Close the day**, **Stop…**
  stops the clock but does not close that screen. The question comes when you close it.

### Stopping it

PARAGON says how long you worked, for example "You worked 52 minutes on Write the offer for the
shed. You planned 45 min." Then:

- **Done, tick it off** ticks the task in its note. If the task can no longer be found there —
  renamed, moved or already ticked — the time is still saved and nothing else is ticked.
- **Not done yet** leaves the task open. For a block from **Plan the day** that belongs to no task, this answer is called **Save the time**, and there is no **Done, tick it off** (see **A clock on a block** below).
- **Don't save the time** writes nothing, for a clock that was left running by mistake.

The first two write the time into today's daily note under a heading **Worked**, one line for
each stretch between pauses:

```
## Worked
- 08:02-08:54 Write the offer for the shed
- 09:05-09:15 Call the bank
```

The heading is made the first time, above **Looking back** when that is there. PARAGON only adds
lines; a line you change or delete by hand stays as you left it. Each stretch is rounded to whole
minutes, so the lines add up to what the question said. A stretch under half a minute is no
line, so when no stretch reached half a minute nothing is written and nothing is asked. A
stretch that runs past midnight is written on both days. If the time cannot be written, the
question says why and the clock is kept, paused, so you can try again later. Opening another
vault folder, or closing the vault, writes a running clock's time first; if that cannot be done,
the vault is not changed. In **Read** mode these lines are
drawn as an ordinary list, not as plan blocks. In the evening, **Close the day** shows them
beside what you planned, under **Planned and worked**.

### A clock on a block

A clock started on a block from **Plan the day**, from the block's right-click menu (press and hold on the iPhone) or from the clock button on **Today**, can belong to a task too.

- It belongs to a task when exactly one open task has the same name as the block. That is usually the task the block was made from, for example by **Start the day**.
- Then the question after stop is the same as for a task: **Done, tick it off** and **Not done yet**. **Done, tick it off** ticks that task in its note.
- Big and small letters and extra spaces do not matter, and `#next` is left out, as on the block itself. Another tag does matter: a block called "Write the offer" does not belong to the task "Write the offer #work".
- A task dated after the block's day does not count, such as the next copy of a repeating task. Neither does a task with no date in a later day's daily note, nor a task in an archived note.
- If no open task has the block's name, or two or more do, PARAGON cannot tell which one to tick. Then there is no **Done, tick it off**, and the answer that writes the time is called **Save the time**.
- While notes are still coming from iCloud, PARAGON cannot be sure no other task has the same name, so the clock belongs to the block alone, and the answer is **Save the time**.
- Either way the line under **Worked** carries the block's name, so **Planned and worked** in **Close the day** shows the block and its work on one row.

## Weekly review

The review is a walk you do once a week, in order, from the top of the screen down.

### What the top of the screen says

Today's date, then one line saying how many tasks you finished in the last seven days. Under that, one orange capsule for each thing that wants looking at: overdue tasks, projects needing attention, goals needing attention, items waiting in the Inbox, notes due for a look, projects that serve no goal.

**When there is nothing to look at, one green capsule says so.** That matters: a row of zeroes reads as if the app had failed to count, and it is easy to miss that a week was simply a good one.

### Every part folds

Everything under the summary folds away: **Due for a look**, steps 1 to 8, and **Projects with no goal**. The first time you open the review, every part is folded, so you see the summary and one short heading for each part. Press a heading to open that part, and press it again to fold it. PARAGON remembers what you opened. The iPhone and the Mac each remember this on their own.

**A folded heading still says how much is in it.** "2. Reschedule or drop overdue tasks · 3" means three overdue tasks are waiting inside. When a part has nothing in it, the heading has no number at all, never a 0; open it and it says so in words, such as "Nothing is overdue". Steps 7 and 8 have no number: there is no list in them to work through.

Under the summary is one button for all of them: **Open all** while any part is folded, **Close all** when every part is open.

### Due for a look

Under the summary is **Due for a look**: everything whose review rhythm has come round. Its heading says how many notes are due.

Each level of the chain is on its own rhythm, because they do not change at the same speed:

| Level | How often | Why |
| --- | --- | --- |
| Aspiration | every 6 months | What you are becoming changes slowly. More often makes it feel like a task. |
| Goal with a date | every 3 months | Is it still what you want, and is anything delivering it? |
| Project | every week | Live work, looked at with the rest of the weekly review. |
| Area | every month | No finish line, so the question is whether the standard is still being kept. |

All four can be changed under **Settings › Review rhythm**, where each one is a row of named lengths — every week, every month, every 6 months — rather than a count of days. The project one is the same setting the review has always had, so there is one number for it, not two.

Each row says which level the note is, when you last looked at it, and how far past the rhythm it is. A note nobody has ever looked at says **never looked at**, with **due now** on the right, and is always at the top — that is not the same as "looked at a very long time ago", and the app does not pretend it is.

Press a row to open the note with the review still beside it. **Right-click a row** (long-press on the phone) for **I looked at it today**, which writes `reviewed:` with today's date into the note and starts that note's rhythm again; the row then leaves the list. The line under the heading says so, so the menu is not something you have to know about. Because it is written into the note, both devices agree and it is in your backups. The same button is at the top of an aspiration, a goal or an area; see **When you last looked at it**.

Work that is over is never asked about: a project you dropped, a goal you missed, anything archived. A review is a question about work you are still doing.

### The steps

Every step's heading is always on screen, even when the step is empty. Open a step you have finished and it says "Inbox is empty" or "Nothing is overdue" rather than disappearing. A step that vanished was impossible to tell from one the app had decided not to show you.

1. **Empty the inbox.** How many loose items are waiting. Press it to go to the Inbox and file them.
2. **Reschedule or drop overdue tasks.** Every task whose date has passed, with the note it lives in. Tick it, move it, or drop it, straight from the row.
3. **Read the aspirations again.** One row per aspiration — what you are becoming, with no date. Is each one still true?
4. **Check the goals with a date are on course.** One row per goal with a date: how far the work under it has come, how many projects and areas serve it, and its flags.
5. **Give every project a next action.** One row per active project, with its flags, the open and overdue counts, and when you last looked at it. **I looked at all of them** in the heading stamps today's date on every one. It is there while the step is open.
6. **Look over the areas.** The same row for each area, with its Standard under its name: "Standard:" and the first sentence of what you wrote. When none is written, a dashed grey **No standard written yet** says so. Write or change it on the area's page. The point of the line is to check the area against it.
7. **Look back at last week.** A whole week, from your own notes, and a box where you can write one line about it. The heading names the week the step shows: **last week** on Monday and Tuesday, **this week** from Wednesday, and the week's number, such as **week 41**, when you press **‹** further back. See below.
8. **Write the goal for the week.** One line for the week you are about to work in: on Monday and Tuesday the week you are in, from Wednesday next week. The heading says which. It is the same box as at the top of **Calendar › Week**: press it, write the line, press Return or **Done**. It is shown on **Today** during that week. Pressing **‹** in step 7 does not move it.

Aspirations and goals with a date are two steps, not one. They are different questions asked at different speeds — the review rhythm says so, a goal every three months against an aspiration every six.

Under the steps, when there are any, comes **Projects with no goal** — a loose end to tidy when you have time rather than a step in the walk, so it has no step number.

### Step 7: looking back at a week

Steps 1 to 6 look forward. Step 7 looks back, at a whole week, and step 8 looks forward again, at the coming week. Everything in step 7 comes from your own notes:

- **The week's goal**, the one you wrote in **Calendar › Week** or in step 8 of an earlier review. When none was written, a grey dashed box says so.
- **Seven days, Monday to Sunday.** A green bar for the tasks you finished each day, with the number above it. A day with none shows a dash, never a zero. A day still to come shows nothing. A day whose note has not reached this device from iCloud yet shows a small cloud.
- **How many tasks you finished** in the week.
- **Your evening lines.** What you wrote under **How was today?** in **Close the day**, one line per day. Press a line and that day's note opens, with the review still beside it on the Mac.
- **How was the week?** A box under the evening lines, for one line or two about the week itself. Press it, write, and press **Done**. **Cancel** throws the words away. The words go into that week's note, under a heading called **Looking back**, and nothing else in the note is changed. Empty words take the heading away again. If the week has no note yet, no note is made while the box is empty.
- **The time on the focus timer**, added up from the **Worked** lines in your daily notes.
- **Projects that ended in the week**, with how they ended: **Done**, **Missed** or **Dropped**. Press one to open it.
- **What it served**: what the week's finished tasks went towards — an aspiration, a goal, an area, or, when a task's note serves none of these, that note itself — the same way **Close the day** shows a single day. Tasks ticked in the days' own notes are one row, **Daily notes**. At most six rows, then "…and 3 more".

**Which week it shows.** On Monday and Tuesday it shows the week that has just ended, because that is when a week is looked back on. From Wednesday it shows the week you are in. The heading of the step says which, for example **7. Look back at last week**. The arrows **‹** and **›** beside the week's name move one week at a time, and the heading changes with them. **›** stops at the week you are in.

**The box belongs to the week shown.** Press **‹** and it is that older week's note you are writing in. If that week has no note yet, one is made when you press **Done** with words in the box, and only then. While the week's note has not reached this device from iCloud, the box says so in orange and cannot be pressed. If the words cannot be written, the box stays open with them and says why.

**Two places in a weekly note look back, and PARAGON writes in one of them.** A weekly note made from the Weekly template already has a heading called **Review** with two questions, **What went well?** and **What to change next week?**. They are yours to answer by hand, and PARAGON never changes them. **How was the week?** writes under its own heading, **Looking back**, at the end of the note, below those two questions. It is the same heading **Close the day** uses for a day.

A task counts on the day of its `@done(…)` stamp — the day you ticked it. A task ticked without a stamp has no day and is not counted. While notes are still coming from iCloud, an orange line says so, because the numbers may still grow. When the week's own note has not arrived yet, the goal box says so in orange rather than "No goal was written".

The count at the top of the review, "tasks finished in the last 7 days", is today and the six days before it. Step 7 counts Monday to Sunday, so the two numbers are the same only on a Sunday when step 7 shows the week you are in.

### What you can do to a row

Right-click any goal, project or area row (long-press on the phone):

- **I looked at it today** — writes `reviewed:` with today's date into the note, and starts that note's rhythm again. It is grey when the note already says today. A goal that has ended does not have it.
- **Put on hold** / **Set active** — a project or goal you are deliberately not working on now. On hold is never counted as needing attention.
- **Mark done**, **Mark missed**, **Mark dropped** — the three ways a thing can be over. Done means you delivered it; missed means the date passed without it; dropped means you decided not to. Only *done* counts towards a goal's per cent.
- **Archive** — moves the note to the Archive folder and stops syncing its tasks.

### The flags

A project is flagged when it has no next action, has overdue tasks, is past its due date, is due after the goal it serves, has not changed for the number of days set in Settings, is **Due for a look** (not looked at within its rhythm), or is on hold.

**Due for a look** follows each kind's own rhythm: a project is due after a week and an area after a month, unless you change them in **Settings › Review rhythm**.

Two of those deserve a word.

**"Due after its goal"** means the project's own deadline falls later than the target date of the goal it serves. That cannot be true and the goal still be reached, so either the project has to come forward or the goal has to move. Set a project's deadline from the **Due** button at the top of the project note. Write the date in the field as 2031-12-01, or pick it in the calendar below; press the button again to change or clear it. A goal can be years away, so typing is usually quicker than clicking.

**"Projects with no goal"** is its own short list at the foot of the review: the projects with no `goal:` line at all. Work with nothing above it is not an error — plenty of good work is simply something you want to do — so these are never counted as needing attention and never coloured as a problem. The review asks once. To answer, open the project and press **Serves…** at the top of the note; the same choice is on the right-click menu in the project list.

A goal is flagged when nothing serves it, when its target date has passed, when nothing has moved for 30 days, or when the only thing serving it is an area. A goal whose projects are all finished counts as served, not as neglected. That last one, **"No project yet"**, is the difference between a dated goal and a wish: an area is a standard you keep up, not a path to an outcome on a date. It applies to dated goals only. A goal reached through dated sub-goals is fine — those carry the projects — and so is an aspiration held by an area, which is exactly where an aspiration belongs.

## Map

The Map draws what serves what: goals at the top, then areas and projects, then open tasks and resources. Notes without a goal and archived notes sit in dashed boxes. Click a box to highlight its connections and open the note.

A project sits under the area its `area:` line names — the line **In area…** writes. A project that only links to an area in its text, like `[[Health]]`, does not sit under that area.

The Map and the Goals screen answer the same question — what serves what — and they are built from the same reading of your notes, so they can never tell you different things. The difference is the shape. The Map is the picture: it shows the whole vault at once, including the parts that hang from nothing. The **Aspirations** screen is the list: one aspiration at a time, with dates, per cents and next actions a drawing has no room for, and **Goals** is every goal with a date in one list.

### What each box says

Every box carries the same icon the rest of the app uses for that kind of note:

- **A star** is an **aspiration** — a goal with no date, which says what you are becoming. It is the north star on PARAGON's own app icon: what you steer by and never tick off.
- **Two circles, a target**, is a **goal with a date** — what you will have done, by a day.

**The difference is the date.** An aspiration has no target date; a goal has one. That one rule is the whole distinction, and everywhere the two sit side by side the app says it in a line under the heading.
- **A flag** is a **project**, **four squares** an **area**, **books** a **resource**, and a **ring** is one open task.

The colour is the note's kind: goals gold, areas pink, projects green, resources blue, the archive grey. An **aspiration** is a deeper gold than a **goal with a date**, so on the Map the colour and the icon say the same thing. The legend along the bottom names every one of them, with the same icon and colour the box itself carries.

Under the name, the second line begins with **what the note is** — Aspiration, Goal, Project, Area, Resource — and then how it stands.

For a goal that word is **Aspiration** or **Goal**. Then, if the note has been marked, its state — **Done**, **Missed**, **Dropped**, **On hold** or **Archived**, in the same words the rest of the app uses. Then the open task count for a project or an area, a deadline (`due`) and a target date (`by`).

### The lines between the boxes

- A **solid line** means *sits under*: this box's only home is the one above it.
- A **dashed line** means *also serves*: a second link the tree cannot draw as a parent. A project that belongs to an area and also delivers a goal sits under the area and has a dashed line to the goal. An archived note keeps dashed lines to the goal and area it still names.

Click any box and the footer says, in words, what it **serves** (everything above it, in order) and what is **served by** it.

### Wiring it up by dragging

The Map is not only something to look at. Drag one box onto another and the link is written into the notes:

- A **project onto an area** — the project now belongs to that area.
- A **project or area onto a goal** — it now serves that goal.
- An **area onto another area** — it becomes a sub-area of it.
- A **goal onto a goal** — the first becomes a subgoal of the second.
- A **task chip onto a project or area** — the task moves into that note, subtasks and all.

The box you are over is outlined while it would accept the drop; anything that does not go together is refused and the drag springs back. The map redraws itself afterwards, so the new arrangement is on screen at once.

The boxes themselves are placed by the app, worked out from your links — there is no way to drag a box to a position of its own, because the next change would move it again.

### Arranging it by hand

The boxes are placed by the app, worked out from your links. If you would rather put some of them where you want them, press **Arrange** — the hand button in the Map's toolbar, to the right of the zoom buttons. While it is on, a tinted strip across the top of the map says so, says what a drag will do, and has **Done** to leave the mode (Esc also works).

**While Arrange is on**, dragging a box moves it. Let go and it stays there. Dragging no longer links things — that is the whole point of the switch, so one drag never means two things.

**Moving several at once.** There are two ways to mark boxes, and they work together:

- **Tap a box** to mark it, tap it again to unmark it.
- **On the Mac, drag a rectangle across the empty background** and everything it touches is marked as well. It adds to whatever you had already tapped rather than replacing it. (On the phone a drag across the background scrolls the map, so there is no rectangle there — tapping does the job.)

The toolbar counts what is marked. Then drag any marked box and the whole set moves together, keeping its shape. Dragging a box that is *not* marked moves only that box and leaves your marks alone. Tap the empty background to clear the marks, and turning Arrange off clears them too.

**While Arrange is off** (the normal state), dragging links things as described above and nothing moves.

#### Where the position is kept

In the note itself, as one line in its frontmatter:

```
---
title: Mobility
type: area
map: 320,180
---
```

Two numbers: how far from the left and how far from the top, in points, measured at normal zoom. That has some useful consequences:

- **It travels with the note.** Rename the note, move it between folders, open the vault on the iPhone — the box stays where you put it, because the position is part of the file.
- **Both devices agree**, through iCloud, like everything else in the vault.
- **It is in your backups**, and in any other editor you open the file in.
- **Zoom does not disturb it.** The numbers are stored as if the map were at normal zoom, so zooming in and out moves the box on screen without changing what is written down.
- **If it is ever wrong**, the worst that happens is a box in an odd place. Delete the `map:` line in any editor and the app places it again.

#### Placed and unplaced boxes together

A note with no `map:` line is placed by the app as before. So the two live side by side: the boxes you have parked stay put, everything else is arranged around them by the layout.

That means a **new note appears wherever the layout puts it**, which can be on top of a box you placed. Move either one and they sort themselves out. Task chips and the dashed group boxes are never parked — only proper notes are.

#### Putting a box back

- **Right-click a box while arranging › Place this one automatically** takes its `map:` line out. If the box is one of several marked, it offers to place all of them.
- **Reset all** in the toolbar (also only while arranging) does the same for every note at once, after asking.

Nothing else in the note changes either way.

### Exporting the map

The **Export** button in the Map's toolbar offers:

- **PDF** — vector, so it stays sharp however far you zoom or print it. The one to send to someone.
- **PNG** — a picture, for pasting into a mail or a document.
- **Copy image** — the same picture, straight to the clipboard.
- **Copy as outline** — the same tree as an indented list of text, which is often easier to read than a diagram and can be pasted anywhere.

On the Mac a save dialog asks where to put the file. On the iPhone the share sheet opens, so it can go to Files, Mail, Messages or anywhere else.

## Linking notes with [[ ]]

Type two square brackets in any note and a list of your notes appears under the cursor. Keep typing to narrow it down, use the arrow keys to move, and press Return — or click one — to put it in. What lands in the text is `[[The note's title]]`.

**Opening one.** Hold ⌘ and click the link on the Mac. On the iPhone, switch to **Read** with the button below the note and tap the link there. A plain click on the Mac still just puts the cursor where you clicked, so a link never gets in the way of writing. The pointer turns into a hand when it is over one.

**Coming back.** Following a link takes you to the other note; **Back** brings you here again. On the Mac it is the ‹ button at the top left of the window, or ⌃⌘←, with ⌃⌘→ to go forward again — the same as a web browser, and it remembers the whole trail, not just the last step. On the iPhone the ordinary back arrow does it.

**Press the name to open it.** **Linked notes** and **Tasks** are both boxes that fold. Press anywhere on the heading — the arrow at the left turns to show whether the box is open.

**Both directions.** A note's **Linked notes** section lists **Links to** — the notes this one points at — and **Linked from** — the notes that point at it. You never have to remember who mentioned what: point from wherever you happen to be writing, and the other end knows.

**Linking to a note you have not written yet.** Write the link anyway. It appears under **Not made yet** in the Linked notes section, and clicking it — or ⌘-clicking the link in the text — offers to make that note there and then, with the link's own words as its title. Choose whether it should be a goal, project, area or resource and it is created, opened, and the link is a real link from that moment.

**What counts as a link.** Both `[[double brackets]]` in the text and the `goal:`, `area:`, `parent:` and `related:` lines at the top of a note. All of them show under **Linked notes**. But which area a project is in is decided only by its `area:` line, the one **In area…** writes: a `[[Health]]` in the text links the two notes and does not put the project in Health.

**Renaming.** If you rename a note, every `[[link]]` to it is rewritten. Links are for connections that cut across the structure — a resource three projects use, a person who turns up in two areas — while Goals, Areas and Projects are the structure itself.

## Finding things again

- **Recent** in the sidebar lists what you opened last, newest first, whatever kind it was. It is remembered between launches; **Clear** empties it.
- **Calendar › Notes** lists every daily and weekly note you have written, newest first, with the first line of each and its own search field. Day, Week and Month are for finding a date; Notes is for finding what you wrote.
- **Search Everywhere** (⇧⌘F) looks inside every note and task; see below.

### Search Everywhere

**The field is for words. Everything else is a tick box.**

Write a word in the field at the top. Under it are rows of boxes, and ticking them is the
search — one look at the boxes tells you what you are asking for.

- **Tasks**: Not done, Done, Overdue, Today, This week, This month, No date. **Tick any one of
  these and the results are tasks rather than notes.**
- **Kind of note**: Goals, Projects, Areas, Resources, Archive, Calendar, Inbox.
- **How the note stands**: Active, On hold, Done, Archived.
- **Tags**: every tag in the vault.

Two boxes in the **same row** mean either of them — tick **Not done** and **Done** and you get
both. Boxes in **different rows** are added together: Projects *and* overdue.

The word and the boxes are two different questions, and this is the one that used to catch
people out. Writing **done** looks for the letters d-o-n-e in your notes. Ticking the **Done**
box asks for tasks you have finished. Neither is wrong; the boxes just make it plain which one
you asked.

The field holds **your words only**. Ticking a box never puts anything in it. If you prefer to
type the syntax by hand, write it in the field anyway — `type:project` ticks the **Projects**
box, and the words move out of the field when you leave it.

The button beside the field folds the boxes away. On the iPhone they start folded, so the
results have the screen; on the Mac they start open. While they are folded, a line says what
the search is in words.

**On the iPhone**, three things put the keyboard away so the results have room: **Search** on
the keyboard, a swipe down over the result list, and the **Done** button above the keys. The
keyboard does not open by itself when you arrive with a search already in the field — after
tapping a tag, for example.

Every box also has a word you can type instead, if you prefer typing:

- `type:project`, `type:area`, `type:goal`
- `status:active`, `status:done`, `status:missed`, `status:dropped`, `status:on-hold`
- `tag:web` or `#web`
- `area:Health`
- `in:Projects` to limit to a folder
- `due:overdue`, `due:today`, `due:week`, `due:month`, `due:none`, `due:any`
- `is:open`, `is:done`, `is:task`
- quotes for an exact phrase: `"race day"`

### Saved searches

A search you run often can be kept.

**Saving one.** Set up the search — the word, the boxes, or both — and press the **bookmark**
button beside the field. A name is offered already, the same plain words the line under the tick
boxes uses; change it if you like and press **Save**. The button only appears when there is
something to save.

**Running one.** Saved searches appear as chips under the field, above a line that keeps them apart from the tick boxes below, on the Mac and the phone.
Press one and it runs. The one you are looking at right now is filled in and has a solid
border; the others are grey with a dashed one — the same two states every other button in the
app uses. Press the heading **Saved searches** to fold them away.

**Changing one.** Right-click a chip (long-press on the phone) for **Rename…** and **Delete**.
Saving again under a name you already used changes that one rather than making a second with
the same name. A name another saved search already has is refused.

**What is actually saved is the search, not the results.** It is the same text the field and the
boxes make between them, so running a saved search is exactly like typing it again: it answers
for your vault as it is today, not as it was when you saved it. And because it is only text, you
can still change any box after running one.

They are kept in `.ams-para/searches.json` inside the vault, so they travel between your Mac and
your iPhone through iCloud like everything else, and they are in your backups. They are not
notes, so they never appear in Today, the Map, the review or Apple Reminders.

## Tools: templates, snippets and tags

The sidebar group **Tools** holds the three things you use *on* your notes rather than notes
themselves. Press the word **Tools** to fold the group away and again to open it.

### Tags

A tag is a single word you put on a note or on a task, so that everything about one subject
can be found together later. `#travel`, `#waiting`, `#next` are tags. A tag has no spaces in
it: write `#next-week`, not `#next week`.

#### The three ways to add one

There are three ways to put one on something, and the Tags screen can also make, rename and
delete tags on their own.

**1. The Tags… button at the top of a note.** This is the easy one. Open the note and press
the button in the top row. It says **Tags…** when the note has none and lists them once it
has. A small panel opens:

- A field at the top for a new tag. Write the word and press Return. The `#` is added for you,
  a space becomes a hyphen, and any `#` you type yourself is taken out — so "Claude #Productivity"
  becomes the one tag `#Claude-Productivity`. For two tags, add them one at a time.
- Under it, every tag you already use anywhere. Press one to put it on this note, press it
  again to take it off. A filled circle means the note has it.

**2. Typing the `tags:` line yourself.** Press the **pencil** so you are writing, go to the top
of the note, and edit the line between the two `---`. Both of these work:

```
tags: [travel, summer]
```

```
tags:
  - travel
  - summer
```

The button writes the first form, so a list you typed the second way is rewritten to one line
the next time the button saves. Nothing is lost — the two mean the same thing.

**3. On a task, with `#`.** Write the tag anywhere on the task's own line. Two tags is two
words:

```
- [ ] Book the ferry #travel #summer
```

A task's tag belongs to that task, not to the note it sits in. That is why the Tags screen
counts notes and tasks separately.

#### Making a tag before you use it

The **Tags** screen has a field at the top. Write a word there and press **Make**. The tag is
kept even though nothing carries it yet, so it is offered in the **Tags…** panel of every note
from then on. It is marked **not used yet** in the list until something takes it.

#### Renaming a tag, and deleting one

Right-click a tag in the **Tags** screen (long-press on the iPhone):

- **Rename…** changes it in every note and every task that carries it, in one go. Both places
  are rewritten: the `tags:` lines and the `#tag` words.
- **Delete…** takes it out of every note and every task. The notes and the tasks themselves are
  kept — only the tag is removed.

Two things are left alone on purpose. `#next`, which is how the app marks a next action, cannot
be renamed or deleted; doing so would break that. And a longer tag that starts with the same
letters is never touched: renaming `#travel` leaves `#travelling` as it is.

If a note cannot be written — it is open elsewhere, or iCloud has not finished with it — the app
says which ones still carry the old tag rather than letting it pass.

#### The Tags screen

**Tags** in the sidebar lists every tag you have used, the most used first, with how many notes
and how many tasks carry each one. Press a tag to open it: the notes that carry it, then the tasks, open
ones first. Press a note to open it, or tick a task where it stands — the list stays where it
is. The field at the top finds a tag by name.

Right-click a tag (long-press on the iPhone) for **Search for #tag**, which hands it to the
Search screen where you can combine it with anything else.

## Templates and snippets

Two kinds of ready-made text, both ordinary markdown files in the `Templates` folder inside your vault. **Templates** are what a new note starts as; **snippets** are blocks of tasks you drop into a note you are already in. The **Templates** section in the sidebar lists them all and lets you edit them without leaving the app.

### The templates

Every new note is a copy of the matching file, with `{{title}}` and `{{date}}` filled in.

- **Project** — Outcome ("what does done look like?"), Tasks with a first step already written, Notes, and a Log with the day it was created. Frontmatter: `status: active`, empty `area:` and `due:`, `tags`, `related`.
- **Area** — Standard ("what does good look like here?"), Tasks, Notes. Frontmatter: `status: active`, `tags`. The question under Standard counts as nothing written until you answer it, also in a template of your own; see **An area's page**.
- **Resource** — a plain note for reference material, with `related` ready to point at what it supports.
- **Goal** — Why it matters, the measure, and a "Serving this goal" section reminding you that projects and areas link here with `goal:`. Frontmatter: `horizon`, `target`, `measure`.
- **Daily** — the shape of a day's note.
- **Weekly** — the shape of a week's plan.

### The snippets

**Snippets** in the sidebar lists every block and what is in it; the file itself is edited beside the list on the Mac, and one tap down on the iPhone. Pick a block to use from the **Snippet** button beside **Add a task** in any note (a symbol rather than the word on the phone), and its lines are added to that note's Tasks. The ones the app starts with:

- **Delegate** — "Ask {{who}} to {{what}}" due tomorrow, with a subtask to check they have it in a week.
- **Waiting for** — one line tagged `#waiting`, dated a week out, so it turns up in a review rather than being forgotten.
- **Meeting** — prepare it today (with agenda and "what do I need from them" as subtasks) and write it up tomorrow.
- **Decision** — "Decide: …" a week out at high priority, with the options, who else has a say, and telling the people it affects.
- **Errand** — one line tagged `#errand`.
- **Follow up** — one line a week out.

### Filling in the blanks

- `{{title}}` is the note's name and `{{date}}` is today; in snippets `{{tomorrow}}` and `{{week}}` (a week from today) work as well.
- Anything **else** in double braces — `{{who}}`, `{{what}}`, `{{meeting}}` — is a question. The app asks for it when you use the snippet and puts your answer in everywhere that name appears. Leave one blank and the braces stay in the task, so you can see what is still missing.

### More than one template for the same thing

A template says what it makes in its own `type:` line, so you can keep several side by side — a plain **Project** and a **Client project**, say. The Templates section groups them under the kind of note they make, in that kind's colour, and each group folds.

- **+** in the toolbar adds one. Give it a name and say what it makes; it starts as a copy of the one that kind uses now.
- The template **named after its kind** — Project, Area, Resource, Goal — is the one used unless you choose another.
- When a kind has more than one, **New note** grows a **Template** chip.
- Right-click a template — long-press on the phone — to **Rename** or **Delete** it. Deleting the template only removes the template; notes already made from it are untouched.

### Changing them

Open **Templates** in the sidebar, pick a file and edit it. It saves itself a moment after you stop typing, and when you move to another template or leave the section; **Save** (⌘S) is there when you want to be sure. Or edit the files in `Templates/` in any other editor — it is the same thing.

- Add a snippet by writing a new `## Heading` with task lines under it. Delete one by deleting its heading and lines. Rename it by renaming the heading.
- Add a template of your own by putting a file in the folder; the six named above are the ones the app looks for when it makes a note, so a new file is for your own use.
- Delete a template and the app falls back to a bare note with just a title and a type.

**This page describes the ones the app starts with.** Once you change them, the manual will not follow — the Templates section always shows what you actually have.

## Quick capture

- ⇧⌘N opens the capture panel in the app. On the Mac there is also a panel in the menu bar.
- **New note** (⌘N) has **Capture** as its fifth button, which gives the same screen.
- On the iPhone it is the **+** at the top left of **Today**. It opens the **New note** screen with **Capture** already chosen. The **+** on the other tabs opens the same screen, starting on the kind that fits that tab.
- On the iPhone, Share › PARAGON sends text or a link.
- Other apps and Shortcuts can call `amspara://capture?text=Call%20the%20bank&target=inbox`.

Captures land in the Inbox, today's note or a project, and are filed the next time the app is active.

### What the chips under the field mean

Write a line and the app reads it back to you in chips:

- **Due 15 September** — it found a date.
- **Priority !!** — it found the marks.
- **#travel** — it found a tag.

The **#tag…** button under the field opens the whole list of tags you already have, the same one the New note screen and a note's header use, so you can see what you have before making a new one. Tags on a capture are written into the words as `#travel`, which is how a task carries a tag.

**If a chip does not appear, the app did not read that part.** That is the point of them: you
see what will be saved before you save it. The chips are dashed because they are not buttons;
they are what the app heard.

The row under them **writes the syntax for you**: **Today**, **Tomorrow**, **Date…**, **!**,
**!!** and **#tag** all put the right thing at the end of your line. You can still type it by
hand, and the **ⓘ** at the top right shows the whole list.

Under that, **where it goes** (Inbox, today's note, or one of your projects) and whether it is
**a task** or **a note**.

## Backups

The app saves a copy of the whole vault before every sync and once a day, keeping the last ten. They live inside the vault, in a hidden folder called `.ams-para/Backups`, as ordinary folders of markdown files.

- **Settings › Backups › Back up now** saves one immediately. Nothing is saved twice if nothing changed.
- **Show in Finder** opens the folder, where you can drag a single note back by hand.
- **Restore a copy** writes a whole backup back into the vault. What you have at that moment is saved as a backup first, and notes you created after the backup are left where they are.

Time Machine covers the rest: these backups sit inside the vault folder, so they do not protect against losing that folder itself.

## On the iPhone

**Reading or writing.** A note opens ready to write in. The **pencil** button at the bottom of the note (in the toolbar on the Mac) turns writing on and off. When the pencil is lit and its frame is solid, you are writing. When it is grey with a dashed frame, you are reading: the note is shown rendered — headings, bold, tappable links — and there is no cursor. If a note ever seems to refuse your typing, look at that button.


Sync with Reminders from the phone with the button in the top right of Today and Inbox, or Settings › Reminders sync › Sync now. The first sync is when iOS asks for permission to use Reminders.

On the phone, a note's own actions — Rename, Archive and Delete — are behind the **⋯** button at the top right of the note. On the Mac they are buttons in the toolbar. The pencil is not in there: it is always on screen.

The phone shows five tabs: **Today**, **Plan**, **Actions**, **Inbox** and **Browse**. **Plan** is Plan the day and **Actions** is All actions. **Browse** holds everything else: Aspirations, Goals, Projects, Areas, Resources, Archive, Calendar, Done, Review, Map, Search, and Settings with Help. Every tab except **Browse** has a **+** at the top left. On **Today** it opens **Capture**, for a quick line into the Inbox. Tap a note to open it and swipe from the left edge to go back. Long-press a task for the task menu. The share sheet in other apps has a PARAGON entry that sends text or a link to the Inbox.

## Moving between the tabs

Press a tab in the bar at the bottom to move to it: Today, Plan, Actions, Inbox, Browse. The
**Inbox** tab shows how many lines are waiting in the Inbox.

You cannot swipe sideways between the tabs any more. The swipe made the app crash on the
iPhone, so since build 232 the tabs work the same way as in Apple's own apps.

A drag from the very **left edge** still means *go back*, as it does everywhere in iOS.

**Actions** has its own filter at the top: **All**, **With a date**, **No date** and **Next
actions**.

## Widgets

Two widgets, on the Mac and on the iPhone.

**On the Mac**: click the date and time at the right of the menu bar to open Notification Centre, scroll to the bottom and click **Edit Widgets**. Search for **PARAGON** and drag one in. You can also right-click the desktop and choose **Edit Widgets**, which puts the widget on the desktop itself.

**The first time after an update, PARAGON may not be in that list.** macOS only learns about a new widget once the app it came with has run. Open PARAGON, quit it with ⌘Q, open it again, and look in **Edit Widgets** once more. If it is still missing, restart the Mac: macOS keeps its own list of known widgets and that list is stubborn about new ones.

**On the iPhone**: press and hold the Home Screen, press **+** at the top, search for **PARAGON**, and pick one.

**Today's actions** is the same list the planner shows: everything due today or earlier, then your next actions. Each line shows the note it lives in and, under it, **what it serves** — the goal in gold, or the area in pink. It comes in three sizes; the small one shows three lines, the medium four, the large seven.

**What is waiting** is four numbers: due today, overdue, waiting in the Inbox, and due for a look. A zero is grey and a number that wants you is in its own colour, so the one to read finds you first.

Clicking or tapping either one opens PARAGON.

Each side is fed by the app on that machine: the Mac widget by PARAGON on the Mac, the iPhone widget by PARAGON on the iPhone. They can therefore show slightly different things for a moment, until both apps have seen the same notes through iCloud.

### How they get their information

The widget never opens your vault. It cannot: the vault is a folder you chose, and only the app itself is allowed to open it.

Instead, **PARAGON writes a short summary for the widget a few seconds after a change that the widget would show**, and the widget reads only that. These changes reach it: you tick a task, you change a task's date, you add a task that is due today or is a next action, a line comes into the Inbox or leaves it, a sync finishes, or a file arrives from iCloud. A change that the widget does not draw writes nothing. So:

- The widgets are right as of the last time the app noticed a change.
- The few seconds are on purpose. While you type, PARAGON waits until you stop. When you leave PARAGON for another app or the Home Screen, or quit it, it writes at once. It writes only when the widget would show something different.
- **After midnight** the widgets move on to the new day by themselves, as long as PARAGON is running.
- **Open PARAGON once after installing**, or the widget has nothing to read yet and says so. On the Mac that means PARAGON on the Mac; on the iPhone, PARAGON on the iPhone.
- If PARAGON has not seen today yet — it was not running at midnight and you have not opened it — the widget says **"Nothing since you last opened PARAGON"** rather than showing yesterday's list as though it were this morning's.
- When there is genuinely nothing due and nothing waiting, it says that too. An empty widget and a widget with nothing to say are different things, and it never leaves you guessing which one you are looking at.

Nothing is written back from the widget, and nothing about your notes leaves the machine it is on.

### When the app asks for a vault folder

If PARAGON shows the welcome screen with **Choose a vault folder…**, it has no folder open. A
widget on that device stays empty, because the app writes nothing for it to read.

If PARAGON knows the folder you used last, the first button is **Open <your folder> again**.
That is the way back. If it could not open that folder by itself, it says so in orange above
the buttons: the folder may have been renamed or moved, or iCloud may not have it on this
device yet. Pressing the button again after iCloud has caught up is usually enough.

**Choose a different folder…** is the second button, for when you really do want another vault.

### When a widget looks empty

Every widget carries one small grey line at the very bottom, for example **PARAGON 177 ·
written 09:41**. It is there so that a widget can never be a blank box with no explanation.
Read it like this:

- **written 09:41** — the widget is working. 09:41 is the time of the last change that PARAGON passed on to it, not the time of the last look, so an old time is normal when nothing has changed. If the rest of the widget is empty, there is genuinely nothing due and nothing waiting.
- **nothing written yet** — the app has not written a summary on this phone. Open PARAGON once.
- **shared folder missing** — the widget cannot reach the small file the app writes. Nothing
  you do on the phone will mend this; it has to be fixed in the build. Tell me and I will.
- **no line at all, a completely blank box** — the widget itself is not running. That is also a
  build problem, not something you can fix yourself.

**Settings › Widget** says the same thing from the app's side: whether the shared folder was
found, when the summary was last written (that is, when something the widget shows last
changed), and how many actions are in it. There is a **Write it again now** button for when you
want to be sure. It writes at once, even when nothing has changed.

## Mac and iPhone together

Keep the vault in iCloud Drive and pick the same folder on both devices. iCloud carries the files across. Each device syncs with Reminders on its own.

### How iCloud moves the files

There is no PARAGON server. Everything the app knows lives in the markdown files in your vault folder, and iCloud is what copies those files between the Mac and the phone — the same way it does for any other folder in iCloud Drive.

That has one consequence worth knowing. iCloud does not push every file to every device the moment it is written. It tells the other device that a file exists and leaves the contents behind until something asks for them. Until then there is only a marker where the file should be: the name is reserved, but the note is not really on the phone yet. This is normal iCloud behaviour, and it is why "Optimise storage" on a phone with little space left can leave a lot of your vault as markers.

The app therefore asks. When it starts, when you open a vault, and once a minute while it runs, it looks through the vault for anything that has not arrived and asks iCloud to fetch it. A few seconds later the file is there and the app reloads by itself. You do not have to do anything.

**PARAGON never waits for iCloud while it starts.** It opens at once with the notes that are on the device and fetches the rest in the background, the Inbox and today's note first. While notes are still coming, a short orange line says how many — at the foot of the sidebar on the Mac, at the top of **Today** on the iPhone — with a button, **Ask iCloud again**. If the Inbox note itself has not arrived, the Inbox says **Still coming from iCloud** instead of **Inbox zero**. A capture that cannot be filed yet is kept and filed when the note arrives.

Some things wait until every note is here, because they reach across the whole vault: the Reminders sync and its rehearsal, renaming or removing a tag everywhere, renaming a note with its links, and restoring a backup. They say why and ask you to try again in a moment. The same is true while iCloud is bringing a newer version of a note that is already on the device. The widget also keeps its last complete picture until every note is here.

### When something takes a moment to arrive

Make a note or a template on the Mac and it usually appears on the phone within seconds of opening the app. If it does not, it is nearly always one of these:

- The phone has no connection, or is on a network that is being slow. iCloud is doing nothing until it can.
- The Mac has not finished uploading. Look at the file in Finder: a small cloud with an arrow means it is still on its way up.
- The phone app has been open the whole time and is between checks. Switch away and back, and it looks again.

While a template is on its way, the Templates list names it and says "coming from iCloud" instead of pretending it is not there.

### If a file seems stuck

Open the Files app on the iPhone, find your vault folder, and tap the file once. That is the same request the app makes, and it usually settles it. If a whole folder looks empty on the phone but is full on the Mac, check that both devices point at the same folder under Settings › Vault, and that iCloud Drive is switched on in iOS Settings.

### Editing the same note on both devices

The app checks every few seconds whether files changed outside it and reloads them. It never writes over a newer file. If you were typing in a note that changed elsewhere at the same time, your text is saved as a copy named "… (conflict date time).md" next to the note, and the note shows the other version. Merge the two by hand when that happens; it is rare.

A note that has not arrived yet is treated as a note that exists. The app will not make a fresh empty one in its place, which would leave you with two versions of the same note for iCloud to argue about. If you open one before it has landed, it says so and you can try again a moment later. If **Close the day** cannot save your line because today's note is still coming, it stays open with your words in it and says so; press **Done** again in a moment. If the note then turns out to have a line already, written on your other device, that line is kept and your words go below it. The goal for the week and **Plan the day** work the same way: nothing you typed is thrown away, and the box stays open until it can be saved. While a week's note is still coming, its goal box says so in orange and cannot be pressed. If the goal was changed on your other device while you were typing, the box does not write over it: a message says what the goal now is, your words stay in the box, and pressing **Done** again puts yours in its place.

## Getting new versions

Both apps come from TestFlight. When a new build is sent, TestFlight tells you and you press
Update: on the iPhone in the TestFlight app, on the Mac in TestFlight for Mac. The Mac app
lives in your Applications folder like any other app.

## Keyboard shortcuts

- ⌘N new note, ⇧⌘N quick capture, ⇧⌘F search everywhere, ⇧⌘R sync with Reminders
- ⌃⌘← back to the note you came from, ⌃⌘→ forward again
- ⌘⌫ delete the open note (it waits in Deleted)
- ⌃⌘D copy diagnostics, a log you can paste when reporting a problem
- The sync button's menu holds the sync preview and the last report

## When something looks wrong

Help › Copy Diagnostics (⌃⌘D — control, not option) copies a short log: the build number, what was clicked, which section and note are open, and the window layout. Paste it into the chat with the developer. The build number is also shown at the bottom of the sidebar.
