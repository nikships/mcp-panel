import SwiftUI
import AppKit

/// An editable, theme-aware JSON code editor backed by `NSTextView`.
///
/// Live re-highlights on edit (debounced), uses a monospaced font, and a theme-aware background
/// surface that respects Reduce Transparency. Two-way bound to a `String`.
struct JSONCodeEditor: NSViewRepresentable {
    @Binding var text: String
    let themeColors: ThemeColors
    var fontSize: CGFloat = 13
    var isEditable: Bool = true
    var reduceTransparency: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = surfaceColor()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = surfaceColor()
        textView.drawsBackground = true
        textView.textColor = NSColor(themeColors.primaryText)
        textView.insertionPointColor = NSColor(themeColors.primaryAccent)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        context.coordinator.textView = textView
        context.coordinator.applyHighlight(to: textView, text: text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.parent = self

        let newSurface = surfaceColor()
        scrollView.backgroundColor = newSurface
        textView.backgroundColor = newSurface
        textView.insertionPointColor = NSColor(themeColors.primaryAccent)
        textView.isEditable = isEditable

        // Only replace text if it changed externally (not from user typing in this view).
        if textView.string != text {
            let selected = textView.selectedRange()
            context.coordinator.applyHighlight(to: textView, text: text)
            if selected.location <= (textView.string as NSString).length {
                textView.setSelectedRange(selected)
            }
        } else {
            // Re-apply highlight for theme changes.
            context.coordinator.applyHighlight(to: textView, text: text, preserveSelection: true)
        }
    }

    private func surfaceColor() -> NSColor {
        if reduceTransparency {
            return NSColor(themeColors.panelBackground)
        }
        // Subtle theme-aware translucent surface.
        return NSColor(themeColors.mainBackground).withAlphaComponent(0.55)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONCodeEditor
        weak var textView: NSTextView?
        private var debounceWorkItem: DispatchWorkItem?

        init(_ parent: JSONCodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            parent.text = newText

            // Debounce re-highlighting while typing.
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.applyHighlight(to: textView, text: textView.string, preserveSelection: true)
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }

        /// Apply syntax highlighting to the text view's storage.
        func applyHighlight(to textView: NSTextView, text: String, preserveSelection: Bool = false) {
            guard let storage = textView.textStorage else {
                textView.string = text
                return
            }

            let selected = textView.selectedRange()

            // Bridging `NSAttributedString(AttributedString)` drops SwiftUI-scope foreground
            // colors, so the text view would render default (black) text. Instead, build an
            // NSAttributedString directly and map the highlighter's per-run SwiftUI colors to
            // AppKit `.foregroundColor` (NSColor) attributes.
            let attributed = JSONSyntaxHighlighter.highlight(text, colors: parent.themeColors)
            let ns = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            ns.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular), range: fullRange)
            ns.addAttribute(.foregroundColor, value: NSColor(parent.themeColors.primaryText), range: fullRange)

            for run in attributed.runs {
                guard let color = run.foregroundColor else { continue }
                let lower = attributed.characters.distance(from: attributed.startIndex, to: run.range.lowerBound)
                let upper = attributed.characters.distance(from: attributed.startIndex, to: run.range.upperBound)
                guard lower < upper,
                      let sLower = text.index(text.startIndex, offsetBy: lower, limitedBy: text.endIndex),
                      let sUpper = text.index(text.startIndex, offsetBy: upper, limitedBy: text.endIndex) else { continue }
                ns.addAttribute(.foregroundColor, value: NSColor(color), range: NSRange(sLower..<sUpper, in: text))
            }

            storage.beginEditing()
            storage.setAttributedString(ns)
            storage.endEditing()

            if preserveSelection, selected.location + selected.length <= ns.length {
                textView.setSelectedRange(selected)
            }
        }
    }
}
