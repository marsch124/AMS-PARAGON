import Foundation

/// Build 339: ordinary Markdown links in a note's text, `[words](address)`, so they can be
/// opened while the note is being edited — the way `[[links]]` to other notes already can.
///
/// The reason is the line another app leaves in a note it made: AMS Seedboard writes
/// `[Open the board in Seedboard](seedboard://board/…)` into the note a board became, and
/// until now that line could only be pressed in the reading view.
///
/// Pictures (`![words](file)`) are not links, and an address without a scheme (a file path)
/// is not one either: only something another app or the browser can open counts.
public enum MarkdownLinks {
    public struct Match: Equatable, Sendable {
        /// The whole `[words](address)`.
        public let range: NSRange
        /// The `[words]` part, brackets included: what is shown as a link and what a tap means.
        public let label: NSRange
        public let url: URL
    }

    /// `[words](scheme:rest)` — not straight after a `!` (a picture), no line break in the
    /// words, no space or bracket in the address.
    static let regex = try! NSRegularExpression(
        pattern: #"(?<!!)(\[[^\[\]\n]+\])\(([A-Za-z][A-Za-z0-9+.\-]*:[^()\s]+)\)"#)

    /// Addresses that are never opened from a note: a file on the device, and addresses that
    /// carry a script or data instead of leading somewhere.
    static let refused: Set<String> = ["file", "javascript", "data", "blob", "about"]

    /// Addresses the browser and Mail take. Everything else belongs to another app.
    static let web: Set<String> = ["http", "https", "mailto"]

    /// Every Markdown link in the text that may be opened.
    public static func matches(in text: String) -> [Match] {
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            guard let url = URL(string: ns.substring(with: m.range(at: 2))), mayOpen(url) else { return nil }
            return Match(range: m.range, label: m.range(at: 1), url: url)
        }
    }

    /// True for an address a note may open: it has a scheme, and not one of the refused ones.
    public static func mayOpen(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return false }
        return !refused.contains(scheme)
    }

    /// True when the address opens another app (the board link from AMS Seedboard), not the
    /// browser or Mail — and not PARAGON itself.
    public static func opensAnotherApp(_ url: URL) -> Bool {
        guard mayOpen(url), let scheme = url.scheme?.lowercased() else { return false }
        return !web.contains(scheme) && scheme != CaptureItem.urlScheme
    }

    /// The address of the link the offset falls inside (anywhere in `[words](address)`), or
    /// nil. Used for a ⌘-click on the Mac.
    public static func link(at offset: Int, in text: String) -> URL? {
        let length = (text as NSString).length
        guard offset >= 0, offset <= length else { return nil }
        for match in matches(in: text) where NSLocationInRange(offset, match.range) || offset == NSMaxRange(match.range) {
            return match.url
        }
        return nil
    }

    /// The link whose WORDS the offset falls on, when it opens another app, or nil. Used for
    /// a plain tap on iPhone and iPad: a link to the web keeps taking the caret as before.
    public static func appLink(at offset: Int, in text: String) -> Match? {
        let length = (text as NSString).length
        guard offset >= 0, offset <= length else { return nil }
        for match in matches(in: text) where opensAnotherApp(match.url) {
            if NSLocationInRange(offset, match.label) || offset == NSMaxRange(match.label) { return match }
        }
        return nil
    }
}
