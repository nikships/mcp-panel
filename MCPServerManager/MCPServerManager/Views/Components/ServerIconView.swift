import SwiftUI
import AppKit

/// Circular avatar icon for server cards
struct ServerIconView: View {
    let server: ServerModel
    let size: CGFloat
    var onCustomIconSelected: ((Result<String, Error>) -> Void)?

    @State private var logoImage: NSImage?
    @State private var isLoading = true
    @State private var isHovering = false
    @Environment(\.themeColors) private var themeColors

    private var isCustomIconSelectable: Bool {
        onCustomIconSelected != nil
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            themeColors.glassBackground.opacity(isHovering ? 0.8 : 0.6),
                            themeColors.glassBackground.opacity(isHovering ? 0.5 : 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(themeColors.borderColor.opacity(isHovering ? 0.6 : 0.3), lineWidth: isHovering ? 2 : 1)
                )

            // Icon content
            if let logoImage = logoImage {
                // Show fetched logo
                Image(nsImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.9, height: size * 0.9)
                    .clipShape(Circle())
            } else if isLoading {
                // Show loading indicator
                ProgressView()
                    .scaleEffect(0.75)
                    .frame(width: size * 0.9, height: size * 0.9)
            } else {
                // Show SF Symbol fallback
                Image(systemName: IconService.shared.getFallbackSymbol(for: server.name))
                    .font(.system(size: size * 0.65))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeColors.primaryAccent,
                                themeColors.secondaryAccent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Edit overlay on hover (only show if callback is provided)
            if isHovering, isCustomIconSelectable {
                Circle()
                    .fill(Color.black.opacity(0.6))

                Image(systemName: "photo.badge.plus")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: themeColors.primaryAccent.opacity(0.2), radius: 4, x: 0, y: 2)
        .onTapGesture {
            if isCustomIconSelectable {
                openFilePicker()
            }
        }
        .onHover { hovering in
            if isCustomIconSelectable {
                isHovering = hovering
            }
        }
        .contextMenu {
            if isCustomIconSelectable {
                Button {
                    openFilePicker()
                } label: {
                    Label("Set Custom Icon", systemImage: "photo.badge.plus")
                }

                if server.customIconPath != nil {
                    Button {
                        onCustomIconSelected?(.success(""))
                    } label: {
                        Label("Reset to Default Icon", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .task {
            await loadIcon()
        }
        .id(server.customIconPath)
    }

    private func loadIcon() async {
        isLoading = true

        // Highest priority: custom icon (user-selected, stored in app container)
        if let customIconFilename = server.customIconPath,
           let image = CustomIconManager.shared.loadCustomIcon(filename: customIconFilename) {
            logoImage = image
            isLoading = false
            return
        }

        // Second priority: registry image URL
        if let registryImageUrl = server.registryImageUrl,
           let url = URL(string: registryImageUrl),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let image = NSImage(data: data) {
            logoImage = image
            isLoading = false
            return
        }

        // Fall back to IconService if no custom/registry image or if loading failed
        logoImage = await IconService.shared.loadIcon(for: server.name, domain: server.iconDomain)
        isLoading = false
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select an icon image for \(server.name)"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                handleFileSelection(.success([url]))
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // Validate and copy image to app container
                let filename = try CustomIconManager.shared.storeCustomIcon(from: url, for: server.id)
                onCustomIconSelected?(.success(filename))
            } catch {
                // Pass the error (e.g. CustomIconError) to the ViewModel for a detailed toast.
                onCustomIconSelected?(.failure(error))
            }

        case .failure(let error):
            onCustomIconSelected?(.failure(error))
        }
    }
}

/// Preview helper
#if DEBUG
struct ServerIconView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            ServerIconView(
                server: ServerModel(
                    name: "GitHub MCP",
                    config: ServerConfig(command: "npx", args: ["@modelcontextprotocol/server-github"])
                ),
                size: 40
            )

            ServerIconView(
                server: ServerModel(
                    name: "Chrome DevTools",
                    config: ServerConfig(command: "npx", args: ["mcp-server-chrome"])
                ),
                size: 40
            )

            ServerIconView(
                server: ServerModel(
                    name: "Unknown Server",
                    config: ServerConfig(command: "some-command")
                ),
                size: 40
            )
        }
        .padding()
        .background(Color.black)
    }
}
#endif
