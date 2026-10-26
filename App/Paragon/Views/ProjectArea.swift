import SwiftUI
import ParagonCore

// Which area a project is in (build 269).
//
// **Before this build nothing in the app could write `area:` except a drag on the Map**, the
// same fault as `due:` (132), an area's `goal:` (134), a project's `goal:` (140), `tags:` (144)
// and `status:` (165). The line was read by the Map, the planner and the widget all along.
//
// **Only this line decides** (his answer to the plan, 21 October): a `[[Health]]` in a
// project's text links the two notes but does not put the project in Health. Every screen
// reads the line through `NoteIndex.area(named:)`, so the button, the Map and the planner
// cannot give three answers. These views mirror the `AreaParent*` and `NoteGoal*` views in
// ContentView, but live in a file of their own so that file, which other builds change at the
// same time, stays as it was.

/// The words these views show, worked out in plain functions rather than inside a
/// `@ViewBuilder` (build 58).
enum ProjectAreaWording {
    /// Long enough for "Health › Mobility", short enough that one name cannot take the whole
    /// row at the top of a note. A Mac `Menu` is drawn by AppKit and does not take a SwiftUI
    /// frame inside its label, so the name is shortened here, where it is certain to work.
    static let longestName = 28

    /// An area as a line in the list: a sub-area after its own area, "Health › Yoga".
    static func name(of area: Note, in index: NoteIndex) -> String {
        guard let above = index.parentArea(of: area) else { return area.displayTitle }
        return "\(above.displayTitle) \u{203A} \(area.displayTitle)"
    }

    /// The same line with a tick in front when it is the one chosen.
    static func choice(_ area: Note, in index: NoteIndex, chosen: Bool) -> String {
        let shown = name(of: area, in: index)
        return chosen ? "\u{2713} \(shown)" : shown
    }

    /// A name cut to `longestName` characters, with "…" at the end when it was cut.
    static func short(_ name: String) -> String {
        guard name.count > longestName else { return name }
        return String(name.prefix(longestName - 1)) + "\u{2026}"
    }

    /// The archived area a name points at, found by the same rule as `NoteIndex.area(named:)`
    /// (title, shown title or file name, ignoring case). `area(named:)` answers with live areas
    /// only, so without this an archived Health would be called "No area is called Health" —
    /// untrue, since the note is in the Archive (build 100).
    static func archivedArea(named reference: String, in index: NoteIndex, besides project: Note) -> Note? {
        let name = reference.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        func same(_ candidate: String) -> Bool {
            candidate.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        return index.notes.first { candidate in
            candidate.declaredKind == .area && candidate.isArchived
                && candidate.relativePath != project.relativePath
                && (same(candidate.title) || same(candidate.displayTitle) || same(candidate.fileName))
        }
    }

    /// What is said when the line names no area here. While notes are still coming from
    /// iCloud the area may simply not have arrived yet, so "No area is called …" would be a
    /// guess (builds 100 and 118).
    static func missing(_ name: String, stillComing: Bool) -> String {
        stillComing ? "\(name) may still be coming from iCloud" : "No area is called \(name)"
    }
}

/// The places a project can be: in no area, or in one of the areas. Shared by the menu on a
/// row and the button at the top of the note, so both offer exactly the same choices.
struct ProjectAreaOptions: View {
    /// Passed in rather than read from the environment: these choices are shown inside a
    /// context menu, whose content is built outside the row's own view hierarchy.
    @ObservedObject var model: AppModel
    let note: Note

    /// Read back from the model: choosing saves and reloads, and the copy handed in a moment
    /// ago is then one behind (build 144).
    private var live: Note { model.note(at: note.relativePath) ?? note }
    private var current: Note? { model.index.area(of: live) }

    /// Every area that is not put away, each sub-area straight after its own area.
    private var areas: [Note] {
        model.index.areasInFamilyOrder().filter { !$0.isArchived }
    }

    private func label(for area: Note) -> String {
        ProjectAreaWording.choice(area, in: model.index, chosen: current?.relativePath == area.relativePath)
    }

    /// The area the line names when that area was archived: it exists, it is only put away.
    private var archived: Note? {
        guard current == nil, let written = live.area else { return nil }
        return ProjectAreaWording.archivedArea(named: written, in: model.index, besides: live)
    }

    /// The `area:` line when it names no area at all — misspelled, the area was renamed
    /// outside the app, or it is still coming from iCloud. Said out loud rather than hidden
    /// (build 100).
    private var unknownName: String? {
        guard current == nil, archived == nil, let written = live.area else { return nil }
        return written
    }

    private var unknownText: String {
        guard let unknownName else { return "" }
        return ProjectAreaWording.missing(unknownName, stillComing: !model.notesWaitingForCloud.isEmpty)
    }

    var body: some View {
        if let current {
            Button("Open \(current.displayTitle)") { model.show(current) }
            Divider()
        }
        if let archived {
            Text("\(archived.displayTitle) is archived")
            Button("Open \(archived.displayTitle)") { model.show(archived) }
            Divider()
        }
        if unknownName != nil {
            Text(unknownText)
            Divider()
        }
        Button(live.area == nil ? "\u{2713} In no area" : "In no area") {
            // The choice already ticked writes nothing (build 254's rule for the emoji): a
            // save moves the file's date, and here it would also take the template's empty
            // `area:` line away.
            guard live.area != nil else { return }
            model.setArea(live, to: nil)
        }
        if !areas.isEmpty {
            Divider()
            ForEach(areas) { area in
                Button(label(for: area)) {
                    guard current?.relativePath != area.relativePath else { return }
                    model.setArea(live, to: area)
                }
            }
        }
    }
}

/// Right-click a project in a list (press and hold on the phone): which area is it in?
struct ProjectAreaMenu: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        Menu("In area") {
            ProjectAreaOptions(model: model, note: note)
        }
    }
}

/// The same choices at the top of a project: **In area…** in grey while it is in none,
/// **In Health** in pink once it is in one.
struct ProjectAreaChip: View {
    @ObservedObject var model: AppModel
    let note: Note

    private var live: Note { model.note(at: note.relativePath) ?? note }
    private var current: Note? { model.index.area(of: live) }

    /// The area the line names when that area was archived: it exists, it is only put away.
    private var archived: Note? {
        guard current == nil, let written = live.area else { return nil }
        return ProjectAreaWording.archivedArea(named: written, in: model.index, besides: live)
    }

    /// Notes are still coming from iCloud, so a name that matches nothing here may only not
    /// have arrived yet (builds 100 and 118).
    private var stillComing: Bool { !model.notesWaitingForCloud.isEmpty }

    /// The whole name, for the tooltip and for VoiceOver.
    private var fullTitle: String {
        if let current { return "In \(ProjectAreaWording.name(of: current, in: model.index))" }
        // A line that names no area is shown as it is written, in grey, so it can be found
        // and put right — never drawn as if the project were in no area at all.
        if let written = live.area { return archived == nil ? "In \(written)" : "In \(written) (archived)" }
        return "In area\u{2026}"
    }

    private var title: String {
        if let current { return "In \(ProjectAreaWording.short(ProjectAreaWording.name(of: current, in: model.index)))" }
        if let written = live.area {
            let shown = "In \(ProjectAreaWording.short(written))"
            return archived == nil ? shown : "\(shown) (archived)"
        }
        return "In area\u{2026}"
    }

    /// Pink in an area; orange while the area it names may still be coming from iCloud, as
    /// every other "still coming" line is; grey otherwise.
    private var tint: Color {
        if current != nil { return ParaKind.area.tint }
        if live.area != nil, archived == nil, stillComing { return Color.orange }
        return Color.secondary
    }

    private var tooltip: String {
        if current != nil { return "\(fullTitle). Press to choose another area, or none." }
        if let archived { return "\(archived.displayTitle) is archived. Press to choose another area, or none." }
        if let written = live.area {
            if stillComing { return "\(ProjectAreaWording.missing(written, stillComing: true))." }
            return "\(ProjectAreaWording.missing(written, stillComing: false)). Press to choose one."
        }
        return "Which area this project is part of"
    }

    var body: some View {
        Menu {
            ProjectAreaOptions(model: model, note: note)
        } label: {
            Label(title, systemImage: ChainSymbol.area)
                .lineLimit(1)
        }
        .menuIndicator(.hidden)
        // On the chip itself, never on the row: the row is a `WrappingHStack` (build 250).
        .fixedSize()
        .foregroundStyle(tint)
        .help(tooltip)
        // Set explicitly, one sentence on both platforms, so the screen test reads the same
        // words on the Mac's menu button and the phone's button (build 253).
        .accessibilityLabel(fullTitle)
        .accessibilityIdentifier("note.area")
    }
}
