import SwiftUI
import ParagonCore

/// Step 7 of the Weekly review, **Look back at the week** (build 263). He chose it from the
/// plan page (https://claude.ai/artifact/RyZxairjYDdB7KoxiuGZ3S): the week's goal, the tasks
/// finished each day, the lines written in **Close the day**, the time on the focus timer, the
/// projects that ended, and what the work served. Every part of it was already in his notes;
/// the evening lines in particular were saved and never shown again.
///
/// `WeekLook` (Core, tested) decides every number; this only draws them.
///
/// **No row here carries a `.tag`.** The review's `List` has a selection, and these rows hold
/// buttons of their own — the arrows, a day's line, an ended project. A tagged row would take
/// their click (builds 71–74), and an untagged one also never takes the selection fill, so the
/// explicit colours below stay readable (build 201).
///
/// **Build 266: the heading names the week the step shows.** It said "7. Look back at the
/// week" while, on a Monday, the summary above it said "9 tasks finished in the last 7 days" —
/// and he could not tell which week the step was about. It now says "7. Look back at last week"
/// (or "this week", or "week 41"), through `WeekLook.weekName`, the one place a week is named
/// in a sentence (build 264), and it follows the arrows. The step folds like every other part
/// of the review; folded, nothing below the heading is worked out at all.
struct WeekLookStep: View {
    @EnvironmentObject private var model: AppModel
    /// The week the arrows chose, or nil for the one `WeekLook.weekToShow(today:)` picks. Kept
    /// by `ReviewView`, whose state is certain to outlive a scroll of the list.
    @Binding var chosenWeek: WeekRef?
    /// Whether the step is open. `ReviewView` keeps it with every other part of the review in
    /// one stored string, so **Open all** and this heading can never disagree.
    @Binding var isOpen: Bool

    private var thisWeek: WeekRef { WeekRef(containing: DateOnly.today()) }
    /// Worked out each time, so a Mac left open from Tuesday to Wednesday moves on by itself.
    private var shownWeek: WeekRef { chosenWeek ?? WeekLook.weekToShow(today: DateOnly.today()) }
    /// "this week" or "that week", for every sentence that names the week shown. On Monday and
    /// Tuesday the step opens on last week, and a sentence saying "this week" about it would
    /// contradict the heading above it (review of 263).
    private var weekWords: String { shownWeek == thisWeek ? "this week" : "that week" }

    /// "7. Look back at last week" — the week shown, named the way step 8 and **Calendar ›
    /// Week** name a week, so it changes with the arrows.
    private var heading: String {
        "7. Look back at " + WeekLook.weekName(shownWeek, today: DateOnly.today())
    }

    var body: some View {
        Section {
            if isOpen {
                content(model.index.weekLook(for: shownWeek))
            }
        } header: {
            ReviewPartHeading(title: heading, isOpen: $isOpen, part: "7")
        } footer: {
            if isOpen {
                Text("Press a day's line to open that day's note. The arrows show earlier weeks.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The step's rows. A function, so the week is only worked out while the step is open; the
    /// rows are each their own row in the list, as they were when they sat in the body.
    @ViewBuilder
    private func content(_ look: WeekLook) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            weekBar
            goalBox(look.goal)
            WeekDayBars(look: look)
            finishedLine(look)
        }
        .padding(.vertical, 4)

        if eveningLines(look).isEmpty {
            Text("No evening lines \(weekWords). **Close the day** writes them.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            ForEach(eveningLines(look)) { line in
                EveningLineRow(line: line)
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            timerLine(look)
            ForEach(look.endedProjects) { project in
                EndedProjectRow(project: project, weekWords: weekWords)
            }
            if !look.finished.isEmpty {
                SectionLabel(title: "What it served")
                    .padding(.top, 4)
                ForEach(servedShown(look)) { served in
                    ServedRow(served: served)
                }
                if let more = servedMore(look) {
                    Text(more)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)

        // Build 100's rule: a note not yet on this device must never read as a quiet week.
        if !model.notesWaitingForCloud.isEmpty {
            Label(cloudText, systemImage: "icloud")
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The parts

    private var weekBar: some View {
        HStack(spacing: 8) {
            Button {
                chosenWeek = shownWeek.adding(weeks: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            // Borderless, or on the phone a press anywhere in the row would press every
            // button in it.
            .buttonStyle(.borderless)
            .accessibilityLabel("Earlier week")
            .accessibilityIdentifier("review.lookBack.earlier")

            Text(shownWeek.title)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(shownWeek.title)
                .accessibilityIdentifier("review.lookBack")

            Button {
                chosenWeek = shownWeek.adding(weeks: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            // Nothing has happened yet in a week to come.
            .disabled(shownWeek.monday >= thisWeek.monday)
            .accessibilityLabel("Later week")
            .accessibilityIdentifier("review.lookBack.later")
        }
    }

    /// The goal written for the week, in the gold of the goal box it was written in, or a
    /// dashed grey box saying none was — the two states `WeekGoalBox` already draws. While the
    /// week's own note is still coming from iCloud it says that instead, in orange: "no goal"
    /// is not something this device can know yet (build 100's rule, review of 263).
    private func goalBox(_ goal: String?) -> some View {
        let tint = ParaKind.goal.tint
        let waiting = goal == nil && model.weeklyNoteIsWaitingForCloud(shownWeek)
        let missing = waiting ? "The week's note is still coming from iCloud."
                              : "No goal was written for \(weekWords)."
        return VStack(alignment: .leading, spacing: 2) {
            // Named as Calendar › Week names it ("Goal for last week"), so the two boxes never call
            // one week by two names; the sentences below keep "that week" (review of 264).
            Text(WeekLook.goalTitle(for: shownWeek, today: DateOnly.today()))
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(goal == nil ? Color.secondary : tint)
            Text(goal ?? missing)
                .font(goal == nil ? .callout : .callout.weight(.semibold))
                .foregroundStyle(goal != nil ? Color.primary : (waiting ? Color.orange : Color.secondary))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(goal == nil ? Color.clear : tint.opacity(0.10)))
        .overlay(GoalBoxBorder(isSet: goal != nil, tint: tint))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("review.lookBack.goal")
    }

    @ViewBuilder
    private func finishedLine(_ look: WeekLook) -> some View {
        if let text = look.finishedText {
            CountPill(text: text, systemImage: "checkmark.circle", tint: .green)
        } else {
            Text("No task was ticked off \(weekWords).")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func timerLine(_ look: WeekLook) -> some View {
        Label(look.workedText ?? "The focus timer was not used \(weekWords).", systemImage: "timer")
            .font(.callout)
            .foregroundStyle(look.workedText == nil ? Color.secondary : Color.primary)
    }

    // MARK: Worked out, never in the body (build 58)

    /// The days with an evening line, and the days whose note is still coming from iCloud —
    /// those say so rather than look like an evening with nothing written.
    private func eveningLines(_ look: WeekLook) -> [EveningLine] {
        look.days.compactMap { record -> EveningLine? in
            let text = record.lookingBack
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !text.isEmpty {
                return EveningLine(day: record.day, text: text, path: record.dailyNotePath, waiting: false)
            }
            if model.dailyNoteIsWaitingForCloud(record.day) {
                return EveningLine(day: record.day, text: "Still coming from iCloud", path: nil, waiting: true)
            }
            return nil
        }
    }

    /// What the week's work served, with the days' own notes as one row: a week of tasks ticked
    /// in daily notes would otherwise be seven rows of dates pushing the goals out of the six
    /// shown (review of 263). `ServedCount.mergingDailyNotes` (Core, tested) decides it.
    private func served(_ look: WeekLook) -> [ServedCount] {
        ServedCount.mergingDailyNotes(model.index.servedCounts(of: look.finished))
    }

    /// At most six: the point is where the week went, not a second list of everything.
    private func servedShown(_ look: WeekLook) -> [ServedCount] {
        Array(served(look).prefix(6))
    }

    private func servedMore(_ look: WeekLook) -> String? {
        let left = served(look).count - 6
        return left > 0 ? "\u{2026}and \(left) more" : nil
    }

    private var cloudText: String {
        let count = model.notesWaitingForCloud.count
        let notes = count == 1 ? "1 note is" : "\(count) notes are"
        return "\(notes) still coming from iCloud, so these numbers may still grow."
    }
}

/// Step 8 of the Weekly review, **Write the goal for …** (build 264): the week's goal box, for
/// the week you are about to work in (`WeekLook.goalWeek`, Core, tested). **The same
/// `WeekGoalBox` as Calendar › Week**, not a copy, so the two can never disagree about what the
/// goal is or how it is written (build 168). It does not follow step 7's arrows: looking at an
/// old week must not move what you are about to plan.
struct WeekGoalStep: View {
    /// Not read, but watched: it is what makes the body run again when the model publishes —
    /// at midnight among other times — so a review left open from Tuesday to Wednesday moves on
    /// to next week like step 7 does. A view with nothing to watch is drawn once (review of 264).
    @EnvironmentObject private var model: AppModel
    /// Whether the step is open, kept by `ReviewView` with the rest of the review (build 266).
    @Binding var isOpen: Bool

    var body: some View {
        let today = DateOnly.today()
        let week = WeekLook.goalWeek(today: today)
        Section {
            if isOpen {
                WeekGoalBox(week: week, identifier: "review.nextGoal", divided: false)
                    .padding(.vertical, 4)
                    // The field's **Cancel** and **Done** sit in one List row: borderless, or on the
                    // phone one press would press both. The box's own button keeps its `.plain`.
                    .buttonStyle(.borderless)
            }
        } header: {
            ReviewPartHeading(title: "8. Write the goal for \(WeekLook.weekName(week, today: today))",
                              isOpen: $isOpen, part: "8")
        } footer: {
            if isOpen {
                Text("It is shown on **Today** during that week, and at the top of **Calendar \u{203A} Week**.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One evening's line, or a day still on its way from iCloud.
struct EveningLine: Identifiable {
    let day: DateOnly
    let text: String
    let path: String?
    let waiting: Bool

    var id: DateOnly { day }
}

/// The day's short name and what was written that evening. Pressing it opens that day's note
/// **without leaving the review** (build 135): on the Mac in the third column beside the
/// list, on the phone one screen deeper with the back arrow returning here.
private struct EveningLineRow: View {
    @EnvironmentObject private var model: AppModel
    let line: EveningLine

    var body: some View {
        Button {
            if let path = line.path {
                model.show(section: .review, notePath: path)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
                if line.waiting {
                    Label(line.text, systemImage: "icloud")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else {
                    Text(line.text)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(line.path == nil)
        .accessibilityIdentifier("review.lookBack.evening.\(line.day.description)")
    }

    private var dayName: String {
        line.day.date()?.formatted(.dateTime.weekday(.abbreviated)) ?? line.day.description
    }
}

/// "Ended this week: Fix the bike · Done", in the ending's own symbol and colour (build 165).
/// "that week" when the step shows an earlier one. Pressing it opens the project, staying in
/// the review.
private struct EndedProjectRow: View {
    @EnvironmentObject private var model: AppModel
    let project: EndedProject
    let weekWords: String

    var body: some View {
        Button {
            model.show(section: .review, notePath: project.path)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: project.status.systemImage)
                    .foregroundStyle(project.status.tint(onNote: ParaKind.project.tint))
                    .frame(width: 18)
                Text("Ended \(weekWords):")
                    .foregroundStyle(.secondary)
                Text(project.title)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text("\u{00B7} \(project.status.label)")
                    .foregroundStyle(project.status.tint(onNote: ParaKind.project.tint))
                Spacer(minLength: 0)
            }
            .font(.callout)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("review.lookBack.ended.\(project.path)")
    }
}

/// Seven columns, Monday to Sunday: the tasks finished that day as a green bar, the count above
/// it. **A day with none shows "–", never "0"** (build 141), a day still to come shows nothing
/// at all, and a day whose note is still coming from iCloud shows the cloud — "none" would be a
/// claim this device cannot make.
private struct WeekDayBars: View {
    @EnvironmentObject private var model: AppModel
    let look: WeekLook

    private let barArea: CGFloat = 40

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(look.days) { record in
                column(record)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.lookBack.days")
    }

    private func column(_ record: DayRecord) -> some View {
        let count = record.finished.count
        let future = record.day > DateOnly.today()
        let waiting = model.dailyNoteIsWaitingForCloud(record.day)
        return VStack(spacing: 3) {
            HStack(spacing: 1) {
                if waiting {
                    Image(systemName: "icloud")
                        .foregroundStyle(.orange)
                }
                Text(countText(count, future: future, waiting: waiting))
                    .monospacedDigit()
                    .foregroundStyle(count == 0 ? Color.secondary : Color.primary)
            }
            .font(.caption2.weight(.semibold))
            RoundedRectangle(cornerRadius: 3)
                .fill(barFill(count, future: future, waiting: waiting))
                .frame(height: barHeight(count))
                .frame(height: barArea, alignment: .bottom)
            Text(dayName(record.day))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(record, count: count, future: future, waiting: waiting))
    }

    /// A day still to come, or one still coming from iCloud with nothing counted, draws no dash
    /// and no grey line: both are what "none" looks like, and neither day can say that.
    private func countText(_ count: Int, future: Bool, waiting: Bool) -> String {
        if future || (waiting && count == 0) { return " " }
        return count == 0 ? "\u{2013}" : "\(count)"
    }

    private func barHeight(_ count: Int) -> CGFloat {
        guard count > 0 else { return 2 }
        return max(4, barArea * CGFloat(count) / CGFloat(look.biggest))
    }

    private func barFill(_ count: Int, future: Bool, waiting: Bool) -> Color {
        if future || (waiting && count == 0) { return Color.clear }
        return count == 0 ? Color.secondary.opacity(0.25) : Color.green.opacity(0.85)
    }

    private func dayName(_ day: DateOnly) -> String {
        day.date()?.formatted(.dateTime.weekday(.abbreviated)) ?? day.description
    }

    private func spoken(_ record: DayRecord, count: Int, future: Bool, waiting: Bool) -> String {
        let name = record.day.date()?.formatted(.dateTime.weekday(.wide)) ?? record.day.description
        if future { return "\(name): still to come" }
        if waiting && count == 0 { return "\(name): still coming from iCloud" }
        switch count {
        case 0: return "\(name): no task finished"
        case 1: return "\(name): 1 task finished"
        default: return "\(name): \(count) tasks finished"
        }
    }
}

/// The goal box's frame: solid gold when a goal is written, dashed grey when not — the
/// language of build 142, the same two states `WeekGoalBox` draws.
private struct GoalBoxBorder: View {
    let isSet: Bool
    let tint: Color

    var body: some View {
        if isSet {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint.opacity(0.6), lineWidth: 1.2)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
        }
    }
}
