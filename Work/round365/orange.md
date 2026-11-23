# Build 365: orange means one thing

## What changed
- App/Paragon/Assets.xcassets/PlanTint.colorset: day #C05E0C -> #8E4B2A, night #F2A45C -> #E0946A (copper).
- App/ParagonWidgets/Assets.xcassets/PlanTint.colorset: same copy, same new values (a test keeps the two equal).
- App/Paragon/Assets.xcassets/MorningTint.colorset: day #D4640A -> #C8553D, night #FFA23A -> #F08A74 (coral).
- App/Paragon/Views/Theme.swift: two comments only.
- Core/Tests/ParagonCoreTests/LookRulesTests.swift: testPlanAndMorningColoursAreNotTheWarningOrange.

## Who follows by itself (no code change needed)
- Focus timer: in-app bar (FocusViews), Today "Now" line, Mac menu bar item (FocusMenuBar reads PlanTint), Lock Screen and Dynamic Island (FocusLiveActivityWidget uses PlanLook.plan = PlanTint). All were already PlanTint, so one colour set moves all of them.
- Plan blocks, planner capsules, Today's plan widget: PlanTint.
- Start the day button on Today, the Start the day screen: MorningTint.
- Shades for buttons, words, bands are computed from the colour sets (Look.swift reads them), so they follow.

## Left orange on purpose (warnings)
Theme.attention (#D4640A / #FFA23A, Look.swift), all Color.orange fills and dashes in Review, Goals flags, Done waiting day, Theme notice boxes, OwnFolderViews, SyncReport, EmptyStateView (tint == .orange untouched), the widgets' unused WidgetLook.attention.

## Readability (measured)
- Copper day: white words 6.6 to 1; night: dark words 8.6 to 1.
- Coral day: white 4.4 to 1 (same as the old plan orange; the app's own rule steps it deeper for small words); night: dark 8.6 to 1.
- Plan block strengths (22 % fill, coloured words and edge) kept as they were.

## Uncertain
- Looks not seen on screen (no simulator allowed). Copper on the dark night page is 7 to 1, fine; copper day on a white page is fine.
- Old tests with hard-coded old hex (Round9BTests, ShadeRuleTests) test the shade rule with their own numbers, so they still pass; they were not run.
- The Calendar month grid note in round352/looks.md is unrelated.
- Docs still say "orange" for plan blocks and the timer in many places (HowItWorks, Guide); not edited per instructions.

## Ready sentences
(a) What's new: Orange now means one thing only: this needs a look. The plan's time blocks and the focus timer are now copper brown, and the morning (the Start button on Today and its screen) is now a warm coral, by day and by night.
(b) How it works: Time blocks in the planner and the focus timer (the bar at the foot, the Now line, the Mac menu bar and the Lock Screen) are copper brown. The Start the day button and its screen are coral. Orange is kept for warnings.
(c) Signs in this app: Orange = needs a look. Copper brown = a plan time block or the focus timer. Coral = the morning.
