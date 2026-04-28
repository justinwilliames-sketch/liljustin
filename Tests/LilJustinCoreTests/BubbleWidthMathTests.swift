import XCTest
@testable import LilJustinCore

/// Sir's contract for bubble width:
///   - Default popover must match the Lil-Lenny fork (380pt cap).
///   - Expanded popover is the only mode that grows bubbles.
///
/// Past regressions: v0.1.41 tried to grow on expand but read stale
/// bounds so nothing changed. v0.1.43 grew on expand correctly but
/// also widened the default popover from 380 → 400, which Sir
/// flagged. v0.1.44 holds 380 in default and grows only past the
/// expansion threshold. These tests pin all four cases.
final class BubbleWidthMathTests: XCTestCase {

    func testDefaultPopoverHoldsHistoricalCap() {
        // Default popover ~432pt → column ~400pt. Lil-Lenny held
        // bubbles at 380pt for conversational line length, and
        // Sir explicitly asked for that to remain unchanged in
        // default mode. Anything between minWidth and the
        // expansionThreshold should return defaultCap (capped at
        // the actual column width).
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 432, sidePadding: 16)
        XCTAssertEqual(result, 380)
    }

    func testSlightlyWiderThanDefaultStillHoldsCap() {
        // Manual window resize that nudges the popover a bit wider
        // (without hitting the expand toggle) shouldn't trigger
        // bubble growth. 450pt frame → 418pt column → still under
        // the 460pt threshold → still 380.
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 450, sidePadding: 16)
        XCTAssertEqual(result, 380)
    }

    func testExpandedPopoverGrowsToColumnWidth() {
        // Expanded popover ~648pt → 616pt column. Above the 460pt
        // threshold, so bubbles grow. Capped at 720pt.
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 648, sidePadding: 16)
        XCTAssertEqual(result, 616)
    }

    func testWideExpandedPopoverHitsSoftCap() {
        // A 1000pt-wide popover hands us 968pt of column. Capping
        // at 720 keeps bubble line-length readable even when the
        // user has all the screen real estate in the world.
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 1000, sidePadding: 16)
        XCTAssertEqual(result, 720)
    }

    func testNarrowFrameHitsFloor() {
        // First-layout frame width often arrives near zero. The
        // formula must clamp up to the floor so the bubble doesn't
        // collapse to a sliver while the popover is still settling.
        let zero = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 0, sidePadding: 16)
        XCTAssertEqual(zero, 280)

        let small = BubbleWidthMath.maxBubbleWidth(forFrameWidth: 100, sidePadding: 16)
        XCTAssertEqual(small, 280)
    }

    func testExactlyAtThresholdHoldsDefaultCap() {
        // Boundary case — frame.width that yields a column exactly
        // at the expansionThreshold should still hold the default
        // cap (the threshold is inclusive of "default mode").
        let frameAtThreshold = BubbleWidthMath.expansionThreshold + 32  // + 16 padding * 2
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: frameAtThreshold, sidePadding: 16)
        XCTAssertEqual(result, 380)
    }

    func testJustAboveThresholdGrows() {
        // One pixel above the threshold should switch to grow mode.
        let frameJustAbove = BubbleWidthMath.expansionThreshold + 33  // + 16 padding * 2 + 1
        let result = BubbleWidthMath.maxBubbleWidth(forFrameWidth: frameJustAbove, sidePadding: 16)
        XCTAssertEqual(result, BubbleWidthMath.expansionThreshold + 1)
    }
}
