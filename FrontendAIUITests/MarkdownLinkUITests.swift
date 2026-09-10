import XCTest

final class MarkdownLinkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingLinkRequiresConfirmationAndCancelDoesNotOpen() {
        let app = launchLinks()
        app.links["first site"].tap()
        let alert = app.alerts["Open external link?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "https://example.com/first?one=1&two=2")).firstMatch.exists)
        attachScreenshot(app, name: "External link confirmation")
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["markdown.opened-url"].label, "Nothing opened")
        app.links["second site"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Continue"].tap()
        XCTAssertEqual(app.staticTexts["markdown.opened-url"].label, "https://example.org/second")
    }

    @MainActor
    func testHoldingSpecificLinkShowsURLAndCopiesWithoutOpening() {
        let app = launchLinks()
        app.links["second site"].press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["https://example.org/second"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        attachScreenshot(app, name: "Link URL and Copy menu")
        app.buttons["Copy"].tap()
        app.buttons["Read Clipboard"].tap()
        XCTAssertEqual(app.staticTexts["markdown.copied-url"].label, "https://example.org/second")
        XCTAssertEqual(app.staticTexts["markdown.opened-url"].label, "Nothing opened")
    }

    @MainActor
    private func launchLinks() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--markdown-ui-testing", "--markdown-links-ui-testing"]
        app.launch()
        XCTAssertTrue(app.links["first site"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
