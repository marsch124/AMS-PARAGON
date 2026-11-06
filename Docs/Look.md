# The look of PARAGON

Decided on 6 November 2026 with look B, "coloured panels with meaning". Built in build 280 (version 1.0 (280)). Every function stays as it is; this document is only about how PARAGON looks and feels. Read it before you change any screen.

The look follows the one in the Subscriptions app (version 1.0): one place for text sizes, one place for part colours, one heading, one main button, one panel. The code is in `App/Paragon/Views/Look.swift` (the scale `Txt`, `Heading`, `Pill`, `PanelStyle`, `SheetChrome`, `AppVersion`) and `Marks.swift` (the icons).

## 1. Text sizes

There is one scale, kept in one place in the code (`Txt` in Look.swift). No screen picks its own size. A rule test in Core (`LookRulesTests`) reads the sources and fails on any text size named outside the scale.

### Mac

| Name | Points | Weight | Colour | Used for |
|------|--------|--------|--------|----------|
| Page title | 26 | bold | black by day, white at night | The open note's title and the title of a screen that fills a column. |
| Section heading | 17 | semibold | the colour of the part | Every heading (`SectionLabel`, `Heading`) and the title in an edit window's bar. |
| Value | 15 | regular | black or white | Note text, facts, fields, and the words in panels. |
| Label | 12 | regular | soft grey | The small word above a value, counts in headings, footers. |
| List | 13 | regular | black or white | Sidebar rows, menus, pop-ups. |
| List title | 13 | semibold | black or white | The title of a row. |
| List second line | 11 | regular | grey | The one second line of a row, numbers, badges. |
| Button | 13 | semibold | white on the part's colour | The main button. |
| Code | 14 | regular, monospaced | grey | Code, and the settings block. |
| Capsule | 11 | medium | the part's colour on a 14 % tint | A status or a count that cannot be changed. |

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
- There is at most one second line, for example "0 of 2 · Due in 12 d". It depends on the kind of note: a project shows progress and the due date; a goal shows its progress and its target date or horizon; an area shows its open tasks ("3 open"); a resource shows its links ("4 linked"); a daily note shows its date; any other note shows open tasks and a due date. When there is nothing to show, a project shows its area and another note its goal. Everything else is in the facts panel at the top of the note.
- An overdue date is red. All else is grey.
- A status such as Paused, Someday or Ended is a small capsule at the right edge (11 points, the part's colour on a 14 % tint).
- A group heading in a list is the 17-point heading in the part's colour.

## 4. The top of a note

The title is 26 points, bold; pressing it renames the note where that is allowed. Under it is the facts panel, in the note's colour. Its heading is the kind of note, for example "Project", with the note's icon beside it. Inside, the facts sit in a row that wraps. Each is a small grey label (12 points) with its value (15 points) under it: Status, In area (or Part of), Serves, Horizon, Target, Measure, Looked at, Deadline, Tags, List and Icon. Only the ones that fit the kind of note are shown. A fact you can change is a bordered pop-up or button, not coloured words. A fact you cannot change is plain words. Tasks and Linked notes are tinted panels too.

## 5. Edit windows

This is for New note, Make this note (from a link), Close the day, Start the day, and Quick capture on the Mac. All use one shape, `SheetChrome` in Look.swift.

Mac: a bar at the top with the title (17 points, semibold, in the part's colour) at the left, and **Cancel** and the doing button (**Create**, **Done** or **Save**) side by side at the right, then one thin line, then the form.

- The doing button is filled in the part's colour and has the large control size.
- **Escape** is Cancel. **Return** and **⌘S** do the doing button (the second shortcut sits on a hidden button, because one button carries one shortcut).
- **Tab** moves between text fields as macOS does. The choice chips are buttons, not fields; do not promise that Tab reaches every chip.
- Quick capture inside the New note sheet has no bar of its own; it keeps its one **Save**.

iPhone: a navigation bar with the title small in the middle, **Cancel** on the left and the doing button on the right, in the part's colour and bold. The iPhone's own Quick capture screen keeps its full-width **Save** button; that button is the part's colour, paler when it cannot act.

The Date window keeps its field and calendar. **Set** is a filled button.

## 6. Empty screens

The part's icon, in the part's colour at 60 %, one calm line (15 points, grey), the explanation in small grey (12 points), and, where there was a button, a quiet bordered one in the part's colour. Some empty screens show only the icon and the line (`CalmEmptyView`).

## 7. Icons

- Every icon in the app, the widgets and the share sheet is a hand-drawn mark from the AMS-Icons package, drawn on a grid of 24 points with one line of 1.9 points, round ends and no fill. `Marks.swift` turns a name into a mark (the app); `WidgetMarks.swift` does it for the widgets.
- A new icon is drawn in the same style in the AMS Icon Library (source `TemplateIcons.swift`), and the library is built again.
- No stock icons and no emoji. `LookRulesTests` fails on `systemImage:`, `Image(systemName:)` or an emoji in the source.
- The one exception is a user's own note icon chosen from Apple's symbols in the icon picker. That is his choice, not the app's icon.

## 8. Reading width and the window

- On the Mac the note's header, the panels and the text stop at 680 points (`Theme.readingWidth`) and sit centred in the column. On a wide window the rest is calm margin.
- The sidebar column is at least 180 points wide, normally 200. The list column is 220 to 280 points; the Map list is 420 to 720.
- Window toolbar: Search, Quick capture and Sync. The **+** New note button stays over the list column. **Start the day** and **Close the day** stay in Today's date row, and **Show all** stays in the Goals header. They are placed where the owner put them.

## 9. iPhone

Browse has a large title that shrinks when you scroll. The long press that reveals Work is on the version line at the foot of Browse (on the Mac it is on the PARA heading in the sidebar). The tab bar icons are the hand-drawn marks. Swipe actions on rows are as before. On the iPad the three columns are used.

## 10. The version

The version shows as "PARAGON 1.0 (280)" at the foot of the Mac sidebar and at the foot of Browse on the iPhone. It is not in Settings. `AppVersion.text` builds it.

## 11. Day and night

Each colour in section 2 has a day shade and a night shade. By day a panel is white with a light tint and no border. At night a panel is #1E2228 with a stronger tint (13 %) and a 1-point line. Both were drawn and checked.

## 12. Checks for every new screen

- The text sizes come from the scale in section 1. No new size.
- The part's colour comes from section 2. No new colour.
- A panel, a row, an edit window and an empty screen follow sections 3 to 6.
- The main button is in colour.
- Icons are marks, never stock symbols or emoji.
- The screen looks right on the iPhone and the Mac, by day and by night, at a normal iPhone size.
