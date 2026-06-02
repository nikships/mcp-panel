import Foundation
import WidgetKit

/// Manages shared data between the main app and widget extension via App Groups
class SharedDataManager {
    static let shared = SharedDataManager()

    /// App Group identifier for sharing data between main app and widget
    private let suiteName = "group.com.anand-92.mcp-panel"

    /// Maximum number of servers that can be displayed in the widget
    static let maxWidgetServers = 8

    /// UserDefaults instance using App Group suite
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private let widgetServersKey = "widgetServers"
    private let config1PathKey = "config1Path"
    private let config2PathKey = "config2Path"
    private let activeConfigIndexKey = "activeConfigIndex"
    private let currentThemeKey = "currentTheme"

    // MARK: - Theme (for widget access)

    /// Save current theme to shared UserDefaults
    func saveTheme(_ theme: String) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(theme, forKey: currentThemeKey)
        defaults.synchronize()
        reloadWidgetTimeline()
        #if DEBUG
        print("SharedDataManager: Saved theme '\(theme)' to widget")
        #endif
    }

    /// Load theme from shared UserDefaults
    func loadTheme() -> String {
        sharedDefaults?.string(forKey: currentThemeKey) ?? "claudeCode"
    }

    // MARK: - Config Paths (for widget access)

    /// Save config paths to shared UserDefaults
    func saveConfigPaths(config1: String, config2: String, activeIndex: Int) {
        guard let defaults = sharedDefaults else { return }
        let normalizedActiveIndex = max(0, min(activeIndex, 1))
        defaults.set(config1, forKey: config1PathKey)
        defaults.set(config2, forKey: config2PathKey)
        defaults.set(normalizedActiveIndex, forKey: activeConfigIndexKey)

        // Preserve the widget's own selected config after it has been set, but
        // seed it from the app so first-run widgets do not assume config 0.
        if defaults.object(forKey: widgetActiveConfigKey) == nil {
            defaults.set(normalizedActiveIndex, forKey: widgetActiveConfigKey)
        }
        defaults.synchronize()
    }

    /// Load config paths from shared UserDefaults
    func loadConfigPaths() -> (config1: String, config2: String, activeIndex: Int)? {
        guard let defaults = sharedDefaults,
              let config1 = defaults.string(forKey: config1PathKey),
              let config2 = defaults.string(forKey: config2PathKey) else {
            return nil
        }
        let activeIndex = max(0, min(defaults.integer(forKey: activeConfigIndexKey), 1))
        return (config1, config2, activeIndex)
    }

    private let widgetActiveConfigKey = "widgetActiveConfigIndex"

    // MARK: - Widget Active Config

    func saveWidgetActiveConfig(_ index: Int) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(max(0, min(index, 1)), forKey: widgetActiveConfigKey)
        defaults.synchronize()
        reloadWidgetTimeline()
    }

    func loadWidgetActiveConfig() -> Int {
        guard let defaults = sharedDefaults else { return 0 }
        if defaults.object(forKey: widgetActiveConfigKey) != nil {
            return max(0, min(defaults.integer(forKey: widgetActiveConfigKey), 1))
        }
        return max(0, min(defaults.integer(forKey: activeConfigIndexKey), 1))
    }

    // MARK: - Widget Server Model

    /// Lightweight server model for widget display
    struct WidgetServer: Codable, Identifiable {
        let id: UUID
        let name: String
        var isEnabled: Bool
        let configIndex: Int // 0 = Claude, 1 = Gemini
        var inConfigs: [Bool] // [inClaude, inGemini] - whether server exists in each config

        var configName: String {
            configIndex == 0 ? "Claude" : "Gemini"
        }

        init(id: UUID, name: String, isEnabled: Bool, configIndex: Int, inConfigs: [Bool] = [false, false]) {
            self.id = id
            self.name = name
            self.isEnabled = isEnabled
            self.configIndex = configIndex
            self.inConfigs = inConfigs
        }

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

    // MARK: - Save/Load Widget Servers

    /// Save servers to shared UserDefaults for widget access
    func saveWidgetServers(_ servers: [WidgetServer]) {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("SharedDataManager: Failed to access App Group UserDefaults")
            #endif
            return
        }

        do {
            let data = try JSONEncoder().encode(servers)
            defaults.set(data, forKey: widgetServersKey)
            defaults.synchronize()

            // Reload widget timelines
            reloadWidgetTimeline()

            #if DEBUG
            print("SharedDataManager: Saved \(servers.count) servers to widget")
            #endif
        } catch {
            #if DEBUG
            print("SharedDataManager: Failed to encode widget servers: \(error)")
            #endif
        }
    }

    /// Load servers from shared UserDefaults
    func loadWidgetServers() -> [WidgetServer] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetServersKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([WidgetServer].self, from: data)
        } catch {
            #if DEBUG
            print("SharedDataManager: Failed to decode widget servers: \(error)")
            #endif
            return []
        }
    }

    /// Update a single server's enabled state
    func updateServerState(serverID: UUID, isEnabled: Bool) {
        var servers = loadWidgetServers()
        if let index = servers.firstIndex(where: { $0.id == serverID }) {
            servers[index].isEnabled = isEnabled
            let activeConfig = loadWidgetActiveConfig()
            while servers[index].inConfigs.count <= activeConfig {
                servers[index].inConfigs.append(false)
            }
            servers[index].inConfigs[activeConfig] = isEnabled
            saveWidgetServers(servers)
        }
    }

    // MARK: - Widget Timeline

    /// Request widget to reload its timeline
    func reloadWidgetTimeline() {
        if #available(macOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Notification Handling

    /// Notification name for server toggle from widget
    static let serverToggledNotificationName = "MCPServerToggled"

    /// Post notification when server is toggled (from widget to main app)
    func postServerToggledNotification(serverID: UUID, newState: Bool, configIndex: Int? = nil) {
        let userInfo: [String: Any] = [
            "serverID": serverID.uuidString,
            "newState": newState,
            "configIndex": configIndex ?? loadWidgetActiveConfig()
        ]

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(Self.serverToggledNotificationName),
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    /// Parse server toggle notification
    static func parseServerToggledNotification(_ notification: Notification) -> (serverID: UUID, newState: Bool)? {
        guard let userInfo = notification.userInfo,
              let serverIDString = userInfo["serverID"] as? String,
              let serverID = UUID(uuidString: serverIDString),
              let newState = userInfo["newState"] as? Bool else {
            return nil
        }
        return (serverID, newState)
    }
}
