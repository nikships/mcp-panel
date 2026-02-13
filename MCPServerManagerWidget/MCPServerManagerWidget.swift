import WidgetKit
import SwiftUI
import AppIntents

/// Main entry point for the MCP Server Manager Widget
@main
struct MCPServerManagerWidgetBundle: WidgetBundle {
    var body: some Widget {
        MCPServerManagerWidget()
    }
}

struct MCPServerManagerWidget: Widget {
    let kind: String = "MCPServerManagerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WidgetProvider()
        ) { entry in
            if #available(macOS 14.0, *) {
                MCPWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        WidgetThemeColors.forTheme(entry.themeName).background
                    }
            } else {
                MCPWidgetEntryView(entry: entry)
                    .padding()
                    .background(WidgetThemeColors.forTheme(entry.themeName).background)
            }
        }
        .configurationDisplayName("MCP Servers")
        .description("Quick toggle for your MCP servers")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Widget entry containing server data
struct ServerEntry: TimelineEntry {
    let date: Date
    let servers: [WidgetServerModel]
    let configName: String
    let themeName: String
    let activeConfigIndex: Int
}

/// Simplified server model for widget display
struct WidgetServerModel: Identifiable {
    let id: UUID
    let name: String
    var isEnabled: Bool
    var inConfigs: [Bool]
}

