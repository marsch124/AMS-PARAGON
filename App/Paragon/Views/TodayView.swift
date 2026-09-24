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
            Text(today.date()?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? today.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.gutter + 6)
                .padding(.bottom, Theme.tight)
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
                            HeaderActionButton(title: "Move to today",
                                               spokenTitle: "Move every overdue task to today",
                                               tint: ParaKind.daily.tint) {
                                model.moveTasks(overdue, to: today)
                            }
                            HeaderActionButton(title: "Move to tomorrow",
                                               spokenTitle: "Move every overdue task to tomorrow",
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
    let title: String
    let spokenTitle: String
    /// Optional: two buttons side by side with one symbol between them would be two icons
    /// that look alike, which is usually a sign one of them should not be there (build 154).
    /// The words already say where the tasks are going, so the pair over **Overdue** has none.
    var systemImage: String?
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
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
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}
