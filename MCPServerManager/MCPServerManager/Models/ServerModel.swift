import Foundation

struct ServerModel: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var config: ServerConfig
    var enabled: Bool
    var updatedAt: Date
    var inConfigs: [Bool] // [inConfig1, inConfig2]
    var registryImageUrl: String? // Image URL from MCP registry (takes precedence over fetched icons)
    var customIconPath: String? // User-selected custom icon path (takes highest precedence)
    var tags: [ServerTag]
    var showInWidget: Bool // Whether this server appears in the macOS widget

    init(id: UUID = UUID(),
         name: String,
         config: ServerConfig,
         enabled: Bool = false,
         updatedAt: Date = Date(),
         inConfigs: [Bool] = [false, false],
         registryImageUrl: String? = nil,
         customIconPath: String? = nil,
         tags: [ServerTag] = [],
         showInWidget: Bool = false) {
        self.id = id
        self.name = name
        self.config = config
        self.enabled = enabled
        self.updatedAt = updatedAt
        self.inConfigs = inConfigs
        self.registryImageUrl = registryImageUrl
        self.customIconPath = customIconPath
        self.tags = tags
        self.showInWidget = showInWidget
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case config
        case enabled
        case updatedAt
        case inConfigs
        case registryImageUrl
        case customIconPath
        case tags
        case showInWidget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        config = try container.decode(ServerConfig.self, forKey: .config)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let decodedInConfigs = try container.decode([Bool].self, forKey: .inConfigs)
        var normalizedInConfigs = Array(decodedInConfigs.prefix(2))
        while normalizedInConfigs.count < 2 {
            normalizedInConfigs.append(false)
        }
        inConfigs = normalizedInConfigs
        registryImageUrl = try container.decodeIfPresent(String.self, forKey: .registryImageUrl)
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        tags = try container.decodeIfPresent([ServerTag].self, forKey: .tags) ?? []
        showInWidget = try container.decodeIfPresent(Bool.self, forKey: .showInWidget) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(config, forKey: .config)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(inConfigs, forKey: .inConfigs)
        try container.encodeIfPresent(registryImageUrl, forKey: .registryImageUrl)
        try container.encodeIfPresent(customIconPath, forKey: .customIconPath)
        try container.encode(tags, forKey: .tags)
        try container.encode(showInWidget, forKey: .showInWidget)
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

    var isInConfig1: Bool { inConfigs.count > 0 ? inConfigs[0] : false }
    var isInConfig2: Bool { inConfigs.count > 1 ? inConfigs[1] : false }

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
