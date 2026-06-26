import Foundation

/// Mirrors the app's reconcile / sync model (`ServerViewModel.mergeConfig` and
/// `syncToConfigs`): the UserDefaults cache (`cached_servers`) is the master
/// list including disabled servers, while the `mcpServers` map in
/// `~/.claude.json` is the enabled subset Claude Code actually loads. Reads
/// merge the two; writes update both so the CLI and the GUI stay in agreement.
struct ServerRegistry {
    private let configStore: ClaudeConfigStore
    private let cacheStore: DefaultsCacheStore

    /// name -> entry, where each entry uses the app's cached-server JSON shape.
    private(set) var entries: [String: [String: Any]]

    init(configStore: ClaudeConfigStore, cacheStore: DefaultsCacheStore) throws {
        self.configStore = configStore
        self.cacheStore = cacheStore
        self.entries = [:]
        try reload()
    }

    /// Rebuilds the unified view, mirroring `ServerViewModel.mergeConfig`:
    /// cached servers form the master list (reset to disabled), then anything
    /// present on disk is marked enabled with its on-disk config.
    mutating func reload() throws {
        let fileServers = try configStore.readServers()
        var merged: [String: [String: Any]] = [:]

        for var entry in cacheStore.readCachedServers() {
            guard let name = entry["name"] as? String else { continue }
            entry["enabled"] = false
            merged[name] = entry
        }

        for (name, config) in fileServers {
            if var entry = merged[name] {
                entry["config"] = config
                entry["enabled"] = true
                merged[name] = entry
            } else {
                merged[name] = ServerRegistry.makeEntry(name: name, config: config, enabled: true)
            }
        }

        entries = merged
    }

    func sortedNames() -> [String] {
        entries.keys.sorted()
    }

    func entry(named name: String) -> [String: Any]? {
        entries[name]
    }

    /// Builds a fresh cache entry equivalent to a `ServerModel(...)` as encoded
    /// by the app's default `JSONEncoder` (UUID string, `updatedAt` as a
    /// reference-date interval, empty tags).
    static func makeEntry(name: String, config: [String: Any], enabled: Bool) -> [String: Any] {
        [
            "id": UUID().uuidString,
            "name": name,
            "config": config,
            "enabled": enabled,
            "updatedAt": Date().timeIntervalSinceReferenceDate,
            "tags": [Any]()
        ]
    }

    /// Adds or updates a server from a parsed config object, enabling it.
    @discardableResult
    mutating func add(name: String, config: [String: Any]) throws -> [String: Any] {
        let now = Date().timeIntervalSinceReferenceDate
        if var existing = entries[name] {
            existing["config"] = config
            existing["enabled"] = true
            existing["updatedAt"] = now
            entries[name] = existing
        } else {
            entries[name] = ServerRegistry.makeEntry(name: name, config: config, enabled: true)
        }
        try persist()
        guard let result = entries[name] else {
            throw CLIError.io("internal: server '\(name)' missing after add")
        }
        return result
    }

    /// Sets a server's enabled state (or flips it when `target` is nil).
    /// Returns the resulting entry and whether anything changed.
    mutating func setEnabled(name: String, target: Bool?) throws -> (entry: [String: Any], changed: Bool) {
        guard var entry = entries[name] else {
            throw CLIError.notFound("no server named '\(name)'")
        }
        let current = (entry["enabled"] as? Bool) ?? false
        let desired = target ?? !current
        if desired == current {
            return (entry, false)
        }
        entry["enabled"] = desired
        entry["updatedAt"] = Date().timeIntervalSinceReferenceDate
        entries[name] = entry
        try persist()
        return (entry, true)
    }

    /// Persists to both stores, mirroring `ServerViewModel.syncToConfigs`:
    /// the enabled subset goes to `~/.claude.json`, the full list to the cache.
    private func persist() throws {
        var enabled: [String: [String: Any]] = [:]
        for (name, entry) in entries where (entry["enabled"] as? Bool) == true {
            enabled[name] = (entry["config"] as? [String: Any]) ?? [:]
        }
        try configStore.writeServers(enabled)

        if cacheStore.isWritable {
            let ordered = sortedNames().compactMap { entries[$0] }
            try cacheStore.writeCachedServers(ordered)
        }
    }
}
