import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var showSettings = false
    @State private var showAddServer = false
    @State private var showQuickActions = false
    @State private var showImporter = false
    @State private var showExporter = false

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
                AddServerModal(isPresented: $showAddServer, viewModel: viewModel)
            }
        }
        .environment(\.themeColors, viewModel.themeColors)
        .environment(\.currentTheme, viewModel.currentTheme)
        .frame(minWidth: 900, minHeight: 600)
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
            // Setup menu bar with view model (this ensures view model is available)
            print("ContentView appeared - setting up menu bar with view model")

            if let window = NSApp.windows.first(where: { candidate in
                candidate.className != "NSStatusBarWindow" && !(candidate is MenuBarPanel)
            }) {
                appDelegate.registerMainWindow(window)
            }
            
            // Use the environment object directly
            print("✅ Using AppDelegate environment object, calling setupMenuBar...")
            appDelegate.setupMenuBar(with: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WidgetServerToggled"))) { notification in
            handleWidgetServerToggle(notification)
        }
    }

    // MARK: - Widget Server Toggle Handler

    private func handleWidgetServerToggle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let serverID = userInfo["serverID"] as? UUID,
              let newState = userInfo["newState"] as? Bool else {
            return
        }

        // Find and toggle the server
        if let server = viewModel.servers.first(where: { $0.id == serverID }) {
            let currentState = server.inConfigs[safe: viewModel.settings.activeConfigIndex] ?? false
            if currentState != newState {
                viewModel.toggleServer(server)
            }
        }
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

    // MARK: - Import Handler

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            if case .failure(let error) = result {
                print("ERROR: File picker error: \(error)")
            }
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
            print("ERROR: Failed to read import file")
            return
        }

        _ = viewModel.addServers(from: jsonString)
    }
}
