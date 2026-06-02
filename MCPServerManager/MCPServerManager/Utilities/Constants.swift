import SwiftUI

// MARK: - App Constants

enum AppConstants {
    static let appName = "MCP Panel"
    static let defaultConfigPath = "~/.claude.json"
    static let mcpRegistryURL = "https://lobehub.com/mcp"
}

// MARK: - Design Tokens

enum DesignTokens {
    // MARK: - Theme-Aware Colors

    // Get colors for the current theme
    static func colors(for theme: AppTheme) -> ThemeColors {
        return ThemeColors.forTheme(theme)
    }

    // MARK: - Legacy Color Properties (for backward compatibility during migration)

    static let primaryGradient = LinearGradient(
        colors: [.cyan, .blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassBackground = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.1)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.016, green: 0.027, blue: 0.071),
            Color(red: 0.027, green: 0.067, blue: 0.122),
            Color(red: 0.012, green: 0.020, blue: 0.063)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successColor = Color.green
    static let errorColor = Color.red
    static let warningColor = Color.orange
    static let activeColor = Color.blue

    // MARK: - Typography

    // Font Family Names
    enum FontFamily {
        static let sans = "Poppins"
        static let serif = "Crimson Pro"
    }

    // Font Weights
    enum FontWeight {
        case regular
        case medium
        case semibold
        case bold

        var suffix: String {
            switch self {
            case .regular: return "-Regular"
            case .medium: return "-Medium"
            case .semibold: return "-SemiBold"
            case .bold: return "-Bold"
            }
        }
    }

    // Sans-serif fonts (Poppins) - for UI elements
    static func sans(size: CGFloat, weight: FontWeight = .regular) -> Font {
        return Font.custom(FontFamily.sans + weight.suffix, size: size)
    }

    // Serif fonts (Crimson Pro) - for body text and reading
    static func serif(size: CGFloat, weight: FontWeight = .regular) -> Font {
        return Font.custom(FontFamily.serif + weight.suffix, size: size)
    }

    // Monospace font for code/JSON
    static let monoFont = Font.system(.body, design: .monospaced)

    // Semantic Typography System
    enum Typography {
        // Display & Titles (Poppins - Sans)
        static let hero = sans(size: 60, weight: .bold)           // Onboarding emoji-like text
        static let display = sans(size: 40, weight: .bold)        // Empty state icons
        static let title1 = sans(size: 28, weight: .bold)         // Main titles
        static let title2 = sans(size: 22, weight: .semibold)     // Modal titles, server names
        static let title3 = sans(size: 20, weight: .semibold)     // Section headers

        // Body Text (Poppins - Sans for readability)
        static let bodyLarge = sans(size: 17, weight: .regular)  // Main body text
        static let body = sans(size: 14, weight: .regular)       // Standard body text
        static let bodySmall = sans(size: 12, weight: .regular)  // Secondary text

        // UI Elements (Poppins - Sans for clarity)
        static let buttonLarge = sans(size: 16, weight: .semibold)
        static let button = sans(size: 14, weight: .medium)
        static let label = sans(size: 14, weight: .regular)
        static let labelSmall = sans(size: 12, weight: .regular)
        static let caption = sans(size: 11, weight: .regular)
        static let captionSmall = sans(size: 10, weight: .bold)

        // Code & Technical (Monospace)
        static let codeLarge = Font.system(size: 15, design: .monospaced)
        static let code = Font.system(size: 13, design: .monospaced)
        static let codeSmall = Font.system(size: 11, design: .monospaced)
    }

    // MARK: - Spacing

    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let gridSpacing: CGFloat = 16

    // MARK: - Effects

    static let jsonPreviewBlurRadius: CGFloat = 8

    // MARK: - Shadows

    static func glassCardShadow() -> some View {
        EmptyView()
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Grid Configuration

enum GridConfiguration {
    static let columns = [
        GridItem(.adaptive(minimum: 400, maximum: 600), spacing: 16)
    ]
}
