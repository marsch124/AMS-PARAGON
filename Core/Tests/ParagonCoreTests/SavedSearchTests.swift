import XCTest
@testable import ParagonCore

/// Build 173: a search you gave a name to. What is stored is the query text, never the
/// results, so a saved search always answers for the vault as it is today.
final class SavedSearchTests: XCTestCase {

    private var root: URL!
    private var vault: Vault!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("paragon-searches-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        vault = try Vault(rootURL: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testAVaultWithNoFileHasNoSavedSearches() {
        // Not an error and not a reason to refuse anything: there simply are none yet.
        XCTAssertTrue(vault.savedSearches().isEmpty)
    }

    func testSavingAndReadingBack() throws {
        try vault.addSavedSearch(name: "Overdue at work", query: "is:open due:overdue #work")
        try vault.addSavedSearch(name: "Reading", query: "type:resource")

        let all = vault.savedSearches()
        XCTAssertEqual(all.map(\.name), ["Overdue at work", "Reading"])
        XCTAssertEqual(all.first?.query, "is:open due:overdue #work")
        // Ids are minted once, so a rename cannot break anything pointing at one.
        XCTAssertEqual(Set(all.map(\.id)).count, 2)
    }

    func testSavingTheSameNameTwiceChangesItRatherThanAddingASecond() throws {
        try vault.addSavedSearch(name: "Reading", query: "type:resource")
        let id = vault.savedSearches()[0].id
        try vault.addSavedSearch(name: "  reading ", query: "type:resource #travel")

        let all = vault.savedSearches()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].query, "type:resource #travel")
        // The same row, not a replacement: anything holding the id still finds it.
        XCTAssertEqual(all[0].id, id)
        XCTAssertEqual(all[0].name, "reading")
    }

    func testAnEmptyNameIsRefused() {
        XCTAssertThrowsError(try vault.addSavedSearch(name: "   ", query: "anything")) { error in
            XCTAssertEqual(error as? VaultError, .invalidName)
        }
        XCTAssertTrue(vault.savedSearches().isEmpty)
    }

    func testRenamingRefusesANameAlreadyTaken() throws {
        try vault.addSavedSearch(name: "Reading", query: "type:resource")
        try vault.addSavedSearch(name: "Work", query: "#work")
        let work = vault.savedSearches().first { $0.name == "Work" }!

        XCTAssertThrowsError(try vault.renameSavedSearch(id: work.id, to: "reading")) { error in
            XCTAssertEqual(error as? VaultError, .nameInUse("reading"))
        }
        // Nothing was written: the list is exactly as it was.
        XCTAssertEqual(vault.savedSearches().map(\.name), ["Reading", "Work"])

        try vault.renameSavedSearch(id: work.id, to: "Work things")
        XCTAssertEqual(vault.savedSearches().map(\.name), ["Reading", "Work things"])
        // Renaming keeps the query.
        XCTAssertEqual(vault.savedSearches()[1].query, "#work")
    }

    func testDeleting() throws {
        try vault.addSavedSearch(name: "Reading", query: "type:resource")
        try vault.addSavedSearch(name: "Work", query: "#work")
        let reading = vault.savedSearches()[0]

        try vault.deleteSavedSearch(id: reading.id)
        XCTAssertEqual(vault.savedSearches().map(\.name), ["Work"])
        // Deleting something already gone is not an error.
        try vault.deleteSavedSearch(id: reading.id)
        XCTAssertEqual(vault.savedSearches().count, 1)
    }

    func testTheSavedQueryIsWhatTheSearchScreenWouldHaveParsed() throws {
        // The promise of storing the text and not the results: a saved search and the same
        // words typed by hand are the same search.
        let text = "is:open due:overdue type:project"
        try vault.addSavedSearch(name: "Late projects", query: text)
        let saved = vault.savedSearches()[0]

        let a = SearchQuery.parse(saved.query)
        let b = SearchQuery.parse(text)
        XCTAssertEqual(a.summary, b.summary)
        XCTAssertEqual(a.taskStates, b.taskStates)
        XCTAssertEqual(a.dues, b.dues)
        XCTAssertEqual(a.kinds, b.kinds)
    }

    func testTheOfferedNameIsTheQueryInTheSameWordsTheScreenUses() {
        let query = SearchQuery.parse("is:open due:overdue")
        // One place puts a query into words, so the name offered and the line under the tick
        // boxes can never say different things.
        XCTAssertEqual(SavedSearch.suggestedName(for: query), query.summary)
        // Nothing to name when nothing is asked for.
        XCTAssertEqual(SavedSearch.suggestedName(for: SearchQuery.parse("")), "")
    }

    func testALongNameIsCutRatherThanAllowedToRunOff() {
        let long = SearchQuery.parse("is:open due:overdue type:project type:area type:goal #travel #work sunshine")
        let name = SavedSearch.suggestedName(for: long)
        XCTAssertLessThanOrEqual(name.count, 61)
        XCTAssertFalse(name.isEmpty)
    }
}
