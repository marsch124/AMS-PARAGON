import SwiftUI
import ParagonCore

/// **Start turns Today into picking** (build 335, his pick 3 of the picture of 17 November
/// 2026). Until 334 this file held `StartDayView`, a second page (a sheet) that listed Today's
/// tasks again with a **Pick** button on each. The page is gone: the Start button on Today's
/// band turns Today's own list into the picking list, and the pieces that list needs live here
/// — the dark strip, the morning card, the field for a new action, the row with its Pick in
/// front, and the foot with the plan button. `TodayView` puts them in place; the rules without
/// a screen are Core's `TodayPicking` (tested).
///
/// **It makes plan blocks, never Time Blocks** (build 147): a `TB:` line in the daily note that
/// stays in PARAGON. Whether a block is also in Apple Calendar is still his choice, per block,
/// on **Plan** (build 151).
enum StartDay {
    /// A cup, not a sunrise: `sunrise` already means **Tomorrow** on the Inbox's buttons and over
    /// **Overdue** (builds 215 and 224), and one symbol with two meanings is build 168's fault.
    static let symbol = "cup.and.saucer.fill"

    /// The explanation under the field (build 312: by itself the first three times).
    static func instructions(usesTaskTimes: Bool) -> String {
        if usesTaskTimes {
            return "Press Pick on the left of what matters today. A task with no time asks for one first. Each one goes into your plan as a block of its own length, in the free time left today. A task that has a time of day goes in at that time, if it is free. The circle marks a task as done."
        }
        return "Press Pick on the left of the two or three that matter most today. Each one goes into your plan as a one-hour block, in the free time left today. A task that has a time of day goes in at that time, if it is free. The circle marks a task as done."
    }

    /// **Not `TaskRef.id`** (build 238): that carries the line number, and ticking a repeating
    /// task writes its next occurrence on the line below.
    static func key(_ ref: TaskRef) -> String {
        TodayPicking.key(notePath: ref.notePath, title: ref.task.title)
    }
}

/// The dark strip right under Today's band while picking: what is going on, and the way out.
/// It carries the old page's name for the screen tests (`startDay.screen`).
struct PickingStrip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Text(TodayPicking.stripWords)
                .font(Txt.label.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                model.stopPicking()
            } label: {
                // The padding goes inside the label: a Button's tap area is its label (build 186).
                Text("Done")
                    .font(Txt.label.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done: leave picking, nothing is planned")
            .accessibilityIdentifier("picking.done")
            .help("Leave picking. Nothing is planned.")
        }
        .padding(.leading, Theme.gutter + 6)
        .padding(.trailing, Theme.gutter - 4)
        .frame(maxWidth: .infinity)
        .background(StartScreen.slate)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("startDay.screen")
    }
}

/// **This morning**: the line he wrote last evening in Close the day and the goal for the week,
/// read and never written (build 265). Each line only when it has something to say; while its
/// note is still coming from iCloud it says so — "nothing written" is not something this device
/// can know yet (build 100).
struct MorningCard: View {
    @EnvironmentObject private var model: AppModel
    let day: DateOnly

    private var yesterday: DateOnly { day.adding(days: -1) }
    private var lastEveningText: String { model.lookingBack(for: yesterday) }

    /// False when the card would be an empty box: then it is not drawn at all.
    static func hasSomething(_ model: AppModel, on day: DateOnly) -> Bool {
        let yesterday = day.adding(days: -1)
        return !model.lookingBack(for: yesterday).isEmpty
            || model.dailyNoteIsWaitingForCloud(yesterday)
            || model.weekGoal(for: .current()) != nil
            || model.weeklyNoteIsWaitingForCloud(.current())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(title: "This morning", tint: Theme.morningTint)
            lastEvening
            weekGoal
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("startDay.morning")
    }

    @ViewBuilder
    private var lastEvening: some View {
        if !lastEveningText.isEmpty {
            (Text("Last evening: ").fontWeight(.semibold).foregroundColor(Theme.morningTint.ink)
                + Text(lastEveningText))
                .font(Txt.label)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                // One sentence on both platforms, set explicitly, so a test reads the same words
                // on the phone and the Mac (build 253's `project.next`).
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last evening you wrote: \(lastEveningText)")
                .accessibilityIdentifier("startDay.lastEvening")
        } else if model.dailyNoteIsWaitingForCloud(yesterday) {
            MarkLabel("Last evening's note is still coming from iCloud.", "icloud", text: .footnote)
                .font(Txt.label)
                .foregroundStyle(Theme.attention.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("startDay.lastEvening")
        }
    }

    @ViewBuilder
    private var weekGoal: some View {
        if let goal = model.weekGoal(for: .current()) {
            WeekGoalLine(goal: goal, identifier: "startDay.weekGoal")
        } else if model.weeklyNoteIsWaitingForCloud(.current()) {
            MarkLabel("This week's note is still coming from iCloud.", "icloud", text: .footnote)
                .font(Txt.label)
                .foregroundStyle(Theme.attention.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("startDay.weekGoal")
        }
    }
}

/// **Build 235, his idea: the morning is when new things come to mind**, so picking has to take
/// them. One field and a **+**, the shape of the add-a-task bar in a note (build 142).
///
/// **It goes to the Inbox, dated today**, through the ordinary capture path — the same line
/// **Capture** would write. The date is what puts it under **Due today**, and a date he typed
/// himself wins (`CaptureReading.line(_:datedIfUndated:)`, Core, tested). **It arrives already
/// picked**: typing it here is the choosing. The field keeps its focus after **+**.
struct PickingAddField: View {
    @EnvironmentObject private var model: AppModel
    let day: DateOnly
    @State private var newAction = ""
    @FocusState private var focused: Bool
    /// Said under the field when a line typed with another day's date went to the Inbox but not
    /// into today's list (build 238).
    @State private var note: String?

    private var tint: Color { Theme.morningTint }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Add an action for today", text: $newAction)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { addAction() }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.35)))
                    .accessibilityIdentifier("startDay.newAction")
                Button {
                    addAction()
                } label: {
                    MarkImage("plus.circle.fill", text: .headline)
                        .foregroundStyle(canAdd ? tint : Color.secondary.opacity(0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Add this action for today and pick it")
                .accessibilityIdentifier("startDay.add")
                .help("Add this action for today and pick it")
            }
            if let note {
                Text(note)
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Goes to the Inbox, dated today, and is picked for your plan.")
                    .font(Txt.listSecond)
                    .foregroundStyle(.soft)
            }
        }
        .macCursorStartsHere($focused)
    }

    private var canAdd: Bool {
        !newAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Captures the line, then finds it in the refreshed list and picks it. `capture` reloads
    /// the model before it returns; the new line is the one ref that was not there before and
    /// carries the title just written.
    private func addAction() {
        let line = CaptureReading.line(newAction, datedIfUndated: day)
        guard !line.isEmpty else { return }
        let title = CaptureReading(line: line).title
        let before = Set(model.actionsForPlanning(on: day).map(\.id))
        model.capture(text: line, target: .inbox)
        newAction = ""
        focused = true
        if let ref = model.actionsForPlanning(on: day)
            .first(where: { !before.contains($0.id) && $0.task.title == title }) {
            model.todayPicks.insert(StartDay.key(ref))
            note = nil
        } else {
            // A date he typed for another day: the line is safe in the Inbox, it just does not
            // belong on today's list — say so rather than let it vanish (build 100).
            note = "Saved to the Inbox. It has another date, so it is not in today's list."
        }
    }
}

private extension View {
    /// The Mac: the cursor starts in the field when picking starts, so the first key pressed
    /// types (look 1.0). Nothing on the iPhone and iPad, where it would raise the keyboard.
    func macCursorStartsHere(_ focus: FocusState<Bool>.Binding) -> some View {
        #if os(macOS)
        self.onAppear { DispatchQueue.main.async { focus.wrappedValue = true } }
        #else
        self
        #endif
    }
}

/// One of Today's task rows while picking: a real `TaskRow` (build 149: a tick here ticks the
/// task in its own note), with the pick **in front of it**. The pick is **not** a circle: the
/// task's own tick box is the circle (build 154).
///
/// **Build 240: the pick comes first.** With **Pick** at the far right, the first thing his
/// thumb met on each row was the tick circle, and he ticked two actions *done* while trying to
/// pick them. On the iPhone it is the large button; in the Mac's and iPad's narrow Today column
/// the small capsule, at one width so nothing jumps when **Pick** becomes **Picked**.
struct PickingRow: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    /// The iPhone's large button.
    let large: Bool
    /// When the task is already in today's plan: its start, shown instead of the button.
    let plannedAt: Int?
    @AppStorage(TaskTimeSetting.key) private var useTaskTimes = true
    /// Pressing **Pick** on a task with no time asks for the time first, and choosing one picks
    /// it (build 249, his answer).
    @State private var askingTime = false

    static let smallWidth: CGFloat = 62
    private var tint: Color { Theme.morningTint }
    private var key: String { StartDay.key(ref) }
    private var width: CGFloat { large ? PickButton.largeWidth : PickingRow.smallWidth }

    var body: some View {
        HStack(alignment: .top, spacing: large ? 12 : 8) {
            front
            TaskRow(ref: ref, showNote: true, place: .startDay) { model.toggle(ref) }
        }
    }

    @ViewBuilder
    private var front: some View {
        if let plannedAt {
            VStack(spacing: 0) {
                Text("In plan")
                    .font(Txt.listSecond)
                Text(PlanBlock.clock(plannedAt))
                    .font(Txt.label.monospacedDigit())
            }
            .foregroundStyle(.soft)
            .frame(width: width)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("In the plan at \(PlanBlock.clock(plannedAt))")
        } else {
            PickButton(isOn: model.todayPicks.contains(key), tint: tint, large: large) {
                press()
            }
            .frame(width: width)
            .accessibilityIdentifier("startDay.pick.\(ref.task.title)")
            .popover(isPresented: $askingTime) {
                TaskTimeChoices(ref: ref, tint: tint) {
                    model.todayPicks.insert(key)
                    askingTime = false
                }
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func press() {
        if model.todayPicks.contains(key) {
            model.todayPicks.remove(key)
        } else if useTaskTimes && ref.task.minutes == nil {
            askingTime = true
        } else {
            model.todayPicks.insert(key)
        }
    }
}

/// The foot of Today while something is picked: **Does it fit?** (build 249) and the one
/// full-colour button. With nothing picked it draws nothing — the strip's **Done** is the way
/// out, and a main button is never grey.
struct PickingFoot: View {
    @EnvironmentObject private var model: AppModel
    let day: DateOnly
    /// The picked tasks in the list's order (`TodayPicking.chosen`).
    let refs: [TaskRef]
    @AppStorage(TaskTimeSetting.key) private var useTaskTimes = true

    var body: some View {
        if let title = TodayPicking.planTitle(picked: refs.count) {
            VStack(alignment: .leading, spacing: 8) {
                if useTaskTimes { fitLine }
                Button(title) { finish() }
                    .buttonStyle(.main(Theme.morningTint))
                    .accessibilityIdentifier("picking.plan")
            }
            .padding(.horizontal, Theme.gutter + 6)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    /// The picked times added up, against the free time left in the working day and in the
    /// whole day. **The working day is a measure, never a wall**: going past it is said in grey,
    /// and only a day with no room left before midnight is orange (`DayFit`, Core, tested).
    private var fitLine: some View {
        let fit = model.dayFit(for: refs, on: day)
        let end = PlanBlock.clock(model.workdayEnds)
        let untimed = refs.filter { $0.task.minutes == nil }.count
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Picked")
                Spacer()
                Text(TaskTime.total(fit.picked))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            HStack {
                Text(fit.freeInWorkday > 0 ? "Free until \(end)" : "Free this evening")
                Spacer()
                Text(TaskTime.total(fit.freeInWorkday > 0 ? fit.freeInWorkday : fit.freeToday))
                    .monospacedDigit()
            }
            Text(verdictText(fit.verdict, end: end, workdayLeft: fit.freeInWorkday > 0))
                .fontWeight(.semibold)
                .foregroundStyle(verdictColor(fit.verdict))
                .fixedSize(horizontal: false, vertical: true)
            if untimed > 0 {
                Text(untimed == 1 ? "One pick has no time and counts as 1 h." : "\(untimed) picks have no time and count as 1 h each.")
                    .font(Txt.listSecond)
                    .foregroundStyle(.soft)
            }
        }
        .font(Txt.label)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("startDay.fit")
    }

    private func verdictText(_ verdict: DayFit.Verdict, end: String, workdayLeft: Bool) -> String {
        switch verdict {
        case .fitsWorkday:
            return "It fits before \(end)."
        case .runsIntoEvening(let minutes):
            return workdayLeft
                ? "\(TaskTime.total(minutes)) goes past \(end), into the evening."
                : "It fits this evening."
        case .tooMuch(let minutes):
            return "\(TaskTime.total(minutes)) more than the rest of today holds."
        }
    }

    private func verdictColor(_ verdict: DayFit.Verdict) -> Color {
        switch verdict {
        case .fitsWorkday: return .green
        case .runsIntoEvening: return .secondary
        case .tooMuch: return Theme.attention.ink
        }
    }

    /// One write puts every pick into the plan, and the message says how many fitted — never
    /// silently fewer than he asked for (build 100's rule). Then picking is over.
    private func finish() {
        guard !refs.isEmpty else { return }
        let placed = model.planActions(refs, on: day)
        let text = messageWithCloudNote(placed: placed, asked: refs.count)
        // The caution about notes still coming from iCloud is three sentences: give it time.
        if model.notesWaitingForCloud.isEmpty {
            model.flash(text)
        } else {
            model.flash(text, seconds: 10)
        }
        model.stopPicking()
    }

    /// **A note that has not arrived is not known** (build 100's rule): a task with a time of day
    /// in it is not in the index, so its hour was not kept free. The plan is written all the
    /// same, and the message says so.
    private func messageWithCloudNote(placed: Int, asked: Int) -> String {
        let text = message(placed: placed, asked: asked)
        if model.notesWaitingForCloud.isEmpty { return text }
        return text + " Some notes are still coming from iCloud. A task with a time of day in them was not kept free. Look at Plan."
    }

    private func message(placed: Int, asked: Int) -> String {
        if placed == 0 {
            return "No free time is left today, so nothing was added to your plan."
        }
        if placed < asked {
            return "\(placed) of \(asked) fitted in your plan. The rest had no free time left today."
        }
        return placed == 1 ? "Added 1 action to today's plan." : "Added \(placed) actions to today's plan."
    }
}

/// **Pick** / **Picked**, in build 142's two-state language: picked is the tint filled with a
/// solid border, not picked is grey with a dashed one — the same as `FilterBox` (build 157).
/// **Close the day** uses it too, as **First** (build 236), so the two screens mark things the
/// same way. `large` (build 240) is the size used in front of a task row: bigger than the tick
/// circle beside it, and one width for both words so the rows line up and nothing jumps when
/// **Pick** becomes **Picked**.
struct PickButton: View {
    static let largeWidth: CGFloat = 76

    let isOn: Bool
    let tint: Color
    var onTitle = "Picked"
    var offTitle = "Pick"
    var large = false
    let action: () -> Void

    init(isOn: Bool, tint: Color, onTitle: String = "Picked", offTitle: String = "Pick",
         large: Bool = false, action: @escaping () -> Void) {
        self.isOn = isOn
        self.tint = tint
        self.onTitle = onTitle
        self.offTitle = offTitle
        self.large = large
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            // The padding goes **inside** the label: a Button's tap area is its label (build 186).
            Text(isOn ? onTitle : offTitle)
                .font(large ? .callout.weight(.semibold) : .caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isOn ? tint.capsuleWords : Color.primary.opacity(0.62))
                .frame(width: large ? PickButton.largeWidth - 16 : nil)
                .padding(.horizontal, large ? 8 : 10)
                .padding(.vertical, large ? 6 : 3)
                .background(Capsule().fill(isOn ? tint.opacity(0.24) : Color.clear))
                .overlay(border)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    @ViewBuilder
    private var border: some View {
        if isOn {
            Capsule().strokeBorder(tint, lineWidth: 1.3)
        } else {
            Capsule().strokeBorder(Color.primary.opacity(0.45),
                                   style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        }
    }
}

/// **An explanation that steps back once it is known** (build 312), for Start the day and
/// Close the day. The first three times the sheet is opened the paragraph is simply there
/// (`HintRule`, Core, tested). After that only a small hand-drawn info mark is left; a press
/// shows the paragraph, another press folds it again.
struct HintParagraph: View {
    let text: String
    /// How often the sheet has been opened, this time included.
    let opens: Int
    let tint: Color
    /// `<identifier>` is the info button, `<identifier>.text` the paragraph.
    let identifier: String
    @State private var asked = false

    private var byItself: Bool { HintRule.showsByItself(opens: opens) }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !byItself {
                Button {
                    withAnimation(Motion.fold) { asked.toggle() }
                } label: {
                    MarkImage("info.circle", size: 18)
                        .foregroundStyle(asked ? tint.ink : Theme.soft)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("What to do here")
                .accessibilityIdentifier(identifier)
                .help(asked ? "Hide the explanation" : "What to do here")
            }
            if byItself || asked {
                Text(text)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(identifier + ".text")
            }
        }
    }
}
