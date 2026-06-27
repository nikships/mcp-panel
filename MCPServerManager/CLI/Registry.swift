import Foundation

/// Mirrors the app's reconcile / sync model (`ServerViewModel.mergeConfig` and
/// `syncToConfigs`): the UserDefaults cache (`cached_servers`) is the master
/// list including disabled servers, while the `mcpServers` map in
/// `~/.claude.json` is the enabled subset Claude Code actually loads. Reads
/// merge the two; writes update both so the CLI and the GUI stay in agreement.
struct ServerRegistry {
    private let configStore: ClaudeConfigStore
    private let cacheStore: DefaultsCacheStore
    /// Optional Factory ("Droid") config, mirrored with normalized enabled servers.
    private let factoryStore: ClaudeConfigStore?

    /// name -> entry, where each entry uses the app's cached-server JSON shape.
    private(set) var entries: [String: [String: Any]]

    init(configStore: ClaudeConfigStore,
         cacheStore: DefaultsCacheStore,
         factoryStore: ClaudeConfigStore? = nil) throws {
        self.configStore = configStore
        self.cacheStore = cacheStore
        self.factoryStore = factoryStore
        self.entries = [:]
        try reload()
    }

    /// The configured Factory ("Droid") config path, if any.
    var factoryConfigPath: String? { factoryStore?.path }

    /// Whether the Factory config's server set matches the enabled set, or nil
    /// when no Factory path is configured.
    func factoryInSync() -> Bool? {
        guard let factoryStore else { return nil }
        let enabledNames = Set(entries.filter { ($0.value["enabled"] as? Bool) == true }.map { $0.key })
        let factoryNames = Set(((try? factoryStore.readServers()) ?? [:]).keys)
        return enabledNames == factoryNames
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

    /// Persists to every surface, mirroring `ServerViewModel.syncToConfigs`:
    /// the enabled subset goes to `~/.claude.json` and (normalized) to the
    /// Factory config when configured, while the full list goes to the cache.
    private func persist() throws {
        var enabled: [String: [String: Any]] = [:]
        for (name, entry) in entries where (entry["enabled"] as? Bool) == true {
            enabled[name] = (entry["config"] as? [String: Any]) ?? [:]
        }

        // Write the cache (full list, incl. disabled) BEFORE the live config: if
        // the cache write fails we must not have already mutated ~/.claude.json
        // and lost the remembered disabled-state. The app treats the file as the
        // source of truth for "enabled", so a cache-ahead state self-heals on its
        // next load, whereas a file-ahead state can drop a disabled server's config.
        if cacheStore.isWritable {
            let ordered = sortedNames().compactMap { entries[$0] }
            try cacheStore.writeCachedServers(ordered)
        }
        try configStore.writeServers(enabled)

        // Mirror the enabled set into the Factory ("Droid") config, normalized
        // exactly as the GUI's `syncClaudeServersToDroid` does, when configured.
        if let factoryStore {
            let normalized = enabled.mapValues { DroidNormalizer.normalize($0) }
            try factoryStore.writeServers(normalized)
        }
    }
}
