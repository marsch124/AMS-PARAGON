#if DEBUG
import Foundation
import ParagonCore

/// A vault made from nothing at launch, so the screen tests have something to look at.
///
/// **Build 190, and this is the point of the whole build.** CI has compiled this app since the
/// first push and has never once opened a screen in it. Every fault that cost the most slipped
/// straight through it: the Inbox where no line could be selected (builds 71 to 74), the map
/// boxes that swallowed every click on the canvas (85), the phone editor that needed a long
/// press before it would take a letter (114 to 128), and the three builds spent hunting a
/// fault that turned out to be an **editorMode** setting (123 to 127). A compiler cannot see
/// any of those. A simulator pressing the buttons can.
///
/// **The obstacle was always the vault.** PARAGON opens a folder the user chose, kept as a
/// security-scoped bookmark, so a fresh install shows the welcome screen and a test can go no
/// further. With `-paragon-test-vault` on the command line the app makes its own folder in the
/// temporary directory and opens it through the ordinary `openVault(at:)` — the same path a
/// real folder takes, so the tests exercise the real code and not a special one.
///
/// **DEBUG only.** The Release build that goes to TestFlight does not contain this file, so
/// there is no argument anyone could pass to the app he runs.
enum TestVault {
    /// Passed by `ScreenTests` as a launch argument.
    static let argument = "-paragon-test-vault"

    static var isWanted: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

    /// Wipes what an earlier test run left behind. The simulator keeps the app's container
    /// between runs, so without this a stored section, a remembered note or an `editorMode`
    /// would decide what the next test sees — which is the very thing that made builds 123 to
    /// 127 so expensive.
    static func resetSettings() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: id)
    }

    /// A fresh vault with one of each kind of note, so no list is empty and the chain has
    /// something in it. Deleted and rebuilt on every launch: a test may never depend on what
    /// the test before it left.
    static func make() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PARAGON screen tests", isDirectory: true)
        let files = FileManager.default
        if files.fileExists(atPath: root.path) { try files.removeItem(at: root) }
        try files.createDirectory(at: root, withIntermediateDirectories: true)

        let vault = try Vault(rootURL: root)
        try vault.bootstrap()
        _ = try vault.createNote(kind: .goal, title: aspiration,
                                 extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .goal, title: datedGoal,
                                 extraFrontmatter: [("horizon", "year"),
                                                    ("target", "2027-08-15"),
                                                    ("goal", aspiration)])
        var trip = try vault.createNote(kind: .project, title: project,
                                        extraFrontmatter: [("goal", datedGoal)])
        // One wikilink, so the project's **Linked notes** box exists at all: it is drawn only
        // when a note has links, and expanding it is the exact trigger of build 30's window
        // scramble, which the Mac screen test presses (build 198).
        trip.body += "\n\nWhat to bring: [[\(resource)]]\n"
        // One task with a name of its own and **no date**, so the All actions filter test can
        // name what it expects to see and what it expects a tick to hide (build 211). The
        // project template's own task would do, but a test must not depend on the wording of a
        // template someone may reword.
        trip.body += "\n- [ ] \(action)\n"
        _ = try vault.save(trip)
        // A project that is already over (build 262), so the line "Done on … · after 41 days ·
        // 2 tasks finished" has something to say. Its body is **set**, never added to, so the
        // project template's own open task is not in it (build 162). Its two ticked tasks carry
        // **no `@done` stamp**: a stamp would draw the Projects band and break the weekly-bars
        // test, which first checks there is none. No `goal:` and no open task, so the chain,
        // the Map's aspiration box, All actions and Start the day stay as they were.
        var bike = try vault.createNote(kind: .project, title: finishedProject)
        bike.body = "# \(finishedProject)\n\n- [x] Pump the tyres\n- [x] Oil the chain\n"
        bike.frontmatter.set("status", NoteStatus.done.rawValue)
        bike.frontmatter.set("created", DateOnly.today().adding(days: -41).description)
        bike.frontmatter.set(Note.endedKey, DateOnly.today().description)
        _ = try vault.save(bike)
        _ = try vault.createNote(kind: .area, title: area, extraFrontmatter: [("goal", aspiration)])
        _ = try vault.createNote(kind: .resource, title: resource)
        // Through `capture`, the same path the capture screens use, so the line is exactly
        // what a real capture would have written.
        _ = try vault.capture(CaptureItem(text: inboxLine))
        // Yesterday's daily note with one line under **Looking back** (build 265), so **Start the
        // day** has something to show under *Last evening you wrote*. **The first dated daily
        // note in this vault.** It holds prose and no task — the Daily template has none — so
        // build 221's fixture still holds: no dated open task, no plan, no `#next`.
        let yesterday = try vault.dailyNote(for: DateOnly.today().adding(days: -1))
        _ = try vault.save(yesterday.settingLookingBack(lastEvening))
        return root
    }

    // The names the tests look for. Spelled here so a test and the vault cannot disagree.
    static let aspiration = "Be strong and steady at seventy"
    static let datedGoal = "Walk the Kungsleden in one go"
    static let project = "Plan the Kungsleden trip"
    static let finishedProject = "Fix the bike"
    static let area = "Health"
    static let resource = "Packing list"
    static let inboxLine = "Call the bank about the ferry"
    static let action = "Book the night train"
    static let lastEvening = "A quiet day by the sea."
}
#endif
