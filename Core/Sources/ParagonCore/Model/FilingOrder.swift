import Foundation

/// Build 331: which places a line from the Inbox is offered FIRST when it is filed.
///
/// Until now **File it** opened one flat list of every project and every area — fine with
/// five places, a long scroll with fifty. The advisors' round (16 Nov 2026) asked for the
/// likely places on top. Two short groups come before the whole list:
///
/// - **Suggested** — places whose name shares a telling word with the line
///   ("Book the ferry for the Kungsleden trip" → "Plan the Kungsleden trip"). At most two,
///   the one with the most shared words first.
/// - **Recent** — the places he last filed a line to, newest first. At most three, and never
///   one that is already under Suggested.
///
/// The whole list still follows underneath, in its usual order, so nothing is ever hidden.
/// With a short list (six places or fewer) there are no groups at all: the list is its own
/// shortcut, and a place shown twice in a list of four is only noise.
public enum FilingOrder {
    public struct Place: Equatable, Sendable {
        public let path: String
        public let title: String
        public init(path: String, title: String) {
            self.path = path
            self.title = title
        }
    }

    public struct Offer: Equatable, Sendable {
        public let suggested: [Place]
        public let recent: [Place]
        public var isEmpty: Bool { suggested.isEmpty && recent.isEmpty }
        public init(suggested: [Place] = [], recent: [Place] = []) {
            self.suggested = suggested
            self.recent = recent
        }

        /// Build 332: the same filter rule as `FilingOrder.matching`, applied to both groups.
        /// An empty search gives the offer back unchanged.
        public func matching(_ query: String) -> Offer {
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return self }
            return Offer(suggested: FilingOrder.matching(suggested, query),
                         recent: FilingOrder.matching(recent, query))
        }
    }

    public static let suggestedLimit = 2
    public static let recentLimit = 3
    /// How many filed-to places a device remembers. More than `recentLimit`, so the group
    /// stays full when one of them is archived or already shown as a suggestion.
    public static let rememberedLimit = 8
    /// A list this short gets no groups.
    public static let shortList = 6
    /// Build 332: a list with at least this many places gets a search field.
    public static let searchFrom = 12

    /// Build 332: the places whose name holds EVERY word typed in the search field.
    /// Capitals and accents do not count ("norrkop" finds "Norrköping"). An empty search
    /// gives the places back unchanged. Places where a word of the name BEGINS with the
    /// first typed word come first, then the other matches; inside each group the order of
    /// `places` is kept.
    public static func matching(_ places: [Place], _ query: String) -> [Place] {
        let typed = plain(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = typed.first else { return places }
        var starts: [Place] = []
        var others: [Place] = []
        for place in places {
            let title = plain(place.title)
            guard typed.allSatisfy({ title.contains($0) }) else { continue }
            let begins = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .contains { $0.hasPrefix(first) }
            if begins { starts.append(place) } else { others.append(place) }
        }
        return starts + others
    }

    private static func plain(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// - Parameters:
    ///   - places: every place a line can go, in the order the whole list shows them.
    ///   - recentPaths: the paths last filed to, newest first.
    ///   - shortList: the tests of the screens pass 0, their notes have two places only.
    public static func offer(for taskTitle: String, places: [Place], recentPaths: [String],
                             shortList: Int = FilingOrder.shortList) -> Offer {
        guard places.count > shortList else { return Offer() }

        let taskWords = words(taskTitle)
        var scored: [(place: Place, score: Int, order: Int)] = []
        for (order, place) in places.enumerated() {
            let score = taskWords.intersection(words(place.title)).count
            if score > 0 { scored.append((place, score, order)) }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
        let suggested = scored.prefix(suggestedLimit).map(\.place)

        let taken = Set(suggested.map(\.path))
        var seen = Set<String>()
        var recent: [Place] = []
        for path in recentPaths where recent.count < recentLimit {
            guard !taken.contains(path), seen.insert(path).inserted,
                  let place = places.first(where: { $0.path == path }) else { continue }
            recent.append(place)
        }
        return Offer(suggested: suggested, recent: recent)
    }

    /// The remembered list after a line was filed to `path`: that place first, once, and no
    /// more than `rememberedLimit` in all.
    public static func remembering(_ path: String, in recentPaths: [String]) -> [String] {
        Array(([path] + recentPaths.filter { $0 != path }).prefix(rememberedLimit))
    }

    /// The telling words of a name: three letters or more, small letters, a plural "s" taken
    /// off, and without the little words every line has ("the", "and", "for" …) or the app's
    /// own marks ("next", "someday", "waiting").
    static func words(_ text: String) -> Set<String> {
        var found = Set<String>()
        for piece in text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted) {
            guard piece.count >= 3, !fillers.contains(piece) else { continue }
            let word = piece.count > 3 && piece.hasSuffix("s") ? String(piece.dropLast()) : piece
            guard !fillers.contains(word) else { continue }
            found.insert(word)
        }
        return found
    }

    private static let fillers: Set<String> = [
        "the", "and", "for", "with", "from", "about", "this", "that", "into", "onto", "over",
        "under", "after", "before", "until", "not", "new", "all", "any", "our", "your", "his",
        "her", "its", "are", "was", "has", "have", "will", "can", "get", "out", "off", "per",
        "next", "someday", "waiting", "due", "deadline",
        // Swedish and German, his other two languages.
        "och", "att", "det", "som", "för", "med", "till", "den", "ett", "från", "inte",
        "und", "der", "die", "das", "mit", "von", "für", "ein", "eine", "nicht",
    ]
}
