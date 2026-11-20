import Foundation

/// Round 350 (capture-inbox): the drawings of two new marks, in the library's style — the 24-point
/// grid, one 1.9 line, round ends, no fill. Their names are registered in `Marks.byName`.
extension Marks {
    /// Dictate: a microphone — the capsule, the cradle round it and the stand.
    static let micPath = "M12 3.5a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0v-5a3 3 0 0 1 3-3Z M6.5 11.5a5.5 5.5 0 0 0 11 0 M12 17v3.5 M9 20.5h6"

    /// Scan a paper list: the four corners of a viewfinder with two lines of writing inside.
    static let scanListPath = "M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8 M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8 M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16 M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16 M8 10h8 M8 14h5"
}
