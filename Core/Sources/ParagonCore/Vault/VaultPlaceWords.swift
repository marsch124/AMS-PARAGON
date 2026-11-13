import Foundation

/// **Where the vault is, in plain words** (round 9, build 316): Settings › Vault used to show
/// the raw folder path ("/Users/…/Library/Mobile Documents/com~apple~CloudDocs/…"). It now
/// shows the folder's name and one of three places. The path itself is never shown.
public enum VaultPlaceWords {
    /// The folder's own name: the last part of its path.
    public static func name(path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }

    /// "in iCloud Drive", "in Dropbox", or "on <device>" for anywhere else.
    public static func place(path: String, device: String) -> String {
        if path.contains("/Mobile Documents/") { return "in iCloud Drive" }
        if path.range(of: "/Dropbox", options: .caseInsensitive) != nil
            || path.contains("/CloudStorage/Dropbox") { return "in Dropbox" }
        return "on \(device)"
    }

    /// "My Vault · in iCloud Drive".
    public static func line(path: String, device: String) -> String {
        "\(name(path: path)) \u{00B7} \(place(path: path, device: device))"
    }
}
