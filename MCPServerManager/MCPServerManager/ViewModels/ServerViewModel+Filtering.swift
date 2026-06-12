import Foundation

// MARK: - Filtering, Searching & Sorting

extension ServerViewModel {
    var filteredServers: [ServerModel] {
        var filtered = servers

        // Apply filter mode
        switch filterMode {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.enabled }
        case .disabled:
            filtered = filtered.filter { !$0.enabled }
        case .recent:
            // Servers modified within the last 24 hours.
            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            filtered = filtered.filter { $0.updatedAt >= cutoff }
        }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText) ||
                server.config.summary.localizedCaseInsensitiveContains(searchText) ||
                server.configJSON.localizedCaseInsensitiveContains(searchText)
            }
        }

        return sorted(filtered)
    }

    /// Apply the active sort order. Ties fall back to a stable A→Z by name.
    private func sorted(_ servers: [ServerModel]) -> [ServerModel] {
        switch sortMode {
        case .name:
            return servers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .enabledFirst:
            return servers.sorted { lhs, rhs in
                if lhs.enabled != rhs.enabled { return lhs.enabled }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .recentlyModified:
            return servers.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }
}
