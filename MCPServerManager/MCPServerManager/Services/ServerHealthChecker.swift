import Foundation

struct ServerHealthChecker {
    private enum HealthTarget {
        case remote(urlString: String, headers: [String: String])
        case stdio(command: String, cwd: String?)
        case unsupported
    }

    private let timeout: TimeInterval = 4

    func check(_ server: ServerModel) async -> ServerHealthStatus {
        switch target(for: server.config) {
        case .remote(let urlString, let headers):
            return await checkRemote(urlString: urlString, headers: headers)
        case .stdio(let command, let cwd):
            return checkCommand(command, cwd: cwd)
        case .unsupported:
            return .unsupported("No HTTP/SSE endpoint or stdio command found")
        }
    }

    private func target(for config: ServerConfig) -> HealthTarget {
        if let httpUrl = nonBlank(config.httpUrl) {
            return .remote(urlString: httpUrl, headers: config.headers ?? [:])
        }

        if let transportUrl = nonBlank(config.transport?.url) {
            return .remote(urlString: transportUrl, headers: config.transport?.headers ?? config.headers ?? [:])
        }

        if let url = nonBlank(config.url) {
            return .remote(urlString: url, headers: config.headers ?? [:])
        }

        if let remote = config.remotes?.first {
            return .remote(urlString: remote.url, headers: remote.headers ?? config.headers ?? [:])
        }

        if let command = nonBlank(config.command) {
            return .stdio(command: command, cwd: config.cwd)
        }

        return .unsupported
    }

    private func checkRemote(urlString: String, headers: [String: String]) async -> ServerHealthStatus {
        guard let url = normalizedHTTPURL(from: urlString) else {
            return .unreachable("Invalid URL: \(urlString)")
        }

        do {
            let headStatus = try await statusCode(for: url, method: "HEAD", headers: headers)
            if headStatus == 405 {
                let getStatus = try await statusCode(for: url, method: "GET", headers: headers)
                return statusResult(getStatus, host: url.host ?? url.absoluteString)
            }
            return statusResult(headStatus, host: url.host ?? url.absoluteString)
        } catch {
            return .unreachable("Could not reach \(url.host ?? url.absoluteString): \(error.localizedDescription)")
        }
    }

    private func statusCode(for url: URL, method: String, headers: [String: String]) async throws -> Int {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if method == "GET", request.value(forHTTPHeaderField: "Range") == nil {
            request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return httpResponse.statusCode
    }

    private func statusResult(_ statusCode: Int, host: String) -> ServerHealthStatus {
        switch statusCode {
        case 200..<400, 405:
            return .reachable("\(host) responded with HTTP \(statusCode)")
        case 401, 403:
            return .authRequired("\(host) requires authentication (HTTP \(statusCode))")
        default:
            return .unreachable("\(host) responded with HTTP \(statusCode)")
        }
    }

    private func checkCommand(_ command: String, cwd: String?) -> ServerHealthStatus {
        if let path = resolvedExecutablePath(command, cwd: cwd) {
            return .reachable("Command resolves to \(path)")
        }
        return .unreachable("Command '\(command)' was not found on PATH")
    }

    private func resolvedExecutablePath(_ command: String, cwd: String?) -> String? {
        let expandedCommand = NSString(string: command).expandingTildeInPath

        if expandedCommand.contains("/") {
            let candidate: String
            if expandedCommand.hasPrefix("/") {
                candidate = expandedCommand
            } else if let cwd = nonBlank(cwd) {
                candidate = URL(fileURLWithPath: NSString(string: cwd).expandingTildeInPath)
                    .appendingPathComponent(expandedCommand)
                    .path
            } else {
                candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent(expandedCommand)
                    .path
            }
            return FileManager.default.isExecutableFile(atPath: candidate) ? candidate : nil
        }

        for directory in pathDirectories() {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(expandedCommand).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    private func pathDirectories() -> [String] {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let fallback = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        return Array(Set(path.split(separator: ":").map(String.init) + fallback)).sorted()
    }

    private func normalizedHTTPURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

    private func nonBlank(_ string: String?) -> String? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
