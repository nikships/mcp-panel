import SwiftUI

/// Theme-aware JSON syntax highlighter.
///
/// Produces an `AttributedString` colored per `ThemeColors`. Highlighting is pure and
/// deterministic; callers should cache the result (keyed by `(jsonHash, themeName)`) and avoid
/// recomputing on every `body` call (see swiftui perf-patterns §2 / Anti-Pattern 2).
enum JSONSyntaxHighlighter {

    /// Highlight a JSON string. The result has no font applied; apply a monospaced font at render
    /// time via `.font(.system(size:design:.monospaced))`.
    static func highlight(_ json: String, colors: ThemeColors) -> AttributedString {
        var result = AttributedString(json)
        // Default color for any unclassified characters.
        result.foregroundColor = colors.primaryText

        let scalars = Array(json)
        let count = scalars.count
        var i = 0

        // Helper to color a [start, end) range of character indices.
        func colorRange(_ start: Int, _ end: Int, _ color: Color) {
            guard start < end, end <= count else { return }
            let lower = result.index(result.startIndex, offsetByCharacters: start)
            let upper = result.index(result.startIndex, offsetByCharacters: end)
            result[lower..<upper].foregroundColor = color
        }

        while i < count {
            let ch = scalars[i]

            if ch == "\"" {
                // Parse a complete string token (handles escapes).
                let stringStart = i
                i += 1
                while i < count {
                    if scalars[i] == "\\" {
                        i += 2 // skip escaped char
                        continue
                    }
                    if scalars[i] == "\"" {
                        i += 1
                        break
                    }
                    i += 1
                }
                let stringEnd = i // exclusive

                // Determine whether this string is a key (next non-whitespace char is ':').
                var j = stringEnd
                while j < count, scalars[j] == " " || scalars[j] == "\t" || scalars[j] == "\n" || scalars[j] == "\r" {
                    j += 1
                }
                let isKey = j < count && scalars[j] == ":"

                colorRange(stringStart, stringEnd, isKey ? colors.primaryAccent : colors.successColor)
                continue
            }

            if ch == "-" || (ch >= "0" && ch <= "9") {
                // Parse a number token.
                let numStart = i
                i += 1
                while i < count {
                    let c = scalars[i]
                    if (c >= "0" && c <= "9") || c == "." || c == "e" || c == "E" || c == "+" || c == "-" {
                        i += 1
                    } else {
                        break
                    }
                }
                colorRange(numStart, i, colors.secondaryAccent)
                continue
            }

            // Keywords: true / false / null
            if ch == "t" || ch == "f" || ch == "n" {
                let keyword: String?
                if matches(scalars, at: i, keyword: "true") { keyword = "true" }
                else if matches(scalars, at: i, keyword: "false") { keyword = "false" }
                else if matches(scalars, at: i, keyword: "null") { keyword = "null" }
                else { keyword = nil }

                if let kw = keyword {
                    colorRange(i, i + kw.count, colors.warningColor)
                    i += kw.count
                    continue
                }
            }

            // Punctuation: { } [ ] : ,
            if ch == "{" || ch == "}" || ch == "[" || ch == "]" || ch == ":" || ch == "," {
                colorRange(i, i + 1, colors.mutedText)
                i += 1
                continue
            }

            i += 1
        }

        return result
    }

    private static func matches(_ scalars: [Character], at index: Int, keyword: String) -> Bool {
        let kw = Array(keyword)
        guard index + kw.count <= scalars.count else { return false }
        for (offset, c) in kw.enumerated() where scalars[index + offset] != c {
            return false
        }
        return true
    }
}
