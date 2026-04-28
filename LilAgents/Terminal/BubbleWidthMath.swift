import Foundation
import CoreGraphics

/// Pure math the chat bubble layout depends on. Extracted here so
/// the test suite can pin the formula — the same function killed
/// the v0.1.41 expand fix when the wrong inputs (stale stack bounds
/// instead of `frame.width`) were fed in. Failure mode was silent:
/// bubbles capped at the narrow default. Tests exist now.
enum BubbleWidthMath {
    /// Lower floor — first-launch layout with frame near zero shouldn't
    /// crush bubbles into something unreadable.
    static let minWidth: CGFloat = 280
    /// Upper soft cap — wider popovers don't pay off for line-length
    /// readability past about 720pt of measured text width.
    static let maxWidth: CGFloat = 720

    /// Given the TerminalView's current frame width and the side
    /// padding it carves off, return the column width a chat bubble
    /// should target. `min(maxWidth, max(minWidth, frame - padding*2))`.
    static func maxBubbleWidth(forFrameWidth frameWidth: CGFloat, sidePadding: CGFloat) -> CGFloat {
        let columnWidth = max(0, frameWidth - sidePadding * 2)
        return min(maxWidth, max(minWidth, columnWidth))
    }
}
