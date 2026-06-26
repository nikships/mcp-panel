# Changelog

All notable changes to MCP Server Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- **Agent-First CLI (`mcp-panel`)** - New built-in command-line interface — a separate `mcp-panel` executable in the Swift package — for scripting MCP server management from coding agents. Commands: `list` (all servers with enabled/disabled status), `add <name> <json>` (add or update a server from raw MCP JSON via argument or stdin), and `toggle <name> [on|off]` (idempotent enable/disable). Output is JSON on stdout with structured errors and stable exit codes on stderr. The CLI shares MCP Panel's model — enabled servers are written to `~/.claude.json` while disabled servers are remembered in the app's UserDefaults cache — so the CLI and the GUI stay in sync. Ships with a reusable agent skill in `skills/mcp-panel-cli/`. Not included in the sandboxed Mac App Store build.
- **Drag-and-Drop to Add Servers** - Drop JSON text or a `.json` file anywhere on the window to open the Add Servers modal pre-filled with that content, ready to review and add. A highlighted drop overlay appears while dragging, and invalid JSON still surfaces the normal validation messaging. The existing paste and file-import paths are unchanged.
- **Standard Keyboard Shortcuts** - Added the conventional macOS shortcuts: **⌘N** opens the Add Servers modal, **⌘F** focuses the header search field, and **⌘,** opens Settings. These join the existing **⌘R** (reload from disk) without conflicting.
- **SwiftLint Linting** - Added a tuned `.swiftlint.yml` (complexity, file/function/line length, naming, and TODO tracking rules), a `Lint` GitHub Actions workflow that runs `swiftlint lint --strict` on every push/PR, and a pre-commit hook that lints staged changes. The existing source was brought to **zero** violations (safe renames of single-letter locals, tuple→struct refactors, long-line wrapping, and splitting oversized types/files), with no behavior change.
- **Live Config Watching** - The app now watches your config file and reloads automatically when it changes on disk (edited by another tool, CLI, or editor). Debounced and resilient to atomic saves; no more stale views.
- **JSON Syntax Highlighting** - Server config previews, the inline card editor, the Raw JSON editor, and the Add Servers editor now render theme-aware, syntax-highlighted JSON (keys, strings, numbers, booleans/null, and punctuation), with caching for smooth scrolling.
- **Inline Rename** - Edit a server's top-level JSON key in the card editor to rename it; collisions and empty names are rejected with a clear message.
- **Transport Badge** - Each server card shows a transport badge (stdio / HTTP / SSE) at a glance, plus a context menu (Edit, Copy JSON, Delete) and improved accessibility labels.
- **Server Health Checks** - Each server card now has a Check action that performs a lightweight health check: HTTP/SSE configs ping their endpoint with a short timeout, and stdio configs verify that the command resolves on PATH. Results appear inline on the card and in a toast.
- **Sort Options** - A new sort control in the toolbar lets you order the server list by Name (A→Z, the default), Enabled first, or Recently modified. Sorting is applied alongside the active filter/search and your choice persists across launches.
- **`servers` Wrapper Support** - Pasting configs wrapped in `"servers"` (the VS Code / GitHub Copilot format) now works just like `"mcpServers"`; the wrapper is unwrapped automatically.
- **Paste a URL to Add** - Pasting a bare URL (e.g. `https://mcp.magicpatterns.com/mcp`) and clicking Add now creates an HTTP server keyed by the domain (e.g. `magicpatterns`). A missing scheme defaults to `https://`.

### Changed
- **"All Off" Button** - The toolbar's all-servers toggle switch is now a plain **All Off** button (power icon). It always disables every server in one click, replacing the previous switch that flipped all servers on or off depending on their current state.
- **Live Validation in Add Servers** - The Add Servers modal now validates the manual JSON as you type and shows inline valid/invalid feedback, so the separate **Validate** button has been removed. The editor is also syntax-highlighted, matching the Raw JSON editor.
- **Single Config Model** - Simplified to a single active configuration. A server is either enabled (present in the config) or not, replacing the previous dual-config enabled-state arrays.
- **⌘R Reloads From Disk** - The refresh button and ⌘R now reload servers from the config file instead of re-writing it.
- **Real "Recent" Filter** - The Recent filter now shows servers modified within the last 24 hours; use the new "Recently modified" sort to order them most-recent first.
- **Renamed to "MCP Panel"** - User-facing app name updated throughout the UI.
- **Normal Dock App** - The app now shows in the Dock like a standard macOS app (activation policy `.regular`) while keeping the menu bar icon, instead of running as an accessory/menu-bar-only app.
- **Simplified Theme Setting** - Removed the "Auto (Detect from Config)" theme option; the app now defaults to the Claude Code theme, and you can pick any of the built-in themes directly.
- **Claude Logo in Header** - The active-config badge now shows the Claude logo (tinted to the theme accent) for a `.claude.json` config instead of the "Claude Code" text label.
- **Internal Cleanup** - Simplified source across models, services, view models, and views (deduplicated JSON encoding, flattened redundant conditionals and availability guards) with no behavior change.

### Fixed
- **Drag-and-Drop Actually Working** - Dropping JSON onto the window previously showed the drop overlay but then silently did nothing on release. Two causes: Finder file drags only advertise a file URL (not the `public.json` type the handler matched on), and dragged text from browsers/Electron-based editors often fails the `NSString` object-loading path. File drops now resolve the dropped file URL directly, text drops load a raw plain-text representation first (with the old path as fallback), and a drop that can't be read shows an error toast instead of failing silently.
- **Stuck on "Loading configuration..."** - When `~/.claude.json` had no top-level `mcpServers` key (the default for Claude Code, which stores unrelated keys like `projects` and `userID`), the parser fell back to treating the entire file as the server list, creating bogus server cards and stalling the app on the loading screen. A missing `mcpServers` key is now treated as an empty server set.
- **Update Check Crash** - Fixed a hard crash when "Check for Updates" (or the automatic background check) found a newer version. The app was built against one version of Sparkle but the DMG shipped a different one, which crashed when the update window appeared. Sparkle is now pinned to a single exact version that both the build and the DMG packaging use.
- **Smoother Grid Scrolling** - The server grid no longer stutters while scrolling. Each card's read-only JSON preview previously nested its own `ScrollView`, re-encoded its config to a JSON string on every redraw, and always applied a blur layer. Previews now render as a fixed-height clipped view, cache their JSON off the render path (recomputed only when the server changes), and apply blur only when "Blur JSON previews" is enabled.
- **Valid Config Message Now Green** - In the Add Servers modal, the "Valid! Found N server(s)" confirmation now renders in the theme's success green. Previously it always used red error styling regardless of whether the configuration was actually valid.
- **Removed Nonfunctional Menu Bar Open App Button** - Removed the menu bar dropdown's "Open App" footer action because it did not reliably focus or restore the main window from the custom non-activating panel. The menu bar dropdown now only exposes actions that work there; Dock reopen and ⌘0 continue to use the main-window reopen path.
- **Consistent Custom Fonts Across Build Paths** - Poppins / Crimson Pro now register reliably whether the app is built via the GitHub Actions workflow (xcodebuild) or locally for Transporter (`swift build`). `FontManager` now discovers fonts by recursively scanning the bundle instead of probing fixed paths, the Info.plist uses the correct macOS `ATSApplicationFontsPath` key (the old iOS-only `UIAppFonts` key was ignored), and both build paths embed fonts in `Contents/Resources/Fonts`. Previously some App Store builds silently fell back to the system font.

### Removed
- **macOS Widget** - Removed the WidgetKit extension entirely (widget target, App Intents toggle, "Show in Widget" card button, and shared-storage sync). The app and its menu bar integration remain. The App Groups entitlement (`group.com.anand-92.mcp-panel`) is no longer needed; security-scoped bookmarks now live in standard app storage.
- **Gemini CLI Support** - Removed the Gemini CLI config, theme, config switcher, and related menu-bar UI. The app now focuses on a single Claude Code config.

### Fixed
- **Reopen Window from Menu Bar** - "Open App" in the menu bar (and clicking the Dock icon) now reliably reopens the main window after it's been closed. The app now uses a single `Window` scene so the window can be re-created on demand.
- **Escaped Slashes in JSON** - Forward slashes are no longer rendered as `\/` in the editors or written to the config file (e.g. `@scope\/pkg` now shows as `@scope/pkg`). JSON formatting is now consistent across the card editor, Raw JSON editor, and Add Server modal.

### Added
- **Menu Bar Mode** - Access MCP servers from the menu bar! Enable in Settings → Menu Bar to add a status bar icon with popover for quick server toggling. Optionally hide the Dock icon for a minimal, always-accessible experience.
- **macOS Widget Support** - WidgetKit extension for Control Center widgets. Mark servers with "Show in Widget" to display them in small/medium/large widget sizes. Interactive toggles on macOS 14+ (uses App Intents).
- **"Show in Widget" Feature** - New widget icon button on server cards to control which servers appear in the macOS widget. Maximum 8 servers can be displayed.
- **Launch at Login** - Option to start MCP Server Manager automatically when you log in (Settings → Menu Bar).
- **Mini Mode** - Super compact view for quick server toggling. Click "Mini" button (⇧⌘M) to shrink window to a minimal server list with on/off toggles. Click the Claude/Gemini badge to switch configs. Perfect for keeping the app accessible while working.
- **Responsive Toolbar** - Toolbar now gracefully adapts when window is narrowed. Buttons collapse to icon-only mode using `ViewThatFits`, with tooltips for discoverability.
- **Server List View** - New compact list view mode for better density when managing many servers. Toggle between Grid, List, and Raw JSON modes.
- Server tags (UI, Backend, Creativity, Dev Ops, Advanced) with per-server tagging and bulk enable by tag.

### Fixed
- **Widget Background** - Fixed widget rendering as a solid gray slab when unfocused. Moved themed background to `containerBackground` modifier so macOS handles focus/unfocus transitions properly instead of desaturating an opaque fill.
- **Widget Icon** - Fixed app icon in widget turning into a gray box when unfocused by using `.renderingMode(.original)` to preserve colors.
- **Widget Config Switcher** - Added Claude/Gemini toggle button to widget header (macOS 14+). Tap to switch between configs and see each config's servers with their independent enabled states. Previously the widget was locked to whichever config was last active in the main app.

### Changed
- **Menu Bar Icon** - Proper macOS template icon derived from the app logo. Now displays as a monochrome crystalline silhouette that automatically adapts to light/dark menu bars, matching other native menu bar icons like Teams and Claude.
- **Header & Toolbar Redesign** - Modern unified navigation with cleaner visual hierarchy. New app logo, prominent config switcher with Claude and Gemini brand icons, expandable search field with keyboard hints, and hover states throughout.
- **Config Switcher** - Replaced SF Symbols with official Claude and Gemini logos. Pill-style toggle with smooth matched geometry animations.
- **Toolbar Improvements** - View mode and filter toggles now show server counts. Filter labels always visible (never collapse). Better visual separation with dividers.
- **Quick Actions Menu** - Card-based design with staggered animations, two-line items (title + subtitle), and improved hover states.
- **Settings Modal Redesign** - Complete overhaul with macOS-native sidebar navigation. Four organized tabs (General, Appearance, Privacy, Advanced), visual theme picker grid with color swatches, improved section cards, and polished UX throughout.
- **App Entitlements** - Added App Groups entitlement for main app to widget communication (`group.com.anand-92.mcp-panel`).

### Removed
- **Codex Support** - Completely removed Codex configuration support. The app now focuses on Claude Code and Gemini CLI only (both use JSON format). Removed TOMLKit dependency, TOML parsing/writing, third config path, and all Codex-specific UI components.

### Fixed
- **Critical: Widget Toggles Now Work Without Main App** - Widget toggles now directly modify config files (~/.claude.json, ~/.settings.json) so they work instantly whether or not the main app is running, matching menu bar behavior. Previously, toggles only worked when the main app was running because they relied on notification passing. Now the widget uses security-scoped bookmarks stored in App Groups to directly read/write configs. Toggle flow: Read config → Toggle disabled field → Save config → Update display → Notify main app (if running).
- **Widget Button Not Visible** - Fixed "Show in Widget" button not showing checkmark when server is in widget. The SF Symbol `widget.small.badge.minus` doesn't exist on all macOS versions. Changed to use `widget.small.fill` with a checkmark overlay for better visibility.
- **Menu Bar Icon Not Appearing** - Fixed menu bar icon not showing even when enabled in settings. The icon was only set up when ContentView appeared, which could fail if there were window issues. Now shows menu bar icon early in `applicationDidFinishLaunching` before any views load.
- **Launch at Login UX** - Kept the in-app toggle, added a direct link to System Settings > Login Items, and improved approval handling so settings stay in sync.
- **Critical: Widget Empty in TestFlight/App Store** - Fixed widget showing empty even after marking servers with "Show in Widget". The `appstore.entitlements` file was missing the App Groups entitlement (`group.com.anand-92.mcp-panel`), preventing the main app from writing to the shared container that the widget reads from. Also added App Groups to `entitlements.plist` for DMG builds.
- **Menu Bar Disappearing on Settings** - Fixed bug where opening Settings would cause the menu bar icon to vanish. The issue was caused by incorrect use of `@NSApplicationDelegateAdaptor` property wrapper inside Views (should only be used in the App struct). Changed to access AppDelegate properly via `NSApp.delegate`.
- **Bookmark Permissions Loss** - Fixed intermittent "no permission to access config file" errors after app restart. Stale bookmarks were being aggressively deleted when refresh failed, even though they often still work for reading. Now preserves stale bookmarks and adds proper security-scoped access when refreshing.
- **Potential Crash in Mini Mode** - Fixed force unwrap `NSScreen.screens.first!` in `defaultWindowFrame()` that could crash if no screens are available (edge case during display reconfiguration).
- **Widget App Store Connect Warnings** - Fixed version mismatch warnings (90473) and provisioning profile error (90885) for the widget extension. Widget now inherits `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from project settings instead of using hardcoded values. Added explicit code signing settings to widget target.
- **Critical: macOS 26 Mini Mode Crash** - Fixed crash when toggling between mini mode and normal mode on macOS 26 (Tahoe). The crash occurred in `NSHostingView.invalidateSizeConstraintsIfNecessary()` due to simultaneous SwiftUI state animations and AppKit window resize animations conflicting during constraint updates. Fixed by sequencing operations: update state first, then defer window resize to next run loop.
- **Header Text Scaling** - Fixed header button text wrapping at narrow window widths. Text now scales smoothly with window size using `minimumScaleFactor` instead of wrapping awkwardly.
- **Critical: macOS 26 Launch Crash** - Fixed fatal crash on app startup caused by `Bundle.module` assertion failure when SPM resource bundle is missing. Replaced direct `Bundle.module` access with safe bundle lookup that gracefully handles missing resources without crashing.
- **Critical: Missing Resource Bundle in Builds** - Fixed GitHub Actions workflows (build-dmg.yml and build-appstore.yml) to copy the SPM resource bundle (`MCPServerManager_MCPServerManager.bundle`) containing fonts to the app's Resources folder. This was the root cause of the crash - the bundle was never being included in distributed builds.
- **Flexible Configuration** - Updated `ServerConfig` to support unlimited custom fields (e.g., `enabled_tools`, `startup_timeout_sec`, `enabled`), preserving all data in the configuration file.
- **Font Loading** - Enhanced font registration to robustly search for custom fonts in both development (SPM) and release (.app) environments, fixing missing font issues in local builds.

## [3.0.0] - 2025-11-26

### Added
- **Codex Configuration Support** - Full support for third config file with complete universe isolation. Manage Codex servers separately with dedicated UI, TOML file format support, and zero cross-contamination with Claude Code or Gemini CLI configs. Servers remain locked to their creation universe forever
- **TOML Display & Editing** - Codex servers now properly display and edit as TOML format (not JSON). Includes dedicated RawTOMLView component and TOML-aware ServerCardView previews

### Changed
- **App Store Readiness** - Updated app icon with black background for better visibility and App Store compliance. Optimized build scripts for App Store submission.

### Fixed
- **TOML File Selection** - Config file picker now accepts both .json and .toml files, allowing selection of Codex config files
- **Critical: Codex TOML Rendering** - Fixed major bug where Codex servers (stored as TOML) were incorrectly displayed and edited as JSON. All Codex UI components now use native TOML format with proper parsing and serialization
- **Critical: TOML Conversion Logic** - Centralized TOML utilities to fix build errors and code duplication. Proper TOMLValueConvertible unwrapping and TOMLArray handling
- **Critical: Codex Inline Editing** - Disabled inline editing for Codex servers to prevent JSON parser errors on TOML data. Users must use Raw TOML editor for Codex
- **Critical: Codex Add Server Bug** - Fixed "Added 0 servers" issue. Changed TOML parsing to expect `[mcp_servers]` (snake_case) which is more idiomatic for TOML configs
- **Swift 6 Concurrency** - Resolved main actor isolation issues in regex handling to prevent runtime warnings and potential crashes. Optimized concurrency model for better stability.
- **App Store Build Resources** - Fixed build script to correctly embed the resource bundle (containing fonts and assets) into the App Store package, resolving issues with missing custom fonts.
- **Font Registration** - Updated font manager to use standard `Bundle.module` access and explicitly register Crimson Pro fonts, ensuring correct typography in both Debug and Release builds.

---

## [2.0.3] - 2025-11-22

### Added
- **Custom Icon Personalization** - Click any server icon to upload custom images (PNG, JPG, SVG). Icons persist across restarts with smart validation (10MB max, 2048×2048px)
- **12 Professional Themes** - Choose from Nord, Dracula, Solarized Dark/Light, Monokai Pro, One Dark, GitHub Dark, Tokyo Night, Catppuccin Mocha, Gruvbox, Material Palenight, plus Auto mode
- **JSON Preview Blur** - Toggle blur effect for privacy during screen sharing. Automatically disables when editing
- **Force Save Option** - Override validation for custom MCP configurations with detailed error messages
- **HTTP-Based MCP Servers** - Support for GitHub Copilot format with httpUrl and custom headers fields
- **Server-Sent Events (SSE)** - Full support for SSE transport type and streaming servers

### Changed
- **Settings Modal Layout** - Redesigned settings interface with organized sections (Configuration, Appearance, Privacy & Security, Network). Added visual icons, better spacing, and card-based grouping for improved readability and navigation
- **Apple Liquid Glass Implementation** - Fully implemented Apple's native Liquid Glass design language with intelligent fallback support. On macOS 26 (Tahoe) and later, the app uses the new `.glassEffect()` modifier for authentic translucent materials that reflect and refract surroundings. On macOS 13-25, the app gracefully falls back to traditional glass morphism. Removed custom transparency sliders in Settings - the system now handles all glass effects automatically based on OS version.

### Fixed
- **Sparkle Update Installation** - Fixed "An error occurred while launching the installer" by disabling app sandboxing for DMG builds. Sparkle's installer requires non-sandboxed environment to properly replace the app bundle. Removed SUEnableInstallerLauncherService flag as it's only needed for sandboxed apps
- **Registry Browser Decoding** - Fixed "Browse Registry" failing to load servers due to strict header field requirements. Made APIHeader.name and APIHeader.value optional to handle servers with missing or incomplete header definitions
- **Sparkle Update Verification** - Added SUPublicEDKey to Info.plist to fix "error occurred in retrieving update information" when checking for updates
- **App Window Behavior** - Removed problematic "Show Main Window" menu item. App now quits when window is closed (standard single-window app behavior). This fixes App Store compliance issues.
- **Custom Icon Picker** - Fixed non-functional icon click by replacing SwiftUI fileImporter with native NSOpenPanel
- **Registry API Update** - Updated to correct GitHub MCP registry endpoint (api.mcp.github.com/v0/servers)
- **Sparkle Update Feed** - Corrected SUFeedURL to point to proper GitHub repository
- **Icon Visibility** - Increased icon fill from 60% to 90% for better visibility
- Permission errors when saving config files (removed atomic writes)
- Security-scoped bookmark write failures
- Better error handling throughout the app

---

## [2.0.2] - 2025-10-27

### Added ✨
- **MCP Registry Browser** - Browse and install servers from the official MCP registry with one click
- **Adaptive Themes** - Three beautiful themes that auto-switch based on your config (Claude Code, Gemini CLI, Default)
- **Server Logos** - Automatically fetches and displays server icons from the web
- **Quick Actions Menu** - Fast access to common tasks (explore registry, add servers, import/export)
- **Auto-Update System** - Sparkle framework integration for automatic updates (DMG builds)
- Sparkle update framework with release notes display

### Changed 🔧
- Enhanced JSON editor with better syntax highlighting and validation
- Improved search and filtering capabilities across server configurations
- Better error handling and user feedback throughout the app
- Performance optimizations for large config files

### Fixed 🐛
- Fixed config file reading issues on first launch
- Resolved server toggle state synchronization problems
- Improved stability when managing multiple configs simultaneously
- Fixed issues with hidden file visibility in file picker

---

## [2.0.0] - 2025-10-15

### Added
- Initial public release
- Dual config management (Claude Code + Gemini CLI)
- Grid view with server cards
- Raw JSON editor
- Search and filtering
- Import/export functionality
- Native macOS app built with SwiftUI

---

## How to Use This Changelog

When preparing a new release:

1. Move items from `[Unreleased]` to a new version section
2. Update the version number and date
3. Commit the changes
4. The GitHub workflow will automatically use these notes in:
   - Sparkle update dialog (shown to users)
   - GitHub release page
   - Update notifications

### Categories

- **Added** ✨ - New features
- **Changed** 🔧 - Changes to existing functionality
- **Deprecated** ⚠️ - Soon-to-be removed features
- **Removed** 🗑️ - Now removed features
- **Fixed** 🐛 - Bug fixes
- **Security** 🔒 - Security improvements
