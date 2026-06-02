import SwiftUI
import CoreText

/// Manages custom font registration for the app
/// Call FontManager.registerFonts() at app startup to load Poppins and Crimson Pro
enum FontManager {

    /// Register all custom fonts from the Resources/Fonts directory
    static func registerFonts() {
        let fontNames = [
            "Poppins-Regular.ttf",
            "Poppins-Medium.ttf",
            "Poppins-SemiBold.ttf",
            "Poppins-Bold.ttf",
            "CrimsonPro-Regular.ttf",
            "CrimsonPro-Variable.ttf"
        ]

        for fontName in fontNames {
            registerFont(filename: fontName)
        }
    }

    /// Cached resource bundle to avoid repeated lookups
    private static let resourceBundle: Bundle? = {
        // Try to find the SPM resource bundle safely (without using Bundle.module which crashes)
        let bundleName = "MCPServerManager_MCPServerManager"

        // 1. Look in main bundle's Resources directory
        if let resourceURL = Bundle.main.resourceURL {
            let bundleURL = resourceURL.appendingPathComponent("\(bundleName).bundle")
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }

            // 2. Search Resources directory for any matching bundle
            if let contents = try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) {
                for url in contents where url.lastPathComponent.contains(bundleName) {
                    if let bundle = Bundle(url: url) {
                        return bundle
                    }
                }
            }
        }

        // 3. Look relative to executable (for development/debug builds)
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

    /// Register a single font file
    private static func registerFont(filename: String) {
        let fontName = filename.replacingOccurrences(of: ".ttf", with: "")
        var fontURL: URL?

        // 1. Try cached resource bundle (safe - won't crash if not found)
        if let url = resourceBundle?.url(forResource: fontName, withExtension: "ttf") {
            fontURL = url
        }
        // 2. Try Bundle.main (App Bundle root resources)
        else if let url = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
            fontURL = url
        }
        // 3. Try fonts subdirectory in main bundle
        else if let url = Bundle.main.url(forResource: fontName, withExtension: "ttf", subdirectory: "Fonts") {
            fontURL = url
        }

        guard let foundURL = fontURL else {
            #if DEBUG
            print("⚠️ Could not find font file: \(filename)")
            print("   Bundle path: \(Bundle.main.bundlePath)")
            if let resourceURL = Bundle.main.resourceURL {
                print("   Resource URL: \(resourceURL.path)")
            }
            #endif
            return
        }

        registerFontFromURL(foundURL, filename: filename)
    }

    /// Register font from URL
    private static func registerFontFromURL(_ url: URL, filename: String) {
        var error: Unmanaged<CFError>?

        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            if let error = error?.takeRetainedValue() {
                // kCTFontManagerErrorAlreadyRegistered = 105
                let nsError = error as Error as NSError
                #if DEBUG
                if nsError.code != 105 {
                    print("Failed to register font \(filename): \(error)")
                }
                #endif
            }
            return
        }
    }
}
