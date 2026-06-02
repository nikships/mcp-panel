import SwiftUI
import CoreText

/// Manages custom font registration for the app
/// Call FontManager.registerFonts() at app startup to load Poppins and Crimson Pro.
///
/// Fonts are discovered by recursively scanning every candidate bundle for `.ttf`/`.otf`
/// files, rather than probing for specific paths. This keeps registration working
/// regardless of how the resources were laid out by the build path — `swift build`
/// (SPM resource bundle) and `xcodebuild` (flattened into `Contents/Resources`) place
/// font files in different locations, which previously caused silent fallbacks to the
/// system font in some builds.
enum FontManager {

    private static let fontExtensions: Set<String> = ["ttf", "otf"]

    /// Register all custom fonts found in any of the app's resource locations.
    static func registerFonts() {
        var registered = Set<String>()

        for url in discoverFontURLs() {
            // Avoid registering the same file twice if it appears in multiple bundles.
            let key = url.lastPathComponent.lowercased()
            guard !registered.contains(key) else { continue }
            registered.insert(key)
            registerFontFromURL(url)
        }

        #if DEBUG
        if registered.isEmpty {
            print("⚠️ FontManager: no font files found in any bundle.")
            print("   Bundle path: \(Bundle.main.bundlePath)")
            if let resourceURL = Bundle.main.resourceURL {
                print("   Resource URL: \(resourceURL.path)")
            }
        }
        #endif
    }

    /// Collect every `.ttf`/`.otf` URL across all candidate bundle locations.
    private static func discoverFontURLs() -> [URL] {
        var roots: [URL] = []

        // SPM resource bundle (present in `swift build` output / Transporter path).
        if let spmBundle = resourceBundle, let url = spmBundle.resourceURL ?? Optional(spmBundle.bundleURL) {
            roots.append(url)
        }
        // Main bundle Resources (present in xcodebuild output / workflow path).
        if let resourceURL = Bundle.main.resourceURL {
            roots.append(resourceURL)
        }
        // The app bundle itself, as a final catch-all.
        roots.append(Bundle.main.bundleURL)

        var urls: [URL] = []
        var seenRoots = Set<String>()
        for root in roots {
            let standardized = root.standardizedFileURL.path
            guard !seenRoots.contains(standardized) else { continue }
            seenRoots.insert(standardized)
            urls.append(contentsOf: fontFiles(in: root))
        }
        return urls
    }

    /// Recursively enumerate font files under a directory.
    private static func fontFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var found: [URL] = []
        for case let url as URL in enumerator
        where fontExtensions.contains(url.pathExtension.lowercased()) {
            found.append(url)
        }
        return found
    }

    /// Cached SPM resource bundle (looked up without `Bundle.module`, which would crash if absent).
    private static let resourceBundle: Bundle? = {
        let bundleName = "MCPServerManager_MCPServerManager"

        if let resourceURL = Bundle.main.resourceURL {
            let bundleURL = resourceURL.appendingPathComponent("\(bundleName).bundle")
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }

            if let contents = try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) {
                for url in contents where url.lastPathComponent.contains(bundleName) {
                    if let bundle = Bundle(url: url) {
                        return bundle
                    }
                }
            }
        }

        let executableURL = Bundle.main.bundleURL
        let possiblePaths = [
            executableURL.appendingPathComponent("Contents/Resources/\(bundleName).bundle"),
            executableURL.appendingPathComponent("Resources/\(bundleName).bundle"),
            executableURL.appendingPathComponent("\(bundleName).bundle")
        ]

        for path in possiblePaths {
            if let bundle = Bundle(url: path) {
                return bundle
            }
        }

        return nil
    }()

    /// Register font from URL
    private static func registerFontFromURL(_ url: URL) {
        var error: Unmanaged<CFError>?

        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            if let error = error?.takeRetainedValue() {
                // kCTFontManagerErrorAlreadyRegistered = 105
                let nsError = error as Error as NSError
                #if DEBUG
                if nsError.code != 105 {
                    print("Failed to register font \(url.lastPathComponent): \(error)")
                }
                #endif
            }
            return
        }
    }
}
