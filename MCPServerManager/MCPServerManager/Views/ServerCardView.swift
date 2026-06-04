import AppKit
import SwiftUI

struct ServerCardView: View {
    let server: ServerModel
    @Binding var confirmDelete: Bool
    @Binding var blurJSONPreviews: Bool
    @State private var isEditing = false
    @State private var editedConfigText: String = ""
    /// Cached `namedConfigJSON` for the read-only preview. Encoding is comparatively
    /// expensive, so it is computed off the `body` path in `.task` (keyed by `server`)
    /// instead of re-encoding on every render while scrolling the grid. On first
    /// appearance — and until `.task` populates the cache, or whenever `server`
    /// changes — `cachedServer != server`, so the preview falls back to a synchronous
    /// encode (avoiding an empty-preview flicker) and uses the cached string thereafter.
    @State private var previewJSON: String = ""
    @State private var cachedServer: ServerModel?
    @State private var isHovering = false
    @State private var showingDeleteAlert = false
    @State private var showForceAlert = false
    @State private var invalidReason: String = ""
    @State private var pendingConfig: ServerConfig?
    @Environment(\.themeColors) private var themeColors
    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let onToggle: () -> Void
    let onTagToggle: (ServerTag) -> Void
    let onDelete: () -> Void
    let onUpdate: (String) -> ServerUpdateResult
    let onUpdateForced: (ServerConfig) -> Bool
    let onCustomIconSelected: ((Result<String, Error>) -> Void)?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                configSummary
                tagsSection
                configSection
                footerSection
            }
            .padding(DesignTokens.cardPadding)
        }
        .contextMenu {
            Button {
                startEditing()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                copyConfigToPasteboard()
            } label: {
                Label("Copy JSON", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                handleDeleteTapped()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Invalid Server Configuration", isPresented: $showForceAlert) {
            Button("Cancel", role: .cancel) {
                clearForceAlertState()
            }
            Button("Force Save") {
                handleForceSave()
            }
        } message: {
            Text("This server has validation errors:\n\n\(invalidReason)\n\n"
                + "Do you want to force save anyway? This will override all validations.")
        }
        .task(id: server) {
            previewJSON = server.namedConfigJSON
            cachedServer = server
        }
    }

    private func copyConfigToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(server.namedConfigJSON, forType: .string)
    }

    // MARK: - View Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(server.name)
                    .font(DesignTokens.Typography.title2)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TransportBadge(label: transportLabel, themeColors: themeColors)
            }

            Spacer(minLength: 8)

            ServerIconView(
                server: server,
                size: 40,
                onCustomIconSelected: onCustomIconSelected
            )
        }
    }

    private var configSummary: some View {
        Text(server.config.summary)
            .font(DesignTokens.Typography.bodySmall)
            .foregroundColor(.secondary)
            .lineLimit(1)
    }

    private var tagsSection: some View {
        HStack {
            ForEach(server.tags) { tag in
                TagChip(tag: tag) {
                    onTagToggle(tag)
                }
            }

            Menu {
                ForEach(ServerTag.allCases) { tag in
                    Button(action: { onTagToggle(tag) }, label: {
                        HStack {
                            Text(tag.rawValue)
                            if server.tags.contains(tag) {
                                Image(systemName: "checkmark")
                            }
                        }
                    })
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                    Text(server.tags.isEmpty ? "Add Tags" : "Edit")
                }
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(themeColors.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .stroke(themeColors.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(server.tags.isEmpty ? "Add tags" : "Edit tags")
        }
    }

    @ViewBuilder
    private var configSection: some View {
        if isEditing {
            editorView
        } else {
            previewView
        }
    }

    private var editorView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            JSONCodeEditor(
                text: $editedConfigText,
                themeColors: themeColors,
                reduceTransparency: reduceTransparency
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeColors.borderColor, lineWidth: 1)
            )

            HStack(spacing: 8) {
                EditorButton(
                    title: "Format",
                    icon: "text.alignleft",
                    style: .secondary,
                    themeColors: themeColors,
                    action: { editedConfigText = formatJSON(editedConfigText) }
                )

                Spacer()

                EditorButton(
                    title: "Cancel",
                    style: .secondary,
                    themeColors: themeColors,
                    action: { isEditing = false }
                )

                EditorButton(
                    title: "Save",
                    icon: "checkmark",
                    style: .primary,
                    themeColors: themeColors,
                    action: handleSave
                )
            }
        }
    }

    private var previewView: some View {
        ZStack(alignment: .topTrailing) {
            // Read-only preview: render the highlighted JSON directly (no nested
            // ScrollView — one per card stutters the grid) clipped to a fixed height.
            // Tap the pencil / Edit to see and modify the full config.
            HighlightedJSONText(
                json: cachedServer == server ? previewJSON : server.namedConfigJSON,
                themeColors: themeColors,
                themeName: currentTheme.rawValue
            )
            .padding(8)
            .modifier(PreviewBlur(active: blurJSONPreviews))
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200, alignment: .topLeading)
            .background(jsonSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if isHovering {
                Button(action: startEditing) {
                    Image(systemName: "pencil")
                        .font(DesignTokens.Typography.labelSmall)
                        .padding(6)
                        .background(themeColors.primaryAccent.opacity(0.85))
                        .foregroundColor(themeColors.textOnAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Edit \(server.name) configuration")
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var jsonSurface: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.panelBackground)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.mainBackground.opacity(0.55))
        }
    }

    private var footerSection: some View {
        HStack {
            CustomToggleSwitch(
                isOn: Binding(
                    get: { server.enabled },
                    set: { _ in onToggle() }
                )
            )
            .accessibilityLabel(server.enabled ? "Disable \(server.name)" : "Enable \(server.name)")

            Spacer()

            Button(action: handleDeleteTapped) {
                Image(systemName: "trash")
                    .foregroundColor(themeColors.errorColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(server.name)")
            .alert("Delete Server", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } message: {
                Text("Are you sure you want to delete '\(server.name)'?")
            }
        }
    }

    // MARK: - Transport Badge

    private var transportLabel: String {
        let config = server.config
        if let type = config.type?.lowercased() {
            switch type {
            case "stdio": return "stdio"
            case "http": return "HTTP"
            case "sse": return "SSE"
            default: break
            }
        }
        if config.command != nil { return "stdio" }
        if config.httpUrl != nil { return "HTTP" }
        if let transport = config.transport {
            return transport.type.uppercased()
        }
        if config.url != nil { return "HTTP" }
        return "Custom"
    }

    // MARK: - Actions

    private func startEditing() {
        // Edit the full named entry so the key can be renamed.
        editedConfigText = server.namedConfigJSON
        isEditing = true
    }

    private func handleSave() {
        let result = onUpdate(editedConfigText)
        if result.success {
            isEditing = false
        } else if let reason = result.invalidReason {
            invalidReason = reason
            pendingConfig = result.config
            showForceAlert = true
        }
    }

    private func handleForceSave() {
        if let config = pendingConfig, onUpdateForced(config) {
            isEditing = false
        }
        clearForceAlertState()
    }

    private func handleDeleteTapped() {
        if confirmDelete {
            showingDeleteAlert = true
        } else {
            onDelete()
        }
    }

    private func clearForceAlertState() {
        showForceAlert = false
        pendingConfig = nil
        invalidReason = ""
    }

    private func formatJSON(_ string: String) -> String {
        JSONFormatter.prettyPrinted(string) ?? string
    }
}

// MARK: - Preview Blur

/// Applies a blur only when active. Applying `.blur(radius: 0)` unconditionally still
/// forces an offscreen render pass per card, so the inactive case returns the view
/// untouched to keep grid scrolling smooth.
private struct PreviewBlur: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.blur(radius: DesignTokens.jsonPreviewBlurRadius)
        } else {
            content
        }
    }
}

// MARK: - Transport Badge

private struct TransportBadge: View {
    let label: String
    let themeColors: ThemeColors

    var body: some View {
        Text(label)
            .font(DesignTokens.Typography.captionSmall)
            .foregroundColor(themeColors.primaryAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(themeColors.primaryAccent.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(themeColors.primaryAccent.opacity(0.3), lineWidth: 1)
                    )
            )
            .accessibilityLabel("Transport: \(label)")
    }
}

// MARK: - Editor Button

private struct EditorButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    var icon: String?
    let style: Style
    let themeColors: ThemeColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(DesignTokens.Typography.labelSmall)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return themeColors.textOnAccent
        case .secondary:
            return themeColors.primaryText
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.accentGradient)
                .shadow(color: themeColors.primaryAccent.opacity(0.3), radius: 6, x: 0, y: 2)
        case .secondary:
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeColors.borderColor, lineWidth: 1)
                )
        }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: ServerTag
    let action: () -> Void
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag.rawValue)
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(DesignTokens.Typography.caption)
            .foregroundColor(themeColors.textOnAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AnyShapeStyle(themeColors.accentGradient))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove tag \(tag.rawValue)")
    }
}
