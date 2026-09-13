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
        Group {
            if chains.isEmpty && loose.isEmpty {
                EmptyStateView(title: "No goals yet",
                               systemImage: SidebarSection.kind(.goal).systemImage,
                               message: "An aspiration says what you are becoming. A goal with a target date says what you will have done. Make one and the chain under it appears here.",
                               tint: ParaKind.goal.tint,
                               actionTitle: "New goal\u{2026}") { model.activeSheet = .newNote }
            } else if isPhone {
                phoneList(held: held, bare: bare, loose: loose)
            } else {
                deskList(held: held, bare: bare, loose: loose)
            }
        }
        .navigationTitle("Goals")
    }

    // MARK: The Mac — a list that fills the third column

    private func deskList(held: [AspirationChain], bare: [AspirationChain], loose: [Note]) -> some View {
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
                Section("Goals with no aspiration") {
                    ForEach(loose) { note in
                        NoteRow(note: note, goalProgress: model.index.progress(of: note))
                            .tag(note.relativePath)
                            .contextMenu { rowMenu(note) }
                    }
                }
            }
        }
    }

    // MARK: The phone — the chain folds open in place

    private func phoneList(held: [AspirationChain], bare: [AspirationChain], loose: [Note]) -> some View {
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
                        Button {
                            model.show(section: .kind(.goal), notePath: note.relativePath)
                        } label: {
                            NoteRow(note: note, goalProgress: model.index.progress(of: note))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// One aspiration on the phone: a plain `Button`, never a selection tag, because a list
    /// whose rows carry a tag takes the click away from anything inside them (builds 71–74).
    @ViewBuilder
    private func foldingRow(_ chain: AspirationChain) -> some View {
        let isOpen = opened.contains(chain.note.relativePath)
        Button {
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

/// One aspiration in the list: its name, how many goals serve it, and how far they have come.
struct AspirationRow: View {
    @EnvironmentObject private var model: AppModel
    let chain: AspirationChain

    var body: some View {
        HStack(spacing: 10) {
            TintStripe(color: ParaKind.goal.tint, height: 34)
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
                        Label(area.title, systemImage: "circle.grid.2x2")
                            .foregroundStyle(ParaKind.area.tint)
                    }
                    let wanting = chain.goalsNeedingAttention.count
                    if wanting > 0 {
                        Label(wanting == 1 ? "1 goal needs attention" : "\(wanting) goals need attention",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
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
        HStack(spacing: 8) {
            SectionLabel(title: showsNote ? "Note" : (isAspiration ? "Aspiration" : "Goal"),
                         count: nil,
                         systemImage: showsNote ? "doc.text" : "star",
                         tint: ParaKind.goal.tint)
            // Build 159's two-state control: it shows the state you are in, not the one you
            // would get.
            StateToggle(systemImage: "doc.text", title: "Note",
                        isOn: showsNote, tint: ParaKind.goal.tint) {
                showsNote.toggle()
            }
        }
        .padding(8)
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
            ForEach(chain.goals) { goal in
                ChainGoalBlock(goal: goal, lead: false)
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
                             systemImage: "circle.grid.2x2", tint: ParaKind.area.tint)
                ForEach(chain.areas) { area in
                    Button { model.show(section: .kind(.goal), notePath: area.relativePath) } label: {
                        Label(area.title, systemImage: "circle.grid.2x2")
                            .foregroundStyle(ParaKind.area.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var head: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chain.note.title)
                .font(.title2.weight(.semibold))
                .lineLimit(3)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { model.show(section: .kind(.goal), notePath: goal.note.relativePath) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(goal.note.title)
                        .font(lead ? .title3.weight(.semibold) : .headline)
                        .foregroundStyle(ParaKind.goal.tint)
                        .lineLimit(2)
                    WrappingHStack(spacing: 6, lineSpacing: 5) {
                        if let target = goal.note.targetDate {
                            ChainChip(text: "Target \(target.description)", tint: ParaKind.goal.tint, filled: false)
                        }
                        if let serves = goal.note.goal, !serves.isEmpty {
                            // The extra he ticked: a dated goal says what it is in service of.
                            ChainChip(text: "Serves \(serves)", tint: ParaKind.area.tint, filled: false)
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
                    Label(area.title, systemImage: "circle.grid.2x2")
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
                    Text(project.note.title)
                        .font(.callout)
                        .strikethrough(project.isFinished)
                        .foregroundStyle(project.isFinished ? Color.secondary : ParaKind.project.tint)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if project.isFinished {
                        Text("done").font(.caption2).foregroundStyle(.secondary)
                    } else if project.openTaskCount > 0 {
                        Text("\(project.openTaskCount) open").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let next = project.nextAction {
                    Text("Next: \(next.title)")
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
