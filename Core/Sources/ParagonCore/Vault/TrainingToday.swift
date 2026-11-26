import Foundation

// Build 369: the "Training:" line on Today. AMS Triathlon Training (URL scheme `amsworkoutsync://`) is the
// ONLY writer of a small "today" note; PARAGON only reads it and never changes anything there.
// 🚨 The contract is `Triathlon Training/round-28/today-note-contract.md`. Plain Foundation, no type of the app.
//
// The note is JSON, format 1, kept as one keychain item on the device where Triathlon runs
// (service `ams.training.today`, account `v1`, group `D24ENP83QQ.com.schabbauer.AMSWorkoutSync`).
// Unknown and missing fields are ignored. A newer format (`v` above 1) shows nothing.

public enum TrainingToday {
    public static let service = "ams.training.today"
    public static let account = "v1"
    public static let group = "D24ENP83QQ.com.schabbauer.AMSWorkoutSync"
    public static let knownFormat = 1
    public static let todayLink = "amsworkoutsync://today"
    /// The only scheme PARAGON ever opens from the note.
    public static let scheme = "amsworkoutsync://"
    /// A note written longer ago than this is never shown, even on today's date.
    public static let staleAfter: TimeInterval = 36 * 3600

    public struct Session: Equatable, Sendable {
        public var key: String
        public var sport: String
        public var sportWord: String
        public var title: String
        public var minutes: Int?
        public var length: String
        /// "todo", "done", "missed" or "rest". Anything else counts as to do.
        public var state: String
        public var canDone: Bool
        public var open: String?
        public var done: String?

        public var isRest: Bool { state == "rest" || sport.lowercased() == "rest" }
        public var isDone: Bool { !isRest && state == "done" }
        public var isMissed: Bool { !isRest && state == "missed" }
        public var isToDo: Bool { !isRest && !isDone && !isMissed }
    }

    public struct Note: Equatable, Sendable {
        public var v: Int
        public var day: String
        public var written: String
        public var sessions: [Session]

        /// Reads the bytes as far as they make sense; nil when they are not a JSON object.
        public init?(data: Data) {
            guard let top = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
            v = Self.int(top["v"]) ?? 0
            day = top["day"] as? String ?? ""
            written = top["written"] as? String ?? ""
            let rows = top["sessions"] as? [[String: Any]] ?? []
            sessions = rows.map { row in
                Session(key: row["key"] as? String ?? "",
                        sport: row["sport"] as? String ?? "",
                        sportWord: row["sportWord"] as? String ?? "",
                        title: row["title"] as? String ?? "",
                        minutes: Self.int(row["minutes"]),
                        length: row["length"] as? String ?? "",
                        state: row["state"] as? String ?? "todo",
                        canDone: row["canDone"] as? Bool ?? false,
                        open: row["open"] as? String,
                        done: row["done"] as? String)
            }
        }

        private static func int(_ value: Any?) -> Int? {
            if let n = value as? Int { return n }
            if let d = value as? Double { return Int(d) }
            return nil
        }

        /// When Triathlon wrote the note; nil when the field is missing or unreadable.
        var writtenDate: Date? {
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: written) { return date }
            let fractions = ISO8601DateFormatter()
            fractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractions.date(from: written)
        }
    }

    /// What Today shows after the label "Training: ", and where a press goes.
    public struct Line: Equatable, Sendable {
        public var words: String
        public var link: String
    }

    /// The line for today, or nil when nothing is to be shown (no note, a note that is not readable, a newer
    /// format, another day, an old note, no sessions). `today` is the reader's own local day, "2026-12-01".
    public static func line(from data: Data?, today: String, now: Date) -> Line? {
        guard let data, let note = Note(data: data), note.v <= knownFormat, note.day == today,
              let written = note.writtenDate, now.timeIntervalSince(written) <= staleAfter,
              !note.sessions.isEmpty else { return nil }
        let sessions = note.sessions
        if sessions.allSatisfy({ $0.isRest }) { return Line(words: "rest day", link: todayLink) }
        if sessions.allSatisfy({ $0.isDone }) { return Line(words: "done", link: todayLink) }
        let parts: [String] = sessions.compactMap { s in
            if s.isRest { return nil }
            let word = word(for: s)
            if s.isDone { return word + " done" }
            if s.isMissed { return word + " missed" }
            return s.length.isEmpty ? word : word + " " + s.length
        }
        var link = todayLink
        let toDo = sessions.filter { $0.isToDo }
        if toDo.count == 1, let open = toDo[0].open, open.lowercased().hasPrefix(scheme) { link = open }
        return Line(words: parts.joined(separator: ", "), link: link)
    }

    /// For VoiceOver: the label in front of the words, as the view draws it.
    public static func spoken(_ line: Line) -> String { "Training: " + line.words }

    private static func word(for s: Session) -> String {
        if !s.sportWord.isEmpty { return s.sportWord }
        let sport = s.sport.isEmpty ? "session" : s.sport
        return sport.prefix(1).uppercased() + sport.dropFirst()
    }
}
