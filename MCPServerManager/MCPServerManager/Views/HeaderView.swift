import SwiftUI

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var viewModel: ServerViewModel
    @Binding var showSettings: Bool
    @Binding var showAddServer: Bool
    @Binding var showQuickActions: Bool
    @Environment(\.themeColors) private var themeColors
    @State private var isSearchFocused = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: Logo + Title (logo has integrated quick actions)
            HStack(spacing: 12) {
                AppLogoView(themeColors: themeColors, showQuickActions: $showQuickActions)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MCP Panel")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(themeColors.primaryText)
                        .lineLimit(1)

                    Text(viewModel.servers.count == 1 ? "1 server" : "\(viewModel.servers.count) servers")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(themeColors.mutedText)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Spacer()

            // Center: Active config filename (read-only)
            ActiveConfigLabel(path: viewModel.settings.configPath, themeColors: themeColors)

            Spacer()

            // Right: Search + Settings
            HStack(spacing: 12) {
                SearchField(text: $viewModel.searchText, isFocused: $isSearchFocused)

                Divider()
                    .frame(height: 24)
                    .opacity(0.3)

                SettingsButton(showSettings: $showSettings, themeColors: themeColors)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .modifier(LiquidGlassModifier(shape: Rectangle(), fillColor: themeColors.sidebarBackground.opacity(0.8)))
    }
}

// MARK: - App Logo (with integrated Quick Actions)

private struct AppLogoView: View {
    let themeColors: ThemeColors
    @Binding var showQuickActions: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showQuickActions.toggle()
            }
        } label: {
            ZStack {
                // App icon (visible when not hovered and quick actions not open)
                Image(nsImage: AppIcon.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(isHovered || showQuickActions ? 0 : 1)
                    .scaleEffect(isHovered || showQuickActions ? 0.5 : 1)

                // Plus/X icon background + icon (visible when hovered or quick actions open)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColors.accentGradient)
                        .frame(width: 36, height: 36)

                    Image(systemName: showQuickActions ? "xmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeColors.textOnAccent)
                        .rotationEffect(.degrees(showQuickActions ? 0 : -90))
                }
                .opacity(isHovered || showQuickActions ? 1 : 0)
                .scaleEffect(isHovered || showQuickActions ? 1 : 0.5)
            }
            .shadow(
                color: themeColors.primaryAccent.opacity(isHovered || showQuickActions ? 0.5 : 0.2),
                radius: isHovered ? 12 : 6,
                x: 0,
                y: 4
            )
            .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .help("Quick Actions")
        .accessibilityLabel(showQuickActions ? "Close quick actions" : "Open quick actions")
    }
}

// MARK: - Active Config Label

private struct ActiveConfigLabel: View {
    let path: String
    let themeColors: ThemeColors

    private var isClaudeConfig: Bool {
        path.contains(".claude.json")
    }

    var body: some View {
        HStack(spacing: 8) {
            if isClaudeConfig, let logo = ServiceLogo.claude {
                Image(nsImage: logo)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(themeColors.primaryAccent)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeColors.primaryAccent)

                Text(path.shortPath())
                    .font(DesignTokens.Typography.label)
                    .foregroundColor(themeColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeColors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColors.borderColor, lineWidth: 1)
                )
        )
        .help(path)
        .accessibilityLabel(isClaudeConfig ? "Active config: Claude Code (\(path))" : "Active config: \(path)")
    }
}

// MARK: - Search Field

private struct SearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Environment(\.themeColors) private var themeColors
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isFocused ? themeColors.primaryAccent : themeColors.mutedText)

            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.body)
                .focused($fieldFocused)
                .onChange(of: fieldFocused) { newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFocused = newValue
                    }
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(themeColors.mutedText)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: isFocused ? 260 : 200)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeColors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? themeColors.primaryAccent.opacity(0.5) : themeColors.borderColor, lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}

// MARK: - Settings Button

private struct SettingsButton: View {
    @Binding var showSettings: Bool
    let themeColors: ThemeColors
    @State private var isHovered = false

    var body: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isHovered ? themeColors.primaryAccent : themeColors.secondaryText)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColors.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isHovered ? themeColors.primaryAccent.opacity(0.4) : themeColors.borderColor, lineWidth: 1)
                        )
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("Settings")
        .accessibilityLabel("Settings")
    }
}
