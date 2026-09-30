import SwiftUI
import ParagonCore

/// The morning step, the partner of **Close the day** (build 233): what is overdue, what is due
/// today and your next actions, and you pick the few that matter most. Those go into today's
/// plan as one-hour blocks, in the free time left in the day.
///
/// **The same shape as `CloseDayView` on purpose** — a sheet you open, work down and finish,
/// through the app's single `.sheet` (build 44). Two screens that are a pair should look like
/// one.
///
/// **It makes plan blocks, never Time Blocks** (build 147): a `TB:` line in the daily note that
/// stays in PARAGON. Whether a block is also in Apple Calendar is still his choice, per block,
/// on **Plan** (build 151).
struct StartDayView: View {
    @EnvironmentObject private var model: AppModel

    /// The picked actions, by note path and title (`pickKey`). Nothing is picked when the screen opens: choosing
    /// what matters is the whole point, and a screen that chose for him would skip it.
    @State private var picked: Set<String> = []
    /// What is being typed into the **+** field at the top (build 235).
    @State private var newAction = ""
    @FocusState private var newActionFocused: Bool
    /// Said under the field when a line typed with another day's date went to the Inbox but not
    /// into this list. **Inside the sheet**, because the app's own message line sits under it and
    /// the sheet covers that on a phone (build 238).
    @State private var addNote: String?

    /// **Not `TaskRef.id`** (build 238): that carries the line number, and ticking a repeating task
    /// here writes its next occurrence on the line below, moving every later task in that note —
    /// a pick kept by line would then point at the wrong task. Path and title are what
    /// `FirstPick` has used since build 236.
    private func pickKey(_ ref: TaskRef) -> String {
        ref.notePath + "\n" + ref.task.title
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    private var day: DateOnly { DateOnly.today() }
    private var tint: Color { Theme.morningTint }

    /// The planner's own question (build 174), so this screen and **Plan** can never offer two
    /// different lists of "today's actions".
    private var actions: [TaskRef] { model.actionsForPlanning(on: day) }

    /// Marked **First** in last night's **Close the day** (build 236): his choice was a mark,
    /// not a block, and the mark's whole job is to put these at the top of this screen.
    private var marked: [TaskRef] { model.firstPicks.split(actions, on: day).first }

    /// Everything else, in the planner's order; the three groups below are drawn from this.
    private var unmarked: [TaskRef] { model.firstPicks.split(actions, on: day).rest }

    private var overdue: [TaskRef] {
        unmarked.filter { ref in
            guard let due = ref.task.dueDate else { return false }
            return due < day
        }
    }

    private var dueToday: [TaskRef] {
        unmarked.filter { $0.task.dueDate == day }
    }

    /// Next actions with no date on or before today — the rest of what the planner offers.
    private var nextOnes: [TaskRef] {
        unmarked.filter { ref in
            guard let due = ref.task.dueDate else { return true }
            return due > day
        }
    }

    /// The titles already in today's plan, so an action that is already there says so instead
    /// of offering to go in a second time.
    private var plannedAt: [String: Int] {
        var result: [String: Int] = [:]
        for block in model.planBlocks(for: day) where result[block.title] == nil {
            result[block.title] = block.start
        }
        return result
    }

    /// In the order the list shows them, so the earliest block goes to the first one picked
    /// from the top.
    private var pickedRefs: [TaskRef] {
        (marked + overdue + dueToday + nextOnes).filter { picked.contains(pickKey($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    counts
                    addField
                    if actions.isEmpty {
                        nothingToPick
                    } else {
                        Text("Press Pick on the left of the two or three that matter most today. Each one goes into your plan as a one-hour block, in the free time left today. The circle marks a task as done.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        group("Marked first last evening", marked)
                        group("Overdue", overdue)
                        group("Due today", dueToday)
                        group("Next actions", nextOnes)
                    }
                }
                .padding(isPhone ? 14 : 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            SheetFooter(actionTitle: actionTitle, tint: tint,
                        cancel: { close() }, act: { finish() })
                .padding(isPhone ? 14 : 20)
        }
        // One name the screen test can wait for (build 190). Accessibility only.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("startDay.screen")
        .onAppear { model.loadFirstPicks() }
        // Today's events are what the blocks are fitted around, so read them fresh here rather
        // than trust whatever Today loaded earlier (build 238).
        .task { await model.loadEvents(for: day) }
        .frame(minWidth: isPhone ? nil : 480, minHeight: isPhone ? nil : 420)
        .frame(maxWidth: fillOnPhone, maxHeight: fillOnPhone, alignment: .topLeading)
    }

    /// Says what the press will do: with nothing picked it only closes the screen.
    private var actionTitle: String {
        switch picked.count {
        case 0: return "Done"
        case 1: return "Plan 1 action"
        default: return "Plan \(picked.count) actions"
        }
    }

    /// Written out rather than a ternary with `nil` in one arm (build 199).
    private var fillOnPhone: CGFloat? {
        if isPhone { return CGFloat.infinity }
        return nil
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label("Start the day", systemImage: StartDayView.symbol)
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

    /// A cup, not a sunrise: `sunrise` already means **Tomorrow** on the Inbox's buttons and over
    /// **Overdue** (builds 215 and 224), and one symbol with two meanings is build 168's fault.
    static let symbol = "cup.and.saucer.fill"

    private var counts: some View {
        WrappingHStack(spacing: 8, lineSpacing: 8) {
            if !overdue.isEmpty {
                CountPill(text: "\(overdue.count) overdue",
                          systemImage: "exclamationmark.circle", tint: .orange)
            }
            CountPill(text: "\(dueToday.count) due today",
                      systemImage: "calendar", tint: tint)
            if !picked.isEmpty {
                CountPill(text: "\(picked.count) picked",
                          systemImage: "checkmark.circle", tint: .green)
            }
        }
    }

    /// **Build 235, his idea: the morning is when new things come to mind**, so the screen has to
    /// take them. One field and a **+**, the shape of the add-a-task bar in a note (build 142).
    ///
    /// **It goes to the Inbox, dated today**, through the ordinary capture path — the same line
    /// **Capture** would write, so it is filed later the usual way and nothing new is invented.
    /// The date is what puts it under **Due today** here, and a date he typed himself wins
    /// (`CaptureReading.line(_:datedIfUndated:)`, Core, tested). **It arrives already picked**:
    /// typing it here is the choosing.
    ///
    /// The field keeps its focus after **+**, so a second and a third can follow without a tap.
    private var addField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Add an action for today", text: $newAction)
                    .textFieldStyle(.plain)
                    .focused($newActionFocused)
                    .submitLabel(.done)
                    .onSubmit { addAction() }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.35)))
                    .accessibilityIdentifier("startDay.newAction")
                Button {
                    addAction()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canAdd ? tint : Color.secondary.opacity(0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Add this action for today and pick it")
                .accessibilityIdentifier("startDay.add")
                .help("Add this action for today and pick it")
            }
            if let addNote {
                Text(addNote)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Goes to the Inbox, dated today, and is picked for your plan.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canAdd: Bool {
        !newAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Captures the line, then finds it in the refreshed list and picks it. `capture` reloads
    /// the model before it returns, so the new line is already in `actionsForPlanning`; it is
    /// the one ref that was not there before and carries the title just written.
    private func addAction() {
        let line = CaptureReading.line(newAction, datedIfUndated: day)
        guard !line.isEmpty else { return }
        let title = CaptureReading(line: line).title
        let before = Set(actions.map(\.id))
        model.capture(text: line, target: .inbox)
        newAction = ""
        newActionFocused = true
        if let ref = model.actionsForPlanning(on: day)
            .first(where: { !before.contains($0.id) && $0.task.title == title }) {
            picked.insert(pickKey(ref))
            addNote = nil
        } else {
            // A date he typed for another day: the line is safe in the Inbox, it just does not
            // belong on today's list — say so rather than let it vanish (build 100).
            addNote = "Saved to the Inbox. It has another date, so it is not in today's list."
        }
    }

    /// Nothing due and no next action is worth saying in words. An empty list under a heading
    /// reads as a screen that failed to load (build 100).
    private var nothingToPick: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nothing is waiting for today.")
                .font(.callout.weight(.semibold))
            Text("No task is due today or overdue, and no note has a next action. Add one above with +.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One group, drawn only when it has something in it — the counts above already say when a
    /// group is empty, so an empty heading here would say nothing twice.
    @ViewBuilder
    private func group(_ title: String, _ refs: [TaskRef]) -> some View {
        if !refs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: title, count: refs.count)
                ForEach(refs) { ref in
                    row(ref)
                }
            }
        }
    }

    /// A real `TaskRow` (build 149: a tick here ticks the task in its own note), with the pick
    /// **in front of it**. The pick is **not** a circle: the task's own tick box is the circle,
    /// and two circles side by side would be two controls that look alike (build 154).
    ///
    /// **Build 240: the pick comes first, and larger.** With **Pick** at the far right, the first
    /// thing his thumb met on each row was the tick circle, and in testing 239 he ticked two
    /// actions *done* while trying to pick them. He chose this shape (B) over hiding the tick:
    /// the morning is also when he notices something is already done.
    private func row(_ ref: TaskRef) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let start = plannedAt[planBlockTitle(from: ref.task)] {
                VStack(spacing: 0) {
                    Text("In plan")
                        .font(.caption2)
                    Text(PlanBlock.clock(start))
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                .frame(width: PickButton.largeWidth)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("In the plan at \(PlanBlock.clock(start))")
            } else {
                PickButton(isOn: picked.contains(pickKey(ref)), tint: tint, large: true) {
                    if picked.contains(pickKey(ref)) {
                        picked.remove(pickKey(ref))
                    } else {
                        picked.insert(pickKey(ref))
                    }
                }
                .accessibilityIdentifier("startDay.pick.\(ref.task.title)")
            }
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
        }
    }

    /// With nothing picked, **Done** only closes. Otherwise one write puts every pick into the
    /// plan, and the message says how many fitted — never silently fewer than he asked for
    /// (build 100's rule).
    private func finish() {
        let refs = pickedRefs
        if !refs.isEmpty {
            let placed = model.planActions(refs, on: day)
            model.flash(message(placed: placed, asked: refs.count))
        }
        close()
    }

    private func message(placed: Int, asked: Int) -> String {
        if placed == 0 {
            return "No free hour is left today, so nothing was added to your plan."
        }
        if placed < asked {
            return "\(placed) of \(asked) fitted in your plan. The rest had no free hour left today."
        }
        return placed == 1 ? "Added 1 action to today's plan." : "Added \(placed) actions to today's plan."
    }

    private func close() {
        model.activeSheet = nil
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
                .foregroundStyle(isOn ? tint : Color.primary.opacity(0.62))
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
