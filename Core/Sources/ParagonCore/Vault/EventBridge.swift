import Foundation

// THE CONTRACT between AMS Financial Steward (events) and AMS PARAGON (projects).
// 🚨 The SAME file lives in both apps' Core (StewardCore and ParagonCore). Change it in BOTH, and raise
// `format` when an older app could misread what a newer one writes.
//
// How the two apps talk (his picks of 24 Nov 2026: link, open each other, make each other's item, suggest,
// days in step, done in step, events in the weekly review, "Talk about it" becomes a task):
// · Each app keeps a small LIST in a keychain group both may read: PARAGON its projects, Steward its events.
// · Each app leaves small MESSAGES for the other; the other reads them when it next opens ON THAT DEVICE.
// · Nothing here is a file in iCloud. Across devices each app's own store carries the result
//   (Steward: the event's `project` field; PARAGON: the note's `steward-event` line).
// Only plain Foundation, no type of either app: days are "2026-11-24", money is whole öre in kronor.

public enum EventBridge {
    public static let format = 1
    /// The keychain group both apps carry in `keychain-access-groups` (team prefix, so no registration is needed).
    public static let group = "D24ENP83QQ.com.schabbauer.ams.bridge"

    /// The four places (keychain "service"). A list has ONE item, account `listKey`; a message box has one item
    /// per message, account = the message's id.
    public enum Box: String, Sendable, CaseIterable {
        case projects = "bridge.paragon.projects"
        case events = "bridge.steward.events"
        case toParagon = "bridge.to.paragon"
        case toSteward = "bridge.to.steward"
    }
    public static let listKey = "list"

    // MARK: What PARAGON tells Steward

    /// One PARAGON project. `path` is the note's place in the vault ("Projects/Lisbon Marathon.md") and is its identity.
    public struct Project: Codable, Hashable, Sendable, Identifiable {
        public var path: String
        public var title: String
        /// PARAGON's own words: "active", "on-hold", "done", "missed", "dropped", "archived".
        public var status: String
        /// The project's deadline, "2027-03-12", when it has one.
        public var due: String?
        /// The Steward event this project is linked to (the event's id), when linked.
        public var event: String?
        public var id: String { path }
        public var isLive: Bool { status == "active" || status == "on-hold" }
        public var isDone: Bool { status == "done" }
        public init(path: String, title: String, status: String = "active", due: String? = nil, event: String? = nil) {
            self.path = path; self.title = title; self.status = status; self.due = due; self.event = event
        }
    }
    /// Every live project, plus every linked one whatever its state.
    public struct ProjectList: Codable, Sendable {
        public var format: Int
        public var written: Date
        public var projects: [Project]
        public init(written: Date, projects: [Project]) { format = EventBridge.format; self.written = written; self.projects = projects }
    }

    // MARK: What Steward tells PARAGON

    public struct Event: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var name: String
        /// "race" or "trip".
        public var type: String
        public var from: String
        public var to: String
        public var place: String
        /// The whole plan and what is spent so far, in kronor öre.
        public var planned: Int64
        public var spent: Int64
        /// The day he pressed "Finish event", when he has.
        public var finished: String?
        /// The PARAGON project it is linked to: the note's path (empty while a new project is still being made) and title.
        public var project: String?
        public var projectTitle: String?
        public var isLinked: Bool { project != nil || projectTitle != nil }
        public init(id: String, name: String, type: String, from: String, to: String, place: String = "", planned: Int64 = 0,
                    spent: Int64 = 0, finished: String? = nil, project: String? = nil, projectTitle: String? = nil) {
            self.id = id; self.name = name; self.type = type; self.from = from; self.to = to; self.place = place
            self.planned = planned; self.spent = spent; self.finished = finished; self.project = project; self.projectTitle = projectTitle
        }
    }
    /// Every linked event, plus every event that is not over yet or ended in the last 60 days.
    public struct EventList: Codable, Sendable {
        public var format: Int
        public var written: Date
        public var events: [Event]
        public init(written: Date, events: [Event]) { format = EventBridge.format; self.written = written; self.events = events }
    }

    // MARK: Messages

    /// A small note one app leaves for the other. `kind` is kept as plain text so an older app can skip a kind it does not know.
    public struct Message: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var kind: String
        /// The Steward event it is about.
        public var event: String
        /// The PARAGON note's path, where the kind needs one.
        public var path: String?
        /// A project title (makeProject) or a task's words (addTask).
        public var title: String?
        /// A day: the deadline (makeProject, setDue) or the event's new first day (moveDays).
        public var day: String?
        public var sent: Date
        public init(_ kind: Kind, event: String, path: String? = nil, title: String? = nil, day: String? = nil,
                    id: String = UUID().uuidString.lowercased(), sent: Date = Date()) {
            self.id = id; self.kind = kind.rawValue; self.event = event; self.path = path; self.title = title; self.day = day; self.sent = sent
        }
        public var known: Kind? { Kind(rawValue: kind) }
    }
    public enum Kind: String, Sendable, CaseIterable {
        // To PARAGON:
        /// Make a project called `title` with the deadline `day`, linked to `event`. If a live project with exactly
        /// that title exists and is not linked, link that one instead of making a second.
        case makeProject
        /// Link the project at `path` to `event` (and take the event off any other project).
        case link
        /// Take the link to `event` off whichever project carries it.
        case unlink
        /// Set the deadline of the project linked to `event` to `day` (he said yes in Steward).
        case setDue
        /// Add an open task with the words `title` to the project linked to `event`.
        case addTask
        // To Steward:
        /// Move the event so that it starts on `day`, keeping its length (he said yes in PARAGON).
        case moveDays

        public var box: Box { self == .moveDays ? .toSteward : .toParagon }
    }

    // MARK: Reading and writing (bytes only — the keychain itself is in each app, `BridgeBox`)

    public static func encode<T: Encodable>(_ value: T) -> Data? {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]
        return try? e.encode(value)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(type, from: data)
    }

    // MARK: Rules both apps use

    /// A name as it is compared: small letters, accents off, only letters and digits, single spaces.
    public static func fold(_ s: String) -> String {
        let plain = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_SE")).lowercased()
        let kept = plain.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// Do two names mean the same thing? Equal once folded, or one holds the other as whole words (at least 5 letters),
    /// so "Lisbon Marathon" fits "Lisbon Marathon 2027" but "Run" fits nothing by itself.
    public static func namesFit(_ a: String, _ b: String) -> Bool {
        let x = fold(a), y = fold(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        if x == y { return true }
        let (short, long) = x.count <= y.count ? (x, y) : (y, x)
        guard short.count >= 5 else { return false }
        return (" " + long + " ").contains(" " + short + " ")
    }

    /// The project Steward suggests for an event that has none (pick 5): a live project nobody is linked to, whose name
    /// fits and whose deadline — when it has one — is no more than 14 days before the first day and not after the last.
    /// With several, the one whose deadline is nearest the first day; a project without a deadline comes last.
    public static func suggestion(name: String, from: String, to: String, among projects: [Project], skipping: Set<String> = []) -> Project? {
        let fits = projects.filter { p in
            guard p.isLive, p.event == nil, !skipping.contains(p.path), namesFit(p.title, name) else { return false }
            guard let due = p.due else { return true }
            guard let gap = days(from: due, to: from) else { return false }
            return gap <= 14 && due <= to
        }
        return fits.min { a, b in
            let ga = a.due.flatMap { days(from: $0, to: from) }.map(abs) ?? Int.max
            let gb = b.due.flatMap { days(from: $0, to: from) }.map(abs) ?? Int.max
            return (ga, a.title) < (gb, b.title)
        }
    }

    /// The events of the weekly review's step "Events ahead" (pick 17): not finished, and either running today or
    /// starting within `weeks` weeks. Oldest first.
    public static func ahead(_ events: [Event], today: String, weeks: Int = 8) -> [Event] {
        guard let last = day(today, adding: weeks * 7) else { return [] }
        return events.filter { $0.finished == nil && $0.to >= today && $0.from <= last }
            .sorted { ($0.from, $0.name) < ($1.from, $1.name) }
    }

    /// Steward asks "Finish the event too?" (pick 16): the event is linked, not finished, and its project is done.
    public static func projectIsDone(for event: Event, in projects: [Project]) -> Project? {
        guard event.finished == nil else { return nil }
        return projects.first { $0.event == event.id && $0.isDone }
    }
    /// PARAGON asks "Mark the project done?" (pick 16): the project is live and its event is finished.
    public static func eventIsFinished(for project: Project, in events: [Event]) -> Event? {
        guard project.isLive, let id = project.event else { return nil }
        return events.first { $0.id == id && $0.finished != nil }
    }
    /// The project's deadline and the event's first day differ (pick 15: the deadline is the FIRST day).
    public static func outOfStep(_ event: Event, _ project: Project) -> Bool {
        guard project.event == event.id, let due = project.due else { return false }
        return due != event.from
    }

    /// The words of the task a flagged purchase makes in its project (pick 20). No amount, by his choice.
    public static func talkTask(shop: String, day: String) -> String {
        let s = shop.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Talk about it: " + (s.isEmpty ? "a purchase" : s) + ", " + day
    }

    /// "9 800 kr" — whole kronor with a thin gap between thousands, as Steward writes amounts.
    public static func kronor(_ ore: Int64) -> String {
        let whole = (abs(ore) + 50) / 100
        var digits = String(whole), out = ""
        while digits.count > 3 { out = "\u{00A0}" + String(digits.suffix(3)) + out; digits = String(digits.dropLast(3)) }
        return (ore < 0 && whole != 0 ? "\u{2212}" : "") + digits + out + "\u{00A0}kr"
    }

    // MARK: Days as text

    private static let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private static func date(_ day: String) -> Date? {
        let p = day.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, day.count == 10 else { return nil }
        return utc.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))
    }
    /// "2026-11-24" so many days later (or earlier, with a minus).
    public static func day(_ day: String, adding n: Int) -> String? {
        guard let d = date(day), let moved = utc.date(byAdding: .day, value: n, to: d) else { return nil }
        let c = utc.dateComponents([.year, .month, .day], from: moved)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    /// How many days from one day to another (minus = the other is earlier).
    public static func days(from a: String, to b: String) -> Int? {
        guard let x = date(a), let y = date(b) else { return nil }
        return utc.dateComponents([.day], from: x, to: y).day
    }
}
