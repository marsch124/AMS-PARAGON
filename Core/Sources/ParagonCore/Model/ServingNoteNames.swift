import Foundation

/// What to do with a name typed into the **Add goal**, **Add aspiration** or **Add area**
/// field of a list on the New note screen (build 272).
///
/// **The box asks before it writes**, because the only other way to learn that a name is
/// taken is `Vault.createNote` throwing, and the app answers a throw with an alert. An alert
/// raised behind a popover is two presentations at once (builds 238 and 246), and the box
/// has the owner's words still in it. So this decides, in Core where it can be tested, which
/// of four things is true, and the box says the right one in its own place.
public enum NameCheck: Equatable, Sendable {
    /// Nothing goes by that name: make the note.
    case free
    /// A live note of the kind being made already has the name: choose it, make nothing.
    case choose(Note)
    /// A goal of the **other** kind has the name. Aspirations and goals with a date share the
    /// `Goals` folder, so the two would be one file name and the vault refuses the second.
    /// It cannot be chosen either: it is not what the list is for.
    case otherKind(Note)
    /// A note of the right kind has the name but has ended or been put away, so the list does
    /// not offer it. Choosing it would set a value the chip cannot show. Said, not guessed.
    case ended(Note)
}

public extension ServingNote {
    /// The check for **Add goal** (a goal with a date) and **Add aspiration**.
    ///
    /// Only goal notes are looked at: a project or an area with the same name has its own
    /// folder and is no obstacle. `existing(named:kind:among:)` does the matching (title or
    /// file name, capitals ignored); it is asked about each kind of goal on its own so that
    /// a goal of the right kind is found first, whatever order the notes come in.
    static func check(goalNamed name: String, horizon: GoalHorizon, among notes: [Note]) -> NameCheck {
        let wantsAspiration = horizon == .life
        func isAspiration(_ note: Note) -> Bool { (note.horizon ?? .year) == .life }
        let sameKind = notes.filter { $0.kind == .goal && isAspiration($0) == wantsAspiration }
        if let taken = existing(named: name, kind: .goal, among: sameKind) {
            // The same two tests the lists use (`aspirations()`, `datedGoals()`).
            return taken.isArchived || taken.isEnded ? .ended(taken) : .choose(taken)
        }
        let otherKind = notes.filter { $0.kind == .goal && isAspiration($0) != wantsAspiration }
        if let taken = existing(named: name, kind: .goal, among: otherKind) {
            return .otherKind(taken)
        }
        return .free
    }

    /// The check for **Add area**. A project, a goal or a resource with the same name is no
    /// obstacle: each kind has its own folder, and `area:` is looked up among areas only
    /// (`NoteIndex.area(named:)`), so the new area is the one a line will find.
    static func check(areaNamed name: String, among notes: [Note]) -> NameCheck {
        guard let taken = existing(named: name, kind: .area, among: notes) else { return .free }
        // The In area… list leaves out an area that is put away, and only that.
        return taken.isArchived ? .ended(taken) : .choose(taken)
    }
}
