import Foundation

/// One colour as three numbers, and the few rules that decide which step of a part's colour is
/// drawn where (build 310, the colours round of the premium review).
///
/// A part has two shades: a deep one for the day and a bright one for the night. Used plainly
/// that leaves four weak spots, all measured on his screens: white words on a bright night
/// shade (2 to 1), small coloured words on a wash of the same colour (3.2 to 1), the morning
/// orange written on white (3.7 to 1), and the word on a button that cannot act yet (1.1 to 1).
/// The rules below fix each of them once, for every part, so no screen chooses its own step.
public struct Shade: Equatable, Sendable {
    /// 0 to 1, in sRGB as it is written in a colour set.
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// From a number as it is written in the look document: `0x6B4EA8`.
    public init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Back to the number, rounded: for tests and for the look document.
    public var hex: UInt32 {
        func part(_ v: Double) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return part(red) << 16 | part(green) << 8 | part(blue)
    }

    public static let white = Shade(red: 1, green: 1, blue: 1)
    public static let black = Shade(red: 0, green: 0, blue: 0)

    /// How bright the eye finds it, 0 (black) to 1 (white): the measure contrast is built on.
    public var luminance: Double {
        func linear(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// "4.5 to 1": how well words in one of the two read on the other. 1 is none, 21 the most.
    public func contrast(with other: Shade) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The same colour with a share of black mixed in: `deeper(0.25)` is a quarter darker.
    public func deeper(_ share: Double) -> Shade {
        let keep = 1 - min(max(share, 0), 1)
        return Shade(red: red * keep, green: green * keep, blue: blue * keep)
    }

    /// This colour laid over another at a strength of 0 to 1: a 14 % wash, a 40 % fill.
    public func over(_ ground: Shade, strength: Double) -> Shade {
        let s = min(max(strength, 0), 1)
        return Shade(red: red * s + ground.red * (1 - s),
                     green: green * s + ground.green * (1 - s),
                     blue: blue * s + ground.blue * (1 - s))
    }
}

/// Which step of a part's colour goes where. Every rule takes the part's day shade (and its
/// night shade where night differs) and gives back what to draw.
public enum ShadeRule {
    /// The step that takes the morning orange #D4640A to #B35300.
    static let morningStep = 0.155

    /// **The ground for white words** — a full-colour button, the chosen sidebar row, the band
    /// at night. Always the deep day shade, by day and by night. A day shade on which white
    /// would measure under 4 to 1 (only the morning orange) is drawn one step deeper.
    public static func ground(day: Shade) -> Shade {
        day.contrast(with: .white) < 4 ? day.deeper(morningStep) : day
    }

    /// **The colour written as words on a white page by day** — headings, links, the word Done
    /// at the top of a sheet. The day shade, one step deeper when it would measure under
    /// 4.5 to 1 on white (morning orange, plan orange, the now-line blue). Night keeps its own
    /// bright shade, which already reads well on dark.
    public static func ink(day: Shade) -> Shade {
        day.contrast(with: .white) < 4.5 ? day.deeper(morningStep) : day
    }

    /// **The small words in a capsule by day**: the day shade a quarter deeper, because the
    /// smallest words sit on a wash of their own colour. Night keeps the night shade.
    public static func capsuleWords(day: Shade) -> Shade { day.deeper(0.25) }

    /// **The word on a main button that cannot act yet**, by day: the day shade 30 % deeper,
    /// on the button's 40 % fill. Night: the night shade on a 30 % fill.
    public static func waitingWords(day: Shade) -> Shade { day.deeper(0.30) }
    public static let waitingFillDay = 0.40
    public static let waitingFillNight = 0.30

    /// **The far end of the band at night**: the ground at 80 % of itself over black.
    public static func bandEnd(ground: Shade) -> Shade { ground.over(.black, strength: 0.8) }
}
