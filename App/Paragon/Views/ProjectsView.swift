import SwiftUI
import ParagonCore

/// The Projects list, grouped under what each project works towards (build 253). He chose the
/// shape from a drawing (https://claude.ai/artifact/4ByhCcS4cA5kYYNH41b6ap) after saying the
/// list was *"a bit boring … I need to get inspired by the app so that I feel like using it."*
///
/// **Every decision about what a box says is in Core** (`ProjectGroups.swift`, tested): which
/// group a project lands in, what it needs next, what is late. This file only draws it, so the
/// list and the review cannot disagree about a project.
///
/// **One list for both platforms**, `List(selection:)` with a `.tag` on each box, exactly as the
/// flat list had: on the phone `PhoneStack` pushes the note when the selection changes. Nothing
/// inside a box takes a click — the pills are words, not buttons — which is what keeps a tagged
/// row safe (builds 71–74). Every action is on the right-click menu.
struct ProjectsListView: View {
    @EnvironmentObject private var model: AppModel
    /// The live groups he has folded shut, one id per line. **Open by default**: a group is
    /// closed only because he closed it (build 121).
    @AppStorage("projectGroupsFolded") private var foldedText = ""
    /// The ended groups he has opened, one id per line. Done, Missed and Dropped **start
    /// folded**, as they do in both goal rooms (build 165); the heading still says how many.
    @AppStorage("projectGroupsOpened") private var openedText = ""
    /// Handed in, because the rename alert and the delete question belong to the note list
    /// around this view, and the flat list uses the very same two.
    let rename: (Note) -> Void
    let trash: (Note) -> Void
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isPhone: Bool { horizontalSizeClass == .compact }
#else
    private var isPhone: Bool { false }
#endif

    var body: some View {
        VStack(spacing: 0) {
            band
            groupedList
        }
    }

    /// The line above the list (build 255): the whole list's weekly bars, how many tasks were
    /// finished in eight weeks and this week, and how many projects want a look. **Outside the
    /// `List`**, so it is not a row with a row's smallest height (build 220's reason). Nothing
    /// is drawn when no finished task carries a date and nothing is late.
    @ViewBuilder
    private var band: some View {
        let weekly = ProjectGroup.weekly(of: model.projectGroups)
        let look = ProjectGroup.needsALookCount(of: model.projectGroups)
        if !weekly.isEmpty || look > 0 {
            WrappingHStack(spacing: 9, lineSpacing: 4) {
                if weekly.total > 0, let head = weekly.bandHead {
                    WeekBars(weekly: weekly, barWidth: 6)
                    Text(head)
                        .fontWeight(.semibold)
                    Text("\u{00B7} " + weekly.bandWeek)
                        .foregroundStyle(.soft)
                } else if let caption = weekly.caption(today: DateOnly.today()) {
                    // Every dated finish is older than eight weeks: bars of nothing and
                    // "0 tasks finished" would say more than the notes do (build 270, the same
                    // fault the area page's review found; the box beside it has long said this).
                    Text(caption)
                        .foregroundStyle(.soft)
                }
                if look > 0 {
                    MarkLabel(WeeklyFinished.lookText(look), "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(Txt.label)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("projects.band")
            Divider()
        }
    }

    private var groupedList: some View {
        List(selection: model.noteSelection) {
            ForEach(model.projectGroups) { group in
                Section {
                    if isOpen(group) {
                        ForEach(group.lines) { line in
                            row(line, in: group)
                        }
                        // His own order, inside the group. A drag never leaves the group, and
                        // the projects outside it keep their places (`ProjectOrder.moving`).
                        .onMove(perform: mover(for: group))
                    }
                } header: {
                    ProjectGroupHeader(group: group, open: isOpen(group)) { toggle(group) }
                } footer: {
                    if isOpen(group), let text = footerText(for: group) {
                        Text(text)
                            .font(Txt.label)
                            .foregroundStyle(.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func row(_ line: ProjectLine, in group: ProjectGroup) -> some View {
        ProjectRow(line: line, under: aspiration(of: group))
            .tag(line.note.relativePath)
            // Named by its path for the screen tests (build 191), the same name the flat list
            // gave the row, so every test that opens the test project still finds it.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("note.\(line.note.relativePath)")
            .acceptsTaskDrop { ref in model.moveTask(ref, to: line.note.relativePath) }
            .contextMenu { menu(for: line.note) }
    }

    /// The four new lines are the status ones: before build 253 a project could only be marked
    /// done from inside the note or from the review, so a list showing "All 15 finished" had no
    /// way to answer itself — the fields-nothing-could-write rule (builds 132 to 165), turned
    /// round. Each line is offered only when it would change something.
    @ViewBuilder
    private func menu(for note: Note) -> some View {
        Button("Rename\u{2026}") { rename(note) }
        NoteGoalMenu(model: model, note: note)
        // Build 269. The groups stay by aspiration (build 253); choosing an area moves the
        // project on the Map, not here.
        ProjectAreaMenu(model: model, note: note)
        Divider()
        // Shared with the area page's project rows (build 270), so the two menus cannot
        // offer different lines.
        ProjectStatusItems(model: model, note: note)
        Divider()
        if model.canArchive(note) {
            Button("Archive") { model.archive(note) }
        }
        Button("Move to Trash\u{2026}", role: .destructive) { trash(note) }
    }

    /// A closure for a live group, nil for an ended one: Done, Missed and Dropped are not a
    /// plan, so there is nothing to arrange in them.
    private func mover(for group: ProjectGroup) -> ((IndexSet, Int) -> Void)? {
        guard !group.isEnded else { return nil }
        let notes = group.lines.map(\.note)
        return { source, destination in
            model.reorderProjects(in: notes, from: source, to: destination)
        }
    }

    /// The aspiration a group sits under, so a box can leave out a goal that only repeats the
    /// heading (build 169's rule).
    private func aspiration(of group: ProjectGroup) -> Note? {
        if case .aspiration(let note) = group.heading { return note }
        return nil
    }

    /// A footer only where the heading names a loose end, and it says where the fix is.
    private func footerText(for group: ProjectGroup) -> String? {
        switch group.heading {
        case .notLinked:
            // Two reasons can put a project here, and each needs its own fix: a goal with no
            // aspiration is fixed in Goals, a goal name that was not found (dashed) only with
            // the project's own Serves (build 254, from the reviews of 253 and 254). Each
            // sentence is said only when a project in the group needs it.
            var parts: [String] = []
            if group.lines.contains(where: { !$0.goalIsMissing }) {
                parts.append("Their goal has no aspiration yet. In Goals, press Give it an aspiration under that goal.")
            }
            if group.lines.contains(where: \.goalIsMissing) {
                parts.append(DeviceWords.holds
                    ? "A line saying No goal called … names a goal that was not found: hold the project and choose Serves."
                    : "A line saying No goal called … names a goal that was not found: right-click the project and choose Serves.")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        case .noGoal:
            return DeviceWords.holds
                ? "Hold a project and choose Serves to give it a goal."
                : "Right-click a project and choose Serves to give it a goal."
        default:
            return nil
        }
    }

    // MARK: Folding

    private var folded: Set<String> { Self.ids(in: foldedText) }
    private var opened: Set<String> { Self.ids(in: openedText) }

    private func isOpen(_ group: ProjectGroup) -> Bool {
        group.isEnded ? opened.contains(group.id) : !folded.contains(group.id)
    }

    private func toggle(_ group: ProjectGroup) {
        if group.isEnded {
            openedText = Self.flipping(group.id, in: openedText)
        } else {
            foldedText = Self.flipping(group.id, in: foldedText)
        }
    }

    private static func ids(in text: String) -> Set<String> {
        Set(text.split(separator: "\n").map(String.init))
    }

    private static func flipping(_ id: String, in text: String) -> String {
        var ids = Self.ids(in: text)
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        return ids.sorted().joined(separator: "\n")
    }
}

/// The heading of one group (1.0): its badge, its name as a 17-point heading in the colour
/// of what the group is, how many projects it holds, and how many want a look. No band: the
/// colour is in the words, as on every other heading. **The whole line folds**, never a
/// small triangle (build 205), and it is a header, so it never takes the selection (build 201).
struct ProjectGroupHeader: View {
    let group: ProjectGroup
    let open: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MarkImage("chevron.right")
                    .font(Txt.listSecond.weight(.semibold))
                    .foregroundStyle(.soft)
                    .rotationEffect(.degrees(open ? 90 : 0))
                badge
                Text(group.title)
                    .font(Txt.sectionTitle)
                    .foregroundStyle(headingTint.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    // Build 281: a List measures its header one line tall unless the text says
                    // how tall it is, so at 280 points the name was cut with "…" instead of
                    // wrapping (the reviewer of 280).
                    .fixedSize(horizontal: false, vertical: true)
                // Round 3: "Done 1 · 1 this year" said the same number twice. The count gives
                // way when the year's line already says it.
                if yearCaption != ProjectGroup.thisYearText(group.lines.count) {
                    Text("\(group.lines.count)")
                        .font(Txt.label.monospacedDigit())
                        .foregroundStyle(Theme.soft)
                }
                if let caption = yearCaption {
                    // Build 269: on Done alone, how many ended this year. Grey, and it gives
                    // way before the name does in a narrow column (builds 138, 212).
                    Text("\u{00B7} " + caption)
                        .font(Txt.label)
                        .foregroundStyle(Theme.soft)
                        .lineLimit(2)
                        .layoutPriority(-1)
                }
                if group.needsALookCount > 0 {
                    // Orange, as everywhere in PARAGON: look at this. On the heading, so a
                    // folded group still says it (build 100).
                    MarkLabel("\(group.needsALookCount)", "exclamationmark.triangle.fill")
                        .font(Txt.label.weight(.semibold))
                        .foregroundStyle(Theme.attention)
                }
            }
            // The whole line, never a `Spacer` beside a short button: the Mac reported a wrong
            // frame for that shape and a test's click landed in the list (build 247).
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A list writes a header in capitals by itself; the names are his own words.
        .textCase(nil)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(open ? [.isSelected] : [])
        .accessibilityIdentifier("projects.group.\(group.id)")
        .help(open ? "Press to close." : "Press to open.")
    }

    private var spoken: String {
        var words = "\(group.title), \(group.lines.count) " + (group.lines.count == 1 ? "project" : "projects")
        if let caption = yearCaption { words += ", " + caption }
        if group.needsALookCount > 0 { words += ", \(group.needsALookCount) need a look" }
        return words
    }

    /// "4 this year" on the Done heading, nil on every other one (Core decides, and says why).
    private var yearCaption: String? {
        group.thisYearCaption(today: DateOnly.today())
    }

    /// The colour of what the group is: the aspiration's gold, a dated goal's gold, soft grey
    /// for projects with no goal, and the ending's own colour for Done, Missed and Dropped.
    private var headingTint: Color {
        switch group.heading {
        case .aspiration: return ChainTint.aspiration
        case .notLinked: return ChainTint.datedGoal
        case .noGoal: return Theme.soft
        case .ended(let status): return endedTint(status)
        }
    }

    /// The same badge the Goals rooms draw for the same thing, so a heading here and a row
    /// there are one picture (build 168).
    @ViewBuilder
    private var badge: some View {
        switch group.heading {
        case .aspiration:
            KindBadge(kind: .goal, size: 20, markName: ChainSymbol.aspiration, tint: ChainTint.aspiration)
        case .notLinked:
            KindBadge(kind: .goal, size: 20, markName: ChainSymbol.datedGoal, tint: ChainTint.datedGoal)
        case .noGoal:
            // Dashed and grey: not connected, as on the Map (build 82).
            MarkImage(ChainSymbol.datedGoal)
                .font(Txt.listSecond.weight(.semibold))
                .foregroundStyle(.soft)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.7),
                                               style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        case .ended(let status):
            MarkImage(status.markName)
                .font(Txt.listTitle)
                .foregroundStyle(endedTint(status))
                .frame(width: 20, height: 20)
        }
    }

    /// The colours the status chip gives the same three words (build 165): done in the
    /// project's own green, missed orange, dropped grey — a decision, not a failure.
    private func endedTint(_ status: NoteStatus) -> Color {
        status.tint(onNote: ParaKind.project.tint)
    }
}

/// One project as a row (1.0): the note's own icon or the 8-point dot, one title, one quiet
/// second line that says how far it is and what it needs ("0 of 2 · Next: Book the train"),
/// a capsule at the right when it is not simply active, and the small weekly bars when a task
/// was finished. Every other fact is in the project's own facts panel. Build 253's card — a
/// tile, a Next line, a goal chip, a progress bar and a frame — said the same things in four
/// lines; what the line says is still decided in Core (`ProjectLine`). **Every text colour goes
/// through `rowTint`**, because the selection fill is his own accent colour and an explicit
/// colour on it can vanish (build 200).
struct ProjectRow: View {
    let line: ProjectLine
    /// The aspiration whose heading this row sits under. A goal that would only name it again
    /// is left out (build 169).
    var under: Note? = nil
    @AppStorage(TaskTimeSetting.key) private var useTaskTimes = true

    private var isOver: Bool { line.status.isEnded || line.status == .archived }
    private var isCalledOff: Bool { line.status == .missed || line.status == .dropped }
    /// Only a project still running can be late. A passed deadline on one that is on hold or
    /// over is a fact, drawn grey, never red.
    private var isRunning: Bool { line.status == .active }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            ProjectTile(status: line.status, note: line.note)
                .accessibilityIdentifier("project.tile.\(line.id)")
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    // `strikethrough` while it is still a `Text`, before `lineLimit` makes it a view.
                    Text(line.note.title)
                        .strikethrough(isCalledOff)
                        .font(Txt.listTitle)
                        .lineLimit(1)
                        .foregroundStyle(isOver ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                    Spacer(minLength: 6)
                    if line.status != .active {
                        Pill(text: line.status.label, color: line.status.tint(onNote: ParaKind.project.tint))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    secondLine
                    Spacer(minLength: 0)
                    if !line.weekly.isEmpty {
                        // Build 255: the tasks finished each week, newest on the right. Nothing
                        // at all when no finished task carries a date: empty bars would say
                        // "you did nothing" (build 141).
                        WeekBars(weekly: line.weekly, height: 12)
                            .accessibilityIdentifier("project.weekly.\(line.id)")
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// The one second line. Named `project.next.<path>` with the need as its spoken words
    /// ("Next: …") on a live project, and `project.endedDay.<path>` saying "Ended on …" on one
    /// that is over — the names the screen tests have read since builds 211 and 269.
    @ViewBuilder
    private var secondLine: some View {
        let second = secondText
        if isOver {
            Text(second.text)
                .font(Txt.listSecond)
                .foregroundStyle(.soft)
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(endedSpoken)
                .accessibilityIdentifier("project.endedDay.\(line.id)")
        } else {
            // The count is its own words, so a screen reader and the tests hear "0 of 2" and
            // then the need; the need element keeps its old name and its "Next: …" label.
            HStack(spacing: 4) {
                if let count = second.count {
                    Text(count + " \u{00B7}")
                        .lineLimit(1)
                        .fixedSize()
                }
                Text(second.text)
                    .lineLimit(1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(needWords)
                    .accessibilityIdentifier("project.next.\(line.id)")
            }
            .font(Txt.listSecond)
            // Red when a date has passed; orange ("look at this") when the project is due
            // after its goal, as the card said it (build 253); grey otherwise.
            .foregroundStyle(second.late ? AnyShapeStyle(Color.red)
                             : second.attention ? AnyShapeStyle(Theme.attention) : AnyShapeStyle(.secondary))
        }
    }

    /// The facts of the second line, most telling first, joined with a middle dot; `late` when
    /// one of them is a date that has passed on a running project. Assembled here rather than
    /// in the body, where a loop and `var` are not allowed (build 58).
    private var secondText: (count: String?, text: String, late: Bool, attention: Bool) {
        let today = DateOnly.today()
        var parts: [String] = []
        var count: String?
        var late = false
        var attention = false
        if isOver {
            if let ended = line.ended {
                // Build 269: the day it ended, "20 October". An old project with no `ended:`
                // day gets nothing, never a guessed day (build 262).
                parts.append("Ended " + ProjectEnding.dayText(ended, today: today))
            }
            if case .allFinished(let count) = line.need {
                parts.append(ProjectLine.finishedText(count: count))
            }
        } else {
            if line.total > 0, line.openCount > 0 { count = "\(line.done) of \(line.total)" }
            parts.append(needWords)
            if let next = line.nextTask {
                if useTaskTimes, let minutes = next.minutes { parts.append(TaskTime.label(minutes)) }
                if let due = next.dueDate {
                    parts.append(due.timeLeftText(from: today))
                    if isRunning, due < today { late = true }
                }
            }
            if let deadline = line.deadline {
                parts.append(ProjectLine.deadlineText(deadline, today: today))
                if isRunning, line.deadlinePassed { late = true }
            }
            if isRunning, line.overdueCount > 0 {
                parts.append(ProjectLine.overdueText(line.overdueCount))
                late = true
            }
            if isRunning, line.dueAfterGoal { parts.append("Due after its goal"); attention = true }
        }
        if let goal = line.goal {
            if goal.relativePath != under?.relativePath { parts.append(goal.title) }
        } else if line.goalIsMissing, let name = line.note.goal {
            parts.append("No goal called \(name)")
        }
        return (count, parts.joined(separator: " \u{00B7} "), late, attention)
    }

    /// The need line in words, set as its label: one element with one sentence reads the same
    /// on both platforms, where a combined one keeps its words in different places (build 196).
    /// Calm grey for "no next action": it is true of most of his projects today, and orange for
    /// it would read as a telling-off (build 132).
    private var needWords: String {
        switch line.need {
        case .next: return "Next: " + (line.nextTitle ?? "")
        case .allFinished(let count):
            return ProjectLine.finishedText(count: count) + (line.status == .active ? " \u{00B7} No next action" : "")
        case .waitingOnly(let count):
            // Build 279: every open line is waiting for somebody else. The same calm grey as
            // "All finished": there is no next action, but not "finished", which would be false.
            return ProjectLine.waitingText(count: count) + (line.status == .active ? " \u{00B7} No next action" : "")
        case .noTasks: return "No tasks yet"
        }
    }

    /// "Ended on 20 October", the day first, as the screen test reads it (build 269).
    private var endedSpoken: String {
        if let ended = line.ended {
            return "Ended on " + ProjectEnding.dayText(ended, today: DateOnly.today())
        }
        return secondText.text
    }
}

/// Small bars, one per week for the last eight weeks, newest on the right (build 255). A week
/// with nothing finished is a short grey stub, so the row keeps its shape. Shapes keep their
/// colour on a selected row (build 200).
struct WeekBars: View {
    let weekly: WeeklyFinished
    var barWidth: CGFloat = 4
    var height: CGFloat = 16
    /// The colour of a week with something finished: a project's green here, an area's pink on
    /// the area's own page (build 270).
    var tint: Color = ParaKind.project.tint

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            // Over the indices, never `enumerated()`: a `ForEach` id is a key path, and a key
            // path cannot reach into a tuple (build 61).
            ForEach(weekly.counts.indices, id: \.self) { index in
                bar(weekly.counts[index])
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekly.spoken)
    }

    private func bar(_ count: Int) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(count == 0 ? Color.secondary.opacity(0.3) : tint)
            .frame(width: barWidth,
                   height: count == 0 ? 2 : max(3, height * CGFloat(count) / CGFloat(weekly.biggest)))
    }
}

/// One short fact on a box. A struct, never a tuple: a `ForEach` id is a key path, and a key
/// path cannot reach into a tuple (build 61).
struct ProjectFact: Identifiable {
    let id: String
    let text: String
    var markName: String? = nil
    var tint: Color = .secondary
    /// Dashed and unfilled: something missing rather than something there, as everywhere in
    /// PARAGON (`StateToggle` off, a loose Map box).
    var dashed: Bool = false
    /// A name for the screen tests. A pill that has one is drawn as one element whose label
    /// is `spoken`, or its words when there is none (build 269).
    var identifier: String? = nil
    var spoken: String? = nil
}

/// A pill: words, an optional symbol, a light fill and a thin border in one colour.
struct ProjectPill: View {
    let fact: ProjectFact
    var lines: Int = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let symbol = fact.markName {
                MarkImage(symbol)
            }
            Text(fact.text)
                .lineLimit(lines)
                .multilineTextAlignment(.leading)
        }
        .font(Txt.label)
        .rowTint(fact.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(fact.tint.opacity(fact.dashed ? 0 : 0.12),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(fact.tint.opacity(fact.dashed ? 0.6 : 0.4),
                              style: StrokeStyle(lineWidth: 1, dash: fact.dashed ? [3, 2] : []))
        )
    }
}

/// A small bar and "5 of 8 finished". Drawn rather than a `ProgressView`, so it looks the same
/// on both platforms. A shape, so it keeps its colour on a selected row (build 200).
struct ProjectProgress: View {
    let done: Int
    let total: Int

    private var fraction: CGFloat {
        total > 0 ? CGFloat(done) / CGFloat(total) : 0
    }

    var body: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule().fill(ParaKind.project.tint.opacity(0.2))
                Capsule().fill(ParaKind.project.tint).frame(width: 40 * fraction)
            }
            .frame(width: 40, height: 5)
            Text(ProjectLine.progressText(done: done, total: total))
                .font(Txt.label)
                .foregroundStyle(.soft)
        }
    }
}

/// The square at the left of a box. What it shows, in this order (`Note.ownIcon`, Core):
/// his **icon** on its colour (build 274, the AMS-Icons package); else an old **emoji** in a
/// solid frame, exactly as before (build 254) until an icon replaces it; else just a colour he
/// picked, with the project's first letter on it; else the project flag in a dashed frame —
/// dashed means "not set yet" everywhere in PARAGON (build 142).
///
/// **Automatic looks like the project's status**: green while it is running or done, grey when
/// it is on hold, missed, dropped or archived. An icon on Automatic takes that colour too, so
/// a project on hold still reads as one; a colour he chose himself is always that colour.
struct ProjectTile: View {
    let status: NoteStatus
    let note: Note

    private var tint: Color {
        status == .active || status == .done ? ParaKind.project.tint : Color.secondary
    }

    /// The old emoji, when that is what the tile shows.
    private var emoji: String? {
        if case .emoji(let value) = note.ownIcon { return value }
        return nil
    }

    var body: some View {
        face
            // One element saying what is in the tile, so a screen test can read it.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
    }

    /// 1.0: the row's mark is the note's own icon on its colour, or the 8-point dot every list
    /// row has (`NoteRow`'s rule). Only an old emoji keeps the small frame it always had.
    @ViewBuilder
    private var face: some View {
        if note.ownIcon.isIconOrColour {
            NoteIconTile(note: note, fallbackTint: tint, size: 30)
        } else if emoji != nil {
            framedMark
                .frame(width: 30, height: 30)
        } else {
            TintStripe(color: tint)
        }
    }

    /// The old emoji or the project flag, in the frame this tile has always had.
    private var framedMark: some View {
        mark
            .frame(width: 30, height: 30)
            .background(tint.opacity(emoji == nil ? 0.10 : 0.16),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(tint.opacity(0.6),
                                  style: StrokeStyle(lineWidth: 1.2, dash: emoji == nil ? [3, 2] : []))
            )
    }

    @ViewBuilder
    private var mark: some View {
        if let emoji {
            Text(emoji)
                .font(Txt.sectionTitle)
        } else {
            MarkImage(ChainSymbol.project)
                .font(Txt.listTitle)
                .rowTint(tint)
        }
    }

    /// The icon's own name ("Bike"), the old emoji, or "Project".
    private var spoken: String {
        switch note.ownIcon {
        case .icon:
            if let name = NoteIconTile.iconName(of: note) { return name }
            return "Icon"
        case .emoji(let value):
            return value
        case .colour, .unset:
            return "Project"
        }
    }
}
