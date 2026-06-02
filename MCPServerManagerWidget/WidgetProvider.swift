import WidgetKit
import SwiftUI

/// Timeline provider for the MCP Server Manager Widget
struct WidgetProvider: TimelineProvider {
    typealias Entry = ServerEntry

    /// App Group identifier for accessing shared data
    private let suiteName = WidgetConstants.suiteName
    private let widgetServersKey = WidgetConstants.widgetServersKey
    private let currentThemeKey = WidgetConstants.currentThemeKey
    private let widgetActiveConfigKey = WidgetConstants.widgetActiveConfigKey
    private let activeConfigIndexKey = WidgetConstants.activeConfigIndexKey

    func placeholder(in context: Context) -> ServerEntry {
        ServerEntry(
            date: Date(),
            servers: [
                WidgetServerModel(id: UUID(), name: "example-server", isEnabled: true, inConfigs: [true, false]),
                WidgetServerModel(id: UUID(), name: "another-server", isEnabled: false, inConfigs: [true, true])
            ],
            configName: "Claude",
            themeName: "claudeCode",
            activeConfigIndex: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerEntry>) -> Void) {
        let entry = createEntry()

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry() -> ServerEntry {
        let allServers = loadWidgetServers()
        let activeConfig = loadActiveConfig()
        let configName = activeConfig == 0 ? "Claude" : "Gemini"
        let themeName = loadTheme()

        let filteredServers = allServers
            .map { server in
                WidgetServerModel(
                    id: server.id,
                    name: server.name,
                    isEnabled: server.inConfigs.count > activeConfig ? server.inConfigs[activeConfig] : false,
                    inConfigs: server.inConfigs
                )
            }

        return ServerEntry(
            date: Date(),
            servers: filteredServers,
            configName: configName,
            themeName: themeName,
            activeConfigIndex: activeConfig
        )
    }

    private func loadActiveConfig() -> Int {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return 0 }
        if defaults.object(forKey: widgetActiveConfigKey) != nil {
            return max(0, min(defaults.integer(forKey: widgetActiveConfigKey), 1))
        }
        return max(0, min(defaults.integer(forKey: activeConfigIndexKey), 1))
    }

    private func loadTheme() -> String {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return "claudeCode"
        }
        return defaults.string(forKey: currentThemeKey) ?? "claudeCode"
    }

    private func loadWidgetServers() -> [SharedWidgetServer] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: widgetServersKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SharedWidgetServer].self, from: data)
        } catch {
            return []
        }
    }
}

/// Shared widget server model (must match SharedDataManager.WidgetServer)
struct SharedWidgetServer: Codable, Identifiable {
    let id: UUID
    let name: String
    var isEnabled: Bool
    let configIndex: Int
    var inConfigs: [Bool]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        configIndex = try container.decode(Int.self, forKey: .configIndex)
        var decoded = try container.decodeIfPresent([Bool].self, forKey: .inConfigs) ?? [false, false]
        while decoded.count < 2 { decoded.append(false) }
        inConfigs = Array(decoded.prefix(2))
    }
}
