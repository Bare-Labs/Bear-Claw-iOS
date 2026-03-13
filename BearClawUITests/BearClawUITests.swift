//
//  BearClawAppUITests.swift
//  BearClawAppUITests
//
//  Created by Joe Caruso on 3/6/26.
//

import XCTest

final class BearClawUITests: XCTestCase {
    private let pairingPayloadFallbackURL = URL(fileURLWithPath: "/tmp/bearclaw-ui-test-pairing.json")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLiveBackendChatFlow() throws {
        let app = configuredApp(pairingPayload: try requiredPairingPayload())
        app.launch()

        let input = app.textFields["chat.messageInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("hello from simulator")

        let send = app.buttons["chat.sendButton"]
        XCTAssertTrue(send.exists)
        send.tap()

        let assistantText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "hello from simulator")).firstMatch
        XCTAssertTrue(assistantText.waitForExistence(timeout: 15))
    }

    @MainActor
    func testUnauthorizedTokenShowsError() throws {
        let app = configuredApp(pairingPayload: try badTokenPayload())
        app.launch()

        let input = app.textFields["chat.messageInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("unauthorized test")

        app.buttons["chat.sendButton"].tap()

        let errorText = app.staticTexts["chat.errorText"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 15))
        XCTAssertTrue(errorText.label.contains("Unauthorized"))
    }

    private func configuredApp(pairingPayload: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BEARCLAW_UI_TEST_PAIRING_PAYLOAD"] = pairingPayload
        app.launchEnvironment["BEARCLAW_UI_TEST_USER_DEFAULTS_SUITE"] = "BearClawUITests-\(UUID().uuidString)"
        app.launchEnvironment["BEARCLAW_UI_TEST_IN_MEMORY_TOKEN_STORE"] = "1"
        app.launchEnvironment["BEARCLAW_UI_TEST_RESET_STATE"] = "1"
        return app
    }

    private func requiredPairingPayload() throws -> String {
        guard let payload = ProcessInfo.processInfo.environment["BEARCLAW_UI_TEST_PAIRING_PAYLOAD"],
              !payload.isEmpty else {
            guard let fallbackPayload = try? String(contentsOf: pairingPayloadFallbackURL, encoding: .utf8),
                  !fallbackPayload.isEmpty else {
                throw XCTSkip("No pairing payload was provided by the harness")
            }
            return fallbackPayload
        }
        return payload
    }

    private func badTokenPayload() throws -> String {
        let payload = try requiredPairingPayload()
        let data = try XCTUnwrap(payload.data(using: .utf8))
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XCTSkip("Pairing payload was not valid JSON")
        }
        json["bearer_token"] = "wrong-token"
        let mutated = try JSONSerialization.data(withJSONObject: json)
        return try XCTUnwrap(String(data: mutated, encoding: .utf8))
    }
}
