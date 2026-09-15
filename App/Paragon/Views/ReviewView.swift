import SwiftUI
import ParagonCore

/// The weekly review: inbox, overdue work, and a health check of every active project and area.
struct ReviewView: View {
    @EnvironmentObject private var model: AppModel

    /// The aspirations among the review's goals, and the dated goals. Two plain functions
    /// rather than work done inside the body: a `@ViewBuilder` takes views and nothing else
    /// (build 58).
    private func aspirations(_ report: ReviewReport) -> [GoalHealth] {
        report.goals.filter { ($0.note.horizon ?? .year) == .life }
    }

    private func datedGoals(_ report: ReviewReport) -> [GoalHealth] {
        report.goals.filter { ($0.note.horizon ?? .year) != .life }
    }

    var body: some View {
        let report = model.index.review(config: model.config)
        let due = model.dueForReview()
        List(selection: model.noteSelection) {
            Section { ReviewSummary(report: report, dueForReview: due.count) }

            // **Build 172: the review rhythm.** Until now the app asked about one thing only —
            // a project not marked reviewed for a week. A goal could sit untouched for two
            // years and never be mentioned. This section is every level of the chain on its
            // own rhythm, set under Settings › Review rhythm.
            //
            // Buttons, not tagged rows: most of these notes are listed again further down, and
            // two rows carrying the same selection tag is what made the Inbox unusable in
            // builds 71 to 74.
            Section {
                if due.isEmpty {
                    Label("Everything has been looked at recently", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(due) { item in
                        ReviewDueRow(item: item)
                    }
                }
            } header: {
                Text("Due for a look")
            } footer: {
                Text("Right-click a row (long-press on the phone) for **Mark reviewed**, and it leaves this list. Each level has its own rhythm, set under Settings \u{203A} Review rhythm.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("1. Empty the inbox") {
                if report.inboxOpenTasks == 0 {
                    Label("Inbox is empty", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        model.show(section: .inbox, notePath: model.vault?.config.inboxFile)
                    } label: {
                        Label("\(report.inboxOpenTasks) open items to file into projects or areas", systemImage: "tray")
                    }
                }
            }

            // **Every numbered step is always drawn, even when it is empty** (build 171).
            // They used to appear only when they had something in them, so the walk through
            // the review read 1, 2, 4 on a good week and you could not tell a step you had
            // finished from one the app had decided not to show you. Build 100's rule: an
            // absence has to say it is an absence.
            Section("2. Reschedule or drop overdue tasks") {
                if report.overdueTasks.isEmpty {
                    Label("Nothing is overdue", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.overdueTasks) { ref in
                        TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                            .tag(ref.notePath)
                    }
                }
            }

            // **Build 175, both from his test.** He asked for two things here: steps 3 to 5
            // named what to *do*, the way 1 and 2 already were, and aspirations kept apart
            // from goals — "Goals and aspirations are mixed. Is it possible to separate
            // them?" They are two different questions, asked at different speeds (the review
            // rhythm says so: a year against a quarter), so they are two steps.
            Section("3. Read the aspirations again") {
                if aspirations(report).isEmpty {
                    Label("No aspirations yet", systemImage: ChainSymbol.aspiration)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(aspirations(report)) { health in
                        GoalHealthRow(health: health)
                            .tag(health.note.relativePath)
                    }
                }
            }

            Section("4. Check the goals are on course") {
                if datedGoals(report).isEmpty {
                    Label("No goals with a date yet", systemImage: ChainSymbol.datedGoal)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(datedGoals(report)) { health in
                        GoalHealthRow(health: health)
                            .tag(health.note.relativePath)
                    }
                }
            }

            Section {
                ForEach(report.projects) { health in
                    HealthRow(health: health)
                        .tag(health.note.relativePath)
                }
                if report.projects.isEmpty {
                    Label("No active projects", systemImage: SidebarSection.kind(.project).systemImage)
                        .foregroundStyle(.secondary)
                }
            } header: {
                HStack {
                    Text("5. Give every project a next action")
                    Spacer()
                    Button("Mark all reviewed") { model.markAllReviewed() }
                        .font(.caption)
                }
            }

            Section("6. Look over the areas") {
                if report.areas.isEmpty {
                    Label("No areas yet", systemImage: SidebarSection.kind(.area).systemImage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.areas) { health in
                        HealthRow(health: health)
                            .tag(health.note.relativePath)
                    }
                }
            }

            // **Last, and with no number** (build 171). It sat above step 1, which put a
            // question that is not part of the weekly walk in front of the walk itself. It
            // is a loose end to tidy when you have time, and it says so.
            if !report.projectsWithoutGoal.isEmpty {
                Section {
                    // Buttons, not tagged HealthRows: these projects are listed again under
                    // step 5, and two rows carrying the same selection tag is exactly
                    // what made the Inbox unselectable in builds 71 to 74.
                    ForEach(report.projectsWithoutGoal) { health in
                        Button {
                            // Stay in Weekly review. On the Mac the note opens in the third
                            // column with this list still beside it, so the review can be
                            // worked straight down; on the phone it pushes one screen and the
                            // back arrow returns here. Jumping to the Projects section instead
                            // threw the review away and gave Back nowhere sensible to return to.
                            model.show(section: .review, notePath: health.note.relativePath)
                        } label: {
                            Label(health.note.displayTitle, systemImage: "questionmark.circle")
                        }
                    }
                } header: {
                    Text("Projects with no goal")
                } footer: {
                    // A Section footer in a narrow column is handed one line unless it is
                    // told it may grow downwards, and the sentence was cut at "Give one a g…".
                    Text("These projects have nothing above them. That is fine for work you do for its own sake. If one should belong to a goal, open it and press Serves\u{2026} at the top. None of them counts as needing attention.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// The week in one block: what moved, then one capsule for each thing that wants looking at.
///
/// **Build 171.** It was five `LabeledContent` rows — a name on the left and a bare number on
/// the right. That is a table, not a summary: every line looked equally important, and a zero
/// looked exactly like a fault. Now what moved is one plain sentence, each worry is an orange
/// capsule, and **when there is nothing to worry about one green capsule says so** rather than
/// four zeroes. Build 100's rule in a new place: an absence has to be visible, and it must not
/// be drawn as if it were a fault.
struct ReviewSummary: View {
    let report: ReviewReport
    /// How many notes are past their review rhythm (build 172).
    var dueForReview = 0

    /// One thing that wants looking at. **A struct, not a tuple**, because a `ForEach` id is a
    /// key path and a key path cannot address a tuple member — the same wall build 61 hit.
    struct Worry: Identifiable {
        var text: String
        var symbol: String
        var id: String { text }
    }

    /// The things that want looking at. A plain array built outside the body, because a
    /// `@ViewBuilder` takes views and nothing else (build 58).
    private var worries: [Worry] {
        var out: [Worry] = []
        if !report.overdueTasks.isEmpty {
            out.append(Worry(text: report.overdueTasks.count == 1 ? "1 task overdue"
                                                                   : "\(report.overdueTasks.count) tasks overdue",
                             symbol: "clock.badge.exclamationmark"))
        }
        let projects = report.projectsNeedingAttention.count
        if projects > 0 {
            out.append(Worry(text: projects == 1 ? "1 project needs attention"
                                                  : "\(projects) projects need attention",
                             symbol: SidebarSection.kind(.project).systemImage))
        }
        let goals = report.goalsNeedingAttention.count
        if goals > 0 {
            out.append(Worry(text: goals == 1 ? "1 goal needs attention"
                                               : "\(goals) goals need attention",
                             symbol: ChainSymbol.datedGoal))
        }
        if report.inboxOpenTasks > 0 {
            out.append(Worry(text: report.inboxOpenTasks == 1 ? "1 item in the Inbox"
                                                               : "\(report.inboxOpenTasks) items in the Inbox",
                             symbol: SidebarSection.inbox.systemImage))
        }
        if dueForReview > 0 {
            out.append(Worry(text: dueForReview == 1 ? "1 note due for a look"
                                                     : "\(dueForReview) notes due for a look",
                             symbol: "calendar.badge.clock"))
        }
        if !report.projectsWithoutGoal.isEmpty {
            out.append(Worry(text: report.projectsWithoutGoal.count == 1
                                   ? "1 project serves no goal"
                                   : "\(report.projectsWithoutGoal.count) projects serve no goal",
                             symbol: "questionmark.circle"))
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // The same wording Today uses, so the two screens name a day the same way.
            Text(DateOnly.today().date()?.formatted(.dateTime.weekday(.wide).day().month(.wide))
                 ?? DateOnly.today().description)
                .font(.headline)
            Text(report.completedLast7Days == 1 ? "1 task finished in the last 7 days"
                                                : "\(report.completedLast7Days) tasks finished in the last 7 days")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            WrappingHStack(spacing: 6, lineSpacing: 5) {
                if worries.isEmpty {
                    ReviewStat(text: "Nothing needs attention", symbol: "checkmark.circle", tint: ParaKind.project.tint)
                } else {
                    ForEach(worries) { worry in
                        ReviewStat(text: worry.text, symbol: worry.symbol, tint: .orange)
                    }
                }
            }
            .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

/// One capsule in the review's summary. The same two-state language the rest of the app uses
/// (build 142): a filled tint with a solid border for something that is true right now.
struct ReviewStat: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(tint, lineWidth: 1))
            .foregroundStyle(tint)
    }
}

struct HealthRow: View {
    @EnvironmentObject private var model: AppModel
    let health: ProjectHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                KindBadge(kind: health.note.kind, size: 20)
                Image(systemName: health.needsAttention ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .foregroundStyle(health.needsAttention ? Color.orange : health.note.tint)
                Text(health.note.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 6)
                Group {
                    if let days = health.daysSinceReview {
                        Text("reviewed \(days == 0 ? "today" : "\(days)d ago")")
                    } else {
                        Text("never reviewed")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            }
            WrappingHStack(spacing: 8, lineSpacing: 3) {
                Label("\(health.openTaskCount) open", systemImage: "checklist")
                if health.overdueTaskCount > 0 {
                    Label("\(health.overdueTaskCount) overdue", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.red)
                }
                Label("\(health.completedLast7Days) done this week", systemImage: "checkmark")
                if let due = health.note.dueDate {
                    Label(due.description, systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            if !health.flags.isEmpty {
                WrappingHStack(spacing: 6, lineSpacing: 3) {
                    ForEach(health.flags, id: \.self) { flag in
                        Text(flag.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(flag == .onHold ? Color.secondary.opacity(0.15) : Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(flag == .onHold ? Color.secondary : Color.orange)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Mark reviewed") { model.markReviewed(health.note) }
            if health.note.kind == .project {
                if health.flags.contains(.onHold) {
                    Button("Set active") { model.setStatus(NoteStatus.active, for: health.note) }
                } else {
                    Button("Put on hold") { model.setStatus(NoteStatus.onHold, for: health.note) }
                }
                // Three endings, not one (build 165). "Mark done" used to be the only way out,
                // so a project you gave up on was written down as one you finished.
                ForEach(NoteStatus.endings, id: \.self) { ending in
                    Button("Mark \(ending.label.lowercased())") { model.setStatus(ending, for: health.note) }
                }
                Button("Archive") { model.archive(health.note) }
            }
        }
    }
}

struct GoalHealthRow: View {
    @EnvironmentObject private var model: AppModel
    let health: GoalHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // The star for an aspiration, the target for a goal with a date (build 171,
                // finishing what 168 and 170 did on the other screens).
                KindBadge(kind: .goal, size: 20, systemImage: ChainSymbol.forGoal(health.note))
                Text(health.note.title)
                    .font(.headline)
                    .lineLimit(2)
                if let horizon = health.note.horizon {
                    Text(horizon.label)
                        .font(.caption2)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(health.note.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(health.note.tint)
                }
                Spacer(minLength: 6)
                if let days = health.daysSinceActivity {
                    Text(days == 0 ? "moved today" : "moved \(days)d ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            WrappingHStack(spacing: 8, lineSpacing: 3) {
                // One item, so the bar and its per cent always move to a new line together.
                GoalProgressBar(progress: health.progress, width: 54, showsCounts: false)
                if health.progress.projectsTotal > 0 {
                    Label("\(health.progress.projectsDone) of \(health.progress.projectsTotal) projects done", systemImage: "flag")
                } else {
                    Label("no projects yet", systemImage: "flag")
                }
                Label("\(health.areas.count) areas", systemImage: "circle.grid.2x2")
                Label("\(health.openTaskCount) open", systemImage: "checklist")
                Label("\(health.completedLast30Days) done in 30d", systemImage: "checkmark")
                if let target = health.note.targetDate {
                    Label(target.description, systemImage: "flag.checkered")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            if !health.flags.isEmpty {
                WrappingHStack(spacing: 6, lineSpacing: 3) {
                    ForEach(health.flags, id: \.self) { flag in
                        Text(flag.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(flag == .achieved ? health.note.tint.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(flag == .achieved ? health.note.tint : Color.orange)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        // **Build 171, and it is the seventh time.** The project rows have carried this menu
        // since build 165 and the goal rows carried nothing at all — so the review could ask
        // "nothing moved in 30 days" about a goal and offer no way to answer it. A screen that
        // asks a question has to put the answer one press away.
        .contextMenu {
            Button("Mark reviewed") { model.markReviewed(health.note) }
            if health.note.noteStatus.isOnHold {
                Button("Set active") { model.setStatus(NoteStatus.active, for: health.note) }
            } else {
                Button("Put on hold") { model.setStatus(NoteStatus.onHold, for: health.note) }
            }
            ForEach(NoteStatus.endings, id: \.self) { ending in
                Button("Mark \(ending.label.lowercased())") { model.setStatus(ending, for: health.note) }
            }
            if model.canArchive(health.note) {
                Button("Archive") { model.archive(health.note) }
            }
        }
    }
}

/// One note whose rhythm has come round (build 172).
///
/// It names **which level** it is — aspiration, goal, project or area — because the same note
/// title means nothing on its own once four kinds are in one list, and because the level is
/// what decides the rhythm behind the row.
struct ReviewDueRow: View {
    @EnvironmentObject private var model: AppModel
    let item: ReviewDue

    private var symbol: String {
        switch item.level {
        case .aspiration: return ChainSymbol.aspiration
        case .goal: return ChainSymbol.datedGoal
        case .project: return ChainSymbol.project
        case .area: return ChainSymbol.area
        }
    }

    private var tint: Color {
        item.level == .area ? ParaKind.area.tint
            : (item.level == .project ? ParaKind.project.tint : ParaKind.goal.tint)
    }

    var body: some View {
        Button {
            // Stay in Weekly review, so the list is still beside the note (build 135).
            model.show(section: .review, notePath: item.note.relativePath)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.note.displayTitle)
                        .lineLimit(2)
                    Text("\(item.level.label) \u{00B7} \(item.lastText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(item.whenText)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Mark reviewed") { model.markReviewed(item.note) }
            Button("Open the note") { model.show(section: .review, notePath: item.note.relativePath) }
        }
    }
}
