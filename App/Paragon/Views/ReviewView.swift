import SwiftUI
import ParagonCore

/// The weekly review: inbox, overdue work, and a health check of every active project and area.
///
/// **Build 266: every part under the summary folds, and starts folded.** His words after the
/// first week with steps 7 and 8: *"it's so many lines. I would say it's like 50 lines or
/// more, and that is a bit scary."* The first look is now the summary and one short heading per
/// part. Each heading says how many things are in its part, so nothing is hidden by folding it
/// (build 100), and **Open all** / **Close all** in the summary does every part at once.
struct ReviewView: View {
    @EnvironmentObject private var model: AppModel
    /// The week step 7 looks at once its arrows are pressed (build 263). Kept here rather than
    /// in the step itself: this view's state certainly outlives a scroll of the list.
    @State private var lookedWeek: WeekRef?
    /// The parts he has opened, one id per line (`ReviewView.parts`). **Folded by default**: the
    /// review's length was the whole complaint. One string for every part, steps 7 and 8
    /// included, so there is one answer to "is this open" — and its own key per platform, so
    /// opening a step on the phone does not open it on the Mac (build 161's pair).
    @AppStorage("reviewOpenParts") private var deskOpenText = ""
    @AppStorage("reviewOpenPartsPhone") private var phoneOpenText = ""

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    /// A plain stub, so the body never carries an `#if` in the middle of a modifier chain
    /// (build 148's lesson, and build 160's about this pair).
    private var isPhone: Bool { false }
    #endif

    /// Every part that folds, in the order they are drawn. The id is also the screen test's
    /// name for the heading: `review.part.<id>`.
    static let parts = ["due", "1", "2", "3", "4", "5", "6", "7", "8", "noGoal"]

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
            // **Never folded**: it is the week in one block, and it holds the one button that
            // opens or closes every part below it (build 167: a control that governs what a
            // column shows belongs in that column).
            Section {
                ReviewSummary(report: report, dueForReview: due.count)
                ReviewOpenAllButton(opensAll: anyFolded(report)) { openOrCloseAll(report) }
            }

            // **Build 172: the review rhythm.** Until now the app asked about one thing only —
            // a project not marked reviewed for a week. A goal could sit untouched for two
            // years and never be mentioned. This section is every level of the chain on its
            // own rhythm, set under Settings › Review rhythm.
            //
            // Buttons, not tagged rows: most of these notes are listed again further down, and
            // two rows carrying the same selection tag is what made the Inbox unusable in
            // builds 71 to 74.
            Section {
                if isOpen("due") {
                    if due.isEmpty {
                        Label("Everything has been looked at recently", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(due) { item in
                            ReviewDueRow(item: item)
                        }
                    }
                }
            } header: {
                ReviewPartHeading(title: "Due for a look", count: due.count,
                                  isOpen: openBinding("due"), part: "due")
            } footer: {
                if isOpen("due") {
                    // "Looked at" everywhere (build 270, his answer 3a): the button at the top
                    // of a goal, an aspiration or an area says the same words.
                    Text("Right-click a row (long-press on the phone) for **I looked at it today**, and it leaves this list. The same button is at the top of an aspiration, a goal or an area. Each level has its own rhythm, set under Settings \u{203A} Review rhythm.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                if isOpen("1") {
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
            } header: {
                ReviewPartHeading(title: "1. Empty the inbox", count: report.inboxOpenTasks,
                                  isOpen: openBinding("1"), part: "1")
            }

            // **Every numbered step is always drawn, even when it is empty** (build 171).
            // They used to appear only when they had something in them, so the walk through
            // the review read 1, 2, 4 on a good week and you could not tell a step you had
            // finished from one the app had decided not to show you. Build 100's rule: an
            // absence has to say it is an absence. Folded (build 266), a step is still its
            // heading, and the heading still counts what is in it.
            Section {
                if isOpen("2") {
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
            } header: {
                ReviewPartHeading(title: "2. Reschedule or drop overdue tasks", count: report.overdueTasks.count,
                                  isOpen: openBinding("2"), part: "2")
            }

            // **Build 175, both from his test.** He asked for two things here: steps 3 to 5
            // named what to *do*, the way 1 and 2 already were, and aspirations kept apart
            // from goals — "Goals and aspirations are mixed. Is it possible to separate
            // them?" They are two different questions, asked at different speeds (the review
            // rhythm says so: a year against a quarter), so they are two steps.
            Section {
                if isOpen("3") {
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
            } header: {
                ReviewPartHeading(title: "3. Read the aspirations again", count: aspirations(report).count,
                                  isOpen: openBinding("3"), part: "3")
            } footer: {
                // Build 176: the rule in one line, where the two kinds sit side by side.
                // A title string and a footer cannot be given together (build 157).
                if isOpen("3") {
                    Text(GoalWording.aspirationRule)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                if isOpen("4") {
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
            } header: {
                ReviewPartHeading(title: "4. Check the goals with a date are on course", count: datedGoals(report).count,
                                  isOpen: openBinding("4"), part: "4")
            } footer: {
                if isOpen("4") {
                    Text(GoalWording.datedGoalRule)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                if isOpen("5") {
                    ForEach(report.projects) { health in
                        HealthRow(health: health)
                            .tag(health.note.relativePath)
                    }
                    if report.projects.isEmpty {
                        Label("No active projects", systemImage: SidebarSection.kind(.project).systemImage)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                // A plain `HStack`, not a `WrappingHStack`: a wrapping row places each item at
                // its one-line width, so a long heading would run off a narrow column instead
                // of breaking between words. The button keeps its own width and the heading
                // takes what is left (build 138).
                HStack(spacing: 8) {
                    ReviewPartHeading(title: "5. Give every project a next action", count: report.projects.count,
                                      isOpen: openBinding("5"), part: "5")
                    // Only while the step is open: it stamps every project in it, and a folded
                    // step has not been looked at yet.
                    if isOpen("5") {
                        Button("I looked at all of them") { model.markAllReviewed() }
                            .font(.caption)
                            .fixedSize()
                    }
                }
            }

            Section {
                if isOpen("6") {
                    if report.areas.isEmpty {
                        Label("No areas yet", systemImage: SidebarSection.kind(.area).systemImage)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(report.areas) { health in
                            // Build 271: an area shows its Standard under its name, so it
                            // can be checked against what "good" looks like.
                            HealthRow(health: health, showsStandard: true)
                                .tag(health.note.relativePath)
                        }
                    }
                }
            } header: {
                ReviewPartHeading(title: "6. Look over the areas", count: report.areas.count,
                                  isOpen: openBinding("6"), part: "6")
            }

            // **Build 263: the review looks back as well as forward.** Steps 1 to 6 are all
            // about what comes next; this one is the week that has just gone, from his own
            // notes — including the evening lines **Close the day** saves and nothing showed
            // again.
            // **Build 264: and then forward again.** The walk ends by writing the goal for the
            // week about to start, in the same box as Calendar › Week. The two steps share a
            // `Group` so this list stays at ten children.
            Group {
                WeekLookStep(chosenWeek: $lookedWeek, isOpen: openBinding("7"))
                WeekGoalStep(isOpen: openBinding("8"))
            }

            // **Last, and with no number** (build 171). It sat above step 1, which put a
            // question that is not part of the weekly walk in front of the walk itself. It
            // is a loose end to tidy when you have time, and it says so.
            if !report.projectsWithoutGoal.isEmpty {
                Section {
                    if isOpen("noGoal") {
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
                    }
                } header: {
                    ReviewPartHeading(title: "Projects with no goal", count: report.projectsWithoutGoal.count,
                                      isOpen: openBinding("noGoal"), part: "noGoal")
                } footer: {
                    // A Section footer in a narrow column is handed one line unless it is
                    // told it may grow downwards, and the sentence was cut at "Give one a g…".
                    if isOpen("noGoal") {
                        Text("These projects have nothing above them. That is fine for work you do for its own sake. If one should belong to a goal, open it and press Serves\u{2026} at the top. None of them counts as needing attention.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        // For the screen test, which scrolls this list to reach step 7 (build 263).
        .accessibilityIdentifier("review.list")
    }

    // MARK: Folding (build 266)

    /// The open set for this platform.
    private var openText: Binding<String> { isPhone ? $phoneOpenText : $deskOpenText }

    private func isOpen(_ part: String) -> Bool {
        Self.ids(in: openText.wrappedValue).contains(part)
    }

    /// What a heading's `FoldButton` reads and writes. Every part goes through the same string,
    /// so **Open all** and a heading can never disagree.
    private func openBinding(_ part: String) -> Binding<Bool> {
        let text = openText
        return Binding(get: { Self.ids(in: text.wrappedValue).contains(part) },
                       set: { text.wrappedValue = Self.storing(part, opening: $0, in: text.wrappedValue) })
    }

    /// The parts drawn right now: **Projects with no goal** only while there are such projects,
    /// so a part that is not on screen can never make the button say **Open all**.
    private func shownParts(_ report: ReviewReport) -> [String] {
        report.projectsWithoutGoal.isEmpty ? Self.parts.filter { $0 != "noGoal" } : Self.parts
    }

    /// True while any part on screen is folded: the button then opens them all.
    private func anyFolded(_ report: ReviewReport) -> Bool {
        let opened = Self.ids(in: openText.wrappedValue)
        return shownParts(report).contains { !opened.contains($0) }
    }

    private func openOrCloseAll(_ report: ReviewReport) {
        openText.wrappedValue = anyFolded(report) ? Self.parts.joined(separator: "\n") : ""
    }

    private static func ids(in text: String) -> Set<String> {
        Set(text.split(separator: "\n").map(String.init))
    }

    private static func storing(_ part: String, opening: Bool, in text: String) -> String {
        var opened = Self.ids(in: text)
        if opening { opened.insert(part) } else { opened.remove(part) }
        return opened.sorted().joined(separator: "\n")
    }
}

/// The heading of one part of the Weekly review (build 266): **the whole line is the
/// button** (`FoldButton`, build 205), and the label fills the line, because a short button
/// beside a `Spacer` gets a wrong frame on the Mac (build 247).
///
/// **The heading counts what the part lists** — "2. Reschedule or drop overdue tasks · 3" — so
/// a folded part still says something is in it (build 100). **One rule everywhere: a number
/// when there is something, nothing when there is not.** Never "· 0": a zero beside a step reads
/// as a fault (builds 141, 171), and the part itself says "Nothing is overdue" once opened.
/// Steps 7 and 8 list nothing to work through, so they carry no number; step 7 names its week
/// instead.
///
/// The words keep the list's own look: on the phone a `List` writes a header in capitals, as it
/// did before the fold, so nothing about the heading changes but the arrow and the number.
struct ReviewPartHeading: View {
    let title: String
    let count: Int
    @Binding var isOpen: Bool
    /// "due", "1" … "8", "noGoal" — the id the open set keeps.
    let part: String

    init(title: String, count: Int = 0, isOpen: Binding<Bool>, part: String) {
        self.title = title
        self.count = count
        self._isOpen = isOpen
        self.part = part
    }

    private var shown: String {
        count > 0 ? "\(title) \u{00B7} \(count)" : title
    }

    /// Said aloud and readable by a test, beside the `isSelected` trait `FoldButton` gives an
    /// open box.
    private var state: String { isOpen ? "open" : "folded" }

    var body: some View {
        FoldButton(isOpen: $isOpen, accessibilityName: shown) {
            Text(shown)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityValue(state)
        .accessibilityIdentifier("review.part.\(part)")
    }
}

/// **Open all** while any part of the review is folded, **Close all** once every part is open
/// (build 266). One button whose words say what it will do now. The same two words as the
/// button at the top of Help, which does the same thing to that page's sections — one action,
/// one pair of words (build 165).
struct ReviewOpenAllButton: View {
    /// True while anything is folded.
    let opensAll: Bool
    let action: () -> Void

    private var words: String { opensAll ? "Open all" : "Close all" }
    private var symbol: String { opensAll ? "chevron.down" : "chevron.up" }

    var body: some View {
        Button(action: action) {
            Label(words, systemImage: symbol)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        // Borderless, so on the phone only this button answers a press in its row. The row
        // carries no `.tag`, so the colour never sits on a selection fill (build 201).
        .buttonStyle(.borderless)
        .foregroundStyle(SidebarSection.review.tint)
        .accessibilityLabel(words)
        .accessibilityIdentifier("review.openAll")
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
    /// Step 6 only (build 271): the area's Standard, or "No standard written yet", under
    /// its name. Step 5's project rows have none.
    var showsStandard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                KindBadge(kind: health.note.kind, size: 20)
                Image(systemName: health.needsAttention ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .rowTint(health.needsAttention ? Color.orange : health.note.tint)
                Text(health.note.title)
                    .font(.headline)
                    .lineLimit(2)
            }
            if showsStandard {
                standardLine
            }
            WrappingHStack(spacing: 8, lineSpacing: 3) {
                // The Aspirations list's own words and eye (build 270, his answer 3a:
                // "Looked at" everywhere). "Never looked at" is a sentence, never a big number
                // (build 141). On this line, not beside the name: "looked at about a month ago"
                // kept its full width there and squeezed the name in the Mac's narrow middle
                // column (builds 138, 250). Here it wraps as one whole item.
                Label(ReviewWording.lookedAt(daysAgo: health.daysSinceReview), systemImage: "eye")
                Label("\(health.openTaskCount) open", systemImage: "checklist")
                if health.overdueTaskCount > 0 {
                    Label("\(health.overdueTaskCount) overdue", systemImage: "clock.badge.exclamationmark")
                        .rowTint(.red)
                }
                // "In 7 days", not "this week": it counts back from today, and the step 7 week
                // is Monday to Sunday (review of 263).
                Label("\(health.completedLast7Days) done in 7 days", systemImage: "checkmark")
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
                            .rowTint(flag == .onHold ? Color.secondary : Color.orange)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            LookedAtMenuItem(model: model, note: health.note)
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

    /// **The area's Standard, in the row's grey** — only `.secondary` and a shape, no colour of
    /// its own, so the row stays readable when it is selected (builds 200, 201). Words are
    /// `AreaStandard`'s (Core, tested); a standard that is only the template's question reads
    /// as none. The row is a selectable one, so nothing here takes a click (builds 71–74).
    @ViewBuilder
    private var standardLine: some View {
        if let standard = model.standard(of: health.note) {
            Text("Standard: " + AreaStandard.firstSentence(of: standard))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("review.standard.\(health.note.relativePath)")
        } else {
            ProjectPill(fact: ProjectFact(id: "noStandard", text: "No standard written yet",
                                          systemImage: "circle.dashed", dashed: true))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("No standard written yet")
                .accessibilityIdentifier("review.standard.\(health.note.relativePath)")
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
                KindBadge(kind: .goal, size: 20, systemImage: ChainSymbol.forGoal(health.note),
                          tint: ChainTint.forGoal(health.note))
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
                        .rowTint(health.note.tint)
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
                GoalProgressBar(progress: health.progress, width: 54, showsCounts: false,
                                tint: ChainTint.forGoal(health.note))
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
                            .rowTint(flag == .achieved ? health.note.tint : Color.orange)
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
            LookedAtMenuItem(model: model, note: health.note)
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

    /// The level's own colour, decided in the same breath as its symbol: an aspiration is the
    /// deeper gold since build 189, a goal with a date the family gold.
    private var tint: Color {
        switch item.level {
        case .aspiration: return ChainTint.aspiration
        case .goal: return ChainTint.datedGoal
        case .project: return ParaKind.project.tint
        case .area: return ParaKind.area.tint
        }
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
            LookedAtMenuItem(model: model, note: item.note)
            Button("Open the note") { model.show(section: .review, notePath: item.note.relativePath) }
        }
    }
}
