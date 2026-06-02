import Foundation

struct AppSettings: Codable, Equatable {
    private static let defaultConfigPath = "~/.claude.json"

    var confirmDelete: Bool
    var configPath: String
    var droidConfigPath: String?
    var blurJSONPreviews: Bool
    var overrideTheme: String? // nil = auto-detect, otherwise use the theme name

    // Menu Bar Mode settings
    var menuBarModeEnabled: Bool
    var hideDockIconInMenuBarMode: Bool
    var launchAtLogin: Bool

    static let `default` = AppSettings(
        confirmDelete: true,
        configPath: defaultConfigPath,
        droidConfigPath: nil,
        blurJSONPreviews: false,
        overrideTheme: nil,
        menuBarModeEnabled: false,
        hideDockIconInMenuBarMode: false,
        launchAtLogin: false
    )

    init(confirmDelete: Bool = true,
         configPath: String = defaultConfigPath,
         droidConfigPath: String? = nil,
         blurJSONPreviews: Bool = false,
         overrideTheme: String? = nil,
         menuBarModeEnabled: Bool = false,
         hideDockIconInMenuBarMode: Bool = false,
         launchAtLogin: Bool = false) {
        self.confirmDelete = confirmDelete
        self.configPath = Self.normalizedConfigPath(configPath)
        self.droidConfigPath = droidConfigPath
        self.blurJSONPreviews = blurJSONPreviews
        self.overrideTheme = overrideTheme
        self.menuBarModeEnabled = menuBarModeEnabled
        self.hideDockIconInMenuBarMode = hideDockIconInMenuBarMode
        self.launchAtLogin = launchAtLogin
    }

    // Custom Codable for backward compatibility with old settings
    enum CodingKeys: String, CodingKey {
        case confirmDelete, configPath, configPaths, droidConfigPath, blurJSONPreviews, overrideTheme
        case menuBarModeEnabled, hideDockIconInMenuBarMode, launchAtLogin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmDelete = try container.decodeIfPresent(Bool.self, forKey: .confirmDelete) ?? true
        // Migration: prefer new single `configPath`; fall back to legacy `configPaths[0]`.
        if let decodedPath = try container.decodeIfPresent(String.self, forKey: .configPath) {
            configPath = Self.normalizedConfigPath(decodedPath)
        } else if let legacyPaths = try container.decodeIfPresent([String].self, forKey: .configPaths),
                  let first = legacyPaths.first {
            configPath = Self.normalizedConfigPath(first)
        } else {
            configPath = Self.defaultConfigPath
        }
        droidConfigPath = try container.decodeIfPresent(String.self, forKey: .droidConfigPath)?.trimmedNilIfEmpty
        blurJSONPreviews = try container.decodeIfPresent(Bool.self, forKey: .blurJSONPreviews) ?? false
        overrideTheme = try container.decodeIfPresent(String.self, forKey: .overrideTheme)
        // New settings with defaults for backward compatibility
        menuBarModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .menuBarModeEnabled) ?? false
        hideDockIconInMenuBarMode = try container.decodeIfPresent(Bool.self, forKey: .hideDockIconInMenuBarMode) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(confirmDelete, forKey: .confirmDelete)
        try container.encode(configPath, forKey: .configPath)
        try container.encodeIfPresent(droidConfigPath, forKey: .droidConfigPath)
        try container.encode(blurJSONPreviews, forKey: .blurJSONPreviews)
        try container.encodeIfPresent(overrideTheme, forKey: .overrideTheme)
        try container.encode(menuBarModeEnabled, forKey: .menuBarModeEnabled)
        try container.encode(hideDockIconInMenuBarMode, forKey: .hideDockIconInMenuBarMode)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
    }

    private static func normalizedConfigPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultConfigPath : trimmed
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
