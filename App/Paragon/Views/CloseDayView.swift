import SwiftUI
import ParagonCore

/// The evening step: what you finished, what did not happen, and one line about the day.
///
/// He asked for it in the same breath as three other things — *"to make my day more efficient
/// and in harmony"* — and picked this shape from a drawing of three
/// (https://claude.ai/artifact/NrbS7bxiaBin21sLjwzvEg), shape **A**: a screen you open on
/// purpose, work down, and **finish**.
///
/// **Why not at the foot of Today** (shape B): builds 213, 214 and 219 were all about making
/// that screen shorter, and a new box on it would undo some of that. **Why not its own sidebar
/// row** (shape C): the phone's five tabs are full, so it would sit inside **Browse** — two taps
/// away, every evening.
///
/// It is a sheet, through the app's single `.sheet` (build 44), so it can never argue with
/// another one.
struct CloseDayView: View {
    @EnvironmentObject private var model: AppModel

    /// What he has written, loaded once from the note and written back only on **Done**.
    @State private var lookingBack = ""
    /// `onAppear` runs again when the sheet is re-laid-out, and reading the note a second time
    /// would throw away what he has typed since.
    @State private var loaded = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    private var day: DateOnly { DateOnly.today() }
    private var tint: Color { SidebarSection.review.tint }

    /// Still open and dated today or earlier. Undated tasks are deliberately left out: a task
    /// with no date was never promised to this day, so it did not "not happen".
    private var leftovers: [TaskRef] { model.index.openTasks(dueOnOrBefore: day) }

    private var tomorrow: DateOnly { day.adding(days: 1) }

    private var finished: [TaskRef] { model.index.tasksCompleted(on: day) }

    /// Tomorrow's list is the planner's own question for tomorrow (build 174) — the same list
    /// **Start the day** will show in the morning — **without today's leftovers**, which are
    /// drawn above with their own buttons. Pressing **Tomorrow** on one moves it down here.
    private var tomorrowActions: [TaskRef] {
        let left = Set(leftovers.map(\.id))
        return model.actionsForPlanning(on: tomorrow).filter { !left.contains($0.id) }
    }

    /// Everything dated tomorrow, then at most this many next actions: one per project would
    /// otherwise push the line about the day off the bottom of a phone (build 213's lesson).
    /// An action already marked **First** is always shown, so a mark can always be taken off.
    private let nextActionsShown = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
            Divider()
            ScrollView {
                // Build 237, his order: the three things to act on first — what was left over,
                // tomorrow, and the line about today — and what the day achieved at the foot,
                // where it can be read at leisure once the work is done.
                VStack(alignment: .leading, spacing: 18) {
                    if leftovers.isEmpty {
                        allClear
                    } else {
                        didNotHappen
                    }
                    tomorrowSection
                    lookingBackField
                    Divider()
                    whatYouDid
                }
                .padding(isPhone ? 14 : 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            SheetFooter(actionTitle: "Done", tint: tint, cancel: { close() }, act: { finish() })
                .padding(isPhone ? 14 : 20)
        }
        // One name the screen test can wait for: what it is really checking is that this view
        // builds at all, on both platforms (build 190). Accessibility only — nothing here takes
        // a press.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("closeDay.screen")
        .frame(minWidth: isPhone ? nil : 480)
        .frame(maxWidth: fillOnPhone, maxHeight: fillOnPhone, alignment: .topLeading)
        .onAppear {
            model.loadFirstPicks()
            guard !loaded else { return }
            lookingBack = model.lookingBack(for: day)
            loaded = true
        }
        .task { await model.loadEvents(for: tomorrow) }
    }

    /// Written out rather than a ternary with `nil` in one arm: `.infinity` is a member of
    /// `CGFloat`, not of `CGFloat?`, and there is no compiler here to settle it (build 199).
    private var fillOnPhone: CGFloat? {
        if isPhone { return CGFloat.infinity }
        return nil
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label("Close the day", systemImage: "moon")
                .font(.headline)
                .foregroundStyle(tint)
            Spacer(minLength: 0)
            Text(day.date()?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                 ?? day.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, isPhone ? 14 : 20)
        .padding(.vertical, 12)
    }

    /// **Build 236: be proud of the day** — his words. He chose the count and what the work
    /// served over every task by name: **Done** already lists the names, and a list of twelve
    /// lines reads as a report, while "Healthy body · 3" reads as a day that went somewhere.
    /// `NoteIndex.servedCounts(of:)` (Core, tested) decides the grouping.
    @ViewBuilder
    private var whatYouDid: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "What you did today")
            // The count once, as the green capsule it has been since build 223; the section
            // headings below carry their own counts, so the old row of two capsules would only
            // have repeated them (build 169).
            CountPill(text: pillText(finished.count, "finished today"),
                      systemImage: "checkmark.circle", tint: .green)
            if finished.isEmpty {
                Text("No task was ticked off today.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.index.servedCounts(of: finished)) { served in
                    ServedRow(served: served)
                }
            }
        }
    }

    /// Tomorrow's calendar, then what is waiting, each with a **First** mark. The mark only
    /// marks — his choice: no block is made, and **Start the day** shows the marked ones at the
    /// top in the morning. Stored in the vault (`FirstPicks`, Core), so a mark made on the phone
    /// tonight is on the Mac tomorrow.
    private var tomorrowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Two headings, his ask (build 239): "Tomorrow" alone did not say that the rows under
            // it were calendar events, and one heading over both the events and the actions
            // could only be true of one of them.
            if model.showsCalendarEvents {
                SectionLabel(title: "Tomorrow's calendar events · " + tomorrowText)
                CalendarEventRows(date: tomorrow, compact: true)
            }
            SectionLabel(title: "Waiting for tomorrow")
                .padding(.top, model.showsCalendarEvents ? 8 : 0)
            if tomorrowShown.isEmpty {
                Text("Nothing is waiting for tomorrow yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Press First on the left of what comes first. Start the day shows it at the top tomorrow morning.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(tomorrowShown) { ref in
                    // **First** in front of the row, larger (build 240): the tick circle came
                    // first before, and a press meant for the mark finished the task instead.
                    HStack(alignment: .top, spacing: 12) {
                        PickButton(isOn: model.firstPicks.isFirst(ref, on: tomorrow), tint: tint,
                                   onTitle: "First", offTitle: "First", large: true) {
                            model.toggleFirst(ref, on: tomorrow)
                        }
                        .accessibilityIdentifier("closeDay.first.\(ref.task.title)")
                        TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                    }
                }
                if tomorrowHidden > 0 {
                    Text(tomorrowHidden == 1 ? "…and 1 more next action." : "…and \(tomorrowHidden) more next actions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// "Thu 1 Oct", the same short form as the date at the top of the sheet.
    private var tomorrowText: String {
        tomorrow.date()?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            ?? tomorrow.description
    }

    /// Dated for tomorrow, and every marked one, always; then the first few next actions.
    private var tomorrowShown: [TaskRef] {
        let all = tomorrowActions
        let dated = all.filter { isForTomorrow($0) }
        let marked = all.filter { !isForTomorrow($0) && model.firstPicks.isFirst($0, on: tomorrow) }
        let others = all.filter { !isForTomorrow($0) && !model.firstPicks.isFirst($0, on: tomorrow) }
        return dated + marked + Array(others.prefix(nextActionsShown))
    }

    /// Dated tomorrow (or earlier and not a leftover). A next action dated next week is still
    /// only a next action here.
    private func isForTomorrow(_ ref: TaskRef) -> Bool {
        guard let due = ref.task.dueDate else { return false }
        return due <= tomorrow
    }

    private var tomorrowHidden: Int {
        max(0, tomorrowActions.count - tomorrowShown.count)
    }

    /// "1 task finished today", never "1 tasks".
    private func pillText(_ count: Int, _ tail: String) -> String {
        count == 1 ? "1 task \(tail)" : "\(count) tasks \(tail)"
    }

    /// Nothing open and dated is worth saying in words. An empty list with a heading over it
    /// reads as a screen that failed to load (build 100).
    private var allClear: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nothing was left over.")
                .font(.callout.weight(.semibold))
            Text("Everything with a date for today or earlier is done or dropped.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var didNotHappen: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Did not happen", count: leftovers.count)
            // Real `TaskRow`s: a tick here ticks the task in its own note, and the task menu and
            // the date popover come with it. Build 149's rule — reach for `TaskRow` for any list
            // of tasks, because a second one only repeats work and then drifts. Its `.draggable`
            // is safe: this is not a `List(selection:)` (builds 71 to 74).
            ForEach(leftovers) { ref in
                LeftoverRow(ref: ref, today: day, tint: tint)
            }
            if leftovers.count > 1 {
                Button("Move all \(leftovers.count) to tomorrow") {
                    model.moveTasks(leftovers, to: day.adding(days: 1))
                }
                .font(.caption)
                .padding(.top, 2)
            }
        }
    }

    private var lookingBackField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "How was today?")
            TextField("One line, if you feel like it", text: $lookingBack, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.35)))
            Text("Goes into today's daily note, under **Looking back**.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// **Done saves the line; Cancel does not.** The tick boxes and the Tomorrow buttons have
    /// already written their notes when they were pressed, so nothing there waits for this — the
    /// footer only decides the fate of the words in the field.
    private func finish() {
        model.saveLookingBack(lookingBack, for: day)
        close()
    }

    private func close() {
        model.activeSheet = nil
    }
}

/// One fact about the day as a capsule.
///
/// Its own small view rather than the review's `ReviewStat`: that one is built around a week's
/// report and its worries. **Start the day** (build 233) is its second user, so it is no longer
/// private to this file. If a third screen ever wants it, that is the moment to move it into
/// `Theme.swift` — the note build 214 left about `HeaderActionButton`.
struct CountPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.45)))
    }
}

/// One thing the day's finished tasks went towards, with how many.
///
/// The goal's own star or target and its gold (`ChainSymbol` / `ChainTint`, build 189), an
/// area's pink, or the note's own kind: the same pictures and colours the rest of the app uses
/// for the same things (build 168).
private struct ServedRow: View {
    @EnvironmentObject private var model: AppModel
    let served: ServedCount

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(served.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(tint)
                .lineLimit(2)
            Text(served.count == 1 ? "1 task" : "\(served.count) tasks")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var symbol: String {
        switch served.kind {
        case .goal: return ChainSymbol.forGoal(named: served.title, in: model.index)
        case .area: return ChainSymbol.area
        case .note(let kind): return SidebarSection.kind(kind).systemImage
        }
    }

    private var tint: Color {
        switch served.kind {
        case .goal: return ChainTint.forGoal(named: served.title, in: model.index)
        case .area: return ParaKind.area.tint
        case .note(let kind): return kind.tint
        }
    }
}

/// A task that did not happen, with **Tomorrow** and **Day…** beside it.
///
/// Its own view because **Day…** needs a popover of its own, and a popover is state that
/// belongs to one row (build 83's reason for `MapNodeBox`).
private struct LeftoverRow: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    let today: DateOnly
    let tint: Color
    @State private var choosingDay = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
            Button {
                model.moveTasks([ref], to: today.adding(days: 1))
            } label: {
                // The padding goes **inside** the label: a Button's tap area is its label, and
                // padding put outside only moves it (build 186).
                capsule("Tomorrow", colour: tint)
            }
            .buttonStyle(.plain)
            .help("Move this to tomorrow")
            Button {
                choosingDay = true
            } label: {
                capsule("Day…", colour: .secondary)
            }
            .buttonStyle(.plain)
            .help("Move this to another day")
            .popover(isPresented: $choosingDay) {
                DateChoiceView(current: today.adding(days: 1), cancel: { choosingDay = false }) { chosen in
                    choosingDay = false
                    if let chosen { model.moveTasks([ref], to: chosen) }
                }
                .padding()
                .frame(minWidth: 280)
            }
        }
    }

    private func capsule(_ title: String, colour: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(colour)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(colour.opacity(0.55), lineWidth: 1))
            .contentShape(Capsule())
    }
}
