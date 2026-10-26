import SwiftUI
import ParagonCore

/// Everything due today or overdue, plus undated tasks marked `!!` or `!!!`.
struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    // Open by default, and its own key per platform, so folding it on the phone cannot
    // fold it on the Mac (build 161's pair). Build 121 still holds: the fold is one press
    // away and the count stays in the heading, so the day's events can never go missing
    // without saying so.
    @AppStorage("todayCalendarFolded") private var deskCalendarFolded = false
    @AppStorage("todayCalendarFoldedPhone") private var phoneCalendarFolded = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    /// A plain stub, so the body never carries an `#if` in the middle of a modifier chain
    /// (build 148's lesson, and build 160's about this pair).
    private var isPhone: Bool { false }
    #endif

    private var calendarFolded: Binding<Bool> {
        isPhone ? $phoneCalendarFolded : $deskCalendarFolded
    }

    var body: some View {
        let index = model.index
        let today = DateOnly.today()
        let dated = index.openTasks(dueOnOrBefore: today)
        let overdue = dated.filter { ($0.task.dueDate ?? today) < today }
        let dueToday = dated.filter { $0.task.dueDate == today }
        let important = index.openTasks().filter { $0.task.dueDate == nil && $0.task.priority >= 2 }
        let shown = Set((dated + important).map(\.id))
        let nextActions = index.nextActions().filter { !shown.contains($0.id) }
        let todayNotePath = model.vault?.dailyNotePath(for: today)
        let fromTodayNote = (model.todayNote?.openTasks ?? [])
            .filter { $0.dueDate == nil }
            .map { TaskRef(notePath: todayNotePath ?? "", noteTitle: "Today's note", task: $0) }

        // **The date is one short grey line, outside the List (builds 219 and 220).** 219
        // deleted the row it used to live in, because a full-width list row for a date and a
        // count repeated what the screen already said. He then asked for the date itself
        // back, and picked this shape. **It has to sit outside the `List` to be small at
        // all**: inside one it would be a row again, and a row has a minimum height whatever
        // is written in it — build 213's whole lesson. The count did not come back: the
        // **Due today** section names those tasks a few lines further down.
        VStack(alignment: .leading, spacing: 0) {
            // **On the phone, notes still coming from iCloud are named here** (build 261). Since
            // 261 the app no longer waits for them at launch, so for a moment after a start the
            // lists below can be short; the Mac says so at the foot of its sidebar, and the phone
            // has no sidebar. A read failure must never look like an absence (build 100).
            if isPhone, let warning = model.vaultWarning {
                VaultWarningBar(text: warning) { model.fetchMissingNotes() }
                    .padding(.bottom, Theme.tight)
            }
            // **Close the day sits beside the date, not in the window's toolbar.** A control
            // that governs a column belongs in that column next to its own name (build 167),
            // and the date row build 220 put here is that name. It costs no new furniture: the
            // right half of that row was empty.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // The date keeps its width first, so what gives way is the buttons' words and
                // never the date breaking over two lines (build 138).
                Text(today.date()?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? today.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                // **Start the day and Close the day are a pair** (build 233), so they sit side by
                // side. Symbols only, on every screen (build 247): he asked for the words to go.
                // Their names stay as the spoken title and the Mac's tooltip (build 159).
                dayButtons
            }
            .padding(.horizontal, Theme.gutter + 6)
            .padding(.bottom, Theme.tight)
            // **Now and Then, the day's plan in two short lines** (build 266), outside the
            // `List` for the same reason the date is (build 220). Nothing at all on a day with
            // no plan, or once the last block is over, so Today is then as short as before.
            NowAndNextLines()
            // **The goal for this week, one line under the date** (build 251), outside the
            // `List` for the same reason the date is (build 220). Nothing at all when no goal is
            // written: an empty line asking for one every morning would be a nag, and the week
            // screen is where it is written. **Start the day** draws the same line (build 265),
            // so it is one shared view, `WeekGoalLine`.
            if let weekGoal = model.weekGoal(for: .current()) {
                WeekGoalLine(goal: weekGoal, identifier: "today.weekGoal")
                    .padding(.horizontal, Theme.gutter + 6)
                    .padding(.bottom, Theme.tight)
            }
            List(selection: model.noteSelection) {
                if model.showsCalendarEvents {
                    Section {
                        // **The message is never folded away.** With Calendar access off, the
                        // body is the only thing that says why there are no events, and hiding a
                        // reason behind a chevron is build 100's fault in a new place.
                        if !calendarFolded.wrappedValue || model.calendarAccessGranted == false {
                            CalendarEventRows(date: today, compact: true)
                        }
                    } header: {
                        FoldButton(isOpen: calendarOpen, accessibilityName: "Calendar") {
                            SectionLabel(title: "Calendar",
                                         count: model.events(on: today).count,
                                         systemImage: SidebarSection.calendar.systemImage,
                                         tint: SidebarSection.calendar.tint)
                        }
                    }
                }
                Section {
                    if !fromTodayNote.isEmpty {
                        rows(fromTodayNote)
                    }
                } header: {
                    HStack(spacing: 8) {
                        // No symbol on the heading: the button beside it already carries the
                        // calendar, and two of one symbol in a row says nothing twice.
                        SectionLabel(title: "Today's note")
                        HeaderActionButton(title: model.todayNote == nil ? "Create" : "Open",
                                           spokenTitle: model.todayNote == nil
                                                ? "Create today's note" : "Open today's note",
                                           systemImage: "calendar",
                                           tint: ParaKind.daily.tint) {
                            model.openDailyNote(for: today)
                        }
                    }
                    // A `List` uppercases a section header's text for us, which would leave the
                    // button saying CREATE. `SectionLabel` uppercases its own words, so the
                    // heading is unchanged and only the button reads as an ordinary word.
                    .textCase(nil)
                }
                if !nextActions.isEmpty {
                    Section("Next actions") { rows(nextActions) }
                }
                if !overdue.isEmpty {
                    Section {
                        rows(overdue)
                    } header: {
                        // A `WrappingHStack`, never a plain one: a heading and two buttons in a
                        // narrow middle column would squeeze until the words broke mid-word
                        // (build 138). The buttons govern this section, so they belong in its
                        // own header rather than the window's toolbar (build 167), and
                        // `.textCase(nil)` keeps a `List` from shouting them (build 214).
                        WrappingHStack(spacing: 8, lineSpacing: 6) {
                            SectionLabel(title: "Overdue", count: overdue.count)
                            // **The Inbox's own two symbols, not new ones.** `InboxQuadrant`
                            // has drawn `sun.max` for today and `sunrise` for tomorrow since
                            // build 215, with the words beside them, so these are already
                            // learnt — and two screens that set a date must not use different
                            // pictures for it (build 168). The words live on as the spoken
                            // label and the Mac's tooltip (build 159).
                            HeaderActionButton(spokenTitle: "Move every overdue task to today",
                                               systemImage: "sun.max",
                                               tint: ParaKind.daily.tint) {
                                model.moveTasks(overdue, to: today)
                            }
                            HeaderActionButton(spokenTitle: "Move every overdue task to tomorrow",
                                               systemImage: "sunrise",
                                               tint: ParaKind.daily.tint) {
                                model.moveTasks(overdue, to: today.adding(days: 1))
                            }
                        }
                        .textCase(nil)
                    }
                }
                Section("Due today") {
                    if dueToday.isEmpty {
                        Text(overdue.isEmpty && nextActions.isEmpty
                             ? "Nothing is due today. Give a task a date, or pick a next action in a project."
                             : "Nothing else is due today.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        rows(dueToday)
                    }
                }
                if !important.isEmpty {
                    Section("Important, no date") { rows(important) }
                }
            }
        }
        .task(id: today) { await model.loadEvents(for: today) }
    }

    /// `FoldButton` asks whether the box is **open**; the stored value says whether it is
    /// folded, so the two are the same question read the other way round.
    private var calendarOpen: Binding<Bool> {
        Binding(get: { !calendarFolded.wrappedValue },
                set: { calendarFolded.wrappedValue = !$0 })
    }

    private func rows(_ refs: [TaskRef]) -> some View {
        ForEach(refs) { ref in
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                .tag(ref.notePath)
        }
    }

    /// The morning and evening buttons, symbols only.
    private var dayButtons: some View {
        HStack(spacing: 6) {
            HeaderActionButton(title: nil,
                               spokenTitle: "Start the day: pick the actions that matter most and put them in today's plan",
                               systemImage: StartDayView.symbol,
                               tint: Theme.morningTint,
                               strong: true) {
                model.activeSheet = .startDay
            }
            .accessibilityIdentifier("today.startDay")
            HeaderActionButton(title: nil,
                               spokenTitle: "Close the day: what you finished, what did not happen, and one line about it",
                               systemImage: CloseDayView.symbol,
                               tint: Theme.eveningTint) {
                model.activeSheet = .closeDay
            }
            .accessibilityIdentifier("today.closeDay")
        }
        .fixedSize()
    }
}

/// **Now and Then** (build 266): the block of today's plan you are in, and the one after it, as
/// two short lines under the date. **Now** carries a small clock button that starts the focus
/// timer on that block; **Then** has no button. His words, from the plan page: **Then**, not
/// "Next", because **Next actions** a few lines lower already means the `#next` task, and one
/// word with two meanings on one screen is build 176's fault. And **two lines**, not one.
///
/// Plan blocks only, read through `model.planBlocks(for:)`, which never writes a file. Which
/// block is now and which comes next is decided in Core (`NowAndNext`, tested), so the Mac
/// widget can name the same block (build 280). In this file because `HeaderActionButton` is
/// private to it.
private struct NowAndNextLines: View {
    @EnvironmentObject private var model: AppModel
    /// False where no focus bar is drawn: the clock button is then left out, because a clock
    /// started where its bar cannot be seen would run unseen (build 256).
    @Environment(\.focusBarShown) private var focusBarShown

    var body: some View {
        // `.everyMinute`, never a sleep loop like `NowLine`'s: the lines change on the minute a
        // block starts or ends, not up to 59 seconds late. The day is read from the timeline's
        // own date, so at midnight the lines move on to the new day's plan by themselves.
        TimelineView(.everyMinute) { context in
            lines(current(at: context.date), on: DateOnly(context.date))
        }
    }

    /// A plain function, never worked out inside the view builder (build 58).
    private func current(at date: Date) -> NowAndNext {
        NowAndNext(blocks: model.planBlocks(for: DateOnly(date)),
                   minute: NowAndNext.minute(of: date))
    }

    /// Nothing at all when there is nothing to say: no plan today, or the last block is over.
    /// A note still coming from iCloud reads as no plan here; the vault warning on **Today**
    /// (phone) and at the foot of the sidebar (Mac) already says why (build 261).
    /// `day` is the plan's own day, the one the lines were read from, handed on to the clock
    /// button so the block's task is looked for on that day (build 267).
    @ViewBuilder
    private func lines(_ state: NowAndNext, on day: DateOnly) -> some View {
        if !state.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                if let now = state.now {
                    nowRow(now, on: day)
                }
                if let next = state.next {
                    thenRow(next)
                }
            }
            .padding(.horizontal, Theme.gutter + 6)
            .padding(.bottom, Theme.tight)
        }
    }

    /// **Now 09:30 – 11:00 Write the offer**, and the clock button on the right. The word and
    /// the time keep their width; only the title gives way in a narrow column (build 138).
    private func nowRow(_ block: PlanBlock, on day: DateOnly) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // The words are one element with one sentence, so both platforms read them the same
            // (build 253's shape). The button beside them keeps its own.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Now")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.planBlockTint)
                    .fixedSize()
                Text(block.timeText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(block.title)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }
            .font(.caption)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.nowWords(block))
            .accessibilityIdentifier("today.now")
            Spacer(minLength: 6)
            nowControl(for: block, on: day)
        }
    }

    /// **Then 11:00 Call Anna**, all in grey, and no button: it is only what comes after.
    private func thenRow(_ block: PlanBlock) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Then")
                .fontWeight(.semibold)
                .fixedSize()
            Text(block.startText)
                .monospacedDigit()
                .fixedSize()
            Text(block.title)
                .lineLimit(1)
                .layoutPriority(-1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.thenWords(block))
        .accessibilityIdentifier("today.next")
    }

    /// The clock button, or — while the focus timer already runs on this block — a small dot in
    /// its place: orange while it runs, grey while paused. **Never a button that does nothing**
    /// (build 175). The clock is matched to the block by name, the way **Planned and worked**
    /// matches them (build 259), so a clock started on the task the block was made from counts.
    /// The button goes through the same `startFocus(onBlock:on:)` as the block's menu in **Plan
    /// the day**, so one rule decides in both places whether the clock can tick a task off
    /// (builds 168, 267).
    @ViewBuilder
    private func nowControl(for block: PlanBlock, on day: DateOnly) -> some View {
        if let session = model.focus, NowAndNext.sameName(session.title, block.title) {
            Circle()
                .fill(session.isPaused ? Color.secondary : Theme.planBlockTint)
                .frame(width: 7, height: 7)
                .accessibilityElement()
                .accessibilityLabel(Self.runningWords(session))
                .accessibilityIdentifier("today.now.running")
                .help(Self.runningWords(session))
        } else if focusBarShown {
            // `timer`, the symbol **Focus on this** already has on every menu.
            HeaderActionButton(spokenTitle: "Start the focus timer on \(block.title)",
                               systemImage: "timer",
                               tint: Theme.planBlockTint) {
                model.startFocus(onBlock: block, on: day)
            }
            .fixedSize()
            .accessibilityIdentifier("today.now.focus")
        }
    }

    private static func nowWords(_ block: PlanBlock) -> String {
        "Now: \(block.startText) to \(block.endText), \(block.title)"
    }

    private static func thenWords(_ block: PlanBlock) -> String {
        "Then: \(block.startText), \(block.title)"
    }

    private static func runningWords(_ session: FocusSession) -> String {
        session.isPaused ? "The focus timer is on this, paused" : "The focus timer is on this"
    }
}

/// A short button beside a section's own name, in the shape the header controls elsewhere
/// already have (build 167: a control that governs a section belongs in that section's
/// header, not in the window's toolbar).
///
/// It carries as few words as the heading beside it allows — one where the heading already
/// carries the noun (**Create** under *Today's note*), two or three where it has to say what
/// it will do (**Move to tomorrow** under *Overdue*). The whole sentence is still said out
/// loud and shown as the Mac's tooltip — build 159's rule: a control that shrinks hands its
/// words to the row it sits in, it does not lose them.
private struct HeaderActionButton: View {
    /// Nil for a button that is only its symbol. One of `title` and `systemImage` is always
    /// given; a button with neither would be an invisible press.
    var title: String?
    let spokenTitle: String
    /// Optional: two buttons side by side with one symbol between them would be two icons
    /// that look alike, which is usually a sign one of them should not be there (build 154).
    /// The words already say where the tasks are going, so the pair over **Overdue** has none.
    var systemImage: String?
    let tint: Color
    /// A full-strength border and bolder words, for the one button on a row that should stand
    /// out (**Start the day**, build 241). Still no fill: a tinted fill means "this is on"
    /// in build 142's two-state language, and this is an action, not a state.
    var strong = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.caption.weight(strong ? .bold : .semibold))
                .lineLimit(1)
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .overlay(Capsule().strokeBorder(tint.opacity(strong ? 1 : 0.55),
                                                lineWidth: strong ? 1.5 : 1))
                // The tap area is the label, so the padding goes inside it (build 186).
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenTitle)
        .help(spokenTitle)
    }

    /// Views only, so the `@ViewBuilder` rule holds (build 58). Nothing hangs off this
    /// button, so an `if` changing the subtree's identity costs nothing here — unlike the
    /// popovers build 202 had to keep still.
    @ViewBuilder private var label: some View {
        if let title, let systemImage {
            Label(title, systemImage: systemImage)
        } else if let title {
            Text(title)
        } else if let systemImage {
            Image(systemName: systemImage)
        }
    }
}
