import SwiftUI

struct RawJSONView: View {
    @ObservedObject var viewModel: ServerViewModel
    @Environment(\.themeColors) private var themeColors
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var jsonText: String = ""
    @State private var isDirty: Bool = false
    @State private var errorMessage: String = ""
    @State private var showForceAlert: Bool = false
    @State private var invalidServerDetails: String = ""
    @State private var pendingSaveJSON: String = ""
    @State private var pendingServerDict: [String: ServerConfig]?

    var body: some View {
        VStack(spacing: 0) {
            // Info panel
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RAW JSON EDITOR")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(.secondary)
                        .tracking(1.5)

                    Text("Edit the full configuration in JSON format. Changes will be applied to the active config.")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isDirty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Unsaved edits")
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
            .padding(20)

            if !errorMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                }
                .font(DesignTokens.Typography.body)
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                )
                .padding(.horizontal, 20)
            }

            // Syntax-highlighted JSON editor
            JSONCodeEditor(
                text: $jsonText,
                themeColors: themeColors,
                fontSize: 15,
                reduceTransparency: reduceTransparency
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeColors.borderColor, lineWidth: 1)
            )
            .padding(20)
            .blur(radius: (viewModel.settings.blurJSONPreviews && !isDirty) ? DesignTokens.jsonPreviewBlurRadius : 0)
            .onChange(of: jsonText) { newValue in
                isDirty = newValue != serversToJSON()
            }

            // Action buttons
            HStack(spacing: 12) {
                RawJSONSecondaryButton(
                    icon: "text.alignleft",
                    title: "Format JSON",
                    themeColors: themeColors,
                    action: formatJSON
                )

                RawJSONSecondaryButton(
                    icon: "arrow.counterclockwise",
                    title: "Reset",
                    themeColors: themeColors,
                    action: resetJSON
                )

                Spacer()

                Button(action: applyChanges) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Apply Changes")
                    }
                    .font(DesignTokens.Typography.label)
                    .foregroundColor(isDirty ? Color(hex: "#1a1a1a") : themeColors.mutedText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDirty ? AnyShapeStyle(themeColors.accentGradient) : AnyShapeStyle(themeColors.glassBackground))
                    )
                    .shadow(color: isDirty ? themeColors.primaryAccent.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!isDirty)
            }
            .padding(20)
        }
        .onAppear {
            jsonText = serversToJSON()
        }
        .onChange(of: viewModel.filterMode) { _ in
            refreshJSONIfClean()
        }
        .onChange(of: viewModel.searchText) { _ in
            refreshJSONIfClean()
        }
        .alert("Invalid Server Configuration", isPresented: $showForceAlert) {
            Button("Cancel", role: .cancel, action: clearPendingSave)
            Button("Force Save") {
                forceSave()
            }
        } message: {
            Text("The following servers have validation errors:\n\n\(invalidServerDetails)\n\nDo you want to force save anyway? This will override all validations.")
        }
    }

    private func serversToJSON() -> String {
        viewModel.activeConfigServersJSON()
    }

    private func formatJSON() {
        // First normalize quotes (curly quotes from Notes/Word/Slack)
        let normalized = jsonText.normalizingQuotes()

        guard let data = normalized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: formatted, encoding: .utf8) else {
            errorMessage = "Invalid JSON format (after normalizing quotes)"
            return
        }
        jsonText = result
        errorMessage = ""
    }

    private func resetJSON() {
        jsonText = serversToJSON()
        isDirty = false
        errorMessage = ""
    }

    private func refreshJSONIfClean() {
        if !isDirty {
            jsonText = serversToJSON()
        }
    }

    private func applyChanges() {
        let result = viewModel.applyRawJSON(jsonText)

        if result.success {
            // Success
            isDirty = false
            errorMessage = ""
        } else if let invalidServers = result.invalidServers {
            // Validation failed, show force save alert
            let details = invalidServers.map { name, reason in
                "\(name): \(reason)"
            }.joined(separator: "\n")

            invalidServerDetails = details
            pendingSaveJSON = jsonText
            pendingServerDict = result.serverDict  // Store parsed dictionary to avoid re-parsing
            showForceAlert = true
        } else {
            // JSON parsing error (toast already shown by viewModel)
            // Keep isDirty as true and don't clear error
        }
    }

    private func forceSave() {
        do {
            // Use parsed dictionary if available to avoid re-parsing
            if let serverDict = pendingServerDict {
                viewModel.applyRawJSONForced(serverDict: serverDict)
            } else {
                // Fallback to JSON parsing (shouldn't happen in normal flow)
                try viewModel.applyRawJSONForced(pendingSaveJSON)
            }
            isDirty = false
            errorMessage = ""
            clearPendingSave()
        } catch {
            errorMessage = "Failed to parse JSON: \(error.localizedDescription)"
            showForceAlert = false
        }
    }

    private func clearPendingSave() {
        showForceAlert = false
        pendingSaveJSON = ""
        pendingServerDict = nil
        invalidServerDetails = ""
    }
}

private struct RawJSONSecondaryButton: View {
    let icon: String
    let title: String
    let themeColors: ThemeColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(DesignTokens.Typography.label)
            .foregroundColor(themeColors.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeColors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeColors.borderColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
