import Foundation

/// Build 363: **key points while you speak**. While a thought is being recorded, the Lock
/// Screen card lists up to three key points of what was said so far, and keeps them there
/// through Pause, the write-up and the saved card. His ask after the Flowtica Verso video
/// (23 November 2026): "live summary", and "make sure that the live summary doesn't close".
///
/// The rules live here so they can be tested without a phone: when the on-device model is
/// asked again, how its answer is tidied, and what the saved card shows.
public enum VoiceLiveSummary {
    /// Words said before the first ask. Fewer give the model nothing to sum up.
    public static let firstWords = 30
    /// New words said before the next ask.
    public static let moreWords = 25
    /// Seconds between two asks, so the model does not take the phone away from the
    /// speech-to-text.
    public static let rest: TimeInterval = 20
    /// An ask that has not come back after this many seconds is dropped.
    public static let tooLong: TimeInterval = 45
    /// After this many asks in a row without an answer, this recording asks no more.
    public static let mostFailures = 3
    /// The card has room for three lines.
    public static let mostPoints = 3
    /// One line on the card.
    public static let longestPoint = 70
    /// The model reads about 4,000 tokens: a long recording is summed up from its newest part.
    public static let mostLetters = 6000
    /// The saved card stays on the Lock Screen this long (Apple's longest: four hours).
    public static let cardStays: TimeInterval = 4 * 60 * 60
    /// The summary on the saved card: four lines.
    public static let longestCardSummary = 240

    /// Is it time to ask for key points again?
    /// - `words`: the words said so far.
    /// - `askedAtWords`: the words said when the last ask was made; nil before the first.
    /// - `sinceAsk`: seconds since the last ask; nil before the first.
    /// - `busy`: an ask is still out.
    /// - `failures`: asks in a row without an answer.
    public static func isDue(words: Int, askedAtWords: Int?, sinceAsk: TimeInterval?,
                             busy: Bool, failures: Int = 0) -> Bool {
        guard !busy, failures < mostFailures else { return false }
        guard let askedAtWords, let sinceAsk else { return words >= firstWords }
        return words - askedAtWords >= moreWords && sinceAsk >= rest
    }

    /// How many words a text has.
    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// What the model is given: the cleaned words, and of a long recording the newest part,
    /// starting at a whole word.
    public static func textToSumUp(_ transcript: String) -> String {
        let text = VoiceThought.clean(transcript)
        guard text.count > mostLetters else { return text }
        let tail = String(text.suffix(mostLetters))
        if let space = tail.firstIndex(where: { $0.isWhitespace }) {
            return String(tail[tail.index(after: space)...])
        }
        return tail
    }

    /// The model's answer made fit for the card: no list marks or numbers in front, no empty
    /// or doubled lines, at most three, each at most one line long.
    public static func points(_ raw: [String]) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for line in raw {
            let point = shortened(stripped(line))
            guard !point.isEmpty else { continue }
            guard seen.insert(point.lowercased()).inserted else { continue }
            out.append(point)
            if out.count == mostPoints { break }
        }
        return out
    }

    /// The summary as the saved card shows it: one paragraph, cut at a word when it is long.
    public static func cardSummary(_ summary: String?) -> String {
        shortened(VoiceThought.clean(summary ?? ""), limit: longestCardSummary)
    }

    /// A line without the "- ", "• ", "1. " the model may put in front, and without a full
    /// stop at its end (the card's lines are not sentences).
    static func stripped(_ line: String) -> String {
        var text = VoiceThought.clean(line)
        while let first = text.first, "-–—•*·".contains(first) {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        let digits = text.prefix(while: { $0.isNumber })
        if !digits.isEmpty, digits.count <= 2 {
            let rest = text.dropFirst(digits.count)
            if let mark = rest.first, ".):".contains(mark) {
                text = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
        }
        if text.hasSuffix("."), !text.hasSuffix("..") { text = String(text.dropLast()) }
        return text
    }

    /// Cut at a whole word, with "…" at the end, when longer than `limit`.
    static func shortened(_ text: String, limit: Int = longestPoint) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit - 1))
        if let space = head.lastIndex(where: { $0.isWhitespace }), head.distance(from: head.startIndex, to: space) > limit / 2 {
            return head[..<space].trimmingCharacters(in: .whitespaces) + "…"
        }
        return head + "…"
    }
}
