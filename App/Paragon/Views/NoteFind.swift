import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// **Find inside the open note** (review round 8, build 315), with Apple's own find bar: the
/// text view's, so next, previous, the count and the highlight are the system's.
///
/// The text view is looked for at the moment of asking, in the window in front, instead of
/// being kept somewhere: more than one editor can exist (a note, a template) and the one on
/// screen is the one meant.
@MainActor
enum NoteFind {
    #if os(macOS)
    enum Step { case show, next, previous }

    static func run(_ step: Step) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let textView = (window.firstResponder as? LinkingTextView) ?? first(LinkingTextView.self, in: window.contentView)
        guard let textView else { return }
        if window.firstResponder !== textView, step == .show { window.makeFirstResponder(textView) }
        let action: NSTextFinder.Action
        switch step {
        case .show: action = .showFindInterface
        case .next: action = .nextMatch
        case .previous: action = .previousMatch
        }
        // The find bar reads what to do from the sender's tag, the way the Edit menu's items do.
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        textView.performTextFinderAction(sender)
    }

    private static func first<V: NSView>(_ type: V.Type, in view: NSView?) -> V? {
        guard let view else { return nil }
        if let found = view as? V { return found }
        for child in view.subviews {
            if let found = first(type, in: child) { return found }
        }
        return nil
    }
    #else
    static func show() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        guard let textView = first(PictureTextView.self, in: window) else { return }
        textView.findInteraction?.presentFindNavigator(showingReplace: false)
        // The bar's tick and the keyboard's Search key stay Apple's blue: the bar is drawn
        // by the keyboard and takes no colour from the text view or its window (tried in
        // build 315, both ignored).
    }

    /// True while the find bar is on screen (build 315 polish: the note's own bar at the foot
    /// steps aside for it).
    static var isUp: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        return first(PictureTextView.self, in: window)?.findInteraction?.isFindNavigatorVisible == true
    }

    private static func first<V: UIView>(_ type: V.Type, in view: UIView?) -> V? {
        guard let view else { return nil }
        if let found = view as? V { return found }
        for child in view.subviews {
            if let found = first(type, in: child) { return found }
        }
        return nil
    }
    #endif
}
