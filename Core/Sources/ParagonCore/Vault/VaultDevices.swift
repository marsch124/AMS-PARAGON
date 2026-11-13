import Foundation

/// One device that has opened this vault with PARAGON 319 or newer (build 319). Each device
/// writes one small file of its own, `.ams-para/devices/<device id>.json`; files with
/// different names never fight in iCloud.
public struct VaultDevice: Codable, Equatable, Sendable {
    public var deviceID: String
    /// The device's own name, as its owner sees it ("Martin's iPhone").
    public var name: String
    public var build: Int
    /// "iPhone", "iPad" or "Mac".
    public var kind: String
    public var seenAt: Date

    public init(deviceID: String, name: String, build: Int, kind: String, seenAt: Date) {
        self.deviceID = deviceID
        self.name = name
        self.build = build
        self.kind = kind
        self.seenAt = seenAt
    }
}

/// **Which devices use this vault, and are they all on a build that understands a moved vault?**
/// Asked before a move is offered: a device on an older PARAGON keeps writing into the old
/// folder and knows nothing of the new one.
public enum VaultDevices {
    public static let folderName = "devices"
    /// A device that has not synced for this long is not counted: an old phone in a drawer
    /// must not hold the move up for ever.
    public static let recentDays = 60

    public struct Line: Equatable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var build: Int?
        public var lastSeen: Date?
        public var isReady: Bool
        public var isThisDevice: Bool

        /// "Martin's iPhone: build 319, seen 2026-11-13" / "A device that last synced on …".
        public var words: String {
            let day = lastSeen.map { VaultMove.day($0) }
            if let build {
                let seen = isThisDevice ? "this device" : (day.map { "seen \($0)" } ?? "seen")
                return "\(name): PARAGON \(build), \(seen)"
            }
            return "\(name): has not opened PARAGON \(VaultMove.firstBuild) or newer yet" + (day.map { ", last synced \($0)" } ?? "")
        }
    }

    /// The devices to show. Every device with a device file, plus every device known only by
    /// its Reminders memory that synced in the last `recentDays` days — those are the ones not
    /// updated yet. Not ready first, then by name.
    public static func lines(devices: [VaultDevice], syncStates: [(deviceID: String, modifiedAt: Date?)],
                             thisDeviceID: String, minimumBuild: Int = VaultMove.firstBuild,
                             now: Date = Date()) -> [Line] {
        var lines: [String: Line] = [:]
        for device in devices {
            if let known = lines[device.deviceID], (known.lastSeen ?? .distantPast) >= device.seenAt { continue }
            lines[device.deviceID] = Line(id: device.deviceID, name: device.name, build: device.build, lastSeen: device.seenAt,
                                          isReady: device.build >= minimumBuild, isThisDevice: device.deviceID == thisDeviceID)
        }
        let limit = now.addingTimeInterval(-Double(recentDays) * 86_400)
        for state in syncStates where lines[state.deviceID] == nil && state.deviceID != thisDeviceID {
            guard let modified = state.modifiedAt, modified >= limit else { continue }
            lines[state.deviceID] = Line(id: state.deviceID, name: "Another device", build: nil, lastSeen: modified,
                                         isReady: false, isThisDevice: false)
        }
        return lines.values.sorted {
            if $0.isReady != $1.isReady { return !$0.isReady }
            if $0.isThisDevice != $1.isThisDevice { return $0.isThisDevice }
            return ($0.name, $0.id) < ($1.name, $1.id)
        }
    }

    public static func allReady(_ lines: [Line]) -> Bool { lines.allSatisfy(\.isReady) }
}

public extension Vault {
    var devicesURL: URL { stateFolderURL.appendingPathComponent(VaultDevices.folderName, isDirectory: true) }

    /// Notes that this device uses the vault. Written when the file is not there, when the
    /// build or the name changed, or once a day; otherwise nothing is written. True when a
    /// file was written.
    @discardableResult
    func noteDevice(_ device: VaultDevice) -> Bool {
        let url = devicesURL.appendingPathComponent("\(Vault.sanitizeFileName(device.deviceID)).json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if CloudFiles.exists(url) {
            // Still in iCloud: it is there, and this is not the moment to write over it.
            guard let data = try? CloudFiles.read(url, waitingUpTo: 0) else { return false }
            if let known = try? decoder.decode(VaultDevice.self, from: data),
               known.build == device.build, known.name == device.name, known.kind == device.kind,
               device.seenAt.timeIntervalSince(known.seenAt) < 86_400 { return false }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: devicesURL, withIntermediateDirectories: true)
            try encoder.encode(device).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// The devices that have noted themselves. A file still in iCloud is left out (and asked for).
    func devices() -> [VaultDevice] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: devicesURL.path)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return Set(names.map { CloudFiles.realName(ofPlaceholder: $0) ?? $0 }).sorted().compactMap { name in
            guard name.hasSuffix(".json"),
                  let data = try? CloudFiles.read(devicesURL.appendingPathComponent(name), waitingUpTo: 0) else { return nil }
            return try? decoder.decode(VaultDevice.self, from: data)
        }
    }

    /// The devices to show before a move.
    func deviceLines(thisDeviceID: String, now: Date = Date()) -> [VaultDevices.Line] {
        let states = otherSyncStateFiles(currentDeviceID: thisDeviceID).map { (deviceID: $0.deviceName, modifiedAt: $0.modifiedAt) }
        return VaultDevices.lines(devices: devices(), syncStates: states, thisDeviceID: thisDeviceID, now: now)
    }
}
