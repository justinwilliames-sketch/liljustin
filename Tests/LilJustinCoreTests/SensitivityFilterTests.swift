import XCTest
@testable import LilJustinCore

/// Sir's primary requirement when the memory layer was specced:
/// "try and avoid memorising anything sensitive". These tests pin
/// that contract — every category we promised to filter must be
/// rejected, and benign generalised content must pass.
///
/// Failure here is the highest-stakes class of regression: a leaky
/// SensitivityFilter would silently persist customer PII, API keys,
/// or private revenue figures to disk under the user's profile.
final class SensitivityFilterTests: XCTestCase {

    // MARK: - Reject cases

    func testRejectsEmailAddress() {
        let entry = entry(body: "Contact justin@sophiie.ai for the playbook.")
        XCTAssertEqual(SensitivityFilter.evaluate(entry), .reject(reason: "Detected email address: justin@sophiie.ai"))
    }

    func testRejectsAnthropicStyleAPIKey() {
        let entry = entry(body: "Test key sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxx ended up in the chat.")
        if case .reject = SensitivityFilter.evaluate(entry) {
            // pass
        } else {
            XCTFail("API-key shape should be rejected")
        }
    }

    func testRejectsGitHubPersonalAccessToken() {
        let entry = entry(body: "Pushed via ghp_abcdefghijklmnop1234567890.")
        if case .reject = SensitivityFilter.evaluate(entry) {} else {
            XCTFail("GitHub token shape should be rejected")
        }
    }

    func testRejectsAWSAccessKey() {
        let entry = entry(body: "Rotated AKIAIOSFODNN7EXAMPLE last week.")
        if case .reject = SensitivityFilter.evaluate(entry) {} else {
            XCTFail("AWS key shape should be rejected")
        }
    }

    func testRejectsJWT() {
        let entry = entry(body: "Cookie carries eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c.")
        if case .reject = SensitivityFilter.evaluate(entry) {} else {
            XCTFail("JWT shape should be rejected")
        }
    }

    func testRejectsPhoneNumber() {
        let entry = entry(body: "He texted from +61 412 345 678 around lunch.")
        if case .reject = SensitivityFilter.evaluate(entry) {} else {
            XCTFail("Phone shape should be rejected")
        }
    }

    func testRejectsHighPrecisionCurrency() {
        // Generalised "$500K" passes; precise "$487,213.00" must not.
        let entry = entry(body: "Q3 came in at $1,234,567.89 against forecast.")
        if case .reject = SensitivityFilter.evaluate(entry) {} else {
            XCTFail("Precise currency figures should be rejected")
        }
    }

    func testRejectsUSSocialSecurityShape() {
        let entry = entry(body: "The submitted form had 123-45-6789 in the wrong field.")
        if case .reject = SensitivityFilter.evaluate(entry) {} else {
            XCTFail("SSN shape should be rejected")
        }
    }

    // MARK: - Allow cases

    func testAllowsGeneralisedScale() {
        let entry = entry(body: "Consumer marketplace with ~500K active monthly subscribers.")
        XCTAssertEqual(SensitivityFilter.evaluate(entry), .allow)
    }

    func testAllowsRoleAndToolingFact() {
        let entry = entry(body: "User runs lifecycle on Braze, primary channel is email, just-launched a win-back flow.")
        XCTAssertEqual(SensitivityFilter.evaluate(entry), .allow)
    }

    func testAllowsRoughTeamSize() {
        let entry = entry(body: "Small team — three operators, no dedicated deliverability lead.")
        XCTAssertEqual(SensitivityFilter.evaluate(entry), .allow)
    }

    func testAllowsRoughCurrencyBands() {
        let entry = entry(body: "Average order value sits in the low hundreds.")
        XCTAssertEqual(SensitivityFilter.evaluate(entry), .allow)
    }

    // MARK: - Helpers

    private func entry(body: String) -> MemoryEntry {
        MemoryEntry(
            name: "Test fact",
            description: "A fact under test",
            body: body,
            kind: .user
        )
    }
}
