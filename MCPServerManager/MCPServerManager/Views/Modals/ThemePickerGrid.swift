import SwiftUI

// MARK: - Theme Picker Grid

struct ThemePickerGrid: View {
    @Binding var selectedTheme: AppTheme
    let onThemeSelected: (AppTheme) -> Void

    @Environment(\.themeColors) private var themeColors

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                ThemeSwatchButton(
                    theme: theme,
                    isSelected: selectedTheme == theme,
                    action: { onThemeSelected(theme) }
                )
            }
        }
    }
}

// MARK: - Theme Swatch Button

private struct ThemeSwatchButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.themeColors) private var currentThemeColors
    @State private var isHovered: Bool = false

    private var themeColors: ThemeColors {
        ThemeColors.forTheme(theme)
    }

    // Extract short display name
    private var displayName: String {
        switch theme {
        case .claudeCode: return "Claude"
        case .default: return "Cyberpunk"
        case .solarizedDark: return "Sol Dark"
        case .solarizedLight: return "Sol Light"
        case .monokai: return "Monokai"
        case .oneDark: return "One Dark"
        case .githubDark: return "GitHub"
        case .tokyoNight: return "Tokyo"
        case .catppuccin: return "Catppuccin"
        default: return theme.rawValue.components(separatedBy: " ").first ?? theme.rawValue
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Color swatch preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeColors.mainBackground)
                    .frame(height: 44)
                    .overlay(
                        HStack(spacing: 4) {
                            Circle()
                                .fill(themeColors.primaryAccent)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(themeColors.secondaryAccent)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(themeColors.successColor)
                                .frame(width: 12, height: 12)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? currentThemeColors.primaryAccent : currentThemeColors.glassBorder,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                // Theme name
                Text(displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(isSelected ? currentThemeColors.primaryText : currentThemeColors.secondaryText)
                    .lineLimit(1)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                            ? currentThemeColors.selectionColor.opacity(0.5)
                            : (isHovered ? currentThemeColors.glassBackground : Color.clear)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
