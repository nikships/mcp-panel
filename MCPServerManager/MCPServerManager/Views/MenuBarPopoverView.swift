import SwiftUI
import AppKit

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Menu bar popover view for quick server access
struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: ServerViewModel
    let onRefresh: () -> Void
    @State private var searchText = ""

    // Use viewModel.themeColors directly for live updates when switching configs
    private var themeColors: ThemeColors { viewModel.themeColors }

    private var filteredServers: [ServerModel] {
        if searchText.isEmpty {
            return viewModel.servers
        }
        return viewModel.servers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            popoverHeader
            searchField
            serverList
            popoverFooter
        }
        .frame(width: 280, height: 400)
        // Invisible hit area to capture scroll/mouse events on transparent background
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColors.sidebarBackground.opacity(0.3))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    private var popoverHeader: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIcon.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)

            Text("MCP Servers")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeColors.primaryAccent)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.clear)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(themeColors.primaryAccent.opacity(0.7))

            TextField("Search servers...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(themeColors.primaryAccent)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(themeColors.primaryAccent.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(themeColors.primaryAccent.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(themeColors.primaryAccent.opacity(0.3), lineWidth: 0.5))
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Server List

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if filteredServers.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredServers) { server in
                        PopoverServerRow(
                            server: server,
                            isEnabled: server.enabled,
                            themeColors: themeColors,
                            onToggle: { viewModel.toggleServer(server) }
                        )
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(nsImage: AppIcon.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .opacity(0.5)

            Text(searchText.isEmpty ? "No servers configured" : "No matching servers")
                .font(.system(size: 12))
                .foregroundColor(themeColors.primaryAccent.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var popoverFooter: some View {
        HStack(spacing: 8) {
            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(themeColors.primaryAccent)
            .help("Refresh servers")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.clear)
    }
}

// MARK: - Popover Server Row

struct PopoverServerRow: View {
    let server: ServerModel
    let isEnabled: Bool
    let themeColors: ThemeColors
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            statusDot
            serverNameLabel
            Spacer()
            toggleSwitch
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHovering ? themeColors.primaryAccent.opacity(0.15) : Color.clear))
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hover
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(isEnabled ? themeColors.successColor : themeColors.primaryAccent.opacity(0.4))
            .frame(width: 6, height: 6)
    }

    private var serverNameLabel: some View {
        Text(server.name)
            .font(.system(size: 12, weight: isEnabled ? .medium : .regular))
            .foregroundColor(isEnabled ? themeColors.primaryAccent : themeColors.primaryAccent.opacity(0.6))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var toggleSwitch: some View {
        Button(action: onToggle) {
            ZStack {
                Capsule()
                    .fill(isEnabled ? themeColors.successColor : themeColors.primaryAccent.opacity(0.2))
                    .frame(width: 32, height: 18)
                    .overlay(Capsule().stroke(isEnabled ? Color.clear : themeColors.primaryAccent.opacity(0.3), lineWidth: 0.5))

                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .offset(x: isEnabled ? 7 : -7)
            }
        }
        .buttonStyle(.plain)
    }
}
