import XCTest
@testable import ParagonCore

/// Build 361: two notes folders (Martin's, Anna's) share one Reminders list. Each takes in the
/// other's tasks under the same id, with who does it.
final class SharedTasksTests: XCTestCase {
    func testTwoFoldersShareOneProjectWithWhoDoesIt() async throws {
        let martin = try makeTemporaryVault()
        let anna = try makeTemporaryVault()
        defer { removeVault(martin); removeVault(anna) }
        let store = InMemoryRemindersStore(lists: ["Reminders"])

        func engine(_ vault: Vault, _ name: String) -> SyncEngine {
            var config = vault.config
            config.myName = name
            return SyncEngine(vault: vault, store: store, deviceID: name, config: config)
        }
        func garden(_ vault: Vault, with other: String, body: String) throws {
            var note = try vault.createNote(kind: .project, title: "Garden")
            note.frontmatter.set("shared-with", list: [other])
            note.body += body
            try vault.save(note)
        }
        func tasks(_ vault: Vault) throws -> [TaskItem] {
            try vault.allNotes().first { $0.title == "Garden" }!.tasks
        }

        try garden(martin, with: "Anna", body: "- [ ] Buy paint @who(Anna)\n")
        _ = try await engine(martin, "Martin").run()

        let reminder = try await store.reminders(inList: "Garden")[0]
        XCTAssertEqual(SharedTasks.who(inNotes: reminder.notes), "Anna")
        XCTAssertEqual(SharedTasks.from(inNotes: reminder.notes), "Martin")

        // Anna's PARAGON takes Martin's task in, same id, same person responsible.
        try garden(anna, with: "Martin", body: "- [ ] Fix the gate @who(Martin)\n")
        _ = try await engine(anna, "Anna").run()
        let hers = try tasks(anna)
        let paint = try XCTUnwrap(hers.first { $0.title == "Buy paint" })
        XCTAssertEqual(paint.id, try tasks(martin).first { $0.title == "Buy paint" }?.id)
        XCTAssertEqual(paint.who, "Anna")

        // And Martin's takes hers in.
        _ = try await engine(martin, "Martin").run()
        let gate = try XCTUnwrap(try tasks(martin).first { $0.title == "Fix the gate" })
        XCTAssertEqual(gate.who, "Martin")

        // A task of his own folder that his notes do not (yet) show is still left alone.
        XCTAssertFalse(SharedTasks.takesIn(markID: "t123456", knownIDs: [], noteShared: true, from: "Martin", me: "Martin"))
        XCTAssertEqual(SharedTasks.names(from: "Anna and Erik, anna"), ["Anna", "Erik"])
        XCTAssertEqual(TaskParser.parse(line: "- [ ] Paint @who(Anna)")?.serialized, "- [ ] Paint @who(Anna)")
    }
}
