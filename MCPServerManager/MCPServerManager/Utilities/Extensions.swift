import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func shortPath() -> String {
        // Smart naming based on parent folder/filename
        if self.contains(".claude.json") {
            return "Claude Code"
        }

        // Fallback to filename
        let components = self.split(separator: "/")
        return String(components.last ?? "")
    }

    /// `JSONSerialization` always escapes "/" as "\/", which is valid but noisy in the editors.
    /// Strip that escaping. This is safe: a literal backslash is emitted as "\\", so the only
    /// place "\" is immediately followed by "/" in valid JSON output is an escaped solidus.
    func unescapingJSONSlashes() -> String {
        replacingOccurrences(of: "\\/", with: "/")
    }

    /// Normalize various quotation mark styles to standard straight quotes
    /// Handles curly quotes commonly pasted from Notes, Word, Slack, etc.
    func normalizingQuotes() -> String {
        return self
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // Left double quotation mark
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // Right double quotation mark
            .replacingOccurrences(of: "\u{2018}", with: "'")   // Left single quotation mark
            .replacingOccurrences(of: "\u{2019}", with: "'")   // Right single quotation mark
            .replacingOccurrences(of: "\u{201A}", with: "'")   // Single low-9 quotation mark
            .replacingOccurrences(of: "\u{201E}", with: "\"")  // Double low-9 quotation mark
            .replacingOccurrences(of: "\u{00AB}", with: "\"")  // Left-pointing double angle quotation mark
            .replacingOccurrences(of: "\u{00BB}", with: "\"")  // Right-pointing double angle quotation mark
            .replacingOccurrences(of: "\u{2039}", with: "'")   // Single left-pointing angle quotation mark
            .replacingOccurrences(of: "\u{203A}", with: "'")   // Single right-pointing angle quotation mark
    }
}

// MARK: - JSON Formatting

enum JSONFormatter {
    /// Pretty-print a JSON string (sorted keys, unescaped slashes), normalizing curly quotes first.
    /// Returns nil if the input isn't valid JSON.
    static func prettyPrinted(_ string: String) -> String? {
        guard let data = string.normalizingQuotes().data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: formatted, encoding: .utf8) else {
            return nil
        }
        return result.unescapingJSONSlashes()
    }
}

// MARK: - Date Extensions

extension Date {
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: self, to: now)

        if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "just now"
        }
    }
}

// MARK: - View Extensions

#if os(macOS)
extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}
#endif

// MARK: - App Icon Helper

enum AppIcon {
    /// Get the app icon - tries bundle first (for swift run), then NSApp fallback
    static var image: NSImage {
        // Try loading from SPM bundle (for swift run)
        if let bundleURL = Bundle.main.url(forResource: "MCPServerManager_MCPServerManager", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL),
           let iconURL = bundle.url(
               forResource: "icon_512x512@2x",
               withExtension: "png",
               subdirectory: "Assets.xcassets/AppIcon.appiconset"
           ),
           let image = NSImage(contentsOf: iconURL) {
            return image
        }

        // Fallback to NSApp (works in release builds)
        return NSApp.applicationIconImage ?? NSImage()
    }
}

// MARK: - Bundled Service Logos

/// Loads bundled service logos (Claude, Codex) from the SPM resource bundle.
/// Logos are monochrome template PNGs intended to be tinted at render time.
enum ServiceLogo {
    static let claude = load("icon-claude")
    static let codex = load("icon-codex")

    private static func load(_ name: String) -> NSImage? {
        let bundleName = "MCPServerManager_MCPServerManager"

        if let resourceURL = Bundle.main.resourceURL,
           let bundle = Bundle(url: resourceURL.appendingPathComponent("\(bundleName).bundle")),
           let url = bundle.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            return image
        }

        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            return image
        }

        return nil
    }
}
