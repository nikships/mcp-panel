import SwiftUI

struct ServerGridView: View {
    @ObservedObject var viewModel: ServerViewModel
    @Binding var showAddServer: Bool

    var body: some View {
        ScrollView {
            if viewModel.filteredServers.isEmpty {
                EmptyStateView(onCreateServer: {
                    showAddServer = true
                })
            } else {
                LazyVGrid(columns: GridConfiguration.columns, spacing: DesignTokens.gridSpacing) {
                    ForEach(viewModel.filteredServers) { server in
                        ServerCardView(
                            server: server,
                            confirmDelete: $viewModel.settings.confirmDelete,
                            blurJSONPreviews: $viewModel.settings.blurJSONPreviews,
                            onToggle: {
                                viewModel.toggleServer(server)
                            },
                            onTagToggle: { tag in
                                viewModel.toggleTag(tag, for: server)
                            },
                            onDelete: {
                                viewModel.deleteServer(server)
                            },
                            onUpdate: { json in
                                return viewModel.updateServer(server, with: json)
                            },
                            onUpdateForced: { config in
                                return viewModel.updateServerForced(server, config: config)
                            },
                            onCustomIconSelected: { result in
                                viewModel.updateCustomIcon(for: server, result: result)
                            }
                        )
                    }
                }
                .padding(20)
            }
        }
    }
}

struct EmptyStateView: View {
    let onCreateServer: () -> Void
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: AppIcon.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                )

            Text("No servers configured yet")
                .font(DesignTokens.Typography.title2)

            Text("Add your first MCP server to MCP Panel to get started")
                .font(DesignTokens.Typography.body)
                .foregroundColor(.secondary)

            Button(action: onCreateServer) {
                Text("Add Server")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(themeColors.accentGradient)
                    )
                    .foregroundColor(Color(hex: "#0b0e14"))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
