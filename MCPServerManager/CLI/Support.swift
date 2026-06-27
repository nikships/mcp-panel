import Foundation

// MARK: - Errors

/// Errors surfaced by the CLI. Each maps to a stable process exit code so that
/// agents can branch on the failure type without parsing prose.
enum CLIError: Error {
    case usage(String)
    case badInput(String)
    case invalidConfig(String)
    case notFound(String)
    case io(String)

    /// Stable, sysexits-style exit codes.
    var exitCode: Int32 {
        switch self {
        case .usage: return 64           // EX_USAGE
        case .badInput: return 65        // EX_DATAERR
        case .invalidConfig: return 65   // EX_DATAERR
        case .notFound: return 69        // EX_UNAVAILABLE
        case .io: return 74              // EX_IOERR
        }
    }

    var message: String {
        switch self {
        case .usage(let value),
             .badInput(let value),
             .invalidConfig(let value),
             .notFound(let value),
             .io(let value):
            return value
        }
    }
}

// MARK: - JSON helpers

enum JSONUtil {
    /// Pretty-print a JSON value exactly the way MCP Panel writes config files:
    /// sorted keys, two-space indentation, and forward slashes left unescaped.
    static func prettyString(_ value: Any) throws -> String {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw CLIError.io("internal: value is not a serializable JSON object")
        }
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw CLIError.io("internal: could not encode JSON as UTF-8")
        }
        return string.unescapingJSONSlashes()
    }

    /// Parse a JSON object from raw text, tolerating curly quotes pasted from
    /// docs or chat tools (matching the app's `normalizingQuotes`).
    static func parseObject(_ text: String) throws -> [String: Any] {
        let normalized = text.normalizingQuotes()
        guard let data = normalized.data(using: .utf8) else {
            throw CLIError.badInput("input is not valid UTF-8")
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CLIError.badInput("could not parse JSON: \(error.localizedDescription)")
        }
        guard let dictionary = object as? [String: Any] else {
            throw CLIError.badInput("expected a JSON object")
        }
        return dictionary
    }
}

// MARK: - String helpers

extension String {
    /// `JSONSerialization` escapes "/" as "\/"; strip that to match the app's
    /// on-disk formatting. Safe because a literal backslash is emitted as "\\",
    /// so the only place "\" precedes "/" in valid JSON output is an escaped solidus.
    func unescapingJSONSlashes() -> String {
        replacingOccurrences(of: "\\/", with: "/")
    }

    /// Normalize curly / smart quotes to straight quotes so JSON pasted from
    /// editors, docs, or chat still parses.
    func normalizingQuotes() -> String {
        replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201E}", with: "\"")
            .replacingOccurrences(of: "\u{00AB}", with: "\"")
            .replacingOccurrences(of: "\u{00BB}", with: "\"")
    }

    var trimmedWhitespace: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Server summaries

/// Lightweight transport / summary derivation, mirroring the labels the app
/// shows on each server card.
enum ServerSummary {
    static func transport(for config: [String: Any]) -> String {
        if let command = config["command"] as? String, !command.trimmedWhitespace.isEmpty {
            return "stdio"
        }
        if let type = (config["type"] as? String)?.lowercased(), !type.isEmpty {
            return type
        }
        if let httpURL = config["httpUrl"] as? String, !httpURL.trimmedWhitespace.isEmpty {
            return "http"
        }
        if let transport = config["transport"] as? [String: Any] {
            if let type = (transport["type"] as? String)?.lowercased(), !type.isEmpty {
                return type
            }
            if let url = transport["url"] as? String, !url.trimmedWhitespace.isEmpty {
                return "http"
            }
        }
        if let url = config["url"] as? String, !url.trimmedWhitespace.isEmpty {
            return "http"
        }
        if remoteURL(in: config) != nil {
            return "http"
        }
        return "custom"
    }

    static func describe(_ config: [String: Any]) -> String {
        if let command = config["command"] as? String, !command.trimmedWhitespace.isEmpty {
            let args = (config["args"] as? [Any])?.compactMap { $0 as? String } ?? []
            return ([command] + args).joined(separator: " ")
        }
        for key in ["httpUrl", "url"] {
            if let value = config[key] as? String, !value.trimmedWhitespace.isEmpty {
                return host(of: value) ?? value
            }
        }
        if let transport = config["transport"] as? [String: Any],
           let url = transport["url"] as? String, !url.trimmedWhitespace.isEmpty {
            return host(of: url) ?? url
        }
        if let remote = remoteURL(in: config) {
            return host(of: remote) ?? remote
        }
        return "custom server"
    }

    /// First non-empty `url` among a config's `remotes` entries, if any.
    private static func remoteURL(in config: [String: Any]) -> String? {
        guard let remotes = config["remotes"] as? [[String: Any]] else { return nil }
        for remote in remotes {
            if let url = remote["url"] as? String, !url.trimmedWhitespace.isEmpty {
                return url
            }
        }
        return nil
    }

    private static func host(of urlString: String) -> String? {
        URL(string: urlString)?.host
    }
}

// MARK: - Droid / Factory normalization

/// Normalizes a server config for the Factory ("Droid") config exactly as the
/// app's `ConfigManager.normalizeForDroid` does: ensure an explicit `type`, map
/// `httpUrl` to `url`, and flatten a `transport` block to `type`/`url`/`headers`.
/// Original keys are preserved (fields are only added), matching the GUI output.
enum DroidNormalizer {
    static func normalize(_ config: [String: Any]) -> [String: Any] {
        var result = config

        if let command = config["command"] as? String, !command.trimmedWhitespace.isEmpty {
            if isBlank(result["type"]) {
                result["type"] = "stdio"
            }
            return result
        }

        if let httpURL = config["httpUrl"] as? String, !httpURL.trimmedWhitespace.isEmpty {
            if isBlank(result["type"]) {
                result["type"] = "http"
            }
            if isBlank(result["url"]) {
                result["url"] = httpURL
            }
        }

        if let transport = config["transport"] as? [String: Any] {
            if isBlank(result["type"]), let type = transport["type"] as? String {
                result["type"] = type
            }
            if isBlank(result["url"]), let url = transport["url"] as? String {
                result["url"] = url
            }
            if result["headers"] == nil, let headers = transport["headers"] {
                result["headers"] = headers
            }
        }

        return result
    }

    private static func isBlank(_ value: Any?) -> Bool {
        guard let string = value as? String else { return value == nil }
        return string.trimmedWhitespace.isEmpty
    }
}
