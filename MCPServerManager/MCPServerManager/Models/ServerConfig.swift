import Foundation

// MARK: - AnyCodable

/// A type-erased Codable value to handle arbitrary JSON/TOML data
enum AnyCodable: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    case null

    init(_ value: Any?) {
        guard let value = value else {
            self = .null
            return
        }
        
        if let string = value as? String {
            self = .string(string)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let array = value as? [Any] {
            self = .array(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            self = .dictionary(dict.mapValues { AnyCodable($0) })
        } else if let codable = value as? AnyCodable {
            self = codable
        } else {
            self = .string(String(describing: value))
        }
    }

    var value: Any? {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .array(let a): return a.map { $0.value }
        case .dictionary(let d): return d.mapValues { $0.value }
        case .null: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .dictionary(let d): try container.encode(d)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - String Extension for Validation

private extension String? {
    /// Returns true if the optional string is non-nil and contains non-whitespace characters
    var isNonEmptyString: Bool {
        guard let self = self else { return false }
        return !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Server Configuration Models

struct ServerTransportConfig: Codable, Equatable {
    var type: String
    var url: String?
    var headers: [String: String]?
    // Support extra fields in transport too
    var extra: [String: AnyCodable] = [:]

    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }

    private static let knownKeys: Set<String> = ["type", "url", "headers"]

    init(type: String, url: String? = nil, headers: [String: String]? = nil, extra: [String: AnyCodable] = [:]) {
        self.type = type
        self.url = url
        self.headers = headers
        self.extra = extra
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Mandatory/Known fields
        if let typeKey = DynamicCodingKeys(stringValue: "type") {
            type = try container.decode(String.self, forKey: typeKey)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to create type coding key")
            )
        }

        if let urlKey = DynamicCodingKeys(stringValue: "url") {
            url = try container.decodeIfPresent(String.self, forKey: urlKey)
        }
        if let headersKey = DynamicCodingKeys(stringValue: "headers") {
            headers = try container.decodeIfPresent([String: String].self, forKey: headersKey)
        }
        
        // Decode everything else into extra
        for key in container.allKeys {
            let name = key.stringValue
            if !Self.knownKeys.contains(name) {
                extra[name] = try container.decode(AnyCodable.self, forKey: key)
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        
        if let typeKey = DynamicCodingKeys(stringValue: "type") {
            try container.encode(type, forKey: typeKey)
        }
        if let urlKey = DynamicCodingKeys(stringValue: "url") {
            try container.encodeIfPresent(url, forKey: urlKey)
        }
        if let headersKey = DynamicCodingKeys(stringValue: "headers") {
            try container.encodeIfPresent(headers, forKey: headersKey)
        }
        
        for (key, value) in extra {
            if !Self.knownKeys.contains(key), let dynamicKey = DynamicCodingKeys(stringValue: key) {
                try container.encode(value, forKey: dynamicKey)
            }
        }
    }
}

struct ServerRemoteConfig: Codable, Equatable {
    var type: String
    var url: String
    var headers: [String: String]?

    init(type: String, url: String, headers: [String: String]? = nil) {
        self.type = type
        self.url = url
        self.headers = headers
    }
}

struct ServerConfig: Codable, Equatable {
    // Standard MCP fields
    var command: String?
    var args: [String]?
    var cwd: String?
    var env: [String: String]?
    var transport: ServerTransportConfig?
    var remotes: [ServerRemoteConfig]?
    
    // Implicit/Remote fields
    var type: String?
    var url: String?
    
    // GitHub Copilot MCP fields
    var httpUrl: String?
    var headers: [String: String]?

    // Everything else (unlimited versioning)
    var extra: [String: AnyCodable] = [:]

    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }

    // List of known keys to exclude from 'extra'
    private static let knownKeys: Set<String> = [
        "command", "args", "cwd", "env", "transport", "remotes", 
        "type", "url", "httpUrl", "headers"
    ]

    init(command: String? = nil,
         args: [String]? = nil,
         cwd: String? = nil,
         env: [String: String]? = nil,
         transport: ServerTransportConfig? = nil,
         remotes: [ServerRemoteConfig]? = nil,
         type: String? = nil,
         url: String? = nil,
         httpUrl: String? = nil,
         headers: [String: String]? = nil,
         extra: [String: AnyCodable] = [:]) {
        self.command = command
        self.args = args
        self.cwd = cwd
        self.env = env
        self.transport = transport
        self.remotes = remotes
        self.type = type
        self.url = url
        self.httpUrl = httpUrl
        self.headers = headers
        self.extra = extra
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Decode known fields explicitly
        if let k = DynamicCodingKeys(stringValue: "command") { command = try container.decodeIfPresent(String.self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "args") { args = try container.decodeIfPresent([String].self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "cwd") { cwd = try container.decodeIfPresent(String.self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "env") { env = try container.decodeIfPresent([String: String].self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "transport") { transport = try container.decodeIfPresent(ServerTransportConfig.self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "remotes") { remotes = try container.decodeIfPresent([ServerRemoteConfig].self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "type") { type = try container.decodeIfPresent(String.self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "url") { url = try container.decodeIfPresent(String.self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "httpUrl") { httpUrl = try container.decodeIfPresent(String.self, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "headers") { headers = try container.decodeIfPresent([String: String].self, forKey: k) }

        // Decode everything else
        for key in container.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                extra[key.stringValue] = try container.decode(AnyCodable.self, forKey: key)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Encode known fields
        if let v = command, let k = DynamicCodingKeys(stringValue: "command") { try container.encode(v, forKey: k) }
        if let v = args, !v.isEmpty, let k = DynamicCodingKeys(stringValue: "args") { try container.encode(v, forKey: k) }
        if let v = cwd, let k = DynamicCodingKeys(stringValue: "cwd") { try container.encode(v, forKey: k) }
        if let v = env, !v.isEmpty, let k = DynamicCodingKeys(stringValue: "env") { try container.encode(v, forKey: k) }
        if let v = transport, let k = DynamicCodingKeys(stringValue: "transport") { try container.encode(v, forKey: k) }
        if let v = remotes, !v.isEmpty, let k = DynamicCodingKeys(stringValue: "remotes") { try container.encode(v, forKey: k) }
        if let v = type, let k = DynamicCodingKeys(stringValue: "type") { try container.encode(v, forKey: k) }
        if let v = url, let k = DynamicCodingKeys(stringValue: "url") { try container.encode(v, forKey: k) }
        if let v = httpUrl, let k = DynamicCodingKeys(stringValue: "httpUrl") { try container.encode(v, forKey: k) }
        if let v = headers, !v.isEmpty, let k = DynamicCodingKeys(stringValue: "headers") { try container.encode(v, forKey: k) }

        // Encode extra fields
        for (key, value) in extra {
            if !Self.knownKeys.contains(key), let dynamicKey = DynamicCodingKeys(stringValue: key) {
                try container.encode(value, forKey: dynamicKey)
            }
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        // Check for stdio-type servers
        if type == "stdio", command.isNonEmptyString {
            return true
        }

        // Check for HTTP-type servers
        if type == "http", url.isNonEmptyString {
            return true
        }

        // Check for httpUrl-based servers (GitHub Copilot MCP format)
        if httpUrl.isNonEmptyString {
            return true
        }

        // Check for SSE-type servers (Server-Sent Events)
        if type == "sse", url.isNonEmptyString {
            return true
        }
        
        // Relaxed validation: If URL is present, it's likely a valid remote server (implicit type)
        if url.isNonEmptyString {
            return true
        }

        // Check for standard command-based servers
        let hasCommand = command.isNonEmptyString
        let hasTransport = transport != nil
        let hasRemotes = remotes?.isEmpty == false

        return hasCommand || hasTransport || hasRemotes
    }

    // MARK: - Summary

    var summary: String {
        // Handle URL-based servers (HTTP, SSE)
        if let serverType = type, (serverType == "http" || serverType == "sse"), url.isNonEmptyString, let urlString = url {
            let urlHost = formatURLHost(urlString)
            return "\(serverType.uppercased()) → \(urlHost)"
        }

        if command.isNonEmptyString, let cmd = command {
            return cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Handle httpUrl-based servers
        if httpUrl.isNonEmptyString, let httpUrlString = httpUrl {
            let urlHost = formatURLHost(httpUrlString)
            return "HTTP → \(urlHost)"
        }

        if let transport = transport {
            let transportType = transport.type
            let urlHost = transport.url.flatMap { formatURLHost($0) } ?? "custom endpoint"
            return "Remote \(transportType) → \(urlHost)"
        }

        if let remotes = remotes, let firstRemote = remotes.first {
            let remoteType = firstRemote.type
            let urlHost = formatURLHost(firstRemote.url)
            return "Remote \(remoteType) → \(urlHost)"
        }
        
        // Fallback for implicit URL servers
        if let urlString = url {
             return "Remote → \(formatURLHost(urlString))"
        }

        return "Custom server configuration"
    }

    private func formatURLHost(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
    }

    // MARK: - JSON

    /// Pretty-printed JSON representation of this config.
    var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }
}
