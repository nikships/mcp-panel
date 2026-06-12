import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: ServerViewModel
    @Namespace private var namespace
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        HStack(spacing: 16) {
            // Left: View Mode Toggle
            viewModeToggle()

            // Separator
            Divider()
                .frame(height: 24)
                .opacity(0.3)

            // Center: Filter Pills
            filterPills()

            Spacer()

            // Right: Actions
            rightSideActions()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(themeColors.mainBackground.opacity(0.5))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [themeColors.borderColor.opacity(0.3), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    // MARK: - View Mode Toggle

    @ViewBuilder
    private func viewModeToggle() -> some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                viewModeButton(mode: mode)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeColors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColors.borderColor, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func viewModeButton(mode: ViewMode) -> some View {
        let isSelected = viewModel.viewMode == mode

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.viewMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(mode.displayName)
                    .font(DesignTokens.Typography.labelSmall)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(isSelected ? themeColors.textOnAccent : themeColors.mutedText)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColors.accentGradient)
                        .shadow(color: themeColors.primaryAccent.opacity(0.3), radius: 4, x: 0, y: 2)
                        .matchedGeometryEffect(id: "viewModePill", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Pills

    @ViewBuilder
    private func filterPills() -> some View {
        HStack(spacing: 6) {
            ForEach(FilterMode.allCases, id: \.self) { mode in
                filterPillButton(mode: mode)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func filterPillButton(mode: FilterMode) -> some View {
        let isSelected = viewModel.filterMode == mode
        let count = filterCount(for: mode)

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.filterMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(filterColor(for: mode, isSelected: isSelected))
                    .frame(width: 8, height: 8)

                Text(mode.label)
                    .font(DesignTokens.Typography.labelSmall)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if count > 0 {
                    Text("\(count)")
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(isSelected ? themeColors.primaryAccent : themeColors.mutedText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? themeColors.primaryAccent.opacity(0.15) : themeColors.glassBackground)
                        )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(isSelected ? themeColors.primaryText : themeColors.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? themeColors.primaryAccent.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? themeColors.primaryAccent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func filterColor(for mode: FilterMode, isSelected: Bool) -> Color {
        switch mode {
        case .all:
            return isSelected ? themeColors.primaryAccent : themeColors.mutedText
        case .active:
            return themeColors.successColor
        case .disabled:
            return themeColors.errorColor
        case .recent:
            return themeColors.warningColor
        }
    }

    private func filterCount(for mode: FilterMode) -> Int {
        switch mode {
        case .all:
            return viewModel.servers.count
        case .active:
            return viewModel.servers.filter { $0.enabled }.count
        case .disabled:
            return viewModel.servers.filter { !$0.enabled }.count
        case .recent:
            // Servers modified in the last 24 hours.
            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            return viewModel.servers.filter { $0.updatedAt >= cutoff }.count
        }
    }

    // MARK: - Right Side Actions

    @ViewBuilder
    private func rightSideActions() -> some View {
        HStack(spacing: 10) {
            sortMenu()
            enableByTagMenu()
            toggleAllButton()
            refreshButton()
        }
    }

    @ViewBuilder
    private func sortMenu() -> some View {
        Menu {
            ForEach(SortMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.sortMode = mode
                    }
                } label: {
                    Label {
                        Text(mode.displayName)
                    } icon: {
                        if viewModel.sortMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                Text(viewModel.sortMode.label)
                    .font(DesignTokens.Typography.labelSmall)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.6)
            }
            .fixedSize(horizontal: true, vertical: false)
            .modifier(ToolbarButtonStyle())
        }
        .buttonStyle(.plain)
        .help("Sort servers")
        .accessibilityLabel("Sort servers")
    }

    @ViewBuilder
    private func enableByTagMenu() -> some View {
        Menu {
            ForEach(ServerTag.allCases) { tag in
                let count = viewModel.taggedServersCount(for: tag)
                Button { viewModel.enableServers(with: tag) } label: {
                    Label {
                        Text(count > 0 ? "\(tag.rawValue) (\(count))" : tag.rawValue)
                    } icon: {
                        Image(systemName: "tag.fill")
                    }
                }
                .disabled(count == 0)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 13, weight: .medium))
                Text("Tags")
                    .font(DesignTokens.Typography.labelSmall)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.6)
            }
            .fixedSize(horizontal: true, vertical: false)
            .modifier(ToolbarButtonStyle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func toggleAllButton() -> some View {
        let allEnabled = viewModel.servers.allSatisfy { $0.enabled }

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.toggleAllServers(!allEnabled)
            }
        } label: {
            HStack(spacing: 8) {
                Text(allEnabled ? "All Off" : "All On")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(themeColors.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                // Modern toggle switch
                ZStack {
                    Capsule()
                        .fill(allEnabled ? themeColors.successColor : themeColors.glassBackground)
                        .overlay(
                            Capsule()
                                .stroke(allEnabled ? Color.clear : themeColors.borderColor, lineWidth: 1)
                        )
                        .frame(width: 40, height: 22)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(x: allEnabled ? 9 : -9)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeColors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeColors.borderColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func refreshButton() -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.loadServers()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .medium))
                .modifier(ToolbarIconButtonStyle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: .command)
        .help("Reload from disk (⌘R)")
        .accessibilityLabel("Reload from disk")
    }
}

// MARK: - Toolbar Button Styles

private struct ToolbarButtonStyle: ViewModifier {
    @Environment(\.themeColors) private var themeColors
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .foregroundColor(isHovered ? themeColors.primaryAccent : themeColors.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeColors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? themeColors.primaryAccent.opacity(0.3) : themeColors.borderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

private struct ToolbarIconButtonStyle: ViewModifier {
    @Environment(\.themeColors) private var themeColors
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .foregroundColor(isHovered ? themeColors.primaryAccent : themeColors.secondaryText)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeColors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? themeColors.primaryAccent.opacity(0.3) : themeColors.borderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}
