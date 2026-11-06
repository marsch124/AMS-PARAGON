# PARAGON look — the design system

One place for every number. Every function stays exactly as it is; this is only how it looks and feels.
The standard copied: Subscriptions 1.0 (`Txt`, part colours day/night, `Heading`, `MainButtonStyle`, `CardStyle`).

---

## 1. Type — one scale, one place (`Txt` in Theme.swift)

### Mac
| Name | Points | Weight | Colour | Used for |
|------|--------|--------|--------|----------|
| `pageTitle` | 26 | bold | primary (black / white) | the open note's title at the top of the detail column; the title of a full-column screen (Today, Weekly review, Map, Plan the day, Settings window title row) |
| `sectionTitle` | 17 | semibold | **the part's colour** | every panel / section heading: Tasks, Linked notes, Calendar, Due today, Next actions, review steps, Goal chain blocks, sheet titles |
| `value` | 15 | regular | primary | note text, task titles in the note, facts, sheet fields, dates, the words in panels |
| `label` | 12 | regular | soft grey (`Theme.soft`) | the small word above or beside a value ("Deadline", "Serves", "List"), counts in headings, footers |
| `list` | 13 | regular | primary | Apple's own: sidebar rows, middle-column row titles, menus, pop-ups, toolbar |
| `listSecond` | 11 | regular | secondary | Apple's own: the row's one second line, sidebar badges |
| `button` | 13 | semibold | white on the part colour | the main button; the native `.large` control size in sheets (15 pt) |
| `mono` | 14 | regular, monospaced | secondary | code and the settings block in the editor |

Rule: **never a 12 pt label beside a 22 pt value.** The biggest step allowed inside one panel is label 12 → value 15 → heading 17. The 26 pt title stands alone at the top of a column.

### Note editor (Mac) — "reads like a good book"
| Element | Points | Weight / style |
|---------|--------|----------------|
| text | 15 | regular, line spacing 6 pt (≈ 1.45 line height), paragraph spacing 8 |
| `#` heading | 22 | semibold, primary, 18 pt space above / 6 below |
| `##` heading | 18 | semibold, primary, 14 above / 4 below |
| `###` heading | 15 | semibold, primary, 10 above / 2 below |
| checkbox | 15 pt circle, 1.5 pt stroke, top-aligned to the text's cap height; ticked = filled in the part's colour with a white tick | |
| code / front matter | 14 | SF Mono (`.monospacedSystemFont`), secondary, on a 4 % grey block |
| link / `[[link]]` / #tag | 15 | regular, **the part's colour** (not blue) |
| due date `>2026-11-20` | 14 | monospaced digits, part colour |
| priority `!!` | 15 | bold, orange ("look at this") |
| finished task | 15 | secondary, strikethrough |
| quote | 15 | italic, secondary, 2 pt bar in part colour at left |
| rule `---` | 1 pt line, 8 % grey | |
| markers (`#`, `-`, `[ ]`) | same size as their line, 30 % grey; never a smaller size | |

Edit and Read modes use **the same numbers** (today Edit is 14/23/20/17 and Read is 17/28/22/20 — switching reflows the whole note).

### iPhone — Apple's text styles only, growing with Dynamic Type
| Mac name | iPhone style | Default points |
|----------|--------------|----------------|
| `pageTitle` | `.largeTitle` bold via `navigationTitle` (large, shrinks to inline on scroll) | 34 → 17 |
| `sectionTitle` | `.headline` in the part's colour | 17 semibold |
| `value` | `.body` | 17 |
| `label` | `.footnote` secondary | 13 |
| `list` row title | `.body` | 17 |
| `listSecond` | `.footnote` secondary | 13 |
| editor text | `.body` 17, line spacing 5 | |
| editor `#` / `##` / `###` | `.title2` 22 / `.title3` 20 / `.headline` 17, semibold | |
| code | `.body` monospaced design | 16 |
| tiny marks only (badge counts) | `.caption2` | 11 |

iPad: the Mac's three columns and the Mac's scale through Apple's styles (`.title` 28 for the page title is acceptable there).

---

## 2. Colour with meaning

One colour per part, **his meanings kept**, used the same way everywhere: sidebar icon · section heading · main button · list mark · panel tint · links in a note of that part. Defined once as `Color(day:night:)` (the Subscriptions way), so day and night are both decided. Day shades are dark enough for 17 pt semibold text on white (≥ 4.5 : 1 where possible); night shades are light enough on the night panel `#1E2228`.

| Part | Meaning he set | Day | Night | Nearest Apple colour | Where |
|------|----------------|-----|-------|----------------------|-------|
| Projects | green | `#2A7A57` | `#6CCB9B` | systemGreen (darkened for text) | Projects, All actions |
| Areas | pink | `#BC3C78` | `#F285B6` | systemPink | Areas, Tags |
| Resources | blue | `#2A6DB3` | `#74B2EA` | systemBlue | Resources, Recent, Templates, Search |
| Archive | grey | `#6E6E73` | `#9A9AA2` | systemGray | Archive, Deleted, Work |
| Goals (dated) | gold | `#8F6E10` (was `#A7811A`, 3.6 : 1 — too light) | `#E5BE55` | systemYellow (darkened) | Goals, Map |
| Aspirations | deeper gold | `#7E5210` | `#E0A83E` | systemBrown | Aspirations |
| Inbox | amber | `#B0631A` (was `#C2701B`) | `#EBA45A` | systemOrange (darkened) | Inbox, Snippets, Quick capture |
| Calendar / daily notes / Today | purple | `#6B4EA8` | `#AC93E2` | systemPurple | Calendar, Today, Time Blocks, daily & weekly notes |
| Weekly review / Done | teal | `#1E7F84` | `#62C5CA` | systemTeal | Weekly review, Done |
| Plan blocks | orange | `#B5580B` | `#F2A45C` | systemOrange | planner blocks, block sheet, focus bar |
| Start the day | clear orange | `#D4640A` | `#FFA23A` | systemOrange | the morning button and screen |
| Close the day | dark lilac | `#6E3A86` | `#C79AE0` | systemIndigo | the evening button and screen |
| Now-line | slate blue | `#477C9C` | `#92C3DE` | — (his: "not red") | now-line on planner and day |
| "Look at this" | orange | `#D4640A` | `#FFA23A` | systemOrange | warnings, stale flags, priority |
| Overdue / danger | red | systemRed | systemRed | systemRed | overdue dates, Delete, Delete for good |

Neutral set (from Subscriptions, proven): `surface` `#FFFFFF` / `#1E2228` (panels) · `canvas` `#F3F5F8` / `#15181C` (the page behind panels) · `soft` text `#5C6470` / `#A9B1BC` · `line` `#E2E6EB` / `#2E333A` · sidebar: the system's translucent sidebar material, nothing of our own.

How a colour is worn (every part the same):
- **Sidebar icon** — the part's hand-drawn icon, 16 pt, stroked in the part colour; the word stays primary.
- **Section heading** — 17 semibold in the part colour.
- **Main button** — filled in the part colour, white words (dark words `#2B2200` on the night golds and oranges, as Subscriptions' `onYellow`). Disabled = the same colour at 40 %, never grey.
- **List mark** — an 8 pt filled dot in the part colour at the row's left (or the note's own icon at 18 pt in that colour when it has one). No 3 pt stripes.
- **Panel tint** — the panel is `surface` with the part colour laid over at **7 % by day, 13 % by night** (`CardStyle.tinted`), 10 pt radius, no border by day, a 1 pt `line` border by night.
- **Links and tags** in a note — the note's part colour.
- **Selection** — Apple's own: the accent fill in a `List(selection:)`, white words; marks keep their colour (`rowTint` already does this). Never a custom selection.
- **The mode wash** (`ModeAccent`, 8.5 % over the whole detail column) **goes**: colour sits on the panels that mean something, not over the whole column.

---

## 3. Spacing (`Theme` numbers)
| Name | Points | Used for |
|------|--------|----------|
| `gutter` | 16 | left/right inset of a column's content; sheet padding 20 |
| `panelPad` | 12 | inside a tinted panel (10 at night with the border) |
| `panelGap` | 12 | between panels |
| `headGap` | 6 | heading → its first line |
| `sectionGap` | 20 | between sections of a page |
| `rowV` | 5 | vertical padding of a list row (Mac); iPhone uses Apple's inset list |
| `rowH` | 10 | between mark, title and trailing text in a row |
| `radius` | 10 | panels, buttons 8, chips 6 |
| `readingWidth` | 680 | the note text column, centred, min 24 pt side gutters |
| `sidebar` | min 180 / ideal 210 | collapsible with the standard sidebar button |
| `list` | min 240 / ideal 300 (Map 480 / 760) | |
| `controlGap` | 10 | between fields in a sheet |

No empty bands: a section with nothing in it draws nothing (its heading too), except the empty state of a whole screen.

---

## 4. Row anatomy (middle column and every list)
```
[mark 8 pt dot · part colour]  Title · 13 (Mac) / body (iPhone), primary, one line       [trailing: count or date · 11 / footnote · secondary]
                               One quiet second line · 11 / footnote · secondary · at most one fact pair, e.g. "3 of 7 · due 20 Nov"
```
- Height = its words: a one-line row is ~24 pt on the Mac, a two-line row ~40 pt. Nothing fixed.
- At most one second line; today's row packs up to six facts (progress bar, count, due, horizon, target, goal, area, links). The second line keeps **the two that matter for that kind**: project → progress + due; goal → progress + target; area → open projects; resource → link count; daily note → the date; inbox line → source. Everything else lives in the note header's facts panel.
- Overdue date in red; "look at this" in orange; everything else secondary.
- Status (Paused, Someday, Ended) as a 6 pt-radius capsule, 11 pt, part colour on 14 % tint, at the trailing edge.
- Mac selection: Apple's accent fill. Marks keep colour; words go white (already handled by `rowTint`).
- Grouped lists (Projects by aspiration, Browse groups, Today's sections) use the part's **17 pt heading** as the group header on the Mac and Apple's section header on the iPhone, in the part colour.
- Swipe actions on the iPhone stay as they are.

---

## 5. Sheet anatomy (New note, Quick capture, block editor, Close/Start the day, Snippet, New template)
Mac:
```
┌───────────────────────────────────────────────────────────────┐
│ New project                              [ Cancel ] [ Create ] │  ← 17 semibold in the part colour; buttons .large, Create filled in the part colour
│ One grey line under the title row                              │
│  Name            [ text field, .large                      ]   │  ← Form, .formStyle(.grouped): labels left (12 soft), controls right
│  Serves          [ pop-up ▾ white, border, grey chevron    ]   │
│  In area         [ pop-up ▾                                ]   │
│  Deadline        [ 2026-12-01 ] [calendar]                     │
│  Tags            [ #house  #2027  + ]                          │
│  Start from      [ pop-up ▾ template                       ]   │
└───────────────────────────────────────────────────────────────┘
```
- Width 520 (Quick capture 480, Close/Start the day 640), min height from content, never a scroll inside a scroll.
- **Cancel and Save side by side top right** (his brief). Save/Create/Done filled in the part's colour, `.controlSize(.large)`; Cancel bordered. Today they sit bottom right (`SheetFooter`) — they move up.
- Keys: **Escape = Cancel**, **⌘S = Save** (and Return in a one-line field), **Tab** moves between fields in order, the first field has focus when the sheet opens, focus ring visible.
- iPhone: `NavigationStack` sheet, title inline, **Cancel left, Save right** in the bar, Save in the part colour and bold; the sheet slides up (`.presentationDetents([.large])`, medium for Quick capture). A full-width main button at the foot only where there is one action and no bar (Start/Close the day keep theirs, in colour).
- The Date window (`DateTimeChoiceView`) keeps its field + calendar; **Set** becomes the filled main button; the pop-up calendar is Apple's `.graphical` picker as now.

---

## 6. Native controls — nothing iPhone-like on the Mac
| Control | Mac | iPhone |
|---------|-----|--------|
| choose one of a list | `Picker(.menu)` = NSPopUpButton: white, 1 pt border, grey chevron, 13 pt. In the note header and on chips: `Menu` + `.menuStyle(.button)` + `.buttonStyle(.bordered)` so it also has a border and a chevron — **never coloured text on nothing** (today's "blue text" problem, `PickerChip`, `NoteGoalChip`, `AreaParentChip`, `ProjectAreaChip`, `NoteStatusChip`) | `Picker` in a Form row (navigation link or menu), Apple's |
| on/off | `Toggle(.switch)` in sheets and Settings (Apple's own Settings style); `.checkbox` only in lists of options | switch |
| date | the field + graphical calendar window as now; a `DatePicker(.compact)` for times (At) | Apple's wheel/compact |
| task checkbox | the circle (his, build 153), 15 pt, aligned with the text | 20 pt circle |
| text field | `.roundedBorder`, `.large` in sheets | Form row |
| buttons | `.bordered` for secondary, `.borderedProminent` tinted in the part colour for the main one; `.plain` only for chevrons and in-row marks | same |
| segmented | `Picker(.segmented)` in the toolbar (Calendar: Day/Week/Month/Notes; Help pages) — Apple's | Apple's |
| toolbar | Search, New note (+, in the section's colour), Quick capture, Sync, Edit toggle, Back/Forward — all in the window toolbar, `Label` with the hand-drawn icon; **no buttons floating inside the page** (today: Start/Close day in Today's date row, Show all in the Goals header, "+" in the list column's own bar — they move to the window toolbar, same functions) | nav-bar items |
| keyboard focus | the default focus ring on every control; `.focusEffectDisabled()` only on the graphical calendar and the Done grid, as now | — |
| menus | Apple's `Menu` / context menu, 13 pt, hand-drawn icons at 13 pt where an item has one | — |

---

## 7. Empty states
One calm line, 15 pt secondary, centred, with the part's hand-drawn icon above it at 28 pt in the part colour at 60 %: "Nothing in the Inbox." / "No note open — choose one on the left." No headline, no 380-pt paragraph, no prominent button (the New note button is in the toolbar already). Today's `EmptyStateView` (38 pt SF symbol + headline + callout + prominent button) is replaced everywhere it is used.

---

## 8. Icons
- Every icon is a hand-drawn single stroke from the AMS icon library: 24-pt grid, 1.9 stroke, round ends, no fill, stroked in the part colour (`currentColor`). The app already draws note icons from the AMS-Icons package; the 20 sidebar/section icons and the toolbar icons are added to `TemplateIcons.swift` in the same style and the library rebuilt.
- Sizes: sidebar 16 · toolbar 17 · section heading 17 (optional, before the words) · row mark 8 (dot) or 18 (own icon) · empty state 28 · widget 14.
- New icons to draw (one each): inbox tray, sun (Today), calendar, clock-blocks (Time Blocks), tick-list (Review), map nodes, ring (All actions), clock-back (Recent), ring-tick (Done), bin (Deleted), page-gear (Templates), text-append (Snippets), hash (Tags), magnifier (Search), star (Aspiration), target (Goal), flag (Project), four squares (Area), books (Resource), box (Archive), briefcase (Work), plus, capture-tray, sync arrows, pencil, back/forward chevrons, archive-down, gear, moon (Close the day), sunrise (Start the day).

---

## 9. Reading width and the window
- Note text stops at **680 pt**, centred in the detail column; the header band and the panels (Tasks, Linked notes, Goal chain) use the same 680. On a 13-inch laptop (window 1180 wide: sidebar 210 + list 300 + detail 670) the text fills the column with 24 pt gutters; on a big screen it stays 680 centred and the extra space is calm margin.
- Sidebar: translucent system material, hides with the standard toolbar button (⌃⌘S) — nothing custom.
- Column widths above; the window remembers them.

---

## 10. What is wrong today — his five, and points 6 onward (from the code)
1. Pop-ups are blue text — chips are `.buttonStyle(.plain)` with coloured words and no border (85 plain-styled buttons in the views). Fix: section 6.
2. No type system — 195 uses of `.caption`, 54 of `.caption2`, 38 `.callout`, 29 `.headline`, hardly any `.body`; sizes chosen per screen. Fix: section 1.
3. Text far too small for the window — most words are 12 pt (the whole note header, every list's second line, the review's numbers, Today's date); the note editor is 14 pt with no reading width, so on a big screen lines run 150 characters. Fix: sections 1 and 9.
4. Headings do not stand out — every section heading is `SectionLabel`: 12 pt UPPERCASE grey. Fix: 17 semibold in the part colour.
5. Panels have no colour and no meaning — `ModeAccent` washes the whole column at 8.5 %, the note header adds a second 10 % wash, nothing has an edge. Fix: section 2, tinted panels.
6. **The note header is a row of twelve chips** (kind, icon, name capsule, Status, In area, Serves, Horizon, Target, Measure, Looked at, Deadline, Tags, List) at 12 pt, labels and buttons mixed so you cannot tell what is pressable. Becomes a **facts panel**: the title at 26 bold above; under it a two-column table label 12 soft / value 15, each value a bordered pop-up where it can be changed and a plain value where it cannot; the icon beside the title.
7. **Edit and Read reflow the note** — Edit 14/23/20/17, Read 17/28/22/20. One scale for both (section 1).
8. **Two toolbars, and buttons inside pages** — the list column has its own "+", Today has Start/Close day in the date row, Goals has Show all in its header. All window-level actions go to the window toolbar.
9. **Rows carry a 3 pt stripe and up to six facts** at 12 pt; the title is 13 semibold so title and facts fight. One title, one second line, one dot.
10. **Grey main buttons** — the phone's `SheetFooter` greys Save until it can act; Set in the date window is a plain button. Main button always in colour, disabled at 40 %.
11. **Night mode is a wash on a wash** — 8.5 % tint over the dark window plus the 10 % header reads brown-grey. Night panels are a lighter surface `#1E2228` on `#15181C` with 13 % tint and a 1 pt line.
12. **Icons are 88 SF Symbols of uneven weight** (tray, sun.max, point.3.filled.connected…, text.append) in nine colours in one sidebar. One hand-drawn set, one stroke.
13. **Empty states shout** — 38 pt symbol, headline, 380 pt paragraph, prominent button. One calm line and the icon.
14. **Widgets keep their own colour table** (`WidgetLookHex`, `PlanLook`) — they take the same part colours or they drift.
15. **The version does not show** — only "Build 279" at the sidebar's foot and under Browse. Settings › About and the sidebar foot show "1.0 (279)".
16. **Capsule chips in five styles** (`ChainChip`, `NoteStatusChip`, `ProjectPill`, `CountPill`, `ReadChip`, `PickChip`, `SavedSearchChip`, the name capsule) — one `Pill` (12 medium, part colour on 14 % tint) for a fact, one bordered button for a choice.
17. **Section headers inside `List` on the Mac** (`FoldButton` + `SectionLabel`) are 12 pt grey with a 10 pt chevron — the fold stays, the words become the 17 pt heading with a 13 pt chevron in the part colour.
18. **iPhone root tabs use inline titles** (Browse draws its own `.headline` title to take a long press). Large titles on Today, Plan, Actions, Inbox, Browse; the long press moves to the "Build" row, which already has one.
19. **The planner's hour ruler, the Map's boxes and the Done squares** draw their own 10 pt labels (`size: 10 * zoom`); they take `label` 12 / `listSecond` 11 — nothing under 11 pt anywhere.
20. **Mac sheets put Cancel/Save bottom right** (`SheetFooter.deskRow`) while his brief says top right; and Tab does not reach every field in the New note sheet (chips are buttons, not fields). Fix: section 5.

---

## 11. Recommendation — Look B
**Look B, coloured panels with meaning.** It is the one that answers his five points in his own words: panels get a colour that says what they are (point 5), headings pop in that colour (4), the type scale is the Subscriptions 1.0 one he already likes (2, 3), and the pop-ups are white with a border and a grey chevron (1). Look A is Apple-plain and calm but leaves the panels without colour, which is the very thing he asked for; Look C is the quietest and the closest to Things, but he said "not like Things in this particular respect" about panels. B keeps the note text itself on plain white at a reading width, so the colour sits on the facts, tasks and links around it and never on the words he reads.

One real choice for him (use, not looks): his brief says no buttons floating inside the page, but **Start the day / Close the day** sit in Today's date row and **Show all** in the Goals header — both his placements. The mock-ups leave them where they are; moving them into the window toolbar needs his yes.
