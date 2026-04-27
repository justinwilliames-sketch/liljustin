import Foundation

enum AppSettings {

    // MARK: - Model enums

    enum ClaudeModel: String, CaseIterable {
        case `default`
        case opus46 = "claude-opus-4-6"
        case sonnet46 = "claude-sonnet-4-6"
        case haiku45 = "claude-haiku-4-5-20251001"

        var label: String {
            switch self {
            case .default: return "Claude"
            case .opus46: return "Claude Opus 4.6"
            case .sonnet46: return "Claude Sonnet 4.6"
            case .haiku45: return "Claude Haiku 4.5"
            }
        }
    }

    enum OpenAIModel: String, CaseIterable {
        case gpt54 = "gpt-5.4"
        case gpt54Pro = "gpt-5.4-pro"
        case gpt54Mini = "gpt-5.4-mini"
        case gpt54Nano = "gpt-5.4-nano"
        case gpt41 = "gpt-4.1"
        case gpt5 = "gpt-5"
        case gpt5Mini = "gpt-5-mini"
        case gpt5Nano = "gpt-5-nano"

        var label: String {
            switch self {
            case .gpt54: return "GPT-5.4"
            case .gpt54Pro: return "GPT-5.4 Pro"
            case .gpt54Mini: return "GPT-5.4 mini"
            case .gpt54Nano: return "GPT-5.4 nano"
            case .gpt41: return "GPT-4.1"
            case .gpt5: return "GPT-5"
            case .gpt5Mini: return "GPT-5 mini"
            case .gpt5Nano: return "GPT-5 nano"
            }
        }
    }

    enum CodexModel: String, CaseIterable {
        case `default`
        case gpt54 = "gpt-5.4"
        case gpt54Mini = "gpt-5.4-mini"
        case gpt53Codex = "gpt-5.3-codex"

        var label: String {
            switch self {
            case .default: return "Codex"
            case .gpt54: return "GPT-5.4"
            case .gpt54Mini: return "GPT-5.4 mini"
            case .gpt53Codex: return "GPT-5.3 Codex"
            }
        }
    }

    enum PreferredTransport: String {
        case automatic
        case claudeCode
        case codex
        case openAIAPI
    }

    enum ArchiveAccessMode: String {
        case starterPack
        case officialMCP
    }

    enum WelcomePreviewMode: String, CaseIterable {
        case live
        case starterPackWithBanner
        case starterPackConnected
        case officialConnected

        var label: String {
            switch self {
            case .live:                 return "Live behavior"
            case .starterPackWithBanner: return "Starter Pack + banner"
            case .starterPackConnected: return "Starter Pack, already connected"
            case .officialConnected:    return "Official MCP connected"
            }
        }
    }

    enum OfficialMCPSource: String, CaseIterable {
        case claudeGlobalConfig
        case codexGlobalConfig
        case settingsToken
        case environmentToken

        var label: String {
            switch self {
            case .claudeGlobalConfig: return "Claude Code"
            case .codexGlobalConfig:  return "Codex"
            case .settingsToken:      return "saved token"
            case .environmentToken:   return "shell token"
            }
        }
    }

    // MARK: - UserDefaults keys

    static let preferredTransportKey              = "preferredTransport"
    static let hasExplicitPreferredTransportChoiceKey = "hasExplicitPreferredTransportChoice"
    static let archiveAccessModeKey              = "archiveAccessMode"
    static let hasExplicitStarterPackChoiceKey   = "hasExplicitStarterPackChoice"
    static let officialLennyMCPTokenKey          = "officialLennyMCPToken"
    static let openAIAPIKeyKey                   = "openAIAPIKey"
    static let debugLoggingEnabledKey            = "debugLoggingEnabled"
    static let preferredClaudeModelKey           = "preferredClaudeModel"
    static let preferredCodexModelKey            = "preferredCodexModel"
    static let preferredOpenAIModelKey           = "preferredOpenAIModel"
    static let welcomePreviewModeKey             = "welcomePreviewMode"
    static let mcpReconnectNeededKey             = "mcpReconnectNeeded"
    static let launchAtLoginKey                  = "launchAtLogin"

    // MARK: - Preferences

    /// Run at login. Defaults to ON for first-install users (the dock
    /// companion is ambient — most users want it back after restart
    /// without thinking about it). Wired via SMAppService.mainApp; the
    /// first call to `applyLaunchAtLoginPreference()` triggers the OS
    /// permission grant in System Settings → General → Login Items.
    static var launchAtLoginEnabled: Bool {
        get {
            // If the user has never explicitly set this, default to ON.
            if UserDefaults.standard.object(forKey: launchAtLoginKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: launchAtLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
        }
    }

    static var preferredTransport: PreferredTransport {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredTransportKey) ?? PreferredTransport.automatic.rawValue
            return PreferredTransport(rawValue: rawValue) ?? .automatic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredTransportKey) }
    }

    static var hasExplicitPreferredTransportChoice: Bool {
        get { UserDefaults.standard.bool(forKey: hasExplicitPreferredTransportChoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasExplicitPreferredTransportChoiceKey) }
    }

    static var archiveAccessMode: ArchiveAccessMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: archiveAccessModeKey) ?? defaultArchiveAccessMode.rawValue
            return ArchiveAccessMode(rawValue: rawValue) ?? .starterPack
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: archiveAccessModeKey) }
    }

    static var hasStoredArchiveAccessModePreference: Bool {
        UserDefaults.standard.object(forKey: archiveAccessModeKey) != nil
    }

    /// True only when the user explicitly clicked "Starter Pack" in the source pane.
    /// Programmatically written defaults do NOT set this flag.
    static var hasExplicitStarterPackChoice: Bool {
        get { UserDefaults.standard.bool(forKey: hasExplicitStarterPackChoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasExplicitStarterPackChoiceKey) }
    }

    static var officialLennyMCPToken: String? {
        get {
            let value = UserDefaults.standard.string(forKey: officialLennyMCPTokenKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: officialLennyMCPTokenKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: officialLennyMCPTokenKey)
            }
        }
    }

    static var openAIAPIKey: String? {
        get {
            let value = UserDefaults.standard.string(forKey: openAIAPIKeyKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: openAIAPIKeyKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: openAIAPIKeyKey)
            }
        }
    }

    static var effectiveArchiveAccessMode: ArchiveAccessMode {
        // An explicit user choice to stay on Starter Pack always wins — but only
        // if the user actually clicked the radio button (not just an auto-written default).
        if hasExplicitStarterPackChoice {
            return .starterPack
        }
        // Native CLI MCP config activates official mode automatically.
        let sources = detectedOfficialMCPSources
        if sources.contains(.claudeGlobalConfig) || sources.contains(.codexGlobalConfig) {
            return .officialMCP
        }
        return sources.isEmpty ? .starterPack : .officialMCP
    }

    static var defaultArchiveAccessMode: ArchiveAccessMode {
        detectedOfficialMCPSources.isEmpty ? .starterPack : .officialMCP
    }

    static var debugLoggingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: debugLoggingEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: debugLoggingEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: debugLoggingEnabledKey) }
    }

    static var preferredClaudeModel: ClaudeModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredClaudeModelKey) ?? ClaudeModel.default.rawValue
            return ClaudeModel(rawValue: rawValue) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredClaudeModelKey) }
    }

    static var preferredCodexModel: CodexModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredCodexModelKey) ?? CodexModel.default.rawValue
            return CodexModel(rawValue: rawValue) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredCodexModelKey) }
    }

    static var preferredOpenAIModel: OpenAIModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredOpenAIModelKey) ?? OpenAIModel.gpt54Mini.rawValue
            return OpenAIModel(rawValue: rawValue) ?? .gpt54Mini
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredOpenAIModelKey) }
    }

    /// Persists across app restarts — set when MCP auth fails, cleared when
    /// the user saves a token, dismisses the banner with X, or picks Starter Pack.
    static var mcpReconnectNeeded: Bool {
        get { UserDefaults.standard.bool(forKey: mcpReconnectNeededKey) }
        set { UserDefaults.standard.set(newValue, forKey: mcpReconnectNeededKey) }
    }

    static var welcomePreviewMode: WelcomePreviewMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: welcomePreviewModeKey) ?? WelcomePreviewMode.live.rawValue
            return WelcomePreviewMode(rawValue: rawValue) ?? .live
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: welcomePreviewModeKey) }
    }

    static var showsDeveloperTools: Bool {
        ProcessInfo.processInfo.arguments.contains("#debug")
    }

    // MARK: - Reset

    static func resetAllData() throws {
        let defaults = UserDefaults.standard
        let managedKeys = [
            preferredTransportKey,
            hasExplicitPreferredTransportChoiceKey,
            archiveAccessModeKey,
            hasExplicitStarterPackChoiceKey,
            officialLennyMCPTokenKey,
            openAIAPIKeyKey,
            debugLoggingEnabledKey,
            preferredClaudeModelKey,
            preferredCodexModelKey,
            preferredOpenAIModelKey,
            welcomePreviewModeKey,
            "hasCompletedOnboarding",
            mcpReconnectNeededKey
        ]

        for key in managedKeys {
            defaults.removeObject(forKey: key)
        }

        try removeOfficialMCPConfiguration()
        refreshDetectionState()
        NotificationCenter.default.post(name: .lilLennyDidResetData, object: nil)
    }
}

extension Notification.Name {
    static let lilLennyDidResetData = Notification.Name("LilLennyDidResetData")
}

// MARK: - Launch at login (SMAppService)

import ServiceManagement

extension AppSettings {

    /// Reconcile the OS login-item registration with the stored
    /// `launchAtLoginEnabled` preference. Called once at app launch,
    /// and again whenever the user toggles the setting.
    ///
    /// First call after install will register the app with the OS,
    /// which triggers macOS to surface a System Settings → General
    /// → Login Items prompt for the user to approve.
    static func applyLaunchAtLoginPreference() {
        let service = SMAppService.mainApp
        let want = launchAtLoginEnabled
        do {
            switch service.status {
            case .enabled:
                if !want { try service.unregister() }
            case .notRegistered, .notFound:
                if want { try service.register() }
            case .requiresApproval:
                // User has the registration but hasn't approved it yet
                // in System Settings. Nothing we can force from here —
                // the OS handles the prompt. Keep our preference in
                // sync so a re-toggle in our UI still works.
                break
            @unknown default:
                if want { try service.register() }
            }
        } catch {
            NSLog("[LilJustin] Launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
