---
name: mcp-panel-cli
description: >-
  Manage Claude Code MCP servers from the command line with the `mcp-panel` CLI:
  add a server, list servers with their enabled/disabled status, and toggle
  servers on or off. Use this when the user asks to add/install, list/inspect,
  enable, disable, or toggle an MCP server for Claude Code (the servers in
  ~/.claude.json), or to check which MCP servers are configured or active.
  macOS only; pairs with the MCP Panel app and keeps its GUI in sync.
---

# MCP Panel CLI (`mcp-panel`)

`mcp-panel` is the built-in command-line interface of **MCP Panel**, a macOS app that
manages **Claude Code** MCP server configuration. It edits the `mcpServers` map in
`~/.claude.json` (what Claude Code actually loads) and stays in sync with the app's full
view of servers, including ones that are disabled-but-remembered.

Reach for this skill when the user wants to:
- **Add / install** an MCP server for Claude Code.
- **List** configured MCP servers and see which are enabled or disabled.
- **Enable / disable / toggle** an MCP server without deleting it.

This CLI intentionally does **not** remove servers and does **not** manage tags. To delete
a server, use the MCP Panel app.

## Install

The CLI ships with the MCP Panel source as a separate executable in the Swift package:

```bash
cd MCPServerManager
swift build -c release
# binary: .build/release/mcp-panel
mkdir -p ~/.local/bin && cp .build/release/mcp-panel ~/.local/bin/mcp-panel   # optional; ensure ~/.local/bin is on PATH
```

If `mcp-panel` is already on PATH, call it directly.

## Commands

All success output is JSON on **stdout**. Errors are JSON on **stderr** with a non-zero
exit code, so you can branch on failures without parsing prose.

### list — show servers and their status

```bash
mcp-panel list
```

Returns `configPath`, `counts`, and a `servers` array. Each server has `name`, `enabled`,
`transport`, `summary`, and its full `config`. `enabled: true` means the server is active
in `~/.claude.json`; `enabled: false` means it is remembered but not currently loaded.

### add — add or update a server

Provide the server `name` and its **raw MCP config JSON** (the value object), either as an
argument or piped via stdin. Adding enables the server.

```bash
# stdio server
mcp-panel add context7 '{"command":"npx","args":["-y","@upstash/context7-mcp"]}'

# HTTP server (config via stdin)
echo '{"type":"http","url":"https://mcp.example.com/mcp"}' | mcp-panel add example

# GitHub Copilot httpUrl style
mcp-panel add gh '{"httpUrl":"https://api.githubcopilot.com/mcp/","headers":{"Authorization":"Bearer TOKEN"}}'
```

Accepted input shapes: a bare config object (preferred), or a `{"mcpServers": {…}}` /
`{"servers": {…}}` wrapper containing the named server. The explicit `<name>` argument
always determines the key.

### toggle — enable or disable a server

```bash
mcp-panel toggle context7        # flip current state
mcp-panel toggle context7 off    # force disable (idempotent)
mcp-panel toggle context7 on     # force enable  (idempotent)
```

In automation, prefer the explicit `on` / `off` form: it is idempotent and reports
`"changed": false` when the server is already in the desired state.

## Options

- `--config <path>` — operate on a specific config file (default: the app's configured
  path, otherwise `~/.claude.json`).
- `--factory <path>` — Factory ("Droid") config to mirror (default: the app's `droidConfigPath`
  setting, e.g. `~/.factory/mcp.json`). Also settable via `MCP_PANEL_FACTORY_CONFIG`.
- `--defaults <path>` — point at MCP Panel's preferences plist (advanced / testing).
- `-h`, `--help`, `--version`.

## Behavior and gotchas

- **Enabled vs. disabled:** enabled servers live in `~/.claude.json`; disabled servers are
  preserved in MCP Panel's shared cache (its UserDefaults) so they can be re-enabled later
  with their config intact. This matches the app's GUI exactly.
- **Factory (Droid) sync:** if the app has a Factory config path set (`droidConfigPath`,
  e.g. `~/.factory/mcp.json`), `add`/`toggle` also mirror the enabled set there, normalized
  like the GUI (explicit `type`, `httpUrl`→`url`, flattened `transport`). `list` reports
  `factoryConfigPath` and `factoryInSync`. Unset (or no `--factory`) means Droid sync is off.
- **Restart to load:** Claude Code reads MCP servers at startup. After adding or enabling a
  server, restart Claude Code (or the relevant MCP client) for it to take effect.
- **Live app:** if MCP Panel is open, it reconciles automatically via its file watcher;
  pressing ⌘R in the app forces an immediate refresh.
- **No remove:** this CLI only adds, lists, and toggles. Deleting is done in the app.
- **Exit codes:** `0` success, `64` usage error, `65` bad/invalid JSON, `69` server not
  found, `74` I/O error, `70` unexpected error.

## Recipes

```bash
# Is a server already configured, and is it active?
mcp-panel list | jq '.servers[] | select(.name=="context7") | {enabled, transport}'

# Add a server (add enables it automatically)
mcp-panel add context7 '{"command":"npx","args":["-y","@upstash/context7-mcp"]}'

# Temporarily disable a server without losing its config
mcp-panel toggle filesystem off
```
