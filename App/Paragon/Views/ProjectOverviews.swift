import SwiftUI
import ParagonCore

// Build 344 — the four views of the Projects page and the switch between them. His words on
// 20 Nov 2026: "I would like an easy way to find an overview of all projects", then "Build 1,
// 2 and a version of two where all projects have some minimal info in the (larger) box each.
// We need a premium way to choose between the four views." His picks from the numbered
// pictures: a segmented switch (1), the List opens "needs a look first", the Board by state
// with dragging, Cards with progress, deadline and goal, and the last view used comes back.
// Which project goes where is decided in Core (`ProjectViews.swift`, tested).

// MARK: - The switch

/// Four parts, each a hand-drawn mark and a word. The chosen part is full project green with
/// white words (the main button is never grey); the others are plain. Command-Option-1…4 on
/// the Mac.
struct ProjectsLayoutSwitch: View {
    @Binding var selection: String
    @Namespace private var glide

    private var chosen: ProjectsLayout { ProjectsLayout(rawValue: selection) ?? .byGoal }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ProjectsLayout.allCases) { layout in
                part(layout)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("projects.layout")
    }

    private func part(_ layout: ProjectsLayout) -> some View {
        let isOn = layout == chosen
        return Button {
            withAnimation(Motion.press) { selection = layout.rawValue }
        } label: {
            HStack(spacing: 4) {
                MarkImage(ProjectOverviewMarks.name(for: layout), size: 13)
                Text(layout.title)
                    .font(Txt.label.weight(isOn ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                if isOn {
                    Capsule().fill(ParaKind.project.tint)
                        .matchedGeometryEffect(id: "chosen", in: glide)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(layout.number)")), modifiers: [.command, .option])
        .help("\(layout.title) (\u{2318}\u{2325}\(layout.number))")
        .accessibilityLabel(layout.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("projects.layout.\(layout.rawValue)")
    }
}

/// The marks of the four views. By goal is the goal's own target; the other three are drawn
/// for this build (Marks.swift), so none of them says something another mark already says.
enum ProjectOverviewMarks {
    static func name(for layout: ProjectsLayout) -> String {
        switch layout {
        case .byGoal: return "target"
        case .list: return "projects.rows"
        case .board: return "projects.columns"
        case .cards: return "projects.cards"
        }
    }
}

/// The small mark in front of a project's name in the List and on the Board: its own icon
/// when it has one, else the 8-point dot every list row has.
struct SmallProjectMark: View {
    let line: ProjectLine
    var size: CGFloat = 18

    var body: some View {
        if line.note.ownIcon.isIconOrColour {
            NoteIconTile(note: line.note, fallbackTint: ProjectOverviewWords.tint(of: line), size: size)
        } else {
            TintStripe(color: ProjectOverviewWords.tint(of: line))
        }
    }
}

/// Short words the three new views share, so a project says the same thing in each.
enum ProjectOverviewWords {
    static func tint(of line: ProjectLine) -> Color {
        line.status == .active || line.status == .done ? ParaKind.project.tint : Color.secondary
    }

    /// "Next: …" words without "Next:", or what stands in for it.
    static func next(_ line: ProjectLine) -> (text: String, isTask: Bool) {
        switch line.need {
        case .next: return (line.nextTitle ?? "", true)
        case .allFinished, .waitingOnly:
            if case .waitingOnly(let count) = line.need, line.status != .active {
                return (ProjectLine.waitingText(count: count), false)
            }
            return (line.status == .active ? "No next action" : ProjectLine.finishedText(count: line.done), false)
        case .noTasks: return ("No tasks yet", false)
        }
    }

    static func deadline(_ line: ProjectLine) -> (text: String, late: Bool)? {
        guard let deadline = line.deadline else { return nil }
        return (ProjectLine.deadlineText(deadline, today: DateOnly.today()),
                line.status == .active && line.deadlinePassed)
    }
}

// MARK: - List

/// One line per running or on-hold project, in columns. Opens "needs a look first"; a press
/// on a column heading sorts by it, a second press turns the order round.
struct ProjectListOverview<Menu: View>: View {
    @EnvironmentObject private var model: AppModel
    let lines: [ProjectLine]
    let isPhone: Bool
    @ViewBuilder let menu: (Note) -> Menu
    @State private var sort: ProjectSort = .attention
    @State private var ascending = true
    /// Build 345: only the running projects with no next action. Not kept: the List always
    /// opens with every project.
    @State private var onlyWanting = false

    private var wanting: [ProjectLine] { lines.filter(ProjectOverview.needsNextAction) }

    private var shown: [ProjectLine] {
        ProjectOverview.sorted(onlyWanting ? wanting : lines, by: sort, ascending: ascending)
    }

    var body: some View {
        VStack(spacing: 0) {
            wantingButton
            header
            Divider()
            List(selection: model.noteSelection) {
                ForEach(shown) { line in
                    row(line)
                        .tag(line.note.relativePath)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("projects.list.\(line.id)")
                        .contextMenu { menu(line.note) }
                }
            }
            .listStyle(.plain)
        }
    }

    /// Build 345, his pick of my idea: "5 need a next action" above the List. The dashed
    /// ring is the row's own mark for "No next action". Gone when no project needs one.
    @ViewBuilder
    private var wantingButton: some View {
        let count = wanting.count
        if count > 0 || onlyWanting {
            HStack {
                Button {
                    withAnimation(Motion.press) { onlyWanting.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        MarkImage("circle.dashed", size: 11)
                        Text(onlyWanting
                             ? "Showing \(count) that \(count == 1 ? "needs" : "need") a next action \u{00B7} Show all"
                             : ProjectOverview.needsNextActionText(count))
                            .lineLimit(1)
                    }
                    .font(Txt.label.weight(.semibold))
                    .foregroundStyle(onlyWanting ? Color.white : ParaKind.project.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(onlyWanting ? ParaKind.project.tint : ParaKind.project.tint.opacity(0.12),
                                in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(onlyWanting ? "Show every project again" : "Show only the running projects with no next action")
                .accessibilityIdentifier("projects.list.wanting")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 7)
            .padding(.bottom, 2)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            heading(.name).frame(maxWidth: .infinity, alignment: .leading)
            if !isPhone {
                heading(.goal).frame(width: 170, alignment: .leading)
                heading(.state).frame(width: 96, alignment: .leading)
                heading(.next).frame(maxWidth: .infinity, alignment: .leading)
            }
            heading(.deadline).frame(width: isPhone ? 110 : 120, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }

    private func heading(_ column: ProjectSort) -> some View {
        let isOn = sort == column
        return Button {
            if isOn { ascending.toggle() } else { sort = column; ascending = true }
        } label: {
            HStack(spacing: 3) {
                Text(column.heading)
                if isOn {
                    MarkImage(ascending ? "chevron.down" : "chevron.up", size: 9)
                }
            }
            .font(Txt.label.weight(isOn ? .semibold : .regular))
            .foregroundStyle(isOn ? AnyShapeStyle(ParaKind.project.tint) : AnyShapeStyle(.secondary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Sort by \(column.heading.lowercased())")
        .accessibilityIdentifier("projects.list.sort.\(column.rawValue)")
    }

    private func row(_ line: ProjectLine) -> some View {
        let next = ProjectOverviewWords.next(line)
        let deadline = ProjectOverviewWords.deadline(line)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .center, spacing: 7) {
                SmallProjectMark(line: line)
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.note.title)
                        .font(Txt.listTitle)
                        .lineLimit(1)
                    if isPhone {
                        Text(next.text)
                            .font(Txt.listSecond)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isPhone {
                Text(line.goal?.title ?? "No goal")
                    .foregroundStyle(line.goal == nil ? .tertiary : .secondary)
                    .lineLimit(1)
                    .frame(width: 170, alignment: .leading)
                stateWords(line)
                    .frame(width: 96, alignment: .leading)
                Text(next.text)
                    .foregroundStyle(next.isTask ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Group {
                if let deadline {
                    Text(deadline.text)
                        .foregroundStyle(deadline.late ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                } else {
                    Text("\u{2013}").foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
            .frame(width: isPhone ? 110 : 120, alignment: .leading)
        }
        .font(Txt.listSecond)
        .padding(.vertical, 1)
    }

    /// The board's own words for its state, so the List and the Board say the same.
    private func stateWords(_ line: ProjectLine) -> some View {
        let column = BoardColumn.column(of: line)
        return Text(column?.title ?? line.status.label)
            .foregroundStyle(column == .needsALook ? AnyShapeStyle(Theme.attention.ink)
                             : line.status == .active ? AnyShapeStyle(ParaKind.project.tint)
                             : AnyShapeStyle(.secondary))
            .lineLimit(1)
    }
}

// MARK: - Board

/// Four columns side by side: Needs a look, Running, On hold, Done. Drag a card onto Running,
/// On hold or Done to change the project's state; Needs a look takes no drop (a date puts a
/// project there).
struct ProjectBoardOverview<Menu: View>: View {
    @EnvironmentObject private var model: AppModel
    let stacks: [BoardStack]
    let isPhone: Bool
    @ViewBuilder let menu: (Note) -> Menu
    @State private var target: BoardColumn?
    /// Build 345: the card the pointer rests on shows its 8-week bars.
    @State private var hovered: String?

    private var columnWidth: CGFloat { isPhone ? 230 : 250 }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(stacks) { stack in
                    column(stack)
                }
            }
            .padding(12)
        }
    }

    private func tint(_ column: BoardColumn) -> Color {
        switch column {
        case .needsALook: return Theme.attention.ink
        case .running, .done: return ParaKind.project.tint
        case .onHold: return .secondary
        }
    }

    private func column(_ stack: BoardStack) -> some View {
        let canDrop = stack.column.dropStatus != nil
        let isTarget = target == stack.column && canDrop
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(stack.column.title)
                    .font(Txt.listTitle)
                    .foregroundStyle(tint(stack.column))
                Text("\(stack.lines.count)")
                    .font(Txt.label)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            ScrollView(.vertical) {
                LazyVStack(spacing: 6) {
                    ForEach(stack.lines) { line in
                        card(line)
                    }
                    if stack.lines.isEmpty {
                        Text(canDrop ? "Drag a project here" : "Nothing late")
                            .font(Txt.label)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
        }
        .padding(8)
        .frame(width: columnWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.secondary.opacity(isTarget ? 0.16 : 0.07),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(ParaKind.project.tint.opacity(isTarget ? 0.7 : 0), lineWidth: 1.5)
        )
        .dropDestination(for: String.self) { paths, _ in
            guard let status = stack.column.dropStatus else { return false }
            var moved = false
            for path in paths {
                if let note = model.note(at: path), note.noteStatus != status {
                    model.setStatus(status, for: note)
                    moved = true
                }
            }
            return moved
        } isTargeted: { inside in
            target = inside ? stack.column : (target == stack.column ? nil : target)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("projects.board.\(stack.column.rawValue)")
    }

    private func card(_ line: ProjectLine) -> some View {
        let next = ProjectOverviewWords.next(line)
        let deadline = ProjectOverviewWords.deadline(line)
        // A plain box with a tap, not a `Button`: on the Mac a button keeps the mouse to
        // itself and the card could not be dragged (seen on the test copy, build 344).
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 7) {
                SmallProjectMark(line: line)
                Text(line.note.title)
                    .font(Txt.listTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 4) {
                MarkImage(next.isTask ? "square" : "circle.dashed", size: 10)
                Text(next.text).lineLimit(1)
            }
            .font(Txt.listSecond)
            .foregroundStyle(.secondary)
            if let deadline {
                HStack(spacing: 4) {
                    MarkImage("deadline", size: 10)
                    Text(deadline.text).lineLimit(1)
                }
                .font(Txt.listSecond)
                .foregroundStyle(deadline.late ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
            }
            if hovered == line.id {
                // Build 345, his pick of my idea: the 8-week bars while the pointer rests on
                // the card. Only with a pointer; the iPhone's cards are unchanged.
                HStack(spacing: 6) {
                    if line.weekly.total > 0 {
                        WeekBars(weekly: line.weekly, height: 12)
                        Text("Finished in 8 weeks: \(line.weekly.total)")
                    } else {
                        Text("Nothing finished in 8 weeks")
                    }
                }
                .font(Txt.listSecond)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .transition(.opacity)
                .accessibilityIdentifier("projects.card.weekly.\(line.id)")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { model.show(line.note) }
        .onHover { inside in
            withAnimation(Motion.press) {
                if inside { hovered = line.id } else if hovered == line.id { hovered = nil }
            }
        }
        .draggable(line.note.relativePath) {
            Text(line.note.title)
                .font(Txt.listTitle)
                .padding(6)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 6))
        }
        .contextMenu { menu(line.note) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("projects.card.\(line.id)")
    }
}

/// White by day, a lifted grey by night: a card on a grey column.
private var cardBackground: Color {
    #if os(macOS)
    Color(nsColor: .controlBackgroundColor)
    #else
    Color(uiColor: .secondarySystemGroupedBackground)
    #endif
}

// MARK: - Cards

/// A grid of larger boxes, one per running or on-hold project: icon, name, progress bar,
/// deadline and goal — his pick of what a card shows.
struct ProjectCardsOverview<Menu: View>: View {
    @EnvironmentObject private var model: AppModel
    let lines: [ProjectLine]
    @ViewBuilder let menu: (Note) -> Menu

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)],
                      alignment: .leading, spacing: 10) {
                ForEach(lines) { line in
                    card(line)
                }
            }
            .padding(12)
        }
    }

    private func card(_ line: ProjectLine) -> some View {
        let deadline = ProjectOverviewWords.deadline(line)
        return Button {
            model.show(line.note)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 9) {
                    ProjectTile(status: line.status, note: line.note)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.note.title)
                            .font(Txt.listTitle)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                        if line.status != .active {
                            Text(line.status.label)
                                .font(Txt.listSecond)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if line.total > 0 {
                    ProjectProgress(done: line.done, total: line.total)
                } else {
                    Text("No tasks yet").font(Txt.label).foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        MarkImage("deadline", size: 11)
                        Text(deadline?.text ?? "No deadline").lineLimit(1)
                    }
                    .foregroundStyle(deadline?.late == true ? AnyShapeStyle(Color.red)
                                     : deadline == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                    HStack(spacing: 4) {
                        MarkImage("target", size: 11)
                        Text(line.goal?.title ?? "No goal").lineLimit(1)
                    }
                    .foregroundStyle(line.goal == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                }
                .font(Txt.listSecond)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ProjectOverviewWords.tint(of: line).opacity(0.35), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu { menu(line.note) }
        .accessibilityIdentifier("projects.cards.\(line.id)")
    }
}
