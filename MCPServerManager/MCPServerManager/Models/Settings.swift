import Foundation

struct AppSettings: Codable, Equatable {
    var confirmDelete: Bool
    var configPaths: [String]
    var droidConfigPath: String?
    var activeConfigIndex: Int
    var blurJSONPreviews: Bool
    var overrideTheme: String? // nil = auto-detect, otherwise use the theme name

    // Menu Bar Mode settings
    var menuBarModeEnabled: Bool
    var hideDockIconInMenuBarMode: Bool
    var launchAtLogin: Bool

    static let `default` = AppSettings(
        confirmDelete: true,
        configPaths: [
            "~/.claude.json",
            "~/.settings.json"
        ],
        droidConfigPath: nil,
        activeConfigIndex: 0,
        blurJSONPreviews: false,
        overrideTheme: nil,
        menuBarModeEnabled: false,
        hideDockIconInMenuBarMode: false,
        launchAtLogin: false
    )

    init(confirmDelete: Bool = true,
         configPaths: [String] = ["~/.claude.json", "~/.settings.json"],
         droidConfigPath: String? = nil,
         activeConfigIndex: Int = 0,
         blurJSONPreviews: Bool = false,
         overrideTheme: String? = nil,
         menuBarModeEnabled: Bool = false,
         hideDockIconInMenuBarMode: Bool = false,
         launchAtLogin: Bool = false) {
        self.confirmDelete = confirmDelete
        self.configPaths = configPaths
        self.droidConfigPath = droidConfigPath
        self.activeConfigIndex = max(0, min(activeConfigIndex, 1)) // Ensure 0 or 1
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
        confirmDelete = try container.decode(Bool.self, forKey: .confirmDelete)
        configPaths = try container.decode([String].self, forKey: .configPaths)
        droidConfigPath = try container.decodeIfPresent(String.self, forKey: .droidConfigPath)
        let decodedIndex = try container.decode(Int.self, forKey: .activeConfigIndex)
        activeConfigIndex = max(0, min(decodedIndex, 1))
        blurJSONPreviews = try container.decode(Bool.self, forKey: .blurJSONPreviews)
        overrideTheme = try container.decodeIfPresent(String.self, forKey: .overrideTheme)
        // New settings with defaults for backward compatibility
        menuBarModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .menuBarModeEnabled) ?? false
        hideDockIconInMenuBarMode = try container.decodeIfPresent(Bool.self, forKey: .hideDockIconInMenuBarMode) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }

    var activeConfigPath: String {
        configPaths[safe: activeConfigIndex] ?? configPaths[0]
    }

    var config1Path: String {
        configPaths[safe: 0] ?? "~/.claude.json"
    }

    var config2Path: String {
        configPaths[safe: 1] ?? "~/.settings.json"
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
