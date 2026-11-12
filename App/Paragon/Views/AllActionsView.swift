import SwiftUI
import ParagonCore

/// Every open task in the vault, grouped by the note it lives in. The one place to answer
/// "what is actually on my plate", without a search you have to remember.
///
/// **Build 198: tick boxes instead of the four-way Picker.** His own ask from the roadmap. The
/// old control was a segmented Picker holding **All / With a date / No date / Next actions**,
/// so it could only ever answer one question at a time — "overdue *and* important" was not
/// something the screen could be asked. The boxes are `FilterBox`, the same control and the
/// same rule as the Search screen (build 157): within a row an **or**, between rows an
/// **and**. Nothing the Picker could ask has been lost: "With a date" is the four dated boxes
/// together, and "No date" and "Next actions" are boxes of their own.
///
/// The filter itself lives in Core as `ActionFilter`, where it is tested (build 174's reason:
/// a rule that decides what you do not see has to be testable).
///
/// **Build 279: a switch beside the column's name, and a second half.** The **Waiting for**
/// switch turns the column into the lines he is waiting on other people for, grouped by person
/// (`WaitingForList`). The boxes filter actions, not people, so they are not drawn there. It is
/// a switch in this column and not a sidebar row or a Browse row: a second door into one room
/// (build 166). While it is off, one line says how many lines are waiting and opens the list,
/// so the lines are never out of sight and the switch is findable (build 74).
///
/// **Build 312: the switch has its words.** The hourglass and the filter symbol carried no
/// words, and the screen said its name three times ("All actions", "Actions 3", "Every open
/// action"). Now one two-part switch **Actions | Waiting for** sits under the title, in the
/// Actions colour, with the count in it; the filter is a worded button **Filter**; and the
/// line "Every open action" is gone — a filter line is drawn only when boxes are ticked.
struct AllActionsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("actionFiltersFolded") private var deskFolded = false
    /// Build 304: the filter boxes' measured height, so their scroll area is only as tall as they are.
    @State private var boxesHeight: CGFloat?
    @AppStorage("actionFiltersFoldedPhone") private var phoneFolded = true
    @AppStorage(WaitingShowing.key) private var showsWaiting = false

    private var folded: Bool { isPhone ? phoneFolded : deskFolded }
    private var tint: Color { SidebarSection.allActions.tint }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    /// A plain stub, so the body never carries an `#if` in the middle of a modifier chain
    /// (build 148's lesson about a broken chain, and build 160's about this pair).
    private var isPhone: Bool { false }
    #endif

    /// Every open action, before the boxes narrow it. Kept apart from `groups` so the empty
    /// state can tell "nothing open at all" from "the boxes ruled everything out" — build
    /// 100's rule, which is why this screen never says a bare "nothing here".
    private var everything: [TaskRef] { model.index.openTasks() }

    /// Notes in the order the sidebar lists them, each with the actions that pass the boxes.
    private func groups(_ refs: [TaskRef]) -> [(note: Note, tasks: [TaskRef])] {
        var byPath: [String: [TaskRef]] = [:]
        for ref in refs { byPath[ref.notePath, default: []].append(ref) }
        return model.notes.compactMap { note in
            guard let tasks = byPath[note.relativePath], !tasks.isEmpty else { return nil }
            return (note, tasks.sorted(by: byDueThenOrder))
        }
    }

    private func byDueThenOrder(_ a: TaskRef, _ b: TaskRef) -> Bool {
        switch (a.task.dueDate, b.task.dueDate) {
        case let (x?, y?): return x == y ? a.task.lineIndex < b.task.lineIndex : x < y
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return a.task.lineIndex < b.task.lineIndex
        }
    }

    var body: some View {
        let all = everything
        // Worked out from the actions already in hand, not by walking the vault again, and
        // through the index so that this and the task menu's chooser leave out the same notes
        // (finished and archived ones).
        let waiting = model.index.waitingFor(among: all, today: DateOnly.today())
        let shown = model.actionFilter.apply(to: all, today: .today())
        VStack(spacing: 0) {
            header(shown: shown.count, waiting: waiting.count)
            if showsWaiting {
                WaitingForList(list: waiting)
            } else {
                actionsPart(all: all, shown: shown, waiting: waiting)
            }
        }
    }

    /// The column as it was before build 279: header, boxes, and the list of actions.
    @ViewBuilder
    private func actionsPart(all: [TaskRef], shown: [TaskRef], waiting: WaitingList) -> some View {
        let listed = groups(shown)
        if !model.actionFilter.isEmpty {
            filterLine(shown: shown.count, total: all.count)
        }
        if !folded {
            // Build 301: only as tall as the boxes (a bare ScrollView took the whole 260 points
            // and left an empty gap); it scrolls only when they would not fit under the cap.
            // **Build 304 fix — the iPhone hung at launch.** 301 did this with `ViewThatFits`
            // round the wrapping chips; the chips' height depends on the room offered and
            // ViewThatFits kept re-measuring them without end, so the phone froze on start (iOS
            // then closes it — it looked like a crash). Now the boxes are measured once inside
            // the ScrollView (their height there never depends on the ScrollView's own height)
            // and the ScrollView takes that height, capped.
            let cap: CGFloat = isPhone ? 200 : 260
            ScrollView {
                boxes(among: all)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { boxesHeight = $0 }
            }
            // The same cap as the Search screen's panel: on a phone this is a whole
            // tab, and boxes filling it would leave two rows of actions to look at.
            .frame(height: min(boxesHeight ?? cap, cap))
        }
        waitingPointer(waiting)
        Divider()
        if listed.isEmpty {
            empty(total: all.count)
        } else {
            list(listed)
        }
    }

    // MARK: Waiting for

    /// "3 waiting for other people", one press from the list. Nothing is drawn when nothing is
    /// waiting: there is nothing to point at.
    @ViewBuilder
    private func waitingPointer(_ waiting: WaitingList) -> some View {
        if let text = waiting.pointerText {
            Button {
                showsWaiting = true
            } label: {
                MarkLabel(text, WaitingShowing.symbol, text: .footnote)
                    .font(Txt.label)
                    .foregroundStyle(tint.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .help("Show the lines you are waiting on other people for")
            .accessibilityIdentifier("actions.waitingPointer")
        }
    }

    // MARK: The header and the boxes

    /// **Actions | Waiting for** and **Filter**, one row, the same on both halves (build 312).
    /// Inside the column, next to what it governs — build 167, where a control in the window's
    /// toolbar landed in a different place on every screen and carried no word.
    ///
    /// `ViewThatFits` picks between two short rows of fixed-size things (nothing in them wraps,
    /// which is what hung build 301): in a narrow Mac column the Filter button drops its
    /// symbol before the switch is ever cut.
    private func header(shown: Int, waiting: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            headerRow(shown: shown, waiting: waiting, filterSymbol: true)
            headerRow(shown: shown, waiting: waiting, filterSymbol: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func headerRow(shown: Int, waiting: Int, filterSymbol: Bool) -> some View {
        HStack(spacing: 8) {
            TwoPartSwitch(first: "Actions \(shown)",
                          second: waiting > 0 ? "Waiting for \(waiting)" : "Waiting for",
                          showsSecond: $showsWaiting, tint: tint)
                .accessibilityIdentifier("actions.switch")
                .frame(maxWidth: .infinity, alignment: .leading)
            // The boxes filter actions, not people, so the other half has no Filter.
            if !showsWaiting {
                filterButton(symbol: filterSymbol)
            }
        }
    }

    /// The worded **Filter** button: opens and folds the boxes. In the part's colour while the
    /// boxes are open or any of them is ticked, quiet otherwise.
    private func filterButton(symbol: Bool) -> some View {
        let lit = !folded || !model.actionFilter.isEmpty
        return Button {
            if isPhone { phoneFolded.toggle() } else { deskFolded.toggle() }
        } label: {
            HStack(spacing: 4) {
                if symbol {
                    MarkImage(folded ? "line.3.horizontal.decrease.circle" : "chevron.up", text: .footnote)
                }
                Text("Filter")
                    .font(Txt.label)
            }
            .foregroundStyle(lit ? tint.ink : Theme.soft)
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Filter")
        .accessibilityValue(folded ? "folded" : "open")
        .help(folded ? "Show the boxes" : "Hide the boxes")
        .accessibilityIdentifier("actions.fold")
    }

    /// Drawn only while a box is ticked, so the filter is never invisible (build 161: a screen
    /// may not narrow what it shows without saying so where you can see). What is ticked while
    /// the boxes are folded away, then "2 of 5" and **Clear**. With nothing ticked there is no
    /// line at all: "Every open action" said the screen's name a third time (build 312).
    private func filterLine(shown: Int, total: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(folded ? model.actionFilter.summary : "")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(shown) of \(total)")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize()
            Button("Clear") { model.actionFilter = ActionFilter() }
                .buttonStyle(.borderless)
                .font(Txt.label)
                .fixedSize()
                .help("Untick every box")
                .accessibilityIdentifier("actions.clear")
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func boxes(among all: [TaskRef]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            row("When", choices: ActionFilter.When.allCases.map { when in
                Choice(id: when.rawValue, title: when.label,
                       isOn: model.actionFilter.whens.contains(when)) {
                    toggle(&model.actionFilter.whens, when)
                }
            })
            row("Mark", choices: ActionFilter.Mark.allCases.map { mark in
                Choice(id: mark.rawValue, title: mark.label,
                       isOn: model.actionFilter.marks.contains(mark)) {
                    toggle(&model.actionFilter.marks, mark)
                }
            })
            let tags = ActionFilter.tagChoices(among: all, including: model.actionFilter.tags)
            if !tags.isEmpty {
                row("Tags", choices: tags.map { tag in
                    Choice(id: tag, title: "#\(tag)",
                           isOn: model.actionFilter.tags.contains(tag)) {
                        toggle(&model.actionFilter.tags, tag)
                    }
                })
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One titled row. A `WrappingHStack`, so a narrow column moves whole boxes to the next
    /// line rather than squeezing every one of them thinner (build 138).
    private func row(_ title: String, choices: [Choice]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Build 301 (his ask): small grey capitals, not a green heading — the chips carry
            // the colour.
            Text(title.uppercased())
                .font(Txt.pill.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.soft)
            WrappingHStack(spacing: 5, lineSpacing: 5) {
                ForEach(choices) { choice in
                    FilterBox(title: choice.title, isOn: choice.isOn, tint: tint, chip: true, action: choice.action)
                        .accessibilityIdentifier("actions.box.\(choice.id)")
                }
            }
            .lineLimit(1)
        }
    }

    /// A struct, not a tuple: a `ForEach` id is a key path and a key path cannot address a
    /// tuple member (build 61, and the fifth time it has come up).
    private struct Choice: Identifiable {
        let id: String
        let title: String
        let isOn: Bool
        let action: () -> Void
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    // MARK: The list, and the two ways it can be empty

    private func list(_ groups: [(note: Note, tasks: [TaskRef])]) -> some View {
        List(selection: model.noteSelection) {
            Group {
            ForEach(groups, id: \.note.relativePath) { group in
                Section {
                    ForEach(group.tasks) { ref in
                        TaskRow(ref: ref, showNote: false) { model.toggle(ref) }
                            .tag(ref.notePath)
                    }
                } header: {
                    HStack {
                        SectionLabel(title: group.note.displayTitle,
                                     count: group.tasks.count,
                                     markName: SidebarSection.kind(group.note.kind).markName,
                                     tint: group.note.tint)
                        Spacer()
                        Button("Open") { model.show(section: .kind(group.note.kind), notePath: group.note.relativePath) }
                            .font(Txt.label)
                            .buttonStyle(.borderless)
                    }
                }
            }
            }
            // Review round 4: on the iPhone each row is a card in the part's colour.
            .phoneCard(SidebarSection.allActions.tint)
        }
    }

    /// **Two different sentences**, because an empty list from a tick and an empty list from
    /// an empty vault are not the same news (build 100, and build 157's `emptyMessage`).
    @ViewBuilder
    private func empty(total: Int) -> some View {
        if total == 0 {
            EmptyStateView(title: "Nothing open",
                           markName: "checkmark.circle",
                           message: "No open action anywhere in the vault. Capture something in the Inbox, and it will show up here.",
                           tint: tint)
                .accessibilityIdentifier("actions.nothingOpen")
        } else {
            EmptyStateView(title: "No action matches",
                           markName: "line.3.horizontal.decrease.circle",
                           message: "There are \(total) open actions, but none of them matches the boxes you ticked: \(model.actionFilter.summary).",
                           tint: tint,
                           actionTitle: "Untick every box",
                           action: { model.actionFilter = ActionFilter() })
                // The two states carry different names, because a screen test that could not
                // tell them apart would pass on an empty vault (build 190's rule).
                .accessibilityIdentifier("actions.noMatch")
        }
    }
}

/// Apple's two-part switch with its words in a part's colour (build 312): **Actions | Waiting
/// for**. On the iPhone and iPad it is the system's own segmented control, asked to write the
/// chosen part in the tint — a SwiftUI `Picker` cannot be told that. On the Mac it is the
/// SwiftUI `Picker`, which the system draws its own way.
struct TwoPartSwitch: View {
    let first: String
    let second: String
    @Binding var showsSecond: Bool
    let tint: Color

    var body: some View {
        #if os(iOS)
        Segments(first: first, second: second, showsSecond: $showsSecond, tint: tint)
        #else
        Picker("Show", selection: $showsSecond) {
            Text(first).tag(false)
            Text(second).tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .tint(tint)
        #endif
    }

    #if os(iOS)
    private struct Segments: UIViewRepresentable {
        let first: String
        let second: String
        @Binding var showsSecond: Bool
        let tint: Color

        func makeCoordinator() -> Coordinator { Coordinator(showsSecond: $showsSecond) }

        func makeUIView(context: Context) -> UISegmentedControl {
            let control = UISegmentedControl(items: [first, second])
            control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
            // Hugs its height, takes the width it is given.
            control.setContentHuggingPriority(.required, for: .vertical)
            control.setContentHuggingPriority(.defaultLow, for: .horizontal)
            return control
        }

        func updateUIView(_ control: UISegmentedControl, context: Context) {
            context.coordinator.showsSecond = $showsSecond
            if control.titleForSegment(at: 0) != first { control.setTitle(first, forSegmentAt: 0) }
            if control.titleForSegment(at: 1) != second { control.setTitle(second, forSegmentAt: 1) }
            let index = showsSecond ? 1 : 0
            if control.selectedSegmentIndex != index { control.selectedSegmentIndex = index }
            let size = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
            control.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: size)], for: .normal)
            control.setTitleTextAttributes([.foregroundColor: UIColor(tint.ink),
                                            .font: UIFont.systemFont(ofSize: size, weight: .semibold)],
                                           for: .selected)
        }

        final class Coordinator: NSObject {
            var showsSecond: Binding<Bool>
            init(showsSecond: Binding<Bool>) { self.showsSecond = showsSecond }

            @MainActor @objc func changed(_ control: UISegmentedControl) {
                showsSecond.wrappedValue = control.selectedSegmentIndex == 1
            }
        }
    }
    #endif
}
