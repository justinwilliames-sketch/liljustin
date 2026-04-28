import AppKit

extension ChatBubbleView {
    func setText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.setAttributedString(newText)
        updateTextAlignment()
        recalculateSize()
    }

    func appendText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.append(newText)
        updateTextAlignment()
        recalculateSize()
    }

    @objc func copyTapped() {
        // Prefer the original markdown source converted to Slack
        // mrkdwn so the user can paste a properly-formatted message
        // straight into Slack. Fall back to the rendered plain text
        // when markdown isn't available (e.g. user bubbles, errors).
        let payload: String
        if let source = markdownSource, !source.isEmpty {
            payload = MarkdownToSlack.convert(source)
        } else {
            payload = textView.string
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        onCopy?()
    }

    /// Update the bubble's markdown source as new content streams in.
    /// Called from the streaming path so the copy button always
    /// reflects the latest accumulated markdown.
    func setMarkdownSource(_ source: String) {
        markdownSource = source
    }

    @objc func followUpTapped() {
        WalkerCharacter.playSelectionSound()
        onFollowUp?()
    }

    func configureTextContainer() {
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
    }

    func updateTextAlignment() {
        guard let storage = textView.textStorage else { return }

        let alignment: NSTextAlignment = .left

        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.alignment = alignment
            if style.lineSpacing == 0 {
                style.lineSpacing = 4
            }
            if style.paragraphSpacing == 0 {
                style.paragraphSpacing = 7
            }
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
        storage.endEditing()
        textView.alignment = alignment
    }

    func recalculateSize() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        textContainer.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)

        let targetContentWidth = rect.width
        let paddingWidth: CGFloat = 28

        // Bubble max width adapts to the available transcript column. In
        // the default-size popover the column is ~376pt, so the cap lands
        // at roughly the historical 380; in the expanded popover the
        // column is ~580pt+, so the bubble grows with it instead of
        // sitting in the left half of a wide column. Soft-capped at 720
        // so a 1000pt-wide popover doesn't produce hard-to-read line
        // lengths.
        let availableWidth: CGFloat
        if let parentWidth = superview?.bounds.width, parentWidth > 0 {
            // Subtract trailing gutter (56) used by the bubbleBackground
            // constraint plus a small breathing buffer.
            availableWidth = max(280, parentWidth - 56 - 4)
        } else {
            // No superview yet — initial layout. Fall back to the
            // original cap so the first render isn't undersized.
            availableWidth = 380
        }
        let maxWidth: CGFloat = min(720, availableWidth)
        let desiredWidth = targetContentWidth + paddingWidth

        if let textWidthConstraint {
            textView.removeConstraint(textWidthConstraint)
            self.textWidthConstraint = nil
        }
        if let textHeightConstraint {
            textView.removeConstraint(textHeightConstraint)
            self.textHeightConstraint = nil
        }

        if desiredWidth >= maxWidth {
            textContainer.containerSize = NSSize(width: maxWidth - paddingWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let newRect = layoutManager.usedRect(for: textContainer)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: maxWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: newRect.height + 24)
        } else {
            let finalWidth = max(desiredWidth, 60)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: finalWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: rect.height + 24)
        }

        textWidthConstraint?.isActive = true
        textHeightConstraint?.isActive = true
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        var view: NSView? = self.superview
        while let v = view {
            if let terminal = v as? TerminalView {
                guard let url = link as? URL,
                      url.scheme == "lilagents-expert",
                      let host = url.host,
                      let expert = terminal.expertSuggestionTargets[host] else {
                    return false
                }
                WalkerCharacter.playSelectionSound()
                terminal.onSelectExpert?(expert)
                return true
            }
            view = v.superview
        }
        return false
    }
}
