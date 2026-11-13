import Foundation

/// A Reminders list he chose to keep apart from the note with the same name (build 315).
/// Remembered by the list's own identity in Reminders; the name is kept for showing it in
/// Settings and for a device on which that list carries another identity.
public struct KeptApartList: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The list's calendar identifier in Reminders.
    public var id: String
    /// The list's name when it was set apart.
    public var name: String
    /// The device on which it was set apart (review round 8). Nil when not known.
    public var device: String?

    public init(id: String, name: String, device: String? = nil) {
        self.id = id
        self.name = name
        self.device = device
    }
}

/// The rule for "Keep them apart" (build 315): the sync asked about a note named like a
/// Reminders list that PARAGON did not make, and he answered that the two are not the same
/// thing. The list is remembered in the vault's settings (`VaultConfig.listsKeptApart`), so
/// both devices know; the sync then leaves the note and the list alone and never asks again.
public enum ListsKeptApart {
    /// Whether the list called `name`, which carries `ids` on this device (two lists can share
    /// a name), is kept apart. It is when one of its identities is remembered.
    ///
    /// The name decides only on **another** device than the one that remembered it: there the
    /// same list can be known under another identity. On the device that remembered it the
    /// identity is the whole answer (review round 8): once that list is deleted, a later list
    /// with the same name is a new list, and the sync asks about it again.
    public static func isKeptApart(name: String, ids: [String], deviceListIDs: Set<String>,
                                   deviceID: String, in kept: [KeptApartList]) -> Bool {
        kept.contains { entry in
            if ids.contains(entry.id) { return true }
            if entry.device == deviceID, !entry.id.isEmpty { return false }
            return entry.name == name && !deviceListIDs.contains(entry.id)
        }
    }

    /// `kept` without the entries this device remembered for a list that is no longer in
    /// Reminders here. Entries of other devices stay: only they know whether their list lives.
    /// With no lists at all (Reminders could not be read) nothing is dropped.
    public static func droppingDeleted(deviceID: String, deviceListIDs: Set<String>,
                                       from kept: [KeptApartList]) -> [KeptApartList] {
        guard !deviceListIDs.isEmpty else { return kept }
        return kept.filter { $0.device != deviceID || $0.id.isEmpty || deviceListIDs.contains($0.id) }
    }

    /// `kept` with one more list. The same identity is never remembered twice; a list set
    /// apart again under a new name takes that name.
    public static func adding(id: String, name: String, device: String? = nil, to kept: [KeptApartList]) -> [KeptApartList] {
        guard !id.isEmpty || !name.isEmpty else { return kept }
        var result = kept.filter { $0.id != id }
        result.append(KeptApartList(id: id, name: name, device: device))
        return result.sorted { ($0.name.lowercased(), $0.id) < ($1.name.lowercased(), $1.id) }
    }

    /// `kept` without that list: "Connect again". The next sync asks about it as before.
    public static func removing(_ entry: KeptApartList, from kept: [KeptApartList]) -> [KeptApartList] {
        kept.filter { $0 != entry }
    }
}
