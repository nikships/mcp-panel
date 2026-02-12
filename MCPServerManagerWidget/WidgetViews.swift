import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Widget Theme Colors

/// Lightweight theme colors for widget display
struct WidgetThemeColors {
    let primaryAccent: Color
    let background: Color
    let text: Color
    let mutedText: Color
    let success: Color

    static func forTheme(_ themeName: String) -> WidgetThemeColors {
        switch themeName {
        case "Claude Code":
            return .claudeCode
        case "Gemini CLI":
            return .geminiCLI
        case "Nord":
            return .nord
        case "Dracula":
            return .dracula
        case "Monokai Pro":
            return .monokai
        case "One Dark":
            return .oneDark
        case "GitHub Dark":
            return .githubDark
        case "Tokyo Night":
            return .tokyoNight
        case "Catppuccin Mocha":
            return .catppuccin
        case "Gruvbox Dark":
            return .gruvbox
        case "Material Palenight":
            return .palenight
        default:
            return .claudeCode
        }
    }

    static let claudeCode = WidgetThemeColors(
        primaryAccent: Color(hex: "#d87757"),
        background: Color(hex: "#0b0e14"),
        text: Color(hex: "#c3c1ba"),
        mutedText: Color(hex: "#c3c1ba").opacity(0.5),
        success: .green
    )

    static let geminiCLI = WidgetThemeColors(
        primaryAccent: Color(hex: "#39BAE6"),
        background: Color(hex: "#0b0e14"),
        text: Color(hex: "#aeaca6"),
        mutedText: Color(hex: "#646A71"),
        success: Color(hex: "#AAD94C")
    )

    static let nord = WidgetThemeColors(
        primaryAccent: Color(hex: "#88C0D0"),
        background: Color(hex: "#2E3440"),
        text: Color(hex: "#ECEFF4"),
        mutedText: Color(hex: "#4C566A"),
        success: Color(hex: "#A3BE8C")
    )

    static let dracula = WidgetThemeColors(
        primaryAccent: Color(hex: "#BD93F9"),
        background: Color(hex: "#282A36"),
        text: Color(hex: "#F8F8F2"),
        mutedText: Color(hex: "#6272A4"),
        success: Color(hex: "#50FA7B")
    )

    static let monokai = WidgetThemeColors(
        primaryAccent: Color(hex: "#FFD866"),
        background: Color(hex: "#2D2A2E"),
        text: Color(hex: "#FCFCFA"),
        mutedText: Color(hex: "#727072"),
        success: Color(hex: "#A9DC76")
    )

    static let oneDark = WidgetThemeColors(
        primaryAccent: Color(hex: "#61AFEF"),
        background: Color(hex: "#282C34"),
        text: Color(hex: "#ABB2BF"),
        mutedText: Color(hex: "#5C6370"),
        success: Color(hex: "#98C379")
    )

    static let githubDark = WidgetThemeColors(
        primaryAccent: Color(hex: "#58A6FF"),
        background: Color(hex: "#0D1117"),
        text: Color(hex: "#C9D1D9"),
        mutedText: Color(hex: "#484F58"),
        success: Color(hex: "#3FB950")
    )

    static let tokyoNight = WidgetThemeColors(
        primaryAccent: Color(hex: "#7AA2F7"),
        background: Color(hex: "#1A1B26"),
        text: Color(hex: "#C0CAF5"),
        mutedText: Color(hex: "#565F89"),
        success: Color(hex: "#9ECE6A")
    )

    static let catppuccin = WidgetThemeColors(
        primaryAccent: Color(hex: "#89B4FA"),
        background: Color(hex: "#1E1E2E"),
        text: Color(hex: "#CDD6F4"),
        mutedText: Color(hex: "#6C7086"),
        success: Color(hex: "#A6E3A1")
    )

    static let gruvbox = WidgetThemeColors(
        primaryAccent: Color(hex: "#83A598"),
        background: Color(hex: "#282828"),
        text: Color(hex: "#EBDBB2"),
        mutedText: Color(hex: "#928374"),
        success: Color(hex: "#B8BB26")
    )

    static let palenight = WidgetThemeColors(
        primaryAccent: Color(hex: "#82AAFF"),
        background: Color(hex: "#292D3E"),
        text: Color(hex: "#BABFC7"),
        mutedText: Color(hex: "#676E95"),
        success: Color(hex: "#C3E88D")
    )
}

// Color hex extension for widget
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

/// Main entry view for the widget
struct MCPWidgetEntryView: View {
    var entry: ServerEntry

    @Environment(\.widgetFamily) var family

    private var themeColors: WidgetThemeColors {
        WidgetThemeColors.forTheme(entry.themeName)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry, themeColors: themeColors)
        case .systemMedium:
            MediumWidgetView(entry: entry, themeColors: themeColors)
        case .systemLarge:
            LargeWidgetView(entry: entry, themeColors: themeColors)
        default:
            SmallWidgetView(entry: entry, themeColors: themeColors)
        }
    }
}

// MARK: - Small Widget (2 servers)

struct SmallWidgetView: View {
    let entry: ServerEntry
    let themeColors: WidgetThemeColors

    private var displayServers: [WidgetServerModel] {
        Array(entry.servers.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if displayServers.isEmpty {
                emptyStateView
            } else {
                ForEach(displayServers) { server in
                    WidgetServerRow(server: server, compact: true, themeColors: themeColors)
                }
            }

            Spacer()
        }
        .padding(12)
    }

    private var headerView: some View {
        HStack {
            Image("WidgetAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)

            Text("MCP")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeColors.primaryAccent)

            #if DEBUG
            Text("🔧")
                .font(.system(size: 10))
            #endif

            Spacer()

            Text(entry.configName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeColors.mutedText)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 4) {
            Image("WidgetAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .opacity(0.5)

            Text("No servers")
                .font(.system(size: 10))
                .foregroundColor(themeColors.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget (4 servers in 2x2 grid)

struct MediumWidgetView: View {
    let entry: ServerEntry
    let themeColors: WidgetThemeColors

    private var displayServers: [WidgetServerModel] {
        Array(entry.servers.prefix(4))
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if displayServers.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(displayServers) { server in
                        WidgetServerRow(server: server, compact: false, themeColors: themeColors)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
    }

    private var headerView: some View {
        HStack {
            Image("WidgetAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)

            Text("MCP Servers")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeColors.primaryAccent)

            #if DEBUG
            Text("🔧")
                .font(.system(size: 12))
            #endif

            Spacer()

            Text(entry.configName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(themeColors.mutedText)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image("WidgetAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .opacity(0.5)

            Text("No servers configured")
                .font(.system(size: 12))
                .foregroundColor(themeColors.mutedText)

            Text("Add servers in the app")
                .font(.system(size: 10))
                .foregroundColor(themeColors.mutedText.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Large Widget (8 servers in 2x4 grid)

struct LargeWidgetView: View {
    let entry: ServerEntry
    let themeColors: WidgetThemeColors

    private var displayServers: [WidgetServerModel] {
        Array(entry.servers.prefix(8))
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            if displayServers.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(displayServers) { server in
                        WidgetServerRow(server: server, compact: false, themeColors: themeColors)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
    }

    private var headerView: some View {
        HStack {
            Image("WidgetAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)

            Text("MCP Servers")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeColors.primaryAccent)

            #if DEBUG
            Text("🔧")
                .font(.system(size: 14))
            #endif

            Spacer()

            Text(entry.configName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeColors.mutedText)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image("WidgetAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .opacity(0.5)

            Text("No servers configured")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeColors.mutedText)

            Text("Open MCP Server Manager to add servers,\nthen mark them for widget display")
                .font(.system(size: 12))
                .foregroundColor(themeColors.mutedText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Server Row

struct WidgetServerRow: View {
    let server: WidgetServerModel
    let compact: Bool
    let themeColors: WidgetThemeColors

    var body: some View {
        if #available(macOS 14.0, *) {
            interactiveRow
        } else {
            staticRow
        }
    }

    @available(macOS 14.0, *)
    private var interactiveRow: some View {
        Button(intent: ServerToggleIntent(serverID: server.id.uuidString, newState: !server.isEnabled)) {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var staticRow: some View {
        rowContent
    }

    private var rowContent: some View {
        HStack(spacing: compact ? 6 : 8) {
            Circle()
                .fill(server.isEnabled ? themeColors.success : themeColors.mutedText)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)

            Text(server.name)
                .font(.system(size: compact ? 11 : 12, weight: server.isEnabled ? .medium : .regular))
                .foregroundColor(server.isEnabled ? themeColors.primaryAccent : themeColors.mutedText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Image(systemName: server.isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: compact ? 12 : 14))
                .foregroundColor(server.isEnabled ? themeColors.success : themeColors.mutedText)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.primaryAccent.opacity(0.1))
        )
    }
}

// MARK: - Previews

struct MCPWidgetEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleServers = [
            WidgetServerModel(id: UUID(), name: "filesystem", isEnabled: true),
            WidgetServerModel(id: UUID(), name: "github", isEnabled: true),
            WidgetServerModel(id: UUID(), name: "slack", isEnabled: false),
            WidgetServerModel(id: UUID(), name: "notion", isEnabled: true)
        ]

        let claudeEntry = ServerEntry(date: Date(), servers: sampleServers, configName: "Claude", themeName: "Claude Code")
        let geminiEntry = ServerEntry(date: Date(), servers: sampleServers, configName: "Gemini", themeName: "Gemini CLI")

        Group {
            MCPWidgetEntryView(entry: claudeEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small - Claude")

            MCPWidgetEntryView(entry: geminiEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small - Gemini")

            MCPWidgetEntryView(entry: claudeEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            MCPWidgetEntryView(entry: claudeEntry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}
