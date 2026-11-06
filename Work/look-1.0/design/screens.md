# PARAGON — every screen, sheet, popover, menu, alert and widget

Walk list for the picture-taker and the reviewer. Paths are under
`App/Paragon/` unless they start with `App/ParagonWidgets/` or `App/ParagonShare/`.
"L123" is the line where the thing starts. Build 279.

Counts: **22 sidebar sections** · **9 window-level sheets** · **8 sheets inside screens** · **20 popovers** ·
**16 context menus** · **6 toolbar/button menus** · **4 menu-bar menus + 1 status-item menu** · **18 alerts and
confirmation dialogs** · **3 widgets** (3 sizes each) · **1 share extension** · **5 iPhone tabs**.
Total distinct things to look at: **about 140**.

---

## A. Windows and top-level structure

### Mac
| # | Thing | File | Starts |
|---|-------|------|--------|
| A1 | Main window: three columns (sidebar · list · detail), `NavigationSplitView` | Views/ContentView.swift | L67 |
| A2 | Window toolbar: Quick capture, Sync menu (Mac has no Settings button; Settings is ⌘,) | Views/ContentView.swift | L80 |
| A3 | Welcome screen (no vault chosen yet) + folder picker | Views/ContentView.swift | L309 |
| A4 | Sidebar (`SidebarView`), sections Actions / Tools (foldable) / Goals / PARA / Work, build stamp + iCloud warning bar at the foot | Views/ContentView.swift | L361 |
| A5 | Middle column (`NoteListView`): flat list, Areas tree, search field, toolbar "+" in the section's colour, Clear (Recent), Hide (Work) | Views/ContentView.swift | L466, toolbar L701 |
| A6 | Detail column (`DetailView`) — which screen it shows per section, mode-tinted | Views/ContentView.swift | L1119 |
| A7 | "Plan the day" extra window (planner on its own) | ParagonApp.swift | L86 |
| A8 | PARAGON Help window (How it works / Words / Version history, segmented) | ParagonApp.swift L100; Views/HelpView.swift | L7, document L48 |
| A9 | Settings window (⌘,) | ParagonApp.swift L102; Views/SettingsView.swift | L4 |
| A10 | Menu bar extra "PARAGON quick capture" (window style, compact capture) | ParagonApp.swift | L96 |
| A11 | Focus timer status item in the menu bar (`NSStatusItem`) + its menu: title, Planned, Pause/Go on, Stop…, Show PARAGON | FocusMenuBar.swift | L32, menu L131 |
| A12 | Focus bar at the foot of the window (while a timer runs) | Views/FocusViews.swift | L30 |
| A13 | Flash capsule at the foot (message + Undo) | UndoOffer.swift | L142 |

### iPhone (compact width)
| # | Thing | File | Starts |
|---|-------|------|--------|
| A14 | Tab bar: Today · Plan · Actions · Inbox (badge) · Browse | Views/PhoneRootView.swift | L19, tabs L23, pages L91 |
| A15 | Today tab: `TodayView` with "+" (leading) and Sync (trailing) | Views/PhoneRootView.swift L93; Views/TodayView.swift | L5 |
| A16 | Plan tab: `NoteListView(fixed: .timeBlocks)` → planner | Views/PhoneRootView.swift | L119 |
| A17 | Actions tab: `NoteListView(fixed: .allActions)` | Views/PhoneRootView.swift | L127 |
| A18 | Inbox tab: `NoteListView(fixed: .inbox)` | Views/PhoneRootView.swift | L135 |
| A19 | Browse tab (`PhoneBrowseView`): groups Goals and PARA / Plan / Tools / Settings and Help / Build (long-press reveals Work) | Views/PhoneRootView.swift | L266 |
| A20 | Section screen pushed from Browse (`PhoneSectionScreen`) | Views/PhoneRootView.swift | L354 |
| A21 | Navigation stack per tab (`PhoneStack`, routes note / template / section / settings) | Views/PhoneRootView.swift | L172, routes L258 |
| A22 | Settings pushed from Browse (iPhone) · Settings as sheet with Done (iPad / compact from toolbar) | Views/PhoneRootView.swift L194; Views/ContentView.swift | L126 |
| A23 | Focus bar above the tab bar | Views/PhoneRootView.swift | L71 |
| A24 | Share extension sheet ("PARAGON": text, Save to Inbox/Today's note, As note toggle) | App/ParagonShare/ShareViewController.swift | L8, view L81 |

### iPad
Uses the Mac's three columns (A1–A6) with the iPhone's toolbar extras (Settings gear in toolbar, ContentView L92).

---

## B. Sidebar sections (the 22 rooms) — Mac middle+detail, iPhone pushed screens

`SidebarSection` is AppModel.swift L12–110 (cases L13–36, titles L40–61, symbols L63–100, order L102, tools L107).
Phone Browse groups: PhoneRootView.swift L269–277.

| # | Section | Middle column / phone list | Detail (Mac) | Files |
|---|---------|---------------------------|--------------|-------|
| B1 | Inbox | `InboxTriageView` (lines, quadrant, date sheet) | `InboxFileItView` (destinations) or the note | Views/InboxView.swift L66, L365, L449 |
| B2 | Today | `TodayView` (date row, Start/Close day buttons, Now & Next, week goal, Calendar fold, Today's note, Overdue, Due today, Important, Next actions) | note | Views/TodayView.swift L5 |
| B3 | Calendar | `CalendarView` segmented Day / Week / Month / Notes | `CalendarDetailView` → `DayScheduleView` | Views/CalendarView.swift L5, L31, L479, L592, L321; Views/DayScheduleView.swift L6, L88 |
| B4 | Time Blocks (Plan) | `TimeBlocksView` list of blocks | `PlannerDayView` (calendar lane + plan lane + now-line) | Views/TimeBlocksView.swift L6; Views/PlannerView.swift L38, L88 |
| B5 | Weekly review | `ReviewView` steps 1–6 + Due for a look + Projects with no goal | note | Views/ReviewView.swift L11, headings L79–265 |
| B6 | Map | `MapView` canvas (wide column), footer, export | note | Views/MapView.swift L7, canvas L328, node L478, footer L751 |
| B7 | All actions | `AllActionsView` | note | Views/AllActionsView.swift L24 |
| B8 | Recent | flat `NoteRow` list, Clear | note | Views/ContentView.swift L466 |
| B9 | Done | `DoneView` day cards + squares | empty state / note | Views/DoneView.swift L11, L156, L236 |
| B10 | Deleted | `DeletedView` + Empty… | note | Views/DeletedView.swift L7 |
| B11 | Search | `SearchView` (filters, saved searches, help) | note | Views/SearchView.swift L18, filter L383, hit L414, help L450, chip L506 |
| B12 | Templates (Tools) | `TemplatesView` groups | `TemplateEditorView` | Views/TemplatesView.swift L7, L186 |
| B13 | Snippets (Tools) | `SnippetsView` | `TemplateEditorView(Snippets.md)` | Views/TagsView.swift L197 |
| B14 | Tags (Tools) | `TagsView` | empty state / note | Views/TagsView.swift L13 |
| B15 | Aspirations | `AspirationsListView` (+ Show all) | `GoalDetailView` chain / `AllAspirationsView` | Views/GoalsView.swift L20, L667, L1203, header L1261 |
| B16 | Goals (dated) | `DatedGoalsListView` | `GoalDetailView` | Views/GoalsView.swift L217 |
| B17 | Projects | `ProjectsListView` grouped by aspiration, week band, `ProjectBox` | note | Views/ProjectsView.swift L16, header L215, box L337, tile L682 |
| B18 | Areas | two-level tree in `NoteListView` | `AreaDashboardView` (area page) / note | Views/ContentView.swift L492; Views/AreasView.swift L24 |
| B19 | Resources | flat list | note | Views/ContentView.swift L466 |
| B20 | Archive | flat list (grey) | note | Views/ContentView.swift L466 |
| B21 | Work (hidden until revealed) | flat list, Hide button, New work note alert | note | Views/ContentView.swift L706, L732 |
| B22 | Daily / weekly notes (reached via Calendar › Notes or Today) | `DailyNotesListView` | note with `DayAgendaView` / `WeekAgendaView` | Views/CalendarView.swift L321; Views/NoteEditorView.swift L1473, L1517 |

---

## C. The note (detail column on the Mac, pushed screen on the iPhone)

| # | Part | File | Starts |
|---|------|------|--------|
| C1 | `NoteEditorView` body, desk / phone layouts | Views/NoteEditorView.swift | L4, desk L249, phone L265 |
| C2 | Note toolbar — Mac: Back/Forward, Edit toggle, Archive, Delete; phone: "More" menu (Rename / Archive / Delete) | Views/NoteEditorView.swift | L165 |
| C3 | `NoteHeader` tinted band: kind, icon chip, name capsule, Status, In area, Serves, Horizon, Target, Measure, Looked at, Deadline, Tags, List | Views/NoteEditorView.swift | L1056 |
| C4 | Sections: Day agenda / Week agenda / Goal dashboard / Tasks fold / Linked notes fold | Views/NoteEditorView.swift | L331 |
| C5 | Settings block (frontmatter) fold row | Views/NoteEditorView.swift | L441 |
| C6 | Markdown editor (NSTextView / UITextView) with syntax colouring; base 14 pt, headings +9/+6/+3 | Views/MarkdownSyntaxEditor.swift | L17, sizes L77 |
| C7 | Read mode `MarkdownPreview` (title/title2/title3 headings) | Views/MarkdownPreview.swift | L6, fonts L203 |
| C8 | Add-task bar at the foot (+ snippet menu, task syntax help button) | Views/NoteEditorView.swift | L550, snippet menu L581, syntax L1718 |
| C9 | `TaskChecklist` + `TaskRow` (checkbox, title, date, time, who, next-action, subtask) | Views/NoteEditorView.swift | L1221, L1276 |
| C10 | Linked notes / Missing links / Wiki link list | Views/NoteEditorView.swift | L1423, L1447, L1676 |
| C11 | Area standard box (on an area note) | Views/AreaStandardView.swift | L80 |
| C12 | Aspiration reason box (on an aspiration) | Views/AspirationReasonView.swift | L106 |
| C13 | Waiting-for list (on a note with waiting tasks) | Views/WaitingForView.swift | L168 |
| C14 | Goal chain page: `GoalDetailView`, `AspirationChainBody`, `ChainGoalBlock`, `ChainProjectRow`, chips | Views/GoalsView.swift | L667, L711, L876, L1052, L1111 |
| C15 | Area page `AreaDashboardView` (projects, sub-areas, status items) | Views/AreasView.swift | L24, L192, L322 |

---

## D. Sheets

### Window-level (`AppSheet`, AppModel.swift L114–131; presented ContentView.swift L105)
| # | Sheet | File | Starts |
|---|-------|------|--------|
| D1 | New note (`NewNoteSheet`: What? chips Aspiration/Goal/Project/Area/Resource/Capture, name, serves, area, date, tags, template; footer Cancel/Create) | Views/NewNoteSheet.swift | L99, choices L16, footer `SheetFooter` Theme.swift L549 |
| D2 | Quick capture (desk + phone + compact menu-bar form) | Views/QuickCaptureView.swift | L19 |
| D3 | Sync report | Views/SyncReportView.swift | L5 |
| D4 | Note from a `[[link]]` (`NoteFromLinkSheet`) | Views/NewNoteSheet.swift | L979 |
| D5 | Close the day (done today, left over, tomorrow's First, one line about the day, planned vs worked) | Views/CloseDayView.swift | L18 |
| D6 | Start the day (pick today's few, time question, In plan) | Views/StartDayView.swift | L20 |
| D7 | Focus stopped — "is the task done?" (`FocusStopView`) | Views/FocusViews.swift | L179 |
| D8 | Settings as a sheet with Done (iPad/compact only) | Views/ContentView.swift | L126 |
| D9 | Week look step / Week goal step (in Close the day on the week's last day and in the review) | Views/WeekLookStep.swift | L23, L428 |

### Inside screens
| # | Sheet | File | Starts |
|---|-------|------|--------|
| D10 | Inbox: pick a date for a line (`DateChoiceView` in a sheet) | Views/InboxView.swift | L178, L511 |
| D11 | Planner: block editor sheet / "Calendar blocks" sheet (`PlannerSheet`) | Views/PlannerView.swift | L129, kinds L1082 |
| D12 | Calendar day: `TimeBlockSheet` new / edit (`ScheduleSheet`) | Views/DayScheduleView.swift | L127, L437 |
| D13 | Map: share/export file (`ShareSheet`, iOS) | Views/MapView.swift L87; Views/MapExport.swift | L110 |
| D14 | Note: fill a snippet (`SnippetSheet`) | Views/NoteEditorView.swift L159; Views/TemplatesView.swift | L283 |
| D15 | Templates: new template (`NewTemplateSheet`) | Views/TemplatesView.swift | L104, L328 |
| D16 | Quick capture: pick a date | Views/QuickCaptureView.swift | L70 |
| D17 | Welcome: folder importer | Views/ContentView.swift | L57 |

---

## E. Popovers (20)
| # | Popover | File | Starts |
|---|---------|------|--------|
| E1 | Project deadline date (`DateChoiceView`) | Views/NoteEditorView.swift | L712 |
| E2 | Goal target date | Views/NoteEditorView.swift | L753 |
| E3 | Goal measure editor (`GoalMeasureEditor`) | Views/NoteEditorView.swift | L837, L893 |
| E4 | Project ended date | Views/NoteEditorView.swift | L1019 |
| E5 | Task "Waiting for who" (`WaitingWhoView`) | Views/NoteEditorView.swift L1375; Views/WaitingForView.swift | L88 |
| E6 | Task date + At time (`TaskDatePicker` → `DateTimeChoiceView`) | Views/NoteEditorView.swift L1399; Views/TaskActions.swift L208; Theme.swift | L240 |
| E7 | Task syntax help | Views/NoteEditorView.swift | L1736, L1741 |
| E8 | Task "How long" chooser (`TaskTimeChoices`) | Views/TaskActions.swift | L295, L305 |
| E9 | Start the day: time question per pick | Views/StartDayView.swift | L505 |
| E10 | Close the day: choose the day | Views/CloseDayView.swift | L573 |
| E11 | New note: Serves / Area / Template picker list (`PickerChip`) | Views/NewNoteSheet.swift | L775 |
| E12 | New note: tags (`TagChoices`) | Views/NewNoteSheet.swift | L918 |
| E13 | New note: date (`DateChip`) | Views/NewNoteSheet.swift | L946 |
| E14 | Quick capture: tags | Views/QuickCaptureView.swift | L412 |
| E15 | Quick capture: syntax help (`CaptureSyntaxHelp`) | Views/QuickCaptureView.swift | L69, L469 |
| E16 | Goals: add a serving note (`AddServingNoteBox`) | Views/GoalsView.swift | L1371, L1411 |
| E17 | Goals/areas: "Looked at" box (`LookedAtBox`) | Views/GoalsView.swift | L1606, L1647 |
| E18 | Note icon picker (`NoteIconChip`) | Views/NoteIconViews.swift | L111 |
| E19 | Note tags (`NoteTagsChip`) | Views/TagsView.swift | L280, L297 |
| E20 | Goal horizon (This year / Long term) | Views/GoalHorizonChip.swift | L45 |

Chips in the note header that open menus rather than popovers: `NoteStatusChip` (GoalsView L1144), `NoteGoalChip` "Serves" (ContentView L943, menu L936), `AreaParentChip` "Part of" (ContentView L1001, menu L994), `ProjectAreaChip` "In area" (ProjectArea.swift L156, menu L148).

---

## F. Menus

### Menu bar (Mac) — ParagonApp.swift
| # | Menu | Items | Starts |
|---|------|-------|--------|
| F1 | File (replacing New) | New Note… ⌘N · Quick Capture… ⇧⌘N · Search Everywhere… ⇧⌘F · Sync with Reminders ⇧⌘R · Work/Hide Work ⌃⌘W | L33 |
| F2 | Go | Plan the Day… ⇧⌘P · Back ⌃⌘← · Forward ⌃⌘→ | L55 |
| F3 | Help | How PARAGON Works ⌘? · Words in PARAGON · Version History · Copy Diagnostics ⌃⌘D | L74 |
| F4 | Status item menu (focus timer) | see A11 | FocusMenuBar.swift L131 |
| F5 | Menu bar extra (quick capture window) | see A10 | ParagonApp.swift L96 |

### Toolbar and button menus
| # | Menu | File | Starts |
|---|------|------|--------|
| F6 | Sync (Sync now · Show me what would change… · Last sync report…) | Views/ContentView.swift | L1205 |
| F7 | Note snippet menu (one item per snippet) | Views/NoteEditorView.swift | L581 |
| F8 | Phone note "More" menu (Rename / Archive / Delete) | Views/NoteEditorView.swift | L170 |
| F9 | "Serves" menu (`NoteGoalMenu`) | Views/ContentView.swift | L931, L936 |
| F10 | "Part of" menu (`AreaParentMenu`) | Views/ContentView.swift | L989, L994 |
| F11 | "In area" menu (`ProjectAreaMenu`) | Views/ProjectArea.swift | L143, L148 |

### Context menus (right-click / long press)
| # | On | Items | File | Starts |
|---|----|-------|------|--------|
| F12 | Note row (middle column) | Looked at · Rename… · Part of › · Serves › · In area › · Archive · Delete… | Views/ContentView.swift | L589 |
| F13 | Task row | Focus on this · Reschedule › (Today/Tomorrow/Next Monday/In a week/Pick…/Remove) · How long › · Repeat › · Move to › · Waiting for… · Next action · Delete | Views/NoteEditorView.swift L1393; Views/TaskActions.swift | L64 |
| F14 | Inbox line | Move to › · Turn into a note › (Project/Area/Resource/Goal) · Block time for this… · Remove the date · Rename… · Delete | Views/InboxView.swift | L288, L316 |
| F15 | Aspiration / goal row | Open the note · Archive | Views/GoalsView.swift | L87, L114, L182, L194, L343, L357, L361 |
| F16 | Project row (grouped list) | Rename… · Serves › · In area › · status items · Archive · Delete… | Views/ProjectsView.swift | L115, L120 |
| F17 | Area page project row | Serves › · In area › · status items | Views/AreasView.swift | L228 |
| F18 | Calendar event row | Open in Calendar | Views/CalendarEventsView.swift | L108 |
| F19 | Time block row | Edit · Open in Calendar · Delete… | Views/TimeBlocksView.swift | L155 |
| F20 | Planner block card | (block menu) | Views/PlannerView.swift | L950 |
| F21 | Map node | Unpin / pin | Views/MapView.swift | L537 |
| F22 | Review rows (health, goal health, due) | Looked at · Set active · Open the note | Views/ReviewView.swift | L564, L676, L748 |
| F23 | Deleted row | Put back · Delete for good | Views/DeletedView.swift | L83 |
| F24 | Template row | Rename… · Delete… | Views/TemplatesView.swift | L52 |
| F25 | Tag row | Rename… · Delete… | Views/TagsView.swift | L129 |
| F26 | Saved search chip | Rename… · Delete | Views/SearchView.swift | L530 |
| F27 | Done / All actions task rows | task menu (F13) | Views/DoneView.swift, Views/AllActionsView.swift | (via `TaskRow`) |

---

## G. Alerts and confirmation dialogs (18)
| # | Alert | File | Starts |
|---|-------|------|--------|
| G1 | Something went wrong (OK) | Views/ContentView.swift | L220 |
| G2 | New work note (title field) | Views/ContentView.swift | L732 |
| G3 | Rename "note" (list) | Views/ContentView.swift | L743 |
| G4 | Delete "note"? (list) | Views/ContentView.swift | L766 |
| G5 | Delete "note"? (editor) | Views/NoteEditorView.swift | L137 |
| G6 | Rename "note" (editor) | Views/NoteEditorView.swift | L148 |
| G7 | New subtask (title field) | Views/NoteEditorView.swift | L1260 |
| G8 | Delete all N for good? (Deleted) | Views/DeletedView.swift | L41 |
| G9 | Place every box automatically again? (Map) | Views/MapView.swift | L91 |
| G10 | Rename template / Delete the template? | Views/TemplatesView.swift | L109, L118 |
| G11 | Rename #tag / Delete #tag everywhere? | Views/TagsView.swift | L61, L72 |
| G12 | Save this search / Rename saved search | Views/SearchView.swift | L78, L85 |
| G13 | Delete block from Apple Calendar? | Views/TimeBlocksView.swift | L33 |
| G14 | Restore the backup from …? | Views/SettingsView.swift | L253 |
| G15 | What is next for this goal? (`WhatNextDialog`) | Views/WhatNextDialog.swift | L103, L108 |
| G16 | Flash capsule messages (not modal) | UndoOffer.swift | L142 |
| G17 | Vault warning bar (iCloud) | Views/Theme.swift | L125 |
| G18 | Empty states (`EmptyStateView`) — Pick a template / Tags / Pick an aspiration / Pick a goal / What you finished / No note open / Nothing to do today / Nothing was left over … | Views/Theme.swift L97; ContentView L1140–1198; StartDayView L455; CloseDayView L150, L177, L241 | |

---

## H. Settings (one Form, both platforms) — Views/SettingsView.swift
| # | Section | Starts |
|---|---------|--------|
| H1 | Vault (folder, Choose folder…, Close vault) | L14 |
| H2 | Tasks (Use task times, Hide finished tasks) | L29 |
| H3 | Reminders sync (Sync automatically picker, When both sides changed picker, 4 toggles) | L44 |
| H4 | Backups (toggle, Back up now, Show in Finder, list with Restore…) | L93 |
| H5 | Apple Calendar (show events, per-calendar toggles, Time blocks go to picker, Connect…) | L131 |
| H6 | Help (How it works, Words, Version history — NavigationLinks on iPhone, window buttons on Mac) | L174 |
| H7 | Morning reminder / Evening reminder (`DayReminderSection`: toggle, At time, Allow notifications, test) | L187, L413 |
| H8 | Quick capture (menu bar toggle) | L190 |
| H9 | Weekly review (stale-days stepper, rhythm steppers) | L199, L210, L266 |
| H10 | Last sync | L222 |
| H11 | Widget status | L234, L336 |
| H12 | About (version, build) | L236 |
| H13 | Working day ends (`WorkdayEndRow`) | L557 |

---

## I. Widgets (App/ParagonWidgets/) — iPhone home screen, Mac Notification Centre
| # | Widget | Sizes | File | Starts |
|---|--------|-------|------|--------|
| I1 | Today's actions (`ActionsWidget`) | small, medium, large | ParagonWidgets.swift | L377, view L259, row L344 |
| I2 | What is waiting (`CountsWidget`) | small, medium | ParagonWidgets.swift | L445, view L391 |
| I3 | Today's plan (`TodayPlanWidget`) | small, medium, large | TodayPlanWidget.swift | L107, view L123, headline L230, ruler L362 |
| I4 | Widget look constants (`WidgetLook`, `WidgetLookHex`, `PlanLook`) — colours must follow the new system | ParagonWidgets.swift L136, L197; TodayPlanWidget.swift L38 | |

---

## J. Shared pieces that every screen draws (change these once)
| # | Piece | File | Starts |
|---|-------|------|--------|
| J1 | `Theme` numbers (gutter 14, tight 4, gap 8, radius 8, editor font/line spacing, planBlock/now/morning/evening tints) | Views/Theme.swift | L5 |
| J2 | `SectionLabel` (uppercase caption heading) | Views/Theme.swift | L44 |
| J3 | `WeekGoalLine` | Views/Theme.swift | L82 |
| J4 | `EmptyStateView` | Views/Theme.swift | L97 |
| J5 | `VaultWarningBar` | Views/Theme.swift | L125 |
| J6 | `ModeAccent` (0.085 tint over the detail column) | Views/Theme.swift | L153 |
| J7 | `DateChoiceView` / `DateTimeChoiceView` (date window, 300 pt) | Views/Theme.swift | L178, L240 |
| J8 | `WrappingHStack` | Views/Theme.swift | L389 |
| J9 | `SheetFooter` (Cancel + doing button) | Views/Theme.swift | L549 |
| J10 | `GoalProgressBar` | Views/Theme.swift | L622 |
| J11 | `StateToggle` (Edit toggle), `MoveToArchiveIcon` | Views/Theme.swift | L688, L672 |
| J12 | `FoldButton` | Views/Theme.swift | L745 |
| J13 | `NowLine` | Views/Theme.swift | L795 |
| J14 | `rowTint` (selection-safe tint) | Views/Theme.swift | L853 |
| J15 | `TaskTray` (draggable tiles) | Views/Theme.swift | L920 |
| J16 | `NoteRow` (list row: stripe/icon, title headline, caption facts) | Views/ContentView.swift | L1022 |
| J17 | `KindBadge`, `TintStripe` | Views/ContentView.swift | L1285, L1307 |
| J18 | `ParaKind.tint`, `SidebarSection.tint`, `Note.tint` | Views/ContentView.swift | L1237, L1251, L1277 |
| J19 | `ChainSymbol`, `ChainTint`, `GoalMark`, `GoalWording` | Views/GoalsView.swift | L411, L455, L487, L513 |
| J20 | `Pill`-like capsules: `CountPill`, `ProjectPill`, `ChainChip`, `NoteStatusChip`, `ReadChip`, `AddChip`, `PickChip`, `SavedSearchChip` | CloseDayView L316; ProjectsView L622; GoalsView L1111, L1144; QuickCaptureView L364, L422, L441; SearchView L506 | |
| J21 | Colour assets (13 `*Tint.colorset`, day + night) | Assets.xcassets/ | |
| J22 | Note icons from the AMS-Icons package (`NoteIconTile`, `NoteIconChip`) | Views/NoteIconViews.swift | L36, L81 |
