import XCTest
@testable import LilJustinCore

/// The system prompt that ships to Mini Justin every turn pulls
/// from `BusinessContext.systemPromptSection()`. A regression here
/// would silently strip Sir's program details out of every answer
/// without any visible UI cue. These tests pin the contract.
final class BusinessContextTests: XCTestCase {

    func testIsCompleteRequiresAllRequiredFields() {
        var ctx = BusinessContext(
            vertical: "B2B SaaS",
            espTool: "Braze",
            primaryChannel: "Email primarily",
            listSizeBand: "100k–1M",
            teamSize: "2–5",
            biggestPain: "",
            schemaVersion: 1,
            capturedAt: Date()
        )
        XCTAssertTrue(ctx.isComplete)

        ctx.vertical = ""
        XCTAssertFalse(ctx.isComplete, "Empty vertical should disqualify")

        ctx.vertical = "B2B SaaS"
        ctx.teamSize = "  "
        XCTAssertFalse(ctx.isComplete, "Whitespace-only field should disqualify")

        // biggestPain is optional — leaving it blank should still pass.
        ctx.teamSize = "2–5"
        ctx.biggestPain = ""
        XCTAssertTrue(ctx.isComplete)
    }

    func testSystemPromptSectionEmptyWhenIncomplete() {
        let ctx = BusinessContext.empty()
        XCTAssertEqual(ctx.systemPromptSection(), "")
    }

    func testSystemPromptSectionIncludesAllFields() {
        let ctx = BusinessContext(
            vertical: "Marketplace",
            espTool: "Iterable",
            primaryChannel: "Multi-channel",
            listSizeBand: "1M+",
            teamSize: "20+",
            biggestPain: "Reactivation flow underperforms",
            schemaVersion: 1,
            capturedAt: Date()
        )
        let section = ctx.systemPromptSection()

        XCTAssertTrue(section.contains("Vertical: Marketplace"))
        XCTAssertTrue(section.contains("ESP / CRM tool: Iterable"))
        XCTAssertTrue(section.contains("Primary channel: Multi-channel"))
        XCTAssertTrue(section.contains("List size: 1M+"))
        XCTAssertTrue(section.contains("Team size: 20+"))
        XCTAssertTrue(section.contains("Reactivation flow underperforms"))
    }

    func testSystemPromptSectionOmitsPainWhenBlank() {
        let ctx = BusinessContext(
            vertical: "B2B SaaS",
            espTool: "HubSpot",
            primaryChannel: "Email primarily",
            listSizeBand: "10k–100k",
            teamSize: "Just me",
            biggestPain: "",
            schemaVersion: 1,
            capturedAt: Date()
        )
        let section = ctx.systemPromptSection()
        XCTAssertFalse(section.contains("Current focus / pain"))
    }

    func testCuratedOptionsCoverEachExpectedCategory() {
        // Spot-check that the option lists weren't accidentally
        // emptied — Sir asked for a wide vertical list explicitly.
        XCTAssertTrue(BusinessContextOptions.verticals.contains("B2B SaaS"))
        XCTAssertTrue(BusinessContextOptions.verticals.contains("Marketplace"))
        XCTAssertTrue(BusinessContextOptions.verticals.contains("Health / wellness"))
        XCTAssertGreaterThanOrEqual(BusinessContextOptions.verticals.count, 15)

        XCTAssertTrue(BusinessContextOptions.espTools.contains("Braze"))
        XCTAssertTrue(BusinessContextOptions.espTools.contains("Klaviyo"))
        XCTAssertTrue(BusinessContextOptions.espTools.contains("None yet"))
        XCTAssertGreaterThanOrEqual(BusinessContextOptions.espTools.count, 15)

        XCTAssertEqual(BusinessContextOptions.listSizeBands.count, 4)
        XCTAssertEqual(BusinessContextOptions.teamSizes.count, 4)
    }
}
