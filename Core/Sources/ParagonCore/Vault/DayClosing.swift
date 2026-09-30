import Foundation

// Build 236: a fuller **Close the day**. He chose, from a drawing of two shapes
// (https://claude.ai/artifact/DAuGkev2WtZqotkZR36qTA): one page, top to bottom; **counts and
// what they served** rather than every task by name; and **First** only *marks* an action for
// tomorrow, so **Start the day** shows it at the top in the morning — no block is made.
// Both decisions live here, in Core, because they decide what is stored and what is counted.

/// How many finished tasks went towards one thing: a goal, an area, or the note itself.
public struct ServedCount: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The task's note serves a goal (an aspiration or a goal with a date).
        case goal
        /// The task's note sits in an area.
        case area
        /// Neither: the count belongs to the note the task is written in.
        case note(ParaKind)
    }

    public var title: String
    public var kind: Kind
    public var count: Int

    public var id: String {
        switch kind {
        case .goal: return "goal:" + title
        case .area: return "area:" + title
        case .note(let paraKind): return "note:\(paraKind.rawValue):" + title
        }
    }

    public init(title: String, kind: Kind, count: Int) {
        self.title = title
        self.kind = kind
        self.count = count
    }
}

public extension NoteIndex {
    /// The finished tasks gathered by what they served, most first, then by name.
    ///
    /// **One chain, one answer**: `serves(_:)` is the question the planner's Actions column and
    /// the widget already ask (build 174), so a task counts towards the same thing here as it is
    /// shown serving there. A task whose note serves nothing counts towards its own note —
    /// "Bathroom renovation: 2" says more than "2 served nothing".
    func servedCounts(of refs: [TaskRef]) -> [ServedCount] {
        var counts: [String: ServedCount] = [:]
        var order: [String] = []
        for ref in refs {
            let entry: ServedCount
            if let served = serves(ref) {
                entry = ServedCount(title: served.title, kind: served.isGoal ? .goal : .area, count: 1)
            } else {
                let kind = note(path: ref.notePath)?.declaredKind ?? .inbox
                entry = ServedCount(title: ref.noteTitle, kind: .note(kind), count: 1)
            }
            if counts[entry.id] == nil {
                counts[entry.id] = entry
                order.append(entry.id)
            } else {
                counts[entry.id]?.count += 1
            }
        }
        return order.compactMap { counts[$0] }
            .sorted { $0.count != $1.count ? $0.count > $1.count
                                           : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

/// One action marked **First** for a day.
///
/// Kept by the note's path and the task's **title**, never by `TaskRef.id`: that id carries the
/// line number, and a line moves the moment anything above it changes — overnight on another
/// device, for instance. The title is what a task is to him.
public struct FirstPick: Codable, Hashable, Sendable {
    public var notePath: String
    public var title: String

    public init(notePath: String, title: String) {
        self.notePath = notePath
        self.title = title
    }

    public init(_ ref: TaskRef) {
        self.init(notePath: ref.notePath, title: ref.task.title)
    }

    public func matches(_ ref: TaskRef) -> Bool {
        ref.notePath == notePath && ref.task.title == title
    }
}

/// The actions marked **First**, per day.
///
/// **A mark, not a change to the task.** Nothing is written into the note: a `#first` tag would
/// travel into Apple Reminders and stay behind on the line after the morning has passed. So the
/// marks live in `.ams-para/first.json`, beside `tags.json` and `searches.json` — inside the
/// vault, so a mark made on the phone in the evening is there on the Mac in the morning.
public struct FirstPicks: Codable, Equatable, Sendable {
    /// `YYYY-MM-DD` → the marks for that day, in the order they were made.
    public var byDay: [String: [FirstPick]]

    public init(byDay: [String: [FirstPick]] = [:]) {
        self.byDay = byDay
    }

    public func picks(on day: DateOnly) -> [FirstPick] {
        byDay[day.description] ?? []
    }

    public func isFirst(_ ref: TaskRef, on day: DateOnly) -> Bool {
        picks(on: day).contains { $0.matches(ref) }
    }

    public mutating func toggle(_ ref: TaskRef, on day: DateOnly) {
        var list = picks(on: day)
        if let index = list.firstIndex(where: { $0.matches(ref) }) {
            list.remove(at: index)
        } else {
            list.append(FirstPick(ref))
        }
        byDay[day.description] = list.isEmpty ? nil : list
    }

    /// Marks for days before `day` are finished with; nothing ever reads them again.
    public mutating func dropDays(before day: DateOnly) {
        byDay = byDay.filter { key, _ in (DateOnly(key).map { $0 >= day }) ?? false }
    }

    /// The refs marked for `day`, in the order they were marked, and the rest in their own order.
    public func split(_ refs: [TaskRef], on day: DateOnly) -> (first: [TaskRef], rest: [TaskRef]) {
        let marks = picks(on: day)
        let first = marks.compactMap { mark in refs.first { mark.matches($0) } }
        let rest = refs.filter { ref in !marks.contains { $0.matches(ref) } }
        return (first, rest)
    }
}

public extension Vault {
    var firstPicksURL: URL { stateFolderURL.appendingPathComponent("first.json") }

    /// Empty when there is no file yet or it cannot be read: a lost mark only means an action
    /// is not on top in the morning, and it is still in the list below.
    func firstPicks() -> FirstPicks {
        guard let data = try? Data(contentsOf: firstPicksURL),
              let picks = try? JSONDecoder().decode(FirstPicks.self, from: data) else { return FirstPicks() }
        return picks
    }

    func saveFirstPicks(_ picks: FirstPicks) throws {
        try FileManager.default.createDirectory(at: stateFolderURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(picks).write(to: firstPicksURL, options: .atomic)
    }
}
