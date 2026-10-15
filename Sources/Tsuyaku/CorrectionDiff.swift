import Foundation

/// Which words of a corrected row the corrector wrote, so the panel can
/// tint those and leave Gemini's own words white.
///
/// Word-level longest common subsequence: a correction swaps a word or two
/// and keeps the rest, which is exactly what LCS lines up. Whitespace runs
/// are carried through so the line reads back verbatim.
enum CorrectionDiff {

    struct Run: Equatable {
        let text: String
        let changed: Bool
    }

    static func runs(original: String, corrected: String) -> [Run] {
        let old = words(original)
        let tokens = tokenize(corrected)
        let new = tokens.filter { !$0.isSpace }.map(\.text)
        let kept = common(old, new)

        var marks: [Bool] = []
        var w = 0
        for token in tokens {
            if token.isSpace {
                marks.append(false)
            } else {
                marks.append(!kept.contains(w))
                w += 1
            }
        }
        // A space between two rewritten words belongs to the rewrite, so
        // "Raksul's quote" tints as one phrase.
        for i in tokens.indices where tokens[i].isSpace
            && i > 0 && i < tokens.count - 1 && marks[i - 1] && marks[i + 1] {
            marks[i] = true
        }

        var runs: [Run] = []
        for (token, changed) in zip(tokens, marks) {
            if let last = runs.last, last.changed == changed {
                runs[runs.count - 1] = Run(text: last.text + token.text, changed: changed)
            } else {
                runs.append(Run(text: token.text, changed: changed))
            }
        }
        return runs
    }

    private struct Token {
        let text: String
        let isSpace: Bool
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var inSpace = false
        for ch in text {
            let space = ch.isWhitespace
            if !current.isEmpty, space != inSpace {
                tokens.append(Token(text: current, isSpace: inSpace))
                current = ""
            }
            current.append(ch)
            inSpace = space
        }
        if !current.isEmpty { tokens.append(Token(text: current, isSpace: inSpace)) }
        return tokens
    }

    private static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Indexes into `new` of the words that are part of the LCS with `old`.
    private static func common(_ old: [String], _ new: [String]) -> Set<Int> {
        let n = old.count, m = new.count
        guard n > 0, m > 0 else { return [] }
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                table[i][j] = old[i] == new[j]
                    ? table[i + 1][j + 1] + 1
                    : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var kept: Set<Int> = []
        var i = 0, j = 0
        while i < n, j < m {
            if old[i] == new[j] {
                kept.insert(j)
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return kept
    }
}
