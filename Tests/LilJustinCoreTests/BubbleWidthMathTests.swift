import XCTest
@testable import LilJustinCore

/// The bug Sir flagged in v0.1.41: chat bubbles were stuck at the
/// 380pt default in expanded popover mode. Root cause was the wrong
/// input (stale `transcriptStack.bounds.width`) being fed to a
/// formula that itself was correct. The TerminalView call site
/// passes `frame.width` directly now; this suite pins the formula
/// so a future "let's just use this number" tweak can't silently
/// re-narrow the column.
final class BubbleWidthMathTests: XCTestCase {

    func testDefaultPopoverFitsHistoricalCap() {
        // Default popover width is ~432pt; minus 16*2 padding gives
        // a 400pt column. The historical hardcoded cap was 380pt;
        // 400 sits comfortably above the floor and below the cap.
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 432, sidePadding: 16)
        XCTAssertEqual(result, 400)
    }

    func testExpandedPopoverGrowsToColumnWidth() {
        // Expanded popover ~648pt → 616pt column. Should grow to
        // match (under the 720pt soft cap), NOT stay at 380.
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 648, sidePadding: 16)
        XCTAssertEqual(result, 616)
    }

    func testWidePopoverHitsSoftCap() {
        // A 1000pt-wide popover hands us 968pt of column. Capping
        // at 720 keeps bubble line-length readable.
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 1000, sidePadding: 16)
        XCTAssertEqual(result, 720)
    }

    func testNarrowFrameHitsFloor() {
        // First-layout frame width often arrives near zero. The
        // formula must clamp UP to 280 so the bubble doesn't
        // collapse to a sliver.
        let zero = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 0, sidePadding: 16)
        XCTAssertEqual(zero, 280)

        let small = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 100, sidePadding: 16)
        XCTAssertEqual(small, 280)
    }

    func testPaddingScalesLinearly() {
        // Sanity: doubling padding eats 2x as much from the column.
        let withSmallPad = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 600, sidePadding: 16)
        let withLargePad = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 600, sidePadding: 32)
        XCTAssertEqual(withSmallPad - withLargePad, 32)
    }
}
