import AppIntents
import WidgetKit
import Foundation

/// App Intent for toggling server state from the widget (macOS 14+)
@available(macOS 14.0, *)
struct ServerToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle MCP Server"
    static var description: IntentDescription = IntentDescription("Toggle an MCP server on or off")

    @Parameter(title: "Server ID")
    var serverID: String

    @Parameter(title: "New State")
    var newState: Bool

    init() {
        self.serverID = ""
        self.newState = false
    }

    init(serverID: String, newState: Bool) {
        self.serverID = serverID
        self.newState = newState
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: serverID) else {
            return .result()
        }

        // Toggle server in actual config files
        toggleServerInConfigs(serverID: uuid, newState: newState)

        // Update the widget display state
        updateServerState(serverID: uuid, newState: newState)

        // Post notification to main app (in case it's running)
        postNotificationToMainApp(serverID: uuid, newState: newState)

        // Reload widget timeline
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }

    // MARK: - Config File Updates

    private func toggleServerInConfigs(serverID: UUID, newState: Bool) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let config1Path = defaults.string(forKey: WidgetConstants.config1PathKey),
              let config2Path = defaults.string(forKey: WidgetConstants.config2PathKey),
              let widgetData = defaults.data(forKey: widgetServersKey),
              let widgetServers = try? JSONDecoder().decode([SharedWidgetServerForIntent].self, from: widgetData),
              let widgetServer = widgetServers.first(where: { $0.id == serverID }) else {
            return
        }

        // Use widget's active config to determine which config file to update
        let activeConfig = defaults.integer(forKey: WidgetConstants.widgetActiveConfigKey)
        let configPath = activeConfig == 0 ? config1Path : config2Path

        toggleInConfig(serverID: serverID, serverName: widgetServer.name, newState: newState, configPath: configPath)
    }

    private func toggleInConfig(serverID: UUID, serverName: String, newState: Bool, configPath: String) {
        let url = resolveConfigURL(configPath)

        // Read existing config
        guard let data = try? Data(contentsOf: url),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Get or create mcpServers object
        var mcpServers = json["mcpServers"] as? [String: Any] ?? [:]

        // Toggle the server's disabled state
        if var serverConfig = mcpServers[serverName] as? [String: Any] {
            if newState {
                // Enable: remove disabled field
                serverConfig.removeValue(forKey: "disabled")
            } else {
                // Disable: set disabled to true
                serverConfig["disabled"] = true
            }
            mcpServers[serverName] = serverConfig
        }

        // Save back to config
        json["mcpServers"] = mcpServers

        if let outputData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? outputData.write(to: url)
        }
    }

    private func resolveConfigURL(_ path: String) -> URL {
        // Try to resolve bookmark first
        if let bookmarkURL = resolveBookmark(for: path) {
            return bookmarkURL
        }

        // Fallback to expanding tilde
        let expandedPath = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath)
    }

    private func resolveBookmark(for path: String) -> URL? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }

        let expandedPath = NSString(string: path).expandingTildeInPath
        let key = "bookmark_\(expandedPath.replacingOccurrences(of: "~", with: "home"))"

        guard let bookmarkData = defaults.data(forKey: key) else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                if accessing {
                    if let refreshedData = try? url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        defaults.set(refreshedData, forKey: key)
                        defaults.synchronize()
                    }
                }
            }

            return url
        } catch {
            defaults.removeObject(forKey: key)
            defaults.synchronize()
            return nil
        }
    }

    // MARK: - Widget Display State

    private let suiteName = WidgetConstants.suiteName
    private let widgetServersKey = WidgetConstants.widgetServersKey

    private func updateServerState(serverID: UUID, newState: Bool) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: widgetServersKey) else {
            return
        }

        do {
            var servers = try JSONDecoder().decode([SharedWidgetServerForIntent].self, from: data)

            if let index = servers.firstIndex(where: { $0.id == serverID }) {
                servers[index].isEnabled = newState
                let updatedData = try JSONEncoder().encode(servers)
                defaults.set(updatedData, forKey: widgetServersKey)
                defaults.synchronize()
            }
        } catch {
            // Failed to update, ignore silently
        }
    }

    // MARK: - Notification

    private func postNotificationToMainApp(serverID: UUID, newState: Bool) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        // Store pending toggle in shared UserDefaults (sandboxed apps can't pass userInfo)
        let pendingToggle: [String: Any] = [
            "serverID": serverID.uuidString,
            "newState": newState,
            "timestamp": Date().timeIntervalSince1970
        ]
        defaults.set(pendingToggle, forKey: "pendingServerToggle")
        defaults.synchronize()

        // Post notification WITHOUT userInfo (sandboxed apps can't receive it)
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("MCPServerToggled"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

/// App Intent for switching between Claude and Gemini configs in the widget
@available(macOS 14.0, *)
struct ConfigSwitchIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Config"
    static var description: IntentDescription = IntentDescription("Switch between Claude and Gemini")

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.suiteName) else {
            return .result()
        }

        let current = defaults.integer(forKey: WidgetConstants.widgetActiveConfigKey)
        let newIndex = 1 - current
        defaults.set(newIndex, forKey: WidgetConstants.widgetActiveConfigKey)
        defaults.synchronize()

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Shared widget server model for intent (must match SharedDataManager.WidgetServer)
@available(macOS 14.0, *)
private struct SharedWidgetServerForIntent: Codable, Identifiable {
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
