import AppKit
import Foundation

/// Installs the bundled `mcp-panel` command-line tool onto the user's PATH by
/// symlinking it into `~/.local/bin`. The binary is embedded in the app bundle
/// by the DMG build; symlinking (rather than copying) means a Sparkle update to
/// the app keeps the CLI current automatically.
///
/// Only meaningful in direct-download (DMG) builds — the sandboxed App Store
/// build neither ships the binary nor can write outside its container, so the
/// menu command that calls this is hidden when `isAvailable` is false.
enum CLIInstaller {
    private static var installDirectory: String {
        "\(NSHomeDirectory())/.local/bin"
    }

    private static var installPath: String {
        "\(installDirectory)/mcp-panel"
    }

    /// Path to the `mcp-panel` binary embedded in the app bundle, if present.
    static var bundledBinaryPath: String? {
        let fileManager = FileManager.default

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            let candidate = executableDirectory.appendingPathComponent("mcp-panel").path
            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
        }

        if let resource = Bundle.main.resourceURL?.appendingPathComponent("mcp-panel").path,
           fileManager.fileExists(atPath: resource) {
            return resource
        }

        return nil
    }

    /// Whether this build ships the CLI (true for DMG builds, false on the App Store).
    static var isAvailable: Bool {
        bundledBinaryPath != nil
    }

    private static let unavailableMessage = """
    This build doesn't include the mcp-panel binary. Use the \
    direct-download (DMG) build, or build it from source.
    """

    private static let successMessage = """
    Linked mcp-panel into ~/.local/bin.

    If your shell can't find it yet, add this line to your shell profile \
    (~/.zshrc or ~/.bash_profile) and restart your terminal:

    export PATH="$HOME/.local/bin:$PATH"
    """

    /// Symlink the bundled CLI into `~/.local/bin`, replacing any existing entry.
    @MainActor
    static func install() {
        guard let source = bundledBinaryPath else {
            showAlert(style: .warning, title: "Command-Line Tool Unavailable", message: unavailableMessage)
            return
        }

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(atPath: installDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: installPath) {
                try fileManager.removeItem(atPath: installPath)
            }
            try fileManager.createSymbolicLink(atPath: installPath, withDestinationPath: source)
        } catch {
            showAlert(style: .warning, title: "Installation Failed", message: error.localizedDescription)
            return
        }

        showAlert(style: .informational, title: "Command-Line Tool Installed", message: successMessage)
    }

    @MainActor
    private static func showAlert(style: NSAlert.Style, title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
