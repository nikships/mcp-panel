import SwiftUI

/// Read-only, theme-aware highlighted JSON renderer.
///
/// Highlighting is computed off the `body` path (in `.task`/`onChange`) and cached in `@State`,
/// keyed by `(jsonHash, themeName)`, per swiftui perf-patterns §2 (Anti-Pattern 2).
struct HighlightedJSONText: View {
    let json: String
    let themeColors: ThemeColors
    let themeName: String
    var fontSize: CGFloat = 13

    @State private var highlighted: AttributedString = AttributedString("")
    @State private var cacheKey: String = ""

    var body: some View {
        Text(highlighted)
            .font(.system(size: fontSize, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: currentKey) {
                recomputeIfNeeded()
            }
    }

    private var currentKey: String {
        "\(themeName)#\(json.hashValue)"
    }

    private func recomputeIfNeeded() {
        let key = currentKey
        guard key != cacheKey else { return }
        highlighted = JSONSyntaxHighlighter.highlight(json, colors: themeColors)
        cacheKey = key
    }
}
