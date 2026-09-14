import SwiftUI
import ParagonCore

/// The Goals section, build 162 — the shape he chose from a preview of three
/// (https://claude.ai/code/artifact/5ccd27ac-0b62-4895-8e62-b575ca226861, "B: the chain, top
/// to bottom").
///
/// The middle column lists the **aspirations** — the handful of things you are becoming —
/// and picking one draws the whole chain under it: the dated goals that serve it, the
/// projects under each goal, and the one next action under each project. One screen answers
/// "am I actually doing anything about this?".
///
/// Two groups exist so nothing can hide: aspirations with nothing under them yet, and dated
/// goals with no aspiration above them. Neither is a fault — a goal can stand on its own —
/// but a list that quietly leaves them out is build 100's rule broken again.
///
/// **The phone folds the chain open in the row instead of pushing a screen.** That is the
/// `TagsView` precedent (build 143): a second screen would need its own `PhoneRoute` and a
/// second layout to keep working, and the chain reads perfectly well as one scroll.
struct AspirationsListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var opened: Set<String> = []
    /// Closed to begin with: a goal that is over is something you look back at on purpose.
    @AppStorage("goalsReachedFolded") private var endedFolded = true
    /// **One at a time**, or every aspiration at once (build 166, his ask). One key, read by
    /// this column and by the detail column, so the button and what it shows cannot disagree.
    @AppStorage(GoalsShowAll.key) private var showAll = false
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isPhone: Bool { horizontalSizeClass == .compact }
#else
    private var isPhone: Bool { false }
#endif

    var body: some View {
        let chains = model.index.aspirationChains()
        let held = chains.filter { !$0.isBare }
        let bare = chains.filter(\.isBare)
        let loose = model.index.goalsOutsideAnyAspiration()
        let ended = model.index.endedGoals()
        Group {
            if chains.isEmpty && loose.isEmpty && ended.isEmpty {
                EmptyStateView(title: "No goals yet",
                               systemImage: SidebarSection.kind(.goal).systemImage,
                               message: "An aspiration says what you are becoming. A goal with a target date says what you will have done. Make one and the chain under it appears here.",
                               tint: ParaKind.goal.tint,
                               actionTitle: "New goal\u{2026}") { model.activeSheet = .newNote }
            } else if isPhone {
                phoneList(held: held, bare: bare, loose: loose, ended: ended)
            } else {
                deskList(held: held, bare: bare, loose: loose, ended: ended)
            }
        }
        .navigationTitle("Goals")
    }

    // MARK: The Mac — a list that fills the third column

    private func deskList(held: [AspirationChain], bare: [AspirationChain], loose: [Note],
                          ended: [(status: NoteStatus, notes: [Note])]) -> some View {
        List(selection: model.noteSelection) {
            if !held.isEmpty {
                Section("Aspirations") {
                    ForEach(held) { chain in
                        AspirationRow(chain: chain)
                            .tag(chain.note.relativePath)
                            .contextMenu { rowMenu(chain.note) }
                    }
                }
            }
            if !bare.isEmpty {
                Section("Nothing serves these yet") {
                    ForEach(bare) { chain in
                        AspirationRow(chain: chain)
                            .tag(chain.note.relativePath)
                            .contextMenu { rowMenu(chain.note) }
                    }
                }
            }
            if !loose.isEmpty {
                Section {
                    ForEach(loose) { note in
                        DatedGoalRow(note: note)
                            .tag(note.relativePath)
                            .contextMenu { rowMenu(note) }
                    }
                } header: {
                    Label("Goals with no aspiration", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            ForEach(ended, id: \.status) { group in
                endedSection(group.status, group.notes)
            }
        }
    }

    /// A goal that is over drops out of the lists above and gathers here, closed, **under the
    /// name of its ending** — Done, Missed or Dropped (builds 163 and 165). It is history
    /// rather than work, but it is never hidden altogether.
    @ViewBuilder
    private func endedSection(_ status: NoteStatus, _ notes: [Note]) -> some View {
        Section {
            if !endedFolded {
                ForEach(notes) { note in
                    DatedGoalRow(note: note)
                        .tag(note.relativePath)
                        .contextMenu { rowMenu(note) }
                }
            }
        } header: {
            endedHeader(status, notes.count)
        }
    }

    private func endedHeader(_ status: NoteStatus, _ count: Int) -> some View {
        Button {
            endedFolded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: endedFolded ? "chevron.right" : "chevron.down")
                    .font(.caption2)
                Text(status.label)
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 5)
                    .background(.quaternary, in: Capsule())
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: The phone — the chain folds open in place

    private func phoneList(held: [AspirationChain], bare: [AspirationChain], loose: [Note],
                           ended: [(status: NoteStatus, notes: [Note])]) -> some View {
        List {
            if !held.isEmpty {
                Section("Aspirations") {
                    ForEach(held) { chain in
                        foldingRow(chain)
                    }
                }
            }
            if !bare.isEmpty {
                Section("Nothing serves these yet") {
                    ForEach(bare) { chain in
                        foldingRow(chain)
                    }
                }
            }
            if !loose.isEmpty {
                Section("Goals with no aspiration") {
                    ForEach(loose) { note in
                        looseRow(note)
                    }
                }
            }
            ForEach(ended, id: \.status) { group in
                Section {
                    if !endedFolded {
                        ForEach(group.notes) { note in looseRow(note) }
                    }
                } header: {
                    endedHeader(group.status, group.notes.count)
                }
            }
        }
    }

    private func looseRow(_ note: Note) -> some View {
        Button {
            model.show(section: .kind(.goal), notePath: note.relativePath)
        } label: {
            DatedGoalRow(note: note)
        }
        .buttonStyle(.plain)
    }

    /// One aspiration on the phone: a plain `Button`, never a selection tag, because a list
    /// whose rows carry a tag takes the click away from anything inside them (builds 71–74).
    @ViewBuilder
    private func foldingRow(_ chain: AspirationChain) -> some View {
        // While **All of them** is on every chain is open, because that is what the button
        // means. The chevron still works; it just starts open.
        let isOpen = showAll || opened.contains(chain.note.relativePath)
        Button {
            if showAll { showAll = false; opened = [chain.note.relativePath]; return }
            if isOpen { opened.remove(chain.note.relativePath) } else { opened.insert(chain.note.relativePath) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                AspirationRow(chain: chain)
            }
        }
        .buttonStyle(.plain)
        if isOpen {
            AspirationChainBody(chain: chain, compact: true)
                .padding(.leading, 10)
                .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private func rowMenu(_ note: Note) -> some View {
        Button("Open the note") { model.show(section: .kind(.goal), notePath: note.relativePath) }
        if model.canArchive(note) {
            Button("Archive") { model.archive(note) }
        }
    }
}

/// The symbol for each link in the chain, in one place so the list, the chain and the header
/// can never show three different pictures of the same thing (build 164, his ask).
///
/// **An aspiration and a dated goal share the `.goal` kind but not the idea.** The aspiration
/// keeps the **star** — the north star on the app's own icon, the thing you steer by and never
/// tick off — and a goal with a target date gets a **target**, which is what you aim at and
/// hit on a day. Everything below them already had a symbol and keeps it: a project is a flag,
/// an area is the four squares, a task is the plain ring the Done list and every checkbox use.
///
/// **Build 168 finished the job 164 started.** 164 split the two apart here and nowhere else,
/// so the sidebar row named **Goals** still wore the star and every `goal:` chip in the app
/// did too. The star is now spelled **once**, here, and means an aspiration wherever it is
/// drawn; the dated goal reads its symbol back out of `SidebarSection`, so the row and the
/// chip cannot drift apart again.
enum ChainSymbol {
    /// The one place the star is spelled. It means an aspiration, and nothing else.
    static let aspiration = "star"
    static let datedGoal = SidebarSection.kind(.goal).systemImage   // target
    static let project = SidebarSection.kind(.project).systemImage  // flag
    static let area = SidebarSection.kind(.area).systemImage        // circle.grid.2x2
    static let task = SidebarSection.allActions.systemImage         // circle

    /// The right one for a goal note, whichever kind of goal it is.
    static func forGoal(_ note: Note) -> String {
        (note.horizon ?? .year) == .life ? aspiration : datedGoal
    }

    /// The right one for a `goal:` line, which may name either kind. A name with no note
    /// behind it gets the dated goal's target: it is the section's own mark, so an unresolved
    /// link never claims to be an aspiration.
    static func forGoal(named reference: String, in index: NoteIndex) -> String {
        // Written out rather than `.map(forGoal)`: `forGoal` is overloaded now, and there is
        // no Swift compiler here to settle which one a bare function reference means.
        guard let note = index.goal(matching: reference) else { return datedGoal }
        return forGoal(note)
    }
}

/// One aspiration in the list: its name, how many goals serve it, and how far they have come.
struct AspirationRow: View {
    @EnvironmentObject private var model: AppModel
    let chain: AspirationChain

    var body: some View {
        HStack(spacing: 10) {
            KindBadge(kind: .goal, size: 24, systemImage: ChainSymbol.aspiration)
            VStack(alignment: .leading, spacing: 3) {
                Text(chain.note.title)
                    .font(.headline)
                    .lineLimit(2)
                WrappingHStack(spacing: 8, lineSpacing: 4) {
                    if chain.progress.fraction != nil {
                        GoalProgressBar(progress: chain.progress, width: 56, showsCounts: false)
                    }
                    if !chain.goals.isEmpty {
                        Text(chain.goals.count == 1 ? "1 goal" : "\(chain.goals.count) goals")
                            .foregroundStyle(ParaKind.goal.tint)
                    }
                    if let area = chain.area {
                        Label(area.title, systemImage: ChainSymbol.area)
                            .foregroundStyle(ParaKind.area.tint)
                    }
                    let wanting = chain.goalsNeedingAttention.count
                    if wanting > 0 {
                        Label(wanting == 1 ? "1 goal needs attention" : "\(wanting) goals need attention",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    if chain.needsAttention {
                        Label(chain.flags.first?.label ?? "Needs attention",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .lineLimit(1)
                // The measure, on the row rather than only inside the goal (build 163).
                if let measure = chain.note.measure, !measure.isEmpty {
                    Text(measure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// One dated goal in a list: its target with how long is left, how far it has come, whether it
/// wants attention, and what it is measured by. Build 163 — all four are his small extras, and
/// they are one row so the list never says two of the four and leaves you guessing.
struct DatedGoalRow: View {
    @EnvironmentObject private var model: AppModel
    let note: Note

    var body: some View {
        let health = model.index.chainGoal(of: note)
        HStack(spacing: 10) {
            KindBadge(kind: .goal, size: 24, systemImage: ChainSymbol.forGoal(note))
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    // Struck through however it ended: done, missed or dropped, it is over.
                    .strikethrough(note.isEnded)
                    .font(.headline)
                    .lineLimit(2)
                WrappingHStack(spacing: 8, lineSpacing: 4) {
                    if health.progress.fraction != nil {
                        GoalProgressBar(progress: health.progress, width: 56, showsCounts: false)
                    }
                    if let target = note.targetDate {
                        let left = target.timeLeftText(from: .today())
                        Label("\(target.description) · \(left)", systemImage: "flag")
                            .foregroundStyle(overdue(target) ? Color.orange : ParaKind.goal.tint)
                    }
                    if note.isEnded {
                        Label(note.noteStatus.label, systemImage: note.isAchieved ? "checkmark.seal" : "xmark.circle")
                            .foregroundStyle(note.isAchieved ? ParaKind.goal.tint : Color.secondary)
                    } else if needsAnAspiration {
                        NoAspirationPrompt(model: model, note: note)
                    } else if health.needsAttention, let first = health.flags.first {
                        Label(first.label, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .lineLimit(1)
                if let measure = note.measure, !measure.isEmpty {
                    Text(measure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func overdue(_ target: DateOnly) -> Bool {
        !note.isEnded && target < .today()
    }

    /// A live dated goal with nothing above it. An aspiration itself never needs one.
    private var needsAnAspiration: Bool {
        guard !note.isEnded, (note.horizon ?? .year) != .life else { return false }
        guard let reference = note.goal else { return true }
        return model.index.goal(matching: reference)?.horizon != .life
    }
}

/// The third column while the Goals section is open: the chain under the chosen aspiration,
/// or the note itself when the button in the header is turned on.
struct GoalDetailView: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    /// Per note, because the view is given `.id(path)` — picking another goal starts on the
    /// chain again, never on the note text of the one before.
    @State private var showsNote = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showsNote {
                NoteEditorView(path: note.relativePath)
            } else {
                ScrollView {
                    if isAspiration {
                        AspirationChainBody(chain: model.index.chain(of: note), compact: false)
                            .padding(Theme.gutter)
                    } else {
                        ChainGoalBlock(goal: model.index.chainGoal(of: note), lead: true)
                            .padding(Theme.gutter)
                    }
                }
            }
        }
    }

    private var isAspiration: Bool { (note.horizon ?? .year) == .life }

    private var header: some View {
        GoalsHeader(title: showsNote ? "Note" : (isAspiration ? "Aspiration" : "Goal"),
                    systemImage: showsNote ? "doc.text" : ChainSymbol.forGoal(note)) {
            // Build 159's two-state control: it shows the state you are in, not the one you
            // would get.
            StateToggle(systemImage: "doc.text", title: "Note",
                        isOn: showsNote, tint: ParaKind.goal.tint) {
                showsNote.toggle()
            }
        }
    }
}

/// An aspiration drawn as the chain beneath it.
struct AspirationChainBody: View {
    @EnvironmentObject private var model: AppModel
    let chain: AspirationChain
    /// The phone folds this open inside a list row, so it drops the big header.
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !compact { head }
            if chain.isBare {
                Text("Nothing works towards this yet. Give a goal with a target date `goal: \(chain.note.title)`, or press **Serves…** in that goal's header.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let changed = chain.activity.summary {
                Label(changed, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            ForEach(chain.goals) { goal in
                ChainGoalBlock(goal: goal, lead: false, under: chain.note.title)
            }
            // One heading per ending, never one heading for all three: a group called Done
            // may not hold a goal that was missed (build 165).
            ForEach(endedGroups, id: \.status) { group in
                SectionLabel(title: group.status.label, count: group.goals.count,
                             systemImage: group.status == .done ? "checkmark.seal" : "xmark.circle",
                             tint: group.status == .done ? ParaKind.goal.tint : .secondary)
                ForEach(group.goals) { goal in
                    endedRow(goal)
                }
            }
            if !chain.projects.isEmpty {
                SectionLabel(title: "Straight under the aspiration", count: nil,
                             systemImage: "shippingbox", tint: ParaKind.project.tint)
                ForEach(chain.projects) { project in
                    ChainProjectRow(project: project)
                }
            }
            if !chain.areas.isEmpty {
                SectionLabel(title: "Areas that hold this", count: nil,
                             systemImage: ChainSymbol.area, tint: ParaKind.area.tint)
                ForEach(chain.areas) { area in
                    Button { model.show(section: .kind(.goal), notePath: area.relativePath) } label: {
                        Label(area.title, systemImage: ChainSymbol.area)
                            .foregroundStyle(ParaKind.area.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The goals that are over, split by how they ended and in the order the menu offers.
    /// Worked out here rather than in the body: a `@ViewBuilder` takes views, not loops.
    private var endedGroups: [(status: NoteStatus, goals: [ChainGoal])] {
        NoteStatus.endings.compactMap { ending in
            let over = chain.endedGoals.filter { $0.note.noteStatus == ending }
            return over.isEmpty ? nil : (ending, over)
        }
    }

    private func endedRow(_ goal: ChainGoal) -> some View {
        Button { model.show(section: .kind(.goal), notePath: goal.note.relativePath) } label: {
            HStack(spacing: 6) {
                Image(systemName: ChainSymbol.datedGoal)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(goal.note.title)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let target = goal.note.targetDate {
                    Text(target.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private var head: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                KindBadge(kind: .goal, size: 26, systemImage: ChainSymbol.aspiration)
                Text(chain.note.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(3)
            }
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ChainChip(text: GoalHorizon.life.label, tint: ParaKind.goal.tint, filled: true)
                if let area = chain.area {
                    ChainChip(text: "In area: \(area.title)", tint: ParaKind.area.tint, filled: false)
                }
                if let measure = chain.note.measure, !measure.isEmpty {
                    ChainChip(text: "Measure: \(measure)", tint: .secondary, filled: false, dashed: true)
                }
                ForEach(chain.flags, id: \.self) { flag in
                    ChainChip(text: flag.label, tint: flag == .achieved ? ParaKind.goal.tint : .orange, filled: false)
                }
            }
            .lineLimit(2)
            if chain.progress.fraction != nil {
                GoalProgressBar(progress: chain.progress, width: 200)
            }
        }
    }
}

/// One dated goal with the projects that deliver it.
struct ChainGoalBlock: View {
    @EnvironmentObject private var model: AppModel
    let goal: ChainGoal
    /// True when this goal is the whole screen rather than one link in a chain.
    let lead: Bool
    /// The aspiration whose chain this row is being drawn inside, when there is one.
    ///
    /// **Build 169, his report.** The **Serves…** chip named that same aspiration on every
    /// goal under it, which is a sentence you are already looking at. It still appears when
    /// the goal stands on its own — opened by itself, or in **Goals with no aspiration** —
    /// where the answer is not on the screen already. Same family as build 153's grey page
    /// badge: not wrong, just carrying no information.
    var under: String? = nil

    /// What this goal is in service of, unless the screen already says so.
    private var servesToShow: String? {
        guard let serves = goal.note.goal, !serves.isEmpty else { return nil }
        // Written out rather than the `if let under` shorthand: there is no compiler here.
        if let shown = under, shown.localizedCaseInsensitiveCompare(serves) == .orderedSame {
            return nil
        }
        return serves
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { model.show(section: .kind(.goal), notePath: goal.note.relativePath) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: ChainSymbol.datedGoal)
                            .font(.caption)
                            .foregroundStyle(ParaKind.goal.tint)
                        Text(goal.note.title)
                            .font(lead ? .title3.weight(.semibold) : .headline)
                            .foregroundStyle(ParaKind.goal.tint)
                            .lineLimit(2)
                    }
                    WrappingHStack(spacing: 6, lineSpacing: 5) {
                        if let target = goal.note.targetDate {
                            // Build 163: the date alone never says whether it is close.
                            let left = target.timeLeftText(from: .today())
                            let late = !goal.isEnded && target < .today()
                            ChainChip(text: "Target \(target.description) · \(left)",
                                      tint: late ? .orange : ParaKind.goal.tint, filled: false)
                        }
                        if let serves = servesToShow {
                            // The extra he ticked: a dated goal says what it is in service of.
                            // Gold, because what it names is an aspiration — it was pink, the
                            // colour this app uses for an area (build 169).
                            ChainChip(text: "Serves \(serves)", tint: ParaKind.goal.tint, filled: false)
                        }
                        if let percent = goal.progress.percent {
                            ChainChip(text: "\(percent)%", tint: ParaKind.goal.tint, filled: true)
                        }
                        if lead, let measure = goal.note.measure, !measure.isEmpty {
                            ChainChip(text: "Measure: \(measure)", tint: .secondary, filled: false, dashed: true)
                        }
                        ForEach(goal.flags, id: \.self) { flag in
                            ChainChip(text: flag.label,
                                      tint: flag == .achieved ? ParaKind.goal.tint : .orange,
                                      filled: false)
                        }
                    }
                    .font(.caption)
                    .lineLimit(2)
                }
            }
            .buttonStyle(.plain)
            if lead, let changed = goal.activity.summary {
                Label(changed, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            rail
        }
    }

    /// The projects, drawn against a rail so the level is visible without indenting text.
    private var rail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if goal.projects.isEmpty && goal.finishedProjects.isEmpty {
                Text("No project delivers this goal yet.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            ForEach(goal.projects) { project in
                ChainProjectRow(project: project)
            }
            ForEach(goal.finishedProjects) { project in
                ChainProjectRow(project: project)
            }
            ForEach(goal.areas) { area in
                Button { model.show(section: .kind(.goal), notePath: area.relativePath) } label: {
                    Label(area.title, systemImage: ChainSymbol.area)
                        .font(.callout)
                        .foregroundStyle(ParaKind.area.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ParaKind.goal.tint.opacity(0.35))
                .frame(width: 1.5)
        }
        .padding(.leading, 4)
    }
}

/// One project under a goal, with the one thing to do next on it.
struct ChainProjectRow: View {
    @EnvironmentObject private var model: AppModel
    let project: ChainProject

    var body: some View {
        Button {
            model.show(section: .kind(.goal), notePath: project.note.relativePath)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: ChainSymbol.project)
                        .font(.caption2)
                        .foregroundStyle(project.note.isEnded ? Color.secondary : ParaKind.project.tint)
                    Text(project.note.title)
                        .font(.callout)
                        .strikethrough(project.note.isEnded)
                        .foregroundStyle(project.note.isEnded ? Color.secondary : ParaKind.project.tint)
                        .lineLimit(2)
                    // **Build 169: the count belongs to the project, so it sits next to it.**
                    // A `Spacer` pushed "2 open" out to the right edge of a wide column, far
                    // from the name it counts, and with several projects the numbers formed a
                    // column of their own that read as a separate list.
                    if project.note.isEnded {
                        Text(project.note.noteStatus.label.lowercased())
                            .font(.caption2).foregroundStyle(.secondary)
                    } else if project.openTaskCount > 0 {
                        Text("\(project.openTaskCount) open").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if let next = project.nextAction {
                    Label("Next: \(next.title)", systemImage: ChainSymbol.task)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if project.hasNothingToDo {
                    Text("No next action")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// One fact about a goal. The same two-state language as `FilterBox` and `StateToggle`:
/// solid when it is something the note says, dashed when it is only a note to the reader.
struct ChainChip: View {
    let text: String
    var tint: Color = .secondary
    var filled: Bool = false
    var dashed: Bool = false

    var body: some View {
        Text(text)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(filled ? 0.16 : 0), in: Capsule())
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.55),
                                       style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 2] : []))
            )
            .foregroundStyle(tint)
    }
}

/// How a note stands, and pressing it changes it.
///
/// **Build 165, and the fifth time this rule has been earned.** `status:` was read by the
/// review, the Map, the search, the roll-up and the note header — and the only thing that
/// could write it was three buttons in the weekly review's context menu, projects only. So a
/// goal could never be marked anything at all from the app. `due:` (132), an area's `goal:`
/// (134), a project's `goal:` (140) and `tags:` (144) were the same fault. **Before shipping a
/// screen that reads a field, find the control that writes it.**
///
/// A `Menu`, not a popover: there is nothing to type, only one of six words to pick, and each
/// line says what it means — "Missed" and "Dropped" are new words and a bare list of them
/// would be a guess.
struct NoteStatusChip: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        // Read back out of the model: a change saves and reloads, so the note handed in is one
        // behind (build 144's lesson, in a new place).
        let live = model.note(at: note.relativePath) ?? note
        let status = live.noteStatus
        Menu {
            Picker("How it stands", selection: statusBinding(live)) {
                ForEach(NoteStatus.allCases.filter { $0 != .archived }, id: \.self) { choice in
                    Text("\(choice.label) — \(choice.meaning)").tag(choice)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label(status.label, systemImage: symbol(for: status))
                .font(.caption)
                .foregroundStyle(tint(for: status))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("How this note stands. Done means it delivered; Missed means it is over and did not happen; Dropped means you called it off.")
    }

    private func statusBinding(_ live: Note) -> Binding<NoteStatus> {
        Binding(get: { live.noteStatus },
                set: { model.setStatus($0, for: live) })
    }

    private func symbol(for status: NoteStatus) -> String {
        switch status {
        case .active: return "circle"
        case .onHold: return "pause.circle"
        case .done: return "checkmark.circle.fill"
        case .missed: return "xmark.circle"
        case .dropped: return "minus.circle"
        case .archived: return "archivebox"
        }
    }

    /// Done is the note's own colour because it is the good ending. Missed is orange, the
    /// colour this app already uses for "look at this". **Dropped is grey on purpose** — it is
    /// not a failure, it is a decision, and drawing it in a warning colour would say otherwise.
    private func tint(for status: NoteStatus) -> Color {
        switch status {
        case .done: return note.tint
        case .missed: return .orange
        default: return .secondary
        }
    }
}

/// Where the **One at a time / All of them** setting is spelled, so the middle column's button
/// and the detail column's content read the same key (build 166).
enum GoalsShowAll {
    static let key = "goalsShowAll"
}

/// Every aspiration at once, as one outline — his "whole life on one screen".
///
/// **A list, not a drawing, and that was his call.** He asked for it mapped *or* listed and
/// then said: *"No, I don't want that as a drawn tree, more as a list."* He is right. The
/// **Map** is already the drawn version of this, and a second picture of one thing leaves you
/// unsure which to open; a list can also carry the target dates, the per cents and the next
/// actions that a drawing cannot.
///
/// It is the same `AspirationChainBody` the one-at-a-time view uses, repeated. **Never a second
/// way of drawing a chain** — that is how the Map, the review and the goal dashboard came to
/// answer "what serves what" three different ways before build 162.
struct AllAspirationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let chains = model.index.aspirationChains()
        let loose = model.index.goalsOutsideAnyAspiration()
        VStack(spacing: 0) {
            GoalsHeader(title: "All of them", systemImage: "list.bullet.indent") { EmptyView() }
            Divider()
            outline(chains: chains, loose: loose)
        }
    }

    private func outline(chains: [AspirationChain], loose: [Note]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if chains.isEmpty && loose.isEmpty {
                    EmptyStateView(title: "No aspirations yet",
                                   systemImage: ChainSymbol.aspiration,
                                   message: "An aspiration says what you are becoming. Make one and everything working towards it appears here.",
                                   tint: ParaKind.goal.tint)
                }
                ForEach(chains) { chain in
                    AspirationChainBody(chain: chain, compact: false)
                }
                // Build 100's rule: a screen called "your whole life" may not quietly leave
                // out the goals that hang under no aspiration.
                if !loose.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Goals with no aspiration", count: loose.count,
                                     systemImage: ChainSymbol.datedGoal, tint: .orange)
                        Text("Each of these is working towards nothing. Give it the aspiration it is in service of.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        ForEach(loose) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                ChainGoalBlock(goal: model.index.chainGoal(of: note), lead: false)
                                NoAspirationPrompt(model: model, note: note)
                            }
                        }
                    }
                }
            }
            .padding(Theme.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The one header row the Goals column always has, so **All of them** is always in the same
/// place with its name beside it.
///
/// **Build 167, and it was his report: "I don't understand, and it also moves in various
/// views."** Build 166 put that button in the window's `.toolbar`, where it sits after
/// whatever else the screen owns — so it landed in a different spot on every screen and
/// carried no word at all. **A control that governs what a column shows belongs in that
/// column, next to its own name.** The Calendar's Schedule/Note header (build 159) is the
/// same shape and does not wander.
struct GoalsHeader<Trailing: View>: View {
    private let title: String
    private let systemImage: String
    private let trailing: Trailing
    @AppStorage(GoalsShowAll.key) private var showAll = false

    /// Written out rather than left to the memberwise initializer: a struct that mixes a
    /// property wrapper with a `@ViewBuilder` stored property is exactly where the generated
    /// one is hard to predict, and there is no Swift compiler in this container to ask.
    init(title: String, systemImage: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            SectionLabel(title: showAll ? "All of them" : title, count: nil,
                         systemImage: showAll ? "list.bullet.indent" : systemImage,
                         tint: ParaKind.goal.tint)
            trailing
            StateToggle(systemImage: "list.bullet.indent", title: "All of them",
                        isOn: showAll, tint: ParaKind.goal.tint) {
                showAll.toggle()
            }
        }
        .padding(8)
    }
}

/// A dated goal that hangs under no aspiration, with the one button that fixes it.
///
/// **Build 167, his ask.** The group has always said these goals exist; it never said what to
/// do about them, and the answer — give it an aspiration — was three screens away. Same rule
/// as `due:` (132), an area's `goal:` (134), a project's `goal:` (140), `tags:` (144) and
/// `status:` (165): **when a screen asks a question, the answer is one press from where it is
/// asked.**
///
/// **Orange, not red.** Orange is what this app has always used for "look at this" — past a
/// target date, no next action, needs attention. Red is not in the palette anywhere, and a
/// goal with no aspiration is a loose end, not an error.
struct NoAspirationPrompt: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        Menu {
            NoteGoalOptions(model: model, note: note)
        } label: {
            Label("Give it an aspiration", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("This goal hangs under no aspiration. Choose the one it is in service of.")
    }
}
