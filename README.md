<div align="center">

<img src="app-icon.png" width="128" height="128" alt="MCP Panel Icon"/>

# MCP Panel

[![Download Latest DMG](https://img.shields.io/badge/Download-Latest%20DMG-blue?style=for-the-badge&logo=apple)](https://github.com/anand-92/mcp-panel/releases/latest)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/anand-92/mcp-panel?style=for-the-badge)](https://github.com/anand-92/mcp-panel/releases/latest)
[![Build Status](https://img.shields.io/github/actions/workflow/status/anand-92/mcp-panel/build-dmg.yml?branch=main&style=for-the-badge)](https://github.com/anand-92/mcp-panel/actions)

**[⬇️ Download MCP Panel on the Mac App Store](https://apps.apple.com/us/app/mcp-server-manager/id6753700883?mt=12)**

A native macOS app for managing Claude Code MCP server configurations, built with SwiftUI.

</div>

## Features

- **MCP Registry Browser**: Browse and install servers from the official MCP registry with one click
- **Live Config Watching**: Automatically reloads when your config file is edited by another tool or editor
- **Server Icons**: Automatically fetches and displays server icons from the web, with custom icon support
- **Multiple View Modes**: Grid view with cards or raw JSON editor with syntax highlighting
- **Search & Filtering**: Real-time search and filter by status (all / active / disabled / recent)
- **Import/Export**: Bulk import/export server configurations; supports `mcpServers` and `servers` wrapper formats
- **Quick Actions Menu**: Fast access to registry browsing, adding servers, and import/export
- **Themes**: 13 built-in themes (Claude Code, Cyberpunk, Nord, Dracula, Tokyo Night, Catppuccin, and more)
- **Menu Bar Integration**: Optional menu bar icon for quick server toggling without opening the main window
- **Launch at Login**: Start MCP Panel automatically when you log in (Settings → General)
- **Auto-Updates**: Sparkle-powered updates for DMG builds
- **Keyboard Shortcuts**: ⌘N new server, ⌘R reload from disk, ⌘U check for updates

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building from source)
- Swift 5.9+

## Quick Start

### Install from App Store (Recommended)

Download from the [Mac App Store](https://apps.apple.com/us/app/mcp-server-manager/id6753700883?mt=12).

### Download DMG

Download the latest DMG from [GitHub Releases](https://github.com/anand-92/mcp-panel/releases/latest).

### Build from Source

```bash
cd MCPServerManager
swift run MCPServerManager      # Build & run the app in development mode
swift build -c release          # Release binaries only
```

> The package has two executables (`MCPServerManager` and `mcp-panel`), so pass the product name to `swift run`.

Linting (SwiftLint):

```bash
brew install swiftlint          # one-time
DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib \
  swiftlint lint --strict       # run from repo root; CI enforces zero violations
swiftlint --fix                 # autocorrect fixable issues
```

Distribution builds:

```bash
./build-appstore.sh             # Signed PKG for the Mac App Store
./build-and-sign-local.sh       # Notarized DMG for direct download
```

## Usage

### First Launch

1. On first launch you'll see the onboarding screen
2. Click **Select Config File** and navigate to `~/.claude.json`
3. Press **⌘⇧.** to reveal hidden files if needed
4. Click **Continue**

### Managing Servers

- **Add**: Click **New Server** or press **⌘N** — paste JSON, enter fields manually, or browse the registry
- **Edit**: Hover over a card and click the edit button, or rename the key inline
- **Delete**: Click the trash icon (confirmation dialog optional in Settings)
- **Toggle**: Use the switch on each card to enable or disable a server

### MCP Registry Browser

Click **New Server → Browse Registry**, search or scroll to find a server, and click **Add Server** to install it.

### Search & Filter

Type in the search bar to filter by name or configuration. Use the filter pills to show:
- **All Servers**
- **Active Only** — enabled in the current config
- **Disabled Only** — not in the current config
- **Recent** — modified in the last 24 hours

### Import/Export

- **Import**: Quick Actions → **Import JSON** — supports `mcpServers`, `servers` wrapper, or a bare URL paste
- **Export**: Quick Actions → **Export JSON**

### Settings

Open via the gear icon. Tabs:
- **General**: Config file path, launch at login, confirm-delete toggle
- **Appearance**: Theme picker (13 themes), window opacity, font scale
- **Privacy**: Blur JSON previews, fetch server logos toggle
- **Advanced**: Network and debug options

## Command-Line Interface

MCP Panel ships with **`mcp-panel`**, an agent-first CLI for scripting the same configuration the app manages. It's a separate executable in the Swift package:

```bash
cd MCPServerManager
swift build -c release
.build/release/mcp-panel --help          # or copy it onto your PATH
```

```bash
mcp-panel list                       # List servers + enabled/disabled status (JSON)
mcp-panel add <name> '<mcp-json>'    # Add/update a server from raw MCP JSON (arg or stdin)
mcp-panel toggle <name> [on|off]     # Enable/disable a server (no arg flips state)
```

Enabled servers are written to `~/.claude.json`; disabled servers are remembered in MCP Panel's shared cache, so the CLI and the app always agree. Output is JSON on stdout and errors are JSON on stderr with non-zero exit codes — designed for coding agents. A ready-to-use agent skill lives in [`skills/mcp-panel-cli/`](skills/mcp-panel-cli/SKILL.md). The CLI is not part of the sandboxed Mac App Store build.

## Configuration Format

MCP Panel manages `~/.claude.json` files:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["path/to/server.js"],
      "env": {
        "API_KEY": "your-key"
      }
    }
  }
}
```

Supports stdio, HTTP, SSE, and `httpUrl`-style (GitHub Copilot) transports.

## Project Structure

```
MCPServerManager/
├── Models/
│   ├── ServerConfig.swift          # MCP server config with dynamic field support
│   ├── ServerModel.swift           # In-memory server representation
│   ├── Settings.swift              # App settings
│   ├── Theme.swift                 # 13 built-in themes
│   ├── RegistryServer.swift        # MCP registry models
│   ├── ServerTag.swift             # Server tags
│   └── ConfigFormat.swift          # Config format helpers
├── ViewModels/
│   └── ServerViewModel.swift       # Main state and business logic
├── Views/
│   ├── ContentView.swift
│   ├── HeaderView.swift
│   ├── ServerGridView.swift
│   ├── ServerCardView.swift
│   ├── RawJSONView.swift
│   ├── MenuBarPopoverView.swift
│   ├── Components/
│   │   ├── BrowseRegistryView.swift
│   │   ├── GlassPanel.swift
│   │   ├── CustomToggleSwitch.swift
│   │   ├── ToastView.swift
│   │   ├── ToolbarView.swift
│   │   ├── QuickActionsMenu.swift
│   │   ├── ServerIconView.swift
│   │   ├── JSONCodeEditor.swift
│   │   └── HighlightedJSONText.swift
│   └── Modals/
│       ├── AddServerModal.swift
│       ├── SettingsModal.swift
│       └── OnboardingModal.swift
├── Services/
│   ├── ConfigManager.swift         # JSON config file I/O
│   ├── ConfigFileWatcher.swift     # Live reload on external edits
│   ├── MCPRegistryService.swift    # MCP registry API client
│   ├── IconService.swift           # Server logo fetching & caching
│   ├── BookmarkManager.swift       # Security-scoped bookmarks
│   ├── CustomIconManager.swift     # Custom icon management
│   ├── MenuBarController.swift     # Menu bar status item
│   └── UpdateChecker.swift         # Sparkle auto-update
└── Utilities/
    ├── Constants.swift
    ├── JSONSyntaxHighlighter.swift
    ├── LiquidGlassModifier.swift
    ├── DomainExtractor.swift
    ├── ServerExtractor.swift
    ├── FontManager.swift
    ├── FontScale.swift
    └── Extensions.swift
```

## Troubleshooting

**Can't see hidden files in the file picker** — press **⌘⇧.** to toggle hidden file visibility.

**Config not loading** — verify the path in Settings → General and use **Test Connection**. Ensure the file is valid JSON and readable.

**Servers not saving** — check file permissions (`chmod 644 ~/.claude.json`) and review Console.app filtered to "MCPServerManager" for errors.

**App won't launch** — requires macOS 13.0+. If you downloaded the DMG, check System Settings → Privacy & Security.

**Auto-updates not working** — auto-updates are DMG-only. Press **⌘U** to check manually. App Store builds update through the Mac App Store.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a Pull Request

## License

MIT — see LICENSE for details.

## Credits

Built with SwiftUI for macOS by [Nikhil Anand](https://github.com/nikhilanand).

- [Sparkle](https://sparkle-project.org/) — automatic updates
- MCP GitHub Registry — server discovery

---

[Mac App Store](https://apps.apple.com/us/app/mcp-server-manager/id6753700883?mt=12) · [GitHub Releases](https://github.com/anand-92/mcp-panel/releases) · [Report Issues](https://github.com/anand-92/mcp-panel/issues)
