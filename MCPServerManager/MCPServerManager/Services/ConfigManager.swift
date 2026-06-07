import Foundation

class ConfigManager {
    static let shared = ConfigManager()

    struct ConfigFile: Codable {
        var mcpServers: [String: ServerConfig]
    }

    private init() {}

    // MARK: - Path Resolution

    func expandPath(_ path: String) -> URL {
        let expanded = NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    private func resolveURL(for path: String) -> URL {
        BookmarkManager.shared.resolveBookmark(for: path) ?? expandPath(path)
    }

    private func withConfigAccess<T>(_ path: String, _ operation: (URL) throws -> T) throws -> T {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = resolveURL(for: trimmedPath)

        if BookmarkManager.shared.hasBookmark(for: trimmedPath) {
            return try url.withSecurityScopedAccess(operation)
        }

        return try operation(url)
    }

    // MARK: - Read/Write Config

    func readConfig(from path: String) throws -> [String: ServerConfig] {
        try withConfigAccess(path) { url in
            guard FileManager.default.fileExists(atPath: url.path) else {
                return [:]
            }

            let data = try Data(contentsOf: url)
            return try self.parseServers(from: data)
        }
    }

    private func parseServers(from data: Data) throws -> [String: ServerConfig] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        // Claude Code's `~/.claude.json` stores many unrelated top-level keys
        // (projects, userID, etc.) and only has `mcpServers` once servers exist.
        // Treat a missing `mcpServers` as an empty set rather than parsing the
        // whole file as servers, which would create bogus cards and stall loading.
        let serverDictionary = json["mcpServers"] as? [String: Any] ?? [:]

        return serverDictionary.compactMapValues { value in
            guard let serverData = try? JSONSerialization.data(withJSONObject: value),
                  let config = try? JSONDecoder().decode(ServerConfig.self, from: serverData) else {
                return nil
            }
            return config
        }
    }

    func writeConfig(servers: [String: ServerConfig], to path: String) throws {
        try withConfigAccess(path) { url in
            try self.writeJSONConfig(servers: servers, to: url)
        }
    }

    func syncClaudeServersToDroid(_ servers: [String: ServerConfig], to path: String) throws {
        let droidServers = servers.mapValues { normalizeForDroid($0) }
        try writeConfig(servers: droidServers, to: path)
    }

    private func writeJSONConfig(servers: [String: ServerConfig], to url: URL) throws {
        let parentDirectory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        var json = readExistingJSON(at: url)

        let mcpServers = try servers.mapValues { config -> [String: Any] in
            let data = try JSONEncoder().encode(config)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        }

        json["mcpServers"] = mcpServers

        let outputData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        guard let decoded = String(bytes: outputData, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        let output = decoded.unescapingJSONSlashes()
        try output.write(to: url, atomically: true, encoding: .utf8)
    }

    /// True when a string is nil, empty, or only whitespace.
    private func isBlank(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalizeForDroid(_ config: ServerConfig) -> ServerConfig {
        var normalized = config

        if !isBlank(normalized.command) {
            if isBlank(normalized.type) {
                normalized.type = "stdio"
            }
            return normalized
        }

        if let httpUrl = normalized.httpUrl, !isBlank(httpUrl) {
            if isBlank(normalized.type) {
                normalized.type = "http"
            }
            if isBlank(normalized.url) {
                normalized.url = httpUrl
            }
        }

        if let transport = normalized.transport {
            if isBlank(normalized.type) {
                normalized.type = transport.type
            }
            if isBlank(normalized.url) {
                normalized.url = transport.url
            }
            if normalized.headers == nil {
                normalized.headers = transport.headers
            }
        }

        return normalized
    }

    private func readExistingJSON(at url: URL) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    func testConnection(to path: String) throws -> Int {
        try readConfig(from: path).count
    }

    // MARK: - Bookmarks

    func storeBookmarkForConfigFile(url: URL, path _: String) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try BookmarkManager.shared.storeBookmark(for: url)
    }

    // MARK: - Server Operations

    func addServer(name: String, config: ServerConfig, to configPath: String) throws {
        try setServer(name: name, config: config, in: configPath)
    }

    func updateServer(name: String, config: ServerConfig, in configPath: String) throws {
        try setServer(name: name, config: config, in: configPath)
    }

    private func setServer(name: String, config: ServerConfig, in configPath: String) throws {
        var servers = try readConfig(from: configPath)
        servers[name] = config
        try writeConfig(servers: servers, to: configPath)
    }

    func deleteServer(name: String, from configPath: String) throws {
        var servers = try readConfig(from: configPath)
        servers.removeValue(forKey: name)
        try writeConfig(servers: servers, to: configPath)
    }

    // MARK: - Bulk Operations

    func addServers(_ newServers: [String: ServerConfig], to configPath: String, merge: Bool = true) throws {
        var servers = merge ? try readConfig(from: configPath) : [:]
        servers.merge(newServers) { _, new in new }
        try writeConfig(servers: servers, to: configPath)
    }

    // MARK: - Export

    func exportServers(from servers: [ServerModel]) -> String {
        let filteredServers = servers
            .filter { $0.enabled }
            .reduce(into: [String: ServerConfig]()) { $0[$1.name] = $1.config }

        return encodeToJSON(ConfigFile(mcpServers: filteredServers)) ?? "{\n  \"mcpServers\" : {}\n}"
    }

    private func encodeToJSON<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private enum Keys {
        static let settings = "app_settings"
        static let servers = "cached_servers"
        static let hasCompletedOnboarding = "has_completed_onboarding"
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        set(try? JSONEncoder().encode(value), forKey: key)
    }

    var appSettings: AppSettings {
        get { decode(AppSettings.self, forKey: Keys.settings) ?? .default }
        set { encode(newValue, forKey: Keys.settings) }
    }

    var cachedServers: [ServerModel] {
        get { decode([ServerModel].self, forKey: Keys.servers) ?? [] }
        set { encode(newValue, forKey: Keys.servers) }
    }

    var hasCompletedOnboarding: Bool {
        get { bool(forKey: Keys.hasCompletedOnboarding) }
        set { set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
}
