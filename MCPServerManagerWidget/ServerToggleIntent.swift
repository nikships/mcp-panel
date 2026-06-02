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
        let toggleResult = toggleServerInConfigs(serverID: uuid, newState: newState)

        // Update the widget display state
        if toggleResult.didWrite {
            updateServerState(serverID: uuid, newState: newState, configIndex: toggleResult.configIndex)
        }

        // Post notification to main app (in case it's running)
        postNotificationToMainApp(serverID: uuid, newState: newState, configIndex: toggleResult.configIndex)

        // Reload widget timeline
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }

    // MARK: - Config File Updates

    private func toggleServerInConfigs(serverID: UUID, newState: Bool) -> (configIndex: Int, didWrite: Bool) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let config1Path = defaults.string(forKey: WidgetConstants.config1PathKey),
              let config2Path = defaults.string(forKey: WidgetConstants.config2PathKey),
              let widgetData = defaults.data(forKey: widgetServersKey),
              let widgetServers = try? JSONDecoder().decode([SharedWidgetServer].self, from: widgetData),
              let widgetServer = widgetServers.first(where: { $0.id == serverID }) else {
            return (0, false)
        }

        // Use widget's active config to determine which config file to update
        let activeConfig = loadActiveConfig(defaults: defaults)
        let configPath = activeConfig == 0 ? config1Path : config2Path
        let fallbackConfigPath = activeConfig == 0 ? config2Path : config1Path

        let didWrite = toggleInConfig(
            serverName: widgetServer.name,
            newState: newState,
            configPath: configPath,
            fallbackConfigPath: fallbackConfigPath
        )
        return (activeConfig, didWrite)
    }

    private func toggleInConfig(
        serverName: String,
        newState: Bool,
        configPath: String,
        fallbackConfigPath: String
    ) -> Bool {
        let url = resolveConfigURL(configPath)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Read existing config
        let existingData = try? Data(contentsOf: url)
        var json = existingData.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        } ?? [:]

        var mcpServers = json["mcpServers"] as? [String: Any] ?? [:]

        if newState {
            guard mcpServers[serverName] == nil else {
                return true
            }

            guard let serverConfig = loadServerConfig(named: serverName, from: fallbackConfigPath) else {
                return false
            }
            mcpServers[serverName] = serverConfig
        } else {
            guard mcpServers.removeValue(forKey: serverName) != nil else {
                return true
            }
        }

        // Save back to config
        json["mcpServers"] = mcpServers

        if let outputData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try outputData.write(to: url)
                return true
            } catch {
                return false
            }
        }

        return false
    }

    private func loadServerConfig(named serverName: String, from configPath: String) -> [String: Any]? {
        let url = resolveConfigURL(configPath)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpServers = json["mcpServers"] as? [String: Any] else {
            return nil
        }

        return mcpServers[serverName] as? [String: Any]
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

    private func loadActiveConfig(defaults: UserDefaults) -> Int {
        if defaults.object(forKey: WidgetConstants.widgetActiveConfigKey) != nil {
            return max(0, min(defaults.integer(forKey: WidgetConstants.widgetActiveConfigKey), 1))
        }
        return max(0, min(defaults.integer(forKey: WidgetConstants.activeConfigIndexKey), 1))
    }

    private func updateServerState(serverID: UUID, newState: Bool, configIndex: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: widgetServersKey) else {
            return
        }

        do {
            var servers = try JSONDecoder().decode([SharedWidgetServer].self, from: data)

            if let index = servers.firstIndex(where: { $0.id == serverID }) {
                servers[index].isEnabled = newState
                while servers[index].inConfigs.count <= configIndex {
                    servers[index].inConfigs.append(false)
                }
                servers[index].inConfigs[configIndex] = newState
                let updatedData = try JSONEncoder().encode(servers)
                defaults.set(updatedData, forKey: widgetServersKey)
                defaults.synchronize()
            }
        } catch {
            // Failed to update, ignore silently
        }
    }

    // MARK: - Notification

    private func postNotificationToMainApp(serverID: UUID, newState: Bool, configIndex: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        // Store pending toggle in shared UserDefaults (sandboxed apps can't pass userInfo)
        let pendingToggle: [String: Any] = [
            "serverID": serverID.uuidString,
            "newState": newState,
            "configIndex": configIndex,
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

        let current: Int
        if defaults.object(forKey: WidgetConstants.widgetActiveConfigKey) != nil {
            current = max(0, min(defaults.integer(forKey: WidgetConstants.widgetActiveConfigKey), 1))
        } else {
            current = max(0, min(defaults.integer(forKey: WidgetConstants.activeConfigIndexKey), 1))
        }
        let newIndex = 1 - current
        defaults.set(newIndex, forKey: WidgetConstants.widgetActiveConfigKey)
        defaults.synchronize()

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
