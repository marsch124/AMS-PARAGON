# Version history

The build number is shown at the bottom of the sidebar. Newest first.

## Build 202 · 20 September 2026

**Two things in the New note screen's pop-up lists, both from your screenshot.**

**The small yellow label no longer covers the buttons.** Hovering a chip made macOS show its
name beside the pointer, and because those chips sit just above the bottom of the screen, the
label landed on top of **Cancel** and **Create** and cut both words in half. While the list is
open that label also said nothing new — the list already has the same word as its heading. It
now appears only while the list is closed.

**The gold line under the first row is gone.** That was not ours: macOS gives the first button
in a pop-up list the keyboard focus as soon as it opens and draws a ring around it in the
accent colour you chose in System Settings, which is orange. It looked like a second choice
arguing with the blue tick beside it. The same thing caused the yellow square around the Inbox
in build 197.

Both fixes reach every pop-up list of this kind: the **Template**, **Serves a goal** and date
chips on the New note screen, and the tag list wherever it opens — the note header, the New
note screen and **Quick capture**.

## Build 201 · 18 September 2026

**The rest of the screens.** Build 200 fixed the lists you had in front of you. You asked
whether the whole app had been checked, and it had not: four more places could go orange on
orange when a row was selected.

- The **sidebar** itself. Each row's little coloured symbol.
- **Weekly review**, both kinds of row: the projects and areas, and the aspirations and goals.
- The results in **Search Everywhere**.

Every list in the app that lets you select a row has now been gone through, one by one.

## Build 200 · 18 September 2026

**A selected row can be read again.** You picked an aspiration and its warning line vanished:
orange writing on an orange background. The colour behind a selected row is the accent colour
you chose in macOS System Settings, and yours is orange, so the two were the same colour.

Every coloured word inside a row that can be selected now steps aside while that row is
selected, and takes its own colour back the moment you pick another one. The rows that were
affected: the aspirations, the goals, every note list, the task lists, and the Inbox.

The coloured badge at the left of a row and the progress bar keep their colours. They are
shapes, not writing, and a bar that changed colour when you clicked it would look like it was
saying something about the goal.

## Build 199 · 18 September 2026

**Aspirations have a room of their own.** There are now two rows in the sidebar where there
was one.

**Aspirations** is the screen you already knew: your aspirations listed, and picking one draws
everything working towards it. **Goals** is new: **every goal that has a target date, in one
list, without choosing anything first**. Before this, the row named Goals listed the
aspirations, so a goal only appeared once you had picked the aspiration above it — and a goal
that served no aspiration was hard to find at all.

The Goals list has three groups:

- **Needs a look** — the goals the weekly review has something to say about: past their target
  date, nothing serving them, no next action. It is where to start, not a fault list.
- **By date** — the rest, soonest first.
- **Done**, **Missed** and **Dropped** — closed, with the count on the heading.

Each row carries its target date and how long is left, its measure, its bar, and a **Give it an
aspiration** button when nothing holds it. Right-click a row (press and hold on the iPhone) for
the same choices.

**The per cent is gone from an aspiration.** Your screenshot showed one reading **100% · 3
goals · 2 goals need attention**, which cannot all be true: the figure was the average of the
goals under it, and goals with no project yet count as nothing to measure. More than that, you
never finish an aspiration, so a per cent on one is a promise the idea does not make. In its
place each aspiration says **when you last looked at it** — "Looked at 12 days ago", or "Never
looked at". Every goal under it keeps its own bar, where the number is true.

**One list, not two.** The old **Nothing serves these yet** group is gone. An aspiration with
nothing under it says so on its own row instead, which is the same news without a box around
it.

**A sixth button on the New note screen.** It is **Aspiration**, **Goal**, **Project**,
**Area**, **Resource**, **Capture**. The "What kind of goal" chip is gone: the button at the
top now says which kind you are making, and the star and the target sit side by side where the
difference is easiest to see.

**Nothing in your vault was moved or rewritten.** Both kinds are still goal notes, and the line
that tells them apart is `horizon:`, exactly as before.

## Build 198 · 18 September 2026

**All actions can be narrowed with tick boxes.** The screen used to have one row of four
choices — All, With a date, No date, Next actions — and it could only answer one of them at a
time. Now there are tick boxes in three rows: **When** (Overdue, Today, Next 7 days, Later, No
date), **Mark** (Next action, Important) and **Tags**, listing the tags your open actions
actually carry. Boxes in the same row mean "any of these". Boxes in different rows are all
required together, so you can ask for overdue **and** important.

Nothing the old row could ask has been lost: "With a date" is the four dated boxes together.

The heading counts what is shown, for example **12 of 48**. **Clear** unticks everything. The
button beside it folds the boxes away, and while they are folded the line under the heading
says what is ticked, so the list is never narrowed without telling you. When the boxes rule
everything out, the screen says how many open actions there are and which boxes hid them.

## Build 197 · 18 September 2026

**No more thick ring around the Inbox at launch.** On the Mac, the Inbox column takes the
keyboard focus when the app opens, so that the single keys work on its lines (arrows, t, m, d).
A focused view on the Mac is drawn with a ring in your Mac's accent colour, and that ring sat
around the whole Inbox until you clicked somewhere else. The keys still work; the ring is gone.
The Calendar had the same ring and loses it too.

## Build 196 · 16 September 2026

**All seven checks now run on the Mac as well as on the simulated iPhone.** The build machine
opens a project note on the Mac and types into it, clicks a line in the Inbox, makes a project
from the New note screen, saves a Quick capture and finds it in the Inbox, and clicks a box on
the Map. Nothing changes in the app.

Later the same day, four checks that only the Mac can answer: the three columns are still
inside the window after a note is opened (the "window scramble" of builds 30 and 34), ⌘N opens
the New note screen, ⇧⌘N opens Quick capture, and ⌃⌘← goes back to the note that was open
before. Nothing changes in the app.

## Build 195 · 16 September 2026

**The build machine now presses the Mac app too.** Until now every screen check ran on a
simulated iPhone. A second check starts PARAGON on the Mac itself, opens the vault, and clicks
every row in the sidebar. The faults that cost the most days earlier this month were Mac
faults — the Inbox list that could not be clicked, the Map boxes that swallowed clicks — and
nothing had ever pressed them there.

Two checks on the Mac today; the other five come across next. Nothing changes in the app.

## Build 194 · 15 September 2026

**One more check on the build machine, nothing new to see.** The simulated iPhone now opens the
Map from Browse, taps a box, and checks that the box's note opens. That is the fault from build
85 — boxes that swallowed every click — pressed on every push from now on.

## Build 193 · 15 September 2026

**One more check on the build machine, nothing new to see.** The simulated iPhone now presses
the Quick capture button on Today, types a line, presses **Save**, and then finds that line
waiting in the Inbox. The fastest path through the app is pressed on every push.

## Build 192 · 15 September 2026

**One more check on the build machine, nothing new to see.** The simulated iPhone now opens the
New note screen from the Projects list, presses **Project**, types a name, presses **Create**,
and checks that the new note opens with that name in it. The screen you asked for in build 185
is now pressed on every push.

## Build 191 · 15 September 2026

**Two more checks on the build machine, and one small fix.**

The machine now also opens a project note on the simulated iPhone and types into it, and picks
a line in the Inbox by tapping it. Those are the two faults that cost the most days earlier this
month, and until now nothing could catch them before they reached you.

The fix: the small sheet that appears when you follow a `[[link]]` to a note that does not
exist yet had the same two blue words at the bottom that the New note screen had before build
186. It now has the same proper **Cancel** and **Create** buttons, and it no longer asks for
more width than the phone has.

## Build 190 · 15 September 2026

**Nothing changes in the app.** This build is a check, not a feature, so there is nothing for
you to look at.

Until now the build machine only checked that PARAGON *compiles*. It never opened a screen. That
is why the faults that cost us the most days all went past it with a green light: the Inbox where
no line could be clicked, the map boxes that swallowed every click, and the phone note that
needed a long press before it would take a letter.

From this build the machine starts an iPhone simulator on every push, opens PARAGON with a small
made-up vault, and presses the tabs. If a screen draws nothing, or the app stops, the build turns
red before it can reach you. It is two checks today; more will be added as we go.

## Build 189 · 15 September 2026

**An aspiration has its own colour now: a deeper gold.** You picked it from a drawing. A goal
with a date keeps the gold it has always had, so the two are told apart by colour as well as by
the star and the target.

It is the same colour everywhere at once — the Goals list, the chain, the Map, the weekly
review, the note header, every **Serves…** chip, the New note screen and the review rhythm in
Settings. One symbol in two colours on some screens and not others is a fault this app has
already paid for twice.

**The sidebar row named Goals keeps the plain gold**, and so does the colour over the note
column. That row is the whole family, not one half of it — the same reason it carries the
target and not the star.

On the New note screen the **Goal** button changes colour as you choose: deeper gold with a
star while **Aspiration** is picked, plain gold with a target once it has a date.

## Build 188 · 15 September 2026

**The Capture screen has the same tag list.** You found it: *"The tags work on everything
except Capture."* The **#tag…** button used to write a bare `#` and leave you to remember the
word. It now opens the very same list as the New note screen and a note's header — every tag
you have, with a tick on the ones you picked and a number saying how much of your vault carries
it.

The tags go into the words as `#travel`, which is how a task carries a tag, so the chips under
the field read them straight back. Picking tags moves them to the end of the line; the date and
the `!` marks stay where you put them.

## Build 187 · 15 September 2026

**The New note screen has a Tags chip, and it shows every tag you already have.** Your words:
*"It's not always too easy to know what tags I have defined, and I don't want two tags the same
meaning, but slightly different names."*

Press **Tags…** and you get the whole list, with a tick on the ones you have picked. Beside each
tag is **how much of your vault carries it** — a number, or "not used yet". That is what makes a
near-duplicate show itself: if you see **#travel 24** and **#travelling 1**, you know which one
you meant. There is also a field at the top for a tag that does not exist yet.

**It is the same list the tag button in a note's header opens**, so the two can never offer you
different tags.

A tag you type is tidied the same way everywhere: a `#` and any spaces become hyphens, so
`Claude #Productivity` is stored as `Claude-Productivity`. That rule moved into the tested part
of the app, where it belongs.

## Build 186 · 15 September 2026

**Cancel and Create are proper buttons on the iPhone now.** They were two blue words in the
bottom corner. **Create** is a full-width button in the colour of the kind you picked — gold
for a goal, green for a project — and it is grey until the name field has something in it. It
is the same shape as **Save** on the capture screen. **Cancel** sits beside it with room around
it, so neither is a small target.

The screen also starts at the top now instead of floating in the middle.

On the Mac the two buttons stay where a Mac sheet keeps them, bottom right, and Create is
filled in the same colour. Return still creates and Escape still cancels.

## Build 185 · 15 September 2026

**The New note screen is rebuilt.** You called the old one a very sad entry page, and you were
right: two blue words at the bottom with no labels at all.

**Five buttons across the top: Goal, Project, Area, Resource, Capture.** The name field is under
them, with the cursor already in it. The button you press decides everything below it.

**Capture is now in the same screen.** Press it and the lower half becomes the quick capture
screen — the same one as ever, with the chips that read your line back. So one screen answers
"I want to put something into PARAGON", whether the thought is a project or a line you must not
forget. Quick capture on its own is unchanged: ⇧⌘N, the menu bar, the button on Today, and the
share sheet from other apps.

**The settings are chips now, not rows of menus.** Press a chip to change it. A chip you have
set is filled in its own colour with a solid line around it; a chip you have not set is grey
with a dashed line — the same two states the app uses everywhere else. What you get:

- **A goal** asks which kind it is (Aspiration, Long term, This year), and then for a target
  date and the aspiration it serves. The date is picked the same way as a project deadline:
  write it as 2031-12-01, or use the calendar.
- **A project** asks which goal it delivers.
- **An area** asks which area it is part of, and — new — which aspiration it serves. That was
  missing here before; you had to open the note afterwards to set it.
- **Everything** asks which **Template** to start from, when there is more than one.

The Goal button shows the star while **Aspiration** is chosen and the target while a date is,
so the difference between the two is on screen at the moment you choose.

**The word on the capture button is Save.** It said "Caught it" for a moment after saving, and
you asked for plain words. The line under it now says "3 saved today."

## Build 184 · 15 September 2026

**The swipe looks like cards now.** There is a small gap between the screens, so while one
slides past the other you see two edges moving rather than one sheet. Your word for it was
carousel.

What it does not do is show a slice of the next screen while nothing is moving. That needs
replacing Apple's page view with our own scrolling, and then every screen's top bar would sit
inside a scrolling area instead of its own — the part of the phone layout this app has had the
most trouble with. Say the word and I will do it, but I would rather not spend that risk on a
look.

## Build 183 · 15 September 2026

**Five tabs on the iPhone, and you can swipe between all of them.** You asked for the swipe to
work on every screen, not only in Time Blocks, and chose this shape.

The bar now reads **Today · Plan · Actions · Inbox · Browse**. **Plan** is Plan the day and
**Actions** is All actions — the two screens you reach for most, out of Browse and into the bar.
Swipe sideways anywhere to move between them, or press a tab as before.

**Quick capture is now the button at the top left of Today.** It lost its place in the bar to
Plan and Actions. Everything else about capture is unchanged: the share sheet from other apps,
and ⇧⌘N on the Mac.

Time Blocks and All actions have left the Browse list, since they are tabs now. The two-page
swipe of build 181 is gone with them — the tabs do that job, everywhere.

The Mac and the iPad are untouched.

## Build 182 · 15 September 2026

**The line for now is no longer red.** Your reason was the right one: in PARAGON red means
overdue or dangerous, and a line that only says what the time is should not look like a
warning. It is a soft **slate blue** now, and a little thicker so it still reads.

The colour is its own, not borrowed. Purple is the Calendar lane drawn right beside it, orange
is your blocks, pink Areas, green Projects, blue Resources, teal the review, gold Goals, grey
the Archive. The time of day is none of those, so it has a colour of its own.

If you would rather have another one, name it and it is one line to change.

## Build 181 · 15 September 2026

**Two pages on the iPhone, swiped between.** **Plan the day** and **All actions** are now one
screen with two pages. Swipe right to left for one, left to right for the other. Two small dots
at the foot show which page you are on.

Both rows lead there and open where you pressed: **Time Blocks** opens on the plan, **All
actions** opens on the actions.

This is a proper pager, not a gesture of our own, for one reason: on the iPhone a drag from the
**left edge** is Apple's own *go back*. If PARAGON took that gesture, going back from a note
would stop working. A pager leaves the edge alone.

Nothing changed on the Mac.

## Build 180 · 15 September 2026

**A line for where we are in the day.** Your ask, and the planner was the one day view without
it. **Plan the day** now draws the red line and dot across both lanes at the current time, the
way a calendar app does, and it moves on its own every minute. It is drawn only on today, and
only while the time is inside the hours the planner shows.

The Calendar section's day already had such a line. Both now draw the same one, so they cannot
end up looking different from each other.

## Build 179 · 15 September 2026

**A way back to your folder.** You found this on the iPhone: PARAGON showed the welcome screen
with **Choose a vault folder…**, as though the app had never been set up, and there was no way
back into it. That is also why the widget on that phone stayed empty — with no vault open, the
app writes nothing for it to read.

Three different situations used to look exactly the same on that screen: a real first run, a
vault closed by mistake, and a folder PARAGON knew about but could not open. Now:

- **The screen says which one it is.** If PARAGON cannot open the folder it used last, it says
  so in orange, and names the likely reasons — renamed, moved, or not yet down from iCloud.
- **There is a way back.** The first button is **Open <your folder> again**. Choosing a
  different folder is still there, underneath, as the second choice.
- **Closing a vault no longer throws the way home away.** PARAGON keeps a pointer to the last
  folder even after you close it, purely so that button can exist.

**The small widget kept its own explanation.** On the small size the message filled the whole
card and pushed the little grey line off the bottom — the very line that says what is wrong.
The small size now uses short messages and the grey line always keeps its place.

## Build 178 · 15 September 2026

**The widget on the Mac.** You said you use the widget on the Mac only, and that explains the
blank box: **PARAGON had no Mac widget at all**. The PARAGON widget the Mac offered you was
your iPhone's widget, handed over by iPhone Mirroring — the feature Apple does not provide in
your part of the world. It could never have drawn anything.

PARAGON now has its own Mac widget, built from the Mac app, with nothing coming from the phone.
Click the date and time in the menu bar, scroll to the bottom of Notification Centre, click
**Edit Widgets**, search for **PARAGON**. Right-clicking the desktop and choosing **Edit
Widgets** puts it on the desktop instead.

Both widgets are the same two: **Today's actions** and **What is waiting**. Each is fed by the
app on that machine, so the Mac widget follows PARAGON on the Mac.

**Settings › Widget** is now on the Mac as well, with the same three answers and the same
**Write it again now** button.

## Build 177 · 15 September 2026

**A widget that cannot be silent.** Your widget came up as a blank box, and nothing anywhere
could say why. Three different faults looked exactly the same from the outside, and one of the
three — the widget being unable to reach the small file the app writes for it — cannot be mended
by opening the app, which was the only advice the widget could give.

**Every widget now carries one small grey line at the bottom**, for example **PARAGON 177 ·
written 09:41**. If that line is on screen, the widget itself is running, and the line says what
it found: *written 09:41*, *nothing written yet*, or *shared folder missing*. If there is still
no line at all, the widget is not running, and that is mine to fix in the build.

**Settings › Widget** answers the same question from the app's side: shared folder found or not,
when the summary was last written, how many actions are in it, and a **Write it again now**
button.

The build now also lists every part it ships, so a widget quietly left out of the app can never
again look the same as a clean build.

## Build 176 · 15 September 2026

**Telling an aspiration from a goal.** You said you sometimes have trouble with it, and asked
whether the star could be made to stand out more. Three changes, and the star stays gold.

**The star is filled now.** A filled shape carries a colour far better than an outline — the
same thing the New note button taught us in build 156, where most of the "pop" turned out to be
the fill rather than the shape.

**The dated one is called "Goal with a date".** The word *Goal* on its own was the ambiguous
one: an aspiration is also a kind of goal, so plain "Goal" asked you to hold both meanings at
once. Wherever the two appear together — the Goals screen header, the Weekly review's step 4,
the Map legend — it now says **Goal with a date**, and the name carries the rule.

On a Map box it still says just **Goal**, because the target date is printed right beside it
and saying both would be saying the same thing twice.

**The rule is on screen where the two sit side by side.** One short line under each heading:

- Aspirations — *What you are becoming. No date.*
- Goals with a date — *What you will have done, by a date.*

That is the whole difference. Read it a few times and you should stop needing it, which is the
point of putting it there rather than in the manual.

## Build 175 · 15 September 2026

Everything you asked for in the field test of 170 to 173.

**The Map: every box says what it is.** Build 170 named the two kinds of goal and left an area
reading "2 open" and a project "5 open · due 2031-12-01" — which say how much work is in them
but never what they are. Now the second line begins with **Aspiration**, **Goal**, **Project**,
**Area** or **Resource**.

**The Map legend: symbols, not coloured dots.** The boxes carry symbols and four of the six
legend entries were plain dots, so the legend did not explain the thing it sits under. Every
entry is now the icon the box itself draws.

**The Weekly review: six steps, each saying what to do.** You said 1 and 2 were good because
they name the action. So do the rest now:

3. Read the aspirations again
4. Check the goals are on course
5. Give every project a next action
6. Look over the areas

**Aspirations and goals are two steps, not one.** You asked whether they could be separated,
and they should be: they are different questions asked at different speeds — a goal every three
months, an aspiration every six.

**Due for a look says you can right-click a row.** The line under the heading now names
**Mark reviewed** instead of leaving you to find it.

**The review rhythm is set in words, not in days.** Every week, every month, every 3 months,
every 6 months, every year. The old counter moved 30 days at a time, so from a year it could
never reach six months at all — which is exactly what you asked for.

**An aspiration is now every 6 months** out of the box, as you asked. If your own vault still
says a year, one press on **Every 6 months** under **Settings › Review rhythm** changes it.

**A line under the saved searches**, so they no longer run straight into the tick boxes.

## Build 174 · 15 September 2026

**Two widgets for the iPhone.** The last of the five.

Press and hold the Home Screen, press **+**, search for **PARAGON**.

- **Today's actions** — everything due today or earlier, then your next actions, each with the
  note it lives in and what it serves: the goal in gold, the area in pink. Three sizes.
- **What is waiting** — due today, overdue, waiting in the Inbox, due for a look. A zero is
  grey; a number that wants you is in its own colour.

Tapping either opens PARAGON.

**Open PARAGON once after you add a widget.** The widget cannot open your vault — only the app
is allowed to — so instead the app writes a short summary for it every time it reloads, and the
widget reads that. Until the app has run once there is nothing to read, and the widget says so
rather than sitting empty.

It also tells you which kind of quiet it is showing: **"Nothing since you last opened PARAGON"**
when the summary is from an earlier day, and **"Nothing due, nothing waiting"** when the list is
genuinely empty. Yesterday's work is never drawn as though it were this morning's.

Nothing is written back from the widget, and nothing leaves the phone.

## Build 173 · 14 September 2026

**Saved searches.** The last thing on the roadmap you stopped in build 157.

**Saving one.** Set up the search, then press the **bookmark** button beside the field. A name
is offered already — the query in the same plain words the line under the tick boxes uses.

**Running one.** They appear as chips under the field, on the Mac and the phone. Press one and
it runs. The one you are in is filled with a solid border; the others are grey with a dashed
one, the same two states as every other button in the app. The heading **Saved searches** folds
them away.

**Changing one.** Right-click a chip for **Rename…** and **Delete**. Saving again under a name
you already used changes that one rather than making a second row with the same name, and a
name another saved search has is refused.

**What is saved is the search, not the results**, so it answers for your vault as it is today.
It is only text, so you can change any box after running one.

They live in `.ams-para/searches.json` inside the vault: they travel between the Mac and the
iPhone through iCloud, and they are in your backups. They are not notes, so they never turn up
in Today, the Map, the review or Apple Reminders.

## Build 172 · 14 September 2026

**A review rhythm for every level of the chain.** This is the last piece of the Aspiration
Chain you brought me, and the one real gap that was left.

Until now the app asked about one thing: a project you had not marked reviewed for a week.
A goal could sit untouched for two years and never be mentioned.

Now each level has its own rhythm, because they do not change at the same speed:

- an **aspiration** every 365 days
- a **goal with a date** every 90 days
- a **project** every 7 days
- an **area** every 30 days

**Due for a look** is a new section at the top of the Weekly review, listing everything whose
rhythm has come round. Each row says which level it is, when you last looked at it, and how far
past the rhythm it is. Press a row to open the note with the review still beside it;
right-click for **Mark reviewed**.

A note nobody has ever marked reviewed says **never looked at**, and is always at the top. That
is deliberately not written as a number of days — it is a different thing from "looked at a
very long time ago".

Work that is over is never asked about: a project you dropped, a goal you missed, anything
archived.

**Settings › Review rhythm** sets all four, each with one line saying why it is what it is. The
project number is the setting the review has always had, moved here — one number for it, never
two. Nothing else in your settings is touched.

Nothing new is written into your notes. It all reads the `reviewed:` line **Mark reviewed** has
always written.

## Build 171 · 14 September 2026

**The Weekly review, brought up to date.** It was the second-oldest screen in the app.

- **The top of the screen is a summary, not a table.** It was five rows of a name and a bare
  number, where a zero looked exactly like a fault. Now: today's date, one line saying how many
  tasks you finished in the last seven days, then one orange capsule for each thing that wants
  looking at. **When nothing does, one green capsule says so** — a row of zeroes reads as if
  the app had failed to count.
- **The steps are numbered 1 to 5 and always on screen**, even when empty. They used to appear
  only when they had something in them, so on a good week the walk read 1, 2, 4 and you could
  not tell a step you had finished from one the app had decided not to show you. An empty step
  now says "Inbox is empty" or "Nothing is overdue".
- **Goals are step 3**, between the overdue tasks and the projects. The numbering matches the
  order you work in.
- **"Projects with no goal" moved to the foot of the review.** It sat above step 1, putting a
  question that is not part of the weekly walk in front of the walk itself. It has no number,
  because it is a loose end to tidy when you have time.
- **A goal row can be acted on.** Right-click it for **Mark reviewed**, **Put on hold**,
  **Mark done / missed / dropped** and **Archive** — the menu the project rows have had since
  build 165. The review could say "nothing moved in 30 days" about a goal and offer no way at
  all to answer it.
- **A goal row carries its own icon**: the star for an aspiration, the target for a goal with a
  date.
- **"Achieved" is now "Done"**, the word settled in build 165. The review was the last place
  still using the old one.

The manual has a much fuller **Weekly review** section: what the top of the screen means, the
five steps in order, what the right-click menu does, and what every flag means.

## Build 170 · 14 September 2026

**The Map now speaks the same words as the rest of the app.** It is the oldest screen here and
it had not kept up.

- **A goal box carries the right icon.** A star when it is an aspiration, the target when it is
  a goal with a date — the pair the Goals screen and the sidebar have used since build 168.
  Both are gold, so the colour could never tell them apart.
- **The legend names them**, along the bottom of the Map, beside the colours for areas,
  projects, resources and the archive.
- **The second line under a box says what the note is.** A goal now begins with the word
  **Aspiration** or **Goal**; a goal with a date used to have no word at all.
- **A marked note says Done, Missed or Dropped** in those words. The Map was the one screen
  build 165 missed, so it alone still printed the raw word from the file — "Achieved" where
  everything else says "Done".

The manual has a much fuller **Map** section: what every icon means, what a solid and a dashed
line mean, and how the Map and the Goals screen relate.

## Build 169 · 14 September 2026

Two small things on the Goals screen.

**A goal no longer repeats the aspiration you are already looking at.** Inside an aspiration's
chain, every goal under it carried a **Serves…** chip naming that same aspiration. The chip
stays where it tells you something: when you open a goal on its own, and in **Goals with no
aspiration**. It is also gold now rather than pink — pink is the colour this app uses for an
area, and what the chip names is an aspiration.

**A project's open count sits next to the project.** "2 open" was pushed out to the right edge
of the column, away from the name it counts. With several projects under one goal the numbers
lined up as a column of their own and read as a separate list. They now follow the project's
name.

## Build 168 · 14 September 2026

**The sidebar Goals row now has the goal's icon, not the aspiration's star.** You spotted it:
"If you say that a goal is two circles, and an aspiration is a star. How come the goal button
to the left doesn't have the two circles?" You were right, and it was my mistake.

Until build 164 there was one goal icon, the star, and the sidebar row wore it. Build 164 split
the two apart on the Goals screen — star for an aspiration, target for a goal with a date — but
only there. So the row said **Goals** and showed the aspiration's star.

Now the star means one thing in the whole app: an aspiration. Everywhere else that shows the
goal a note serves picks the right one of the two:

- the sidebar row **Goals** carries the target
- a note's own header shows a star when the note is an aspiration, a target when it has a date
- the **Serves…** chip in a note header shows the star or the target, depending on which one
  it names
- the same for the goal shown on a note row in a list, and for the line under an action in the
  planner that says what it is in aid of

Nothing moved and nothing was renamed. Only the pictures changed.

## Build 167 · 14 September 2026

Two things you reported on 166.

**The All of them button has stopped wandering.** It was in the window's toolbar, so it sat
after whatever else each screen owned and landed somewhere different every time — and it had
no word next to it. It is now in a header row at the top of the Goals column, always in the
same place, with its name beside it: **ALL OF THEM**, or **ASPIRATION** / **GOAL** / **NOTE**
when you are looking at one.

**A goal with no aspiration now says what to do about it.** That group used to state the
problem and leave you to find the fix three screens away. Each of those goals now carries an
orange **Give it an aspiration** button that opens the list of your aspirations, and the group
heading is marked in orange with one line saying why it matters.

Orange rather than red on purpose: orange is what this app has always used for "look at this"
— past a target date, no next action, needs attention. A goal with no aspiration is a loose
end, not an error.

**The two icons, since you asked:** an **aspiration** is a **star** — the north star on
PARAGON's own icon, what you steer by and never tick off. A **goal with a target date** is a
**target** — what you aim at and hit on a day. The aspiration is the higher of the two: Area
→ Aspiration → Goal with a date → Project → Task.

## Build 166 · 14 September 2026

**Your whole life on one screen.** Your idea, and you chose the shape.

The **Goals** screen has a new button at the top right: **All of them**. Turn it on and every
aspiration is open at once, in one outline — each aspiration, the dated goals that serve it,
the projects under those, and the next action on each. Turn it off and you are back to one at
a time.

- It is a **list, not a drawing**. You asked for that, and you were right: the **Map** is
  already the drawn version, and a list can carry the target dates, the per cents and the next
  actions that a drawing cannot.
- Goals with no aspiration are at the foot, so nothing is left out of a screen that claims to
  be everything.
- On the iPhone the same button opens every aspiration in the list. Tapping one closes the
  rest and leaves you on that one.
- It is the same drawing of a chain as the one-at-a-time view, so the two can never disagree.

## Build 165 · 14 September 2026

**A goal or a project can now end three ways: Done, Missed or Dropped.**

Until now there was only **done**. So a goal you gave up on and a goal you reached were written
the same way, and your history said you reached everything you ever stopped working on.

- **Done** — finished, and it did what it was for.
- **Missed** — it is over and it did not happen.
- **Dropped** — you decided not to do it. Nothing failed; you called it off.

**Where you set it.** A new button in the note's header says how the note stands — press it and
pick. That is the first time a **goal** could be marked anything at all from inside the app; the
weekly **Review** could only ever do it for projects, and only "Mark done". The Review now offers
all three.

**What it changes elsewhere:**

- **A goal's per cent counts only Done.** A missed or dropped project is left out of the sum
  entirely. Counting it as finished would be untrue, and counting it as zero would hold the goal
  down for ever.
- **Anything that has ended leaves the working lists** — the Review, the next actions, the Map,
  the "move a task to" list. A goal you dropped is not work.
- On the **Goals** screen, goals that are over sit in closed groups at the foot, **one group per
  ending**, each named after it. A group called Done never holds a goal you missed.
- **Search** has boxes for **Missed** and **Dropped**.

**Nothing in your notes was rewritten.** Old words keep their meaning: `achieved` and `completed`
still read as Done, and `paused` and `someday` still read as On hold.

## Build 164 · 14 September 2026

**The Goals screen has icons now**, one for every link in the chain, and they are the ones the
rest of the app already uses.

- **Aspiration — a star.** The north star on PARAGON's own icon: the thing you steer by and
  never tick off.
- **Goal with a target date — a target.** The one new symbol. An aspiration and a dated goal
  were both gold stars before, which said they were the same thing. They are not.
- **Project — a flag**, as in the sidebar.
- **Task — a ring**, the same circle as a checkbox and the **Done** list.
- **Area — the four squares**, as in the sidebar.

They appear on the rows, on the goal's own screen and all the way down the chain, so the same
thing looks the same wherever you meet it.

## Build 163 · 14 September 2026

**The five small extras on the Goals screen**, the ones you asked for.

- **The measure is on the row.** Your `measure:` line — "cooking in it every day" — is under
  the goal's name in the list, not only inside the goal.
- **Days left beside the target date.** "2026-12-01 · in about 3 months", and **in orange**
  when the date has passed: "11 days over".
- **Goals that need attention are marked.** The same checks the weekly **Review** makes —
  nothing serving it, past its target, nothing moving for 30 days — so the two screens agree.
- **Reached goals fold away.** A goal you mark as reached leaves the lists above and gathers in
  a **Reached** group at the foot, closed. Press it to look back. The same happens inside an
  aspiration: its reached goals sit under a small **Reached** heading below the live ones.
- **What changed lately.** One line on a goal or aspiration: tasks finished in the last 30
  days, how many projects are finished, and when something last moved. If nothing can be
  counted, no line is shown at all — a line saying "0 tasks, no activity" would tell you less
  than nothing.

## Build 162 · 13 September 2026

**The Goals screen is the chain, top to bottom.** You chose this shape from a preview of three.

The **Goals** row in the sidebar no longer gives you a plain list of goal notes. It lists your
**aspirations** — the few things you are becoming. Choose one and everything working towards it
appears beside it:

- the **goals with a target date** that serve it, soonest first, each with how far it has come;
- the **projects** under each goal, finished ones struck through;
- the **next action** on each project, or **No next action** in orange when there is none.

Two groups make sure nothing hides. **Nothing serves these yet** holds aspirations with no goal
under them. **Goals with no aspiration** holds dated goals that stand on their own. Neither is a
fault; they just have to be visible.

Every dated goal says what it **Serves**, so you can see what it is in aid of without opening it.

**The note itself is one button away.** The **Note** button at the top of the column shows the
goal's own text; press it again for the chain. On the iPhone there is no second column, so an
aspiration folds open where it stands.

Searching still works: type in the search field and the ordinary note list comes back.

## Build 161 · 13 September 2026

**The search field holds words only — now it really does.** You sent a screenshot of the iPhone
where the field said *Search for a word* and contained `is:open`. That token came from the
**Not done** box, not from you. Build 157 promised the field was for words and the boxes were
for everything else, and it did not keep that promise.

- The field now shows and edits **only your words**. Ticking a box changes the boxes, never the
  field.
- Typing the syntax by hand still works. Write `type:project` in the field and the **Projects**
  box ticks itself; the token moves out of the field when you leave it.
- A phrase in quotes stays one phrase.

**The tick boxes start folded on the iPhone.** The boxes plus the keyboard left about two rows
of results. They are one press away, the arrow beside the field opens them, and while they are
folded the line underneath still says what you are searching for. On the Mac they are open as
before.

## Build 160 · 13 September 2026

**On the iPhone, Search now lets you put the keyboard away.** You reported that the result list
was very small, because the keyboard sat under the field and the tick boxes and nothing closed
it. Three ways now, so one of them is always to hand:

- **Search** on the keyboard itself closes it.
- **Swipe down over the results** and the keyboard goes away.
- A **Done** button sits above the keys.

Two more things on the phone:

- The tick boxes take less height there, so more of the screen is results.
- The keyboard no longer opens by itself when you arrive with a search already in the field —
  for example after tapping a tag. You came to read the results, not to type.

Nothing changed on the Mac.

## Build 159 · 13 September 2026

**Three more buttons now look like the rest of the app.** Since build 142 a two-state button in
PARAGON says which state you are in: the tint filled in with a solid border when it is on, grey
with a dashed border when it is off. Three buttons had not caught up.

- **Hide finished**, in a note's task box, is now that button. It used to swap its own symbol
  between an open and a closed eye, which could be read either way. It is always the closed eye,
  lit when finished tasks are hidden. The number of finished tasks sits beside it as plain text,
  so you can see it whether they are hidden or not.
- **The Calendar's Schedule / Note switch** was a segmented control. It is now a heading that
  says what you are looking at — SCHEDULE or NOTE — and one button beside it.
- **Arrange**, on the Map, was a plain button that looked much the same on or off. It is now lit
  when Arrange is on.

Nothing about what these buttons do has changed.

## Build 158 · 13 September 2026

**Quick capture on the iPhone is rebuilt.** You chose the shape and all four extras.

- **The words get the room.** The writing area fills the sheet instead of two cramped lines with
  an empty space under them.
- **It shows what it understood.** Write `>2026-09-15 !! #travel` and chips appear under the
  field: **Due 15 September**, **Priority !!**, **#travel**. If a chip does not appear, the app
  did not read that part — you can see it before you save.
- **Buttons write the syntax for you**: Today, Tomorrow, Date…, **!**, **!!**, **#tag**. You
  never have to remember it. Typing it by hand still works.
- **Where it goes** is a row of chips, not a dropdown. **A task** or **A note** are two words,
  not a switch labelled "As note, not task" — which was a double negative.
- **Save is a wide button above the keyboard.** It used to hang off the right edge, because the
  panel asked for a fixed Mac width of 460 points on a phone about 390 wide.
- The long syntax line moved behind the **ⓘ**, where it can be read whole.
- **The four small things:** the button says **Caught it** for a moment after saving; the tray
  symbol gives a short flourish; the empty field greets you differently each time; and a quiet
  line says how many you have caught today.
- The flourish is off when Reduce Motion is on in iOS Settings.
- The Mac panel keeps its shape, and gains the read-back chips and the syntax buttons.

## Build 157 · 13 September 2026

**Search is rebuilt around tick boxes.**

- The field at the top is now only for **words**. Everything else is a row of boxes you can see
  without opening a menu, so one look tells you what you are searching for.
- **Tasks**: Not done, Done, Overdue, Today, This week, This month, No date. Tick any of them
  and the results are tasks rather than notes — which the screen now says, where before it just
  quietly changed.
- **Kind of note**, **How the note stands** and **Tags** have their own rows of boxes.
- **Two boxes in the same row mean either of them.** That is new: before, picking a second one
  replaced the first. Boxes in different rows are added together.
- **Why “done” found nothing you wanted.** The word **done** and the **Done** box are two
  different questions, and the old screen made them look the same. Writing done searches for
  those letters in your notes; the Done box asks for finished tasks. The boxes make it plain.
- **When nothing matches, the screen says why.** That is the fault you found. Searching for the
  word **done** came back empty because a box was still ticked from before: `is:done done` asks
  for *finished tasks whose own name contains the word done*, which nobody has. The old screen
  showed that as a blank list. Now it says so, and tells you how many notes the word alone is
  in, and which boxes to untick.
- The button beside the field folds the boxes away on a narrow column, and a line then says the
  search in words.
- Everything you could type before still works, typed or ticked.

## Build 156 · 13 September 2026

- **The New note button is the one you chose**: a plus in a filled circle, in the colour of the
  section you are in — green in Projects, pink in Areas, gold in Goals. It was a grey pencil
  before, the same weight as everything else in the bar.
- The colour is the same one laid over the note column, so the button says which list it will
  add to. It still makes a note in the section you are looking at, and ⌘N still works.

## Build 155 · 13 September 2026

- **The Map's name is on the left now, like every other screen.** Its zoom and **Arrange**
  buttons had been put in the slot that sits *before* the window's name, so the word **Map** was
  pushed out past them. They have moved to the right, beside **Export**.
- **The window says "Time Blocks" when you are in Time Blocks.** It said "Actions". The heading
  inside the middle column still says **ACTIONS**, because that is what that column is.

## Build 154 · 13 September 2026

The note's toolbar, from your screenshot.

- **Rename has no button of its own any more.** It was a second pencil next to the Edit pencil,
  and a whole toolbar slot for something you do rarely. **The note's name now sits in the row
  under the toolbar, beside "Project" or "Area", and you press it to rename.** That is where its
  goal, its tags and its deadline already are, and all of those are changed by pressing them.
  On the iPhone rename stays in the **…** menu.
- **The Archive button shows the movement**: a small arrow coming down into the box, so it reads
  as "move this note to the Archive" rather than "here is the archive".
- **The Edit pencil is easier to see.** Both of its states are stronger now — still the tint
  with a solid frame when Edit is on, still grey with a dashed frame when it is off, only with
  enough contrast to read in a toolbar. The same lift reaches the **calendar** button in
  Calendar › Day, which uses the same control.
- With rename gone there is one pencil in that row, not two.

## Build 153 · 13 September 2026

- **Fixed, from your field test: each `TB:` is on its own row.** Two blocks written under each
  other were one paragraph in markdown, so they were drawn joined on one line. There is now a
  blank line between them in the daily note, which is what markdown needs, and it is right in
  any editor, not only here.
- **A plan line in Read mode is drawn as a block**, in the same orange as the planner, instead
  of as ordinary grey text.
- **The sidebar order changed, as you asked.** **All actions**, **Recent** and **Done** now sit
  together, straight above **Deleted**. The rest keeps its order.
- **All actions has a ring for an icon**, since **Done** is that same ring with a tick in it —
  and a task's own checkbox is the same circle.
- **A task now shows what kind of note it lives in.** In the planner's action list and
  everywhere else, the grey page beside a note's name became the note's own symbol: a star for
  a goal, a flag for a project, the four squares for an area, a calendar for a daily note, in
  that kind's colour. Two notes of different kinds no longer look identical.

## Build 152 · 13 September 2026

Your three points from the screenshot.

- **A plan line is written as `TB: 12:45-13:45 special time block`**, not as a bullet. It no
  longer renders as a list, and `TB:` says what the line is. Lines written before this still
  read exactly as they did; the next time a day's plan is saved, they are tidied to the new
  shape.
- **Time blocks are orange**, not teal. The lane, the cards, the buttons that make a block and
  the sheet all take the new colour.
- **Drag a block to move it** (on the Mac). Pick it up and slide it; it snaps to five minutes
  and shows its new time while you move. **Drag the grip at the foot of a block** to make it
  longer or shorter. A click without moving still opens the block for editing.
  On the iPhone a block is tapped, not dragged: the lane lives inside the page's scroll, and a
  drag there belongs to the scroll.
- **The block sheet is rebuilt.** The two long dropdowns are gone. There is a proper time field
  with **−** and **+** for quarter hours, a row of lengths to press (15 min up to 4 h), and one
  line underneath saying what it comes to: **09:30 – 11:00 · 1 h 30 min**.
- If you drag a block that is also in Apple Calendar, the event moves with it.

## Build 151 · 13 September 2026

- **A plan block can now be put into Apple Calendar, one block at a time.** Right-click a block
  in the planner (long-press on the iPhone) and tick **In Apple Calendar**. The same tick is in
  the block's own sheet, as **Also put this block in Apple Calendar**.
- A block that is also an event shows a small **calendar** symbol beside its time, so you can
  see which ones are out there without opening a menu.
- The event goes to the calendar you chose under **Settings › Apple Calendar › Time blocks
  go to**, the same one the old Time Blocks use.
- **It keeps up with you.** Change a block's name, its time or its length and the event moves
  with it. Take the tick off, or remove the block, and the event is deleted.
- **Nothing changed by default.** A block is still only a line in your daily note under
  **Plan**. This is the one way out, and only when you ask for it.
- One thing to know: if you edit a block's line **by hand** in the daily note, the app loses
  sight of which event belonged to it. The event stays in Apple Calendar — nothing you wrote is
  deleted behind your back — and you can remove it from the **Blocks in Apple Calendar** list.

## Build 150 · 13 September 2026

- **The planner is in the ordinary window now.** Choose **Time Blocks** and you get the day's actions in the middle column and the day itself — Calendar beside your own blocks, on one hour ruler — on the right. No floating window needed.
- **The floating window is still there** as an extra: **Go › Plan the Day…** (⇧⌘P). It shows the same three parts and can stay up while you work in a note.
- **Two events at the same time no longer sit on top of each other.** They stand side by side at half the width, three at a third, and so on. The same goes for your own blocks.
- **The blocks in Apple Calendar are one button away**: the small calendar symbol at the top right of the day. They are unchanged.
- **Confirmed, because you asked:** a block you make in the planner is never written to Apple Calendar. It is a line in the daily note under **Plan**, and nothing outside PARAGON ever sees it.
- Fixed: on the Mac the right-hand side said **No note open** when you chose Time Blocks. My mistake in build 148 — the change landed in the wrong half of the file.

## Build 149 · 13 September 2026

- **The Actions column in the planner is now made of real task rows.** Each one has a **checkbox**: tick it here and the task is ticked in its own note. Right-click a row (long-press on the iPhone) for the usual task menu — rename, give it a date, make it the next action, move it.
- **Every action shows what it serves:** the goal its note belongs to, in gold, or the area it sits in, in pink. A list of things to do says little without that.
- A line under the heading says what the list is: **due today or earlier, then your next actions**.
- **The column scrolls on its own**, so a long list no longer pushes anything about.
- The **+** button on a row is what makes a block for it. Pressing the words now edits the task instead.
- **On the iPhone the planner is one page**: the day's hours first, the actions under them. Three columns never fitted on a phone.

## Build 148 · 13 September 2026

- **Time Blocks in the sidebar now opens the planner.** In build 147 it still showed the old Apple Calendar form, and the planner was hidden behind a menu item. That was not what we agreed — my mistake.
- On the Mac the planner fills the right-hand side the moment you choose **Time Blocks**. The middle column keeps the Apple Calendar blocks, now under their own name, and has a button to open the planner in a window of its own.
- On the iPhone, **Time Blocks** is the planner. The **calendar** button at the top right leads to the Apple Calendar blocks.
- Nothing was deleted. The blocks you already made are still events in Apple Calendar and still work exactly as before.

## Build 147 · 13 September 2026

- **Plan the day.** A new screen with three parts side by side: the day's **Calendar** on the left, your own **Time blocks** in the middle, and the day's **Actions** on the right. Calendar and blocks hang on the same hours, so you see at once whether a block lands inside something already booked.
- **A block is only for you.** It says where you mean to be or what you mean to work on. It is never written to Apple Calendar and never becomes a task.
- **Blocks are kept in the daily note**, under a heading called **Plan**, as plain lines like `- 09:30-11:00 Deep work`. They sync with everything else, and you can read or correct them by hand in any editor.
- Press an action on the right to make a block for it. Press a block to change it, or right-click it (long-press on the iPhone) to remove it.
- **How to get there:** on the Mac, **Go › Plan the Day…** (⇧⌘P) opens it in its own window; on the iPhone, **Time Blocks › Plan the day…**.
- **The old Time Blocks are untouched.** Those are still real events in Apple Calendar, and the section still works exactly as before. The two kinds sit next to each other so the difference is visible.

## Build 146 · 13 September 2026

- **The month grid in Calendar › Day is off until you ask for it.** Thirty-one dated cells took more of the column than the day itself. A **calendar** button in the day's top row turns it on and off, lit when it is on, and it stays as you leave it.
- **A tag can no longer come out with a `#` inside it.** Typing "Claude #Productivity" in a tag field made the single tag `Claude-#Productivity`, which nothing could ever match on a task line. Every `#` is now taken out, not just one at the front, and repeated hyphens are squeezed.
- If you already have a tag like that: open **Tags**, right-click it (long-press on the iPhone) › **Rename…** and write it properly. It is fixed in every note and task at once.

## Build 145 · 12 September 2026

- **A tag can be renamed everywhere at once.** Right-click a tag in **Tags** (long-press on the iPhone) › **Rename…**. Every note and every task that carries it is changed — both the `tags:` lines and the `#tag` words.
- **A tag can be deleted everywhere.** Same menu › **Delete…**. The tag is taken out; the notes and the tasks themselves are kept.
- **A tag can be made before anything uses it.** The **Tags** screen has a field at the top: write a word, press **Make**. It is offered in every note's **Tags…** panel from then on, and the list shows it as **not used yet**.
- `#next` cannot be renamed or deleted: it is how the app marks a next action.
- A longer tag that starts the same way is never caught — renaming `#travel` leaves `#travelling` alone. Nor is a `## Heading`.
- If a note cannot be written, the app names the notes that still carry the old tag instead of letting it pass quietly.

## Build 144 · 12 September 2026

- **A note's tags can be set from the note.** The top row of every note now has a **Tags…** button. It opens a small panel: a field for a new tag, and under it every tag you already use, with a circle you press to put one on this note or take it off.
- Build 143 gave tags a screen and left them unwritable: the only way to tag a note was to type the `tags:` line yourself. That still works, and so does `#tag` on a task — all three ways write the same thing.
- A space in a new tag becomes a hyphen, and a leading `#` is added for you. A tag with a space in it could never be written as `#tag` on a task line.
- **Docs › How PARAGON works** now sets out all three ways in one place, under **Tools: templates, snippets and tags**.

## Build 143 · 12 September 2026

- **A new group in the sidebar, "Tools".** It holds **Templates**, **Snippets** and **Tags** — the three things you use *on* your notes rather than notes themselves. Press the word **Tools** to fold it away; it stays as you leave it.
- **Snippets has a row of its own.** It used to be one line inside Templates, where it was easy to miss. The list shows every block and what is in it, and the file is edited beside it (on the iPhone, one tap down).
- **Tags is new.** Every tag in your notes, most used first, with how many notes and how many tasks carry it. Press a tag to open it: the notes carrying it, then the tasks, open ones first. Press a note or tick a task straight from there — the list stays where it is.
- The field at the top finds a tag by name. Right-click a tag (long-press on the iPhone) for **Search for #tag**, which hands it to the Search screen.
- **Templates left the Actions list** and is now the first row under Tools.

## Build 142 · 12 September 2026

- **The add-a-task field says just "Add a task…".** The old grey text was eighty-four characters long. On the iPhone you only ever saw the first few words, and it vanished as soon as you started typing.
- **A new ⓘ button beside the field** opens what you can write there: a date, a date and a time, a priority, a tag, a repeat. It stays available instead of being almost readable once.
- **On the iPhone, Add and Snippet are now symbols.** The field gets about twice the width. **Add** only takes its colour when there is something to add.
- **The Edit / Read button is one pencil, not two symbols.** It used to show an eye while you were writing and a pencil while you were reading — the thing you would get, not the thing you were in. Now it is always a pencil: lit with a solid frame means you are writing, grey with a dashed frame means you are reading.
- The Mac's toolbar has the same pencil in place of the old Edit / Split / Preview switch.
- **Split view is gone**, on both the Mac and the iPhone. There are two modes now: writing and reading.

## Build 141 · 12 September 2026

- **A goal now shows how far it has come.** A bar and a per cent, worked out from the projects under it. It appears on the goal's own page, in the Goals list, and on the goal's row in **Weekly review**.
- **How the figure is worked out.** Every project under the goal counts the same, whatever its size. A project that is marked done counts as a whole one; a project still running counts as the share of its tasks that are ticked. The goal's figure is the average.
- **Areas are left out on purpose.** An area is something you keep up, not something that finishes, so counting one would hold its goal below full for ever.
- **An aspiration counts through its goals.** Each dated goal under it contributes its own figure, one share each.
- **A goal with nothing under it shows no bar at all.** That is not nought per cent; there is simply nothing to measure yet.
- **A goal whose projects are all finished is no longer called unserved.** Before this, marking the last project done made the goal read "No project or area serves this".
- A goal's page now also lists the finished projects under it, struck through and marked "done".

## Build 140 · 12 September 2026

- **"Hobby or homeless?" is now called "Projects with no goal".** The old heading was a piece of wordplay that meant nothing unless you already knew what it was getting at. The sentence under it now also says what to do.
- **A project can be given a goal from the note itself.** Press **Serves…** at the top of a project, the same button an area already had, or right-click the project in the list. Until now the review asked which goal a project served and the only way to answer was dragging its box onto a goal on the Map.
- A project is offered the dated goals first, an area the aspirations first.

## Build 139 · 12 September 2026

- **The sentence under "Hobby or homeless?" is readable again.** It was cut off after a few words; it now wraps onto as many lines as it needs.

## Build 138 · 11 September 2026

- **The rows in Weekly review no longer squash their own text.** In a narrow middle column the counts were being crushed until the words broke apart — "projects" became "project s" and a date came out over three lines. Each count now stays whole and moves down to the next line when it does not fit.
- Long project and goal names stop after two lines instead of running down the column.

## Build 137 · 11 September 2026

- **One date chooser, used everywhere a date is picked.** The same panel now opens for a project's deadline and for a task's date: a field at the top where you write 2031-12-01, a calendar underneath for dates close at hand, and **Clear**, **Cancel** and **Set**.
- Picking in the calendar fills the field in, and **Set** always reads the field. While the text is not a date the app can read, the hint under it turns red and **Set** is greyed out.

## Build 136 · 11 September 2026

- **A project's deadline can be typed.** The **Due** button now opens with a field at the top: write 2031-12-01 and press Return. The calendar is still there underneath for dates close at hand, and picking in it fills the field in.
- This was needed because a goal can be years away. Reaching December 2031 by pressing the calendar's arrow was about forty presses.

## Build 135 · 11 September 2026

- **Pressing a project under "Hobby or homeless?" no longer throws the review away.** The note opens beside the list on the Mac, or one screen forward on the phone, and the Weekly review is still there when you come back. Before this it jumped to the Projects section and there was no way back to where you were.

## Build 134 · 11 September 2026

- **An area can now say which aspiration it serves.** A **Serves…** button at the top of an area note, beside "Part of…", and the same choice when you right-click an area in the list. Aspirations are offered first.
- The app has always read that line — one of the review's flags says "No project **or area** serves this" — but the only thing that could ever write one was dragging an area's box onto a goal on the Map, which nobody would find. Now it is one click.
- This is what gives an aspiration a home: Endurance holds "an endurance athlete still racing at seventy" instead of it floating on its own.

## Build 133 · 11 September 2026

- **A goal with no date is now called an Aspiration**, not a "Life goal". PARAGON is PARA plus the aspiration, the goal and the north star, so the app may as well use its own word. The Horizon choice says **Aspiration**, and a dated goal's box says **Serves aspiration**.
- Only the wording changed. Nothing was written to your notes, nothing moved, and every existing goal is exactly where it was.

## Build 132 · 11 September 2026

- **The weekly review now checks the chain**, the first step of the aspiration work. Three new questions, all answered from notes you already have:
  - **A project that is due after the goal it serves.** That cannot be true and the goal still be reached, so it is flagged as needing attention.
  - **A dated goal that only an area serves.** An area is a standard you keep up, not a path to an outcome on a date — so the goal has no way of being reached yet. A goal reached through dated sub-goals is fine, and so is a life goal held by an area: that is exactly where a life goal belongs.
  - **Projects with no goal at all**, gathered into their own short list headed "Hobby or homeless?". These are never counted as needing attention and never shown as a problem: work with nothing above it is often exactly right. The review asks once, rather than colouring every such project red.
- **A project can now be given a deadline.** Press **Due** at the top of a project note and pick a date; press it again to change or clear it. Until now the app read a project's deadline but had no way to set one, so the "past its due date" check had never once been able to fire.
- Nothing in your vault is changed or required. Every check reads what is already there.

## Build 131 · 11 September 2026

- **Housekeeping only — nothing in the app changed.** The folders, targets and the Swift package inside the project were still called AMSPara; they are now called Paragon, so the project reads the same way the app does.
- You will not see any difference. If anything at all looks different from build 130, it is a mistake and worth telling me about.

## Build 130 · 11 September 2026

- **The app is called PARAGON.** The name under the icon, the window title, the Mac menu bar, the Help window, the share sheet on the iPhone, the permission prompts, the exported map's file name and this manual.
- Nothing underneath moved. It is the same app in TestFlight, updated the same way, and your vault, your reminders and your settings do not notice the new name.
- **On the Mac the application file is now PARAGON rather than AMSPara**, so Finder and the Dock say the right thing. After this update you may find the old AMSPara still sitting in your Applications folder: it can be dragged to the Trash. Keep the one that shows build 130.
- Four things keep the old name on purpose, because something else depends on each: the app's identity to Apple, the `ams-para:` marker that ties every mirrored reminder to its task, the hidden `.ams-para` folder in your vault, and the `amspara://` link other apps use to add to your Inbox.

## Build 129 · 11 September 2026

- **A new app icon**, the first step of the rename to PARAGON. A white frame now sits outside the gold goals frame, with a small star resting on its top edge. Everything inside — the four PARA squares and the tick — is unchanged.
- The star fades out at the two smallest Mac sizes, which only ever appear in a Finder list. It is there in the Dock, in the sidebar and on the Home screen.

## Build 128 · 11 September 2026

- **A single tap puts the cursor in a note on the iPhone.** No more pressing and holding. The cause was a link-tap handler added in build 114: a text view uses your tap to place the cursor, and having a second handler watching for taps made that ambiguous. It is gone.
- **Following a `[[link]]` on the phone is done in Read**, which is one tap away in the bar below the note. Edit is for writing, Read is for reading and following links.
- The Read / Edit button is now just its icon, in a border.

## Build 127 · 11 September 2026

- **A Read / Edit button on the iPhone**, in the bar at the bottom of the note where it is always in reach. It says what it will switch to. A note left in Read looks exactly like an editor that refuses to type — which is what went wrong yesterday — so it is one tap now instead of a setting buried in the ⋯ menu. Split is gone from the phone; it was never useful on a screen that size.
- **The note text is no longer penned into a small window while you edit.** It grows to its full height and the page scrolls as one thing, so a long note reads properly instead of showing a slice of itself.

## Builds 123 to 126 · 11 September 2026

- Four builds spent chasing a fault that was not there. Typing in a note on the iPhone appeared to be broken; it was in fact set to Read, where there is nothing to type into. The changes made and undone in between left the app exactly where it started. Build 127 fixes the real inconvenience — and makes Read impossible to be stuck in without noticing.

## Build 122 · 11 September 2026

- **Fix: on the iPhone the long press into the Work section only ever worked once.** It opened Work the first time and did nothing every time after, until the app was quit. Now every press opens it. (The Work row at the foot of the Browse list was still there in the meantime — that was the way back in.)

## Build 121 · 10 September 2026

- **The "More" fold in the new-note sheet is gone.** Everything is on screen at once: name, kind, and whatever settings apply to that kind. Nothing to open.

## Build 120 · 10 September 2026

- **Fix: ⌘N opened an empty second window instead of the new-note sheet.** macOS puts its own **New Window** on ⌘N and it was winning; the app's New Note had the same shortcut and never got a look in. ⌘N is now New Note, and New Window is gone from the File menu — one window is what this app is for.

## Build 119 · 10 September 2026

- **New note (⌘N) asks one thing, not nine.** The name field is first with the cursor already in it, so a note is a name and Return. Under it, the four kinds as coloured buttons — the same gold, green, pink and blue as the sidebar — and one line saying what that kind is for.
- **Everything else is behind "More".** Template, what an area is part of, a goal's horizon and target date, the goal a project serves. It is shut every time the sheet opens, and the label says what is inside so you know when to open it.
- **A project can now name the goal it serves as you make it**, instead of being opened afterwards to add the line by hand.
- The heading says **New project**, not "Projects" — it is one note, not the list it lands in.

## Build 118 · 10 September 2026

- **Back and Forward.** Follow a link to another note and **Back** brings you where you were — the ‹ button at the top left of the window, ⌃⌘←, or **Go › Back** in the menu bar; ⌃⌘→ goes forward again. It remembers the whole trail, not just the last step, and steps over notes deleted in the meantime. (The iPhone already had its own back arrow.)
- **A link to a note that does not exist yet can make it.** ⌘-click the link — or click it in the new **Not made yet** list in the note's **Linked notes** section — and you are asked what kind of note it should be. It is created with the link's own words as its title, opened, and the link works from that moment. A link written inside a work note makes a work note.
- Links with no note behind them are no longer silent: they are listed under **Not made yet**, so a link you meant to follow up is visible rather than forgotten.
- **`[[Note|call it something else]]` and `[[Note#a heading]]` now work everywhere.** They already worked in Preview; clicking them in the editor, and the Linked notes lists, went looking for a note with the whole phrase as its name and never found one.
- While notes are still arriving from iCloud, the app no longer says a note does not exist — it says how many are still coming. Saying otherwise is how you end up with two copies of the same note.

## Build 117 · 10 September 2026

- **Fix: the long press could not open Work on the iPhone.** The "Browse" title the press belongs to was drawn behind iPhone's own large title, so nothing ever reached it. The title is now the small one at the top of the screen and takes the press properly — and opening Work goes straight to it instead of only adding the row at the foot of the list.
- **A second way in on the iPhone: long-press the "Build 117" line** at the very bottom of the Browse list. Easier to hit than the title.

## Build 116 · 10 September 2026

- **Fix: choosing a note from the `[[` list spun the app.** Writing the chosen title told the editor to update, which told the app to update, which told the editor again. The chosen title is now written once and everything the editor reports back waits until the screen has finished drawing.

## Build 115 · 10 September 2026

- **Fix: the `[[` list was cut off at the bottom of the editor.** When the cursor is near the foot of the note there is no room under it, so the list now opens upwards instead — and it always stays inside the editor rather than sliding off an edge.

## Build 114 · 10 September 2026

Linking notes with `[[ ]]`.

- **Type `[[` and a list of your notes drops under the cursor.** Keep typing to narrow it, ↑ ↓ to move, Return or a click to put it in. It completes to `[[Title]]` and leaves the cursor after the brackets.
- **⌘-click a link to open that note** (a tap on the iPhone, and a plain click in Preview). An ordinary click still just places the cursor, so editing is never hijacked; on the Mac the pointer turns into a hand over a link.
- **Linked notes is now two lists: "Links to" and "Linked from"**, so you can see who points at whom instead of one mixed pile. Links in the text count as well as `goal:`, `area:`, `parent:` and `related:` lines.
- **Work notes and ordinary notes never see each other.** Inside a work note, `[[` offers work notes; everywhere else it offers the rest of the vault.
- A link to a note that does not exist yet says so when you click it. Making one from the link comes next.

## Build 113 · 10 September 2026

- **The coloured line along the top of the right-hand panel is gone.** Only the even tint is left.

## Build 112 · 10 September 2026

- **A separate place for work notes.** Plain notes in a `Work` folder in your vault, kept out of Today, All actions, the Map, the weekly review, the main search — and out of Reminders. No projects, no goals, no dates: notes and a list of them, with its own search box.
- **It is not in the sidebar.** To open it: **long-press the PARA heading** in the sidebar on the Mac (or ⌃⌘W), and **long-press the Browse title** on the iPhone. The row appears until you press **Hide** or quit the app.
- The Work folder is only created when you make the first note there, so a vault without work notes shows no sign of it.

## Build 111 · 10 September 2026

- **The iPhone gets the section's colour too.** The phone has no right-hand panel, so the note screen itself carries the tint of the section you came in through.

## Build 110 · 10 September 2026

- **The gradient at the top of the right-hand panel is gone.** The section's colour now sits evenly over the whole column, with the hairline along the top.

## Build 109 · 9 September 2026

- **The section's colour on the right-hand panel is stronger**, both over the whole column and in the wash at the top — the setting you chose from the preview.

## Build 108 · 9 September 2026

- **The section's colour now sits over the whole right-hand panel**, not only the top of it: the faintest tint everywhere, a little more at the top, and the hairline. The note's own text area keeps its plain background so reading and writing are unaffected.
- The "Linked notes" heading takes the note's colour, like "Tasks" already did.

## Build 107 · 9 September 2026

- **The right-hand panel now carries the colour of the section you are in** — green in Projects, pink in Areas, gold in Goals, blue in Resources and Templates, and so on. A hairline along the top and a wash that has faded away before it reaches the text. It follows the section rather than the note, so it stays put as you click from one note to the next.

## Build 106 · 9 September 2026

- **A sync will not start while notes are still coming from iCloud.** It would only see part of your vault. The app says how many are outstanding and asks you to try again in a moment. (Even before this, a sync never deleted a reminder whose note it could not read — that rule is what kept your Reminders intact today.)
- **The app is now told when a note arrives** instead of looking every ten seconds. macOS reports what iCloud is doing with the vault's files, so notes appear as they come down. The old check stays underneath as a backstop.

## Build 105 · 9 September 2026

- **A note iCloud cannot deliver now says "still coming from iCloud"** rather than showing a technical file error. Build 104's fix stands; this is the wording and the count behind it.

## Build 104 · 9 September 2026

**This is the fix for the empty vault.** Your diagnostics showed the app had loaded exactly one note and had not failed to read a single file — it never saw them. When iCloud has not sent a note to a device it can leave a hidden marker where the file belongs, and the app's note listing skipped hidden files. Finder showed you `Testproj.md` with a cloud; the app looked in the same folder and found nothing at all.

- **The app now sees those markers, counts them, and fetches the notes behind them** — a few per load, so it never sits still, with the rest listed as "still coming from iCloud".
- **Opening such a note now fetches it** instead of reporting it missing.
- Neither the restore nor anything you did caused this. The notes were in iCloud the whole time.

## Build 103 · 9 September 2026

- **Copy Diagnostics has a shortcut that works.** It was ⌥⌘D, which is macOS's own "hide the Dock" — the app never saw it. It is **⌃⌘D** now (control, not option), and it is still in the Help menu.

## Build 102 · 9 September 2026

- **A vault that is all in iCloud now fills in gradually instead of stopping the app.** Waiting for a note to come down takes time, so the app waits for a handful per load and asks for the rest, then picks up the next few seconds later. You see the count going down rather than a frozen app — and the phone cannot be killed for taking too long.

## Build 101 · 9 September 2026

- **The app now reads a note the way TextEdit does.** This is the real cause of today's scare. When iCloud keeps a file's contents off the Mac, a plain read of it fails — so TextEdit could open a note while the app called it unreadable and drew an empty vault. The app now asks macOS for the file properly, which makes iCloud fetch it first and wait for it. Notes appear whether or not they happen to be downloaded.
- **Fix: the iPhone app could be killed at launch.** Since build 95 the app asked iCloud about every file in the vault before it finished starting up. On a phone that can take long enough for iOS to give up and close the app. That now happens in the background, out of the way of starting.

## Build 100 · 9 September 2026

- **The app no longer shows an empty vault when it simply cannot read your notes.** If iCloud has the contents and this device does not, the app used to draw "No projects yet" — which looks exactly like losing everything. It now says how many notes are still coming, at the foot of the sidebar and in place of the empty-section message, with an **Ask iCloud again** button.
- **It asks iCloud for those notes itself.** A note it could not read because the contents are not here is now requested there and then, so it arrives without you going into Finder.
- **A sync report lists them too**, so it is plain that a sync ran while part of the vault was missing — and, as before, nothing is deleted in Reminders for a note the app cannot see.

## Build 99 · 9 September 2026

Hardening, first part: the things the app does that touch several notes at once.

- **Moving an action between notes can no longer lose it.** It used to be taken out of the first note and then written to the second; if that second write failed — the note had just changed on the other device — the action was gone from both. The order is turned round: the receiving note is written first, so the worst case is the action appearing twice, and the app says so and tells you which one to delete.
- **Making a note out of an Inbox line can no longer lose the line.** The line was removed first and the note made afterwards, so a name already in use meant the line vanished and no note appeared. The note is made first now.
- **Renaming tells you when it could not follow every link.** A rename rewrites `goal:`, `area:`, `parent:` and `[[links]]` in every note that named the old title. Failures were silently ignored, leaving links pointing at a title that no longer existed. Now you are told how many notes still name the old title, so you can search for it.
- **A rename makes a backup first.** It is the one action that can touch every note in the vault.
- **Rearranging a list reports once, not once per note.** And a note whose file changed while you were dragging is written again rather than skipped.
- Underneath all of these: when a note has changed on disk in the moment between reading and writing, the app now re-reads it and makes the same change to what is actually there, instead of giving up. Nothing of the other device's work is overwritten.

Hardening, second part: the backups.

- **Restoring a backup no longer stops halfway.** A single file it could not write used to abort the whole restore, leaving the vault half old and half new with no word about which. It now restores everything it can and tells you exactly which files it could not put back.
- **A backup is no longer lost to one unreadable file.** The same problem the other way round: one file that could not be copied meant no backup at all that day. Those files are skipped, listed inside the backup in `skipped.txt`, and the rest is saved. If nothing at all could be copied, you are told rather than left with an empty folder that looks like a safe copy.
- **A second backup in the same minute was invisible.** It got a slightly different folder name that the app could not read back, so it never appeared in the list and was never cleaned up.
- **A backup asks iCloud for anything missing first**, so it does not quietly copy a vault with holes in it.
- Restoring is now covered by tests: that a deleted note comes back, that a note made after the backup is left alone, that your current text is kept as a backup of its own first, and that a file it cannot write is reported.

## Build 96 · 9 September 2026

- **The manual explains iCloud.** "Mac and iPhone together" now says how the files actually move between the two devices, why a new note or template can take a moment to appear on the phone, what the "coming from iCloud" line means, and what to do if something looks stuck.

## Build 95 · 9 September 2026

- **A new template made on the Mac now arrives on the iPhone.** iCloud does not send a file to the phone until something asks for it; until then there is only a hidden stub, which the app walked straight past — so the template looked as though it had never left the Mac. The app now asks iCloud for everything it is missing at launch, when you open a vault and once a minute after that. Templates still on their way are listed as "coming from iCloud".
- **The same was true of notes**, not only templates: one written on the Mac could stay invisible on the phone. Fixed by the same change.
- **A note or template that is on its way is no longer written over.** Because the stub is not the file, the app thought the note was missing and could make a fresh empty one in its place — which would then collide with the real one in iCloud. Everything that creates, renames or archives a file now counts a file that iCloud is still sending as being there.

## Build 93 · 9 September 2026

- **Fix: the Templates list drew its rows on top of each other.** The headings and the rows below them overlapped. Plain sections now, with a fold arrow in each heading.
- **Fix: New template really asks what it makes.** The choice was in a Mac alert, which quietly drops anything that is not a text field — so the picker never appeared and every new template came out a project. It is a proper panel now, with the name, what it makes, and a sentence explaining what a template is for.
- **The Save button says "Saved" when there is nothing to save**, instead of going grey. Your typing is written a moment after you stop; the dimmed button made it look as though nothing had happened.
- **A template edited on one device now reaches the other.** The app watches the notes for outside changes but was not watching the Templates folder, so an edit made on the Mac sat there until the phone was restarted.
- A template that is not the default for its kind says so: "One way to start a project note. Pick it under New note › Start from."

## Build 92 · 9 September 2026

- **Fix: you can type in a template.** The editor showed the file but would not take a keystroke on the Mac. It is the same editor the notes use now — proven, and it colours the markdown while you write.
- **Templates save themselves** a moment after you stop typing, and when you switch to another one or leave the section. **Save** (⌘S) is still there when you want to be sure.

## Build 91 · 9 September 2026

- **The manual now says "long-press" where it meant it.** It said "right-click" throughout, which is a Mac instruction and no help on the iPhone. Every place that offers a menu now names both, and there is a line near the top saying that right-click on the Mac is long-press on the phone.

## Build 90 · 9 September 2026

- **Templates are grouped and colour-coded** by the kind of note they make — Goals gold, Projects green, Areas pink, Resources blue — and each group folds.
- **You can have more than one template for the same kind.** Press **+** to add, say, a "Client project" beside the plain Project one; it starts as a copy of the current one. When a kind has more than one, **New note** grows a **Start from** picker. The template named after its kind stays the default.
- **Rename** and **Delete** a template by right-clicking it. Deleting removes only the template; notes made from it are untouched.
- **Fix: templates can be opened and edited on the iPhone.** Tapping one did nothing there — the phone had no way to push the editor. It opens like a note now.

## Build 89 · 9 September 2026

- **Fix: the note screen's top bar on the iPhone.** Edit / Split / Preview, Archive, Rename and Delete were all separate buttons up there, and on a phone they collided — the three-way switch was squeezed into a few overlapping letters next to the title.
- They are one **⋯** menu now: the view mode at the top, then Rename, Archive and Delete. The Mac keeps the row of buttons, which it has room for.

## Build 88 · 9 September 2026

- **Templates, in the app at last.** A new **Templates** section in the sidebar lists the files a new note starts from — Project, Area, Resource, Goal, Daily, Weekly — and lets you edit and save them without leaving AMS PARA. They were always there in your vault's `Templates` folder; now you can reach them.
- **Snippets.** Ready-made blocks of tasks you drop into a note: press **Snippet** beside Add a task. The app starts with **Delegate**, **Waiting for**, **Meeting**, **Decision**, **Errand** and **Follow up**.
- A snippet can ask for words. `{{who}}`, `{{what}}` and the like are filled in from a small form; `{{date}}`, `{{tomorrow}}` and `{{week}}` are worked out for you.
- Snippets live in `Templates/Snippets.md`, one `##` heading each — add, rename or delete them by editing that file, in the app or anywhere else.
- Help › How it works now lists every template and snippet and what is in them.

## Build 87 · 9 September 2026

- **You can no longer be in Arrange mode without noticing.** A tinted strip runs across the top of the map while it is on, saying what a drag will do and how many boxes are marked, with **Reset all** and **Done** in it. Esc leaves the mode too.
- **The zoom and Arrange buttons moved to the left** of the Map's toolbar, where the eye starts. Export stays on the right.

## Build 86 · 9 September 2026

- **Fix: tapping a box and sweeping a rectangle work again.** In build 85 neither did, and it was my mistake twice over.
  - Every box was placed in a way that made its touch area cover the whole map, so the box drawn last quietly swallowed every click anywhere on the canvas. Boxes now claim only their own space.
  - The tap and the drag were two separate gestures on the same box, and they argued over which one a click belonged to. One gesture now handles both: no movement means a tap, movement means a move.
- The background works the same way — sweep to mark, click to clear — through a single gesture.

## Build 85 · 9 September 2026

- **Mark boxes by sweeping a rectangle.** On the Mac, with **Arrange** on, drag across the empty background and every box the rectangle touches is marked.
- It **adds to** what you already tapped rather than replacing it, so tapping single boxes and sweeping a cluster can be used together.
- On the phone a drag across the background scrolls the map, so there is no rectangle there; tapping boxes works as before.

## Build 84 · 9 September 2026

- **Move several boxes at once on the Map.** With **Arrange** on, tap boxes to mark them — the toolbar counts them — then drag any one of them and the whole set moves together, keeping its shape.
- Tap a marked box again to unmark it, tap the empty background to clear the marks. Turning Arrange off clears them too.
- Dragging a box that is not marked still moves only that box, and leaves your marks alone.
- Right-click a marked box › **Place these N automatically** hands the whole set back to the layout.

## Build 83 · 9 September 2026

- **Park the map's boxes where you want them.** A new **Arrange** button in the Map's toolbar. While it is on, dragging a box moves it and it stays where you let go; while it is off, dragging links things as before. One drag never means two things.
- **The position lives in the note**, as a `map: 320,180` line in its frontmatter — so it travels with the note when you rename or move it, it is the same on the Mac and the iPhone, it is in your backups, and zooming does not disturb it. Delete the line in any editor and the app places the box again.
- Notes you have not placed are still arranged by the app, around the ones you have. A brand new note can therefore land on top of a box you parked; move either one.
- **Right-click a box while arranging › Place this one automatically**, or **Reset all** in the toolbar, hands them back to the layout.
- Only proper notes can be parked; task chips and the dashed group boxes always follow the layout.

## Build 82 · 9 September 2026

- **The Map is now something you work in, not only look at.** Drag a box onto another and the link is written into the notes:
  - a **project onto an area** puts the project in that area;
  - a **project or area onto a goal** makes it serve that goal;
  - an **area onto another area** makes it a sub-area;
  - a **goal onto a goal** makes it a subgoal;
  - a **task chip onto a project or area** moves the task there.
- The box under the pointer is outlined while it would take the drop. A pair that means nothing is refused and the drag springs back.
- The map redraws straight away, so you see the new shape immediately.
- Boxes still can't be dragged to a position of your own choosing: the layout is worked out from your links, so a hand-placed box would be moved again by the next change.

## Build 81 · 9 September 2026

- **Export the Map.** A new **Export** button in the Map's toolbar: **PDF** (vector, so it prints and zooms without going fuzzy), **PNG**, **Copy image**, and **Copy as outline** — the same tree as indented text you can paste anywhere. The Mac asks where to save; the phone opens the share sheet.
- **Help is now something you can navigate.** How it works and Version history are no longer one long scroll: every heading opens and closes, and a search box at the top filters the page down to the parts that mention what you typed, already opened. **Open all** / **Close all** in the same row.
- **The manual has been reorganised** to match: related things sit together (renaming and deleting are under Notes, the sync preview under Reminders sync, Recent and Search under "Finding things again"), the Inbox has a section of its own, and long sections have sub-headings.

## Build 80 · 9 September 2026

- **Deleted.** A new sidebar section holding the notes you have deleted, newest first. Each one has **Put back**, which returns it to the folder it came from, and **Delete for good**; **Empty** in the toolbar clears the lot.
- **This closes a real hole on the iPhone.** Deleting used to put the file in the Mac's Trash, which the phone has no equivalent of — there the note was simply removed, and iCloud then took it off the Mac too. Now both behave the same way.
- Deleted notes are kept for **30 days** and then cleared out on their own. They sit in a hidden folder inside the vault, so they cost you nothing and never sync to Reminders.
- The wording follows: the button is now **Delete**, and it says where the note is going.
- Only whole notes are kept. A task deleted from a list is still gone straight away.

## Build 79 · 9 September 2026

- **The Inbox "File it" column now shows the shape of your vault.** Two headings — **Projects** in green, **Areas** in pink — instead of one long run of cards.
- **Sub-areas sit under their area**, indented, on a faint tint of their own colour and joined to the parent by a thin line, so a family reads as a family. They say "Sub-area" rather than "Area".
- Any area with sub-areas has a small **chevron** to fold its family away when the list gets long.
- Every card is still a click target and a drop target, exactly as before.

## Build 78 · 9 September 2026

- **Recent.** A new sidebar section listing the notes you opened most recently, newest first, of any kind. It survives quitting the app, and **Clear** in the toolbar empties it. On the phone it is under Browse › Plan.
- **Calendar › Notes.** A fourth view next to Day, Week and Month: every daily and weekly note you have written, newest first, with the first line of what you wrote so a day is recognisable. It has its own search field.
- **All actions** is now on the phone too, under Browse › Plan.

## Build 77 · 9 September 2026

- **Rename a note.** Right-click it in the list on the Mac, or long-press it on the phone → **Rename…**. Works for projects, areas, sub-areas, resources, goals and archived notes. The note screen also has a **Rename** button in its toolbar.
- The file on disk is renamed with it, and **every link follows**: `goal:`, `area:`, `parent:`, `related:` and any `[[wikilink]]` in another note is pointed at the new name, so nothing comes loose.
- The note's own `# Heading` is updated too, when it still said the old name. Headings further down are left alone.
- A name already taken by another note is refused rather than overwriting it.
- The list in Apple Reminders follows on the next sync — the tasks keep their reminders.

## Build 76 · 9 September 2026

- **Rename a task anywhere.** Right-click a task on the Mac, or long-press it on the phone, and the menu now has **Rename…**. The line turns into a field; type and press Return. Works in a note's task list, in Today, in All actions, in Done and in the calendar day.
- The date, repeat rule, tags, subtasks and the task's identity in Apple Reminders all stay as they were — only the wording changes.
- Renaming a **next action** no longer loses the marker: the badge is put back after the rename.

## Build 75 · 9 September 2026

- **Fix, properly this time: picking an inbox line works again.** Build 71 made the rows draggable and double-clickable, and on the Mac either of those takes the click the list needs to select a row — so no line could be marked, and nothing could be filed. Both are gone. Click a line, then click where it should go, exactly as before build 71.
- Renaming a line is on its **⋯ menu** (and the right-click menu): **Rename…**. Double-click is not back yet; I would rather leave it out than break selecting again.
- Dragging a line from the Inbox onto a destination is gone with it. Clicking a destination does the same thing in one click.

## Build 74 · 8 September 2026

- **Fix: you can pick an inbox line again.** Build 71's double-click-to-rename was swallowing the click the list needs to select a row, so marking a line and then pressing a destination stopped working. Sorry — selecting, the single keys and "click a destination" all work as before, and double-click still renames.
- **Sub-areas are now where you can find them.** Open an area note and the top row has a **Part of…** button: click it and pick the area it belongs to, or "Not part of another area" to take it back out. The right-click menu on an area in the list has the same choices.
- **New note › Area** now has a **Part of** picker, so a sub-area can be made as one from the start.
- Any area can now be picked as the parent, not only the top-level ones. Choosing one that is itself a sub-area lifts it up first — asking for "Yoga under Mobility" means Mobility is the level above.

## Build 73 · 8 September 2026

- **Sub-areas.** An area can now sit under another area: Mobility under Health, or Yoga, Pliability and Stretching under Mobility. Right-click an area › **Part of** and pick where it belongs, or pick "Nothing" to take it back out.
- The Areas list shows them indented under their area, and the small chevron folds them away.
- A sub-area is a normal note in every other way: its own tasks, its own list in Apple Reminders, its own box on the Map (drawn under its area), and its own destination in the Inbox "File it" column and in a task's **Move to** menu, where it reads "Health › Mobility".
- Arranging by hand still works and stays inside the family: a sub-area moves among its siblings, an area among the other areas.
- The note itself shows **Part of Health** at the top; click it to go there.
- Areas nest one level only. An area that already has sub-areas cannot become one until its children are moved out.

## Build 72 · 8 September 2026

- **Move an action to an area, not just a project.** Right-click any task › **Move to** now lists your active projects *and* your active areas (and the Inbox, if it is not already there). Before this, the menu only offered projects, so a task that had landed in the wrong area could not be moved back from the menu.

## Build 71 · 8 September 2026

- **Edit an inbox line where it sits.** Double-click it, or right-click › Rename. Enter saves. The date, tags and any subtasks stay as they were.
- **Drag an inbox line straight onto a destination** in the right-hand column, as well as clicking one.
- The stray arrow next to the "…" button on each inbox line is gone.
- **New note** now sits above the list it adds to, instead of over on the right by the search field.

## Build 70 · 8 September 2026

- **All actions.** A new sidebar section with every open task in the vault, grouped by the note it belongs to, with a filter for All, With a date, No date and Next actions. Tick tasks off in place, or press Open to go to the note. No more remembering a search.
- **Arrange projects and areas by hand.** Drag a note up or down in the list and it stays there. The position is written into the note itself as `order: 20`, so the Mac and the iPhone agree, and so does the "File it" column in the Inbox. Notes you have never dragged stay in alphabetical order, after the arranged ones.

## Build 69 · 8 September 2026

- **Fix: coming back to the Inbox shows "File it" again.** If you had opened a note elsewhere — including one you had just made from an inbox line — the right-hand column kept showing that note instead of your destinations. The Inbox now always opens on sorting; the raw note appears only when you ask for it with "Open the Inbox note".

## Builds 67 and 68 · 8 September 2026

- **The Inbox's right-hand column is now "File it".** It used to repeat the same list of tasks the middle column already shows. It holds the line you are sorting — with room to read a long one in full — and under it your active projects and areas, each with its open count.
- **Drag a line onto a destination, or select it and click one.** Either way it moves, and the selection steps to the next line so you can keep going.
- **New note from this line…** turns a captured line into a project, area or resource of its own when no destination fits.
- Goals are deliberately not destinations: they are direction, not lists to file work into. The raw Inbox note is still one click away.

## Build 66 · 8 September 2026

- **The Inbox is now a sorting screen.** There is only ever one inbox note, so the middle column used to be a list of one. It now holds everything waiting to be sorted, a line at a time, with a capture box at the top for typing new items straight in.
- Each line has **Today**, **Tomorrow** and **Pick a date** to hand, and a menu for the rest: move it into a project or area, turn it into a project, area, resource or goal of its own, block time for it, or delete it.
- **Keyboard**: ↑ and ↓ to move down the list, **T** for today, **M** for tomorrow, **D** for done, **⌫** to delete. The selection moves on by itself, so a full inbox takes a minute.
- When you reach the end it says **Inbox zero** instead of showing an empty list. The note itself stays readable in the right-hand column.

## Builds 63 to 65 · 7-8 September 2026

- **A gold frame around the app icon.** The four PARA squares now sit inside a gold ring, in the same colour goals have everywhere else in the app: everything you keep serves the goals around it.

## Build 62 · 7 September 2026

- A build server fix: it no longer asks Apple for a new signing certificate on every run, which had filled up the account's allowance. Nothing in the app changed.

## Build 61 · 7 September 2026

- **The Calendar section now uses the whole window.** The right-hand column shows the selected day as a schedule: hours down the side, your Apple Calendar events in place and in their own colours, and your time blocks drawn on top of them. A red line marks now.
- **Time blocks live there.** Press "Block time", or double-click an hour, to reserve one. Click a block to change its title, time, length, calendar or notes, or to delete it. All of it writes to Apple Calendar as before, so it shows on every device.
- **Drag a task onto an hour** and that hour is blocked for it, with a link back to the note it came from.
- All-day events and tasks due today without a time sit in a strip above the clock, so nothing is hidden.
- A **Schedule / Note** switch at the top of the column: the daily note is one click away, and it opens by itself when you pick a note.

## Builds 58 to 60 · 7 September 2026

The Calendar section's day view, rebuilt.

- **A month grid of our own** instead of the small system date picker: it fills the column, the cells are big enough to read and to drop a task onto.
- **Dots under the days** so you can see the shape of a month at a glance: green for tasks due (red if something is overdue), blue for calendar events, grey for a day that already has a note.
- **Week numbers** down the left.
- **The day itself below the grid** — its calendar events, what is due, anything undated in the daily note, what got done, and a button to open or create the note. It used to be a list of every daily note in the vault, newest first.
- **A proper header**: the day written out, its week number, and what it holds.
- **Moving around**: arrows for the previous and next day, a Today button, separate arrows for the month, and the left and right arrow keys once the calendar has focus.

## Build 57 · 7 September 2026

- Notes only. Both apps now come from TestFlight and Xcode is out of the loop; this build records that.

## Build 56 · 7 September 2026

- **The Mac app comes from TestFlight too.** One press of the build button now sends both the iPhone app and the Mac app. The Mac app installs into your Applications folder like any other app, appears in Spotlight and the Dock, and tells you itself when a new version is ready. No more quitting, pulling and pressing play in Xcode.

## Build 55 · 7 September 2026

- **The Xcode project carries your signing team.** Until now Xcode had to be told by hand which Apple account signs the app, which meant the project file was changed on your Mac every time you pressed play, and those changes then got in the way of the next Pull. The team is part of the project now, so pressing play no longer modifies anything.

## Build 54 · 7 September 2026

- **Hide finished tasks.** The task list under a note header can leave out what is done or cancelled. The switch is on the header row of the Tasks box ("Hide finished"), and in Settings › Tasks. A finished task that still has open subtasks is always shown, so nothing open can disappear. The file is untouched: the tasks are still there in the text and in Reminders.

## Build 53 · 7 September 2026

- **The note screen scrolls on the iPhone.** A note with a long task list ran off both ends of the screen at once: the first tasks were hidden behind the title bar, the last behind the tabs at the bottom, and nothing would move. The whole screen is one scrolling page now, so every task is reachable.
- **"Add a task" stays put.** It sits just above the tabs instead of being the last thing on the page, so you no longer have to scroll to the bottom to add something.
- The Mac and iPad keep the layout they had.

## Build 52 · 7 September 2026

- **One build number everywhere.** TestFlight used to count its own uploads, so the phone said "Build 50" while TestFlight said "1.0.5". Now TestFlight uses the app's own number, the one at the bottom of the sidebar and on the Browse tab. Both say the same thing.

## Build 51 · 7 September 2026

- **A sync button on the iPhone.** Today and Inbox have one in the top right corner, and Settings › Reminders sync has "Sync now". Until now the phone could only wait for the automatic sync, which also meant iOS never got round to asking for permission to use Reminders.

## Build 50 · 7 September 2026

- The app now declares which screen rotations it supports, which Apple requires before an upload is accepted. On the iPhone and iPad it can be used in any orientation.
- The TestFlight build job uses the newest build machine and the newest Xcode, because Apple only accepts builds made with the current system.

## Build 49 · 7 September 2026

- Fixes in the TestFlight build job: it now signs with the Apple team from the new `ASC_TEAM_ID` setting, and makes its log folder before writing to it. Nothing in the app itself changed.

## Build 48 · 7 September 2026

- **The iPhone app can now come from TestFlight.** A new build server job builds the phone app and sends it to Apple, so new versions reach the phone by themselves: no cable, no Xcode, no seven-day expiry. The one-time setup is in TESTFLIGHT.md and happens entirely in a browser.

## Build 47 · 7 September 2026

- **The editor draws markdown while you type.** Headings grow and turn bold, task boxes are coloured, a finished task is struck through, dates and priorities and tags stand out, and the syntax characters fade into the background. The text in the file does not change at all: it is still the same markdown, only easier to read.
- Bold, italics, `code`, quotes, `[[links]]` and the settings block at the top of a note are all shown for what they are.

## Build 46 · 7 September 2026

A pass over how the app looks.

- **The editor reads like a document,** not like code: proportional type, more line spacing, wider margins.
- **Empty sections say what belongs there** and offer the button that fills them, instead of a bare line of text. Projects, Areas, Resources, Goals, Archive, Done and the note pane each have their own.
- **Today starts with the date** and how much is due, and the sections read more calmly.
- Headings above the task list and the linked notes are quieter and carry their count.

## Build 44 · 7 September 2026

- **Backups.** The app saves a copy of the whole vault before every sync and once a day, keeping the last ten. They are plain folders in the vault under `.ams-para/Backups`, so you can also open one in Finder and drag a single note back. Settings › Backups has "Back up now", "Show in Finder" and "Restore a copy", and a switch for the backup before each sync. Restoring saves what you have now as a backup first, and leaves notes made since then alone.
- **See what a sync would do.** The sync button is now a menu: "Sync now", "Show me what would change…" and "Last sync report…". The preview rehearses the whole sync on a copy of your vault and a copy of your reminders, so the numbers are exactly what a real sync would do, and nothing is changed. From the preview you can go straight to "Sync now".
- **A readable sync report** instead of one line: what was created, updated, deleted, anything that changed in both places, and anything worth knowing.

## Build 43 · 7 September 2026

- **The `^t` markers are hidden in the editor.** Every synced task carries a marker like `^t3cd432` that links it to its reminder. It is still in the file, so NotePlan and the sync keep working, but the editor no longer shows it, so you cannot delete it by accident while editing.
- **A lost marker repairs itself.** If a task did lose its marker, the next sync recognises the task by its note and title and gives the same marker back, instead of deleting the reminder and making a new one. Anything you had added to that reminder stays.

## Build 42 · 7 September 2026

- **iPhone layout.** On a phone the app shows tabs: Today, Inbox, Browse and Capture. Browse holds Goals, Projects, Areas, Resources, Archive, Calendar, Time Blocks, Done, Review, Map, Search and Settings. Tap a note to open it, swipe back to return. iPad and Mac keep the three columns.

## Build 41 · 7 September 2026

- **Next action per project.** Right-click a task in a project: "Make this the next action". It gets a "next" badge, shows on the project row, and Today lists one next action per active project.
- **Drag tasks between notes.** Drag a task from any list onto a note in the middle column, or onto Inbox in the sidebar. Subtasks travel along, and the reminder follows on the next sync.
- **Reschedule with one click.** Right-click a task: Today, Tomorrow, Next Monday, In a week, Pick a date, Remove date.
- **Repeating tasks.** Right-click › Repeat: every day, week, 2 weeks, month, 3 months, year. When a repeating task is ticked, here or in Reminders, the next one appears below it with the next date. In the file it is `@repeat(weekly)`.
- **Done.** A new sidebar section with everything completed, day by day, for the last 30 days, and a count for this week.
- **Project progress.** Project rows show a small bar with done and total tasks, and "Due in 12 d" or "3 d overdue".
- **Drag tasks onto the calendar.** Drop a task on a day in the month grid or the week list to set its date.
- **Time block from a task.** Right-click a task › "Block time for this…" opens Time Blocks with the title filled in and a link back to the note.
- **Weekly plan.** The weekly note shows all seven days. Drop tasks onto a day to plan it there, tick them off in place.
- Under the hood: new files no longer need the project file rewritten, so pulls stop clashing with your Team setting after this one.

## Builds 39 and 40 · 6 September 2026

Hardening after a code audit. Nothing new to learn; the app is more careful with your files.

- A note changed on the iPhone, in iCloud or in another editor is never overwritten. The app reloads such changes every few seconds and when it comes to the front. If you were typing in that note at the same time, your version is kept as a "(conflict …)" copy next to it.
- Unsaved typing is written before every sync, before ticking a task, and when the app quits or goes to the background.
- Frontmatter lines the app does not understand (comments, nested values, keys with spaces) are kept exactly as written. Windows line endings are read correctly. Quoted values no longer gain backslashes.
- Reminders sync: renaming a project moves its reminders instead of cancelling its tasks; a second device never deletes reminders for notes it has not received yet; a task line copied into another note gets its own id; ids typed into a reminder title cannot hijack a task; a failure while talking to Reminders no longer leaves half-done work.
- A note the app cannot read is skipped and logged instead of hiding the whole vault. Files in Windows text encoding are read.
- Archiving a second note with the same name keeps both. Cancelled tasks keep their done stamp.
- Capture links can no longer point at files outside the vault or at the app's own settings; only web and mail links are kept. Captures that cannot be filed yet wait in the outbox instead of being dropped.
- Choosing a folder that cannot be opened leaves the current vault working.

## Build 38 · 6 September 2026

- Help window with "How it works" and this version history (Help menu on the Mac, Settings on the iPhone).

## Build 35 · 6 September 2026

- Settings › Apple Calendar lists every calendar with a switch, and a picker for the calendar new time blocks go to.
- New Time Blocks section: reserve blocks of time as events in Apple Calendar, separate from tasks. Click to edit, right-click to open in Calendar or delete.
- Every event in Today and daily notes can be opened in the Calendar app.

## Build 34 · 6 September 2026

- Root cause of the "columns hidden under the toolbar" problem fixed: the window no longer grows when a task is added, a section is opened or the list changes.

## Build 33 · 6 September 2026

- Today and daily notes show the day's Apple Calendar events above the tasks. Read only. Can be turned off in Settings.

## Build 32 · 6 September 2026

- Map: a top-down diagram of goals, areas, projects, tasks, resources and archive. Click a box to see its connections and open the note.

## Build 31 · 6 September 2026

- Move any note except the Inbox to the Trash: toolbar button, ⌘⌫, or right-click in the list. Goals can be archived.

## Build 30 · 6 September 2026

- Opening "Linked notes" no longer pushes the editor out of the window.

## Builds 28 and 29 · 6 September 2026

- Build number at the bottom of the sidebar.
- Help › Copy Diagnostics (⌥⌘D) copies a log for reporting problems.
- Following a goal link or a linked note navigates in two steps, the way two clicks would.
- Goal references match their goal even when case, punctuation or length differ. A missing goal shows a message in the bottom banner instead of a pop-up.

## Builds 22 to 27 · 6 September 2026

- The goal link in a project no longer creates a stray resource note.
- Several fixes for state changes during redraws: list selection, sheet and alert dismissal, search field text, saving when a note is swapped out.

## Build 21 · 6 September 2026

- Goals above PARA: life goals and dated goals, `goal:` links from projects and areas, the goal dashboard and goal flags in the weekly review. Goals never sync to Reminders.

## Build 20 · 5 September 2026

- Colour throughout the app: Projects green, Areas pink, Resources blue, Archive grey, Goals gold.

## Builds 16 to 19 · 5 September 2026

- App icon.
- Fix for the frozen window when opening a sheet.
- Fix for state changes published during view updates.

## Builds 10 to 15 · 5 September 2026

- The Xcode project, Info.plist, entitlements and shared scheme are committed, so the repository opens directly in Xcode. The project is regenerated only when its spec changes, keeping your signing Team.
- The Swift package moved into `Core/` so Xcode can open the project.

## Builds 7 to 9 · 5 September 2026

- Quick capture: menu bar panel, iOS share extension, `amspara://capture` link.
- Full-text search with filters for type, status, tag, area, folder, due date and open or done.

## Builds 4 to 6 · 5 September 2026

- Due times on tasks, subtasks, alarms in Reminders.
- Weekly notes, and week and month overviews in the Calendar section.

## Builds 1 to 3 · 5 September 2026

- Continuous integration on a Mac runner: core tests, macOS and iOS builds on every push.
- Daily notes with a calendar, markdown preview with clickable wikilinks, weekly review.

## Foundation · 5 September 2026

- The core: markdown notes with frontmatter, NotePlan style tasks, the PARA vault, the note index, and the two-way Reminders sync engine with tests.
- The app: sidebar, note list, editor with preview, task checklist, settings, example vault.
