import Foundation

/// Watches a config file for external changes and notifies a callback on the main actor.
///
/// Handles atomic saves (editors replace the inode, firing `.rename`/`.delete`): on those
/// events the old descriptor is closed and the watch is re-armed on the new path. If the file
/// is briefly missing, the parent directory is watched until the file reappears.
///
/// All file access happens inside the security-scoped bookmark window (mirrors
/// `ConfigManager.withConfigAccess`).
final class ConfigFileWatcher {
    /// The user-facing path (e.g. "~/.claude.json"). Used for bookmark resolution.
    private var path: String
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void

    private let queue = DispatchQueue(label: "com.anand-92.mcp-panel.config-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var isWatchingParent = false
    private var debounceWorkItem: DispatchWorkItem?

    /// Tracks whether we currently hold security-scoped access we must release.
    private var securityScopedURL: URL?

    init(path: String, debounceInterval: TimeInterval = 0.3, onChange: @escaping () -> Void) {
        self.path = path
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    deinit {
        // deinit may run off the watcher queue; tear down synchronously.
        teardownSource()
        releaseSecurityScope()
    }

    // MARK: - Public API

    func start() {
        queue.async { [weak self] in
            self?.arm()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.teardownSource()
            self?.releaseSecurityScope()
        }
    }

    /// Switch to watching a new path (e.g. when the user changes the config in Settings).
    func updatePath(_ newPath: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.teardownSource()
            self.releaseSecurityScope()
            self.path = newPath
            self.arm()
        }
    }

    // MARK: - Arming

    /// Resolve the on-disk URL inside the security scope and begin watching either the file
    /// (if it exists) or its parent directory (until the file appears).
    private func arm() {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedURL = BookmarkManager.shared.resolveBookmark(for: trimmedPath)
            ?? ConfigManager.shared.expandPath(trimmedPath)

        // Open the watch inside the security-scoped bookmark access.
        if BookmarkManager.shared.hasBookmark(for: trimmedPath) {
            if resolvedURL.startAccessingSecurityScopedResource() {
                securityScopedURL = resolvedURL
            }
        }

        if FileManager.default.fileExists(atPath: resolvedURL.path) {
            watchFile(at: resolvedURL)
        } else {
            watchParentDirectory(of: resolvedURL)
        }
    }

    private func watchFile(at url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            // Could not open the file; fall back to watching the parent directory.
            watchParentDirectory(of: url)
            return
        }

        fileDescriptor = fd
        isWatchingParent = false

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.source?.data ?? []

            if flags.contains(.delete) || flags.contains(.rename) {
                // Atomic save replaced the inode: re-arm on the (new) path.
                self.scheduleDebouncedChange()
                self.reArm()
            } else {
                self.scheduleDebouncedChange()
            }
        }

        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source = src
        src.resume()
    }

    /// Watch the parent directory and re-arm onto the file once it (re)appears.
    private func watchParentDirectory(of url: URL) {
        let parent = url.deletingLastPathComponent()
        let fd = open(parent.path, O_EVTONLY)
        guard fd >= 0 else {
            fileDescriptor = -1
            return
        }

        fileDescriptor = fd
        isWatchingParent = true

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            // If the watched file has appeared, switch to watching it directly.
            if FileManager.default.fileExists(atPath: url.path) {
                self.scheduleDebouncedChange()
                self.reArm()
            }
        }

        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source = src
        src.resume()
    }

    /// Tear down the current source and re-arm on the (possibly new) path.
    private func reArm() {
        teardownSource()
        // Small delay so atomic replace completes before we re-open.
        queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            let trimmedPath = self.path.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedURL = BookmarkManager.shared.resolveBookmark(for: trimmedPath)
                ?? ConfigManager.shared.expandPath(trimmedPath)

            if FileManager.default.fileExists(atPath: resolvedURL.path) {
                self.watchFile(at: resolvedURL)
            } else {
                self.watchParentDirectory(of: resolvedURL)
            }
        }
    }

    // MARK: - Debounce

    private func scheduleDebouncedChange() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.onChange()
            }
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    // MARK: - Teardown

    private func teardownSource() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        if let src = source {
            src.cancel()
            source = nil
        } else if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func releaseSecurityScope() {
        if let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
    }
}
