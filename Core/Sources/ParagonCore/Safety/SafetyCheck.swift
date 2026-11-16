import Foundation

/// **Is everything safe?** (build 326). One page in Settings that only looks and changes
/// nothing: which devices use these notes and on which build, when the copies were last made,
/// whether a conflict copy is lying about, and how the last sync went. Each line is either
/// fine or "needs a look"; the summary counts the second kind.
///
/// Why the builds matter: a device on an older PARAGON can rewrite a task line and drop what
/// only the newer build knows (build 316's new repeats were lost that way by a 315 device).
public enum SafetyCheck {
    /// A copy older than this many days needs a look. The app makes both copies once a day.
    public static let copyDays = 2

    public enum Kind: String, Sendable, CaseIterable {
        case devices, insideCopy, outsideCopy, conflictCopies, sync

        public var title: String {
            switch self {
            case .devices: return "Devices"
            case .insideCopy: return "Copies in the notes folder"
            case .outsideCopy: return "Second copy, outside"
            case .conflictCopies: return "Conflict copies"
            case .sync: return "Reminders sync"
            }
        }
    }

    public struct Line: Equatable, Sendable, Identifiable {
        public var kind: Kind
        public var needsALook: Bool
        /// One sentence: "All 3 devices run PARAGON 326."
        public var words: String
        /// Smaller lines under it: one per device, or the conflict copies' names.
        public var details: [String]
        public var id: String { kind.rawValue }

        public init(kind: Kind, needsALook: Bool, words: String, details: [String] = []) {
            self.kind = kind
            self.needsALook = needsALook
            self.words = words
            self.details = details
        }
    }

    /// What the page is told. Nothing in here is read from disk by the rule itself.
    public struct Facts: Sendable {
        /// Every device that has noted itself in the vault, this one included or not.
        public var devices: [VaultDevice]
        public var thisDeviceID: String
        public var thisDeviceName: String
        public var thisBuild: Int
        public var newestInsideCopy: Date?
        public var newestOutsideCopy: Date?
        /// Paths of every note in the vault, relative to its root.
        public var notePaths: [String]
        public var lastSync: Date?
        public var syncConflicts: Int
        public var now: Date

        public init(devices: [VaultDevice], thisDeviceID: String, thisDeviceName: String, thisBuild: Int,
                    newestInsideCopy: Date?, newestOutsideCopy: Date?, notePaths: [String],
                    lastSync: Date?, syncConflicts: Int, now: Date = Date()) {
            self.devices = devices
            self.thisDeviceID = thisDeviceID
            self.thisDeviceName = thisDeviceName
            self.thisBuild = thisBuild
            self.newestInsideCopy = newestInsideCopy
            self.newestOutsideCopy = newestOutsideCopy
            self.notePaths = notePaths
            self.lastSync = lastSync
            self.syncConflicts = syncConflicts
            self.now = now
        }
    }

    public static func lines(_ facts: Facts, calendar: Calendar = DayWords.here) -> [Line] {
        [devices(facts, calendar: calendar),
         copy(.insideCopy, made: facts.newestInsideCopy, now: facts.now, calendar: calendar),
         copy(.outsideCopy, made: facts.newestOutsideCopy, now: facts.now, calendar: calendar),
         conflictCopies(facts.notePaths),
         sync(facts, calendar: calendar)]
    }

    public static func thingsToLookAt(_ lines: [Line]) -> Int { lines.filter(\.needsALook).count }

    /// "Everything is safe" / "1 thing to look at" / "3 things to look at".
    public static func summary(_ lines: [Line]) -> String {
        let count = thingsToLookAt(lines)
        switch count {
        case 0: return "Everything is safe"
        case 1: return "1 thing to look at"
        default: return "\(count) things to look at"
        }
    }

    // MARK: Devices

    /// The devices that count: this one, and every other seen in the last
    /// `VaultDevices.recentDays` days. Newest file wins when a device shows up twice.
    static func counted(_ facts: Facts) -> [VaultDevice] {
        let limit = facts.now.addingTimeInterval(-Double(VaultDevices.recentDays) * 86_400)
        var byID: [String: VaultDevice] = [:]
        for device in facts.devices where device.deviceID != facts.thisDeviceID && device.seenAt >= limit {
            if let known = byID[device.deviceID], known.seenAt >= device.seenAt { continue }
            byID[device.deviceID] = device
        }
        let this = VaultDevice(deviceID: facts.thisDeviceID, name: facts.thisDeviceName, build: facts.thisBuild,
                               kind: "", seenAt: facts.now)
        return [this] + byID.values.sorted { ($0.name, $0.deviceID) < ($1.name, $1.deviceID) }
    }

    static func devices(_ facts: Facts, calendar: Calendar) -> Line {
        let all = counted(facts)
        let newest = all.map(\.build).max() ?? facts.thisBuild
        let behind = all.filter { $0.build < newest }
        let details = all.map { device -> String in
            let seen = device.deviceID == facts.thisDeviceID ? "this device" : "seen \(DayWords.plain(device.seenAt, calendar: calendar))"
            return "\(device.name): PARAGON \(device.build), \(seen)"
        }
        if all.count == 1 {
            return Line(kind: .devices, needsALook: false,
                        words: "Only this device uses these notes (PARAGON \(facts.thisBuild)).", details: [])
        }
        if behind.isEmpty {
            return Line(kind: .devices, needsALook: false,
                        words: "All \(all.count) devices run PARAGON \(newest).", details: details)
        }
        let words: String
        if behind.count == 1, let old = behind.first {
            if old.deviceID == facts.thisDeviceID {
                let ahead = all.first { $0.build == newest }?.name ?? "another device"
                words = "This device runs PARAGON \(old.build), \(ahead) runs \(newest). Update this device in TestFlight."
            } else {
                words = "\(old.name) runs PARAGON \(old.build), the newest here is \(newest). Update \(old.name) in TestFlight."
            }
        } else {
            words = "\(behind.count) devices run an older PARAGON than \(newest). Update them in TestFlight."
        }
        return Line(kind: .devices, needsALook: true, words: words, details: details)
    }

    // MARK: Copies

    static func copy(_ kind: Kind, made: Date?, now: Date, calendar: Calendar) -> Line {
        guard let made else {
            return Line(kind: kind, needsALook: true, words: "No copy has been made yet.")
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: made), to: calendar.startOfDay(for: now)).day ?? 0
        let when = DayWords.plainWithTime(made, calendar: calendar)
        if days > copyDays {
            return Line(kind: kind, needsALook: true, words: "The newest copy is \(days) days old (\(when)).")
        }
        return Line(kind: kind, needsALook: false, words: "Newest copy: \(when).")
    }

    // MARK: Conflict copies

    /// Notes that are a second version of another note: the app's own
    /// "Name (conflict 2026-11-16 0752).md", and iCloud's doubled files, "Name 2.md" beside
    /// "Name.md". A note that only ends in a number ("Chapter 2", no "Chapter" beside it) is
    /// an ordinary note. Sorted by path.
    public static func strayCopies(among paths: [String]) -> [String] {
        let known = Set(paths.map { $0.lowercased() })
        return paths.filter { path in
            if Note(relativePath: path, kind: .resource).isConflictCopy { return true }
            let ns = path as NSString
            let ext = ns.pathExtension
            let base = ns.deletingPathExtension
            guard let space = base.lastIndex(of: " ") else { return false }
            let tail = base[base.index(after: space)...]
            guard tail.count == 1, let number = Int(tail), number >= 2 else { return false }
            let twin = String(base[base.startIndex..<space]) + (ext.isEmpty ? "" : "." + ext)
            return known.contains(twin.lowercased())
        }.sorted()
    }

    static func conflictCopies(_ paths: [String]) -> Line {
        let strays = strayCopies(among: paths)
        guard !strays.isEmpty else {
            return Line(kind: .conflictCopies, needsALook: false, words: "No conflict copies.")
        }
        let names = strays.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
        let words = strays.count == 1 ? "1 conflict copy in your notes." : "\(strays.count) conflict copies in your notes."
        return Line(kind: .conflictCopies, needsALook: true, words: words, details: names)
    }

    // MARK: Sync

    static func sync(_ facts: Facts, calendar: Calendar) -> Line {
        if facts.syncConflicts > 0 {
            let words = facts.syncConflicts == 1 ? "The last sync had 1 conflict." : "The last sync had \(facts.syncConflicts) conflicts."
            return Line(kind: .sync, needsALook: true, words: words)
        }
        guard let last = facts.lastSync else {
            return Line(kind: .sync, needsALook: false, words: "Not synced yet since PARAGON was opened.")
        }
        return Line(kind: .sync, needsALook: false, words: "Last sync: \(DayWords.plainWithTime(last, calendar: calendar)), no conflicts.")
    }
}
