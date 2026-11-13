import Foundation

/// The one key that opens quick capture from any app on the Mac (review round 8, build 315).
///
/// Chosen in Settings and **off until he chooses one**: a key that works in every app is his to
/// hand out. Kept per Mac in the app's settings under `storageKey`, never in the vault. The
/// numbers are the ones macOS's hot-key call wants (Carbon), written here so the choice, its
/// words and its key cannot drift apart.
public enum CaptureHotKey: String, CaseIterable, Sendable, Identifiable {
    case off
    case controlOptionSpace
    case controlShiftSpace
    case controlOptionCommandSpace
    /// A key he recorded himself (build 316): which one is in `RecordedKey`, not here.
    case custom

    public static let storageKey = "captureHotKey"

    public var id: String { rawValue }

    /// What is stored, read back. Nothing stored, or a word this build does not know, is off.
    public static func stored(_ raw: String?) -> CaptureHotKey {
        raw.flatMap(CaptureHotKey.init(rawValue:)) ?? .off
    }

    /// The words in the Settings list.
    public var label: String {
        switch self {
        case .off: return "Off"
        case .controlOptionSpace: return "\u{2303}\u{2325}Space"
        case .controlShiftSpace: return "\u{2303}\u{21E7}Space"
        case .controlOptionCommandSpace: return "\u{2303}\u{2325}\u{2318}Space"
        case .custom: return "My own key"
        }
    }

    /// The three fixed keys and Off: what the Settings list always offers.
    public static let fixedChoices: [CaptureHotKey] = [.off, .controlOptionSpace, .controlShiftSpace, .controlOptionCommandSpace]

    /// The key's number on the keyboard (Space is 49), or nil when off. Nil for his own key
    /// too: its number is in `RecordedKey`.
    public var keyCode: UInt32? { self == .off || self == .custom ? nil : 49 }

    /// The held keys, in Carbon's numbers: Command 0x100, Shift 0x200, Option 0x800, Control 0x1000.
    public var modifiers: UInt32 {
        switch self {
        case .off, .custom: return 0
        case .controlOptionSpace: return 0x1000 | 0x800
        case .controlShiftSpace: return 0x1000 | 0x200
        case .controlOptionCommandSpace: return 0x1000 | 0x800 | 0x100
        }
    }
}
