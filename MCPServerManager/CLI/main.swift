import Foundation

// Entry point for the `mcp-panel` executable. All logic lives in `MCPPanelCLI`;
// this file only wires argv to it and forwards the process exit code.
exit(MCPPanelCLI.run(Array(CommandLine.arguments.dropFirst())))
