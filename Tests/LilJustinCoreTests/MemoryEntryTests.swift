import XCTest
@testable import LilJustinCore

/// Memory layer's storage shape is load-bearing: a Codable break
/// would corrupt every saved entry and lose Sir's accumulated
/// context across an update. These tests pin the JSON round-trip
/// and the limit-enforcement contract.
final class MemoryEntryTests: XCTestCase {

    func testCodableRoundTripPreservesAllFields() throws {
        let original = MemoryEntry(
            id: UUID(),
            name: "User runs Braze",
            description: "ESP context",
            body: "User's ESP is Braze; primary channel is email; list size ~500K.",
            kind: .user,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
            pinned: true,
            schemaVersion: MemoryEntry.currentSchemaVersion
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MemoryEntry.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testIsCompleteRequiresAllNonEmpty() {
        var entry = MemoryEntry(
            name: "x",
            description: "x",
            body: "x",
            kind: .user
        )
        XCTAssertTrue(entry.isComplete)

        entry.name = ""
        XCTAssertFalse(entry.isComplete)

        entry.name = "x"
        entry.body = "  "
        XCTAssertFalse(entry.isComplete, "Whitespace-only body should not count as complete")
    }

    func testKindSortOrderUserFirst() {
        let kinds: [MemoryEntry.Kind] = [.reference, .feedback, .user, .preference, .project]
        let sorted = kinds.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(sorted, [.user, .preference, .feedback, .project, .reference])
    }

    func testPromptLineMarksPinnedEntries() {
        let pinned = MemoryEntry(
            name: "User on Braze",
            description: "ESP",
            body: "Primary channel is email.",
            kind: .user,
            pinned: true
        )
        let unpinned = MemoryEntry(
            name: "User on Braze",
            description: "ESP",
            body: "Primary channel is email.",
            kind: .user,
            pinned: false
        )

        XCTAssertTrue(pinned.promptLine().hasPrefix("★"), "Pinned entries should start with the star marker")
        XCTAssertTrue(unpinned.promptLine().hasPrefix("- "), "Unpinned entries should use the bullet marker")
    }

    func testEmbeddableTextConcatenatesNameDescriptionBody() {
        let entry = MemoryEntry(
            name: "ESP choice",
            description: "Tooling fact",
            body: "Runs Braze.",
            kind: .user
        )
        XCTAssertEqual(entry.embeddableText, "ESP choice. Tooling fact. Runs Braze.")
    }
}
