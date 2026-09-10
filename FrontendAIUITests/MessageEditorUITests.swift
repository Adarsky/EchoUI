import XCTest

final class MessageEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLongMessageCanBeEditedAtTheBottomAndSaved() {
        let app = launchEditor(isUser: false)
        let editor = app.textViews["message-editor.text"]
        XCTAssertTrue(app.navigationBars["Edit Luna’s message"].exists)
        let originalText = editor.value as? String ?? ""
        XCTAssertTrue(originalText.hasSuffix("END_MARKER"))

        // Move the cursor away from the end, then scroll back through the text.
        // This catches a lower region that renders but cannot accept touches.
        for _ in 0..<3 {
            editor.swipeDown(velocity: .fast)
        }
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.15)).tap()
        for _ in 0..<25 {
            editor.swipeUp(velocity: .fast)
        }
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.97)).tap()
        editor.typeText("_EDITED")
        assertKeyboardDoesNotCoverEditor(app)
        attachScreenshot(app, name: "Long message — bottom with keyboard")

        let editedText = editor.value as? String ?? ""
        XCTAssertTrue(editedText.hasSuffix("END_MARKER_EDITED"))
        XCTAssertEqual(editedText, originalText + "_EDITED")
        XCTAssertTrue(app.buttons["message-editor.save"].isHittable)
        app.buttons["message-editor.save"].tap()
        XCTAssertTrue(app.navigationBars["Saved edits: 1"].waitForExistence(timeout: 5))

        openEditor(app, messageSuffix: "END_MARKER_EDITED")
        XCTAssertEqual(app.textViews["message-editor.text"].value as? String, editedText)
    }

    @MainActor
    func testCancelPreservesOriginalMessage() {
        let app = launchEditor(isUser: true)
        let editor = app.textViews["message-editor.text"]
        XCTAssertEqual(editor.value as? String, "Original message")
        XCTAssertTrue(app.navigationBars["Edit your message"].exists)
        editor.tap()
        editor.typeText(" changed")
        assertKeyboardDoesNotCoverEditor(app)
        attachScreenshot(app, name: "Edit your message")
        app.buttons["message-editor.cancel"].tap()
        XCTAssertTrue(app.navigationBars["Saved edits: 0"].waitForExistence(timeout: 5))

        openEditor(app, messageSuffix: "Original message")
        XCTAssertEqual(app.textViews["message-editor.text"].value as? String, "Original message")
    }

    @MainActor
    private func assertKeyboardDoesNotCoverEditor(_ app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3), "Run with the simulator software keyboard enabled.")
        XCTAssertLessThanOrEqual(app.textViews["message-editor.text"].frame.maxY, keyboard.frame.minY)
    }

    @MainActor
    private func launchEditor(isUser: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--message-editor-ui-testing"]
        if isUser { app.launchArguments.append("--user-message") }
        app.launch()
        openEditor(app, messageSuffix: isUser ? "Original message" : "END_MARKER")
        return app
    }

    @MainActor
    private func openEditor(_ app: XCUIApplication, messageSuffix: String) {
        let message = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", messageSuffix)).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        // The long bubble extends beyond the screen; target its visible bottom.
        let visibleBottom = min(message.frame.maxY, app.frame.height - 180)
        let targetY = message.frame.height < 100 ? message.frame.midY : visibleBottom - 20
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: message.frame.midX, dy: targetY))
            .press(forDuration: 1)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.textViews["message-editor.text"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
