import Foundation

struct ServerModel: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var config: ServerConfig
    var enabled: Bool
    var updatedAt: Date
    var registryImageUrl: String? // Image URL from MCP registry (takes precedence over fetched icons)
    var customIconPath: String? // User-selected custom icon path (takes highest precedence)
    var tags: [ServerTag]

    init(id: UUID = UUID(),
         name: String,
         config: ServerConfig,
         enabled: Bool = false,
         updatedAt: Date = Date(),
         registryImageUrl: String? = nil,
         customIconPath: String? = nil,
         tags: [ServerTag] = []) {
        self.id = id
        self.name = name
        self.config = config
        self.enabled = enabled
        self.updatedAt = updatedAt
        self.registryImageUrl = registryImageUrl
        self.customIconPath = customIconPath
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case config
        case enabled
        case updatedAt
        case inConfigs // legacy key (pre single-config migration)
        case registryImageUrl
        case customIconPath
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        config = try container.decode(ServerConfig.self, forKey: .config)
        // Migration: prefer new `enabled` key; if absent, derive from legacy `inConfigs`.
        if let decodedEnabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) {
            enabled = decodedEnabled
        } else if let legacyInConfigs = try container.decodeIfPresent([Bool].self, forKey: .inConfigs) {
            enabled = legacyInConfigs.first ?? false
        } else {
            enabled = false
        }
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        registryImageUrl = try container.decodeIfPresent(String.self, forKey: .registryImageUrl)
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        tags = try container.decodeIfPresent([ServerTag].self, forKey: .tags) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(config, forKey: .config)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(registryImageUrl, forKey: .registryImageUrl)
        try container.encodeIfPresent(customIconPath, forKey: .customIconPath)
        try container.encode(tags, forKey: .tags)
    }

    // MARK: - Computed Properties

    var configJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(config),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }

    /// Full named entry: "name": { ...config... }  (matches on-disk shape)
    var namedConfigJSON: String {
        let inner = configJSON                       // existing pretty body
        let indented = inner.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: "\n  ")
        return "\"\(name)\" : \(indented)"
    }

    /// Extract domain for icon fetching
    var iconDomain: String? {
        return DomainExtractor.extractDomain(from: name, config: config)
    }
}

// MARK: - Config Response

struct ConfigResponse: Codable {
    let success: Bool
    let servers: [String: ServerConfig]
    let fullConfig: FullConfig?
    let isNew: Bool?
    let error: String?

    struct FullConfig: Codable {
        let mcpServers: [String: ServerConfig]?
    }
}

// MARK: - Save Response

struct SaveResponse: Codable {
    let success: Bool
    let error: String?
}
