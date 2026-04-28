import AppKit

extension WalkerCharacter {
    func openOnboardingPopover() {
        showingCompletion = false
        hideBubble()

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        setFacing(.front)

        if popoverWindow == nil {
            createPopoverWindow()
        }

        terminalView?.inputField.isEditable = false
        terminalView?.updatePlaceholder("")

        // Reset transcript to a clean state on each call so repeated clicks don't accumulate content
        if let tv = terminalView {
            tv.currentAssistantText = ""
            let views = tv.transcriptStack.arrangedSubviews
            views.forEach { view in
                tv.transcriptStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }

        let welcome = """
        LilJustin — founder of Orbit, on your desktop.

        Ask about lifecycle, deliverability, Braze, retention. The Orbit playbook, in dock form.
        """
        terminalView?.appendStreamingText(welcome)
        terminalView?.endStreaming()

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        syncPopoverPinState()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.closeOnboarding()
        }
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closeOnboarding(); return nil }
            return event
        }
    }

    private func closeOnboarding() {
        removeEventMonitors()
        expertSwitcherPopover?.close()
        popoverWindow?.orderOut(nil)
        popoverWindow = nil
        terminalView = nil
        isIdleForPopover = false
        isOnboarding = false
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.0...3.0)
        setFacing(.front)
        controller?.completeOnboarding()
    }

    func openPopover() {
        // Real user interaction → wake from sleep + reset idle timer.
        noteUserInteraction()

        if let siblings = controller?.characters {
            for sibling in siblings where sibling !== self && sibling.isIdleForPopover {
                if sibling.isPopoverPinned { continue }
                sibling.closePopover()
            }
        }

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        setFacing(.front)

        showingCompletion = false
        hideBubble()

        if popoverWindow == nil {
            createPopoverWindow()
        }

        // Reshuffle the welcome chips on every popover open. The pool is
        // 1:1 with the Orbit guide library (87 chips); 4 are shown at a
        // time, drawn at random so the user sees fresh prompts each time.
        terminalView?.currentWelcomeSuggestions = []
        terminalView?.lastRenderedWelcomeSignature = nil

        if claudeSession == nil {
            let session = ClaudeSession()
            session.focusedExpert = focusedExpert
            claudeSession = session
            wireSession(session)
            session.start()
        } else if claudeSession?.isRunning != true {
            claudeSession?.focusedExpert = focusedExpert
            claudeSession?.start()
        }

        refreshPopoverHeader()
        restoreTranscriptState()

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
        syncPopoverPinState()

        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }

        refreshPopoverEventMonitors()
    }

    @objc func expandToggleTapped() {
        guard let popover = popoverWindow, let screen = NSScreen.main else { return }
        isPopoverExpanded = !isPopoverExpanded

        let charFrame = window.frame
        let visibleFrame = screen.visibleFrame
        let currentFrame = popover.frame

        // ── New height ──────────────────────────────────────────────
        let newHeight: CGFloat
        if isPopoverExpanded {
            let popoverBottomY = charFrame.maxY - 10
            let maxAvailable = visibleFrame.maxY - 4 - popoverBottomY
            newHeight = min(max(maxAvailable, 500), visibleFrame.height - 20)
        } else {
            newHeight = WalkerCharacter.defaultPopoverHeight
        }

        // ── New width ───────────────────────────────────────────────
        // 50% wider on expand. Falls back to the default width when
        // collapsing. Also clamped to the visible screen so the
        // popover never overflows the desktop on narrow displays.
        let baseWidth = WalkerCharacter.defaultPopoverWidth
        let expandedWidth = min(baseWidth * 1.5, visibleFrame.width - 8)
        let newWidth: CGFloat = isPopoverExpanded ? expandedWidth : baseWidth

        // ── New origin — keep the tail centred on the sprite ───────
        let desiredBottomY = charFrame.maxY - 10
        let clampedBottomY = max(
            visibleFrame.minY + 4,
            min(desiredBottomY, visibleFrame.maxY - newHeight - 4)
        )
        var newX = charFrame.midX - newWidth / 2
        newX = max(visibleFrame.minX + 4, min(newX, visibleFrame.maxX - newWidth - 4))

        let newFrame = NSRect(x: newX, y: clampedBottomY, width: newWidth, height: newHeight)

        // Animate the window frame AND the bubble shell path together
        // so the speech-bubble outline stays in sync with the content
        // throughout the resize. Without the explicit path rebuild,
        // the CAShapeLayer keeps its original-size path while the
        // window grows around it — which is exactly what produced
        // the "detached title" Sir saw on the v0.1.21 expand attempt.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            popover.animator().setFrame(newFrame, display: true)
            rebuildPopoverBubbleShellPath(forSize: newFrame.size, animated: true, duration: 0.28)
        }

        let symbolName = isPopoverExpanded
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            popoverExpandButton?.image = img.withSymbolConfiguration(config)
        }
    }

    /// Rebuild the speech-bubble outline path to match a new window
    /// size. Must be called whenever the popover frame changes —
    /// without this, the `CAShapeLayer` keeps the path it was given
    /// at creation, the bubble outline stays the original size, and
    /// any new content stretches outside the drawn outline (the
    /// "detached title" bug).
    ///
    /// When `animated` is true the path change is wrapped in a
    /// `CABasicAnimation` so the outline morphs alongside the window
    /// frame animation rather than snapping to the new shape on
    /// frame 0.
    func rebuildPopoverBubbleShellPath(forSize size: CGSize, animated: Bool, duration: CFTimeInterval = 0.28) {
        guard let bubbleShape = popoverBubbleShape else { return }

        let newPath = WalkerCharacter.bubbleShellPath(
            size: size,
            tailHeight: WalkerCharacter.popoverTailHeight,
            tailWidth: WalkerCharacter.popoverTailWidth,
            cornerRadius: 18
        )

        if animated {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = bubbleShape.path
            anim.toValue = newPath
            anim.duration = duration
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bubbleShape.add(anim, forKey: "pathResize")
        }
        bubbleShape.frame = CGRect(origin: .zero, size: size)
        bubbleShape.path = newPath
    }

    func closePopover() {
        guard isIdleForPopover else { return }

        expertSwitcherPopover?.close()
        isPopoverExpanded = false
        if let btn = popoverExpandButton,
           let img = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            btn.image = img.withSymbolConfiguration(config)
        }
        // Reset window to default size before hiding so the next
        // open starts collapsed. Both width and height reset — without
        // the width reset a popover that was expanded then closed
        // would reopen at the expanded width with no visual cue.
        if let popover = popoverWindow {
            let f = popover.frame
            let needsResize = f.width != WalkerCharacter.defaultPopoverWidth
                || f.height != WalkerCharacter.defaultPopoverHeight
            if needsResize {
                let resetSize = CGSize(
                    width: WalkerCharacter.defaultPopoverWidth,
                    height: WalkerCharacter.defaultPopoverHeight
                )
                let newFrame = NSRect(origin: f.origin, size: resetSize)
                popover.setFrame(newFrame, display: false)
                rebuildPopoverBubbleShellPath(forSize: resetSize, animated: false)
            }
        }

        popoverWindow?.orderOut(nil)
        removeEventMonitors()

        isIdleForPopover = false

        if showingCompletion {
            completionBubbleExpiry = CACurrentMediaTime() + 3.0
            showBubble(text: currentPhrase, isCompletion: true)
        } else if isClaudeBusy {
            if currentActivityStatus.isEmpty {
                currentPhrase = ""
                lastPhraseUpdate = 0
                updateThinkingPhrase()
                showBubble(text: currentPhrase, isCompletion: false)
            } else {
                hideBubble()
            }
        } else {
            setFacing(.front)
        }

        let delay = Double.random(in: 2.0...5.0)
        pauseEndTime = CACurrentMediaTime() + delay
    }

    @objc func togglePopoverPinned() {
        isPopoverPinned.toggle()
        syncPopoverPinState()
        refreshPopoverEventMonitors()
    }

    /// Clear the current conversation and reset the popover to the
    /// welcome state (4 random prompt chips + greeting). The session's
    /// in-memory history map is wiped for the active expert key, so
    /// the next user message starts a fresh thread with no carry-over
    /// context. Pending follow-up chips are cleared too. Lives on the
    /// popover-control axis next to settings/expand/pin/close.
    @objc func clearConversationTapped() {
        guard let session = claudeSession else { return }

        // Wipe the in-memory history for the current conversation
        // partition (the focused expert's key, or the default `lenny`
        // key when there's no expert focus — which is always true in
        // LilJustin since experts are disabled).
        let key = session.key(for: focusedExpert)
        session.conversations[key] = nil

        // Reset all transient transcript state — live status, expert
        // suggestions, follow-up chips, attachments, the input field —
        // so the next interaction looks like a fresh popover open.
        terminalView?.clearFollowUpChips()
        terminalView?.clearTranscriptSuggestionView()
        terminalView?.clearLiveStatus()
        terminalView?.endStreaming()
        terminalView?.pendingAttachments.removeAll()
        terminalView?.refreshAttachmentPreviews()
        terminalView?.inputField.stringValue = ""
        terminalView?.currentAssistantText = ""
        terminalView?.deferredExpertSuggestions = []

        // Re-render with empty history → triggers the welcome state
        // path with fresh chip suggestions. forceRefresh: true reshuffles
        // the 4 prompt chips so a cleared conversation never reopens
        // with the same chip set as the one that was just dismissed.
        terminalView?.replayConversation([], expertSuggestions: [])
        terminalView?.showWelcomeGreeting(forceRefresh: true)

        // Refocus the input so Sir can immediately type the next thing.
        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }
    }

    @objc func closePopoverFromButton() {
        isPopoverPinned = false
        syncPopoverPinState()
        if isOnboarding {
            closeOnboarding()
            return
        }
        closePopover()
    }

    @objc func returnToGenieTapped() {
        controller?.returnToGenie()
    }

    func syncPopoverPinState() {
        if let pinButton = popoverPinButton {
            let symbolName = isPopoverPinned ? "pin.fill" : "pin"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: isPopoverPinned ? "Unpin" : "Pin") {
                let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
                pinButton.image = image.withSymbolConfiguration(config)
            }

            let t = resolvedTheme
            let normalBg = isPopoverPinned
                ? t.accentColor.withAlphaComponent(0.22).cgColor
                : t.separatorColor.withAlphaComponent(0.10).cgColor
            let hoverBg = isPopoverPinned
                ? t.accentColor.withAlphaComponent(0.32).cgColor
                : t.separatorColor.withAlphaComponent(0.22).cgColor
            pinButton.normalBg = normalBg
            pinButton.hoverBg = hoverBg
            pinButton.layer?.backgroundColor = normalBg
            pinButton.contentTintColor = isPopoverPinned ? t.accentColor : t.textDim
        }

        terminalView?.isPinnedOpen = isPopoverPinned
    }

    func refreshPopoverEventMonitors() {
        removeEventMonitors()
        guard isIdleForPopover, !isPopoverPinned else { return }

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let popover = self.popoverWindow else { return }
            let popoverFrame = popover.frame
            let charFrame = self.window.frame
            let switcherFrame = self.expertSwitcherPopover?.contentViewController?.view.window?.frame
            let isInsideSwitcher = switcherFrame?.contains(NSEvent.mouseLocation) == true
            if !popoverFrame.contains(NSEvent.mouseLocation) &&
                !charFrame.contains(NSEvent.mouseLocation) &&
                !isInsideSwitcher {
                self.closePopover()
            }
        }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                if self?.expertSwitcherPopover?.isShown == true {
                    self?.expertSwitcherPopover?.performClose(nil)
                    return nil
                }
                self?.closePopover()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
    }

    func updateInputPlaceholder() {
        if let expert = focusedExpert {
            terminalView?.updatePlaceholder("Ask \(expert.name) a follow-up")
        } else {
            terminalView?.updatePlaceholder("Ask a question or drop in a file")
        }
    }
}
