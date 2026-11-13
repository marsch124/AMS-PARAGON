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

/// Which page the task's date window opens on. The task menu sets it just before it asks the
/// row to open the window (**Deadline › Pick a date…**, **Repeat › On weekdays…**); the window
/// reads it once and puts it back to **Date**, which is what every other way in gets.
@MainActor
enum TaskWindowStart {
    static var tab: TaskWindowTab = .day
}

/// **Date · Deadline · Repeat** at the top of a task's date window.
struct TaskWindowTabs: View {
    @Binding var tab: TaskWindowTab
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(TaskWindowTab.allCases, id: \.self) { one in
                    PickChip(title: one.rawValue, isOn: tab == one, tint: Theme.fallbackTint) { tab = one }
                        .accessibilityIdentifier("task.window.\(one.rawValue.lowercased())")
                }
                Spacer(minLength: 0)
            }
            if let hint {
                Text(hint)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The **Repeat** page of a task's date window: does not repeat, every N days, weeks, months or
/// years, on chosen weekdays, or the last day of the month — and **Count from the day I finish
/// it** for the every-N rules. Nothing is written until **Save**.
struct RepeatChoiceView: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var tab: TaskWindowTab
    let close: () -> Void

    private enum Kind: String, CaseIterable {
        case none = "Does not repeat"
        case every = "Every\u{2026}"
        case days = "On weekdays"
        case monthEnd = "Last day of the month"
    }

    @State private var kind: Kind = .none
    @State private var countText = "1"
    @State private var unit: RepeatRule.Unit = .week
    @State private var days: Set<Int> = []
    @State private var afterDone = false
    @State private var phoneHeight: CGFloat = 0

    private var tint: Color { Theme.fallbackTint }
    private var count: Int { min(max(Int(countText.trimmingCharacters(in: .whitespaces)) ?? 1, 1), 999) }

    private static let quick: [RepeatRule] = [
        RepeatRule(unit: .day), RepeatRule(unit: .week), RepeatRule(count: 2, unit: .week),
        RepeatRule(unit: .month), RepeatRule(count: 3, unit: .month), RepeatRule(unit: .year),
    ]

    /// What **Save** will write, or nil for "does not repeat".
    private var rule: RepeatRule? {
        switch kind {
        case .none: return nil
        case .every: return RepeatRule(count: count, unit: unit, afterDone: afterDone)
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
                PickChip(title: one.rawValue, isOn: kind == one, tint: tint) { choose(one) }
                    .accessibilityIdentifier("repeat.kind.\(one)")
            }
        }
        if kind == .every {
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ForEach(Self.quick, id: \.description) { one in
                    PickChip(title: one.label, isOn: count == one.count && unit == one.unit, tint: tint) {
                        countText = String(one.count)
                        unit = one.unit
                    }
                }
            }
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                Text("Every")
                    .font(Txt.value.weight(.semibold))
                TextField("1", text: $countText)
                    .modifier(DateFieldLook(isPhone: isPhone))
                    .font(Txt.value.monospacedDigit())
                    .frame(width: 52)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityIdentifier("repeat.count")
                unitChip("days", .day)
                unitChip("weeks", .week)
                unitChip("months", .month)
                unitChip("years", .year)
            }
            PickChip(title: "Count from the day I finish it", isOn: afterDone, tint: tint) { afterDone.toggle() }
                .accessibilityIdentifier("repeat.afterDone")
        }
        if kind == .days {
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    PickChip(title: RepeatRule.dayLabels[day - 1], isOn: days.contains(day), tint: tint) { toggle(day) }
                        .accessibilityIdentifier("repeat.day.\(day)")
                }
            }
            Button("Monday to Friday") { days = [1, 2, 3, 4, 5] }
                .font(Txt.label)
        }
        Text(explanation)
            .font(Txt.label)
            .foregroundStyle(.soft)
            .lineLimit(3, reservesSpace: true)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func unitChip(_ title: String, _ value: RepeatRule.Unit) -> some View {
        PickChip(title: title, isOn: unit == value, tint: tint) { unit = value }
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
                        .tint(Theme.fallbackTint.ink)
                        .accessibilityIdentifier("repeat.cancel")
                }
                RepeatSaveItem(save: save)
            }
        }
        .presentationDetents(phoneHeight > 0 ? [.height(max(phoneHeight + 64, 320)), .large] : [.large])
        .presentationBackground(Theme.canvas)
        .onAppear(perform: load)
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
            countText = String(now.count)
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
            .buttonStyle(.filled(Theme.fallbackTint))
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

/// A task's deadline on its row (build 316): a red flag and "3 days left", "Due today" or
/// "2 days late". The words turn red on the day itself and after it. A finished task keeps a
/// grey flag and the plain date.
struct DeadlineLabel: View {
    let task: TaskItem
    var today: DateOnly = .today()

    var body: some View {
        if let deadline = task.deadline {
            if task.isDone {
                MarkLabel(deadline.description, "flag", text: .footnote)
                    .accessibilityLabel("Deadline \(deadline.description)")
            } else {
                HStack(spacing: 3) {
                    MarkImage("flag", text: .footnote)
                        .rowTint(Color.red)
                    if TaskDeadline.isPressing(deadline, on: today) {
                        Text(TaskDeadline.words(until: deadline, from: today))
                            .rowTint(Color.red)
                    } else {
                        Text(TaskDeadline.words(until: deadline, from: today))
                    }
                }
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

    private var found: PlainDate? {
        guard let found = PlainDate.read(text, today: .today()), !found.isIgnored(by: ignored) else { return nil }
        return found
    }

    var body: some View {
        if let found {
            ReadChip(title: PlainDateChip.title(date: found.date, time: found.time),
                     markName: found.time == nil ? "calendar" : "clock",
                     tint: SidebarSection.calendar.tint,
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
