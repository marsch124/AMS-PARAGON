#if os(macOS)
import AppKit
import SwiftUI
import ParagonCore

/// The running focus clock in the Mac's menu bar (build 257), from the
/// drawing he loved (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX): *"The running time also
/// shows in the menu bar, next to the clock, so you see it when PARAGON is behind another
/// window."* It is there only while a clock runs. **macOS puts a new item at the left of the
/// icons already there, never beside the clock**, so it carries an `autosaveName`: ⌘-dragged
/// next to the clock once, it comes back there every time.
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
/// task, **Planned: 45 min** when it has a time, **Pause** or **Go on**, **Stop…** and **Show
/// PARAGON**. Stop shows the window first, because the one question after Stop is asked there.
/// **Pause**, **Go on** and **Stop…** are greyed out while that question is open or waiting
/// (`NSMenuItemValidation`, asked each time the menu opens): the menu is outside the sheet, so
/// nothing else would stop the clock being started again behind it (build 257's review).
///
/// **When no clock runs, the item is hidden, never removed** (`isVisible`): removing an item
/// that has an `autosaveName` throws away the place he dragged it to.
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
        item.isVisible = true
        item.menu = menu(for: session)
        // Here, on each change, not each second: neither changes between ticks, and setting a
        // tooltip every second can stop it ever showing.
        if let button = item.button {
            button.image = Self.dot(paused: session.isPaused)
            button.toolTip = session.title
        }
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
        // Remembers where he puts it with ⌘-drag, across clocks and launches.
        item.autosaveName = "PARAGON focus clock"
        // After the name, which loads what was saved under it: a hidden state saved once must
        // never keep the clock out of the menu bar.
        item.isVisible = true
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

    /// Hides the item. Never `removeStatusItem`: for an item with an `autosaveName` that also
    /// deletes the place it was ⌘-dragged to, and it would come back at the far left.
    private func remove() {
        timer?.invalidate()
        timer = nil
        item?.isVisible = false
    }

    private func redraw() {
        guard let session, let button = item?.button else { return }
        let clock = FocusSession.clock(session.workedSeconds(at: Date()))
        button.title = " " + clock
        let state = session.isPaused ? ", paused" : ""
        button.setAccessibilityLabel("Focus clock \(clock)\(state), \(session.title)")
    }

    /// The bar's dot: the plan-block orange while the clock runs, grey while it is paused.
    private static func dot(paused: Bool) -> NSImage? {
        // `systemGray`, a fixed mid grey, rather than `secondaryLabelColor`: the menu bar can be
        // dark while the app is light, and a colour resolved for the app could vanish there.
        let colour = paused ? NSColor.systemGray : (NSColor(named: "PlanTint") ?? .systemOrange)
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
            let line = NSMenuItem(title: "Planned: " + TaskTime.total(planned), action: nil, keyEquivalent: "")
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

    /// Brings PARAGON forward with its main window: the one carrying `MainWindowMarker`, which
    /// `ContentView` draws whether it shows the vault or the welcome screen — never Settings,
    /// Help or the planner window, where the stop question cannot be shown. A minimized window
    /// comes back from the Dock, a hidden PARAGON is shown again, and only when no main window
    /// exists at all is a fresh one opened (both reviews of build 257): activating the app alone
    /// never makes one, so Stop… would have shown nothing.
    @objc private func showApp() {
        if NSApp.isHidden { NSApp.unhide(nil) }
        NSApp.activate()
        // Not filtered on `canBecomeMain`: that is false for a minimized window, which would then
        // be passed over and a second main window opened beside it.
        let shown = NSApp.windows.filter { $0.isVisible || $0.isMiniaturized }
        if let main = shown.first(where: { Self.holdsMarker($0.contentView) }) {
            if main.isMiniaturized { main.deminiaturize(nil) }
            main.makeKeyAndOrderFront(nil)
        } else if let open = model?.openMainWindow {
            open()
        } else {
            // No main window has been drawn since launch, so `ContentView` never handed in
            // `openWindow`: ask the way a Dock click does, which opens the main window.
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL,
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func holdsMarker(_ view: NSView?) -> Bool {
        guard let view else { return false }
        if view is MainWindowMarker.MarkerView { return true }
        return view.subviews.contains { holdsMarker($0) }
    }
}

/// An empty, zero-sized view `ContentView` carries on the Mac, so the menu bar clock can tell
/// the main window from Settings, Help and the planner window — on the welcome screen too, where
/// there is no split view to look for (build 257's second review). It takes no clicks and asks
/// for no size: anything that claims a size in that window is builds 30 and 34 again.
struct MainWindowMarker: NSViewRepresentable {
    final class MarkerView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> MarkerView { MarkerView(frame: .zero) }
    func updateNSView(_ nsView: MarkerView, context: Context) {}
}

extension FocusStatusItem: NSMenuItemValidation {
    /// Asked each time the menu opens, so it follows the stop question whether or not the clock
    /// changed since the menu was built.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePause) || menuItem.action == #selector(stop) {
            return !(model?.focusQuestionPending ?? false)
        }
        return true
    }
}
#endif
