import AppKit

extension TerminalView {
    func welcomeSuggestionPool(for archiveMode: AppSettings.ArchiveAccessMode) -> [(String, String, String)] {
        archiveMode == .starterPack
            ? WelcomeChipsView.starterPackSuggestionPool
            : WelcomeChipsView.defaultSuggestionPool
    }

    func ensureWelcomeSuggestionSelection(forceRefresh: Bool = false) {
        let archiveMode = welcomePreviewArchiveMode
        guard forceRefresh || currentWelcomeArchiveMode != archiveMode || currentWelcomeSuggestions.isEmpty else {
            return
        }

        currentWelcomeArchiveMode = archiveMode
        currentWelcomeSuggestions = Array(welcomeSuggestionPool(for: archiveMode).shuffled().prefix(4))
    }

    var welcomePreviewMode: AppSettings.WelcomePreviewMode {
        AppSettings.welcomePreviewMode
    }

    var welcomePreviewArchiveMode: AppSettings.ArchiveAccessMode {
        switch welcomePreviewMode {
        case .live:
            return AppSettings.effectiveArchiveAccessMode
        case .starterPackWithBanner, .starterPackConnected:
            return .starterPack
        case .officialConnected:
            return .officialMCP
        }
    }

    var shouldShowStarterPackUpsell: Bool {
        switch welcomePreviewMode {
        case .live:
            return AppSettings.effectiveArchiveAccessMode == .starterPack && !AppSettings.hasDetectedOfficialMCPConfiguration
        case .starterPackWithBanner:
            return true
        case .starterPackConnected, .officialConnected:
            return false
        }
    }

    var shouldPresentStarterPackWelcomeBanner: Bool {
        shouldShowStarterPackUpsell && !starterPackWelcomeBannerDismissed
    }

    var welcomeSuggestions: [(String, String, String)] {
        ensureWelcomeSuggestionSelection()
        return currentWelcomeSuggestions
    }

    func openOfficialMCPURL() {
        NSWorkspace.shared.open(officialMCPURL)
    }

    func completeOfficialMCPSetupFlow() {
        AppSettings.mcpReconnectNeeded = false
        isShowingOfficialMCPSetupPanel = false
        starterPackWelcomeBannerDismissed = true
        currentWelcomeArchiveMode = nil
        showWelcomeSuggestionsPanel()
    }

    func showOfficialMCPSetupPanel() {
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        isShowingOfficialMCPSetupPanel = true

        let setupCard = OfficialMCPConnectCardView(theme: theme, compact: true, showsBackButton: false)
        setupCard.onOpenWebsite = { [weak self] in
            self?.openOfficialMCPURL()
        }
        setupCard.onBack = { [weak self] in
            guard let self else { return }
            self.isShowingOfficialMCPSetupPanel = false
            self.showWelcomeSuggestionsPanel()
        }
        setupCard.onDismiss = { [weak self] in
            guard let self else { return }
            AppSettings.mcpReconnectNeeded = false
            self.isShowingOfficialMCPSetupPanel = false
            self.mcpSetupBannerDismissedThisSession = true  // suppress proactive banner this session
            self.showWelcomeSuggestionsPanel()
        }
        setupCard.onUseStarterPack = { [weak self] in
            guard let self else { return }
            AppSettings.mcpReconnectNeeded = false
            AppSettings.archiveAccessMode = .starterPack
            self.isShowingOfficialMCPSetupPanel = false
            self.refreshFirstRunStateIfNeeded(forceRefresh: true)
            self.showWelcomeSuggestionsPanel()
        }
        setupCard.onSave = { [weak self] in
            self?.completeOfficialMCPSetupFlow()
        }

        expertSuggestionLabel.isHidden = true
        expertSuggestionStack.addArrangedSubview(setupCard)
        setupCard.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor).isActive = true
        welcomeChipsView = nil
        expertSuggestionContainer.isHidden = false
        expertSuggestionContainer.alphaValue = 1
        relayoutPanels()
    }

    func openAppSettings() {
        NSApp.sendAction(#selector(AppDelegate.openSettings), to: NSApp.delegate, from: self)
    }

    func showWelcomeSuggestionsPanel() {
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if requiresInitialConnectionSetup {
            let setupCard = ConnectionSetupCardView(theme: theme)
            setupCard.onOpenSettings = { [weak self] in
                self?.openAppSettings()
            }
            expertSuggestionLabel.isHidden = true
            expertSuggestionStack.addArrangedSubview(setupCard)
            setupCard.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor).isActive = true
            welcomeChipsView = nil
            expertSuggestionContainer.isHidden = false
            expertSuggestionContainer.alphaValue = 1
            relayoutPanels()
            return
        }

        // MCP reconnect: persisted failure flag from a previous turn.
        // Proactive: token-based path selected but no token saved yet (first-run / unconfigured).
        // Native MCP (codex mcp add / codex mcp login) is self-sufficient — no app token needed.
        let hasNativeMCPConfig = AppSettings.detectedOfficialMCPSources.contains(.claudeGlobalConfig)
            || AppSettings.detectedOfficialMCPSources.contains(.codexGlobalConfig)
        let hasWorkingToken = AppSettings.officialLennyMCPToken != nil
            || AppSettings.shellEnvironmentOfficialMCPToken() != nil
        let needsTokenSetup = !hasNativeMCPConfig
            && AppSettings.effectiveArchiveAccessMode == .officialMCP
            && !hasWorkingToken
            && !mcpSetupBannerDismissedThisSession
        let shouldPromptMCPSetup = AppSettings.mcpReconnectNeeded
            || isShowingOfficialMCPSetupPanel
            || needsTokenSetup

        if shouldPromptMCPSetup {
            showOfficialMCPSetupPanel()
            return
        }

        if shouldPresentStarterPackWelcomeBanner {
            let upsell = StarterPackUpsellCardView(theme: theme, compact: true, showsSkipButton: true)
            upsell.onConnectTapped = { [weak self] in
                self?.showOfficialMCPSetupPanel()
            }
            upsell.onSkipTapped = { [weak self] in
                self?.starterPackWelcomeBannerDismissed = true
                self?.showWelcomeSuggestionsPanel()
            }
            expertSuggestionLabel.isHidden = true
            expertSuggestionStack.addArrangedSubview(upsell)
            upsell.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor).isActive = true
            welcomeChipsView = nil
            expertSuggestionContainer.isHidden = false
            expertSuggestionContainer.alphaValue = 1
            relayoutPanels()
            return
        }

        let chips = WelcomeChipsView(
            theme: theme,
            suggestions: welcomeSuggestions
        )
        chips.onChipTapped = { [weak self] text in
            guard let self else { return }
            self.hideWelcomeSuggestionsPanel()
            self.inputField.stringValue = text
            self.inputSubmitted()
        }

        expertSuggestionLabel.isHidden = true
        expertSuggestionStack.addArrangedSubview(chips)
        chips.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor).isActive = true

        welcomeChipsView = chips
        expertSuggestionContainer.isHidden = false
        expertSuggestionContainer.alphaValue = 1
        relayoutPanels()
    }

    func firstRunConfigurationSignature() -> String {
        [
            "welcome:\(welcomePreviewMode.rawValue)",
            "archive:\(AppSettings.archiveAccessMode.rawValue)",
            "transport:\(AppSettings.preferredTransport.rawValue)",
            "official:\(AppSettings.hasDetectedOfficialMCPConfiguration ? "1" : "0")",
            "token:\(AppSettings.officialLennyMCPToken != nil ? "1" : "0")",
            "openai:\(AppSettings.openAIAPIKey != nil ? "1" : "0")",
            "setup:\(requiresInitialConnectionSetup ? "1" : "0")"
        ].joined(separator: "|")
    }

    func refreshFirstRunStateIfNeeded(forceRefresh: Bool = false) {
        let signature = firstRunConfigurationSignature()
        guard forceRefresh || lastObservedFirstRunConfigurationSignature != signature else { return }

        lastObservedFirstRunConfigurationSignature = signature
        starterPackWelcomeBannerDismissed = false
        currentWelcomeArchiveMode = nil
        currentWelcomeSuggestions = []
        lastRenderedWelcomeSignature = nil
        lastObservedWelcomePreviewMode = welcomePreviewMode

        guard isShowingInitialWelcomeState, !isExpertMode else { return }

        if requiresInitialConnectionSetup {
            onRefreshSetupState?()
            return
        }

        showWelcomeGreeting(forceRefresh: true)
    }

    func refreshWelcomePreviewIfNeeded() {
        refreshFirstRunStateIfNeeded()
    }

    func hideWelcomeSuggestionsPanel() {
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        welcomeChipsView = nil
        expertSuggestionContainer.isHidden = true
        expertSuggestionContainer.alphaValue = 0
        relayoutPanels()
    }
}
