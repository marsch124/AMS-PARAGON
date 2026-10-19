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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func row(_ line: ProjectLine, in group: ProjectGroup) -> some View {
        ProjectBox(line: line, under: aspiration(of: group), framed: !isPhone)
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
        let status = note.noteStatus
        Button("Rename\u{2026}") { rename(note) }
        NoteGoalMenu(model: model, note: note)
        Divider()
        if status != .active {
            Button("Set active") { model.setStatus(NoteStatus.active, for: note) }
        }
        ForEach(NoteStatus.endings, id: \.self) { ending in
            if ending != status {
                Button("Mark \(ending.label.lowercased())") { model.setStatus(ending, for: note) }
            }
        }
        if status == .active {
            Button("Put on hold") { model.setStatus(NoteStatus.onHold, for: note) }
        }
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
            let advice = "Their goal has no aspiration yet. In Goals, press Give it an aspiration under that goal."
            // A dashed goal name cannot be fixed in Goals: there is no such goal there (build
            // 254, from the review of 253). It needs the project's own Serves.
            guard group.lines.contains(where: \.goalIsMissing) else { return advice }
            return advice + (isPhone
                ? " A goal name with a dashed line was not found: press and hold the project and choose Serves."
                : " A goal name with a dashed line was not found: right-click the project and choose Serves.")
        case .noGoal:
            return isPhone
                ? "Press and hold a project and choose Serves to give it a goal."
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

/// The heading of one group: a band in the colour of what the group is, its badge, its name,
/// how many projects it holds, and how many want a look. **The whole line folds**, never a
/// small triangle (build 205), and it is a header, so it never takes the selection (build 201).
struct ProjectGroupHeader: View {
    let group: ProjectGroup
    let open: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(open ? 90 : 0))
                badge
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(group.isEnded ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(group.lines.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                if group.needsALookCount > 0 {
                    // Orange, as everywhere in PARAGON: look at this. On the heading, so a
                    // folded group still says it (build 100).
                    Label("\(group.needsALookCount)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            // The whole line, never a `Spacer` beside a short button: the Mac reported a wrong
            // frame for that shape and a test's click landed in the list (build 247).
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background { band }
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
        if group.needsALookCount > 0 { words += ", \(group.needsALookCount) need a look" }
        return words
    }

    /// The same badge the Goals rooms draw for the same thing, so a heading here and a row
    /// there are one picture (build 168).
    @ViewBuilder
    private var badge: some View {
        switch group.heading {
        case .aspiration:
            KindBadge(kind: .goal, size: 20, systemImage: ChainSymbol.aspiration, tint: ChainTint.aspiration)
        case .notLinked:
            KindBadge(kind: .goal, size: 20, systemImage: ChainSymbol.datedGoal, tint: ChainTint.datedGoal)
        case .noGoal:
            // Dashed and grey: not connected, as on the Map (build 82).
            Image(systemName: ChainSymbol.datedGoal)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.7),
                                               style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        case .ended(let status):
            Image(systemName: status.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(endedTint(status))
                .frame(width: 20, height: 20)
        }
    }

    /// The colours the status chip gives the same three words (build 165): done in the
    /// project's own green, missed orange, dropped grey — a decision, not a failure.
    private func endedTint(_ status: NoteStatus) -> Color {
        switch status {
        case .done: return ParaKind.project.tint
        case .missed: return .orange
        default: return .secondary
        }
    }

    @ViewBuilder
    private var band: some View {
        switch group.heading {
        case .aspiration:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(ChainTint.aspiration.opacity(0.14))
        case .notLinked:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(ChainTint.datedGoal.opacity(0.11))
        case .noGoal:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        case .ended:
            Color.clear
        }
    }
}

/// One project as a box: a tile, its name on up to two lines, what it needs, the goal it
/// serves, and a row of short pills. **Every text colour goes through `rowTint`**, because the
/// selection fill is his own accent colour and an explicit colour on it can vanish (build 200).
struct ProjectBox: View {
    let line: ProjectLine
    /// The aspiration whose heading this box sits under. A goal pill that would only name it
    /// again is left out (build 169).
    var under: Note? = nil
    /// Its own frame on the Mac. On the phone the section's rounded card is already the box,
    /// and a frame inside it would be a box in a box.
    var framed: Bool = true
    @AppStorage(TaskTimeSetting.key) private var useTaskTimes = true

    private var isOver: Bool { line.status.isEnded || line.status == .archived }
    private var isCalledOff: Bool { line.status == .missed || line.status == .dropped }
    /// Only a project still running can be late. A passed deadline on one that is on hold or
    /// over is a fact, drawn grey, never red.
    private var isRunning: Bool { line.status == .active }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProjectTile(status: line.status, emoji: line.note.emoji)
                .accessibilityIdentifier("project.tile.\(line.id)")
            VStack(alignment: .leading, spacing: 5) {
                // `strikethrough` while it is still a `Text`, before `lineLimit` makes it a view.
                Text(line.note.title)
                    .strikethrough(isCalledOff)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(isOver ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                need
                goalLine
                if !facts.isEmpty || showsProgress {
                    WrappingHStack(spacing: 6, lineSpacing: 4) {
                        if showsProgress {
                            ProjectProgress(done: line.done, total: line.total)
                        }
                        ForEach(facts) { fact in
                            ProjectPill(fact: fact)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(framed ? 10 : 2)
        .background {
            if framed {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isOver ? Color.clear : ParaKind.project.tint.opacity(0.07))
            }
        }
        .overlay {
            if framed {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder((isOver ? Color.secondary : ParaKind.project.tint).opacity(isOver ? 0.3 : 0.45),
                                  lineWidth: 1)
            }
        }
        .padding(.vertical, framed ? 3 : 2)
    }

    /// The line that says what the project needs. Calm grey for "no next action": it is true of
    /// most of his projects today, and orange for it would read as a telling-off (build 132).
    @ViewBuilder
    private var need: some View {
        switch line.need {
        case .next:
            Label {
                Text("Next: " + (line.nextTitle ?? ""))
                    .lineLimit(2)
            } icon: {
                Image(systemName: ChainSymbol.task)
                    .rowTint(ParaKind.project.tint)
            }
            .font(.subheadline)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(needWords)
            .accessibilityIdentifier("project.next.\(line.id)")
        case .allFinished(let count):
            WrappingHStack(spacing: 6, lineSpacing: 4) {
                Label(ProjectLine.finishedText(count: count), systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .rowTint(ParaKind.project.tint)
                if line.status == .active {
                    ProjectPill(fact: ProjectFact(id: "noNext", text: "No next action",
                                                  systemImage: "circle.dashed", dashed: true))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(needWords)
            .accessibilityIdentifier("project.next.\(line.id)")
        case .noTasks:
            ProjectPill(fact: ProjectFact(id: "noTasks", text: "No tasks yet",
                                          systemImage: "circle.dashed", dashed: true))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(needWords)
                .accessibilityIdentifier("project.next.\(line.id)")
        }
    }

    /// The need line in words, set as its label: one element with one sentence reads the same
    /// on both platforms, where a combined one keeps its words in different places (build 196).
    private var needWords: String {
        switch line.need {
        case .next: return "Next: " + (line.nextTitle ?? "")
        case .allFinished(let count):
            return ProjectLine.finishedText(count: count) + (line.status == .active ? ". No next action" : "")
        case .noTasks: return "No tasks yet"
        }
    }

    /// The goal it serves, on a line of its own so a long name wraps instead of squeezing the
    /// pills (build 138). Dashed and grey when the `goal:` line names nothing that exists.
    @ViewBuilder
    private var goalLine: some View {
        if let goal = line.goal {
            if goal.relativePath != under?.relativePath {
                ProjectPill(fact: ProjectFact(id: "goal", text: goal.title,
                                              systemImage: ChainSymbol.forGoal(goal),
                                              tint: ChainTint.forGoal(goal)),
                            lines: 2)
            }
        } else if line.goalIsMissing, let name = line.note.goal {
            ProjectPill(fact: ProjectFact(id: "goal", text: name, systemImage: ChainSymbol.datedGoal, dashed: true),
                        lines: 2)
                .help("No goal has this name. Right-click the project and choose Serves.")
        }
    }

    private var showsProgress: Bool {
        guard case .next = line.need else { return false }
        return line.total > 0
    }

    /// The short facts, assembled here rather than in the body, where a loop and `var` are not
    /// allowed (build 58). Red only for a date that has passed; orange for "look at this".
    private var facts: [ProjectFact] {
        let today = DateOnly.today()
        var facts: [ProjectFact] = []
        if let next = line.nextTask {
            if useTaskTimes, let minutes = next.minutes {
                facts.append(ProjectFact(id: "time", text: TaskTime.label(minutes), systemImage: "clock"))
            }
            if let due = next.dueDate {
                facts.append(ProjectFact(id: "date", text: due.timeLeftText(from: today),
                                         systemImage: "calendar",
                                         tint: isRunning && due < today ? Color.red : Color.secondary))
            }
        }
        if line.status == .onHold {
            facts.append(ProjectFact(id: "onHold", text: NoteStatus.onHold.label,
                                     systemImage: NoteStatus.onHold.systemImage))
        }
        if let deadline = line.deadline, !isOver {
            facts.append(ProjectFact(id: "deadline", text: ProjectLine.deadlineText(deadline, today: today),
                                     systemImage: "flag.checkered",
                                     tint: isRunning && line.deadlinePassed ? Color.red : Color.secondary))
        }
        if isRunning, line.overdueCount > 0 {
            facts.append(ProjectFact(id: "overdue", text: ProjectLine.overdueText(line.overdueCount),
                                     systemImage: "exclamationmark.circle", tint: Color.red))
        }
        if isRunning, line.dueAfterGoal {
            facts.append(ProjectFact(id: "afterGoal", text: "Due after its goal",
                                     systemImage: "exclamationmark.triangle.fill", tint: Color.orange))
        }
        let tags = line.note.tags
        for tag in tags.prefix(2) {
            facts.append(ProjectFact(id: "tag." + tag, text: "#" + tag, tint: SidebarSection.tags.tint))
        }
        if tags.count > 2 {
            facts.append(ProjectFact(id: "moreTags", text: "+\(tags.count - 2)", tint: SidebarSection.tags.tint))
        }
        return facts
    }
}

/// One short fact on a box. A struct, never a tuple: a `ForEach` id is a key path, and a key
/// path cannot reach into a tuple (build 61).
struct ProjectFact: Identifiable {
    let id: String
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary
    /// Dashed and unfilled: something missing rather than something there, as everywhere in
    /// PARAGON (`StateToggle` off, a loose Map box).
    var dashed: Bool = false
}

/// A pill: words, an optional symbol, a light fill and a thin border in one colour.
struct ProjectPill: View {
    let fact: ProjectFact
    var lines: Int = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let symbol = fact.systemImage {
                Image(systemName: symbol)
            }
            Text(fact.text)
                .lineLimit(lines)
                .multilineTextAlignment(.leading)
        }
        .font(.caption)
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
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// The square at the left of a box: his own emoji in a solid frame (build 254), or the project
/// flag in a dashed one until he picks one — dashed means "not set yet" everywhere in PARAGON
/// (build 142). Green while the project is running or done, grey when it is on hold, missed,
/// dropped or archived.
struct ProjectTile: View {
    let status: NoteStatus
    var emoji: String? = nil

    private var tint: Color {
        status == .active || status == .done ? ParaKind.project.tint : Color.secondary
    }

    var body: some View {
        mark
            .frame(width: 34, height: 34)
            .background(tint.opacity(emoji == nil ? 0.10 : 0.16),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(tint.opacity(0.6),
                                  style: StrokeStyle(lineWidth: 1.2, dash: emoji == nil ? [3, 2] : []))
            )
            // One element saying what is in the tile, so a screen test can read the emoji.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(emoji ?? "Project")
    }

    @ViewBuilder
    private var mark: some View {
        if let emoji {
            Text(emoji)
                .font(.system(size: 19))
        } else {
            Image(systemName: ChainSymbol.project)
                .font(.system(size: 14, weight: .semibold))
                .rowTint(tint)
        }
    }
}

/// **Emoji…** in a project's header (build 254): grey and dashed until one is picked, then the
/// emoji itself in a green frame. Pressing it opens `EmojiChoices`. It writes `emoji:` in the
/// settings block, so the choice travels with the note to the other device.
struct ProjectEmojiChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var picking = false

    /// Read back from the model rather than kept: choosing saves and reloads, and the copy
    /// handed to this view a moment ago is then one behind (build 144's `NoteTagsChip`).
    private var live: Note { model.note(at: note.relativePath) ?? note }

    var body: some View {
        let emoji = live.emoji
        Button { picking = true } label: {
            chipFace(emoji)
                .helpWhenClosed("Choose an emoji for this project. It is shown in the Projects list.",
                                open: picking)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emoji.map { "Emoji \($0)" } ?? "Choose an emoji")
        .accessibilityIdentifier("note.emoji")
        .popover(isPresented: $picking) {
            EmojiChoices(current: emoji) { chosen in
                model.setEmoji(chosen, on: live)
                picking = false
            }
        }
    }

    @ViewBuilder
    private func chipFace(_ emoji: String?) -> some View {
        Group {
            if let emoji {
                Text(emoji)
            } else {
                Label("Emoji\u{2026}", systemImage: "face.smiling")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .overlay(
            Capsule().strokeBorder((emoji == nil ? Color.secondary : ParaKind.project.tint).opacity(0.6),
                                   style: StrokeStyle(lineWidth: 1, dash: emoji == nil ? [3, 2] : []))
        )
        .contentShape(Capsule())
    }
}

/// The list **Emoji…** opens: four rows of choices, a field for any other emoji, and **Remove
/// emoji** when one is set. The choices are `ProjectEmoji.groups` (Core, tested).
struct EmojiChoices: View {
    let current: String?
    let choose: (String?) -> Void
    @State private var typed = ""

    private var typedEmoji: String? { ProjectEmoji.cleaned(typed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Emoji for this project")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ProjectEmoji.groups) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            ForEach(group.emoji, id: \.self) { emoji in
                                choice(emoji)
                            }
                        }
                    }
                }
            }
            // A list of buttons: the first would otherwise take keyboard focus and be ringed
            // in his accent colour, reading as a second choice (build 202). The field below
            // keeps its ring, which is useful there.
            .focusEffectDisabled()
            HStack(spacing: 6) {
                TextField("Or type any emoji", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(useTyped)
                Button("Use", action: useTyped)
                    .disabled(typedEmoji == nil)
            }
            #if os(macOS)
            Text("Control-Command-Space shows every emoji there is.")
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
            if current != nil {
                Button("Remove emoji", role: .destructive) { choose(nil) }
                    .accessibilityIdentifier("emoji.remove")
            }
        }
        .padding(14)
        .frame(width: 290)
        // A small list beside the button on the phone too, as the tag list is, rather than a
        // whole sheet for 24 emoji.
        .presentationCompactAdaptation(.popover)
    }

    private func choice(_ emoji: String) -> some View {
        let chosen = emoji == current
        return Button { choose(emoji) } label: {
            Text(emoji)
                .font(.title2)
                .frame(width: 38, height: 38)
                .background(chosen ? ParaKind.project.tint.opacity(0.2) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(chosen ? ParaKind.project.tint : Color.clear, lineWidth: 1.2)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emoji)
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
        .accessibilityIdentifier("emoji.choice.\(emoji)")
    }

    private func useTyped() {
        guard let emoji = typedEmoji else { return }
        choose(emoji)
    }
}
