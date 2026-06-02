import SwiftUI
import ServiceManagement
#if canImport(Sparkle)
import Sparkle
#endif

@main
struct MCPServerManagerApp: App {
    static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updateChecker = UpdateChecker.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // A single Window (not WindowGroup) so the window can be reliably reopened
        // from the menu bar after it's closed (WindowGroup destroys the window on close).
        Window("MCP Panel", id: MCPServerManagerApp.mainWindowID) {
            ContentView()
                .environmentObject(appDelegate)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Give the AppKit menu-bar controller a way to reopen this window.
                    appDelegate.openMainWindow = { openWindow(id: MCPServerManagerApp.mainWindowID) }
                    // Ensure window accepts keyboard input
                    NSApp.activate(ignoringOtherApps: true)
                }
                .task {
                    // Apply Liquid Glass to window background (with slight delay to ensure window is ready)
                    try? await Task.sleep(for: .milliseconds(100))
                    await MainActor.run {
                        if let window = NSApp.windows.first {
                            if #available(macOS 26.0, *) {
                                window.isOpaque = false
                                window.backgroundColor = .clear
                                window.titlebarAppearsTransparent = true
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // Only show "Check for Updates" for non-App Store builds
            if updateChecker.canCheckForUpdates {
                CommandGroup(after: .appInfo) {
                    Button("Check for Updates...") {
                        updateChecker.checkForUpdates()
                    }
                    .keyboardShortcut("U", modifiers: [.command])
                }
            }

            // Window menu to reopen the main window (Apple Review requirement)
            CommandGroup(after: .windowArrangement) {
                Button("MCP Panel") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var menuBarController: MenuBarController?

    /// Set by the SwiftUI scene; opens (and re-creates if needed) the main window.
    var openMainWindow: (() -> Void)?

    /// Bring the main window to front, re-creating it if it was closed.
    @MainActor
    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Reuse an existing main window if one is still around.
        if let window = NSApp.windows.first(where: { window in
            window.className != "NSStatusBarWindow" && !(window is MenuBarPanel)
        }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            // Window was closed/destroyed: ask SwiftUI to open a fresh one.
            openMainWindow?()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register custom fonts (Poppins & Crimson Pro)
        FontManager.registerFonts()

        // Run as a normal app: show in the Dock (the menu bar icon is still added separately).
        NSApp.setActivationPolicy(.regular)

        NSApp.activate(ignoringOtherApps: true)

        // Sync launch at login with saved setting
        syncLaunchAtLogin()
    }

    // Keep app alive when window closed - always keep running for menu bar
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Never quit when window closes - we're a menu bar app now
    }



    // MARK: - Menu Bar Setup

    /// Setup menu bar with view model (called from ContentView) - ALWAYS ENABLED NOW
    @MainActor
    func setupMenuBar(with viewModel: ServerViewModel) {
        // Always create the controller if it doesn't exist
        if menuBarController == nil {
            menuBarController = MenuBarController()
        }
        
        // Set up the menu bar controller with the view model
        menuBarController?.setup(with: viewModel)
        
        // Make sure the menu bar icon is visible
        menuBarController?.showMenuBarIcon()
    }

    /// Update menu bar (simplified - always enabled now)
    @MainActor
    func updateMenuBarMode(enabled: Bool, hideDock: Bool, viewModel: ServerViewModel) {
        // Always enabled now, so just ensure it's set up
        if menuBarController == nil {
            menuBarController = MenuBarController()
        }
        menuBarController?.setup(with: viewModel)
        menuBarController?.showMenuBarIcon()
        NSApp.setActivationPolicy(.regular) // Normal app: keep the Dock icon visible
    }

    // MARK: - Launch at Login

    /// Update launch at login setting
    /// Returns true if successful, false if failed
    @discardableResult
    func updateLaunchAtLogin(enabled: Bool) -> Bool {
        do {
            let currentStatus = SMAppService.mainApp.status
            if enabled {
                if currentStatus == .enabled || currentStatus == .requiresApproval {
                    return true // Already enabled
                }
                try SMAppService.mainApp.register()
                let updatedStatus = SMAppService.mainApp.status
                return updatedStatus == .enabled || updatedStatus == .requiresApproval
            } else {
                if currentStatus != .notRegistered {
                    try SMAppService.mainApp.unregister()
                }
                return true
            }
        } catch {
            #if DEBUG
            print("Failed to update launch at login: \(error)")
            #endif
            return false
        }
    }

    /// Check if launch at login is enabled
    func isLaunchAtLoginEnabled() -> Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    /// Check if launch at login requires user approval
    func launchAtLoginRequiresApproval() -> Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Try to sync launch at login with saved setting
    func syncLaunchAtLogin() {
        let savedSetting = UserDefaults.standard.appSettings.launchAtLogin
        let systemState = isLaunchAtLoginEnabled()

        if savedSetting != systemState {
            #if DEBUG
            print("Launch at login mismatch - saved: \(savedSetting), system: \(systemState). Attempting to sync...")
            #endif
            updateLaunchAtLogin(enabled: savedSetting)
        }
    }

    // Handle reopening when user clicks dock icon with no windows open
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows: reopen (re-creating if needed).
            MainActor.assumeIsolated { showMainWindow() }
        }
        return true
    }
}
