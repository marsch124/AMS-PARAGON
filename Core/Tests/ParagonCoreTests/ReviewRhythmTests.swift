import XCTest
@testable import ParagonCore

/// Build 172: a review rhythm per level. Everything here is read out of the `reviewed:` line
/// that the app has written since the review was first built, so the tests are about the
/// arithmetic and about what the app is allowed to say.
final class ReviewRhythmTests: XCTestCase {

    private let today = DateOnly(year: 2026, month: 9, day: 14)

    private func note(_ path: String, kind: ParaKind, text: String) -> Note {
        Note(relativePath: path, kind: kind, text: text)
    }

    private func index(_ notes: [Note]) -> NoteIndex { NoteIndex(notes: notes) }

    func testEachKindOfNoteKnowsItsLevel() {
        let aspiration = note("Goals/Athlete.md", kind: .goal,
                              text: "---\ntitle: Still racing at seventy\nhorizon: life\n---\n")
        let goal = note("Goals/IM.md", kind: .goal,
                        text: "---\ntitle: Do IM 70.3\ntarget: 2027-08-15\n---\n")
        let project = note("Projects/Bike.md", kind: .project, text: "---\ntitle: New bike\n---\n")
        let area = note("Areas/Health.md", kind: .area, text: "---\ntitle: Health\n---\n")
        let resource = note("Resources/Plan.md", kind: .resource, text: "---\ntitle: A plan\n---\n")
        let i = index([aspiration, goal, project, area, resource])

        XCTAssertEqual(i.reviewLevel(of: aspiration), .aspiration)
        XCTAssertEqual(i.reviewLevel(of: goal), .goal)
        XCTAssertEqual(i.reviewLevel(of: project), .project)
        XCTAssertEqual(i.reviewLevel(of: area), .area)
        // A resource is reference material. Nobody reviews it, and asking would be noise.
        XCTAssertNil(i.reviewLevel(of: resource))
    }

    func testAnArchivedProjectStillReadsAsAProject() {
        // Archiving moves the file, so `kind` comes out as `.archive` from the folder. The
        // level has to read `type:` instead, or an archived project would answer "no level"
        // for the wrong reason (build 141).
        let archived = note("Archive/Old.md", kind: .archive,
                            text: "---\ntitle: Old project\ntype: project\n---\n")
        XCTAssertEqual(index([archived]).reviewLevel(of: archived), .project)
    }

    func testNeverReviewedIsDueAndIsNotDrawnAsANumber() {
        let project = note("Projects/Bike.md", kind: .project, text: "---\ntitle: New bike\n---\n")
        let schedule = index([project]).reviewSchedule(rhythm: ReviewRhythm(), today: today)
        XCTAssertEqual(schedule.count, 1)
        XCTAssertNil(schedule[0].daysSinceReview)
        XCTAssertTrue(schedule[0].isDue)
        XCTAssertEqual(schedule[0].whenText, "never looked at")
        XCTAssertEqual(schedule[0].lastText, "never reviewed")
    }

    func testTheRhythmDecidesWhenSomethingIsDue() {
        // Reviewed 10 days ago. A project is on 7 days, so it is over; a goal is on 90, so it
        // is not; and the same note cannot be both.
        let text = "---\ntitle: Thing\nreviewed: 2026-09-04\n---\n"
        let project = note("Projects/Thing.md", kind: .project, text: text)
        let goal = note("Goals/Thing.md", kind: .goal, text: text)
        let schedule = index([project, goal]).reviewSchedule(rhythm: ReviewRhythm(), today: today)

        let byLevel = Dictionary(uniqueKeysWithValues: schedule.map { ($0.level, $0) })
        XCTAssertEqual(byLevel[.project]?.daysSinceReview, 10)
        XCTAssertTrue(byLevel[.project]?.isDue ?? false)
        XCTAssertEqual(byLevel[.project]?.whenText, "3 days over")
        XCTAssertFalse(byLevel[.goal]?.isDue ?? true)
        XCTAssertEqual(byLevel[.goal]?.whenText, "due in 80 days")
    }

    func testDueTodayAndDueTomorrowAreSaidInWords() {
        func due(_ daysAgo: Int) -> ReviewDue {
            ReviewDue(note: note("Projects/X.md", kind: .project, text: "# X"),
                      level: .project, daysSinceReview: daysAgo, every: 7)
        }
        XCTAssertEqual(due(7).whenText, "due today")
        XCTAssertEqual(due(6).whenText, "due tomorrow")
        XCTAssertEqual(due(5).whenText, "due in 2 days")
        XCTAssertEqual(due(8).whenText, "1 day over")
        XCTAssertEqual(due(0).lastText, "reviewed today")
        XCTAssertEqual(due(1).lastText, "reviewed yesterday")
        XCTAssertEqual(due(4).lastText, "reviewed 4 days ago")
    }

    func testWorkThatIsOverIsNeverAskedAbout() {
        // A dropped project, a done goal and an archived area are not questions for a review.
        // Counting them would be the noise build 132 refused when it kept `noGoal` out of
        // "needs attention".
        let dropped = note("Projects/Tuba.md", kind: .project,
                           text: "---\ntitle: Learn the tuba\nstatus: dropped\n---\n")
        let done = note("Goals/Race.md", kind: .goal,
                        text: "---\ntitle: Race\nstatus: done\n---\n")
        let archived = note("Archive/Club.md", kind: .archive,
                            text: "---\ntitle: Club\ntype: area\narchived: true\n---\n")
        let live = note("Projects/Bike.md", kind: .project, text: "---\ntitle: New bike\n---\n")

        let schedule = index([dropped, done, archived, live]).reviewSchedule(rhythm: ReviewRhythm(), today: today)
        XCTAssertEqual(schedule.map(\.note.title), ["New bike"])
    }

    func testNeverReviewedSortsAboveTheMostOverdue() {
        let never = note("Projects/Never.md", kind: .project, text: "---\ntitle: Never\n---\n")
        let long = note("Projects/Long.md", kind: .project,
                        text: "---\ntitle: Long ago\nreviewed: 2026-01-01\n---\n")
        let recent = note("Projects/Recent.md", kind: .project,
                          text: "---\ntitle: Recent\nreviewed: 2026-09-13\n---\n")
        let schedule = index([recent, long, never]).reviewSchedule(rhythm: ReviewRhythm(), today: today)
        XCTAssertEqual(schedule.map(\.note.title), ["Never", "Long ago", "Recent"])
        XCTAssertEqual(schedule.filter(\.isDue).map(\.note.title), ["Never", "Long ago"])
    }

    func testTheProjectRhythmIsTheReviewIntervalAlreadyInTheSettings() {
        // One number, not two. A second setting meaning the same thing is how two screens come
        // to disagree.
        var config = VaultConfig()
        config.reviewIntervalDays = 21
        config.goalReviewDays = 45
        let rhythm = ReviewRhythm(config: config)
        XCTAssertEqual(rhythm.days(for: .project), 21)
        XCTAssertEqual(rhythm.days(for: .goal), 45)
        XCTAssertEqual(rhythm.days(for: .aspiration), ReviewLevel.aspiration.defaultDays)
        XCTAssertEqual(rhythm.days(for: .area), ReviewLevel.area.defaultDays)
    }

    func testAnAspirationIsLookedAtTwiceAYear() {
        // His answer from the build 174 field test, and the one box he marked as not right.
        XCTAssertEqual(ReviewLevel.aspiration.defaultDays, 182)
        XCTAssertEqual(ReviewRhythm.label(forDays: 182), "Every 6 months")
    }

    func testALengthIsSaidInTheWordsAPersonUses() {
        XCTAssertEqual(ReviewRhythm.label(forDays: 7), "Every week")
        XCTAssertEqual(ReviewRhythm.label(forDays: 14), "Every 2 weeks")
        XCTAssertEqual(ReviewRhythm.label(forDays: 30), "Every month")
        XCTAssertEqual(ReviewRhythm.label(forDays: 90), "Every 3 months")
        XCTAssertEqual(ReviewRhythm.label(forDays: 365), "Every year")
        // Anything the list does not name still reads as something, never as blank.
        XCTAssertEqual(ReviewRhythm.label(forDays: 45), "Every 45 days")
    }

    func testWhateverAVaultIsSetToIsAlwaysOneOfTheChoices() {
        // Build 174 set an aspiration to 365 and stepped 30 days at a time, so 182 was
        // unreachable. Whatever a vault holds now has to be offered, or the screen would show
        // nothing chosen while something plainly is.
        let odd = ReviewRhythm.choices(for: .aspiration, including: 400)
        XCTAssertTrue(odd.contains(400))
        XCTAssertEqual(odd, odd.sorted())
        // The offered ones are not duplicated when the current value is already among them.
        let normal = ReviewRhythm.choices(for: .aspiration, including: 182)
        XCTAssertEqual(normal, ReviewLevel.aspiration.choices)
        XCTAssertEqual(Set(normal).count, normal.count)
        // Every level offers something, and its own default is always on the list.
        for level in ReviewLevel.allCases {
            XCTAssertFalse(level.choices.isEmpty)
            XCTAssertTrue(level.choices.contains(level.defaultDays), "\(level) omits its own default")
        }
    }

    func testEveryLevelSaysWhatItIsAndWhy() {
        for level in ReviewLevel.allCases {
            XCTAssertFalse(level.label.isEmpty)
            XCTAssertFalse(level.reason.isEmpty)
            XCTAssertGreaterThan(level.defaultDays, 0)
        }
    }

    func testAVaultConfigWrittenBeforeThisBuildStillReads() {
        // The one promise that matters: his config.json has none of these keys in it.
        let old = """
        {"projectsFolder":"Projects","reviewIntervalDays":9,"inboxListName":"Inbox"}
        """
        let config = try! JSONDecoder().decode(VaultConfig.self, from: Data(old.utf8))
        XCTAssertEqual(config.reviewIntervalDays, 9)
        XCTAssertEqual(config.inboxListName, "Inbox")
        XCTAssertEqual(config.goalReviewDays, ReviewLevel.goal.defaultDays)
        XCTAssertEqual(config.aspirationReviewDays, ReviewLevel.aspiration.defaultDays)
        XCTAssertEqual(config.areaReviewDays, ReviewLevel.area.defaultDays)
    }

    // MARK: The words two screens say (build 199)

    func testLookedAtSaysNeverRatherThanANumber() {
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: nil), "Never looked at")
    }

    func testLookedAtInDaysMonthsAndYears() {
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 0), "Looked at today")
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 1), "Looked at yesterday")
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 12), "Looked at 12 days ago")
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 30), "Looked at 30 days ago")
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 31), "Looked at about a month ago")
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 120), "Looked at about 4 months ago")
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 400), "Looked at about a year ago")
        XCTAssertEqual(ReviewWording.lookedAt(daysAgo: 1100), "Looked at about 3 years ago")
    }
}
