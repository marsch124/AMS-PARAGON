import Foundation

/// **A capture key he recorded himself** (round 9, build 316): Settings › Quick capture ›
/// **Record my own key…**. Besides the three fixed choices of `CaptureHotKey`, because
/// ⌃⌥Space can already be "next input source" on a Mac with two keyboards.
///
/// Kept per Mac under `storageKey` as `keyCode:modifiers:name`, never in the vault. The numbers
/// are Carbon's, as in `CaptureHotKey`; `keyName` is what the key is called on his keyboard at
/// the moment he pressed it ("K", "Space", "F5"), because a key's number does not say which
/// letter is printed on it.
public struct RecordedKey: Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var keyName: String

    public static let storageKey = "captureHotKeyOwn"

    public static let command: UInt32 = 0x100
    public static let shift: UInt32 = 0x200
    public static let option: UInt32 = 0x800
    public static let control: UInt32 = 0x1000

    public init(keyCode: UInt32, modifiers: UInt32, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers & (Self.command | Self.shift | Self.option | Self.control)
        self.keyName = keyName
    }

    /// What is stored, read back. Nil for nothing stored or anything this build cannot read.
    public init?(stored: String?) {
        guard let stored else { return nil }
        let parts = stored.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let code = UInt32(parts[0]), let held = UInt32(parts[1]), !parts[2].isEmpty else { return nil }
        self.init(keyCode: code, modifiers: held, keyName: parts[2])
    }

    public var stored: String { "\(keyCode):\(modifiers):\(keyName)" }

    /// The key as symbols, in Apple's order: ⌃ ⌥ ⇧ ⌘, then the key. "⌥⌘K".
    public var label: String {
        var text = ""
        if modifiers & Self.control != 0 { text += "\u{2303}" }
        if modifiers & Self.option != 0 { text += "\u{2325}" }
        if modifiers & Self.shift != 0 { text += "\u{21E7}" }
        if modifiers & Self.command != 0 { text += "\u{2318}" }
        return text + keyName
    }

    /// **The rule: a key needs ⌘ or ⌃, and a key every app uses is refused.**
    /// A bare letter, or Shift and a letter, is typing. So is ⌥ and a key, with or without
    /// Shift: on a Swedish keyboard ⌥2 is "@" and ⌥8 and ⌥9 are "[" and "]". As a key that
    /// works in every app it would take that letter or sign away everywhere. And ⌘C, ⌘V, ⌘Q,
    /// ⌘Tab and the like (`everyAppKeys`) would stop copying, pasting, quitting and switching
    /// apps on the whole Mac.
    public var isAllowed: Bool { refusalLine == nil }

    /// Why this key cannot be the capture key, in plain words, or nil when it can.
    public var refusalLine: String? {
        if modifiers & (Self.command | Self.control) == 0 { return Self.refusedLine }
        if Self.everyAppKeys.contains(label) {
            return "\(label) is used in almost every app, for things like copy, paste, save, quit or switching apps. As your capture key it would stop doing that everywhere. Choose another key, for example \u{2325}\u{2318}K."
        }
        return nil
    }

    public static let refusedLine = "Hold \u{2318} or \u{2303} together with the key. A key by itself, or with only \u{2325} or \u{21E7}, types a letter or a sign such as @ or [, and you could not type that any more in any app."

    /// What macOS already does with this key, or nil. A warning, not a refusal: he may have
    /// turned that shortcut off, and macOS has the last word anyway.
    public var knownUse: String? { Self.knownUses[label] }

    /// The warning's words, or nil.
    public var warningLine: String? {
        knownUse.map { "\(label) is already \($0). Your key may not work, or it may take that away. Another key is safer." }
    }

    static let knownUses: [String: String] = [
        "\u{2325}\u{2318}Space": "the Finder search window",
        "\u{2303}Space": "macOS's key for the previous input source",
        "\u{2303}\u{2325}Space": "macOS's key for the next input source",
        "\u{2303}\u{2318}Space": "the emoji and symbols window",
        "\u{2325}\u{2318}Esc": "Force Quit",
        "\u{2325}\u{2318}D": "macOS's key for hiding the Dock",
        "\u{2303}\u{2318}Q": "macOS's key for locking the screen",
        "\u{2303}\u{2318}F": "full screen in most apps",
        "\u{21E7}\u{2318}3": "macOS's key for a screenshot",
        "\u{21E7}\u{2318}4": "macOS's key for a screenshot",
        "\u{21E7}\u{2318}5": "macOS's key for a screenshot",
        "\u{2303}\u{2191}": "Mission Control",
        "\u{2303}\u{2193}": "macOS's key for an app's windows",
        "\u{2303}\u{2190}": "macOS's key for moving between desktops",
        "\u{2303}\u{2192}": "macOS's key for moving between desktops",
        "\u{21E7}\u{2318}N": "PARAGON's own quick capture",
    ]

    /// Keys that mean the same in nearly every app, or that macOS itself needs: refused.
    static let everyAppKeys: Set<String> = Set(
        ["Q", "W", "H", "M", "C", "V", "X", "Z", "A", "S", "N", "O", "P", "F", "T", ",", "Tab", "Space", "Return", "Delete", "Esc"]
            .map { "\u{2318}\($0)" }
        + ["\u{21E7}\u{2318}Z", "\u{21E7}\u{2318}Tab", "\u{2303}C", "\u{2325}\u{2318}Esc"]
    )

    /// The name of a key that has no letter of its own, by its number; nil for the others,
    /// whose name is the letter the keyboard gives.
    public static func specialName(forKeyCode code: UInt32) -> String? {
        switch code {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "\u{2190}"
        case 124: return "\u{2192}"
        case 125: return "\u{2193}"
        case 126: return "\u{2191}"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return nil
        }
    }
}
