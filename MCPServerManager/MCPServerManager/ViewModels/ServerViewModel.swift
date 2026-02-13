import Foundation
import SwiftUI

@MainActor
class ServerViewModel: ObservableObject {
    @Published var servers: [ServerModel] = []
    @Published var settings: AppSettings = .default
    @Published var searchText: String = ""
    @Published var viewMode: ViewMode = .grid
    @Published var filterMode: FilterMode = .all
    @Published var isLoading: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var selectedServer: ServerModel?
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var toastType: ToastType = .success

    private let configManager = ConfigManager.shared
    private var skipSync = false

    // MARK: - Theme Detection

    var currentTheme: AppTheme {
        // If override theme is set, use it (unless it's "auto")
        if let overrideThemeStr = settings.overrideTheme,
           let overrideTheme = AppTheme(rawValue: overrideThemeStr),
           overrideTheme != .auto {
            return overrideTheme
        }
        // Otherwise, auto-detect from config path
        return AppTheme.detect(from: settings.activeConfigPath)
    }

    var themeColors: ThemeColors {
        DesignTokens.colors(for: currentTheme)
    }

    enum ToastType {
        case success, error, warning
    }

    init() {
        loadSettings()

        // Show onboarding if first time
        showOnboarding = !UserDefaults.standard.hasCompletedOnboarding

        // Only load servers if onboarding is complete
        if !showOnboarding {
            loadServers()
        }
    }

    // MARK: - Filtering & Searching

    var filteredServers: [ServerModel] {
        let activeIndex = settings.activeConfigIndex
        var filtered = servers

        // Apply filter mode
        switch filterMode {
        case .all:
            break  // Show all servers in this universe
        case .active:
            filtered = filtered.filter { $0.inConfigs[safe: activeIndex] ?? false }
        case .disabled:
            filtered = filtered.filter { !($0.inConfigs[safe: activeIndex] ?? false) }
        case .recent:
            filtered = filtered.sorted { $0.updatedAt > $1.updatedAt }
        }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText) ||
                server.config.summary.localizedCaseInsensitiveContains(searchText) ||
                server.configJSON.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    // MARK: - Settings Management

    func loadSettings() {
        settings = UserDefaults.standard.appSettings
        // Sync current theme to widget on load
        SharedDataManager.shared.saveTheme(currentTheme.rawValue)
    }

    func saveSettings() {
        UserDefaults.standard.appSettings = settings
        // Also save to SharedDataManager for widget access
        SharedDataManager.shared.saveConfigPaths(
            config1: settings.configPaths[0],
            config2: settings.configPaths[1],
            activeIndex: settings.activeConfigIndex
        )
        // Save current theme for widget
        SharedDataManager.shared.saveTheme(currentTheme.rawValue)
        showToast(message: "Settings saved", type: .success)
    }

    func completeOnboarding(configPath: String) {
        settings.configPaths[0] = configPath
        UserDefaults.standard.appSettings = settings
        UserDefaults.standard.hasCompletedOnboarding = true
        showOnboarding = false
        loadServers()
    }

    // MARK: - Server Management

    func loadServers() {
        isLoading = true
        skipSync = true

        // Ensure widget has current config paths
        SharedDataManager.shared.saveConfigPaths(
            config1: settings.configPaths[0],
            config2: settings.configPaths[1],
            activeIndex: settings.activeConfigIndex
        )

        Task {
            var loadError: Error?

            do {
                let config1 = try configManager.readConfig(from: settings.config1Path)
                let config2 = try configManager.readConfig(from: settings.config2Path)
                servers = mergeConfigs(config1: config1, config2: config2)
            } catch {
                #if DEBUG
                print("Error loading servers: \(error)")
                #endif
                servers = UserDefaults.standard.cachedServers
                loadError = error
            }

            UserDefaults.standard.cachedServers = servers

            let usedIcons = Set(servers.compactMap { $0.customIconPath })
            CustomIconManager.shared.cleanupUnusedIcons(usedFilenames: usedIcons)

            skipSync = false
            isLoading = false

            if let error = loadError {
                showToast(message: "Failed to load config: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func mergeConfigs(config1: [String: ServerConfig], config2: [String: ServerConfig]) -> [ServerModel] {
        var merged: [String: ServerModel] = [:]
        let now = Date()

        // Start with cached servers to preserve metadata, but reset inConfigs
        for server in UserDefaults.standard.cachedServers {
            var cachedServer = server
            cachedServer.inConfigs = [false, false]
            merged[server.name] = cachedServer
        }

        // Process config1 servers (Claude Code)
        for (name, config) in config1 {
            if var existing = merged[name] {
                existing.config = config
                existing.inConfigs[0] = true
                merged[name] = existing
            } else {
                merged[name] = ServerModel(
                    name: name,
                    config: config,
                    updatedAt: now,
                    inConfigs: [true, false]
                )
            }
        }

        // Process config2 servers (Gemini CLI)
        for (name, config) in config2 {
            if var existing = merged[name] {
                // Only update config if not already set by config1
                if !existing.inConfigs[0] {
                    existing.config = config
                }
                existing.inConfigs[1] = true
                merged[name] = existing
            } else {
                merged[name] = ServerModel(
                    name: name,
                    config: config,
                    updatedAt: now,
                    inConfigs: [false, true]
                )
            }
        }

        return Array(merged.values).sorted { $0.name < $1.name }
    }

    func syncToConfigs() {
        guard !skipSync else {
            #if DEBUG
            print("DEBUG: Skipping sync")
            #endif
            return
        }

        Task {
            do {
                let config1Servers = servers
                    .filter { $0.isInConfig1 }
                    .reduce(into: [String: ServerConfig]()) { $0[$1.name] = $1.config }

                let config2Servers = servers
                    .filter { $0.isInConfig2 }
                    .reduce(into: [String: ServerConfig]()) { $0[$1.name] = $1.config }

                #if DEBUG
                print("DEBUG: Syncing - Config1: \(config1Servers.count), Config2: \(config2Servers.count)")
                #endif

                try configManager.writeConfig(servers: config1Servers, to: settings.config1Path)
                try configManager.writeConfig(servers: config2Servers, to: settings.config2Path)

                if let droidPath = settings.droidConfigPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !droidPath.isEmpty {
                    do {
                        try configManager.syncClaudeServersToDroid(config1Servers, to: droidPath)
                    } catch {
                        NSLog("Failed to sync Droid MCP config: %@", error.localizedDescription)
                    }
                }

                // Update cache
                await MainActor.run {
                    UserDefaults.standard.cachedServers = servers
                }
            } catch {
                await MainActor.run {
                    showToast(message: "Failed to save: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }

    // MARK: - Server CRUD

    func addServers(from jsonString: String, registryImages: [String: String]? = nil) -> (invalidServers: [String: String], serverDict: [String: ServerConfig])? {
        guard let serverDict = ServerExtractor.extractServerEntries(from: jsonString) else {
            showToast(message: "Could not parse JSON. Please check format.", type: .error)
            return nil
        }

        guard !serverDict.isEmpty else {
            showToast(message: "No servers found in JSON", type: .warning)
            return nil
        }

        // Check for invalid servers
        let invalidServers = serverDict.compactMapValues { config -> String? in
            config.isValid ? nil : getInvalidReason(config)
        }

        if !invalidServers.isEmpty {
            return (invalidServers: invalidServers, serverDict: serverDict)
        }

        addServersInternal(serverDict: serverDict, registryImages: registryImages, forceMode: false)
        return nil
    }

    func addServersForced(from jsonString: String, registryImages: [String: String]? = nil) {
        guard let serverDict = ServerExtractor.extractServerEntries(from: jsonString) else {
            showToast(message: "Could not parse JSON. Please check format.", type: .error)
            return
        }
        addServersInternal(serverDict: serverDict, registryImages: registryImages, forceMode: true)
    }

    func addServersForced(serverDict: [String: ServerConfig], registryImages: [String: String]? = nil) {
        addServersInternal(serverDict: serverDict, registryImages: registryImages, forceMode: true)
    }

    private func addServersInternal(serverDict: [String: ServerConfig], registryImages: [String: String]?, forceMode: Bool) {
        let configIndex = settings.activeConfigIndex
        let now = Date()

        for (name, config) in serverDict {
            let registryImageUrl = registryImages?[name]

            if let index = servers.firstIndex(where: { $0.name == name }) {
                servers[index].config = config
                servers[index].updatedAt = now
                servers[index].inConfigs[configIndex] = true
                if let imageUrl = registryImageUrl {
                    servers[index].registryImageUrl = imageUrl
                }
            } else {
                var inConfigs = [false, false]
                inConfigs[configIndex] = true

                let newServer = ServerModel(
                    name: name,
                    config: config,
                    updatedAt: now,
                    inConfigs: inConfigs,
                    registryImageUrl: registryImageUrl
                )
                servers.append(newServer)
            }
        }

        servers.sort { $0.name < $1.name }
        objectWillChange.send()
        syncToConfigs()

        let message = forceMode ? "Force saved \(serverDict.count) server(s)" : "Added \(serverDict.count) server(s)"
        showToast(message: message, type: .success)
    }

    private func getInvalidReason(_ config: ServerConfig) -> String {
        if config.command == nil && config.httpUrl == nil && config.transport == nil && config.remotes == nil {
            return "missing command, httpUrl, transport, or remotes"
        }
        if let cmd = config.command, cmd.trimmingCharacters(in: .whitespaces).isEmpty {
            return "empty command"
        }
        if let httpUrlString = config.httpUrl, httpUrlString.trimmingCharacters(in: .whitespaces).isEmpty {
            return "empty httpUrl"
        }
        return "unknown issue"
    }

    private func parseServerConfig(from jsonString: String) throws -> ServerConfig {
        let normalized = jsonString.normalizingQuotes()

        guard let data = normalized.data(using: .utf8) else {
            throw NSError(domain: "MCPServerManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert JSON string to data"
            ])
        }

        return try JSONDecoder().decode(ServerConfig.self, from: data)
    }

    func updateServer(_ server: ServerModel, with jsonString: String) -> (success: Bool, invalidReason: String?, config: ServerConfig?) {
        do {
            let config = try parseServerConfig(from: jsonString)

            if !config.isValid {
                return (success: false, invalidReason: getInvalidReason(config), config: config)
            }

            guard applyServerUpdate(server, config: config) else {
                return (success: false, invalidReason: nil, config: nil)
            }

            showToast(message: "Server updated", type: .success)
            return (success: true, invalidReason: nil, config: nil)
        } catch {
            showToast(message: "Failed to update: \(error.localizedDescription)", type: .error)
            return (success: false, invalidReason: nil, config: nil)
        }
    }

    func updateServerForced(_ server: ServerModel, with jsonString: String) -> Bool {
        do {
            let config = try parseServerConfig(from: jsonString)
            guard applyServerUpdate(server, config: config) else { return false }
            showToast(message: "Server force saved", type: .success)
            return true
        } catch {
            showToast(message: "Failed to update: \(error.localizedDescription)", type: .error)
            return false
        }
    }

    func updateServerForced(_ server: ServerModel, config: ServerConfig) -> Bool {
        guard applyServerUpdate(server, config: config) else { return false }
        showToast(message: "Server force saved", type: .success)
        return true
    }

    private func applyServerUpdate(_ server: ServerModel, config: ServerConfig) -> Bool {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else {
            return false
        }

        servers[index].config = config
        servers[index].updatedAt = Date()
        syncToConfigs()
        return true
    }

    func applyRawJSON(_ jsonText: String) -> (success: Bool, invalidServers: [String: String]?, serverDict: [String: ServerConfig]?) {
        do {
            let serverDict = try parseServerDict(from: jsonText)

            let invalidServers = serverDict.compactMapValues { config -> String? in
                config.isValid ? nil : getInvalidReason(config)
            }

            if !invalidServers.isEmpty {
                return (success: false, invalidServers: invalidServers, serverDict: serverDict)
            }

            applyRawJSONInternal(serverDict: serverDict, forceMode: false)
            return (success: true, invalidServers: nil, serverDict: nil)
        } catch {
            showToast(message: "Failed to parse JSON: \(error.localizedDescription)", type: .error)
            return (success: false, invalidServers: nil, serverDict: nil)
        }
    }

    func applyRawJSONForced(_ jsonText: String) throws {
        let serverDict = try parseServerDict(from: jsonText)
        applyRawJSONInternal(serverDict: serverDict, forceMode: true)
    }

    func applyRawJSONForced(serverDict: [String: ServerConfig]) {
        applyRawJSONInternal(serverDict: serverDict, forceMode: true)
    }

    private func parseServerDict(from jsonText: String) throws -> [String: ServerConfig] {
        let normalized = jsonText.normalizingQuotes()

        guard let data = normalized.data(using: .utf8) else {
            throw NSError(domain: "Invalid JSON", code: -1)
        }

        return try JSONDecoder().decode([String: ServerConfig].self, from: data)
    }

    private func applyRawJSONInternal(serverDict: [String: ServerConfig], forceMode: Bool) {
        let configIndex = settings.activeConfigIndex
        let now = Date()

        // Remove all servers from this config
        for i in 0..<servers.count {
            servers[i].inConfigs[configIndex] = false
        }

        // Add/update servers from JSON
        for (name, config) in serverDict {
            if let index = servers.firstIndex(where: { $0.name == name }) {
                servers[index].config = config
                servers[index].inConfigs[configIndex] = true
                servers[index].updatedAt = now
            } else {
                var inConfigs = [false, false]
                inConfigs[configIndex] = true

                let newServer = ServerModel(
                    name: name,
                    config: config,
                    updatedAt: now,
                    inConfigs: inConfigs
                )
                servers.append(newServer)
            }
        }

        servers.sort { $0.name < $1.name }
        objectWillChange.send()
        syncToConfigs()

        let message = forceMode ? "Configuration force saved" : "Configuration updated"
        showToast(message: message, type: .success)
    }

    func deleteServer(_ server: ServerModel) {
        servers.removeAll { $0.id == server.id }
        syncToConfigs()
        showToast(message: "Server deleted", type: .success)
    }

    // MARK: - Tags

    func taggedServersCount(for tag: ServerTag) -> Int {
        servers.filter { $0.tags.contains(tag) }.count
    }

    func enableServers(with tag: ServerTag) {
        let configIndex = settings.activeConfigIndex
        let now = Date()

        let taggedServers = servers.enumerated().filter { $0.element.tags.contains(tag) }

        guard !taggedServers.isEmpty else {
            showToast(message: "No servers tagged \(tag.rawValue)", type: .warning)
            return
        }

        let indicesToEnable = taggedServers
            .filter { !(servers[$0.offset].inConfigs[safe: configIndex] ?? false) }
            .map { $0.offset }

        guard !indicesToEnable.isEmpty else {
            showToast(message: "All \(tag.rawValue) servers already enabled", type: .warning)
            return
        }

        for index in indicesToEnable {
            servers[index].inConfigs[configIndex] = true
            servers[index].updatedAt = now
        }

        objectWillChange.send()
        syncToConfigs()
        showToast(message: "Enabled \(indicesToEnable.count) \(tag.rawValue) server(s)", type: .success)
    }

    func toggleTag(_ tag: ServerTag, for server: ServerModel) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }

        var updated = servers[index]
        if let tagIndex = updated.tags.firstIndex(of: tag) {
            updated.tags.remove(at: tagIndex)
        } else {
            updated.tags.append(tag)
        }
        updated.updatedAt = Date()
        servers[index] = updated

        // Tags are app metadata (local-only), so we only update the cache.
        // NOTE: If the user clears app data, tags will be lost.
        // Future improvement: Persist tags to a sidecar file or config metadata.
        UserDefaults.standard.cachedServers = servers
    }

    func toggleServer(_ server: ServerModel) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }

        var updated = servers[index]
        let configIndex = settings.activeConfigIndex

        while updated.inConfigs.count <= configIndex {
            updated.inConfigs.append(false)
        }

        updated.inConfigs[configIndex].toggle()
        updated.updatedAt = Date()
        servers[index] = updated

        syncToConfigs()

        // Also sync to widget if this server is shown there
        if updated.showInWidget {
            syncToWidget()
        }

        let status = updated.inConfigs[configIndex] ? "enabled" : "disabled"
        showToast(message: "\(server.name) \(status)", type: .success)
    }

    func updateCustomIcon(for server: ServerModel, result: Result<String, Error>) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }

        switch result {
        case .success(let filename):
            // Remove old custom icon if replacing or resetting
            if let oldFilename = servers[index].customIconPath, oldFilename != filename {
                CustomIconManager.shared.removeCustomIcon(filename: oldFilename)
            }

            var updated = servers[index]
            updated.customIconPath = filename.isEmpty ? nil : filename
            updated.updatedAt = Date()
            servers[index] = updated

            // Update cache (no need to sync to config files as custom icons are app-specific)
            UserDefaults.standard.cachedServers = servers

            let message = filename.isEmpty ? "Icon reset for \(server.name)" : "Custom icon set for \(server.name)"
            showToast(message: message, type: .success)

        case .failure(let error):
            // Show specific error message from CustomIconError
            let errorMessage = error.localizedDescription
            showToast(message: errorMessage, type: .error)
        }
    }

    func toggleAllServers(_ enable: Bool) {
        let configIndex = settings.activeConfigIndex
        let now = Date()

        for i in 0..<servers.count {
            servers[i].inConfigs[configIndex] = enable
            servers[i].updatedAt = now
        }

        objectWillChange.send()
        syncToConfigs()

        let status = enable ? "enabled" : "disabled"
        showToast(message: "All servers \(status)", type: .success)
    }

    // MARK: - Widget Integration

    /// Toggle whether a server appears in the macOS widget
    func toggleShowInWidget(_ server: ServerModel) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }

        let currentWidgetCount = servers.filter { $0.showInWidget }.count

        // If trying to add and already at max, show warning
        if !servers[index].showInWidget && currentWidgetCount >= SharedDataManager.maxWidgetServers {
            showToast(message: "Maximum \(SharedDataManager.maxWidgetServers) servers can be shown in widget", type: .warning)
            return
        }

        servers[index].showInWidget.toggle()
        servers[index].updatedAt = Date()

        // Update cache
        UserDefaults.standard.cachedServers = servers

        // Sync to widget
        syncToWidget()

        let status = servers[index].showInWidget ? "added to" : "removed from"
        showToast(message: "\(server.name) \(status) widget", type: .success)
    }

    /// Sync servers marked for widget to shared storage
    func syncToWidget() {
        let widgetServers = servers
            .filter { $0.showInWidget }
            .prefix(SharedDataManager.maxWidgetServers)
            .map { server in
                SharedDataManager.WidgetServer(
                    id: server.id,
                    name: server.name,
                    isEnabled: server.inConfigs[safe: settings.activeConfigIndex] ?? false,
                    configIndex: settings.activeConfigIndex,
                    inConfigs: server.inConfigs
                )
            }

        SharedDataManager.shared.saveWidgetServers(Array(widgetServers))
    }

    // MARK: - Import/Export

    func exportServers() -> String {
        configManager.exportServers(from: servers, configIndex: settings.activeConfigIndex)
    }

    func testConnection(to path: String) async -> Result<Int, Error> {
        Result { try configManager.testConnection(to: path) }
    }

    // MARK: - Toast

    private var toastTask: Task<Void, Never>?

    func showToast(message: String, type: ToastType) {
        toastTask?.cancel()

        toastMessage = message
        toastType = type
        withAnimation {
            showToast = true
        }

        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation {
                showToast = false
            }
        }
    }
}
