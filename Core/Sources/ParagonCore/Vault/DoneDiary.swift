import Foundation

// Build 267: **Done tells each day's story** (idea 7 on the plan page,
// https://claude.ai/artifact/RyZxairjYDdB7KoxiuGZ3S). The Done screen was a list of ticked tasks
// under a date. Everything else about the day was already in his notes and drawn nowhere beside
// it: the time on the focus timer, the line he wrote in **Close the day**, and what the work went
// towards. His answers: the row keeps the name **Done**, and a day with no tick but a line or
// some time on the timer is listed too ("a diary that leaves out the days you wrote about is not
// a diary").
//
// **Built on `DayRecord`, never a second record of a day** (build 263): step 7 of the Weekly
// review takes seven of them, this takes twelve weeks of them, and both come from the same pass.

/// One day in the Done diary: the day's record and what its finished tasks went towards.
public struct DiaryDay: Identifiable, Equatable, Sendable {
    public var record: DayRecord
    /// What the finished tasks went towards, most first — `servedCounts(of:)`, with the day's
    /// own daily note named "Daily note" (`DoneDiary.labels(_:ownNoteTitle:)`).
    public var served: [ServedCount]

    public init(record: DayRecord, served: [ServedCount]) {
        self.record = record
        self.served = served
    }

    public var id: DateOnly { record.day }
    public var day: DateOnly { record.day }
    public var finished: [TaskRef] { record.finished }
    /// Nil when the focus timer wrote nothing that day, never 0.
    public var workedMinutes: Int? { record.workedMinutes }

    /// The line written under **How was today?**, whole, or nil when there is none.
    public var eveningLine: String? {
        let text = record.lookingBack.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Something to show: a finished task, an evening line, or time on the focus timer. A day
    /// with only a plan or an empty note is not part of the diary.
    public var hasSomething: Bool {
        !record.finished.isEmpty || eveningLine != nil || record.workedMinutes != nil
    }

    /// The grey line under the day's name: "6 done · 2 h 40 min worked", "1 done", "Nothing
    /// ticked off · 45 min worked". **Never "0 min worked" and never "0 done"**: a day listed for
    /// its evening line says in words that nothing was ticked, and a day the timer was not used
    /// says nothing about the timer at all (build 141).
    public var factsText: String {
        let done = record.finished.isEmpty ? "Nothing ticked off" : "\(record.finished.count) done"
        guard let minutes = record.workedMinutes, minutes > 0 else { return done }
        return done + " \u{00B7} " + TaskTime.total(minutes) + " worked"
    }

    /// The whole card as one sentence for VoiceOver. The day's name is handed in, because how a
    /// day is named on screen ("Today", "Tuesday 14 October") is the view's to decide.
    public func spoken(dayName: String) -> String {
        var parts = [dayName + ". " + factsText.replacingOccurrences(of: " \u{00B7} ", with: ", ") + "."]
        if !served.isEmpty {
            let list = served.map { "\($0.title) \($0.count)" }.joined(separator: ", ")
            parts.append("What it served: \(list).")
        }
        if let eveningLine {
            parts.append("In the evening you wrote: \(eveningLine)")
        }
        return parts.joined(separator: " ")
    }
}

/// The Done screen: the last twelve calendar weeks, newest day first, each day that has
/// something to tell.
public struct DoneDiary: Equatable, Sendable {
    /// How far back the diary goes. Calendar weeks, Monday to Sunday — the same weeks as the
    /// weekly notes and the Projects list's bars (build 255) — so "12 weeks" never means a
    /// rolling 84 days that starts on a Thursday.
    public static let weeks = 12
    /// The words on the label for the day's own daily note.
    public static let ownNoteLabel = "Daily note"

    /// The day the diary was worked out for. A screen keeps it to see when the date has moved
    /// (build 254's rule for anything cached from `.today()`).
    public var today: DateOnly
    /// Newest first; only the days with something to show (`DiaryDay.hasSomething`).
    public var days: [DiaryDay]
    /// The earliest day any task in the whole vault was ticked off, whenever that was. Nil when
    /// no finished task carries a day at all: then the counts are not a zero, they are "the
    /// file cannot say" (build 141).
    public var firstFinished: DateOnly?
    /// Tasks ticked off this calendar week, today included.
    public var finishedThisWeek: Int
    /// Tasks ticked off in the twelve weeks.
    public var finishedTotal: Int

    public init(today: DateOnly, days: [DiaryDay], firstFinished: DateOnly?,
                finishedThisWeek: Int, finishedTotal: Int) {
        self.today = today
        self.days = days
        self.firstFinished = firstFinished
        self.finishedThisWeek = finishedThisWeek
        self.finishedTotal = finishedTotal
    }

    public func day(_ day: DateOnly) -> DiaryDay? {
        days.first { $0.day == day }
    }

    /// The first day the diary covers: Monday of the week eleven weeks before this one, so this
    /// week and the eleven before it make the twelve.
    public static func firstDay(today: DateOnly) -> DateOnly {
        WeekRef(containing: today).adding(weeks: -(weeks - 1)).monday
    }

    /// The count line's first half: "6 done this week", or "Nothing done this week yet". Nil
    /// when no finished task in the vault carries a day: a count then would be a zero that only
    /// says the file cannot tell.
    public var weekText: String? {
        guard firstFinished != nil else { return nil }
        return finishedThisWeek == 0 ? "Nothing done this week yet" : "\(finishedThisWeek) done this week"
    }

    /// The count line's second half: "212 in 12 weeks", or "none in 12 weeks". Nil, like
    /// `weekText`, when no finished task carries a day.
    public var totalText: String? {
        guard firstFinished != nil else { return nil }
        return finishedTotal == 0 ? "none in \(Self.weeks) weeks" : "\(finishedTotal) in \(Self.weeks) weeks"
    }

    /// The line at the top of the screen: "6 done this week \u{00B7} 212 in 12 weeks". Nil when
    /// no finished task in the vault carries a day; the screen then draws no count at all.
    public var countText: String? {
        guard let week = weekText, let total = totalText else { return nil }
        return week + " \u{00B7} " + total
    }

    /// The labels under a day: what its tasks went towards, with **the day's own daily note
    /// called "Daily note"** rather than by its long date. The day's name is the line above, and
    /// a label repeating it carries nothing (build 169). Only that one note: `ownNoteTitle` is
    /// its title, `Note.dailyTitle(for:)` of the day. A weekly note is a daily note too, by its
    /// folder, and keeps its own name ("Week 43, 19 Oct – 25 Oct 2026"), as does another day's note whose task was
    /// ticked this day — "Daily notes" would not be true of them (review of 268). Most first,
    /// then by name, as `servedCounts(of:)` orders them.
    public static func labels(_ counts: [ServedCount], ownNoteTitle: String) -> [ServedCount] {
        let own = counts.filter { isOwnNote($0, ownNoteTitle) }
        guard !own.isEmpty else { return counts }
        var merged = counts.filter { !isOwnNote($0, ownNoteTitle) }
        merged.append(ServedCount(title: ownNoteLabel, kind: .note(.daily),
                                  count: own.reduce(0) { $0 + $1.count }))
        return merged.sorted { $0.count != $1.count ? $0.count > $1.count
                                                    : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func isOwnNote(_ count: ServedCount, _ ownNoteTitle: String) -> Bool {
        count.kind == .note(.daily) && count.title == ownNoteTitle
    }
}

public extension NoteIndex {
    /// The Done diary for the twelve calendar weeks up to `today`, in **one pass** over the
    /// notes. Before build 267 the Done screen asked `tasksCompleted(on:)` thirty times, and each
    /// time every note's tasks were parsed again — on every redraw.
    ///
    /// A day counts what `tasksCompleted(on:)` counts (one rule, `TaskItem.doneDay`), so the
    /// diary and the number beside **Done** in the sidebar cannot disagree. A stamp later than
    /// today is left out everywhere.
    func doneDiary(today: DateOnly) -> DoneDiary {
        let first = DoneDiary.firstDay(today: today)
        let pass = dayRecordsInOnePass(from: first, through: today, earliestUpTo: today)
        let thisWeek = WeekRef(containing: today)
        var days: [DiaryDay] = []
        var total = 0
        var inThisWeek = 0
        for record in pass.records.reversed() {
            total += record.finished.count
            if thisWeek.contains(record.day) { inThisWeek += record.finished.count }
            let bare = DiaryDay(record: record, served: [])
            guard bare.hasSomething else { continue }
            let served = DoneDiary.labels(servedCounts(of: record.finished),
                                          ownNoteTitle: Note.dailyTitle(for: record.day))
            days.append(DiaryDay(record: record, served: served))
        }
        return DoneDiary(today: today, days: days, firstFinished: pass.earliest,
                         finishedThisWeek: inThisWeek, finishedTotal: total)
    }
}

// Build 268: **squares for the last 12 weeks** at the top of Done (idea 7, the plan page). One
// square per day, one column per calendar week, Monday at the top and this week on the right; a
// square in a stronger colour is a day with more done, and pressing one goes to that day's card
// in the list.
// Everything the grid shows is decided here, where it can be tested: which days have a square
// at all, how dark each one is, which can be pressed, and where the month names go.

/// One day's square in the grid at the top of Done.
public struct DoneSquare: Identifiable, Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Later this week: the day has not come yet. No square is drawn.
        case notYet
        /// Before the first task in the vault was ticked off with a day. No square is drawn:
        /// a grey one would say "nothing done", when the truth is "the file cannot say"
        /// (build 141).
        case beforeRecord
        /// A day the file can speak for, with the tasks ticked off that day. A 0 is a grey square,
        /// except that the app draws it empty while that day's note is still coming from iCloud.
        case counted(Int)
    }

    public var day: DateOnly
    public var state: State
    /// How dark the square is: 0 for a day with nothing done (and for a day with no square),
    /// 1 to 4 by its share of the busiest day in the twelve weeks.
    public var level: Int
    public var isToday: Bool
    /// The square is drawn and its day has a card in the list below, so a press can go to it.
    /// A day with nothing to show has no card, and a press that goes nowhere is worse than no
    /// button at all (build 175).
    public var canJump: Bool

    public init(day: DateOnly, state: State, level: Int, isToday: Bool, canJump: Bool) {
        self.day = day
        self.state = state
        self.level = level
        self.isToday = isToday
        self.canJump = canJump
    }

    public var id: DateOnly { day }

    /// The number of tasks ticked off that day, or nil when no square is drawn.
    public var count: Int? {
        guard case .counted(let count) = state else { return nil }
        return count
    }

    /// Whether a square is drawn for the day at all.
    public var isDrawn: Bool { count != nil }

    /// What a square says aloud and on the Mac's tooltip: "Tuesday 14 October, 6 done",
    /// "Yesterday, nothing ticked off". The day's name is handed in, so a square and its card
    /// name a day the same way.
    public func spoken(dayName: String) -> String {
        guard let count else { return dayName }
        return dayName + ", " + (count == 0 ? "nothing ticked off" : "\(count) done")
    }
}

/// Where a month's name sits above the squares: over the first column of that month.
public struct MonthMark: Identifiable, Equatable, Sendable {
    /// The column, 0 for the oldest week.
    public var column: Int
    /// The first day of the month. The app writes the month's name from it.
    public var firstDay: DateOnly

    public init(column: Int, firstDay: DateOnly) {
        self.column = column
        self.firstDay = firstDay
    }

    public var id: Int { column }
}

public extension DoneDiary {
    /// How many columns a month's name needs before the next one, so two names never print
    /// over each other.
    static let monthMarkRoom = 3

    /// Whether the squares are drawn at all. Not while no finished task in the vault carries a
    /// day: 84 empty squares would say "nothing done for twelve weeks", when the truth is that
    /// the file cannot say (builds 141, 255).
    var showsSquares: Bool { firstFinished != nil }

    /// How dark a square is: 0 for nothing done, else 1 to 4 by the day's share of the busiest
    /// day — never 0 for a day with something done, or it would look like a day with nothing.
    static func level(_ count: Int, biggest: Int) -> Int {
        guard count > 0 else { return 0 }
        guard biggest > count else { return 4 }
        let share = (4 * count + biggest - 1) / biggest
        return min(4, max(1, share))
    }

    /// The squares, twelve columns of seven: the oldest week first, each from Monday to Sunday,
    /// so this week is the column on the right.
    var squareWeeks: [[DoneSquare]] {
        var counts: [DateOnly: Int] = [:]
        for day in days { counts[day.day] = day.finished.count }
        let biggest = counts.values.max() ?? 0
        let first = Self.firstDay(today: today)
        return (0..<Self.weeks).map { column -> [DoneSquare] in
            (0..<7).map { row -> DoneSquare in
                let day = first.adding(days: column * 7 + row, calendar: WeekRef.calendar)
                return square(for: day, count: counts[day] ?? 0, hasCard: counts[day] != nil, biggest: biggest)
            }
        }
    }

    private func square(for day: DateOnly, count: Int, hasCard: Bool, biggest: Int) -> DoneSquare {
        let state: DoneSquare.State
        if day > today {
            state = .notYet
        } else if let firstFinished, day >= firstFinished {
            state = .counted(count)
        } else {
            state = .beforeRecord
        }
        let drawn: Bool
        if case .counted = state { drawn = true } else { drawn = false }
        return DoneSquare(day: day, state: state,
                          level: drawn ? Self.level(count, biggest: biggest) : 0,
                          isToday: day == today,
                          canJump: drawn && hasCard)
    }

    /// The month names above the columns. A column belongs to the month that holds most of its
    /// days — the month of its Thursday, the rule that gives a week its year — and a name is
    /// written where that month changes. The oldest column's name is left out when the next
    /// month starts fewer than `monthMarkRoom` columns after it: that month only shows at the
    /// left edge, and the two names would print over each other. A month holds four or five
    /// Thursdays, so only the first name can ever be that close.
    var monthMarks: [MonthMark] {
        let first = Self.firstDay(today: today)
        var changes: [MonthMark] = []
        for column in 0..<Self.weeks {
            let thursday = first.adding(days: column * 7 + 3, calendar: WeekRef.calendar)
            let month = DateOnly(year: thursday.year, month: thursday.month, day: 1)
            if changes.last?.firstDay != month {
                changes.append(MonthMark(column: column, firstDay: month))
            }
        }
        var marks: [MonthMark] = []
        for index in changes.indices {
            let isLast = index == changes.count - 1
            if isLast || changes[index + 1].column - changes[index].column >= Self.monthMarkRoom {
                marks.append(changes[index])
            }
        }
        return marks
    }
}
