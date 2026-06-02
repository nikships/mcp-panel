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
        var index = 0

        // Helper to color a [start, end) range of character indices.
        func colorRange(_ start: Int, _ end: Int, _ color: Color) {
            guard start < end, end <= count else { return }
            let lower = result.index(result.startIndex, offsetByCharacters: start)
            let upper = result.index(result.startIndex, offsetByCharacters: end)
            result[lower..<upper].foregroundColor = color
        }

        while index < count {
            let ch = scalars[index]

            if ch == "\"" {
                // Parse a complete string token (handles escapes).
                let stringStart = index
                index += 1
                while index < count {
                    if scalars[index] == "\\" {
                        index += 2 // skip escaped char
                        continue
                    }
                    if scalars[index] == "\"" {
                        index += 1
                        break
                    }
                    index += 1
                }
                let stringEnd = index // exclusive

                // Determine whether this string is a key (next non-whitespace char is ':').
                var keyScanIndex = stringEnd
                while keyScanIndex < count,
                      scalars[keyScanIndex] == " " || scalars[keyScanIndex] == "\t"
                        || scalars[keyScanIndex] == "\n" || scalars[keyScanIndex] == "\r" {
                    keyScanIndex += 1
                }
                let isKey = keyScanIndex < count && scalars[keyScanIndex] == ":"

                colorRange(stringStart, stringEnd, isKey ? colors.primaryAccent : colors.successColor)
                continue
            }

            if ch == "-" || (ch >= "0" && ch <= "9") {
                // Parse a number token.
                let numStart = index
                index += 1
                while index < count {
                    let character = scalars[index]
                    if (character >= "0" && character <= "9") || character == "." || character == "e"
                        || character == "E" || character == "+" || character == "-" {
                        index += 1
                    } else {
                        break
                    }
                }
                colorRange(numStart, index, colors.secondaryAccent)
                continue
            }

            // Keywords: true / false / null
            if ch == "t" || ch == "f" || ch == "n" {
                let keyword: String?
                if matches(scalars, at: index, keyword: "true") {
                    keyword = "true"
                } else if matches(scalars, at: index, keyword: "false") {
                    keyword = "false"
                } else if matches(scalars, at: index, keyword: "null") {
                    keyword = "null"
                } else {
                    keyword = nil
                }

                if let kw = keyword {
                    colorRange(index, index + kw.count, colors.warningColor)
                    index += kw.count
                    continue
                }
            }

            // Punctuation: { } [ ] : ,
            if ch == "{" || ch == "}" || ch == "[" || ch == "]" || ch == ":" || ch == "," {
                colorRange(index, index + 1, colors.mutedText)
                index += 1
                continue
            }

            index += 1
        }

        return result
    }

    private static func matches(_ scalars: [Character], at index: Int, keyword: String) -> Bool {
        let kw = Array(keyword)
        guard index + kw.count <= scalars.count else { return false }
        for (offset, character) in kw.enumerated() where scalars[index + offset] != character {
            return false
        }
        return true
    }
}
