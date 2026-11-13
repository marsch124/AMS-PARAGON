import Foundation

/// One identity a vault has had, and when it was made (round 9, build 316).
public struct VaultIDRecord: Equatable, Sendable {
    public var id: String
    public var created: Date

    public init(id: String, created: Date) {
        self.id = id
        self.created = created
    }
}

/// **Which identity a vault keeps when it was given two** (round 9, build 316).
///
/// Build 315 made the identity on the first outside copy. Two devices that each made that copy
/// before iCloud had carried `vault-id.txt` across made two identities; iCloud then kept one
/// file, and the copies the other device had marked looked like another vault's.
///
/// The rule: every identity is remembered as a file of its own in `.ams-para/vault-ids`, named
/// `<when it was made>~<identity>.txt`. Files with different names never fight in iCloud, so
/// both devices end up seeing both. **The oldest one is the vault's identity**; when two are
/// equally old, the one that sorts first. Every other one stays known as an older name of the
/// same vault, so a copy marked with it still counts as this vault's.
public enum VaultIDs {
    public static let folderName = "vault-ids"

    /// The made-on day given to an identity from build 315, which wrote none: the day build 315
    /// came out (2026-11-13, 00:00 UTC). The same on every device, so two devices that note the
    /// same old identity write the same file name.
    public static let unrecordedCreated = Date(timeIntervalSince1970: 1_794_528_000)

    /// What a record file holds. The name carries everything; the words are for a person.
    public static let fileText = "PARAGON: a name this vault has had for its outside copies. Please leave this file.\n"

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Only an identity shaped like the ones PARAGON makes gets a record and a sub-folder.
    public static func isWellFormed(_ id: String) -> Bool {
        id.count == 36 && UUID(uuidString: id) != nil
    }

    public static func fileName(for record: VaultIDRecord) -> String {
        "\(stampFormatter.string(from: record.created))~\(record.id).txt"
    }

    /// The record a file name stands for, or nil. Reads the 36 letters after the `~` only, so
    /// a copy iCloud renamed ("… 2.txt") and a placeholder's real name still count.
    public static func record(fromFileName name: String) -> VaultIDRecord? {
        let parts = name.split(separator: "~", maxSplits: 1).map(String.init)
        guard parts.count == 2, let created = stampFormatter.date(from: parts[0]) else { return nil }
        let id = String(parts[1].prefix(36))
        guard isWellFormed(id) else { return nil }
        return VaultIDRecord(id: id, created: created)
    }

    /// **The rule.** The identity the vault keeps: the oldest; of equally old ones, the one that
    /// sorts first. An identity noted twice counts with its oldest day. Nil for no records.
    public static func winner(of records: [VaultIDRecord]) -> String? {
        var oldest: [String: Date] = [:]
        for record in records {
            if let known = oldest[record.id], known <= record.created { continue }
            oldest[record.id] = record.created
        }
        return oldest.min { a, b in a.value != b.value ? a.value < b.value : a.key < b.key }?.key
    }
}
