import SwiftUI

struct AddServerModal: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: ServerViewModel
    @Environment(\.themeColors) private var themeColors

    // MARK: - Entry State

    @State private var jsonText = ""
    @State private var errorMessage = ""
    @State private var entryMode: EntryMode = .manual
    @State private var registryImages: [String: String] = [:]

    // MARK: - Force Save State

    @State private var showForceAlert = false
    @State private var invalidServerDetails = ""
    @State private var pendingSaveJSON = ""
    @State private var pendingServerDict: [String: ServerConfig]?
    @State private var pendingRegistryImages: [String: String]?

    private enum EntryMode {
        case manual
        case browse
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            modeSwitcher
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(
            minWidth: 700,
            idealWidth: 850,
            maxWidth: 1000,
            minHeight: 600,
            idealHeight: 750,
            maxHeight: 900
        )
        .modifier(LiquidGlassModifier(shape: RoundedRectangle(cornerRadius: 20)))
        .shadow(radius: 30)
        .alert("Invalid Server Configuration", isPresented: $showForceAlert) {
            Button("Cancel", role: .cancel) { clearPendingState() }
            Button("Force Save", action: forceSave)
        } message: {
            Text("The following servers have validation errors:\n\n\(invalidServerDetails)\n\n"
                + "Do you want to force save anyway? This will override all validations.")
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("BULK ADD")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(.secondary)
                    .tracking(1.5)

                Text("Add Servers")
                    .font(DesignTokens.Typography.title2)
            }

            Spacer()

            Button(action: { isPresented = false }, label: {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(.secondary)
            })
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ModeButton(
                title: "Manual Entry",
                icon: "text.cursor",
                isSelected: entryMode == .manual,
                themeColors: themeColors
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    entryMode = .manual
                }
            }

            ModeButton(
                title: "Browse Registry",
                icon: "square.grid.2x2",
                isSelected: entryMode == .browse,
                themeColors: themeColors
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    entryMode = .browse
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var contentView: some View {
        if entryMode == .manual {
            manualEntryView
        } else {
            BrowseRegistryView(registryService: MCPRegistryService.shared) { selectedServer in
                handleServerSelection(selectedServer)
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            SecondaryButton(icon: "text.alignleft", title: "Format JSON", action: formatJSON)
            SecondaryButton(icon: "checkmark.shield", title: "Validate", action: validateJSON)

            Spacer()

            SecondaryButton(title: "Cancel") { isPresented = false }

            PrimaryButton(
                icon: "plus.circle.fill",
                title: "Add Servers",
                themeColors: themeColors,
                action: addServers
            )
            .disabled(jsonText.isEmpty)
            .opacity(jsonText.isEmpty ? 0.5 : 1.0)
        }
        .padding(24)
    }

    private var manualEntryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("SERVER JSON")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(.secondary)
                    .tracking(1.5)

                Text("Paste server definitions in the format: {\"server-name\": {\"command\": \"...\"}} or just the config object")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(.secondary)

                TextEditor(text: $jsonText)
                    .font(DesignTokens.Typography.codeLarge)
                    .frame(minHeight: 350, idealHeight: 450, maxHeight: 600)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .focusable(true)

                if !errorMessage.isEmpty {
                    errorMessageView
                }
            }
            .padding(24)
        }
    }

    private var errorMessageView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(errorMessage)
        }
        .font(DesignTokens.Typography.bodySmall)
        .foregroundColor(.red)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }

    // MARK: - State Management

    private func clearPendingState() {
        showForceAlert = false
        pendingSaveJSON = ""
        pendingServerDict = nil
        pendingRegistryImages = nil
        invalidServerDetails = ""
    }

    private func resetForm() {
        jsonText = ""
        errorMessage = ""
        registryImages = [:]
        clearPendingState()
    }

    // MARK: - JSON Operations

    private func formatJSON() {
        guard let result = JSONFormatter.prettyPrinted(jsonText) else {
            errorMessage = "Invalid JSON format (after normalizing quotes)"
            return
        }
        jsonText = result
        errorMessage = ""
    }

    private func validateJSON() {
        guard let serverDict = ServerExtractor.extractServerEntries(from: jsonText) else {
            errorMessage = "Could not parse JSON. Expected format: "
                + "{\"server-name\": {\"command\": \"...\"}} or wrap in {\"mcpServers\": {...}}"
            return
        }

        guard !serverDict.isEmpty else {
            errorMessage = "No valid server configurations found in JSON"
            return
        }

        let invalidServers = serverDict.filter { !$0.value.isValid }
        if !invalidServers.isEmpty {
            let details = invalidServers
                .map { "\($0.key): \(getInvalidReason($0.value))" }
                .joined(separator: "; ")
            errorMessage = "Invalid server config(s): \(details)"
            return
        }

        errorMessage = "Valid! Found \(serverDict.count) server(s)"
    }

    private func getInvalidReason(_ config: ServerConfig) -> String {
        let hasNoEndpoint = config.command == nil
            && config.httpUrl == nil
            && config.transport == nil
            && config.remotes == nil

        if hasNoEndpoint {
            return "missing command, httpUrl, transport, or remotes"
        }
        if let cmd = config.command, cmd.trimmingCharacters(in: .whitespaces).isEmpty {
            return "empty command"
        }
        if let url = config.httpUrl, url.trimmingCharacters(in: .whitespaces).isEmpty {
            return "empty httpUrl"
        }
        return "unknown issue"
    }

    // MARK: - Server Actions

    private func addServers() {
        let images = registryImages.isEmpty ? nil : registryImages

        switch viewModel.addServers(from: jsonText, registryImages: images) {
        case .success:
            isPresented = false
            resetForm()
        case .validationFailed(let invalidServers, let serverDict):
            invalidServerDetails = invalidServers
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            pendingSaveJSON = jsonText
            pendingServerDict = serverDict
            pendingRegistryImages = images
            showForceAlert = true
        case .failed:
            errorMessage = "Could not add servers. Review the JSON and try again."
        }
    }

    private func forceSave() {
        if let serverDict = pendingServerDict {
            viewModel.addServersForced(serverDict: serverDict, registryImages: pendingRegistryImages)
        } else {
            viewModel.addServersForced(from: pendingSaveJSON, registryImages: pendingRegistryImages)
        }

        isPresented = false
        resetForm()
    }

    // MARK: - Registry Selection

    private func handleServerSelection(_ server: RegistryServer) {
        if let imageUrl = server.imageUrl {
            registryImages[server.displayName] = imageUrl
        }

        let wrappedConfig = [server.displayName: server.config]
        jsonText = encodeAsPrettyJSON(wrappedConfig) ?? server.configJSON

        withAnimation(.easeInOut(duration: 0.2)) {
            entryMode = .manual
        }
        errorMessage = ""
    }

    private func encodeAsPrettyJSON(_ value: [String: ServerConfig]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Button Components

private struct SecondaryButton: View {
    let icon: String?
    let title: String
    let action: () -> Void

    init(icon: String? = nil, title: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButton: View {
    let icon: String?
    let title: String
    let themeColors: ThemeColors
    let action: () -> Void

    init(icon: String? = nil, title: String, themeColors: ThemeColors, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.themeColors = themeColors
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .foregroundColor(themeColors.textOnAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeColors.accentGradient)
            )
            .shadow(color: themeColors.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Button Component

private struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let themeColors: ThemeColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(DesignTokens.Typography.body)
            }
            .foregroundColor(isSelected ? themeColors.textOnAccent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(modeButtonBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var modeButtonBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10)
                .fill(themeColors.accentGradient)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}
