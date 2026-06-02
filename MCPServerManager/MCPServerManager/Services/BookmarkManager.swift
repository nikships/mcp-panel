import Foundation

/// Manages security-scoped bookmarks for persistent file access under App Sandbox
class BookmarkManager {
    static let shared = BookmarkManager()

    private init() {}

    // MARK: - UserDefaults Keys

    private enum Keys {
        static func bookmarkKey(for path: String) -> String {
            return "bookmark_\(path.replacingOccurrences(of: "~", with: "home"))"
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
        UserDefaults.standard.set(bookmarkData, forKey: key)
    }

    /// Resolves a bookmark for the given path and returns the URL
    /// Returns nil if no bookmark exists or resolution fails
    func resolveBookmark(for path: String) -> URL? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let key = Keys.bookmarkKey(for: expandedPath)

        guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
            return nil
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

            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    /// Removes a stored bookmark for the given path
    func removeBookmark(for path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let key = Keys.bookmarkKey(for: expandedPath)
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Checks if a bookmark exists for the given path
    func hasBookmark(for path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let key = Keys.bookmarkKey(for: expandedPath)
        return UserDefaults.standard.data(forKey: key) != nil
    }

    /// Clears all stored bookmarks
    func clearAllBookmarks() {
        let standardDefaults = UserDefaults.standard
        let standardKeys = standardDefaults.dictionaryRepresentation().keys

        for key in standardKeys where key.hasPrefix("bookmark_") {
            standardDefaults.removeObject(forKey: key)
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
