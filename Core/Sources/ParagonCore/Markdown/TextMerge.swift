import Foundation

/// Puts two changed copies of one note together, line by line (premium review, hardening-03).
///
/// The editor types into a copy of the note. When the file changed meanwhile (the phone, a
/// sync), there are three texts: the one both started from (`base`), what was typed here
/// (`mine`) and what the file holds now (`theirs`). Changes to different lines are both kept.
/// Changes that meet — the same line, or new lines in the same place — cannot be put together
/// safely, and the caller keeps both copies instead.
public enum TextMerge {
    public enum Result: Equatable {
        case merged(String)
        case conflict
    }

    public static func threeWay(base: String, mine: String, theirs: String) -> Result {
        if mine == theirs || theirs == base { return .merged(mine) }
        if mine == base { return .merged(theirs) }

        let b = base.components(separatedBy: "\n")
        let m = mine.components(separatedBy: "\n")
        let t = theirs.components(separatedBy: "\n")
        let inMine = matches(b, m)
        let inTheirs = matches(b, t)

        var out: [String] = []
        out.reserveCapacity(max(m.count, t.count))
        var bi = 0, mi = 0, ti = 0
        while true {
            // The next line of the base that both copies still have: everything before it is
            // one stretch that either side may have changed.
            var stable = bi
            while stable < b.count, inMine[stable] < 0 || inTheirs[stable] < 0 { stable += 1 }
            let bEnd = stable, mEnd = stable < b.count ? inMine[stable] : m.count
            let tEnd = stable < b.count ? inTheirs[stable] : t.count
            let baseRun = b[bi..<bEnd], mineRun = m[mi..<mEnd], theirRun = t[ti..<tEnd]
            if mineRun == baseRun {
                out += theirRun
            } else if theirRun == baseRun || mineRun == theirRun {
                out += mineRun
            } else if mineRun.count == baseRun.count, theirRun.count == baseRun.count {
                // Lines changed in place on both sides, next to each other (a task ticked
                // there, the line under it typed on here): each line is taken from whoever
                // changed it. The same line changed by both is still a conflict.
                for k in 0..<baseRun.count {
                    let was = b[bi + k], here = m[mi + k], there = t[ti + k]
                    if here == was {
                        out.append(there)
                    } else if there == was || here == there {
                        out.append(here)
                    } else {
                        return .conflict
                    }
                }
            } else {
                return .conflict
            }
            guard stable < b.count else { break }
            out.append(b[stable])
            bi = stable + 1
            mi = mEnd + 1
            ti = tEnd + 1
        }
        return .merged(out.joined(separator: "\n"))
    }

    /// For every line of `a`, the line of `b` it is the same as (in order, never crossing), or
    /// -1. The same start and end are matched straight away; only the part in between is
    /// compared in full, and a part too large for that is left unmatched — which can only
    /// turn a merge into a conflict copy, never into a wrong merge.
    static func matches(_ a: [String], _ b: [String]) -> [Int] {
        var result = [Int](repeating: -1, count: a.count)
        var start = 0
        while start < a.count, start < b.count, a[start] == b[start] {
            result[start] = start
            start += 1
        }
        var endA = a.count, endB = b.count
        while endA > start, endB > start, a[endA - 1] == b[endB - 1] {
            endA -= 1
            endB -= 1
            result[endA] = endB
        }
        let n = endA - start, m = endB - start
        guard n > 0, m > 0, n * m <= 4_000_000 else { return result }

        // Lines as numbers, so the table below compares numbers, not text.
        var ids: [String: Int32] = [:]
        func id(_ line: String) -> Int32 {
            if let known = ids[line] { return known }
            let new = Int32(ids.count)
            ids[line] = new
            return new
        }
        let x = a[start..<endA].map(id), y = b[start..<endB].map(id)
        // table[i][j]: the longest run of shared lines in x[i...] and y[j...].
        let width = m + 1
        var table = [Int32](repeating: 0, count: (n + 1) * width)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                table[i * width + j] = x[i] == y[j]
                    ? table[(i + 1) * width + j + 1] + 1
                    : max(table[(i + 1) * width + j], table[i * width + j + 1])
            }
        }
        var i = 0, j = 0
        while i < n, j < m {
            if x[i] == y[j] {
                result[start + i] = start + j
                i += 1
                j += 1
            } else if table[(i + 1) * width + j] >= table[i * width + j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return result
    }
}
