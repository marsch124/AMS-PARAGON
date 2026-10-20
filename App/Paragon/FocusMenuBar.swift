#if os(macOS)
import AppKit
import ParagonCore

/// The running focus clock in the Mac's menu bar, next to the system clock (build 257), from the
/// drawing he loved (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX): *"The running time also
/// shows in the menu bar, next to the clock, so you see it when PARAGON is behind another
/// window."* It is there only while a clock runs.
///
/// **An `NSStatusItem` of our own, not a second SwiftUI `MenuBarExtra`.** A `MenuBarExtra` label
/// is drawn from what SwiftUI takes out of it, and whether a clock in it would really tick once
/// a second cannot be seen from here, with no Mac to look at. A status item's title is set
/// directly by a timer, which is certain. The orange dot is a small image in the plan-block
/// colour, the same dot as the bar at the foot of the window; the time is plain title text, so
/// the system draws it in the menu bar's own colours, light or dark. Grey dot while paused, as on
/// the bar.
///
/// **The clock is worked out from the session's dates each second**, like the bar
/// (`FocusSession`), so it is right after the Mac slept. Pressing it opens a short menu: the
/// task, **Pause** or **Go on**, **Stop…** and **Show PARAGON**. Stop shows the window first,
/// because the one question after Stop is asked there.
@MainActor
final class FocusStatusItem: NSObject {
    private weak var model: AppModel?
    private var item: NSStatusItem?
    private var timer: Timer?
    private var session: FocusSession?

    init(model: AppModel) {
        self.model = model
    }

    /// Called on every change to the clock. Nil takes the item out of the menu bar.
    func show(_ session: FocusSession?) {
        self.session = session
        guard let session else {
            remove()
            return
        }
        let item = self.item ?? makeItem()
        self.item = item
        item.menu = menu(for: session)
        redraw()
        if timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.redraw() }
            }
            // `.common`, so it keeps ticking while a menu is open.
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageLeading
            // The menu bar's own size, with digits of one width so the item does not
            // twitch as the seconds change.
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
                                                           weight: .regular)
            // Found by name in the screen tests, never by its words (build 191).
            button.setAccessibilityIdentifier("focus.menuBar")
        }
        return item
    }

    private func remove() {
        timer?.invalidate()
        timer = nil
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    private func redraw() {
        guard let session, let button = item?.button else { return }
        let clock = FocusSession.clock(session.workedSeconds(at: Date()))
        button.image = Self.dot(paused: session.isPaused)
        button.title = " " + clock
        button.toolTip = session.title
        let state = session.isPaused ? ", paused" : ""
        button.setAccessibilityLabel("Focus clock \(clock)\(state), \(session.title)")
    }

    /// The bar's dot: the plan-block orange while the clock runs, grey while it is paused.
    private static func dot(paused: Bool) -> NSImage? {
        let colour = paused ? NSColor.secondaryLabelColor : (NSColor(named: "PlanTint") ?? .systemOrange)
        let shape = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [colour]))
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(shape)
        image?.isTemplate = false
        return image
    }

    private func menu(for session: FocusSession) -> NSMenu {
        let menu = NSMenu()
        let title = NSMenuItem(title: session.title, action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        if let planned = session.plannedMinutes {
            let line = NSMenuItem(title: "Planned: " + TaskTime.label(planned), action: nil, keyEquivalent: "")
            line.isEnabled = false
            menu.addItem(line)
        }
        menu.addItem(.separator())
        menu.addItem(entry(session.isPaused ? "Go on" : "Pause", #selector(togglePause)))
        menu.addItem(entry("Stop\u{2026}", #selector(stop)))
        menu.addItem(.separator())
        menu.addItem(entry("Show PARAGON", #selector(showApp)))
        return menu
    }

    private func entry(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    @objc private func togglePause() {
        guard let model, let session = model.focus else { return }
        if session.isPaused { model.resumeFocus() } else { model.pauseFocus() }
    }

    @objc private func stop() {
        showApp()
        model?.stopFocus()
    }

    /// Brings PARAGON forward with its main window: the one holding the sidebar's split view,
    /// rather than Settings, Help or the planner window.
    @objc private func showApp() {
        NSApp.activate()
        let windows = NSApp.windows.filter { $0.canBecomeMain }
        let main = windows.first { Self.holdsSplitView($0.contentView) } ?? windows.first { $0.isVisible }
        guard let main else { return }
        if main.isMiniaturized { main.deminiaturize(nil) }
        main.makeKeyAndOrderFront(nil)
    }

    private static func holdsSplitView(_ view: NSView?) -> Bool {
        guard let view else { return false }
        if view is NSSplitView { return true }
        return view.subviews.contains { holdsSplitView($0) }
    }
}
#endif
