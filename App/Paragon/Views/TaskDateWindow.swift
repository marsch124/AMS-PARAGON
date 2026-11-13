import SwiftUI
import ParagonCore

// Build 316 (premium review features-03, -13, -19): the parts of a task's date window that are
// new — its three pages (Date, Deadline, Repeat), the repeat page itself, the deadline's mark
// on a row, and the chip that shows a date read from plain words.

/// The three pages of a task's date window.
enum TaskWindowTab: String, CaseIterable {
    case day = "Date"
    case deadline = "Deadline"
    case repeats = "Repeat"
}

/// Which page the task's date window opens on. The task menu asks for a page just before it
/// asks the row to open the window (**Deadline › Pick a date…**, **Repeat › On weekdays…**).
///
/// **An asked-for page counts for that one task and for a moment only.** The window of
/// another task, and a window opened later (the menu's window never came up, or the row had
/// gone), open on **Date**, which is what every other way in gets. The window also forgets the
/// request when it appears and when it closes.
@MainActor
enum TaskWindowStart {
    private static var asked: (tab: TaskWindowTab, task: String, at: Date)?
    /// How long a request waits for its window, in seconds.
    static let patience: TimeInterval = 3

    static func ask(for tab: TaskWindowTab, of ref: TaskRef) {
        asked = tab == .day ? nil : (tab, ref.id, Date())
    }

    static func tab(for ref: TaskRef) -> TaskWindowTab {
        guard let asked, asked.task == ref.id, Date().timeIntervalSince(asked.at) < patience else { return .day }
        return asked.tab
    }

    static func forget() { asked = nil }
}

/// **Date · Deadline · Repeat** at the top of a task's date window.
///
/// Round 9 (build 316): Apple's segmented control over the whole width — it says "where am I",
/// and the capsules under it say "what do I choose". Before, the three pages were capsules too.
struct TaskWindowTabs: View {
    @Binding var tab: TaskWindowTab
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Page", selection: $tab) {
                ForEach(TaskWindowTab.allCases, id: \.self) { one in
                    Text(one.rawValue).tag(one)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("task.window.pages")
            if let hint {
                Text(hint)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The height of a task's date window on the iPhone (round 9, build 316): **one height for
/// its three pages**, so **Date · Deadline · Repeat** stay where they are under the finger.
/// It is the height the tallest page needs, the Date page with its **At** line, and it never
/// changes while the window is open. With very large text a page scrolls inside it, and the
/// window can be pulled up to the full height.
enum TaskWindowHeight {
    static let phone: CGFloat = 730
}

/// The **Repeat** page of a task's date window: does not repeat, every N days, weeks, months or
/// years, on chosen weekdays, or the last day of the month — and **Count from the day I finish
/// it** for the every-N rules. Nothing is written until **Save**.
///
/// Round 9 (build 316): **Every…** is one calm line — "Every", the number with its stepper,
/// and the unit in a menu — where 15 capsules stood in five rows.
struct RepeatChoiceView: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var tab: TaskWindowTab
    var tint: Color = Theme.fallbackTint
    /// The one height of the task's window on the iPhone, shared by its three pages.
    var sheetHeight: CGFloat? = nil
    let close: () -> Void

    private enum Kind: String, CaseIterable {
        case none = "Does not repeat"
        case every = "Every\u{2026}"
        case days = "On weekdays"
        case monthEnd = "Last day of the month"
    }

    @State private var kind: Kind = .none
    @State private var count = 1
    @State private var unit: RepeatRule.Unit = .week
    @State private var days: Set<Int> = []
    @State private var afterDone = false
    @State private var phoneHeight: CGFloat = 0

    /// What **Save** will write, or nil for "does not repeat".
    private var rule: RepeatRule? {
        switch kind {
        case .none: return nil
        case .every: return RepeatRule(count: RepeatEvery.clamped(count), unit: unit, afterDone: afterDone)
        case .days: return RepeatRule(weekdays: Array(days))
        case .monthEnd: return .lastDayOfMonth
        }
    }

    private var isPhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    var body: some View {
        #if os(iOS)
        if isPhone { phoneBody } else { deskBody }
        #else
        deskBody
        #endif
    }

    @ViewBuilder
    private var fields: some View {
        TaskWindowTabs(tab: $tab)
        WrappingHStack(spacing: 6, lineSpacing: 6) {
            ForEach(Kind.allCases, id: \.self) { one in
                PickChip(title: one.rawValue, isOn: kind == one, tint: tint, large: isPhone) { choose(one) }
                    .accessibilityIdentifier("repeat.kind.\(one)")
            }
        }
        if kind == .every {
            Divider()
            everyLine
            Toggle("Count from the day I finish it", isOn: $afterDone)
                .tint(tint.deep)
                .accessibilityIdentifier("repeat.afterDone")
        }
        if kind == .days {
            Divider()
            HStack(spacing: isPhone ? 6 : 3) {
                ForEach(1...7, id: \.self) { day in
                    PickChip(title: RepeatRule.dayLabels[day - 1], isOn: days.contains(day), tint: tint,
                             large: isPhone, fills: true) { toggle(day) }
                        .accessibilityIdentifier("repeat.day.\(day)")
                }
            }
            Button("Monday to Friday") { days = [1, 2, 3, 4, 5] }
                .font(isPhone ? Font.subheadline : Txt.label)
                .tint(tint.ink)
        }
        Text(explanation)
            .font(Txt.label)
            .foregroundStyle(.soft)
            .lineLimit(3, reservesSpace: true)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "Every [2] [- +] [weeks]": the number, Apple's stepper, and the unit in a menu.
    private var everyLine: some View {
        HStack(spacing: 10) {
            Text("Every")
                .font(Txt.value.weight(.semibold))
            Text("\(count)")
                .font(Txt.value.monospacedDigit())
                .frame(minWidth: 30)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
                .accessibilityIdentifier("repeat.count")
            Stepper("How many", value: $count, in: RepeatEvery.range)
                .labelsHidden()
                .accessibilityIdentifier("repeat.stepper")
            Picker("Unit", selection: $unit) {
                ForEach(RepeatEvery.units, id: \.self) { one in
                    Text(RepeatEvery.word(one, count: count)).tag(one)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(tint.ink)
            .fixedSize()
            .accessibilityIdentifier("repeat.unit")
            Spacer(minLength: 0)
        }
    }

    /// One plain sentence about what the choice does.
    private var explanation: String {
        guard let rule else { return "When you tick the task, nothing new is made." }
        if kind == .every && afterDone {
            return "\(rule.label): when you tick the task, the next one is counted from that day, not from the date it had."
        }
        return "\(rule.label): when you tick the task, the next one is made with its next date."
    }

    private var deskBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            fields
            HStack {
                Spacer()
                Button("Cancel", action: close)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repeat.cancel")
                Button("Save", action: save)
                    .buttonStyle(.filled(tint))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("repeat.save")
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear(perform: load)
    }

    #if os(iOS)
    private var phoneBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    fields
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .measureHeight($phoneHeight)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.canvas)
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: close)
                        .tint(tint.ink)
                        .accessibilityIdentifier("repeat.cancel")
                }
                RepeatSaveItem(tint: tint, save: save)
            }
        }
        .presentationDetents(detents)
        .presentationBackground(Theme.canvas)
        .onAppear(perform: load)
    }

    private var detents: Set<PresentationDetent> {
        if let sheetHeight { return [.height(sheetHeight), .large] }
        return phoneHeight > 0 ? [.height(max(phoneHeight + 64, 320)), .large] : [.large]
    }
    #endif

    private func load() {
        guard let now = ref.task.repeatRule else {
            kind = .none
            return
        }
        if now.monthEnd {
            kind = .monthEnd
        } else if !now.weekdays.isEmpty {
            kind = .days
            days = Set(now.weekdays)
        } else {
            kind = .every
            count = RepeatEvery.clamped(now.count)
            unit = now.unit
            afterDone = now.afterDone
        }
    }

    private func choose(_ one: Kind) {
        kind = one
        // On weekdays always has a day: the task's own, or today's.
        if one == .days, days.isEmpty {
            days = [DayWords.isoWeekday(ref.task.dueDate ?? .today())]
        }
    }

    /// The last chosen day cannot be taken away, so **Save** always has something to save.
    private func toggle(_ day: Int) {
        if days.contains(day) {
            if days.count > 1 { days.remove(day) }
        } else {
            days.insert(day)
        }
    }

    private func save() {
        model.setRepeat(ref, rule)
        close()
    }
}

#if os(iOS)
/// **Save** in the bar of the iPhone's repeat page: the app's own filled button.
struct RepeatSaveItem: ToolbarContent {
    var tint: Color = Theme.fallbackTint
    let save: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .confirmationAction) { button }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .confirmationAction) { button }
        }
    }

    private var button: some View {
        Button(action: save) { Text("Save").lineLimit(1).fixedSize() }
            .buttonStyle(.filled(tint))
            .accessibilityIdentifier("repeat.save")
    }
}
#endif

extension DayWords {
    /// 1 = Monday … 7 = Sunday.
    static func isoWeekday(_ day: DateOnly) -> Int {
        let calendar = WeekRef.calendar
        guard let date = day.date(calendar: calendar) else { return 1 }
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
}

/// One fact in the small line under a task (round 9, build 316): its mark, 5 points, its
/// words — always on one line. Only a fact that `shortens` (the project's name) may end in
/// "…" when the row is too narrow for it; every other fact keeps its whole width and moves to
/// the next line as one piece (`WrappingHStack`).
///
/// Before, the facts were `Label`s in one `HStack`: a narrow row squeezed each of them, so
/// "Every Mon, Wed, Fri" stood on three lines and a project's name was cut inside a word.
struct RowFact: View {
    let words: String
    let markName: String
    var shortens = false

    init(_ words: String, _ markName: String, shortens: Bool = false) {
        self.words = words
        self.markName = markName
        self.shortens = shortens
    }

    var body: some View {
        HStack(spacing: RowFact.markGap) {
            MarkImage(markName, text: .footnote)
            Text(words)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .fixedSize(horizontal: !shortens, vertical: true)
        .accessibilityElement(children: .combine)
    }

    /// Between a mark and its words.
    static let markGap: CGFloat = 5
    /// Between two facts on the line.
    static let gap: CGFloat = 12
}

/// A task's deadline on its row (build 316): the deadline's own red mark — a pennant on the
/// finish line, not the project's flag — and "3 days left", "Due today" or "2 days late". The
/// words turn red on the day itself and after it. A finished task keeps a grey mark and the
/// plain date.
struct DeadlineLabel: View {
    let task: TaskItem
    var today: DateOnly = .today()

    var body: some View {
        if let deadline = task.deadline {
            if task.isDone {
                RowFact(deadline.description, "deadline")
                    .accessibilityLabel("Deadline \(deadline.description)")
            } else {
                HStack(spacing: RowFact.markGap) {
                    MarkImage("deadline", text: .footnote)
                        .rowTint(Color.red)
                    if TaskDeadline.isPressing(deadline, on: today) {
                        Text(TaskDeadline.words(until: deadline, from: today))
                            .lineLimit(1)
                            .rowTint(Color.red)
                    } else {
                        Text(TaskDeadline.words(until: deadline, from: today))
                            .lineLimit(1)
                    }
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Deadline \(deadline.description), \(TaskDeadline.words(until: deadline, from: today))")
                .help("Deadline \(deadline.description)")
            }
        }
    }
}

/// Under an add field (the Inbox's, a note's **Add a task…**): the date read from plain words,
/// before the line is added. The **x** takes it away, and the words stay plain text.
///
/// `ignored` holds the words he took away. It only counts while the very same words are in the
/// field, so another date typed afterwards is read again.
struct PlainDateChip: View {
    let text: String
    @Binding var ignored: String?
    /// Round 9 (build 316): the colour of the screen the field is on (the Inbox's green, the
    /// note's own colour). It was the Calendar's purple everywhere.
    var tint: Color = SidebarSection.calendar.tint

    private var found: PlainDate? {
        guard let found = PlainDate.read(text, today: .today()), !found.isIgnored(by: ignored) else { return nil }
        return found
    }

    var body: some View {
        if let found {
            ReadChip(title: PlainDateChip.title(date: found.date, time: found.time),
                     markName: found.time == nil ? "calendar" : "clock",
                     tint: tint,
                     remove: { ignored = found.words })
                .accessibilityIdentifier("plainDate.chip")
        }
    }

    /// "Due today", "Due tomorrow 14:00", "Due Fri 2026-11-20".
    static func title(date: DateOnly, time: TimeOfDay?) -> String {
        let today = DateOnly.today()
        let day: String
        if date == today {
            day = "Due today"
        } else if date == today.adding(days: 1, calendar: WeekRef.calendar) {
            day = "Due tomorrow"
        } else if date == today.adding(days: -1, calendar: WeekRef.calendar) {
            day = "Was due yesterday"
        } else {
            day = "Due " + DayWords.withWeekday(date)
        }
        return time.map { day + " " + $0.description } ?? day
    }

    /// The line as it is saved: the words that were read become the date mark.
    static func line(_ text: String, ignoring ignored: String?) -> String {
        PlainDate.line(text, understoodOn: .today(), ignoring: ignored)
    }
}
