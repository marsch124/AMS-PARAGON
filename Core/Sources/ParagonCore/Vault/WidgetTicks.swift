import Foundation

/// A task ticked on a widget (build 317), waiting for the app to write it into its note.
///
/// **The widget never writes the vault.** The vault is a folder he picked, reached through a
/// security-scoped bookmark only the app can resolve, and often in iCloud Drive: a second
/// process writing a note there, with no knowledge of what the editor holds unsaved or what
/// iCloud is bringing in, is how a line is lost. So a tick on the widget is one line appended
/// to a small file in the shared App Group folder — the same shape as the share extension's
/// outbox — and **the app ticks the task itself, through `AppModel.toggle`, the path every
/// tick in the app takes**: at launch, when it comes to the front, and every ten seconds while
/// it is open. The widget draws the line ticked at once, from this file.
///
/// **A tick is tied to one task and to no other** (build 256's rule for the focus timer's
/// **Done**): its `^t` id when it has one, else its exact words and date. If that task is no
/// longer there and open — ticked in Reminders, renamed, moved — the tick is dropped. It never
/// lands on another task.
public struct WidgetTick: Codable, Equatable, Sendable {
    /// `WidgetSnapshot.Item.id`: the line this tick was made on.
    public var key: String
    public var notePath: String
    /// The task's `^t` id, when it has one.
    public var taskID: String?
    /// The task's title exactly as the note has it (with `#next`, which the widget hides).
    public var title: String
    public var due: DateOnly?
    public var at: Date
    /// False when the tick was taken back on the widget before the app wrote it.
    public var ticked: Bool

    public init(key: String, notePath: String, taskID: String?, title: String, due: DateOnly?,
                at: Date, ticked: Bool = true) {
        self.key = key
        self.notePath = notePath
        self.taskID = taskID
        self.title = title
        self.due = due
        self.at = at
        self.ticked = ticked
    }

    /// What the app does with a tick.
    public enum Outcome: Equatable, Sendable {
        /// Tick this task, as the note holds it now.
        case tick(TaskItem)
        /// The task is not there to tick any more: drop the tick.
        case gone
        /// Its note has not come from iCloud yet: keep the tick and try again later.
        case wait
    }

    /// The rule. `note` is the note at `notePath` as the app holds it now, or nil when it has
    /// none; `notesStillArriving` is true while any note is still coming from iCloud — a missing
    /// note is then not proof of anything (build 100's rule), and the tick waits.
    ///
    /// `noteBeingUpdated` (review of build 317): the note is here, but as an older copy while
    /// iCloud holds a newer one. The other device may have ticked the task there already, so
    /// nothing is written into the old copy; the tick waits for the new one.
    public func outcome(in note: Note?, notesStillArriving: Bool, noteBeingUpdated: Bool = false) -> Outcome {
        guard let note else { return notesStillArriving ? .wait : .gone }
        if noteBeingUpdated { return .wait }
        let open = note.tasks.filter { !$0.isDone }
        if let id = taskID {
            if let byID = open.first(where: { $0.id == id }) { return .tick(byID) }
            // The task with that id is there and already done: another task with the same
            // words must not be ticked in its place.
            if note.tasks.contains(where: { $0.id == id }) { return .gone }
        }
        let same = open.filter { $0.title == title && $0.dueDate == due }
        // Two open tasks with the same words and date cannot be told apart: neither is ticked.
        return same.count == 1 ? .tick(same[0]) : .gone
    }
}

/// The file the ticks wait in: one JSON line per press, appended, never rewritten in place.
public struct WidgetTickQueue: Sendable {
    public static let fileName = "widget-ticks.jsonl"

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(container: URL) {
        self.fileURL = container.appendingPathComponent(Self.fileName)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Adds one press. `O_APPEND`, so a line lands whole at the end even when the widget and
    /// the app write at the same moment (the capture outbox's way).
    public func append(_ tick: WidgetTick) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        var line = try Self.encoder.encode(tick)
        line.append(contentsOf: [0x0A])
        let fd = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: line)
    }

    /// The ticks that are waiting, oldest first. Nothing is changed.
    public func pending() -> [WidgetTick] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return Self.settle(Self.lines(in: data))
    }

    /// Takes the waiting ticks and empties the file. The file is renamed first, so a press
    /// made meanwhile lands in a fresh file and is not lost.
    public func drain() -> [WidgetTick] {
        let taken = fileURL.deletingLastPathComponent()
            .appendingPathComponent("widget-ticks.\(UUID().uuidString).jsonl")
        // Asked first: this runs every ten seconds, and nearly always there is no file.
        guard FileManager.default.fileExists(atPath: fileURL.path),
              (try? FileManager.default.moveItem(at: fileURL, to: taken)) != nil else { return [] }
        defer { try? FileManager.default.removeItem(at: taken) }
        guard let data = try? Data(contentsOf: taken) else { return [] }
        return Self.settle(Self.lines(in: data))
    }

    /// Puts ticks back: the ones whose note has not arrived yet.
    public func requeue(_ ticks: [WidgetTick]) {
        for tick in ticks { try? append(tick) }
    }

    private static func lines(in data: Data) -> [WidgetTick] {
        data.split(separator: 0x0A).compactMap { try? decoder.decode(WidgetTick.self, from: $0) }
    }

    /// **The last press on a line is the one that counts.** A tick taken back leaves nothing
    /// waiting; a tick, taken back, and made again is one tick. Lines the file cannot decode
    /// are skipped. Oldest first.
    static func settle(_ presses: [WidgetTick]) -> [WidgetTick] {
        var last: [String: WidgetTick] = [:]
        for press in presses { last[press.key + "\u{1F}" + press.title] = press }
        return last.values.filter(\.ticked).sorted { ($0.at, $0.key) < ($1.at, $1.key) }
    }
}

public extension WidgetSnapshot.Item {
    /// The press on this line, or nil for a line written by a build that could not tick
    /// (it carries no note path, and the widget then draws no tick circle).
    func tick(at date: Date, ticked: Bool = true) -> WidgetTick? {
        guard let notePath else { return nil }
        return WidgetTick(key: id, notePath: notePath, taskID: taskID, title: rawTitle ?? title,
                          due: due, at: date, ticked: ticked)
    }
}

public extension WidgetSnapshot {
    /// The lines the widget draws ticked: those with a waiting tick made on the same line with
    /// the same words. (A line's id is its place in its note, and places move.)
    func tickedIDs(_ ticks: [WidgetTick]) -> Set<String> {
        var result = Set<String>()
        for item in items where ticks.contains(where: { $0.key == item.id && $0.title == (item.rawTitle ?? item.title) }) {
            result.insert(item.id)
        }
        return result
    }

    /// The summary as it will be once the app has written the waiting ticks: those lines gone
    /// and the numbers lower. The Lock Screen widgets draw this, so a task ticked on the Home
    /// Screen is not still counted beside the clock.
    func settled(_ ticks: [WidgetTick]) -> WidgetSnapshot {
        let ticked = tickedIDs(ticks)
        guard !ticked.isEmpty else { return self }
        var copy = self
        for item in items where ticked.contains(item.id) {
            if item.isOverdue {
                copy.overdue = max(0, copy.overdue - 1)
            } else if item.due == day {
                copy.dueToday = max(0, copy.dueToday - 1)
            }
        }
        copy.items = items.filter { !ticked.contains($0.id) }
        return copy
    }
}

// MARK: - The Lock Screen's words

/// What the three Lock Screen widgets say (build 317). Decided here and tested, so the widget
/// only draws. `nil` stands for "no file": the app has not been opened on this iPhone.
public enum LockGlance {
    /// Said when there is no file, or the file is from another day: a number from yesterday
    /// beside today's clock would be an old answer shown as a new one (build 100).
    public static let openText = "Open PARAGON"

    private static func fresh(_ snapshot: WidgetSnapshot?, on today: DateOnly) -> WidgetSnapshot? {
        guard let snapshot, !snapshot.isStale(on: today) else { return nil }
        return snapshot
    }

    /// The number in the round widget: everything open that is due today or earlier. Nil when
    /// there is nothing to count from.
    public static func count(_ snapshot: WidgetSnapshot?, on today: DateOnly) -> Int? {
        fresh(snapshot, on: today).map { $0.dueToday + $0.overdue }
    }

    /// The line above the clock: "3 due today", "3 due today, 1 overdue", "2 overdue",
    /// "Nothing due today".
    public static func inline(_ snapshot: WidgetSnapshot?, on today: DateOnly) -> String {
        guard let s = fresh(snapshot, on: today) else { return openText }
        switch (s.dueToday, s.overdue) {
        case (0, 0): return "Nothing due today"
        case (let due, 0): return "\(due) due today"
        case (0, let over): return "\(over) overdue"
        case (let due, let over): return "\(due) due today, \(over) overdue"
        }
    }

    /// The lines of the wide widget: the next two actions, in the order of **Today's actions**.
    /// Empty when nothing is due and nothing is next.
    public static func lines(_ snapshot: WidgetSnapshot?, on today: DateOnly, limit: Int = 2) -> [String] {
        guard let s = fresh(snapshot, on: today) else { return [] }
        return s.items.prefix(limit).map(\.title)
    }

    /// What the wide widget says in place of lines.
    public static func emptyText(_ snapshot: WidgetSnapshot?, on today: DateOnly) -> String {
        fresh(snapshot, on: today) == nil ? openText : "Nothing due, nothing waiting"
    }
}
