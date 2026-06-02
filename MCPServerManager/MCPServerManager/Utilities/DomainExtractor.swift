import Foundation

/// Utility for extracting domains from server configurations
struct DomainExtractor {

    /// Extract a domain from server name and config
    static func extractDomain(from serverName: String, config: ServerConfig) -> String? {
        // 1. Try to extract from command + args (most common: npx, uvx, docker)
        if let command = config.command, let args = config.args,
           let domain = extractFromCommandAndArgs(command: command, args: args) {
            return domain
        }

        // 2. Try to extract from explicit URL in config (http transport)
        if let url = config.url, let domain = extractFromURL(url) {
            return domain
        }

        // 3. Try to extract from transport URL
        if let transportURL = config.transport?.url, let domain = extractFromURL(transportURL) {
            return domain
        }

        // 4. Try to extract from remotes
        if let remoteURL = config.remotes?.first?.url, let domain = extractFromURL(remoteURL) {
            return domain
        }

        // 5. Try to extract from server name itself
        if let domain = extractFromServerName(serverName) {
            return domain
        }

        // 6. Return nil if nothing found
        return nil
    }

    // MARK: - Private Helpers

    /// Extract domain from command and arguments
    private static func extractFromCommandAndArgs(command: String, args: [String]) -> String? {
        let lowerCommand = command.lowercased()

        // Handle npx/uvx/pnpm/bun commands (npm ecosystem)
        if ["npx", "uvx", "pnpm", "bunx", "yarn"].contains(lowerCommand) {
            // Look for package name in args
            for arg in args {
                // Skip flags
                if arg.hasPrefix("-") {
                    continue
                }

                // Parse package names:
                // - chrome-devtools-mcp@latest → chrome-devtools-mcp
                // - @modelcontextprotocol/server-github → server-github
                // - mcp-server-slack → server-slack
                if let domain = extractFromPackageName(arg) {
                    return domain
                }
            }
        }

        // Handle docker commands
        if lowerCommand == "docker" {
            // Look for image name in args (usually after 'run')
            for arg in args {
                // Skip flags and their values
                if arg.hasPrefix("-") {
                    continue
                }

                // Image names often come after flags
                // Examples:
                // - ghcr.io/github/github-mcp-server → github
                // - ghcr.io/sooperset/mcp-atlassian:latest → atlassian
                if arg.contains("/"), let domain = extractFromDockerImage(arg) {
                    return domain
                }
            }
        }

        // Handle direct command names (e.g., postgres-mcp, filesystem-mcp)
        if lowerCommand.contains("mcp") || lowerCommand.contains("-server"),
           let domain = extractFromPackageName(lowerCommand) {
            return domain
        }

        return nil
    }

    /// Extract domain from Docker image name
    private static func extractFromDockerImage(_ imageName: String) -> String? {
        // Examples:
        // ghcr.io/github/github-mcp-server → github
        // ghcr.io/sooperset/mcp-atlassian:latest → atlassian

        // Remove tag if present
        let nameWithoutTag = imageName.split(separator: ":").first.map(String.init) ?? imageName

        // Split by / and get the last part
        let components = nameWithoutTag.split(separator: "/")

        if components.count >= 2 {
            // Get the organization name (second to last component)
            let org = String(components[components.count - 2]).lowercased()

            // Also check the image name (last component)
            let lastComponent = String(components.last ?? "").lowercased()

            // Try to extract from image name first (e.g., "mcp-atlassian" → atlassian)
            if let domain = extractFromPackageName(lastComponent) {
                return domain
            }

            // Fallback to organization name
            if let domain = extractFromPackageName(org) {
                return domain
            }
        }

        return nil
    }

    /// Extract domain from package/binary name
    private static func extractFromPackageName(_ packageName: String) -> String? {
        // Remove common prefixes and suffixes
        let cleaned = packageName
            .replacingOccurrences(of: "@latest", with: "")
            .replacingOccurrences(of: "@modelcontextprotocol/", with: "")
            .replacingOccurrences(of: "mcp-server-", with: "")
            .replacingOccurrences(of: "server-", with: "")
            .replacingOccurrences(of: "-mcp", with: "")
            .replacingOccurrences(of: "mcp-", with: "")
            .lowercased()

        // Common name-to-domain mappings
        let domainMappings: [String: String] = [
            "chrome": "google.com",
            "chrome-devtools": "google.com",
            "github": "github.com",
            "gitlab": "gitlab.com",
            "atlassian": "atlassian.com",
            "confluence": "atlassian.com",
            "jira": "atlassian.com",
            "slack": "slack.com",
            "postgres": "postgresql.org",
            "postgresql": "postgresql.org",
            "brave": "brave.com",
            "puppeteer": "pptr.dev",
            "playwright": "playwright.dev",
            "sqlite": "sqlite.org",
            "mysql": "mysql.com",
            "mongodb": "mongodb.com",
            "redis": "redis.io",
            "docker": "docker.com",
            "kubernetes": "kubernetes.io",
            "aws": "aws.amazon.com",
            "gcp": "cloud.google.com",
            "azure": "azure.microsoft.com",
            "google": "google.com",
            "anthropic": "anthropic.com",
            "openai": "openai.com",
            "sentry": "sentry.io",
            "raycast": "raycast.com",
            "linear": "linear.app",
            "notion": "notion.so",
            "everart": "everart.com",
            "filesystem": "finder.com", // Placeholder for file system
            "memory": "apple.com",
            "fetch": "apple.com"
        ]

        // Try exact match first
        if let domain = domainMappings[cleaned] {
            return domain
        }

        // Try partial matches
        for (key, domain) in domainMappings where cleaned.contains(key) {
            return domain
        }

        return nil
    }

    /// Extract domain from a URL string
    private static func extractFromURL(_ urlString: String) -> String? {
        // Handle http/https URLs
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }

        // Remove www. prefix if present
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }

        return host
    }

    /// Extract domain from server name
    private static func extractFromServerName(_ serverName: String) -> String? {
        let lowerName = serverName.lowercased()

        // Direct name-to-domain mappings for common servers
        let nameMappings: [String: String] = [
            "github": "github.com",
            "gitlab": "gitlab.com",
            "slack": "slack.com",
            "postgres": "postgresql.org",
            "postgresql": "postgresql.org",
            "brave": "brave.com",
            "chrome": "google.com",
            "chromium": "chromium.org",
            "firefox": "firefox.com",
            "puppeteer": "pptr.dev",
            "playwright": "playwright.dev",
            "sqlite": "sqlite.org",
            "mysql": "mysql.com",
            "mongodb": "mongodb.com",
            "redis": "redis.io",
            "docker": "docker.com",
            "kubernetes": "kubernetes.io",
            "aws": "aws.amazon.com",
            "gcp": "cloud.google.com",
            "azure": "azure.microsoft.com",
            "google": "google.com",
            "anthropic": "anthropic.com",
            "openai": "openai.com",
            "sentry": "sentry.io",
            "raycast": "raycast.com",
            "linear": "linear.app",
            "notion": "notion.so",
            "everart": "everart.com",
            "x": "x.com",
            "twitter": "x.com"
        ]

        // Try exact match first
        if let domain = nameMappings[lowerName] {
            return domain
        }

        // Try partial matches (e.g., "github-mcp" matches "github")
        for (key, domain) in nameMappings where lowerName.contains(key) {
            return domain
        }

        // Check if the name itself looks like a domain
        if lowerName.contains(".com") || lowerName.contains(".io") || lowerName.contains(".dev"),
           let domain = extractFromURL("https://\(serverName)") {
            return domain
        }

        return nil
    }
}
