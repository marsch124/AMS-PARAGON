import AppIntents
import SwiftUI
import WidgetKit
import AMSIcons
import ParagonCore

/// Ticking a task on the widget (build 317).
///
/// **The widget still never opens the vault.** A press appends one line to a small file in the
/// shared folder (`WidgetTickQueue`, in Core) and the widget draws the task ticked from that
/// file at once. PARAGON itself writes the tick into the note — the same way a tick in the app
/// is written — when it next starts or comes to the front, and within ten seconds while it is
/// open. Pressing a ticked line again takes the tick back, as long as the app has not written it.
struct TickWidgetTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Tick a task"
    static var isDiscoverable: Bool = false

    /// `WidgetSnapshot.Item.id` of the line pressed.
    @Parameter(title: "Line") var key: String
    /// The task's own words, so a line that has moved in its note is not taken for another.
    @Parameter(title: "Task") var words: String
    @Parameter(title: "Ticked") var ticked: Bool

    init() {}

    init(item: WidgetSnapshot.Item, ticked: Bool) {
        self.key = item.id
        self.words = item.rawTitle ?? item.title
        self.ticked = ticked
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: ParagonWidgetBundle.appGroupID),
              let snapshot = WidgetSnapshot.read(fromContainer: container),
              let item = snapshot.items.first(where: { $0.id == key && ($0.rawTitle ?? $0.title) == words }),
              let tick = item.tick(at: Date(), ticked: ticked) else {
            return .result()
        }
        try? WidgetTickQueue(container: container).append(tick)
        // The other PARAGON widgets count this task too.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// One action on the medium and large **Today's actions** widget: a tick circle in the colour
/// of the task's kind of note, then the line, which opens its note. The small size, and a line
/// written by a build that could not tick, are drawn as before.
struct ActionLine: View {
    let item: WidgetSnapshot.Item
    var small: Bool
    var ticked: Bool

    var body: some View {
        if small || item.notePath == nil {
            WidgetLink(to: small ? nil : item.url) {
                ActionRow(item: item, compact: small)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Button(intent: TickWidgetTaskIntent(item: item, ticked: !ticked)) {
                    ControlMarkView(ticked ? .ticked : .circle, size: 15)
                        .foregroundStyle(WidgetLook.tint(forKind: item.noteKind))
                        .widgetAccentable()
                        // A finger-sized place to press, without making the row taller.
                        .padding(5)
                        .contentShape(Rectangle())
                        .padding(-5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ticked ? "Take the tick off \(item.title)" : "Tick \(item.title)")
                WidgetLink(to: item.url) {
                    ActionRow(item: item, showsKind: false, ticked: ticked)
                }
            }
        }
    }
}
