import Foundation

/// How long every movement in the app takes, in seconds (build 318, premium review polish-23,
/// his pick "Quick and quiet": 0.2 s for folding; the ticked task fades and the list closes up).
///
/// **One set of numbers for the whole app.** The views never name a duration of their own; they
/// use `Motion.tick`, `Motion.fold` … in the app, and `Motion` reads its seconds here. The
/// numbers live in Core so a test can hold them to the limits (`MotionRulesTests`): every
/// movement is between `shortest` and `longest`, so nothing is too quick to see or slow enough
/// to wait for. The one exception is `spin`, one full turn of the sync ring while a sync runs.
public enum MotionTiming {
    /// No movement is shorter than this …
    public static let shortest = 0.15
    /// … or longer than this.
    public static let longest = 0.35

    /// A task's circle filling when it is ticked.
    public static let tick = 0.2
    /// A row leaving or arriving and the list closing up or making room.
    public static let settle = 0.25
    /// A group opening or closing under its heading.
    public static let fold = 0.2
    /// Something new coming onto the screen: the focus timer's bar, a line added.
    public static let arrive = 0.25
    /// One page of a window giving way to the next.
    public static let page = 0.2
    /// The message at the foot of the screen coming and going.
    public static let toast = 0.2
    /// A progress bar or the sync ring filling to its new value.
    public static let fill = 0.35
    /// A small control answering a press: a filter chip, a card dimming on the map.
    public static let press = 0.15
    /// A plain cross-fade, also what Reduce Motion gets where something must still change gently.
    public static let fade = 0.15
    /// One full turn of the sync ring while a sync runs. Not a movement between two states,
    /// so it is the one number outside the limits.
    public static let spin = 1.0

    /// Every movement between two states, by name, for the test of the limits.
    public static let bounded: [(name: String, seconds: Double)] = [
        ("tick", tick), ("settle", settle), ("fold", fold), ("arrive", arrive), ("page", page),
        ("toast", toast), ("fill", fill), ("press", press), ("fade", fade),
    ]
}
