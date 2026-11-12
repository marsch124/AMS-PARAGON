import Foundation

/// Build 312 (premium review round 6, flow-19): **where a task row asks "How long?"**.
///
/// Until 312 every open task without a length showed the dashed question pill, on every list,
/// and each list read like a form with unanswered questions. The question is now asked only
/// where the length is used to plan: **Start the day** and **Plan the day**. Everywhere else a
/// row shows a time pill only once a time is set; giving one stays in the row's menu
/// (**How long**). With **Settings › Use task times** off nothing shows at all, as before.
public enum TaskTimePill {
    /// Where a task row is drawn.
    public enum Place: Sendable {
        /// **Start the day** and **Plan the day**: the two places a length is planned with.
        case startDay, plan
        /// Every other list: Today, Actions, a note's tasks, Close the day, Review, Search …
        case list
    }

    /// What the right end of an open task's row shows.
    public enum Shown: Equatable, Sendable {
        case nothing
        /// The dashed question.
        case question
        /// The solid pill with the task's own time.
        case time(Int)
    }

    public static func shown(in place: Place, minutes: Int?, usesTaskTimes: Bool) -> Shown {
        guard usesTaskTimes else { return .nothing }
        if let minutes { return .time(minutes) }
        return place == .list ? .nothing : .question
    }
}

/// Build 312 (flow-02): **the settings block at the top of a note starts folded.**
///
/// The block (`title:`, `type:`, `status:` …) was open on every note and took half an iPhone
/// screen; everything in it is already shown as chips above. A fresh install starts folded. An
/// install that already stored "open" (the old default wrote nothing, a press on the fold
/// wrote a value) is folded **once**, on the first start of this build; after that the fold is
/// whatever he last chose.
public enum SettingsBlockFold {
    /// The setting's own key, as `NoteEditorView` has stored it since build 246.
    public static let key = "frontmatterFolded"
    /// Set once the one-time fold of build 312 has been done.
    public static let flippedKey = "frontmatterFoldedSince312"

    /// Whether the block is folded. `stored` is nil when nothing was ever saved.
    public static func isFolded(stored: Bool?, flipped: Bool) -> Bool {
        guard flipped else { return true }
        return stored ?? true
    }
}
