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
        // Headings emit as <p><strong>...</strong></p> rather than
        // <h*> so Slack's paste handler reliably gives them a blank
        // line above the next paragraph.
        let input = """
        ## The mechanism

        The emoji that earns its place is doing semantic work.
        """
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<p><strong>The mechanism</strong></p>"))
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

    func testAllHeadingLevelsRenderAsBoldedParagraph() {
        // Every heading level collapses to <p><strong>...</strong></p>
        // for consistent paste behaviour across Slack/Mail/Notes.
        for prefix in ["#", "##", "###", "####"] {
            let out = MarkdownToHTML.convert("\(prefix) Heading")
            XCTAssertTrue(out.contains("<p><strong>Heading</strong></p>"),
                          "Heading prefix '\(prefix) ' should render as <p><strong>")
        }
    }

    func testHeadingIsFollowedByEmptyParagraphSpacer() {
        // Sir's repeat regression: even with `<p><strong>X</strong></p>
        // <p>body</p>` Slack collapsed the visible break between
        // heading and body. The fix is an explicit empty-paragraph
        // sentinel after each heading so Slack registers a real
        // paragraph boundary.
        let out = MarkdownToHTML.convert("## The core problem\n\nMost sequences fail.")
        XCTAssertTrue(out.contains("<p><strong>The core problem</strong></p>\n<p></p>"))
        XCTAssertTrue(out.contains("<p>Most sequences fail.</p>"))
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

    // MARK: - List items with bold prefix

    func testNumberedItemWithBoldPrefixGetsLineBreakAfterTitle() {
        // Sir's deliverability post had four numbered items each
        // shaped `**Title** body text...`. Without the line break,
        // the title and body run together as one wall of text.
        // The break makes the pasted Slack list look like
        // `1. **Title**` / `   body text` — which mirrors the
        // logical structure.
        let input = "1. **Authentication** SPF, DKIM, and DMARC. Since early 2024."
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<strong>Authentication</strong><br>SPF, DKIM, and DMARC. Since early 2024."))
    }

    func testBulletItemWithBoldPrefixAlsoBreaks() {
        let input = "- **List quality** Your list hygiene policy is a reputation policy."
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<strong>List quality</strong><br>Your list hygiene policy is a reputation policy."))
    }

    func testListItemWithOnlyBoldDoesNotInsertBreak() {
        // If the entire item is just the bold (no body text), don't
        // emit a stray <br> at the end.
        let input = "1. **Done**"
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<li><strong>Done</strong></li>"))
        XCTAssertFalse(out.contains("<strong>Done</strong><br>"))
    }

    func testListItemWithoutBoldPrefixIsUntouched() {
        let input = "- a regular bullet with no bold prefix"
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<li>a regular bullet with no bold prefix</li>"))
        XCTAssertFalse(out.contains("<br>"))
    }

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

    // MARK: - Tables

    func testMarkdownTableRendersAsPreformattedBlock() {
        // The IP-warmup-style table Sir pasted into Slack got
        // smashed onto one line because the converter had no table
        // detection. Now table rows go through a <pre><code> block
        // so column alignment is preserved by monospace rendering.
        let input = """
        | Day | Volume |
        |-----|--------|
        | 1 | 200 |
        | 2 | 500 |
        """
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<pre><code>"))
        // Each table row must appear on its own line inside the block.
        XCTAssertTrue(out.contains("| Day | Volume |"))
        XCTAssertTrue(out.contains("|-----|--------|"))
        XCTAssertTrue(out.contains("| 1 | 200 |"))
        XCTAssertTrue(out.contains("| 2 | 500 |"))
        XCTAssertTrue(out.contains("</code></pre>"))
    }

    func testTableSeparatesFromSurroundingParagraphs() {
        // The pre-table paragraph and post-table paragraph must
        // each be their own <p>, not collapsed into the table.
        let input = """
        Schedule below.

        | Day | Volume |
        | 1 | 200 |

        Notes after.
        """
        let out = MarkdownToHTML.convert(input)
        XCTAssertTrue(out.contains("<p>Schedule below.</p>"))
        XCTAssertTrue(out.contains("<pre><code>"))
        XCTAssertTrue(out.contains("<p>Notes after.</p>"))
    }

    // MARK: - Italic forms

    func testSingleAsteriskItalicBecomesEm() {
        // Sir's writing uses `*X*` for italic. This MUST render as
        // `<em>X</em>`, not literal asterisks (which is what shipped
        // in v0.1.49 — `*who*` showed as `*who*` in Slack).
        XCTAssertEqual(
            MarkdownToHTML.convert("specifically, *who* gets the send"),
            "<p>specifically, <em>who</em> gets the send</p>"
        )
    }

    func testUnderscoreItalicStillWorks() {
        XCTAssertEqual(
            MarkdownToHTML.convert("an _emphasised_ word"),
            "<p>an <em>emphasised</em> word</p>"
        )
    }

    func testItalicDoesNotMisfireInsideBold() {
        // The closing `*` of `**bold**` after the bold pass becomes
        // `*` adjacent to other `*` — must not be eaten by italic.
        let out = MarkdownToHTML.convert("This is **bold** text.")
        XCTAssertTrue(out.contains("<strong>bold</strong>"))
        XCTAssertFalse(out.contains("<em>"))
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
