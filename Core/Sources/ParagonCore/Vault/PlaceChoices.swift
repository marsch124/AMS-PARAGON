import Foundation

/// A ready-made place for **Remind me at a place…** (round 352): one already used on a task
/// (`@place(Name|lat,lon|arrive)`), or the **Home** and **Work** set once in Settings.
///
/// Pressing one fills the choice the way a search answer does, so the user does not have to
/// search for the same shop again.
public struct KnownPlace: Identifiable, Equatable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// Words under the name: the address saved with Home or Work. Empty for a used place.
    public var address: String

    public init(name: String, latitude: Double, longitude: Double, address: String = "") {
        self.name = ReminderPlace.cleanName(name)
        self.latitude = latitude
        self.longitude = longitude
        self.address = ReminderPlace.cleanName(address)
    }

    /// The position to about a metre, the way the task line writes it.
    public var spot: String { "\(ReminderPlace.number(latitude)),\(ReminderPlace.number(longitude))" }

    /// One place: the name (any capitals, any accents) and the position.
    public var id: String { "\(PersonName.key(name))|\(spot)" }

    /// The place on a task, arriving or leaving.
    public func reminder(arriving: Bool) -> ReminderPlace {
        ReminderPlace(name: name, latitude: latitude, longitude: longitude, arriving: arriving)
    }
}

/// **Home** and **Work**, set once per device in Settings (round 352). Stored in `UserDefaults`
/// as `address|lat,lon`; the chip is called by its label, not by the address.
public enum SavedPlace: String, CaseIterable, Sendable, Identifiable {
    case home
    case work

    public var id: String { rawValue }

    /// The word on the chip and in Settings.
    public var label: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        }
    }

    /// The `UserDefaults` key on this device.
    public var defaultsKey: String { "reminderPlace.\(rawValue)" }

    /// What is stored: `address|lat,lon`. The address is cleaned, so it holds no bar.
    public static func stored(address: String, latitude: Double, longitude: Double) -> String {
        let words: String = ReminderPlace.cleanName(address)
        return "\(words)|\(ReminderPlace.number(latitude)),\(ReminderPlace.number(longitude))"
    }

    /// The place read back, named by the label. Nil when nothing (or nothing readable) is stored.
    public func read(_ text: String?) -> KnownPlace? {
        guard let text, let bar = text.lastIndex(of: "|") else { return nil }
        let address = String(text[..<bar])
        let coordinates = text[text.index(after: bar)...].components(separatedBy: ",")
        guard coordinates.count == 2,
              let lat = Double(coordinates[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(coordinates[1].trimmingCharacters(in: .whitespaces)),
              lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return KnownPlace(name: label, latitude: lat, longitude: lon, address: address)
    }
}

public enum PlaceChoices {
    /// How many chips are shown at most.
    public static let shownAtOnce = 8

    /// The chips above the search field: Home, Work (when set), then the places already used,
    /// most used first. A used place at the very spot of Home or Work is not shown twice.
    public static func chips(home: KnownPlace?, work: KnownPlace?, used: [KnownPlace],
                             limit: Int = PlaceChoices.shownAtOnce) -> [KnownPlace] {
        var result: [KnownPlace] = []
        var spots = Set<String>()
        let saved: [KnownPlace] = [home, work].compactMap { $0 }
        for place in saved {
            if spots.insert(place.spot).inserted { result.append(place) }
        }
        for place in used where !spots.contains(place.spot) {
            result.append(place)
        }
        return Array(result.prefix(max(0, limit)))
    }
}

public extension NoteIndex {
    /// Every place written on a task (`@place(…)`), open or done, one entry per place: the most
    /// used first, then A to Z. The spelling first met is the one kept.
    func usedPlaces(limit: Int = PlaceChoices.shownAtOnce) -> [KnownPlace] {
        var counts: [String: Int] = [:]
        var first: [String: KnownPlace] = [:]
        var order: [String] = []
        for note in notes {
            for task in note.tasks {
                guard let place = task.place else { continue }
                let known = KnownPlace(name: place.name, latitude: place.latitude, longitude: place.longitude)
                let key = known.id
                if first[key] == nil {
                    first[key] = known
                    order.append(key)
                }
                counts[key, default: 0] += 1
            }
        }
        let sorted: [String] = order.sorted { left, right in
            let a = counts[left] ?? 0
            let b = counts[right] ?? 0
            if a != b { return a > b }
            return left < right
        }
        return sorted.prefix(max(0, limit)).compactMap { first[$0] }
    }
}
