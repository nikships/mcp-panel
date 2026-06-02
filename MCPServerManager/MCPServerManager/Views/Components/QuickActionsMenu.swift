import SwiftUI
import UniformTypeIdentifiers

struct QuickActionsMenu: View {
    @ObservedObject var viewModel: ServerViewModel
    @Binding var showAddServer: Bool
    @Binding var showImporter: Bool
    @Binding var showExporter: Bool
    @Binding var isExpanded: Bool
    @Environment(\.themeColors) private var themeColors
    @State private var animateIn = false

    private enum QuickAction: CaseIterable {
        case registry
        case addServer
        case importJSON
        case exportJSON

        var icon: String {
            switch self {
            case .registry: return "sparkles"
            case .addServer: return "plus"
            case .importJSON: return "arrow.down.doc"
            case .exportJSON: return "arrow.up.doc"
            }
        }

        var title: String {
            switch self {
            case .registry: return "Explore MCPs"
            case .addServer: return "New Server"
            case .importJSON: return "Import"
            case .exportJSON: return "Export"
            }
        }

        var subtitle: String {
            switch self {
            case .registry: return "Browse registry"
            case .addServer: return "Add manually"
            case .importJSON: return "From JSON file"
            case .exportJSON: return "To JSON file"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text("Quick Actions")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(themeColors.mutedText)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.leading, 4)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : -10)

            VStack(spacing: 4) {
                ForEach(Array(QuickAction.allCases.enumerated()), id: \.element) { index, action in
                    QuickActionButton(
                        icon: action.icon,
                        title: action.title,
                        subtitle: action.subtitle,
                        color: color(for: action),
                        delay: Double(index) * 0.05,
                        animateIn: animateIn
                    ) {
                        handleAction(action)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeColors.panelBackground.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeColors.borderColor, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.9, anchor: .topLeading)

            // Keyboard hint
            Text("Press ESC to close")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(themeColors.mutedText)
                .padding(.leading, 4)
                .opacity(animateIn ? 0.6 : 0)
                .offset(y: animateIn ? 0 : 10)
        }
        .frame(width: 200, alignment: .leading)
        .padding(.top, 70)
        .padding(.leading, 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }

    private func color(for action: QuickAction) -> Color {
        switch action {
        case .registry: return themeColors.secondaryAccent
        case .addServer: return themeColors.successColor
        case .importJSON: return themeColors.primaryAccent
        case .exportJSON: return themeColors.warningColor
        }
    }

    private func handleAction(_ action: QuickAction) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded = false
        }

        switch action {
        case .registry: openRegistry()
        case .addServer: showAddServer = true
        case .importJSON: showImporter = true
        case .exportJSON: showExporter = true
        }
    }

    private func openRegistry() {
        if let url = URL(string: AppConstants.mcpRegistryURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let delay: Double
    let animateIn: Bool
    let action: () -> Void
    @Environment(\.themeColors) private var themeColors
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isHovered ? themeColors.textOnAccent : color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHovered ? color : color.opacity(0.15))
                    )

                // Text
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DesignTokens.Typography.label)
                        .foregroundColor(themeColors.primaryText)

                    Text(subtitle)
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(themeColors.mutedText)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(themeColors.mutedText)
                    .opacity(isHovered ? 1 : 0)
                    .offset(x: isHovered ? 0 : -4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? themeColors.glassBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: animateIn)
    }
}
