import AppKit

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Hoverable chip card for welcome suggestions

class HoverChipView: NSView {
    var onTapped: (() -> Void)?
    private let normalBg: CGColor
    private let hoverBg: CGColor
    private weak var contentStack: NSStackView?

    init(symbol: String, label: String, theme: PopoverTheme) {
        self.normalBg = theme.inputBg.cgColor
        self.hoverBg = theme.accentColor.withAlphaComponent(0.06).cgColor
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = normalBg
        layer?.cornerRadius = 10
        layer?.borderWidth = 1.0
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.55).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 10
        hStack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack = hStack
        addSubview(hStack)

        let minimumHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        minimumHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            minimumHeight,
        ])

        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = theme.accentColor
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        hStack.addArrangedSubview(iconView)

        let textLabel = NSTextField(labelWithString: label)
        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        hStack.addArrangedSubview(textLabel)

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        guard let contentStack else { return super.intrinsicContentSize }
        let fitting = contentStack.fittingSize
        return NSSize(width: NSView.noIntrinsicMetric, height: max(48, fitting.height))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().layer?.backgroundColor = hoverBg
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().layer?.backgroundColor = normalBg
        }
    }

    override func mouseDown(with event: NSEvent) {
        onTapped?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Welcome chips grid

class WelcomeChipsView: NSView {
    var onChipTapped: ((String) -> Void)?
    private let theme: PopoverTheme
    private weak var outerStackView: NSStackView?

    private let suggestions: [(String, String, String)]

    static let defaultSuggestionPool: [(String, String, String)] = [
        ("envelope.badge",            "Build a lifecycle programme from scratch",      "How would you build a lifecycle marketing programme from scratch for an early-stage consumer app?"),
        ("arrow.triangle.2.circlepath", "Win-back flow that actually performs",        "What does a win-back flow that actually performs look like in 2026?"),
        ("rectangle.split.3x3",       "Braze vs HubSpot for a Series A startup",       "Braze vs HubSpot for a Series A consumer startup — how would you pick?"),
        ("person.crop.square.filled.and.at.rectangle", "Liquid personalisation patterns I should know", "What Liquid personalisation patterns should I know for serious lifecycle work?"),
        ("chart.bar.xaxis",           "How to measure CRM impact properly",             "How should I measure CRM impact properly without the usual vanity metrics?"),
        ("waveform.path.ecg",         "Where AI workflows actually pay off in CRM",     "Where do AI workflows actually pay off in a lifecycle marketing function today?"),
        ("hammer",                    "AI for trades businesses — where to start",      "If I run a trades business, where should I start with AI workflows?"),
        ("person.2.wave.2",           "Activation funnel diagnostic checklist",         "Give me a checklist for diagnosing a broken activation funnel."),
        ("creditcard",                "Subscription churn — first three things to look at", "Subscription churn is creeping up. What are the first three places I should look?"),
        ("briefcase",                 "Path to Head of CRM",                            "What's the realistic path from CRM Manager to Head of CRM?")
    ]

    // Kept for upstream compatibility — never surfaced now that LilJustin has no archive mode.
    static let starterPackSuggestionPool: [(String, String, String)] = defaultSuggestionPool

    init(theme: PopoverTheme, suggestions: [(String, String, String)] = WelcomeChipsView.defaultSuggestionPool) {
        self.theme = theme
        self.suggestions = suggestions
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 8
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStackView = outerStack
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let pairs = stride(from: 0, to: suggestions.count, by: 2).map { i -> [(String, String, String)] in
            let end = min(i + 2, suggestions.count)
            return Array(suggestions[i..<end])
        }

        for pair in pairs {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.alignment = .centerY
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for (symbol, label, sendText) in pair {
                let chip = HoverChipView(symbol: symbol, label: label, theme: theme)
                chip.onTapped = { [weak self] in self?.onChipTapped?(sendText) }
                rowStack.addArrangedSubview(chip)
            }
            outerStack.addArrangedSubview(rowStack)
            rowStack.widthAnchor.constraint(equalTo: outerStack.widthAnchor).isActive = true
        }

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override var intrinsicContentSize: NSSize {
        guard let outerStackView else { return super.intrinsicContentSize }
        let fitting = outerStackView.fittingSize
        return NSSize(width: NSView.noIntrinsicMetric, height: fitting.height)
    }
}

class ConnectionSetupCardView: NSView {
    var onOpenSettings: (() -> Void)?

    private let theme: PopoverTheme

    init(theme: PopoverTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = theme.inputBg.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.45).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        let title = NSTextField(wrappingLabelWithString: "Set up your AI connection")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = theme.textPrimary
        title.maximumNumberOfLines = 0
        stack.addArrangedSubview(title)
        title.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let body = NSTextField(wrappingLabelWithString: "Open Settings to connect Claude, Codex/ChatGPT, or OpenAI. Once one is connected, LilJustin is ready to chat.")
        body.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        body.textColor = theme.textDim
        body.maximumNumberOfLines = 0
        stack.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let settingsButton = HoverButton(title: "", target: self, action: #selector(openSettingsTapped))
        settingsButton.isBordered = false
        settingsButton.wantsLayer = true
        settingsButton.normalBg = theme.accentColor.cgColor
        settingsButton.hoverBg = theme.accentColor.withAlphaComponent(0.82).cgColor
        settingsButton.layer?.backgroundColor = settingsButton.normalBg
        settingsButton.layer?.cornerRadius = 12
        settingsButton.horizontalContentPadding = 16
        settingsButton.verticalContentPadding = 6
        settingsButton.attributedTitle = NSAttributedString(string: "Open Settings", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
        stack.addArrangedSubview(settingsButton)

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @objc private func openSettingsTapped() {
        onOpenSettings?()
    }
}
