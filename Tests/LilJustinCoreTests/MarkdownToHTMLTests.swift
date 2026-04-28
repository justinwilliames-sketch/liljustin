import XCTest
@testable import LilJustinCore

/// The bug Sir flagged in v0.1.46: copying a multi-paragraph reply
/// and pasting into Slack produced one wall-of-text with no spacing
/// between paragraphs ("worse.That's / mechanismThe / pair.SourcesEmojis").
/// Root cause was Foundation's AttributedString-to-RTF path collapsing
/// block boundaries. v0.1.47 routes Slack copy through MarkdownToHTML
/// instead, which emits explicit `<p>` boundaries.
///
/// These tests pin paragraph preservation, heading rendering, list
/// emission, and inline-formatting safety so that "the Slack copy
/// merged my paragraphs again" can never silently re-ship.
final class MarkdownToHTMLTests: XCTestCase {

    // MARK: - The block-boundary regression

    func testParagraphsBecomeSeparateParagraphTags() {
        let input = """
        First paragraph.

        Second paragraph.
        """
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<p>First paragraph.</p>"))
        XCTAssertTrue(out.contains("<p>Second paragraph.</p>"))
        // The two paragraphs MUST be separate <p> tags. If the
        // converter collapses them into one, this would fail.
        XCTAssertFalse(out.contains("<p>First paragraph. Second paragraph.</p>"))
    }

    func testHeadingFollowedByParagraphRendersSeparately() {
        // The exact shape Sir's bug screenshot showed: a heading
        // immediately followed by a paragraph getting merged.
        let input = """
        ## The mechanism

        The emoji that earns its place is doing semantic work.
        """
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<h2>The mechanism</h2>"))
        XCTAssertTrue(out.contains("<p>The emoji that earns its place is doing semantic work.</p>"))
    }

    func testSourcesBlockSeparatesFromTrailingParagraph() {
        let input = """
        Write them as a pair.

        **Sources**

        - [Apple MPP, four years in](https://get.yourorbit.team/guides/apple-mpp-four-years)
        """
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<p>Write them as a pair.</p>"))
        XCTAssertTrue(out.contains("<strong>Sources</strong>"))
        XCTAssertTrue(out.contains("<ul>"))
        XCTAssertTrue(out.contains("<a href=\"https://get.yourorbit.team/guides/apple-mpp-four-years\">Apple MPP, four years in</a>"))
    }

    // MARK: - Headings

    func testEachHeadingLevelRenders() {
        XCTAssertTrue(MarkdownToHTML.convert("# H1").contains("<h1>H1</h1>"))
        XCTAssertTrue(MarkdownToHTML.convert("## H2").contains("<h2>H2</h2>"))
        XCTAssertTrue(MarkdownToHTML.convert("### H3").contains("<h3>H3</h3>"))
    }

    // MARK: - Inline formatting

    func testBoldBecomesStrong() {
        XCTAssertEqual(
            MarkdownToHTML.convert("This is **bold**."),
            "<p>This is <strong>bold</strong>.</p>"
        )
    }

    func testMarkdownLinkBecomesAnchor() {
        XCTAssertEqual(
            MarkdownToHTML.convert("[label](https://example.com)"),
            "<p><a href=\"https://example.com\">label</a></p>"
        )
    }

    func testInlineCodeBecomesCodeTag() {
        XCTAssertEqual(
            MarkdownToHTML.convert("run `npm test`"),
            "<p>run <code>npm test</code></p>"
        )
    }

    func testInlineCodeAsterisksAreNotInterpretedAsBold() {
        // Bug-class: an asterisk inside backticks shouldn't get
        // converted to <strong>. The placeholder dance in
        // transformInline is what protects this case.
        XCTAssertEqual(
            MarkdownToHTML.convert("use `glob *.tsx`"),
            "<p>use <code>glob *.tsx</code></p>"
        )
    }

    func testHTMLSpecialCharsInBodyAreEscaped() {
        // The user could write `<script>` or `&` in their text — those
        // must escape, otherwise we'd inject markup the receiver
        // would render as actual HTML.
        let out = MarkdownToHTML.convert("if a < b && c > d then x")
        XCTAssertTrue(out.contains("&lt;"))
        XCTAssertTrue(out.contains("&gt;"))
        XCTAssertTrue(out.contains("&amp;"))
    }

    // MARK: - Lists

    func testUnorderedListRendersWithUlAndLi() {
        let input = "- one\n- two\n- three"
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<ul>"))
        XCTAssertTrue(out.contains("<li>one</li>"))
        XCTAssertTrue(out.contains("<li>two</li>"))
        XCTAssertTrue(out.contains("<li>three</li>"))
        XCTAssertTrue(out.contains("</ul>"))
    }

    func testOrderedListRendersWithOlAndLi() {
        let input = "1. first\n2. second"
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<ol>"))
        XCTAssertTrue(out.contains("<li>first</li>"))
        XCTAssertTrue(out.contains("<li>second</li>"))
    }

    func testListIsClosedBeforeNextParagraph() {
        let input = """
        - item

        Following paragraph.
        """
        let out = MarkdownToHTML.convert(input)
        // The </ul> must appear before <p>Following — otherwise the
        // paragraph gets glued onto the list.
        guard let listEnd = out.range(of: "</ul>"),
              let paraStart = out.range(of: "<p>Following") else {
            XCTFail("Missing list close or following paragraph")
            return
        }
        XCTAssertLessThan(listEnd.upperBound, paraStart.lowerBound)
    }

    // MARK: - Blockquote and code block

    func testBlockquoteRenders() {
        XCTAssertEqual(
            MarkdownToHTML.convert("> a quote"),
            "<blockquote>a quote</blockquote>"
        )
    }

    func testFencedCodeBlockRenders() {
        let input = "```\nlet x = 1\nlet y = 2\n```"
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<pre><code>"))
        XCTAssertTrue(out.contains("let x = 1"))
        XCTAssertTrue(out.contains("</code></pre>"))
    }

    func testFencedCodeBlockEscapesHTMLChars() {
        // Code block with `<` and `>` should escape so the receiver
        // doesn't render the contents as actual HTML.
        let input = "```\n<div>hi</div>\n```"
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("&lt;div&gt;"))
        XCTAssertFalse(out.contains("<div>hi</div>"), "Raw HTML inside code block must be escaped")
    }
}
