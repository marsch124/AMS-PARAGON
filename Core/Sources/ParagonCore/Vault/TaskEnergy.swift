import Foundation

/// **How much effort a task takes** (round 350, pick 44): one of three tags on the task's own
/// line, `#easy`, `#medium` or `#hard`. One at a time. Written the way `#next` and `#someday`
/// are, so an older build keeps them, the Reminders sync carries them in the title and he can
/// type one by hand. The three words are the app's own: the Tags screen may not rename or remove
/// them (`TaskEnergy.isEnergyTag`), as it may not `#next` or `#waiting`.
public enum TaskEnergy: String, CaseIterable, Sendable, Identifiable, Codable {
    case easy, medium, hard

    public var id: String { rawValue }

    /// The tag, without `#`.
    public var tag: String { rawValue }

    /// The word on a button and in the menu.
    public var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// Whether `tag` (with or without `#`, any capitals) is one of the three.
    public static func isEnergyTag(_ tag: String) -> Bool {
        let name = NoteIndex.normalized(tag)
        return allCases.contains { $0.tag == name }
    }
}

public extension TaskItem {
    /// The energy the task is marked with. If a hand-typed line carries two, the easiest wins,
    /// so the answer never depends on the order the words were written in.
    var energy: TaskEnergy? {
        let names = Set(tags.map { NoteIndex.normalized($0) })
        return TaskEnergy.allCases.first { names.contains($0.tag) }
    }

    /// The task with exactly this energy: every other energy tag is taken off, the chosen one
    /// is put at the end of the title. Nil takes them all off. The same choice again changes
    /// nothing, so a press that changes nothing writes nothing.
    func settingEnergy(_ energy: TaskEnergy?) -> TaskItem {
        let own: [String] = tags.filter { TaskEnergy.isEnergyTag($0) }.map { NoteIndex.normalized($0) }
        let wanted: [String] = energy == nil ? [] : [energy!.tag]
        if own == wanted { return self }
        var task = self
        let words: [Substring] = task.title.split(separator: " ")
        let kept: [Substring] = words.filter { word in
            guard word.hasPrefix("#") else { return true }
            return !TaskEnergy.isEnergyTag(String(word))
        }
        var title: String = kept.joined(separator: " ")
        if let energy = energy {
            title = title.isEmpty ? "#" + energy.tag : title + " #" + energy.tag
        }
        task.title = title
        return TaskParser.normalized(task)
    }
}
