import Foundation

// MARK: - MCP Registry Service

@MainActor
class MCPRegistryService: ObservableObject {
    static let shared = MCPRegistryService()

    @Published var isLoading: Bool = false

    private let apiURL = "https://api.mcp.github.com/v0/servers"
    private var cachedServers: [RegistryServer]?
    private var cacheTimestamp: Date?
    private let cacheTimeout: TimeInterval = 3600 // 1 hour

    // Compiled regex patterns for better performance (Sendable, safe for concurrent access)
    nonisolated private static let jsonBlockRegex = compileRegex(
        pattern: #"```json\s*\n(.*?)\n```"#,
        options: [.dotMatchesLineSeparators]
    )
    nonisolated private static let codeBlockRegex = compileRegex(
        pattern: #"```\s*\n(\{.*?\})\n```"#,
        options: [.dotMatchesLineSeparators]
    )
    nonisolated private static let inlineRegex = compileRegex(
        pattern: #""[^"]+"\s*:\s*\{[\s\S]*?"(?:command|httpUrl|url|transport|remotes|type)"\s*:[\s\S]*?\}"#,
        options: []
    )

    /// Safely compile a regex pattern, returning `nil` (and logging in debug) instead of crashing.
    nonisolated private static func compileRegex(
        pattern: String,
        options: NSRegularExpression.Options
    ) -> NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            #if DEBUG
            print("MCPRegistryService: Failed to compile regex \(pattern): \(error)")
            #endif
            return nil
        }
    }

    private init() {}

    /// Fetch servers from the MCP registry
    func fetchServers() async throws -> [RegistryServer] {
        // Check cache first
        if let cached = cachedServers,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            #if DEBUG
            print("MCPRegistryService: Returning cached servers (\(cached.count) servers)")
            #endif
            return cached
        }

        #if DEBUG
        print("MCPRegistryService: Fetching from API: \(apiURL)")
        #endif

        isLoading = true
        defer { isLoading = false }

        let allServers = try await fetchAllServerWrappers()

        // Process servers and extract configs
        let registryServers = allServers.compactMap { makeRegistryServer(from: $0) }

        #if DEBUG
        print("MCPRegistryService: Successfully processed \(registryServers.count) servers")
        #endif

        // Update cache
        cachedServers = registryServers
        cacheTimestamp = Date()

        return registryServers
    }

    /// Fetch every page of registry servers, following pagination cursors with a safety limit.
    private func fetchAllServerWrappers() async throws -> [RegistryAPIServerWrapper] {
        var allServers: [RegistryAPIServerWrapper] = []
        var cursor: String?
        var pageCount = 0
        let maxPages = 100 // Safety limit to prevent infinite loops

        repeat {
            pageCount += 1

            // Break if we hit pagination limit
            if pageCount > maxPages {
                #if DEBUG
                print("MCPRegistryService: Hit maximum page limit (\(maxPages)), stopping pagination")
                #endif
                break
            }

            let apiResponse = try await fetchServerPage(cursor: cursor)

            #if DEBUG
            print("MCPRegistryService: Page \(pageCount) - Fetched \(apiResponse.servers.count) servers")
            #endif

            allServers.append(contentsOf: apiResponse.servers)

            // Check for next page
            cursor = apiResponse.metadata?.nextCursor.flatMap { $0.isEmpty ? nil : $0 }
        } while cursor != nil

        #if DEBUG
        print("MCPRegistryService: Total \(allServers.count) servers fetched across \(pageCount) page(s)")
        #endif

        return allServers
    }

    /// Fetch and decode a single page of registry servers for the given pagination cursor.
    private func fetchServerPage(cursor: String?) async throws -> RegistryAPIResponse {
        let pageURL: String
        if let cursor, !cursor.isEmpty {
            pageURL = apiURL + "?cursor=\(cursor)"
        } else {
            pageURL = apiURL
        }

        guard let url = URL(string: pageURL) else {
            throw MCPRegistryError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPRegistryError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw MCPRegistryError.httpError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(RegistryAPIResponse.self, from: data)
        } catch {
            throw MCPRegistryError.decodingError(error)
        }
    }

    /// Build a `RegistryServer` from an API wrapper, resolving its config and metadata.
    private func makeRegistryServer(from wrapper: RegistryAPIServerWrapper) -> RegistryServer? {
        let apiServer = wrapper.server
        let xGithub = wrapper.xGithub

        guard let finalConfig = resolveConfig(for: apiServer, xGithub: xGithub) else {
            #if DEBUG
            print("MCPRegistryService: Skipping \(apiServer.name) - no valid config found")
            #endif
            return nil
        }

        let packageInfo = apiServer.packages?.first(where: { inferRegistryName(for: $0) != nil }) ?? apiServer.packages?.first
        let metadata = RegistryMetadata(
            createdAt: apiServer.createdAt,
            updatedAt: apiServer.updatedAt,
            packageIdentifier: packageInfo?.name,
            packageVersion: packageInfo?.version,
            registryType: packageInfo.flatMap { inferRegistryName(for: $0) } ?? packageInfo?.registryName,
            runtimeHint: packageInfo?.runtimeHint
        )

        // Extract image URL from GitHub metadata (prefer preferredImage, fallback to ownerAvatarUrl)
        let imageUrl = xGithub?.preferredImage ?? xGithub?.ownerAvatarUrl

        return RegistryServer(
            id: apiServer.name,
            name: apiServer.name,
            description: apiServer.description,
            repository: apiServer.repository?.url ?? "",
            config: finalConfig,
            metadata: metadata,
            imageUrl: imageUrl
        )
    }

    /// Resolve a server config, preferring remotes, then packages, then README extraction.
    private func resolveConfig(for apiServer: RegistryAPIServer, xGithub: GitHubMetadata?) -> ServerConfig? {
        // Try to get config from remotes first (HTTP/SSE servers)
        if let remotes = apiServer.remotes, !remotes.isEmpty,
           let config = createConfigFromRemotes(remotes) {
            #if DEBUG
            print("MCPRegistryService: Using remotes config for \(apiServer.name)")
            #endif
            return config
        }

        // Try packages if no remotes
        if let packages = apiServer.packages, !packages.isEmpty,
           let config = createConfigFromPackages(packages) {
            #if DEBUG
            print("MCPRegistryService: Using packages config for \(apiServer.name)")
            #endif
            return config
        }

        // Fall back to README extraction if no remotes or packages
        if let readme = xGithub?.readme,
           let config = extractConfigFromReadme(readme) {
            #if DEBUG
            print("MCPRegistryService: Extracted config from README for \(apiServer.name)")
            #endif
            return config
        }

        return nil
    }

    /// Clear cached servers (force refresh on next fetch)
    func clearCache() {
        cachedServers = nil
        cacheTimestamp = nil
    }

    // MARK: - Private Helpers

    /// Create config from API remotes data (HTTP/SSE servers)
    private func createConfigFromRemotes(_ remotes: [APIRemoteConfig]) -> ServerConfig? {
        for remote in remotes {
            if let config = createConfigFromRemote(remote) {
                return config
            }
        }

        return nil
    }

    /// Create config from one API remote data entry.
    private func createConfigFromRemote(_ remote: APIRemoteConfig) -> ServerConfig? {
        let url = remote.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isUsableRemoteURL(url) else { return nil }

        // Map transport type to our config format. Empty registry values are common for streamable HTTP.
        let transportType: String
        switch remote.transportType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "sse":
            transportType = "sse"
        case "", "streamable-http", "http", "https":
            transportType = "http"
        default:
            transportType = remote.transportType
        }

        let headers = headersDictionary(from: remote.headers)

        // Create config with type and url
        let config = ServerConfig(
            command: nil,
            args: nil,
            cwd: nil,
            env: nil,
            transport: nil,
            remotes: nil,
            type: transportType,
            url: url,
            headers: headers
        )

        // Validate it's a proper remote config
        guard config.isValid else { return nil }

        return config
    }

    /// Create config from API packages data (stdio servers)
    private func createConfigFromPackages(_ packages: [PackageInfo]) -> ServerConfig? {
        for package in packages {
            if let config = createConfigFromPackage(package) {
                return config
            }
        }

        return nil
    }

    /// Create config from one API package data entry.
    private func createConfigFromPackage(_ package: PackageInfo) -> ServerConfig? {
        guard let rawName = package.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty,
              let registryName = inferRegistryName(for: package) else { return nil }

        // Create config based on registry type
        let command: String
        let args: [String]

        switch registryName {
        case "npm":
            command = runtimeCommand(from: package.runtimeHint, defaultCommand: "npx")
            args = [rawName]
        case "pypi":
            command = runtimeCommand(from: package.runtimeHint, defaultCommand: "uvx")
            args = [rawName]
        case "oci":
            // Docker-based servers
            command = "docker"
            args = ["run", "-i", rawName]
        default:
            #if DEBUG
            print("MCPRegistryService: Unknown registry type: \(registryName)")
            #endif
            return nil
        }

        let config = ServerConfig(
            command: command,
            args: args,
            cwd: nil,
            env: nil,
            transport: nil,
            remotes: nil,
            type: nil,
            url: nil
        )

        // Validate it's a proper stdio config
        guard config.isValid else { return nil }

        return config
    }

    private func runtimeCommand(from runtimeHint: String?, defaultCommand: String) -> String {
        guard let command = runtimeHint?.trimmingCharacters(in: .whitespacesAndNewlines),
              !command.isEmpty else {
            return defaultCommand
        }

        return command
    }

    private func inferRegistryName(for package: PackageInfo) -> String? {
        if let registryName = package.registryName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !registryName.isEmpty {
            return registryName
        }

        let registryBaseURL = package.registryBaseUrl?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let registryBaseURL, !registryBaseURL.isEmpty {
            if registryBaseURL.contains("npmjs") {
                return "npm"
            }

            if registryBaseURL.contains("pypi") || registryBaseURL.contains("pythonhosted") {
                return "pypi"
            }

            if registryBaseURL.contains("docker") || registryBaseURL.contains("ghcr.io") || registryBaseURL.contains("quay.io") {
                return "oci"
            }
        }

        let runtimeHint = package.runtimeHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch runtimeHint {
        case "npx", "npm", "node", "yarn", "pnpm":
            return "npm"
        case "uvx", "uv", "python", "python3", "pip", "pipx":
            return "pypi"
        case "docker", "podman":
            return "oci"
        default:
            break
        }

        guard let name = package.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }

        if name.hasPrefix("@") {
            return "npm"
        }

        if name.contains("/") || name.contains(":") {
            return "oci"
        }

        return nil
    }

    private func headersDictionary(from apiHeaders: [APIHeader]?) -> [String: String]? {
        guard let apiHeaders, !apiHeaders.isEmpty else { return nil }

        var headers: [String: String] = [:]
        for header in apiHeaders {
            guard let name = header.headerName, let value = header.headerValue else { continue }
            headers[name] = value
        }

        return headers.isEmpty ? nil : headers
    }

    /// Extract MCP config from README markdown
    private func extractConfigFromReadme(_ readme: String) -> ServerConfig? {
        // Prevent ReDoS attacks by validating README size
        guard readme.count < 1_000_000 else {
            #if DEBUG
            print("MCPRegistryService: README too large (\(readme.count) chars), skipping regex")
            #endif
            return nil
        }

        let jsonBlocks = extractJSONBlocks(from: readme)

        for block in jsonBlocks {
            if let config = parseConfigBlock(block) {
                return config
            }
        }

        return nil
    }

    /// Extract JSON code blocks from markdown
    /// Note: Runs on background thread to avoid blocking UI with regex operations
    private nonisolated func extractJSONBlocks(from markdown: String) -> [String] {
        var blocks: [String] = []

        let fullRange = NSRange(markdown.startIndex..., in: markdown)

        // Pattern 1: ```json\n...\n```
        let matches1 = Self.jsonBlockRegex?.matches(in: markdown, range: fullRange) ?? []
        for match in matches1 {
            if let range = Range(match.range(at: 1), in: markdown) {
                blocks.append(String(markdown[range]))
            }
        }

        // Pattern 2: ```\n{...}\n```
        let matches2 = Self.codeBlockRegex?.matches(in: markdown, range: fullRange) ?? []
        for match in matches2 {
            if let range = Range(match.range(at: 1), in: markdown) {
                blocks.append(String(markdown[range]))
            }
        }

        // Pattern 3: Inline JSON with server name (e.g., "server-name": { ... })
        // This catches configs like command-based stdio and URL-based remote configs.
        let matches3 = Self.inlineRegex?.matches(in: markdown, range: fullRange) ?? []
        for match in matches3 {
            if let range = Range(match.range, in: markdown) {
                let jsonStr = String(markdown[range])
                // Try to find the complete JSON object (handle nested braces)
                if let completeJson = extractCompleteJSON(from: markdown, startingAt: range.lowerBound) {
                    blocks.append(completeJson)
                } else {
                    // Fallback: wrap in braces to make it valid JSON
                    blocks.append("{\(jsonStr)}")
                }
            }
        }

        return blocks
    }

    /// Extract a complete JSON object with proper brace matching
    private nonisolated func extractCompleteJSON(from text: String, startingAt: String.Index) -> String? {
        var depth = 0
        var startIndex: String.Index?
        var endIndex: String.Index?
        var inString = false
        var escapeNext = false

        var currentIndex = startingAt

        while currentIndex < text.endIndex {
            let char = text[currentIndex]

            if escapeNext {
                escapeNext = false
                currentIndex = text.index(after: currentIndex)
                continue
            }

            if char == "\\" {
                escapeNext = true
                currentIndex = text.index(after: currentIndex)
                continue
            }

            if char == "\"" {
                inString.toggle()
                currentIndex = text.index(after: currentIndex)
                continue
            }

            if !inString {
                if char == "{" {
                    if startIndex == nil {
                        startIndex = currentIndex
                    }
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 && startIndex != nil {
                        endIndex = text.index(after: currentIndex)
                        break
                    }
                }
            }

            currentIndex = text.index(after: currentIndex)
        }

        if let start = startIndex, let end = endIndex {
            return String(text[start..<end])
        }

        return nil
    }

    /// Try to parse a JSON block as an MCP config
    private nonisolated func parseConfigBlock(_ jsonString: String) -> ServerConfig? {
        guard let data = jsonString.data(using: .utf8) else { return nil }

        // Try to decode as JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Check if it's an mcpServers wrapper
        if let mcpServers = json["mcpServers"] as? [String: Any] {
            #if DEBUG
            if mcpServers.count > 1 {
                print("MCPRegistryService: Found \(mcpServers.count) servers in mcpServers wrapper, trying all")
            }
            #endif

            // Try all servers in the wrapper, return first valid config
            for (_, serverValue) in mcpServers {
                if let serverDict = serverValue as? [String: Any],
                   let config = parseServerConfig(serverDict) {
                    return config
                }
            }
        }

        // Check if it's a direct server config
        if Self.looksLikeServerConfig(json) {
            return parseServerConfig(json)
        }

        // Check if it's a nested structure
        for value in json.values {
            if let serverDict = value as? [String: Any],
               Self.looksLikeServerConfig(serverDict) {
                return parseServerConfig(serverDict)
            }
        }

        return nil
    }

    /// Parse a server config dictionary into ServerConfig
    private nonisolated func parseServerConfig(_ dict: [String: Any]) -> ServerConfig? {
        guard let configData = try? JSONSerialization.data(withJSONObject: dict),
              let config = try? JSONDecoder().decode(ServerConfig.self, from: configData),
              config.isValid,
              !Self.hasPlaceholderRemoteURL(config) else {
            return nil
        }

        return config
    }

    private nonisolated static func looksLikeServerConfig(_ dict: [String: Any]) -> Bool {
        let keys = ["command", "args", "httpUrl", "transport", "remotes", "type", "url"]
        return keys.contains { dict[$0] != nil }
    }

    private nonisolated static func hasPlaceholderRemoteURL(_ config: ServerConfig) -> Bool {
        if let url = config.url, !isUsableRemoteURL(url) {
            return true
        }

        if let httpUrl = config.httpUrl, !isUsableRemoteURL(httpUrl) {
            return true
        }

        if let transportURL = config.transport?.url, !isUsableRemoteURL(transportURL) {
            return true
        }

        if let remotes = config.remotes,
           remotes.contains(where: { !isUsableRemoteURL($0.url) }) {
            return true
        }

        return false
    }

    private nonisolated static func isUsableRemoteURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lowercase = trimmed.lowercased()
        let placeholderFragments = ["<", ">", "{", "}", "$", "example.com", "your-", "your_", "localhost", "127.0.0.1", "0.0.0.0"]
        guard !placeholderFragments.contains(where: { lowercase.contains($0) }) else {
            return false
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host,
              !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        return true
    }
}

// MARK: - Errors

enum MCPRegistryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid registry URL"
        case .invalidResponse:
            return "Invalid response from registry"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
