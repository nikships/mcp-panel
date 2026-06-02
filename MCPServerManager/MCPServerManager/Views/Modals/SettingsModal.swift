import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case privacy = "Privacy"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .privacy: return "lock.shield.fill"
        case .advanced: return "wrench.and.screwdriver.fill"
        }
    }

    var description: String {
        switch self {
        case .general: return "Configs & startup"
        case .appearance: return "Themes & display"
        case .privacy: return "Security options"
        case .advanced: return "Network & debug"
        }
    }
}

// MARK: - Settings Modal

struct SettingsModal: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: ServerViewModel
    @Environment(\.themeColors) private var themeColors

    @State private var selectedTab: SettingsTab = .general
    @State private var config1Path: String = ""
    @State private var config2Path: String = ""
    @State private var droidConfigPath: String = ""
    @State private var confirmDelete: Bool = true
    @State private var fetchServerLogos: Bool = true
    @State private var blurJSONPreviews: Bool = false
    @State private var selectedTheme: AppTheme = .auto
    @State private var testingConnection: Bool = false
    @State private var testResult: String = ""
    @State private var showBookmarkAlert: Bool = false
    @State private var bookmarkAlertMessage: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginRequiresApproval: Bool = false

    // Animation states
    @State private var appearAnimation: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar Navigation
            sidebarView

            // Divider
            Rectangle()
                .fill(themeColors.borderColor.opacity(0.5))
                .frame(width: 1)

            // Content Area
            VStack(spacing: 0) {
                contentHeader
                Divider().opacity(0.5)
                contentBody
                Divider().opacity(0.5)
                footerView
            }
        }
        .frame(width: 720, height: 560)
        .modifier(LiquidGlassModifier(shape: RoundedRectangle(cornerRadius: 16)))
        .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
        .onAppear {
            loadSettings()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
        .alert("Bookmark Storage Failed", isPresented: $showBookmarkAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bookmarkAlertMessage)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 8) {
            // App Icon & Title
            VStack(spacing: 8) {
                Image(nsImage: AppIcon.image)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Settings")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(themeColors.primaryText)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Tab Items
            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Version info
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(themeColors.mutedText)
                .padding(.bottom, 16)
        }
        .frame(width: 190)
        .background(themeColors.sidebarBackground.opacity(0.5))
    }

    // MARK: - Content Header

    private var contentHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab.rawValue)
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(themeColors.primaryText)

                Text(selectedTab.description)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(themeColors.secondaryText)
            }

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(themeColors.mutedText)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Content Body

    private var contentBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch selectedTab {
                case .general:
                    generalTabContent
                case .appearance:
                    appearanceTabContent
                case .privacy:
                    privacyTabContent
                case .advanced:
                    advancedTabContent
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - General Tab

    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Config Files Section
            SettingsSectionCard(title: "Configuration Files", icon: "doc.text.fill") {
                VStack(spacing: 16) {
                    ConfigPathEditor(
                        label: "Claude Code",
                        icon: "1.circle.fill",
                        placeholder: "~/.claude.json",
                        path: $config1Path,
                        onBrowse: { selectConfigFile { config1Path = $0 } }
                    )

                    Divider().opacity(0.3)

                    ConfigPathEditor(
                        label: "Gemini CLI",
                        icon: "2.circle.fill",
                        placeholder: "~/.settings.json",
                        path: $config2Path,
                        onBrowse: { selectConfigFile { config2Path = $0 } }
                    )

                    Divider().opacity(0.3)

                    ConfigPathEditor(
                        label: "Droid (Optional)",
                        icon: "3.circle.fill",
                        placeholder: "~/.factory/mcp.json",
                        path: $droidConfigPath,
                        onBrowse: { selectConfigFile { droidConfigPath = $0 } }
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(themeColors.mutedText)
                        Text("Leave Droid path empty to keep Droid sync disabled.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(themeColors.mutedText)
                        Spacer()
                    }
                }
            }

            // Startup Section
            SettingsSectionCard(title: "Startup", icon: "power.circle.fill") {
                VStack(spacing: 12) {
                    SettingsToggleRow(
                        isOn: $launchAtLogin,
                        icon: "power.circle.fill",
                        label: "Launch at Login",
                        description: "Start MCP Server Manager when you log in"
                    )

                    if launchAtLogin && launchAtLoginRequiresApproval {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(themeColors.warningColor)
                                .font(.system(size: 12))

                            Text("Approval required in System Settings")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(themeColors.warningColor)

                            Spacer()

                            Button(action: openLoginItemsSettings) {
                                Text("Open Settings")
                                    .font(DesignTokens.Typography.caption)
                            }
                            .buttonStyle(.link)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeColors.warningColor.opacity(0.1))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Appearance Tab

    private var appearanceTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Theme Selection
            SettingsSectionCard(title: "Theme", icon: "paintpalette.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    // Auto mode toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-detect from Config")
                                .font(DesignTokens.Typography.label)
                                .foregroundColor(themeColors.primaryText)

                            Text("Uses Claude Code or Gemini CLI theme based on active config")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(themeColors.mutedText)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { selectedTheme == .auto },
                            set: { newValue in
                                if newValue {
                                    selectedTheme = .auto
                                } else {
                                    // Default to first non-auto theme when disabling auto
                                    selectedTheme = .claudeCode
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    if selectedTheme != .auto {
                        Divider().opacity(0.3)

                        // Theme Grid
                        Text("Select Theme")
                            .font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(themeColors.mutedText)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ThemePickerGrid(
                            selectedTheme: $selectedTheme,
                            onThemeSelected: { theme in
                                selectedTheme = theme
                                viewModel.settings.overrideTheme = theme == .auto ? nil : theme.rawValue
                                viewModel.saveSettings()
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Privacy Tab

    private var privacyTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionCard(title: "Confirmations", icon: "checkmark.shield.fill") {
                SettingsToggleRow(
                    isOn: $confirmDelete,
                    icon: "trash.circle.fill",
                    label: "Confirm before deleting",
                    description: "Show confirmation dialog when deleting servers"
                )
            }

            SettingsSectionCard(title: "Data Visibility", icon: "eye.slash.fill") {
                SettingsToggleRow(
                    isOn: $blurJSONPreviews,
                    icon: "rectangle.badge.xmark",
                    label: "Blur JSON previews",
                    description: "Hide sensitive data in code previews until you interact"
                )
            }
        }
    }

    // MARK: - Advanced Tab

    private var advancedTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionCard(title: "Network", icon: "network") {
                VStack(spacing: 16) {
                    SettingsToggleRow(
                        isOn: $fetchServerLogos,
                        icon: "photo.circle.fill",
                        label: "Fetch server logos",
                        description: "Download logos from internet (no tracking)"
                    )

                    Divider().opacity(0.3)

                    // Connection Test
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connectivity")
                            .font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(themeColors.mutedText)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack {
                            Button(action: testConnection) {
                                HStack(spacing: 8) {
                                    if testingConnection {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "network.badge.shield.half.filled")
                                    }
                                    Text(testingConnection ? "Testing..." : "Test Connection")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .disabled(testingConnection)
                        }

                        if !testResult.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: testResult.contains("Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(testResult.contains("Error") ? themeColors.errorColor : themeColors.successColor)
                                    .font(.system(size: 12))

                                Text(testResult)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(themeColors.secondaryText)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 12) {
            // Reset to defaults (subtle)
            Button(action: resetToDefaults) {
                Text("Reset to Defaults")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(themeColors.mutedText)
            }
            .buttonStyle(.plain)

            Spacer()

            // Cancel
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            // Save
            Button(action: saveSettings) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColors.primaryAccent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func loadSettings() {
        config1Path = viewModel.settings.config1Path
        config2Path = viewModel.settings.config2Path
        droidConfigPath = viewModel.settings.droidConfigPath ?? ""
        confirmDelete = viewModel.settings.confirmDelete
        fetchServerLogos = UserDefaults.standard.object(forKey: "fetchServerLogos") as? Bool ?? true
        blurJSONPreviews = viewModel.settings.blurJSONPreviews
        launchAtLogin = viewModel.settings.launchAtLogin
        let requiresApproval = (NSApp.delegate as? AppDelegate)?.launchAtLoginRequiresApproval() ?? false
        launchAtLoginRequiresApproval = launchAtLogin && requiresApproval

        if let themeStr = viewModel.settings.overrideTheme,
           let theme = AppTheme(rawValue: themeStr) {
            selectedTheme = theme
        } else {
            selectedTheme = .auto
        }
    }

    private func selectConfigFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.json]
        panel.showsHiddenFiles = true
        panel.message = "Select a config file to manage MCP servers"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try ConfigManager.shared.storeBookmarkForConfigFile(url: url, path: url.path)
            let path = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            completion(path)
        } catch {
            bookmarkAlertMessage = "Failed to create persistent access to the selected file. The app may not be able to access this file after restart.\n\nError: \(error.localizedDescription)"
            showBookmarkAlert = true
        }
    }

    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }

    private func testConnection() {
        testingConnection = true
        testResult = ""

        Task {
            let result = await viewModel.testConnection(to: config1Path)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    testingConnection = false

                    switch result {
                    case .success(let count):
                        testResult = "Found \(count) server(s) in config"
                    case .failure(let error):
                        testResult = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func resetToDefaults() {
        config1Path = "~/.claude.json"
        config2Path = "~/.settings.json"
        droidConfigPath = ""
        confirmDelete = true
        fetchServerLogos = true
        blurJSONPreviews = false
        selectedTheme = .auto
        launchAtLogin = false
    }

    private func saveSettings() {
        viewModel.settings.configPaths = [config1Path, config2Path]
        let trimmedDroidPath = droidConfigPath.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.settings.droidConfigPath = trimmedDroidPath.isEmpty ? nil : trimmedDroidPath
        viewModel.settings.confirmDelete = confirmDelete
        viewModel.settings.blurJSONPreviews = blurJSONPreviews
        UserDefaults.standard.set(fetchServerLogos, forKey: "fetchServerLogos")

        viewModel.settings.overrideTheme = selectedTheme == .auto ? nil : selectedTheme.rawValue
        viewModel.settings.launchAtLogin = launchAtLogin
        viewModel.saveSettings()

        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.setupMenuBar(with: viewModel)

            let launchUpdated = appDelegate.updateLaunchAtLogin(enabled: launchAtLogin)
            launchAtLoginRequiresApproval = launchAtLogin && appDelegate.launchAtLoginRequiresApproval()
            if !launchUpdated {
                viewModel.showToast(message: "Failed to update Launch at Login. Check System Settings > Login Items.", type: .error)
            } else if launchAtLoginRequiresApproval {
                viewModel.showToast(message: "Launch at Login needs approval in System Settings > Login Items.", type: .warning)
            }
        }

        isPresented = false
    }
}

// MARK: - Sidebar Tab Button

private struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.themeColors) private var themeColors
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? themeColors.primaryAccent : themeColors.secondaryText)
                    .frame(width: 20)

                Text(tab.rawValue)
                    .font(DesignTokens.Typography.label)
                    .foregroundColor(isSelected ? themeColors.primaryText : themeColors.secondaryText)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? themeColors.selectionColor : (isHovered ? themeColors.glassBackground : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Settings Section Card

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    @Environment(\.themeColors) private var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeColors.primaryAccent)

                Text(title)
                    .font(DesignTokens.Typography.label)
                    .foregroundColor(themeColors.primaryText)
            }

            // Section Content
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeColors.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Config Path Editor

private struct ConfigPathEditor: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var path: String
    let onBrowse: () -> Void

    @Environment(\.themeColors) private var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(themeColors.primaryAccent)
                    .font(.system(size: 12))

                Text(label)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(themeColors.secondaryText)
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: $path)
                    .textFieldStyle(.roundedBorder)
                    .font(DesignTokens.Typography.code)

                Button(action: onBrowse) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    @Binding var isOn: Bool
    let icon: String
    let label: String
    let description: String

    @Environment(\.themeColors) private var themeColors

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeColors.primaryAccent.opacity(0.8))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignTokens.Typography.label)
                    .foregroundColor(themeColors.primaryText)

                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(themeColors.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

// MARK: - Theme Picker Grid

private struct ThemePickerGrid: View {
    @Binding var selectedTheme: AppTheme
    let onThemeSelected: (AppTheme) -> Void

    @Environment(\.themeColors) private var themeColors

    // All themes except .auto (handled separately)
    private let themes: [AppTheme] = AppTheme.allCases.filter { $0 != .auto }

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(themes, id: \.self) { theme in
                ThemeSwatchButton(
                    theme: theme,
                    isSelected: selectedTheme == theme,
                    action: { onThemeSelected(theme) }
                )
            }
        }
    }
}

// MARK: - Theme Swatch Button

private struct ThemeSwatchButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.themeColors) private var currentThemeColors
    @State private var isHovered: Bool = false

    private var themeColors: ThemeColors {
        ThemeColors.forTheme(theme)
    }

    // Extract short display name
    private var displayName: String {
        switch theme {
        case .claudeCode: return "Claude"
        case .geminiCLI: return "Gemini"
        case .default: return "Cyberpunk"
        case .solarizedDark: return "Sol Dark"
        case .solarizedLight: return "Sol Light"
        case .monokai: return "Monokai"
        case .oneDark: return "One Dark"
        case .githubDark: return "GitHub"
        case .tokyoNight: return "Tokyo"
        case .catppuccin: return "Catppuccin"
        default: return theme.rawValue.replacingOccurrences(of: " ", with: "\n").components(separatedBy: "\n").first ?? theme.rawValue
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Color swatch preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeColors.mainBackground)
                    .frame(height: 44)
                    .overlay(
                        HStack(spacing: 4) {
                            Circle()
                                .fill(themeColors.primaryAccent)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(themeColors.secondaryAccent)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(themeColors.successColor)
                                .frame(width: 12, height: 12)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? currentThemeColors.primaryAccent : currentThemeColors.glassBorder, lineWidth: isSelected ? 2 : 1)
                    )

                // Theme name
                Text(displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(isSelected ? currentThemeColors.primaryText : currentThemeColors.secondaryText)
                    .lineLimit(1)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? currentThemeColors.selectionColor.opacity(0.5) : (isHovered ? currentThemeColors.glassBackground : Color.clear))
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
