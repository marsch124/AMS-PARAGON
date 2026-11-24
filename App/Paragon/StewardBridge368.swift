import SwiftUI
import ParagonCore

// Build 368: the link to AMS Financial Steward — the keychain side, the questions and the
// small views. The RULES are in Core (`StewardLink`, tested); the contract is `EventBridge`.

/// Where the bridge is kept, and what was last written to it.
///
/// 🚨 A test-vault, sample or screen-test run gets `MemoryBridge` and never the real keychain, so
/// made-up projects and events can never reach Finance Steward on the same device.
@MainActor
final class StewardBridgeState {
    let store: BridgeStore
    /// The project list as it was last written, so a keystroke that changes nothing writes nothing.
    var lastWritten: [EventBridge.Project]?
    var busy = false

    /// Passed beside `-paragon-test-vault`: the memory bridge is filled with made-up events (pictures).
    static let sampleArgument = "-paragon-bridge-sample"
    /// With the sample: no finished event, so "Mark the project done?" does not stand over a picture.
    static let noFinishedArgument = "-paragon-bridge-no-finished"

    init() {
        #if DEBUG
        if TestVault.isWanted {
            let memory = MemoryBridge()
            if ProcessInfo.processInfo.arguments.contains(Self.sampleArgument) {
                let quiet = ProcessInfo.processInfo.arguments.contains(Self.noFinishedArgument)
                memory.put(Self.sampleEvents(finished: !quiet), .events)
            }
            store = memory
            return
        }
        #endif
        store = KeychainBridge()
    }

    #if DEBUG
    static let lisbonID = "sample-lisbon"
    static let finishedID = "sample-finished"

    /// Made-up events for pictures. Lisbon is linked to a project of the test vault, Gotland is not,
    /// and one finished event is linked to the test vault's live project.
    static func sampleEvents(finished: Bool, today: DateOnly = .today()) -> EventBridge.EventList {
        func day(_ n: Int) -> String { today.adding(days: n).description }
        var events = [
            EventBridge.Event(id: lisbonID, name: "Lisbon Marathon", type: "race", from: day(25), to: day(27), place: "Lisbon",
                              planned: 980_000, spent: 640_000,
                              project: "Projects/\(TestVault.sampleProject).md", projectTitle: TestVault.sampleProject),
            EventBridge.Event(id: "sample-gotland", name: "Summer on Gotland", type: "trip", from: day(42), to: day(49), place: "Gotland",
                              planned: 1_400_000, spent: 0),
        ]
        if finished {
            events.append(EventBridge.Event(id: finishedID, name: "Stockholm 10 km", type: "race", from: day(-10), to: day(-9), place: "Stockholm",
                                            planned: 120_000, spent: 95_000, finished: day(-9),
                                            project: "Projects/\(TestVault.project).md", projectTitle: TestVault.project))
        }
        return EventBridge.EventList(written: Date(), events: events)
    }
    #endif
}

/// "Stockholm 10 km is finished in Steward. Mark the project done?"
struct StewardDoneQuestion: Equatable {
    let path: String
    let projectTitle: String
    let eventName: String
}

/// "Move the event in Steward to start on 2027-03-20 too?"
struct StewardMoveQuestion: Equatable {
    let eventID: String
    let eventName: String
    let day: String
}

// MARK: The model's side

extension AppModel {
    /// Reads what Steward left, acts on it, rewrites the project list and looks for the done question.
    /// Called with the outbox: after the vault opens, when the app comes to the front, and so on.
    func syncSteward() {
        let state = stewardState
        guard vault != nil, !state.busy else { return }
        state.busy = true
        defer { state.busy = false }
        // A project still coming from iCloud is not "missing": wait, and every message waits with it.
        if notesWaitingForCloud.isEmpty, notesBeingUpdated.isEmpty { handleStewardMessages() }
        refreshStewardEvents()
        writeStewardList(force: true)
        askStewardDone()
    }

    private func handleStewardMessages() {
        let store = stewardState.store
        let waiting = store.messages(.toParagon)
        guard !waiting.isEmpty else { return }
        flushPendingEdits()
        for message in waiting {
            switch StewardLink.apply(message, to: notes) {
            case .leave:
                continue
            case .discard:
                store.done(message, in: .toParagon)
            case .edit(let changed):
                var all = true
                for note in changed where !save(note) { all = false }
                if all { store.done(message, in: .toParagon) }
            case .make(let title, let due, let event):
                var extra = [(Note.stewardEventKey, event)]
                if let due { extra.append(("due", due)) }
                if makeNoteQuietly(kind: .project, title: title, extraFrontmatter: extra) != nil {
                    store.done(message, in: .toParagon)
                }
            }
        }
    }

    /// Steward's list as it was written last. Kept so the review step and the question can use it.
    func refreshStewardEvents() {
        let list = stewardState.store.list(EventBridge.EventList.self, .events)
        if list?.written != stewardEvents?.written || list?.events.count != stewardEvents?.events.count {
            stewardEvents = list
        }
    }

    /// The project list for Steward. `force` writes even when nothing changed (start, coming to the front);
    /// without it nothing is written unless the list differs from the last one.
    func writeStewardList(force: Bool = false) {
        guard vault != nil else { return }
        let projects = StewardLink.projectList(from: notes)
        let state = stewardState
        guard force || !StewardLink.sameProjects(projects, state.lastWritten) else { return }
        state.store.put(EventBridge.ProjectList(written: Date(), projects: projects), .projects)
        state.lastWritten = projects
    }

    /// Called when the notes change: a changed project, deadline, status or link reaches Steward.
    func stewardListMayHaveChanged() {
        guard vault != nil, stewardState.lastWritten != nil else { return }
        writeStewardList()
    }

    /// "Mark the project done?" — once per project, and only while nothing else is asking.
    func askStewardDone() {
        guard stewardDone == nil, whatNext == nil, activeSheet == nil, !focusQuestionPending, errorMessage == nil,
              !startScreenUp, notesWaitingForCloud.isEmpty, notesBeingUpdated.isEmpty,
              let events = stewardEvents?.events,
              let found = StewardLink.doneQuestion(notes: notes, events: events) else { return }
        stewardDone = StewardDoneQuestion(path: found.note.relativePath, projectTitle: found.note.displayTitle, eventName: found.event.name)
    }

    func stewardMarkDone(_ question: StewardDoneQuestion) {
        afterUpdate { self.stewardDone = nil }
        guard let note = note(at: question.path) else { return }
        setStatus(NoteStatus.done, for: note)
    }

    /// "Not now": written on the project, so it is not asked again on any device.
    func stewardNotNow(_ question: StewardDoneQuestion) {
        afterUpdate { self.stewardDone = nil }
        flushPendingEdits()
        guard let note = note(at: question.path) else { return }
        save(StewardLink.askedDone(note))
    }

    /// After a deadline was set on a linked project: ask whether the event moves too.
    func askStewardMove(after project: Note, newDue: DateOnly?) {
        guard let event = StewardLink.shouldAskToMoveEvent(project: project, newDue: newDue, events: stewardEvents?.events ?? []),
              let newDue else { return }
        afterUpdate { self.stewardMove = StewardMoveQuestion(eventID: event.id, eventName: event.name, day: newDue.description) }
    }

    func stewardMoveEvent(_ question: StewardMoveQuestion) {
        afterUpdate { self.stewardMove = nil }
        stewardState.store.send(EventBridge.Message(.moveDays, event: question.eventID, day: question.day))
    }

    /// Events running now or starting in the next 8 weeks (the review's step "Events ahead").
    var stewardEventsAhead: [EventBridge.Event] {
        EventBridge.ahead(stewardEvents?.events ?? [], today: DateOnly.today().description)
    }

    /// The project an event is linked to, found by the link on the note (not by what Steward remembers).
    func stewardProject(for event: EventBridge.Event) -> Note? {
        notes.first { $0.isStewardProject && $0.stewardEvent == event.id }
    }
}

// MARK: The questions

/// The two questions of the link, in the look of "What is next?": a card over a dimmed page, a
/// full-colour main button and a quiet second one.
struct StewardQuestions: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            .overlay {
                if let q = model.stewardDone {
                    StewardQuestionCard(
                        title: "Mark the project done?",
                        lead: Text(q.eventName).fontWeight(.semibold) + Text(" is finished in Steward."),
                        main: "Mark done", second: "Not now",
                        mainID: "steward.doneCard.markDone", secondID: "steward.doneCard.notNow",
                        cardID: "steward.doneCard",
                        mainAction: { model.stewardMarkDone(q) }, secondAction: { model.stewardNotNow(q) })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if let q = model.stewardMove {
                    StewardQuestionCard(
                        title: "Move the event too?",
                        lead: Text("Move the event in Steward to start on ") + Text(q.day).fontWeight(.semibold) + Text(" too?"),
                        main: "Move the event", second: "Only here",
                        mainID: "steward.moveEvent", secondID: "steward.onlyHere",
                        cardID: "steward.moveCard",
                        mainAction: { model.stewardMoveEvent(q) }, secondAction: { model.afterUpdate { model.stewardMove = nil } })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(Motion.arrive, value: model.stewardDone)
            .animation(Motion.arrive, value: model.stewardMove)
    }
}

struct StewardQuestionCard: View {
    let title: String
    let lead: Text
    let main: String
    let second: String
    let mainID: String
    let secondID: String
    let cardID: String
    let mainAction: () -> Void
    let secondAction: () -> Void

    private var tint: Color { ParaKind.project.tint }

    var body: some View {
        ZStack {
            Color.black.opacity(dim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: secondAction)
                .accessibilityHidden(true)
            card
        }
    }

    private var dim: Double {
        #if os(macOS)
        0.25
        #else
        0.35
        #endif
    }

    private var card: some View {
        VStack(spacing: 0) {
            MarkImage(ChainSymbol.project, size: 18)
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(tint.deep, in: Circle())
            Text(title)
                .font(Txt.sectionTitle)
                .foregroundStyle(.primary)
                .padding(.top, 8)
            lead
                .font(Txt.value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            Button(main, action: mainAction)
                .buttonStyle(MainButtonStyle(color: tint))
                .padding(.top, 14)
                .accessibilityIdentifier(mainID)
            Button(second, action: secondAction)
                .buttonStyle(.plain)
                .font(Txt.value)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 2)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier(secondID)
        }
        .padding(16)
        .frame(maxWidth: 340)
        .background(Color(PlatformColor.systemBackgroundColour), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(cardID)
    }
}

// MARK: Menus and the project page

/// "Open in Steward" for a linked project, "Make a Steward event" for one that is not.
struct StewardMenuItem: View {
    let note: Note
    @Environment(\.openURL) private var openURL

    var body: some View {
        if note.isStewardProject, note.noteStatus != .archived, let url = StewardLink.stewardURL(for: note) {
            if note.stewardEvent != nil {
                Button { openURL(url) } label: { MarkLabel("Open in Steward", "arrow.up.forward.app") }
                    .accessibilityIdentifier("steward.open")
            } else {
                Button { openURL(url) } label: { MarkLabel("Make a Steward event", "plus") }
                    .accessibilityIdentifier("steward.makeEvent")
            }
        }
    }
}

/// The small fact on a linked project's page: "Steward event". A tap opens it in Steward.
struct StewardFactChip: View {
    let note: Note
    @Environment(\.openURL) private var openURL

    var body: some View {
        if note.isStewardProject, note.stewardEvent != nil, let url = StewardLink.stewardURL(for: note) {
            Button { openURL(url) } label: {
                MarkLabel("Steward event", "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
            .foregroundStyle(ParaKind.project.tint.ink)
            .help("Open this project's event in Finance Steward")
            .accessibilityIdentifier("steward.open")
        }
    }
}

// MARK: The weekly review's step 10

/// **10. Events ahead** (build 368): the events from Steward that are on now or start in the next 8 weeks.
struct StewardEventsStep: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    @Binding var isOpen: Bool

    var body: some View {
        let ahead = model.stewardEventsAhead
        Section {
            if isOpen {
                if model.stewardEvents == nil {
                    Text("Open Finance Steward once on this device, then its events show here.")
                        .font(Txt.value).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("review.eventsAhead.never")
                } else if ahead.isEmpty {
                    Text("No events in the next 8 weeks.")
                        .font(Txt.value).foregroundStyle(.secondary)
                        .accessibilityIdentifier("review.eventsAhead.none")
                } else {
                    ForEach(ahead) { event in row(event) }
                }
            }
        } header: {
            ReviewPartHeading(title: "10. Events ahead", count: ahead.count, isOpen: $isOpen, part: "10")
        } footer: {
            if isOpen, let written = model.stewardEvents?.written {
                Text("As Steward knew it on \(DayWords.plain(written)).")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(_ event: EventBridge.Event) -> some View {
        let today = DateOnly.today().description
        let project = model.stewardProject(for: event)
        return VStack(alignment: .leading, spacing: 2) {
            Text(event.name).font(Txt.listTitle)
            Text("\(event.from) to \(event.to) \u{00B7} \(StewardLink.whenWords(event, today: today))")
                .font(Txt.listSecond).foregroundStyle(.secondary)
            Text(StewardLink.moneyLine(event))
                .font(Txt.listSecond).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                if let project {
                    Button { model.show(section: .review, notePath: project.relativePath) } label: {
                        MarkLabel(project.displayTitle, ChainSymbol.project, text: .caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ParaKind.project.tint.ink)
                    .accessibilityIdentifier("review.eventsAhead.project")
                }
                if let url = URL(string: "amsfinancialsteward://event/" + (event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.id)) {
                    Button { openURL(url) } label: { MarkLabel("Open in Steward", "arrow.up.forward.app", text: .caption) }
                        .buttonStyle(.plain)
                        .foregroundStyle(SidebarSection.review.tint.ink)
                        .accessibilityIdentifier("steward.open")
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.eventsAhead.\(event.id)")
    }
}
