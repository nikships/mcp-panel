import Foundation
import SwiftUI
import AppKit

/// Service for fetching and caching server logos/icons
@MainActor
class IconService: ObservableObject {
    static let shared = IconService()

    private let cacheDirectory: URL
    private let bundledLogos: [String: String] = [
        "chrome": "chrome-logo",
        "github": "github-logo",
        "gitlab": "gitlab-logo",
        "slack": "slack-logo",
        "postgres": "postgres-logo",
        "postgresql": "postgres-logo",
        "filesystem": "filesystem-logo",
        "brave": "brave-logo",
        "puppeteer": "puppeteer-logo",
        "playwright": "playwright-logo",
        "sqlite": "sqlite-logo",
        "mysql": "mysql-logo",
        "mongodb": "mongodb-logo",
        "redis": "redis-logo",
        "docker": "docker-logo",
        "kubernetes": "kubernetes-logo",
        "aws": "aws-logo",
        "gcp": "gcp-logo",
        "azure": "azure-logo",
        "anthropic": "anthropic-logo",
        "openai": "openai-logo",
        "google": "google-logo",
        "fetch": "fetch-logo",
        "memory": "memory-logo",
        "sequential-thinking": "sequential-thinking-logo",
        "everart": "everart-logo",
        "sentry": "sentry-logo",
        "raycast": "raycast-logo",
        "linear": "linear-logo",
        "notion": "notion-logo"
    ]

    private init() {
        // Setup cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cacheDir.appendingPathComponent("MCPServerManager/ServerLogos", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Load icon for a server with automatic fallback chain
    func loadIcon(for serverName: String, domain: String?) async -> NSImage? {
        // 1. Check bundled assets first (instant)
        if let bundledIcon = loadBundledIcon(for: serverName) {
            return bundledIcon
        }

        // 2. Check if we have it cached
        if let domain = domain, let cachedIcon = loadCachedIcon(for: domain) {
            return cachedIcon
        }

        // 3. Fetch from remote if enabled
        if UserDefaults.standard.bool(forKey: "fetchServerLogos"), let domain,
           let remoteIcon = await fetchRemoteIcon(for: domain) {
            cacheIcon(remoteIcon, for: domain)
            return remoteIcon
        }

        // 4. Fallback to nil (caller will show SF Symbol)
        return nil
    }

    /// Get SF Symbol fallback icon name based on server name
    func getFallbackSymbol(for serverName: String) -> String {
        let lowerName = serverName.lowercased()

        // Keyword matching for common patterns
        if lowerName.contains("chrome") || lowerName.contains("browser") {
            return "globe"
        } else if lowerName.contains("github") || lowerName.contains("gitlab") || lowerName.contains("git") {
            return "chevron.left.forwardslash.chevron.right"
        } else if lowerName.contains("slack") || lowerName.contains("discord") || lowerName.contains("message") {
            return "message.fill"
        } else if lowerName.contains("database") || lowerName.contains("postgres")
                    || lowerName.contains("mysql") || lowerName.contains("sql") {
            return "cylinder.fill"
        } else if lowerName.contains("filesystem") || lowerName.contains("file") {
            return "folder.fill"
        } else if lowerName.contains("memory") || lowerName.contains("cache") {
            return "memorychip.fill"
        } else if lowerName.contains("fetch") || lowerName.contains("http") {
            return "arrow.down.circle.fill"
        } else if lowerName.contains("sequential") || lowerName.contains("thinking") {
            return "brain.head.profile"
        } else if lowerName.contains("docker") || lowerName.contains("container") {
            return "shippingbox.fill"
        } else if lowerName.contains("kubernetes") || lowerName.contains("k8s") {
            return "network"
        } else if lowerName.contains("cloud") || lowerName.contains("aws") || lowerName.contains("gcp") || lowerName.contains("azure") {
            return "cloud.fill"
        } else if lowerName.contains("api") {
            return "arrow.left.arrow.right"
        } else if lowerName.contains("search") {
            return "magnifyingglass"
        } else if lowerName.contains("honeycomb") {
            return "hexagon.fill"
        } else if lowerName.contains("x-") || lowerName == "x" {
            return "xmark"
        } else {
            return "server.rack"
        }
    }

    // MARK: - Private Helpers

    private func loadBundledIcon(for serverName: String) -> NSImage? {
        let lowerName = serverName.lowercased()

        // Try exact match first
        if let assetName = bundledLogos[lowerName], let image = NSImage(named: assetName) {
            return image
        }

        // Try partial matches
        for (key, assetName) in bundledLogos where lowerName.contains(key) {
            if let image = NSImage(named: assetName) {
                return image
            }
        }

        return nil
    }

    private func loadCachedIcon(for domain: String) -> NSImage? {
        let cacheURL = cacheDirectory.appendingPathComponent("\(domain).png")
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        return NSImage(contentsOf: cacheURL)
    }

    private func cacheIcon(_ image: NSImage, for domain: String) {
        let cacheURL = cacheDirectory.appendingPathComponent("\(domain).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }

        try? pngData.write(to: cacheURL)
    }

    private func fetchRemoteIcon(for domain: String) async -> NSImage? {
        // Try domain variations (.com, .dev, .io, .ai, .app)
        let variations = generateDomainVariations(domain)

        for testDomain in variations {
            // Only accept icons that meet the quality threshold.
            if let icon = await fetchBestIcon(for: testDomain), scoreIcon(icon) > 100 {
                return icon
            }
        }

        return nil
    }

    /// Generate domain variations to try
    private func generateDomainVariations(_ domain: String) -> [String] {
        // If already has TLD, return as-is
        if domain.contains(".") {
            return [domain]
        }

        // Try common TLDs
        return [
            "\(domain).com",
            "\(domain).dev",
            "\(domain).io",
            "\(domain).ai",
            "\(domain).app",
            "\(domain).org"
        ]
    }

    /// Fetch icon from multiple sources in parallel and pick the best quality
    private func fetchBestIcon(for domain: String) async -> NSImage? {
        // Fire all requests simultaneously (~200-400ms total)
        async let clearbit = fetchImageData(from: "https://logo.clearbit.com/\(domain)")
        async let iconHorse = fetchImageData(from: "https://icon.horse/icon/\(domain)")
        async let duckduckgo = fetchImageData(from: "https://icons.duckduckgo.com/ip3/\(domain).ico")
        async let google = fetchImageData(from: "https://www.google.com/s2/favicons?sz=128&domain=\(domain)")

        let dataResults = await [clearbit, iconHorse, duckduckgo, google]

        // Convert data to images and filter out nil and tiny icons, then pick highest quality
        let images = dataResults.compactMap { data -> NSImage? in
            guard let data = data else { return nil }
            return NSImage(data: data)
        }

        return images
            .filter { $0.size.width >= 64 || $0.size.height >= 64 } // Skip tiny icons
            .max { scoreIcon($0) < scoreIcon($1) }
    }

    /// Score an icon's quality (higher = better)
    private func scoreIcon(_ image: NSImage) -> Int {
        var score = 0

        // Resolution score (bigger = better, up to a point)
        let maxDimension = max(image.size.width, image.size.height)
        score += Int(min(maxDimension, 512)) // Cap at 512 to avoid preferring huge images

        // Check for transparency (professional logos usually have it)
        if imageHasTransparency(image) {
            score += 100
        }

        // Check if it's a vector (PDF representation)
        if image.representations.contains(where: { $0 is NSPDFImageRep }) {
            score += 200
        }

        // Check if it's a bitmap with good quality
        if let bitmapRep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            // Prefer higher bit depth
            score += bitmapRep.bitsPerPixel
        }

        return score
    }

    /// Check if image has transparency
    private func imageHasTransparency(_ image: NSImage) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        return bitmapRep.hasAlpha
    }

    /// Fetch image data from URL (nonisolated for parallel execution)
    nonisolated private func fetchImageData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    /// Clear all cached icons
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
