import Foundation

/// A Reminders list he chose to keep apart from the note with the same name (build 315).
/// Remembered by the list's own identity in Reminders; the name is kept for showing it in
/// Settings and for a device on which that list carries another identity.
public struct KeptApartList: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The list's calendar identifier in Reminders.
    public var id: String
    /// The list's name when it was set apart.
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// The rule for "Keep them apart" (build 315): the sync asked about a note named like a
/// Reminders list that PARAGON did not make, and he answered that the two are not the same
/// thing. The list is remembered in the vault's settings (`VaultConfig.listsKeptApart`), so
/// both devices know; the sync then leaves the note and the list alone and never asks again.
public enum ListsKeptApart {
    /// Whether the list called `name`, which carries `ids` on this device (two lists can share
    /// a name), is kept apart. It is when one of its identities is remembered. A remembered
    /// identity that no list on this device has was remembered on the other device, where the
    /// same list can be known under another identity: then the name decides.
    public static func isKeptApart(name: String, ids: [String], deviceListIDs: Set<String>,
                                   in kept: [KeptApartList]) -> Bool {
        kept.contains { entry in
            if ids.contains(entry.id) { return true }
            return entry.name == name && !deviceListIDs.contains(entry.id)
        }
    }

    /// `kept` with one more list. The same identity is never remembered twice; a list set
    /// apart again under a new name takes that name.
    public static func adding(id: String, name: String, to kept: [KeptApartList]) -> [KeptApartList] {
        guard !id.isEmpty || !name.isEmpty else { return kept }
        var result = kept.filter { $0.id != id }
        result.append(KeptApartList(id: id, name: name))
        return result.sorted { ($0.name.lowercased(), $0.id) < ($1.name.lowercased(), $1.id) }
    }

    /// `kept` without that list: "Connect again". The next sync asks about it as before.
    public static func removing(_ entry: KeptApartList, from kept: [KeptApartList]) -> [KeptApartList] {
        kept.filter { $0 != entry }
    }
}
