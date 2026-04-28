import AppKit
import Lottie

final class WalkerCharacter {
    let videoName: String
    var window: NSWindow!
    var imageView: NSImageView!

    let displayHeight: CGFloat = 96
    let displayWidth: CGFloat = 96

    var accelStart: CFTimeInterval = 3.0
    var fullSpeedStart: CFTimeInterval = 3.75
    var decelStart: CFTimeInterval = 7.5
    var walkStop: CFTimeInterval = 8.25
    var walkAmountRange: ClosedRange<CGFloat> = 0.25...0.5
    var yOffset: CGFloat = 0
    var flipXOffset: CGFloat = 0
    var characterColor: NSColor = .gray

    var walkStartTime: CFTimeInterval = 0
    var positionProgress: CGFloat = 0.0
    var isWalking = false
    var isPaused = true
    var pauseEndTime: CFTimeInterval = 0
    var movementLocked = false
    var goingRight = true
    var walkStartPos: CGFloat = 0.0
    var walkEndPos: CGFloat = 0.0
    var currentTravelDistance: CGFloat = 500.0
    var walkStartPixel: CGFloat = 0.0
    var walkEndPixel: CGFloat = 0.0

    var isOnboarding = false
    var isIdleForPopover = false
    var popoverWindow: NSWindow?
    var terminalView: TerminalView?
    var claudeSession: ClaudeSession?
    var clickOutsideMonitor: Any?
    var escapeKeyMonitor: Any?
    weak var controller: LilAgentsController?
    var themeOverride: PopoverTheme?
    var thinkingBubbleWindow: NSWindow?
    var focusedExpert: ResponderExpert?
    var representedExpert: ResponderExpert?
    var isCompanionAvatar = false
    var handoffEffectWindow: NSWindow?
    var handoffEffectAnimationView: LottieAnimationView?
    var expertNameWindow: NSWindow?
    var popoverTitleLabel: NSTextField?
    var popoverSubtitleLabel: NSTextField?
    var popoverExpertSwitcherButton: HoverButton?
    var popoverReturnButton: NSButton?
    var popoverSettingsButton: HoverButton?
    var popoverExpandButton: HoverButton?
    var popoverPinButton: HoverButton?
    var popoverCloseButton: HoverButton?
    var expertSwitcherPopover: NSPopover?
    var isPopoverExpanded = false
    var isPopoverPinned = false
    // Total popover window dimensions. The bubble body is
    // `defaultPopoverHeight - popoverTailHeight` tall; the bottom
    // `popoverTailHeight` pixels host the speech-bubble tail pointing
    // down at the character. `defaultPopoverWidth` is the rest-state
    // width — the expand toggle widens to 1.5× and lengthens height to
    // a screen-fit value, then collapses back to these defaults.
    static let defaultPopoverWidth: CGFloat = 468
    static let defaultPopoverHeight: CGFloat = 574
    static let popoverTailHeight: CGFloat = 14
    static let popoverTailWidth: CGFloat = 28

    // Backing layer for the speech-bubble outline (rounded body + tail
    // as one continuous shape). Stored so we can rebuild its path when
    // the popover resizes.
    var popoverBubbleShape: CAShapeLayer?

    // ── Sleep state machine ─────────────────────────────────────────
    // After ~3–6 minutes of no interaction, LilJustin curls up for a
    // 20–60s nap (`main-sleeping.gif`). Any click / popover open wakes
    // him immediately; otherwise he wakes on his own, paces, and
    // delivers an ambient bubble within ~8–25s of standing back up.
    //
    // Awake windows are deliberately set wider than the ambient bubble
    // cadence (60–180s) so several bubbles can fire per awake period
    // — Sir wants the companion to actually talk to him, not nap
    // through every shift. Steady-state target: ~75% awake.
    var sleepingImage: NSImage?
    var isSleeping: Bool = false
    var lastInteractionAt: CFTimeInterval = CACurrentMediaTime()
    var idleSleepThreshold: TimeInterval = TimeInterval.random(in: 180...360)
    var wakeAt: CFTimeInterval = 0
    static let minIdleBeforeSleep: TimeInterval = 180     // 3 min
    static let maxIdleBeforeSleep: TimeInterval = 360     // 6 min
    static let minSleepDuration: TimeInterval = 20
    static let maxSleepDuration: TimeInterval = 60

    // ── Idle facing variety ────────────────────────────────────────
    // During long idle pauses, periodically re-roll between front and
    // back facing so LilJustin doesn't just stare at the camera the
    // whole time. Driven from the per-tick update().
    var nextIdleFacingRollAt: CFTimeInterval = 0

    // ── Ambient bubbles ────────────────────────────────────────────
    // While idle (no popover, no chat in flight, awake, not focused on
    // an expert) LilJustin periodically pipes up with a short Justin/
    // Orbit-voice comment — a CRM micro-tip, a deliverability gripe,
    // or a dry remark. Cadence is a randomised 90–240s gap between
    // bubbles. Each bubble lingers ~12s so Sir actually has time to
    // read it.
    // First bubble fires 20–90s after launch — Sir wanted LilJustin
    // to introduce himself sooner rather than waiting 1–3 minutes.
    var nextAmbientBubbleAt: CFTimeInterval = CACurrentMediaTime() + TimeInterval.random(in: 20...90)
    var ambientBubbleExpiresAt: CFTimeInterval = 0
    var lastAmbientLineIndex: Int = -1
    var isAmbientLLMRequestInFlight: Bool = false
    // Steady-state gap between bubbles. Average ~97s = ~37 bubbles/hr
    // when LilJustin is idle. Tighter than this risks stacking — the
    // ambient LLM call takes up to 25s and we don't want a new bubble
    // queueing while the previous one is still rendering or its LLM
    // dispatch is still in flight.
    static let minAmbientGap: TimeInterval = 45
    static let maxAmbientGap: TimeInterval = 150
    // Linger time on screen. 15s gives Sir comfortable reading time
    // for a two-line CRM/lifecycle observation without making the
    // bubble feel sticky.
    static let ambientBubbleLinger: TimeInterval = 15

    /// Build the speech-bubble outline as a single closed CGPath:
    /// rounded body on top + downward-pointing tail below. Drawing the
    /// whole thing as one path eliminates the visible seam where a
    /// separate body and tail used to meet.
    static func bubbleShellPath(
        size: CGSize,
        tailHeight: CGFloat,
        tailWidth: CGFloat,
        cornerRadius r: CGFloat
    ) -> CGPath {
        // Cocoa flipped Y: origin bottom-left. Body sits from y=tailHeight
        // up to y=size.height; tail apex points down to y=0 at horizontal
        // centre. Path traces clockwise from the top-left corner-curve
        // start, rounds each corner via tangent-end arcs, and breaks the
        // bottom edge at the tail attachment points.
        let w = size.width
        let h = size.height
        let bodyBottom = tailHeight
        let bodyTop = h
        let cx = w / 2
        let halfTail = tailWidth / 2

        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: bodyTop - r))
        p.addArc(tangent1End: CGPoint(x: 0, y: bodyTop), tangent2End: CGPoint(x: r, y: bodyTop), radius: r)
        p.addArc(tangent1End: CGPoint(x: w, y: bodyTop), tangent2End: CGPoint(x: w, y: bodyTop - r), radius: r)
        p.addArc(tangent1End: CGPoint(x: w, y: bodyBottom), tangent2End: CGPoint(x: w - r, y: bodyBottom), radius: r)
        p.addLine(to: CGPoint(x: cx + halfTail, y: bodyBottom))
        p.addLine(to: CGPoint(x: cx, y: 0))
        p.addLine(to: CGPoint(x: cx - halfTail, y: bodyBottom))
        p.addArc(tangent1End: CGPoint(x: 0, y: bodyBottom), tangent2End: CGPoint(x: 0, y: bodyBottom + r), radius: r)
        p.closeSubpath()
        return p
    }

    var isClaudeBusy: Bool { claudeSession?.isBusy ?? false }

    var directionalImages: [WalkerFacing: NSImage] = [:]
    var persona: WalkerPersona = .lenny

    var lastPhraseUpdate: CFTimeInterval = 0
    var currentPhrase = ""
    var completionBubbleExpiry: CFTimeInterval = 0
    var showingCompletion = false
    var phraseAnimating = false
    var currentActivityStatus = ""
    var liveStatusFallbackTimer: Timer?
    var lastLiveStatusEventAt: Date?
    var liveStatusFallbackIndex = 0
    var isDraggingHorizontally = false
    var usesExpandedHorizontalRange = false

    init(videoName: String) {
        self.videoName = videoName
    }
}
