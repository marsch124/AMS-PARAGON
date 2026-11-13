import AppIntents
import ParagonCore

/// An open task, as **Start focus** offers it in Shortcuts (build 317).
///
/// **Found again by its own mark, not by its place.** A synced task carries a hidden mark
/// (`^t…`) that stays with it when lines are added above it; that mark is the identity. Only a
/// task with no mark yet falls back to its note and line.
struct FocusTaskEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task")
    static let defaultQuery = FocusTaskQuery()

    var id: String
    var title: String
    var noteTitle: String
    var due: String?

    var displayRepresentation: DisplayRepresentation {
        let second = due.map { "\(noteTitle) \u{00B7} \($0)" } ?? noteTitle
        return DisplayRepresentation(title: "\(title)", subtitle: "\(second)")
    }

    init(_ ref: TaskRef) {
        id = Self.identity(of: ref)
        title = DueTodayAnswer.spokenTitle(ref.task)
        noteTitle = ref.noteTitle
        due = ref.task.dueDate.map { DayWords.plain($0) }
    }

    static func identity(of ref: TaskRef) -> String {
        if let mark = ref.task.id, !mark.isEmpty { return "t:" + mark }
        return "l:" + ref.id
    }

    /// The open task with this identity, as the vault is now.
    @MainActor
    static func ref(for identity: String, in model: AppModel) -> TaskRef? {
        model.index.openTasks().first { Self.identity(of: $0) == identity }
    }
}

struct FocusTaskQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [FocusTaskEntity] {
        let model = AppModel.shared
        let open = model.index.openTasks()
        return identifiers.compactMap { wanted in
            open.first { FocusTaskEntity.identity(of: $0) == wanted }.map(FocusTaskEntity.init)
        }
    }

    /// Due today and overdue first, then each project's next action.
    @MainActor
    func suggestedEntities() async throws -> [FocusTaskEntity] {
        AppModel.shared.focusSuggestions().map(FocusTaskEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [FocusTaskEntity] {
        AppModel.shared.focusMatches(string).map(FocusTaskEntity.init)
    }
}
