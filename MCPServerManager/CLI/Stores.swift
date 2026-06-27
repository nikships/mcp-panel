import Foundation

// MARK: - Path resolution

/// Resolves the filesystem locations the CLI reads from and writes to.
enum Paths {
    static let defaultConfigPath = "~/.claude.json"

    /// The app's bundle identifier(s) — the domain for its UserDefaults and its
    /// sandbox container. `com.mcpmanager.app` is authoritative: it is the
    /// `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and the `CFBundleIdentifier`
    /// written by both build scripts. (`bundleIdPrefix: com.anand-92` is only a
    /// default for targets without an explicit id, and `group.com.anand-92.mcp-panel`
    /// was a separate App Group namespace.) The prefix-derived id is kept as a
    /// fallback so the CLI still locates the container if an older build used it.
    static let appBundleIdentifiers = ["com.mcpmanager.app", "com.anand-92.mcp-panel"]

    static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private static var home: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Candidate locations for MCP Panel's UserDefaults plist, most specific
    /// first: an explicit override, the sandbox container (App Store / signed
    /// build), then the non-sandboxed location (a plain `swift run`). Each
    /// bundle identifier is probed in priority order.
    static func defaultsCandidates(override: String?) -> [String] {
        var candidates: [String] = []
        if let override, !override.trimmedWhitespace.isEmpty {
            candidates.append(expand(override))
        }
        if let env = ProcessInfo.processInfo.environment["MCP_PANEL_DEFAULTS_PLIST"], !env.isEmpty {
            candidates.append(expand(env))
        }
        for identifier in appBundleIdentifiers {
            let prefs = "Library/Preferences/\(identifier).plist"
            candidates.append("\(home)/Library/Containers/\(identifier)/Data/\(prefs)")
            candidates.append("\(home)/\(prefs)")
        }
        return candidates
    }
}

// MARK: - Claude config (~/.claude.json)

/// Reads and writes the `mcpServers` map in the user's Claude config,
/// preserving every other top-level key (`projects`, `userID`, …) and matching
/// the app's exact serialization: pretty-printed, sorted keys, unescaped slashes.
struct ClaudeConfigStore {
    let path: String

    init(path: String) {
        self.path = Paths.expand(path)
    }

    func readRoot() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: path) else { return [:] }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw CLIError.io("could not read \(path)")
        }
        if data.isEmpty { return [:] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CLIError.io("\(path) is not a valid JSON object")
        }
        return root
    }

    func readServers() throws -> [String: [String: Any]] {
        let root = try readRoot()
        let raw = root["mcpServers"] as? [String: Any] ?? [:]
        var servers: [String: [String: Any]] = [:]
        for (name, value) in raw where value is [String: Any] {
            if let config = value as? [String: Any] {
                servers[name] = config
            }
        }
        return servers
    }

    func writeServers(_ servers: [String: [String: Any]]) throws {
        var root = try readRoot()
        var mcpServers: [String: Any] = [:]
        for (name, config) in servers {
            mcpServers[name] = config
        }
        root["mcpServers"] = mcpServers

        let string = try JSONUtil.prettyString(root)
        let directory = (path as NSString).deletingLastPathComponent
        if !directory.isEmpty {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        do {
            try string.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw CLIError.io("could not write \(path): \(error.localizedDescription)")
        }
    }
}

// MARK: - App preference cache (UserDefaults)

/// Bridges to MCP Panel's UserDefaults so the CLI shares the app's full server
/// list — including disabled servers, which never appear in `~/.claude.json`.
/// The relevant keys (`cached_servers`, `app_settings`) are stored by the app
/// as JSON `Data` blobs inside its preferences plist.
struct DefaultsCacheStore {
    let readPath: String?
    let writePath: String?
    let format: PropertyListSerialization.PropertyListFormat

    init(override: String?) {
        let candidates = Paths.defaultsCandidates(override: override)
        let fileManager = FileManager.default

        var resolvedRead: String?
        for candidate in candidates where fileManager.fileExists(atPath: candidate) {
            resolvedRead = candidate
            break
        }

        // Prefer writing where we read; otherwise pick the first candidate whose
        // parent directory already exists. Never fabricate the app's container.
        var resolvedWrite = resolvedRead
        if resolvedWrite == nil {
            for candidate in candidates {
                let parent = (candidate as NSString).deletingLastPathComponent
                if fileManager.fileExists(atPath: parent) {
                    resolvedWrite = candidate
                    break
                }
            }
        }

        self.readPath = resolvedRead
        self.writePath = resolvedWrite

        // Preserve the existing plist format on rewrite; default to binary (the
        // format cfprefsd uses) when creating a fresh file.
        var detected: PropertyListSerialization.PropertyListFormat = .binary
        if let resolvedRead, let data = fileManager.contents(atPath: resolvedRead) {
            _ = try? PropertyListSerialization.propertyList(from: data, format: &detected)
        }
        self.format = detected
    }

    var isAvailable: Bool { readPath != nil || writePath != nil }
    var isWritable: Bool { writePath != nil }

    private func readPlist() -> [String: Any] {
        guard let readPath, let data = FileManager.default.contents(atPath: readPath) else {
            return [:]
        }
        var fmt = PropertyListSerialization.PropertyListFormat.binary
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: &fmt),
              let dictionary = plist as? [String: Any] else {
            return [:]
        }
        return dictionary
    }

    /// The app's cached server list as an array of mutable JSON objects.
    func readCachedServers() -> [[String: Any]] {
        guard let blob = readPlist()["cached_servers"] as? Data,
              let array = try? JSONSerialization.jsonObject(with: blob) as? [[String: Any]] else {
            return []
        }
        return array
    }

    /// The config path the user selected inside the app, if any.
    func readConfigPath() -> String? {
        appSetting("configPath")
    }

    /// The Factory ("Droid") config path the user configured in the app, if any.
    /// The GUI mirrors enabled servers here (normalized) when it's set; empty
    /// means Droid sync is disabled.
    func readDroidConfigPath() -> String? {
        appSetting("droidConfigPath")
    }

    private func appSetting(_ key: String) -> String? {
        guard let blob = readPlist()["app_settings"] as? Data,
              let settings = try? JSONSerialization.jsonObject(with: blob) as? [String: Any],
              let value = settings[key] as? String, !value.trimmedWhitespace.isEmpty else {
            return nil
        }
        return value
    }

    func writeCachedServers(_ servers: [[String: Any]]) throws {
        guard let writePath else {
            throw CLIError.io("MCP Panel's preference cache was not found; launch the app once so disabled servers can be tracked")
        }
        var plist = readPlist()
        let blob = try JSONSerialization.data(withJSONObject: servers, options: [])
        plist["cached_servers"] = blob

        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
        } catch {
            throw CLIError.io("could not encode preference cache: \(error.localizedDescription)")
        }

        let directory = (writePath as NSString).deletingLastPathComponent
        if !directory.isEmpty {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        do {
            try data.write(to: URL(fileURLWithPath: writePath), options: .atomic)
        } catch {
            throw CLIError.io("could not write preference cache: \(error.localizedDescription)")
        }
    }
}
