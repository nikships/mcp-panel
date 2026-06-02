import SwiftUI

struct BrowseRegistryView: View {
    @ObservedObject var registryService: MCPRegistryService
    @Environment(\.themeColors) private var themeColors

    @State private var servers: [RegistryServer] = []
    @State private var searchText = ""
    @State private var errorMessage = ""
    @State private var isInitialLoad = true

    let onSelectServer: (RegistryServer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider()
                .padding(.horizontal, 24)

            serverListContent
        }
        .task {
            if isInitialLoad {
                await loadServers()
            }
        }
    }

    // MARK: - View Components

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search servers...", text: $searchText)
                .font(DesignTokens.Typography.body)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var serverListContent: some View {
        if registryService.isLoading && isInitialLoad {
            loadingView
        } else if !errorMessage.isEmpty {
            errorView
        } else if filteredServers.isEmpty {
            emptyStateView
        } else {
            serverList
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading servers from registry...")
                .font(DesignTokens.Typography.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(errorMessage)
                .font(DesignTokens.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await loadServers()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeColors.accentGradient)
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(emptyStateMessage)
                .font(DesignTokens.Typography.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateMessage: String {
        if searchText.isEmpty {
            return "No servers available"
        } else {
            return "No servers match '\(searchText)'"
        }
    }

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredServers) { server in
                    ServerRow(server: server) {
                        onSelectServer(server)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Computed Properties

    private var filteredServers: [RegistryServer] {
        guard !searchText.isEmpty else {
            return servers
        }

        return servers.filter { server in
            server.name.localizedCaseInsensitiveContains(searchText) ||
            server.description.localizedCaseInsensitiveContains(searchText) ||
            server.config.command?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    // MARK: - Private Methods

    private func loadServers() async {
        errorMessage = ""
        defer { isInitialLoad = false }

        do {
            servers = try await registryService.fetchServers()
        } catch {
            errorMessage = "Failed to load servers: \(error.localizedDescription)"
        }
    }
}

// MARK: - Server Row

struct ServerRow: View {
    let server: RegistryServer
    let onSelect: () -> Void

    @Environment(\.themeColors) private var themeColors

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                serverIcon

                serverDetails

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var serverIcon: some View {
        if let imageUrl = server.imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 40, height: 40)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                case .failure, _:
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Circle()
            .fill(themeColors.accentGradient.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Text(server.displayName.prefix(1).uppercased())
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(themeColors.primaryAccent)
            )
    }

    private var serverDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(server.displayName)
                .font(DesignTokens.Typography.title3)
                .foregroundColor(.primary)

            Text(server.description)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(.secondary)
                .lineLimit(2)

            configInfo
        }
    }

    @ViewBuilder
    private var configInfo: some View {
        if let command = server.config.command {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                Text(commandPreview(command, args: server.config.args))
                    .font(DesignTokens.Typography.codeSmall)
            }
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.top, 2)
        } else if let type = server.config.type, let url = server.config.url {
            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.system(size: 10))
                Text("\(type.uppercased()): \(url)")
                    .font(DesignTokens.Typography.codeSmall)
                    .lineLimit(1)
            }
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.top, 2)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    // MARK: - Helper Methods

    private func commandPreview(_ command: String, args: [String]?) -> String {
        guard let args = args, !args.isEmpty else {
            return command
        }

        let argsPreview = args.prefix(2).joined(separator: " ")
        let suffix = args.count > 2 ? "..." : ""
        return "\(command) \(argsPreview)\(suffix)"
    }
}
