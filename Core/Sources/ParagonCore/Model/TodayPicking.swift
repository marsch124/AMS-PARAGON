import Foundation

/// **Start turns Today into picking** (build 335, his pick 3 of the picture of 17 November 2026).
///
/// Until 334 **Start the day** was a second page that listed Today's tasks again with a
/// **Pick** button on each. Now the Start button on Today's band turns the *same* list into the
/// picking list: a dark strip "Picking for today · Done", the morning lines on top, **Pick** in
/// front of every task, and one full-colour button "Plan N actions" at the foot. **Done** or the
/// plan button leaves it. The rules that can be said without a screen live here.
public enum TodayPicking {
    /// The words on the dark strip under Today's band.
    public static let stripWords = "Picking for today"

    /// One pick, by note and title — never by line number: ticking a repeating task writes its
    /// next occurrence on the line below and moves every later task in that note (build 238).
    public static func key(notePath: String, title: String) -> String {
        notePath + "\n" + title
    }

    /// Picking is on from the press on **Start** until **Done** or the plan button — and it ends
    /// by itself when the day changes: picks made yesterday are not today's picks.
    public static func isOn(since day: DateOnly?, today: DateOnly) -> Bool {
        day == today
    }

    /// The picked ones in the order the list shows them, each once, and only those the list
    /// still shows — a pick that was ticked done or moved to another day meanwhile is dropped,
    /// so the count on the button is never more than what will be planned.
    public static func chosen<Row>(_ picks: Set<String>, in shown: [Row], key: (Row) -> String) -> [Row] {
        var seen = Set<String>()
        var result: [Row] = []
        for row in shown {
            let name = key(row)
            guard picks.contains(name), !seen.contains(name) else { continue }
            seen.insert(name)
            result.append(row)
        }
        return result
    }

    /// The full-colour button at the foot, or nil with nothing picked: a button that would only
    /// close the list is the strip's **Done**, and a main button is never grey.
    public static func planTitle(picked: Int) -> String? {
        switch picked {
        case ..<1: return nil
        case 1: return "Plan 1 action"
        default: return "Plan \(picked) actions"
        }
    }

    /// A task marked **First** last evening is drawn once, at the top; the sections below leave
    /// it out while picking, so no task has two Pick buttons.
    public static func withoutMarked<Row>(_ rows: [Row], marked: [Row], key: (Row) -> String) -> [Row] {
        let top = Set(marked.map(key))
        return rows.filter { !top.contains(key($0)) }
    }
}
