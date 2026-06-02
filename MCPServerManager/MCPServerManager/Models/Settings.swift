import Foundation

struct AppSettings: Codable, Equatable {
    private static let defaultConfigPaths = ["~/.claude.json", "~/.settings.json"]

    var confirmDelete: Bool
    var configPaths: [String] {
        didSet {
            configPaths = Self.normalizedConfigPaths(configPaths)
            activeConfigIndex = Self.normalizedActiveConfigIndex(activeConfigIndex, configPathCount: configPaths.count)
        }
    }
    var droidConfigPath: String?
    var activeConfigIndex: Int {
        didSet {
            activeConfigIndex = Self.normalizedActiveConfigIndex(activeConfigIndex, configPathCount: configPaths.count)
        }
    }
    var blurJSONPreviews: Bool
    var overrideTheme: String? // nil = auto-detect, otherwise use the theme name

    // Menu Bar Mode settings
    var menuBarModeEnabled: Bool
    var hideDockIconInMenuBarMode: Bool
    var launchAtLogin: Bool

    static let `default` = AppSettings(
        confirmDelete: true,
        configPaths: defaultConfigPaths,
        droidConfigPath: nil,
        activeConfigIndex: 0,
        blurJSONPreviews: false,
        overrideTheme: nil,
        menuBarModeEnabled: false,
        hideDockIconInMenuBarMode: false,
        launchAtLogin: false
    )

    init(confirmDelete: Bool = true,
         configPaths: [String] = defaultConfigPaths,
         droidConfigPath: String? = nil,
         activeConfigIndex: Int = 0,
         blurJSONPreviews: Bool = false,
         overrideTheme: String? = nil,
         menuBarModeEnabled: Bool = false,
         hideDockIconInMenuBarMode: Bool = false,
         launchAtLogin: Bool = false) {
        self.confirmDelete = confirmDelete
        self.configPaths = Self.normalizedConfigPaths(configPaths)
        self.droidConfigPath = droidConfigPath
        self.activeConfigIndex = Self.normalizedActiveConfigIndex(activeConfigIndex, configPathCount: self.configPaths.count)
        self.blurJSONPreviews = blurJSONPreviews
        self.overrideTheme = overrideTheme
        self.menuBarModeEnabled = menuBarModeEnabled
        self.hideDockIconInMenuBarMode = hideDockIconInMenuBarMode
        self.launchAtLogin = launchAtLogin
    }

    // Custom Codable for backward compatibility with old settings
    enum CodingKeys: String, CodingKey {
        case confirmDelete, configPaths, droidConfigPath, activeConfigIndex, blurJSONPreviews, overrideTheme
        case menuBarModeEnabled, hideDockIconInMenuBarMode, launchAtLogin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmDelete = try container.decodeIfPresent(Bool.self, forKey: .confirmDelete) ?? true
        configPaths = Self.normalizedConfigPaths(try container.decodeIfPresent([String].self, forKey: .configPaths))
        droidConfigPath = try container.decodeIfPresent(String.self, forKey: .droidConfigPath)?.trimmedNilIfEmpty
        let decodedIndex = try container.decodeIfPresent(Int.self, forKey: .activeConfigIndex) ?? 0
        activeConfigIndex = Self.normalizedActiveConfigIndex(decodedIndex, configPathCount: configPaths.count)
        blurJSONPreviews = try container.decodeIfPresent(Bool.self, forKey: .blurJSONPreviews) ?? false
        overrideTheme = try container.decodeIfPresent(String.self, forKey: .overrideTheme)
        // New settings with defaults for backward compatibility
        menuBarModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .menuBarModeEnabled) ?? false
        hideDockIconInMenuBarMode = try container.decodeIfPresent(Bool.self, forKey: .hideDockIconInMenuBarMode) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }

    var activeConfigPath: String {
        configPaths[safe: activeConfigIndex] ?? config1Path
    }

    var config1Path: String {
        configPaths[safe: 0] ?? "~/.claude.json"
    }

    var config2Path: String {
        configPaths[safe: 1] ?? "~/.settings.json"
    }

    private static func normalizedConfigPaths(_ paths: [String]?) -> [String] {
        var normalized = (paths ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        while normalized.count < defaultConfigPaths.count {
            normalized.append(defaultConfigPaths[normalized.count])
        }

        return normalized
    }

    private static func normalizedActiveConfigIndex(_ index: Int, configPathCount: Int) -> Int {
        guard configPathCount > 0 else { return 0 }
        return max(0, min(index, configPathCount - 1))
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ViewMode: String, Codable, CaseIterable {
    case grid = "grid"
    case rawJSON = "json"

    var displayName: String {
        switch self {
        case .grid: return "Grid"
        case .rawJSON: return "JSON"
        }
    }

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .rawJSON: return "curlybraces"
        }
    }
}

enum FilterMode: String, Codable, CaseIterable {
    case all = "all"
    case active = "active"
    case disabled = "disabled"
    case recent = "recent"

    var displayName: String {
        switch self {
        case .all: return "All Servers"
        case .active: return "Active Only"
        case .disabled: return "Disabled Only"
        case .recent: return "Recently Modified"
        }
    }

    var label: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .disabled: return "Disabled"
        case .recent: return "Recent"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .active: return "checkmark.circle.fill"
        case .disabled: return "circle.slash"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
