#if os(macOS)
import SwiftUI
import AppKit
import Carbon.HIToolbox
import ParagonCore

/// **One key that opens quick capture from any app** (review round 8, build 315).
///
/// Chosen in Settings › Quick capture and off until then (`CaptureHotKey`, Core). The key is
/// asked for with macOS's own hot-key call, which needs no permission from him: nothing is
/// read from the keyboard, macOS only tells PARAGON when that one key was pressed.
///
/// The panel is a small floating window of its own with the same capture screen the menu bar
/// item shows. It takes the typing **without bringing PARAGON's windows forward**, so the app
/// he was in stays where it was; Escape or a press on the key again closes it.
@MainActor
final class CaptureKey {
    static let shared = CaptureKey()

    private weak var model: AppModel?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var panel: CapturePanel?
    /// Counts every opening, closing, save and typed word (review round 8). The close that
    /// follows a save happens only when nothing of that kind came after it.
    private var generation = 0

    /// Called once at launch, and again whenever the choice in Settings changes.
    func apply(_ choice: CaptureHotKey, model: AppModel) {
        self.model = model
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        // Build 316: his own recorded key. One that is not allowed (no ⌘ or ⌃, or a key every app uses) is never
        // asked for, whatever is stored.
        let own = choice == .custom
            ? RecordedKey(stored: UserDefaults.standard.string(forKey: RecordedKey.storageKey)).flatMap { $0.isAllowed ? $0 : nil }
            : nil
        guard let code = own?.keyCode ?? choice.keyCode else { return }
        let held = own?.modifiers ?? choice.modifiers
        installHandler()
        let id = EventHotKeyID(signature: 0x5041_5247 /* "PARG" */, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(code, held, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { hotKey = ref } else { model.log("capture key not taken: \(status)") }
    }

    /// Whether macOS gave PARAGON the key (another app can hold it already).
    var isRegistered: Bool { hotKey != nil }

    /// Lets go of the key while he records a new one (build 316), so pressing the old key in
    /// the recording window does not open the panel. `apply` takes it again.
    func letGo() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { CaptureKey.shared.toggle() }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    func toggle() {
        generation += 1
        if let panel, panel.isVisible {
            panel.close()
            return
        }
        guard let model else { return }
        let panel = self.panel ?? CapturePanel()
        self.panel = panel
        // A fresh screen each time, so the field is empty and has the cursor.
        // Once the words are saved it shows "Saved" for a moment and goes away by itself —
        // unless he opened it again or went on typing meanwhile: then it stays.
        let screen = QuickCaptureView(compact: true,
                                      onSaved: { [weak self] in self?.closeSoon() },
                                      onCancel: { [weak self] in self?.close() },
                                      onTyped: { [weak self] in self?.generation += 1 })
        panel.contentView = NSHostingView(rootView: screen.environmentObject(model))
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 380, height: 260))
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Cancel and Escape in the panel: SwiftUI's own `dismiss` does nothing in a bare panel.
    private func close() {
        generation += 1
        panel?.close()
    }

    private func closeSoon() {
        generation += 1
        let mine = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.generation == mine else { return }
            self.panel?.close()
        }
    }
}

/// A floating panel that can be typed in without making PARAGON the app in front.
final class CapturePanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
                   styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        title = "PARAGON quick capture"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    /// Escape closes it.
    override func cancelOperation(_ sender: Any?) { close() }
}
#endif
