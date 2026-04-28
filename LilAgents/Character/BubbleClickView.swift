import AppKit

/// Container view for the speech-bubble window.
///
/// Forwards two lightweight interactions to the owning character:
///
///   - `onClick` fires on `mouseDown`. When LilJustin is showing an
///     ambient tip / quote / observation, clicking the bubble itself
///     (rather than the character sprite below it) opens the chat
///     pre-loaded to expand on the topic.
///
///   - `onHoverChanged` fires on `mouseEntered` / `mouseExited`. The
///     character pauses the bubble's expiry timer while the cursor is
///     over the bubble — Sir asked for the option to read longer
///     observations without racing the auto-dismiss — and resets the
///     timer to a full linger window when the cursor leaves.
///
/// Whether the bubble window actually receives mouse events is decided
/// at the window level (`thinkingBubbleWindow.ignoresMouseEvents`):
/// only ambient tips opt in. Status / completion bubbles set
/// ignoresMouseEvents = true so this view's handlers never fire and
/// clicks pass through to whatever's underneath.
final class BubbleClickView: NSView {
    var onClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        // .activeAlways so hover registers even when the LilJustin
        // process isn't the frontmost app — the bubble lives on the
        // user's primary workspace, not in our windowed UI.
        // .inVisibleRect so the area auto-resizes when the bubble is
        // re-laid-out for a longer or shorter line.
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    /// Click cursor over the whole bubble area so the affordance is
    /// visible without needing a separate hover state. Only applied
    /// when the bubble is interactive (per the window's
    /// ignoresMouseEvents flag); inert bubbles don't reach this code
    /// path because the window swallows nothing.
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
