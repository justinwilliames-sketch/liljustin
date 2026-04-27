import AppKit
import Combine
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case source       // Hidden in LilJustin — Lenny archive mode is not used.
    case models
    case about
    case developer

    // LilJustin hides the `.source` pane (Lenny archive switcher) from the sidebar.
    // The pane itself stays in the file tree to keep the upstream merge surface small.
    static var allCases: [SettingsPane] { [.models, .about, .developer] }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source: return "Source"
        case .models: return "Models"
        case .about: return "About"
        case .developer: return "Developer"
        }
    }

    var subtitle: String {
        switch self {
        case .source: return "Hidden"
        case .models: return "Runtime and model choices"
        case .about: return "Credits and release notes"
        case .developer: return "Logs and preview states"
        }
    }

    var icon: String {
        switch self {
        case .source: return "books.vertical.fill"
        case .models: return "cpu.fill"
        case .about: return "person.text.rectangle.fill"
        case .developer: return "wrench.and.screwdriver.fill"
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppSettings.preferredTransportKey) var preferredTransport = AppSettings.PreferredTransport.automatic.rawValue
    @AppStorage(AppSettings.archiveAccessModeKey) var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) var officialToken = ""
    @AppStorage(AppSettings.openAIAPIKeyKey) var openAIAPIKey = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) var debugLoggingEnabled = true
    @AppStorage(AppSettings.preferredClaudeModelKey) var preferredClaudeModel = AppSettings.ClaudeModel.default.rawValue
    @AppStorage(AppSettings.preferredCodexModelKey) var preferredCodexModel = AppSettings.CodexModel.default.rawValue
    @AppStorage(AppSettings.preferredOpenAIModelKey) var preferredOpenAIModel = AppSettings.OpenAIModel.gpt5Nano.rawValue
    @AppStorage(AppSettings.welcomePreviewModeKey) var welcomePreviewMode = AppSettings.WelcomePreviewMode.live.rawValue
    @AppStorage(AppSettings.mcpReconnectNeededKey) var mcpReconnectNeeded = false

    @State var selectedPane: SettingsPane = .models
    @State var showResetConfirmation = false
    @State var resetErrorMessage: String?
    @State var sourcePaneStatusMessage: String?
    @State var sourcePaneErrorMessage: String?
    @State var detectionRefreshID = UUID()
    // Async detection results — nil means "still checking"
    @State var detectedClaudeAvailable: Bool? = nil
    @State var detectedCodexAvailable: Bool? = nil

    let officialArchiveURL = URL(string: "https://www.lennysdata.com") ?? URL(fileURLWithPath: "/")

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPane) {
                ForEach(visiblePanes) { pane in
                    SettingsSidebarRow(
                        pane: pane,
                        isSelected: selectedPane == pane,
                        action: { selectedPane = pane }
                    )
                    .tag(pane)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 250)
        } detail: {
            ScrollView(.vertical, showsIndicators: false) {
                currentPaneView
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("Settings")
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 840, idealWidth: 920, minHeight: 620, idealHeight: 700)
        .onAppear {
            refreshDetectionStateAndDefaults()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshDetectionStateAndDefaults()
        }
        .onChange(of: debugLoggingEnabled) { _, enabled in
            if !enabled && selectedPane == .developer {
                selectedPane = .source
            }
        }
        .alert("Reset LilJustin data?", isPresented: $showResetConfirmation) {
            Button("Reset All Data", role: .destructive) {
                do {
                    try AppSettings.resetAllData()
                    refreshDetectionStateAndDefaults()
                } catch {
                    resetErrorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears LilJustin's saved token, API keys, model/runtime settings, onboarding state, and removes the `lennysdata` MCP config it wrote for Claude and Codex.")
        }
        .alert("Reset Failed", isPresented: Binding(
            get: { resetErrorMessage != nil },
            set: { if !$0 { resetErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetErrorMessage ?? "")
        }
        .alert("Connection Failed", isPresented: Binding(
            get: { sourcePaneErrorMessage != nil },
            set: { if !$0 { sourcePaneErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sourcePaneErrorMessage ?? "")
        }
    }

    private var visiblePanes: [SettingsPane] {
        var panes: [SettingsPane] = [.source, .models, .about]
        if AppSettings.showsDeveloperTools {
            panes.append(.developer)
        }
        return panes
    }

    @ViewBuilder
    private var currentPaneView: some View {
        switch selectedPane {
        case .source:
            sourcePane
        case .models:
            modelsPane
        case .about:
            aboutPane
        case .developer:
            developerPane
        }
    }

    func refreshDetectionStateAndDefaults() {
        // Reset local loading indicators immediately so the UI shows "checking".
        detectedClaudeAvailable = nil
        detectedCodexAvailable = nil

        // Repopulate all subprocess-backed caches on a background thread so the
        // view body never reads slow properties (e.g. `claude mcp list`) with empty
        // caches on the main thread — which was the source of AttributeGraph cycles.
        DispatchQueue.global(qos: .userInitiated).async {
            AppSettings.refreshAndPrefetchDetectionStateSync()
            DispatchQueue.main.async {
                detectionRefreshID = UUID()
                // Only skip re-evaluation if the user explicitly chose Starter Pack.
                // Auto-written defaults don't count — native MCP detection should always upgrade.
                if !AppSettings.hasExplicitStarterPackChoice {
                    archiveAccessMode = AppSettings.defaultArchiveAccessMode.rawValue
                }
            }
        }
    }
}
