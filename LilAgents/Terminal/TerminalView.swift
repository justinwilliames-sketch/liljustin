import AppKit

class TerminalView: NSView {
    enum TranscriptReplayRestoreStrategy {
        case preserveVisiblePosition
        case focusUnreadBoundary(lastReadHistoryCount: Int)
    }

    let scrollView = NSScrollView()
    let transcriptContainer = FlippedView()
    let transcriptStack = NSStackView()
    let inputField = NSTextField()
    let liveStatusContainer = NSView()
    let liveStatusSpinner = NSProgressIndicator()
    let liveStatusAvatarView = NSImageView()
    let liveStatusLabel = NSTextField(labelWithString: "")
    let attachmentStrip = NSView()
    let attachmentScrollView = NSScrollView()
    let attachmentPreviewDocumentView = NSView()
    let attachmentPreviewStack = NSStackView()
    let attachmentHintLabel = NSTextField(labelWithString: "")
    let expertSuggestionContainer = NSView()
    let expertSuggestionLabel = NSTextField(labelWithString: "")
    let expertSuggestionStack = NSStackView()
    let attachButton = HoverButton(title: "", target: nil, action: nil)
    let sendButton = HoverButton(title: "", target: nil, action: nil)
    let composerStatusLabel = NSTextField(labelWithString: "Generating...")
    let returnButton = NSButton(title: "Back to LilJustin", target: nil, action: nil)
    var onSendMessage: ((String, [SessionAttachment]) -> Void)?
    var onStopRequested: (() -> Void)?
    var onReturnToLenny: (() -> Void)?
    var onSelectExpert: ((ResponderExpert) -> Void)?
    var onSelectExpertSuggestion: ((UUID, ResponderExpert) -> Void)?
    var onEditExpertSuggestion: ((UUID) -> Void)?
    var onTogglePinned: (() -> Void)?
    var onCloseRequested: (() -> Void)?
    var onRefreshSetupState: (() -> Void)?
    var onApprovalResponse: ((ClaudeSession.ApprovalChoice) -> Void)?
    var onReachedTranscriptBottom: (() -> Void)?

    var characterColor: NSColor?
    var themeOverride: PopoverTheme?
    var currentAssistantText = ""
    var isStreaming = false
    var placeholderText = "Ask a question or drop in a file"
    var welcomeChipsView: WelcomeChipsView?
    var pendingAttachments: [SessionAttachment] = []
    var expertSuggestionTargets: [String: ResponderExpert] = [:]
    var deferredExpertSuggestions: [ResponderExpert] = []
    var currentExpertSuggestions: [ResponderExpert] = []
    var lastPickedExpert: ResponderExpert?
    var isShowingInitialWelcomeState = false
    var transcriptSuggestionView: NSView?
    /// Tappable chip pair showing 2 LLM-generated follow-up prompts after
    /// each substantive assistant response. Lives at the bottom of the
    /// transcript stack, cleared when the user types or sends or when
    /// the next response begins streaming. Owned by TerminalView so the
    /// transcript replay path doesn't accidentally double-render.
    var followUpChipsView: FollowUpChipsView?
    var transcriptLiveStatusView: NSView?
    var transcriptApprovalView: NSView?
    var renderedConversationKey: String?
    var expertSuggestionsCollapsed = false
    var liveStatusAvatarTimer: Timer?
    var liveStatusAvatarPaths: [String] = []
    var liveStatusAvatarIndex = 0
    var streamingPresentationInterrupted = false
    var currentStreamingSpeakerName: String?
    var isPinnedOpen = false
    var isShowingDropTarget = false
    var isExpertMode = false
    var isReplayingTranscript = false
    var starterPackWelcomeBannerDismissed = false
    /// Session-only flag: set when the user explicitly dismisses the proactive
    /// MCP setup banner. Resets on the next app open so they get a reminder.
    var mcpSetupBannerDismissedThisSession = false
    /// Session-only flag: set when the user clicks "Skip for now" on the
    /// business-context survey card. Persistent dismissal lives in
    /// `AppSettings.markBusinessContextPromptShown()` (stamps the current
    /// app version). This flag avoids re-rendering the card after skip
    /// within the same session, even though the persistent stamp also
    /// suppresses it.
    var businessContextPromptDismissedThisSession = false
    var currentWelcomeArchiveMode: AppSettings.ArchiveAccessMode?
    var currentWelcomeSuggestions: [(String, String, String)] = []
    var lastRenderedWelcomeSignature: String?
    var lastObservedWelcomePreviewMode = AppSettings.welcomePreviewMode
    var isShowingOfficialMCPSetupPanel = false
    var requiresInitialConnectionSetup = false
    var lastObservedFirstRunConfigurationSignature: String?
    var settingsObserver: NSObjectProtocol?
    let officialMCPURL = URL(string: "https://get.yourorbit.team")!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    deinit {
        liveStatusAvatarTimer?.invalidate()
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    var theme: PopoverTheme {
        var t = themeOverride ?? PopoverTheme.current
        if let color = characterColor {
            t = t.withCharacterColor(color)
        }
        t = t.withCustomFont()
        return t
    }

    override func layout() {
        super.layout()
        relayoutPanels()
        propagateBubbleMaxWidth()
    }

    /// Tell every existing chat bubble what the maximum text-column
    /// width should be, based on the current transcript stack width.
    /// Called on every layout pass so bubbles re-flow when the popover
    /// toggles between default and expanded modes. Soft-capped at
    /// 720pt so very wide popovers don't produce hard-to-read line
    /// lengths; floored at 280 so the first layout pass with a
    /// not-yet-laid-out stack doesn't crush the bubbles.
    private func propagateBubbleMaxWidth() {
        let stackWidth = transcriptStack.bounds.width
        guard stackWidth > 0 else { return }
        let target = min(720, max(280, stackWidth))
        for view in transcriptStack.arrangedSubviews {
            if let bubble = view as? ChatBubbleView, bubble.maxBubbleWidth != target {
                bubble.maxBubbleWidth = target
            }
        }
    }

    func setReturnToLennyVisible(_ visible: Bool) {
        returnButton.isHidden = !visible
    }
}
