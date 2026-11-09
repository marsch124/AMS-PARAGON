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
    /// Closed to begin with: an aspiration you have reached is something you look back at on
    /// purpose. The count stays on the heading, so nothing is hidden (build 100).
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

    /// Aspirations that are over. `endedGoals()` gathers both kinds of goal, so the dated ones
    /// are dropped here — they belong to the **Goals** list, which folds them away in the same
    /// way. Assembled outside the body (the `@ViewBuilder` rule, build 58).
    private var ended: [(status: NoteStatus, notes: [Note])] {
        model.index.endedGoals().compactMap { group in
            // Written out rather than `.filter(GoalWording.isAspiration)`: there is no Swift
            // compiler in this container to settle a bare function reference (build 168).
            let mine = group.notes.filter { GoalWording.isAspiration($0) }
            return mine.isEmpty ? nil : (group.status, mine)
        }
    }

    var body: some View {
        let chains = model.index.aspirationChains()
        // `let over = ended`, never `let ended = ended`: a local shadows the property of the
        // same name inside its own initial value (build 150).
        let over = ended
        Group {
            if chains.isEmpty && over.isEmpty {
                EmptyStateView(title: "No aspirations yet",
                               markName: ChainSymbol.aspiration,
                               message: "An aspiration says what you are becoming. It has no date, because you never tick one off. Make one, and every goal working towards it appears beside it.",
                               tint: ChainTint.aspiration,
                               actionTitle: "New aspiration\u{2026}") { model.activeSheet = .newNote }
            } else if isPhone {
                phoneList(chains: chains, ended: over)
            } else {
                deskList(chains: chains, ended: over)
            }
        }
        .navigationTitle("Aspirations")
    }

    // MARK: The Mac — a list that fills the middle column

    /// **One list since build 199.** Before it the aspirations were split into two groups,
    /// "Aspirations" and "Nothing serves these yet", which put the ones you had not started on
    /// into a box of their own and read as a telling-off. The row says it instead, in one
    /// line, and the order stays the plain alphabetical one.
    private func deskList(chains: [AspirationChain],
                          ended: [(status: NoteStatus, notes: [Note])]) -> some View {
        List(selection: model.noteSelection) {
            if !chains.isEmpty {
                Section {
                    ForEach(chains) { chain in
                        AspirationRow(chain: chain)
                            .tag(chain.note.relativePath)
                            // Named by its path for the screen tests (build 277), the way a
                            // goal's row is (build 268): one element that holds the row's words.
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("aspiration.\(chain.note.relativePath)")
                            .contextMenu { rowMenu(chain.note) }
                    }
                } header: {
                    Text("Aspirations")
                } footer: {
                    // `Section { } header: { } footer: { }` — a title string and a footer
                    // cannot be given together (build 157).
                    Text(GoalWording.aspirationRule)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(ended, id: \.status) { group in
                endedSection(group.status, group.notes)
            }
        }
    }

    /// An aspiration that is over drops out of the list above and gathers here, closed,
    /// **under the name of its ending** — Done, Missed or Dropped (builds 163 and 165). It is
    /// history rather than work, but it is never hidden altogether.
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
        GoalEndedHeader(status: status, count: count, folded: endedFolded) { endedFolded.toggle() }
    }

    // MARK: The phone — the chain folds open in place

    private func phoneList(chains: [AspirationChain],
                           ended: [(status: NoteStatus, notes: [Note])]) -> some View {
        List {
            if !chains.isEmpty {
                Section("Aspirations") {
                    ForEach(chains) { chain in
                        foldingRow(chain)
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
            model.show(section: .aspirations, notePath: note.relativePath)
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
                MarkImage(isOpen ? "chevron.down" : "chevron.right")
                    .font(Txt.listSecond)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                AspirationRow(chain: chain)
            }
        }
        .buttonStyle(.plain)
        // The Mac's right-click menu, on a long press (build 270): **I looked at it today**,
        // and **Open the note**, which the phone's Aspirations list had no other way to open for
        // a live aspiration (the Map, Search and the review could).
        .contextMenu { rowMenu(chain.note) }
        // Named by its path for the screen tests (build 277), on the button itself: it is the
        // one element here that takes the press.
        .accessibilityIdentifier("aspiration.\(chain.note.relativePath)")
        if isOpen {
            AspirationChainBody(chain: chain, compact: true)
                .padding(.leading, 10)
                .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private func rowMenu(_ note: Note) -> some View {
        Button("Open the note") { model.show(section: .aspirations, notePath: note.relativePath) }
        LookedAtMenuItem(model: model, note: note)
        if model.canArchive(note) {
            Button("Archive") { model.archive(note) }
        }
    }
}

/// Every goal with a target date, in one list — the **Goals** row, build 199.
///
/// **Before this there was no such list.** The row named Goals drew the *aspirations*, so a
/// goal with a date was only on screen once you had picked the aspiration above it. His words:
/// *"I am not choosing an aspiration, no goals are visible on the Goals page."* He was right,
/// and the split he chose fixes both halves at once: the aspirations get a room of their own,
/// and this room is the goals.
///
/// Three groups, in the order you would want them:
/// 1. **Needs a look** — the goals the review has something to say about: past their target,
///    nothing serving them, no next action. Never a fault list, just the ones to start with.
/// 2. **By date** — everything else, soonest first.
/// 3. **Done / Missed / Dropped**, folded, with the count on the heading (his ask, and
///    build 165's rule: one heading per ending, never one heading for all three).
struct DatedGoalsListView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("goalsEndedFolded") private var endedFolded = true
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isPhone: Bool { horizontalSizeClass == .compact }
#else
    private var isPhone: Bool { false }
#endif

    /// The live goals, split into the two groups. Worked out here rather than in the body,
    /// where `let` and a loop are not allowed (build 58).
    private var live: (wanting: [Note], rest: [Note]) {
        var wanting: [Note] = []
        var rest: [Note] = []
        for note in model.index.datedGoals() {
            if model.index.chainGoal(of: note).needsAttention { wanting.append(note) } else { rest.append(note) }
        }
        return (wanting, rest)
    }

    private var ended: [(status: NoteStatus, notes: [Note])] {
        model.index.endedGoals().compactMap { group in
            let mine = group.notes.filter { !GoalWording.isAspiration($0) }
            return mine.isEmpty ? nil : (group.status, mine)
        }
    }

    var body: some View {
        // Never `let live = live`: a local shadows the property of the same name inside its
        // own initial value (build 150).
        let split = live
        let over = ended
        Group {
            if split.wanting.isEmpty && split.rest.isEmpty && over.isEmpty {
                EmptyStateView(title: "No goals with a date yet",
                               markName: ChainSymbol.datedGoal,
                               message: "A goal with a date says what you will have done, and by when. Make one, point projects at it, and its progress shows up here.",
                               tint: ChainTint.datedGoal,
                               actionTitle: "New goal\u{2026}") { model.activeSheet = .newNote }
            } else if isPhone {
                phoneList(live: split, ended: over)
            } else {
                deskList(live: split, ended: over)
            }
        }
        .navigationTitle("Goals")
    }

    private func deskList(live: (wanting: [Note], rest: [Note]),
                          ended: [(status: NoteStatus, notes: [Note])]) -> some View {
        List(selection: model.noteSelection) {
            if !live.wanting.isEmpty {
                Section {
                    ForEach(live.wanting) { note in
                        deskRow(note)
                    }
                } header: {
                    MarkLabel("Needs a look", "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            if !live.rest.isEmpty {
                Section {
                    ForEach(live.rest) { note in
                        deskRow(note)
                    }
                } header: {
                    Heading(text: "By date", color: ChainTint.datedGoal).textCase(nil)
                } footer: {
                    Text(GoalWording.datedGoalRule)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(ended, id: \.status) { group in
                Section {
                    if !endedFolded {
                        ForEach(group.notes) { note in
                            deskRow(note)
                        }
                    }
                } header: {
                    GoalEndedHeader(status: group.status, count: group.notes.count,
                                    folded: endedFolded) { endedFolded.toggle() }
                }
            }
        }
    }

    private func phoneList(live: (wanting: [Note], rest: [Note]),
                           ended: [(status: NoteStatus, notes: [Note])]) -> some View {
        List {
            if !live.wanting.isEmpty {
                Section("Needs a look") {
                    ForEach(live.wanting) { note in row(note) }
                }
            }
            if !live.rest.isEmpty {
                Section {
                    ForEach(live.rest) { note in row(note) }
                } header: {
                    Heading(text: "By date", color: ChainTint.datedGoal).textCase(nil)
                }
            }
            ForEach(ended, id: \.status) { group in
                Section {
                    if !endedFolded {
                        ForEach(group.notes) { note in row(note) }
                    }
                } header: {
                    GoalEndedHeader(status: group.status, count: group.notes.count,
                                    folded: endedFolded) { endedFolded.toggle() }
                }
            }
        }
    }

    /// A plain `Button`, never a selection tag: a tagged row takes the click away from the
    /// chips inside it (builds 71–74), and this row carries **Give it an aspiration**.
    private func row(_ note: Note) -> some View {
        Button {
            model.show(section: .kind(.goal), notePath: note.relativePath)
        } label: {
            DatedGoalRow(note: note)
        }
        .buttonStyle(.plain)
        // The Mac's right-click menu, on a long press (build 270). The manual has said
        // "press and hold on the iPhone" for this list since build 199; until now nothing came.
        .contextMenu { rowMenu(note) }
        // Named by its path for the screen tests (build 268), on the button itself: it is the
        // one element here that takes the press.
        .accessibilityIdentifier("goal.\(note.relativePath)")
    }

    /// One goal in the Mac's list: a selection tag, so pressing it puts the goal's page in the
    /// third column. Named by its path for the screen tests (build 268), the way every note row
    /// is named (build 191), on one element that holds the row's words.
    private func deskRow(_ note: Note) -> some View {
        DatedGoalRow(note: note)
            .tag(note.relativePath)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("goal.\(note.relativePath)")
            .contextMenu { rowMenu(note) }
    }

    @ViewBuilder
    private func rowMenu(_ note: Note) -> some View {
        Button("Open the note") { model.show(section: .kind(.goal), notePath: note.relativePath) }
        LookedAtMenuItem(model: model, note: note)
        NoteGoalOptions(model: model, note: note)
        if model.canArchive(note) {
            Button("Archive") { model.archive(note) }
        }
    }
}

/// The folding heading both goal lists use for Done, Missed and Dropped. One view, so the two
/// rooms cannot come to draw the same thing differently (build 168's lesson).
struct GoalEndedHeader: View {
    let status: NoteStatus
    let count: Int
    let folded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                MarkImage(folded ? "chevron.right" : "chevron.down")
                    .font(Txt.listSecond)
                Text(status.label)
                Text("\(count)")
                    .font(Txt.listSecond.monospacedDigit())
                    .padding(.horizontal, 5)
                    .background(.quaternary, in: Capsule())
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    ///
    /// **Filled, since build 176.** He asked whether the star could be made "a bit more
    /// popping" without a second colour, and a filled shape is what carries a tint — the same
    /// thing the New note button learned in build 156, where most of the pop turned out to be
    /// the fill rather than the glyph.
    static let aspiration = "star.fill"
    static let datedGoal = SidebarSection.kind(.goal).markName   // target
    static let project = SidebarSection.kind(.project).markName  // flag
    static let area = SidebarSection.kind(.area).markName        // circle.grid.2x2
    static let task = SidebarSection.allActions.markName         // circle

    /// The right one for a goal note, whichever kind of goal it is.
    static func forGoal(_ note: Note) -> String {
        (note.horizon ?? .year) == .life ? aspiration : datedGoal
    }

    /// What that mark is called when it stands in for an icon (build 281): the Icon… button
    /// says it, and so does a tile a screen reader lands on.
    static func word(for note: Note) -> String {
        (note.horizon ?? .year) == .life ? "Star" : "Target"
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

/// The colour of each link in the chain, paired with `ChainSymbol` above.
///
/// **Build 189, his choice from a preview** (https://claude.ai/artifact/4ka6hyMeeTCuEBMjN5Ajc2).
/// An aspiration wears a **deeper gold** than a goal with a date. He had asked for this since
/// build 175: *"sometimes I have difficulties understanding what is an aspiration and what is
/// a goal."* Build 176 answered it with words; this answers it with the colour.
///
/// **It stays inside the goal family on purpose.** A colour in PARAGON is a claim about what a
/// thing is (build 169), and an aspiration is the head of the goals, not a fifth kind of note.
/// Plum was drawn and rejected for exactly that, and because it neighbours the Calendar's
/// violet.
///
/// **The sidebar row named Goals keeps the plain gold**, the same reasoning as build 168's
/// icon: the row is the whole family, so it wears the family's colour. `SidebarSection.tint`
/// is untouched, and so is the tint over the detail column.
enum ChainTint {
    /// The one place the deeper gold is spelled.
    static let aspiration = Color("AspirationTint")
    static let datedGoal = ParaKind.goal.tint

    /// The right one for a goal note, whichever kind of goal it is.
    static func forGoal(_ note: Note) -> Color {
        (note.horizon ?? .year) == .life ? aspiration : datedGoal
    }

    /// The right one for a `goal:` line, which may name either kind. A name with no note behind
    /// it takes the dated goal's gold, never the aspiration's — the same rule `ChainSymbol` uses,
    /// so an unresolved link never claims to be an aspiration.
    static func forGoal(named reference: String, in index: NoteIndex) -> Color {
        // Written out rather than `.map(forGoal)`: `forGoal` is overloaded, and there is no
        // Swift compiler here to settle which one a bare function reference means (build 168).
        guard let note = index.goal(matching: reference) else { return datedGoal }
        return forGoal(note)
    }
}

/// A goal note's mark at the head of a row or a page: the star or the target it has always had,
/// or, once he has chosen one with **Icon…** (build 276), his own icon on his colour at the same
/// size. **This is the one place that decides it** for the Aspirations and Goals lists, the
/// aspiration's page and the weekly review's goal rows, so they cannot disagree (build 168).
///
/// A goal with no icon is drawn exactly as before: `KindBadge` with `ChainSymbol.forGoal` and
/// `ChainTint.forGoal`. The star and the target stay what the *default* means (builds 164 to
/// 189); a chosen icon is the user's own mark, and the room it is drawn in (Aspirations or
/// Goals) and its sentence still say which of the two it is. A shape either way, so the
/// selection fill leaves its colour alone (build 200). A tile is decoration beside a title that
/// names the goal, so a screen reader skips it.
struct GoalMark: View {
    let note: Note
    let size: CGFloat

    var body: some View {
        if note.ownIcon.isIconOrColour {
            // Build 281: a colour with no icon keeps the star or the target, on that colour.
            NoteIconTile(note: note, fallbackTint: ChainTint.forGoal(note), size: size,
                         defaultMark: ChainSymbol.forGoal(note))
                .accessibilityHidden(true)
        } else {
            KindBadge(kind: .goal, size: size, markName: ChainSymbol.forGoal(note),
                      tint: ChainTint.forGoal(note))
        }
    }
}

/// The two kinds of goal, named and explained in one place.
///
/// **Build 176, and it is not a drawing problem.** He said: *"sometimes I have difficulties
/// understanding what is an aspiration and what is a goal."* An icon can only remind you of
/// something you already know, so no amount of star-versus-target fixes that. Two things do:
///
/// 1. **The word "Goal" alone is the ambiguous one.** An aspiration *is* a kind of goal, so
///    calling the dated one just "Goal" asks him to hold both meanings at once. Wherever the
///    two sit together it is spelled **"Goal with a date"**, and the name then carries the rule.
/// 2. **The difference is the date**, and one short line says so where they sit side by side.
///    Read a few times, it stops being needed — which is the point.
enum GoalWording {
    static let aspiration = "Aspiration"
    static let datedGoal = "Goal with a date"

    /// The short form, for the one place the target date is printed immediately after it: a
    /// Map box, where "Goal with a date · by 2031-08-01" would say the same thing twice and be
    /// cut off at this width anyway. The date beside the word teaches the rule by itself.
    static let datedGoalShort = "Goal"

    static let aspirationRule = "What you are becoming. No date."
    static let datedGoalRule = "What you will have done, by a date."

    static func isAspiration(_ note: Note) -> Bool { (note.horizon ?? .year) == .life }
    static func name(for note: Note) -> String { isAspiration(note) ? aspiration : datedGoal }
    static func rule(for note: Note) -> String { isAspiration(note) ? aspirationRule : datedGoalRule }
}

/// One aspiration in the list: its name, how many goals serve it, when you last looked at it,
/// and whether any of them wants attention.
///
/// **No per cent, since build 199, and that is the point of the build.** His screenshot of the
/// old row read **100% · 3 goals · ⚠ 2 goals need attention**, which cannot all be true. The
/// bar was the average of the goals under it, and three goals with no projects yet each count
/// as nothing to measure — so the bar quietly showed the one goal that *had* a finished
/// project and called it the whole aspiration. More than that: **you never finish an
/// aspiration.** A per cent on one is a promise the idea does not make, and build 141 already
/// said an absence may not look like a number. What belongs here instead is how long it has
/// been since you last thought about it, which is the question an aspiration actually asks.
struct AspirationRow: View {
    @EnvironmentObject private var model: AppModel
    let chain: AspirationChain

    /// Days since the `reviewed:` line, or nil for one nobody has looked at yet. Worked out
    /// here rather than in the body (the `@ViewBuilder` rule, build 58).
    private var daysSinceLook: Int? {
        chain.note.reviewedDate.map { DateOnly.today().days(since: $0) }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            GoalMark(note: chain.note, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chain.note.title)
                        .font(Txt.listTitle)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    // Orange, as everywhere: look at this. On the row's right, where every
                    // list keeps its one capsule (1.0).
                    let wanting = chain.goalsNeedingAttention.count
                    if wanting > 0 {
                        Pill(text: wanting == 1 ? "1 goal needs attention" : "\(wanting) goals need attention",
                             color: Theme.attention)
                    } else if chain.needsAttention {
                        Pill(text: chain.flags.first?.label ?? "Needs attention", color: Theme.attention)
                    }
                }
                // 1.0: one quiet second line. How many goals serve it (or that nothing does yet
                // — said on the row rather than in a group of its own, build 199), when you last
                // looked at it, the area that holds it, and the measure (build 163).
                Text(secondLine)
                    .font(Txt.listSecond)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var secondLine: String {
        var parts: [String] = []
        if !chain.goals.isEmpty {
            parts.append(chain.goals.count == 1 ? "1 goal" : "\(chain.goals.count) goals")
        } else if chain.isBare {
            parts.append("Nothing serves this yet")
        }
        parts.append(ReviewWording.lookedAt(daysAgo: daysSinceLook))
        if let area = chain.area { parts.append(area.title) }
        if let measure = chain.note.measure, !measure.isEmpty { parts.append(measure) }
        return parts.joined(separator: " \u{00B7} ")
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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            GoalMark(note: note, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.title)
                        // Struck through however it ended: done, missed or dropped, it is over.
                        .strikethrough(note.isEnded)
                        .font(Txt.listTitle)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if note.isEnded {
                        Pill(text: note.noteStatus.label, color: note.isAchieved ? ParaKind.goal.tint : Color.secondary)
                    } else if needsAnAspiration {
                        // Build 167: the one button that fixes it, kept on the row.
                        NoAspirationPrompt(model: model, note: note)
                    } else if health.needsAttention, let first = health.flags.first {
                        Pill(text: first.label, color: Theme.attention)
                    }
                }
                // 1.0: one quiet second line — how far it has come, the target and how long is
                // left, and the measure (build 163). Red only when the target has passed.
                if let second = secondLine(health) {
                    Text(second.text)
                        .font(Txt.listSecond)
                        .foregroundStyle(second.late ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func secondLine(_ health: ChainGoal) -> (text: String, late: Bool)? {
        var parts: [String] = []
        var late = false
        if let percent = health.progress.percent { parts.append("\(percent) %") }
        if let target = note.targetDate {
            parts.append("\(target.description) \u{00B7} \(target.timeLeftText(from: .today()))")
            if overdue(target) { late = true }
        }
        if let measure = note.measure, !measure.isEmpty { parts.append(measure) }
        guard !parts.isEmpty else { return nil }
        return (parts.joined(separator: " \u{00B7} "), late)
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
                    // 1.0: the same reading width as a note, centred; the rest is calm margin.
                    if isAspiration {
                        AspirationChainBody(chain: model.index.chain(of: note), compact: false)
                            .padding(Theme.gutter)
                            .readingWidth()
                    } else {
                        ChainGoalBlock(goal: model.index.chainGoal(of: note), lead: true)
                            .padding(Theme.gutter)
                            .readingWidth()
                    }
                }
            }
        }
    }

    private var isAspiration: Bool { (note.horizon ?? .year) == .life }

    private var header: some View {
        GoalsHeader(title: showsNote ? "Note" : (isAspiration ? GoalWording.aspiration : GoalWording.datedGoal),
                    markName: showsNote ? "doc.text" : ChainSymbol.forGoal(note),
                    showsAll: model.section == .aspirations,
                    quiet: !showsNote) {
            // Build 159's two-state control: it shows the state you are in, not the one you
            // would get.
            StateToggle(markName: "doc.text", title: "Note",
                        isOn: showsNote, tint: ChainTint.forGoal(note)) {
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
    /// True on the aspiration's own page (1.0): the note's header, title at 26 and the facts
    /// panel. **All of them** draws every aspiration in one scroll and keeps a 17-point heading.
    var fullHead = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !compact { head }
            if compact {
                // The phone has no aspiration page, so the reason (build 277) and the measure's
                // button live in the folded-open chain (review of 271): the row above shows the
                // measure, and this is what changes it. Its own list row, outside the fold
                // button, so it is never a button inside a button (builds 71–74).
                AspirationReasonBox(note: chain.note)
                GoalMeasureChip(model: model, note: chain.note, onChainPage: true)
            }
            if let changed = chain.activity.summary {
                MarkLabel(changed, "clock.arrow.circlepath")
                    .font(Txt.label)
                    .foregroundStyle(Theme.soft)
                    .lineLimit(2)
            }
            if fullHead && !compact {
                // 1.0: on the aspiration's own page the goals sit in a panel of the goal gold,
                // headed Goals, with **Add a goal…** at its foot — the shape of the Projects
                // panel on a goal's page.
                goalsPanel
            } else {
                if chain.isBare {
                    // Build 269: the old line asked him to type `goal:` into another note. The
                    // button under it makes the goal instead, already serving this aspiration.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nothing works towards this yet.")
                            .font(Txt.value)
                            .foregroundStyle(.secondary)
                        AddServingNoteButton(model: model, parent: chain.note)
                    }
                }
                ForEach(chain.goals) { goal in
                    ChainGoalBlock(goal: goal, lead: false, under: chain.note.title)
                }
                // **Add a goal…** at the foot of the goals (build 269), on the phone too: the
                // phone has no aspiration page, so the folded-open chain is the only place to add
                // a second goal from (the review of 271 put the measure there for the same
                // reason). A bare chain has the button above, beside the line it answers.
                if !chain.isBare {
                    AddServingNoteButton(model: model, parent: chain.note)
                }
            }
            // One heading per ending, never one heading for all three: a group called Done
            // may not hold a goal that was missed (build 165).
            ForEach(endedGroups, id: \.status) { group in
                SectionLabel(title: group.status.label, count: group.goals.count,
                             markName: group.status == .done ? "checkmark.seal" : "xmark.circle",
                             tint: group.status == .done ? ParaKind.goal.tint : .secondary)
                ForEach(group.goals) { goal in
                    endedRow(goal)
                }
            }
            if !chain.projects.isEmpty {
                SectionLabel(title: "Straight under the aspiration", count: nil,
                             markName: "shippingbox", tint: ParaKind.project.tint)
                ForEach(chain.projects) { project in
                    ChainProjectRow(project: project)
                }
            }
            if !chain.areas.isEmpty {
                SectionLabel(title: "Areas that hold this", count: nil,
                             markName: ChainSymbol.area, tint: ParaKind.area.tint)
                ForEach(chain.areas) { area in
                    Button { model.show(section: model.section ?? .kind(.goal), notePath: area.relativePath) } label: {
                        MarkLabel(area.title, ChainSymbol.area)
                            .foregroundStyle(ParaKind.area.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The goals under the aspiration, as the page draws them (1.0).
    private var goalsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Heading(text: "Goals", color: ChainTint.datedGoal, count: chain.goals.count)
            if chain.isBare {
                Text("Nothing works towards this yet.")
                    .font(Txt.value)
                    .foregroundStyle(.secondary)
            }
            ForEach(chain.goals) { goal in
                ChainGoalBlock(goal: goal, lead: false, under: chain.note.title)
            }
            AddServingNoteButton(model: model, parent: chain.note)
                .padding(.top, 2)
        }
        .panel(ChainTint.datedGoal)
    }

    /// **Every row inside a chain keeps the room you are in** — `model.section`, not a fixed
    /// one. Build 135's rule: a row inside a working screen should select, not navigate away.
    /// Since build 199 there are two goal rooms, so naming one of them here would throw the
    /// Aspirations list out of the middle column each time a goal under it was pressed.
    ///
    /// The goals that are over, split by how they ended and in the order the menu offers.
    /// Worked out here rather than in the body: a `@ViewBuilder` takes views, not loops.
    private var endedGroups: [(status: NoteStatus, goals: [ChainGoal])] {
        NoteStatus.endings.compactMap { ending in
            let over = chain.endedGoals.filter { $0.note.noteStatus == ending }
            return over.isEmpty ? nil : (ending, over)
        }
    }

    private func endedRow(_ goal: ChainGoal) -> some View {
        Button { model.show(section: model.section ?? .kind(.goal), notePath: goal.note.relativePath) } label: {
            HStack(spacing: 6) {
                endedMark(goal.note)
                Text(goal.note.title)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let target = goal.note.targetDate {
                    Text(target.description)
                        .font(Txt.label)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    /// The small mark before an ended goal's name: the grey target it has always had, or his own
    /// icon (build 276). A function rather than inline: the row is a button label, and a branch
    /// on the icon is cleaner to read here than in the middle of that closure.
    @ViewBuilder
    private func endedMark(_ note: Note) -> some View {
        if note.ownIcon.isIconOrColour {
            NoteIconTile(note: note, fallbackTint: ChainTint.forGoal(note), size: 16,
                         defaultMark: ChainSymbol.forGoal(note))
                .accessibilityHidden(true)
        } else {
            MarkImage(ChainSymbol.datedGoal)
                .font(Txt.listSecond)
                .foregroundStyle(.secondary)
        }
    }

    /// 1.0: on its own page the aspiration has the note's header — the title at 26 points and
    /// the facts panel (Aspiration, Icon…, Status, Horizon, Measure, Looked at, Tags) with the
    /// same bordered buttons a project's page has — and under it his reason (build 277). The
    /// chips it replaces were the same facts (builds 268 to 276); nothing was taken away, and
    /// **Areas that hold this** further down still names the area. In **All of them** the name
    /// is a heading, so the page stays a list.
    @ViewBuilder
    private var head: some View {
        if fullHead {
            VStack(alignment: .leading, spacing: 10) {
                NoteHeader(note: chain.note, inset: false,
                           notices: chain.flags.filter { $0 != .achieved }.map(\.label))
                AspirationReasonBox(note: chain.note)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    GoalMark(note: chain.note, size: 24)
                    Heading(text: chain.note.title, color: ChainTint.aspiration)
                    ForEach(chain.flags.filter { $0 != .achieved }, id: \.self) { flag in
                        Pill(text: flag.label, color: Theme.attention)
                    }
                }
                // The three presses the page has always offered here (builds 268, 270, 276):
                // the icon, the measure and "looked at today" — bordered, in the part's colour.
                WrappingHStack(spacing: 8, lineSpacing: 6) {
                    NoteIconChip(model: model, note: chain.note)
                    GoalMeasureChip(model: model, note: chain.note)
                    LookedAtChip(model: model, note: chain.note)
                }
                .font(Txt.value)
                .lineLimit(1)
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .tint(ChainTint.aspiration)
                AspirationReasonBox(note: chain.note)
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
        VStack(alignment: .leading, spacing: lead ? Theme.panelGap : 6) {
            if lead {
                // 1.0: the goal's own page has the note's header — the title at 26 points and
                // the facts panel with Serves, Horizon, Target, Progress, Measure, Looked at
                // as bordered pop-ups and buttons — like a project's or an area's page. The
                // chips it replaces were the same facts (build 268); nothing was taken away.
                // **No button around the head** (build 268): pressing it would only have
                // opened the page you are already on.
                NoteHeader(note: goal.note, inset: false, progress: goal.progress,
                           notices: goal.flags.filter { $0 != .achieved }.map(\.label))
                if let changed = goal.activity.summary {
                    MarkLabel(changed, "clock.arrow.circlepath")
                        .font(Txt.label)
                        .foregroundStyle(Theme.soft)
                        .lineLimit(2)
                }
                projectsPanel
            } else {
                Button { model.show(section: model.section ?? .kind(.goal), notePath: goal.note.relativePath) } label: {
                    head
                }
                .buttonStyle(.plain)
                rail
            }
        }
    }

    /// The goal's own page (1.0): its projects in a panel of the project green, headed
    /// **Projects**, with **Add a project…** at the foot (build 269). The same rows as inside a
    /// chain, without the rail.
    private var projectsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Heading(text: "Projects", color: ParaKind.project.tint,
                    count: goal.projects.count + goal.finishedProjects.count)
            if goal.projects.isEmpty && goal.finishedProjects.isEmpty {
                Text("No project delivers this goal yet.")
                    .font(Txt.value)
                    .foregroundStyle(Theme.attention)
            }
            ForEach(goal.projects) { project in
                ChainProjectRow(project: project)
            }
            ForEach(goal.finishedProjects) { project in
                ChainProjectRow(project: project)
            }
            ForEach(goal.areas) { area in
                Button { model.show(section: model.section ?? .kind(.goal), notePath: area.relativePath) } label: {
                    MarkLabel(area.title, ChainSymbol.area)
                        .font(Txt.value)
                        .foregroundStyle(ParaKind.area.tint)
                }
                .buttonStyle(.plain)
            }
            AddServingNoteButton(model: model, parent: goal.note)
                .padding(.top, 2)
        }
        .panel(ParaKind.project.tint)
    }

    /// The small mark before the goal's name: the target it has always had, or his own icon at
    /// a size that can still be read (build 276).
    @ViewBuilder
    private var mark: some View {
        if goal.note.ownIcon.isIconOrColour {
            NoteIconTile(note: goal.note, fallbackTint: ChainTint.forGoal(goal.note), size: 20,
                         defaultMark: ChainSymbol.forGoal(goal.note))
                .accessibilityHidden(true)
        } else {
            MarkImage(ChainSymbol.datedGoal)
                .font(Txt.label)
                .foregroundStyle(ParaKind.goal.tint)
        }
    }

    /// The goal's name and its facts inside an aspiration's chain, where the whole head is one
    /// button that opens the goal, so its facts are plain capsules. (On the goal's own page the
    /// head is the note's header, 1.0.)
    private var head: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                mark
                Text(goal.note.title)
                    .font(Txt.sectionTitle)
                    .foregroundStyle(ParaKind.goal.tint)
                    .lineLimit(2)
            }
            WrappingHStack(spacing: 6, lineSpacing: 5) {
                if let target = goal.note.targetDate {
                    // Build 163: the date alone never says whether it is close. Spelled by
                    // `GoalTargetChip`, so a goal with a button and one without say it alike.
                    ChainChip(text: GoalTargetChip.words(for: target, withTimeLeft: true),
                              tint: GoalTargetChip.color(for: target, ended: goal.isEnded),
                              filled: false)
                }
                if let serves = servesToShow {
                    // The extra he ticked: a dated goal says what it is in service of.
                    // The chip takes the colour of the thing it NAMES, not of the goal
                    // it sits on — the deeper gold since build 189, and gold rather
                    // than the area's pink since build 169.
                    ChainChip(text: "Serves \(serves)",
                              tint: ChainTint.forGoal(named: serves, in: model.index),
                              filled: false)
                }
                if let percent = goal.progress.percent {
                    ChainChip(text: "\(percent)%", tint: ParaKind.goal.tint, filled: true)
                }
                ForEach(goal.flags, id: \.self) { flag in
                    ChainChip(text: flag.label,
                              tint: flag == .achieved ? ParaKind.goal.tint : Theme.attention,
                              filled: false)
                }
            }
            .font(Txt.label)
            .lineLimit(2)
        }
    }

    /// The projects under a goal inside an aspiration's chain, stepped in so the level shows.
    /// 1.0: no rail line beside them — the step is enough, and a stripe is not in the look.
    ///
    /// **Add a project…** (build 269) is offered here only under "No project delivers this
    /// goal yet.", where it answers the line above it; on the goal's own page it is at the foot
    /// of the Projects panel. It sits under the head, never in the head's button.
    private var rail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if goal.projects.isEmpty && goal.finishedProjects.isEmpty {
                Text("No project delivers this goal yet.")
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention)
                AddServingNoteButton(model: model, parent: goal.note)
            }
            ForEach(goal.projects) { project in
                ChainProjectRow(project: project)
            }
            ForEach(goal.finishedProjects) { project in
                ChainProjectRow(project: project)
            }
            ForEach(goal.areas) { area in
                Button { model.show(section: model.section ?? .kind(.goal), notePath: area.relativePath) } label: {
                    MarkLabel(area.title, ChainSymbol.area)
                        .font(Txt.value)
                        .foregroundStyle(ParaKind.area.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
    }
}

/// One project under a goal, with the one thing to do next on it.
struct ChainProjectRow: View {
    @EnvironmentObject private var model: AppModel
    let project: ChainProject

    var body: some View {
        Button {
            model.show(section: model.section ?? .kind(.goal), notePath: project.note.relativePath)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    MarkImage(ChainSymbol.project)
                        .font(Txt.listSecond)
                        .foregroundStyle(project.note.isEnded ? Color.secondary : ParaKind.project.tint)
                    Text(project.note.title)
                        .font(Txt.value)
                        .strikethrough(project.note.isEnded)
                        .foregroundStyle(project.note.isEnded ? Color.secondary : ParaKind.project.tint)
                        .lineLimit(2)
                    // **Build 169: the count belongs to the project, so it sits next to it.**
                    // A `Spacer` pushed "2 open" out to the right edge of a wide column, far
                    // from the name it counts, and with several projects the numbers formed a
                    // column of their own that read as a separate list.
                    if project.note.isEnded {
                        Text(project.note.noteStatus.label.lowercased())
                            .font(Txt.listSecond).foregroundStyle(.secondary)
                    } else if project.openTaskCount > 0 {
                        Text("\(project.openTaskCount) open").font(Txt.listSecond).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if let next = project.nextAction {
                    MarkLabel("Next: \(next.title)", ChainSymbol.task)
                        .font(Txt.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if project.hasNothingToDo {
                    Text("No next action")
                        .font(Txt.label)
                        .foregroundStyle(.orange)
                } else if project.waitingCount > 0, !project.note.isEnded {
                    // Build 279: nothing he can do himself, but not idle: every open line waits
                    // for somebody else. The same words and the same calm grey as the Projects
                    // list (build 168), never the orange of a project nobody can act on.
                    MarkLabel(ProjectLine.waitingText(count: project.waitingCount), WaitingShowing.symbol)
                        .font(Txt.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(.plain)
        // Named by its path for the screen tests (build 269), the same name the project
        // carries in a goal's own page on the phone (`GoalDashboardView`).
        .accessibilityIdentifier("serves.\(project.note.relativePath)")
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
            .font(Txt.label)
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
            MarkLabel(status.label, symbol(for: status))
                .font(Txt.label)
                .foregroundStyle(tint(for: status))
        }
        .fixedSize()
        .help("How this note stands. Done means it delivered; Missed means it is over and did not happen; Dropped means you called it off.")
    }

    private func statusBinding(_ live: Note) -> Binding<NoteStatus> {
        Binding(get: { live.noteStatus },
                set: { model.setStatus($0, for: live) })
    }

    private func symbol(for status: NoteStatus) -> String { status.markName }

    /// Done is the note's own colour because it is the good ending. Missed is orange, the
    /// colour this app already uses for "look at this". **Dropped is grey on purpose** — it is
    /// not a failure, it is a decision, and drawing it in a warning colour would say otherwise.
    private func tint(for status: NoteStatus) -> Color {
        status.tint(onNote: note.tint)
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
            GoalsHeader(title: "All of them", markName: "list.bullet.indent") { EmptyView() }
            Divider()
            outline(chains: chains, loose: loose)
        }
    }

    private func outline(chains: [AspirationChain], loose: [Note]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if chains.isEmpty && loose.isEmpty {
                    EmptyStateView(title: "No aspirations yet",
                                   markName: ChainSymbol.aspiration,
                                   message: "An aspiration says what you are becoming. Make one and everything working towards it appears here.",
                                   tint: ChainTint.aspiration)
                }
                ForEach(chains) { chain in
                    AspirationChainBody(chain: chain, compact: false, fullHead: false)
                }
                // Build 100's rule: a screen called "your whole life" may not quietly leave
                // out the goals that hang under no aspiration.
                if !loose.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Goals with no aspiration", count: loose.count,
                                     markName: ChainSymbol.datedGoal, tint: .orange)
                        Text("Each of these is working towards nothing. Give it the aspiration it is in service of.")
                            .font(Txt.label)
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
    private let markName: String
    /// **Only the Aspirations room has All of them** (build 199). The Goals row is already one
    /// list of every dated goal, so there is nothing for the button to open there — and a
    /// control that does nothing where it is drawn is worse than no control (build 175).
    private let showsAll: Bool
    /// True on the goal and aspiration pages (1.0): the facts panel under it already carries
    /// the kind as its heading, so this row says it quietly, in small grey, and holds the
    /// buttons. Build 280's first pictures had "Goal with a date" twice, one above the other.
    private let quiet: Bool
    private let trailing: Trailing
    @AppStorage(GoalsShowAll.key) private var showAll = false

    /// Written out rather than left to the memberwise initializer: a struct that mixes a
    /// property wrapper with a `@ViewBuilder` stored property is exactly where the generated
    /// one is hard to predict, and there is no Swift compiler in this container to ask.
    init(title: String, markName: String, showsAll: Bool = true, quiet: Bool = false,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.markName = markName
        self.showsAll = showsAll
        self.quiet = quiet
        self.trailing = trailing()
    }

    /// True only where the button is both offered and on, so a setting left on in the
    /// Aspirations room cannot rename the Goals room's header.
    private var showingAll: Bool { showsAll && showAll }

    var body: some View {
        HStack(spacing: 8) {
            if quiet && !showingAll {
                MarkLabel(title, markName)
                    .font(Txt.label)
                    .foregroundStyle(Theme.soft)
                    .lineLimit(1)
                Spacer(minLength: 0)
            } else {
                SectionLabel(title: showingAll ? "All of them" : title, count: nil,
                             markName: showingAll ? "list.bullet.indent" : markName,
                             tint: ParaKind.goal.tint)
            }
            trailing
            if showsAll {
                StateToggle(markName: "list.bullet.indent", title: "All of them",
                            isOn: showAll, tint: ParaKind.goal.tint) {
                    showAll.toggle()
                }
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
            MarkLabel("Give it an aspiration", "exclamationmark.triangle.fill")
                .font(Txt.label)
                .rowTint(.orange)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("This goal hangs under no aspiration. Choose the one it is in service of.")
    }
}

/// **Add a project…** on a goal, **Add a goal…** on an aspiration (build 269), and — with
/// `link: .area` — **Add a project…** on an area (the area page, a later build).
///
/// **You stay where you are** (his answer, 21 October). The note is made through
/// `makeNoteSayingWhy`, the quiet way build 203 made for the New note sheet, never through
/// `createNote`, whose `show(_:)` would carry him out of the Goals room into Projects (builds
/// 135 and 203). The new note appears in the list under the button at once, already linked,
/// and one press on it opens it. A goal often needs more than one project, so the button stays
/// for the next one.
///
/// **What it makes is decided in Core** (`ServingNote`, tested): a project under a goal with a
/// date, a goal with a date under an aspiration, a project under an area. The link line is the
/// parent's title, the same value **Serves…** writes.
///
/// A plain-style button, so it can sit in a phone list row beside other buttons without the
/// row taking the press (builds 71–74), and never inside another button: on the goal's own
/// page it sits in the rail under the head, never in it (build 268).
struct AddServingNoteButton: View {
    @ObservedObject var model: AppModel
    let parent: Note
    /// Which line ties the new note to `parent`: `goal:` on a goal or an aspiration, `area:`
    /// on an area.
    var link: ServingLink = .goal
    @State private var adding = false

    /// Read back out of the model: a chip on the same page may have just renamed or changed
    /// the note, and the copy handed in is then one behind (build 144).
    private var live: Note { model.note(at: parent.relativePath) ?? parent }

    var body: some View {
        let plan = ServingNote(under: live, link: link)
        Button { adding = true } label: {
            MarkLabel(plan.buttonTitle, "plus.circle")
                .font(Txt.value)
                .foregroundStyle(plan.tint)
                .helpWhenClosed(plan.helpText, open: adding)
        }
        .buttonStyle(.bordered)
        .tint(plan.tint)
        .accessibilityIdentifier(plan.identifier)
        .popover(isPresented: $adding) {
            AddServingNoteBox(plan: plan, cancel: { adding = false }) { (name: String) -> String? in
                add(name, plan)
            }
        }
    }

    /// Makes the note and closes the box, or says why it made none. **Every reason is handed
    /// back to the box**, never put in an alert: an alert behind a popover is two presentations
    /// at once (builds 238 and 246), and the box keeps his words so a second try costs nothing.
    private func add(_ name: String, _ plan: ServingNote) -> String? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "Write a name first." }
        if let taken = ServingNote.existing(named: title, kind: plan.kind, among: model.notes) {
            return plan.nameInUse(taken.displayTitle)
        }
        do {
            guard try model.makeNoteSayingWhy(kind: plan.kind, title: title,
                                              extraFrontmatter: plan.frontmatter) != nil else {
                return "No folder of notes is open."
            }
        } catch VaultError.noteAlreadyExists(_) {
            // A note that is still coming from iCloud is not in the list yet, so only the
            // vault itself can say the name is taken.
            return plan.nameInUse(title)
        } catch VaultError.invalidTitle {
            return "That name cannot be used for a file. Use letters and numbers."
        } catch {
            return error.localizedDescription
        }
        adding = false
        return nil
    }
}

/// What **Add a project…** and **Add a goal…** open: a heading, one field for the name, one
/// line that says what the new note will serve, and **Cancel** and **Add project** (or **Add
/// goal**). Return adds, as the button does. A small popover on the phone too, the shape of
/// `GoalMeasureEditor` (build 268): it hangs near the button, so the keyboard does not cover
/// the buttons (builds 160 and 231).
struct AddServingNoteBox: View {
    let plan: ServingNote
    let cancel: () -> Void
    /// Makes the note. The answer is nil when it was made, or why it was not, in words for
    /// the box.
    let add: (String) -> String?

    @State private var typed = ""
    /// Why the last press made nothing. Said inside the popover, never in an alert over it: a
    /// popover's messages belong in the popover (build 238).
    @State private var notice: String? = nil
    /// Set once the note is made. On the Mac Return can reach both the field's own submit and
    /// the default button, and a second press must not answer "already a project called…"
    /// about the note the first one has just made.
    @State private var made = false
    @FocusState private var focused: Bool

    private var trimmed: String { typed.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkLabel(plan.heading, plan.symbol)
                .font(Txt.label.weight(.semibold))
                .foregroundStyle(plan.tint)
            TextField("Name", text: $typed)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(commit)
                .accessibilityIdentifier("addNote.field")
            Text(plan.sentence)
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let notice {
                Text(notice)
                    .font(Txt.label)
                    .foregroundStyle(Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("addNote.notice")
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .accessibilityIdentifier("addNote.cancel")
                Button(plan.addTitle, action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
                    .accessibilityIdentifier("addNote.add")
            }
        }
        .padding(14)
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
        .onAppear {
            typed = ""
            notice = nil
            made = false
            // Focus does not always take in the turn the popover appears (build 119).
            DispatchQueue.main.async { focused = true }
        }
    }

    /// An empty field does nothing: the button is greyed out, and Return must not say "Write a
    /// name first." about a field he has not started on.
    private func commit() {
        guard !trimmed.isEmpty, !made else { return }
        let problem = add(typed)
        notice = problem
        if problem == nil { made = true }
    }
}

/// The words and colours of **Add a project…** and **Add a goal…**, in one place, so the
/// button, its box and the screen test's names cannot drift apart. What the button *makes* is
/// Core's decision (`ServingNote`); how it is said is the app's.
extension ServingNote {
    /// The button: **Add a project…** or **Add a goal…**.
    var buttonTitle: String { makesAGoal ? "Add a goal\u{2026}" : "Add a project\u{2026}" }
    /// The button inside the box that makes it.
    var addTitle: String { makesAGoal ? "Add goal" : "Add project" }
    /// The box's heading.
    var heading: String { makesAGoal ? "New goal" : "New project" }
    /// The word for one of what is made, inside a sentence.
    var noun: String { makesAGoal ? "goal" : "project" }
    /// The symbol of what is made: the target for a goal with a date, the flag for a project.
    var symbol: String { makesAGoal ? ChainSymbol.datedGoal : ChainSymbol.project }
    /// The colour of what is made: a goal's gold, a project's green.
    var tint: Color { makesAGoal ? ChainTint.datedGoal : ParaKind.project.tint }

    /// Named after what it is pressed on and what it makes, for the screen tests. A name of its
    /// own, never the button's words (build 191).
    var identifier: String {
        switch link {
        case .area: return "area.addProject"
        case .goal: return makesAGoal ? "aspiration.addGoal" : "goal.addProject"
        }
    }

    /// The one line under the field: what the new note will serve, and — for a goal, which is
    /// made without one — where its date is set.
    var sentence: String {
        let serves: String
        switch link {
        case .goal: serves = "It will serve \u{201C}\(parentTitle)\u{201D}."
        case .area: serves = "It will be in the area \u{201C}\(parentTitle)\u{201D}."
        }
        guard makesAGoal else { return serves }
        return serves + " It has no target date yet. Open it and press Set a target date\u{2026} to give it one."
    }

    /// The Mac's tooltip on the button.
    var helpText: String {
        switch link {
        case .area: return "Make a new project in this area. You stay on this page."
        case .goal:
            return makesAGoal
                ? "Make a new goal that serves this aspiration. You stay on this page."
                : "Make a new project that serves this goal. You stay on this page."
        }
    }

    /// What the box says when the name is taken.
    func nameInUse(_ name: String) -> String {
        "There is already a \(noun) called \u{201C}\(name)\u{201D}. Use another name."
    }
}

extension NoteStatus {
    /// The symbol for each way a note can stand. One place, because the status chip, the
    /// Projects list's headings and its On hold pill all draw them (build 253, build 168's rule).
    var markName: String {
        switch self {
        case .active: return "circle"
        case .onHold: return "pause.circle"
        case .done: return "checkmark.circle.fill"
        case .missed: return "xmark.circle"
        case .dropped: return "minus.circle"
        case .archived: return "archivebox"
        }
    }

    /// The colour each way a note can stand is drawn in, given the note's own colour: done in
    /// it (the good ending), missed orange (this app's "look at this"), dropped and the rest
    /// grey — dropping is a decision, not a failure (build 165). One place since build 262, for
    /// the status chip, the Projects list's headings and the line under a finished project.
    func tint(onNote noteTint: Color) -> Color {
        switch self {
        case .done: return noteTint
        case .missed: return .orange
        default: return .secondary
        }
    }
}

/// When this note was last looked at, and the one press that says you have looked at it today
/// (build 270, idea 3). On an aspiration, a goal with a date and an area: at the top of the
/// note, and on the goal's and the aspiration's own page in **Goals** and **Aspirations**.
///
/// **Before this build the only way to write `reviewed:` was the Weekly review's right-click
/// menu.** The Aspirations list and **Due for a look** both read it, so an aspiration you had
/// just thought about for an hour still said "Never looked at" until you went to the review and
/// found it there. The rule this project keeps earning, turned round: a screen that shows a
/// fact needs the control that changes it within reach.
///
/// **A popover with a named button, never a `Menu`.** A menu puts its lines where the Mac's test
/// tree cannot reach them by name, and a popover can say how often this kind of note gets a look
/// and when the next one is due, which is the question the button raises. The same shape as
/// `GoalTargetChip` and `GoalMeasureChip`, and the same two looks: a grey label in a note's
/// header, and a capsule on the chain page — solid once it has been looked at, dashed while it
/// never has (build 142's language). **Grey either way**: when a look is due the Weekly review
/// says so in orange; here it is a fact about the note, not a warning.
///
/// **Nothing is drawn for a note with no place on a rhythm** — an ended goal, an archived area.
/// A review is a question about work you are still doing, so offering **I looked at it today**
/// on one that is over would be a button about nothing.
struct LookedAtChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    var onChainPage: Bool = false
    @State private var showingBox = false

    var body: some View {
        // Read back out of the model on every draw (build 144): a press saves, and the note
        // handed in is then one save behind.
        if let due = model.reviewDue(of: note) {
            Button { showingBox = true } label: {
                face(due)
                    .helpWhenClosed("When you last looked at this, how often it gets a look, and a button to say you looked at it today.",
                                    open: showingBox)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(due.lookedAtText))
            // `note.lookedAt` on every kind it is drawn on, never `goal.…`: an area carries it
            // too, and a name that says "goal" on an area would be a name that lies (build 196).
            .accessibilityIdentifier("note.lookedAt")
            .popover(isPresented: $showingBox) {
                LookedAtBox(due: due) {
                    model.markReviewed(due.note)
                    showingBox = false
                }
            }
        }
    }

    @ViewBuilder
    private func face(_ due: ReviewDue) -> some View {
        if onChainPage {
            MarkLabel(due.lookedAtText, "eye")
                .font(Txt.label)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay(
                    Capsule().strokeBorder(Color.secondary.opacity(0.55),
                                           style: StrokeStyle(lineWidth: 1,
                                                              dash: due.daysSinceReview == nil ? [3, 2] : []))
                )
                .foregroundStyle(.secondary)
        } else {
            // A wrapping row measures each item at its natural width (build 250), so the words
            // are capped like the other chips in the header.
            MarkLabel(due.lookedAtText, "eye")
                .lineLimit(1)
                .frame(maxWidth: 260, alignment: .leading)
                .foregroundStyle(.secondary)
        }
    }
}

/// What the **Looked at** button opens: when you last looked, how often this kind of note gets a
/// look and when the next one is due, and **I looked at it today**. Every sentence comes from
/// `ReviewDue` (Core, tested), so the box and the Weekly review cannot tell one note two things.
///
/// **I looked at it today** is greyed while the note already says today: pressing it again
/// would write nothing (`AppModel.markReviewed`), and a button that does nothing where it is
/// drawn is worse than no button (build 175). The box closes when you press anywhere outside it.
struct LookedAtBox: View {
    let due: ReviewDue
    let lookedAtToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkLabel(due.lookedAtText, "eye")
                .font(Txt.label.weight(.semibold))
            Text(due.rhythmText + " " + due.nextText)
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("How often is set in **Settings \u{203A} Review rhythm**.")
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("I looked at it today", action: lookedAtToday)
                    .keyboardShortcut(.defaultAction)
                    .disabled(due.daysSinceReview == 0)
                    .accessibilityIdentifier("lookedAt.today")
            }
        }
        .padding(14)
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
    }
}

/// **I looked at it today** on a right-click menu (a long press on the iPhone): the Aspirations
/// list, the Goals list and the Areas list (build 270). Left out for a note with no place on a
/// rhythm, and greyed while the note already says today, for the same reasons as the button at
/// the top of the note. The model is passed in rather than read from the environment:
/// context-menu content is built outside the row's own view hierarchy (`NoteGoalOptions`).
struct LookedAtMenuItem: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        if let due = model.reviewDue(of: note) {
            Button("I looked at it today") { model.markReviewed(note) }
                .disabled(due.daysSinceReview == 0)
        }
    }
}
