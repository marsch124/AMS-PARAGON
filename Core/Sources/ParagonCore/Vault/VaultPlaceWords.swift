import Foundation

/// **Where the vault is, in plain words** (round 9, build 316): Settings › Vault used to show
/// the raw folder path ("/Users/…/Library/Mobile Documents/com~apple~CloudDocs/…"). It now
/// shows the folder's name and one of three places. The path itself is never shown.
public enum VaultPlaceWords {
    /// The folder's own name: the last part of its path.
    public static func name(path: String) -> String {
        // Build 319: PARAGON's own iCloud folder is "Documents" on disk and "PARAGON" in Files
        // and Finder; he is told the name he sees.
        if isOwnFolder(path: path) { return "PARAGON" }
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }

    /// True for the `Documents` folder of the app's own iCloud container.
    public static func isOwnFolder(path: String) -> Bool {
        let folder = VaultMove.containerID.replacingOccurrences(of: ".", with: "~")
        return path.hasSuffix("/Mobile Documents/\(folder)/Documents") || path.hasSuffix("/Mobile Documents/\(folder)/Documents/")
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
