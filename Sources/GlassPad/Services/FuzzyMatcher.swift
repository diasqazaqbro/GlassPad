import Foundation

/// Lightweight subsequence fuzzy matcher tuned for app names. Returns a relevance
/// score (higher = better) or `nil` when the query isn't a subsequence of the
/// candidate. Rewards prefix matches, word-boundary hits, and consecutive runs.
enum FuzzyMatcher {
    static func score(query: String, candidate: String) -> Int? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }

        let q = Array(trimmed.lowercased())
        let original = Array(candidate)
        let lower = Array(candidate.lowercased())

        var qi = 0
        var score = 0
        var previousMatch = -2

        var i = 0
        while i < lower.count && qi < q.count {
            if lower[i] == q[qi] {
                var charScore = 1
                if i == 0 {
                    charScore += 14 // matches the very start
                } else {
                    let prev = original[i - 1]
                    if prev == " " || prev == "-" || prev == "_" || prev == "." {
                        charScore += 10 // start of a word
                    } else if original[i].isUppercase && prev.isLowercase {
                        charScore += 8 // camelCase boundary
                    }
                }
                if i == previousMatch + 1 {
                    charScore += 6 // consecutive run
                }
                score += charScore
                previousMatch = i
                qi += 1
            }
            i += 1
        }

        guard qi == q.count else { return nil }

        if lower.starts(with: q) { score += 24 } // whole-prefix bonus
        score -= candidate.count / 12 // gently prefer shorter, tighter matches
        return score
    }
}
