import SwiftUI
import ParagonCore

#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#endif

/// The note editor: an ordinary text view that draws markdown as you type. Headings grow,
/// tasks get a coloured box, finished ones are struck through, and the syntax characters
/// fade into the background. The text itself is never changed, only how it looks.
struct MarkdownSyntaxEditor: View {
    @Binding var text: String
    var tint: Color = .accentColor
    /// Where a half-typed `[[link]]` is, and where on screen it is being typed, so the note
    /// screen can put the list of titles under the cursor. Nil when nothing is being typed.
    @Binding var linkDraft: LinkDraftOnScreen?
    /// Set by the note screen to put a chosen title in and move the cursor past it.
    @Binding var completion: LinkCompletion?
    /// A ⌘-click (a tap on the phone) on a finished `[[link]]`.
    var openLink: (String) -> Void = { _ in }
    /// The keys the list of titles wants while it is up. True means it was used.
    var onLinkKey: (LinkKey) -> Bool = { _ in false }
    /// Whether the text scrolls inside itself. False makes it ask for its full height and
    /// leaves the scrolling to whatever it is placed in — what the phone wants, so a tap is
    /// a tap rather than an argument between two scroll views. macOS ignores it: there the
    /// text view lives in its own NSScrollView, which builds 30/34 require.
    var scrolls: Bool = true
    /// Build 288/289: pictures in the text, and the pencil and photo buttons above the
    /// keyboard. Nil leaves them out (the template editor).
    var pictures: PictureHooks? = nil

    init(text: Binding<String>,
         tint: Color = .accentColor,
         linkDraft: Binding<LinkDraftOnScreen?> = .constant(nil),
         completion: Binding<LinkCompletion?> = .constant(nil),
         openLink: @escaping (String) -> Void = { _ in },
         onLinkKey: @escaping (LinkKey) -> Bool = { _ in false },
         scrolls: Bool = true,
         pictures: PictureHooks? = nil) {
        self.pictures = pictures
        _text = text
        self.tint = tint
        _linkDraft = linkDraft
        _completion = completion
        self.openLink = openLink
        self.onLinkKey = onLinkKey
        self.scrolls = scrolls
    }

    var body: some View {
        MarkdownTextViewRepresentable(text: $text, tint: tint, linkDraft: $linkDraft,
                                      completion: $completion, openLink: openLink,
                                      onLinkKey: onLinkKey, scrolls: scrolls, pictures: pictures)
    }
}

/// The keys the list of titles answers to.
enum LinkKey { case up, down, enter, escape }

/// A `[[` being typed, and the caret's place in the editor's own coordinates.
struct LinkDraftOnScreen: Equatable {
    let draft: WikiLinks.Draft
    /// The caret, from the top left of the editor.
    let caret: CGPoint
    /// How tall the line is, so the list can sit just below it.
    let lineHeight: CGFloat
}

/// A title the note screen wants written into the text.
struct LinkCompletion: Equatable {
    let draft: WikiLinks.Draft
    let title: String
}

/// The long-press (right-click) menu on a task's box (build 287).
enum BoxAction { case cancel, tomorrow }

/// Bold, italic and heading: the buttons above the keyboard and the Mac's Format menu.
enum FormatAction { case bold, italic, strike, heading }

/// Build 289: what the editor needs to show pictures in the text and to make new ones.
struct PictureHooks {
    /// The note, from the vault's root, so `../Sketches/…` can be found.
    var notePath: String
    var root: URL
    /// Raised when a picture file changed (a sketch drawn on again), so it is loaded afresh.
    var version: Int
    /// The pencil: a new sketch where the cursor is (an offset in the note's markdown).
    var sketch: (Int) -> Void
    /// The photo button: a photo where the cursor is; true for the camera, false for the library.
    var photo: (Int, Bool) -> Void
    /// A press on a picture in the text: its file, from the vault's root.
    var open: (String) -> Void
}

/// A picture shown in the text in place of its `![…](…)` line. The line itself rides along,
/// so the text handed back is the same markdown that was read.
final class PictureAttachment: NSTextAttachment {
    var link = ""
    var path = ""
}

/// Build 289: the markdown ⇄ what the editor shows. The editor holds one U+FFFC per picture
/// with a `PictureAttachment`; everything else is the markdown, character for character.
@MainActor
enum PictureText {
    nonisolated static let mark = "\u{FFFC}"
    nonisolated static let markChar: unichar = 0xFFFC
    static let maxHeight: CGFloat = 320

    /// The text to show, and where each picture goes in it.
    static func display(_ markdown: String, hooks: PictureHooks?, width: CGFloat,
                        cache: inout [String: PlatformImage]) -> (text: String, pictures: [(Int, PictureAttachment)]) {
        guard let hooks else { return (markdown, []) }
        let matches = Pictures.matches(in: markdown, notePath: hooks.notePath)
        guard !matches.isEmpty else { return (markdown, []) }
        let ns = markdown as NSString
        var out = ""
        var placed: [(Int, PictureAttachment)] = []
        var last = 0
        for match in matches {
            out += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let attachment = PictureAttachment()
            attachment.link = ns.substring(with: match.range)
            attachment.path = match.path
            var image = cache[match.path]
            if image == nil {
                let loaded = picture(at: match.path, root: hooks.root, width: width)
                image = loaded.image
                if loaded.real { cache[match.path] = loaded.image }
            }
            if let image {
                attachment.image = image
                attachment.bounds = CGRect(origin: .zero, size: image.size)
            }
            placed.append(((out as NSString).length, attachment))
            out += mark
            last = NSMaxRange(match.range)
        }
        out += ns.substring(from: last)
        return (out, placed)
    }

    /// The markdown for what the editor holds: each picture back to its line. A U+FFFC
    /// without its picture (pasted from elsewhere) is dropped.
    nonisolated static func markdown(from storage: NSAttributedString) -> String {
        markdown(from: storage, upTo: storage.length)
    }

    nonisolated static func markdown(from storage: NSAttributedString, upTo end: Int) -> String {
        let ns = storage.string as NSString
        let stop = min(max(end, 0), ns.length)
        guard ns.range(of: mark).location != NSNotFound else { return ns.substring(to: stop) }
        var out = ""
        var last = 0
        var index = ns.range(of: mark, options: [], range: NSRange(location: 0, length: stop)).location
        while index != NSNotFound {
            out += ns.substring(with: NSRange(location: last, length: index - last))
            if let a = storage.attribute(.attachment, at: index, effectiveRange: nil) as? PictureAttachment { out += a.link }
            last = index + 1
            let next = ns.range(of: mark, options: [], range: NSRange(location: last, length: stop - last))
            index = next.location
        }
        return out + ns.substring(with: NSRange(location: last, length: stop - last))
    }

    /// The pictures in a text storage, to put back after restyling.
    nonisolated static func pictures(in storage: NSAttributedString) -> [(Int, PictureAttachment)] {
        var found: [(Int, PictureAttachment)] = []
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if let a = value as? PictureAttachment { found.append((range.location, a)) }
        }
        return found
    }

    /// After the whole string was set (a chosen [[title]] written in), the pictures go back on
    /// the U+FFFC marks in the order they were in: the completion never adds or removes one.
    nonisolated static func reattachInOrder(_ old: [(Int, PictureAttachment)], to storage: NSTextStorage) {
        let ns = storage.string as NSString
        var index = 0
        for i in 0..<ns.length where ns.character(at: i) == markChar {
            guard index < old.count else { break }
            storage.addAttribute(.attachment, value: old[index].1, range: NSRange(location: i, length: 1))
            index += 1
        }
    }

    nonisolated static func attach(_ pictures: [(Int, PictureAttachment)], to storage: NSTextStorage) {
        for (at, a) in pictures where at < storage.length && (storage.string as NSString).character(at: at) == markChar {
            storage.addAttribute(.attachment, value: a, range: NSRange(location: at, length: 1))
        }
    }

    /// The picture's file, made to fit the text and rounded; a grey box with words while iCloud
    /// has not sent it.
    static func picture(at path: String, root: URL, width: CGFloat) -> (image: PlatformImage, real: Bool) {
        let url = root.appendingPathComponent(path)
        if CloudFiles.isMissing(url) { CloudFiles.startDownload(url) }
        let maxWidth = max(min(width, 600), 120)
        guard let data = try? Data(contentsOf: url), let source = PlatformImage(data: data),
              source.size.width > 0, source.size.height > 0 else {
            return (placeholder(width: min(maxWidth, 260)), false)
        }
        let scale = min(maxWidth / source.size.width, maxHeight / source.size.height, 1)
        let size = CGSize(width: (source.size.width * scale).rounded(), height: (source.size.height * scale).rounded())
        return (rounded(source, size: size), true)
    }

    private static let placeholderSize = CGSize(width: 260, height: 44)

    #if os(iOS)
    static func rounded(_ source: UIImage, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8).addClip()
            source.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    static func placeholder(width: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: placeholderSize.height)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.systemGray5.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8).fill()
            ("On its way from iCloud" as NSString).draw(at: CGPoint(x: 12, y: 13), withAttributes: [
                .font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.secondaryLabel])
        }
        return image
    }
    #else
    static func rounded(_ source: NSImage, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).addClip()
            source.draw(in: rect)
            return true
        }
    }
    static func placeholder(width: CGFloat) -> NSImage {
        let size = CGSize(width: width, height: placeholderSize.height)
        let image = NSImage(size: size, flipped: true) { rect in
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            ("On its way from iCloud" as NSString).draw(at: CGPoint(x: 12, y: 13), withAttributes: [
                .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondaryLabelColor])
            return true
        }
        return image
    }
    #endif
}

/// Turns the spans from the Core highlighter into text attributes.
enum MarkdownAttributes {
    // 1.0: the editor reads like a good book — the one scale in `Txt.Editor`: text 15, the
    // headings stepped 22 / 18 / 15 semibold, code 14 in Apple's monospaced font, and
    // comfortable line spacing. Edit and Read draw with the same numbers.
    static var baseSize: CGFloat { Txt.Editor.text }
    static var lineSpacing: CGFloat { Txt.Editor.lineSpacing }

    static var baseFont: PlatformFont { .systemFont(ofSize: baseSize) }
    static var monospaceFont: PlatformFont { .monospacedSystemFont(ofSize: Txt.Editor.code, weight: .regular) }

    static func headingFont(level: Int) -> PlatformFont {
        let sizes: [CGFloat] = [Txt.Editor.h1, Txt.Editor.h2, Txt.Editor.h3, baseSize, baseSize, baseSize]
        let size = sizes[min(max(level, 1), 6) - 1]
        return .systemFont(ofSize: size, weight: .semibold)
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = Txt.Editor.paragraphSpacing
        return style
    }

    /// The attributes every character starts with.
    static func base(color: PlatformColor) -> [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: color, .paragraphStyle: paragraphStyle]
    }

    /// Applies the highlighting for `text` to a text storage that already holds it.
    static func apply(to storage: NSTextStorage, text: String, tint: PlatformColor,
                      primary: PlatformColor, secondary: PlatformColor, faint: PlatformColor,
                      hideMarkers: Bool = false, cursor: Int? = nil) {
        let whole = NSRange(location: 0, length: (text as NSString).length)
        let pictures = PictureText.pictures(in: storage)
        storage.beginEditing()
        storage.setAttributes(base(color: primary), range: whole)
        PictureText.attach(pictures, to: storage)
        // Very long notes are left plain: highlighting every keystroke would drag.
        if whole.length <= 200_000 {
            for span in MarkdownHighlight.spans(in: text) {
                guard span.range.location >= 0, NSMaxRange(span.range) <= whole.length, span.range.length > 0 else { continue }
                storage.addAttributes(attributes(for: span.style, tint: tint, secondary: secondary, faint: faint), range: span.range)
            }
            // Build 286: the box is something to press, so it is drawn in the note's colour.
            for box in TaskBox.boxRanges(in: text) where NSMaxRange(box) <= whole.length {
                storage.addAttributes([.foregroundColor: tint,
                                       .font: PlatformFont.systemFont(ofSize: baseSize, weight: .bold)],
                                      range: box)
            }
            // Build 287, rich text: the `**`, `*` and `# ` step out of sight on every line but
            // the cursor's, so the note reads as formatted text. The file is never changed.
            if hideMarkers {
                let hidden: [NSAttributedString.Key: Any] = [.foregroundColor: PlatformColor.clear,
                                                             .font: PlatformFont.systemFont(ofSize: 0.1)]
                for range in MarkdownHighlight.hiddenMarkers(in: text, cursor: cursor) where NSMaxRange(range) <= whole.length {
                    storage.addAttributes(hidden, range: range)
                }
            }
        }
        storage.endEditing()
    }

    private static func attributes(for style: MarkdownStyle, tint: PlatformColor,
                                   secondary: PlatformColor, faint: PlatformColor) -> [NSAttributedString.Key: Any] {
        switch style {
        case .heading(let level):
            return [.font: headingFont(level: level)]
        case .marker:
            return [.foregroundColor: faint]
        case .bold:
            return [.font: PlatformFont.systemFont(ofSize: baseSize, weight: .semibold)]
        case .italic:
            return [.obliqueness: 0.18]
        case .strike:
            return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        case .code, .frontmatter:
            return [.font: monospaceFont, .foregroundColor: secondary]
        case .link:
            return [.foregroundColor: tint]
        case .finished:
            return [.foregroundColor: secondary,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: secondary]
        case .dueDate:
            return [.foregroundColor: tint, .font: PlatformFont.monospacedDigitSystemFont(ofSize: baseSize - 1, weight: .regular)]
        case .priority:
            return [.foregroundColor: PlatformColor.systemOrange,
                    .font: PlatformFont.systemFont(ofSize: baseSize, weight: .bold)]
        case .tag:
            return [.foregroundColor: tint]
        case .quote:
            return [.foregroundColor: secondary, .obliqueness: 0.12]
        case .rule:
            return [.foregroundColor: faint]
        }
    }
}

// MARK: - The platform text view

#if os(macOS)
/// An NSTextView that reports a ⌘-click. Plain clicks are left alone: they place the cursor,
/// which is what a text view is for — a link opens on ⌘-click and never by accident.
final class LinkingTextView: NSTextView {
    var onCommandClick: ((Int) -> Void)?
    /// A plain click on a task's box (build 286): ticks it instead of placing the cursor.
    var onBoxClick: ((Int) -> Void)?
    /// Build 287: a right-click on a box adds Cancel task / Move to tomorrow.
    var onBoxMenu: ((Int, BoxAction) -> Void)?
    /// Build 287: Format › Bold, Italic, Heading (sent down the responder chain).
    var onFormat: ((FormatAction) -> Void)?
    /// Build 289: a click on a picture in the text, with its file.
    var onPictureClick: ((String) -> Void)?

    /// The picture under `point`, when the click is really on it.
    func picture(at point: NSPoint) -> PictureAttachment? {
        guard let layout = layoutManager, let container = textContainer, let storage = textStorage else { return nil }
        let p = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layout.glyphIndex(for: p, in: container)
        let index = layout.characterIndexForGlyph(at: glyph)
        guard index < storage.length,
              let a = storage.attribute(.attachment, at: index, effectiveRange: nil) as? PictureAttachment else { return nil }
        let rect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        return rect.contains(p) ? a : nil
    }

    @objc func paragonBold(_ sender: Any?) { onFormat?(.bold) }
    @objc func paragonItalic(_ sender: Any?) { onFormat?(.italic) }
    @objc func paragonHeading(_ sender: Any?) { onFormat?(.heading) }
    @objc func paragonStrike(_ sender: Any?) { onFormat?(.strike) }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        let point = convert(event.locationInWindow, from: nil)
        guard let box = boxOffset(at: point) else { return menu }
        let cancel = NSMenuItem(title: "Cancel task", action: #selector(boxMenuChosen(_:)), keyEquivalent: "")
        cancel.representedObject = [box, 0]
        cancel.target = self
        let tomorrow = NSMenuItem(title: "Move to tomorrow", action: #selector(boxMenuChosen(_:)), keyEquivalent: "")
        tomorrow.representedObject = [box, 1]
        tomorrow.target = self
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(tomorrow, at: 0)
        menu.insertItem(cancel, at: 0)
        return menu
    }

    @objc private func boxMenuChosen(_ item: NSMenuItem) {
        guard let pair = item.representedObject as? [Int], pair.count == 2 else { return }
        onBoxMenu?(pair[0], pair[1] == 0 ? .cancel : .tomorrow)
    }

    /// The box under `point` (in this view's coordinates), by the start of its `[`.
    func boxOffset(at point: NSPoint) -> Int? {
        guard let layout = layoutManager, let container = textContainer else { return nil }
        let p = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let index = layout.characterIndex(for: p, in: container, fractionOfDistanceBetweenInsertionPoints: &fraction)
        guard let box = TaskBox.boxRange(in: string, near: index) else { return nil }
        let glyphs = layout.glyphRange(forCharacterRange: box, actualCharacterRange: nil)
        let rect = layout.boundingRect(forGlyphRange: glyphs, in: container).insetBy(dx: -3, dy: -2)
        return rect.contains(p) ? box.location : nil
    }

    static func scrollable() -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let old = scrollView.documentView as? NSTextView,
              let container = old.textContainer, let layout = container.layoutManager,
              let storage = layout.textStorage else { return scrollView }
        let textView = LinkingTextView(frame: old.frame, textContainer: container)
        textView.autoresizingMask = old.autoresizingMask
        textView.minSize = old.minSize
        textView.maxSize = old.maxSize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        _ = storage
        scrollView.documentView = textView
        return scrollView
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard event.modifierFlags.contains(.command) else {
            if event.clickCount == 1, let box = boxOffset(at: point) {
                onBoxClick?(box)
                return
            }
            if event.clickCount == 1, let picture = picture(at: point) {
                onPictureClick?(picture.path)
                return
            }
            super.mouseDown(with: event)
            return
        }
        let offset = characterIndexForInsertion(at: point)
        onCommandClick?(offset)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        // A pointing hand over every link, so it is plain they can be opened.
        guard let layout = layoutManager, let container = textContainer else { return }
        for match in WikiLinks.matches(in: string) {
            let glyphs = layout.glyphRange(forCharacterRange: match.range, actualCharacterRange: nil)
            var rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            rect.origin.x += textContainerInset.width
            rect.origin.y += textContainerInset.height
            addCursorRect(rect, cursor: .pointingHand)
        }
        // And over every task's box, which a click ticks (build 286).
        for box in TaskBox.boxRanges(in: string) {
            let glyphs = layout.glyphRange(forCharacterRange: box, actualCharacterRange: nil)
            var rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            rect.origin.x += textContainerOrigin.x
            rect.origin.y += textContainerOrigin.y
            addCursorRect(rect, cursor: .pointingHand)
        }
    }
}

struct MarkdownTextViewRepresentable: NSViewRepresentable {
    @Binding var text: String
    var tint: Color
    @Binding var linkDraft: LinkDraftOnScreen?
    @Binding var completion: LinkCompletion?
    var openLink: (String) -> Void
    var onLinkKey: (LinkKey) -> Bool
    /// Taken so both platforms have the same shape; the Mac's editor always scrolls.
    var scrolls: Bool = true
    /// Build 289: pictures shown in the text (the Mac cannot draw: no pencil or photo button).
    var pictures: PictureHooks? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, linkDraft: $linkDraft, openLink: openLink, onLinkKey: onLinkKey)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = LinkingTextView.scrollable()
        guard let textView = scrollView.documentView as? LinkingTextView else { return scrollView }
        textView.onCommandClick = { [weak coordinator = context.coordinator] offset in
            coordinator?.commandClicked(at: offset)
        }
        textView.onBoxClick = { [weak coordinator = context.coordinator] offset in
            coordinator?.boxClicked(at: offset)
        }
        textView.onBoxMenu = { [weak coordinator = context.coordinator] offset, action in
            coordinator?.boxMenu(action, at: offset)
        }
        textView.onFormat = { [weak coordinator = context.coordinator] action in
            coordinator?.format(action)
        }
        textView.onPictureClick = { [weak coordinator = context.coordinator] path in
            coordinator?.pictures?.open(path)
        }
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        // No grey word suggestions while typing (build 252). macOS shows one by putting the
        // suggested words into the text itself and holding the keyboard in a loop of its own
        // until you accept or refuse it. When SwiftUI resized the editor during that loop, the
        // text and its layout disagreed and PARAGON crashed (16 October, build 251). Spelling
        // is still checked and underlined.
        textView.inlinePredictionType = .no
        // A sum's answer in grey ("120+35=" then 155) goes down the same path and has a switch
        // of its own.
        if #available(macOS 15.0, *) {
            textView.mathExpressionCompletionType = .no
        }
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.drawsBackground = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        context.coordinator.textView = textView
        context.coordinator.pictures = pictures
        context.coordinator.shownVersion = pictures?.version
        context.coordinator.show(text)
        context.coordinator.styledTint = tint
        context.coordinator.styledScheme = context.environment.colorScheme
        context.coordinator.highlight(tint: NSColor(tint))
        // The same name the phone's text view carries, so one test finds both (build 195).
        textView.setAccessibilityIdentifier("note.editor")
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        context.coordinator.linkDraft = $linkDraft
        context.coordinator.openLink = openLink
        context.coordinator.onLinkKey = onLinkKey
        context.coordinator.pictures = pictures
        // A title picked from the list: written in here, where the text view is, so the cursor
        // lands after it. Undo starts again from here (build 252), as after any outside change.
        if let completion, !context.coordinator.applying {
            // Writing the text sends the delegate off through its callbacks, and anything that
            // published state from there would be publishing inside a SwiftUI update — which
            // is a spin, not a crash, and looks like a beachball (build 116). The flag keeps
            // the coordinator quiet until this pass is over.
            context.coordinator.applying = true
            let done = WikiLinks.completing(textView.string, draft: completion.draft, with: completion.title)
            let pictures = textView.textStorage.map { PictureText.pictures(in: $0) } ?? []
            textView.string = done.text
            if let storage = textView.textStorage { PictureText.reattachInOrder(pictures, to: storage) }
            // Setting the string records nothing, so earlier typing would be undone at places
            // that have moved. An undo may only ever touch the text it was recorded on.
            context.coordinator.history.removeAllActions()
            textView.setSelectedRange(NSRange(location: min(done.cursor, (done.text as NSString).length), length: 0))
            context.coordinator.highlight(tint: NSColor(tint))
            let finished = context.coordinator.markdown()
            DispatchQueue.main.async {
                self.text = finished
                self.completion = nil
                self.linkDraft = nil
                context.coordinator.applying = false
            }
            return
        }
        // Only when the text really came from somewhere else, so typing is never interrupted.
        // Not held back under a half-typed accent either: `textDidChange` copies the screen
        // into the binding first, so a difference here is always a real outside change (a
        // tick, the fold, a sync), and skipping it let the next key write the old screen back
        // over it — the settings block could be lost (build 252's review).
        var replaced = false
        let versionChanged = context.coordinator.shownVersion != pictures?.version
        if versionChanged { context.coordinator.cache = [:]; context.coordinator.shownVersion = pictures?.version }
        if versionChanged || context.coordinator.markdown() != text {
            let selected = textView.selectedRange()
            context.coordinator.show(text)
            context.coordinator.history.removeAllActions()
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selected.location, length), length: 0))
            replaced = true
        }
        // Restyled only when something it depends on changed. This runs on every SwiftUI
        // update, often in the middle of the window's layout, and restyling the whole text
        // there for nothing is a change to the text storage at the worst possible moment
        // (build 252). Typing restyles itself, in `textDidChange`.
        let scheme = context.environment.colorScheme
        if replaced || context.coordinator.styledTint != tint || context.coordinator.styledScheme != scheme {
            context.coordinator.styledTint = tint
            context.coordinator.styledScheme = scheme
            context.coordinator.highlight(tint: NSColor(tint))
        }
    }

    /// The note is closing. Its undo history goes with it, and the text view may not call
    /// back into a coordinator that is about to be gone.
    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        if let textView = scrollView.documentView as? LinkingTextView {
            textView.breakUndoCoalescing()
            // Without the delegate it would fall back to the window's history, the very one it
            // must never point into once it is freed. Nothing it does on its way out is recorded.
            textView.allowsUndo = false
            textView.onCommandClick = nil
            textView.onBoxClick = nil
            textView.onBoxMenu = nil
            textView.onFormat = nil
            textView.onPictureClick = nil
            textView.delegate = nil
        }
        coordinator.history.removeAllActions()
        coordinator.textView = nil
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var linkDraft: Binding<LinkDraftOnScreen?>
        var openLink: (String) -> Void
        var onLinkKey: (LinkKey) -> Bool
        /// True while a chosen title is being written in: nothing is reported meanwhile.
        var applying = false
        weak var textView: NSTextView?
        /// This editor's own undo history. Without it the text view kept its typing in the
        /// window's history, which outlives the editor: every note opens a fresh one
        /// (`.id(path)`), so ⌘Z after leaving a note asked a text view that was already gone
        /// to undo its typing, and PARAGON crashed (16 October, build 251).
        let history = UndoManager()

        func undoManager(for view: NSTextView) -> UndoManager? { history }
        /// The tint and the light or dark look the text was last styled with, so an update
        /// that changes nothing restyles nothing — and a switch to dark mode still does.
        var styledTint: Color?
        var styledScheme: ColorScheme?
        /// Build 289: pictures in the text.
        var pictures: PictureHooks?
        var shownVersion: Int?
        var cache: [String: NSImage] = [:]

        /// Puts the markdown on screen, each picture line as its picture.
        func show(_ markdown: String) {
            guard let textView, let storage = textView.textStorage else { return }
            let width = textView.textContainer?.size.width ?? 0
            let shown = PictureText.display(markdown, hooks: pictures, width: width > 200 ? width - 12 : 480, cache: &cache)
            textView.string = shown.text
            PictureText.attach(shown.pictures, to: storage)
        }

        /// What the editor holds, as markdown.
        func markdown() -> String {
            guard let storage = textView?.textStorage else { return text.wrappedValue }
            return PictureText.markdown(from: storage)
        }

        init(text: Binding<String>, linkDraft: Binding<LinkDraftOnScreen?>,
             openLink: @escaping (String) -> Void, onLinkKey: @escaping (LinkKey) -> Bool) {
            self.text = text
            self.linkDraft = linkDraft
            self.openLink = openLink
            self.onLinkKey = onLinkKey
        }

        /// While the list of titles is up it gets the arrow keys, Return and Escape. Anything
        /// else, and anything it does not use, goes on to do its ordinary job.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard linkDraft.wrappedValue != nil else {
                // Build 287: Return on a task or bullet line carries the list on.
                if selector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText() {
                    let selected = textView.selectedRange()
                    if selected.length == 0, let next = RichText.continuingList(textView.string, at: selected.location) {
                        replace(with: next.text, selection: NSRange(location: next.cursor, length: 0))
                        return true
                    }
                }
                return false
            }
            switch selector {
            case #selector(NSResponder.moveDown(_:)): return onLinkKey(.down)
            case #selector(NSResponder.moveUp(_:)): return onLinkKey(.up)
            case #selector(NSResponder.insertNewline(_:)): return onLinkKey(.enter)
            case #selector(NSResponder.cancelOperation(_:)): return onLinkKey(.escape)
            default: return false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            // Copied first, always: if AppKit finishes a half-typed accent without telling us,
            // the note already holds what the screen shows, and nothing is lost.
            let now = markdown()
            if text.wrappedValue != now { text.wrappedValue = now }
            // A half-typed accent (´ then e) is marked text, and AppKit keeps its own marking
            // on it. It is not restyled or measured until the letter is finished, which calls
            // this again.
            guard !textView.hasMarkedText() else { return }
            highlight(tint: nil)
            reportDraft()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            restyleIfTheCursorChangedLine()
            reportDraft()
        }

        /// Build 287: the hidden `**` / `#` show on the cursor's line only, so moving to
        /// another line restyles. Only then, and never under a half-typed accent.
        private var styledLine: NSRange?
        private func restyleIfTheCursorChangedLine() {
            guard let textView, !textView.hasMarkedText() else { return }
            let ns = textView.string as NSString
            let at = min(textView.selectedRange().location, ns.length)
            let line = ns.lineRange(for: NSRange(location: at, length: 0))
            if line != styledLine { highlight(tint: nil) }
        }

        func commandClicked(at offset: Int) {
            guard let textView, let title = WikiLinks.link(at: offset, in: textView.string) else { return }
            openLink(title)
        }

        /// Ticks the task whose box was clicked, as an ordinary edit, so ⌘Z undoes it.
        func boxClicked(at offset: Int) {
            guard let textView, let ticked = TaskBox.toggled(textView.string, at: offset) else { return }
            replace(with: ticked, selection: nil)
        }

        /// Build 287: the right-click menu on a box.
        func boxMenu(_ action: BoxAction, at offset: Int) {
            guard let textView else { return }
            let changed: String?
            switch action {
            case .cancel: changed = TaskBox.cancelled(textView.string, at: offset)
            case .tomorrow: changed = TaskBox.movedToTomorrow(textView.string, at: offset)
            }
            if let changed { replace(with: changed, selection: nil) }
        }

        /// Build 287: Format › Bold (⌘B), Italic (⌘I), Heading (⌥⌘H).
        func format(_ action: FormatAction) {
            guard let textView, !textView.hasMarkedText() else { return }
            let selected = textView.selectedRange()
            switch action {
            case .bold, .italic, .strike:
                let marker = action == .bold ? "**" : action == .strike ? "~~" : "*"
                let done = RichText.toggling(textView.string, selection: selected, marker: marker)
                replace(with: done.text, selection: done.selection)
            case .heading:
                let done = RichText.cyclingHeading(textView.string, at: selected.location)
                replace(with: done.text, selection: NSRange(location: done.cursor, length: 0))
            }
        }

        /// Writes only the part that changed, as an ordinary edit, so ⌘Z undoes it. Nil keeps
        /// the cursor where it was.
        func replace(with new: String, selection: NSRange?) {
            guard let textView else { return }
            let edit = TaskBox.edit(from: textView.string, to: new)
            let selected = textView.selectedRange()
            guard textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
            textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
            textView.didChangeText()
            let length = (textView.string as NSString).length
            var target = selection ?? NSRange(location: selected.location, length: 0)
            target.location = min(target.location, length)
            target.length = min(target.length, length - target.location)
            textView.setSelectedRange(target)
        }

        /// Tells the note screen what is being typed and where the caret is. Reading only:
        /// nothing here changes the text, so typing is never interrupted.
        private func reportDraft() {
            guard !applying, let textView, let layout = textView.layoutManager,
                  let container = textView.textContainer else { return }
            let selected = textView.selectedRange()
            guard selected.length == 0,
                  let draft = WikiLinks.draft(in: textView.string, cursor: selected.location) else {
                publish(nil)
                return
            }
            let glyph = layout.glyphRange(forCharacterRange: NSRange(location: selected.location, length: 0),
                                          actualCharacterRange: nil)
            var rect = layout.boundingRect(forGlyphRange: glyph, in: container)
            rect.origin.x += textView.textContainerInset.width
            rect.origin.y += textView.textContainerInset.height
            // Minus how far the view is scrolled: the list is placed over the editor, not over
            // the document.
            let scrolled = textView.enclosingScrollView?.contentView.bounds.origin.y ?? 0
            let onScreen = LinkDraftOnScreen(draft: draft,
                                             caret: CGPoint(x: rect.minX, y: rect.minY - scrolled),
                                             lineHeight: max(rect.height, 16))
            publish(onScreen)
        }

        /// Never straight away: a delegate callback can happen inside a SwiftUI update, and
        /// state written there sends the two of them round in circles.
        private func publish(_ value: LinkDraftOnScreen?) {
            guard linkDraft.wrappedValue != value else { return }
            DispatchQueue.main.async { [self] in
                if linkDraft.wrappedValue != value { linkDraft.wrappedValue = value }
            }
        }

        private var lastTint: NSColor = .controlAccentColor

        func highlight(tint: NSColor?) {
            guard let textView, let storage = textView.textStorage else { return }
            if let tint { lastTint = tint }
            // Restyling would wipe the marking AppKit keeps on a half-typed accent. The next
            // `textDidChange`, when the letter is finished, styles everything.
            guard !textView.hasMarkedText() else { return }
            let ns = textView.string as NSString
            let cursor = min(textView.selectedRange().location, ns.length)
            styledLine = ns.lineRange(for: NSRange(location: cursor, length: 0))
            MarkdownAttributes.apply(to: storage, text: textView.string, tint: lastTint,
                                     primary: .labelColor, secondary: .secondaryLabelColor, faint: .tertiaryLabelColor,
                                     hideMarkers: true, cursor: cursor)
            textView.typingAttributes = MarkdownAttributes.base(color: .labelColor)
        }
    }
}
#else
struct MarkdownTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    var tint: Color
    @Binding var linkDraft: LinkDraftOnScreen?
    @Binding var completion: LinkCompletion?
    var openLink: (String) -> Void
    var onLinkKey: (LinkKey) -> Bool
    var scrolls: Bool = true
    var pictures: PictureHooks? = nil

    /// The floor under everything below. Build 123 let the text view ask for its own height
    /// and it asked for none, so a note could not be edited at all: SwiftUI does not lay a
    /// `UIViewRepresentable` out from `intrinsicContentSize`, and nothing else claimed a
    /// height either. Whatever the measuring does now, it can never come out shorter than
    /// the box the editor has always had.
    static let leastHeight: CGFloat = 320

    /// Asked by SwiftUI how tall this wants to be. Only answered when the text does not
    /// scroll itself; a scrolling text view takes whatever it is given, as it always has.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard !scrolls else { return nil }
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, Self.leastHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, linkDraft: $linkDraft, openLink: openLink)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        // NO gesture recogniser here. Build 114 added a tap recogniser so a tap could open a
        // [[link]], with cancelsTouchesInView = false in the belief that it would give way.
        // It did not: a UITextView's own single tap is what places the cursor, and a second
        // tap recogniser on the same view makes that tap ambiguous — you have to press and
        // hold to get a caret. That is the long press he lived with from 114 to 128, and it
        // is why three attempts at the *layout* never touched it. On the phone, links are
        // followed in Read, which is one tap away in the bar below.
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.isScrollEnabled = scrolls
        textView.alwaysBounceVertical = scrolls
        context.coordinator.textView = textView
        context.coordinator.pictures = pictures
        context.coordinator.shownVersion = pictures?.version
        context.coordinator.show(text)
        context.coordinator.highlight(tint: UIColor(tint))
        // What the screen tests type into (build 191). A name of its own, so a change to the
        // screen around it cannot quietly stop the test from finding it.
        textView.accessibilityIdentifier = "note.editor"
        // Build 286: a tap on a task's box ticks it. This recogniser only *begins* on a box
        // (`gestureRecognizerShouldBegin`), so everywhere else the text view's own tap places
        // the caret untouched — the trap of build 114 above was a recogniser that always began.
        let boxTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.boxTapped(_:)))
        boxTap.delegate = context.coordinator
        textView.addGestureRecognizer(boxTap)
        context.coordinator.boxTap = boxTap
        // Build 287: a long press on a box offers Cancel task / Move to tomorrow. Same rule:
        // it only begins on a box, so the text view's own long press (the loupe) is untouched.
        let boxPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.boxPressed(_:)))
        boxPress.delegate = context.coordinator
        textView.addGestureRecognizer(boxPress)
        context.coordinator.boxPress = boxPress
        let menu = UIEditMenuInteraction(delegate: context.coordinator)
        textView.addInteraction(menu)
        context.coordinator.boxMenu = menu
        // The bar above the keyboard (his pick A, 11 Nov): one button for now, the checkbox.
        textView.inputAccessoryView = context.coordinator.formatBar(tint: UIColor(tint))
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.isScrollEnabled != scrolls { textView.isScrollEnabled = scrolls }
        context.coordinator.text = $text
        context.coordinator.linkDraft = $linkDraft
        context.coordinator.openLink = openLink
        context.coordinator.pictures = pictures
        if let completion, !context.coordinator.applying {
            context.coordinator.applying = true
            let done = WikiLinks.completing(textView.text, draft: completion.draft, with: completion.title)
            let pictures = PictureText.pictures(in: textView.textStorage)
            textView.text = done.text
            PictureText.reattachInOrder(pictures, to: textView.textStorage)
            textView.selectedRange = NSRange(location: min(done.cursor, (done.text as NSString).length), length: 0)
            context.coordinator.highlight(tint: UIColor(tint))
            let finished = context.coordinator.markdown()
            DispatchQueue.main.async {
                self.text = finished
                self.completion = nil
                self.linkDraft = nil
                context.coordinator.applying = false
            }
            return
        }
        let versionChanged = context.coordinator.shownVersion != pictures?.version
        if versionChanged { context.coordinator.cache = [:]; context.coordinator.shownVersion = pictures?.version }
        if versionChanged || context.coordinator.markdown() != text {
            let selected = textView.selectedRange
            context.coordinator.show(text)
            let length = (textView.text as NSString).length
            textView.selectedRange = NSRange(location: min(selected.location, length), length: 0)
        }
        context.coordinator.highlight(tint: UIColor(tint))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate, UIEditMenuInteractionDelegate {
        weak var boxTap: UIGestureRecognizer?
        weak var boxPress: UIGestureRecognizer?
        var boxMenu: UIEditMenuInteraction?
        /// The box the open long-press menu is about.
        private var menuBox: Int?
        /// True while restyling, which sets the selection back and must not restyle again.
        private var styling = false
        private var styledLine: NSRange?
        var text: Binding<String>
        var linkDraft: Binding<LinkDraftOnScreen?>
        var openLink: (String) -> Void
        var pictures: PictureHooks?
        var shownVersion: Int?
        var cache: [String: UIImage] = [:]

        /// Puts the markdown on screen, each picture line as its picture (build 289).
        func show(_ markdown: String) {
            guard let textView else { return }
            let width = textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right - 12
            let fallback = (textView.window?.windowScene?.screen.bounds.width ?? 390) - 40
            let shown = PictureText.display(markdown, hooks: pictures, width: width > 200 ? width : fallback, cache: &cache)
            textView.text = shown.text
            PictureText.attach(shown.pictures, to: textView.textStorage)
        }

        /// What the editor holds, as markdown.
        func markdown() -> String {
            guard let textView else { return text.wrappedValue }
            return PictureText.markdown(from: textView.textStorage)
        }

        /// The place in the markdown for a place on screen.
        func markdownOffset(_ offset: Int) -> Int {
            guard let textView else { return offset }
            return (PictureText.markdown(from: textView.textStorage, upTo: offset) as NSString).length
        }

        /// The picture under `point`, when the tap is really on it.
        func picture(at point: CGPoint) -> PictureAttachment? {
            guard let textView, let position = textView.closestPosition(to: point) else { return nil }
            let storage = textView.textStorage
            let index = textView.offset(from: textView.beginningOfDocument, to: position)
            for at in [index, index - 1] where at >= 0 && at < storage.length {
                guard let a = storage.attribute(.attachment, at: at, effectiveRange: nil) as? PictureAttachment,
                      let start = textView.position(from: textView.beginningOfDocument, offset: at),
                      let end = textView.position(from: start, offset: 1),
                      let range = textView.textRange(from: start, to: end) else { continue }
                if textView.firstRect(for: range).contains(point) { return a }
            }
            return nil
        }
        /// True while a chosen title is being written in: nothing is reported meanwhile.
        var applying = false
        weak var textView: UITextView?
        private var lastTint: UIColor = .tintColor

        init(text: Binding<String>, linkDraft: Binding<LinkDraftOnScreen?>, openLink: @escaping (String) -> Void) {
            self.text = text
            self.linkDraft = linkDraft
            self.openLink = openLink
        }

        func textViewDidChange(_ textView: UITextView) {
            let now = markdown()
            if text.wrappedValue != now { text.wrappedValue = now }
            highlight(tint: nil)
            reportDraft()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Build 287: the hidden `**` / `#` show on the cursor's line only.
            if !styling, textView.markedTextRange == nil, cursorLine(of: textView) != styledLine {
                highlight(tint: nil)
            }
            reportDraft()
        }

        func textViewDidBeginEditing(_ textView: UITextView) { highlight(tint: nil) }
        func textViewDidEndEditing(_ textView: UITextView) { highlight(tint: nil) }

        /// Return on a task or bullet line carries the list on (build 287).
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n", range.length == 0, textView.markedTextRange == nil,
                  let next = RichText.continuingList(textView.text, at: range.location) else { return true }
            write(next.text, selection: NSRange(location: next.cursor, length: 0))
            return false
        }

        /// The line the cursor is on, or nil while the note is only being read: then every
        /// marker is hidden.
        private func cursorLine(of textView: UITextView) -> NSRange? {
            guard textView.isFirstResponder else { return nil }
            let ns = textView.text as NSString
            return ns.lineRange(for: NSRange(location: min(textView.selectedRange.location, ns.length), length: 0))
        }

        // MARK: Ticking a box, and the bar above the keyboard (build 286)

        /// The box under `point`, by the start of its `[`, when the point is really on it.
        private func boxOffset(at point: CGPoint) -> Int? {
            guard let textView, let position = textView.closestPosition(to: point) else { return nil }
            let index = textView.offset(from: textView.beginningOfDocument, to: position)
            guard let box = TaskBox.boxRange(in: textView.text, near: index),
                  let start = textView.position(from: textView.beginningOfDocument, offset: box.location),
                  let end = textView.position(from: start, offset: box.length),
                  let range = textView.textRange(from: start, to: end) else { return nil }
            let rect = textView.firstRect(for: range).insetBy(dx: -8, dy: -6)
            return rect.contains(point) ? box.location : nil
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard recognizer === boxTap || recognizer === boxPress, let textView else { return true }
            let point = recognizer.location(in: textView)
            if recognizer === boxTap, picture(at: point) != nil { return true }
            return boxOffset(at: point) != nil
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            recognizer === boxTap || recognizer === boxPress
        }

        @objc func boxTapped(_ recognizer: UITapGestureRecognizer) {
            if let textView, let picture = picture(at: recognizer.location(in: textView)) {
                textView.resignFirstResponder()
                pictures?.open(picture.path)
                return
            }
            guard let textView, let offset = boxOffset(at: recognizer.location(in: textView)),
                  let ticked = TaskBox.toggled(textView.text, at: offset) else { return }
            write(ticked, cursor: nil)
        }

        @objc func boxPressed(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let textView, let boxMenu else { return }
            let point = recognizer.location(in: textView)
            guard let offset = boxOffset(at: point) else { return }
            menuBox = offset
            boxMenu.presentEditMenu(with: UIEditMenuConfiguration(identifier: "box", sourcePoint: point))
        }

        func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration,
                                 suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard configuration.identifier as? String == "box", let box = menuBox else { return nil }
            let cancel = UIAction(title: "Cancel task") { [weak self] _ in
                guard let self, let textView = self.textView,
                      let changed = TaskBox.cancelled(textView.text, at: box) else { return }
                self.write(changed, cursor: nil)
            }
            let tomorrow = UIAction(title: "Move to tomorrow") { [weak self] _ in
                guard let self, let textView = self.textView,
                      let changed = TaskBox.movedToTomorrow(textView.text, at: box) else { return }
                self.write(changed, cursor: nil)
            }
            return UIMenu(children: [cancel, tomorrow])
        }

        private func write(_ new: String, cursor: Int?) {
            write(new, selection: cursor.map { NSRange(location: $0, length: 0) })
        }

        /// Writes only the part that changed, through the text view, so Undo works.
        private func write(_ new: String, selection: NSRange?) {
            guard let textView else { return }
            let edit = TaskBox.edit(from: textView.text, to: new)
            guard let start = textView.position(from: textView.beginningOfDocument, offset: edit.range.location),
                  let end = textView.position(from: start, offset: edit.range.length),
                  let range = textView.textRange(from: start, to: end) else { return }
            let selected = textView.selectedRange
            textView.replace(range, withText: edit.replacement)
            let length = (textView.text as NSString).length
            var target = selection ?? NSRange(location: selected.location, length: 0)
            target.location = min(target.location, length)
            target.length = min(target.length, length - target.location)
            textView.selectedRange = target
            textViewDidChange(textView)
        }

        func formatBar(tint: UIColor) -> UIView {
            let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
            let task = UIBarButtonItem(image: Marks.uiImage("checkmark.square.fill", size: 22),
                                       style: .plain, target: self, action: #selector(switchTask))
            task.accessibilityLabel = "Task"
            task.accessibilityIdentifier = "format.task"
            task.tintColor = tint
            // Build 287: bold, italic and heading, drawn as letters (no stock icons).
            func letter(_ title: String, _ font: UIFont, _ id: String, _ label: String, _ action: Selector) -> UIBarButtonItem {
                let button = UIButton(type: .system)
                button.setAttributedTitle(NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: tint]), for: .normal)
                button.addTarget(self, action: action, for: .touchUpInside)
                button.frame = CGRect(x: 0, y: 0, width: 40, height: 36)
                button.accessibilityLabel = label
                button.accessibilityIdentifier = id
                return UIBarButtonItem(customView: button)
            }
            let size: CGFloat = 19
            let bold = letter("B", .systemFont(ofSize: size, weight: .bold), "format.bold", "Bold", #selector(makeBold))
            let italicFont = UIFont.systemFont(ofSize: size, weight: .regular).fontDescriptor.withSymbolicTraits(.traitItalic)
                .map { UIFont(descriptor: $0, size: size) } ?? .italicSystemFont(ofSize: size)
            let italic = letter("I", italicFont, "format.italic", "Italic", #selector(makeItalic))
            let heading = letter("H", .systemFont(ofSize: size, weight: .semibold), "format.heading", "Heading", #selector(makeHeading))
            // Build 288: S struck through, and the pencil for a sketch at the end.
            let strike = letter("S", .systemFont(ofSize: size, weight: .regular), "format.strike", "Strikethrough", #selector(makeStrike))
            if let button = strike.customView as? UIButton {
                button.setAttributedTitle(NSAttributedString(string: "S", attributes: [
                    .font: UIFont.systemFont(ofSize: size, weight: .regular), .foregroundColor: tint,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue, .strikethroughColor: tint]), for: .normal)
            }
            var items: [UIBarButtonItem] = [task, bold, italic, strike, heading, .flexibleSpace()]
            if pictures != nil {
                // Build 289: the photo button beside the pencil, a choice of camera or library.
                var choices: [UIAction] = []
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    choices.append(UIAction(title: "Take photo") { [weak self] _ in self?.makePhoto(camera: true) })
                }
                choices.append(UIAction(title: "Choose photo") { [weak self] _ in self?.makePhoto(camera: false) })
                let photo = UIBarButtonItem(image: Marks.uiImage("photo", size: 22), menu: UIMenu(children: choices))
                photo.accessibilityLabel = "Photo"
                photo.accessibilityIdentifier = "format.photo"
                photo.tintColor = tint
                let sketch = UIBarButtonItem(image: Marks.uiImage("pencil", size: 22),
                                             style: .plain, target: self, action: #selector(makeSketch))
                sketch.accessibilityLabel = "Sketch"
                sketch.accessibilityIdentifier = "format.sketch"
                sketch.tintColor = tint
                items.append(photo)
                items.append(sketch)
            }
            bar.items = items
            bar.sizeToFit()
            return bar
        }

        @objc func switchTask() {
            guard let textView else { return }
            let switched = TaskBox.switchingTask(textView.text, at: textView.selectedRange.location)
            write(switched.text, cursor: switched.cursor)
        }

        @objc func makeBold() { toggle("**") }
        @objc func makeItalic() { toggle("*") }
        @objc func makeStrike() { toggle("~~") }
        @objc func makeSketch() {
            guard let textView else { return }
            let at = markdownOffset(textView.selectedRange.location)
            textView.resignFirstResponder()
            pictures?.sketch(at)
        }
        func makePhoto(camera: Bool) {
            guard let textView else { return }
            let at = markdownOffset(textView.selectedRange.location)
            textView.resignFirstResponder()
            pictures?.photo(at, camera)
        }
        @objc func makeHeading() {
            guard let textView else { return }
            let done = RichText.cyclingHeading(textView.text, at: textView.selectedRange.location)
            write(done.text, cursor: done.cursor)
        }
        private func toggle(_ marker: String) {
            guard let textView else { return }
            let done = RichText.toggling(textView.text, selection: textView.selectedRange, marker: marker)
            write(done.text, selection: done.selection)
        }

        /// Reading only: what is being typed and where the caret is.
        private func reportDraft() {
            guard !applying, let textView else { return }
            let selected = textView.selectedRange
            guard selected.length == 0,
                  let draft = WikiLinks.draft(in: textView.text, cursor: selected.location),
                  let position = textView.position(from: textView.beginningOfDocument, offset: selected.location) else {
                publish(nil)
                return
            }
            let caret = textView.caretRect(for: position)
            let onScreen = LinkDraftOnScreen(draft: draft,
                                             caret: CGPoint(x: caret.minX, y: caret.minY - textView.contentOffset.y),
                                             lineHeight: max(caret.height, 16))
            publish(onScreen)
        }

        /// Never straight away: see the macOS side. A delegate callback can land inside a
        /// SwiftUI update, and state written there sends the two round in circles.
        private func publish(_ value: LinkDraftOnScreen?) {
            guard linkDraft.wrappedValue != value else { return }
            DispatchQueue.main.async { [self] in
                if linkDraft.wrappedValue != value { linkDraft.wrappedValue = value }
            }
        }

        func highlight(tint: UIColor?) {
            guard let textView else { return }
            if let tint { lastTint = tint }
            // Not under a half-typed letter: restyling would wipe its marking.
            guard textView.markedTextRange == nil else { return }
            let selected = textView.selectedRange
            styling = true
            defer { styling = false }
            styledLine = cursorLine(of: textView)
            MarkdownAttributes.apply(to: textView.textStorage, text: textView.text, tint: lastTint,
                                     primary: .label, secondary: .secondaryLabel, faint: .tertiaryLabel,
                                     hideMarkers: true, cursor: styledLine.map { _ in selected.location })
            textView.typingAttributes = MarkdownAttributes.base(color: .label)
            textView.selectedRange = selected
        }
    }
}
#endif
