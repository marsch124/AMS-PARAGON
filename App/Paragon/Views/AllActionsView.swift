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
struct AllActionsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("actionFiltersFolded") private var deskFolded = false
    @AppStorage("actionFiltersFoldedPhone") private var phoneFolded = true

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
        let shown = model.actionFilter.apply(to: all, today: .today())
        let groups = groups(shown)
        VStack(spacing: 0) {
            header(shown: shown.count, total: all.count)
            if folded {
                foldedLine
            } else {
                ScrollView { boxes(among: all) }
                    // The same cap as the Search screen's panel: on a phone this is a whole
                    // tab, and boxes filling it would leave two rows of actions to look at.
                    .frame(maxHeight: isPhone ? 200 : 260)
            }
            Divider()
            if groups.isEmpty {
                empty(total: all.count)
            } else {
                list(groups)
            }
        }
    }

    // MARK: The header and the boxes

    /// The fold button and **Clear** sit inside the column, next to the column's own name —
    /// build 167, where a control in the window's toolbar landed in a different place on every
    /// screen and carried no word.
    private func header(shown: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            SectionLabel(title: "Actions", count: shown,
                         systemImage: SidebarSection.allActions.systemImage, tint: tint)
            Spacer()
            if !model.actionFilter.isEmpty {
                Text("of \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear") { model.actionFilter = ActionFilter() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .help("Untick every box")
                    .accessibilityIdentifier("actions.clear")
            }
            Button {
                if isPhone { phoneFolded.toggle() } else { deskFolded.toggle() }
            } label: {
                Label(folded ? "Show the boxes" : "Hide the boxes",
                      systemImage: folded ? "line.3.horizontal.decrease.circle" : "chevron.up")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(model.actionFilter.isEmpty ? Color.secondary : tint)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("actions.fold")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    /// What the boxes say while they are folded away, so the filter is never invisible. Build
    /// 161's lesson: a screen may not narrow what it shows without saying so where you can see.
    private var foldedLine: some View {
        Text(model.actionFilter.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
    }

    private func boxes(among all: [TaskRef]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: title, count: nil, tint: tint)
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ForEach(choices) { choice in
                    FilterBox(title: choice.title, isOn: choice.isOn, tint: tint, action: choice.action)
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
                                     systemImage: SidebarSection.kind(group.note.kind).systemImage,
                                     tint: group.note.tint)
                        Spacer()
                        Button("Open") { model.show(section: .kind(group.note.kind), notePath: group.note.relativePath) }
                            .font(.caption)
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    /// **Two different sentences**, because an empty list from a tick and an empty list from
    /// an empty vault are not the same news (build 100, and build 157's `emptyMessage`).
    @ViewBuilder
    private func empty(total: Int) -> some View {
        if total == 0 {
            EmptyStateView(title: "Nothing open",
                           systemImage: "checkmark.circle",
                           message: "No open action anywhere in the vault. Capture something in the Inbox, and it will show up here.",
                           tint: tint)
                .accessibilityIdentifier("actions.nothingOpen")
        } else {
            EmptyStateView(title: "No action matches",
                           systemImage: "line.3.horizontal.decrease.circle",
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
