import Foundation

/// Top-level command handling for the `mcp-panel` executable. Agent-first: all
/// success output is pretty-printed JSON on stdout, all errors are JSON on
/// stderr, and the process exit code encodes the failure type.
enum MCPPanelCLI {
    static let version = "0.1.0"

    static func run(_ arguments: [String]) -> Int32 {
        do {
            return try dispatch(arguments)
        } catch let error as CLIError {
            emitError(error.message)
            return error.exitCode
        } catch {
            emitError(error.localizedDescription)
            return 70 // EX_SOFTWARE
        }
    }

    // MARK: - Dispatch

    private static func dispatch(_ arguments: [String]) throws -> Int32 {
        var configOverride: String?
        var defaultsOverride: String?
        var factoryOverride: String?
        var positionals: [String] = []

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            // Global flags are only recognized before the command token. Once a
            // positional (the command) has been seen, everything after it is
            // command data — so a server literally named `help` or an argument
            // like `--config` is passed through untouched.
            if !positionals.isEmpty {
                positionals.append(contentsOf: arguments[index...])
                break
            }
            switch arg {
            case "-h", "--help", "help":
                printUsage()
                return 0
            case "--version":
                printLine(version)
                return 0
            case "--config":
                index += 1
                guard index < arguments.count else { throw CLIError.usage("--config requires a path") }
                configOverride = arguments[index]
            case "--defaults":
                index += 1
                guard index < arguments.count else { throw CLIError.usage("--defaults requires a path") }
                defaultsOverride = arguments[index]
            case "--factory":
                index += 1
                guard index < arguments.count else { throw CLIError.usage("--factory requires a path") }
                factoryOverride = arguments[index]
            default:
                positionals.append(arg)
            }
            index += 1
        }

        guard let command = positionals.first else {
            printUsage()
            return 0
        }
        let rest = Array(positionals.dropFirst())
        let context = Context(
            configOverride: configOverride,
            defaultsOverride: defaultsOverride,
            factoryOverride: factoryOverride
        )

        switch command {
        case "list", "ls":
            return try runList(context: context)
        case "add":
            return try runAdd(rest, context: context)
        case "toggle":
            return try runToggle(rest, context: context)
        default:
            throw CLIError.usage("unknown command '\(command)'. Run 'mcp-panel --help'.")
        }
    }

    // MARK: - Shared context

    /// Resolves the active config path (override → app setting → default) and
    /// builds the stores shared by every command.
    struct Context {
        let configStore: ClaudeConfigStore
        let cacheStore: DefaultsCacheStore
        let factoryStore: ClaudeConfigStore?

        var configPath: String { configStore.path }
        var factoryConfigPath: String? { factoryStore?.path }

        init(configOverride: String?, defaultsOverride: String?, factoryOverride: String?) {
            let cache = DefaultsCacheStore(override: defaultsOverride)
            let resolvedPath: String
            if let configOverride, !configOverride.trimmedWhitespace.isEmpty {
                resolvedPath = configOverride
            } else if let fromApp = cache.readConfigPath() {
                resolvedPath = fromApp
            } else {
                resolvedPath = Paths.defaultConfigPath
            }
            self.cacheStore = cache
            self.configStore = ClaudeConfigStore(path: resolvedPath)

            // Factory ("Droid") path: explicit flag, then env var, then the app's
            // configured droidConfigPath. Absent → Droid sync stays disabled,
            // exactly as in the GUI.
            let env = ProcessInfo.processInfo.environment["MCP_PANEL_FACTORY_CONFIG"]
            let factoryPath = [factoryOverride, env, cache.readDroidConfigPath()]
                .compactMap { $0 }
                .map { $0.trimmedWhitespace }
                .first { !$0.isEmpty }
            self.factoryStore = factoryPath.map { ClaudeConfigStore(path: $0) }
        }
    }

    // MARK: - Commands

    private static func runList(context: Context) throws -> Int32 {
        let registry = try ServerRegistry(configStore: context.configStore, cacheStore: context.cacheStore, factoryStore: context.factoryStore)

        var servers: [[String: Any]] = []
        for name in registry.sortedNames() {
            guard let entry = registry.entry(named: name) else { continue }
            let config = (entry["config"] as? [String: Any]) ?? [:]
            let enabled = (entry["enabled"] as? Bool) ?? false
            servers.append([
                "name": name,
                "enabled": enabled,
                "transport": ServerSummary.transport(for: config),
                "summary": ServerSummary.describe(config),
                "config": config
            ])
        }

        let enabledCount = servers.filter { ($0["enabled"] as? Bool) == true }.count
        var payload: [String: Any] = [
            "configPath": context.configPath,
            "cacheAvailable": context.cacheStore.isAvailable,
            "counts": [
                "total": servers.count,
                "enabled": enabledCount,
                "disabled": servers.count - enabledCount
            ],
            "servers": servers
        ]
        if let factoryPath = context.factoryConfigPath {
            payload["factoryConfigPath"] = factoryPath
            if let inSync = registry.factoryInSync() {
                payload["factoryInSync"] = inSync
            }
        }
        printLine(try JSONUtil.prettyString(payload))
        return 0
    }

    private static func runAdd(_ args: [String], context: Context) throws -> Int32 {
        guard let name = args.first, !name.trimmedWhitespace.isEmpty else {
            throw CLIError.usage("usage: mcp-panel add <name> [json]   (JSON via argument or stdin)")
        }
        let jsonText = try resolveInput(Array(args.dropFirst()))
        let parsed = try JSONUtil.parseObject(jsonText)
        let config = try extractConfig(from: parsed, name: name)
        try validate(config)

        var registry = try ServerRegistry(configStore: context.configStore, cacheStore: context.cacheStore, factoryStore: context.factoryStore)
        let existed = registry.entry(named: name) != nil
        let entry = try registry.add(name: name, config: config)

        var payload: [String: Any] = [
            "action": existed ? "updated" : "added",
            "name": name,
            "enabled": (entry["enabled"] as? Bool) ?? true,
            "transport": ServerSummary.transport(for: config),
            "configPath": context.configPath,
            "cacheUpdated": context.cacheStore.isWritable,
            "config": config
        ]
        if let factoryPath = context.factoryConfigPath {
            payload["factoryConfigPath"] = factoryPath
            payload["factorySynced"] = true
        }
        printLine(try JSONUtil.prettyString(payload))
        return 0
    }

    private static func runToggle(_ args: [String], context: Context) throws -> Int32 {
        guard let name = args.first, !name.trimmedWhitespace.isEmpty else {
            throw CLIError.usage("usage: mcp-panel toggle <name> [on|off]")
        }

        var target: Bool?
        if args.count > 1 {
            switch args[1].lowercased() {
            case "on", "true", "enable", "enabled": target = true
            case "off", "false", "disable", "disabled": target = false
            default: throw CLIError.usage("toggle state must be 'on' or 'off'")
            }
        }

        var registry = try ServerRegistry(configStore: context.configStore, cacheStore: context.cacheStore, factoryStore: context.factoryStore)
        let result = try registry.setEnabled(name: name, target: target)
        let enabled = (result.entry["enabled"] as? Bool) ?? false

        var payload: [String: Any] = [
            "action": "toggle",
            "name": name,
            "enabled": enabled,
            "changed": result.changed,
            "configPath": context.configPath,
            "cacheUpdated": context.cacheStore.isWritable
        ]
        // Disabling without a writable cache means the config cannot be
        // remembered for re-enabling — surface that instead of losing it silently.
        if !enabled && !context.cacheStore.isWritable {
            payload["warning"] = "MCP Panel's cache was not found; this server is removed from the active config and not remembered. Launch MCP Panel once to enable disabled-state tracking."
        }
        if let factoryPath = context.factoryConfigPath {
            payload["factoryConfigPath"] = factoryPath
            payload["factorySynced"] = result.changed
        }
        printLine(try JSONUtil.prettyString(payload))
        return 0
    }

    // MARK: - Input handling

    private static func resolveInput(_ args: [String]) throws -> String {
        let joined = args.joined(separator: " ").trimmedWhitespace
        if !joined.isEmpty {
            return joined
        }
        let data = (try? FileHandle.standardInput.readToEnd()) ?? Data()
        guard let text = String(data: data, encoding: .utf8), !text.trimmedWhitespace.isEmpty else {
            throw CLIError.badInput("no server JSON provided (pass it as an argument or via stdin)")
        }
        return text
    }

    private static let configKeys: Set<String> = [
        "command", "args", "env", "cwd", "type", "url",
        "httpUrl", "headers", "transport", "remotes"
    ]

    /// Resolves the server config object from flexible input shapes, always
    /// keyed by the explicit `<name>` argument.
    private static func extractConfig(from object: [String: Any], name: String) throws -> [String: Any] {
        for wrapper in ["mcpServers", "servers"] {
            if let inner = object[wrapper] as? [String: Any] {
                if let match = inner[name] as? [String: Any] {
                    return match
                }
                if inner.count == 1, let only = inner.values.first as? [String: Any] {
                    return only
                }
                throw CLIError.badInput("'\(wrapper)' has multiple servers and none named '\(name)'")
            }
        }
        if !configKeys.isDisjoint(with: object.keys) {
            return object
        }
        if object.count == 1, let only = object.values.first as? [String: Any] {
            return only
        }
        throw CLIError.badInput("could not find a server config in the provided JSON")
    }

    private static func validate(_ config: [String: Any]) throws {
        func nonEmpty(_ key: String) -> Bool {
            guard let value = config[key] as? String else { return false }
            return !value.trimmedWhitespace.isEmpty
        }
        if nonEmpty("command") || nonEmpty("httpUrl") || nonEmpty("url") { return }
        if config["transport"] is [String: Any] { return }
        if let remotes = config["remotes"] as? [Any], !remotes.isEmpty { return }
        throw CLIError.invalidConfig("config needs one of: command, url, httpUrl, transport, or remotes")
    }

    // MARK: - Output

    private static func printLine(_ string: String) {
        print(string)
    }

    private static func emitError(_ message: String) {
        let payload = ["error": message]
        let line: String
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            line = text.unescapingJSONSlashes()
        } else {
            line = message
        }
        if let data = (line + "\n").data(using: .utf8) {
            try? FileHandle.standardError.write(contentsOf: data)
        }
    }

    private static func printUsage() {
        let text = """
        mcp-panel \(version) — agent-first CLI for MCP Panel (Claude Code MCP servers)

        USAGE
          mcp-panel [options] <command> [args]    (options precede the command)

        COMMANDS
          list                      List all servers with status (JSON)
          add <name> [json]         Add/update a server from raw MCP JSON (argument or stdin)
          toggle <name> [on|off]    Enable/disable a server (no arg flips; on|off is idempotent)

        OPTIONS
          --config <path>           Config file (default: app setting, else ~/.claude.json)
          --factory <path>          Factory/Droid config to mirror (default: app setting; e.g. ~/.factory/mcp.json)
          --defaults <path>         MCP Panel preferences plist (advanced)
          -h, --help                Show this help
          --version                 Print version

        NOTES
          Enabled servers live in ~/.claude.json (what Claude Code loads). Disabled servers
          are remembered in MCP Panel's shared cache, matching the app's GUI. When a Factory
          (Droid) config is set — in the app or via --factory — the enabled set is mirrored
          there too, normalized to match the GUI. Output is JSON on stdout; errors are JSON
          on stderr with a non-zero exit code.

        EXAMPLES
          mcp-panel list
          mcp-panel add context7 '{"command":"npx","args":["-y","@upstash/context7-mcp"]}'
          echo '{"type":"http","url":"https://mcp.example.com/mcp"}' | mcp-panel add example
          mcp-panel toggle context7 off
        """
        printLine(text)
    }
}
