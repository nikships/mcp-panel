import Foundation

/// Manages security-scoped bookmarks for persistent file access under App Sandbox
class BookmarkManager {
    static let shared = BookmarkManager()

    private init() {}

    // Use App Groups UserDefaults so widget can access bookmarks
    private let suiteName = "group.com.anand-92.mcp-panel"
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static func bookmarkKey(for path: String) -> String {
            return "bookmark_\(path.replacingOccurrences(of: "~", with: "home"))"
        }
    }

    private enum BookmarkStore {
        case shared
        case standard
    }

    private func bookmarkData(forKey key: String, from store: BookmarkStore) -> Data? {
        switch store {
        case .shared:
            return sharedDefaults?.data(forKey: key)
        case .standard:
            return UserDefaults.standard.data(forKey: key)
        }
    }

    private func removeBookmarkData(forKey key: String, from store: BookmarkStore) {
        switch store {
        case .shared:
            sharedDefaults?.removeObject(forKey: key)
            sharedDefaults?.synchronize()
        case .standard:
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Bookmark Operations

    /// Stores a security-scoped bookmark for the given URL
    func storeBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let key = Keys.bookmarkKey(for: url.path)

        // Store in both standard and shared defaults for migration
        UserDefaults.standard.set(bookmarkData, forKey: key)
        sharedDefaults?.set(bookmarkData, forKey: key)
        sharedDefaults?.synchronize()
    }

    /// Resolves a bookmark for the given path and returns the URL
    /// Returns nil if no bookmark exists or resolution fails
    func resolveBookmark(for path: String) -> URL? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let key = Keys.bookmarkKey(for: expandedPath)

        for store in [BookmarkStore.shared, BookmarkStore.standard] {
            guard let bookmarkData = bookmarkData(forKey: key, from: store) else {
                continue
            }

            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    try? url.withSecurityScopedAccess { url in
                        try storeBookmark(for: url)
                    }
                }

                // If we resolved from standard defaults, migrate to shared defaults.
                if store == .standard {
                    sharedDefaults?.set(bookmarkData, forKey: key)
                    sharedDefaults?.synchronize()
                }

                return url
            } catch {
                removeBookmarkData(forKey: key, from: store)
            }
        }

        return nil
    }

    /// Removes a stored bookmark for the given path
    func removeBookmark(for path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let key = Keys.bookmarkKey(for: expandedPath)
        removeBookmarkData(forKey: key, from: .standard)
        removeBookmarkData(forKey: key, from: .shared)
    }

    /// Checks if a bookmark exists for the given path
    func hasBookmark(for path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let key = Keys.bookmarkKey(for: expandedPath)
        return UserDefaults.standard.data(forKey: key) != nil || sharedDefaults?.data(forKey: key) != nil
    }

    /// Clears all stored bookmarks
    func clearAllBookmarks() {
        let standardDefaults = UserDefaults.standard
        let standardKeys = standardDefaults.dictionaryRepresentation().keys

        for key in standardKeys where key.hasPrefix("bookmark_") {
            standardDefaults.removeObject(forKey: key)
        }

        if let sharedDefaults {
            let sharedKeys = sharedDefaults.dictionaryRepresentation().keys
            for key in sharedKeys where key.hasPrefix("bookmark_") {
                sharedDefaults.removeObject(forKey: key)
            }
            sharedDefaults.synchronize()
        }
    }
}

// MARK: - Security-Scoped Resource Helper

extension URL {
    /// Executes a closure with security-scoped access to this URL
    func withSecurityScopedAccess<T>(_ closure: (URL) throws -> T) throws -> T {
        let accessing = startAccessingSecurityScopedResource()
        defer {
            if accessing {
                stopAccessingSecurityScopedResource()
            }
        }
        return try closure(self)
    }
}
