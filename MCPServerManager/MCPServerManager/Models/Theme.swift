import SwiftUI

// MARK: - Theme Type

enum AppTheme: String, CaseIterable {
    case auto = "Auto (Detect from Config)"
    case claudeCode = "Claude Code"
    case `default` = "Default (Cyberpunk)"
    case nord = "Nord"
    case dracula = "Dracula"
    case solarizedDark = "Solarized Dark"
    case solarizedLight = "Solarized Light"
    case monokai = "Monokai Pro"
    case oneDark = "One Dark"
    case githubDark = "GitHub Dark"
    case tokyoNight = "Tokyo Night"
    case catppuccin = "Catppuccin Mocha"
    case gruvbox = "Gruvbox Dark"
    case palenight = "Material Palenight"

    // Detect theme from config path
    static func detect(from configPath: String) -> AppTheme {
        let lowercased = configPath.lowercased()

        if lowercased.contains("claude") {
            return .claudeCode
        } else {
            return .default
        }
    }
}

// MARK: - Theme Colors

struct ThemeColors {
    // Background colors
    let mainBackground: Color
    let sidebarBackground: Color
    let panelBackground: Color
    let glassBackground: Color
    let glassBorder: Color

    // Text colors
    let primaryText: Color
    let secondaryText: Color
    let mutedText: Color
    let textOnAccent: Color

    // Accent colors
    let primaryAccent: Color
    let secondaryAccent: Color
    let successColor: Color
    let errorColor: Color
    let warningColor: Color

    // UI element colors
    let borderColor: Color
    let selectionColor: Color
    let lineHighlight: Color

    // Gradients
    let backgroundGradient: LinearGradient
    let accentGradient: LinearGradient

    // MARK: - Theme Presets

    static let claudeCode = ThemeColors(
        // Background - pitch black base
        mainBackground: Color(hex: "#0b0e14"),
        sidebarBackground: Color(hex: "#262626"),
        panelBackground: Color(hex: "#0b0e14"),
        glassBackground: Color.white.opacity(0.02),
        glassBorder: Color(hex: "#303030").opacity(0.5),

        // Text colors
        primaryText: Color(hex: "#c3c1ba"),
        secondaryText: Color(hex: "#faf8f1").opacity(0.7),
        mutedText: Color(hex: "#c3c1ba").opacity(0.5),
        textOnAccent: Color(hex: "#1a1a1a"),

        // Accent colors - Claude Code brand
        primaryAccent: Color(hex: "#d87757"), // Claude Code primary
        secondaryAccent: Color(hex: "#faf8f1"), // Secondary
        successColor: Color.green,
        errorColor: Color(hex: "#f14444"), // Destructive red
        warningColor: Color.orange,

        // UI elements
        borderColor: Color(hex: "#303030"),
        selectionColor: Color(hex: "#d87757").opacity(0.3),
        lineHighlight: Color(hex: "#262626"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#0b0e14"),
                Color(hex: "#262626"),
                Color(hex: "#0b0e14")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [
                Color(hex: "#d87757"),
                Color(hex: "#faf8f1")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let `default` = ThemeColors(
        // Original cyberpunk-ish theme
        mainBackground: Color(red: 0.016, green: 0.027, blue: 0.071),
        sidebarBackground: Color(red: 0.027, green: 0.067, blue: 0.122),
        panelBackground: Color(red: 0.012, green: 0.020, blue: 0.063),
        glassBackground: Color.white.opacity(0.05),
        glassBorder: Color.white.opacity(0.1),

        // Text colors
        primaryText: Color.white.opacity(0.9),
        secondaryText: Color.white.opacity(0.7),
        mutedText: Color.white.opacity(0.5),
        textOnAccent: Color(hex: "#1a1a1a"),

        // Accent colors
        primaryAccent: Color.cyan,
        secondaryAccent: Color.blue,
        successColor: Color.green,
        errorColor: Color.red,
        warningColor: Color.orange,

        // UI elements
        borderColor: Color.white.opacity(0.1),
        selectionColor: Color.blue.opacity(0.3),
        lineHighlight: Color.white.opacity(0.05),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [
                Color(red: 0.016, green: 0.027, blue: 0.071),
                Color(red: 0.027, green: 0.067, blue: 0.122),
                Color(red: 0.012, green: 0.020, blue: 0.063)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [.cyan, .blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let nord = ThemeColors(
        // Nord - Arctic, north-bluish color palette
        mainBackground: Color(hex: "#2E3440"),
        sidebarBackground: Color(hex: "#3B4252"),
        panelBackground: Color(hex: "#2E3440"),
        glassBackground: Color(hex: "#4C566A").opacity(0.1),
        glassBorder: Color(hex: "#4C566A").opacity(0.3),

        // Text - Nord Snow Storm
        primaryText: Color(hex: "#ECEFF4"),
        secondaryText: Color(hex: "#D8DEE9"),
        mutedText: Color(hex: "#4C566A"),
        textOnAccent: Color(hex: "#2E3440"),

        // Accents - Nord Frost
        primaryAccent: Color(hex: "#88C0D0"),
        secondaryAccent: Color(hex: "#81A1C1"),
        successColor: Color(hex: "#A3BE8C"),
        errorColor: Color(hex: "#BF616A"),
        warningColor: Color(hex: "#EBCB8B"),

        // UI
        borderColor: Color(hex: "#4C566A"),
        selectionColor: Color(hex: "#88C0D0").opacity(0.3),
        lineHighlight: Color(hex: "#3B4252"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#2E3440"), Color(hex: "#3B4252"), Color(hex: "#434C5E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#88C0D0"), Color(hex: "#81A1C1"), Color(hex: "#5E81AC")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let dracula = ThemeColors(
        // Dracula - Dark theme with purple accents
        mainBackground: Color(hex: "#282A36"),
        sidebarBackground: Color(hex: "#21222C"),
        panelBackground: Color(hex: "#282A36"),
        glassBackground: Color(hex: "#44475A").opacity(0.2),
        glassBorder: Color(hex: "#6272A4").opacity(0.3),

        // Text
        primaryText: Color(hex: "#F8F8F2"),
        secondaryText: Color(hex: "#F8F8F2").opacity(0.8),
        mutedText: Color(hex: "#6272A4"),
        textOnAccent: Color(hex: "#282A36"),

        // Accents
        primaryAccent: Color(hex: "#BD93F9"),
        secondaryAccent: Color(hex: "#FF79C6"),
        successColor: Color(hex: "#50FA7B"),
        errorColor: Color(hex: "#FF5555"),
        warningColor: Color(hex: "#F1FA8C"),

        // UI
        borderColor: Color(hex: "#44475A"),
        selectionColor: Color(hex: "#BD93F9").opacity(0.3),
        lineHighlight: Color(hex: "#44475A"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#282A36"), Color(hex: "#21222C"), Color(hex: "#191A21")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#BD93F9"), Color(hex: "#FF79C6"), Color(hex: "#8BE9FD")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let solarizedDark = ThemeColors(
        // Solarized Dark - Precision colors for machines and people
        mainBackground: Color(hex: "#002B36"),
        sidebarBackground: Color(hex: "#073642"),
        panelBackground: Color(hex: "#002B36"),
        glassBackground: Color(hex: "#073642").opacity(0.5),
        glassBorder: Color(hex: "#586E75").opacity(0.3),

        // Text
        primaryText: Color(hex: "#FDF6E3"),
        secondaryText: Color(hex: "#EEE8D5"),
        mutedText: Color(hex: "#586E75"),
        textOnAccent: Color(hex: "#002B36"),

        // Accents
        primaryAccent: Color(hex: "#268BD2"),
        secondaryAccent: Color(hex: "#2AA198"),
        successColor: Color(hex: "#859900"),
        errorColor: Color(hex: "#DC322F"),
        warningColor: Color(hex: "#B58900"),

        // UI
        borderColor: Color(hex: "#073642"),
        selectionColor: Color(hex: "#268BD2").opacity(0.3),
        lineHighlight: Color(hex: "#073642"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#002B36"), Color(hex: "#073642"), Color(hex: "#002B36")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#268BD2"), Color(hex: "#2AA198"), Color(hex: "#6C71C4")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let solarizedLight = ThemeColors(
        // Solarized Light - Light theme variant
        mainBackground: Color(hex: "#FDF6E3"),
        sidebarBackground: Color(hex: "#EEE8D5"),
        panelBackground: Color(hex: "#FDF6E3"),
        glassBackground: Color(hex: "#EEE8D5").opacity(0.5),
        glassBorder: Color(hex: "#93A1A1").opacity(0.3),

        // Text
        primaryText: Color(hex: "#002B36"),
        secondaryText: Color(hex: "#073642"),
        mutedText: Color(hex: "#93A1A1"),
        textOnAccent: Color(hex: "#FDF6E3"),

        // Accents
        primaryAccent: Color(hex: "#268BD2"),
        secondaryAccent: Color(hex: "#2AA198"),
        successColor: Color(hex: "#859900"),
        errorColor: Color(hex: "#DC322F"),
        warningColor: Color(hex: "#B58900"),

        // UI
        borderColor: Color(hex: "#EEE8D5"),
        selectionColor: Color(hex: "#268BD2").opacity(0.2),
        lineHighlight: Color(hex: "#EEE8D5"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#FDF6E3"), Color(hex: "#EEE8D5"), Color(hex: "#FDF6E3")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#268BD2"), Color(hex: "#2AA198"), Color(hex: "#6C71C4")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let monokai = ThemeColors(
        // Monokai Pro - Warm dark theme
        mainBackground: Color(hex: "#2D2A2E"),
        sidebarBackground: Color(hex: "#221F22"),
        panelBackground: Color(hex: "#2D2A2E"),
        glassBackground: Color(hex: "#403E41").opacity(0.3),
        glassBorder: Color(hex: "#5B595C").opacity(0.3),

        // Text
        primaryText: Color(hex: "#FCFCFA"),
        secondaryText: Color(hex: "#FCFCFA").opacity(0.8),
        mutedText: Color(hex: "#727072"),
        textOnAccent: Color(hex: "#2D2A2E"),

        // Accents
        primaryAccent: Color(hex: "#FFD866"),
        secondaryAccent: Color(hex: "#FF6188"),
        successColor: Color(hex: "#A9DC76"),
        errorColor: Color(hex: "#FF6188"),
        warningColor: Color(hex: "#FC9867"),

        // UI
        borderColor: Color(hex: "#403E41"),
        selectionColor: Color(hex: "#FFD866").opacity(0.3),
        lineHighlight: Color(hex: "#403E41"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#2D2A2E"), Color(hex: "#221F22"), Color(hex: "#19181A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#FFD866"), Color(hex: "#FC9867"), Color(hex: "#FF6188")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let oneDark = ThemeColors(
        // One Dark - Atom's iconic dark theme
        mainBackground: Color(hex: "#282C34"),
        sidebarBackground: Color(hex: "#21252B"),
        panelBackground: Color(hex: "#282C34"),
        glassBackground: Color(hex: "#3E4451").opacity(0.3),
        glassBorder: Color(hex: "#3E4451").opacity(0.5),

        // Text
        primaryText: Color(hex: "#ABB2BF"),
        secondaryText: Color(hex: "#ABB2BF").opacity(0.8),
        mutedText: Color(hex: "#5C6370"),
        textOnAccent: Color(hex: "#282C34"),

        // Accents
        primaryAccent: Color(hex: "#61AFEF"),
        secondaryAccent: Color(hex: "#C678DD"),
        successColor: Color(hex: "#98C379"),
        errorColor: Color(hex: "#E06C75"),
        warningColor: Color(hex: "#E5C07B"),

        // UI
        borderColor: Color(hex: "#3E4451"),
        selectionColor: Color(hex: "#61AFEF").opacity(0.3),
        lineHighlight: Color(hex: "#2C313A"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#282C34"), Color(hex: "#21252B"), Color(hex: "#181A1F")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#61AFEF"), Color(hex: "#C678DD"), Color(hex: "#56B6C2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let githubDark = ThemeColors(
        // GitHub Dark - GitHub's dark theme
        mainBackground: Color(hex: "#0D1117"),
        sidebarBackground: Color(hex: "#161B22"),
        panelBackground: Color(hex: "#0D1117"),
        glassBackground: Color(hex: "#21262D").opacity(0.3),
        glassBorder: Color(hex: "#30363D").opacity(0.5),

        // Text
        primaryText: Color(hex: "#C9D1D9"),
        secondaryText: Color(hex: "#8B949E"),
        mutedText: Color(hex: "#484F58"),
        textOnAccent: Color(hex: "#FFFFFF"),

        // Accents
        primaryAccent: Color(hex: "#58A6FF"),
        secondaryAccent: Color(hex: "#1F6FEB"),
        successColor: Color(hex: "#3FB950"),
        errorColor: Color(hex: "#F85149"),
        warningColor: Color(hex: "#D29922"),

        // UI
        borderColor: Color(hex: "#30363D"),
        selectionColor: Color(hex: "#58A6FF").opacity(0.3),
        lineHighlight: Color(hex: "#161B22"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#0D1117"), Color(hex: "#161B22"), Color(hex: "#010409")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#58A6FF"), Color(hex: "#1F6FEB"), Color(hex: "#388BFD")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let tokyoNight = ThemeColors(
        // Tokyo Night - A clean, dark theme with neon highlights
        mainBackground: Color(hex: "#1A1B26"),
        sidebarBackground: Color(hex: "#16161E"),
        panelBackground: Color(hex: "#1A1B26"),
        glassBackground: Color(hex: "#24283B").opacity(0.3),
        glassBorder: Color(hex: "#414868").opacity(0.3),

        // Text
        primaryText: Color(hex: "#C0CAF5"),
        secondaryText: Color(hex: "#A9B1D6"),
        mutedText: Color(hex: "#565F89"),
        textOnAccent: Color(hex: "#1A1B26"),

        // Accents
        primaryAccent: Color(hex: "#7AA2F7"),
        secondaryAccent: Color(hex: "#BB9AF7"),
        successColor: Color(hex: "#9ECE6A"),
        errorColor: Color(hex: "#F7768E"),
        warningColor: Color(hex: "#E0AF68"),

        // UI
        borderColor: Color(hex: "#414868"),
        selectionColor: Color(hex: "#7AA2F7").opacity(0.3),
        lineHighlight: Color(hex: "#24283B"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#1A1B26"), Color(hex: "#16161E"), Color(hex: "#0F0F14")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#7AA2F7"), Color(hex: "#BB9AF7"), Color(hex: "#2AC3DE")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let catppuccin = ThemeColors(
        // Catppuccin Mocha - Warm, pastel dark theme
        mainBackground: Color(hex: "#1E1E2E"),
        sidebarBackground: Color(hex: "#181825"),
        panelBackground: Color(hex: "#1E1E2E"),
        glassBackground: Color(hex: "#313244").opacity(0.3),
        glassBorder: Color(hex: "#45475A").opacity(0.3),

        // Text
        primaryText: Color(hex: "#CDD6F4"),
        secondaryText: Color(hex: "#BAC2DE"),
        mutedText: Color(hex: "#6C7086"),
        textOnAccent: Color(hex: "#1E1E2E"),

        // Accents
        primaryAccent: Color(hex: "#89B4FA"),
        secondaryAccent: Color(hex: "#CBA6F7"),
        successColor: Color(hex: "#A6E3A1"),
        errorColor: Color(hex: "#F38BA8"),
        warningColor: Color(hex: "#F9E2AF"),

        // UI
        borderColor: Color(hex: "#45475A"),
        selectionColor: Color(hex: "#89B4FA").opacity(0.3),
        lineHighlight: Color(hex: "#313244"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#1E1E2E"), Color(hex: "#181825"), Color(hex: "#11111B")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#89B4FA"), Color(hex: "#CBA6F7"), Color(hex: "#F5C2E7")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let gruvbox = ThemeColors(
        // Gruvbox Dark - Retro groove color scheme
        mainBackground: Color(hex: "#282828"),
        sidebarBackground: Color(hex: "#1D2021"),
        panelBackground: Color(hex: "#282828"),
        glassBackground: Color(hex: "#3C3836").opacity(0.3),
        glassBorder: Color(hex: "#504945").opacity(0.3),

        // Text
        primaryText: Color(hex: "#EBDBB2"),
        secondaryText: Color(hex: "#D5C4A1"),
        mutedText: Color(hex: "#928374"),
        textOnAccent: Color(hex: "#282828"),

        // Accents
        primaryAccent: Color(hex: "#83A598"),
        secondaryAccent: Color(hex: "#D3869B"),
        successColor: Color(hex: "#B8BB26"),
        errorColor: Color(hex: "#FB4934"),
        warningColor: Color(hex: "#FABD2F"),

        // UI
        borderColor: Color(hex: "#504945"),
        selectionColor: Color(hex: "#83A598").opacity(0.3),
        lineHighlight: Color(hex: "#3C3836"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#282828"), Color(hex: "#1D2021"), Color(hex: "#0E1013")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#83A598"), Color(hex: "#D3869B"), Color(hex: "#8EC07C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let palenight = ThemeColors(
        // Material Palenight - Deep ocean syntax theme
        mainBackground: Color(hex: "#292D3E"),
        sidebarBackground: Color(hex: "#1F2233"),
        panelBackground: Color(hex: "#292D3E"),
        glassBackground: Color(hex: "#3B3F51").opacity(0.3),
        glassBorder: Color(hex: "#4E5579").opacity(0.3),

        // Text
        primaryText: Color(hex: "#BABFC7"),
        secondaryText: Color(hex: "#959DCB"),
        mutedText: Color(hex: "#676E95"),
        textOnAccent: Color(hex: "#292D3E"),

        // Accents
        primaryAccent: Color(hex: "#82AAFF"),
        secondaryAccent: Color(hex: "#C792EA"),
        successColor: Color(hex: "#C3E88D"),
        errorColor: Color(hex: "#F07178"),
        warningColor: Color(hex: "#FFCB6B"),

        // UI
        borderColor: Color(hex: "#4E5579"),
        selectionColor: Color(hex: "#82AAFF").opacity(0.3),
        lineHighlight: Color(hex: "#3B3F51"),

        // Gradients
        backgroundGradient: LinearGradient(
            colors: [Color(hex: "#292D3E"), Color(hex: "#1F2233"), Color(hex: "#15182A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentGradient: LinearGradient(
            colors: [Color(hex: "#82AAFF"), Color(hex: "#C792EA"), Color(hex: "#89DDFF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    // Get theme colors for a specific theme type
    static func forTheme(_ theme: AppTheme) -> ThemeColors {
        switch theme {
        case .auto:
            return .default // Will be overridden by detection logic
        case .claudeCode:
            return .claudeCode
        case .default:
            return .default
        case .nord:
            return .nord
        case .dracula:
            return .dracula
        case .solarizedDark:
            return .solarizedDark
        case .solarizedLight:
            return .solarizedLight
        case .monokai:
            return .monokai
        case .oneDark:
            return .oneDark
        case .githubDark:
            return .githubDark
        case .tokyoNight:
            return .tokyoNight
        case .catppuccin:
            return .catppuccin
        case .gruvbox:
            return .gruvbox
        case .palenight:
            return .palenight
        }
    }

}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Environment Keys for Theme

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ThemeColors = .default
}

private struct CurrentThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .default
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }

    var currentTheme: AppTheme {
        get { self[CurrentThemeKey.self] }
        set { self[CurrentThemeKey.self] = newValue }
    }
}
