import SwiftUI
import UniformTypeIdentifiers
import ParagonCore

extension UTType {
    /// A task dragged inside the app (between notes, onto a day).
    static let amsParaTask = UTType(exportedAs: "com.schabbauer.amspara.task")
}

/// What a dragged task carries: enough to find it again in its note.
struct TaskTransfer: Codable, Transferable {
    var notePath: String
    var lineIndex: Int
    var title: String
    /// Set when a whole note was dragged rather than a task in it: the Map drags its boxes,
    /// and every task drop target ignores those instead of guessing at a task.
    var isNote: Bool?

    init(_ ref: TaskRef) {
        notePath = ref.notePath
        lineIndex = ref.task.lineIndex
        title = ref.task.title
    }

    init(note: Note) {
        notePath = note.relativePath
        lineIndex = -1
        title = note.displayTitle
        isNote = true
    }

    /// A drag that means nothing, for boxes on the Map that are not notes.
    static let nothing = TaskTransfer(note: Note(relativePath: "", kind: .resource))

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .amsParaTask)
    }
}

/// Makes a view accept a dropped task. The closure gets the task as it is in its note now.
struct TaskDropModifier: ViewModifier {
    @EnvironmentObject private var model: AppModel
    let perform: (TaskRef) -> Void
    @State private var targeted = false

    func body(content: Content) -> some View {
        content
            .background(targeted ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .dropDestination(for: TaskTransfer.self) { items, _ in
                guard let transfer = items.first, let ref = model.task(for: transfer) else { return false }
                perform(ref)
                return true
            } isTargeted: { targeted = $0 }
    }
}

extension View {
    func acceptsTaskDrop(_ perform: @escaping (TaskRef) -> Void) -> some View {
        modifier(TaskDropModifier(perform: perform))
    }
}

/// The right-click menu shared by every task row: reschedule, repeat, next action, time block, move.
struct TaskContextMenu: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    let showNote: Bool
    @Binding var pickingDate: Bool
    /// Opens **Who?** (build 279). The row owns the window, as it owns the date picker.
    @Binding var askingWho: Bool
    var onAddSubtask: (() -> Void)?
    var onRename: (() -> Void)?
    /// Handed in by the row, which can read where it is drawn; a context menu is built outside
    /// the row's own hierarchy (build 256).
    var offersFocus: Bool = true
    @AppStorage(TaskTimeSetting.key) private var useTaskTimes = true

    private var note: Note? { model.note(at: ref.notePath) }
    private var inboxPath: String { model.vault?.config.inboxFile ?? "Inbox.md" }

    /// The notes a task can be moved to: the active projects, then the areas with their
    /// sub-areas under them, in the same order as the sidebar lists.
    private func destinations(_ kind: ParaKind) -> [Note] {
        let listed = kind == .area ? model.index.areasInFamilyOrder() : model.notes.filter { $0.kind == kind }
        return listed.filter {
            !$0.isArchived && !$0.isEnded && $0.relativePath != ref.notePath
        }
    }

    /// Sub-areas read as "Mobility \u{203A} Yoga", so the menu is not a flat list of words.
    private func label(for note: Note) -> String {
        guard let parent = model.index.parentArea(of: note) else { return note.displayTitle }
        return "\(parent.displayTitle) \u{203A} \(note.displayTitle)"
    }
    private var isNext: Bool { ref.task.tags.contains(Note.nextActionTag) }

    private static let repeatChoices: [RepeatRule] = [
        RepeatRule(unit: .day), RepeatRule(unit: .week), RepeatRule(count: 2, unit: .week),
        RepeatRule(unit: .month), RepeatRule(count: 3, unit: .month), RepeatRule(unit: .year),
    ]

    var body: some View {
        if offersFocus, model.canFocus(on: ref) {
            // First in the menu, as in the drawing (build 256): start the clock on this task.
            Button {
                model.startFocus(on: ref)
            } label: {
                MarkLabel("Focus on this", "timer")
            }
            Divider()
        }
        Menu {
            Button("Today") { model.setDueDate(ref, .today()) }
            Button("Tomorrow") { model.setDueDate(ref, DateOnly.today().adding(days: 1)) }
            Button("Next Monday") { model.setDueDate(ref, Self.nextMonday()) }
            Button("In a week") { model.setDueDate(ref, DateOnly.today().adding(days: 7)) }
            Divider()
            Button("Pick a date…") { openWindow(.day) }
            if ref.task.dueDate != nil {
                Button("Remove date", role: .destructive) { model.setDueDate(ref, nil) }
            }
        } label: {
            MarkLabel("Reschedule", "calendar")
        }
        // Build 316: the day it must be finished by, besides the day he plans to do it.
        // Round 9: every line of this menu has its hand-drawn mark (only Focus on this had
        // one), and the two removals are red, as removals are everywhere else.
        Menu {
            Button("Pick a date…") { openWindow(.deadline) }
            Button("In a week") { model.setTaskDeadline(ref, DateOnly.today().adding(days: 7)) }
            if ref.task.deadline != nil {
                Button("Remove deadline", role: .destructive) { model.setTaskDeadline(ref, nil) }
            }
        } label: {
            MarkLabel("Deadline", "deadline")
        }
        if useTaskTimes {
            Menu {
                ForEach(TaskTime.choices, id: \.self) { value in
                    TickedChoice(title: TaskTime.label(value), chosen: ref.task.minutes == value) {
                        model.setMinutes(ref, value)
                    }
                }
                if ref.task.minutes != nil {
                    Divider()
                    Button("No time") { model.setMinutes(ref, nil) }
                }
            } label: {
                MarkLabel("How long", "hourglass")
            }
        }
        // Build 279: a line he has handed to somebody else. On a line that already waits the
        // item reads the same and the window starts on the current person, so asking again
        // who it is changes the name; the second item takes the line back out of the list.
        if !ref.task.isDone {
            Button { askingWho = true } label: { MarkLabel("Waiting for…", "person.crop.circle") }
            if ref.task.isWaiting {
                Button { model.stopWaiting(ref) } label: { MarkLabel("Not waiting any more", "arrow.turn.left.up") }
            }
        }
        Menu {
            TickedChoice(title: "Does not repeat", chosen: ref.task.repeatRule == nil) { model.setRepeat(ref, nil) }
            Divider()
            ForEach(Self.repeatChoices, id: \.description) { rule in
                TickedChoice(title: rule.label, chosen: isChosen(rule)) { model.setRepeat(ref, keepingCount(rule)) }
            }
            // Build 316: chosen weekdays, the month's last day, and counting from the tick.
            Divider()
            TickedChoice(title: weekdaysTitle, chosen: ref.task.repeatRule?.weekdays.isEmpty == false) {
                openWindow(.repeats)
            }
            TickedChoice(title: "Last day of the month", chosen: ref.task.repeatRule?.monthEnd == true) {
                model.setRepeat(ref, .lastDayOfMonth)
            }
            Button(otherTitle) { openWindow(.repeats) }
            if let now = ref.task.repeatRule, now.canCountFromDone {
                Divider()
                TickedChoice(title: "Count from the day I finish it", chosen: now.afterDone) {
                    model.setRepeat(ref, RepeatRule(count: now.count, unit: now.unit, afterDone: !now.afterDone))
                }
            }
        } label: {
            MarkLabel("Repeat", "repeat")
        }
        if note?.kind == .project, !ref.task.isSubtask {
            if isNext {
                Button { model.clearNextAction(ref) } label: { MarkLabel("Clear next action", "bookmark") }
            } else if !ref.task.isWaiting {
                // Build 279: a waiting line is never the next thing, so marking one would take
                // `#next` off the project's real next action and put it where nothing reads it.
                Button { model.makeNextAction(ref) } label: { MarkLabel("Make this the next action", "bookmark") }
            }
        }
        Button { model.blockTime(for: ref) } label: { MarkLabel("Block time for this…", "calendar.badge.clock") }
        if !ref.task.isSubtask {
            Menu {
                if ref.notePath != inboxPath {
                    Button("Inbox") { model.moveTask(ref, to: inboxPath) }
                    Divider()
                }
                ForEach(destinations(.project)) { note in
                    Button(note.displayTitle) { model.moveTask(ref, to: note.relativePath) }
                }
                if !destinations(.project).isEmpty, !destinations(.area).isEmpty {
                    Divider()
                }
                ForEach(destinations(.area)) { note in
                    Button(label(for: note)) { model.moveTask(ref, to: note.relativePath) }
                }
            } label: {
                MarkLabel("Move to", "folder")
            }
        }
        if let onRename {
            Button(action: onRename) { MarkLabel("Rename…", "pencil") }
        }
        if let onAddSubtask {
            Button(action: onAddSubtask) { MarkLabel("Add subtask…", "list.bullet.indent") }
        }
        if showNote, let note {
            Divider()
            Button { model.show(note) } label: { MarkLabel("Open \(note.displayTitle)", "arrow.up.right") }
        }
    }

    /// Opens the task's date window on one of its pages (build 316).
    private func openWindow(_ tab: TaskWindowTab) {
        TaskWindowStart.ask(for: tab, of: ref)
        pickingDate = true
    }

    /// A menu choice is the chosen one whether or not the rule counts from the tick.
    private func isChosen(_ rule: RepeatRule) -> Bool {
        guard let now = ref.task.repeatRule, now.canCountFromDone else { return false }
        return now.count == rule.count && now.unit == rule.unit
    }

    /// Another length from the menu keeps **Count from the day I finish it** as it was.
    private func keepingCount(_ rule: RepeatRule) -> RepeatRule {
        let counts = ref.task.repeatRule?.afterDone ?? false
        return RepeatRule(count: rule.count, unit: rule.unit, afterDone: counts)
    }

    /// "On weekdays…", or the chosen days when there are some ("Every Mon, Wed, Fri…").
    private var weekdaysTitle: String {
        guard let now = ref.task.repeatRule, !now.weekdays.isEmpty else { return "On weekdays\u{2026}" }
        return now.label + "\u{2026}"
    }

    /// "Other…", or the rule's own words when it is none of the six ("Every 10 days…").
    private var otherTitle: String {
        guard let now = ref.task.repeatRule, now.canCountFromDone,
              !Self.repeatChoices.contains(where: { $0.count == now.count && $0.unit == now.unit }) else {
            return "Other\u{2026}"
        }
        return RepeatRule(count: now.count, unit: now.unit).label + "\u{2026}"
    }

    static func nextMonday(calendar: Calendar = .current) -> DateOnly {
        var day = DateOnly.today().adding(days: 1)
        for _ in 0..<7 {
            if let date = day.date(calendar: calendar), calendar.component(.weekday, from: date) == 2 { return day }
            day = day.adding(days: 1)
        }
        return day
    }
}

/// A small date picker shown from "Pick a date…".
///
/// **Build 277: it has an At line** — a field for the time of day, four quick times and **No
/// time of day** — and **Set** writes the date and the time together (`AppModel.setDue`). This is
/// the only date window that offers a time: a deadline, a goal's target and the others choose a
/// plain date. **No date** takes the date and the time off; **No time of day** (in the window)
/// keeps the date. It is not the **No time** in **How long**, which takes away the task's length.
///
/// **Build 316: three pages** — **Date** (the day he plans to do it, as before), **Deadline**
/// (the day it must be finished by; a plain date, **Remove deadline** clears it) and **Repeat**
/// (`RepeatChoiceView`). Apple's segmented control at the top changes the page; each page
/// writes only its own thing, with its own **Save** (round 9: one word, one colour and one
/// height for the three pages). It opens on **Date** unless the task menu asked
/// for another page (`TaskWindowStart`).
struct TaskDatePicker: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var isPresented: Bool
    @State private var tab: TaskWindowTab
    /// Round 9 (build 316): the one colour of the window. The Inbox hands in its own; every
    /// other list leaves it, and the window takes the colour of the note the task lives in.
    var screenTint: Color? = nil

    init(ref: TaskRef, isPresented: Binding<Bool>, tint: Color? = nil) {
        self.ref = ref
        self._isPresented = isPresented
        self.screenTint = tint
        self._tab = State(initialValue: TaskWindowStart.tab(for: ref))
    }

    private var tint: Color {
        screenTint ?? model.note(at: ref.notePath)?.tint ?? Theme.fallbackTint
    }

    var body: some View {
        page
            // Build 318: Date, Deadline and Repeat fade into each other (0.2 s).
            .animation(Motion.page, value: tab)
            .onAppear { TaskWindowStart.forget() }
            .onDisappear { TaskWindowStart.forget() }
    }

    @ViewBuilder
    private var page: some View {
        switch tab {
        case .day:
            DateTimeChoiceView(current: ref.task.dueDate,
                               time: ref.task.dueTime,
                               clearTitle: ref.task.dueDate == nil ? nil : "No date",
                               cancel: { isPresented = false },
                               header: AnyView(TaskWindowTabs(tab: $tab)),
                               confirmTitle: "Save", tint: tint,
                               sheetHeight: TaskWindowHeight.phone) { chosenDate, chosenTime in
                model.setDue(ref, date: chosenDate, time: chosenTime)
                isPresented = false
            }
            .id(TaskWindowTab.day)
        case .deadline:
            DateTimeChoiceView(current: ref.task.deadline ?? ref.task.dueDate,
                               offersTime: false,
                               clearTitle: ref.task.deadline == nil ? nil : "Remove deadline",
                               cancel: { isPresented = false },
                               title: "Deadline",
                               header: AnyView(TaskWindowTabs(tab: $tab, hint: Self.deadlineHint)),
                               confirmTitle: "Save", tint: tint,
                               sheetHeight: TaskWindowHeight.phone) { chosenDate, _ in
                model.setTaskDeadline(ref, chosenDate)
                isPresented = false
            }
            .id(TaskWindowTab.deadline)
        case .repeats:
            RepeatChoiceView(ref: ref, tab: $tab, tint: tint, sheetHeight: TaskWindowHeight.phone,
                             close: { isPresented = false })
                .id(TaskWindowTab.repeats)
        }
    }

    static let deadlineHint = "The day it must be finished by. It stays where it is when you move the task to another day."
}

/// The switch in **Settings › Tasks** (build 248). His own ask: task times must be something he
/// can turn off. Off, no row shows a time and nothing asks for one; the `~45m` already written
/// in a note stays there untouched.
enum TaskTimeSetting {
    static let key = "useTaskTimes"
}

/// Settings › Tasks › **Working day ends** (build 249), minutes since midnight. 16:00 was his
/// answer. A plain enum, not a static on the main-actor `AppModel`, so a view's
/// `@AppStorage` can name it from anywhere.
enum WorkdaySetting {
    static let key = "workdayEndMinutes"
    static let defaultEnd = 16 * 60
}

/// How long a task takes, on the right of a task row (build 248): "45 min" when it has a time,
/// a dashed **time?** when it has none. Pressing it opens the choices.
///
/// Build 142's two states: set is a solid border, not set is grey and dashed. The popover is on
/// this button, never a second one on the row (the row already carries the date popover), and
/// its help tag goes inside the label so it does not cover the choices (build 202).
struct TaskTimeButton: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    let tint: Color
    /// False where no timer bar is drawn (build 256).
    var offersFocus: Bool = true
    @State private var choosing = false

    private var spoken: String {
        guard let minutes = ref.task.minutes else { return "Set how long this takes" }
        return "Takes " + TaskTime.label(minutes)
    }

    /// Focus on this for the list, or nil where it is not offered. A function, not a ternary
    /// with a closure in one arm (builds 152, 154).
    private func focusAction() -> (() -> Void)? {
        guard offersFocus, model.canFocus(on: ref) else { return nil }
        return {
            choosing = false
            model.startFocus(on: ref)
        }
    }

    var body: some View {
        Button { choosing = true } label: {
            Group {
                if let minutes = ref.task.minutes {
                    Text(TaskTime.label(minutes))
                        .fontWeight(.medium)
                        .rowTint(Color.primary)
                } else {
                    Text("How long?")
                        .rowTint(Color.secondary)
                }
            }
            .font(Txt.label)
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(
                Capsule().strokeBorder(Color.secondary.opacity(ref.task.minutes == nil ? 0.55 : 0.7),
                                       style: StrokeStyle(lineWidth: 1, dash: ref.task.minutes == nil ? [3, 2] : []))
            )
            .contentShape(Capsule())
            .helpWhenClosed("How long this task takes", open: choosing)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(Text(spoken))
        .accessibilityIdentifier("task.time.\(ref.task.title)")
        .popover(isPresented: $choosing) {
            TaskTimeChoices(ref: ref, tint: tint,
                            done: { choosing = false },
                            focus: focusAction())
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// The choices behind a task's time button: the eight times, and **No time** when one is set.
struct TaskTimeChoices: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    let tint: Color
    let done: () -> Void
    /// **Focus on this** under the times (build 256), from a task row's time button only: the
    /// drawing put it on the right-click menu, and an action only a right-click reveals is one
    /// nobody finds (build 74). Start the day's question about a time leaves it out.
    var focus: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How long does \u{201C}\(ref.task.title)\u{201D} take?")
                .font(Txt.value)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ForEach(TaskTime.choices, id: \.self) { value in
                    PickChip(title: TaskTime.label(value), isOn: ref.task.minutes == value, tint: tint) {
                        model.setMinutes(ref, value)
                        done()
                    }
                    .accessibilityIdentifier("time.choice.\(value)")
                }
            }
            if ref.task.minutes != nil {
                Button("No time") {
                    model.setMinutes(ref, nil)
                    done()
                }
                .font(Txt.label)
            }
            if let focus, model.canFocus(on: ref) {
                Divider()
                Button(action: focus) {
                    MarkLabel("Focus on this", "timer", text: .body)
                        .font(Txt.value.weight(.semibold))
                        .foregroundStyle(Theme.planBlockTint.ink)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("focus.start")
                .help("Start a clock on this task. When you stop it, the time goes into today's note under Worked.")
            }
        }
        .padding(14)
        .frame(width: 270, alignment: .leading)
        .focusEffectDisabled()
    }
}

/// One choice in a menu of several, the chosen one with the hand-drawn tick. A menu draws
/// only words and images, so the tick is the label's icon rather than a typed "✓" in the
/// title (premium review, round 5).
private struct TickedChoice: View {
    let title: String
    let chosen: Bool
    let action: () -> Void

    var body: some View {
        if chosen {
            Button(action: action) {
                Label {
                    Text(title)
                } icon: {
                    MarkImage("checkmark")
                }
            }
            .accessibilityAddTraits(.isSelected)
        } else {
            Button(title, action: action)
        }
    }
}
