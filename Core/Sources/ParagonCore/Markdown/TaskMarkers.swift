import Foundation

/// A place a task is tied to: `@place(Home|59.32940,18.06860|arrive)` (round 350).
///
/// The sync writes it into the task's reminder as a location alarm, so Apple Reminders itself
/// watches the place and rings on arriving or leaving. PARAGON never asks for the phone's
/// location for that. The marker is never part of a reminder's title.
public struct ReminderPlace: Equatable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// True: ring when you arrive. False: ring when you leave.
    public var arriving: Bool

    /// How close counts as "at the place", in metres. One value, so the app and Reminders agree.
    public static let radius: Double = 150

    public init(name: String, latitude: Double, longitude: Double, arriving: Bool = true) {
        self.name = ReminderPlace.cleanName(name)
        self.latitude = latitude
        self.longitude = longitude
        self.arriving = arriving
    }

    /// A name that can sit between the brackets: no brackets, no bars, no line breaks.
    public static func cleanName(_ raw: String) -> String {
        var text = raw
        for bad in ["(", ")", "|", "\n", "\r"] { text = text.replacingOccurrences(of: bad, with: " ") }
        return TaskParser.collapseWhitespace(text)
    }

    /// What is written between the brackets.
    public var markerText: String {
        let way: String = arriving ? "arrive" : "leave"
        return "\(name)|\(ReminderPlace.number(latitude)),\(ReminderPlace.number(longitude))|\(way)"
    }

    /// Reads the words between the brackets. Nil when they are not a place.
    public init?(marker: String) {
        let parts = marker.components(separatedBy: "|")
        guard parts.count == 3 else { return nil }
        let name = ReminderPlace.cleanName(parts[0])
        let coordinates = parts[1].components(separatedBy: ",")
        guard !name.isEmpty, coordinates.count == 2,
              let lat = Double(coordinates[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(coordinates[1].trimmingCharacters(in: .whitespaces)),
              lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        let way = parts[2].trimmingCharacters(in: .whitespaces).lowercased()
        guard way == "arrive" || way == "leave" else { return nil }
        self.init(name: name, latitude: lat, longitude: lon, arriving: way == "arrive")
    }

    /// Five decimals is about a metre: enough to be the same place, short enough to compare.
    static func number(_ value: Double) -> String {
        String(format: "%.5f", value)
    }

    /// For telling whether two sides say the same: name, rounded place and direction.
    public var fingerprint: String { markerText }

    /// The words on a task row.
    public var words: String { arriving ? "Arriving at \(name)" : "Leaving \(name)" }
}

/// `@person(Anna Svensson)`: the person a task is about (round 350).
public enum PersonName {
    /// A name that can sit between the brackets, or nil when nothing is left.
    public static func clean(_ raw: String) -> String? {
        var text = raw
        for bad in ["(", ")", "|", "\n", "\r", "#", "@", "^"] { text = text.replacingOccurrences(of: bad, with: " ") }
        let words = TaskParser.collapseWhitespace(text)
        return words.isEmpty ? nil : words
    }

    /// A key for telling whether two spellings are one person: lower case, no accents.
    public static func key(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }
}
