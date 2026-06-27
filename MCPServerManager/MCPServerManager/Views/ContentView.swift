import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showAddServer = false
    @State private var showQuickActions = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var showImportForceAlert = false
    @State private var importInvalidServerDetails = ""
    @State private var pendingImportServers: [String: ServerConfig]?
    @State private var droppedJSON: String?
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            backgroundView
            mainContent
            toastOverlay
            onboardingOverlay
            loadingOverlay
            quickActionsOverlay
            modalOverlay(isPresented: showSettings) {
                SettingsModal(isPresented: $showSettings, viewModel: viewModel)
            }
            modalOverlay(isPresented: showAddServer) {
                AddServerModal(isPresented: $showAddServer, viewModel: viewModel, initialJSON: droppedJSON)
            }
            dropTargetOverlay
            keyboardShortcuts
        }
        .environment(\.themeColors, viewModel.themeColors)
        .environment(\.currentTheme, viewModel.currentTheme)
        .frame(minWidth: 900, minHeight: 600)
        .onDrop(of: [.fileURL, .text], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: showAddServer) { isShowing in
            if !isShowing {
                droppedJSON = nil
            }
        }
        .onChange(of: scenePhase) { phase in
            // The descriptor-based file watcher can miss an external atomic
            // replace of the sandboxed config (e.g. a CLI write), so also reload
            // when the app returns to the foreground. Honors the self-write guard.
            if phase == .active {
                viewModel.reloadOnActivation()
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            onCompletion: handleImport
        )
        .fileExporter(
            isPresented: $showExporter,
            document: JSONDocument(content: viewModel.exportServers()),
            contentType: .json,
            defaultFilename: "mcp-servers.json"
        ) { _ in }
        .onAppear {
            appDelegate.setupMenuBar(with: viewModel)
        }
        .alert("Invalid Imported Servers", isPresented: $showImportForceAlert) {
            Button("Cancel", role: .cancel) {
                clearPendingImport()
            }
            Button("Force Import") {
                forceImport()
            }
        } message: {
            Text("The imported file contains validation errors:\n\n\(importInvalidServerDetails)\n\nDo you want to force import anyway?")
        }
    }

    // MARK: - Keyboard Shortcuts

    // Hidden buttons that attach standard macOS shortcuts: ⌘N opens the Add
    // Server modal and ⌘, opens Settings. (⌘F lives in HeaderView next to the
    // search field, and ⌘R in ToolbarView.)
    @ViewBuilder
    private var keyboardShortcuts: some View {
        Group {
            Button { showAddServer = true } label: { EmptyView() }
                .keyboardShortcut("n", modifiers: .command)

            Button { showSettings = true } label: { EmptyView() }
                .keyboardShortcut(",", modifiers: .command)
        }
        .buttonStyle(.plain)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - View Components

    @ViewBuilder
    private var backgroundView: some View {
        if #available(macOS 26.0, *) {
            Color.clear.ignoresSafeArea()
        } else {
            viewModel.themeColors.backgroundGradient.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            HeaderView(
                viewModel: viewModel,
                showSettings: $showSettings,
                showAddServer: $showAddServer,
                showQuickActions: $showQuickActions
            )
            ToolbarView(viewModel: viewModel)
            serverContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var serverContentView: some View {
        switch viewModel.viewMode {
        case .grid:
            ServerGridView(viewModel: viewModel, showAddServer: $showAddServer)
        case .rawJSON:
            RawJSONView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if viewModel.showToast {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ToastView(message: viewModel.toastMessage, type: viewModel.toastType)
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.showToast)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var onboardingOverlay: some View {
        if viewModel.showOnboarding {
            OnboardingModal(viewModel: viewModel)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .blur(radius: 10)

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading configuration...")
                        .font(DesignTokens.Typography.bodyLarge)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(radius: 30)
                )
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var quickActionsOverlay: some View {
        if showQuickActions {
            ZStack(alignment: .topLeading) {
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.0)
                    ]),
                    center: UnitPoint(x: 0.15, y: 0.15),
                    startRadius: 50,
                    endRadius: 1200
                )
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showQuickActions = false
                    }
                }

                QuickActionsMenu(
                    viewModel: viewModel,
                    showAddServer: $showAddServer,
                    showImporter: $showImporter,
                    showExporter: $showExporter,
                    isExpanded: $showQuickActions
                )
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var dropTargetOverlay: some View {
        if isDropTargeted {
            ZStack {
                viewModel.themeColors.primaryAccent.opacity(0.12)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 48))
                        .foregroundColor(viewModel.themeColors.primaryAccent)
                    Text("Drop JSON to add servers")
                        .font(DesignTokens.Typography.bodyLarge)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(radius: 30)
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        viewModel.themeColors.primaryAccent,
                        style: StrokeStyle(lineWidth: 3, dash: [12, 8])
                    )
                    .ignoresSafeArea()
            )
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func modalOverlay<Content: View>(
        isPresented: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                content()
            }
            .transition(.opacity)
        }
    }

    // MARK: - Drop Handler

    /// Handle JSON dropped onto the window: a file from Finder or a block of
    /// text. Routes through the Add Server modal (pre-filled) so the user can
    /// review, rather than the silent import path.
    ///
    /// Finder file drags only register `public.file-url` — they do *not*
    /// conform to `public.json` — so we match on `.fileURL` and read the file
    /// at the resolved URL. Text drags from many sources (browsers,
    /// Electron-based editors) promise plain text lazily, where
    /// `loadObject(ofClass: NSString.self)` is unreliable, so text is loaded
    /// from a raw data representation first.
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        if let fileProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) {
            loadDroppedFile(from: fileProvider)
            return true
        }

        if let textProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
                || $0.canLoadObject(ofClass: NSString.self)
        }) {
            loadDroppedText(from: textProvider)
            return true
        }

        return false
    }

    /// Read a dropped file's contents and present the Add Server modal.
    private func loadDroppedFile(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item: NSSecureCoding?, _: Error?) in
            guard let url = fileURL(from: item) else {
                reportDropFailure()
                return
            }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard let data = try? Data(contentsOf: url),
                  let jsonString = String(data: data, encoding: .utf8) else {
                reportDropFailure()
                return
            }
            DispatchQueue.main.async {
                presentAddServer(with: jsonString)
            }
        }
    }

    /// Decode the file URL handed back by `loadItem`, which arrives as raw
    /// URL bytes (`Data`), an `NSURL`, or a string depending on the source.
    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let url = item as? URL {
            return url
        }
        if let string = item as? String {
            return URL(string: string)
        }
        return nil
    }

    /// Load dropped text, preferring a raw plain-text data representation
    /// (reliable across drag sources) and falling back to `NSString`.
    private func loadDroppedText(from provider: NSItemProvider) {
        let plainTextType = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .plainText) == true
        }
        guard let plainTextType else {
            loadDroppedTextObject(from: provider)
            return
        }
        _ = provider.loadDataRepresentation(forTypeIdentifier: plainTextType) { data, _ in
            if let data, let text = String(data: data, encoding: .utf8) {
                presentDroppedText(text)
            } else {
                loadDroppedTextObject(from: provider)
            }
        }
    }

    /// Fallback text path: let Foundation coerce whatever the provider has
    /// into a string.
    private func loadDroppedTextObject(from provider: NSItemProvider) {
        guard provider.canLoadObject(ofClass: NSString.self) else {
            reportDropFailure()
            return
        }
        _ = provider.loadObject(ofClass: NSString.self) { text, _ in
            guard let text = text as? String else {
                reportDropFailure()
                return
            }
            presentDroppedText(text)
        }
    }

    /// Trim and present dropped text, ignoring whitespace-only drops.
    private func presentDroppedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reportDropFailure()
            return
        }
        DispatchQueue.main.async {
            presentAddServer(with: trimmed)
        }
    }

    /// Surface a toast instead of failing silently when a drop can't be read.
    private func reportDropFailure() {
        DispatchQueue.main.async {
            viewModel.showToast(message: "Couldn't read the dropped JSON", type: .error)
        }
    }

    /// Pre-fill the Add Server modal with the given text and present it.
    private func presentAddServer(with json: String) {
        droppedJSON = json
        showAddServer = true
    }

    // MARK: - Import Handler

    private func handleImport(_ result: Result<URL, Error>) {
        let url: URL
        switch result {
        case .success(let importURL):
            url = importURL
        case .failure(let error):
            viewModel.showToast(message: "Import failed: \(error.localizedDescription)", type: .error)
            return
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let jsonString = String(data: data, encoding: .utf8) else {
            viewModel.showToast(message: "Could not read the selected JSON file", type: .error)
            return
        }

        switch viewModel.addServers(from: jsonString) {
        case .success:
            break
        case .validationFailed(let invalidServers, let serverDict):
            importInvalidServerDetails = invalidServers
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            pendingImportServers = serverDict
            showImportForceAlert = true
        case .failed:
            break
        }
    }

    private func forceImport() {
        if let pendingImportServers {
            viewModel.addServersForced(serverDict: pendingImportServers)
        }
        clearPendingImport()
    }

    private func clearPendingImport() {
        showImportForceAlert = false
        importInvalidServerDetails = ""
        pendingImportServers = nil
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            content = string
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
