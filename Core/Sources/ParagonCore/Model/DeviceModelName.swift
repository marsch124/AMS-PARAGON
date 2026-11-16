import Foundation

/// A device's model in words, from Apple's model code (build 325). iOS gives apps only
/// "iPhone" or "iPad" as a device's name, so the list of devices said "iPhone" for every
/// iPhone. The model tells his devices apart; an unknown code falls back to the plain kind.
public enum DeviceModelName {
    static let known: [String: String] = [
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
        "iPhone19,1": "iPhone 18", "iPhone19,2": "iPhone 18 Pro",
        "iPad14,1": "iPad mini", "iPad14,2": "iPad mini",
        "iPad16,1": "iPad mini", "iPad16,2": "iPad mini",
    ]

    /// "iPhone 17 Pro" for "iPhone18,1"; any other iPad mini/Air/Pro code by its family is not
    /// guessed: the plain kind ("iPhone", "iPad") is the answer.
    public static func friendly(machine: String, kind: String) -> String {
        known[machine] ?? kind
    }
}
