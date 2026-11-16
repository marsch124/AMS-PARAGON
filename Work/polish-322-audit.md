# Polish audit for build 322 — list B (items 1-39 of round9 start note)
Checked 2026-11-16 against HEAD (3171687), VersionHistory 316-321, designer lists 316-319, and the code.

| # | Short title | Status | Build or file:line | Fix |
|---|---|---|---|---|
| 1 | What's new dates 2026-11-13 | DONE | 316 (VH #16); HelpView.swift:245 | - |
| 2 | What's new blurred band iPhone | DONE | 316 (#17) | - |
| 3 | Find in note title over text (iPhone) | DONE | 316 (#14); blue tick cannot be tinted | - |
| 4 | Add a task field black at night | DONE | 316 (#26) | - |
| 5 | Settings cards faint / conflict row 2 lines | DONE | 316 (#25, #18); SettingsView.swift:123 | - |
| 6 | About computer talk behind Details | DONE | 316 (#19); SettingsView.swift:399 | - |
| 7 | Mac Vault raw path | DONE | 316 (#20); SettingsView.swift:55 | - |
| 8 | Restore result in Settings | DONE | 316 (#6, tick look in 316 polish) | - |
| 9 | One outside-copy folder per vault | DONE | 316 (#4) | - |
| 10 | Two vault ids -> older wins | DONE | 316 (#5) | - |
| 11 | "Restoring..." on sync line | DONE | 316 (#7); Theme.swift:442, SettingsView.swift:108 | - |
| 12 | "No weekly review yet" | DONE | 316 (#8); AppModel.swift:4888 | - |
| 13 | Weekly review default Sunday 17:00 | ASK | EveningReminder.swift:85 (default 17*60); On/At pickers exist since 315 | Ask his day and time, then change the default only if he wants another |
| 14 | iPad Find in note | DONE | 316 (#13) | - |
| 15 | One small widget per list | DONE | 316 (#15); ParagonWidgets.swift:570 (not seen live) | - |
| 16 | Record own capture key | DONE | 316 (#11); SettingsView.swift:663 | - |
| 17 | Review iPhone steps spacing / ticks | DONE | 316 (#9) | - |
| 18 | Review Mac headings cut | DONE | 316 (#10) | - |
| 19 | Map: cut box, lines, toolbar, band | ASK | 316 (#34) fixed lines, 2-line titles, slot, Mac band; iPhone box still cut at right edge (map wider than screen) | Needs his choice: new starting zoom for the iPhone Map (MapView.swift) |
| 20 | Mac Inbox Add pale | DONE | 316 (#27) | - |
| 21 | Add-a-task bar stuck after Search | UNTRIED | 316 "could not be made to happen" | Ask him to watch for it on the real phone; no code change |
| 22 | Daily note date three times | DONE | 316 (#29) | - |
| 23 | Cut texts (Next:, goal counts, snippets, calendar heading, Map titles) | DONE | 316 (#33, #34); ProjectsView.swift:255,275 | - |
| 24 | "Press" hints / menu dots | DONE | 316 (#21) dots removed (ParagonApp.swift:50,297); "Press" kept as house wording | - |
| 25 | Bands repeat the line under them | OPEN | Inbox + Plan done 316 (#30); Map and Search bands still show only the date: PhoneRootView.swift:448 | Give Map a fact (e.g. "N boxes") and Search a fact ("Search everything") instead of the bare date; or leave (very small) |
| 26 | Orange too weak by day | DONE | 316 (#23); Shade.swift:71 | - |
| 27 | Day band far end pale | DONE | 316 (#24) | - |
| 28 | iPhone day cards faint | ASK | 316 (#25) shipped 12 % tint (#EDEAF5, 1.09:1); designer: "stand out" | His list said show a stronger variant; ask whether 12 % is enough or show one picture of 12 / 16 / 20 % |
| 29 | Mac group heading 8 pt taller | DONE | 316 (#35) | - |
| 30 | New tiles words, fold arrows, icon-picker Cancel | OPEN | Tiles + fold arrows DONE 316 (#37); icon-picker Cancel still grey outline (shared AMS icon library): NoteIconViews.swift:212 | Make that Cancel the standard Cancel button look; change in the library too (Martin's call that it is shared) |
| 31 | Large text, real icon, Mac icon picker | UNTRIED | needs real device / Mac | Look at the home-screen icon, largest text size, Mac picker once |
| 32 | Plan band / toast / Not planned yet | DONE | 316 (#31); CalendarView.swift:545 | - |
| 33 | Today shows a note from Browse | DONE | 316 (#32) | - |
| 34 | Project/Goal sheet Save grey | DONE | 316 (#28, #41) | - |
| 35 | Mac ring hover tip / short words | DONE | 316 (#22); ContentView.swift:1456; menu-bar short words kept on purpose (Theme.swift:389) | - |
| 36 | Side effects he may want back | ASK | Sync now = 2 taps, Recent 40 Mac only, no search in one list on iPhone, Next free time to midnight, review forgets open parts (Focus on this by swipe: DONE 316 #12) | Ask which of the remaining four he wants back |
| 37 | Mac Search page band + sidebar row | DONE | 316 (#36) | - |
| 38 | Folding group, dragging edge, iPad sidebar | UNTRIED | needs real Mac / iPad | Try once by hand |
| 39 | "Remove its N reminders too?", merge, parked versions | UNTRIED | needs two real devices; backups still hold no pictures | Trial on the throwaway vault |

## Counts
DONE 29 · OPEN 2 (#25, #30) · ASK 4 (#13, #19, #28, #36) · UNTRIED 4 (#21, #31, #38, #39)

## Designer leftovers (not in list B) still open after 321
- 317 list: Pause grey in focus bar (his call), Lock Screen banner gap, Today's plan 30-min name + ruler start, "Notes in it" wording, small widget green circle, widget foot "PARAGON 317 . written" line.
- 318 list: goals list two per cents / 97 pt row / "Edit number..." label / bar-curve gap / review row gap / Edit dash / keyboard hides bar / tick fade band / share words field height (check whether 319-321 fixed any).
- 319 list: device names, toast wording "rests" fixed in 319 (text), Stop page headline, empty PARAGON folder, finished page, Mac offer page not pictured.
- Memory note: Mac sheet button focus ring wider than the button (14 Nov) and grey main button in Settings > Vault.
