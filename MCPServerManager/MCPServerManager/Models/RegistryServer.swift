import Foundation

// MARK: - Registry Server Model

/// Represents a server from the MCP GitHub registry
struct RegistryServer: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let repository: String
    let config: ServerConfig
    let metadata: RegistryMetadata
    let imageUrl: String?

    init(id: String,
         name: String,
         description: String,
         repository: String,
         config: ServerConfig,
         metadata: RegistryMetadata,
         imageUrl: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.repository = repository
        self.config = config
        self.metadata = metadata
        self.imageUrl = imageUrl
    }

    /// Display name (without org prefix)
    var displayName: String {
        name.split(separator: "/").last.map(String.init) ?? name
    }

    /// Formatted config as pretty JSON string
    var configJSON: String {
        config.prettyJSON
    }
}

// MARK: - Registry Metadata

struct RegistryMetadata: Codable {
    let createdAt: String?
    let updatedAt: String?
    let packageIdentifier: String?
    let packageVersion: String?
    let registryType: String?
    let runtimeHint: String?

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case packageIdentifier = "package_identifier"
        case packageVersion = "package_version"
        case registryType = "registry_type"
        case runtimeHint = "runtime_hint"
    }
}

// MARK: - Registry API Response Models

struct RegistryAPIResponse: Codable {
    let servers: [RegistryAPIServerWrapper]
    let metadata: PaginationMetadata?
}

struct PaginationMetadata: Codable {
    let count: Int?
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case count
        case nextCursor = "next_cursor"
    }
}

struct RegistryAPIServerWrapper: Codable {
    let server: RegistryAPIServer
    let xGithub: GitHubMetadata?
    let xRegistry: RegistryMeta?

    enum CodingKeys: String, CodingKey {
        case server
        case xGithub = "x-github"
        case xRegistry = "x-io.modelcontextprotocol.registry"
    }
}

struct RegistryAPIServer: Codable {
    let id: String?
    let name: String
    let description: String
    let repository: RepositoryInfo?
    let packages: [PackageInfo]?
    let remotes: [APIRemoteConfig]?
    let createdAt: String?
    let updatedAt: String?
    let versionDetail: VersionDetail?

    enum CodingKeys: String, CodingKey {
        case id, name, description, repository, packages, remotes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case versionDetail = "version_detail"
    }
}

struct VersionDetail: Codable {
    let version: String
    let isLatest: Bool?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case version
        case isLatest = "is_latest"
        case releaseDate = "release_date"
    }
}

struct RegistryMeta: Codable {
    let id: String?
    let publishedAt: String?
    let updatedAt: String?
    let isLatest: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
        case isLatest = "is_latest"
    }
}

struct GitHubMetadata: Codable {
    let displayName: String?
    let isInOrganization: Bool?
    let license: String?
    let name: String?
    let nameWithOwner: String?
    let opengraphImageUrl: String?
    let ownerAvatarUrl: String?
    let preferredImage: String?
    let primaryLanguage: String?
    let primaryLanguageColor: String?
    let pushedAt: String?
    let readme: String?
    let stargazerCount: Int?
    let topics: [String]?
    let usesCustomOpengraphImage: Bool?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case isInOrganization = "is_in_organization"
        case license, name
        case nameWithOwner = "name_with_owner"
        case opengraphImageUrl = "opengraph_image_url"
        case ownerAvatarUrl = "owner_avatar_url"
        case preferredImage = "preferred_image"
        case primaryLanguage = "primary_language"
        case primaryLanguageColor = "primary_language_color"
        case pushedAt = "pushed_at"
        case readme
        case stargazerCount = "stargazer_count"
        case topics
        case usesCustomOpengraphImage = "uses_custom_opengraph_image"
    }
}

struct APIRemoteConfig: Codable {
    let transportType: String
    let url: String
    let headers: [APIHeader]?

    enum CodingKeys: String, CodingKey {
        case transportType = "transport_type"
        case url, headers
    }
}

struct APIHeader: Codable {
    let name: String?
    let value: String?
    let variables: [String: APIHeaderVariable]?
    let description: String?
    let isSecret: Bool?

    enum CodingKeys: String, CodingKey {
        case name, value, variables, description
        case isSecret = "is_secret"
    }

    var headerName: String? {
        if let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmedName.isEmpty {
            return trimmedName
        }

        let valueHint = value?.lowercased() ?? ""
        let descriptionHint = description?.lowercased() ?? ""

        if valueHint.contains("bearer") || descriptionHint.contains("authorization") || descriptionHint.contains("api token") {
            return "Authorization"
        }

        if descriptionHint.contains("api key") {
            return "X-API-Key"
        }

        return nil
    }

    var headerValue: String? {
        if let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmedValue.isEmpty {
            return trimmedValue
        }

        guard headerName != nil else { return nil }

        let descriptionHint = description?.lowercased() ?? ""
        if descriptionHint.contains("bearer") || descriptionHint.contains("token") {
            return "Bearer <token>"
        }

        if descriptionHint.contains("api key") {
            return "<api-key>"
        }

        return "<value>"
    }
}

struct APIHeaderVariable: Codable {
    let description: String?
    let isSecret: Bool?

    enum CodingKeys: String, CodingKey {
        case description
        case isSecret = "is_secret"
    }
}

struct RepositoryInfo: Codable {
    let id: String?
    let readme: String?
    let source: String?
    let url: String?
}

struct PackageInfo: Codable {
    let name: String?
    let registryName: String?
    let registryBaseUrl: String?
    let version: String?
    let runtimeHint: String?

    enum CodingKeys: String, CodingKey {
        case name
        case registryName = "registry_name"
        case registryBaseUrl = "registry_base_url"
        case version
        case runtimeHint = "runtime_hint"
    }
}
