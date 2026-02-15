import SwiftUI
import ServiceManagement
#if canImport(Sparkle)
import Sparkle
#endif

@main
struct MCPServerManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updateChecker = UpdateChecker.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate)
                .preferredColorScheme(.dark)
                .onAppear {
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
                Button("MCP Server Manager") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    var menuBarController: MenuBarController?
    private var widgetNotificationObserver: Any?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register custom fonts (Poppins & Crimson Pro)
        FontManager.registerFonts()

        // Always run as menu bar app
        NSApp.setActivationPolicy(.accessory)
        print("🚀 App launched as menu bar app (.accessory policy)")

        NSApp.activate(ignoringOtherApps: true)

        // Sync launch at login with saved setting
        syncLaunchAtLogin()

        // Setup widget notification listener
        setupWidgetNotificationListener()
        
        print("🎯 App finish launching - waiting for ContentView to set up menu bar...")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Remove notification observer
        if let observer = widgetNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    // Keep app alive when window closed - always keep running for menu bar
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Never quit when window closes - we're a menu bar app now
    }

    // MARK: - Menu Bar Setup

    @MainActor
    func showMainWindow() {
        // Accessory apps need regular activation policy to present a normal window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let existingWindow = mainWindow ?? NSApp.windows.first(where: { window in
                window.className != "NSStatusBarWindow" && !(window is MenuBarPanel)
            }) {
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            mainWindow = existingWindow
            mainWindow?.delegate = self
            return
        }
    }

    @MainActor
    func registerMainWindow(_ window: NSWindow) {
        guard window.className != "NSStatusBarWindow", !(window is MenuBarPanel) else { return }
        mainWindow = window
        mainWindow?.isReleasedWhenClosed = false
        mainWindow?.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender == mainWindow else { return true }
        sender.orderOut(nil)
        return false
    }

    /// Setup menu bar with view model (called from ContentView) - ALWAYS ENABLED NOW
    @MainActor
    func setupMenuBar(with viewModel: ServerViewModel) {
        print("🔧 AppDelegate: Setting up menu bar with view model - ALWAYS ENABLED")
        print("🔧 Current menuBarController: \(menuBarController == nil ? "nil" : "exists")")
        
        // Always create the controller if it doesn't exist
        if menuBarController == nil {
            print("🔧 Creating new MenuBarController...")
            menuBarController = MenuBarController()
        }
        
        // Set up the menu bar controller with the view model
        print("🔧 Setting up menu bar controller with view model...")
        menuBarController?.setup(with: viewModel)
        
        // Make sure the menu bar icon is visible
        print("🔧 Showing menu bar icon...")
        menuBarController?.showMenuBarIcon()
        
        print("✅ Menu bar setup complete with view model - should be visible now!")
        
        // Let's also check if the status item was created
        print("🔍 Menu bar status: \(menuBarController?.hasStatusItem == true ? "STATUS ITEM EXISTS" : "NO STATUS ITEM")")
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
        NSApp.setActivationPolicy(.accessory) // Always menu bar only
    }

    // MARK: - Launch at Login

    /// Update launch at login setting
    /// Returns true if successful, false if failed
    @discardableResult
    func updateLaunchAtLogin(enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
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
        return false
    }

    /// Check if launch at login is enabled
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            return status == .enabled || status == .requiresApproval
        }
        return false
    }

    /// Check if launch at login requires user approval
    func launchAtLoginRequiresApproval() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .requiresApproval
        }
        return false
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

    // MARK: - Widget Notification Handling

    private func setupWidgetNotificationListener() {
        widgetNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(SharedDataManager.serverToggledNotificationName),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWidgetServerToggle(notification)
        }
    }

    private func handleWidgetServerToggle(_ notification: Notification) {
        // Read pending toggle from shared UserDefaults (sandboxed apps can't receive userInfo)
        guard let defaults = UserDefaults(suiteName: "group.com.anand-92.mcp-panel"),
              let pendingToggle = defaults.dictionary(forKey: "pendingServerToggle"),
              let serverIDString = pendingToggle["serverID"] as? String,
              let serverID = UUID(uuidString: serverIDString),
              let newState = pendingToggle["newState"] as? Bool else {
            #if DEBUG
            print("Widget toggle: No pending toggle found or invalid data")
            #endif
            return
        }

        // Clear the pending toggle
        defaults.removeObject(forKey: "pendingServerToggle")
        defaults.synchronize()

        #if DEBUG
        print("Widget toggled server: \(serverID), new state: \(newState)")
        #endif

        // The actual toggle will be handled by the ServerViewModel
        // which listens to this notification
        NotificationCenter.default.post(
            name: NSNotification.Name("WidgetServerToggled"),
            object: nil,
            userInfo: [
                "serverID": serverID,
                "newState": newState
            ]
        )
    }

    // Handle reopening when user clicks dock icon with no windows open
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows, activate to create one
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}
