import SwiftUI
import ParagonCore

// The top of an area note (build 270, idea 4 "Areas come alive"), from the plan he approved
// on 21 October (https://claude.ai/artifact/RyZxairjYDdB7KoxiuGZ3S).
//
// **What it shows, and what decides it.** Everything here is read from Core's
// `AreaOverview` (tested): the projects in the area — only the `area:` line puts one there,
// his answer `link_rule` — each with the box line the Projects list draws, the sub-areas as
// one row each (his answer `subarea_projects`), and the tasks finished each week in the area
// and in its projects. This file only draws it.
//
// **Add a project… stays on the area.** It is build 269's `AddServingNoteButton` with
// `link: .area`, never the New Note screen: a working screen selects, it does not navigate
// away (build 135), and **Add a project…** on a goal already behaves this way. The new
// project appears in the list at once.
//
// **The Mac's note column does not scroll** (builds 30 and 34): the editor below takes the
// height that is left. So the list folds, and on the Mac it sits in a scroll view no taller
// than `macRowsLimit`. On the phone the whole note is already one scroll view, and a second
// one inside it is build 127's fault, so there the rows are drawn as they are.

/// The panel at the top of an area note, between the header and the note's own tasks.
struct AreaDashboardView: View {
    @EnvironmentObject private var model: AppModel
    let area: Note
    /// **Open by default** (build 121): the list is folded only because he folded it. One
    /// setting for every area, the way **Settings block** is one setting for every note.
    @AppStorage("areaProjectsFolded") private var projectsFolded = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    /// The tallest the rows may be on the Mac and the iPad before they scroll, so the text
    /// below always keeps its room. Static, so it is no part of the view's initializer.
    private static let macRowsLimit: CGFloat = 240

    var body: some View {
        // Worked out here, as `GoalDashboardView` works out `goalHealth`: it reads only this
        // area's projects and sub-areas, so it is cheap. Never in a list's body.
        let overview = model.index.areaOverview(of: area, today: .today())
        VStack(alignment: .leading, spacing: 8) {
            weeklyLine(overview.weekly)
            header(overview)
            // Outside the fold and outside the capped scroll: with the list folded the number in
            // the heading may be short, and this line is the only thing that says why (build 100;
            // build 212 keeps the Calendar's "access is off" reason out of its fold the same way).
            if stillComing {
                comingLine
            }
            if !projectsFolded {
                if isPhone {
                    rows(overview)
                } else {
                    CappedHeight(limit: Self.macRowsLimit) {
                        ScrollView {
                            rows(overview)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("area.panel")
    }

    /// The small pink bars and "14 tasks finished in 8 weeks · 2 this week" — the same words
    /// as the band at the top of the Projects list, so one fact is said one way. **Nothing at
    /// all** when no finished task carries a date: empty bars would say "you did nothing", when
    /// the truth is "the file cannot say" (build 141). **And no bars when every dated finish is
    /// older than the eight weeks**: "0 tasks finished in 8 weeks · 0 this week" beside eight
    /// flat stubs draws an absence as a zero, so the line says only when the last one was
    /// ("last task finished about 3 months ago", build 255's caption for the same case).
    @ViewBuilder
    private func weeklyLine(_ weekly: WeeklyFinished) -> some View {
        if let head = weekly.bandHead, weekly.total > 0 {
            WrappingHStack(spacing: 8, lineSpacing: 4) {
                WeekBars(weekly: weekly, barWidth: 5, tint: ParaKind.area.tint)
                Text(head)
                    .fontWeight(.semibold)
                Text("\u{00B7} " + weekly.bandWeek)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .lineLimit(1)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("area.weekly")
        } else if let caption = weekly.caption(today: .today()) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("area.weekly")
        }
    }

    /// **Projects in this area**, how many, and **Add a project…** beside it — in the heading,
    /// so it is there when the list is folded and when it is empty: a control that vanishes
    /// when there is nothing to show removes the only way to give it something (build 203).
    /// A plain `HStack` with the button `.fixedSize()`, the review's step 5 shape (build 266):
    /// the heading's words break between words in a narrow column instead of running off it.
    private func header(_ overview: AreaOverview) -> some View {
        HStack(spacing: 8) {
            // The whole line folds, never a small triangle (build 205). `SectionLabel` ends in
            // a spacer, so the button is as wide as the room it has (build 247).
            FoldButton(isOpen: projectsOpen, accessibilityName: foldName(overview)) {
                SectionLabel(title: "Projects in this area", count: overview.projects.count,
                             systemImage: ChainSymbol.project, tint: ParaKind.project.tint)
            }
            .accessibilityIdentifier("area.projects")
            AddServingNoteButton(model: model, parent: area, link: .area)
                .fixedSize()
        }
    }

    /// What the fold says aloud: the heading and how many, since the number in the capsule is
    /// not read out on its own.
    private func foldName(_ overview: AreaOverview) -> String {
        "Projects in this area, " + AreaOverview.projectsText(overview.projects.count).lowercased()
    }

    /// `FoldButton` asks whether the list is open; the setting says whether it is folded.
    private var projectsOpen: Binding<Bool> {
        Binding(get: { !projectsFolded }, set: { projectsFolded = !$0 })
    }

    /// Notes are still coming from iCloud, so a project in this area may not be here yet.
    /// "No projects in this area yet." would then be a guess (build 100).
    private var stillComing: Bool { !model.notesWaitingForCloud.isEmpty }

    /// The orange line that says the list may be short. Drawn by `body`, never inside `rows`.
    private var comingLine: some View {
        Label("Some notes are still coming from iCloud. More projects may appear here.",
              systemImage: "icloud")
            .font(.caption)
            .foregroundStyle(Color.orange)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("area.stillComing")
    }

    /// The projects, a line about the ones that are over, and the sub-areas.
    private func rows(_ overview: AreaOverview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if overview.projects.isEmpty {
                if !stillComing {
                    Text(overview.emptyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("area.noProjects")
                }
            } else {
                ForEach(overview.projects) { line in
                    AreaProjectRow(model: model, line: line)
                }
            }
            if let over = overview.overText {
                Text(over)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !overview.subAreas.isEmpty {
                SectionLabel(title: "Sub-areas", count: overview.subAreas.count,
                             systemImage: ChainSymbol.area, tint: ParaKind.area.tint)
                    .padding(.top, 4)
                ForEach(overview.subAreas) { line in
                    SubAreaRow(line: line) { model.show(line.note) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One project on its area's page: the tile with his emoji, the name, what it needs next, and
/// short pills for what is late. **A plain button that opens the project**, like the rows of
/// `GoalDashboardView`; nothing inside it takes a click, and it carries no drag, so one press
/// has one meaning (builds 71–74, 85). The right-click menu (press and hold on the iPhone) has
/// **Serves**, **In area** and the status lines.
///
/// What it says is the Projects list's box, made smaller: the same `ProjectLine`, the same
/// words from Core, and the same colours — red only for a date that has passed on a project
/// that is running.
struct AreaProjectRow: View {
    @ObservedObject var model: AppModel
    let line: ProjectLine

    private var isRunning: Bool { line.status == .active }

    var body: some View {
        Button {
            model.show(line.note)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ProjectTile(status: line.status, emoji: line.note.emoji)
                VStack(alignment: .leading, spacing: 4) {
                    Text(line.note.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    need
                    if !facts.isEmpty {
                        WrappingHStack(spacing: 6, lineSpacing: 4) {
                            ForEach(facts) { fact in
                                ProjectPill(fact: fact)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // One sentence for the whole button, read the same on both platforms (build 253).
        .accessibilityLabel(spoken)
        // Named by its path for the screen tests (build 191).
        .accessibilityIdentifier("area.project.\(line.id)")
        .contextMenu {
            NoteGoalMenu(model: model, note: line.note)
            ProjectAreaMenu(model: model, note: line.note)
            Divider()
            ProjectStatusItems(model: model, note: line.note)
        }
    }

    /// What the project needs, in the Projects list's words. Grey for "No next action": it is
    /// true of many projects, and orange for it would read as a telling-off (build 132).
    @ViewBuilder
    private var need: some View {
        switch line.need {
        case .next:
            Label {
                Text("Next: " + (line.nextTitle ?? ""))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: ChainSymbol.task)
                    .foregroundStyle(ParaKind.project.tint)
            }
            .font(.caption)
        case .allFinished(let count):
            WrappingHStack(spacing: 6, lineSpacing: 4) {
                Label(ProjectLine.finishedText(count: count), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(ParaKind.project.tint)
                if isRunning {
                    ProjectPill(fact: ProjectFact(id: "noNext", text: "No next action",
                                                  systemImage: "circle.dashed", dashed: true))
                }
            }
        case .noTasks:
            ProjectPill(fact: ProjectFact(id: "noTasks", text: "No tasks yet",
                                          systemImage: "circle.dashed", dashed: true))
        }
    }

    /// The short facts, assembled here rather than in the body, where a loop and `var` are not
    /// allowed (build 58). The same rules as the Projects list's box.
    private var facts: [ProjectFact] {
        let today = DateOnly.today()
        var facts: [ProjectFact] = []
        if line.status == .onHold {
            facts.append(ProjectFact(id: "onHold", text: NoteStatus.onHold.label,
                                     systemImage: NoteStatus.onHold.systemImage))
        }
        if isRunning, line.overdueCount > 0 {
            facts.append(ProjectFact(id: "overdue", text: ProjectLine.overdueText(line.overdueCount),
                                     systemImage: "exclamationmark.circle", tint: Color.red))
        }
        if let deadline = line.deadline {
            facts.append(ProjectFact(id: "deadline", text: ProjectLine.deadlineText(deadline, today: today),
                                     systemImage: "flag.checkered",
                                     tint: isRunning && line.deadlinePassed ? Color.red : Color.secondary))
        }
        return facts
    }

    /// The whole row in one sentence, read the same on both platforms (build 253).
    private var spoken: String {
        var words = line.note.title + ". "
        switch line.need {
        case .next: words += "Next: " + (line.nextTitle ?? "")
        case .allFinished(let count):
            words += ProjectLine.finishedText(count: count) + (isRunning ? ". No next action" : "")
        case .noTasks: words += "No tasks yet"
        }
        if line.status == .onHold { words += ". " + NoteStatus.onHold.label }
        if isRunning, line.overdueCount > 0 { words += ". " + ProjectLine.overdueText(line.overdueCount) }
        if let deadline = line.deadline {
            words += ". " + ProjectLine.deadlineText(deadline, today: DateOnly.today())
        }
        return words
    }
}

/// One sub-area on its parent's page: "Yoga · 1 project · 3 open". Pressing it opens the
/// sub-area, where its own projects are listed — each project is shown in one place (his
/// answer `subarea_projects`).
struct SubAreaRow: View {
    let line: SubAreaLine
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: ChainSymbol.area)
                    .font(.caption)
                    .foregroundStyle(ParaKind.area.tint)
                Text(line.note.title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\u{00B7} " + line.factsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                // At the end, so the facts follow the name instead of standing at the far
                // edge of the column (build 169).
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(line.note.title + ", " + line.factsText)
        .accessibilityIdentifier("area.subArea.\(line.id)")
    }
}

/// The status lines of a project's right-click menu: **Set active**, **Mark done**, **Mark
/// missed**, **Mark dropped** and **Put on hold**, each offered only when it would change
/// something. **One view for both menus that carry them**, the Projects list's and the area
/// page's, so the two cannot drift (build 168). Build 262 made `AppModel.setStatus` the only
/// writer of `status:` (and of `ended:` with it), and every line goes through it.
///
/// The model is handed in, never read from the environment: a context menu is built outside
/// the row's hierarchy (build 73).
struct ProjectStatusItems: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        let status = note.noteStatus
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
    }
}

/// A child no taller than its own content and never taller than `limit` (build 270).
///
/// For a scroll view on the Mac's note column: `.frame(maxHeight:)` alone makes a scroll view
/// take the whole limit even for one short row, because a scroll view takes all the height it
/// is offered. This asks the child how tall it would like to be — a vertical scroll view
/// answers with its content's height — and gives it that, up to the limit. The answer does
/// not depend on the height offered, so the column cannot be pushed past the window by it
/// (builds 30 and 34).
struct CappedHeight: Layout {
    var limit: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let natural = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? natural.width, height: min(natural.height, limit))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for child in subviews {
            child.place(at: bounds.origin,
                        proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
        }
    }
}
