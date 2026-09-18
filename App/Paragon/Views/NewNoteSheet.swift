import SwiftUI
import ParagonCore

/// The six things this sheet can make. Five are kinds of note; the sixth writes a line
/// into the Inbox instead of making anything.
///
/// It is its own type rather than `ParaKind` because a capture is not a kind of note, and
/// pretending it is would put it in the sidebar, the Map and the review.
///
/// **An Aspiration is a button of its own since build 199**, his ask: *"We need a sixth
/// button."* Before it, an aspiration was a **Goal** with a chip below reading "What kind of
/// goal", so the one word he most wanted to reach was a setting inside something else. It
/// writes `horizon: life`, which is what that chip wrote — no vault touched, nothing to
/// migrate. Aspiration and Goal share `ParaKind.goal`, so nothing else in the app has to
/// know there are two buttons.
enum NewThing: String, CaseIterable, Identifiable {
    case aspiration, goal, project, area, resource, capture

    var id: String { rawValue }

    /// The name on the button. **"Capture", not "Quick capture"** — six buttons in one row
    /// is not wide enough for the long name, and he agreed to the short one.
    var name: String {
        switch self {
        case .aspiration: return GoalWording.aspiration
        case .goal: return "Goal"
        case .project: return "Project"
        case .area: return "Area"
        case .resource: return "Resource"
        case .capture: return "Capture"
        }
    }

    /// The kind of note it makes. A capture has none; nothing may read this without first
    /// asking `isCapture`.
    var kind: ParaKind {
        switch self {
        case .aspiration, .goal: return .goal
        case .project: return .project
        case .area: return .area
        case .resource: return .resource
        case .capture: return .inbox
        }
    }

    /// The `horizon:` line a new goal note carries. Nil for everything that is not a goal.
    var horizon: GoalHorizon? {
        switch self {
        case .aspiration: return .life
        case .goal: return .year
        default: return nil
        }
    }

    var isCapture: Bool { self == .capture }

    /// Capture wears the **Inbox** tint, not a new colour: that is where it goes, and a tint
    /// in this app is a claim about what a thing is (build 169).
    var tint: Color { kind.tint }

    /// The button to start on when the sheet opens from a section. **Written out rather than
    /// matched on `kind`**: Aspiration and Goal share `.goal`, so a search by kind would land
    /// on whichever came first in `allCases` and the Goals row would open the sheet on
    /// Aspiration (build 199).
    static func forSection(_ section: SidebarSection?) -> NewThing? {
        switch section {
        case .aspirations?: return .aspiration
        case .kind(.goal)?: return .goal
        case .kind(.project)?: return .project
        case .kind(.area)?: return .area
        case .kind(.resource)?: return .resource
        default: return nil
        }
    }
}

/// The one door into making something: five buttons across the top — Goal, Project, Area,
/// Resource, Capture — then the name, then everything else as chips.
///
/// **Build 185, and the shape is his.** His words about the old sheet: *"This is a very sad
/// entry page. I would like to have: Goal, Project, Area, Resource, Quick Capture — all five
/// with buttons at the top, then we can have the name field."* Pressing **Capture** swaps the
/// lower half for the capture screen, so one sheet answers "I want to put something into
/// PARAGON" however the thought arrives.
///
/// **The capture half is not written twice.** It is `QuickCaptureView` with `embedded: true`,
/// the very view the menu bar item, ⇧⌘N and the phone's button use. Two capture screens that
/// could answer differently is the fault build 162 fixed for "what serves what".
///
/// **The settings are chips, not `Picker` rows** — he chose that from a preview
/// (https://claude.ai/artifact/67nAaem7sj89DyZGZBiXDQ). They use the app's two-state language
/// from build 142: set is the tint filled with a solid border, not set is grey with a dashed
/// one. A `Picker` row in a sheet reads as a form to fill in; a chip reads as a fact you can
/// press, which is what the note header has taught him everywhere else.
struct NewNoteSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    @State private var thing: NewThing = .project
    @State private var title = ""
    @State private var target = ""
    /// The goal this note serves: an aspiration for a dated goal or an area, any goal for a
    /// project.
    @State private var servesGoal = ""
    @State private var parentArea = ""
    @State private var template = ""
    /// Tags for the new note. His ask, build 187: he wants to see the tags he already has at
    /// the moment he is making the note, so he does not write a second one meaning the same.
    @State private var tags: [String] = []
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            thingRow
            if thing.isCapture {
                QuickCaptureView(embedded: true)
            } else {
                notePane
            }
        }
        .padding(isPhone ? 14 : 20)
        .frame(minWidth: sheetMinWidth)
        // The phone's sheet is the whole screen, so the content is pinned to the top and the
        // footer pushed to the foot. On the Mac the sheet takes the size of what is in it.
        .frame(maxWidth: fillOnPhone, maxHeight: fillOnPhone, alignment: .topLeading)
        .onAppear {
            if let match = NewThing.forSection(model.section) {
                thing = match
            }
            template = defaultTemplateName
            // The sheet exists to be typed into. Focus does not always take in the same turn
            // the view appears, so it is asked for again on the next one.
            DispatchQueue.main.async { nameFocused = !thing.isCapture }
        }
        // Each kind has its own templates, so the choice starts again at its default.
        .onChange(of: thing) { _, _ in template = defaultTemplateName }
    }

    /// A phone sheet may not be given a minimum width wider than the phone (build 158).
    /// 480 rather than build 185's 420: six buttons across the top, not five (build 199).
    private var sheetMinWidth: CGFloat? { isPhone ? nil : 480 }

    /// Written out rather than a ternary with `nil` in one arm: `.infinity` is a member of
    /// `CGFloat`, not of `CGFloat?`, and there is no compiler here to settle it.
    private var fillOnPhone: CGFloat? {
        if isPhone { return CGFloat.infinity }
        return nil
    }

    // MARK: The six buttons

    /// **An `HStack`, not a `WrappingHStack`.** A chooser reads as a set of equal cells, and
    /// build 138's wrapping layout gives every child its natural width — which would leave
    /// six ragged buttons, some on a second line. Instead the sheet is 60pt wider on the Mac
    /// and each label is allowed to shrink a little on the phone.
    private var thingRow: some View {
        HStack(spacing: 6) {
            ForEach(NewThing.allCases) { choice in
                ThingChoice(thing: choice,
                            chosen: thing == choice,
                            symbol: symbol(for: choice),
                            tint: tint(for: choice)) { pick(choice) }
            }
        }
    }

    /// The star for an aspiration, the target for a goal with a date. The two are not the
    /// same thing (build 168), and these two buttons are where he first meets the difference.
    private func symbol(for choice: NewThing) -> String {
        switch choice {
        case .aspiration: return ChainSymbol.aspiration
        case .goal: return ChainSymbol.datedGoal
        case .capture: return "tray.and.arrow.down"
        default: return SidebarSection.kind(choice.kind).systemImage
        }
    }

    /// And its colour, decided with its symbol: the deeper gold goes with the star (build 189).
    private func tint(for choice: NewThing) -> Color {
        switch choice {
        case .aspiration: return ChainTint.aspiration
        case .goal: return ChainTint.datedGoal
        default: return choice.tint
        }
    }

    // MARK: Making a note

    private var notePane: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("What is it called?", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(create)
                    .accessibilityIdentifier("new.name")
            }

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // No fold. He tried build 119's "More" toggle and asked for everything to be
            // on screen at once (build 121), so the settings are simply here. There is always
            // at least the tags chip, so the divider is always earned.
            Divider()
            settingsChips

            if isPhone { Spacer(minLength: 12) }
            footer
        }
    }

    /// **Build 186, from his screenshot of the phone**: Cancel and Create were two blue words in
    /// the bottom corner. `SheetFooter` (Theme.swift) is where that is put right, for every
    /// sheet at once since build 191.
    private var footer: some View {
        SheetFooter(actionTitle: "Create", tint: tint(for: thing), canAct: canCreate,
                    cancel: { dismiss() }, act: create)
    }

    private var canCreate: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// What a note can be given as it is made, each one a chip you press. Only the chips that
    /// apply to the chosen kind are drawn, so the row stays short without anything folded away.
    private var settingsChips: some View {
        WrappingHStack(spacing: 8, lineSpacing: 8) {
            // **The "What kind of goal" chip is gone (build 199).** The button at the top now
            // says which kind is being made, and two controls for one state is build 165's
            // fault. A target date belongs to a goal with a date, so it keeps the family gold.
            if thing == .goal {
                DateChip(name: "Target",
                         emptyLabel: "Set a target date\u{2026}",
                         tint: ChainTint.datedGoal,
                         text: $target)
            }
            if let serves = serves {
                // The chip takes the colour of the thing it names, not of the note being made.
                PickerChip(name: serves.name,
                           emptyLabel: serves.empty,
                           noneLabel: "Nothing yet",
                           systemImage: ChainSymbol.datedGoal,
                           tint: servesGoal.isEmpty ? ChainTint.datedGoal
                               : ChainTint.forGoal(named: servesGoal, in: model.index),
                           options: serves.options,
                           choice: $servesGoal)
            }
            if thing == .area, !possibleParents.isEmpty {
                PickerChip(name: "Part of another area",
                           emptyLabel: "Part of\u{2026}",
                           noneLabel: "An area of its own",
                           systemImage: "arrow.turn.left.up",
                           tint: ParaKind.area.tint,
                           options: possibleParents.map { ChipOption(value: $0.displayTitle, label: $0.displayTitle) },
                           choice: $parentArea)
            }
            NewNoteTagsChip(model: model, tags: $tags)
            if templateChoices.count > 1 {
                PickerChip(name: "Template",
                           emptyLabel: "Template",
                           noneLabel: nil,
                           systemImage: SidebarSection.templates.systemImage,
                           tint: SidebarSection.templates.tint,
                           options: templateOptions,
                           choice: $template)
            }
        }
        .lineLimit(1)
    }

    /// What the **Serves…** chip offers differs per kind, so it is settled here rather than
    /// in the ViewBuilder (build 58).
    private struct ServesChoice {
        let name: String
        let empty: String
        let options: [ChipOption]
    }

    private var serves: ServesChoice? {
        switch thing {
        case .goal:
            guard !aspirations.isEmpty else { return nil }
            return ServesChoice(name: "Serves aspiration",
                                empty: "Serves an aspiration\u{2026}",
                                options: goalOptions(aspirations))
        case .project:
            guard !allGoals.isEmpty else { return nil }
            return ServesChoice(name: "Serves goal",
                                empty: "Serves a goal\u{2026}",
                                options: goalOptions(allGoals))
        // An area holds an aspiration — the other half of "no project or area serves this",
        // which the sheet has never been able to answer (build 134).
        case .area:
            guard !aspirations.isEmpty else { return nil }
            return ServesChoice(name: "Serves aspiration",
                                empty: "Serves an aspiration\u{2026}",
                                options: goalOptions(aspirations))
        default:
            return nil
        }
    }

    private func goalOptions(_ notes: [Note]) -> [ChipOption] {
        notes.map { ChipOption(value: $0.title, label: $0.title, symbol: ChainSymbol.forGoal($0)) }
    }

    private var templateOptions: [ChipOption] {
        templateChoices.map {
            ChipOption(value: $0.name, label: $0.isDefault ? "\($0.name) (default)" : $0.name)
        }
    }

    /// Switching kind starts the extras again: a goal picked for a project must not follow
    /// you to an area, and a chip would otherwise show a choice you never made.
    private func pick(_ choice: NewThing) {
        guard choice != thing else { return }
        thing = choice
        servesGoal = ""
        parentArea = ""
        target = ""
        // The name field may not exist yet in this turn — coming back from Capture it is
        // only being made now — so the focus is asked for on the next one (build 119).
        DispatchQueue.main.async { nameFocused = !choice.isCapture }
    }

    /// The templates that make this kind of note. More than one and you get to choose.
    private var templateChoices: [TemplateFile] {
        thing.isCapture ? [] : model.templates(for: thing.kind)
    }

    private var defaultTemplateName: String { templateChoices.first?.name ?? "" }

    private var aspirations: [Note] {
        model.notes.filter { $0.kind == .goal && $0.horizon == .life && !$0.isArchived }
    }

    private var allGoals: [Note] { model.notes.filter { $0.kind == .goal && !$0.isArchived } }

    /// Areas a new one can be made under. One level, so only the areas that are not
    /// already sub-areas themselves.
    private var possibleParents: [Note] {
        model.index.areaTree().map(\.area).filter { !$0.isArchived }
    }

    /// One sentence. The full description of each kind lives in the manual, which is
    /// searchable; a paragraph here was read once and skipped ever after.
    private var hint: String {
        switch thing {
        case .project: return "An outcome with an end. Its tasks are mirrored to a Reminders list of the same name."
        case .area: return "An ongoing responsibility with a standard to keep. Its tasks go to Reminders too."
        case .aspiration: return "\(GoalWording.aspirationRule) Never synced to Reminders \u{2014} the work lives in the goals with dates that point at it."
        case .goal: return "\(GoalWording.datedGoalRule) Not synced to Reminders; its work lives in projects."
        default: return "Reference material. No dates, no Reminders \u{2014} link it from wherever it is useful with [[brackets]]."
        }
    }

    private func create() {
        guard !thing.isCapture else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let kind = thing.kind
        var extra: [(String, String)] = []
        if kind == .area, !parentArea.isEmpty {
            extra.append(("parent", parentArea))
        }
        if (kind == .area || kind == .project), !servesGoal.isEmpty {
            extra.append(("goal", servesGoal))
        }
        if let horizon = thing.horizon {
            extra.append(("horizon", horizon.rawValue))
            let t = target.trimmingCharacters(in: .whitespaces)
            if horizon != .life, DateOnly(t) != nil { extra.append(("target", t)) }
            if horizon != .life, !servesGoal.isEmpty { extra.append(("goal", servesGoal)) }
        }
        let chosen = templateChoices.contains { $0.name == template } ? template : nil
        model.createNote(kind: kind, title: trimmed, extraFrontmatter: extra,
                         tags: tags, template: chosen)
        dismiss()
    }
}

/// One of the five, in its own colour. A row of these rather than a segmented picker: the
/// colours are the same ones the sidebar and the Map use, so the choice is recognised rather
/// than read.
private struct ThingChoice: View {
    let thing: NewThing
    let chosen: Bool
    let symbol: String
    let tint: Color
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 5) {
                KindBadge(kind: thing.kind, size: 18, systemImage: symbol, tint: tint)
                    .opacity(chosen ? 1 : 0.45)
                Text(thing.name)
                    .font(.caption)
                    .fontWeight(chosen ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .foregroundStyle(chosen ? tint : Color.secondary)
            .background(tint.opacity(chosen ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(chosen ? tint : Color.secondary.opacity(0.3),
                                  lineWidth: chosen ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        // "Make a new aspiration" rather than "Make a aspiration": six names now, and one of
        // them starts with a vowel.
        .help(thing.isCapture ? "Write a line straight into the Inbox" : "Make a new \(thing.name.lowercased())")
        // "new.project" and so on, for the screen tests (build 192).
        .accessibilityIdentifier("new.\(thing.rawValue)")
    }
}

// MARK: The chips

/// One line in a chip's list. A struct rather than a tuple, because a `ForEach` id is a key
/// path and a key path cannot address a tuple member (build 61).
struct ChipOption: Identifiable {
    let value: String
    let label: String
    var symbol: String? = nil

    var id: String { value }
}

/// A setting you press, drawn in the app's two-state language (build 142): chosen is the
/// tint filled with a solid border, not chosen is grey with a dashed one.
private struct ChipLabel: View {
    let text: String
    let systemImage: String
    let tint: Color
    let isSet: Bool

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .lineLimit(1)
            .foregroundStyle(isSet ? tint : Color.primary.opacity(0.62))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(tint.opacity(isSet ? 0.16 : 0), in: Capsule())
            .overlay(
                Capsule().strokeBorder(isSet ? tint.opacity(0.8) : Color.secondary.opacity(0.55),
                                       style: StrokeStyle(lineWidth: isSet ? 1.3 : 1.2,
                                                          dash: isSet ? [] : [4, 3]))
            )
            .contentShape(Capsule())
    }
}

/// One choice out of a list. A popover and not a `Menu`: `ProjectDeadlineChip` and
/// `NoteTagsChip` are both built this way and are known to behave on both platforms, and a
/// popover can hold a heading saying what is being chosen.
private struct PickerChip: View {
    /// What is being chosen. The heading of the popover, and the tooltip.
    let name: String
    /// The chip's words while nothing is chosen.
    let emptyLabel: String
    /// The first row, for choosing nothing. Nil when there must always be an answer.
    let noneLabel: String?
    let systemImage: String
    let tint: Color
    let options: [ChipOption]
    @Binding var choice: String
    @State private var showing = false

    private var chosen: ChipOption? { options.first { $0.value == choice } }

    var body: some View {
        Button {
            showing = true
        } label: {
            ChipLabel(text: chosen?.label ?? emptyLabel,
                      systemImage: chosen?.symbol ?? systemImage,
                      tint: tint,
                      isSet: chosen != nil)
        }
        .buttonStyle(.plain)
        .help(name)
        .popover(isPresented: $showing) { list }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.subheadline.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if let noneLabel {
                        row(ChipOption(value: "", label: noneLabel))
                    }
                    ForEach(options) { option in
                        row(option)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
        .padding(14)
        .frame(width: 290)
        .presentationCompactAdaptation(.popover)
    }

    private func row(_ option: ChipOption) -> some View {
        Button {
            choice = option.value
            showing = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: choice == option.value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(choice == option.value ? tint : Color.secondary)
                if let symbol = option.symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                }
                Text(option.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The tags a new note is given, with every tag the vault already knows in the list.
///
/// **Build 187, his ask:** *"It's not always too easy to know what tags I have defined, and I
/// don't want two tags the same meaning, but slightly different names."* The list is
/// `TagChoices`, the very one the note header's tag chip opens, so the two can never offer
/// different tags — and each row says how much of the vault carries that tag, which is how a
/// near-duplicate shows itself.
private struct NewNoteTagsChip: View {
    @ObservedObject var model: AppModel
    @Binding var tags: [String]
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            ChipLabel(text: tags.isEmpty ? "Tags\u{2026}" : tags.map { "#\($0)" }.joined(separator: " "),
                      systemImage: SidebarSection.tags.systemImage,
                      tint: SidebarSection.tags.tint,
                      isSet: !tags.isEmpty)
        }
        .buttonStyle(.plain)
        .help("Tags for this note")
        .popover(isPresented: $showing) {
            TagChoices(model: model, title: "Tags for this note", chosen: $tags)
        }
    }
}

/// A date, chosen the one way this app chooses dates: `DateChoiceView`, where the field is
/// read and not the calendar (builds 136 and 137).
private struct DateChip: View {
    let name: String
    let emptyLabel: String
    let tint: Color
    @Binding var text: String
    @State private var picking = false

    private var current: DateOnly? { DateOnly(text.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        Button {
            picking = true
        } label: {
            ChipLabel(text: current.map { "\(name) \($0.description)" } ?? emptyLabel,
                      systemImage: "flag.checkered",
                      tint: tint,
                      isSet: current != nil)
        }
        .buttonStyle(.plain)
        .help(name)
        .popover(isPresented: $picking) {
            DateChoiceView(current: current,
                           clearTitle: current == nil ? nil : "Clear",
                           cancel: { picking = false }) { chosen in
                text = chosen?.description ?? ""
                picking = false
            }
        }
    }
}

extension ParaKind {
    /// "project", not "Projects". `displayName` names the list a note lands in, which is the
    /// wrong word for the single note you are about to make.
    var singularName: String {
        switch self {
        case .inbox: return "inbox note"
        case .project: return "project"
        case .area: return "area"
        case .resource: return "resource"
        case .archive: return "archived note"
        case .daily: return "daily note"
        case .goal: return "goal"
        }
    }
}

/// What a `[[link]]` to a note that does not exist yet offers: make that note.
///
/// The title is the link's own words and cannot be changed here — changing it would leave
/// the link pointing at nothing, which is the very thing this sheet is for. All that is left
/// to decide is what kind of note it should be. A link inside a work note makes a work note,
/// so the two sets stay apart without the sheet having to ask.
struct NoteFromLinkSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ParaKind = .resource
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    /// The work notes' own colour for a link inside a work note, else the chosen kind's.
    private var tint: Color {
        model.linkToCreate?.isWork == true ? SidebarSection.work.tint : kind.tint
    }

    /// A phone sheet may not be given a minimum width wider than the phone (build 158).
    private var sheetMinWidth: CGFloat? { isPhone ? nil : 380 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Make this note")
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(linkTitle)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
            if model.linkToCreate?.isWork == true {
                Text("A work note, kept with the rest of your work notes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Type", selection: $kind) {
                    Text("Goal").tag(ParaKind.goal)
                    Text("Project").tag(ParaKind.project)
                    Text("Area").tag(ParaKind.area)
                    Text("Resource").tag(ParaKind.resource)
                }
                .pickerStyle(.segmented)
            }
            Text("The link becomes a real link as soon as the note is there.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            SheetFooter(actionTitle: "Create", tint: tint, cancel: cancel, act: create)
        }
        .padding(isPhone ? 14 : 20)
        .frame(minWidth: sheetMinWidth)
    }

    private var linkTitle: String { model.linkToCreate?.title ?? "" }

    private func create() {
        model.createNoteFromLink(kind: kind)
        dismiss()
    }

    private func cancel() {
        model.linkToCreate = nil
        dismiss()
    }
}
