import XCTest
@testable import LilJustinCore

/// Regression coverage for the markdown → Slack mrkdwn converter.
///
/// Anchors expected output for the patterns Sir's reply most commonly
/// produces: bold (`**`), links, headings, lists, blockquotes, code.
/// The most painful regressions to catch by eye are subtle bugs in
/// nested formatting (bold-inside-list, link-inside-bold) — those get
/// dedicated cases below.
final class MarkdownToSlackTests: XCTestCase {

    func testBoldGetsSingleAsterisk() {
        let out = MarkdownToSlack.convert("**hello**")
        XCTAssertEqual(out, "*hello*")
    }

    func testBoldInsideParagraphIsRecognised() {
        let out = MarkdownToSlack.convert("This is **bold** in a sentence.")
        XCTAssertEqual(out, "This is *bold* in a sentence.")
    }

    func testHeadingsBecomeBoldLines() {
        let out = MarkdownToSlack.convert("# Title")
        XCTAssertEqual(out, "*Title*")
    }

    func testBulletsNormaliseToBulletGlyph() {
        let out = MarkdownToSlack.convert("- one\n- two")
        XCTAssertTrue(out.contains("•   one"))
        XCTAssertTrue(out.contains("•   two"))
    }

    func testOrderedListsKeepNumbers() {
        let out = MarkdownToSlack.convert("1. first\n2. second")
        XCTAssertTrue(out.contains("1. first"))
        XCTAssertTrue(out.contains("2. second"))
    }

    func testMarkdownLinksBecomeAngleBracketSlackLinks() {
        let out = MarkdownToSlack.convert("[Apple MPP guide](https://example.com/apple-mpp)")
        XCTAssertEqual(out, "<https://example.com/apple-mpp|Apple MPP guide>")
    }

    func testBareURLsGetAngleBrackets() {
        let out = MarkdownToSlack.convert("see https://example.com today")
        XCTAssertEqual(out, "see <https://example.com> today")
    }

    func testInlineCodeSurvivesIntact() {
        let out = MarkdownToSlack.convert("run `npm test` to verify")
        XCTAssertEqual(out, "run `npm test` to verify")
    }

    func testInlineCodeAsterisksAreNotInterpretedAsBold() {
        // Bug-class: an asterisk inside a code span shouldn't trigger
        // the bold pass and corrupt the code contents.
        let out = MarkdownToSlack.convert("use `glob *.tsx` to match")
        XCTAssertEqual(out, "use `glob *.tsx` to match")
    }

    func testFencedCodeBlockSurvivesUntouched() {
        let input = "```\n**not bold here**\n```"
        let out = MarkdownToSlack.convert(input)
        XCTAssertTrue(out.contains("**not bold here**"))
    }

    func testBlockquotePrefixSurvives() {
        let out = MarkdownToSlack.convert("> a quoted line")
        XCTAssertEqual(out, "> a quoted line")
    }

    func testMultilineMixedFormattingDoesNotCorruptLinks() {
        // The exact shape of a typical LilJustin Sources block. The
        // citation links must come through with the Slack
        // `<url|label>` form and the bold "Sources" header above
        // them must collapse `**` to `*`.
        let input = """
        **Sources**
        - [Apple MPP, four years in](https://get.yourorbit.team/guides/apple-mpp-four-years)
        """
        let out = MarkdownToSlack.convert(input)
        XCTAssertTrue(out.contains("*Sources*"), "Bold header should collapse to single asterisks")
        XCTAssertTrue(
            out.contains("<https://get.yourorbit.team/guides/apple-mpp-four-years|Apple MPP, four years in>"),
            "Markdown link should become <url|label>"
        )
    }
}
