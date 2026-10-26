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
