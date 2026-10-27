import XCTest
@testable import ParagonCore

/// Build 272: a name typed into **Add goal**, **Add aspiration** or **Add area** is checked
/// before anything is written, so the popover can say what is wrong itself.
final class ServingNoteNamesTests: XCTestCase {
    var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    private func notes() throws -> [Note] { try vault.allNotes() }

    // MARK: Goals

    func testAFreeNameIsFree() throws {
        _ = try vault.createNote(kind: .goal, title: "Stay fit", extraFrontmatter: [("horizon", "life")])
        XCTAssertEqual(ServingNote.check(goalNamed: "Learn Swedish", horizon: .life, among: try notes()), .free)
        XCTAssertEqual(ServingNote.check(goalNamed: "Learn Swedish", horizon: .year, among: try notes()), .free)
        XCTAssertEqual(ServingNote.check(goalNamed: "  ", horizon: .year, among: try notes()), .free)
    }

    func testAnAspirationWithThatNameIsChosenForAnAspiration() throws {
        let made = try vault.createNote(kind: .goal, title: "Stay fit", extraFrontmatter: [("horizon", "life")])
        // Capitals and spaces at the ends do not make it another name.
        guard case .choose(let taken) = ServingNote.check(goalNamed: "  stay FIT ", horizon: .life,
                                                          among: try notes()) else {
            return XCTFail("The aspiration should have been chosen")
        }
        XCTAssertEqual(taken.relativePath, made.relativePath)
    }

    func testAGoalWithADateWithThatNameIsChosenForAGoalWithADate() throws {
        _ = try vault.createNote(kind: .goal, title: "Walk the Kungsleden",
                                 extraFrontmatter: [("horizon", "year"), ("target", "2028-08-15")])
        guard case .choose(let taken) = ServingNote.check(goalNamed: "walk the kungsleden", horizon: .year,
                                                          among: try notes()) else {
            return XCTFail("The goal with a date should have been chosen")
        }
        XCTAssertEqual(taken.title, "Walk the Kungsleden")
        // A long-term goal is a goal with a date as well.
        XCTAssertEqual(taken.horizon, .year)
        XCTAssertEqual(NameCheckKind.of(ServingNote.check(goalNamed: "Walk the Kungsleden", horizon: .long,
                                                           among: try notes())), .choose)
    }

    func testTheOtherKindOfGoalIsNeverChosenAndSaysSo() throws {
        _ = try vault.createNote(kind: .goal, title: "Stay fit", extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .goal, title: "Walk the Kungsleden", extraFrontmatter: [("horizon", "year")])
        // An aspiration called like a goal with a date, and the other way round.
        guard case .otherKind(let goal) = ServingNote.check(goalNamed: "Walk the Kungsleden", horizon: .life,
                                                            among: try notes()) else {
            return XCTFail("A goal with a date should block an aspiration of the same name")
        }
        XCTAssertEqual(goal.title, "Walk the Kungsleden")
        guard case .otherKind(let aspiration) = ServingNote.check(goalNamed: "STAY FIT", horizon: .year,
                                                                  among: try notes()) else {
            return XCTFail("An aspiration should block a goal with a date of the same name")
        }
        XCTAssertEqual(aspiration.title, "Stay fit")
    }

    /// The reason the check exists: the two kinds of goal share a folder, so the vault itself
    /// refuses the second note. Without the check that refusal became an alert behind the popover.
    func testTheVaultReallyRefusesTheSameFileNameForTheOtherKindOfGoal() throws {
        _ = try vault.createNote(kind: .goal, title: "Stay fit", extraFrontmatter: [("horizon", "life")])
        XCTAssertThrowsError(try vault.createNote(kind: .goal, title: "Stay fit",
                                                  extraFrontmatter: [("horizon", "year")])) { error in
            XCTAssertEqual(error as? VaultError, .noteAlreadyExists("Goals/Stay fit.md"))
        }
    }

    func testAGoalThatHasEndedIsNotChosenBecauseTheListDoesNotOfferIt() throws {
        var done = try vault.createNote(kind: .goal, title: "Reach the hut", extraFrontmatter: [("horizon", "year")])
        done = done.settingStatus(.done, today: DateOnly(year: 2026, month: 9, day: 1))
        try vault.save(done)
        guard case .ended(let taken) = ServingNote.check(goalNamed: "Reach the hut", horizon: .year,
                                                         among: try notes()) else {
            return XCTFail("An ended goal should be reported as ended")
        }
        XCTAssertEqual(taken.noteStatus, .done)
        // The list is what the check has to agree with.
        XCTAssertFalse(NoteIndex(notes: try notes()).datedGoals().contains { $0.relativePath == taken.relativePath })
    }

    func testAGoalPutAwayInItsFolderIsReportedAsEnded() throws {
        var odd = try vault.createNote(kind: .goal, title: "Old plan", extraFrontmatter: [("horizon", "life")])
        odd.frontmatter.set("status", "archived")
        try vault.save(odd)
        XCTAssertEqual(NameCheckKind.of(ServingNote.check(goalNamed: "Old plan", horizon: .life, among: try notes())),
                       .ended)
    }

    func testTheFileNameCountsAsWellAsTheTitle() throws {
        var goal = try vault.createNote(kind: .goal, title: "Stay fit", extraFrontmatter: [("horizon", "life")])
        goal.frontmatter.set("title", "Stay fit and strong")
        try vault.save(goal)
        // The file is still `Goals/Stay fit.md`, so a new "Stay fit" would collide with it.
        guard case .choose(let taken) = ServingNote.check(goalNamed: "Stay fit", horizon: .life,
                                                          among: try notes()) else {
            return XCTFail("The file name should count")
        }
        XCTAssertEqual(taken.title, "Stay fit and strong")
    }

    func testAGoalOfTheRightKindIsFoundEvenWhenTheOtherKindComesFirst() throws {
        // "Stay fit" is an aspiration in the file `Goals/Stay fit.md`; a second note whose
        // *title* is "Walk" is a goal with a date in another file. Asking for a goal with a
        // date called "Walk" must find the second, whatever order the notes arrive in.
        let aspiration = Note(relativePath: "Goals/Walk.md", kind: .goal,
                              text: "---\ntitle: Walk\ntype: goal\nhorizon: life\n---\n")
        let dated = Note(relativePath: "Goals/Walk the trail.md", kind: .goal,
                         text: "---\ntitle: Walk\ntype: goal\nhorizon: year\n---\n")
        for order in [[aspiration, dated], [dated, aspiration]] {
            guard case .choose(let taken) = ServingNote.check(goalNamed: "Walk", horizon: .year, among: order) else {
                return XCTFail("The goal with a date should be chosen")
            }
            XCTAssertEqual(taken.relativePath, "Goals/Walk the trail.md")
        }
    }

    func testProjectsAndAreasWithTheSameNameAreNoObstacleToAGoal() throws {
        _ = try vault.createNote(kind: .project, title: "Stay fit")
        _ = try vault.createNote(kind: .area, title: "Stay fit")
        XCTAssertEqual(ServingNote.check(goalNamed: "Stay fit", horizon: .life, among: try notes()), .free)
        // And the vault agrees: the goal can be made.
        XCTAssertNoThrow(try vault.createNote(kind: .goal, title: "Stay fit", extraFrontmatter: [("horizon", "life")]))
    }

    // MARK: Areas

    func testAnAreaWithThatNameIsChosen() throws {
        _ = try vault.createNote(kind: .area, title: "Health")
        guard case .choose(let taken) = ServingNote.check(areaNamed: " health", among: try notes()) else {
            return XCTFail("The area should be chosen")
        }
        XCTAssertEqual(taken.displayTitle, "Health")
    }

    /// A project called Health is not an area and is never chosen as one. It does not stop an
    /// area called Health either: the two live in different folders.
    func testAProjectWithTheSameNameIsNotChosenAsTheArea() throws {
        _ = try vault.createNote(kind: .project, title: "Health")
        XCTAssertEqual(ServingNote.check(areaNamed: "Health", among: try notes()), .free)
        let area = try vault.createNote(kind: .area, title: "Health")
        XCTAssertEqual(area.relativePath, "Areas/Health.md")
        let index = NoteIndex(notes: try notes())
        XCTAssertEqual(index.area(named: "Health")?.relativePath, "Areas/Health.md")
    }

    func testAnAreaPutAwayIsReportedAsEnded() throws {
        var area = try vault.createNote(kind: .area, title: "Garden")
        area.frontmatter.set("status", "archived")
        try vault.save(area)
        XCTAssertEqual(NameCheckKind.of(ServingNote.check(areaNamed: "Garden", among: try notes())), .ended)
    }

    func testAFreeAreaNameIsFree() throws {
        _ = try vault.createNote(kind: .area, title: "Health")
        XCTAssertEqual(ServingNote.check(areaNamed: "Garden", among: try notes()), .free)
    }
}

/// Which case a `NameCheck` is, without its note, so a test can say it in one line.
private enum NameCheckKind {
    case free, choose, otherKind, ended

    static func of(_ check: NameCheck) -> NameCheckKind {
        switch check {
        case .free: return .free
        case .choose: return .choose
        case .otherKind: return .otherKind
        case .ended: return .ended
        }
    }
}
