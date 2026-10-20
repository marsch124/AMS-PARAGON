import Foundation

/// **Planned and worked** in **Close the day** (build 259), the last step of PARAGON Time and
/// Focus, from the drawing he loved (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX): each
/// thing next to the time planned for it and the time the clock measured, and **All of today**
/// under them — *"Over time you learn how long things really take."*
///
/// **Two sources, both already in today's daily note.** What was planned is the day's blocks
/// under `## Plan` (**Start the day**'s **Plan** makes each one as long as its task); what was
/// worked is the `## Worked` lines the focus clock writes. A thing worked on with no block takes
/// its planned time from the task's own time (`~45m`), because that is what the clock was
/// started against. **Nothing is guessed**: with no block and no time the cell is empty, never a
/// number — build 141's rule that an absence must not look like a zero.
///
/// **Matched by name**, because a worked line carries nothing else. The clock names its line
/// exactly the way **Plan** names a block (`TaskItem.planTitle`), so a task planned in the
/// morning and worked on in the afternoon lands on one row. Case and spaces are ignored, so a
/// block he retyped by hand still finds its work.
public struct PlannedAndWorked: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public var title: String
        /// Minutes planned, or nil when there was no block and the task has no time.
        public var planned: Int?
        /// Minutes the clock measured, or nil when the clock never ran on it.
        public var worked: Int?

        public init(title: String, planned: Int?, worked: Int?) {
            self.title = title
            self.planned = planned
            self.worked = worked
        }

        public var id: String { PlannedAndWorked.key(title) }

        /// Worked longer than planned. Only when both are known: a row with no plan cannot be
        /// over it.
        public var isOver: Bool {
            guard let planned, let worked else { return false }
            return worked > planned
        }
    }

    /// In the order the day ran: by the earliest block or worked line of each.
    public var rows: [Row]

    /// All of today: the sum of what was planned, or nil when nothing had a planned time.
    public var plannedTotal: Int? {
        let known = rows.compactMap(\.planned)
        return known.isEmpty ? nil : known.reduce(0, +)
    }

    /// All of today: the sum of what was worked, or nil when the clock never ran.
    public var workedTotal: Int? {
        let known = rows.compactMap(\.worked)
        return known.isEmpty ? nil : known.reduce(0, +)
    }

    public var isEmpty: Bool { rows.isEmpty }

    /// `tasks` are where a thing worked on with no block finds its planned time. A name gives a
    /// time only when every task under it has the same one: two tasks can share a title (build
    /// 256's review), and one task's time must never be lent to another. The same task handed in
    /// twice agrees with itself. Hand in none when **Use task times** is off: a hidden `~45m`
    /// must not appear here either (build 257).
    public init(blocks: [PlanBlock], worked: [WorkedSpan], tasks: [TaskItem] = []) {
        var gathered: [String: Gathered] = [:]
        for block in blocks {
            let key = Self.key(block.title)
            guard !key.isEmpty else { continue }
            var row = gathered[key] ?? Gathered(title: Self.tidy(block.title), first: block.start)
            row.first = min(row.first, block.start)
            row.planned = (row.planned ?? 0) + block.minutes
            gathered[key] = row
        }
        for span in worked {
            let key = Self.key(span.title)
            // A line typed by hand that ends before it starts says nothing about the work.
            guard !key.isEmpty, span.minutes > 0 else { continue }
            var row = gathered[key] ?? Gathered(title: Self.tidy(span.title), first: span.start)
            row.first = min(row.first, span.start)
            row.worked = (row.worked ?? 0) + span.minutes
            gathered[key] = row
        }
        var times: [String: Int] = [:]
        var named: Set<String> = []
        var unclear: Set<String> = []
        for task in tasks {
            let key = Self.key(task.planTitle)
            var minutes: Int?
            if let time = task.minutes, time > 0 { minutes = time }
            if named.insert(key).inserted {
                if let minutes { times[key] = minutes }
            } else if times[key] != minutes {
                unclear.insert(key)
            }
        }
        // Written out with the key beside each row, so the sort below has a tie-break that
        // does not depend on the dictionary's order.
        var keyed: [(key: String, row: Gathered)] = []
        for (key, value) in gathered {
            var row = value
            if row.planned == nil, !unclear.contains(key), let minutes = times[key] { row.planned = minutes }
            keyed.append((key: key, row: row))
        }
        keyed.sort { lhs, rhs in
            if lhs.row.first != rhs.row.first { return lhs.row.first < rhs.row.first }
            return lhs.key < rhs.key
        }
        rows = keyed.map { Row(title: $0.row.title, planned: $0.row.planned, worked: $0.row.worked) }
    }

    /// The name a row is matched by: case and runs of spaces ignored.
    static func key(_ title: String) -> String {
        title.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    private static func tidy(_ title: String) -> String {
        title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private struct Gathered {
        var title: String
        var first: Int
        var planned: Int?
        var worked: Int?

        init(title: String, first: Int) {
            self.title = title
            self.first = first
        }
    }
}

public extension TaskItem {
    /// The task's name on a block in the plan and on the clock's line under **Worked**: the
    /// title without `#next`, which only says why the task was offered (build 174's rule); his
    /// own tags stay, because those carry information. One place, so a block and the work done
    /// on it always carry the same name and **Planned and worked** can put them on one row.
    var planTitle: String {
        Note.removingTag(Note.nextActionTag, from: title).trimmingCharacters(in: .whitespaces)
    }
}
