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

    // MARK: - Live File Watching

    private var fileWatcher: ConfigFileWatcher?
    /// Window during which external file-change events are ignored (suppresses our own writes).
    private var ignoreExternalChangesUntil: Date = .distantPast

    // MARK: - Theme Detection

    var currentTheme: AppTheme {
        // Use the user's chosen theme, defaulting to the Claude Code theme.
        if let overrideThemeStr = settings.overrideTheme,
           let overrideTheme = AppTheme(rawValue: overrideThemeStr) {
            return overrideTheme
        }
        return .claudeCode
    }

    var themeColors: ThemeColors {
        DesignTokens.colors(for: currentTheme)
    }

    enum ToastType {
        case success, error, warning
    }

    enum AddServersResult {
        case success
        case validationFailed(invalidServers: [String: String], serverDict: [String: ServerConfig])
        case failed
    }

    init() {
        loadSettings()

        // Show onboarding if first time
        showOnboarding = !UserDefaults.standard.hasCompletedOnboarding

        // Only load servers if onboarding is complete
        if !showOnboarding {
            loadServers()
            startWatchingConfig()
        }
    }

    deinit {
        fileWatcher?.stop()
    }

    // MARK: - Filtering & Searching

    var filteredServers: [ServerModel] {
        var filtered = servers

        // Apply filter mode
        switch filterMode {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.enabled }
        case .disabled:
            filtered = filtered.filter { !$0.enabled }
        case .recent:
            // Servers modified within the last 24 hours, ordered most-recent first.
            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            filtered = filtered
                .filter { $0.updatedAt >= cutoff }
                .sorted { $0.updatedAt > $1.updatedAt }
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
    }

    func saveSettings() {
        UserDefaults.standard.appSettings = settings
        // Restart the watcher on the (possibly new) config path
        startWatchingConfig()
        showToast(message: "Settings saved", type: .success)
    }

    func completeOnboarding(configPath: String) {
        settings.configPath = configPath
        UserDefaults.standard.appSettings = settings
        UserDefaults.standard.hasCompletedOnboarding = true
        showOnboarding = false
        loadServers()
        startWatchingConfig()
    }

    // MARK: - File Watching

    private func startWatchingConfig() {
        let path = settings.configPath
        if let watcher = fileWatcher {
            watcher.updatePath(path)
        } else {
            let watcher = ConfigFileWatcher(path: path) { [weak self] in
                self?.handleExternalConfigChange()
            }
            fileWatcher = watcher
            watcher.start()
        }
    }

    private func handleExternalConfigChange() {
        // Ignore events triggered by our own writes.
        guard Date() >= ignoreExternalChangesUntil else { return }
        loadServers()
    }

    // MARK: - Server Management

    func loadServers() {
        isLoading = true
        skipSync = true

        Task {
            var loadError: Error?

            do {
                let config = try configManager.readConfig(from: settings.configPath)
                servers = mergeConfig(config)
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

    /// Merge the on-disk config with cached metadata. Non-destructive to local metadata
    /// (tags, customIconPath, registryImageUrl): external adds surface as new
    /// enabled cards while existing servers keep their metadata.
    private func mergeConfig(_ config: [String: ServerConfig]) -> [ServerModel] {
        var merged: [String: ServerModel] = [:]
        let now = Date()

        // Start with cached servers to preserve metadata, but reset enabled state.
        for server in UserDefaults.standard.cachedServers {
            var cachedServer = server
            cachedServer.enabled = false
            merged[server.name] = cachedServer
        }

        // Servers present on disk are enabled.
        for (name, serverConfig) in config {
            if var existing = merged[name] {
                existing.config = serverConfig
                existing.enabled = true
                merged[name] = existing
            } else {
                merged[name] = ServerModel(
                    name: name,
                    config: serverConfig,
                    enabled: true,
                    updatedAt: now
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

        // Suppress the file-watcher reload caused by our own write.
        ignoreExternalChangesUntil = Date().addingTimeInterval(0.6)

        Task {
            do {
                let enabledServers = servers
                    .filter { $0.enabled }
                    .reduce(into: [String: ServerConfig]()) { $0[$1.name] = $1.config }

                #if DEBUG
                print("DEBUG: Syncing \(enabledServers.count) enabled server(s)")
                #endif

                try configManager.writeConfig(servers: enabledServers, to: settings.configPath)

                if let droidPath = settings.droidConfigPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !droidPath.isEmpty {
                    do {
                        try configManager.syncClaudeServersToDroid(enabledServers, to: droidPath)
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

    func addServers(from jsonString: String, registryImages: [String: String]? = nil) -> AddServersResult {
        guard let serverDict = ServerExtractor.extractServerEntries(from: jsonString) else {
            showToast(message: "Could not parse JSON. Please check format.", type: .error)
            return .failed
        }

        guard !serverDict.isEmpty else {
            showToast(message: "No servers found in JSON", type: .warning)
            return .failed
        }

        // Check for invalid servers
        let invalidServers = serverDict.compactMapValues { config -> String? in
            config.isValid ? nil : getInvalidReason(config)
        }

        if !invalidServers.isEmpty {
            return .validationFailed(invalidServers: invalidServers, serverDict: serverDict)
        }

        addServersInternal(serverDict: serverDict, registryImages: registryImages, forceMode: false)
        return .success
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
        let now = Date()

        for (name, config) in serverDict {
            let registryImageUrl = registryImages?[name]

            if let index = servers.firstIndex(where: { $0.name == name }) {
                servers[index].config = config
                servers[index].updatedAt = now
                servers[index].enabled = true
                if let imageUrl = registryImageUrl {
                    servers[index].registryImageUrl = imageUrl
                }
            } else {
                let newServer = ServerModel(
                    name: name,
                    config: config,
                    enabled: true,
                    updatedAt: now,
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

    /// Parse a single named entry (`"name": { ... }`) and return the key + config if exactly one
    /// top-level key is present and its value is an object.
    private func parseNamedEntry(from jsonString: String) -> (name: String, config: ServerConfig)? {
        guard let serverDict = ServerExtractor.extractServerEntries(from: jsonString),
              serverDict.count == 1,
              let entry = serverDict.first else {
            return nil
        }
        return (entry.key, entry.value)
    }

    func updateServer(_ server: ServerModel, with jsonString: String) -> (success: Bool, invalidReason: String?, config: ServerConfig?) {
        // Detect a rename: a single named top-level key that differs from the current name.
        if let entry = parseNamedEntry(from: jsonString) {
            if entry.name != server.name {
                return renameServer(server, to: entry.name, config: entry.config)
            }
            // Same name: treat as a value update using the entry's config.
            if !entry.config.isValid {
                return (success: false, invalidReason: getInvalidReason(entry.config), config: entry.config)
            }
            guard applyServerUpdate(server, config: entry.config) else {
                return (success: false, invalidReason: nil, config: nil)
            }
            showToast(message: "Server updated", type: .success)
            return (success: true, invalidReason: nil, config: nil)
        }

        // Fall back to bare config object (value-only) parsing.
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

    /// Rename a server via its top-level JSON key. Validates the new name and re-keys.
    private func renameServer(_ server: ServerModel, to newName: String, config: ServerConfig) -> (success: Bool, invalidReason: String?, config: ServerConfig?) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            showToast(message: "Server name cannot be empty", type: .error)
            return (success: false, invalidReason: nil, config: nil)
        }

        // Collision with a different server.
        if servers.contains(where: { $0.id != server.id && $0.name == trimmedName }) {
            showToast(message: "A server named '\(trimmedName)' already exists", type: .error)
            return (success: false, invalidReason: nil, config: nil)
        }

        if !config.isValid {
            return (success: false, invalidReason: getInvalidReason(config), config: config)
        }

        guard let index = servers.firstIndex(where: { $0.id == server.id }) else {
            return (success: false, invalidReason: nil, config: nil)
        }

        servers[index].name = trimmedName
        servers[index].config = config
        servers[index].updatedAt = Date()
        servers.sort { $0.name < $1.name }
        objectWillChange.send()
        syncToConfigs()
        showToast(message: "Renamed to '\(trimmedName)'", type: .success)
        return (success: true, invalidReason: nil, config: nil)
    }

    func updateServerForced(_ server: ServerModel, with jsonString: String) -> Bool {
        // Honor rename intent in the forced path too.
        if let entry = parseNamedEntry(from: jsonString) {
            if entry.name != server.name {
                let trimmedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty,
                   !servers.contains(where: { $0.id != server.id && $0.name == trimmedName }),
                   let index = servers.firstIndex(where: { $0.id == server.id }) {
                    servers[index].name = trimmedName
                    servers[index].config = entry.config
                    servers[index].updatedAt = Date()
                    servers.sort { $0.name < $1.name }
                    objectWillChange.send()
                    syncToConfigs()
                    showToast(message: "Server force saved", type: .success)
                    return true
                }
            }
            guard applyServerUpdate(server, config: entry.config) else { return false }
            showToast(message: "Server force saved", type: .success)
            return true
        }

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

        if let wrapped = try? JSONDecoder().decode(ConfigManager.ConfigFile.self, from: data) {
            return wrapped.mcpServers
        }

        return try JSONDecoder().decode([String: ServerConfig].self, from: data)
    }

    private func applyRawJSONInternal(serverDict: [String: ServerConfig], forceMode: Bool) {
        let now = Date()

        // The raw editor represents the full enabled set: disable everything first.
        for i in 0..<servers.count {
            servers[i].enabled = false
        }

        // Add/update servers from JSON, marking them enabled.
        for (name, config) in serverDict {
            if let index = servers.firstIndex(where: { $0.name == name }) {
                servers[index].config = config
                servers[index].enabled = true
                servers[index].updatedAt = now
            } else {
                let newServer = ServerModel(
                    name: name,
                    config: config,
                    enabled: true,
                    updatedAt: now
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
        let now = Date()

        let taggedServers = servers.enumerated().filter { $0.element.tags.contains(tag) }

        guard !taggedServers.isEmpty else {
            showToast(message: "No servers tagged \(tag.rawValue)", type: .warning)
            return
        }

        let indicesToEnable = taggedServers
            .filter { !servers[$0.offset].enabled }
            .map { $0.offset }

        guard !indicesToEnable.isEmpty else {
            showToast(message: "All \(tag.rawValue) servers already enabled", type: .warning)
            return
        }

        for index in indicesToEnable {
            servers[index].enabled = true
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
        UserDefaults.standard.cachedServers = servers
    }

    func toggleServer(_ server: ServerModel) {
        setServer(server, enabled: !server.enabled)
    }

    func setServer(_ server: ServerModel, enabled: Bool) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }

        guard servers[index].enabled != enabled else { return }

        servers[index].enabled = enabled
        servers[index].updatedAt = Date()

        syncToConfigs()

        let status = enabled ? "enabled" : "disabled"
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
        let now = Date()

        for i in 0..<servers.count {
            servers[i].enabled = enable
            servers[i].updatedAt = now
        }

        objectWillChange.send()
        syncToConfigs()

        let status = enable ? "enabled" : "disabled"
        showToast(message: "All servers \(status)", type: .success)
    }

    // MARK: - Import/Export

    func exportServers() -> String {
        configManager.exportServers(from: servers)
    }

    func activeConfigServersJSON() -> String {
        configManager.exportServers(from: servers)
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
