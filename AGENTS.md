# Repository Guidelines

MCP Panel is a native macOS app (SwiftUI + Swift Package Manager, macOS 13.0+) for managing MCP server configs for **Claude Code**. It edits the user's config file directly — no backend, no Claude Desktop support.

## Project Structure & Module Organization

- `MCPServerManager/` — SwiftPM package root (`Package.swift`, depends on Sparkle).
  - `MCPServerManager/` — app sources, grouped by role:
    - `Models/` — `ServerModel` (`enabled: Bool`), `ServerConfig`, `Settings` (single `configPath`), `Theme` (`AppTheme`, 7 themes).
    - `ViewModels/` — `ServerViewModel`, all business logic and config sync.
    - `Services/` — `ConfigManager` (file I/O), `ConfigFileWatcher` (live reload), `BookmarkManager` (security-scoped bookmarks), `MenuBarController`.
    - `Views/` — SwiftUI views; `Views/Modals/`, `Views/Components/` (e.g. `JSONCodeEditor`).
    - `Utilities/` — `Constants` (`appName = "MCP Panel"`), `JSONSyntaxHighlighter`, extensions.
    - `Resources/`, `Assets.xcassets/` — fonts and icons.
  - `CLI/` — sources for the `mcp-panel` agent CLI: a separate SwiftPM executable target (pure Foundation, no SwiftUI/Sparkle) that shares the app's on-disk format and UserDefaults cache. Built by `swift build`; excluded from the App Store package (`Package.swift.appstore`).
- Root scripts: `build-local-dev.sh`, `build-appstore.sh`, `create-dmg.sh`, `extract-changelog.sh`. `project.yml` drives `xcodegen`.

## Build, Test, and Development Commands

```bash
cd MCPServerManager && swift run MCPServerManager   # Build & run the app
cd MCPServerManager && swift run mcp-panel list      # Run the agent CLI (see CLI/)
cd MCPServerManager && swift build -c release        # Release binaries (.build only)
./build-local-dev.sh --launch                        # Bundle, sign, embed Sparkle, launch
```

The package now has two executable products (`MCPServerManager` and `mcp-panel`), so pass the product name to `swift run` — bare `swift run` is ambiguous. This machine has Command Line Tools only (no full Xcode), so `xcodebuild` is unavailable; use `swift build`. There is no automated test suite — verify changes by building and launching.

### Linting

```bash
brew install swiftlint                                          # one-time
DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib \
  swiftlint lint --strict                                       # lint (CLT needs the framework path)
swiftlint --fix                                                 # autocorrect fixable violations
```

- Config lives in `.swiftlint.yml` (rules tuned for this SwiftUI codebase: complexity, file/function length, line length, naming, `todo` tracking).
- CI runs `swiftlint lint --strict` on every push/PR via `.github/workflows/lint.yml`; the repo is expected to stay at **zero** violations.
- The `.githooks/pre-commit` hook also runs strict SwiftLint on commits when it is installed and SwiftLint is on PATH.

## Coding Style & Naming Conventions

- Swift, 4-space indentation. Types `UpperCamelCase`, members `lowerCamelCase`.
- Target macOS 13: avoid macOS 14+ APIs (two-parameter `.onChange`, `ContentUnavailableView`).
- Use `Read`/`Edit`/`Create` tools for file changes, not shell.
- Run SwiftLint before committing; keep the tree at zero violations (CI is strict).

## Commit & Pull Request Guidelines

- Commits: imperative, capitalized subject, no prefix (e.g. "Add widget config switcher", "Fix live theme color updates").
- **Only commit when explicitly asked.** Include the Claude Code co-author footer.
- **Always update `CHANGELOG.md` `[Unreleased]`** with code changes; GitHub Actions extracts it for Sparkle/GitHub release notes. After a release, move `[Unreleased]` into a versioned section.
- PRs: summarize all commits, list a test plan; use `gh pr create`.

## Configuration & Agent Notes

- Single config: `~/.claude.json`. `ConfigFileWatcher` reloads on external edits; ⌘R reloads from disk.
- Themes via `AppTheme`; Liquid Glass on macOS 26+, fallback for 13–25.
- Settings persist in UserDefaults via `@AppStorage`; custom icons in `~/Library/Application Support/MCPServerManager/CustomIcons/`.
- `CLAUDE.md` is a symlink to this file.
