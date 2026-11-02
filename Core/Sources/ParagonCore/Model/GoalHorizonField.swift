import Foundation

/// A goal with a date can say how far ahead it reaches: **This year** or **Long term**
/// (build 276). The line is `horizon:` in the settings block.
///
/// **The most repeated fault in this project, once more.** The Goals lists, the review and the
/// note's header all read `horizon:`, and until this build only the New note screen wrote it —
/// once, when the goal was made. The same fault as `due:` (132), an area's `goal:` (134), a
/// project's `goal:` (140), `tags:` (144), `status:` (165) and `measure:` (268). The goal's
/// header now has a button for it, and this is what the button writes.
///
/// In Core, with tests, because it decides what is stored. The rules:
/// - **Only a goal with a date has the choice.** An aspiration (`horizon: life`) is a different
///   thing and lives in the other room: switching it would move the note between **Aspirations**
///   and **Goals** behind his back, so asking for it changes nothing, and so does asking a note
///   of any other kind. `.life` can never be written from here either.
/// - **A line that is missing is written when it is chosen.** A goal with no `horizon:` line
///   reads as **This year**, so the button already shows it ticked. Pressing **This year** on it
///   writes `horizon: year` all the same, so the file says what the screen says. A line that
///   already says the value, in any capitals, is left exactly as it is.
/// - **The line is never removed.** There are two choices and the file always holds one.
public extension GoalFields {
    /// The settings key for the horizon.
    static let horizonKey = "horizon"

    /// The two horizons a goal with a date can have, in the order the button offers them.
    static let datedHorizons: [GoalHorizon] = [.year, .long]
}

public extension Note {
    /// The note with its horizon set to `horizon`, or the note as it was when there is nothing
    /// to change: the value is already written, the note is not a goal with a date, or the
    /// value asked for is `.life`.
    func settingHorizon(_ horizon: GoalHorizon) -> Note {
        // `.life` is the aspiration. It is a different thing, not a longer horizon.
        guard horizon != .life else { return self }
        // `self.horizon` is nil for every note that is not a goal, and `.life` for an aspiration.
        guard kind == .goal, let current = self.horizon, current != .life else { return self }
        let written = frontmatter.string(GoalFields.horizonKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if written == horizon.rawValue { return self }
        var updated = self
        updated.frontmatter.set(GoalFields.horizonKey, horizon.rawValue)
        return updated
    }
}
