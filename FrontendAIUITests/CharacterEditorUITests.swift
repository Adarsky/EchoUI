import XCTest

final class CharacterEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateRemainsAccessibleWhileEditingAndRequiresPhoto() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Main Menu"].tap()
        app.buttons["New Character"].tap()

        let navigationBar = app.navigationBars["New Character"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 3))
        let createButton = navigationBar.buttons["Create"]
        XCTAssertTrue(createButton.exists)
        XCTAssertFalse(createButton.isEnabled)
        attachScreenshot(app, name: "New Character")

        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText("Luna")
        app.buttons["Done"].tap()
        app.swipeUp()

        app.buttons["Expand Description"].tap()
        let expandedEditor = app.textViews.firstMatch
        XCTAssertTrue(expandedEditor.waitForExistence(timeout: 3))
        expandedEditor.tap()
        expandedEditor.typeText("A thoughtful creative partner.")
        app.navigationBars["Description"].buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Add a photo to create this character."].waitForExistence(timeout: 3))
        XCTAssertFalse(createButton.isEnabled)
        XCTAssertTrue(createButton.isHittable)
        attachScreenshot(app, name: "Character Requires Photo")

        app.buttons["Expand Description"].tap()
        XCTAssertEqual(app.textViews.firstMatch.value as? String, "A thoughtful creative partner.")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
