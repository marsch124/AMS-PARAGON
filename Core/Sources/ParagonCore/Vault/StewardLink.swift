import Foundation

/// The PARAGON half of the link to AMS Financial Steward (build 368). The contract is `EventBridge`
/// (the same file as in Steward). Everything here is a rule on notes, with no keychain and no screen,
/// so each rule has a small test.
///
/// The link on a project is one line in its frontmatter: `steward-event: <event id>`. After "Not now"
/// on the question "Mark the project done?" the project says `steward-asked: done`.
public extension Note {
    static let stewardEventKey = "steward-event"
    static let stewardAskedKey = "steward-asked"

    /// The Steward event this project is linked to.
    var stewardEvent: String? {
        guard let id = frontmatter.string(Note.stewardEventKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else { return nil }
        return id
    }
    /// He said "Not now" to the question about marking this project done.
    var stewardAskedDone: Bool { frontmatter.string(Note.stewardAskedKey)?.lowercased() == "done" }

    /// A project as far as the link is concerned: a project note, or an archived one that still says it was a project.
    var isStewardProject: Bool { kind == .project || frontmatter.string("type")?.lowercased() == "project" }
}

public enum StewardLink {
    /// What one message does to the vault.
    public enum Outcome: Equatable {
        /// These notes changed (whole notes, ready to save). The message is deleted afterwards.
        case edit([Note])
        /// Make a new project with this title, deadline and link; then the message is deleted.
        case make(title: String, due: String?, event: String)
        /// Nothing to do (the project cannot be found, or it is already so): delete the message quietly.
        case discard
        /// Not for this app or not understood: leave it where it is.
        case leave
    }

    /// The project list PARAGON writes for Steward: every live project (active or on hold) and every project that
    /// carries a link, whatever its state. Sorted by title so an unchanged vault gives an unchanged list.
    public static func projectList(from notes: [Note]) -> [EventBridge.Project] {
        notes.filter { $0.isStewardProject && ($0.stewardEvent != nil || $0.noteStatus == .active || $0.noteStatus == .onHold) }
            .map { n in
                EventBridge.Project(path: n.relativePath, title: n.displayTitle, status: n.noteStatus.rawValue,
                                    due: n.dueDate?.description, event: n.stewardEvent)
            }
            .sorted { ($0.title, $0.path) < ($1.title, $1.path) }
    }

    /// Is this list the same as the one written last (ignoring the time it was written)?
    public static func sameProjects(_ a: [EventBridge.Project], _ b: [EventBridge.Project]?) -> Bool { a == b }

    /// What a message does. `notes` is every note in the vault.
    public static func apply(_ m: EventBridge.Message, to notes: [Note]) -> Outcome {
        guard let kind = m.known, kind.box == .toParagon else { return .leave }
        let carrying = notes.filter { $0.isStewardProject && $0.stewardEvent == m.event }
        switch kind {
        case .makeProject:
            // Already made (or linked): never a second one.
            if !carrying.isEmpty { return .discard }
            let title = (m.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return .discard }
            if var same = notes.first(where: { $0.isStewardProject && $0.noteStatus.isLive && $0.stewardEvent == nil
                                                && $0.displayTitle.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                same.frontmatter.set(Note.stewardEventKey, m.event)
                return .edit([same])
            }
            return .make(title: title, due: m.day.flatMap { DateOnly($0) }?.description, event: m.event)
        case .link:
            guard let path = m.path, var target = notes.first(where: { $0.relativePath == path && $0.isStewardProject }) else { return .discard }
            var changed: [Note] = []
            for var other in carrying where other.relativePath != path {
                other.frontmatter.remove(Note.stewardEventKey)
                other.frontmatter.remove(Note.stewardAskedKey)
                changed.append(other)
            }
            if target.stewardEvent != m.event {
                target.frontmatter.set(Note.stewardEventKey, m.event)
                target.frontmatter.remove(Note.stewardAskedKey)
                changed.append(target)
            }
            return changed.isEmpty ? .discard : .edit(changed)
        case .unlink:
            let changed = carrying.map { n -> Note in
                var n = n
                n.frontmatter.remove(Note.stewardEventKey)
                n.frontmatter.remove(Note.stewardAskedKey)
                return n
            }
            return changed.isEmpty ? .discard : .edit(changed)
        case .setDue:
            guard let day = m.day.flatMap({ DateOnly($0) }) else { return .discard }
            let changed = carrying.filter { $0.dueDate != day }.map { n -> Note in
                var n = n
                n.frontmatter.set("due", day.description)
                return n
            }
            return changed.isEmpty ? .discard : .edit(changed)
        case .addTask:
            let words = (m.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty, var project = carrying.first else { return .discard }
            // The same words are never added twice (a message handled, then the app stopped before deleting it).
            if project.body.contains("- [ ] " + words) || project.body.contains("- [x] " + words) { return .discard }
            _ = project.append(task: TaskParser.normalized(TaskItem(title: words)))
            return .edit([project])
        case .moveDays:
            return .leave
        }
    }

    /// The project PARAGON asks about ("Mark the project done?"): live, linked to a finished event, not asked before.
    public static func doneQuestion(notes: [Note], events: [EventBridge.Event]) -> (note: Note, event: EventBridge.Event)? {
        let projects = projectList(from: notes)
        for p in projects {
            guard let event = EventBridge.eventIsFinished(for: p, in: events),
                  let note = notes.first(where: { $0.relativePath == p.path }), !note.stewardAskedDone else { continue }
            return (note, event)
        }
        return nil
    }

    /// The note with "Not now" written on it.
    public static func askedDone(_ note: Note) -> Note {
        var n = note
        n.frontmatter.set(Note.stewardAskedKey, "done")
        return n
    }

    /// The link a project's menu opens: its event in Steward, or a new event filled in from the project.
    public static func stewardURL(for note: Note) -> URL? {
        if let id = note.stewardEvent {
            return URL(string: "amsfinancialsteward://event/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id))
        }
        var c = URLComponents()
        c.scheme = "amsfinancialsteward"
        c.host = "new-event"
        var items = [URLQueryItem(name: "project", value: note.relativePath), URLQueryItem(name: "title", value: note.displayTitle)]
        if let due = note.dueDate { items.append(URLQueryItem(name: "due", value: due.description)) }
        c.queryItems = items
        return c.url
    }

    /// The question after he changes a linked project's deadline: only when it really moved to another day than the event's first.
    public static func shouldAskToMoveEvent(project: Note, newDue: DateOnly?, events: [EventBridge.Event]) -> EventBridge.Event? {
        guard let id = project.stewardEvent, let newDue,
              let event = events.first(where: { $0.id == id }), event.finished == nil, event.from != newDue.description else { return nil }
        return event
    }

    /// When an event is: "On now, until 2027-03-14", "Starts tomorrow" or "Starts in 25 days".
    public static func whenWords(_ e: EventBridge.Event, today: String) -> String {
        guard let n = EventBridge.days(from: today, to: e.from) else { return e.from }
        if n <= 0 { return "On now, until \(e.to)" }
        if n == 1 { return "Starts tomorrow" }
        return "Starts in \(n) days"
    }

    /// "Planned 9 800 kr · spent 6 400 kr"
    public static func moneyLine(_ e: EventBridge.Event) -> String {
        "Planned \(EventBridge.kronor(e.planned)) · spent \(EventBridge.kronor(e.spent))"
    }
}

private extension NoteStatus {
    var isLive: Bool { self == .active || self == .onHold }
}
