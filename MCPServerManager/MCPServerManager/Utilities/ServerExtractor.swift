import Foundation

/// Utility to extract server configurations from raw JSON input
/// Based on the original Electron version's forgiving parser
struct ServerExtractor {

    /// Extract server entries from raw JSON string
    /// Handles common issues like trailing commas, missing braces, curly quotes, etc.
    static func extractServerEntries(from raw: String) -> [String: ServerConfig]? {
        var normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Bare URL paste (e.g. "https://mcp.magicpatterns.com/mcp"): build a single HTTP server.
        if let urlEntry = serverEntry(fromURL: normalized) {
            return urlEntry
        }

        // Normalize quotation marks - replace curly/typographic quotes with straight quotes
        // This is super common when copying from Notes, Slack, Word, etc.
        normalized = normalized.normalizingQuotes()

        // Handle JSON fragments: if it doesn't start with {, try wrapping it
        // This includes cases like: "server-name": { ... } (missing outer braces)
        if !normalized.hasPrefix("{") {
            normalized = "{\(normalized)}"
        }

        // Remove trailing commas before closing braces (common copy-paste issue)
        normalized = normalized.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )

        // Try to parse the JSON
        guard let data = normalized.data(using: .utf8) else {
            return nil
        }

        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            // Check for a known wrapper key ("mcpServers" or VS Code/Copilot's "servers").
            if let wrapped = (parsed["mcpServers"] ?? parsed["servers"]) as? [String: Any] {
                return parseServerDictionary(wrapped)
            }

            // Otherwise treat the whole thing as server entries
            return parseServerDictionary(parsed)
        } catch {
            return nil
        }
    }

    /// If the input is a bare URL (optionally without a scheme), build a single HTTP server
    /// entry keyed by the URL's second-level domain (e.g. "magicpatterns").
    private static func serverEntry(fromURL input: String) -> [String: ServerConfig]? {
        // Must be a single token that isn't JSON.
        guard !input.isEmpty,
              !input.contains("{"),
              !input.contains("\""),
              input.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        let hasScheme = input.contains("://")
        // Require a dot for schemeless input so bare words aren't treated as URLs.
        guard hasScheme || input.contains(".") else { return nil }

        let urlString = hasScheme ? input : "https://\(input)"

        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            return nil
        }

        let parts = host.split(separator: ".")
        let name = parts.count >= 2 ? String(parts[parts.count - 2]) : host

        return [name: ServerConfig(type: "http", url: urlString)]
    }

    private static func parseServerDictionary(_ dict: [String: Any]) -> [String: ServerConfig]? {
        var result: [String: ServerConfig] = [:]

        for (name, value) in dict {
            let normalizedValue = normalizeServerValue(value)

            guard JSONSerialization.isValidJSONObject(normalizedValue),
                  let data = try? JSONSerialization.data(withJSONObject: normalizedValue),
                  let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
                continue
            }
            result[name] = config
        }

        return result.isEmpty ? nil : result
    }

    private static func normalizeServerValue(_ value: Any) -> Any {
        guard var config = value as? [String: Any] else {
            return value
        }

        if let commandArray = config["command"] as? [Any] {
            let parts = commandArray.compactMap { $0 as? String }
            if let command = parts.first {
                config["command"] = command
                if config["args"] == nil, parts.count > 1 {
                    config["args"] = Array(parts.dropFirst())
                }
            }
        }

        if config["env"] == nil, let environment = stringDictionary(from: config["environment"]) {
            config["env"] = environment
        }

        if let headers = stringDictionary(from: config["headers"]) {
            config["headers"] = headers
        }

        if var transport = config["transport"] as? [String: Any] {
            if let headers = stringDictionary(from: transport["headers"]) {
                transport["headers"] = headers
            }
            config["transport"] = transport
        }

        if let remotes = config["remotes"] as? [[String: Any]] {
            config["remotes"] = remotes.map { remote in
                var normalizedRemote = remote
                if let headers = stringDictionary(from: normalizedRemote["headers"]) {
                    normalizedRemote["headers"] = headers
                }
                return normalizedRemote
            }
        }

        return config
    }

    private static func stringDictionary(from value: Any?) -> [String: String]? {
        if let strings = value as? [String: String] {
            return strings
        }

        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        let strings = dictionary.compactMapValues { value -> String? in
            switch value {
            case let string as String:
                return string
            case let number as NSNumber:
                return number.stringValue
            default:
                return nil
            }
        }

        return strings.isEmpty ? nil : strings
    }
}
