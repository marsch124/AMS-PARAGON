# The look of PARAGON

Decided on 6 November 2026 with look B, "coloured panels with meaning". Built in build 280 (version 1.0 (280)). Every function stays as it is; this document is only about how PARAGON looks and feels. Read it before you change any screen.

The look follows the one in the Subscriptions app (version 1.0): one place for text sizes, one place for part colours, one heading, one main button, one panel.

## 1. Text sizes

There is one scale, kept in one place in the code (`Txt` in Theme.swift). No screen picks its own size.

### Mac

| Name | Points | Weight | Colour | Used for |
|------|--------|--------|--------|----------|
| Page title | 26 | bold | black by day, white at night | The open note's title at the top of the note column. The title of a screen that fills a column: Today, Weekly review, Map, Plan the day, and the title row of Settings. |
| Section heading | 17 | semibold | the colour of the part | Every panel or section heading: Tasks, Linked notes, Calendar, Due today, Next actions, the review steps, the blocks of Goal chain, and the titles of edit windows. |
| Value | 15 | regular | black or white | Note text, task titles in a note, facts, fields in windows, dates, and the words in panels. |
| Label | 12 | regular | soft grey | The small word above or beside a value ("Deadline", "Serves", "List"), counts in headings, and footers. |
| List | 13 | regular | black or white | Apple's own size for sidebar rows, the title of a row in the middle column, menus, pop-ups and the toolbar. |
| List second line | 11 | regular | grey | The one second line of a row, and the numbers in the sidebar. |
| Button | 13 | semibold | white on the part's colour | The main button. In windows, the large control size is used (15 points). |
| Code | 14 | regular, monospaced | grey | Code, and the settings block in the note editor. |

The rule: never a 12-point label beside a 22-point value. The biggest step inside one panel is label 12, value 15, heading 17. The 26-point page title stands alone at the top of a column. Nothing in the app is smaller than 11 points. The planner's hour ruler, the Map's boxes and the Done squares use 12 or 11 points (before: 10).

### The note editor on the Mac

The note should read like a good book. Edit and Read use the same numbers, so the note does not move when you switch.

| Element | Points | Style |
|---------|--------|-------|
| Text | 15 | regular; 6 points between lines (a line is about 1.45 times the text size); 8 points between paragraphs |
| Heading with # | 22 | semibold, black or white; 18 points above, 6 below |
| Heading with ## | 18 | semibold; 14 above, 4 below |
| Heading with ### | 15 | semibold; 10 above, 2 below |
| Checkbox | 15 | a circle, line 1.5 points, lined up with the top of the capital letters of the text. Ticked: filled in the colour of the part, with a white tick. |
| Code and settings block | 14 | Apple's monospaced font, grey, on a block that is 4 % grey |
| Link, [[link]] and #tag | 15 | regular, in the colour of the part (not blue) |
| Due date such as >2026-11-20 | 14 | digits of equal width, in the colour of the part |
| Priority !! | 15 | bold, orange |
| Finished task | 15 | grey, with a line through it |
| Quote | 15 | italic, grey, with a 2-point bar at the left in the colour of the part |
| Line --- | 1 | a thin line, 8 % grey |
| Marks (#, -, [ ]) | the size of their line | 30 % grey. Never a smaller size. |

Before build 280, Edit used 14, 23, 20 and 17 points and Read used 17, 28, 22 and 20 points. Switching between them moved the whole note.

### iPhone

The iPhone uses only Apple's own text styles, so the text grows and shrinks with the text size set on the iPhone.

| Mac name | iPhone style | Normal size in points |
|----------|--------------|-----------------------|
| Page title | Large title, bold, set with the navigation title. It shrinks to a small title when you scroll. | 34, then 17 |
| Section heading | Headline, in the colour of the part | 17, semibold |
| Value | Body | 17 |
| Label | Footnote, grey | 13 |
| Title of a list row | Body | 17 |
| Second line of a row | Footnote, grey | 13 |
| Note text | Body, with 5 points between lines | 17 |
| Headings with #, ## and ### | Title 2, Title 3, Headline; all semibold | 22, 20, 17 |
| Code | Body, monospaced | 16 |
| Tiny marks (counts on badges only) | Caption 2 | 11 |

On the iPad the three columns and the Mac scale are used, drawn with Apple's styles. The page title may be Title (28 points) there.

## 2. Colour

Every part has one colour. It is the same everywhere the part shows: the icon in the sidebar, the section heading, the main button, the mark in a list, the tint of a panel, and the links in a note of that part. Colours are defined once, each with a day shade and a night shade. Day shades are dark enough to read at 17 points on white (a contrast of at least 4.5 to 1 where possible). Night shades are light enough to read on the dark panel.

| Part | Colour | Day | Night | Where it shows |
|------|--------|-----|-------|----------------|
| Projects | green | #2A7A57 | #6CCB9B | Projects, All actions |
| Areas | pink | #BC3C78 | #F285B6 | Areas, Tags |
| Resources | blue | #2A6DB3 | #74B2EA | Resources, Recent, Templates, Search |
| Archive | grey | #6E6E73 | #9A9AA2 | Archive, Deleted, Work |
| Goals with a date | gold | #8F6E10 (before: #A7811A, too light) | #E5BE55 | Goals, Map |
| Aspirations | deeper gold | #7E5210 | #E0A83E | Aspirations |
| Inbox | amber | #B0631A (before: #C2701B) | #EBA45A | Inbox, Snippets, Quick capture |
| Calendar | purple | #6B4EA8 | #AC93E2 | Calendar, Today, Time Blocks, daily and weekly notes |
| Weekly review | teal | #1E7F84 | #62C5CA | Weekly review, Done |
| Blocks in Plan the day | orange | #B5580B | #F2A45C | Blocks in the planner, the block window, the focus bar |
| Start the day | clear orange | #D4640A | #FFA23A | The morning button and screen |
| Close the day | dark lilac | #6E3A86 | #C79AE0 | The evening button and screen |
| The now-line | slate blue | #477C9C | #92C3DE | The now-line in the planner and the day. Never red. |
| Look at this | orange | #D4640A | #FFA23A | Warnings, old flags, priority |
| Overdue and danger | red | Apple's red | Apple's red | Overdue dates, Delete, Delete for good |

Neutral colours:

| Name | Day | Night | Used for |
|------|-----|-------|----------|
| Surface | #FFFFFF | #1E2228 | Panels |
| Canvas | #F3F5F8 | #15181C | The page behind the panels |
| Soft text | #5C6470 | #A9B1BC | Labels and quiet text |
| Line | #E2E6EB | #2E333A | Thin lines and night borders |

The sidebar has no colour of its own. It is the system's see-through sidebar.

How a colour is worn, the same for every part:

- Sidebar icon: the part's hand-drawn icon, 16 points, drawn in the part's colour. The word stays black or white.
- Section heading: 17 points, semibold, in the part's colour.
- Main button: filled in the part's colour with white words. On the night golds and oranges the words are dark (#2B2200). When it cannot be used yet it is the same colour at 40 %. Never grey.
- Mark in a list: a filled dot, 8 points, at the left of the row. When the note has its own icon, that icon (18 points, in the part's colour) is shown instead. There is no 3-point stripe.
- Panel tint: the panel is the surface colour with the part's colour laid over it, 7 % by day and 13 % at night. Corners 10 points round. No border by day. A 1-point line at night.
- Links and tags in a note: the colour of the part the note is in.
- Selection in a list: Apple's own. The system colour fills the row and the words turn white. Dots and icons keep their colour. There is no selection colour of our own.
- The old colour wash over the whole note column (8.5 %) is gone.
- Widgets use the same part colours. They do not keep a table of their own.

## 3. Spacing

| Name | Points | Used for |
|------|--------|----------|
| Gutter | 16 | The room at the left and right of a column's content. Windows have 20. |
| Panel padding | 12 | Inside a tinted panel (10 at night, because of the line) |
| Panel gap | 12 | Between panels |
| Heading gap | 6 | From a heading to its first line |
| Section gap | 20 | Between the sections of a page |
| Row padding | 5 | Above and below a list row on the Mac. The iPhone uses Apple's own list. |
| Row spacing | 10 | Between the mark, the title and the text at the right of a row |
| Radius | 10 | Panels. Buttons 8. Small labels 6. |
| Reading width | 680 | The note text column, in the middle, with at least 24 points at each side |
| Sidebar | 180 to 210 | At least 180, normally 210. It hides with the standard sidebar button. |
| List column | 240 to 300 | The Map list is 480 to 760. |
| Gap between fields in a window | 10 | |

A section with nothing in it draws nothing, not even its heading. Only a whole empty screen shows an empty message.

## 4. A row in a list

```
[dot, 8 pt, part colour]  Title, 13 pt (Mac) or Body (iPhone), black or white, one line     [count or date, 11 pt, grey]
                          One quiet second line, 11 pt (Mac) or Footnote (iPhone), grey
```

- The height is the height of its words. A one-line row on the Mac is about 24 points. A two-line row is about 40. Nothing has a fixed height.
- There is at most one second line, and it holds at most one pair of facts, for example "3 of 7 · due 20 Nov". Before, Today's row could hold up to six facts.
- The second line keeps the two facts that matter for the kind of note: a project shows progress and the date due; a goal shows progress and the target; an area shows its open projects; a resource shows its number of links; a daily note shows its date; an Inbox line shows where it came from. Everything else is in the facts panel at the top of the note.
- An overdue date is red. "Look at this" is orange. All else is grey.
- Paused, Someday and Ended show as a small capsule at the right edge: 6-point corners, 11 points, the part's colour on a 14 % tint.
- Grouped lists (Projects by aspiration, the groups in Browse, Today's sections) use the part's 17-point heading as the group header on the Mac. On the iPhone they use Apple's section header, in the part's colour. The fold arrow stays, 13 points, in the part's colour.
- Swipe actions on the iPhone stay as they were.

## 5. The facts at the top of a note

The icon of the note stands beside the title (26 points, bold). Under the title is a table with two columns. The left column is the label (12 points, soft grey). The right column is the value (15 points). A value you can change is a pop-up menu with a border. A value you cannot change is plain words. Before build 280 this was a row of up to twelve chips at 12 points.

A small label for a fact (for example a count or a status) is one shape only: 12 points, medium weight, the part's colour on a 14 % tint. A choice is one shape only: a bordered pop-up. The old five kinds of chip are gone.

## 6. Edit windows

This is for New Note, Quick capture, the block window, Start the day, Close the day, Snippet and New template.

Mac:

```
Title, 17 pt, semibold, part colour               [ Cancel ] [ Save ]
----------------------------------------------------------------- one thin grey line
 Label (12 pt, grey)     [ field or pop-up menu ]
 Label                   [ white pop-up with a border and a grey arrow ]
 Label                   [ 2026-12-01 ] [calendar]
```

- Width: 520 points. Quick capture 480. Start the day and Close the day 640. The height comes from the content. There is never a scroll inside a scroll.
- **Cancel** and **Save** (or **Create**, or **Done**) are side by side at the top right. Before, they were at the bottom right. **Save** is filled in the part's colour and has the large control size. **Cancel** has a border.
- The fields are a grouped form: labels at the left, controls at the right.
- Keys: **Escape** is Cancel. **⌘S** is Save, and Return does the same in a one-line field. **Tab** moves from field to field in order. The first field is ready when the window opens. The focus ring is visible.
- The Date window keeps its field and calendar. **Set** is the filled main button. The calendar is Apple's own.

iPhone:

- The window slides up (full height; Quick capture half height). The title is small, in the middle.
- **Cancel** is at the left of the bar and **Save** at the right, in the part's colour and bold.
- A full-width main button at the foot is used only where there is one action and no bar: Start the day and Close the day keep theirs, in colour.

## 7. Controls

| Control | Mac | iPhone |
|---------|-----|--------|
| Choose one from a list | A pop-up menu: white, a 1-point border, a grey arrow, 13 points. In a note's header and on small chips it is a menu button with a border and an arrow, so it is never coloured words on nothing. | Apple's own list row or menu |
| On or off | A switch in windows and in Settings. A tick box only in lists of options. | A switch |
| Date | The field and the calendar window. A compact picker for times (the At line). | Apple's own |
| Task circle | 15 points, lined up with the text | 20 points |
| Text field | A rounded border; large in windows | A row in a form |
| Buttons | A border for a second choice. The main one is filled in the part's colour. A plain button only for arrows and marks inside a row. | The same |
| Segmented choice | In the toolbar (Day, Week, Month and Notes in Calendar; the Help pages). Apple's own. | Apple's own |
| Toolbar | Search, New Note (the +, in the colour of the section), Quick capture, Sync, the Edit switch, Back and Forward. All have a hand-drawn icon. No button floats inside a page, and the list column has no bar of its own. | Items in the navigation bar |
| Keyboard focus | The standard focus ring on every control. Switched off only on the calendar and the Done squares, as before. | None |
| Menus | Apple's own menus and right-click menus, 13 points. Hand-drawn icons of 13 points where an item has one. | None |

Not moved on purpose: **Start the day** and **Close the day** stay in Today's date row, and **Show all** stays in the Goals header. They are placed where the owner put them.

## 8. Empty screens

One calm line, 15 points, grey, in the middle. Above it, the part's hand-drawn icon, 28 points, in the part's colour at 60 %. For example: "Nothing in the Inbox." or "No note open — choose one on the left." There is no headline, no long paragraph and no big button. The New Note button is in the toolbar already. Before, an empty screen had a 38-point symbol, a headline, a paragraph 380 points wide and a big button.

## 9. Icons

- Every icon is hand-drawn on a grid of 24 points, with one line of 1.9 points, round ends and no fill. It is drawn in the part's colour.
- The icons come from the AMS Icon Library. Its source is `TemplateIcons.swift`. A new icon is drawn in the same style, added there, and the library built again.
- Sizes: sidebar 16, toolbar 17, section heading 17 (optional, before the words), row mark 8 (dot) or 18 (the note's own icon), empty screen 28, widget 14.
- Drawn for build 280, one each: Inbox tray, sun (Today), calendar, clock with blocks (Time Blocks), tick list (Weekly review), map with nodes, ring (All actions), clock going back (Recent), ring with a tick (Done), bin (Deleted), page with a gear (Templates), added text (Snippets), hash (Tags), magnifying glass (Search), star (Aspiration), target (Goal), flag (Project), four squares (Area), books (Resource), box (Archive), briefcase (Work), plus, capture tray, sync arrows, pencil, back and forward arrows, archive arrow, gear (Settings), moon (Close the day) and sunrise (Start the day).
- No stock icons and no emoji. Before, the sidebar and toolbar used 88 stock symbols of uneven weight.

## 10. Reading width and the window

- The note's text stops at 680 points and sits in the middle of the column. The facts panel and the panels under it (Tasks, Linked notes, Goal chain) are also 680 points wide.
- On a 13-inch laptop the window is 1180 points wide: sidebar 210, list 300, note 670. The text fills the column with 24 points at each side. On a big screen the text stays 680 wide, with calm margin at the sides.
- The sidebar is the system's see-through sidebar. It hides with the standard toolbar button or ⌃⌘S. Nothing about it is custom.
- The window remembers the width of the columns.

## 11. Day and night

Each colour in section 2 has a day shade and a night shade. By day a panel is white with a light tint and no border. At night a panel is #1E2228 on a page of #15181C, with a stronger tint (13 %) and a 1-point line. Night mode is never a tint laid on a tint.

## 12. The version

The version shows as 1.0 (280) at the foot of the sidebar and in Settings › About. Before build 280 only "Build 279" showed, at the foot of the sidebar and under Browse.

## 13. Checks for every new screen

- The text sizes come from the scale in section 1. No new size.
- The part's colour comes from section 2. No new colour.
- A panel, a row, a window and an empty screen follow sections 4 to 8.
- The main button is in colour.
- The screen looks right on the iPhone and the Mac, by day and by night, at a normal iPhone size.
