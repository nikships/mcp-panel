import AppKit
import SwiftUI

// MARK: - Custom Menu Bar Panel

/// A custom NSPanel that supports transparency and vibrancy for menu bar dropdowns
class MenuBarPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: backingStoreType,
            defer: flag
        )

        // Hide title bar completely
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Make window background transparent for vibrancy
        isOpaque = false
        backgroundColor = .clear

        // Float above other windows like a popover
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Don't show in dock or app switcher
        hidesOnDeactivate = false

        // IMPORTANT: Don't ignore mouse events - capture them for scrolling
        ignoresMouseEvents = false
    }

    // Allow the panel to become key without activating the app
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Accept mouse moved events for proper hover/scroll handling
    override var acceptsMouseMovedEvents: Bool {
        get { true }
        set { }
    }
}

// MARK: - Menu Bar Controller

/// Manages the menu bar status item and panel for quick server access
@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private weak var viewModel: ServerViewModel?
    private var eventMonitor: Any?
    private var localEventMonitor: Any?

    // Public property to check status
    var hasStatusItem: Bool { statusItem != nil }

    private let panelSize = NSSize(width: 280, height: 400)

    /// Clean up resources - called manually before releasing
    func cleanup() {
        removeEventMonitors()
    }

    // MARK: - Setup

    /// Initialize the menu bar controller with a view model
    func setup(with viewModel: ServerViewModel) {
        self.viewModel = viewModel

        // If we already have a status item but no panel, set it up now
        if statusItem != nil && panel == nil {
            setupPanel()
        }

        // If we have a panel, update its content with the new view model
        if panel != nil {
            updatePanelContent()
        }
    }

    /// Show the menu bar icon
    func showMenuBarIcon() {
        guard statusItem == nil else {
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Load menu bar icon from bundle resources
            var menuBarIcon: NSImage?

            // Try to load from bundle (SPM copies assets here)
            if let bundleURL = Bundle.main.url(forResource: "MCPServerManager_MCPServerManager", withExtension: "bundle"),
               let bundle = Bundle(url: bundleURL),
               let iconURL = bundle.url(
                   forResource: "MenuBarIcon@2x",
                   withExtension: "png",
                   subdirectory: "Assets.xcassets/MenuBarIcon.imageset"
               ),
               let image = NSImage(contentsOf: iconURL) {
                menuBarIcon = image
            }

            // Fallback: try NSImage(named:) for compiled asset catalog
            if menuBarIcon == nil, let image = NSImage(named: "MenuBarIcon") {
                menuBarIcon = image
            }

            if let icon = menuBarIcon {
                icon.isTemplate = true
                icon.size = NSSize(width: 22, height: 22)  // Standard menu bar icon size
                button.image = icon
            } else {
                // Final fallback to SF Symbol
                button.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "MCP Servers")
            }
            button.action = #selector(togglePanel)
            button.target = self
        }

        setupPanel()
    }

    /// Hide the menu bar icon
    func hideMenuBarIcon() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        closePanel()
        panel = nil
    }

    /// Update visibility based on settings
    func updateVisibility(enabled: Bool) {
        if enabled {
            showMenuBarIcon()
        } else {
            hideMenuBarIcon()
        }
    }

    /// Refresh the panel content (useful when servers change)
    func refreshPopoverContent() {
        guard viewModel != nil, panel != nil else { return }
        updatePanelContent()
    }

    // MARK: - Panel Management

    private func setupPanel() {
        panel = MenuBarPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        updatePanelContent()
    }

    private func updatePanelContent() {
        guard let viewModel = viewModel, let panel = panel else {
            return
        }

        let panelView = MenuBarPopoverView(
            viewModel: viewModel,
            onOpenApp: { [weak self] in self?.openMainApp() },
            onRefresh: { [weak self] in self?.refreshServers() }
        )
        .environment(\.themeColors, viewModel.themeColors)
        .environment(\.currentTheme, viewModel.currentTheme)

        let hostingView = NSHostingView(rootView: panelView)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }

        // If no viewModel yet, just open the main app
        guard let viewModel = viewModel else {
            openMainApp()
            return
        }

        // Ensure panel exists and is properly configured
        if panel == nil {
            setupPanel()
        }

        guard let panel = panel else {
            return
        }

        if panel.isVisible {
            closePanel()
        } else {
            // Refresh data before showing
            viewModel.loadServers()
            updatePanelContent()

            // Calculate position below the status item
            if let buttonWindow = button.window {
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = buttonWindow.convertToScreen(buttonRect)

                // Position panel centered below the button
                let x = screenRect.midX - (panelSize.width / 2)
                let y = screenRect.minY - panelSize.height - 4 // 4px gap

                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            // Show the panel
            panel.makeKeyAndOrderFront(nil)
            addEventMonitors()
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        removeEventMonitors()
    }

    // MARK: - Event Monitoring

    private func addEventMonitors() {
        // Global monitor for clicks outside the app
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }

        // Local monitor for clicks inside the app but outside the panel
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return event }

            // If click is on the status item button, let togglePanel handle it
            if let button = self.statusItem?.button,
               let buttonWindow = button.window,
               event.window == buttonWindow {
                return event
            }

            // If click is outside the panel, close it
            if event.window != panel {
                self.closePanel()
            }

            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Actions

    private func openMainApp() {
        closePanel()

        // Delegate to the app delegate, which re-creates the SwiftUI window if it was closed.
        (NSApp.delegate as? AppDelegate)?.showMainWindow()
    }

    private func refreshServers() {
        viewModel?.loadServers()
    }
}
