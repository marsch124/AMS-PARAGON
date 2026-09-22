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

        List(selection: model.noteSelection) {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text(today.date()?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? today.description)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    let open = overdue.count + dueToday.count
                    Text(open == 0 ? "Nothing due" : "\(open) due")
                        .font(.callout)
                        .foregroundStyle(overdue.isEmpty ? .secondary : Color.red)
                }
                .listRowSeparator(.hidden)
            }
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
                Button {
                    model.openDailyNote(for: today)
                } label: {
                    Label(model.todayNote == nil ? "Create today's note" : "Open today's note", systemImage: "calendar")
                        .foregroundStyle(ParaKind.daily.tint)
                }
                if !fromTodayNote.isEmpty {
                    rows(fromTodayNote)
                }
            }
            if !nextActions.isEmpty {
                Section("Next actions") { rows(nextActions) }
            }
            if !overdue.isEmpty {
                Section("Overdue") { rows(overdue) }
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
