import Foundation

/// What the iPhone widget draws, written by the app and read by the widget.
///
/// **Build 174.** A widget is a separate process with no access to the vault: the folder is
/// reached through a security-scoped bookmark that only the app can resolve, and a widget is
/// given a few milliseconds and no user to ask. So the app writes a small file into the shared
/// App Group container whenever the vault is reloaded, and the widget reads only that.
///
/// **The widget never opens a note, never parses markdown and never writes anything.** That is
/// the whole design: one writer, one reader, one small file. If the file is missing or old the
/// widget says so rather than showing nothing — build 100's rule, on a home screen.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// One action on the widget.
    public struct Item: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var title: String
        public var noteTitle: String
        /// `ParaKind.rawValue` of the note the task lives in, so the widget can draw its
        /// symbol and colour without a second table of its own.
        public var noteKind: String
        /// "today", "2 days over", "tomorrow" — already in words, because
        /// `DateOnly.timeLeftText(from:)` lives here and the widget must not invent a second
        /// wording (build 163).
        public var dueText: String?
        public var isOverdue: Bool
        /// The goal this action is in aid of, else the area. The chain, in one line — the
        /// same thing the planner's Actions column shows (build 149).
        public var serves: String?
        public var servesIsGoal: Bool
        /// `amspara://…`, so a tap opens the note in the app.
        public var url: String

        public init(id: String, title: String, noteTitle: String, noteKind: String,
                    dueText: String?, isOverdue: Bool, serves: String?, servesIsGoal: Bool,
                    url: String) {
            self.id = id
            self.title = title
            self.noteTitle = noteTitle
            self.noteKind = noteKind
            self.dueText = dueText
            self.isOverdue = isOverdue
            self.serves = serves
            self.servesIsGoal = servesIsGoal
            self.url = url
        }
    }

    /// The day the app was standing on when it wrote this.
    public var day: DateOnly
    public var written: Date
    public var dueToday: Int
    public var overdue: Int
    public var inboxCount: Int
    /// Notes past their review rhythm (build 172).
    public var dueForReview: Int
    public var items: [Item]

    public init(day: DateOnly, written: Date, dueToday: Int, overdue: Int,
                inboxCount: Int, dueForReview: Int, items: [Item]) {
        self.day = day
        self.written = written
        self.dueToday = dueToday
        self.overdue = overdue
        self.inboxCount = inboxCount
        self.dueForReview = dueForReview
        self.items = items
    }

    /// The most actions any widget size shows. Writing more would make the file bigger for
    /// nothing; the widget is a glance, not a list.
    public static let maxItems = 8

    /// The file name inside the App Group container. One constant, so the app and the widget
    /// cannot look in two different places.
    public static let fileName = "widget-snapshot.json"

    /// Nothing to show, but the app has run. Told apart from "no file at all", which means the
    /// app has never been opened on this phone.
    public var isEmpty: Bool { items.isEmpty }

    /// True when the app has not written since yesterday. The widget says "opened yesterday"
    /// rather than drawing yesterday's list as if it were today's — an out-of-date answer
    /// presented as a current one is the fault build 100 is about.
    public func isStale(on today: DateOnly) -> Bool { day != today }
}

public extension WidgetSnapshot {
    /// Reads the snapshot from a container folder. **Every failure reads as nil**, never as an
    /// empty snapshot: "the app has not written yet" and "it wrote nothing to do" are different
    /// answers and the widget draws them differently.
    static func read(fromContainer container: URL) -> WidgetSnapshot? {
        let url = container.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Writes it. Atomic, because the widget can be reading while the app writes.
    func write(toContainer container: URL) throws {
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self)
            .write(to: container.appendingPathComponent(WidgetSnapshot.fileName), options: .atomic)
    }
}

public extension NoteIndex {
    /// The actions worth doing on a day: everything due then or earlier, then the next actions.
    ///
    /// **Moved here in build 174** from `AppModel`, so the planner's Actions column and the
    /// widget ask one question once. Two lists called "today's actions" that could answer
    /// differently is the fault this project keeps finding (the Map, the review and the goal
    /// dashboard before build 162).
    func actionsForPlanning(on day: DateOnly) -> [TaskRef] {
        var seen = Set<String>()
        var result: [TaskRef] = []
        for ref in openTasks(dueOnOrBefore: day) where seen.insert(ref.id).inserted {
            result.append(ref)
        }
        for ref in nextActions() where seen.insert(ref.id).inserted {
            result.append(ref)
        }
        return result
    }

    /// What an action is in aid of: the goal its note serves, else the area it sits in.
    /// The chain, in one line — the same answer the planner's Actions column draws.
    func serves(_ ref: TaskRef) -> (title: String, isGoal: Bool)? {
        guard let note = self.note(path: ref.notePath) else { return nil }
        if let goal = note.goal {
            return (self.goal(matching: goal)?.displayTitle ?? goal, true)
        }
        if let area = note.area {
            return (self.note(matching: area)?.displayTitle ?? area, false)
        }
        return nil
    }

    /// Builds what the widget should draw.
    ///
    /// `dueForReview` is handed in rather than worked out here: the rhythm lives in
    /// `VaultConfig`, which the index does not carry, and a snapshot that guessed the default
    /// rhythm would disagree with the review screen beside it.
    func widgetSnapshot(on day: DateOnly = .today(), inboxCount: Int, dueForReview: Int,
                        written: Date = Date(), limit: Int = WidgetSnapshot.maxItems) -> WidgetSnapshot {
        let actions = actionsForPlanning(on: day)
        let items = actions.prefix(limit).map { ref -> WidgetSnapshot.Item in
            let due = ref.task.dueDate
            let serves = self.serves(ref)
            return WidgetSnapshot.Item(
                id: ref.id,
                title: ref.task.title,
                noteTitle: ref.noteTitle,
                noteKind: (self.note(path: ref.notePath)?.declaredKind ?? .project).rawValue,
                dueText: due.map { $0.timeLeftText(from: day) },
                isOverdue: due.map { $0 < day } ?? false,
                serves: serves?.title,
                servesIsGoal: serves?.isGoal ?? false,
                url: WidgetSnapshot.link(toNoteTitled: ref.noteTitle)
            )
        }
        return WidgetSnapshot(
            day: day,
            written: written,
            dueToday: openTasks(dueOn: day).count,
            overdue: actions.filter { ($0.task.dueDate.map { $0 < day }) ?? false }.count,
            inboxCount: inboxCount,
            dueForReview: dueForReview,
            items: Array(items)
        )
    }
}

public extension WidgetSnapshot {
    /// `amspara://<note title>`, which `AppModel.handle(url:)` has opened since build 39.
    /// **The existing scheme, never a new one**: `amspara://` is one of the four identifiers
    /// the rename deliberately kept, and his Shortcuts already use it.
    static func link(toNoteTitled title: String) -> String {
        let allowed = CharacterSet.urlHostAllowed
        let encoded = title.addingPercentEncoding(withAllowedCharacters: allowed) ?? title
        return "amspara://\(encoded)"
    }
}
