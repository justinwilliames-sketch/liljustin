import AppKit

extension WalkerCharacter {
    private static let thinkingPhrases = [
        "digging...", "searching...", "checking the archive...",
        "one sec...", "looking...", "pulling excerpts...",
        "finding the best answer..."
    ]

    private static let completionPhrases = ["found one!", "got it!", "ready!", "answer’s up", "here you go"]

    private static let bubbleH: CGFloat = 26
    static let expertNameTagH: CGFloat = 24
    private static let completionSounds: [(name: String, ext: String)] = [
        ("ping-aa", "mp3"), ("ping-bb", "mp3"), ("ping-cc", "mp3"),
        ("ping-dd", "mp3"), ("ping-ee", "mp3"), ("ping-ff", "mp3"),
        ("ping-gg", "mp3"), ("ping-hh", "mp3"), ("ping-jj", "m4a")
    ]

    private static var lastSoundIndex: Int = -1
    static var soundsEnabled = true

    func updateThinkingBubble() {
        // Hard suppression — when the chat popover is open, no ambient
        // bubbles ever show. The popover is the conversation surface;
        // a status/completion bubble next to it competes for attention
        // and looks like a leak.
        if popoverWindow?.isVisible == true {
            hideBubble()
            return
        }

        if isClaudeBusy && !currentActivityStatus.isEmpty {
            hideBubble()
            return
        }

        let now = CACurrentMediaTime()

        if showingCompletion {
            if now >= completionBubbleExpiry {
                showingCompletion = false
                hideBubble()
                return
            }
            if isIdleForPopover {
                completionBubbleExpiry += 1.0 / 60.0
                hideBubble()
            } else {
                showBubble(text: currentPhrase, isCompletion: true)
            }
            return
        }

        if isClaudeBusy && !isIdleForPopover {
            let oldPhrase = currentPhrase
            updateThinkingPhrase()
            if currentPhrase != oldPhrase && !oldPhrase.isEmpty && !phraseAnimating {
                animatePhraseChange(to: currentPhrase, isCompletion: false)
            } else if !phraseAnimating {
                showBubble(text: currentPhrase, isCompletion: false)
            }
        } else if !showingCompletion {
            hideBubble()
        }
    }

    func hideBubble() {
        if thinkingBubbleWindow?.isVisible ?? false {
            thinkingBubbleWindow?.orderOut(nil)
        }
    }

    private func animatePhraseChange(to newText: String, isCompletion: Bool) {
        guard let win = thinkingBubbleWindow, win.isVisible,
              let label = win.contentView?.viewWithTag(100) as? NSTextField else {
            showBubble(text: newText, isCompletion: isCompletion)
            return
        }
        phraseAnimating = true

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            label.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.showBubble(text: newText, isCompletion: isCompletion)
            label.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.allowsImplicitAnimation = true
                label.animator().alphaValue = 1.0
            }, completionHandler: {
                self?.phraseAnimating = false
            })
        })
    }

    func showBubble(text: String, isCompletion: Bool, multiline: Bool = false) {
        // Hard suppression — never show a bubble while the chat popover
        // is open (the popover IS the conversation surface).
        if popoverWindow?.isVisible == true {
            return
        }

        let t = resolvedTheme
        if thinkingBubbleWindow == nil {
            createThinkingBubble()
        }

        let padding: CGFloat = 16
        let font = t.bubbleFont
        let lineH = ceil(("Xg" as NSString).size(withAttributes: [.font: font]).height)

        // Status / completion bubbles stay narrow + single-line so they
        // ellipsis-clip cleanly. Ambient comments get a wider bubble
        // and up to 2 lines of word-wrapped text so a one-sentence
        // remark fits visibly.
        let maxBubbleW: CGFloat = multiline ? 340 : 220
        let maxLines: Int = multiline ? 2 : 1

        let availableLabelWidth = maxBubbleW - padding
        let wrapAttrs: [NSAttributedString.Key: Any] = [.font: font]
        let wrappedRect = (text as NSString).boundingRect(
            with: CGSize(width: availableLabelWidth, height: lineH * CGFloat(maxLines) + 4),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: wrapAttrs
        )
        let neededLines = min(maxLines, max(1, Int(ceil(wrappedRect.height / lineH))))
        let textBlockHeight = lineH * CGFloat(neededLines)

        // Bubble height: text block + vertical padding (8 top + 8 bottom).
        // Single-line keeps the original 26px so the existing pill aesthetic
        // for status bubbles is preserved.
        let bubbleH: CGFloat = neededLines == 1 ? Self.bubbleH : textBlockHeight + 16
        // Width fits the wrapped text plus horizontal padding, capped.
        let measuredW = ceil(wrappedRect.width) + padding * 2
        let bubbleW = min(maxBubbleW, max(measuredW, 48))
        // Pill for single-line, gentler corners for multi-line.
        let bubbleRadius: CGFloat = neededLines == 1 ? bubbleH / 2 : 14

        let charFrame = window.frame
        let x = charFrame.midX - bubbleW / 2
        // Anchor bubble bottom higher when multi-line so it sits above
        // the head with breathing room.
        let yBase = charFrame.origin.y + charFrame.height * (multiline ? 0.92 : 0.88)
        let y = yBase + (neededLines > 1 ? CGFloat(neededLines - 1) * lineH * 0.5 : 0)
        thinkingBubbleWindow?.setFrame(CGRect(x: x, y: y, width: bubbleW, height: bubbleH), display: false)

        let borderColor = isCompletion ? t.bubbleCompletionBorder.cgColor : t.bubbleBorder.cgColor
        let textColor = isCompletion ? t.bubbleCompletionText : t.bubbleText

        if let container = thinkingBubbleWindow?.contentView {
            container.frame = NSRect(x: 0, y: 0, width: bubbleW, height: bubbleH)
            container.layer?.backgroundColor = t.bubbleBg.cgColor
            container.layer?.cornerRadius = bubbleRadius
            container.layer?.borderColor = borderColor
            if let label = container.viewWithTag(100) as? NSTextField {
                label.font = font
                let labelW = bubbleW - padding
                let labelX = (bubbleW - labelW) / 2
                let labelY = round((bubbleH - textBlockHeight) / 2) - 1
                label.frame = NSRect(x: labelX, y: labelY, width: labelW, height: textBlockHeight + 2)
                label.stringValue = text
                label.textColor = textColor
                label.lineBreakMode = .byTruncatingTail
                label.maximumNumberOfLines = maxLines
                label.cell?.wraps = multiline
                label.cell?.isScrollable = false
                label.alignment = .center
            }
        }

        if !(thinkingBubbleWindow?.isVisible ?? false) {
            thinkingBubbleWindow?.alphaValue = 1.0
            thinkingBubbleWindow?.orderFrontRegardless()
        }
    }

    func updateThinkingPhrase() {
        let now = CACurrentMediaTime()
        if currentPhrase.isEmpty || now - lastPhraseUpdate > Double.random(in: 3.0...5.0) {
            var next = Self.thinkingPhrases.randomElement() ?? "..."
            while next == currentPhrase && Self.thinkingPhrases.count > 1 {
                next = Self.thinkingPhrases.randomElement() ?? "..."
            }
            currentPhrase = next
            lastPhraseUpdate = now
        }
    }

    func showCompletionBubble() {
        currentPhrase = Self.completionPhrases.randomElement() ?? "done!"
        showingCompletion = true
        completionBubbleExpiry = CACurrentMediaTime() + 3.0
        lastPhraseUpdate = 0
        phraseAnimating = false
        if !isIdleForPopover {
            showBubble(text: currentPhrase, isCompletion: true)
        }
    }

    func createThinkingBubble() {
        let t = resolvedTheme
        let w: CGFloat = 80
        let h = Self.bubbleH
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: w, height: h),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 5)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = t.bubbleBg.cgColor
        container.layer?.cornerRadius = h / 2
        container.layer?.borderWidth = 1
        container.layer?.borderColor = t.bubbleBorder.cgColor

        let font = t.bubbleFont
        let lineH = ceil(("Xg" as NSString).size(withAttributes: [.font: font]).height)
        let labelY = round((h - lineH) / 2) - 1

        let label = NSTextField(labelWithString: "")
        label.font = font
        label.textColor = t.bubbleText
        label.alignment = .center
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.frame = NSRect(x: 0, y: labelY, width: w, height: lineH + 2)
        label.tag = 100
        container.addSubview(label)

        win.contentView = container
        thinkingBubbleWindow = win
    }

    static func playSelectionSound() {
        guard Self.soundsEnabled else { return }
        var idx: Int
        repeat {
            idx = Int.random(in: 0..<Self.completionSounds.count)
        } while idx == Self.lastSoundIndex && Self.completionSounds.count > 1
        Self.lastSoundIndex = idx

        let s = Self.completionSounds[idx]
        if let url = Bundle.main.url(forResource: s.name, withExtension: s.ext, subdirectory: "Sounds"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
        }
    }

    func playCompletionSound() {
        Self.playSelectionSound()
    }

    // MARK: - Ambient bubbles
    // Hardcoded line pool for v0.1.14. v0.1.15 will replace this with
    // a one-shot LLM call to whichever provider is connected so the
    // comments are fresh + reactive to whatever Sir is working on.
    // Until then: ~30 short, dry, Orbit-voice ambient remarks.
    static let ambientLines: [String] = [
        "Open rate is just Apple's image proxy waving hello.",
        "Welcome flows: 47 things you didn't need to know yet.",
        "Click rate has a job. Open rate has a hobby.",
        "If your A/B test had a 200% novelty effect, you discovered nothing.",
        "Three-bullet symmetry is the AI default. The world isn't always three-shaped.",
        "Apple pre-fetches your email before the user wakes up. Lovely system.",
        "BIMI's a logo in the inbox. Worth setting up. Don't tell finance the ROI.",
        "Win-back at 60 days. Sunset at 180. Most lists do neither.",
        "Liquid is a typing test for marketers.",
        "The deliverability mental model fits on one slide. Most decks use four.",
        "If your A/B test winner had n=300, congrats — you measured noise.",
        "Holdouts are the one tool every program skips and then debates whether it works.",
        "Subject lines that survive contact are the ones written for inbox preview, not the body.",
        "Send-time optimisation is a nice idea, until you remember Apple Mail.",
        "Spam complaints under 0.1%. The 0.3% line is where deliverability dies, slowly.",
        "Naming conventions live in the documentation nobody reads. Enforce in the tooling.",
        "List hygiene: trim the disengaged, keep the soft-bouncers under watch, leave the engaged alone.",
        "If your unsubscribe page just unsubscribes, you're missing the cheapest preference centre on earth.",
        "Cohort retention curves tell you whether the program works. Open rate tells you the dashboard works.",
        "DMARC at p=quarantine before p=reject. The internet has long memory.",
        "The first 72 hours decide who activates. The next 12 weeks just confirm it.",
        "Browse abandonment is the program that sits between ads and cart, and most teams forget it.",
        "Replenishment emails are the lifecycle flow that buys itself.",
        "Win-back patterns: the one that's run, the one that should be, and the one nobody tries.",
        "Personalisation that doesn't feel creepy uses behavioural data, not declared data.",
        "Onboarding emails: signup → activated. Anything else is content marketing.",
        "Your CRM stack will eventually become an archaeological dig. Plan for the dig.",
        "Plain-text versions still matter in 2026. Spam filters are why.",
        "If you can't tell me your incremental open-to-purchase rate, your attribution stack is decorative.",
        "Brand voice in lifecycle: sound like you, not the generic SaaS CRM voice.",
    ]

    /// Per-tick check called from update() while the character is
    /// genuinely idle. Picks a random ambient line, shows it as a
    /// multi-line bubble, and re-schedules the next appearance.
    func tickAmbientBubble() {
        let now = CACurrentMediaTime()

        // Ambient bubbles are forbidden during chat, sleep, expert
        // focus, or while a model turn is in flight. The hard guards
        // that already protect status bubbles in showBubble() also
        // apply here — but we need to NOT schedule new ambients while
        // those are true, otherwise we'd burn through the whole pool
        // during a long chat.
        if popoverWindow?.isVisible == true || isClaudeBusy || isSleeping || isCompanionAvatar || focusedExpert != nil {
            // If an ambient bubble is currently up, hide it and reset
            // expiry so we don't leave a stale message while the user
            // pivots into chat.
            if ambientBubbleExpiresAt > 0 {
                hideBubble()
                ambientBubbleExpiresAt = 0
                nextAmbientBubbleAt = now + TimeInterval.random(in: WalkerCharacter.minAmbientGap...WalkerCharacter.maxAmbientGap)
            }
            return
        }

        // If a status / completion bubble is active, defer ambient.
        if isClaudeBusy || showingCompletion { return }

        // If an ambient is currently showing, expire it on schedule.
        if ambientBubbleExpiresAt > 0 {
            if now >= ambientBubbleExpiresAt {
                hideBubble()
                ambientBubbleExpiresAt = 0
                nextAmbientBubbleAt = now + TimeInterval.random(in: WalkerCharacter.minAmbientGap...WalkerCharacter.maxAmbientGap)
            }
            return
        }

        // Time to fire a new ambient?
        guard now >= nextAmbientBubbleAt, !Self.ambientLines.isEmpty else { return }

        // Avoid repeating the most recent line back-to-back.
        var idx = Int.random(in: 0..<Self.ambientLines.count)
        if Self.ambientLines.count > 1 && idx == lastAmbientLineIndex {
            idx = (idx + 1) % Self.ambientLines.count
        }
        lastAmbientLineIndex = idx
        let line = Self.ambientLines[idx]

        showBubble(text: line, isCompletion: false, multiline: true)
        ambientBubbleExpiresAt = now + WalkerCharacter.ambientBubbleLinger
    }
}
